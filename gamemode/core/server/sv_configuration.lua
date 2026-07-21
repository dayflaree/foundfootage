local function enforceServerConVars()
    for name, desired in pairs(FF_CONFIG.LockedServerConVars or {}) do
        local convar = GetConVar(name)
        if convar and convar:GetString() ~= tostring(desired) then
            RunConsoleCommand(name, tostring(desired))
        end
    end
end

timer.Simple(0, enforceServerConVars)
hook.Add("Initialize", "FF_ApplyServerConfiguration", enforceServerConVars)
timer.Create("FF_EnforceServerConfiguration", 2, 0, enforceServerConVars)

for name, configuredValue in pairs(FF_CONFIG.LockedServerConVars or {}) do
    local lockedName = name
    local lockedValue = tostring(configuredValue)

    if ConVarExists(lockedName) then
        cvars.AddChangeCallback(lockedName, function(_, _, newValue)
            if tostring(newValue) == lockedValue then return end

            timer.Simple(0, function()
                if GetConVar(lockedName) then
                    RunConsoleCommand(lockedName, lockedValue)
                end
            end)
        end, "FF_ServerLock_" .. lockedName)
    end
end
