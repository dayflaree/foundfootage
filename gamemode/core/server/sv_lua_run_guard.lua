-- Some maps contain lua_run entities that fire RunCode without a Code
-- keyvalue. Garry's Mod's base entity forwards nil to RunString, which throws.
-- Keep the fix local to this gamemode and leave the base gamemode untouched.

local function sanitizeEntity(entity)
    if not IsValid(entity) or entity:GetClass() ~= "lua_run" then return end
    if not entity.GetDefaultCode or not entity.SetDefaultCode then return end

    local code = entity:GetDefaultCode()
    if not isstring(code) then
        entity:SetDefaultCode("")
    end
end

local function installClassGuard()
    local stored = scripted_ents.GetStored("lua_run")
    local definition = stored and stored.t
    if not istable(definition) or definition.FF_NilCodeGuardInstalled then return false end

    local originalRunCode = definition.RunCode
    if not isfunction(originalRunCode) then return false end

    definition.FF_NilCodeGuardInstalled = true
    definition.FF_OriginalRunCode = originalRunCode

    function definition:RunCode(activator, caller, code)
        if not isstring(code) then
            code = self.GetDefaultCode and self:GetDefaultCode() or ""
        end

        if not isstring(code) then
            code = ""
        end

        -- Empty map inputs are intentional no-ops. Avoid calling RunString so
        -- malformed lua_run entities cannot generate errors or execute data of
        -- an unexpected type.
        if code == "" then
            return false
        end

        return originalRunCode(self, activator, caller, code)
    end

    return true
end

-- Base gamemode entities are normally registered before this file is included.
-- The hooks are fallbacks for unusual load orders and hot reloads.
installClassGuard()
hook.Add("Initialize", "FF_InstallLuaRunNilGuard", installClassGuard)
hook.Add("OnReloaded", "FF_ReinstallLuaRunNilGuard", installClassGuard)

hook.Add("OnEntityCreated", "FF_SanitizeLuaRunEntity", function(entity)
    if not IsValid(entity) or entity:GetClass() ~= "lua_run" then return end

    -- OnEntityCreated runs before map keyvalues are applied. A valid Code
    -- keyvalue will replace this empty default before the entity initializes.
    sanitizeEntity(entity)
end)

hook.Add("InitPostEntity", "FF_SanitizeExistingLuaRunEntities", function()
    installClassGuard()

    for _, entity in ipairs(ents.FindByClass("lua_run")) do
        sanitizeEntity(entity)
    end
end)
