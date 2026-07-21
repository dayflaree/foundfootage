if SERVER then
    local BL = BetterLights
    local EXP = BL.Explosions
    local CW2_FLASHBANG_FUSE_TIME = 2.5
    local CW2_FLASHBANG_WRAPPER_VERSION = 1

    EXP.RegisterProfile("weapon_base_explosion", {
        classes = {
            "cw_40mm_explosive",
            "cw_grenade_thrown",
            "tfa_exp_base",
            "tfa_exp_contact",
            "tfa_exp_timed"
        },
        source = "integration"
    })

    EXP.RegisterProfile("rpg", {
        classes = { "tfa_exp_rocket" },
        source = "integration"
    })

    EXP.RegisterProfile("cw2_flashbang", {
        classes = { "cw_flash_thrown" },
        source = "integration"
    })

    local function getCW2FlashbangEntityTable()
        if not (scripted_ents and isfunction(scripted_ents.GetStored)) then return nil end

        local stored = scripted_ents.GetStored("cw_flash_thrown")
        if type(stored) ~= "table" then return nil end
        if type(stored.t) == "table" then return stored.t end
        return stored
    end

    local function installCW2FlashbangFuseWrapper()
        local entityTable = getCW2FlashbangEntityTable()
        if not entityTable then return end

        local current = entityTable.Fuse
        if not isfunction(current) then return end

        local previousWrapper = entityTable.BetterLightsCW2FlashbangFuseWrapper
        if entityTable.BetterLightsCW2FlashbangFuseVersion == CW2_FLASHBANG_WRAPPER_VERSION and current == previousWrapper then return end

        local original = current
        if current == previousWrapper and isfunction(entityTable.BetterLightsCW2FlashbangFuseOriginal) then
            original = entityTable.BetterLightsCW2FlashbangFuseOriginal
        end

        local wrapper = function(self, ...)
            local lightDelay = math.max(0, CW2_FLASHBANG_FUSE_TIME - engine.TickInterval())
            timer.Simple(lightDelay, function()
                if not IsValid(self) then return end

                EXP.Emit("cw2_flashbang", self:GetPos(), BL.EXPLOSION_SOURCE_EFFECT)
            end)

            return original(self, ...)
        end

        entityTable.BetterLightsCW2FlashbangFuseVersion = CW2_FLASHBANG_WRAPPER_VERSION
        entityTable.BetterLightsCW2FlashbangFuseOriginal = original
        entityTable.BetterLightsCW2FlashbangFuseWrapper = wrapper
        entityTable.Fuse = wrapper
    end

    installCW2FlashbangFuseWrapper()

    hook.Add("InitPostEntity", "BetterLights_CW2FlashbangIntegration_Init", installCW2FlashbangFuseWrapper)
    hook.Add("OnReloaded", "BetterLights_CW2FlashbangIntegration_Reload", function()
        timer.Simple(0, installCW2FlashbangFuseWrapper)
    end)
end
