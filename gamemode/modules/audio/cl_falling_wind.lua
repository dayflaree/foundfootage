local config = FF_CONFIG.Audio.FallingWind
if not config.Enabled then return end

local VISUALIZER_SOURCE_ID = "falling_wind"
local soundPatch = nil
local volume = 0
local pitch = config.MinimumPitch
local shakeFraction = 0

local function stopSound()
    if soundPatch then
        soundPatch:Stop()
        soundPatch = nil
    end
    if FF_ClearAudioVisualizerSoundSource then
        FF_ClearAudioVisualizerSoundSource(VISUALIZER_SOURCE_ID)
    end
    volume = 0
    shakeFraction = 0
end

function FF_GetFallingWindCameraOffset()
    if shakeFraction <= 0 then
        return Angle(0, 0, 0)
    end

    local time = CurTime() * 18
    local shake = shakeFraction * config.CameraShake
    return Angle(
        math.sin(time * 1.11) * shake,
        math.cos(time * 0.83) * shake,
        math.sin(time * 0.57) * shake * 0.5
    )
end

hook.Add("Think", "FF_FallingWind", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        stopSound()
        return
    end

    if not soundPatch then
        soundPatch = CreateSound(ply, config.Sound)
        if soundPatch then
            soundPatch:PlayEx(0, config.MinimumPitch)
        end
    end

    local velocity = ply:GetVelocity()
    local fallSpeed = math.max(0, -velocity.z)
    local validMovement = not ply:IsOnGround()
        and ply:GetMoveType() ~= MOVETYPE_NOCLIP
        and ply:GetMoveType() ~= MOVETYPE_LADDER
        and not ply:InVehicle()

    local fraction = 0
    if validMovement then
        fraction = math.Clamp(
            (fallSpeed - config.MinimumFallSpeed) /
            math.max(config.MaximumFallSpeed - config.MinimumFallSpeed, 1),
            0,
            1
        )
    end

    shakeFraction = fraction
    local targetVolume = fraction * config.MaximumVolume
    local targetPitch = Lerp(fraction, config.MinimumPitch, config.MaximumPitch)
    local smoothing = 1 - math.exp(-FrameTime() * (fraction > 0 and 8 or 4))

    volume = Lerp(smoothing, volume, targetVolume)
    pitch = Lerp(smoothing, pitch, targetPitch)

    if soundPatch then
        soundPatch:ChangeVolume(volume, 0)
        soundPatch:ChangePitch(math.floor(pitch), 0)
    end

    local playing = soundPatch
        and soundPatch.IsPlaying
        and soundPatch:IsPlaying()

    if playing and FF_SetAudioVisualizerSoundSource then
        FF_SetAudioVisualizerSoundSource(
            VISUALIZER_SOURCE_ID,
            config.Sound,
            volume,
            75,
            nil,
            ply
        )
    elseif FF_ClearAudioVisualizerSoundSource then
        FF_ClearAudioVisualizerSoundSource(VISUALIZER_SOURCE_ID)
    end
end)

hook.Add("ShutDown", "FF_StopFallingWind", stopSound)
