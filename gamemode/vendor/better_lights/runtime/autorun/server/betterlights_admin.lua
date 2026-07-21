if SERVER then
    local BL = BetterLights
    local schema = BL.FLASHLIGHT_SETTING_DEFS

    local APPLY_COOLDOWN = 0.1
    local REQUEST_COOLDOWN = 0.25
    local ARCHIVE_FLAGS = FCVAR_ARCHIVE
    local STRING_FLAGS = FCVAR_ARCHIVE + FCVAR_PRINTABLEONLY
    local applyingSettings = false
    local settingsBroadcastQueued = false

    local modeCvar = CreateConVar(
        "betterlights_enable",
        tostring(BL.SERVER_MODE_ENABLED),
        FCVAR_ARCHIVE,
        "Better Lights server policy: 0 disabled, 1 enabled, 2 player choice",
        BL.SERVER_MODE_DISABLED,
        BL.SERVER_MODE_PLAYER_CHOICE
    )

    local modeMigrationCvar = CreateConVar(
        "betterlights_server_mode_migrated",
        "0",
        FCVAR_ARCHIVE,
        "Tracks the Better Lights server policy migration",
        0,
        1
    )

    -- Found Footage owns the lighting policy. Archived values from a mounted
    -- copy of Better Lights must never disable the curated runtime.
    modeCvar:SetInt(BL.SERVER_MODE_ENABLED)
    modeMigrationCvar:SetInt(1)

    local settingCvars = {}

    local function defaultString(def)
        if def.type == "bool" then return def.default and "1" or "0" end
        return tostring(def.default)
    end

    for i = 1, #schema do
        local def = schema[i]
        local valueFlags = def.type == "string" and STRING_FLAGS or ARCHIVE_FLAGS
        local valueMin = def.type == "bool" and 0 or def.min
        local valueMax = def.type == "bool" and 1 or def.max

        settingCvars[def.name] = {
            force = CreateConVar(
                def.serverForceCvar,
                "0",
                FCVAR_ARCHIVE,
                "Force the server value for " .. def.name,
                0,
                1
            ),
            value = CreateConVar(
                def.serverValueCvar,
                defaultString(def),
                valueFlags,
                "Stored server value for " .. def.name,
                valueMin,
                valueMax
            )
        }
    end

    for i = 1, #schema do
        local def = schema[i]
        if def.type == "string" then
            local cvar = settingCvars[def.name].value
            local value = BL.ValidateServerFlashlightSettingValue(def.name, cvar:GetString())
            cvar:SetString(value or def.default)
        end
    end

    util.AddNetworkString(BL.NET_SERVER_SETTINGS_REQUEST)
    util.AddNetworkString(BL.NET_SERVER_SETTINGS_APPLY)
    util.AddNetworkString(BL.NET_SERVER_SETTINGS_STATE)

    local function readStoredValue(def, cvar)
        if def.type == "bool" then return cvar:GetBool() end
        if def.type == "number" then return cvar:GetFloat() end
        return cvar:GetString()
    end

    function BL.GetServerMode()
        return BL.SERVER_MODE_ENABLED
    end

    function BL.IsServerEnabled()
        return BL.GetServerMode() ~= BL.SERVER_MODE_DISABLED
    end

    function BL.IsEnabledForPlayer(ply)
        local mode = BL.GetServerMode()
        if mode == BL.SERVER_MODE_DISABLED then return false end
        if mode == BL.SERVER_MODE_ENABLED then return true end

        return IsValid(ply) and ply.BetterLights_ClientEnabled == true
    end

    function BL.GetServerFlashlightOverride(name)
        local cvars = settingCvars[name]
        local def = BL.FLASHLIGHT_SETTING_BY_NAME[name]
        if not (cvars and def and cvars.force:GetBool()) then return nil end

        return readStoredValue(def, cvars.value)
    end

    function BL.GetEffectiveServerFlashlightBool(name, clientValue)
        local def = BL.FLASHLIGHT_SETTING_BY_NAME[name]
        if not (def and def.type == "bool") then return nil end

        local override = BL.GetServerFlashlightOverride(name)
        if override ~= nil then return override end

        return clientValue == true
    end

    BL.GetEffectiveFlashlightBool = BL.GetEffectiveServerFlashlightBool

    function BL.GetServerSettingsState()
        local state = {
            mode = BL.GetServerMode(),
            overrides = {},
            values = {}
        }

        for i = 1, #schema do
            local def = schema[i]
            local cvars = settingCvars[def.name]
            state.overrides[def.name] = cvars.force:GetBool()
            state.values[def.name] = readStoredValue(def, cvars.value)
        end

        return state
    end

    local function writeStoredValue(def, cvar, value)
        if def.type == "bool" then
            cvar:SetInt(value and 1 or 0)
        elseif def.type == "number" then
            cvar:SetFloat(value)
        else
            cvar:SetString(value)
        end
    end

    local function canChangeServerSettings(ply)
        return not IsValid(ply)
    end

    BL.CanChangeServerSettings = canChangeServerSettings

    local function sendServerSettings(ply)
        local state, err = BL.ValidateServerSettingsState(BL.GetServerSettingsState())
        if not state then
            ErrorNoHaltWithStack("[BetterLights] Could not serialize server settings: " .. tostring(err) .. "\n")
            return false
        end

        net.Start(BL.NET_SERVER_SETTINGS_STATE)
        local written, writeErr = BL.WriteServerSettingsState(state)
        if not written then
            ErrorNoHaltWithStack("[BetterLights] Could not write server settings: " .. tostring(writeErr) .. "\n")
            return false
        end

        if IsValid(ply) then
            net.Send(ply)
        else
            net.Broadcast()
        end

        return true
    end

    BL.SendServerSettingsState = sendServerSettings

    function BL.ApplyServerSettings(state, ply)
        if not canChangeServerSettings(ply) then return false, "not authorized" end

        local validated, err = BL.ValidateServerSettingsState(state)
        if not validated then return false, err end

        applyingSettings = true
        modeCvar:SetInt(validated.mode)

        for i = 1, #schema do
            local def = schema[i]
            local cvars = settingCvars[def.name]
            cvars.force:SetInt(validated.overrides[def.name] and 1 or 0)
            writeStoredValue(def, cvars.value, validated.values[def.name])
        end
        applyingSettings = false

        sendServerSettings()
        hook.Run("BetterLights_ServerSettingsChanged", validated, IsValid(ply) and ply or nil)
        return true
    end

    local function queueExternalSettingsChange()
        if applyingSettings or settingsBroadcastQueued then return end

        settingsBroadcastQueued = true
        timer.Simple(0, function()
            settingsBroadcastQueued = false
            if applyingSettings then return end

            local state, err = BL.ValidateServerSettingsState(BL.GetServerSettingsState())
            if not state then
                ErrorNoHaltWithStack("[BetterLights] Rejected an invalid server ConVar value: " .. tostring(err) .. "\n")
                return
            end

            sendServerSettings()
            hook.Run("BetterLights_ServerSettingsChanged", state)
        end)
    end

    cvars.AddChangeCallback("betterlights_enable", queueExternalSettingsChange, "BetterLights_ServerModeState")

    local function registerSettingCallbacks(def, cvarPair)
        cvars.AddChangeCallback(def.serverForceCvar, queueExternalSettingsChange, "BetterLights_ServerForceState_" .. def.id)

        if def.type == "string" then
            cvars.AddChangeCallback(def.serverValueCvar, function(_, old, new)
                if applyingSettings then return end

                local value = BL.ValidateServerFlashlightSettingValue(def.name, new)
                if value and value ~= new then
                    cvarPair.value:SetString(value)
                    return
                end

                if not value then
                    local oldValue = BL.ValidateServerFlashlightSettingValue(def.name, old)
                    cvarPair.value:SetString(oldValue or def.default)
                    return
                end

                queueExternalSettingsChange()
            end, "BetterLights_ServerValueState_" .. def.id)
        else
            cvars.AddChangeCallback(def.serverValueCvar, queueExternalSettingsChange, "BetterLights_ServerValueState_" .. def.id)
        end
    end

    for i = 1, #schema do
        local def = schema[i]
        registerSettingCallbacks(def, settingCvars[def.name])
    end

    net.Receive(BL.NET_SERVER_SETTINGS_REQUEST, function(_, ply)
        if not IsValid(ply) then return end

        local now = CurTime()
        if (ply.BetterLights_NextServerSettingsRequest or 0) > now then return end
        ply.BetterLights_NextServerSettingsRequest = now + REQUEST_COOLDOWN

        sendServerSettings(ply)
    end)

    net.Receive(BL.NET_SERVER_SETTINGS_APPLY, function(_, ply)
        if not (IsValid(ply) and canChangeServerSettings(ply)) then return end

        local now = CurTime()
        if (ply.BetterLights_NextServerSettingsApply or 0) > now then
            sendServerSettings(ply)
            return
        end
        ply.BetterLights_NextServerSettingsApply = now + APPLY_COOLDOWN

        local ok, state = pcall(BL.ReadServerSettingsState)
        if not ok or not state then
            sendServerSettings(ply)
            return
        end

        local applied = BL.ApplyServerSettings(state, ply)
        if not applied then sendServerSettings(ply) end
    end)
end
