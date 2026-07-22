-- Found Footage suppresses bundled debug-only console output.
local print = FF_DiscardOutput

if CLIENT then

    local BL = BetterLights

    local function debugVariantDetection(debugCvar, ent, message, ...)
        if not (debugCvar and debugCvar:GetBool()) then return end
        print(string.format("[BetterLights] Entity #%d detected as " .. message, ent:EntIndex(), ...))
    end

    local function detectVariantByClass(ent, options, debugName, debugCvar)
        if options.classes then
            local class = ent:GetClass()
            for _, checkClass in ipairs(options.classes) do
                if class == checkClass then
                    debugVariantDetection(debugCvar, ent, "%s via class: %s", debugName, class)
                    return true
                end
            end
        end
        return false
    end

    local function detectVariantByNWBool(ent, options, debugName, debugCvar)
        if options.nwBools and ent.GetNWBool then
            for _, key in ipairs(options.nwBools) do
                if ent:GetNWBool(key, false) then
                    debugVariantDetection(debugCvar, ent, "%s via NWBool: %s", debugName, key)
                    return true
                end
            end
        end
        return false
    end

    local function detectVariantBySaveTable(ent, options, debugName, debugCvar)
        if not ((options.saveTableKeys or options.saveTableKeyword) and ent.GetSaveTable) then return false end

        local ok, st = pcall(ent.GetSaveTable, ent)
        if not (ok and st) then return false end

        if options.saveTableKeys then
            for _, key in ipairs(options.saveTableKeys) do
                if st[key] == true or st[key] == 1 then
                    debugVariantDetection(debugCvar, ent, "%s via SaveTable: %s", debugName, key)
                    return true
                end
            end
        end

        if options.saveTableKeyword then
            for k, v in pairs(st) do
                local lk = tostring(k):lower()
                if lk:find(options.saveTableKeyword, 1, true) and (v == true or v == 1) then
                    debugVariantDetection(debugCvar, ent, "%s via SaveTable keyword '%s': %s", debugName, options.saveTableKeyword, k)
                    return true
                end
            end
        end

        return false
    end

    local function detectVariantByDisposition(ent, options, debugName, debugCvar)
        if options.checkDisposition and ent.Disposition then
            local lp = LocalPlayer()
            if IsValid(lp) then
                local ok, disp = pcall(function() return ent:Disposition(lp) end)
                if ok and disp == D_LI then
                    debugVariantDetection(debugCvar, ent, "%s via Disposition", debugName)
                    return true
                end
            end
        end
        return false
    end

    local function detectVariantBySkin(ent, options, debugName, debugCvar)
        if not (options.skin and ent.GetSkin) then return false end

        local ok, skin = pcall(ent.GetSkin, ent)
        if not (ok and type(skin) == "number") then return false end

        if type(options.skin) == "number" and skin == options.skin then
            debugVariantDetection(debugCvar, ent, "%s via skin: %d", debugName, skin)
            return true
        end

        if type(options.skin) == "function" and options.skin(skin) then
            debugVariantDetection(debugCvar, ent, "%s via skin check: %d", debugName, skin)
            return true
        end

        return false
    end

    local function detectVariantByTargetName(ent, options, debugName, debugCvar)
        if options.targetname and ent.GetName then
            local ok, name = pcall(ent.GetName, ent)
            if ok and isstring(name) then
                local nm = string.lower(name)
                if nm:find(options.targetname, 1, true) then
                    debugVariantDetection(debugCvar, ent, "%s via targetname: %s", debugName, name)
                    return true
                end
            end
        end
        return false
    end

    function BL.DetectEntityVariant(ent, options)
        if not IsValid(ent) then return false end

        options = options or {}
        local debugName = options.debugName or "variant"
        local debugCvar = options.debugCvar

        if detectVariantByClass(ent, options, debugName, debugCvar) then return true end
        if detectVariantByNWBool(ent, options, debugName, debugCvar) then return true end
        if detectVariantBySaveTable(ent, options, debugName, debugCvar) then return true end
        if detectVariantByDisposition(ent, options, debugName, debugCvar) then return true end
        if detectVariantBySkin(ent, options, debugName, debugCvar) then return true end
        if detectVariantByTargetName(ent, options, debugName, debugCvar) then return true end

        return false
    end

    function BL.DetectSkinVariant(ent, skinMap)
        if not IsValid(ent) or not skinMap then return nil end

        local skin = (ent.GetSkin and ent:GetSkin()) or 0
        return skinMap[skin]
    end

    function BL.DetectModelVariant(ent, modelPatterns)
        if not IsValid(ent) or not modelPatterns then return nil end

        local skin = (ent.GetSkin and ent:GetSkin()) or 0
        for _, pattern in ipairs(modelPatterns) do
            if BL.MatchesModel(ent, pattern.model) then
                if pattern.skinMap then
                    return pattern.skinMap[skin] or pattern.default
                end
                return pattern.default
            end
        end
        return nil
    end
end
