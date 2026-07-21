if CLIENT then

    local BL = BetterLights
    local PROFILES = BL.Profiles or {}
    BL.Profiles = PROFILES

    local PROFILE_DIR = "betterlights"
    local PROFILE_PATH = PROFILE_DIR .. "/profiles.json"
    local SCHEMA_VERSION = 1
    local EXPORT_TYPE = "betterlights" .. ".settings_profile"
    local SHARE_CODE_PREFIX = "BLP1:"
    local MAX_EXPORT_JSON_BYTES = 256 * 1024
    local MAX_SHARE_TEXT_BYTES = 384 * 1024
    local MAX_NAME_LENGTH = 48

    local function copySettings(settings)
        local out = {}

        for cvarName, value in pairs(settings or {}) do
            cvarName = tostring(cvarName)
            if BL.IsClientConVarProfileSetting(cvarName) then
                out[cvarName] = tostring(value)
            end
        end

        return out
    end

    local function countSettings(settings)
        local count = 0

        for _ in pairs(settings or {}) do
            count = count + 1
        end

        return count
    end

    local function normalizeName(name)
        name = string.Trim(tostring(name or ""))
        if name == "" then
            return nil, "notice.profile_name_required"
        end

        if string.len(name) > MAX_NAME_LENGTH then
            return nil, "notice.profile_name_too_long"
        end

        return name
    end

    local function namesMatch(a, b)
        return string.lower(tostring(a or "")) == string.lower(tostring(b or ""))
    end

    local function encodeShareCode(json)
        if type(json) ~= "string" or json == "" then
            return nil, "notice.profile_export_failed"
        end

        if string.len(json) > MAX_EXPORT_JSON_BYTES then
            return nil, "notice.profile_export_too_large"
        end

        local compressed = util.Compress(json)
        if not compressed or compressed == "" then
            return nil, "notice.profile_export_failed"
        end

        local encoded = util.Base64Encode(compressed, true)
        if not encoded or encoded == "" then
            return nil, "notice.profile_export_failed"
        end

        return SHARE_CODE_PREFIX .. encoded
    end

    local function decodeShareSource(source)
        source = tostring(source or "")
        if string.len(source) > MAX_SHARE_TEXT_BYTES then
            return nil, "notice.profile_import_too_large"
        end

        source = string.Trim(source)
        if string.sub(source, 1, string.len(SHARE_CODE_PREFIX)) ~= SHARE_CODE_PREFIX then
            if string.len(source) > MAX_EXPORT_JSON_BYTES then
                return nil, "notice.profile_import_too_large"
            end

            return source
        end

        local encoded = string.sub(source, string.len(SHARE_CODE_PREFIX) + 1)
        if encoded == "" then
            return nil, "notice.profile_import_malformed"
        end

        local compressed = util.Base64Decode(encoded)
        if not compressed or compressed == "" then
            return nil, "notice.profile_import_malformed"
        end

        local json = util.Decompress(compressed, MAX_EXPORT_JSON_BYTES)
        if not json or json == "" then
            return nil, "notice.profile_import_malformed"
        end

        return json
    end

    local function normalizeProfile(profile)
        if type(profile) ~= "table" then return nil end

        local name = normalizeName(profile.name)
        if not name then return nil end

        local settings = copySettings(profile.settings)
        if countSettings(settings) == 0 then return nil end

        return {
            id = tostring(profile.id or ""),
            name = name,
            createdAt = tonumber(profile.createdAt) or os.time(),
            updatedAt = tonumber(profile.updatedAt) or os.time(),
            addonVersion = tostring(profile.addonVersion or ""),
            settings = settings
        }
    end

    local function defaultStore()
        return {
            schemaVersion = SCHEMA_VERSION,
            profiles = {}
        }
    end

    local function ensureStore()
        if PROFILES._store then return PROFILES._store end

        local source = file.Read(PROFILE_PATH, "DATA")
        if not source or source == "" then
            PROFILES._store = defaultStore()
            return PROFILES._store
        end

        local decoded = util.JSONToTable(source)
        if type(decoded) ~= "table" then
            PROFILES._store = defaultStore()
            return PROFILES._store
        end

        local store = defaultStore()
        if type(decoded.profiles) == "table" then
            for i = 1, #decoded.profiles do
                local profile = normalizeProfile(decoded.profiles[i])
                if profile then
                    store.profiles[#store.profiles + 1] = profile
                end
            end
        end

        PROFILES._store = store
        return store
    end

    local function writeStore()
        local store = ensureStore()
        local json = util.TableToJSON({
            schemaVersion = SCHEMA_VERSION,
            profiles = store.profiles
        }, false)
        if not json then
            return false, "notice.profile_save_failed"
        end

        file.CreateDir(PROFILE_DIR)
        if not file.Write(PROFILE_PATH, json) then
            return false, "notice.profile_save_failed"
        end

        return true
    end

    local function findProfileIndexById(id)
        local store = ensureStore()

        for i = 1, #store.profiles do
            if store.profiles[i].id == id then
                return i, store.profiles[i]
            end
        end

        return nil
    end

    local function generateProfileId()
        local store = ensureStore()

        while true do
            local id = "profile_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
            local found = false

            for i = 1, #store.profiles do
                if store.profiles[i].id == id then
                    found = true
                    break
                end
            end

            if not found then return id end
        end
    end

    function PROFILES.Reload()
        PROFILES._store = nil
        return ensureStore()
    end

    function PROFILES.Save()
        return writeStore()
    end

    function PROFILES.NormalizeName(name)
        return normalizeName(name)
    end

    function PROFILES.CaptureSettings()
        local settings = {}

        for cvarName, cvar in pairs(BL.GetRegisteredClientConVars()) do
            if cvar and cvar.GetString and BL.IsClientConVarProfileSetting(cvarName) then
                settings[cvarName] = cvar:GetString()
            end
        end

        return settings
    end

    function PROFILES.GetAll()
        return ensureStore().profiles
    end

    function PROFILES.GetSorted()
        local sorted = {}
        local profiles = PROFILES.GetAll()

        for i = 1, #profiles do
            sorted[i] = profiles[i]
        end

        table.sort(sorted, function(a, b)
            local au = tonumber(a.updatedAt) or 0
            local bu = tonumber(b.updatedAt) or 0
            if au ~= bu then return au > bu end

            return string.lower(a.name or "") < string.lower(b.name or "")
        end)

        return sorted
    end

    function PROFILES.GetById(id)
        local _, profile = findProfileIndexById(id)
        return profile
    end

    function PROFILES.FindByName(name, exceptId)
        name = normalizeName(name)
        if not name then return nil end

        local profiles = PROFILES.GetAll()
        for i = 1, #profiles do
            local profile = profiles[i]
            if profile.id ~= exceptId and namesMatch(profile.name, name) then
                return profile
            end
        end

        return nil
    end

    function PROFILES.Create(name, settings, addonVersion)
        local nameError
        name, nameError = normalizeName(name)
        if not name then return nil, nameError end

        settings = copySettings(settings or PROFILES.CaptureSettings())
        if countSettings(settings) == 0 then
            return nil, "notice.profile_import_empty_settings"
        end

        local now = os.time()
        local profile = {
            id = generateProfileId(),
            name = name,
            createdAt = now,
            updatedAt = now,
            addonVersion = tostring(addonVersion or BL.VERSION or ""),
            settings = settings
        }

        local store = ensureStore()
        store.profiles[#store.profiles + 1] = profile
        local written, writeError = writeStore()
        if not written then
            store.profiles[#store.profiles] = nil
            return nil, writeError
        end

        return profile
    end

    function PROFILES.Overwrite(id, name, settings, addonVersion)
        local _, profile = findProfileIndexById(id)
        if not profile then
            return nil, "notice.profile_missing"
        end

        local nameError
        name, nameError = normalizeName(name or profile.name)
        if not name then return nil, nameError end

        settings = copySettings(settings or PROFILES.CaptureSettings())
        if countSettings(settings) == 0 then
            return nil, "notice.profile_import_empty_settings"
        end

        local oldName = profile.name
        local oldUpdatedAt = profile.updatedAt
        local oldAddonVersion = profile.addonVersion
        local oldSettings = profile.settings

        profile.name = name
        profile.updatedAt = os.time()
        profile.addonVersion = tostring(addonVersion or BL.VERSION or "")
        profile.settings = settings

        local written, writeError = writeStore()
        if not written then
            profile.name = oldName
            profile.updatedAt = oldUpdatedAt
            profile.addonVersion = oldAddonVersion
            profile.settings = oldSettings
            return nil, writeError
        end

        return profile
    end

    function PROFILES.Rename(id, newName)
        local _, profile = findProfileIndexById(id)
        if not profile then
            return nil, "notice.profile_missing"
        end

        local nameError
        newName, nameError = normalizeName(newName)
        if not newName then return nil, nameError end

        local oldName = profile.name
        local oldUpdatedAt = profile.updatedAt

        profile.name = newName
        profile.updatedAt = os.time()

        local written, writeError = writeStore()
        if not written then
            profile.name = oldName
            profile.updatedAt = oldUpdatedAt
            return nil, writeError
        end

        return profile
    end

    function PROFILES.Delete(id)
        local index = findProfileIndexById(id)
        if not index then
            return false, "notice.profile_missing"
        end

        local profiles = ensureStore().profiles
        local profile = table.remove(profiles, index)
        local written, writeError = writeStore()
        if not written then
            table.insert(profiles, index, profile)
            return false, writeError
        end

        return true
    end

    function PROFILES.Apply(profile)
        if not profile or type(profile.settings) ~= "table" then
            return nil, "notice.profile_missing"
        end

        return BL.ApplyClientSettings(copySettings(profile.settings))
    end

    function PROFILES.Export(name, settings, addonVersion)
        local nameError
        name, nameError = normalizeName(name)
        if not name then return nil, nameError end

        settings = copySettings(settings)
        if countSettings(settings) == 0 then
            return nil, "notice.profile_import_empty_settings"
        end

        return util.TableToJSON({
            type = EXPORT_TYPE,
            schemaVersion = SCHEMA_VERSION,
            name = name,
            addonVersion = tostring(addonVersion or BL.VERSION or ""),
            settings = settings
        }, false)
    end

    function PROFILES.ExportProfile(profile)
        if not profile then
            return nil, "notice.profile_missing"
        end

        return PROFILES.Export(profile.name, profile.settings, profile.addonVersion)
    end

    function PROFILES.ExportShareCode(name, settings, addonVersion)
        local json, errorKey = PROFILES.Export(name, settings, addonVersion)
        if not json then return nil, errorKey end

        local code
        code, errorKey = encodeShareCode(json)
        if not code then return nil, errorKey end

        return code, json
    end

    function PROFILES.ExportProfileShareCode(profile)
        if not profile then
            return nil, "notice.profile_missing"
        end

        return PROFILES.ExportShareCode(profile.name, profile.settings, profile.addonVersion)
    end

    function PROFILES.DecodeExport(source)
        local errorKey
        source, errorKey = decodeShareSource(source)
        if not source then return nil, errorKey end

        if source == "" then
            return nil, "notice.profile_import_malformed"
        end

        local decoded = util.JSONToTable(source)
        if type(decoded) ~= "table" then
            return nil, "notice.profile_import_malformed"
        end

        if decoded.type ~= EXPORT_TYPE then
            return nil, "notice.profile_import_wrong_type"
        end

        if type(decoded.settings) ~= "table" then
            return nil, "notice.profile_import_missing_settings"
        end

        local settings = copySettings(decoded.settings)
        if countSettings(settings) == 0 then
            return nil, "notice.profile_import_empty_settings"
        end

        local name, nameError = normalizeName(decoded.name)
        if not name then
            return nil, nameError
        end

        return {
            name = name,
            addonVersion = tostring(decoded.addonVersion or ""),
            settings = settings
        }
    end
end
