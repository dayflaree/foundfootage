local config = FF_CONFIG.Effects.Underwater
if not config.Enabled then return end

local wasUnderwater = false
local surfacedAt = 0

hook.Add("Think", "FF_TrackUnderwaterState", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        wasUnderwater = false
        surfacedAt = 0
        return
    end

    local underwater = ply:WaterLevel() >= config.TriggerWaterLevel
    if underwater then
        wasUnderwater = true
    elseif wasUnderwater then
        wasUnderwater = false
        surfacedAt = CurTime()
    end
end)

hook.Add("RenderScreenspaceEffects", "FF_UnderwaterSurfaceBlur", function()
    if surfacedAt <= 0 then return end

    local elapsed = CurTime() - surfacedAt
    if elapsed >= config.Duration then
        surfacedAt = 0
        return
    end

    local fade = 1 - elapsed / config.Duration
    local intensity = math.max(0, config.Intensity * fade)
    DrawBokehDOF(
        config.BlurRadius * intensity,
        config.BlurPasses * intensity,
        config.BlurRadius * 2
    )
end)
