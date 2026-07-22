FFMapMessages = FFMapMessages or {}

local function getConfig()
    return FF_CONFIG and FF_CONFIG.MapMessages or {}
end

function FFMapMessages.GetConfig()
    return getConfig()
end

function FFMapMessages.IsEnabled()
    return getConfig().Enabled ~= false
end

function FFMapMessages.GetAPIBaseURL()
    local baseURL = string.Trim(tostring(getConfig().APIBaseURL or ""))
    return string.gsub(baseURL, "/+$", "")
end

function FFMapMessages.IsConfigured()
    local baseURL = FFMapMessages.GetAPIBaseURL()
    return FFMapMessages.IsEnabled() and string.StartWith(baseURL, "https://")
end

function FFMapMessages.GetAPIURL(path)
    return FFMapMessages.GetAPIBaseURL() .. "/" .. string.gsub(tostring(path or ""), "^/+", "")
end

function FFMapMessages.GetMapName()
    return game.GetMap()
end

function FFMapMessages.IsValidRecord(record)
    if not istable(record) then return false end
    if not isstring(record.id) or #record.id > 64 then return false end
    if not isstring(record.body) or record.body == "" then return false end
    if not istable(record.position) or not istable(record.normal) then return false end
    return true
end
