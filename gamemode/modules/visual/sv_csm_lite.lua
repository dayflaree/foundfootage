-- Server authority for the gamemode-owned Lite CSM integration.

local config = FF_CONFIG.CSMLite or {}
if config.Enabled == false then return end

util.AddNetworkString("FF_CSMLite_ReloadLighting")

local DEFAULTS = config.Defaults or {}
local LIGHTSTYLE_LETTERS = "abcdefghijklmnopqrstuvwxyz"

local function retireUpstreamRuntime()
    if not net.Receivers then return end

    net.Receivers.shadowsetting = nil
    net.Receivers.shadowlightstyle = nil
end

local function disableLightEnvironment(entity)
    if not IsValid(entity) or entity:GetClass() ~= "light_environment" then return end

    if tostring(DEFAULTS.c_dis_shb or "1") == "1" then
        entity:Fire("TurnOff")
    else
        entity:Fire("TurnOn")
    end
end

local function applyMapDefaults()
    retireUpstreamRuntime()

    for _, entity in ipairs(ents.FindByClass("light_environment")) do
        disableLightEnvironment(entity)
    end

    local styleIndex = math.Clamp(tonumber(DEFAULTS.c_lightstyle) or 12, 0, 25)
    local styleLetter = LIGHTSTYLE_LETTERS:sub(styleIndex + 1, styleIndex + 1)
    engine.LightStyle(0, styleLetter)

    net.Start("FF_CSMLite_ReloadLighting")
    net.Broadcast()
end

retireUpstreamRuntime()

hook.Add("InitPostEntity", "FF_CSMLite_MapDefaults", function()
    timer.Simple(0, applyMapDefaults)
end)

hook.Add("PostCleanupMap", "FF_CSMLite_CleanupDefaults", function()
    timer.Simple(0, applyMapDefaults)
end)

hook.Add("OnReloaded", "FF_CSMLite_ReloadDefaults", function()
    timer.Simple(0, applyMapDefaults)
end)

hook.Add("OnEntityCreated", "FF_CSMLite_DisableNewLightEnvironment", function(entity)
    if not IsValid(entity) or entity:GetClass() ~= "light_environment" then return end

    timer.Simple(0, function()
        disableLightEnvironment(entity)
    end)
end)
