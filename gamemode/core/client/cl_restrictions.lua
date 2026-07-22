local restrictions = FF_CONFIG.Restrictions
local movement = FF_CONFIG.Movement

local function removeScoreboard()
    if IsValid(g_Scoreboard) then
        g_Scoreboard:Remove()
    end

    g_Scoreboard = nil
end

if restrictions.Scoreboard == false then
    function GM:ScoreboardShow()
        removeScoreboard()
        return false
    end

    function GM:ScoreboardHide()
        removeScoreboard()
    end

    timer.Simple(0, removeScoreboard)
    hook.Add("OnReloaded", "FF_RemoveScoreboard", removeScoreboard)
end

local function removeVoiceHUD()
    hook.Remove("InitPostEntity", "CreateVoiceVGUI")

    if IsValid(g_VoicePanelList) then
        g_VoicePanelList:Remove()
    end

    g_VoicePanelList = nil
end

if restrictions.VoiceHUD == false then
    function GM:PlayerStartVoice()
        removeVoiceHUD()
    end

    function GM:PlayerEndVoice()
    end

    function GM:DrawVoiceIcon()
    end

    removeVoiceHUD()
    timer.Simple(0, removeVoiceHUD)
    hook.Add("InitPostEntity", "FF_RemoveVoiceHUD", removeVoiceHUD)
    hook.Add("OnReloaded", "FF_RemoveVoiceHUDReload", removeVoiceHUD)
end

if not restrictions.DefaultHUD then
    hook.Add("HUDShouldDraw", "FF_HideDefaultHUD", function()
        return false
    end)

    hook.Add("HUDDrawTargetID", "FF_HideTargetID", function()
        return false
    end)

    hook.Add("DrawDeathNotice", "FF_HideDeathNotice", function()
        return false
    end)
end

hook.Remove("SpawnMenuOpen", "FF_BlockSpawnMenu")
hook.Remove("OnSpawnMenuOpen", "FF_CloseSpawnMenu")

if not restrictions.SpawnMenu then
    hook.Add("SpawnMenuOpen", "FF_BlockSpawnMenu", function()
        return false
    end)

    hook.Add("OnSpawnMenuOpen", "FF_CloseSpawnMenu", function()
        if spawnmenu and spawnmenu.Close then
            spawnmenu.Close()
        end
    end)
end

hook.Remove("ContextMenuOpen", "FF_BlockContextMenu")
hook.Remove("OnContextMenuOpen", "FF_CloseContextMenu")

if not restrictions.ContextMenu then
    hook.Add("ContextMenuOpen", "FF_BlockContextMenu", function()
        return false
    end)

    hook.Add("OnContextMenuOpen", "FF_CloseContextMenu", function()
        if g_ContextMenu and IsValid(g_ContextMenu) then
            g_ContextMenu:Close()
        end
    end)
end

local blockedBinds = {
    ["gm_showhelp"] = true,
    ["gm_showteam"] = true,
    ["gm_showspare1"] = true,
    ["gm_showspare2"] = true,
}

if restrictions.SpawnMenu == false then
    blockedBinds["+menu"] = true
end

if restrictions.ContextMenu == false then
    blockedBinds["+menu_context"] = true
end

if restrictions.Scoreboard == false then
    blockedBinds["+showscores"] = true
    blockedBinds["-showscores"] = true
end

if restrictions.TextChat == false then
    blockedBinds["messagemode"] = true
    blockedBinds["messagemode2"] = true
    blockedBinds["say"] = true
    blockedBinds["say_team"] = true
end

if not movement.SuitZoomEnabled then
    blockedBinds["+zoom"] = true
end
if not movement.FlashlightEnabled then
    blockedBinds["impulse 100"] = true
end

hook.Add("PlayerBindPress", "FF_BlockRestrictedBinds", function(_, bind)
    bind = string.lower(string.Trim(bind or ""))

    for blocked in pairs(blockedBinds) do
        if bind == blocked or string.StartWith(bind, blocked .. " ") then
            return true
        end
    end
end)

local blockedButtons = 0
if not movement.JumpEnabled then
    blockedButtons = bit.bor(blockedButtons, IN_JUMP)
end
if not movement.SprintEnabled then
    blockedButtons = bit.bor(blockedButtons, IN_SPEED)
end
if not movement.SuitZoomEnabled then
    blockedButtons = bit.bor(blockedButtons, IN_ZOOM)
end

hook.Add("CreateMove", "FF_BlockPredictedInputs", function(command)
    if blockedButtons ~= 0 then
        command:SetButtons(bit.band(command:GetButtons(), bit.bnot(blockedButtons)))
    end

    if not movement.FlashlightEnabled and command:GetImpulse() == 100 then
        command:SetImpulse(0)
    end
end)

FF_CLIENT_CONVAR_OVERRIDES = FF_CLIENT_CONVAR_OVERRIDES or {}

local function desiredClientConVarValue(name, configuredValue)
    local override = FF_CLIENT_CONVAR_OVERRIDES[name]
    if override then
        if RealTime() < override.expires then
            return tostring(override.value)
        end

        FF_CLIENT_CONVAR_OVERRIDES[name] = nil
    end

    return tostring(configuredValue)
end

function FF_SetTemporaryClientConVarOverride(name, value, duration)
    if FF_CONFIG.LockedClientConVars[name] == nil then return false end

    duration = math.max(tonumber(duration) or 0, 0)
    FF_CLIENT_CONVAR_OVERRIDES[name] = {
        value = tostring(value),
        expires = RealTime() + duration,
    }

    RunConsoleCommand(name, tostring(value))

    local timerName = "FF_ClientConVarOverride_" .. string.gsub(name, "[^%w_]", "_")
    timer.Create(timerName, duration, 1, function()
        FF_CLIENT_CONVAR_OVERRIDES[name] = nil
        local configured = FF_CONFIG.LockedClientConVars[name]
        if configured ~= nil and GetConVar(name) then
            RunConsoleCommand(name, tostring(configured))
        end
    end)

    return true
end

local function enforceClientConVars()
    for name, configuredValue in pairs(FF_CONFIG.LockedClientConVars) do
        local desired = desiredClientConVarValue(name, configuredValue)
        local convar = GetConVar(name)
        if convar and convar:GetString() ~= desired then
            RunConsoleCommand(name, desired)
        end
    end
end

hook.Add("InitPostEntity", "FF_ApplyLockedClientConVars", function()
    timer.Simple(0, enforceClientConVars)
end)

timer.Create("FF_EnforceClientConVars", 2, 0, enforceClientConVars)

for name, configuredValue in pairs(FF_CONFIG.LockedClientConVars) do
    local lockedName = name
    local lockedConfiguredValue = tostring(configuredValue)

    if ConVarExists(lockedName) then
        cvars.AddChangeCallback(lockedName, function(_, _, newValue)
            local desired = desiredClientConVarValue(lockedName, lockedConfiguredValue)
            if tostring(newValue) == desired then return end

            timer.Simple(0, function()
                if GetConVar(lockedName) then
                    RunConsoleCommand(lockedName, desiredClientConVarValue(lockedName, lockedConfiguredValue))
                end
            end)
        end, "FF_Lock_" .. lockedName)
    end
end
