local hudConfig = FF_CONFIG.HUD or {}
local config = hudConfig.AudioVisualizer or {}
local surroundConfig = ((FF_CONFIG.Audio or {}).SurroundAmbience or {})

local impulses = {}
local continuousSources = {}
local recentSoundEvents = {}
local nextRecentEventPruneAt = 0
local displayedLevel = math.max(tonumber(config.NoiseFloorMinimum) or 0.035, 0.001)
local displayedDirectionRight = 0
local displayedDirectionForward = 0
local displayedDirectionStrength = 0
local lastUpdateAt = RealTime()
local surroundChannel
local surroundPosition
local surroundVolume = 0

local function normalizedPath(path)
    return string.lower(string.gsub(tostring(path or ""), "\\", "/"))
end

local function directSoundFileExists(path)
    local normalized = normalizedPath(path)
    if normalized == "" then return false end

    -- Sound-script aliases do not have an extension and cannot be verified
    -- through the filesystem. Direct WAV/MP3/OGG paths can.
    if not string.match(normalized, "%.%w+$") then return true end
    if not file or not file.Exists then return true end

    local gamePath = string.sub(normalized, 1, 6) == "sound/"
        and normalized
        or "sound/" .. normalized

    return file.Exists(gamePath, "GAME")
end

local function isExcludedVisualizerPath(path)
    local normalized = normalizedPath(path)
    if normalized == "" then return false end

    return string.find(normalized, "threateffects/", 1, true) ~= nil
end

local function ambientNoiseFloor(now)
    local minimum = math.max(tonumber(config.NoiseFloorMinimum) or 0.035, 0.001)
    local maximum = math.max(tonumber(config.NoiseFloorMaximum) or 0.070, minimum)
    local speed = math.max(tonumber(config.NoiseFloorSpeed) or 0.22, 0.01)
    local primary = (math.sin(now * speed * math.pi * 2) + 1) * 0.5
    local secondary = (math.sin(now * speed * 0.37 * math.pi * 2 + 1.7) + 1) * 0.5
    local blend = primary * 0.68 + secondary * 0.32

    return Lerp(blend, minimum, maximum)
end

local function pathContains(path, fragment)
    return string.find(path, fragment, 1, true) ~= nil
end

local function sourceCategoryGain(soundName)
    local gains = config.SourceGains or {}

    if pathContains(soundName, "dsteps/")
        or pathContains(soundName, "footstep")
        or pathContains(soundName, "player/footsteps/") then
        return math.max(tonumber(gains.Footsteps) or 0.30, 0)
    end

    if pathContains(soundName, "foley_lean/")
        or pathContains(soundName, "crounchandjump/")
        or pathContains(soundName, "camcorder/foley")
        or pathContains(soundName, "fallingwind/") then
        return math.max(tonumber(gains.Foley) or 0.24, 0)
    end

    if pathContains(soundName, "violentimpacts/")
        or pathContains(soundName, "impact")
        or pathContains(soundName, "physics/")
        or pathContains(soundName, "body_medium")
        or pathContains(soundName, "ambient/energy/spark") then
        return math.max(tonumber(gains.Impact) or 0.62, 0)
    end

    if pathContains(soundName, "doors/")
        or pathContains(soundName, "door_")
        or pathContains(soundName, "doorknock") then
        return math.max(tonumber(gains.Door) or 0.48, 0)
    end

    if pathContains(soundName, "gm_paranormal/")
        or pathContains(soundName, "paranormal")
        or pathContains(soundName, "ghost")
        or pathContains(soundName, "caveman/") then
        return math.max(tonumber(gains.Paranormal) or 0.78, 0)
    end

    if pathContains(soundName, "ft_reverb/")
        or pathContains(soundName, "dynamic_prop_sounds/")
        or pathContains(soundName, "ambient/")
        or pathContains(soundName, "surround_ambience/") then
        return math.max(tonumber(gains.Ambient) or 0.22, 0)
    end

    return math.max(tonumber(gains.Other) or 0.38, 0)
end

local function soundOrigin(soundData)
    if soundData.Pos and isvector(soundData.Pos) then
        return soundData.Pos
    end

    local entity = soundData.Entity
    if IsValid(entity) then
        return entity:WorldSpaceCenter()
    end

    return nil
end

local function relativeDirection(origin)
    local listener = LocalPlayer()
    if not IsValid(listener) or not origin or not isvector(origin) then
        return 0, 0, false
    end

    local delta = origin - listener:EyePos()
    delta.z = 0
    if delta:LengthSqr() < 64 then
        return 0, 0, false
    end

    delta:Normalize()
    local angles = listener:EyeAngles()
    local forward = angles:Forward()
    local right = angles:Right()
    forward.z = 0
    right.z = 0
    forward:Normalize()
    right:Normalize()

    return math.Clamp(delta:Dot(right), -1, 1), math.Clamp(delta:Dot(forward), -1, 1), true
end

local function estimateDuration(soundName, pitch)
    local duration = tonumber(config.DefaultImpulseDuration) or 0.22

    if SoundDuration and soundName ~= "" then
        local succeeded, measured = pcall(SoundDuration, soundName)
        if succeeded and tonumber(measured) and measured > 0 then
            duration = measured
        end
    end

    pitch = math.Clamp(tonumber(pitch) or 100, 1, 255)
    duration = duration * (100 / pitch)

    return math.Clamp(
        duration,
        math.max(tonumber(config.MinimumImpulseDuration) or 0.08, 0.01),
        math.max(tonumber(config.MaximumImpulseDuration) or 1.5, 0.01)
    )
end

local function estimateAudibleLevel(soundData, soundName)
    local listener = LocalPlayer()
    if not IsValid(listener) then return 0 end

    local volume = math.Clamp(tonumber(soundData.Volume) or 1, 0, 2)
    local soundLevel = tonumber(soundData.SoundLevel or soundData.Level) or 75
    local referenceLevel = tonumber(config.ReferenceSoundLevel) or 75
    local attenuation = math.Clamp(tonumber(config.NoOriginGain) or 0.65, 0, 1)
    local origin = soundOrigin(soundData)

    if origin then
        local referenceDistance = math.max(tonumber(config.ReferenceDistance) or 850, 1)
        local doubling = math.max(tonumber(config.SoundLevelDistanceDoubling) or 12, 1)
        local audibleDistance = referenceDistance * (2 ^ ((soundLevel - referenceLevel) / doubling))
        local distance = listener:EyePos():Distance(origin)
        local normalizedDistance = distance / math.max(audibleDistance, 1)

        attenuation = 1 / (1 + normalizedDistance * normalizedDistance)
    end

    local ownGain = 1
    if soundData.Entity == listener then
        attenuation = 1
        ownGain = math.max(tonumber(config.OwnSoundGain) or 1.05, 0)
    end

    local loudnessRange = math.max(tonumber(config.SoundLevelLoudnessRange) or 24, 1)
    local soundLevelGain = math.Clamp(2 ^ ((soundLevel - referenceLevel) / loudnessRange), 0.45, 1.45)
    local volumeGain = math.Clamp(volume, 0, 1) ^ 0.80
    local categoryGain = sourceCategoryGain(soundName)
    local sensitivity = math.max(tonumber(config.Sensitivity) or 1.0, 0)

    return math.Clamp(
        volumeGain * soundLevelGain * attenuation * ownGain * categoryGain * sensitivity,
        0,
        1
    )
end

local function copiedOrigin(origin)
    return isvector(origin) and Vector(origin.x, origin.y, origin.z) or nil
end

local function soundEventKey(soundName, origin, entity)
    local entityIndex = IsValid(entity) and entity:EntIndex() or 0
    local x, y, z = 0, 0, 0

    if isvector(origin) then
        x = math.floor(origin.x / 16)
        y = math.floor(origin.y / 16)
        z = math.floor(origin.z / 16)
    end

    return table.concat({ soundName, entityIndex, x, y, z }, ":")
end

local function isDuplicateSoundEvent(soundName, origin, entity)
    local now = RealTime()
    local key = soundEventKey(soundName, origin, entity)
    local previous = recentSoundEvents[key]
    recentSoundEvents[key] = now

    return previous ~= nil and now - previous <= 0.05
end

function FF_PushAudioVisualizerLevel(level, duration, sourceName, origin)
    if config.Enabled == false then return end
    if isExcludedVisualizerPath(sourceName) then return end

    level = math.Clamp(tonumber(level) or 0, 0, 1)
    if level <= 0 then return end

    duration = math.Clamp(
        tonumber(duration) or tonumber(config.DefaultImpulseDuration) or 0.22,
        math.max(tonumber(config.MinimumImpulseDuration) or 0.08, 0.01),
        math.max(tonumber(config.MaximumImpulseDuration) or 1.5, 0.01)
    )

    local maximumSources = math.max(math.floor(tonumber(config.MaximumSources) or 64), 1)
    if #impulses >= maximumSources then
        table.remove(impulses, 1)
    end

    local now = RealTime()
    impulses[#impulses + 1] = {
        level = level,
        startedAt = now,
        endsAt = now + duration,
        origin = copiedOrigin(origin),
    }
end

function FF_PushAudioVisualizerSound(soundName, volume, soundLevel, origin, entity, duration, pitch)
    soundName = normalizedPath(soundName)
    if soundName == "" or isExcludedVisualizerPath(soundName) then return end

    local soundData = {
        Volume = volume,
        SoundLevel = soundLevel,
        Pos = isvector(origin) and origin or nil,
        Entity = IsValid(entity) and entity or nil,
    }
    local level = estimateAudibleLevel(soundData, soundName)
    if level <= 0 then return end

    local listener = LocalPlayer()
    local resolvedOrigin
    if soundData.Entity ~= listener then
        resolvedOrigin = soundOrigin(soundData)
    end
    if isDuplicateSoundEvent(soundName, resolvedOrigin, soundData.Entity) then return end

    local resolvedDuration = tonumber(duration) or estimateDuration(soundName, pitch)
    FF_PushAudioVisualizerLevel(level, resolvedDuration, soundName, resolvedOrigin)

    if sourceCategoryGain(soundName) >= ((config.SourceGains or {}).Paranormal or 0.78)
        and FF_PushCamcorderSignal then
        FF_PushCamcorderSignal(
            math.Clamp(level * 0.85, 0.12, 0.72),
            resolvedDuration,
            soundName
        )
    end
end

function FF_SetAudioVisualizerSoundSource(sourceId, soundName, volume, soundLevel, origin, entity)
    if sourceId == nil then return end

    soundName = normalizedPath(soundName)
    volume = math.Clamp(tonumber(volume) or 0, 0, 2)
    if config.Enabled == false
        or soundName == ""
        or volume <= 0
        or isExcludedVisualizerPath(soundName) then
        continuousSources[sourceId] = nil
        return
    end

    local soundData = {
        Volume = volume,
        SoundLevel = soundLevel,
        Pos = isvector(origin) and origin or nil,
        Entity = IsValid(entity) and entity or nil,
    }
    local listener = LocalPlayer()
    local resolvedOrigin
    if soundData.Entity ~= listener then
        resolvedOrigin = soundOrigin(soundData)
    end
    local level = estimateAudibleLevel(soundData, soundName)

    if level <= 0 then
        continuousSources[sourceId] = nil
        return
    end

    continuousSources[sourceId] = {
        level = level,
        origin = copiedOrigin(resolvedOrigin),
        updatedAt = RealTime(),
    }
end

function FF_ClearAudioVisualizerSoundSource(sourceId)
    if sourceId == nil then return end
    continuousSources[sourceId] = nil
end

function FF_PlaySurfaceSound(soundName, volume, soundLevel, duration)
    surface.PlaySound(soundName)

    if not directSoundFileExists(soundName) then
        return false, 0
    end

    local resolvedDuration = tonumber(duration)
    if not resolvedDuration or resolvedDuration <= 0 then
        local succeeded, measured = pcall(SoundDuration, soundName)
        if succeeded then
            resolvedDuration = tonumber(measured)
        end
    end

    if not resolvedDuration or resolvedDuration <= 0 then
        return false, 0
    end

    FF_PushAudioVisualizerSound(
        soundName,
        volume or 1,
        soundLevel or 75,
        nil,
        nil,
        resolvedDuration
    )

    return true, resolvedDuration
end

net.Receive("FF_AudioVisualizerSound", function()
    local count = net.ReadUInt(8)

    for _ = 1, count do
        local soundName = net.ReadString()
        local volume = net.ReadFloat()
        local soundLevel = net.ReadUInt(8)
        local pitch = net.ReadUInt(8)
        local origin = net.ReadBool() and net.ReadVector() or nil
        local entity = net.ReadBool() and net.ReadEntity() or nil

        FF_PushAudioVisualizerSound(soundName, volume, soundLevel, origin, entity, nil, pitch)
    end
end)

hook.Add("EntityEmitSound", "FF_AudioVisualizerCapture", function(soundData)
    if config.Enabled == false then return end

    local soundName = normalizedPath(soundData.OriginalSoundName or soundData.SoundName)
    if isExcludedVisualizerPath(soundName) then return end

    FF_PushAudioVisualizerSound(
        soundName,
        soundData.Volume,
        soundData.SoundLevel or soundData.Level,
        soundOrigin(soundData),
        soundData.Entity,
        nil,
        soundData.Pitch
    )
end)

hook.Add(
    "FF_SurroundAmbienceStarted",
    "FF_AudioVisualizerTrackSurroundAmbience",
    function(path, position, volume, _, channel)
        if isExcludedVisualizerPath(path) then return end

        surroundChannel = channel
        surroundPosition = position
        surroundVolume = math.Clamp(tonumber(volume) or 0, 0, 1)

        FF_PushAudioVisualizerLevel(
            math.Clamp(math.sqrt(surroundVolume) * 0.42, 0, 1),
            0.2,
            path,
            position
        )
    end
)

hook.Add(
    "FF_SurroundAmbienceStopped",
    "FF_AudioVisualizerStopSurroundAmbience",
    function()
        surroundChannel = nil
        surroundPosition = nil
        surroundVolume = 0
    end
)

local function surroundLevel()
    if not IsValid(surroundChannel) or not surroundChannel.GetLevel then
        return 0, 0, 0
    end

    local succeeded, rightLevel, leftLevel = pcall(surroundChannel.GetLevel, surroundChannel)
    if not succeeded then return 0, 0, 0 end

    local rawLevel = math.max(
        math.abs(tonumber(rightLevel) or 0),
        math.abs(tonumber(leftLevel) or 0)
    )
    if rawLevel <= 0 then return 0, 0, 0 end

    local attenuation = 1
    local listener = LocalPlayer()
    if IsValid(listener) and surroundPosition then
        local fadeMinimum = math.max(tonumber(surroundConfig.FadeMinimumDistance) or 280, 0)
        local fadeMaximum = math.max(
            tonumber(surroundConfig.FadeMaximumDistance) or 1800,
            fadeMinimum + 1
        )
        local distance = listener:EyePos():Distance(surroundPosition)
        attenuation = 1 - math.Clamp(
            (distance - fadeMinimum) / (fadeMaximum - fadeMinimum),
            0,
            1
        )
    end

    local gain = math.max(tonumber(config.SurroundGain) or 2.2, 0)
    local level = math.Clamp(
        (rawLevel ^ 0.70)
            * (math.max(surroundVolume, 0.001) ^ 0.65)
            * attenuation
            * gain,
        0,
        1
    )
    local directionRight, directionForward = relativeDirection(surroundPosition)

    return level, directionRight, directionForward
end

local function combinedImpulseLevel(now)
    local energy = 0
    local directionalEnergy = 0
    local weightedRight = 0
    local weightedForward = 0

    for index = #impulses, 1, -1 do
        local impulse = impulses[index]
        if now >= impulse.endsAt then
            table.remove(impulses, index)
        else
            local duration = math.max(impulse.endsAt - impulse.startedAt, 0.001)
            local progress = math.Clamp((now - impulse.startedAt) / duration, 0, 1)
            local decayExponent = math.max(
                tonumber(config.ImpulseDecayExponent) or 1.15,
                0.05
            )
            local envelope = (1 - progress) ^ decayExponent
            local level = impulse.level * envelope
            local contribution = level * level
            energy = energy + contribution

            local directionRight, directionForward, directional = relativeDirection(impulse.origin)
            if directional then
                directionalEnergy = directionalEnergy + contribution
                weightedRight = weightedRight + directionRight * contribution
                weightedForward = weightedForward + directionForward * contribution
            end
        end
    end

    local right = directionalEnergy > 0 and weightedRight / directionalEnergy or 0
    local forward = directionalEnergy > 0 and weightedForward / directionalEnergy or 0

    return math.Clamp(math.sqrt(energy), 0, 1), right, forward, directionalEnergy
end

local function combinedContinuousLevel(now)
    local energy = 0
    local directionalEnergy = 0
    local weightedRight = 0
    local weightedForward = 0

    for sourceId, source in pairs(continuousSources) do
        if now - (source.updatedAt or 0) > 0.5 then
            continuousSources[sourceId] = nil
        else
            local contribution = source.level * source.level
            energy = energy + contribution

            local directionRight, directionForward, directional = relativeDirection(source.origin)
            if directional then
                directionalEnergy = directionalEnergy + contribution
                weightedRight = weightedRight + directionRight * contribution
                weightedForward = weightedForward + directionForward * contribution
            end
        end
    end

    local right = directionalEnergy > 0 and weightedRight / directionalEnergy or 0
    local forward = directionalEnergy > 0 and weightedForward / directionalEnergy or 0

    return math.Clamp(math.sqrt(energy), 0, 1), right, forward, directionalEnergy
end

hook.Add("Think", "FF_AudioVisualizerUpdate", function()
    local now = RealTime()
    local deltaTime = math.Clamp(now - lastUpdateAt, 0, 0.1)
    lastUpdateAt = now

    if now >= nextRecentEventPruneAt then
        for key, timestamp in pairs(recentSoundEvents) do
            if now - timestamp > 1 then
                recentSoundEvents[key] = nil
            end
        end
        nextRecentEventPruneAt = now + 5
    end

    if config.Enabled == false then
        displayedLevel = ambientNoiseFloor(now)
        impulses = {}
        continuousSources = {}
        recentSoundEvents = {}
        surroundChannel = nil
        return
    end

    local impulseLevel, impulseRight, impulseForward, impulseDirectionalEnergy = combinedImpulseLevel(now)
    local continuousLevel, continuousRight, continuousForward, continuousDirectionalEnergy = combinedContinuousLevel(now)
    local liveSurroundLevel, surroundRight, surroundForward = surroundLevel()
    local continuousEnergy = continuousLevel * continuousLevel
    local surroundEnergy = liveSurroundLevel * liveSurroundLevel
    local eventLevel = math.Clamp(
        math.sqrt(impulseLevel * impulseLevel + continuousEnergy + surroundEnergy),
        0,
        1
    )
    local targetLevel = math.max(eventLevel, ambientNoiseFloor(now))
    local speed = targetLevel > displayedLevel
        and math.max(tonumber(config.AttackSpeed) or 48, 0.01)
        or math.max(tonumber(config.ReleaseSpeed) or 10, 0.01)

    displayedLevel = math.Approach(displayedLevel, targetLevel, speed * deltaTime)

    local totalDirectionalEnergy = impulseDirectionalEnergy
        + continuousDirectionalEnergy
        + surroundEnergy
    local targetRight = 0
    local targetForward = 0
    if totalDirectionalEnergy > 0 then
        targetRight = (
            impulseRight * impulseDirectionalEnergy
                + continuousRight * continuousDirectionalEnergy
                + surroundRight * surroundEnergy
        ) / totalDirectionalEnergy
        targetForward = (
            impulseForward * impulseDirectionalEnergy
                + continuousForward * continuousDirectionalEnergy
                + surroundForward * surroundEnergy
        ) / totalDirectionalEnergy
    end

    local directionMagnitude = math.Clamp(
        math.sqrt(targetRight * targetRight + targetForward * targetForward),
        0,
        1
    )
    local minimumLevel = math.max(tonumber(config.DirectionMinimumLevel) or 0.08, 0.001)
    local targetStrength = directionMagnitude * math.Clamp(
        (eventLevel - minimumLevel) / math.max(1 - minimumLevel, 0.001),
        0,
        1
    )
    local directionSpeed = targetStrength > displayedDirectionStrength
        and math.max(tonumber(config.DirectionAttackSpeed) or 28, 0.01)
        or math.max(tonumber(config.DirectionReleaseSpeed) or 10, 0.01)
    local directionStep = directionSpeed * deltaTime

    displayedDirectionRight = math.Approach(displayedDirectionRight, targetRight, directionStep)
    displayedDirectionForward = math.Approach(displayedDirectionForward, targetForward, directionStep)
    displayedDirectionStrength = math.Approach(
        displayedDirectionStrength,
        targetStrength,
        directionStep
    )
end)

function FF_GetAudioVisualizerLevel()
    if config.Enabled == false then return 0 end
    return math.Clamp(math.max(displayedLevel, ambientNoiseFloor(RealTime())), 0.001, 1)
end

function FF_GetAudioVisualizerDirection()
    if config.Enabled == false or config.DirectionalIndicators == false then
        return 0, 0, 0
    end

    return math.Clamp(displayedDirectionRight, -1, 1),
        math.Clamp(displayedDirectionForward, -1, 1),
        math.Clamp(displayedDirectionStrength, 0, 1)
end

hook.Add("OnReloaded", "FF_AudioVisualizerReset", function()
    impulses = {}
    continuousSources = {}
    recentSoundEvents = {}
    local now = RealTime()
    displayedLevel = ambientNoiseFloor(now)
    displayedDirectionRight = 0
    displayedDirectionForward = 0
    displayedDirectionStrength = 0
    surroundChannel = nil
    surroundPosition = nil
    surroundVolume = 0
    lastUpdateAt = now
end)

hook.Add("ShutDown", "FF_AudioVisualizerShutdown", function()
    impulses = {}
    continuousSources = {}
    recentSoundEvents = {}
    surroundChannel = nil
end)
