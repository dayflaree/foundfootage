if CLIENT then
    local BL = BetterLights
    local EXP = BL.Explosions
    local WRAPPER_VERSION = 1

    local function isUsableVector(pos)
        return isvector(pos) and pos ~= vector_origin
    end

    local function cvarBool(cvar, fallback)
        if cvar then return cvar:GetBool() end
        return fallback ~= false
    end

    local function cvarFloat(cvar, fallback)
        if cvar then return cvar:GetFloat() end
        return fallback or 0
    end

    local function resolveColor(profile)
        if profile.rCvar and profile.gCvar and profile.bCvar then
            return BL.GetColorFromCvars(profile.rCvar, profile.gCvar, profile.bCvar)
        end

        return profile.r or 255, profile.g or 210, profile.b or 120
    end

    local function shouldSuppress(profile, pos)
        local key = profile.suppressionKey or "explosion"
        local dist = profile.suppressionDistance or 80
        local age = profile.suppressionAge or 0.12

        return BL.ShouldSuppressFlash(key, pos, dist * dist, age)
    end

    local function recordFlash(profile, pos)
        BL.RecordFlashPosition(profile.suppressionKey or "explosion", pos)
    end

    function EXP.RegisterClientProfile(id, def)
        return EXP.RegisterProfile(id, def)
    end

    function EXP.EmitProfileFlash(profileId, pos, options)
        if not BL.IsEnabled() then return nil end
        if not isUsableVector(pos) then return nil end
        if options ~= nil and type(options) ~= "table" then return nil end

        options = options or {}

        local profile = EXP.GetProfile(profileId) or EXP.GetProfile("generic")
        if not profile then return nil end
        if profile.emit then return profile.emit(pos, options) end
        if not cvarBool(profile.enableCvar, true) then return nil end
        if shouldSuppress(profile, pos) then return nil end

        local duration = math.max(0, cvarFloat(profile.durationCvar, profile.duration or 0.18))
        if duration <= 0 then return nil end

        local size = math.max(0, cvarFloat(profile.sizeCvar, profile.size or 380))
        local brightness = math.max(0, cvarFloat(profile.brightnessCvar, profile.brightness or 4.6))
        local r, g, b = resolveColor(profile)
        local flash = BL.CreateFlash(pos, r, g, b, size, brightness, duration, profile.baseId or 61000, options.key)

        if flash then
            recordFlash(profile, pos)
        end

        return flash
    end

    BL.AddNetworkHandler(BL.NET_EXPLOSION, function()
        local profileId = net.ReadString()
        local pos = net.ReadVector()
        local source = net.ReadUInt(3)

        EXP.EmitProfileFlash(profileId, pos, {
            source = source
        })
    end)

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
                EXP.EmitProfileFlash(profileId, pos, {
                    source = BL.EXPLOSION_SOURCE_EFFECT
                })
            end

            return ret
        end
    end

    local function emitParticleFlash(particleName, pos)
        local profileId = EXP.MatchParticle(particleName)
        if not profileId then return end
        if not isUsableVector(pos) then return end

        EXP.EmitProfileFlash(profileId, pos, {
            source = BL.EXPLOSION_SOURCE_PARTICLE
        })
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

        if attachmentId and attachmentId > 0 then
            local pos = BL.GetAttachmentPosById(ent, attachmentId)
            if pos then return pos end
        end

        return BL.GetEntityCenter(ent)
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

    wrapUtilEffect()
    wrapParticleEffect()
    wrapParticleEffectAttach()
end
