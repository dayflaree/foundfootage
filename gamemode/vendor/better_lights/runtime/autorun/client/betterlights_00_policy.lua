if CLIENT then
    local BL = BetterLights
    local schema = BL.FLASHLIGHT_SETTING_DEFS

    local cvar_client_enable = BL.CreateClientConVar(
        "betterlights_client_enable",
        "1",
        true,
        false,
        "Enable Better Lights for this client when the server allows player choice",
        nil,
        nil,
        { includeInProfiles = false }
    )

    local function boolValue(value)
        if type(value) == "boolean" then return value end
        if type(value) == "number" then return value ~= 0 end

        value = string.lower(tostring(value or ""))
        return value ~= "" and value ~= "0" and value ~= "false"
    end

    local function makeDefaultState()
        local state = {
            mode = BL.SERVER_MODE_PLAYER_CHOICE,
            overrides = {},
            values = {}
        }

        for i = 1, #schema do
            local def = schema[i]
            state.overrides[def.name] = false
            state.values[def.name] = def.default
        end

        return state
    end

    local function copyState(state)
        local copy = {
            mode = state.mode,
            overrides = {},
            values = {}
        }

        for i = 1, #schema do
            local name = schema[i].name
            copy.overrides[name] = state.overrides[name]
            copy.values[name] = state.values[name]
        end

        return copy
    end

    local initialState = BL.ValidateServerSettingsState(BL._serverSettingsState)
    BL._serverSettingsState = initialState or makeDefaultState()
    BL._hasServerSettingsState = BL._hasServerSettingsState == true and initialState ~= nil

    function BL.GetServerMode()
        return BL._serverSettingsState.mode
    end

    function BL.HasServerSettingsState()
        return BL._hasServerSettingsState
    end

    function BL.GetServerSettingsState()
        return copyState(BL._serverSettingsState)
    end

    function BL.IsClientEnabledPreference()
        return cvar_client_enable:GetBool()
    end

    function BL.CanChangeClientEnabledPreference()
        return BL.HasServerSettingsState()
            and BL.GetServerMode() == BL.SERVER_MODE_PLAYER_CHOICE
    end

    function BL.IsEnabled()
        if not BL.HasServerSettingsState() then return false end

        local mode = BL.GetServerMode()
        if mode == BL.SERVER_MODE_DISABLED then return false end
        if mode == BL.SERVER_MODE_ENABLED then return true end
        return BL.IsClientEnabledPreference()
    end

    local lastEffectiveEnabled = BL.IsEnabled()

    local function emitEffectiveEnabledChange(previous)
        local enabled = BL.IsEnabled()
        previous = previous == nil and lastEffectiveEnabled or previous
        lastEffectiveEnabled = enabled

        if enabled ~= previous then
            hook.Run("BetterLights_EffectiveEnabledChanged", enabled, previous)
        end
    end

    function BL.SetClientEnabledPreference(enabled)
        enabled = boolValue(enabled)

        if not BL.CanChangeClientEnabledPreference() then
            hook.Run("BetterLights_ClientEnabledChangeBlocked", enabled, BL.GetServerMode())
            return false, "server_controlled"
        end

        if cvar_client_enable:GetBool() ~= enabled then
            cvar_client_enable:SetBool(enabled)
        end

        return true, enabled
    end

    function BL.ToggleClientEnabled()
        return BL.SetClientEnabledPreference(not BL.IsClientEnabledPreference())
    end

    local function getPersonalValue(name, valueType, fallback)
        local def = BL.FLASHLIGHT_SETTING_BY_NAME[name]
        local cvar = def and GetConVar(def.name) or nil

        if valueType == "bool" then
            if cvar then return cvar:GetBool() end
            if fallback ~= nil then return boolValue(fallback) end
            return def and boolValue(def.default) or false
        end

        if valueType == "number" then
            if cvar then return cvar:GetFloat() end
            if fallback ~= nil then return tonumber(fallback) or 0 end
            return def and tonumber(def.default) or 0
        end

        if cvar then return cvar:GetString() end
        if fallback ~= nil then return tostring(fallback) end
        return def and tostring(def.default) or ""
    end

    local function getEffectiveValue(name, valueType, fallback)
        local def = BL.FLASHLIGHT_SETTING_BY_NAME[name]
        if not def or def.type ~= valueType then
            return getPersonalValue(name, valueType, fallback)
        end

        local state = BL._serverSettingsState
        if state.overrides[name] then
            return state.values[name]
        end

        return getPersonalValue(name, valueType, fallback)
    end

    function BL.IsFlashlightSettingForced(name)
        return BL.FLASHLIGHT_SETTING_BY_NAME[name] ~= nil
            and BL._serverSettingsState.overrides[name] == true
    end

    function BL.GetEffectiveFlashlightBool(name, fallback)
        return boolValue(getEffectiveValue(name, "bool", fallback))
    end

    function BL.GetEffectiveFlashlightNumber(name, fallback)
        return tonumber(getEffectiveValue(name, "number", fallback)) or tonumber(fallback) or 0
    end

    function BL.GetEffectiveFlashlightString(name, fallback)
        return tostring(getEffectiveValue(name, "string", fallback))
    end

    function BL.RequestServerSettings()
        if not IsValid(LocalPlayer()) then return false, "local_player_unavailable" end

        net.Start(BL.NET_SERVER_SETTINGS_REQUEST)
        net.SendToServer()
        return true
    end

    function BL.SubmitServerSettings(state)
        if not IsValid(LocalPlayer()) then return false, "local_player_unavailable" end

        local validated, err = BL.ValidateServerSettingsState(state)
        if not validated then return false, err end

        net.Start(BL.NET_SERVER_SETTINGS_APPLY)
        BL.WriteServerSettingsState(validated)
        net.SendToServer()
        return true
    end

    local function receiveServerSettings()
        local state, err = BL.ReadServerSettingsState()
        if not state then
            hook.Run("BetterLights_ServerSettingsReceiveFailed", err)
            return
        end

        local previousState = BL._serverSettingsState
        local previousEnabled = BL.IsEnabled()

        BL._serverSettingsState = state
        BL._hasServerSettingsState = true

        hook.Run("BetterLights_ServerSettingsChanged", copyState(state), copyState(previousState))

        emitEffectiveEnabledChange(previousEnabled)
    end

    net.Receive(BL.NET_SERVER_SETTINGS_STATE, receiveServerSettings)

    cvars.AddChangeCallback("betterlights_client_enable", function(_, oldValue, newValue)
        local oldPreference = boolValue(oldValue)
        local newPreference = boolValue(newValue)

        if oldPreference ~= newPreference then
            hook.Run("BetterLights_ClientEnabledPreferenceChanged", newPreference, oldPreference)
        end

        emitEffectiveEnabledChange()
    end, "BetterLights_ClientEnablePolicy")

    concommand.Add("betterlights_toggle", function()
        BL.ToggleClientEnabled()
    end)

    hook.Add("InitPostEntity", "BetterLights_RequestServerSettings", function()
        BL.RequestServerSettings()
    end)

    hook.Add("OnReloaded", "BetterLights_RequestServerSettingsReload", function()
        timer.Simple(0, BL.RequestServerSettings)
    end)

    if IsValid(LocalPlayer()) then
        timer.Simple(0, BL.RequestServerSettings)
    end
end
