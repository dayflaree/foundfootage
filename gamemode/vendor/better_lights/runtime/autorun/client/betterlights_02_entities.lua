if CLIENT then

    local BL = BetterLights
    local tracePools = {}

    BL._classes = BL._classes or {}
    BL._tracked = BL._tracked or {}
    BL._removeHandlers = BL._removeHandlers or {}
    BL._attachCache = BL._attachCache or {}

    local function applyPositionOptions(ent, pos, options)
        if not pos then return nil end
        if not options then return pos end

        local localOffset = options.localOffset or options.offset
        if localOffset and ent.LocalToWorld and ent.GetPos then
            pos = pos + ent:LocalToWorld(localOffset) - ent:GetPos()
        end

        if options.worldOffset then
            pos = pos + options.worldOffset
        end

        return pos
    end

    function BL.IsEntityClass(ent, classes)
        if not IsValid(ent) then return false end
        if not ent.GetClass then return false end

        local cls = ent:GetClass()
        if type(classes) == "string" then
            return cls == classes
        elseif type(classes) == "table" then
            for _, checkClass in ipairs(classes) do
                if cls == checkClass then return true end
            end
        end
        return false
    end

    function BL.MatchesModel(ent, pattern)
        if not IsValid(ent) then return false end
        if not ent.GetModel then return false end

        local mdl = string.lower(ent:GetModel() or "")
        return string.find(mdl, string.lower(pattern), 1, true) ~= nil
    end

    function BL.TrackClass(classname)
        if type(classname) ~= "string" or classname == "" then return end
        if BL._classes[classname] then return end

        BL._classes[classname] = true
        BL._tracked[classname] = BL._tracked[classname] or {}

        timer.Simple(0, function()
            if not BL._classes[classname] then return end
            for _, ent in ipairs(ents.FindByClass(classname)) do
                if IsValid(ent) then BL._tracked[classname][ent] = true end
            end
        end)
    end

    function BL.ForEach(classname, fn)
        local set = BL._tracked[classname]
        if not set then return end

        for ent, _ in pairs(set) do
            if not IsValid(ent) then
                set[ent] = nil
            else
                fn(ent)
            end
        end
    end

    function BL.AddRemoveHandler(classname, fn)
        if type(classname) ~= "string" or not isfunction(fn) then return end

        BL._removeHandlers[classname] = BL._removeHandlers[classname] or {}
        table.insert(BL._removeHandlers[classname], fn)
    end

    function BL.GetEntityCenter(ent, options)
        if not IsValid(ent) then return nil end
        local pos
        if ent.LocalToWorld and ent.OBBCenter then
            pos = ent:LocalToWorld(ent:OBBCenter())
        elseif ent.WorldSpaceCenter then
            pos = ent:WorldSpaceCenter()
        else
            pos = ent:GetPos()
        end

        return applyPositionOptions(ent, pos, options)
    end

    function BL.LookupAttachmentCached(ent, names)
        if not (IsValid(ent) and ent.LookupAttachment and ent.GetModel) then return nil end

        local mdl = ent:GetModel() or ""
        local cache = BL._attachCache[mdl]
        if not cache then
            cache = {}
            BL._attachCache[mdl] = cache
        end

        for i = 1, #names do
            local name = names[i]
            local id = cache[name]
            if id == nil then
                local lid = ent:LookupAttachment(name)
                cache[name] = lid or false
                id = cache[name]
            end
            if id and id ~= false and id > 0 then
                return id
            end
        end
        return nil
    end

    function BL.GetAttachmentTransform(ent, names, options)
        local id = BL.LookupAttachmentCached(ent, names)
        if id then return BL.GetAttachmentTransformById(ent, id, options) end
        return nil
    end

    function BL.TraceLineReuse(key, data)
        local t = tracePools[key]
        if not t then
            t = {}
            tracePools[key] = t
        end

        t.start = data.start
        t.endpos = data.endpos
        t.filter = data.filter
        t.mask = data.mask
        t.mins = data.mins
        t.maxs = data.maxs
        return util.TraceLine(t)
    end

    function BL.IsPlayerHoldingWeapon(weaponClass)
        local ply = LocalPlayer()
        if not IsValid(ply) then return false end

        local wep = ply:GetActiveWeapon()
        return IsValid(wep) and wep:GetClass() == weaponClass
    end

    function BL.GetPlayerEyeTrace(distance, filter)
        local ply = LocalPlayer()
        if not IsValid(ply) then return nil end

        local start = ply:EyePos()
        local endpos = start + ply:EyeAngles():Forward() * (distance or 8192)
        return util.TraceLine({
            start = start,
            endpos = endpos,
            filter = filter or ply
        })
    end

    function BL.GetAttachmentTransformById(ent, attachId, options)
        if not IsValid(ent) or not attachId or attachId <= 0 then return nil end
        if not ent.GetAttachment then return nil end

        local data = ent:GetAttachment(attachId)
        if not (data and data.Pos) then return nil end
        if not options then return data end

        return {
            Pos = applyPositionOptions(ent, data.Pos, options),
            Ang = data.Ang,
            Bone = data.Bone
        }
    end

    function BL.GetAttachmentPos(ent, names, options)
        local data = BL.GetAttachmentTransform(ent, names, options)
        return (data and data.Pos) or nil
    end

    function BL.GetAttachmentPosById(ent, attachId, options)
        local data = BL.GetAttachmentTransformById(ent, attachId, options)
        return (data and data.Pos) or nil
    end

    function BL.GetBonePosition(ent, boneName)
        if not IsValid(ent) or not boneName then return nil end
        if not ent.LookupBone then return nil end

        local bone = ent:LookupBone(boneName)
        if not bone or bone < 0 then return nil end

        if ent.GetBoneMatrix then
            local m = ent:GetBoneMatrix(bone)
            if m then
                local pos = m:GetTranslation()
                if pos and pos ~= vector_origin then
                    return pos
                end
            end
        end

        if ent.GetBonePosition then
            local pos = ent:GetBonePosition(bone)
            if pos and pos ~= vector_origin then
                return pos
            end
        end

        return nil
    end

    function BL.CreateLightFromAttachment(ent, attachNames, r, g, b, brightness, decay, size, isElight, options)
        if not IsValid(ent) then return false end

        local pos = BL.GetAttachmentPos(ent, attachNames, options)
        if not pos then return false end

        BL.CreateDLight(ent:EntIndex(), pos, r, g, b, brightness, decay, size, isElight)
        return true
    end

    function BL.CreateLightAtEntityCenter(ent, index, r, g, b, brightness, decay, size, isElight, options)
        local pos = BL.GetEntityCenter(ent, options)
        if not pos then return false end

        BL.CreateDLight(index, pos, r, g, b, brightness, decay, size, isElight, options)
        return true, pos
    end

    hook.Add("OnEntityCreated", "BetterLights_CoreTrackCreate", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) then return end

            local cls = (ent.GetClass and ent:GetClass()) or ""
            if BL._classes[cls] then
                BL._tracked[cls] = BL._tracked[cls] or {}
                BL._tracked[cls][ent] = true
            end
        end)
    end)

    hook.Add("EntityRemoved", "BetterLights_CoreTrackRemove", function(ent, fullUpdate)
        if fullUpdate then return end
        if not ent then return end

        local cls = (ent.GetClass and ent:GetClass()) or nil
        if not cls then return end

        local set = BL._tracked[cls]
        if set and set[ent] then set[ent] = nil end

        local handlers = BL._removeHandlers[cls]
        if handlers then
            for _, fn in ipairs(handlers) do
                pcall(fn, ent)
            end
        end
    end)
end
