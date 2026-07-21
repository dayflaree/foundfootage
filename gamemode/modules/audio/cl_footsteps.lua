-- Client compatibility for the integrated DSteps/reverb server runtime.
-- Removes mounted Workshop copies and suppresses Source footsteps while the
-- server broadcasts the quieter material-aware replacements.

local function removeMountedFootstepHooks()
    local hooks = {
        { "PlayerFootstep", "zzzzzz_dstep_main" },
        { "EntityEmitSound", "zzzzz_dsteps_maskfootstep" },
        { "OnPlayerHitGround", "dstep_fall" },
        { "PlayerTick", "dstep_fidget" },
        { "OnEntityCreated", "FootstepReverbs_sv" },
        { "EntityRemoved", "FootstepReverbs_sv" },
        { "Think", "FootstepReverbs_sv" },
        { "EntityEmitSound", "FootstepReverbs_sv" },
        { "PlayerFootstep", "FootstepReverbs_sv" },
    }

    for _, entry in ipairs(hooks) do
        hook.Remove(entry[1], entry[2])
    end
end

removeMountedFootstepHooks()
timer.Simple(0, removeMountedFootstepHooks)
hook.Add("InitPostEntity", "FF_RemoveMountedFootstepHooks", removeMountedFootstepHooks)
hook.Add("OnReloaded", "FF_RemoveMountedFootstepHooks", removeMountedFootstepHooks)

hook.Add("PlayerFootstep", "FF_SuppressClientSourceFootsteps", function(_, _, _, soundName)
    local lowerSound = string.lower(soundName or "")
    if string.find(lowerSound, "ladder", 1, true)
        or string.find(lowerSound, "chainlink", 1, true) then
        return
    end

    return true
end)
