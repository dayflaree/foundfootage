local enabled = CreateClientConVar(
    "threateffects_death_enabled",
    "1",
    true,
    false,
    "Enable Threat Effects Death",
    0,
    1
)
local volumeScream = CreateClientConVar(
    "threateffects_death_volume_scream",
    "0.75",
    true,
    false,
    "Death impact volume",
    0,
    1
)
local volumeBackground = CreateClientConVar(
    "threateffects_death_volume_background",
    "0.75",
    true,
    false,
    "Death background volume",
    0,
    1
)

local config = FF_CONFIG.Player.DeathSequence or {}
local spawnIntroConfig = FF_CONFIG.Player.SpawnIntro or {}
local START_NETWORK_MESSAGE = "FF_DeathSequenceStart"
local AUDIO_COMPLETE_NETWORK_MESSAGE = "FF_DeathAudioComplete"
local END_CARD_NETWORK_MESSAGE = "FF_DeathEndCard"
local FINISH_NETWORK_MESSAGE = "FF_DeathSequenceFinish"

local activeToken = nil
local phase = nil
local audioStartedAt = nil
local audioEndsAt = nil
local audioLoadDeadline = nil
local audioCompletionSent = false
local backgroundChannel = nil
local hitChannel = nil

surface.CreateFont("FF_DeathEndCard", {
    font = FF_VHS_FONT_FAMILY or "VCR OSD Mono",
    extended = true,
    size = 31,
    weight = 500,
    antialias = false,
    shadow = false,
})

local function nonNegative(value, fallback)
    return math.max(tonumber(value) or fallback, 0)
end

local function stopChannel(channel)
    if IsValid(channel) then
        channel:Stop()
    end
end

local function stopDeathAudio()
    stopChannel(backgroundChannel)
    stopChannel(hitChannel)
    backgroundChannel = nil
    hitChannel = nil
end

local function resetSequence()
    stopDeathAudio()
    activeToken = nil
    phase = nil
    audioStartedAt = nil
    audioEndsAt = nil
    audioLoadDeadline = nil
    audioCompletionSent = false
end

local function soundFilePath(path)
    path = tostring(path or "")
    if path == "" then return "" end
    if string.StartWith(path, "sound/") then return path end
    return "sound/" .. path
end

local function playChannel(path, volume, token, callback)
    path = soundFilePath(path)
    if path == "" then
        if callback then callback(nil) end
        return
    end

    sound.PlayFile(path, "noplay", function(station)
        if token ~= activeToken or phase ~= "audio" then
            stopChannel(station)
            return
        end

        if not IsValid(station) then
            if callback then callback(nil) end
            return
        end

        station:SetVolume(math.Clamp(tonumber(volume) or 1, 0, 1))
        station:Play()

        if callback then callback(station) end
    end)
end

local function sendAudioComplete()
    if audioCompletionSent or not activeToken then return end

    audioCompletionSent = true
    net.Start(AUDIO_COMPLETE_NETWORK_MESSAGE)
    net.WriteUInt(activeToken, 16)
    net.SendToServer()
end

local function startDeathAudio(token)
    resetSequence()

    activeToken = token
    phase = "audio"
    audioStartedAt = RealTime()
    audioCompletionSent = false

    local minimumDuration = nonNegative(config.AudioMinimumDuration, 4.878662)
    local loadGrace = nonNegative(config.AudioLoadGrace, 1)
    audioLoadDeadline = audioStartedAt + minimumDuration + loadGrace

    local backgroundSound = tostring(
        config.BackgroundSound or "gui/threateffects/death/slideshow.wav"
    )
    playChannel(backgroundSound, volumeBackground:GetFloat(), token, function(station)
        backgroundChannel = station

        if IsValid(station) then
            local duration = nonNegative(station:GetLength(), minimumDuration)
            audioEndsAt = RealTime() + math.max(duration, minimumDuration)
        else
            audioEndsAt = audioStartedAt + minimumDuration
        end
    end)

    local hitCount = math.max(math.floor(tonumber(config.HitSoundCount) or 4), 1)
    local hitPattern = tostring(
        config.HitSoundPattern or "gui/threateffects/death/hit_%d.wav"
    )
    local hitPath = string.format(hitPattern, math.random(1, hitCount))
    playChannel(hitPath, volumeScream:GetFloat(), token, function(station)
        hitChannel = station
    end)
end

hook.Add("Think", "FF_DeathSequenceAudioCompletion", function()
    if phase ~= "audio" or audioCompletionSent then return end

    local now = RealTime()
    if audioEndsAt and now >= audioEndsAt then
        sendAudioComplete()
        return
    end

    if not audioEndsAt and audioLoadDeadline and now >= audioLoadDeadline then
        sendAudioComplete()
    end
end)

hook.Add("FF_DrawVHSFrameOverlay", "FF_DeathSequenceEndCard", function(width, height)
    if phase ~= "end_card" then return end

    local blue = spawnIntroConfig.BlueColor or {}
    surface.SetDrawColor(
        math.Clamp(tonumber(blue.Red) or 8, 0, 255),
        math.Clamp(tonumber(blue.Green) or 42, 0, 255),
        math.Clamp(tonumber(blue.Blue) or 178, 0, 255),
        255
    )
    surface.DrawRect(0, 0, width, height)

    local title = tostring(config.Title or "END OF RECORDING")
    local left = 32
    local top = 27
    local textColor = Color(245, 245, 245, 255)
    local shadowColor = Color(0, 0, 0, 190)

    draw.SimpleText(
        title,
        "FF_DeathEndCard",
        left + 3,
        top + 3,
        shadowColor
    )
    draw.SimpleText(
        title,
        "FF_DeathEndCard",
        left,
        top,
        textColor
    )
end)

hook.Add("HUDShouldDraw", "FF_DeathSequenceHideHUD", function()
    if phase == "end_card" then return false end
end)

net.Receive(START_NETWORK_MESSAGE, function()
    local token = net.ReadUInt(16)

    if enabled:GetBool() then
        startDeathAudio(token)
        return
    end

    resetSequence()
    activeToken = token
    phase = "audio"
    sendAudioComplete()
end)

net.Receive(END_CARD_NETWORK_MESSAGE, function()
    local token = net.ReadUInt(16)
    net.ReadFloat()

    if activeToken and token ~= activeToken then return end

    activeToken = token
    phase = "end_card"
    stopDeathAudio()
end)

net.Receive(FINISH_NETWORK_MESSAGE, function()
    local token = net.ReadUInt(16)
    if activeToken and token ~= activeToken then return end

    resetSequence()
end)

hook.Add("FF_VHSStartupBegan", "FF_EndDeathCardForVHSStartup", function()
    if phase == "end_card" then
        resetSequence()
    end
end)

hook.Add("ShutDown", "FF_StopDeathSequenceAudio", resetSequence)
