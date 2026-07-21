-- Geometry-driven integration of Echo/Reverb Everywhere. It controls the room
-- simulation only; Realistic VHS Effect2's forced equalizer owns player DSP.

local config = FF_CONFIG.Audio.Reverb
if not config.Enabled then return end

local directions = {
    Vector(0, 0, 1),
    Vector(0, 0, -1),
    Vector(1, 0, 0),
    Vector(-1, 0, 0),
    Vector(0, 1, 0),
    Vector(0, -1, 0),
    Vector(1, 1, 0.65):GetNormalized(),
    Vector(-1, 1, 0.65):GetNormalized(),
    Vector(1, -1, 0.65):GetNormalized(),
    Vector(-1, -1, 0.65):GetNormalized(),
    Vector(1, 1, -0.65):GetNormalized(),
    Vector(-1, 1, -0.65):GetNormalized(),
    Vector(1, -1, -0.65):GetNormalized(),
    Vector(-1, -1, -0.65):GetNormalized(),
}

local lastRoomType = nil
local lastVolume = nil

local function setRoom(roomType, volume)
    roomType = tostring(roomType)
    volume = tostring(volume)

    local roomConVar = GetConVar("room_type")
    if roomType ~= lastRoomType or (roomConVar and roomConVar:GetString() ~= roomType) then
        RunConsoleCommand("room_type", roomType)
        lastRoomType = roomType
    end

    local volumeConVar = GetConVar("dsp_volume")
    if volume ~= lastVolume or (volumeConVar and volumeConVar:GetString() ~= volume) then
        RunConsoleCommand("dsp_volume", volume)
        lastVolume = volume
    end
end

local function sampleRoom()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local origin = ply:EyePos()
    local distanceTotal = 0
    local hitCount = 0
    local openCount = 0
    local filter = { ply }

    local vehicle = ply:GetVehicle()
    if IsValid(vehicle) then
        filter[#filter + 1] = vehicle
        if IsValid(vehicle:GetParent()) then
            filter[#filter + 1] = vehicle:GetParent()
        end
    end

    for _, direction in ipairs(directions) do
        local trace = util.TraceLine({
            start = origin,
            endpos = origin + direction * config.TraceDistance,
            filter = filter,
            mask = MASK_SOLID,
        })

        if trace.Hit and not trace.HitSky then
            hitCount = hitCount + 1
            distanceTotal = distanceTotal + origin:Distance(trace.HitPos)
        else
            openCount = openCount + 1
        end
    end

    local openness = openCount / #directions
    if openness >= 0.28 or hitCount == 0 then
        setRoom(21, config.DSPVolume)
        return
    end

    local averageDistance = distanceTotal / hitCount

    if averageDistance > 1400 then
        setRoom(103, math.max(config.DSPVolume, 1.3))
    elseif averageDistance > 760 then
        setRoom(4, math.max(config.DSPVolume, 1.24))
    elseif averageDistance > 380 then
        setRoom(3, config.DSPVolume)
    elseif averageDistance > 175 then
        setRoom(2, config.DSPVolume)
    else
        setRoom(102, 1)
    end
end

timer.Create("FF_ForcedEnvironmentReverb", config.UpdateInterval, 0, sampleRoom)

hook.Add("InitPostEntity", "FF_InitializeEnvironmentReverb", function()
    timer.Simple(0, sampleRoom)
end)

hook.Add("ShutDown", "FF_ResetEnvironmentReverb", function()
    RunConsoleCommand("room_type", "0")
    RunConsoleCommand("dsp_volume", "1")
end)
