local hudConfig = FF_CONFIG.HUD or {}
local signalConfig = hudConfig.SignalIndicator or {}
local faultConfig = hudConfig.RecordingFaults or {}

local signalPulses = {}
local faults = {}
local faultCooldowns = {}
local displayedInterference = 0.045
local surroundActive = false
local lastUpdateAt = RealTime()
local nextContextCheck = 0
local darknessStartedAt
local lastZoomFraction
local lastHealth
local audioPeakReadyAt = 0
local signalLostActive = false

local function now()
    return RealTime()
end

local function clampDuration(duration, fallback)
    return math.Clamp(tonumber(duration) or fallback or 1, 0.1, 12)
end

function FF_PushCamcorderSignal(level, duration, sourceName)
    if signalConfig.Enabled == false then return end

    level = math.Clamp(tonumber(level) or 0, 0, 1)
    if level <= 0 then return end

    local current = now()
    signalPulses[#signalPulses + 1] = {
        level = level,
        startedAt = current,
        endsAt = current + clampDuration(duration, 1),
        sourceName = tostring(sourceName or "unknown"),
    }

    if #signalPulses > 32 then
        table.remove(signalPulses, 1)
    end
end

function FF_PushRecordingFault(text, duration, severity, priority)
    if faultConfig.Enabled == false then return end

    text = string.upper(string.Trim(tostring(text or "")))
    if text == "" then return end

    local current = now()
    local existing = faults[text]
    local endsAt = current + clampDuration(
        duration,
        tonumber(faultConfig.DefaultDuration) or 1.2
    )

    faults[text] = {
        text = text,
        startedAt = existing and math.min(existing.startedAt, current) or current,
        endsAt = math.max(existing and existing.endsAt or 0, endsAt),
        severity = math.Clamp(math.max(
            tonumber(severity) or 0.4,
            existing and existing.severity or 0
        ), 0, 1),
        priority = math.max(
            tonumber(priority) or 0,
            existing and existing.priority or 0
        ),
    }
end

local function pushContextFault(key, text, cooldown, duration, severity, priority)
    local current = now()
    if current < (faultCooldowns[key] or 0) then return end

    faultCooldowns[key] = current + math.max(tonumber(cooldown) or 1, 0.1)
    FF_PushRecordingFault(text, duration, severity, priority)
end

local function signalTarget(current)
    local baseline = 0.045 + math.sin(current * 0.31) * 0.012
    local target = math.Clamp(baseline, 0.025, 0.070)

    if surroundActive then
        target = math.max(target, 0.24)
    end

    for index = #signalPulses, 1, -1 do
        local pulse = signalPulses[index]
        if current >= pulse.endsAt then
            table.remove(signalPulses, index)
        else
            local duration = math.max(pulse.endsAt - pulse.startedAt, 0.001)
            local progress = math.Clamp((current - pulse.startedAt) / duration, 0, 1)
            target = math.max(target, pulse.level * (1 - progress * 0.35))
        end
    end

    local battery = FF_GetFlashlightBatteryFraction and FF_GetFlashlightBatteryFraction() or 1
    if battery <= 0.10 then
        target = math.max(target, 0.18 + (0.10 - battery) * 1.4)
    end

    return math.Clamp(target, 0, 1)
end

local function lightLevelAt(position)
    if not render.GetLightColor then return nil end

    local succeeded, color = pcall(render.GetLightColor, position)
    if not succeeded or not color then return nil end

    local red = tonumber(color.x or color.r) or 0
    local green = tonumber(color.y or color.g) or 0
    local blue = tonumber(color.z or color.b) or 0
    return red * 0.2126 + green * 0.7152 + blue * 0.0722
end

local function updateContextFaults(current)
    if current < nextContextCheck then return end
    nextContextCheck = current + 0.25

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        darknessStartedAt = nil
        lastZoomFraction = nil
        lastHealth = nil
        return
    end

    local battery = FF_GetFlashlightBatteryFraction and FF_GetFlashlightBatteryFraction() or 1
    if battery <= 0.015 then
        pushContextFault(
            "battery_empty",
            "LIGHT OFFLINE",
            faultConfig.BatteryCooldown or 8,
            1.6,
            0.85,
            82
        )
    elseif battery <= 0.20 then
        pushContextFault(
            "battery_low",
            "LOW BATTERY",
            faultConfig.BatteryCooldown or 8,
            1.4,
            0.58,
            62
        )
    end

    if ply:WaterLevel() >= 2 then
        pushContextFault(
            "water",
            "LENS WET",
            faultConfig.WaterCooldown or 7,
            1.4,
            0.58,
            58
        )
        FF_PushCamcorderSignal(0.24, 0.7, "water")
    end

    local flashlightActive = FF_IsFlashlightActive and FF_IsFlashlightActive() or false
    local lightLevel = lightLevelAt(ply:EyePos())
    local lowLightThreshold = math.max(tonumber(faultConfig.LowLightThreshold) or 0.055, 0)

    if not flashlightActive and lightLevel and lightLevel < lowLightThreshold then
        darknessStartedAt = darknessStartedAt or current
        if current - darknessStartedAt >= math.max(tonumber(faultConfig.LowLightDelay) or 1.5, 0) then
            pushContextFault(
                "low_light",
                "LOW LIGHT",
                faultConfig.LowLightCooldown or 8,
                1.3,
                0.38,
                32
            )
        end
    else
        darknessStartedAt = nil
    end

    local zoom = FF_GetCameraZoomFraction and FF_GetCameraZoomFraction() or 0
    if lastZoomFraction and math.abs(zoom - lastZoomFraction) >= 0.08 then
        pushContextFault(
            "autofocus",
            "AUTO FOCUS",
            faultConfig.ZoomCooldown or 4,
            0.75,
            0.22,
            18
        )
    end
    lastZoomFraction = zoom

    local health = math.max(ply:Health(), 0)
    if lastHealth and lastHealth - health >= 15 then
        pushContextFault(
            "damage_tracking",
            "TRACKING",
            faultConfig.ImpactCooldown or 3,
            0.9,
            0.72,
            70
        )
        FF_PushCamcorderSignal(0.42, 0.9, "damage")
    end
    lastHealth = health

    local audioLevel = FF_GetAudioVisualizerLevel and FF_GetAudioVisualizerLevel() or 0
    if audioLevel >= 0.90 and current >= audioPeakReadyAt then
        audioPeakReadyAt = current + 4
        FF_PushRecordingFault("AUDIO PEAK", 0.7, 0.45, 36)
    end
end

hook.Add("Think", "FF_CamcorderStatusUpdate", function()
    local current = now()
    local deltaTime = math.Clamp(current - lastUpdateAt, 0, 0.1)
    lastUpdateAt = current

    local target = signalTarget(current)
    local speed = target > displayedInterference and 8 or 1.15
    displayedInterference = math.Approach(displayedInterference, target, speed * deltaTime)

    local highThreshold = math.Clamp(
        tonumber(signalConfig.HighFlashThreshold) or 0.70,
        0,
        1
    )
    if displayedInterference >= highThreshold then
        if not signalLostActive and FF_PlayUISound then
            FF_PlayUISound("signal_lost")
        end
        signalLostActive = true
    elseif displayedInterference <= highThreshold * 0.72 then
        signalLostActive = false
    end

    updateContextFaults(current)
end)

hook.Add(
    "FF_SurroundAmbienceStarted",
    "FF_CamcorderStatusSurroundStarted",
    function(path, _, _, length)
        surroundActive = true
        FF_PushCamcorderSignal(0.34, math.min(tonumber(length) or 2, 4), path)
        FF_PushRecordingFault("AUDIO ANOMALY", 1.4, 0.52, 54)
    end
)

hook.Add(
    "FF_SurroundAmbienceStopped",
    "FF_CamcorderStatusSurroundStopped",
    function()
        surroundActive = false
    end
)

function FF_GetCamcorderInterference()
    if signalConfig.Enabled == false then return 0 end
    return math.Clamp(displayedInterference, 0, 1)
end

function FF_GetRecordingFault()
    if faultConfig.Enabled == false then return nil end

    local current = now()
    local selected

    for key, fault in pairs(faults) do
        if current >= fault.endsAt then
            faults[key] = nil
        elseif not selected
            or fault.priority > selected.priority
            or (fault.priority == selected.priority and fault.startedAt > selected.startedAt) then
            selected = fault
        end
    end

    if not selected then return nil end

    local fadeTime = math.max(tonumber(faultConfig.FadeTime) or 0.22, 0.01)
    local fadeIn = math.Clamp((current - selected.startedAt) / fadeTime, 0, 1)
    local fadeOut = math.Clamp((selected.endsAt - current) / fadeTime, 0, 1)
    local alpha = math.min(fadeIn, fadeOut)

    if selected.severity >= 0.75 then
        alpha = alpha * (0.68 + math.abs(math.sin(current * 22)) * 0.32)
    end

    return selected.text, selected.severity, math.Clamp(alpha, 0, 1)
end

hook.Add("OnReloaded", "FF_CamcorderStatusReset", function()
    signalPulses = {}
    faults = {}
    faultCooldowns = {}
    displayedInterference = 0.045
    surroundActive = false
    lastUpdateAt = now()
    nextContextCheck = 0
    darknessStartedAt = nil
    lastZoomFraction = nil
    lastHealth = nil
    audioPeakReadyAt = 0
    signalLostActive = false
end)
