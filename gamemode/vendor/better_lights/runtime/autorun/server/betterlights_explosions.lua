if SERVER then
    local BL = BetterLights
    local EXP = BL.Explosions
    local WRAPPER_VERSION = 1
    local SUPPRESSION_DISTANCE_SQR = 160 * 160
    local SUPPRESSION_AGE = 0.12
    local DAMAGE_REMOVAL_WINDOW = 0.35

    util.AddNetworkString(BL.NET_EVENT_MESSAGE)

    local recentExplosions = {}
    local damageRemovalCandidates = {}

    local function isUsableVector(pos)
        return isvector(pos) and pos ~= vector_origin
    end

    local function getEntityCenter(ent)
        if not IsValid(ent) then return nil end

        if ent.LocalToWorld and ent.OBBCenter then
            return ent:LocalToWorld(ent:OBBCenter())
        end

        if ent.WorldSpaceCenter then
            return ent:WorldSpaceCenter()
        end

        return ent:GetPos()
    end

    local function getEntityClass(ent)
        if not (IsValid(ent) and ent.GetClass) then return "" end

        return string.lower(ent:GetClass() or "")
    end

    local function isExplosiveBarrel(ent)
        if not IsValid(ent) then return false end

        local className = getEntityClass(ent)
        if className ~= "prop_physics" and className ~= "prop_physics_multiplayer" then return false end
        if not ent.GetModel then return false end

        return string.find(string.lower(ent:GetModel() or ""), "oildrum001_explosive", 1, true) ~= nil
    end

    local function resolveEntityProfile(ent)
        if isExplosiveBarrel(ent) then return "barrel" end

        return EXP.MatchEntity(ent)
    end

    local function pruneRecent(now)
        for i = #recentExplosions, 1, -1 do
            if now - recentExplosions[i].t > SUPPRESSION_AGE then
                recentExplosions[i] = recentExplosions[#recentExplosions]
                recentExplosions[#recentExplosions] = nil
            end
        end
    end

    local function shouldSuppress(pos)
        local now = CurTime()
        pruneRecent(now)

        for i = 1, #recentExplosions do
            if recentExplosions[i].pos:DistToSqr(pos) < SUPPRESSION_DISTANCE_SQR then
                return true
            end
        end

        recentExplosions[#recentExplosions + 1] = {
            pos = pos,
            t = now
        }

        return false
    end

    function EXP.Emit(profileId, pos, source)
        if not BL.IsServerEnabled() then return false end
        if not isUsableVector(pos) then return false end
        if shouldSuppress(pos) then return false end

        net.Start(BL.NET_EVENT_MESSAGE)
            net.WriteUInt(BL.NET_EXPLOSION, 4)
            net.WriteString(profileId or "generic")
            net.WriteVector(pos)
            net.WriteUInt(source or BL.EXPLOSION_SOURCE_DAMAGE, 3)
        net.SendPVS(pos)

        return true
    end

    local function copyVector(pos)
        if not isUsableVector(pos) then return nil end

        return Vector(pos.x, pos.y, pos.z)
    end

    local function emitFallback(profileId, pos, source)
        if not BL.IsServerEnabled() then return end

        local sendPos = copyVector(pos)
        if not sendPos then return end

        timer.Simple(0, function()
            EXP.Emit(profileId, sendPos, source)
        end)
    end

    local function markDamageRemovalCandidate(ent, profileId, pos)
        if not IsValid(ent) then return end
        if not isUsableVector(pos) then return end

        local record = {
            profileId = profileId,
            pos = copyVector(pos),
            expire = CurTime() + DAMAGE_REMOVAL_WINDOW
        }

        damageRemovalCandidates[ent] = record

        timer.Simple(DAMAGE_REMOVAL_WINDOW, function()
            if damageRemovalCandidates[ent] == record then
                damageRemovalCandidates[ent] = nil
            end
        end)
    end

    local function maybeMarkDamageRemovalCandidate(target)
        local profileId = resolveEntityProfile(target)
        local profile = profileId and EXP.GetProfile(profileId) or nil
        if not (profile and profile.damageRemoval) then return end

        markDamageRemovalCandidate(target, profileId, getEntityCenter(target))
    end

    local function readDamageVector(dmginfo, getter)
        if not (dmginfo and isfunction(dmginfo[getter])) then return nil end

        local pos = dmginfo[getter](dmginfo)
        if isUsableVector(pos) then return pos end

        return nil
    end

    local function resolveDamagePosition(target, dmginfo, inflictor)
        local pos = getEntityCenter(inflictor)
        if isUsableVector(pos) then return pos end

        pos = readDamageVector(dmginfo, "GetDamagePosition")
        if pos then return pos end

        pos = readDamageVector(dmginfo, "GetReportedPosition")
        if pos then return pos end

        return getEntityCenter(target)
    end

    hook.Add("EntityTakeDamage", "BetterLights_ExplosionDamage_Server", function(target, dmginfo)
        if not BL.IsServerEnabled() then return end
        if not (dmginfo and dmginfo.IsExplosionDamage) then return end
        if not dmginfo:IsExplosionDamage() then
            maybeMarkDamageRemovalCandidate(target)
            return
        end

        local inflictor = dmginfo.GetInflictor and dmginfo:GetInflictor() or nil
        local profileId = resolveEntityProfile(inflictor) or "generic"
        local pos = resolveDamagePosition(target, dmginfo, inflictor)

        EXP.Emit(profileId, pos, BL.EXPLOSION_SOURCE_DAMAGE)
    end)

    hook.Add("EntityRemoved", "BetterLights_ExplosionDamageRemoval_Server", function(ent, fullUpdate)
        if fullUpdate then return end

        local record = damageRemovalCandidates[ent]
        damageRemovalCandidates[ent] = nil
        if not record then return end
        if record.expire < CurTime() then return end

        EXP.Emit(record.profileId, record.pos, BL.EXPLOSION_SOURCE_DAMAGE)
    end)

    local function wrapBlastDamage()
        if not (util and isfunction(util.BlastDamage)) then return end
        if util.BetterLightsBlastDamageWrapperVersion == WRAPPER_VERSION then return end

        local original = util.BetterLightsBlastDamageOriginal or util.BlastDamage
        util.BetterLightsBlastDamageOriginal = original
        util.BetterLightsBlastDamageWrapperVersion = WRAPPER_VERSION

        util.BlastDamage = function(inflictor, attacker, damageOrigin, damageRadius, damage)
            local ret = original(inflictor, attacker, damageOrigin, damageRadius, damage)
            local profileId = resolveEntityProfile(inflictor) or "generic"
            EXP.Emit(profileId, damageOrigin, BL.EXPLOSION_SOURCE_DAMAGE)
            return ret
        end
    end

    local function wrapBlastDamageInfo()
        if not (util and isfunction(util.BlastDamageInfo)) then return end
        if util.BetterLightsBlastDamageInfoWrapperVersion == WRAPPER_VERSION then return end

        local original = util.BetterLightsBlastDamageInfoOriginal or util.BlastDamageInfo
        util.BetterLightsBlastDamageInfoOriginal = original
        util.BetterLightsBlastDamageInfoWrapperVersion = WRAPPER_VERSION

        util.BlastDamageInfo = function(dmginfo, damageOrigin, damageRadius)
            local ret = original(dmginfo, damageOrigin, damageRadius)
            local inflictor = dmginfo and dmginfo.GetInflictor and dmginfo:GetInflictor() or nil
            local profileId = resolveEntityProfile(inflictor) or "generic"
            EXP.Emit(profileId, damageOrigin, BL.EXPLOSION_SOURCE_DAMAGE)
            return ret
        end
    end

    local function resolveEffectFlash(effectName, effectData)
        local profileId = EXP.MatchEffect(effectName)
        if not profileId then return nil end
        if not (effectData and effectData.GetOrigin) then return nil end

        local pos = effectData:GetOrigin()
        if not isUsableVector(pos) then return nil end

        return profileId, pos
    end

    local function wrapUtilEffect()
        if not (util and isfunction(util.Effect)) then return end
        if util.BetterLightsExplosionEffectWrapperVersion == WRAPPER_VERSION then return end

        local original = util.BetterLightsExplosionEffectOriginal or util.Effect
        util.BetterLightsExplosionEffectOriginal = original
        util.BetterLightsExplosionEffectWrapperVersion = WRAPPER_VERSION

        util.Effect = function(effectName, effectData, ...)
            local profileId, pos = resolveEffectFlash(effectName, effectData)
            local ret = original(effectName, effectData, ...)

            if profileId then
                emitFallback(profileId, pos, BL.EXPLOSION_SOURCE_EFFECT)
            end

            return ret
        end
    end

    local function emitParticleFlash(particleName, pos)
        local profileId = EXP.MatchParticle(particleName)
        if not profileId then return end

        emitFallback(profileId, pos, BL.EXPLOSION_SOURCE_PARTICLE)
    end

    local function wrapParticleEffect()
        if not isfunction(ParticleEffect) then return end
        if BL._particleEffectWrapperVersion == WRAPPER_VERSION then return end

        local original = BL._particleEffectOriginal or ParticleEffect
        BL._particleEffectOriginal = original
        BL._particleEffectWrapperVersion = WRAPPER_VERSION

        ParticleEffect = function(particleName, pos, ...)
            local ret = original(particleName, pos, ...)
            emitParticleFlash(particleName, pos)
            return ret
        end
    end

    local function getParticleAttachPos(ent, attachmentId)
        if not IsValid(ent) then return nil end
        if attachmentId and attachmentId > 0 and ent.GetAttachment then
            local data = ent:GetAttachment(attachmentId)
            if data and isUsableVector(data.Pos) then return data.Pos end
        end

        return getEntityCenter(ent)
    end

    local function wrapParticleEffectAttach()
        if not isfunction(ParticleEffectAttach) then return end
        if BL._particleEffectAttachWrapperVersion == WRAPPER_VERSION then return end

        local original = BL._particleEffectAttachOriginal or ParticleEffectAttach
        BL._particleEffectAttachOriginal = original
        BL._particleEffectAttachWrapperVersion = WRAPPER_VERSION

        ParticleEffectAttach = function(particleName, attachType, ent, attachmentId, ...)
            local pos = getParticleAttachPos(ent, attachmentId)
            local ret = original(particleName, attachType, ent, attachmentId, ...)
            emitParticleFlash(particleName, pos)
            return ret
        end
    end

    hook.Add("AcceptInput", "BetterLights_ExplosionInput_Server", function(ent, input)
        local profileId = EXP.MatchInput(getEntityClass(ent), input)
        if not profileId then return end

        emitFallback(profileId, getEntityCenter(ent), BL.EXPLOSION_SOURCE_INPUT)
    end)

    wrapBlastDamage()
    wrapBlastDamageInfo()
    wrapUtilEffect()
    wrapParticleEffect()
    wrapParticleEffectAttach()
end
