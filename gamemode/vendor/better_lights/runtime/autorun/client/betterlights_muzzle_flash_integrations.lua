if CLIENT then
    local BL = BetterLights
    local MF = BL.MuzzleFlash

    local ARCCW_ATTACHMENTS = { "muzzle", "1" }
    local MWBASE_ATTACHMENTS = { "muzzle", "tag_flash", "tag_muzzle", "tag_barrel", "tag_tip", "tip" }
    local CW2_ATTACHMENTS = { "muzzle", "1" }
    local TFA_ATTACHMENTS = { "muzzle", "1" }
    local WEAPON_WRAPPER_VERSION = 2
    local TFA_MUZZLE_COLORS = {
        tfa_muzzleflash_cryo = "tfa_cryo",
        tfa_muzzleflash_energy = "tfa_energy",
        tfa_muzzleflash_gauss = "tfa_gauss",
        tfa_muzzleflash_incendiary = "tfa_incendiary",
        tfa_muzzleflash_sniper_energy = "tfa_energy"
    }
    local TFA_NATIVE_LIGHT_EFFECTS = {
        tfa_muzzleflash_cryo = true,
        tfa_muzzleflash_energy = true,
        tfa_muzzleflash_gauss = true,
        tfa_muzzleflash_generic = true,
        tfa_muzzleflash_incendiary = true,
        tfa_muzzleflash_pistol = true,
        tfa_muzzleflash_revolver = true,
        tfa_muzzleflash_rifle = true,
        tfa_muzzleflash_shotgun = true,
        tfa_muzzleflash_smg = true,
        tfa_muzzleflash_sniper = true,
        tfa_muzzleflash_sniper_energy = true
    }

    local isVector = MF.IsVector
    local getAttachmentById = MF.GetAttachmentById
    local getAttachmentByName = MF.GetAttachmentByName
    local getFirstPersonAttachmentFallback = MF.GetFirstPersonAttachmentFallback
    local buildAttachmentCandidates = MF.BuildAttachmentCandidates
    local getWeaponBase = MF.GetWeaponBase

    MF.ClearRulesBySource("integration")
    MF.ClearColorTagsBySource("integration")

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

        local base = getWeaponBase(weapon)
        return base == "cw_base" or isBasedOn(weapon, "cw_base")
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

    local function isTFAMeleeWeapon(weapon)
        if not isTFAWeapon(weapon) then return false end
        if weapon.IsMelee == true or weapon.IsKnife == true then return true end

        local base = getWeaponBase(weapon)
        return base == "tfa_melee_base"
            or string.find(base, "tfa_melee", 1, true) ~= nil
            or string.find(base, "tfa_knife", 1, true) ~= nil
            or isBasedOn(weapon, "tfa_melee_base")
    end

    local function isTFANonFirearm(weapon)
        return isTFAMeleeWeapon(weapon)
            or (IsValid(weapon) and (weapon.IsGrenade == true or weapon.IsBow == true))
    end

    local function readTFAStat(weapon, key, fallback)
        if not (IsValid(weapon) and isfunction(weapon.GetStatL)) then return fallback end

        local ok, value = pcall(weapon.GetStatL, weapon, key, fallback)
        if ok and value ~= nil then return value end
        return fallback
    end

    local function getTFAMuzzleEffect(weapon)
        if not IsValid(weapon) then return "" end

        local silenced = false
        if IsValid(weapon) and isfunction(weapon.GetSilenced) then
            local ok, value = pcall(weapon.GetSilenced, weapon)
            silenced = ok and value == true
        end

        if silenced then
            local effect = readTFAStat(weapon, "MuzzleFlashEffectSilenced", nil)
            if effect ~= nil and effect ~= "" then return string.lower(tostring(effect)) end
        end

        return string.lower(tostring(readTFAStat(weapon, "MuzzleFlashEffect", weapon.MuzzleFlashEffect or "")))
    end

    local function usesTFASilencedMuzzleEffect(weapon)
        if not (IsValid(weapon) and isfunction(weapon.GetSilenced)) then return false end

        local ok, silenced = pcall(weapon.GetSilenced, weapon)
        if not ok or silenced ~= true then return false end

        local effect = readTFAStat(weapon, "MuzzleFlashEffectSilenced", nil)
        return effect ~= nil and effect ~= ""
    end

    local function arc9OwnLightEnabled(isLocal)
        local light = GetConVar("arc9_muzzle_light")
        if not (light and light:GetBool()) then return false end
        if isLocal then return true end

        local others = GetConVar("arc9_muzzle_others")
        return others and others:GetBool()
    end

    local function readArcCWBuffOverride(weapon, key, fallback)
        if not (IsValid(weapon) and isfunction(weapon.GetBuff_Override)) then return fallback end

        local ok, value = pcall(weapon.GetBuff_Override, weapon, key, fallback)
        if ok then return value end
        return fallback
    end

    local function readArcCWMuzzleAttachmentId(weapon)
        local attachmentId = readArcCWBuffOverride(weapon, "Override_MuzzleEffectAttachment", weapon.MuzzleEffectAttachment or 1)
        attachmentId = tonumber(attachmentId)
        if attachmentId and attachmentId > 0 then return attachmentId end

        return 1
    end

    local function readArcCWMuzzleDevice(weapon, worldModel)
        if not (IsValid(weapon) and isfunction(weapon.GetMuzzleDevice)) then return nil end

        local ok, device = pcall(weapon.GetMuzzleDevice, weapon, worldModel)
        if ok and IsValid(device) then return device end
        return nil
    end

    local function arcCWHasNoFlash(weapon)
        if not IsValid(weapon) then return false end

        local noFlash = weapon.NoFlash
        if weapon.BetterLightsArcCWMuzzleLightReplaced then
            noFlash = weapon.BetterLightsArcCWOriginalNoFlash
        end

        if noFlash == true then return true end
        if readArcCWBuffOverride(weapon, "Silencer", false) then return true end
        if readArcCWBuffOverride(weapon, "FlashHider", false) then return true end

        return false
    end

    local function shouldReplaceArcCWMuzzleLight()
        if not BL.IsEnabled() then return false end

        local muzzleCvar = GetConVar("betterlights_muzzle_enable")
        return not muzzleCvar or muzzleCvar:GetBool()
    end

    local function refreshArcCWMuzzleLightReplacement(weapon)
        if not isArcCWWeapon(weapon) then return end

        if shouldReplaceArcCWMuzzleLight() then
            if not weapon.BetterLightsArcCWMuzzleLightReplaced then
                weapon.BetterLightsArcCWOriginalNoFlash = weapon.NoFlash
                weapon.BetterLightsArcCWMuzzleLightReplaced = true
            end

            weapon.NoFlash = true
            return
        end

        if not weapon.BetterLightsArcCWMuzzleLightReplaced then return end

        weapon.NoFlash = weapon.BetterLightsArcCWOriginalNoFlash
        weapon.BetterLightsArcCWOriginalNoFlash = nil
        weapon.BetterLightsArcCWMuzzleLightReplaced = nil
    end

    local function readArc9MuzzleDevice(weapon, worldModel)
        if not (IsValid(weapon) and isfunction(weapon.GetMuzzleDevice)) then return nil end

        local ok, device = pcall(function()
            return weapon:GetMuzzleDevice(worldModel)
        end)

        if ok then return device end
        return nil
    end

    local function useArc9WorldModel(isLocal)
        if not isLocal then return true end

        local localPlayer = LocalPlayer()
        return IsValid(localPlayer)
            and localPlayer.ShouldDrawLocalPlayer
            and localPlayer:ShouldDrawLocalPlayer()
    end

    local function readArc9ProcessedValue(weapon, key, fallback)
        if not (IsValid(weapon) and isfunction(weapon.GetProcessedValue)) then return fallback end

        local ok, value = pcall(weapon.GetProcessedValue, weapon, key, true)
        if ok and value ~= nil then return value end
        return fallback
    end

    local function arc9HasNoFlash(weapon, isLocal)
        if not IsValid(weapon) then return false end
        if readArc9ProcessedValue(weapon, "NoMuzzleEffect", weapon.NoMuzzleEffect) == true then return true end
        if readArc9ProcessedValue(weapon, "NoFlash", weapon.NoFlash) == true then return true end
        if readArc9ProcessedValue(weapon, "Silencer", false) == true then return true end

        local device = readArc9MuzzleDevice(weapon, useArc9WorldModel(isLocal))
        if type(device) == "table" then
            return device.NoMuzzleEffect == true or device.NoFlash == true or device.Silencer == true
        end

        return false
    end

    local function resolveArc9Muzzle(weapon, isLocal)
        if not IsValid(weapon) then return nil end

        local worldModel = useArc9WorldModel(isLocal)
        local attachmentId
        if isfunction(weapon.GetQCAMuzzle) then
            local ok, attachment = pcall(function()
                return weapon:GetQCAMuzzle()
            end)

            if ok and isVector(attachment) then return attachment end
            if ok and type(attachment) == "table" and isVector(attachment.Pos) then return attachment.Pos end
            if ok then attachmentId = tonumber(attachment) end
        end

        if worldModel and isfunction(weapon.ShouldTPIK) then
            local ok, shouldTPIK = pcall(weapon.ShouldTPIK, weapon)
            if ok and shouldTPIK == false then attachmentId = 1 end
        end

        local device = readArc9MuzzleDevice(weapon, worldModel)
        local pos = getAttachmentById(device, attachmentId or 1)
        if not pos and IsValid(device) and device.GetPos then
            pos = device:GetPos()
        elseif not pos and type(device) == "table" and isVector(device.Pos) then
            pos = device.Pos
        end

        pos = pos or getAttachmentById(weapon, attachmentId or 1)
        local firstPersonFallback = not worldModel and getFirstPersonAttachmentFallback(LocalPlayer()) or nil
        if firstPersonFallback and pos then return firstPersonFallback end
        return pos
    end

    local function resolveArcCWMuzzle(weapon, shooter)
        if not IsValid(weapon) then return nil end

        local localPlayer = LocalPlayer()
        local useViewModel = shooter == localPlayer and IsValid(shooter) and not shooter:ShouldDrawLocalPlayer()
        local worldModel = not useViewModel
        local attachmentId = worldModel and 1 or readArcCWMuzzleAttachmentId(weapon)
        local muzzleDevice = readArcCWMuzzleDevice(weapon, worldModel)
        local firstPersonFallback = getFirstPersonAttachmentFallback(shooter)

        if firstPersonFallback then
            if getAttachmentById(muzzleDevice, attachmentId) or getAttachmentById(weapon, attachmentId) then
                return firstPersonFallback
            end

            return nil
        end

        return getAttachmentById(muzzleDevice, attachmentId) or getAttachmentById(weapon, attachmentId)
    end

    local function buildMwBaseAttachmentCandidates(attachments)
        local out = buildAttachmentCandidates(attachments)

        for i = 1, #MWBASE_ATTACHMENTS do
            out[#out + 1] = MWBASE_ATTACHMENTS[i]
        end

        return out
    end

    local function getMwBaseFindAttachmentPos(ent, attachmentName)
        if not (IsValid(ent) and isfunction(ent.FindAttachment)) then return nil end

        local ok, attachmentEnt, attachmentId = pcall(function()
            return ent:FindAttachment(tostring(attachmentName))
        end)

        if not (ok and IsValid(attachmentEnt)) then return nil end
        return getAttachmentById(attachmentEnt, attachmentId)
    end

    local function resolveMwBaseAttachment(ent, candidates, depth)
        if not IsValid(ent) then return nil end

        for i = 1, #candidates do
            local candidate = candidates[i]
            local pos

            if type(candidate) == "number" then
                pos = getAttachmentById(ent, candidate)
            else
                pos = getMwBaseFindAttachmentPos(ent, candidate) or getAttachmentByName(ent, candidate)
                if not pos then
                    pos = getAttachmentById(ent, tonumber(candidate))
                end
            end

            if pos then return pos end
        end

        if depth >= 3 or not ent.GetChildren then return nil end

        for _, child in ipairs(ent:GetChildren()) do
            local pos = resolveMwBaseAttachment(child, candidates, depth + 1)
            if pos then return pos end
        end

        return nil
    end

    local function getMwBaseViewModel(weapon)
        if not (IsValid(weapon) and weapon.GetViewModel) then return nil end

        local viewModel = weapon:GetViewModel()
        if IsValid(viewModel) then return viewModel end
        return nil
    end

    local function resolveMwBaseMuzzle(payload)
        local candidates = buildMwBaseAttachmentCandidates(payload.attachments)
        local viewModel = getMwBaseViewModel(payload.weapon)
        local firstPersonFallback = getFirstPersonAttachmentFallback(payload.shooter)

        if firstPersonFallback then
            if resolveMwBaseAttachment(viewModel, candidates, 0) or resolveMwBaseAttachment(payload.weapon, candidates, 0) then
                return firstPersonFallback
            end

            return nil
        end

        local pos = resolveMwBaseAttachment(payload.weapon, candidates, 0)
        if pos then return pos end

        return resolveMwBaseAttachment(viewModel, candidates, 0)
    end

    local function getCW2M203Muzzle(weapon)
        if not (IsValid(weapon) and type(weapon.AttachmentModelsVM) == "table") then return nil end

        local modelData = weapon.AttachmentModelsVM.md_m203
        local model = type(modelData) == "table" and modelData.ent or nil
        return getAttachmentByName(model, "1") or getAttachmentById(model, 1)
    end

    local function resolveCW2Muzzle(payload)
        local weapon = payload.weapon
        if not IsValid(weapon) then return nil end

        local firstPersonFallback = getFirstPersonAttachmentFallback(payload.shooter)
        local isM203Shot = payload.sourceKind == BL.MUZZLE_SOURCE_ADAPTER
        local m203Muzzle = isM203Shot and firstPersonFallback and getCW2M203Muzzle(weapon) or nil
        if firstPersonFallback then
            if m203Muzzle then return firstPersonFallback end

            if isfunction(weapon.getMuzzlePosition) then
                local ok, attachment = pcall(weapon.getMuzzlePosition, weapon)
                if ok and type(attachment) == "table" and isVector(attachment.Pos) then
                    return firstPersonFallback
                end
            end

            local viewModel = IsValid(weapon.CW_VM) and weapon.CW_VM or payload.shooter:GetViewModel()
            local attachmentName = weapon.MuzzleAttachmentName or weapon.MuzzleAttachment or "muzzle"
            if getAttachmentByName(viewModel, attachmentName) or getAttachmentById(viewModel, tonumber(attachmentName)) then
                return firstPersonFallback
            end

            return nil
        end

        local source = weapon
        if isfunction(weapon.getMuzzleModel) then
            local ok, model = pcall(weapon.getMuzzleModel, weapon)
            if ok and IsValid(model) then source = model end
        elseif IsValid(weapon.WMEnt) then
            source = weapon.WMEnt
        end

        local attachmentId = tonumber(weapon.WorldMuzzleAttachmentID)
        return getAttachmentById(source, attachmentId)
            or getAttachmentByName(source, weapon.MuzzleAttachmentName or "muzzle")
            or getAttachmentById(source, 1)
    end

    local function resolveTFAMuzzle(payload)
        local weapon = payload.weapon
        if not IsValid(weapon) then return nil end

        if isfunction(weapon.UpdateMuzzleAttachment) then
            pcall(weapon.UpdateMuzzleAttachment, weapon)
        end

        local attachment
        if isfunction(weapon.GetMuzzlePos) then
            local ok, value = pcall(weapon.GetMuzzlePos, weapon)
            if ok and type(value) == "table" and isVector(value.Pos) then
                attachment = value.Pos
            end
        end

        local firstPersonFallback = getFirstPersonAttachmentFallback(payload.shooter)
        if firstPersonFallback and attachment then return firstPersonFallback end
        if attachment then return attachment end

        local attachmentId
        if isfunction(weapon.GetMuzzleAttachment) then
            local ok, value = pcall(weapon.GetMuzzleAttachment, weapon)
            if ok then attachmentId = tonumber(value) end
        end

        local source = weapon
        if firstPersonFallback then
            source = IsValid(weapon.OwnerViewModel) and weapon.OwnerViewModel or payload.shooter:GetViewModel()
        end

        if firstPersonFallback and getAttachmentById(source, attachmentId or 1) then return firstPersonFallback end
        return getAttachmentById(source, attachmentId or 1)
    end

    local function shouldReplaceNativeMuzzleLight()
        if not BL.IsEnabled() then return false end

        local muzzleCvar = GetConVar("betterlights_muzzle_enable")
        return not muzzleCvar or muzzleCvar:GetBool()
    end

    local function expireNativeDLight(id)
        id = tonumber(id)
        if not id then return end

        local light = DynamicLight(id)
        if not light then return end

        local dieTime = CurTime() + 0.001
        light.brightness = 0
        light.size = 0
        light.dietime = dieTime
        light.Brightness = 0
        light.Size = 0
        light.DieTime = dieTime
    end

    local function clearCW2MuzzleLight(weapon)
        if not shouldReplaceNativeMuzzleLight() then return end
        if isCW2NonFirearm(weapon) then return end
        if type(weapon.dt) == "table" and weapon.dt.Suppressed == true then return end

        expireNativeDLight(weapon:EntIndex())
    end

    local function clearTFAMuzzleLight(weapon)
        if not shouldReplaceNativeMuzzleLight() then return end

        local effect = getTFAMuzzleEffect(weapon)
        if not TFA_NATIVE_LIGHT_EFFECTS[effect] then return end

        local owner = weapon.GetOwner and weapon:GetOwner() or nil
        if effect == "tfa_muzzleflash_gauss" then
            expireNativeDLight(weapon:EntIndex())
        elseif IsValid(owner) then
            expireNativeDLight(owner:EntIndex())
        end
    end

    local function queueTFAMuzzleLightCleanup(weapon)
        if not IsValid(weapon) then return end

        clearTFAMuzzleLight(weapon)

        local frame = FrameNumber()
        if weapon.BetterLightsTFAMuzzleCleanupFrame == frame then return end
        weapon.BetterLightsTFAMuzzleCleanupFrame = frame

        timer.Simple(0, function()
            if IsValid(weapon) then clearTFAMuzzleLight(weapon) end
        end)
    end

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

    local function wrapCW2MuzzleEffects(weapon)
        if not isCW2Weapon(weapon) then return end

        installWeaponWrapper(weapon, "BetterLightsCW2CreateMuzzle", "CreateMuzzle", function(original, instance, ...)
            local ret = original(instance, ...)
            clearCW2MuzzleLight(instance)
            return ret
        end)

        installWeaponWrapper(weapon, "BetterLightsCW2FireM203", "fireM203", function(original, instance, firstTimePrediction, ...)
            local ret = original(instance, firstTimePrediction, ...)
            if firstTimePrediction == false then return ret end
            if IsFirstTimePredicted and not IsFirstTimePredicted() then return ret end

            MF.HandleAdapterShot(instance, "cw2")
            return ret
        end)
    end

    local function wrapTFAMuzzleEffects(weapon)
        if not isTFAWeapon(weapon) then return end

        installWeaponWrapper(weapon, "BetterLightsTFAMuzzleFlashCustom", "MuzzleFlashCustom", function(original, instance, ...)
            local ret = original(instance, ...)
            if ret ~= nil then return ret end

            clearTFAMuzzleLight(instance)
            MF.HandleAdapterShot(instance, "tfa")
            return ret
        end)
    end

    MF.RegisterAdapter("arc9", {
        matches = isArc9Weapon,
        suppress = function(payload)
            local isLocal = payload.shooter == LocalPlayer()
            if arc9OwnLightEnabled(isLocal) then return true end
            return arc9HasNoFlash(payload.weapon, isLocal)
        end,
        resolve = function(payload)
            return resolveArc9Muzzle(payload.weapon, payload.shooter == LocalPlayer())
        end
    })

    MF.RegisterAdapter("arccw", {
        matches = isArcCWWeapon,
        suppress = function(payload)
            return arcCWHasNoFlash(payload.weapon)
        end,
        resolve = function(payload)
            return resolveArcCWMuzzle(payload.weapon, payload.shooter)
        end
    })

    MF.RegisterAdapter("mwbase", {
        matches = isMwBaseWeapon,
        resolve = resolveMwBaseMuzzle
    })

    MF.RegisterAdapter("cw2", {
        matches = isCW2Weapon,
        shouldHandleBullet = function(_, weapon)
            return not isCW2NonFirearm(weapon)
        end,
        suppress = function(payload)
            local weapon = payload.weapon
            if not IsValid(weapon) then return false end
            if isCW2NonFirearm(weapon) then return true end
            if payload.sourceKind == BL.MUZZLE_SOURCE_ADAPTER then return false end
            if weapon.MuzzleEffect == nil or weapon.MuzzleEffect == false or weapon.MuzzleEffect == "" then return true end

            return type(weapon.dt) == "table" and weapon.dt.Suppressed == true
        end,
        resolve = resolveCW2Muzzle
    })

    MF.RegisterAdapter("tfa", {
        matches = isTFAWeapon,
        shouldHandleBullet = function()
            return false
        end,
        suppress = function(payload)
            local weapon = payload.weapon
            if not IsValid(weapon) then return false end
            if isTFANonFirearm(weapon) then return true end
            if readTFAStat(weapon, "MuzzleFlashEnabled", weapon.MuzzleFlashEnabled) == false then return true end
            if usesTFASilencedMuzzleEffect(weapon) then return true end

            local effect = getTFAMuzzleEffect(weapon)
            return effect == ""
                or effect == "tfa_muzzleflash_silenced"
                or TFA_NATIVE_LIGHT_EFFECTS[effect] ~= true
        end,
        resolve = resolveTFAMuzzle,
        selectProfile = function(payload, rule)
            queueTFAMuzzleLightCleanup(payload.weapon)
            if not (rule and rule.id == "builtin_tfa") then return nil end

            return {
                colorTag = TFA_MUZZLE_COLORS[getTFAMuzzleEffect(payload.weapon)]
            }
        end
    })

    MF.RegisterColorTag("tfa_cryo", {
        r = 162,
        g = 192,
        b = 255,
        source = "integration"
    })

    MF.RegisterColorTag("tfa_energy", {
        r = 128,
        g = 192,
        b = 255,
        source = "integration"
    })

    MF.RegisterColorTag("tfa_gauss", {
        r = 25,
        g = 200,
        b = 255,
        source = "integration"
    })

    MF.RegisterColorTag("tfa_incendiary", {
        r = 255,
        g = 128,
        b = 64,
        source = "integration"
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

    local function wrapArc9DoEffects(weapon)
        if not isArc9Weapon(weapon) then return end

        installWeaponWrapper(weapon, "BetterLightsArc9DoEffects", "DoEffects", function(original, instance, ...)
            local ret = original(instance, ...)
            if IsFirstTimePredicted and not IsFirstTimePredicted() then return ret end

            MF.HandleAdapterShot(instance, "arc9")
            return ret
        end)
    end

    local function wrapArcCWDoEffects(weapon)
        if not isArcCWWeapon(weapon) then return end

        installWeaponWrapper(weapon, "BetterLightsArcCWDoEffects", "DoEffects", function(original, instance, ...)
            refreshArcCWMuzzleLightReplacement(instance)
            local ret = original(instance, ...)
            if IsFirstTimePredicted and not IsFirstTimePredicted() then return ret end

            MF.HandleAdapterShot(instance, "arccw")
            return ret
        end)
    end

    local function wrapMwBaseProjectiles(weapon)
        if not isMwBaseWeapon(weapon) then return end

        installWeaponWrapper(weapon, "BetterLightsMwBaseProjectiles", "Projectiles", function(original, instance, ...)
            local ret = original(instance, ...)
            if IsFirstTimePredicted and not IsFirstTimePredicted() then return ret end

            MF.HandleAdapterShot(instance, "mwbase")
            return ret
        end)
    end

    local function handleAdapterWeapon(weapon)
        if not (IsValid(weapon) and weapon.IsWeapon and weapon:IsWeapon()) then return end

        wrapArc9DoEffects(weapon)
        wrapArcCWDoEffects(weapon)
        refreshArcCWMuzzleLightReplacement(weapon)
        wrapMwBaseProjectiles(weapon)
        wrapCW2MuzzleEffects(weapon)
        wrapTFAMuzzleEffects(weapon)
    end

    local function scanAdapterWeapons()
        for _, ent in ents.Iterator() do
            handleAdapterWeapon(ent)
        end
    end

    hook.Add("OnEntityCreated", "BetterLights_MuzzleFlash_Adapters_Client", function(ent)
        timer.Simple(0, function()
            handleAdapterWeapon(ent)
        end)
    end)

    cvars.AddChangeCallback("betterlights_muzzle_enable", scanAdapterWeapons, "BetterLights_ArcCWMuzzleLightReplacementMuzzle")

    hook.Add("BetterLights_EffectiveEnabledChanged", "BetterLights_ArcCWMuzzleLightReplacementGlobal", scanAdapterWeapons)

    hook.Add("InitPostEntity", "BetterLights_MuzzleFlash_Adapters_Init_Client", scanAdapterWeapons)
    timer.Create("BetterLights_MuzzleFlash_Adapters_Scan_Client", 2, 0, scanAdapterWeapons)
end
