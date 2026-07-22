-- Integrated Sound Muffling Effect without the original global CreateSound and
-- CSoundPatch replacements. Per-sound occlusion remains compatible with the
-- gamemode's camera Foley, footsteps, and forced VHS equalizer.

local config = FF_CONFIG.Audio.Muffling
if not config.Enabled then return end

local function getSoundOrigin(soundData)
    if isvector(soundData.Pos) then
        return soundData.Pos
    end

    local entity = soundData.Entity
    if not IsValid(entity) then return nil end

    if entity:IsPlayer() or entity:IsNPC() or entity:IsNextBot() then
        return entity:EyePos()
    end

    return entity:WorldSpaceCenter()
end

local function traceOcclusion(startPosition, endPosition, filter)
    return util.TraceLine({
        start = startPosition,
        endpos = endPosition,
        filter = filter,
        mask = MASK_SOLID,
    })
end

hook.Add("EntityEmitSound", "FF_ForcedSoundMuffling", function(soundData)
    local listener = LocalPlayer()
    if not IsValid(listener) then return end

    local origin = getSoundOrigin(soundData)
    if not origin then return end

    local listenerPosition = listener:EyePos()
    local trueDistance = listenerPosition:Distance(origin)
    if trueDistance <= 16 then return end

    local filter = { listener }
    if IsValid(soundData.Entity) and soundData.Entity ~= game.GetWorld() then
        filter[#filter + 1] = soundData.Entity
    end

    local forwardTrace = traceOcclusion(listenerPosition, origin, filter)
    local reverseTrace = traceOcclusion(origin, listenerPosition, filter)
    if not istable(forwardTrace) or not istable(reverseTrace) then return end

    local occluded = forwardTrace.Hit == true
        and reverseTrace.Hit == true
        and isvector(forwardTrace.HitPos)
        and isvector(reverseTrace.HitPos)
    local dsp = soundData.DSP or 0

    if occluded then
        local thickness = forwardTrace.HitPos:Distance(reverseTrace.HitPos)
        local minimum = config.MinimumThickness

        if thickness > minimum * 20 then
            dsp = 31
        elseif thickness > minimum * 8 then
            dsp = 14
        elseif thickness >= minimum then
            dsp = 30
        end

        if config.Attenuation then
            local attenuation = math.Clamp(1050 / math.max(trueDistance, 1), 0.08, 1)
            soundData.Volume = math.min(soundData.Volume or 1, attenuation)
        end
    elseif config.FarDistance > 0 and trueDistance > config.FarDistance then
        dsp = 132

        if config.Attenuation then
            local attenuation = math.Clamp(1550 / trueDistance, 0.06, 1)
            soundData.Volume = math.min(soundData.Volume or 1, attenuation)
        end
    end

    -- DSP 1 requests automatic processing, which conflicts with explicit room
    -- and occlusion processing. Zero means no per-sound override.
    if dsp == 1 then
        dsp = 0
    end

    soundData.DSP = dsp
    return true
end)
