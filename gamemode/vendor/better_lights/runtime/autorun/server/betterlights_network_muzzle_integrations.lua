if SERVER then
    local BL = BetterLights
    local MF = BL.MuzzleFlash

    local ARCCW_ATTACHMENTS = { "muzzle", "1" }
    local MWBASE_ATTACHMENTS = { "muzzle", "tag_flash", "tag_muzzle", "tag_barrel", "tag_tip", "tip" }
    local CW2_ATTACHMENTS = { "muzzle", "1" }
    local TFA_ATTACHMENTS = { "muzzle", "1" }
    local WEAPON_WRAPPER_VERSION = 2
    local getWeaponBase = MF.GetWeaponBase

    local function isArc9Weapon(weapon)
        if not IsValid(weapon) then return false end
        if weapon.ARC9 == true then return true end

        local base = getWeaponBase(weapon)
        if base == "arc9_base" or string.find(base, "arc9", 1, true) ~= nil then return true end

        if weapons and weapons.IsBasedOn and weapon.GetClass then
            local className = weapon:GetClass()
            if className ~= "" and weapons.IsBasedOn(className, "arc9_base") then return true end
        end

        return false
    end

    local function isArcCWWeapon(weapon)
        if not IsValid(weapon) then return false end
        if weapon.ArcCW == true then return true end

        local base = getWeaponBase(weapon)
        if base == "arccw_base" or string.find(base, "arccw", 1, true) ~= nil then return true end

        if weapons and weapons.IsBasedOn and weapon.GetClass then
            local className = weapon:GetClass()
            if className ~= "" and weapons.IsBasedOn(className, "arccw_base") then return true end
        end

        return false
    end

    local function isMwBaseWeapon(weapon)
        if not IsValid(weapon) then return false end
        if getWeaponBase(weapon) == "mg_base" then return true end

        if weapons and weapons.IsBasedOn and weapon.GetClass then
            local className = weapon:GetClass()
            if className ~= "" and weapons.IsBasedOn(className, "mg_base") then return true end
        end

        return isfunction(weapon.GetStoredAttachment)
            and isfunction(weapon.PlayViewModelAnimation)
            and isfunction(weapon.GetAllAttachmentsInUse)
    end

    local function isBasedOn(weapon, base)
        if not (IsValid(weapon) and weapons and weapons.IsBasedOn and weapon.GetClass) then return false end

        local className = weapon:GetClass()
        return className ~= "" and weapons.IsBasedOn(className, base)
    end

    local function isCW2Weapon(weapon)
        if not IsValid(weapon) then return false end
        if weapon.CW20Weapon == true then return true end

        return getWeaponBase(weapon) == "cw_base" or isBasedOn(weapon, "cw_base")
    end

    local function isCW2MeleeWeapon(weapon)
        if not isCW2Weapon(weapon) then return false end

        return getWeaponBase(weapon) == "cw_melee_base" or isBasedOn(weapon, "cw_melee_base")
    end

    local function isCW2NonFirearm(weapon)
        return isCW2MeleeWeapon(weapon)
            or (isCW2Weapon(weapon) and (getWeaponBase(weapon) == "cw_grenade_base" or isBasedOn(weapon, "cw_grenade_base")))
    end

    local function isTFAWeapon(weapon)
        if not IsValid(weapon) then return false end
        if weapon.IsTFAWeapon == true then return true end

        local base = getWeaponBase(weapon)
        return base == "tfa_gun_base"
            or base == "tfa_melee_base"
            or isBasedOn(weapon, "tfa_gun_base")
            or isBasedOn(weapon, "tfa_melee_base")
    end

    MF.ClearRulesBySource("integration")

    MF.RegisterAdapter("arc9", {
        matches = isArc9Weapon
    })

    MF.RegisterAdapter("arccw", {
        matches = isArcCWWeapon
    })

    MF.RegisterAdapter("mwbase", {
        matches = isMwBaseWeapon
    })

    MF.RegisterAdapter("cw2", {
        matches = isCW2Weapon,
        shouldHandleBullet = function(_, weapon)
            return not isCW2NonFirearm(weapon)
        end
    })

    MF.RegisterAdapter("tfa", {
        matches = isTFAWeapon,
        shouldHandleBullet = function()
            return false
        end
    })

    MF.RegisterWeaponRule({
        id = "builtin_mwbase",
        adapter = "mwbase",
        profile = "default",
        priority = -900,
        attachments = MWBASE_ATTACHMENTS,
        source = "integration"
    })

    MF.RegisterWeaponRule({
        id = "builtin_arccw",
        adapter = "arccw",
        profile = "default",
        priority = -875,
        attachments = ARCCW_ATTACHMENTS,
        source = "integration"
    })

    MF.RegisterWeaponRule({
        id = "builtin_cw2",
        adapter = "cw2",
        profile = "default",
        priority = -850,
        attachments = CW2_ATTACHMENTS,
        source = "integration"
    })

    MF.RegisterWeaponRule({
        id = "builtin_tfa",
        adapter = "tfa",
        profile = "default",
        priority = -825,
        attachments = TFA_ATTACHMENTS,
        source = "integration"
    })

    local function installWeaponWrapper(weapon, prefix, methodName, callback)
        local current = weapon[methodName]
        if not isfunction(current) then return end

        local versionKey = prefix .. "Version"
        local originalKey = prefix .. "Original"
        local downstreamKey = prefix .. "Downstream"
        local wrapperKey = prefix .. "Wrapper"
        local previousWrapper = weapon[wrapperKey]
        if weapon[versionKey] == WEAPON_WRAPPER_VERSION and current == previousWrapper then return end

        local downstream = current
        if current == previousWrapper then
            if isfunction(weapon[downstreamKey]) then
                downstream = weapon[downstreamKey]
            elseif isfunction(weapon[originalKey]) then
                downstream = weapon[originalKey]
            end
        end

        local original = isfunction(weapon[originalKey]) and weapon[originalKey] or downstream
        local wrapper = function(self, ...)
            return callback(downstream, self, ...)
        end

        weapon[versionKey] = WEAPON_WRAPPER_VERSION
        weapon[originalKey] = original
        weapon[downstreamKey] = downstream
        weapon[wrapperKey] = wrapper
        weapon[methodName] = wrapper
    end

    local function wrapArc9DoEffects(weapon)
        if not isArc9Weapon(weapon) then return end

        installWeaponWrapper(weapon, "BetterLightsArc9DoEffects", "DoEffects", function(original, instance, ...)
            local ret = original(instance, ...)
            MF.SendAdapterMuzzleFlash(instance, "arc9")
            return ret
        end)
    end

    local function wrapArcCWDoEffects(weapon)
        if not isArcCWWeapon(weapon) then return end

        installWeaponWrapper(weapon, "BetterLightsArcCWDoEffects", "DoEffects", function(original, instance, ...)
            local ret = original(instance, ...)
            MF.SendAdapterMuzzleFlash(instance, "arccw")
            return ret
        end)
    end

    local function wrapMwBaseProjectiles(weapon)
        if not isMwBaseWeapon(weapon) then return end

        installWeaponWrapper(weapon, "BetterLightsMwBaseProjectiles", "Projectiles", function(original, instance, ...)
            local ret = original(instance, ...)
            MF.SendAdapterMuzzleFlash(instance, "mwbase")
            return ret
        end)
    end

    local function wrapCW2M203(weapon)
        if not isCW2Weapon(weapon) then return end

        installWeaponWrapper(weapon, "BetterLightsCW2FireM203", "fireM203", function(original, instance, ...)
            local ret = original(instance, ...)
            MF.SendAdapterMuzzleFlash(instance, "cw2")
            return ret
        end)
    end

    local function wrapAdapterWeapon(weapon)
        if not (IsValid(weapon) and weapon.IsWeapon and weapon:IsWeapon()) then return end

        wrapArc9DoEffects(weapon)
        wrapArcCWDoEffects(weapon)
        wrapMwBaseProjectiles(weapon)
        wrapCW2M203(weapon)
    end

    local function scanAdapterWeapons()
        for _, ent in ents.Iterator() do
            wrapAdapterWeapon(ent)
        end
    end

    hook.Add("OnEntityCreated", "BetterLights_MuzzleFlash_Adapters_Server", function(ent)
        timer.Simple(0, function()
            wrapAdapterWeapon(ent)
        end)
    end)

    hook.Add("TFA_MuzzleFlash", "BetterLights_MuzzleFlash_TFA_Server", function(weapon)
        if not isTFAWeapon(weapon) then return end

        MF.SendAdapterMuzzleFlash(weapon, "tfa")
    end)

    hook.Add("InitPostEntity", "BetterLights_MuzzleFlash_Adapters_Init_Server", scanAdapterWeapons)
    timer.Create("BetterLights_MuzzleFlash_Adapters_Scan_Server", 2, 0, scanAdapterWeapons)
end
