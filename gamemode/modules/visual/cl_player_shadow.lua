-- Curated adaptation of Workshop 2844439442 (Simple First-Person Player Shadow).
-- The upstream addon mirrors a public cl_playershadow convar into the built-in
-- cl_drawownshadow convar. Found Footage keeps the behavior forced through the
-- central configuration instead of exposing another menu/profile setting.

local config = FF_CONFIG.PlayerShadow or {}
local desired = config.Enabled == false and "0" or "1"

local function applyPlayerShadow()
    local convar = GetConVar("cl_drawownshadow")
    if convar and convar:GetString() == desired then return end

    RunConsoleCommand("cl_drawownshadow", desired)
end

timer.Simple(0, applyPlayerShadow)
hook.Add("InitPostEntity", "FF_EnableFirstPersonPlayerShadow", applyPlayerShadow)
hook.Add("OnReloaded", "FF_ReapplyFirstPersonPlayerShadow", applyPlayerShadow)
