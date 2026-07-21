if SERVER then
    local BL = BetterLights
    local MF = BL.MuzzleFlash

    util.AddNetworkString(BL.NET_EVENT_MESSAGE)

    local STRIDER_CLASS = "npc_strider"
    local HUNTER_CHOPPER_CLASS = "npc_helicopter"
    local FLOOR_TURRET_CLASS = "npc_turret_floor"
    local STUNSTICK_CLASS = "weapon_stunstick"
    local STUNSTICK_TRACE_DISTANCE = 96
    local STUNSTICK_TRACE_MINS = Vector(-8, -8, -8)
    local STUNSTICK_TRACE_MAXS = Vector(8, 8, 8)
    local SPECIAL_IMPACT_MESSAGES = {
        [STRIDER_CLASS] = BL.NET_STRIDER_BULLET_IMPACT,
        [HUNTER_CHOPPER_CLASS] = BL.NET_HUNTER_CHOPPER_BULLET_IMPACT
    }
    local WRAPPER_VERSION = 3
    local recentMuzzleShots = {}
    local recentMuzzleFrame
    local recentStunstickImpacts = {}

    MF.IgnoredSourceClasses = MF.IgnoredSourceClasses or {}

    local function getEntityClass(ent)
        if not (IsValid(ent) and ent.GetClass) then return "" end
        return string.lower(ent:GetClass() or "")
    end

    local function normalizeClassName(className)
        return string.lower(string.Trim(tostring(className or "")))
    end

    function MF.RegisterIgnoredSourceClass(className)
        className = normalizeClassName(className)
        if className == "" then return false end

        MF.IgnoredSourceClasses[className] = true
        return true
    end

    function MF.UnregisterIgnoredSourceClass(className)
        className = normalizeClassName(className)
        if className == "" then return false end

        MF.IgnoredSourceClasses[className] = nil
        return true
    end

    function MF.IsIgnoredSourceClass(value)
        local className = type(value) == "string" and normalizeClassName(value) or getEntityClass(value)
        return className ~= "" and MF.IgnoredSourceClasses[className] == true
    end

    local function getWeaponBase(ent)
        if not IsValid(ent) then return "" end

        local base = ent.Base
        if base == nil and ent.GetTable then
            local tab = ent:GetTable()
            base = tab and tab.Base
        end

        return string.lower(tostring(base or ""))
    end

    local function isWeaponEntity(ent)
        return IsValid(ent) and ent.IsWeapon and ent:IsWeapon()
    end

    local function resolveWeapon(shooter)
        if not IsValid(shooter) then return nil end
        if isWeaponEntity(shooter) then return shooter end

        if shooter.GetActiveWeapon then
            local weapon = shooter:GetActiveWeapon()
            if IsValid(weapon) then return weapon end
        end

        return nil
    end

    local function resolveShooterAndWeapon(firingEntity)
        local weapon = resolveWeapon(firingEntity)
        local shooter = firingEntity

        if isWeaponEntity(firingEntity) and firingEntity.GetOwner then
            local owner = firingEntity:GetOwner()
            if IsValid(owner) then
                shooter = owner
            end
        end

        return shooter, weapon
    end

    local function resolveMuzzleFlashShooterAndWeapon(ent)
        if IsValid(ent) and ent.GetActiveWeapon then
            local weapon = ent:GetActiveWeapon()
            if IsValid(weapon) then
                return ent, weapon
            end
        end

        return resolveShooterAndWeapon(ent)
    end

    local function isIgnoredSource(shooter, weapon)
        return MF.IsIgnoredSourceClass(shooter) or MF.IsIgnoredSourceClass(weapon)
    end

    local function isUsableVector(pos)
        return isvector(pos) and pos ~= vector_origin
    end

    local function getSendOrigin(shooter, weapon, bullet)
        if bullet and isUsableVector(bullet.Src) then return bullet.Src end
        if IsValid(shooter) and shooter.GetShootPos then return shooter:GetShootPos() end
        if IsValid(weapon) and weapon.GetPos then return weapon:GetPos() end
        if IsValid(shooter) and shooter.GetPos then return shooter:GetPos() end
        return nil
    end

    local function getFrameKey()
        if isfunction(FrameNumber) then return FrameNumber() end
        return math.floor(CurTime() * 100)
    end

    local function shouldSendMuzzleShot(shooter, weapon, profileId, adapterId)
        local frame = getFrameKey()
        if recentMuzzleFrame ~= frame then
            for key in pairs(recentMuzzleShots) do
                recentMuzzleShots[key] = nil
            end

            recentMuzzleFrame = frame
        end

        local shooterIndex = IsValid(shooter) and shooter:EntIndex() or 0
        local weaponIndex = IsValid(weapon) and weapon:EntIndex() or 0
        local key = tostring(shooterIndex) .. ":" .. tostring(weaponIndex) .. ":" .. tostring(profileId or "") .. ":" .. tostring(adapterId or "")

        if recentMuzzleShots[key] == frame then return false end

        recentMuzzleShots[key] = frame
        return true
    end

    local function getSpecialImpactMessage(ent)
        local className = getEntityClass(ent)
        return SPECIAL_IMPACT_MESSAGES[className]
    end

    local function isBuiltinDefaultMuzzleRule(rule)
        return rule and rule.id == "builtin_default" and rule.source == "builtin"
    end

    local function shouldSendMuzzleRule(rule, weapon)
        if not isBuiltinDefaultMuzzleRule(rule) then return true end

        return IsValid(weapon)
    end

    local function shouldSendStandaloneMuzzleRule(rule, weapon)
        return not isBuiltinDefaultMuzzleRule(rule) and shouldSendMuzzleRule(rule, weapon)
    end

    local function isAR2Shot(shooter, bullet)
        local weapon = resolveWeapon(shooter)
        local rule = MF.MatchWeaponRule(shooter, weapon, bullet)
        if rule and rule.profile == "ar2" then return true end

        local shooterClass = getEntityClass(shooter)
        if shooterClass == FLOOR_TURRET_CLASS or shooterClass == "npc_turret_ceiling" then return true end

        if bullet and type(bullet.TracerName) == "string" then
            return string.find(string.lower(bullet.TracerName), "ar2", 1, true) ~= nil
        end

        return false
    end

    local function writeStringList(values)
        values = values or {}
        local count = math.min(#values, 15)

        net.WriteUInt(count, 4)
        for i = 1, count do
            net.WriteString(tostring(values[i]))
        end
    end

    local function sendMuzzleFlash(shooter, weapon, profileId, sourceKind, origin, adapterId, attachments, flags)
        if not origin then return end
        if not shouldSendMuzzleShot(shooter, weapon, profileId, adapterId) then return end

        local filter = RecipientFilter()
        filter:AddPVS(origin)
        if IsValid(shooter) and shooter:IsPlayer() then
            filter:AddPlayer(shooter)
        end

        net.Start(BL.NET_EVENT_MESSAGE)
            net.WriteUInt(BL.NET_MUZZLE_FLASH, 4)
            net.WriteUInt(BL.MUZZLE_FLASH_PAYLOAD_VERSION, 4)
            net.WriteUInt(sourceKind or BL.MUZZLE_SOURCE_FIREBULLETS, 3)
            net.WriteEntity(IsValid(shooter) and shooter or NULL)
            net.WriteEntity(IsValid(weapon) and weapon or NULL)
            net.WriteString(getEntityClass(weapon))
            net.WriteString(profileId or "default")
            net.WriteUInt(flags or 0, 8)
            net.WriteString(adapterId or "")
            writeStringList(attachments)
        net.Send(filter)
    end

    local function getAdapterIdForWeapon(weapon)
        for id, adapter in pairs(MF.Adapters) do
            if adapter.matches and adapter.matches(weapon) then
                return id
            end
        end

        return nil
    end

    MF.GetWeaponBase = getWeaponBase

    MF.ClearRulesBySource("builtin")
    MF.RegisterProfile("default", { source = "builtin" })
    MF.RegisterProfile("ar2", { source = "builtin" })
    MF.RegisterProfile("strider", { source = "builtin" })
    MF.RegisterProfile("hunter_chopper", { source = "builtin" })
    MF.RegisterWeaponRule({
        id = "builtin_strider",
        class = STRIDER_CLASS,
        profile = "strider",
        priority = 1000,
        attachments = { "MiniGun" },
        source = "builtin"
    })
    MF.RegisterWeaponRule({
        id = "builtin_hunter_chopper",
        class = HUNTER_CHOPPER_CLASS,
        profile = "hunter_chopper",
        priority = 950,
        attachments = { "Muzzle" },
        source = "builtin"
    })
    MF.RegisterWeaponRule({
        id = "builtin_floor_turret",
        class = FLOOR_TURRET_CLASS,
        profile = "ar2",
        priority = 600,
        attachments = { "light", "4" },
        source = "builtin"
    })
    MF.RegisterWeaponRule({
        id = "builtin_ar2",
        class = "weapon_ar2",
        profile = "ar2",
        priority = 500,
        attachments = { "muzzle" },
        source = "builtin"
    })
    MF.RegisterWeaponRule({
        id = "builtin_ar2_tracer",
        tracer = "ar2",
        profile = "ar2",
        priority = 250,
        source = "builtin"
    })
    MF.RegisterWeaponRule({
        id = "builtin_default",
        profile = "default",
        priority = -1000,
        source = "builtin"
    })

    local function handleMuzzleFireBullets(ent, bullet)
        if not BL.IsServerEnabled() then return end
        if not IsValid(ent) then return end
        if not bullet then return end

        local shooter, weapon = resolveShooterAndWeapon(ent)
        if isIgnoredSource(shooter, weapon) then return end

        local adapterId = getAdapterIdForWeapon(weapon)
        local rule = MF.MatchWeaponRule(shooter, weapon, bullet, adapterId)
        if not rule then return end
        if not shouldSendMuzzleRule(rule, weapon) then return end

        local origin = getSendOrigin(shooter, weapon, bullet)
        if not origin then return end

        sendMuzzleFlash(shooter, weapon, rule.profile, BL.MUZZLE_SOURCE_FIREBULLETS, origin, adapterId, rule.attachments)
    end

    hook.Add("EntityFireBullets", "BetterLights_MuzzleFlash_Server", handleMuzzleFireBullets)
    hook.Add("PostEntityFireBullets", "BetterLights_MuzzleFlash_Server_Post", handleMuzzleFireBullets)

    local function handleMuzzleFlashCall(ent)
        if not BL.IsServerEnabled() then return end
        if not IsValid(ent) then return end

        local shooter, weapon = resolveMuzzleFlashShooterAndWeapon(ent)
        if isIgnoredSource(shooter, weapon) then return end

        local adapterId = getAdapterIdForWeapon(weapon)
        local rule = MF.MatchWeaponRule(shooter, weapon, nil, adapterId)
        if not rule then return end
        if not shouldSendStandaloneMuzzleRule(rule, weapon) then return end

        local origin = getSendOrigin(shooter, weapon)
        if not origin then return end

        sendMuzzleFlash(shooter, weapon, rule.profile, BL.MUZZLE_SOURCE_FIREBULLETS, origin, adapterId, rule.attachments)
    end

    local function wrapEntityFireBullets()
        local meta = FindMetaTable("Entity")
        if not (meta and isfunction(meta.FireBullets)) then return end
        if meta.BetterLightsFireBulletsWrapperVersion == WRAPPER_VERSION then return end

        local original = meta.BetterLightsFireBulletsOriginal or meta.FireBullets
        meta.BetterLightsFireBulletsWrapperVersion = WRAPPER_VERSION
        meta.BetterLightsFireBulletsOriginal = original
        meta.FireBullets = function(self, bullet, suppressHostEvents)
            local ret = original(self, bullet, suppressHostEvents)
            handleMuzzleFireBullets(self, bullet)
            return ret
        end
    end

    local function wrapEntityMuzzleFlash()
        local meta = FindMetaTable("Entity")
        if not (meta and isfunction(meta.MuzzleFlash)) then return end
        if meta.BetterLightsMuzzleFlashWrapperVersion == WRAPPER_VERSION then return end

        local original = meta.BetterLightsMuzzleFlashOriginal or meta.MuzzleFlash
        meta.BetterLightsMuzzleFlashWrapperVersion = WRAPPER_VERSION
        meta.BetterLightsMuzzleFlashOriginal = original
        meta.MuzzleFlash = function(self, ...)
            local ret = original(self, ...)
            handleMuzzleFlashCall(self)
            return ret
        end
    end

    wrapEntityFireBullets()
    wrapEntityMuzzleFlash()

    local function sendAdapterMuzzleFlash(weapon, adapterId)
        if not BL.IsServerEnabled() then return end
        if not IsValid(weapon) then return end

        local shooter = weapon.GetOwner and weapon:GetOwner() or nil
        if not IsValid(shooter) then shooter = weapon end
        if isIgnoredSource(shooter, weapon) then return end

        local rule = MF.MatchWeaponRule(shooter, weapon, nil, adapterId)
        if not rule then return end

        local origin = getSendOrigin(shooter, weapon)
        if not origin then return end

        sendMuzzleFlash(shooter, weapon, rule.profile, BL.MUZZLE_SOURCE_ADAPTER, origin, adapterId, rule.attachments)
    end

    MF.SendAdapterMuzzleFlash = sendAdapterMuzzleFlash

    hook.Add("EntityFireBullets", "BetterLights_BulletImpact_Server", function(ent, bullet)
        if not BL.IsServerEnabled() then return end
        if not IsValid(ent) then return end
        if not bullet then return end

        local shooter, weapon = resolveShooterAndWeapon(ent)
        if isIgnoredSource(shooter, weapon) then return end

        local prev = bullet.Callback
        bullet.Callback = function(att, tr, dmginfo)
            local ret
            if isfunction(prev) then ret = prev(att, tr, dmginfo) end
            if not BL.IsServerEnabled() then return ret end
            if type(ret) == "table" and ret.effects == false then return ret end
            if not (dmginfo and dmginfo.GetDamage and dmginfo:GetDamage() > 0) then return ret end
            if not tr or not tr.Hit or not tr.HitPos then return ret end

            local pos = tr.HitPos
            if tr.HitNormal then
                pos = pos + tr.HitNormal * 2
            end

            net.Start(BL.NET_EVENT_MESSAGE)
                local specialMessage = getSpecialImpactMessage(ent)
                net.WriteUInt(specialMessage or BL.NET_BULLET_IMPACT, 4)
                net.WriteVector(pos)
                if not specialMessage then
                    net.WriteBool(isAR2Shot(att, bullet))
                end
            net.SendPVS(pos)

            return ret
        end
    end)

    local function isStunstickDamage(attacker, inflictor)
        if IsValid(inflictor) and inflictor.GetClass and inflictor:GetClass() == STUNSTICK_CLASS then
            return true
        end

        if not IsValid(attacker) then return false end
        local weapon = attacker.GetActiveWeapon and attacker:GetActiveWeapon() or nil
        return IsValid(weapon) and weapon.GetClass and weapon:GetClass() == STUNSTICK_CLASS
    end

    local function getActiveStunstick(ply)
        if not IsValid(ply) then return nil end

        local weapon = ply.GetActiveWeapon and ply:GetActiveWeapon() or nil
        if not (IsValid(weapon) and weapon.GetClass and weapon:GetClass() == STUNSTICK_CLASS) then return nil end
        return weapon
    end

    local function getDamagePosition(dmginfo)
        if not (dmginfo and dmginfo.GetDamagePosition) then return nil end

        local pos = dmginfo:GetDamagePosition()
        if not pos or pos == vector_origin then return nil end
        return pos
    end

    local function getStunstickTrace(attacker)
        if not IsValid(attacker) then return nil end
        if not (attacker.GetShootPos and attacker.GetAimVector) then return nil end

        local start = attacker:GetShootPos()
        local endpos = start + attacker:GetAimVector() * STUNSTICK_TRACE_DISTANCE
        return util.TraceHull({
            start = start,
            endpos = endpos,
            mins = STUNSTICK_TRACE_MINS,
            maxs = STUNSTICK_TRACE_MAXS,
            filter = attacker,
            mask = MASK_SHOT_HULL or MASK_SHOT
        })
    end

    local function getTraceImpactPosition(attacker)
        local tr = getStunstickTrace(attacker)
        if not (tr and tr.Hit and tr.HitPos) then return nil end

        local pos = tr.HitPos
        if tr.HitNormal then
            pos = pos + tr.HitNormal * 2
        end

        return pos, tr.Entity
    end

    local function resolveStunstickImpactPosition(dmginfo, attacker)
        local pos = getDamagePosition(dmginfo)
        if pos then return pos end

        return getTraceImpactPosition(attacker)
    end

    local function shouldSendStunstickImpact(attacker)
        local now = CurTime()
        local attackerIndex = IsValid(attacker) and attacker:EntIndex() or 0
        local key = tostring(attackerIndex)
        if recentStunstickImpacts[key] and recentStunstickImpacts[key] > now then return false end

        recentStunstickImpacts[key] = now + 0.12
        return true
    end

    local function sendStunstickImpact(pos)
        net.Start(BL.NET_EVENT_MESSAGE)
            net.WriteUInt(BL.NET_STUNSTICK_IMPACT, 4)
            net.WriteVector(pos)
        net.SendPVS(pos)
    end

    local function sendStunstickTraceImpact(attacker)
        local pos = getTraceImpactPosition(attacker)
        if not pos then return end
        if not shouldSendStunstickImpact(attacker) then return end

        sendStunstickImpact(pos)
    end

    hook.Add("EntityTakeDamage", "BetterLights_StunstickImpact_Server", function(target, dmginfo)
        if not BL.IsServerEnabled() then return end
        if not IsValid(target) then return end
        if not dmginfo then return end

        local attacker = dmginfo.GetAttacker and dmginfo:GetAttacker() or nil
        local inflictor = dmginfo.GetInflictor and dmginfo:GetInflictor() or nil
        if not isStunstickDamage(attacker, inflictor) then return end
        if not shouldSendStunstickImpact(attacker) then return end

        local pos = resolveStunstickImpactPosition(dmginfo, attacker)
        if not pos then return end

        sendStunstickImpact(pos)
    end)

    hook.Add("KeyPress", "BetterLights_StunstickImpact_KeyPress", function(ply, key)
        if key ~= IN_ATTACK then return end
        if not BL.IsServerEnabled() then return end

        local weapon = getActiveStunstick(ply)
        if not weapon then return end

        timer.Simple(0, function()
            if not BL.IsServerEnabled() then return end
            if not IsValid(ply) then return end
            if getActiveStunstick(ply) ~= weapon then return end

            sendStunstickTraceImpact(ply)
        end)
    end)
end
