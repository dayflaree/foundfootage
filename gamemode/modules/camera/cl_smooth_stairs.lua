-- Gamemode-owned adaptation of Workshop 3461074552 (Smooth Out Stairs).
-- The original requires Extended CalcView. Found Footage keeps one CalcView
-- owner, so this module exposes a pure origin transform for cl_camera.lua.

local cameraConfig = FF_CONFIG.Camera or {}
local config = cameraConfig.SmoothStairs or {}

local initialized = false
local lastViewOffsetZ = 0
local lastOriginZ = 0
local verticalOffset = 0

local function retireUpstreamRuntime()
    hook.Remove("CalcViewEx", "apply_step_smoothening")
    hook.Remove("CalcViewModelViewEx", "apply_step_smoothening")

    local initHooks = hook.GetTable().InitPostEntity or {}
    for identifier in pairs(initHooks) do
        identifier = tostring(identifier)
        if string.StartWith(identifier, "MissingAddonMessage") then
            hook.Remove("InitPostEntity", identifier)
        end
    end
end

local function resetState()
    initialized = false
    lastViewOffsetZ = 0
    lastOriginZ = 0
    verticalOffset = 0
end

function FF_ApplySmoothStairs(ply, origin)
    if config.Enabled == false or not IsValid(ply) or ply:InVehicle() then
        resetState()
        return origin
    end

    local viewOffset = ply:GetCurrentViewOffset()
    local viewOffsetZ = viewOffset and viewOffset.z or 0
    local originZ = origin.z

    if not initialized then
        initialized = true
        lastViewOffsetZ = viewOffsetZ
        lastOriginZ = originZ
        return origin
    end

    local difference = originZ - lastOriginZ + (lastViewOffsetZ - viewOffsetZ)
    lastViewOffsetZ = viewOffsetZ
    lastOriginZ = originZ

    local groundEntity = ply:GetGroundEntity()
    if not IsValid(groundEntity) or groundEntity:GetMoveType() ~= MOVETYPE_NONE then
        difference = 0
    end

    local speed = math.max(tonumber(config.Speed) or 1, 0)
    local response = math.max(tonumber(config.Response) or 10, 0)
    local alpha = math.Clamp(FrameTime() * response * speed, 0, 1)
    verticalOffset = Lerp(alpha, verticalOffset + difference, 0)

    return origin - vector_up * verticalOffset
end

retireUpstreamRuntime()
hook.Add("InitPostEntity", "FF_SmoothStairsReset", resetState)
hook.Add("OnReloaded", "FF_SmoothStairsReset", resetState)
hook.Add("OnReloaded", "FF_SmoothStairsRetireUpstream", retireUpstreamRuntime)
hook.Add("ShutDown", "FF_SmoothStairsReset", resetState)
