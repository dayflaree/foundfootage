local NET_SOUND_EVENT = "FF_AudioVisualizerSound"
local MAX_EVENTS_PER_MESSAGE = 255
local pendingEvents = {}

util.AddNetworkString(NET_SOUND_EVENT)

local function normalizedPath(path)
    return string.lower(string.gsub(tostring(path or ""), "\\", "/"))
end

local function isExcludedVisualizerPath(path)
    local normalized = normalizedPath(path)
    if string.sub(normalized, 1, 6) == "sound/" then
        normalized = string.sub(normalized, 7)
    end

    return string.find(normalized, "threateffects/", 1, true) ~= nil
        or string.sub(normalized, 1, 7) == "vhs_ui/"
        or string.sub(normalized, 1, 3) == "ui/"
        or string.sub(normalized, 1, 13) == "garrysmod/ui_"
end

local function soundOrigin(soundData)
    if soundData.Pos and isvector(soundData.Pos) then
        return Vector(soundData.Pos.x, soundData.Pos.y, soundData.Pos.z)
    end

    local entity = soundData.Entity
    if IsValid(entity) then
        return entity:WorldSpaceCenter()
    end
end

hook.Add("EntityEmitSound", "FF_AudioVisualizerForwardServerSound", function(soundData)
    local soundName = normalizedPath(soundData.OriginalSoundName or soundData.SoundName)
    if soundName == "" or isExcludedVisualizerPath(soundName) then return end

    pendingEvents[#pendingEvents + 1] = {
        soundName = soundName,
        volume = math.Clamp(tonumber(soundData.Volume) or 1, 0, 2),
        soundLevel = math.Clamp(
            math.floor(tonumber(soundData.SoundLevel or soundData.Level) or 75),
            0,
            255
        ),
        pitch = math.Clamp(
            math.floor(tonumber(soundData.Pitch) or 100),
            1,
            255
        ),
        origin = soundOrigin(soundData),
        entity = IsValid(soundData.Entity) and soundData.Entity or nil,
    }
end)

local function writeEvent(event)
    net.WriteString(event.soundName)
    net.WriteFloat(event.volume)
    net.WriteUInt(event.soundLevel, 8)
    net.WriteUInt(event.pitch, 8)
    net.WriteBool(event.origin ~= nil)
    if event.origin then
        net.WriteVector(event.origin)
    end

    local hasEntity = IsValid(event.entity)
    net.WriteBool(hasEntity)
    if hasEntity then
        net.WriteEntity(event.entity)
    end
end

hook.Add("Think", "FF_AudioVisualizerFlushServerSounds", function()
    while #pendingEvents > 0 do
        local count = math.min(#pendingEvents, MAX_EVENTS_PER_MESSAGE)

        net.Start(NET_SOUND_EVENT, true)
        net.WriteUInt(count, 8)
        for index = 1, count do
            writeEvent(pendingEvents[index])
        end
        net.Broadcast()

        for _ = 1, count do
            table.remove(pendingEvents, 1)
        end
    end
end)

hook.Add("ShutDown", "FF_AudioVisualizerClearServerSounds", function()
    pendingEvents = {}
end)
