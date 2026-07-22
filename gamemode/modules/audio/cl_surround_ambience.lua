local audioConfig = FF_CONFIG.Audio or {}
local config = audioConfig.SurroundAmbience or {}

if config.Enabled == false then return end

local ambienceDirectory = tostring(config.Directory or "surround_ambience")
local supportedExtensions = {
    mp3 = true,
    ogg = true,
    wav = true,
}

local tracks = {}
local shuffleBag = {}
local activeChannel
local activePath
local activePosition
local expectedEndAt
local loading = false
local loadGeneration = 0
local nextAmbienceAt = math.huge
local lastTrack
local wasAlive = false
local warnedMissingTracks = false
local nextUpdateAt = 0

local function currentTime()
    return RealTime()
end

local function randomRange(minimum, maximum)
    minimum = tonumber(minimum) or 0
    maximum = tonumber(maximum) or minimum

    if maximum < minimum then
        minimum, maximum = maximum, minimum
    end

    return math.Rand(minimum, maximum)
end

local function discoverTracks()
    tracks = {}
    shuffleBag = {}

    local files = file.Find("sound/" .. ambienceDirectory .. "/*", "GAME")
    table.sort(files)

    for _, name in ipairs(files) do
        local extension = string.lower(string.match(name, "%.([^%.]+)$") or "")
        if supportedExtensions[extension] then
            tracks[#tracks + 1] = ambienceDirectory .. "/" .. name
        end
    end

    warnedMissingTracks = false
end

local function refillShuffleBag()
    shuffleBag = {}

    for _, path in ipairs(tracks) do
        shuffleBag[#shuffleBag + 1] = path
    end

    for index = #shuffleBag, 2, -1 do
        local swapIndex = math.random(1, index)
        shuffleBag[index], shuffleBag[swapIndex] = shuffleBag[swapIndex], shuffleBag[index]
    end

    if #shuffleBag > 1 and shuffleBag[#shuffleBag] == lastTrack then
        shuffleBag[1], shuffleBag[#shuffleBag] = shuffleBag[#shuffleBag], shuffleBag[1]
    end
end

local function takeNextTrack()
    if #shuffleBag == 0 then
        refillShuffleBag()
    end

    local path = table.remove(shuffleBag)
    lastTrack = path
    return path
end

local function scheduleNext(initial)
    local minimum
    local maximum

    if initial then
        minimum = config.InitialMinimumDelay or 45
        maximum = config.InitialMaximumDelay or 120
    else
        minimum = config.MinimumDelay or 90
        maximum = config.MaximumDelay or 210
    end

    nextAmbienceAt = currentTime() + math.max(randomRange(minimum, maximum), 0)
end

local function choosePosition(ply)
    local minimumDistance = math.max(tonumber(config.MinimumDistance) or 520, 1)
    local maximumDistance = math.max(tonumber(config.MaximumDistance) or 1200, minimumDistance)
    local verticalVariation = math.max(tonumber(config.VerticalVariation) or 160, 0)
    local attempts = math.max(math.floor(tonumber(config.PositionAttempts) or 10), 1)
    local origin = ply:EyePos()
    local fallback

    for _ = 1, attempts do
        local yaw = randomRange(0, 360)
        local direction = Angle(0, yaw, 0):Forward()
        local distance = randomRange(minimumDistance, maximumDistance)
        local verticalOffset = randomRange(
            -math.min(verticalVariation, distance * 0.5),
            math.min(verticalVariation, distance * 0.5)
        )
        local horizontalDistance = math.sqrt(math.max(distance * distance - verticalOffset * verticalOffset, 0))
        local candidate = origin
            + direction * horizontalDistance
            + Vector(0, 0, verticalOffset)

        fallback = candidate

        local trace = util.TraceLine({
            start = origin,
            endpos = candidate,
            mask = MASK_SOLID_BRUSHONLY,
            filter = ply,
        })

        local position = candidate
        if trace.Hit then
            position = trace.HitPos - direction * 24
        end

        local actualDistance = origin:Distance(position)
        if actualDistance >= minimumDistance and actualDistance <= maximumDistance then
            return position
        end
    end

    return fallback or (origin + Vector(maximumDistance, 0, 0))
end

local function clearChannelState()
    activeChannel = nil
    activePath = nil
    activePosition = nil
    expectedEndAt = nil
end

local function stopAmbience(reason, emitStopHook)
    local stoppedPath = activePath
    local stoppedPosition = activePosition
    local wasActive = stoppedPath ~= nil

    loadGeneration = loadGeneration + 1
    loading = false

    if IsValid(activeChannel) then
        activeChannel:Stop()
    end

    clearChannelState()

    if wasActive and emitStopHook ~= false then
        hook.Run(
            "FF_SurroundAmbienceStopped",
            stoppedPath,
            stoppedPosition,
            tostring(reason or "stopped")
        )
    end

    local ply = LocalPlayer()
    if IsValid(ply) and ply:Alive() then
        scheduleNext(false)
    else
        nextAmbienceAt = math.huge
    end
end

local function scheduleRetry()
    nextAmbienceAt = currentTime() + math.max(tonumber(config.RetryDelay) or 20, 0)
end

local function startAmbience(ply)
    if loading or activePath ~= nil then return end

    if #tracks == 0 then
        discoverTracks()
    end

    if #tracks == 0 then
        if not warnedMissingTracks then
            warnedMissingTracks = true
            FF_DiscardOutput(
                "[Found Footage Surround Ambience] No local audio found under sound/"
                    .. ambienceDirectory
                    .. "/"
            )
        end

        scheduleRetry()
        return
    end

    local path = takeNextTrack()
    if not path then
        scheduleRetry()
        return
    end

    local position = choosePosition(ply)
    local volume = math.Clamp(
        randomRange(config.MinimumVolume or 0.08, config.MaximumVolume or 0.16),
        0,
        1
    )

    loadGeneration = loadGeneration + 1
    local generation = loadGeneration
    loading = true

    sound.PlayFile("sound/" .. path, "3d mono noplay noblock", function(channel, errorCode, errorText)
        if generation ~= loadGeneration then
            if IsValid(channel) then
                channel:Stop()
            end
            return
        end

        loading = false

        local currentPlayer = LocalPlayer()
        if not IsValid(currentPlayer) or not currentPlayer:Alive() then
            if IsValid(channel) then
                channel:Stop()
            end
            nextAmbienceAt = math.huge
            return
        end

        if not IsValid(channel) then
            FF_DiscardOutput(
                "[Found Footage Surround Ambience] Failed to load "
                    .. path
                    .. " ("
                    .. tostring(errorCode)
                    .. "): "
                    .. tostring(errorText)
            )
            scheduleRetry()
            return
        end

        activeChannel = channel
        activePath = path
        activePosition = position

        channel:EnableLooping(false)
        channel:SetPos(position)
        channel:Set3DFadeDistance(
            math.max(tonumber(config.FadeMinimumDistance) or 280, 1),
            math.max(tonumber(config.FadeMaximumDistance) or 1800, 1)
        )
        channel:SetVolume(volume)

        local length = math.max(tonumber(channel:GetLength()) or 0, 0)
        expectedEndAt = length > 0 and (currentTime() + length) or nil

        hook.Run("FF_SurroundAmbienceStarted", path, position, volume, length, channel)
        channel:Play()
    end)
end

hook.Add("Think", "FF_SurroundAmbiencePlayback", function()
    local now = currentTime()
    if now < nextUpdateAt then return end
    nextUpdateAt = now + math.max(tonumber(config.UpdateInterval) or 0.05, 0.01)

    local ply = LocalPlayer()
    local alive = IsValid(ply) and ply:Alive()

    if not alive then
        if activePath ~= nil or loading then
            stopAmbience("player_unavailable", true)
        end

        wasAlive = false
        nextAmbienceAt = math.huge
        return
    end

    if not wasAlive then
        wasAlive = true
        scheduleNext(true)
    end

    if activePath ~= nil then
        if not IsValid(activeChannel) then
            stopAmbience("channel_lost", true)
            return
        end

        local tooCloseDistance = math.max(tonumber(config.TooCloseDistance) or 260, 0)
        if activePosition and ply:EyePos():DistToSqr(activePosition) <= tooCloseDistance * tooCloseDistance then
            stopAmbience("player_too_close", true)
            return
        end

        local state = activeChannel:GetState()
        local stopped = GMOD_CHANNEL_STOPPED ~= nil and state == GMOD_CHANNEL_STOPPED
        local reachedExpectedEnd = expectedEndAt ~= nil and now >= expectedEndAt + 0.1

        if stopped or reachedExpectedEnd then
            stopAmbience("finished", true)
        end

        return
    end

    if loading then return end

    if now >= nextAmbienceAt then
        startAmbience(ply)
    end
end)

hook.Add("InitPostEntity", "FF_SurroundAmbienceDiscover", function()
    discoverTracks()
    wasAlive = false
    nextAmbienceAt = math.huge
end)

hook.Add("OnReloaded", "FF_SurroundAmbienceReset", function()
    stopAmbience("reload", true)
    discoverTracks()
    wasAlive = false
    nextAmbienceAt = math.huge
end)

hook.Add("ShutDown", "FF_SurroundAmbienceStop", function()
    stopAmbience("shutdown", false)
end)
