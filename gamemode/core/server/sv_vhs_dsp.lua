local config = FF_CONFIG.Effects.VHS

local function desiredPreset()
    if config.Enabled ~= false and config.EqualizeSound ~= false then
        return math.max(0, math.floor(tonumber(config.EqualizeDSPPreset) or 14))
    end

    return 1
end

local function applyDSP(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not isfunction(ply.SetDSP) then return end

    ply:SetDSP(desiredPreset(), false)
end

hook.Add("PlayerInitialSpawn", "FF_ApplyInitialVHSDSP", function(ply)
    timer.Simple(1, function()
        applyDSP(ply)
    end)
end)

hook.Add("PlayerSpawn", "FF_ApplySpawnVHSDSP", function(ply)
    timer.Simple(0.25, function()
        applyDSP(ply)
    end)
end)

-- Reapply periodically so explosion/water DSP effects cannot permanently
-- override the forced VHS equalizer profile.
timer.Create("FF_EnforceVHSDSP", 1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        applyDSP(ply)
    end
end)

hook.Add("ShutDown", "FF_ResetVHSDSP", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and isfunction(ply.SetDSP) then
            ply:SetDSP(1, false)
        end
    end
end)
