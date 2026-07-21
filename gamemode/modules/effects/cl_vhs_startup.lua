local config = FF_CONFIG.Player.SpawnIntro or {}
local NETWORK_MESSAGE = "FF_VHSStartup"
local READY_NETWORK_MESSAGE = "FF_VHSStartupReady"
local COMPLETE_NETWORK_MESSAGE = "FF_VHSStartupComplete"

local introStartedAt = nil
local introToken = nil
local completionSent = false
local introSound = nil

surface.CreateFont("FF_VHSStartupOSD", {
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

local function sequenceTimings()
    local initialBlack = nonNegative(config.InitialBlackDuration, 1.5)
    local blueDuration = nonNegative(config.BlueDuration, 1.5)
    local finalBlack = nonNegative(config.FinalBlackDuration, 1)
    local dashesDelay = math.Clamp(
        nonNegative(config.DashesDelay, 0.5),
        0,
        blueDuration
    )
    local playDelay = math.Clamp(
        nonNegative(config.PlayDelay, 1),
        dashesDelay,
        blueDuration
    )

    return initialBlack, blueDuration, finalBlack, dashesDelay, playDelay
end

local function totalSequenceDuration()
    local initialBlack, blueDuration, finalBlack = sequenceTimings()
    return initialBlack + blueDuration + finalBlack
end

local function spawnCompletionTime()
    local spawnBeforeEnd = nonNegative(config.SpawnBeforeEnd, 0.5)
    return math.max(totalSequenceDuration() - spawnBeforeEnd, 0)
end

local function stopIntroSound()
    if introSound then
        introSound:Stop()
        introSound = nil
    end
end

local function playIntroSound()
    stopIntroSound()

    local ply = LocalPlayer()
    local soundPath = tostring(config.Sound or "")
    if not IsValid(ply) or soundPath == "" then return end

    introSound = CreateSound(ply, soundPath)
    if introSound then
        introSound:PlayEx(1, 100)
    end
end

local function sendCompletion()
    if completionSent or not introToken then return end

    completionSent = true
    net.Start(COMPLETE_NETWORK_MESSAGE)
    net.WriteUInt(introToken, 16)
    net.SendToServer()
end

local function finishIntro()
    if not introStartedAt then return end

    introStartedAt = nil
    stopIntroSound()
end

local function startIntro()
    introToken = net.ReadUInt(16)
    completionSent = false

    if config.Enabled == false then
        sendCompletion()
        return
    end

    introStartedAt = RealTime()
    playIntroSound()
end

local function drawFilledPlayArrow(x, y, size, color)
    draw.NoTexture()
    surface.SetDrawColor(color)
    surface.DrawPoly({
        { x = x, y = y },
        { x = x, y = y + size },
        { x = x + size * 0.78, y = y + size * 0.5 },
    })
end

local function drawBlueScreen(width, height, blueElapsed, dashesDelay, playDelay)
    local blue = config.BlueColor or {}
    surface.SetDrawColor(
        math.Clamp(tonumber(blue.Red) or 8, 0, 255),
        math.Clamp(tonumber(blue.Green) or 42, 0, 255),
        math.Clamp(tonumber(blue.Blue) or 178, 0, 255),
        255
    )
    surface.DrawRect(0, 0, width, height)

    local textColor = Color(245, 245, 245, 255)
    local shadowColor = Color(0, 0, 0, 190)
    local left = 32
    local top = 27

    draw.SimpleText("SP", "FF_VHSStartupOSD", left + 3, height - 48 + 3, shadowColor)
    draw.SimpleText("SP", "FF_VHSStartupOSD", left, height - 48, textColor)

    if blueElapsed >= playDelay then
        draw.SimpleText("PLAY", "FF_VHSStartupOSD", left + 3, top + 3, shadowColor)
        draw.SimpleText("PLAY", "FF_VHSStartupOSD", left, top, textColor)

        surface.SetFont("FF_VHSStartupOSD")
        local playWidth = surface.GetTextSize("PLAY")
        drawFilledPlayArrow(left + playWidth + 12 + 3, top + 7 + 3, 18, shadowColor)
        drawFilledPlayArrow(left + playWidth + 12, top + 7, 18, textColor)
    elseif blueElapsed >= dashesDelay then
        draw.SimpleText("-----", "FF_VHSStartupOSD", left + 3, top + 3, shadowColor)
        draw.SimpleText("-----", "FF_VHSStartupOSD", left, top, textColor)
    end
end

hook.Add("FF_DrawVHSFrameOverlay", "FF_VHSStartupSequence", function(width, height)
    if not introStartedAt then return end

    local initialBlack, blueDuration, finalBlack, dashesDelay, playDelay = sequenceTimings()
    local elapsed = RealTime() - introStartedAt
    local totalDuration = initialBlack + blueDuration + finalBlack

    if elapsed >= totalDuration then return end

    if elapsed < initialBlack then
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, width, height)
        return
    end

    if elapsed < initialBlack + blueDuration then
        drawBlueScreen(width, height, elapsed - initialBlack, dashesDelay, playDelay)
        return
    end

    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(0, 0, width, height)
end)

hook.Add("Think", "FF_FinishVHSStartupSequence", function()
    if not introStartedAt then return end

    local elapsed = RealTime() - introStartedAt
    if elapsed >= spawnCompletionTime() then
        sendCompletion()
    end

    if elapsed < totalSequenceDuration() then return end
    finishIntro()
end)

local function signalReady()
    net.Start(READY_NETWORK_MESSAGE)
    net.SendToServer()
end

hook.Add("InitPostEntity", "FF_VHSStartupClientReady", signalReady)
hook.Add("OnReloaded", "FF_VHSStartupClientReloaded", signalReady)

net.Receive(NETWORK_MESSAGE, startIntro)

hook.Add("ShutDown", "FF_StopVHSStartupSound", stopIntroSound)