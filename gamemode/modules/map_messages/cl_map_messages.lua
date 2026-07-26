if not CLIENT then return end

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

local TOKEN_DIRECTORY = "foundfootage"
local TOKEN_PATH = TOKEN_DIRECTORY .. "/map_messages_token.txt"
local AUTH_TIMER = "FF_MapMessages_AuthPoll"
local DEFAULT_CASSETTE_MODEL = "models/angry_builder/insidethebackrooms/cassette.mdl"
local pauseMenuConfig = ((FF_CONFIG or {}).HUD or {}).PauseMenu or {}
local COMPOSER_CANVAS_WIDTH = math.max(math.floor(tonumber(pauseMenuConfig.CanvasWidth) or 720), 320)
local COMPOSER_CANVAS_HEIGHT = math.max(math.floor(tonumber(pauseMenuConfig.CanvasHeight) or 576), 240)
local COMPOSER_ACTION_WIDTH = 300
local COMPOSER_ACTION_HEIGHT = 38
local COMPOSER_ACTION_GAP = 10
local COMPOSER_ACTION_Y = 388

local messages = {}
local focusedMessage = nil
local readingMessage = nil
local readingStartedAt = 0
local tapePlaybackSound = nil
local loginTicket = nil
local pendingSubmission = nil
local composer = nil
local composerEntry = nil
local composerPosition = nil
local composerNormal = nil
local composerSelectedAction = 1
local composerHoveredAction = nil
local composerPauseSuppressedUntil = 0
local composerOpenedAt = 0
local lastPlacementBindAt = 0

-- Remove clientside models left by a Lua refresh before replacing the state table.
FFMapMessages.ClientCassetteModels = FFMapMessages.ClientCassetteModels or {}
for _, model in pairs(FFMapMessages.ClientCassetteModels) do
    if IsValid(model) then model:Remove() end
end
FFMapMessages.ClientCassetteModels = {}
local cassetteModels = FFMapMessages.ClientCassetteModels

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

local function vhsFontFamily()
    return FF_VHS_FONT_FAMILY or "VCR OSD Mono"
end

local function registerFonts()
    -- Composer fonts are drawn into the same fixed VHS canvas as the pause
    -- menu. Playback fonts still scale with the physical display.
    local screenScale = math.Clamp(ScrH() / 900, 1, 1.35)
    local function scaled(size)
        return math.max(12, math.floor(size * screenScale + 0.5))
    end

    surface.CreateFont("FF_MapMessage_ComposerTitle", {
        font = vhsFontFamily(),
        size = 34,
        weight = 500,
        antialias = false,
        extended = true,
    })
    surface.CreateFont("FF_MapMessage_ComposerLabel", {
        font = vhsFontFamily(),
        size = 18,
        weight = 500,
        antialias = false,
        extended = true,
    })
    surface.CreateFont("FF_MapMessage_ComposerEntry", {
        font = vhsFontFamily(),
        size = 26,
        weight = 500,
        antialias = false,
        extended = true,
    })
    surface.CreateFont("FF_MapMessage_ComposerButton", {
        font = vhsFontFamily(),
        size = 20,
        weight = 500,
        antialias = false,
        extended = true,
    })
    surface.CreateFont("FF_MapMessage_Title", {
        font = vhsFontFamily(),
        size = scaled(28),
        weight = 500,
        antialias = false,
        extended = true,
    })
    surface.CreateFont("FF_MapMessage_Body", {
        font = vhsFontFamily(),
        size = scaled(36),
        weight = 500,
        antialias = false,
        extended = true,
    })
    surface.CreateFont("FF_MapMessage_Meta", {
        font = vhsFontFamily(),
        size = scaled(21),
        weight = 500,
        antialias = false,
        extended = true,
    })
    surface.CreateFont("FF_MapMessage_Prompt", {
        font = vhsFontFamily(),
        size = scaled(25),
        weight = 500,
        antialias = false,
        extended = true,
    })
end

registerFonts()
hook.Add("OnScreenSizeChanged", "FF_MapMessages_RebuildFonts", registerFonts)

local function playUISound(name, volume)
    if isfunction(FF_PlayUISound) then
        FF_PlayUISound(name, volume or 0.75)
    end
end

net.Receive(NET_FEEDBACK, function()
    local isError = net.ReadBool()
    net.ReadString()
    if isError then playUISound("error", 0.72) end
end)

local function removeCassetteModel(id)
    local model = cassetteModels[id]
    if IsValid(model) then model:Remove() end
    cassetteModels[id] = nil
end

local function clearCassetteModels()
    for id in pairs(cassetteModels) do
        removeCassetteModel(id)
    end
end

local function stopTapePlaybackSound()
    if tapePlaybackSound then
        tapePlaybackSound:Stop()
        tapePlaybackSound = nil
    end
end

local function playTapePlaybackSound()
    stopTapePlaybackSound()

    local ply = LocalPlayer()
    local introConfig = (((FF_CONFIG or {}).Player or {}).SpawnIntro or {})
    local soundPath = tostring(introConfig.Sound or "foundfootage/vhs_startup.wav")
    if not IsValid(ply) or soundPath == "" then return end

    tapePlaybackSound = CreateSound(ply, soundPath)
    if tapePlaybackSound then
        tapePlaybackSound:PlayEx(1, 100)
    end
end

local function stopReading(playSound)
    if not readingMessage then return end
    stopTapePlaybackSound()
    if playSound ~= false then playUISound("tape_eject", 0.82) end
    readingMessage = nil
    readingStartedAt = 0
end

local function readRecord()
    return {
        id = net.ReadString(),
        body = net.ReadString(),
        position = net.ReadVector(),
        normal = net.ReadNormal(),
        createdAt = net.ReadUInt(32),
    }
end

local function installRecord(record)
    if not record or not record.id then return end
    removeCassetteModel(record.id)
    messages[record.id] = record
end

net.Receive(NET_SNAPSHOT_RESET, function()
    clearCassetteModels()
    messages = {}
    focusedMessage = nil
    stopReading(false)
end)

net.Receive(NET_SNAPSHOT_CHUNK, function()
    local count = net.ReadUInt(6)
    for _ = 1, count do
        installRecord(readRecord())
    end
end)

net.Receive(NET_ADDED, function()
    installRecord(readRecord())
end)

net.Receive(NET_DELETED, function()
    local id = net.ReadString()
    messages[id] = nil
    removeCassetteModel(id)
    if focusedMessage and focusedMessage.id == id then focusedMessage = nil end
    if readingMessage and readingMessage.id == id then stopReading(false) end
end)

local function bearerToken()
    if not file.Exists(TOKEN_PATH, "DATA") then return nil end
    local token = string.Trim(file.Read(TOKEN_PATH, "DATA") or "")
    if token == "" then return nil end
    return token
end

local function saveToken(token)
    file.CreateDir(TOKEN_DIRECTORY)
    file.Write(TOKEN_PATH, token)
end

local function apiRequest(path, options, callback)
    options = options or {}
    if not FFMapMessages.IsConfigured() then
        callback(false, nil, "The global message service is not configured.")
        return
    end

    local headers = options.headers or {}
    headers["Accept"] = "application/json"
    headers["User-Agent"] = "FoundFootage-GMod/1"

    HTTP({
        url = FFMapMessages.GetAPIURL(path),
        method = string.upper(options.method or "GET"),
        headers = headers,
        body = options.body,
        timeout = 20,
        success = function(code, body)
            local decoded = util.JSONToTable(body or "")
            if code < 200 or code >= 300 then
                callback(false, decoded, istable(decoded) and decoded.message or ("HTTP " .. tostring(code)), code)
                return
            end
            callback(true, decoded, nil, code)
        end,
        failed = function(reason)
            callback(false, nil, tostring(reason), 0)
        end,
    })
end

local function randomLoginTicket()
    local ply = LocalPlayer()
    local seed = table.concat({
        tostring(SysTime()),
        tostring(RealTime()),
        IsValid(ply) and ply:SteamID64() or "0",
        tostring(math.random()),
    }, ":")
    return string.sub(util.SHA256(seed), 1, 48)
end

local submitMessage

local function beginSteamLogin()
    if not FFMapMessages.IsConfigured() then
        playUISound("error", 0.72)
        return
    end
    if loginTicket then
        return
    end

    loginTicket = randomLoginTicket()
    gui.OpenURL(FFMapMessages.GetAPIURL("v1/auth/start?ticket=" .. loginTicket))

    timer.Create(AUTH_TIMER, 2, 150, function()
        if not loginTicket then
            timer.Remove(AUTH_TIMER)
            return
        end

        apiRequest("v1/auth/finish?ticket=" .. loginTicket, nil, function(ok, payload, reason, code)
            if code == 202 then return end
            if not ok then
                if code == 410 or code == 400 then
                    loginTicket = nil
                    timer.Remove(AUTH_TIMER)
                    playUISound("error", 0.72)
                end
                return
            end

            if not istable(payload) or payload.status ~= "authenticated" or not isstring(payload.token) then return end
            saveToken(payload.token)
            loginTicket = nil
            timer.Remove(AUTH_TIMER)
            playUISound("confirm_01", 0.78)

            if pendingSubmission then
                local queued = pendingSubmission
                pendingSubmission = nil
                submitMessage(queued.body, queued.position, queued.normal)
            end
        end)
    end)
end

submitMessage = function(body)
    net.Start(NET_SUBMIT)
    net.WriteString(body)
    net.SendToServer()
end

net.Receive(NET_CREATE_RESULT, function()
    local ok = net.ReadBool()
    net.ReadString()

    if ok then
        playUISound("record_stop", 0.82)
        return
    end

    playUISound("error", 0.8)
end)

local function getComposerActionRect(index)
    local x = math.floor((COMPOSER_CANVAS_WIDTH - COMPOSER_ACTION_WIDTH) * 0.5)
    local y = COMPOSER_ACTION_Y + (index - 1) * (COMPOSER_ACTION_HEIGHT + COMPOSER_ACTION_GAP)
    return x, y, COMPOSER_ACTION_WIDTH, COMPOSER_ACTION_HEIGHT
end

function FF_IsMapMessageComposerOpen()
    return IsValid(composer)
end

local function clearComposerState()
    composerEntry = nil
    composerPosition = nil
    composerNormal = nil
    composerSelectedAction = 1
    composerHoveredAction = nil
    composerOpenedAt = 0
end

local function closeComposer(soundName)
    local panel = composer
    composer = nil
    clearComposerState()

    if soundName then
        playUISound(soundName, 0.72)
    end
    if IsValid(panel) then
        panel:Remove()
    end
end

local function suppressPauseMenuForComposerEscape()
    composerPauseSuppressedUntil = RealTime() + 0.25
end

function FF_ConsumeMapMessagePauseRequest()
    if readingMessage then
        stopReading(true)
        return true
    end

    if IsValid(composer) then
        suppressPauseMenuForComposerEscape()
        closeComposer("cancel_02")
        return true
    end

    if RealTime() <= composerPauseSuppressedUntil then
        return true
    end

    return false
end

local function drawCornerBrackets(x, y, width, height, length, color)
    surface.SetDrawColor(color)
    surface.DrawLine(x, y, x + length, y)
    surface.DrawLine(x, y, x, y + length)
    surface.DrawLine(x + width, y, x + width - length, y)
    surface.DrawLine(x + width, y, x + width, y + length)
    surface.DrawLine(x, y + height, x + length, y + height)
    surface.DrawLine(x, y + height, x, y + height - length)
    surface.DrawLine(x + width, y + height, x + width - length, y + height)
    surface.DrawLine(x + width, y + height, x + width, y + height - length)
end

local function selectComposerAction(index, soundName)
    index = math.Clamp(math.floor(tonumber(index) or 1), 1, 2)
    if composerSelectedAction == index then return false end
    composerSelectedAction = index
    if soundName then playUISound(soundName, 0.58) end
    return true
end

local function activateComposerAction(index)
    if not IsValid(composer) then return end
    index = math.Clamp(math.floor(tonumber(index) or composerSelectedAction), 1, 2)

    if index == 2 then
        closeComposer("cancel_01")
        return
    end

    local body = IsValid(composerEntry) and string.Trim(composerEntry:GetValue() or "") or ""
    if body == "" then
        playUISound("error", 0.8)
        return
    end

    if characterCount(body) > 100 then
        playUISound("error", 0.8)
        return
    end

    local position = composerPosition
    local normal = composerNormal
    if not isvector(position) or not isvector(normal) then
        playUISound("error", 0.8)
        closeComposer()
        return
    end

    playUISound("confirm_02", 0.8)
    closeComposer()
    submitMessage(body)
end

local function openComposer(position, normal)
    closeComposer()

    local maximumLength = math.Clamp(tonumber(config().MaximumLength) or 100, 1, 100)
    composerPosition = position
    composerNormal = normal
    composerSelectedAction = 1
    composerOpenedAt = RealTime()
    composerHoveredAction = nil

    composer = vgui.Create("DFrame")
    composer:SetSize(ScrW(), ScrH())
    composer:SetPos(0, 0)
    composer:SetTitle("")
    composer:ShowCloseButton(false)
    composer:SetDraggable(false)
    composer:SetDeleteOnClose(true)
    composer:SetKeyboardInputEnabled(true)
    composer:SetMouseInputEnabled(true)
    composer:SetCursor("arrow")
    composer:SetDrawOnTop(true)
    composer:MakePopup()
    composer.Paint = function()
        return false
    end

    local entry = vgui.Create("DTextEntry", composer)
    composerEntry = entry
    entry:SetMultiline(false)
    entry:SetUpdateOnType(true)
    entry:SetMaximumCharCount(maximumLength)
    entry:SetPos(-16, -16)
    entry:SetSize(8, 8)
    entry:SetAlpha(0)
    entry.Paint = function() end

    entry.OnValueChange = function(self)
        local value = self:GetValue() or ""
        if characterCount(value) <= maximumLength then return end
        local truncated = characterPrefix(value, maximumLength)
        self:SetValue(truncated)
        self:SetCaretPos(#truncated)
    end

    entry.OnEnter = function()
        activateComposerAction(composerSelectedAction)
    end

    entry.OnKeyCodeTyped = function(_, key)
        if key == KEY_ESCAPE then
            suppressPauseMenuForComposerEscape()
            closeComposer("cancel_02")
            return true
        end
        if key == KEY_UP then
            selectComposerAction(1, "navigate_up")
            return true
        end
        if key == KEY_DOWN then
            selectComposerAction(2, "navigate_down")
            return true
        end
        if key == KEY_TAB then
            local nextIndex = composerSelectedAction == 1 and 2 or 1
            selectComposerAction(nextIndex, nextIndex == 1 and "navigate_up" or "navigate_down")
            return true
        end
    end

    composer.Think = function(self)
        if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then
            self:SetSize(ScrW(), ScrH())
            self:SetPos(0, 0)
        end

        -- Clicking the fullscreen controller normally steals keyboard focus
        -- from the invisible DTextEntry. Keep input attached to the entry so
        -- typing resumes immediately after clicking anywhere in the menu.
        if IsValid(entry) and vgui.GetKeyboardFocus() ~= entry then
            entry:RequestFocus()
        end

        local cursorX, cursorY = self:LocalCursorPos()
        local canvasX = cursorX / math.max(self:GetWide(), 1) * COMPOSER_CANVAS_WIDTH
        local canvasY = cursorY / math.max(self:GetTall(), 1) * COMPOSER_CANVAS_HEIGHT
        local hovered
        for index = 1, 2 do
            local x, y, width, height = getComposerActionRect(index)
            if canvasX >= x and canvasX <= x + width
                and canvasY >= y and canvasY <= y + height then
                hovered = index
                break
            end
        end

        if hovered ~= composerHoveredAction then
            composerHoveredAction = hovered
            if hovered then
                selectComposerAction(hovered, "hover_01")
            end
        end
    end

    composer.OnMousePressed = function(_, mouseCode)
        if mouseCode == MOUSE_LEFT and composerHoveredAction then
            activateComposerAction(composerHoveredAction)
        end
    end

    composer.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then
            suppressPauseMenuForComposerEscape()
            closeComposer("cancel_02")
            return
        end
        if key == KEY_ENTER or key == KEY_PAD_ENTER then
            activateComposerAction(composerSelectedAction)
            return
        end
        if key == KEY_UP then
            selectComposerAction(1, "navigate_up")
            return
        end
        if key == KEY_DOWN then
            selectComposerAction(2, "navigate_down")
        end
    end

    composer.OnRemove = function(self)
        if composer == self then
            composer = nil
            clearComposerState()
        end
    end

    playUISound("record_start", 0.82)
    timer.Simple(0, function()
        if IsValid(entry) then entry:RequestFocus() end
    end)
end

net.Receive(NET_OPEN_COMPOSER, function()
    openComposer(net.ReadVector(), net.ReadNormal())
end)

local function requestPlacement()
    if not FFMapMessages.IsConfigured() then
        playUISound("error", 0.72)
        return
    end
    net.Start(NET_REQUEST_PLACEMENT)
    net.SendToServer()
end

hook.Add("PlayerBindPress", "FF_MapMessages_ReloadPlacement", function(_, bind, pressed)
    if not pressed then return end
    if not string.StartWith(string.lower(tostring(bind or "")), "+reload") then return end
    if IsValid(composer) then return end
    if FF_IsVHSPauseMenuOpen and FF_IsVHSPauseMenuOpen() then return end

    local now = RealTime()
    if now < lastPlacementBindAt then return end
    lastPlacementBindAt = now + 0.2

    -- Keep the normal reload bind available to the camera while also sending
    -- a direct placement request. The server-side KeyPress hook remains as a
    -- fallback and its short debounce collapses duplicate requests.
    requestPlacement()
end)

concommand.Add("ff_leave_message", requestPlacement)
concommand.Add("ff_messages_login", beginSteamLogin)
concommand.Add("ff_messages_logout", function()
    local token = bearerToken()
    if token then
        apiRequest("v1/auth/logout", {
            method = "post",
            headers = { ["Authorization"] = "Bearer " .. token },
        }, function() end)
    end
    file.Delete(TOKEN_PATH)
end)

concommand.Add("ff_message_delete", function(_, _, arguments)
    local id = tostring(arguments[1] or "")
    if not string.match(id, "^[0-9a-fA-F%-]+$") or #id ~= 36 then
        playUISound("error", 0.72)
        return
    end
    local token = bearerToken()
    if not token then
        playUISound("error", 0.72)
        return
    end
    apiRequest("v1/messages/" .. id, {
        method = "delete",
        headers = { ["Authorization"] = "Bearer " .. token },
    }, function(ok, _, reason)
        if ok then
            playUISound("tape_eject", 0.8)
            net.Start(NET_POSTED)
            net.SendToServer()
        else
            playUISound("error", 0.8)
        end
    end)
end)

local function resolveCassetteTransform(record)
    if record.renderPosition and record.renderNormal and record.renderAngles then
        return record.renderPosition, record.renderNormal, record.renderAngles
    end

    local position = record.position
    local normal = record.normal
    local groundTrace = util.TraceLine({
        start = record.position + Vector(0, 0, 48),
        endpos = record.position - Vector(0, 0, 144),
        mask = MASK_SOLID_BRUSHONLY,
    })
    if groundTrace.Hit and not groundTrace.HitSky and groundTrace.HitNormal.z >= 0.35 then
        position = groundTrace.HitPos + groundTrace.HitNormal * 1.25
        normal = groundTrace.HitNormal
    elseif normal.z < 0.35 then
        normal = Vector(0, 0, 1)
    end

    local angles = normal:Angle()
    angles:RotateAroundAxis(angles:Right(), -90)
    local yawSeed = tonumber(util.CRC(record.id)) or 0
    angles:RotateAroundAxis(angles:Up(), yawSeed % 360)

    record.renderPosition = position
    record.renderNormal = normal
    record.renderAngles = angles
    return position, normal, angles
end

local function cassetteModelFor(record)
    local modelPath = tostring(config().CassetteModel or DEFAULT_CASSETTE_MODEL)
    local model = cassetteModels[record.id]
    if IsValid(model) and model:GetModel() ~= modelPath then
        removeCassetteModel(record.id)
        model = nil
    end
    if IsValid(model) then return model end

    model = ClientsideModel(modelPath, RENDERGROUP_OPAQUE)
    if not IsValid(model) then return nil end
    model:SetNoDraw(true)
    model:SetModelScale(math.Clamp(tonumber(config().CassetteScale) or 1, 0.25, 3), 0)

    -- The bundled cassette's second compiled LOD is empty. Force the populated
    -- highest-detail LOD so Source never switches the model to zero geometry.
    model:SetLOD(0)

    if model:SkinCount() > 1 then
        local skinSeed = tonumber(util.CRC(record.id .. ":skin")) or 0
        model:SetSkin(skinSeed % model:SkinCount())
    end
    cassetteModels[record.id] = model
    return model
end

local function recordVisibleFromPlayer(ply, record, maximumDistance)
    local position = resolveCassetteTransform(record)
    local eye = ply:EyePos()
    local offset = position - eye
    local distanceSquared = offset:LengthSqr()
    if distanceSquared > maximumDistance * maximumDistance or distanceSquared <= 1 then return false end
    if ply:EyeAngles():Forward():Dot(offset:GetNormalized()) < 0.91 then return false end

    local trace = util.TraceLine({
        start = eye,
        endpos = position + Vector(0, 0, 4),
        filter = ply,
        mask = MASK_VISIBLE,
    })
    return not trace.Hit or trace.HitPos:DistToSqr(position) < 100
end

local function startReading(record)
    readingMessage = record
    readingStartedAt = RealTime()
    playTapePlaybackSound()
end

hook.Add("Think", "FF_MapMessages_SelectCassette", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local interactionDistance = math.max(64, tonumber(config().InteractionDistance) or 150)
    local best = nil
    local bestScore = -math.huge
    local eye = ply:EyePos()
    local forward = ply:EyeAngles():Forward()

    for _, record in pairs(messages) do
        local position = resolveCassetteTransform(record)
        local offset = position - eye
        local distance = offset:Length()
        if distance <= interactionDistance and distance > 1 then
            local dot = forward:Dot(offset / distance)
            local score = dot * 2.4 - distance / interactionDistance
            if dot > 0.91 and score > bestScore and recordVisibleFromPlayer(ply, record, interactionDistance) then
                best = record
                bestScore = score
            end
        end
    end

    focusedMessage = best

    if readingMessage then
        local autoCloseDistance = math.max(interactionDistance, tonumber(config().ReadingAutoCloseDistance) or 360)
        local readPosition = resolveCassetteTransform(readingMessage)
        if not messages[readingMessage.id] or ply:EyePos():DistToSqr(readPosition) > autoCloseDistance * autoCloseDistance then
            stopReading(false)
        end
    end
end)

hook.Add("PlayerBindPress", "FF_MapMessages_UseCassette", function(_, bind, pressed)
    if not pressed or not string.find(bind, "+use", 1, true) then return end

    if focusedMessage then
        if readingMessage and readingMessage.id == focusedMessage.id then
            stopReading(true)
        else
            startReading(focusedMessage)
        end
        return true
    end

    if readingMessage then
        stopReading(true)
        return true
    end
end)

-- Remove the former translucent hook during Lua auto-refresh. The cassette
-- materials use alpha testing, which belongs in the opaque world pass.
hook.Remove("PostDrawTranslucentRenderables", "FF_MapMessages_DrawCassettes")

hook.Add("PostDrawOpaqueRenderables", "FF_MapMessages_DrawCassettes", function(drawingDepth, skybox)
    -- Render hooks can run for shadow/depth and skybox views. Drawing the
    -- clientside model in those auxiliary passes can produce duplicate or
    -- inconsistent visibility results, so draw it once in the main view.
    if drawingDepth or skybox then return end

    for _, record in pairs(messages) do
        local model = cassetteModelFor(record)
        if IsValid(model) then
            local position, _, angles = resolveCassetteTransform(record)
            model:SetPos(position)
            model:SetAngles(angles)
            model:SetupBones()
            render.SetBlend(1)
            render.SetColorModulation(1, 1, 1)
            model:DrawModel()
        end
    end

    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)
end)

local function textLength(text)
    if utf8 and utf8.len then
        local length = utf8.len(text)
        if length then return length end
    end
    return #text
end

local function textPrefix(text, count)
    if utf8 and utf8.sub then
        return utf8.sub(text, 1, count)
    end
    return string.sub(text, 1, count)
end

local function wrapText(text, font, maximumWidth)
    surface.SetFont(font)
    local lines = {}

    local function pushOversizedWord(word)
        local piece = ""
        local length = textLength(word)

        for index = 1, length do
            local character
            if utf8 and utf8.sub then
                character = utf8.sub(word, index, index)
            else
                character = string.sub(word, index, index)
            end

            local candidate = piece .. character
            if piece ~= "" and surface.GetTextSize(candidate) > maximumWidth then
                lines[#lines + 1] = piece
                piece = character
            else
                piece = candidate
            end
        end

        return piece
    end

    for sourceLine in string.gmatch(text .. "\n", "(.-)\n") do
        local current = ""
        for word in string.gmatch(sourceLine, "%S+") do
            local candidate = current == "" and word or (current .. " " .. word)
            if surface.GetTextSize(candidate) <= maximumWidth then
                current = candidate
            else
                if current ~= "" then
                    lines[#lines + 1] = current
                    current = ""
                end

                if surface.GetTextSize(word) > maximumWidth then
                    current = pushOversizedWord(word)
                else
                    current = word
                end
            end
        end

        if current ~= "" then lines[#lines + 1] = current end
    end

    if #lines == 0 then lines[1] = "" end
    return lines
end

local function drawShadowedText(text, font, x, y, color, horizontal, vertical)
    draw.SimpleText(text, font, x + 2, y + 2, Color(0, 0, 0, color.a), horizontal, vertical)
    draw.SimpleText(text, font, x, y, color, horizontal, vertical)
end

local function drawFilledCircle(x, y, radius, color, segments)
    local vertices = {}
    segments = math.max(12, math.floor(tonumber(segments) or 24))

    for index = 0, segments - 1 do
        local angle = math.rad(index / segments * -360)
        vertices[#vertices + 1] = {
            x = x + math.cos(angle) * radius,
            y = y + math.sin(angle) * radius,
        }
    end

    draw.NoTexture()
    surface.SetDrawColor(color)
    surface.DrawPoly(vertices)
end

local function formatTapeTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60) % 60
    local remainingSeconds = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, remainingSeconds)
end

local function drawDoubleFrame(x, y, width, height, outerColor, innerColor)
    surface.SetDrawColor(outerColor)
    surface.DrawOutlinedRect(x, y, width, height, 2)
    surface.SetDrawColor(innerColor)
    surface.DrawOutlinedRect(x + 6, y + 6, width - 12, height - 12, 1)
end

local function useBindingLabel()
    local binding = input.LookupBinding("+use")
    if not isstring(binding) or binding == "" then return "E" end
    return string.upper(binding)
end

local function drawComposerBehindVHS(canvasWidth, canvasHeight)
    if not IsValid(composer) then return end

    local width = COMPOSER_CANVAS_WIDTH
    local height = COMPOSER_CANVAS_HEIGHT
    local outerX = 48
    local outerY = 34
    local outerWidth = width - outerX * 2
    local outerHeight = height - outerY * 2
    local left = outerX + 28
    local right = outerX + outerWidth - 28
    local centerX = math.floor(width * 0.5)
    local white = Color(242, 242, 232, 255)
    local dim = Color(166, 174, 166, 235)
    local faint = Color(104, 112, 106, 210)
    local red = Color(226, 40, 34, 255)

    -- Opaque black recorder plane. RealisticVHSEffect2 supplies the actual VHS
    -- treatment; this menu intentionally adds no scanline texture of its own.
    surface.SetDrawColor(0, 0, 0, 238)
    surface.DrawRect(0, 0, width, height)
    drawDoubleFrame(outerX, outerY, outerWidth, outerHeight, white, faint)

    local recBlink = math.floor(RealTime() * 2) % 2 == 0
    drawFilledCircle(left + 8, outerY + 39, 8, Color(red.r, red.g, red.b, recBlink and 255 or 90), 28)
    drawShadowedText(
        "REC",
        "FF_MapMessage_ComposerLabel",
        left + 28,
        outerY + 28,
        white,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )
    drawShadowedText(
        "TAPE MESSAGE",
        "FF_MapMessage_ComposerTitle",
        centerX,
        outerY + 18,
        white,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_TOP
    )
    drawShadowedText(
        "SP  " .. formatTapeTime(RealTime() - composerOpenedAt),
        "FF_MapMessage_ComposerLabel",
        right,
        outerY + 28,
        white,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_TOP
    )

    surface.SetDrawColor(dim)
    surface.DrawLine(left, outerY + 78, right, outerY + 78)

    drawShadowedText(
        "SOURCE  GLOBAL",
        "FF_MapMessage_ComposerLabel",
        left,
        outerY + 91,
        dim,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )
    drawShadowedText(
        "MAP  " .. string.upper(FFMapMessages.GetMapName()),
        "FF_MapMessage_ComposerLabel",
        right,
        outerY + 91,
        dim,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_TOP
    )

    local messageX = left
    local messageY = outerY + 128
    local messageWidth = right - left
    local messageHeight = 170

    surface.SetDrawColor(5, 7, 6, 230)
    surface.DrawRect(messageX, messageY, messageWidth, messageHeight)
    surface.SetDrawColor(white)
    surface.DrawOutlinedRect(messageX, messageY, messageWidth, messageHeight, 1)
    drawCornerBrackets(messageX + 7, messageY + 7, messageWidth - 14, messageHeight - 14, 18, dim)

    drawShadowedText(
        "MESSAGE / 001",
        "FF_MapMessage_ComposerLabel",
        messageX + 18,
        messageY + 13,
        dim,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )

    local value = IsValid(composerEntry) and composerEntry:GetValue() or ""
    local blinkingCursor = math.floor(RealTime() * 2) % 2 == 0 and "_" or " "
    local displayValue = value .. blinkingCursor
    local lines = wrapText(displayValue, "FF_MapMessage_ComposerEntry", messageWidth - 36)
    for index = 1, math.min(#lines, 4) do
        drawShadowedText(
            lines[index],
            "FF_MapMessage_ComposerEntry",
            messageX + 18,
            messageY + 47 + (index - 1) * 29,
            white,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_TOP
        )
    end

    local maximumLength = math.Clamp(tonumber(config().MaximumLength) or 100, 1, 100)
    drawShadowedText(
        string.format("%03d / %03d", characterCount(value), maximumLength),
        "FF_MapMessage_ComposerLabel",
        messageX + messageWidth - 16,
        messageY + messageHeight - 26,
        dim,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_TOP
    )

    surface.SetDrawColor(dim)
    surface.DrawLine(left, messageY + messageHeight + 16, right, messageY + messageHeight + 16)

    local labels = {
        "RECORD TAPE",
        "EJECT / CANCEL",
    }
    for index, label in ipairs(labels) do
        local x, y, actionWidth, actionHeight = getComposerActionRect(index)
        local selected = composerSelectedAction == index
        local fillColor = selected and white or Color(0, 0, 0, 220)
        local textColor = selected and Color(0, 0, 0, 255) or white

        surface.SetDrawColor(fillColor)
        surface.DrawRect(x, y, actionWidth, actionHeight)
        surface.SetDrawColor(selected and white or dim)
        surface.DrawOutlinedRect(x, y, actionWidth, actionHeight, 1)

        if index == 1 then
            drawFilledCircle(x + 24, y + math.floor(actionHeight * 0.5), 6, red, 24)
        else
            surface.SetDrawColor(textColor)
            surface.DrawRect(x + 18, y + math.floor(actionHeight * 0.5) - 5, 10, 10)
        end

        draw.SimpleText(
            label,
            "FF_MapMessage_ComposerButton",
            x + 42,
            y + math.floor(actionHeight * 0.5),
            textColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    drawShadowedText(
        "TAPE 001  /  SP",
        "FF_MapMessage_ComposerLabel",
        left,
        outerY + outerHeight - 34,
        faint,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )
    drawShadowedText(
        "GLOBAL MEMORY",
        "FF_MapMessage_ComposerLabel",
        right,
        outerY + outerHeight - 34,
        faint,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_TOP
    )
end

hook.Add(
    "FF_DrawBehindRealisticVHSEffect2",
    "FF_MapMessages_DrawComposer",
    drawComposerBehindVHS
)

hook.Add("FF_DrawBehindRealisticVHSEffect2", "FF_MapMessages_DrawTapePlayback", function(canvasWidth, canvasHeight)
    if IsValid(composer) then return end

    local white = Color(238, 240, 232, 255)
    local dim = Color(166, 178, 168, 240)
    local faint = Color(98, 110, 102, 220)
    local red = Color(226, 40, 34, 255)

    if focusedMessage and not readingMessage then
        local promptWidth = math.min(420, canvasWidth * 0.52)
        local promptHeight = 54
        local promptX = canvasWidth * 0.5 - promptWidth * 0.5
        local promptY = canvasHeight * 0.82

        surface.SetDrawColor(0, 0, 0, 235)
        surface.DrawRect(promptX, promptY, promptWidth, promptHeight)
        drawDoubleFrame(promptX, promptY, promptWidth, promptHeight, white, faint)
        drawShadowedText(
            "[ " .. useBindingLabel() .. " ]  PLAY TAPE",
            "FF_MapMessage_Prompt",
            canvasWidth * 0.5,
            promptY + math.floor(promptHeight * 0.5),
            white,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    if not readingMessage then return end

    local charactersPerSecond = math.max(8, tonumber(config().TypewriterCharactersPerSecond) or 28)
    local totalCharacters = textLength(readingMessage.body)
    local elapsed = math.max(0, RealTime() - readingStartedAt)
    local visibleCharacters = math.min(totalCharacters, math.floor(elapsed * charactersPerSecond))
    local visibleBody = textPrefix(readingMessage.body, visibleCharacters)
    local typewriterComplete = visibleCharacters >= totalCharacters
    if not typewriterComplete and math.floor(RealTime() * 3) % 2 == 0 then
        visibleBody = visibleBody .. "_"
    end

    local panelWidth = math.min(820, canvasWidth * 0.82)
    local lines = wrapText(visibleBody, "FF_MapMessage_Body", panelWidth - 86)
    local lineHeight = 42
    local bodyHeight = math.max(116, #lines * lineHeight + 34)
    local panelHeight = 176 + bodyHeight
    local panelX = canvasWidth * 0.5 - panelWidth * 0.5
    local panelY = math.Clamp(canvasHeight * 0.5 - panelHeight * 0.5, 42, canvasHeight - panelHeight - 42)

    surface.SetDrawColor(0, 0, 0, 242)
    surface.DrawRect(panelX, panelY, panelWidth, panelHeight)
    drawDoubleFrame(panelX, panelY, panelWidth, panelHeight, white, faint)

    local blink = math.floor(RealTime() * 2) % 2 == 0
    drawFilledCircle(
        panelX + 34,
        panelY + 39,
        8,
        Color(red.r, red.g, red.b, blink and 255 or 90),
        28
    )
    drawShadowedText(
        "PLAY",
        "FF_MapMessage_Title",
        panelX + 54,
        panelY + 23,
        white,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )
    drawShadowedText(
        "TAPE DECK",
        "FF_MapMessage_Title",
        panelX + panelWidth * 0.5,
        panelY + 23,
        white,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_TOP
    )
    drawShadowedText(
        "SP  " .. formatTapeTime(elapsed),
        "FF_MapMessage_Meta",
        panelX + panelWidth - 28,
        panelY + 27,
        white,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_TOP
    )

    surface.SetDrawColor(dim)
    surface.DrawLine(panelX + 24, panelY + 68, panelX + panelWidth - 24, panelY + 68)

    local timestamp = os.date("%Y.%m.%d  %H:%M", readingMessage.createdAt)
    drawShadowedText(
        "TAPE  " .. string.upper(string.sub(readingMessage.id, 1, 8)),
        "FF_MapMessage_Meta",
        panelX + 28,
        panelY + 80,
        dim,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )
    drawShadowedText(
        timestamp,
        "FF_MapMessage_Meta",
        panelX + panelWidth - 28,
        panelY + 80,
        dim,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_TOP
    )

    local bodyX = panelX + 28
    local bodyY = panelY + 108
    local bodyWidth = panelWidth - 56

    surface.SetDrawColor(4, 7, 5, 232)
    surface.DrawRect(bodyX, bodyY, bodyWidth, bodyHeight)
    surface.SetDrawColor(dim)
    surface.DrawOutlinedRect(bodyX, bodyY, bodyWidth, bodyHeight, 1)
    drawCornerBrackets(bodyX + 7, bodyY + 7, bodyWidth - 14, bodyHeight - 14, 18, faint)

    for index, line in ipairs(lines) do
        drawShadowedText(
            line,
            "FF_MapMessage_Body",
            bodyX + 22,
            bodyY + 18 + (index - 1) * lineHeight,
            white,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_TOP
        )
    end

    local footerY = panelY + panelHeight - 42
    surface.SetDrawColor(dim)
    surface.DrawLine(panelX + 24, footerY - 10, panelX + panelWidth - 24, footerY - 10)
    drawShadowedText(
        "GLOBAL / " .. string.upper(FFMapMessages.GetMapName()),
        "FF_MapMessage_Meta",
        panelX + 28,
        footerY,
        faint,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )
    drawShadowedText(
        "[ " .. useBindingLabel() .. " ]  EJECT",
        "FF_MapMessage_Meta",
        panelX + panelWidth - 28,
        footerY,
        white,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_TOP
    )
end)

hook.Add("InitPostEntity", "FF_MapMessages_ClientReady", function()
    timer.Simple(1, function()
        net.Start(NET_READY)
        net.SendToServer()
    end)
end)

local function cleanupClientModels()
    stopTapePlaybackSound()
    clearCassetteModels()
end

hook.Add("ShutDown", "FF_MapMessages_CleanupModels", cleanupClientModels)
hook.Add("PreCleanupMap", "FF_MapMessages_CleanupModels", cleanupClientModels)
