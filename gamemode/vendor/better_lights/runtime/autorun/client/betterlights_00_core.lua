if CLIENT then
    local BL = BetterLights

    BL.VERSION = "v1.6.0-beta9"

    BL._networkHandlers = BL._networkHandlers or {}
    BL._clientConVars = BL._clientConVars or {}
    BL._clientConVarDefaults = BL._clientConVarDefaults or {}
    BL._clientConVarMetadata = BL._clientConVarMetadata or {}

    local MAIN_VIEW_POS_EPSILON_SQR = 1

    function BL.IsMainViewRender(isDrawingDepth)
        if isDrawingDepth then return false end

        -- Off-screen render.RenderView passes can run 3D hooks before the main view.
        return EyePos():DistToSqr(MainEyePos()) <= MAIN_VIEW_POS_EPSILON_SQR
    end

    function BL.AddNetworkHandler(msgType, fn)
        if not isfunction(fn) then return end
        BL._networkHandlers[msgType] = fn
    end

    net.Receive(BL.NET_EVENT_MESSAGE, function()
        local msgType = net.ReadUInt(4)
        if not BL.IsEnabled() then return end

        local handler = BL._networkHandlers[msgType]
        if handler then
            handler()
        end
    end)

    function BL.GetRegisteredClientConVars()
        return BL._clientConVars
    end

    function BL.GetRegisteredClientConVarDefaults()
        return BL._clientConVarDefaults
    end

    function BL.GetRegisteredClientConVarMetadata()
        return BL._clientConVarMetadata
    end

    function BL.GetClientConVarMetadata(name)
        return BL._clientConVarMetadata[name]
    end

    function BL.IsClientConVarProfileSetting(name)
        local metadata = BL.GetClientConVarMetadata(name)
        return not metadata or metadata.includeInProfiles ~= false
    end

    function BL.GetClientConVarDefault(name, fallback)
        local value = BL._clientConVarDefaults[name]
        if value ~= nil then return value end
        return fallback
    end

    function BL.ResolveClientResetDefaults(defaults)
        local resolved = {}

        for cvarName, fallback in pairs(defaults or {}) do
            resolved[cvarName] = BL.GetClientConVarDefault(cvarName, fallback)
        end

        return resolved
    end

    function BL.ApplyClientSetting(cvarName, value)
        local cvar = BL._clientConVars[cvarName]
        if not cvar then
            return false, "unknown"
        end

        if cvarName == "betterlights_flashlight_texture" then
            if BL.SetFlashlightTexturePath(value) then
                return true
            end

            return false, "flashlight_texture_unavailable"
        end

        value = tostring(value)
        if cvar:GetString() ~= value then
            cvar:SetString(value)
        end

        return true
    end

    function BL.ApplyClientSettings(settings)
        local result = {
            applied = 0,
            skipped = {},
            skippedUnknown = 0,
            flashlightTextureUnavailable = false
        }

        for cvarName, value in pairs(settings or {}) do
            local ok, reason = BL.ApplyClientSetting(cvarName, value)
            if ok then
                result.applied = result.applied + 1
            else
                result.skipped[#result.skipped + 1] = {
                    name = cvarName,
                    reason = reason
                }

                if reason == "unknown" then
                    result.skippedUnknown = result.skippedUnknown + 1
                elseif reason == "flashlight_texture_unavailable" then
                    result.flashlightTextureUnavailable = true
                end
            end
        end

        return result
    end

    function BL.ResetRegisteredClientSettings()
        return BL.ApplyClientSettings(BL.GetRegisteredClientConVarDefaults())
    end

    function BL.CreateClientConVar(name, defaultValue, shouldSave, userData, helpText, min, max, metadata)
        BL._clientConVarDefaults[name] = tostring(defaultValue)
        BL._clientConVarMetadata[name] = metadata or {}
        local cvar = CreateClientConVar(name, tostring(defaultValue), shouldSave, userData, helpText, min, max)
        BL._clientConVars[name] = cvar
        return cvar
    end

    function BL.CreateConVarSet(prefix, defaults)
        defaults = defaults or {}
        local cvars = {}

        if defaults.enable ~= nil then
            cvars.enable = BL.CreateClientConVar(prefix .. "_enable", defaults.enable, true, false, defaults.enableDesc or "Enable this lighting effect")
        end

        if defaults.size then
            cvars.size = BL.CreateClientConVar(prefix .. "_size", defaults.size, true, false, defaults.sizeDesc or "Light radius")
        end

        if defaults.brightness then
            cvars.brightness = BL.CreateClientConVar(prefix .. "_brightness", defaults.brightness, true, false, defaults.brightnessDesc or "Light brightness")
        end

        if defaults.decay then
            cvars.decay = BL.CreateClientConVar(prefix .. "_decay", defaults.decay, true, false, defaults.decayDesc or "Light decay")
        end

        if defaults.r and defaults.g and defaults.b then
            cvars.r = BL.CreateClientConVar(prefix .. "_color_r", defaults.r, true, false, defaults.rDesc or "Red (0-255)")
            cvars.g = BL.CreateClientConVar(prefix .. "_color_g", defaults.g, true, false, defaults.gDesc or "Green (0-255)")
            cvars.b = BL.CreateClientConVar(prefix .. "_color_b", defaults.b, true, false, defaults.bDesc or "Blue (0-255)")
        end

        return cvars
    end

end
