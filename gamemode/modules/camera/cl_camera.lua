-- Found Footage Style Camera Foley & Movement, Workshop 3751162987.
-- The original shake, regrip, and wind behavior is integrated here under the
-- gamemode's forced configuration. Its menu and archived convars are omitted.
-- Custom-camera zoom remains integrated without requiring a SWEP.

-- Remove the retired bodycam landing hook when this file is hot-reloaded.
hook.Remove("OnPlayerHitGround", "FF_CameraLanding")

local config = FF_CONFIG.Camera
if not config.Enabled then return end

local currentFOV = config.BaseFOV
local targetFOV = config.BaseFOV
local zoomDirection = nil
local zoomStopTime = 0
local pendingZoomSteps = 0

local pendingMouseX = 0
local pendingMouseY = 0

local regripAngle = Angle(0, 0, 0)
local regripPosition = Vector(0, 0, 0)
local regripTargetAngle = Angle(0, 0, 0)
local regripTargetPosition = Vector(0, 0, 0)
local regripStarted = 0
local regripDuration = 0
local regripActive = false
local nextRegrip = 0
local regripSound = nil
local regripWobblePhases = {}
local lastShortRegripIndex = 0
local lastLongRegripIndex = 0

local WIND_VISUALIZER_SOURCE_ID = "camera_wind"
local windSound = nil
local windVolume = 0
local lastEyeAngles = nil

local camcorderAngleOffset = Angle(0, 0, 0)
local camcorderPositionOffset = Vector(0, 0, 0)
local camcorderTargetAngle = Angle(0, 0, 0)
local camcorderTargetPosition = Vector(0, 0, 0)
local camcorderLastFOV = nil
local jitterCooldown = 0
local jitterIntensity = 0
local walkDriftOffset = math.Rand(0, 10)

local function expSmoothing(rate, deltaTime)
    return 1 - math.exp(-math.max(rate, 0) * math.max(deltaTime, 0))
end

local function stopZoomLoop(ply)
    if not IsValid(ply) then return end
    ply:StopSound("zoom_in.wav")
    ply:StopSound("zoom_out.wav")
end

local function startZoomLoop(ply, direction)
    stopZoomLoop(ply)

    if direction == "in" then
        ply:EmitSound("zoom_in.wav", 68, 100, 0.58, CHAN_STATIC)
    else
        ply:EmitSound("zoom_out.wav", 68, 100, 0.58, CHAN_STATIC)
    end

    zoomDirection = direction
end

local function finishZoom(ply, direction)
    stopZoomLoop(ply)

    if IsValid(ply) and direction then
        local soundPath = direction == "in" and "zoom_in_stop.wav" or "zoom_out_stop.wav"
        ply:EmitSound(soundPath, 66, 100, 0.55, CHAN_STATIC)
    end

    zoomDirection = nil
end

hook.Add("PlayerBindPress", "FF_CameraWheelZoom", function(_, bind, pressed, code)
    if not pressed or vgui.CursorVisible() then return end

    bind = string.lower(string.Trim(bind or ""))
    if code == MOUSE_WHEEL_UP
        or code == MOUSE_WHEEL_DOWN
        or bind == "invprev"
        or bind == "invnext"
    then
        return true
    end
end)

local function scheduleRegrip()
    local settings = config.Regrip
    local minimum = settings.MinimumDelay
    local maximum = settings.MaximumDelay
    local ply = LocalPlayer()

    if IsValid(ply) and ply:IsOnGround() and ply:GetVelocity():Length2D() > 150 then
        local multiplier = settings.RunningDelayMultiplier or 0.25
        minimum = minimum * multiplier
        maximum = maximum * multiplier
    end

    nextRegrip = CurTime() + math.Rand(minimum, maximum)
end

local function stopRegripSound()
    if regripSound then
        regripSound:Stop()
        regripSound = nil
    end
end

local function pickRegripIndex(lastIndex)
    local index
    repeat
        index = math.random(1, 7)
    until index ~= lastIndex

    return index
end

local function regripEnvelope(fraction)
    local base = math.sin(fraction * math.pi)
    local overshoot = math.sin(fraction * math.pi * 2.4 + 0.5) * 0.15
    local tremor = math.sin(fraction * math.pi * 7.3) * 0.05 * (1 - fraction)

    return math.Clamp(base + overshoot + tremor, -0.3, 1.2)
end

local function buildRegripWobble(isLong)
    regripWobblePhases = {}
    local count = isLong and math.random(3, 5) or math.random(2, 3)

    for index = 1, count do
        regripWobblePhases[index] = {
            time = math.Rand(0.15, 0.85),
            angle = Angle(
                math.Rand(-1.2, 1.2),
                math.Rand(-1.0, 1.0),
                math.Rand(-0.7, 0.7)
            ),
            position = Vector(
                math.Rand(-0.5, 0.5),
                math.Rand(-0.25, 0.25),
                math.Rand(-0.35, 0.35)
            ),
        }
    end

    table.SortByMember(regripWobblePhases, "time", true)
end

local function sampleRegripWobble(fraction)
    local angle = Angle(0, 0, 0)
    local position = Vector(0, 0, 0)

    for _, phase in ipairs(regripWobblePhases) do
        local distance = math.abs(fraction - phase.time)
        local weight = math.exp(-(distance * distance) / 0.02)
        angle = angle + phase.angle * weight
        position = position + phase.position * weight
    end

    return angle, position
end

local function beginRegrip(ply)
    local settings = config.Regrip
    if not settings.Enabled or not IsValid(ply) then return end

    local isLong = math.Rand(0, 1) < settings.LongChance
    local soundPath

    if isLong then
        local index = pickRegripIndex(lastLongRegripIndex)
        lastLongRegripIndex = index
        soundPath = "camcorder/foleylong" .. index .. ".wav"
        regripDuration = math.Rand(2.8, 4.2)
    else
        local index = pickRegripIndex(lastShortRegripIndex)
        lastShortRegripIndex = index
        soundPath = "camcorder/foley" .. index .. ".wav"
        regripDuration = math.Rand(0.9, 2.0)
    end

    local volume = math.Clamp(settings.Volume, 0, 1)
    if volume > 0 then
        stopRegripSound()
        regripSound = CreateSound(ply, soundPath)
        if regripSound then
            regripSound:PlayEx(volume, 100)
            if FF_PushAudioVisualizerSound then
                FF_PushAudioVisualizerSound(
                    soundPath,
                    volume,
                    75,
                    nil,
                    ply,
                    regripDuration
                )
            end
            local soundObject = regripSound
            timer.Simple(regripDuration + 1, function()
                if soundObject then
                    soundObject:Stop()
                end
                if regripSound == soundObject then
                    regripSound = nil
                end
            end)
        end
    end

    local strength = settings.Intensity
    local angleScale = isLong and math.Rand(5.0, 9.0) or math.Rand(3.5, 6.5)
    local positionScale = isLong and math.Rand(2.0, 4.0) or math.Rand(1.2, 2.8)

    regripTargetAngle = Angle(
        math.Rand(-angleScale * 0.7, angleScale) * strength,
        math.Rand(-angleScale, angleScale) * strength,
        math.Rand(-angleScale * 0.5, angleScale * 0.5) * strength
    )
    regripTargetPosition = Vector(
        math.Rand(-positionScale, positionScale) * strength,
        math.Rand(-positionScale * 0.5, positionScale * 0.5) * strength,
        math.Rand(-positionScale * 0.3, positionScale * 0.6) * strength
    )

    buildRegripWobble(isLong)
    regripStarted = CurTime()
    regripActive = true
end

local function updateRegrip(ply, frameTime)
    local settings = config.Regrip
    if not settings.Enabled or not config.Camcorder.Enabled then
        regripActive = false
        regripAngle = Angle(0, 0, 0)
        regripPosition = Vector(0, 0, 0)
        return
    end

    local currentTime = CurTime()
    if nextRegrip == 0 then
        scheduleRegrip()
    elseif not regripActive and currentTime >= nextRegrip then
        beginRegrip(ply)
        scheduleRegrip()
    end

    if regripActive then
        local fraction = math.Clamp(
            (currentTime - regripStarted) / math.max(regripDuration, 0.01),
            0,
            1
        )

        if fraction >= 1 then
            regripActive = false
            regripAngle = LerpAngle(frameTime * 14, regripAngle, Angle(0, 0, 0))
            regripPosition = LerpVector(frameTime * 14, regripPosition, Vector(0, 0, 0))
        else
            local envelope = regripEnvelope(fraction)
            local wobbleAngle, wobblePosition = sampleRegripWobble(fraction)
            local jitterStrength = envelope * 0.1
            local jitterAngle = Angle(
                math.Rand(-jitterStrength, jitterStrength),
                math.Rand(-jitterStrength, jitterStrength),
                math.Rand(-jitterStrength * 0.6, jitterStrength * 0.6)
            )
            local jitterPosition = Vector(
                math.Rand(-jitterStrength * 0.3, jitterStrength * 0.3),
                math.Rand(-jitterStrength * 0.15, jitterStrength * 0.15),
                math.Rand(-jitterStrength * 0.2, jitterStrength * 0.2)
            )

            local targetAngle = regripTargetAngle * envelope
                + wobbleAngle * envelope
                + jitterAngle
            local targetPosition = regripTargetPosition * envelope
                + wobblePosition * envelope
                + jitterPosition

            regripAngle = LerpAngle(frameTime * 22, regripAngle, targetAngle)
            regripPosition = LerpVector(frameTime * 22, regripPosition, targetPosition)
        end
    else
        regripAngle = LerpAngle(frameTime * 12, regripAngle, Angle(0, 0, 0))
        regripPosition = LerpVector(frameTime * 12, regripPosition, Vector(0, 0, 0))
    end
end

local function updateCamcorderMotion(ply, inputFOV)
    local settings = config.Camcorder
    if not settings.Enabled then
        camcorderAngleOffset = Angle(0, 0, 0)
        camcorderPositionOffset = Vector(0, 0, 0)
        camcorderTargetAngle = Angle(0, 0, 0)
        camcorderTargetPosition = Vector(0, 0, 0)
        camcorderLastFOV = inputFOV
        return inputFOV
    end

    local currentTime = CurTime()
    local frameTime = FrameTime()
    local speedMultiplier = math.max(settings.Speed or 1, 0.01)
    local time = currentTime * speedMultiplier
    local drift = settings.BaseDrift
    local jitter = settings.Jitter
    local trembleSettings = settings.Tremble

    local baseDrift = Angle(
        math.sin(time * 0.55) * drift.Pitch + math.sin(time * 0.25) * 1.2,
        math.cos(time * 0.5) * drift.Yaw + math.cos(time * 0.3) * 1.5,
        math.sin(time * 0.4 + 1.3) * drift.Roll
    )
    local basePosition = Vector(
        math.sin(time * 0.45) * drift.PositionX + math.sin(time * 0.2) * 1.1,
        math.cos(time * 0.55 + 2) * drift.PositionY + math.cos(time * 0.3) * 0.7,
        math.sin(time * 0.35 + 0.5) * drift.PositionZ
    )

    if jitterCooldown <= 0 then
        jitterIntensity = math.Rand(jitter.MinimumIntensity, jitter.MaximumIntensity)
        jitterCooldown = math.Rand(jitter.MinimumInterval, jitter.MaximumInterval)
            / speedMultiplier
    else
        jitterCooldown = jitterCooldown - frameTime
    end

    local jitterAngle = Angle(
        math.Rand(-jitterIntensity, jitterIntensity),
        math.Rand(-jitterIntensity, jitterIntensity),
        math.Rand(-jitterIntensity * 0.6, jitterIntensity * 0.6)
    )
    local tremble = Angle(
        (math.sin(time * 50) + math.sin(time * 70)) * trembleSettings.PitchYaw,
        (math.cos(time * 60) + math.cos(time * 80)) * trembleSettings.PitchYaw,
        (math.sin(time * 40 + 3) + math.cos(time * 55 + 1)) * trembleSettings.Roll
    )

    local movementAngle = Angle(0, 0, 0)
    local movementPosition = Vector(0, 0, 0)
    local movement = settings.MovementSway
    local horizontalSpeed = ply:GetVelocity():Length2D()

    if movement.Enabled and ply:IsOnGround() and horizontalSpeed > 5 then
        local running = horizontalSpeed > movement.RunningThreshold
        local bobFrequency = math.Clamp(
            horizontalSpeed / 200,
            1.5,
            running and 6 or 3
        ) * speedMultiplier
        local bobTime = currentTime * bobFrequency * math.pi * 2 + walkDriftOffset

        local vertical = math.abs(math.sin(bobTime) + math.sin(bobTime * 1.3))
            * (running and movement.RunVertical or movement.WalkVertical) * 0.9
        local side = math.sin(bobTime * 2 + math.cos(time * 5))
            * (running and movement.RunSide or movement.WalkSide)
        local pitch = math.sin(bobTime * 1.8)
            * (running and movement.RunPitch or movement.WalkPitch)
        local roll = math.cos(bobTime * 1.5)
            * (running and movement.RunRoll or movement.WalkRoll)
        local yaw = math.sin(bobTime * 1.2 + math.sin(time * 7))
            * (running and movement.RunYaw or movement.WalkYaw)

        movementPosition = LerpVector(0.25, movementPosition, Vector(side, 0, vertical))
        movementAngle = LerpAngle(0.25, movementAngle, Angle(pitch, yaw, roll))
    else
        movementPosition = LerpVector(0.15, movementPosition, Vector(0, 0, 0))
        movementAngle = LerpAngle(0.15, movementAngle, Angle(0, 0, 0))
    end

    local combinedAngle = movementAngle + baseDrift + jitterAngle + tremble
    local combinedPosition = movementPosition + basePosition
    local smoothing = math.Clamp(0.1 * speedMultiplier, 0.05, 0.6)
    local tracking = math.Clamp(0.15 * speedMultiplier, 0.05, 0.7)

    camcorderTargetAngle = LerpAngle(smoothing, camcorderTargetAngle, combinedAngle)
    camcorderTargetPosition = LerpVector(smoothing, camcorderTargetPosition, combinedPosition)
    camcorderAngleOffset = LerpAngle(tracking, camcorderAngleOffset, camcorderTargetAngle)
    camcorderPositionOffset = LerpVector(tracking, camcorderPositionOffset, camcorderTargetPosition)

    if not camcorderLastFOV then
        camcorderLastFOV = inputFOV
    end

    local fovSettings = settings.FOVWobble
    local fovWobble = 0
    if fovSettings.Enabled then
        fovWobble = math.sin(time * 1.8 + math.sin(time * 3))
            * (fovSettings.BaseAmplitude + jitterIntensity * fovSettings.JitterMultiplier)
    end
    camcorderLastFOV = Lerp(
        0.08 * speedMultiplier,
        camcorderLastFOV,
        inputFOV + fovWobble
    )

    return camcorderLastFOV
end

local function downwardLookSettings()
    local settings = config.DownwardLookLimit or {}
    local maximumPitch = math.Clamp(tonumber(settings.MaximumPitch) or 70, 0, 88)
    local softZone = math.Clamp(tonumber(settings.SoftZone) or 18, 0, maximumPitch)
    local minimumInputScale = math.Clamp(tonumber(settings.MinimumInputScale) or 0.06, 0, 1)

    return settings.Enabled ~= false, maximumPitch, softZone, minimumInputScale
end

local function applyDownwardLookRestriction(currentPitch, pitchDelta)
    local enabled, maximumPitch, softZone, minimumInputScale = downwardLookSettings()
    if not enabled then
        return math.Clamp(currentPitch + pitchDelta, -89, 89)
    end

    currentPitch = math.min(currentPitch, maximumPitch)

    if pitchDelta <= 0 or softZone <= 0 then
        return math.Clamp(currentPitch + pitchDelta, -89, maximumPitch)
    end

    local softStart = maximumPitch - softZone
    local progress = math.Clamp((currentPitch - softStart) / softZone, 0, 1)
    local easedProgress = progress * progress * (3 - 2 * progress)
    local inputScale = Lerp(easedProgress, 1, minimumInputScale)

    return math.Clamp(currentPitch + pitchDelta * inputScale, -89, maximumPitch)
end

hook.Add("InputMouseApply", "FF_SmoothMouseMovement", function(cmd, x, y, viewAngles)
    local wheelDelta = cmd:GetMouseWheel()
    local ply = LocalPlayer()
    if wheelDelta ~= 0
        and IsValid(ply)
        and ply:Alive()
        and not vgui.CursorVisible()
    then
        pendingZoomSteps = pendingZoomSteps + wheelDelta
    end

    local smoothing = config.MouseSmoothing
    if not smoothing.Enabled then return end

    pendingMouseX = pendingMouseX + x
    pendingMouseY = pendingMouseY + y

    local deltaTime = math.max(RealFrameTime(), 0.001)
    local factor = 1 - math.exp(-deltaTime / math.max(smoothing.ResponseSeconds, 0.001))
    local applyX = pendingMouseX * factor
    local applyY = pendingMouseY * factor

    pendingMouseX = pendingMouseX - applyX
    pendingMouseY = pendingMouseY - applyY

    viewAngles.p = applyDownwardLookRestriction(
        viewAngles.p,
        applyY * smoothing.DegreesPerCount
    )
    viewAngles.y = viewAngles.y - applyX * smoothing.DegreesPerCount
    viewAngles.r = 0
    cmd:SetViewAngles(viewAngles)

    return true
end)

hook.Add("CreateMove", "FF_DownwardLookSafetyLimit", function(cmd)
    local enabled, maximumPitch = downwardLookSettings()
    if not enabled then return end

    local viewAngles = cmd:GetViewAngles()
    if viewAngles.p <= maximumPitch then return end

    viewAngles.p = maximumPitch
    viewAngles.r = 0
    cmd:SetViewAngles(viewAngles)
end)

local function updateZoom(ply, deltaTime)
    local zoomSteps = pendingZoomSteps
    pendingZoomSteps = 0

    if zoomSteps ~= 0 then
        local direction = zoomSteps > 0 and "in" or "out"
        local degreesPerScroll = math.max(tonumber(config.ZoomDegreesPerScroll) or 4, 0.1)
        local previousTargetFOV = targetFOV

        targetFOV = math.Clamp(
            targetFOV - zoomSteps * degreesPerScroll,
            config.MinimumFOV,
            config.BaseFOV
        )

        if targetFOV ~= previousTargetFOV then
            if zoomDirection ~= direction then
                startZoomLoop(ply, direction)
            end

            zoomStopTime = RealTime() + 0.16
        end
    end

    if ply:KeyDown(IN_RELOAD) then
        targetFOV = config.BaseFOV
    end

    local atMinimum = targetFOV <= config.MinimumFOV + 0.01
    local atMaximum = targetFOV >= config.BaseFOV - 0.01

    if zoomDirection == "in" and (RealTime() >= zoomStopTime or atMinimum) then
        finishZoom(ply, "in")
    elseif zoomDirection == "out" and (RealTime() >= zoomStopTime or atMaximum) then
        finishZoom(ply, "out")
    end

    currentFOV = Lerp(expSmoothing(config.ZoomSmoothing, deltaTime), currentFOV, targetFOV)
end

function FF_GetCameraZoomFraction()
    local wideFOV = tonumber(config.BaseFOV) or 92
    local telephotoFOV = tonumber(config.MinimumFOV) or 32
    local range = math.max(wideFOV - telephotoFOV, 0.001)

    return math.Clamp((wideFOV - (tonumber(currentFOV) or wideFOV)) / range, 0, 1)
end

function FF_GetCameraFOV()
    return tonumber(currentFOV) or tonumber(config.BaseFOV) or 92
end

local function stopWindSound()
    if windSound then
        windSound:Stop()
        windSound = nil
    end
    if FF_ClearAudioVisualizerSoundSource then
        FF_ClearAudioVisualizerSoundSource(WIND_VISUALIZER_SOURCE_ID)
    end

    windVolume = 0
    lastEyeAngles = nil
end

local function startWindSound(ply)
    if windSound then return end

    windSound = CreateSound(ply, "camcorder/wind.wav")
    if windSound then
        windSound:Play()
    end
end

local function updateWind(ply, frameTime)
    if not config.Camcorder.Enabled then
        stopWindSound()
        return
    end

    local eyeAngles = ply:EyeAngles()
    local punch = ply:GetViewPunchAngles() or Angle(0, 0, 0)
    local realAngles = Angle(
        eyeAngles.p - punch.p,
        eyeAngles.y - punch.y,
        eyeAngles.r - punch.r
    )

    if not lastEyeAngles then
        lastEyeAngles = realAngles
        startWindSound(ply)
        if windSound then
            windSound:ChangeVolume(0, 0)
        end
        windVolume = 0
        return
    end

    local deltaPitch = math.AngleDifference(realAngles.p, lastEyeAngles.p)
    local deltaYaw = math.AngleDifference(realAngles.y, lastEyeAngles.y)
    local deltaRoll = math.AngleDifference(realAngles.r, lastEyeAngles.r)
    local angularSpeed = math.sqrt(
        deltaPitch ^ 2 + deltaYaw ^ 2 + deltaRoll ^ 2
    )

    local panVolume = math.Clamp(
        angularSpeed / 10,
        0,
        config.Camcorder.WindMaximumVolume
    )

    local speed = ply:GetVelocity():Length2D()
    local runVolume = 0
    if ply:IsOnGround() and speed > 80 then
        runVolume = math.Clamp((speed - 80) / 200, 0, 0.5)
    end

    local targetVolume = math.max(panVolume, runVolume)
    local lerpRate = targetVolume > windVolume and frameTime * 8 or frameTime * 4
    windVolume = Lerp(lerpRate, windVolume, targetVolume)

    if not windSound then
        startWindSound(ply)
    end
    if windSound then
        windSound:ChangeVolume(windVolume, 0)
    end

    local playing = windSound
        and windSound.IsPlaying
        and windSound:IsPlaying()

    if playing and FF_SetAudioVisualizerSoundSource then
        FF_SetAudioVisualizerSoundSource(
            WIND_VISUALIZER_SOURCE_ID,
            "camcorder/wind.wav",
            windVolume,
            75,
            nil,
            ply
        )
    elseif FF_ClearAudioVisualizerSoundSource then
        FF_ClearAudioVisualizerSoundSource(WIND_VISUALIZER_SOURCE_ID)
    end

    lastEyeAngles = realAngles
end

hook.Add("Think", "FF_CameraThink", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        stopWindSound()
        return
    end

    local frameTime = FrameTime()
    updateWind(ply, frameTime)

    if not ply:Alive() then return end

    updateZoom(ply, math.min(frameTime, 0.05))
    updateRegrip(ply, frameTime)
end)

local function foundFootageCalcView(self, ply, origin, angles, fov, znear, zfar)
    if not IsValid(ply) or not ply:Alive() then
        return self.BaseClass.CalcView(self, ply, origin, angles, fov, znear, zfar)
    end

    if FF_GetBlackMesaFirstPersonView then
        local animationView = FF_GetBlackMesaFirstPersonView(
            ply,
            math.max(config.MinimumFOV, currentFOV or fov),
            znear,
            zfar
        )

        if animationView then
            return animationView
        end
    end

    local baseView = self.BaseClass.CalcView(self, ply, origin, angles, fov, znear, zfar) or {}
    origin = baseView.origin or origin
    angles = baseView.angles or angles

    if FF_ApplySmoothStairs then
        origin = FF_ApplySmoothStairs(ply, origin)
    end

    local cameraFOV = updateCamcorderMotion(ply, currentFOV)
    local intensity = config.Camcorder.Enabled and (config.Camcorder.Intensity or 1) or 0
    local cameraAngle = camcorderAngleOffset * intensity
    local cameraPosition = camcorderPositionOffset * intensity
    local fallingWindAngle = FF_GetFallingWindCameraOffset
        and FF_GetFallingWindCameraOffset()
        or Angle(0, 0, 0)
    local leanPosition, leanAngle = Vector(0, 0, 0), Angle(0, 0, 0)
    if FF_GetLeanViewOffset then
        leanPosition, leanAngle = FF_GetLeanViewOffset(ply, origin, angles)
    end

    local viewAngles = angles + leanAngle + cameraAngle + regripAngle + fallingWindAngle
    local viewOrigin = origin + leanPosition + cameraPosition + regripPosition

    return {
        origin = viewOrigin,
        angles = viewAngles,
        fov = math.max(config.MinimumFOV, cameraFOV),
        znear = baseView.znear or znear,
        zfar = baseView.zfar or zfar,
        drawviewer = false,
    }
end

FF_FoundFootageCalcView = foundFootageCalcView
GM.CalcView = foundFootageCalcView

local function enforceCameraOwnership()
    if GAMEMODE and GAMEMODE.CalcView ~= FF_FoundFootageCalcView then
        GAMEMODE.CalcView = FF_FoundFootageCalcView
    end
end

timer.Create("FF_EnforceCameraOwnership", 1, 0, enforceCameraOwnership)
hook.Add("OnReloaded", "FF_EnforceCameraOwnership", enforceCameraOwnership)

hook.Add("InitPostEntity", "FF_CameraInitialize", function()
    currentFOV = config.BaseFOV
    targetFOV = config.BaseFOV
    scheduleRegrip()
end)

hook.Add("ShutDown", "FF_CameraCleanup", function()
    local ply = LocalPlayer()
    stopZoomLoop(ply)
    stopRegripSound()

    stopWindSound()
end)
