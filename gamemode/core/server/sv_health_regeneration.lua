local playerConfig = FF_CONFIG.Player or {}
local regenerationConfig = playerConfig.HealthRegeneration or {}

if regenerationConfig.Enabled == false then return end

local states = setmetatable({}, { __mode = "k" })

local function resetState(ply)
    if not IsValid(ply) then return end

    local now = CurTime()
    states[ply] = {
        regenerateAt = now,
        lastUpdate = now,
        credit = 0,
    }
end

local function delayRegeneration(ply)
    if not IsValid(ply) then return end

    local now = CurTime()
    local state = states[ply]

    if not state then
        resetState(ply)
        state = states[ply]
    end

    state.regenerateAt = now + math.max(
        tonumber(regenerationConfig.DelayAfterDamage) or 8,
        0
    )
    state.lastUpdate = now
    state.credit = 0
end

hook.Add("PlayerSpawn", "FF_ResetHealthRegeneration", resetState)

hook.Add("EntityTakeDamage", "FF_DelayHealthRegeneration", function(target, damageInfo)
    if not IsValid(target) or not target:IsPlayer() then return end
    if damageInfo:GetDamage() <= 0 then return end

    delayRegeneration(target)
end)

hook.Add("PlayerDeath", "FF_ClearHealthRegeneration", function(ply)
    states[ply] = nil
end)

hook.Add("PlayerDisconnected", "FF_ForgetHealthRegeneration", function(ply)
    states[ply] = nil
end)

local function resetExistingPlayers()
    for _, ply in ipairs(player.GetAll()) do
        resetState(ply)
    end
end

timer.Simple(0, resetExistingPlayers)
hook.Add("OnReloaded", "FF_ResetExistingHealthRegeneration", resetExistingPlayers)

timer.Create(
    "FF_HealthRegeneration",
    math.max(tonumber(regenerationConfig.UpdateInterval) or 0.25, 0.05),
    0,
    function()
        local now = CurTime()
        local regenerationRate = math.max(
            tonumber(regenerationConfig.HealthPerSecond) or 1,
            0
        )

        if regenerationRate <= 0 then return end

        for _, ply in ipairs(player.GetAll()) do
            local state = states[ply]

            if not state then
                resetState(ply)
                state = states[ply]
            end

            local deltaTime = math.Clamp(now - state.lastUpdate, 0, 1)
            state.lastUpdate = now

            if ply:Alive() and now >= state.regenerateAt then
                local maximumHealth = math.max(ply:GetMaxHealth(), 1)
                local currentHealth = ply:Health()

                if currentHealth > 0 and currentHealth < maximumHealth then
                    state.credit = state.credit + regenerationRate * deltaTime

                    local healthToRestore = math.floor(state.credit)
                    if healthToRestore > 0 then
                        local restoredHealth = math.min(
                            currentHealth + healthToRestore,
                            maximumHealth
                        )

                        ply:SetHealth(restoredHealth)
                        state.credit = state.credit - (restoredHealth - currentHealth)
                    end
                else
                    state.credit = 0
                end
            else
                state.credit = 0
            end
        end
    end
)