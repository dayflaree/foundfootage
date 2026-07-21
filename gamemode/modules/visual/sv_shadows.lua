-- Fixed, gamemode-owned Source Shadows integration. Client/admin menus and
-- per-user JSON settings are intentionally omitted.

local config = FF_CONFIG.Shadows
if not config.Enabled then return end

util.AddNetworkString("FF_ShadowRefresh")

local shadowControl = nil
local sunEntity = nil
local lastDirection = nil

local function requestClientRefresh()
    net.Start("FF_ShadowRefresh")
    net.Broadcast()
end

local function findOrCreateShadowControl()
    local controls = ents.FindByClass("shadow_control")
    shadowControl = controls[1]

    if not IsValid(shadowControl) then
        shadowControl = ents.Create("shadow_control")
        if not IsValid(shadowControl) then return false end
        shadowControl:Spawn()
        shadowControl:Activate()
    end

    return true
end

local function getConfiguredDirection()
    if config.UseSunDirection and IsValid(sunEntity) then
        local keyValues = sunEntity:GetKeyValues()
        local sunDirection = keyValues and keyValues.sun_dir

        if isvector(sunDirection) then
            local direction = Vector(-sunDirection.x, -sunDirection.y, -sunDirection.z)
            return tostring(direction:Angle())
        end
    end

    local x, y, z = string.match(config.Direction or "", "([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)")
    local direction = Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or -1)
    if direction:IsZero() then
        direction = Vector(0, 0, -1)
    end

    return tostring(direction:Angle())
end

local function applyShadowSettings(forceRefresh)
    if not findOrCreateShadowControl() then return end

    if not IsValid(sunEntity) then
        sunEntity = ents.FindByClass("env_sun")[1]
    end

    shadowControl:SetKeyValue("enableshadowsfromlocallights", "1")
    shadowControl:SetKeyValue("disableallshadows", config.DisableAll and "1" or "0")
    shadowControl:SetKeyValue("color", config.Color)
    shadowControl:SetKeyValue("distance", tostring(config.Distance))

    local direction = getConfiguredDirection()
    if direction ~= lastDirection then
        shadowControl:SetKeyValue("angles", direction)
        lastDirection = direction
        forceRefresh = true
    end

    if forceRefresh then
        requestClientRefresh()
    end
end

hook.Add("InitPostEntity", "FF_InitializeSourceShadows", function()
    sunEntity = ents.FindByClass("env_sun")[1]
    applyShadowSettings(true)
end)

hook.Add("PostCleanupMap", "FF_RestoreSourceShadows", function()
    timer.Simple(0, function()
        shadowControl = nil
        sunEntity = nil
        lastDirection = nil
        applyShadowSettings(true)
    end)
end)

hook.Add("PlayerInitialSpawn", "FF_SyncSourceShadows", function(ply)
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        net.Start("FF_ShadowRefresh")
        net.Send(ply)
    end)
end)

timer.Create("FF_UpdateSunShadowDirection", 2, 0, function()
    applyShadowSettings(false)
end)
