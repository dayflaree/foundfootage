if not SERVER then return end

local NET_READY = "FF_MapMessages_Ready"
local NET_SNAPSHOT_RESET = "FF_MapMessages_SnapshotReset"
local NET_SNAPSHOT_CHUNK = "FF_MapMessages_SnapshotChunk"
local NET_ADDED = "FF_MapMessages_Added"
local NET_DELETED = "FF_MapMessages_Deleted"
local NET_REQUEST_PLACEMENT = "FF_MapMessages_RequestPlacement"
local NET_OPEN_COMPOSER = "FF_MapMessages_OpenComposer"
local NET_POSTED = "FF_MapMessages_Posted"
local NET_FEEDBACK = "FF_MapMessages_Feedback"
local NET_SUBMIT = "FF_MapMessages_Submit"
local NET_CREATE_RESULT = "FF_MapMessages_CreateResult"

for _, name in ipairs({
    NET_READY,
    NET_SNAPSHOT_RESET,
    NET_SNAPSHOT_CHUNK,
    NET_ADDED,
    NET_DELETED,
    NET_REQUEST_PLACEMENT,
    NET_OPEN_COMPOSER,
    NET_POSTED,
    NET_FEEDBACK,
    NET_SUBMIT,
    NET_CREATE_RESULT,
}) do
    util.AddNetworkString(name)
end

local messages = {}
local readyPlayers = {}
local snapshotLoaded = false
local snapshotLoading = false
local changesLoading = false
local eventCursor = 0
local nextRefreshAt = 0
local lastPlacementRequest = {}
local lastPostedSignal = {}
local pendingPlacements = {}
local submitInFlight = {}
local SERVER_TOKEN_PATH = "foundfootage/map_messages_server_token.txt"
local SERVER_LOG_PATH = "foundfootage/map_messages_server.log"
local writeServiceReady = nil
local writeServiceReason = "Not checked yet"

local function config()
    return FFMapMessages.GetConfig()
end

local function characterCount(value)
    value = tostring(value or "")
    if utf8 and utf8.len then
        local count = utf8.len(value)
        if count then return count end
    end
    return #value
end

local function characterPrefix(value, maximum)
    value = tostring(value or "")
    maximum = math.max(0, math.floor(tonumber(maximum) or 0))
    if utf8 and utf8.sub then
        return utf8.sub(value, 1, maximum)
    end
    return string.sub(value, 1, maximum)
end

local function diagnostic(stage, details)
    details = istable(details) and details or {}
    details.stage = tostring(stage)
    details.timestamp = os.time()
    details.map = details.map or FFMapMessages.GetMapName()

    file.CreateDir("foundfootage")
    local encoded = util.TableToJSON(details, false)
    if isstring(encoded) then
        file.Append(SERVER_LOG_PATH, encoded .. "\n")
    end
end

local function notifyPlayer(ply, message, isError)
    if not IsValid(ply) then return end
    net.Start(NET_FEEDBACK)
    net.WriteBool(isError ~= false)
    net.WriteString(string.sub(tostring(message), 1, 240))
    net.Send(ply)
end

local function tableToVector(value)
    if not istable(value) then return nil end
    local x = tonumber(value.x)
    local y = tonumber(value.y)
    local z = tonumber(value.z)
    if not x or not y or not z then return nil end
    return Vector(x, y, z)
end

local function normalizeRecord(raw)
    if not FFMapMessages.IsValidRecord(raw) then return nil end
    local position = tableToVector(raw.position)
    local normal = tableToVector(raw.normal)
    if not position or not normal or normal:LengthSqr() <= 0 then return nil end

    return {
        id = raw.id,
        body = characterPrefix(raw.body, tonumber(config().MaximumLength) or 100),
        position = position,
        normal = normal:GetNormalized(),
        createdAt = math.max(0, tonumber(raw.created_at) or 0),
    }
end

local function writeRecord(record)
    net.WriteString(record.id)
    net.WriteString(record.body)
    net.WriteVector(record.position)
    net.WriteNormal(record.normal)
    net.WriteUInt(math.min(record.createdAt, 4294967295), 32)
end

local function sortedRecords()
    local records = {}
    for _, record in pairs(messages) do
        records[#records + 1] = record
    end
    table.sort(records, function(a, b)
        if a.createdAt == b.createdAt then return a.id < b.id end
        return a.createdAt < b.createdAt
    end)
    return records
end

local function sendSnapshot(ply)
    if not IsValid(ply) or not readyPlayers[ply] or not snapshotLoaded then return end

    net.Start(NET_SNAPSHOT_RESET)
    net.Send(ply)

    local records = sortedRecords()
    local chunkSize = math.Clamp(tonumber(config().SnapshotChunkSize) or 20, 1, 40)
    for offset = 1, #records, chunkSize do
        local count = math.min(chunkSize, #records - offset + 1)
        net.Start(NET_SNAPSHOT_CHUNK)
        net.WriteUInt(count, 6)
        for index = offset, offset + count - 1 do
            writeRecord(records[index])
        end
        net.Send(ply)
    end
end

local function sendSnapshotToReadyPlayers()
    for ply in pairs(readyPlayers) do
        if IsValid(ply) then
            sendSnapshot(ply)
        else
            readyPlayers[ply] = nil
        end
    end
end

local function requestJSON(path, callback)
    if not FFMapMessages.IsConfigured() then
        callback(false, nil, "APIBaseURL is not configured")
        return
    end

    local queued = HTTP({
        url = FFMapMessages.GetAPIURL(path),
        method = "get",
        headers = {
            ["Accept"] = "application/json",
        },
        timeout = 20,
        success = function(code, body)
            local decoded = util.JSONToTable(body or "")
            if code < 200 or code >= 300 or not istable(decoded) then
                callback(false, decoded, "HTTP " .. tostring(code))
                return
            end
            callback(true, decoded)
        end,
        failed = function(reason)
            callback(false, nil, tostring(reason))
        end,
    })

    if queued == false then
        callback(false, nil, "Garry's Mod refused to queue the HTTP request")
    end
end

local fetchChanges

local function readServerToken()
    local token = string.Trim(file.Read(SERVER_TOKEN_PATH, "DATA") or "")
    if token == "" then return nil end
    return token
end

local function authenticatedServerPost(path, body, callback)
    local token = readServerToken()
    if not token then
        callback(false, 0, nil, "Missing server token at data/" .. SERVER_TOKEN_PATH)
        return false
    end

    local queued = HTTP({
        url = FFMapMessages.GetAPIURL(path),
        method = "post",
        headers = {
            ["Accept"] = "application/json",
            ["X-Server-Token"] = token,
        },
        type = "application/json",
        body = body or "{}",
        timeout = 20,
        success = function(code, responseBody, responseHeaders)
            callback(true, tonumber(code) or 0, responseBody or "", nil, responseHeaders)
        end,
        failed = function(reason)
            callback(false, 0, nil, tostring(reason))
        end,
    })

    if queued == false then
        callback(false, 0, nil, "Garry's Mod refused to queue the HTTP request")
        return false
    end

    return true
end

local function sendCreateResult(ply, ok, message)
    if not IsValid(ply) then return end
    net.Start(NET_CREATE_RESULT)
    net.WriteBool(ok == true)
    net.WriteString(string.sub(tostring(message or ""), 1, 240))
    net.Send(ply)
end

local function postServerMessage(ply, body, placement)
    local steamID64 = ply:SteamID64()
    if not isstring(steamID64) or not string.match(steamID64, "^7656119%d%d%d%d%d%d%d%d%d%d$") then
        diagnostic("create_identity_rejected", {
            steamid64 = tostring(steamID64 or ""),
            steamid = tostring(ply:SteamID() or ""),
            single_player = game.SinglePlayer(),
            reason = "SteamID64 did not match the expected format",
        })
        sendCreateResult(ply, false, "Steam could not verify your player identity.")
        return
    end

    local requestID = util.CRC(table.concat({
        steamID64,
        FFMapMessages.GetMapName(),
        tostring(SysTime()),
        tostring(placement.position),
        body,
    }, ":"))

    local payload = util.TableToJSON({
        request_id = requestID,
        map = FFMapMessages.GetMapName(),
        author_steamid64 = steamID64,
        message = body,
        position = {
            x = placement.position.x,
            y = placement.position.y,
            z = placement.position.z,
        },
        normal = {
            x = placement.normal.x,
            y = placement.normal.y,
            z = placement.normal.z,
        },
    }, false)

    if not isstring(payload) then
        diagnostic("create_payload_failed", {
            request_id = requestID,
            steamid64 = steamID64,
            reason = "util.TableToJSON returned no string",
        })
        sendCreateResult(ply, false, "The message payload could not be encoded.")
        return
    end

    diagnostic("create_attempt", {
        request_id = requestID,
        steamid64 = steamID64,
        message_bytes = #body,
        position = {
            x = placement.position.x,
            y = placement.position.y,
            z = placement.position.z,
        },
        normal = {
            x = placement.normal.x,
            y = placement.normal.y,
            z = placement.normal.z,
        },
        placement_age = math.max(0, CurTime() - (placement.createdAt or CurTime())),
    })

    submitInFlight[ply] = requestID
    authenticatedServerPost("v1/server/messages", payload, function(transportOK, code, responseBody, transportReason)
        if submitInFlight[ply] == requestID then
            submitInFlight[ply] = nil
        end

        if not transportOK then
            diagnostic("create_transport_failed", {
                request_id = requestID,
                steamid64 = steamID64,
                reason = tostring(transportReason or "Unknown HTTP transport error"),
            })
            if IsValid(ply) then
                sendCreateResult(ply, false, "Message service connection failed. See data/foundfootage/map_messages_server.log")
            end
            return
        end

        local decoded = util.JSONToTable(responseBody or "")
        if code < 200 or code >= 300 or not istable(decoded) or decoded.ok ~= true then
            local workerReason = istable(decoded) and tostring(decoded.message or decoded.error or "") or ""
            if workerReason == "" then workerReason = "Cloudflare returned HTTP " .. tostring(code) end

            diagnostic("create_worker_rejected", {
                request_id = requestID,
                steamid64 = steamID64,
                code = code,
                reason = workerReason,
                response = string.sub(tostring(responseBody or ""), 1, 1000),
            })
            if IsValid(ply) then
                sendCreateResult(ply, false, workerReason)
            end
            return
        end

        local record = normalizeRecord(decoded.message)
        if not record then
            diagnostic("create_response_invalid", {
                request_id = requestID,
                steamid64 = steamID64,
                code = code,
                reason = "Worker response did not contain a valid public message record",
                response = string.sub(tostring(responseBody or ""), 1, 1000),
            })
            if IsValid(ply) then
                sendCreateResult(ply, false, "Cloudflare saved the message but returned an invalid record.")
            end
            timer.Simple(0.5, fetchChanges)
            return
        end

        diagnostic("create_succeeded", {
            request_id = requestID,
            steamid64 = steamID64,
            code = code,
            message_id = record.id,
        })

        messages[record.id] = record
        net.Start(NET_ADDED)
        writeRecord(record)
        net.Send(player.GetHumans())
        if IsValid(ply) then
            sendCreateResult(ply, true, "TAPE RECORDED")
            pendingPlacements[ply] = nil
        end
        timer.Simple(1, fetchChanges)
    end)
end

local function checkWriteService(notifyTarget)
    if not FFMapMessages.IsConfigured() then
        writeServiceReady = false
        writeServiceReason = "APIBaseURL is not configured"
        diagnostic("write_health_failed", { reason = writeServiceReason })
        if IsValid(notifyTarget) then notifyPlayer(notifyTarget, writeServiceReason) end
        return
    end

    authenticatedServerPost("v1/server/health", "{}", function(transportOK, code, responseBody, transportReason)
        if not transportOK then
            writeServiceReady = false
            writeServiceReason = tostring(transportReason or "Unknown HTTP transport error")
            diagnostic("write_health_failed", { reason = writeServiceReason })
            if IsValid(notifyTarget) then
                notifyPlayer(notifyTarget, "Message service health check failed. See data/foundfootage/map_messages_server.log")
            end
            return
        end

        local decoded = util.JSONToTable(responseBody or "")
        if code < 200 or code >= 300 or not istable(decoded) or decoded.ok ~= true
            or decoded.authenticated ~= true or decoded.database ~= "ready" then
            writeServiceReady = false
            writeServiceReason = istable(decoded) and tostring(decoded.message or decoded.error or "") or ""
            if writeServiceReason == "" then writeServiceReason = "Cloudflare returned HTTP " .. tostring(code) end
            diagnostic("write_health_failed", {
                code = code,
                reason = writeServiceReason,
                response = string.sub(tostring(responseBody or ""), 1, 1000),
            })
            if IsValid(notifyTarget) then notifyPlayer(notifyTarget, writeServiceReason) end
            return
        end

        writeServiceReady = true
        writeServiceReason = "Authenticated and D1 ready"
        diagnostic("write_health_ready", { code = code, message = writeServiceReason })
        if IsValid(notifyTarget) then
            notifyPlayer(notifyTarget, "MESSAGE SERVICE READY", false)
        end
    end)
end

local function mapPath(endpoint, query)
    -- Source map names are restricted to URL-safe letters, digits, underscores,
    -- and hyphens by the message service, so no realm-specific encoder is needed.
    local mapName = FFMapMessages.GetMapName()
    return "v1/maps/" .. mapName .. "/" .. endpoint .. (query or "")
end

local function loadSnapshotPage(after, baseEventCursor)
    requestJSON(mapPath("snapshot", "?after=" .. tostring(after) .. "&limit=250"), function(ok, payload, reason)
        if not ok then
            snapshotLoading = false
            nextRefreshAt = CurTime() + 30
            return
        end

        if baseEventCursor == nil then
            baseEventCursor = math.max(0, tonumber(payload.event_cursor) or 0)
        end

        for _, raw in ipairs(payload.messages or {}) do
            local record = normalizeRecord(raw)
            if record then messages[record.id] = record end
        end

        local nextAfter = math.max(after, tonumber(payload.scan_cursor) or after)
        if payload.has_more == true and nextAfter > after then
            loadSnapshotPage(nextAfter, baseEventCursor)
            return
        end

        eventCursor = baseEventCursor
        snapshotLoaded = true
        snapshotLoading = false
        nextRefreshAt = CurTime() + math.max(15, tonumber(config().PollInterval) or 60)
        sendSnapshotToReadyPlayers()
        fetchChanges()
    end)
end

local function loadSnapshot()
    if snapshotLoading or not FFMapMessages.IsConfigured() then return end
    snapshotLoading = true
    snapshotLoaded = false
    messages = {}
    loadSnapshotPage(0, nil)
end

fetchChanges = function()
    if changesLoading or snapshotLoading or not snapshotLoaded or not FFMapMessages.IsConfigured() then return end
    changesLoading = true

    local function loadPage(after)
        requestJSON(mapPath("changes", "?after=" .. tostring(after) .. "&limit=250"), function(ok, payload, reason)
            if not ok then
                changesLoading = false
                nextRefreshAt = CurTime() + 30
                return
            end

            for _, event in ipairs(payload.events or {}) do
                local eventID = math.max(0, tonumber(event.event_id) or 0)
                eventCursor = math.max(eventCursor, eventID)

                if event.type == "create" then
                    local record = normalizeRecord(event.message)
                    if record then
                        messages[record.id] = record
                        net.Start(NET_ADDED)
                        writeRecord(record)
                        net.Send(player.GetHumans())
                    end
                elseif event.type == "delete" and isstring(event.message_id) then
                    messages[event.message_id] = nil
                    net.Start(NET_DELETED)
                    net.WriteString(event.message_id)
                    net.Send(player.GetHumans())
                end
            end

            local nextCursor = math.max(eventCursor, tonumber(payload.cursor) or eventCursor)
            eventCursor = nextCursor
            if payload.has_more == true then
                loadPage(nextCursor)
                return
            end

            changesLoading = false
            nextRefreshAt = CurTime() + math.max(15, tonumber(config().PollInterval) or 60)
        end)
    end

    loadPage(eventCursor)
end

local function requestPlacement(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not FFMapMessages.IsConfigured() then
        notifyPlayer(ply, "Global messages are waiting for the service URL to be configured.")
        return
    end

    local now = CurTime()
    if (lastPlacementRequest[ply] or 0) > now then return end
    lastPlacementRequest[ply] = now + 0.25

    local maximumDistance = math.Clamp(tonumber(config().PlacementDistance) or 220, 64, 512)
    local startPosition = ply:GetShootPos()
    local aimTrace = util.TraceLine({
        start = startPosition,
        endpos = startPosition + ply:GetAimVector() * maximumDistance,
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })

    if not aimTrace.Hit or aimTrace.HitSky or not aimTrace.HitWorld then
        notifyPlayer(ply, "Aim at the ground or a lower wall nearby.")
        return
    end

    -- Messages are physical cassette tapes. Project the aimed point down onto
    -- permanent map geometry so every new tape rests on the floor.
    local groundTrace = util.TraceLine({
        start = aimTrace.HitPos + Vector(0, 0, 48),
        endpos = aimTrace.HitPos - Vector(0, 0, 144),
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })

    if not groundTrace.Hit or groundTrace.HitSky or not groundTrace.HitWorld or groundTrace.HitNormal.z < 0.45 then
        notifyPlayer(ply, "No stable floor was found beneath that location.")
        return
    end

    local position = groundTrace.HitPos + groundTrace.HitNormal * 1.25
    if not util.IsInWorld(position) then
        notifyPlayer(ply, "That location is outside the map world.")
        return
    end

    pendingPlacements[ply] = {
        position = position,
        normal = groundTrace.HitNormal:GetNormalized(),
        createdAt = CurTime(),
    }

    net.Start(NET_OPEN_COMPOSER)
    net.WriteVector(position)
    net.WriteNormal(groundTrace.HitNormal)
    net.Send(ply)
end

net.Receive(NET_READY, function(_, ply)
    readyPlayers[ply] = true
    if snapshotLoaded then sendSnapshot(ply) end
end)

net.Receive(NET_REQUEST_PLACEMENT, function(_, ply)
    requestPlacement(ply)
end)

net.Receive(NET_SUBMIT, function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if submitInFlight[ply] then
        sendCreateResult(ply, false, "A tape is already being recorded.")
        return
    end

    local placement = pendingPlacements[ply]
    if not placement then
        diagnostic("create_missing_placement", {
            steamid64 = tostring(ply:SteamID64() or ""),
            reason = "No validated cassette placement was stored for this player",
        })
        sendCreateResult(ply, false, "No cassette placement is active. Aim at the ground and press reload again.")
        return
    end

    local body = string.Trim(net.ReadString() or "")
    body = string.gsub(body, "%c", "")
    local maximumLength = math.Clamp(tonumber(config().MaximumLength) or 100, 1, 100)
    if body == "" then
        sendCreateResult(ply, false, "Enter a message before recording the tape.")
        return
    end
    if characterCount(body) > maximumLength then
        sendCreateResult(ply, false, "Messages are limited to 100 characters.")
        return
    end

    postServerMessage(ply, body, placement)
end)

net.Receive(NET_POSTED, function(_, ply)
    local now = CurTime()
    if (lastPostedSignal[ply] or 0) > now then return end
    lastPostedSignal[ply] = now + 3
    timer.Simple(0.5, fetchChanges)
end)

hook.Add("KeyPress", "FF_MapMessages_ReloadPlacement", function(ply, key)
    if key == IN_RELOAD then requestPlacement(ply) end
end)

hook.Add("PlayerDisconnected", "FF_MapMessages_PlayerCleanup", function(ply)
    readyPlayers[ply] = nil
    lastPlacementRequest[ply] = nil
    lastPostedSignal[ply] = nil
    pendingPlacements[ply] = nil
    submitInFlight[ply] = nil
end)

hook.Add("Initialize", "FF_MapMessages_Initialize", function()
    timer.Simple(2, function()
        if FFMapMessages.IsConfigured() then
            checkWriteService()
            loadSnapshot()
        end
    end)
end)

hook.Add("Think", "FF_MapMessages_Poll", function()
    if not FFMapMessages.IsConfigured() or CurTime() < nextRefreshAt then return end
    if snapshotLoaded then
        fetchChanges()
    else
        loadSnapshot()
    end
end)

concommand.Add("ff_messages_refresh", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    nextRefreshAt = 0
    if snapshotLoaded then fetchChanges() else loadSnapshot() end
end)

concommand.Add("ff_messages_diagnose", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    checkWriteService(IsValid(ply) and ply or nil)
end)
