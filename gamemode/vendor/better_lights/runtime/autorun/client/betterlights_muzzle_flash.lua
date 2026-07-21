if CLIENT then
    local BL = BetterLights
    local MF = BL.MuzzleFlash

    local RULES_PATH = "betterlights/muzzle_flash_rules.json"
    local DEFAULT_ATTACHMENTS = { "muzzle", "Muzzle", "barrel", "muzzle_flash", "1" }
    local FLASH_BASE_ID = 61000
    local LOCAL_ECHO_WINDOW = 0.2
    local MAX_RESOLVE_ATTEMPTS = 2
    local MAX_FIRST_PERSON_MUZZLE_DIST_SQ = 192 * 192
    local WRAPPER_VERSION = 3

    local cvar_enable = BL.CreateClientConVar("betterlights_muzzle_enable", "1", true, false, "Enable muzzle flash light on firing")
    BL.CreateClientConVar("betterlights_muzzle_size", "250", true, false, "Muzzle flash radius")
    BL.CreateClientConVar("betterlights_muzzle_brightness", "2.00", true, false, "Muzzle flash brightness")
    BL.CreateClientConVar("betterlights_muzzle_time", "0.08", true, false, "Muzzle flash duration")
    local cvar_show_others = BL.CreateClientConVar("betterlights_muzzle_show_others", "1", true, false, "Show muzzle flashes from other players and NPCs")
    local cvar_debug = BL.CreateClientConVar("betterlights_muzzle_debug", "0", true, false, "Print developer muzzle flash resolver messages")
    BL.CreateClientConVar("betterlights_muzzle_advanced", "0", true, false, "Show advanced muzzle flash editor when developer mode is enabled")

    BL.CreateClientConVar("betterlights_muzzle_ar2_enable", "1", true, false, "Use blue tint for AR2 muzzle flashes")
    BL.CreateClientConVar("betterlights_muzzle_ar2_size", "250", true, false, "AR2 muzzle flash radius")
    BL.CreateClientConVar("betterlights_muzzle_ar2_brightness", "2.0", true, false, "AR2 muzzle flash brightness")

    BL.CreateClientConVar("betterlights_muzzle_color_r", "255", true, false, "Generic muzzle flash color - red (0-255)")
    BL.CreateClientConVar("betterlights_muzzle_color_g", "170", true, false, "Generic muzzle flash color - green (0-255)")
    BL.CreateClientConVar("betterlights_muzzle_color_b", "90", true, false, "Generic muzzle flash color - blue (0-255)")
    BL.CreateClientConVar("betterlights_muzzle_ar2_color_r", "110", true, false, "AR2 muzzle flash color - red (0-255)")
    BL.CreateClientConVar("betterlights_muzzle_ar2_color_g", "190", true, false, "AR2 muzzle flash color - green (0-255)")
    BL.CreateClientConVar("betterlights_muzzle_ar2_color_b", "255", true, false, "AR2 muzzle flash color - blue (0-255)")

    MF.UserRules = MF.UserRules or {}
    MF.UserColorTags = MF.UserColorTags or {}
    MF._localPredictedShots = MF._localPredictedShots or {}
    MF._lastLocalFrame = MF._lastLocalFrame or {}
    MF._lastLocalFrameNumber = MF._lastLocalFrameNumber or -1

    local function isVector(value)
        if isvector then return isvector(value) end
        return type(value) == "Vector"
    end

    local function isDeveloperEnabled()
        local developer = GetConVar("developer")
        return developer and developer:GetInt() >= 1
    end

    local function debugPrint(text)
        if not isDeveloperEnabled() then return end
        if not cvar_debug:GetBool() then return end

        MsgC(Color(110, 190, 255), "[BetterLights] Muzzle flash: " .. tostring(text) .. "\n")
    end

    local function readCvarNumber(name, fallback)
        local cvar = GetConVar(name)
        if not cvar then return fallback end
        return cvar:GetFloat()
    end

    local function readCvarBool(name, fallback)
        local cvar = GetConVar(name)
        if not cvar then return fallback end
        return cvar:GetBool()
    end

    local function clampColorChannel(value)
        return math.Clamp(math.floor((tonumber(value) or 255) + 0.5), 0, 255)
    end

    local function copySequence(value)
        if type(value) ~= "table" then return nil end

        local out = {}
        for i = 1, #value do
            out[i] = value[i]
        end

        return out
    end

    local function splitList(text)
        local out = {}
        for token in string.gmatch(tostring(text or ""), "[^,%s]+") do
            out[#out + 1] = token
        end
        return out
    end

    local function joinList(values)
        if type(values) ~= "table" then return "" end
        return table.concat(values, ", ")
    end

    local function currentFrameKey()
        if isfunction(FrameNumber) then return FrameNumber() end
        return math.floor(CurTime() * 100)
    end

    local function getRuleKey(shooter, weapon, profileId, adapterId)
        local shooterIndex = IsValid(shooter) and shooter:EntIndex() or 0
        local weaponIndex = IsValid(weapon) and weapon:EntIndex() or 0
        return tostring(shooterIndex) .. ":" .. tostring(weaponIndex) .. ":" .. tostring(profileId or "") .. ":" .. tostring(adapterId or "")
    end

    local function shouldSendLocalFrame(shooter, weapon, profileId, adapterId)
        local key = getRuleKey(shooter, weapon, profileId, adapterId)
        local frame = currentFrameKey()
        if MF._lastLocalFrameNumber ~= frame then
            for previousKey in pairs(MF._lastLocalFrame) do
                MF._lastLocalFrame[previousKey] = nil
            end

            MF._lastLocalFrameNumber = frame
        end

        if MF._lastLocalFrame[key] == frame then return false end

        MF._lastLocalFrame[key] = frame
        return true
    end

    local function recordLocalPrediction(shooter, weapon, profileId, adapterId)
        MF._localPredictedShots[getRuleKey(shooter, weapon, profileId, adapterId)] = CurTime()
    end

    local function pruneLocalPredictedShots()
        local now = CurTime()

        for key, when in pairs(MF._localPredictedShots) do
            if type(when) ~= "number" or when > now or now - when > LOCAL_ECHO_WINDOW then
                MF._localPredictedShots[key] = nil
            end
        end
    end

    timer.Create("BetterLights_MuzzleFlash_LocalPredictionPrune_Client", 1, 0, pruneLocalPredictedShots)

    local function shouldSuppressServerEcho(shooter, weapon, profileId, adapterId)
        if shooter ~= LocalPlayer() then return false end

        local key = getRuleKey(shooter, weapon, profileId, adapterId)
        local when = MF._localPredictedShots[key]
        if not when then return false end
        if CurTime() - when > LOCAL_ECHO_WINDOW then
            MF._localPredictedShots[key] = nil
            return false
        end

        return true
    end

    local function getOwnedWeapon(shooter, weapon)
        if IsValid(weapon) then return weapon end
        if IsValid(shooter) and shooter.GetActiveWeapon then
            local active = shooter:GetActiveWeapon()
            if IsValid(active) then return active end
        end

        return nil
    end

    local function resolveLocalShooterAndWeapon(firingEntity)
        local localPlayer = LocalPlayer()
        if firingEntity == localPlayer then
            return localPlayer, getOwnedWeapon(localPlayer)
        end

        if IsValid(firingEntity) and firingEntity.IsWeapon and firingEntity:IsWeapon() and firingEntity.GetOwner then
            local owner = firingEntity:GetOwner()
            if owner == localPlayer then
                return owner, firingEntity
            end
        end

        return firingEntity, getOwnedWeapon(firingEntity)
    end

    local function getLocalMuzzleFlashShooterAndWeapon(ent)
        local localPlayer = LocalPlayer()
        if ent == localPlayer then
            return localPlayer, getOwnedWeapon(localPlayer)
        end

        if IsValid(ent) and ent.GetActiveWeapon then
            local weapon = ent:GetActiveWeapon()
            if IsValid(weapon) then
                return ent, weapon
            end
        end

        return resolveLocalShooterAndWeapon(ent)
    end

    local function getAttachmentById(ent, attachmentId)
        if not (IsValid(ent) and ent.GetAttachment) then return nil end
        attachmentId = tonumber(attachmentId)
        if not attachmentId or attachmentId <= 0 then return nil end

        local attachment = ent:GetAttachment(attachmentId)
        if attachment and isVector(attachment.Pos) then return attachment.Pos end
        return nil
    end

    local function getAttachmentByName(ent, attachmentName)
        if not (IsValid(ent) and ent.LookupAttachment and ent.GetAttachment) then return nil end

        local attachmentId = ent:LookupAttachment(tostring(attachmentName))
        if attachmentId and attachmentId > 0 then
            return getAttachmentById(ent, attachmentId)
        end

        return nil
    end

    local function resolveAttachment(ent, candidates, includeNumericFallback)
        if not IsValid(ent) then return nil end

        for i = 1, #candidates do
            local candidate = candidates[i]
            local pos

            if type(candidate) == "number" then
                pos = getAttachmentById(ent, candidate)
            else
                pos = getAttachmentByName(ent, candidate)
                if not pos then
                    pos = getAttachmentById(ent, tonumber(candidate))
                end
            end

            if pos then return pos end
        end

        if includeNumericFallback then
            return getAttachmentById(ent, 1)
        end

        return nil
    end

    local function getShooterViewAnchor(shooter)
        if not IsValid(shooter) then return nil end
        if shooter.EyePos then return shooter:EyePos() end
        if shooter.GetShootPos then return shooter:GetShootPos() end
        if shooter.GetPos then return shooter:GetPos() end
        return nil
    end

    local function isPlausibleFirstPersonMuzzlePos(shooter, pos)
        if shooter ~= LocalPlayer() then return true end
        if not isVector(pos) or pos == vector_origin then return false end
        if shooter.ShouldDrawLocalPlayer and shooter:ShouldDrawLocalPlayer() then return true end

        local anchor = getShooterViewAnchor(shooter)
        if not anchor then return true end

        return pos:DistToSqr(anchor) <= MAX_FIRST_PERSON_MUZZLE_DIST_SQ
    end

    local function getFirstPersonAttachmentFallback(shooter)
        if shooter ~= LocalPlayer() then return nil end
        if shooter.ShouldDrawLocalPlayer and shooter:ShouldDrawLocalPlayer() then return nil end

        local anchor = getShooterViewAnchor(shooter)
        if not anchor then return nil end

        local aim = shooter.GetAimVector and shooter:GetAimVector() or nil
        if not isVector(aim) then return anchor end

        return anchor + aim * 24
    end

    local function buildAttachmentCandidates(explicitAttachments)
        local candidates = {}

        if type(explicitAttachments) == "table" then
            for i = 1, #explicitAttachments do
                candidates[#candidates + 1] = explicitAttachments[i]
            end
        end

        for i = 1, #DEFAULT_ATTACHMENTS do
            candidates[#candidates + 1] = DEFAULT_ATTACHMENTS[i]
        end

        return candidates
    end

    local function getFirstPersonViewModel(shooter)
        if shooter ~= LocalPlayer() then return nil end
        if not shooter.GetViewModel then return nil end

        local viewModel = shooter:GetViewModel()
        if IsValid(viewModel) then return viewModel end
        return nil
    end

    local function getProfileSettings(profile, colorTag)
        if not profile then return nil end
        if profile.enableCvar and not readCvarBool(profile.enableCvar, true) then return nil end

        local tag = colorTag or profile.colorTag
        local color = tag and MF.ColorTags[tag] or nil
        local r, g, b

        if color then
            r = clampColorChannel(color.r)
            g = clampColorChannel(color.g)
            b = clampColorChannel(color.b)
        else
            r = clampColorChannel(readCvarNumber(profile.rCvar or "betterlights_muzzle_color_r", profile.r or 255))
            g = clampColorChannel(readCvarNumber(profile.gCvar or "betterlights_muzzle_color_g", profile.g or 170))
            b = clampColorChannel(readCvarNumber(profile.bCvar or "betterlights_muzzle_color_b", profile.b or 90))
        end

        return {
            r = r,
            g = g,
            b = b,
            size = math.max(0, readCvarNumber(profile.sizeCvar or "betterlights_muzzle_size", profile.size or 250)),
            brightness = math.max(0, readCvarNumber(profile.brightnessCvar or "betterlights_muzzle_brightness", profile.brightness or 2)),
            duration = math.max(0, readCvarNumber(profile.durationCvar or "betterlights_muzzle_time", profile.duration or 0.08))
        }
    end

    function MF.EmitProfileFlash(profileId, pos, options)
        if not isVector(pos) then return false end
        if options ~= nil and type(options) ~= "table" then return false end

        options = options or {}
        if not cvar_enable:GetBool() then return false end
        if options.other and not cvar_show_others:GetBool() then return false end

        local profile = MF.GetProfile(profileId)
        local settings = getProfileSettings(profile, options.colorTag)
        if not settings then return false end

        BL.CreateFlash(
            pos,
            settings.r,
            settings.g,
            settings.b,
            settings.size,
            settings.brightness,
            settings.duration,
            options.baseId or FLASH_BASE_ID,
            options.key
        )

        return true
    end

    local function getWeaponBase(weapon)
        if not IsValid(weapon) then return "" end

        local base = weapon.Base
        if base == nil and weapon.GetTable then
            local tab = weapon:GetTable()
            base = tab and tab.Base
        end

        return string.lower(tostring(base or ""))
    end

    MF.IsVector = isVector
    MF.GetAttachmentById = getAttachmentById
    MF.GetAttachmentByName = getAttachmentByName
    MF.GetFirstPersonAttachmentFallback = getFirstPersonAttachmentFallback
    MF.BuildAttachmentCandidates = buildAttachmentCandidates
    MF.GetWeaponBase = getWeaponBase

    local function getAdapterForWeapon(weapon, adapterId)
        if adapterId and adapterId ~= "" then
            return MF.Adapters[adapterId], adapterId
        end

        for id, adapter in pairs(MF.Adapters) do
            if adapter.matches and adapter.matches(weapon) then
                return adapter, id
            end
        end

        return nil, nil
    end

    local function resolveMuzzlePosition(payload, attachments)
        local adapter = payload.adapter
        if adapter and adapter.resolve then
            local ok, pos = pcall(adapter.resolve, payload)
            if ok and isVector(pos) then return pos end
        end

        local candidates = buildAttachmentCandidates(attachments)
        local firstPersonFallback = getFirstPersonAttachmentFallback(payload.shooter)
        if firstPersonFallback then
            local viewModel = getFirstPersonViewModel(payload.shooter)
            if resolveAttachment(viewModel, candidates, true) then return firstPersonFallback end
            if resolveAttachment(payload.weapon, candidates, true) then return firstPersonFallback end
            return nil
        end

        local pos = resolveAttachment(payload.weapon, candidates, true)
        if pos and isPlausibleFirstPersonMuzzlePos(payload.shooter, pos) then return pos end
        if pos then
            debugPrint("rejected weapon muzzle position outside expected range")
        end

        pos = resolveAttachment(payload.shooter, candidates, true)
        if pos and isPlausibleFirstPersonMuzzlePos(payload.shooter, pos) then return pos end
        if pos then
            debugPrint("rejected shooter muzzle position outside expected range")
        end

        return nil
    end

    local function shouldSuppressByAdapter(payload)
        local adapter = payload.adapter
        if not (adapter and adapter.suppress) then return false end

        local ok, suppress = pcall(adapter.suppress, payload)
        return ok and suppress == true
    end

    local function isBuiltinDefaultMuzzleRule(rule)
        return rule and rule.id == "builtin_default" and rule.source == "builtin"
    end

    local function emitMuzzleFlash(payload, attempt)
        attempt = attempt or 1

        if not cvar_enable:GetBool() then return end
        if not payload.shooterIsLocal and not cvar_show_others:GetBool() then return end

        local weaponClass = MF.NormalizeWeaponClass(payload.weaponClass)
            or MF.NormalizeWeaponClass(payload.weapon)
        payload.weaponClass = weaponClass
        if MF.IsWeaponClassBlacklisted(weaponClass) then return end

        if shouldSuppressByAdapter(payload) then return end

        local rule = MF.MatchWeaponRule(payload.shooter, payload.weapon, payload.bullet, payload.adapterId)
        if rule and rule.id == "builtin_default" and payload.profileId and payload.profileId ~= "default" then
            rule = nil
        end

        local profileId = rule and rule.profile or payload.profileId or "default"
        local colorTag = rule and rule.colorTag or nil
        if payload.adapter and isfunction(payload.adapter.selectProfile) then
            local ok, selection = pcall(payload.adapter.selectProfile, payload, rule)
            if ok and type(selection) == "table" then
                profileId = selection.profile or profileId
                colorTag = selection.colorTag or colorTag
            end
        end

        if shouldSuppressServerEcho(payload.shooter, payload.weapon, profileId, payload.adapterId) then return end
        if isBuiltinDefaultMuzzleRule(rule) and not IsValid(payload.weapon) then return end

        local profile = MF.GetProfile(profileId)
        local settings = getProfileSettings(profile, colorTag)
        if not settings then return end

        local attachments = rule and rule.attachments or payload.attachments
        local pos = resolveMuzzlePosition(payload, attachments)
        if not pos then
            if attempt < MAX_RESOLVE_ATTEMPTS then
                timer.Simple(0, function()
                    emitMuzzleFlash(payload, attempt + 1)
                end)
                return
            end

            debugPrint("no muzzle attachment for profile '" .. tostring(profileId) .. "'")
            return
        end

        local key = getRuleKey(payload.shooter, payload.weapon, profileId, payload.adapterId)
        BL.CreateFlash(pos, settings.r, settings.g, settings.b, settings.size, settings.brightness, settings.duration, FLASH_BASE_ID, key)

        if payload.predicted then
            recordLocalPrediction(payload.shooter, payload.weapon, profileId, payload.adapterId)
        end
    end

    local function readAttachmentList()
        local count = net.ReadUInt(4)
        local attachments = {}
        for i = 1, count do
            attachments[i] = net.ReadString()
        end

        return attachments
    end

    BL.AddNetworkHandler(BL.NET_MUZZLE_FLASH, function()
        local version = net.ReadUInt(4)
        if version ~= BL.MUZZLE_FLASH_PAYLOAD_VERSION then return end

        local sourceKind = net.ReadUInt(3)
        local shooter = net.ReadEntity()
        local weapon = net.ReadEntity()
        local weaponClass = net.ReadString()
        local profileId = net.ReadString()
        local flags = net.ReadUInt(8)
        local adapterId = net.ReadString()
        local attachments = readAttachmentList()

        weapon = getOwnedWeapon(shooter, weapon)
        local adapter, resolvedAdapterId = getAdapterForWeapon(weapon, adapterId)

        emitMuzzleFlash({
            sourceKind = sourceKind,
            shooter = shooter,
            weapon = weapon,
            weaponClass = weaponClass,
            profileId = profileId,
            flags = flags,
            adapter = adapter,
            adapterId = resolvedAdapterId,
            attachments = attachments,
            shooterIsLocal = shooter == LocalPlayer()
        })
    end)

    local function handleLocalFireBullets(firingEntity, bullet)
        local shooter, weapon = resolveLocalShooterAndWeapon(firingEntity)
        if shooter ~= LocalPlayer() then return end
        if IsFirstTimePredicted and not IsFirstTimePredicted() then return end

        local adapter, adapterId = getAdapterForWeapon(weapon)
        local rule = MF.MatchWeaponRule(shooter, weapon, bullet, adapterId)
        if not rule then return end
        if not shouldSendLocalFrame(shooter, weapon, rule.profile, adapterId) then return end

        emitMuzzleFlash({
            sourceKind = BL.MUZZLE_SOURCE_PREDICTED,
            shooter = shooter,
            weapon = weapon,
            profileId = rule.profile,
            adapter = adapter,
            adapterId = adapterId,
            attachments = rule.attachments,
            bullet = bullet,
            shooterIsLocal = true,
            predicted = true
        })
    end

    hook.Add("EntityFireBullets", "BetterLights_MuzzleFlash_ClientPrediction", handleLocalFireBullets)
    hook.Add("PostEntityFireBullets", "BetterLights_MuzzleFlash_ClientPrediction_Post", handleLocalFireBullets)

    local function handleLocalMuzzleFlash(ent)
        local shooter, weapon = getLocalMuzzleFlashShooterAndWeapon(ent)
        if shooter ~= LocalPlayer() then return end
        if IsFirstTimePredicted and not IsFirstTimePredicted() then return end

        local adapter, adapterId = getAdapterForWeapon(weapon)
        local rule = MF.MatchWeaponRule(shooter, weapon, nil, adapterId)
        if not rule then return end
        if isBuiltinDefaultMuzzleRule(rule) then return end
        if not shouldSendLocalFrame(shooter, weapon, rule.profile, adapterId) then return end

        emitMuzzleFlash({
            sourceKind = BL.MUZZLE_SOURCE_PREDICTED,
            shooter = shooter,
            weapon = weapon,
            profileId = rule.profile,
            adapter = adapter,
            adapterId = adapterId,
            attachments = rule.attachments,
            shooterIsLocal = true,
            predicted = true
        })
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
            handleLocalFireBullets(self, bullet)
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
            handleLocalMuzzleFlash(self)
            return ret
        end
    end

    wrapEntityFireBullets()
    wrapEntityMuzzleFlash()

    concommand.Add("betterlights_muzzle_status", function()
        local meta = FindMetaTable("Entity")
        local ply = LocalPlayer()
        local weapon = getOwnedWeapon(ply)
        local viewModel = getFirstPersonViewModel(ply)
        local candidates = buildAttachmentCandidates(nil)
        local vmPos = resolveAttachment(viewModel, candidates, true)
        local wepPos = resolveAttachment(weapon, candidates, true)

        MsgC(Color(110, 190, 255), "[BetterLights] Muzzle flash status\n")
        MsgC(Color(220, 220, 220), "  loaded: yes\n")
        MsgC(Color(220, 220, 220), "  enabled: " .. tostring(cvar_enable:GetBool()) .. "\n")
        MsgC(Color(220, 220, 220), "  show others: " .. tostring(cvar_show_others:GetBool()) .. "\n")
        MsgC(Color(220, 220, 220), "  debug: " .. tostring(cvar_debug:GetBool()) .. "\n")
        MsgC(Color(220, 220, 220), "  FireBullets wrapper: " .. tostring(meta and meta.BetterLightsFireBulletsWrapperVersion or "missing") .. "\n")
        MsgC(Color(220, 220, 220), "  MuzzleFlash wrapper: " .. tostring(meta and meta.BetterLightsMuzzleFlashWrapperVersion or "missing") .. "\n")
        MsgC(Color(220, 220, 220), "  rule count: " .. tostring(#MF.WeaponRules) .. "\n")
        MsgC(Color(220, 220, 220), "  active weapon: " .. tostring(IsValid(weapon) and weapon:GetClass() or "none") .. "\n")
        MsgC(Color(220, 220, 220), "  viewmodel attachment: " .. tostring(vmPos ~= nil) .. "\n")
        MsgC(Color(220, 220, 220), "  weapon attachment: " .. tostring(wepPos ~= nil) .. "\n")
        if vmPos and IsValid(ply) then
            MsgC(Color(220, 220, 220), "  viewmodel raw distance from eyes: " .. tostring(math.floor(math.sqrt(vmPos:DistToSqr(ply:EyePos())) + 0.5)) .. "\n")
        end
        if wepPos and IsValid(ply) then
            MsgC(Color(220, 220, 220), "  weapon distance from eyes: " .. tostring(math.floor(math.sqrt(wepPos:DistToSqr(ply:EyePos())) + 0.5)) .. "\n")
        end
    end, nil, "Print Better Lights muzzle flash runtime status")

    local function handleAdapterShot(weapon, adapterId)
        local owner = IsValid(weapon) and weapon.GetOwner and weapon:GetOwner() or nil
        if not IsValid(owner) then owner = weapon end
        if not IsValid(owner) then return end
        if owner == LocalPlayer() and IsFirstTimePredicted and not IsFirstTimePredicted() then return end

        local adapter = MF.Adapters[adapterId]
        local rule = MF.MatchWeaponRule(owner, weapon, nil, adapterId)
        if not rule then return end
        if not shouldSendLocalFrame(owner, weapon, rule.profile, adapterId) then return end

        emitMuzzleFlash({
            sourceKind = BL.MUZZLE_SOURCE_ADAPTER,
            shooter = owner,
            weapon = weapon,
            profileId = rule.profile,
            adapter = adapter,
            adapterId = adapterId,
            attachments = rule.attachments,
            shooterIsLocal = owner == LocalPlayer(),
            predicted = owner == LocalPlayer()
        })
    end

    MF.HandleAdapterShot = handleAdapterShot

    local function registerBuiltIns()
        MF.ClearRulesBySource("builtin")
        MF.ClearColorTagsBySource("builtin")

        MF.RegisterColorTag("default", {
            r = 255,
            g = 170,
            b = 90,
            source = "builtin"
        })
        MF.RegisterColorTag("ar2", {
            r = 110,
            g = 190,
            b = 255,
            source = "builtin"
        })

        MF.RegisterProfile("default", {
            colorTag = nil,
            r = 255,
            g = 170,
            b = 90,
            size = 250,
            brightness = 2.0,
            duration = 0.08,
            sizeCvar = "betterlights_muzzle_size",
            brightnessCvar = "betterlights_muzzle_brightness",
            durationCvar = "betterlights_muzzle_time",
            rCvar = "betterlights_muzzle_color_r",
            gCvar = "betterlights_muzzle_color_g",
            bCvar = "betterlights_muzzle_color_b",
            source = "builtin"
        })
        MF.RegisterProfile("ar2", {
            enableCvar = "betterlights_muzzle_ar2_enable",
            r = 110,
            g = 190,
            b = 255,
            size = 250,
            brightness = 2.0,
            duration = 0.08,
            sizeCvar = "betterlights_muzzle_ar2_size",
            brightnessCvar = "betterlights_muzzle_ar2_brightness",
            durationCvar = "betterlights_muzzle_time",
            rCvar = "betterlights_muzzle_ar2_color_r",
            gCvar = "betterlights_muzzle_ar2_color_g",
            bCvar = "betterlights_muzzle_ar2_color_b",
            source = "builtin"
        })
        MF.RegisterProfile("strider", {
            enableCvar = "betterlights_strider_muzzle_flash_enable",
            r = 80,
            g = 210,
            b = 255,
            size = 320,
            brightness = 2.4,
            duration = 0.08,
            sizeCvar = "betterlights_strider_muzzle_flash_size",
            brightnessCvar = "betterlights_strider_muzzle_flash_brightness",
            durationCvar = "betterlights_strider_muzzle_flash_time",
            rCvar = "betterlights_strider_muzzle_flash_color_r",
            gCvar = "betterlights_strider_muzzle_flash_color_g",
            bCvar = "betterlights_strider_muzzle_flash_color_b",
            source = "builtin"
        })
        MF.RegisterProfile("hunter_chopper", {
            enableCvar = "betterlights_hunter_chopper_muzzle_flash_enable",
            r = 80,
            g = 210,
            b = 255,
            size = 260,
            brightness = 2.2,
            duration = 0.08,
            sizeCvar = "betterlights_hunter_chopper_muzzle_flash_size",
            brightnessCvar = "betterlights_hunter_chopper_muzzle_flash_brightness",
            durationCvar = "betterlights_hunter_chopper_muzzle_flash_time",
            rCvar = "betterlights_hunter_chopper_muzzle_flash_color_r",
            gCvar = "betterlights_hunter_chopper_muzzle_flash_color_g",
            bCvar = "betterlights_hunter_chopper_muzzle_flash_color_b",
            source = "builtin"
        })
        MF.RegisterProfile("hunter", {
            enableCvar = "betterlights_hunter_muzzle_flash_enable",
            r = 70,
            g = 220,
            b = 255,
            size = 220,
            brightness = 2.0,
            duration = 0.08,
            sizeCvar = "betterlights_hunter_muzzle_flash_size",
            brightnessCvar = "betterlights_hunter_muzzle_flash_brightness",
            durationCvar = "betterlights_hunter_muzzle_flash_time",
            rCvar = "betterlights_hunter_muzzle_flash_color_r",
            gCvar = "betterlights_hunter_muzzle_flash_color_g",
            bCvar = "betterlights_hunter_muzzle_flash_color_b",
            source = "builtin"
        })

        MF.RegisterWeaponRule({
            id = "builtin_strider",
            class = "npc_strider",
            profile = "strider",
            priority = 1000,
            attachments = { "MiniGun" },
            source = "builtin"
        })
        MF.RegisterWeaponRule({
            id = "builtin_hunter_chopper",
            class = "npc_helicopter",
            profile = "hunter_chopper",
            priority = 950,
            attachments = { "Muzzle" },
            source = "builtin"
        })
        MF.RegisterWeaponRule({
            id = "builtin_floor_turret",
            class = "npc_turret_floor",
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
    end

    local function registerUserData()
        MF.ClearRulesBySource("user")
        MF.ClearColorTagsBySource("user")

        for tag, color in pairs(MF.UserColorTags) do
            MF.RegisterColorTag(tag, {
                r = color.r,
                g = color.g,
                b = color.b,
                source = "user"
            })
        end

        for i = 1, #MF.UserRules do
            local rule = MF.UserRules[i]
            local def = {}
            for k, v in pairs(rule) do
                def[k] = v
            end
            def.source = "user"
            MF.RegisterWeaponRule(def)
        end
    end

    local function normalizeStoredRules(rules)
        local out = {}
        if type(rules) ~= "table" then return out end

        for i = 1, #rules do
            local rule = rules[i]
            if type(rule) == "table" then
                out[#out + 1] = {
                    class = tostring(rule.class or ""),
                    base = tostring(rule.base or ""),
                    profile = tostring(rule.profile or "default"),
                    colorTag = tostring(rule.colorTag or ""),
                    priority = tonumber(rule.priority) or 0,
                    attachments = copySequence(rule.attachments) or splitList(rule.attachments)
                }
            end
        end

        return out
    end

    function MF.LoadUserRules()
        local source = file.Read(RULES_PATH, "DATA")
        if not source or source == "" then
            MF.UserRules = {}
            MF.UserColorTags = {}
            registerUserData()
            return
        end

        local decoded = util.JSONToTable(source)
        if type(decoded) ~= "table" then
            debugPrint("could not read saved advanced rules")
            return
        end

        MF.UserColorTags = {}
        if type(decoded.colorTags) == "table" then
            for tag, color in pairs(decoded.colorTags) do
                if type(color) == "table" then
                    MF.UserColorTags[tostring(tag)] = {
                        r = clampColorChannel(color.r),
                        g = clampColorChannel(color.g),
                        b = clampColorChannel(color.b)
                    }
                end
            end
        end

        MF.UserRules = normalizeStoredRules(decoded.rules)
        registerUserData()
    end

    function MF.SaveUserRules()
        local encoded = util.TableToJSON({
            colorTags = MF.UserColorTags,
            rules = MF.UserRules
        }, true)
        if not encoded then return false end

        file.CreateDir("betterlights")
        return file.Write(RULES_PATH, encoded) == true
    end

    function MF.ResetUserRules()
        local oldRules = MF.UserRules
        local oldColorTags = MF.UserColorTags

        MF.UserRules = {}
        MF.UserColorTags = {}
        registerUserData()

        if not MF.SaveUserRules() then
            MF.UserRules = oldRules
            MF.UserColorTags = oldColorTags
            registerUserData()
            return false
        end

        return true
    end

    registerBuiltIns()
    MF.LoadUserRules()

    local function refreshColorList(list)
        list:Clear()
        for tag, color in pairs(MF.UserColorTags) do
            list:AddLine(tag, tostring(color.r), tostring(color.g), tostring(color.b))
        end
    end

    local function refreshRuleList(list)
        list:Clear()
        for i = 1, #MF.UserRules do
            local rule = MF.UserRules[i]
            list:AddLine(rule.class or "", rule.profile or "", tostring(rule.priority or 0), joinList(rule.attachments))
        end
    end

    local function addTextEntry(parent, placeholder)
        local entry = vgui.Create("DTextEntry")
        entry:SetTall(24)
        entry:SetPlaceholderText(placeholder)
        parent:AddItem(entry)
        return entry
    end

    function MF.BuildAdvancedEditor(panel)
        if not isDeveloperEnabled() then return end

        local phrase = BetterLights.Menu.Phrase
        local addButton = BetterLights.Menu.AddStyledButton

        local colors = vgui.Create("DForm")
        colors:SetName(phrase("section.muzzle_advanced_colors"))
        panel:AddItem(colors)

        local colorList = vgui.Create("DListView")
        colorList:SetTall(110)
        colorList:AddColumn(phrase("label.tag"))
        colorList:AddColumn("R")
        colorList:AddColumn("G")
        colorList:AddColumn("B")
        colors:AddItem(colorList)

        local tagEntry = addTextEntry(colors, phrase("placeholder.color_tag"))
        local rEntry = addTextEntry(colors, "255")
        local gEntry = addTextEntry(colors, "170")
        local bEntry = addTextEntry(colors, "90")
        local addColor = addButton(colors, phrase("button.add_color_tag"))
        addColor.DoClick = function()
            local tag = tagEntry:GetValue()
            if tag == "" then return end

            MF.UserColorTags[tag] = {
                r = clampColorChannel(rEntry:GetValue()),
                g = clampColorChannel(gEntry:GetValue()),
                b = clampColorChannel(bEntry:GetValue())
            }
            registerUserData()
            refreshColorList(colorList)
        end

        local removeColor = addButton(colors, phrase("button.remove_selected"))
        removeColor.DoClick = function()
            local line = colorList:GetSelectedLine()
            if not line then return end

            local row = colorList:GetLine(line)
            if not row then return end

            MF.UserColorTags[row:GetColumnText(1)] = nil
            registerUserData()
            refreshColorList(colorList)
        end

        colorList.OnRowSelected = function(_, _, row)
            tagEntry:SetValue(row:GetColumnText(1))
            rEntry:SetValue(row:GetColumnText(2))
            gEntry:SetValue(row:GetColumnText(3))
            bEntry:SetValue(row:GetColumnText(4))
        end

        local rules = vgui.Create("DForm")
        rules:SetName(phrase("section.muzzle_advanced_rules"))
        panel:AddItem(rules)

        local ruleList = vgui.Create("DListView")
        ruleList:SetTall(130)
        ruleList:AddColumn(phrase("label.class"))
        ruleList:AddColumn(phrase("label.profile"))
        ruleList:AddColumn(phrase("label.priority"))
        ruleList:AddColumn(phrase("label.attachments"))
        rules:AddItem(ruleList)

        local classEntry = addTextEntry(rules, phrase("placeholder.weapon_class"))
        local profileEntry = addTextEntry(rules, phrase("placeholder.profile"))
        local colorTagEntry = addTextEntry(rules, phrase("placeholder.color_tag_optional"))
        local priorityEntry = addTextEntry(rules, "0")
        local attachmentEntry = addTextEntry(rules, phrase("placeholder.attachments"))
        local addRule = addButton(rules, phrase("button.add_rule"))
        addRule.DoClick = function()
            MF.UserRules[#MF.UserRules + 1] = {
                class = classEntry:GetValue(),
                profile = profileEntry:GetValue() ~= "" and profileEntry:GetValue() or "default",
                colorTag = colorTagEntry:GetValue(),
                priority = tonumber(priorityEntry:GetValue()) or 0,
                attachments = splitList(attachmentEntry:GetValue())
            }
            registerUserData()
            refreshRuleList(ruleList)
        end

        local removeRule = addButton(rules, phrase("button.remove_selected"))
        removeRule.DoClick = function()
            local line = ruleList:GetSelectedLine()
            if not line then return end

            table.remove(MF.UserRules, line)
            registerUserData()
            refreshRuleList(ruleList)
        end

        ruleList.OnRowSelected = function(_, line)
            local rule = MF.UserRules[line]
            if not rule then return end

            classEntry:SetValue(rule.class or "")
            profileEntry:SetValue(rule.profile or "")
            colorTagEntry:SetValue(rule.colorTag or "")
            priorityEntry:SetValue(tostring(rule.priority or 0))
            attachmentEntry:SetValue(joinList(rule.attachments))
        end

        local actions = vgui.Create("DForm")
        actions:SetName(phrase("section.muzzle_advanced_actions"))
        panel:AddItem(actions)

        local save = addButton(actions, phrase("button.save_rules"))
        save.DoClick = function()
            if MF.SaveUserRules() then
                notification.AddLegacy(phrase("notice.muzzle_rules_saved"), NOTIFY_GENERIC, 3)
            else
                notification.AddLegacy(phrase("notice.muzzle_rules_save_failed"), NOTIFY_ERROR, 4)
            end
        end

        local reload = addButton(actions, phrase("button.reload_rules"))
        reload.DoClick = function()
            MF.LoadUserRules()
            refreshColorList(colorList)
            refreshRuleList(ruleList)
        end

        local reset = addButton(actions, phrase("button.reset_rules"))
        reset.DoClick = function()
            if not MF.ResetUserRules() then
                notification.AddLegacy(phrase("notice.muzzle_rules_save_failed"), NOTIFY_ERROR, 4)
            end
            refreshColorList(colorList)
            refreshRuleList(ruleList)
        end

        refreshColorList(colorList)
        refreshRuleList(ruleList)
    end
end
