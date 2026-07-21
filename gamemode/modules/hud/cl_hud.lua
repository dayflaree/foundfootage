local hudConfig = FF_CONFIG.HUD or {}
local staminaConfig = FF_CONFIG.Movement.Stamina or {}
local resourceConfig = hudConfig.ResourceBars or {}
local zoomConfig = hudConfig.ZoomBar or {}
local audioVisualizerConfig = hudConfig.AudioVisualizer or {}
local flashlightBatteryConfig = hudConfig.FlashlightBattery or {}
local signalIndicatorConfig = hudConfig.SignalIndicator or {}
local recordingFaultConfig = hudConfig.RecordingFaults or {}
local interactionConfig = hudConfig.InteractionIndicator or {}

local STAMINA_NETWORK_KEY = "FF_Stamina"
local STAMINA_EXHAUSTED_NETWORK_KEY = "FF_StaminaExhausted"

local HUD_WHITE = Color(255, 255, 255, 255)
local HUD_BLACK = Color(0, 0, 0, 150)

local DOOR_CLASSES = {
    func_door = true,
    func_door_rotating = true,
    prop_door_rotating = true,
}

local BRUSH_DOOR_CLASSES = {
    func_door = true,
    func_door_rotating = true,
}

local DOOR_SPAWNFLAG_USE_OPENS = 256
local DOOR_SPAWNFLAG_TOUCH_OPENS = 1024

local BUTTON_CLASSES = {
    func_button = true,
    func_button_timed = true,
    func_rot_button = true,
    gmod_button = true,
    momentary_rot_button = true,
}

local TRACE_HULL_MINIMUM = Vector(-2, -2, -2)
local TRACE_HULL_MAXIMUM = Vector(2, 2, 2)

local displayedHealth
local displayedStamina
local nextInteractionTrace = 0
local interactionKind
local interactionLocked = false

local function drawOutline(x, y, width, height, thickness, alpha)
    thickness = math.max(math.floor(thickness or 1), 1)

    surface.SetDrawColor(255, 255, 255, math.Clamp(alpha or 255, 0, 255))
    for offset = 0, thickness - 1 do
        surface.DrawOutlinedRect(
            x + offset,
            y + offset,
            math.max(width - offset * 2, 1),
            math.max(height - offset * 2, 1)
        )
    end
end

local function drawDirectionalTriangle(centerX, centerY, size, direction, alpha)
    size = math.max(math.floor(size or 5), 2)
    local half = math.floor(size * 0.5)
    local points

    if direction == "left" then
        points = {
            { x = centerX - half, y = centerY },
            { x = centerX + half, y = centerY - size },
            { x = centerX + half, y = centerY + size },
        }
    elseif direction == "right" then
        points = {
            { x = centerX + half, y = centerY },
            { x = centerX - half, y = centerY - size },
            { x = centerX - half, y = centerY + size },
        }
    elseif direction == "up" then
        points = {
            { x = centerX, y = centerY - half },
            { x = centerX - size, y = centerY + half },
            { x = centerX + size, y = centerY + half },
        }
    else
        points = {
            { x = centerX, y = centerY + half },
            { x = centerX - size, y = centerY - half },
            { x = centerX + size, y = centerY - half },
        }
    end

    draw.NoTexture()
    surface.SetDrawColor(255, 255, 255, math.Clamp(alpha or 255, 0, 255))
    surface.DrawPoly(points)
end

local function lowResourceAlpha(fraction, threshold)
    if fraction > threshold then return 255 end

    local speed = math.max(tonumber(resourceConfig.LowFlashSpeed) or 2.4, 0.01)
    local minimumAlpha = math.Clamp(
        tonumber(resourceConfig.LowFlashMinimumAlpha) or 0.18,
        0,
        1
    )
    local pulse = (math.sin(RealTime() * speed * math.pi * 2) + 1) * 0.5

    return math.floor(Lerp(pulse, minimumAlpha * 255, 255))
end

local function drawSegmentedResourceBar(label, x, y, width, height, fraction, threshold)
    fraction = math.Clamp(fraction, 0, 1)

    local alpha = lowResourceAlpha(fraction, threshold)
    local padding = math.max(math.floor(tonumber(resourceConfig.Padding) or 3), 1)
    local gap = math.max(math.floor(tonumber(resourceConfig.DashGap) or 2), 1)
    local count = math.max(math.floor(tonumber(resourceConfig.DashCount) or 20), 1)
    local outlineThickness = math.max(
        math.floor(tonumber(resourceConfig.OutlineThickness) or 1),
        1
    )

    surface.SetDrawColor(HUD_BLACK.r, HUD_BLACK.g, HUD_BLACK.b, math.floor(alpha * 0.48))
    surface.DrawRect(x, y, width, height)
    drawOutline(x, y, width, height, outlineThickness, alpha)

    local innerX = x + padding
    local innerY = y + padding
    local innerWidth = math.max(width - padding * 2, 1)
    local innerHeight = math.max(height - padding * 2, 1)
    local dashWidth = math.floor((innerWidth - gap * (count - 1)) / count)

    while count > 1 and dashWidth < 1 do
        count = count - 1
        dashWidth = math.floor((innerWidth - gap * (count - 1)) / count)
    end

    dashWidth = math.max(dashWidth, 1)
    local usedWidth = dashWidth * count + gap * (count - 1)
    innerX = innerX + math.floor((innerWidth - usedWidth) * 0.5)

    local filledCount = fraction <= 0 and 0 or math.ceil(fraction * count)
    surface.SetDrawColor(255, 255, 255, alpha)

    for index = 1, filledCount do
        local dashX = innerX + (index - 1) * (dashWidth + gap)
        surface.DrawRect(dashX, innerY, dashWidth, innerHeight)
    end

    draw.SimpleText(
        label,
        "FF_VHSCamcorderHUD",
        x - 6,
        y + math.floor(height * 0.5),
        Color(255, 255, 255, alpha),
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )
end

local function drawZoomBar(canvasWidth)
    if zoomConfig.Enabled == false then return end

    local width = math.max(math.floor(tonumber(zoomConfig.Width) or 112), 24)
    local height = math.max(math.floor(tonumber(zoomConfig.Height) or 10), 6)
    local top = math.max(math.floor(tonumber(zoomConfig.TopMargin) or 12), 0)
    local markerSize = math.Clamp(
        math.floor(tonumber(zoomConfig.MarkerSize) or 7),
        3,
        math.max(height - 2, 3)
    )
    local labelGap = math.max(math.floor(tonumber(zoomConfig.LabelGap) or 7), 0)
    local guideCount = math.max(math.floor(tonumber(zoomConfig.GuideCount) or 3), 0)
    local outlineThickness = math.max(
        math.floor(tonumber(zoomConfig.OutlineThickness) or 1),
        1
    )
    local x = math.floor((canvasWidth - width) * 0.5)
    local y = top
    local zoomFraction = FF_GetCameraZoomFraction and FF_GetCameraZoomFraction() or 0
    zoomFraction = math.Clamp(tonumber(zoomFraction) or 0, 0, 1)

    surface.SetDrawColor(HUD_BLACK.r, HUD_BLACK.g, HUD_BLACK.b, 115)
    surface.DrawRect(x, y, width, height)
    drawOutline(x, y, width, height, outlineThickness, 190)

    if guideCount > 0 then
        surface.SetDrawColor(255, 255, 255, 52)
        for index = 1, guideCount do
            local fraction = index / (guideCount + 1)
            local guideX = math.floor(x + fraction * width)
            surface.DrawRect(guideX, y + 1, 1, math.max(height - 2, 1))
        end
    end

    local travelStart = x + 2
    local travelEnd = x + width - markerSize - 2
    local markerX = math.floor(Lerp(zoomFraction, travelStart, travelEnd) + 0.5)
    local markerY = y + math.floor((height - markerSize) * 0.5)

    surface.SetDrawColor(0, 0, 0, 205)
    surface.DrawRect(markerX - 1, markerY - 1, markerSize + 2, markerSize + 2)
    surface.SetDrawColor(HUD_WHITE)
    surface.DrawRect(markerX, markerY, markerSize, markerSize)

    draw.SimpleText(
        "W",
        "FF_VHSCamcorderHUD",
        x - labelGap,
        y + math.floor(height * 0.5),
        Color(255, 255, 255, 210),
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )
    draw.SimpleText(
        "T",
        "FF_VHSCamcorderHUD",
        x + width + labelGap,
        y + math.floor(height * 0.5),
        Color(255, 255, 255, 210),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
end

local function drawAudioVisualizer(canvasWidth, canvasHeight)
    if audioVisualizerConfig.Enabled == false then return end

    local width = math.max(math.floor(tonumber(audioVisualizerConfig.Width) or 14), 8)
    local height = math.max(math.floor(tonumber(audioVisualizerConfig.Height) or 112), 32)
    local marginX = math.max(math.floor(tonumber(audioVisualizerConfig.MarginX) or 22), 0)
    local marginY = math.max(math.floor(tonumber(audioVisualizerConfig.MarginY) or 22), 0)
    local padding = math.max(math.floor(tonumber(audioVisualizerConfig.Padding) or 3), 1)
    local gap = math.max(math.floor(tonumber(audioVisualizerConfig.DashGap) or 2), 1)
    local count = math.max(math.floor(tonumber(audioVisualizerConfig.DashCount) or 18), 1)
    local outlineThickness = math.max(
        math.floor(tonumber(audioVisualizerConfig.OutlineThickness) or 1),
        1
    )
    local x = math.floor(canvasWidth - marginX - width)
    local y = math.floor(canvasHeight - marginY - height)
    local level = FF_GetAudioVisualizerLevel and FF_GetAudioVisualizerLevel() or 0
    level = math.Clamp(tonumber(level) or 0, 0, 1)

    surface.SetDrawColor(HUD_BLACK.r, HUD_BLACK.g, HUD_BLACK.b, 92)
    surface.DrawRect(x, y, width, height)
    drawOutline(x, y, width, height, outlineThickness, 220)

    local innerX = x + padding
    local innerY = y + padding
    local innerWidth = math.max(width - padding * 2, 1)
    local innerHeight = math.max(height - padding * 2, 1)
    local dashHeight = math.floor((innerHeight - gap * (count - 1)) / count)

    while count > 1 and dashHeight < 1 do
        count = count - 1
        dashHeight = math.floor((innerHeight - gap * (count - 1)) / count)
    end

    dashHeight = math.max(dashHeight, 1)
    local usedHeight = dashHeight * count + gap * (count - 1)
    innerY = innerY + math.floor((innerHeight - usedHeight) * 0.5)

    local filledCount = level <= 0 and 0 or math.ceil(level * count)
    surface.SetDrawColor(HUD_WHITE)

    for index = 1, filledCount do
        local dashY = innerY + usedHeight - dashHeight - (index - 1) * (dashHeight + gap)
        surface.DrawRect(innerX, dashY, innerWidth, dashHeight)
    end

    local label = tostring(audioVisualizerConfig.Label or "A")
    if label ~= "" then
        draw.SimpleText(
            label,
            "FF_VHSCamcorderHUD",
            x + math.floor(width * 0.5),
            y - 4,
            Color(255, 255, 255, 220),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_BOTTOM
        )
    end

    if audioVisualizerConfig.DirectionalIndicators ~= false then
        local directionRight, directionForward, directionStrength = 0, 0, 0
        if FF_GetAudioVisualizerDirection then
            directionRight, directionForward, directionStrength = FF_GetAudioVisualizerDirection()
        end

        directionRight = math.Clamp(tonumber(directionRight) or 0, -1, 1)
        directionForward = math.Clamp(tonumber(directionForward) or 0, -1, 1)
        directionStrength = math.Clamp(tonumber(directionStrength) or 0, 0, 1)

        local indicatorSize = math.max(
            math.floor(tonumber(audioVisualizerConfig.DirectionIndicatorSize) or 5),
            2
        )
        local indicatorGap = math.max(
            math.floor(tonumber(audioVisualizerConfig.DirectionIndicatorGap) or 8),
            2
        )
        local centerX = x + math.floor(width * 0.5)
        local centerY = y + math.floor(height * 0.5)
        local baseAlpha = 28
        local function indicatorAlpha(component)
            return math.floor(Lerp(
                math.Clamp(component * directionStrength, 0, 1),
                baseAlpha,
                255
            ))
        end

        drawDirectionalTriangle(
            x - indicatorGap - indicatorSize,
            centerY,
            indicatorSize,
            "left",
            indicatorAlpha(math.max(-directionRight, 0))
        )
        drawDirectionalTriangle(
            x + width + indicatorGap + indicatorSize,
            centerY,
            indicatorSize,
            "right",
            indicatorAlpha(math.max(directionRight, 0))
        )
        drawDirectionalTriangle(
            centerX,
            y - indicatorGap - indicatorSize,
            indicatorSize,
            "up",
            indicatorAlpha(math.max(directionForward, 0))
        )
        drawDirectionalTriangle(
            centerX,
            y + height + indicatorGap + indicatorSize,
            indicatorSize,
            "down",
            indicatorAlpha(math.max(-directionForward, 0))
        )
    end
end

local function drawFlashlightBattery(canvasWidth)
    if flashlightBatteryConfig.Enabled == false then return end

    local width = math.max(math.floor(tonumber(flashlightBatteryConfig.Width) or 42), 18)
    local height = math.max(math.floor(tonumber(flashlightBatteryConfig.Height) or 14), 8)
    local marginX = math.max(math.floor(tonumber(flashlightBatteryConfig.MarginX) or 22), 0)
    local marginY = math.max(math.floor(tonumber(flashlightBatteryConfig.MarginY) or 22), 0)

    local padding = math.max(math.floor(tonumber(flashlightBatteryConfig.Padding) or 3), 1)
    local gap = math.max(math.floor(tonumber(flashlightBatteryConfig.SegmentGap) or 2), 1)
    local count = math.max(math.floor(tonumber(flashlightBatteryConfig.SegmentCount) or 5), 1)
    local outlineThickness = math.max(
        math.floor(tonumber(flashlightBatteryConfig.OutlineThickness) or 1),
        1
    )
    local x = math.floor(canvasWidth - marginX - width)
    local y = marginY
    local fraction = FF_GetFlashlightBatteryFraction and FF_GetFlashlightBatteryFraction() or 1
    fraction = math.Clamp(tonumber(fraction) or 0, 0, 1)

    local alpha = 255
    local lowThreshold = math.Clamp(
        tonumber(flashlightBatteryConfig.LowThreshold) or 0.20,
        0,
        1
    )
    if fraction <= lowThreshold then
        local speed = math.max(tonumber(flashlightBatteryConfig.FlashSpeed) or 2.4, 0.01)
        local minimumAlpha = math.Clamp(
            tonumber(flashlightBatteryConfig.FlashMinimumAlpha) or 0.20,
            0,
            1
        )
        local pulse = (math.sin(RealTime() * speed * math.pi * 2) + 1) * 0.5
        alpha = math.floor(Lerp(pulse, minimumAlpha * 255, 255))
    end

    surface.SetDrawColor(HUD_BLACK.r, HUD_BLACK.g, HUD_BLACK.b, math.floor(alpha * 0.48))
    surface.DrawRect(x, y, width, height)
    drawOutline(x, y, width, height, outlineThickness, alpha)


    local innerX = x + padding
    local innerY = y + padding
    local innerWidth = math.max(width - padding * 2, 1)
    local innerHeight = math.max(height - padding * 2, 1)
    local segmentWidth = math.floor((innerWidth - gap * (count - 1)) / count)

    while count > 1 and segmentWidth < 1 do
        count = count - 1
        segmentWidth = math.floor((innerWidth - gap * (count - 1)) / count)
    end

    segmentWidth = math.max(segmentWidth, 1)
    local filledCount = fraction <= 0 and 0 or math.ceil(fraction * count)
    surface.SetDrawColor(255, 255, 255, alpha)
    for index = 1, filledCount do
        local segmentX = innerX + (index - 1) * (segmentWidth + gap)
        surface.DrawRect(segmentX, innerY, segmentWidth, innerHeight)
    end

    draw.SimpleText(
        "BAT",
        "FF_VHSCamcorderHUD",
        x - 6,
        y + math.floor(height * 0.5),
        Color(255, 255, 255, alpha),
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )
end

local function drawSignalIndicator(canvasWidth)
    if signalIndicatorConfig.Enabled == false then return end

    local width = math.max(math.floor(tonumber(signalIndicatorConfig.Width) or 42), 18)
    local height = math.max(math.floor(tonumber(signalIndicatorConfig.Height) or 14), 8)
    local marginX = math.max(math.floor(tonumber(signalIndicatorConfig.MarginX) or 22), 0)
    local y = math.max(math.floor(tonumber(signalIndicatorConfig.Top) or 46), 0)
    local padding = math.max(math.floor(tonumber(signalIndicatorConfig.Padding) or 3), 1)
    local gap = math.max(math.floor(tonumber(signalIndicatorConfig.BarGap) or 2), 1)
    local count = math.max(math.floor(tonumber(signalIndicatorConfig.BarCount) or 4), 1)
    local outlineThickness = math.max(
        math.floor(tonumber(signalIndicatorConfig.OutlineThickness) or 1),
        1
    )
    local x = math.floor(canvasWidth - marginX - width)
    local interference = FF_GetCamcorderInterference and FF_GetCamcorderInterference() or 0
    interference = math.Clamp(tonumber(interference) or 0, 0, 1)

    local alpha = 220
    local highThreshold = math.Clamp(
        tonumber(signalIndicatorConfig.HighFlashThreshold) or 0.70,
        0,
        1
    )
    if interference >= highThreshold then
        alpha = math.floor(150 + math.abs(math.sin(RealTime() * 18)) * 105)
    end

    surface.SetDrawColor(HUD_BLACK.r, HUD_BLACK.g, HUD_BLACK.b, math.floor(alpha * 0.42))
    surface.DrawRect(x, y, width, height)
    drawOutline(x, y, width, height, outlineThickness, alpha)

    local innerX = x + padding
    local innerY = y + padding
    local innerWidth = math.max(width - padding * 2, 1)
    local innerHeight = math.max(height - padding * 2, 1)
    local barWidth = math.floor((innerWidth - gap * (count - 1)) / count)
    barWidth = math.max(barWidth, 1)
    local filledCount = interference <= 0 and 0 or math.ceil(interference * count)

    surface.SetDrawColor(255, 255, 255, alpha)
    for index = 1, filledCount do
        local barHeight = math.max(math.floor(innerHeight * (index / count)), 1)
        local barX = innerX + (index - 1) * (barWidth + gap)
        surface.DrawRect(barX, innerY + innerHeight - barHeight, barWidth, barHeight)
    end

    draw.SimpleText(
        tostring(signalIndicatorConfig.Label or "SIG"),
        "FF_VHSCamcorderHUD",
        x - 6,
        y + math.floor(height * 0.5),
        Color(255, 255, 255, alpha),
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )
end

local function drawRecordingFault(canvasWidth)
    if recordingFaultConfig.Enabled == false or not FF_GetRecordingFault then return end

    local text, severity, alphaFraction = FF_GetRecordingFault()
    if not text then return end

    severity = math.Clamp(tonumber(severity) or 0, 0, 1)
    alphaFraction = math.Clamp(tonumber(alphaFraction) or 0, 0, 1)
    if alphaFraction <= 0 then return end

    local alpha = math.floor(alphaFraction * 255)
    local y = math.max(math.floor(tonumber(recordingFaultConfig.Top) or 34), 0)
    local jitter = severity >= 0.75 and math.floor(math.sin(RealTime() * 39) * 2) or 0
    local displayText = "[ " .. tostring(text) .. " ]"

    surface.SetFont("FF_VHSCamcorderHUD")
    local textWidth, textHeight = surface.GetTextSize(displayText)
    local x = math.floor((canvasWidth - textWidth) * 0.5) + jitter

    surface.SetDrawColor(0, 0, 0, math.floor(alpha * 0.46))
    surface.DrawRect(x - 4, y - 1, textWidth + 8, textHeight + 2)
    draw.SimpleText(
        displayText,
        "FF_VHSCamcorderHUD",
        x,
        y,
        Color(255, 255, 255, alpha),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )
end

local function internalBoolean(entity, name)
    if not IsValid(entity) or not entity.GetInternalVariable then return false end

    local succeeded, value = pcall(entity.GetInternalVariable, entity, name)
    if not succeeded then return false end

    return value == true or tonumber(value) == 1
end

local function doorSpawnFlags(entity)
    if not IsValid(entity) then return 0 end

    if entity.GetSpawnFlags then
        local succeeded, value = pcall(entity.GetSpawnFlags, entity)
        if succeeded and tonumber(value) then
            return math.floor(tonumber(value))
        end
    end

    if entity.GetInternalVariable then
        local succeeded, value = pcall(entity.GetInternalVariable, entity, "m_spawnflags")
        if succeeded and tonumber(value) then
            return math.floor(tonumber(value))
        end
    end

    if entity.GetKeyValues then
        local succeeded, values = pcall(entity.GetKeyValues, entity)
        if succeeded and istable(values) and tonumber(values.spawnflags) then
            return math.floor(tonumber(values.spawnflags))
        end
    end

    return 0
end

local function isDoorLocked(entity)
    if not IsValid(entity) then return false end

    if entity:GetNW2Bool("FF_Locked", false)
        or entity:GetNW2Bool("FF_DoorUnavailable", false)
        or entity:GetNWBool("locked", false) then
        return true
    end

    if internalBoolean(entity, "m_bLocked")
        or internalBoolean(entity, "m_bDisabled") then
        return true
    end

    local class = entity:GetClass()
    if BRUSH_DOOR_CLASSES[class] then
        local spawnFlags = doorSpawnFlags(entity)
        local opensFromUse = bit.band(spawnFlags, DOOR_SPAWNFLAG_USE_OPENS) ~= 0
        local opensFromTouch = bit.band(spawnFlags, DOOR_SPAWNFLAG_TOUCH_OPENS) ~= 0

        if not opensFromUse and not opensFromTouch then
            return true
        end
    end

    return false
end

local function classifyInteractionEntity(entity)
    for _ = 1, 4 do
        if not IsValid(entity) then return nil, false end

        local class = entity:GetClass()
        if BUTTON_CLASSES[class] then
            return "button", false
        end

        if DOOR_CLASSES[class] then
            return "door", isDoorLocked(entity)
        end

        entity = entity:GetParent()
    end

    return nil, false
end

local function traceInteraction(ply)
    local now = CurTime()
    if now < nextInteractionTrace then return end

    nextInteractionTrace = now + math.max(
        tonumber(interactionConfig.TraceInterval) or 0.05,
        0.01
    )

    interactionKind = nil
    interactionLocked = false

    if interactionConfig.Enabled == false or not ply:Alive() then return end

    local startPosition = ply:EyePos()
    local endPosition = startPosition + ply:GetAimVector() * math.max(
        tonumber(interactionConfig.TraceDistance) or 96,
        1
    )

    local traceData = {
        start = startPosition,
        endpos = endPosition,
        filter = ply,
        mask = MASK_SOLID,
    }

    local traceResult = util.TraceLine(traceData)
    local tracedEntity = traceResult and traceResult.Entity or nil
    interactionKind, interactionLocked = classifyInteractionEntity(tracedEntity)

    if interactionKind then return end

    traceData.mins = TRACE_HULL_MINIMUM
    traceData.maxs = TRACE_HULL_MAXIMUM
    traceResult = util.TraceHull(traceData)
    tracedEntity = traceResult and traceResult.Entity or nil
    interactionKind, interactionLocked = classifyInteractionEntity(tracedEntity)
end

local function setIndicatorColor(alpha)
    surface.SetDrawColor(255, 255, 255, alpha)
end

local function drawButtonIndicator(centerX, centerY, size, thickness, alpha, pressed)
    local halfSize = math.floor(size * 0.5)
    local armLength = math.max(thickness * 2, math.floor(size * 0.28))
    local left = centerX - halfSize
    local top = centerY - halfSize
    local right = centerX + halfSize
    local bottom = centerY + halfSize

    setIndicatorColor(alpha)

    surface.DrawRect(left, top, armLength, thickness)
    surface.DrawRect(left, top, thickness, armLength)
    surface.DrawRect(right - armLength, top, armLength, thickness)
    surface.DrawRect(right - thickness, top, thickness, armLength)
    surface.DrawRect(left, bottom - thickness, armLength, thickness)
    surface.DrawRect(left, bottom - armLength, thickness, armLength)
    surface.DrawRect(right - armLength, bottom - thickness, armLength, thickness)
    surface.DrawRect(right - thickness, bottom - armLength, thickness, armLength)

    local dotSize = pressed and thickness * 3 or thickness * 2
    surface.DrawRect(
        centerX - math.floor(dotSize * 0.5),
        centerY - math.floor(dotSize * 0.5),
        dotSize,
        dotSize
    )
end

local function drawDoorIndicator(centerX, centerY, size, thickness, alpha, locked)
    local height = size
    local width = math.max(thickness * 4, math.floor(size * 0.62))
    local left = centerX - math.floor(width * 0.5)
    local top = centerY - math.floor(height * 0.5)

    setIndicatorColor(alpha)

    surface.DrawRect(left, top, width, thickness)
    surface.DrawRect(left, top + height - thickness, width, thickness)
    surface.DrawRect(left, top, thickness, height)
    surface.DrawRect(left + width - thickness, top, thickness, height)

    local knobSize = math.max(2, thickness)
    surface.DrawRect(
        left + width - (thickness * 3),
        centerY - math.floor(knobSize * 0.5),
        knobSize,
        knobSize
    )

    if locked then
        local slashLength = math.max(1, height - (thickness * 2))
        for step = 0, slashLength, thickness do
            local fraction = step / slashLength
            surface.DrawRect(
                math.floor(left + thickness + fraction * (width - thickness * 3)),
                top + thickness + step,
                thickness,
                thickness
            )
        end
    end
end

local function drawInteractionIndicator(ply, canvasWidth, canvasHeight)
    traceInteraction(ply)
    if not interactionKind then return end

    local size = math.max(12, math.floor(tonumber(interactionConfig.Size) or 24))
    local thickness = math.Clamp(
        math.floor(tonumber(interactionConfig.Thickness) or 2),
        1,
        math.floor(size * 0.25)
    )
    local pulseSpeed = math.max(tonumber(interactionConfig.PulseSpeed) or 1.35, 0)
    local pulse = (math.sin(CurTime() * pulseSpeed * math.pi * 2) + 1) * 0.5
    local alpha = math.floor(195 + pulse * 60)
    local centerX = math.floor(
        canvasWidth * 0.5 + (tonumber(interactionConfig.OffsetX) or 0)
    )
    local centerY = math.floor(
        canvasHeight * 0.5 + (tonumber(interactionConfig.OffsetY) or 0)
    )
    local pressed = ply:KeyDown(IN_USE)

    if interactionKind == "button" then
        drawButtonIndicator(centerX, centerY, size, thickness, alpha, pressed)
    elseif interactionKind == "door" then
        drawDoorIndicator(centerX, centerY, size, thickness, alpha, interactionLocked)
    end
end

local function drawFoundFootageHUD(canvasWidth, canvasHeight)
    if hudConfig.Enabled == false then return end
    if FF_IsVHSPauseMenuOpen and FF_IsVHSPauseMenuOpen() then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local maximumHealth = math.max(ply:GetMaxHealth(), 1)
    local healthTarget = math.Clamp(ply:Health() / maximumHealth, 0, 1)

    local maximumStamina = math.max(tonumber(staminaConfig.Maximum) or 100, 1)
    local staminaTarget = math.Clamp(
        ply:GetNW2Float(STAMINA_NETWORK_KEY, maximumStamina) / maximumStamina,
        0,
        1
    )

    displayedHealth = displayedHealth or healthTarget
    displayedStamina = displayedStamina or staminaTarget

    local smoothing = math.Clamp(FrameTime() * 12, 0, 1)
    displayedHealth = Lerp(smoothing, displayedHealth, healthTarget)
    displayedStamina = Lerp(smoothing, displayedStamina, staminaTarget)

    -- Lerp approaches zero asymptotically. Snap depleted resources to zero so
    -- the final ceil-based segment cannot remain visible indefinitely.
    if healthTarget <= 0 then
        displayedHealth = 0
    end
    if staminaTarget <= 0 then
        displayedStamina = 0
    end

    canvasWidth = tonumber(canvasWidth) or 720
    canvasHeight = tonumber(canvasHeight) or 576

    -- Coordinates are expressed in the VHS renderer's 720x576 working frame.
    -- RealisticVHSEffect2 processes this layer before its OSD and final overlays.
    local x = math.floor(tonumber(resourceConfig.MarginX) or 22)
    local y = math.floor(tonumber(resourceConfig.MarginY) or 22)
    local width = math.max(48, math.floor(tonumber(resourceConfig.Width) or 132))
    local height = math.max(8, math.floor(tonumber(resourceConfig.Height) or 14))
    local rowSpacing = math.max(
        height + 4,
        math.floor(tonumber(resourceConfig.RowSpacing) or 24)
    )

    drawSegmentedResourceBar(
        "H",
        x,
        y,
        width,
        height,
        displayedHealth,
        math.Clamp(tonumber(resourceConfig.LowHealthThreshold) or 0.25, 0, 1)
    )
    drawSegmentedResourceBar(
        "S",
        x,
        y + rowSpacing,
        width,
        height,
        displayedStamina,
        math.Clamp(tonumber(resourceConfig.LowStaminaThreshold) or 0.20, 0, 1)
    )
    drawZoomBar(canvasWidth)
    drawRecordingFault(canvasWidth)
    drawFlashlightBattery(canvasWidth)
    drawSignalIndicator(canvasWidth)
    drawAudioVisualizer(canvasWidth, canvasHeight)
    drawInteractionIndicator(ply, canvasWidth, canvasHeight)
end

hook.Add("CreateMove", "FF_BlockExhaustedSprintClient", function(command)
    if staminaConfig.Enabled == false then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool(STAMINA_EXHAUSTED_NETWORK_KEY, false) then return end

    command:SetButtons(bit.band(command:GetButtons(), bit.bnot(IN_SPEED)))
end)

-- The vendored VHS renderer calls this while its image is still in the
-- 720x576 working frame. Later blur, interlacing, colour, noise, and final
-- pillarbox passes process this HUD together with the camera image.
hook.Add("FF_DrawBehindRealisticVHSEffect2", "FF_DrawPSXHUDBehindVHS", drawFoundFootageHUD)
