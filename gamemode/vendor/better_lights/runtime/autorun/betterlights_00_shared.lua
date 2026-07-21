BetterLights = BetterLights or {}

local BL = BetterLights

BL.NET_EVENT_MESSAGE = "BetterLights_Event"
BL.NET_FLASHLIGHT_CLIENT_SETTINGS = "BetterLights_FlashlightClientSettings"
BL.NET_SERVER_SETTINGS_REQUEST = "BetterLights_RequestServerSettings"
BL.NET_SERVER_SETTINGS_APPLY = "BetterLights_ApplyServerSettings"
BL.NET_SERVER_SETTINGS_STATE = "BetterLights_ServerSettings"

BL.SERVER_MODE_DISABLED = 0
BL.SERVER_MODE_ENABLED = 1
BL.SERVER_MODE_PLAYER_CHOICE = 2
BL.SERVER_SETTINGS_PROTOCOL_VERSION = 1

BL.NET_MUZZLE_FLASH = 1
BL.NET_BULLET_IMPACT = 2
BL.NET_STRIDER_BULLET_IMPACT = 4
BL.NET_HUNTER_CHOPPER_BULLET_IMPACT = 6
BL.NET_STUNSTICK_IMPACT = 7
BL.NET_EXPLOSION = 8

BL.MUZZLE_FLASH_PAYLOAD_VERSION = 2
BL.MUZZLE_SOURCE_FIREBULLETS = 1
BL.MUZZLE_SOURCE_ADAPTER = 2
BL.MUZZLE_SOURCE_PREDICTED = 3

BL.EXPLOSION_SOURCE_DAMAGE = 1
BL.EXPLOSION_SOURCE_EFFECT = 2
BL.EXPLOSION_SOURCE_INPUT = 3
BL.EXPLOSION_SOURCE_PARTICLE = 4

BL.MuzzleFlash = BL.MuzzleFlash or {}
BL.Explosions = BL.Explosions or {}
BL.Flashlight = BL.Flashlight or {}

do
    local NUMBER_EPSILON = 0.000001
    local schema = {
        {
            id = 1,
            order = 1,
            name = "betterlights_flashlight_player_enable",
            type = "bool",
            default = false,
            section = "behavior",
            sectionKey = "section.behavior",
            labelKey = "control.replace_flashlight",
            serverLabelKey = "control.replace_player_flashlights"
        },
        {
            id = 2,
            order = 2,
            name = "betterlights_flashlight_custom_sounds",
            type = "bool",
            default = true,
            section = "behavior",
            sectionKey = "section.behavior",
            labelKey = "control.use_flashlight_sounds"
        },
        {
            id = 3,
            order = 3,
            name = "betterlights_flashlight_weapon_attachment",
            type = "bool",
            default = true,
            section = "position",
            sectionKey = "section.origin",
            labelKey = "control.attach_beam_to_weapon"
        },
        {
            id = 4,
            order = 4,
            name = "betterlights_flashlight_forward_offset",
            type = "number",
            default = 0,
            min = -32,
            max = 96,
            decimals = 1,
            section = "position",
            sectionKey = "section.origin",
            labelKey = "control.forward_offset"
        },
        {
            id = 5,
            order = 5,
            name = "betterlights_flashlight_attachment_offset",
            type = "number",
            default = 2,
            min = -24,
            max = 24,
            decimals = 1,
            section = "position",
            sectionKey = "section.origin",
            labelKey = "control.attached_side_offset"
        },
        {
            id = 6,
            order = 6,
            name = "betterlights_flashlight_fallback_offset",
            type = "number",
            default = 8,
            min = -24,
            max = 24,
            decimals = 1,
            section = "position",
            sectionKey = "section.origin",
            labelKey = "control.view_origin_side_offset"
        },
        {
            id = 7,
            order = 7,
            name = "betterlights_flashlight_shadows",
            type = "bool",
            default = true,
            section = "beam",
            sectionKey = "section.beam",
            labelKey = "control.cast_shadows"
        },
        {
            id = 8,
            order = 8,
            name = "betterlights_flashlight_flicker",
            type = "bool",
            default = false,
            section = "beam",
            sectionKey = "section.beam",
            labelKey = "control.flicker"
        },
        {
            id = 9,
            order = 9,
            name = "betterlights_flashlight_flicker_amount",
            type = "number",
            default = 0.05,
            min = 0,
            max = 0.3,
            decimals = 2,
            section = "beam",
            sectionKey = "section.beam",
            labelKey = "control.flicker_amount"
        },
        {
            id = 10,
            order = 10,
            name = "betterlights_flashlight_sway",
            type = "bool",
            default = true,
            section = "beam",
            sectionKey = "section.beam",
            labelKey = "control.flashlight_sway"
        },
        {
            id = 11,
            order = 11,
            name = "betterlights_flashlight_sway_intensity",
            type = "number",
            default = 1,
            min = 0,
            max = 3,
            decimals = 2,
            section = "beam",
            sectionKey = "section.beam",
            labelKey = "control.sway_intensity"
        },
        {
            id = 12,
            order = 12,
            name = "betterlights_flashlight_brightness",
            type = "number",
            default = 1.35,
            min = 0.1,
            max = 5,
            decimals = 2,
            section = "beam",
            sectionKey = "section.beam",
            labelKey = "control.brightness"
        },
        {
            id = 13,
            order = 13,
            name = "betterlights_flashlight_fov",
            type = "number",
            default = 45,
            min = 10,
            max = 120,
            decimals = 0,
            section = "beam",
            sectionKey = "section.beam",
            labelKey = "control.fov"
        },
        {
            id = 14,
            order = 14,
            name = "betterlights_flashlight_distance",
            type = "number",
            default = 1200,
            min = 128,
            max = 4096,
            decimals = 0,
            section = "beam",
            sectionKey = "section.beam",
            labelKey = "control.beam_length"
        },
        {
            id = 15,
            order = 15,
            name = "betterlights_flashlight_shadow_depth_bias",
            type = "number",
            default = 0.001,
            min = 0,
            max = 0.005,
            decimals = 5,
            section = "advanced_shadows",
            sectionKey = "section.advanced_shadows",
            labelKey = "control.shadow_depth_bias"
        },
        {
            id = 16,
            order = 16,
            name = "betterlights_flashlight_shadow_slope_scale_depth_bias",
            type = "number",
            default = 4,
            min = 0,
            max = 8,
            decimals = 2,
            section = "advanced_shadows",
            sectionKey = "section.advanced_shadows",
            labelKey = "control.shadow_slope_scale_depth_bias"
        },
        {
            id = 17,
            order = 17,
            name = "betterlights_flashlight_shadow_filter",
            type = "number",
            default = 1.25,
            min = 0,
            max = 4,
            decimals = 2,
            section = "advanced_shadows",
            sectionKey = "section.advanced_shadows",
            labelKey = "control.shadow_filter"
        },
        {
            id = 18,
            order = 18,
            name = "betterlights_flashlight_flare_enable",
            type = "bool",
            default = true,
            section = "flare",
            sectionKey = "section.flare",
            labelKey = "control.flashlight_flare"
        },
        {
            id = 19,
            order = 19,
            name = "betterlights_flashlight_flare_others",
            type = "bool",
            default = true,
            section = "flare",
            sectionKey = "section.flare",
            labelKey = "control.show_other_flashlight_flares"
        },
        {
            id = 20,
            order = 20,
            name = "betterlights_flashlight_flare_size",
            type = "number",
            default = 1,
            min = 0.25,
            max = 3,
            decimals = 2,
            section = "flare",
            sectionKey = "section.flare",
            labelKey = "control.flare_size"
        },
        {
            id = 21,
            order = 21,
            name = "betterlights_flashlight_flare_opacity",
            type = "number",
            default = 90,
            min = 0,
            max = 255,
            decimals = 0,
            section = "flare",
            sectionKey = "section.flare",
            labelKey = "control.flare_opacity"
        },
        {
            id = 22,
            order = 22,
            name = "betterlights_flashlight_color_r",
            type = "number",
            default = 255,
            min = 0,
            max = 255,
            decimals = 0,
            section = "color",
            sectionKey = "section.color",
            labelKey = "control.flashlight_color",
            colorChannel = "r"
        },
        {
            id = 23,
            order = 23,
            name = "betterlights_flashlight_color_g",
            type = "number",
            default = 245,
            min = 0,
            max = 255,
            decimals = 0,
            section = "color",
            sectionKey = "section.color",
            labelKey = "control.flashlight_color",
            colorChannel = "g"
        },
        {
            id = 24,
            order = 24,
            name = "betterlights_flashlight_color_b",
            type = "number",
            default = 225,
            min = 0,
            max = 255,
            decimals = 0,
            section = "color",
            sectionKey = "section.color",
            labelKey = "control.flashlight_color",
            colorChannel = "b"
        },
        {
            id = 25,
            order = 25,
            name = "betterlights_flashlight_texture",
            type = "string",
            default = "effects/flashlight001",
            maxLength = 128,
            section = "texture",
            sectionKey = "section.texture",
            labelKey = "section.texture",
            texture = true
        }
    }

    local byName = {}

    for i = 1, #schema do
        local def = schema[i]
        local serverName = string.gsub(def.name, "^betterlights_flashlight_", "")
        def.cvar = def.name
        def.serverForceCvar = "betterlights_sv_fl_" .. serverName .. "_force"
        def.serverValueCvar = "betterlights_sv_fl_" .. serverName .. "_value"
        byName[def.name] = def
    end

    BL.SERVER_FLASHLIGHT_SCHEMA = schema
    BL.SERVER_FLASHLIGHT_SETTINGS = schema
    BL.SERVER_FLASHLIGHT_SCHEMA_BY_NAME = byName
    BL.SERVER_FLASHLIGHT_SETTINGS_BY_NAME = byName
    BL.FLASHLIGHT_SETTING_DEFS = schema
    BL.FLASHLIGHT_SETTING_BY_NAME = byName

    local function normalizeTexturePath(value)
        value = string.Trim(tostring(value or ""))
        value = string.Replace(value, "\\", "/")
        value = string.gsub(value, "/+", "/")

        if string.lower(string.sub(value, 1, 10)) == "materials/" then
            value = string.sub(value, 11)
        end

        value = string.gsub(value, "^/+", "")

        local extension = string.lower(string.sub(value, -4))
        if extension == ".vmt" or extension == ".vtf" then
            value = string.sub(value, 1, -5)
        end

        return value
    end

    local function isPrintable(value)
        for i = 1, #value do
            local byte = string.byte(value, i)
            if byte < 32 or byte > 126 then return false end
        end

        return true
    end

    local function validateTexturePath(value, def)
        if #value > (def.maxLength or 128) then return nil, "texture path is too long" end
        if not isPrintable(value) then return nil, "texture path contains non-printable characters" end

        value = normalizeTexturePath(value)
        if value == "" then return nil, "empty texture path" end
        if #value > (def.maxLength or 128) then return nil, "texture path is too long" end
        if string.find(value, ":", 1, true) then return nil, "texture path must be relative" end

        for segment in string.gmatch(value, "[^/]+") do
            if segment == "." or segment == ".." then
                return nil, "texture path contains a relative segment"
            end
        end

        return value
    end

    local function roundNumber(value, decimals)
        if decimals == nil then return value end
        return math.Round(value, decimals)
    end

    local function validateValue(def, value)
        if def.type == "bool" then
            if type(value) ~= "boolean" then return nil, "expected boolean" end
            return value
        end

        if def.type == "number" then
            if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
                return nil, "expected finite number"
            end

            if def.min ~= nil and value < def.min - NUMBER_EPSILON then return nil, "number is below minimum" end
            if def.max ~= nil and value > def.max + NUMBER_EPSILON then return nil, "number is above maximum" end

            if def.min ~= nil and value < def.min then value = def.min end
            if def.max ~= nil and value > def.max then value = def.max end
            value = roundNumber(value, def.decimals)

            return value
        end

        if def.type == "string" then
            if type(value) ~= "string" then return nil, "expected string" end
            if def.texture then return validateTexturePath(value, def) end
            return value
        end

        return nil, "unknown setting type"
    end

    function BL.NormalizeServerFlashlightTexturePath(value)
        return normalizeTexturePath(value)
    end

    function BL.ValidateServerFlashlightSettingValue(name, value)
        local def = byName[name]
        if not def then return nil, "unknown flashlight setting" end

        return validateValue(def, value)
    end

    function BL.ValidateServerSettingsState(state)
        if type(state) ~= "table" then return nil, "expected settings table" end

        local mode = state.mode
        if type(mode) ~= "number" or mode % 1 ~= 0 or mode < BL.SERVER_MODE_DISABLED or mode > BL.SERVER_MODE_PLAYER_CHOICE then
            return nil, "invalid server mode"
        end

        if type(state.overrides) ~= "table" or type(state.values) ~= "table" then
            return nil, "incomplete settings state"
        end

        local validated = {
            mode = mode,
            overrides = {},
            values = {}
        }

        for i = 1, #schema do
            local def = schema[i]
            local forced = state.overrides[def.name]
            if type(forced) ~= "boolean" then
                return nil, "invalid force flag for " .. def.name
            end

            local value, err = validateValue(def, state.values[def.name])
            if value == nil then
                return nil, (err or "invalid value") .. " for " .. def.name
            end

            validated.overrides[def.name] = forced
            validated.values[def.name] = value
        end

        return validated
    end

    local function writeValue(def, value)
        if def.type == "bool" then
            net.WriteBool(value)
        elseif def.type == "number" then
            net.WriteFloat(value)
        else
            net.WriteString(value)
        end
    end

    local function readValue(def)
        if def.type == "bool" then return net.ReadBool() end
        if def.type == "number" then return net.ReadFloat() end
        return net.ReadString()
    end

    function BL.WriteServerSettingsState(state)
        local validated, err = BL.ValidateServerSettingsState(state)
        if not validated then return false, err end

        net.WriteUInt(BL.SERVER_SETTINGS_PROTOCOL_VERSION, 4)
        net.WriteUInt(validated.mode, 2)
        net.WriteUInt(#schema, 6)

        for i = 1, #schema do
            local def = schema[i]
            net.WriteUInt(def.id, 6)
            net.WriteBool(validated.overrides[def.name])
            writeValue(def, validated.values[def.name])
        end

        return true
    end

    function BL.ReadServerSettingsState()
        local version = net.ReadUInt(4)
        if version ~= BL.SERVER_SETTINGS_PROTOCOL_VERSION then return nil, "unsupported protocol version" end

        local mode = net.ReadUInt(2)
        local count = net.ReadUInt(6)
        if count ~= #schema then return nil, "unexpected schema count" end

        local state = {
            mode = mode,
            overrides = {},
            values = {}
        }

        for i = 1, #schema do
            local def = schema[i]
            if net.ReadUInt(6) ~= def.id then return nil, "unexpected setting id" end

            state.overrides[def.name] = net.ReadBool()
            state.values[def.name] = readValue(def)
        end

        return BL.ValidateServerSettingsState(state)
    end
end

do
    local FL = BL.Flashlight

    FL.IntegrationsById = FL.IntegrationsById or {}
    FL.Integrations = FL.Integrations or {}

    local function normalizeString(value)
        if value == nil then return nil end

        value = tostring(value)
        if value == "" then return nil end

        return value
    end

    local function rebuildIntegrations()
        local integrations = {}

        for _, integration in pairs(FL.IntegrationsById) do
            integrations[#integrations + 1] = integration
        end

        table.sort(integrations, function(a, b)
            local ap = tonumber(a.priority) or 0
            local bp = tonumber(b.priority) or 0
            if ap ~= bp then return ap > bp end

            return tostring(a.id or "") < tostring(b.id or "")
        end)

        FL.Integrations = integrations
    end

    function FL.RegisterIntegration(def)
        if type(def) ~= "table" then return nil end

        local id = normalizeString(def.id)
        if not id then return nil end

        local integration = {}
        for k, v in pairs(def) do
            integration[k] = v
        end

        integration.id = id
        integration.priority = tonumber(integration.priority) or 0
        FL.IntegrationsById[id] = integration
        rebuildIntegrations()
        return integration
    end

    function FL.GetIntegrations()
        return FL.Integrations
    end

    function FL.GetWeaponBase(weapon)
        if not IsValid(weapon) then return "" end

        local base = weapon.Base
        if base == nil and weapon.GetTable then
            local tab = weapon:GetTable()
            base = tab and tab.Base
        end

        return string.lower(tostring(base or ""))
    end

    rebuildIntegrations()
end

do
    local MF = BL.MuzzleFlash

    MF.ColorTags = MF.ColorTags or {}
    MF.Profiles = MF.Profiles or {}
    MF.WeaponRules = MF.WeaponRules or {}
    MF.Adapters = MF.Adapters or {}

    local sourceRank = {
        builtin = 1,
        integration = 1,
        addon = 2,
        user = 3
    }

    local function copySequence(value)
        if type(value) ~= "table" then return nil end

        local out = {}
        for i = 1, #value do
            out[i] = value[i]
        end

        return out
    end

    local function normalizeString(value)
        if value == nil then return nil end

        value = tostring(value)
        if value == "" then return nil end

        return value
    end

    local function normalizeRule(def)
        if type(def) ~= "table" then return nil end

        local rule = {}
        rule.id = normalizeString(def.id)
        rule.class = normalizeString(def.class)
        rule.base = normalizeString(def.base)
        rule.ammo = normalizeString(def.ammo)
        rule.tracer = normalizeString(def.tracer)
        rule.profile = normalizeString(def.profile) or "default"
        rule.colorTag = normalizeString(def.colorTag)
        rule.priority = tonumber(def.priority) or 0
        rule.attachments = copySequence(def.attachments)
        rule.source = normalizeString(def.source) or "addon"
        rule.adapter = normalizeString(def.adapter)
        return rule
    end

    local function sortRules()
        table.sort(MF.WeaponRules, function(a, b)
            local ap = tonumber(a.priority) or 0
            local bp = tonumber(b.priority) or 0
            if ap ~= bp then return ap > bp end

            local as = sourceRank[a.source] or sourceRank.addon
            local bs = sourceRank[b.source] or sourceRank.addon
            if as ~= bs then return as > bs end

            return tostring(a.id or a.class or "") < tostring(b.id or b.class or "")
        end)
    end

    function MF.RegisterColorTag(tag, def)
        tag = normalizeString(tag)
        if not tag or type(def) ~= "table" then return nil end

        local color = {
            r = tonumber(def.r or def[1]) or 255,
            g = tonumber(def.g or def[2]) or 255,
            b = tonumber(def.b or def[3]) or 255,
            source = normalizeString(def.source) or "addon"
        }

        MF.ColorTags[tag] = color
        return color
    end

    function MF.RegisterProfile(id, def)
        id = normalizeString(id)
        if not id or type(def) ~= "table" then return nil end

        local profile = {}
        for k, v in pairs(def) do
            profile[k] = v
        end

        profile.id = id
        profile.source = normalizeString(profile.source) or "addon"
        MF.Profiles[id] = profile
        return profile
    end

    function MF.RegisterWeaponRule(def)
        local rule = normalizeRule(def)
        if not rule then return nil end

        if rule.id then
            for i = #MF.WeaponRules, 1, -1 do
                local existing = MF.WeaponRules[i]
                if existing.id == rule.id and existing.source == rule.source then
                    table.remove(MF.WeaponRules, i)
                end
            end
        end

        MF.WeaponRules[#MF.WeaponRules + 1] = rule
        sortRules()
        return rule
    end

    function MF.RegisterAdapter(id, def)
        id = normalizeString(id)
        if not id or type(def) ~= "table" then return nil end

        def.id = id
        MF.Adapters[id] = def
        return def
    end

    function MF.ClearRulesBySource(source)
        source = normalizeString(source)
        if not source then return end

        for i = #MF.WeaponRules, 1, -1 do
            if MF.WeaponRules[i].source == source then
                table.remove(MF.WeaponRules, i)
            end
        end
    end

    function MF.ClearColorTagsBySource(source)
        source = normalizeString(source)
        if not source then return end

        for tag, def in pairs(MF.ColorTags) do
            if def.source == source then
                MF.ColorTags[tag] = nil
            end
        end
    end

    function MF.GetProfile(id)
        return MF.Profiles[id or "default"] or MF.Profiles.default
    end

    local function classMatches(ruleClass, ent)
        if not ruleClass then return true end
        if not (IsValid(ent) and ent.GetClass) then return false end

        return string.lower(ent:GetClass() or "") == string.lower(ruleClass)
    end

    local function baseMatches(ruleBase, ent)
        if not ruleBase then return true end
        if not IsValid(ent) then return false end

        local base = ent.Base
        if base == nil and ent.GetTable then
            local tab = ent:GetTable()
            base = tab and tab.Base
        end

        return string.lower(tostring(base or "")) == string.lower(ruleBase)
    end

    local function bulletMatches(rule, bullet)
        if not bullet then return not (rule.ammo or rule.tracer) end

        if rule.ammo and string.lower(tostring(bullet.AmmoType or "")) ~= string.lower(rule.ammo) then
            return false
        end

        if rule.tracer then
            local tracer = string.lower(tostring(bullet.TracerName or ""))
            if not string.find(tracer, string.lower(rule.tracer), 1, true) then
                return false
            end
        end

        return true
    end

    function MF.MatchWeaponRule(shooter, weapon, bullet, adapterId)
        local adapter = adapterId and MF.Adapters[adapterId] or nil
        if bullet and adapter and isfunction(adapter.shouldHandleBullet) then
            local ok, shouldHandle = pcall(adapter.shouldHandleBullet, shooter, weapon, bullet)
            if ok and shouldHandle == false then return nil end
        end

        for i = 1, #MF.WeaponRules do
            local rule = MF.WeaponRules[i]
            local classOk = classMatches(rule.class, weapon) or classMatches(rule.class, shooter)
            if classOk and baseMatches(rule.base, weapon) and bulletMatches(rule, bullet) and (not rule.adapter or rule.adapter == adapterId) then
                return rule
            end
        end

        return nil
    end
end

do
    local EXP = BL.Explosions

    EXP.Profiles = EXP.Profiles or {}
    EXP.ClassProfiles = EXP.ClassProfiles or {}
    EXP.EffectProfiles = EXP.EffectProfiles or {}
    EXP.ParticleProfiles = EXP.ParticleProfiles or {}
    EXP.InputProfiles = EXP.InputProfiles or {}

    local function normalizeString(value)
        if value == nil then return nil end

        value = tostring(value)
        if value == "" then return nil end

        return value
    end

    local function normalizeKey(value)
        value = normalizeString(value)
        if not value then return nil end

        return string.lower(value)
    end

    local function addValue(out, value)
        value = normalizeString(value)
        if not value then return end

        out[#out + 1] = value
    end

    local function buildList(...)
        local out = {}

        for i = 1, select("#", ...) do
            local value = select(i, ...)
            if type(value) == "table" then
                for j = 1, #value do
                    addValue(out, value[j])
                end
            else
                addValue(out, value)
            end
        end

        return out
    end

    local function registerValues(map, values, profileId)
        for i = 1, #values do
            local key = normalizeKey(values[i])
            if key then
                map[key] = profileId
            end
        end
    end

    function EXP.RegisterProfile(id, def)
        id = normalizeString(id)
        if not id then return nil end

        def = def or {}
        local profile = EXP.Profiles[id] or { id = id }

        for k, v in pairs(def) do
            profile[k] = v
        end

        profile.id = id
        EXP.Profiles[id] = profile

        local classes = buildList(def.class, def.classes)
        registerValues(EXP.ClassProfiles, classes, id)
        registerValues(EXP.EffectProfiles, buildList(def.effect, def.effects), id)
        registerValues(EXP.ParticleProfiles, buildList(def.particle, def.particles), id)

        local inputs = buildList(def.input, def.inputs)
        if #classes > 0 and #inputs > 0 then
            for i = 1, #classes do
                local classKey = normalizeKey(classes[i])
                if classKey then
                    EXP.InputProfiles[classKey] = EXP.InputProfiles[classKey] or {}
                    registerValues(EXP.InputProfiles[classKey], inputs, id)
                end
            end
        end

        return profile
    end

    function EXP.GetProfile(id)
        return EXP.Profiles[id or "generic"] or EXP.Profiles.generic
    end

    function EXP.MatchClass(className)
        local key = normalizeKey(className)
        if not key then return nil end

        return EXP.ClassProfiles[key]
    end

    function EXP.MatchEntity(ent)
        if not (IsValid(ent) and ent.GetClass) then return nil end

        return EXP.MatchClass(ent:GetClass())
    end

    function EXP.MatchEffect(effectName)
        local key = normalizeKey(effectName)
        if not key then return nil end

        return EXP.EffectProfiles[key]
    end

    function EXP.MatchParticle(particleName)
        local key = normalizeKey(particleName)
        if not key then return nil end

        return EXP.ParticleProfiles[key]
    end

    function EXP.MatchInput(className, inputName)
        local classKey = normalizeKey(className)
        local inputKey = normalizeKey(inputName)
        if not (classKey and inputKey) then return nil end

        local inputs = EXP.InputProfiles[classKey]
        return inputs and inputs[inputKey] or nil
    end

    EXP.RegisterProfile("generic", {
        effects = {
            "Explosion",
            "AR2Explosion",
            "WaterSurfaceExplosion"
        },
        source = "builtin"
    })

    EXP.RegisterProfile("env", {
        classes = {
            "env_explosion",
            "env_physexplosion",
            "env_ar2explosion"
        },
        inputs = { "Explode" },
        source = "builtin"
    })

    EXP.RegisterProfile("barrel", {
        source = "builtin"
    })

    EXP.RegisterProfile("scanner", {
        classes = {
            "npc_cscanner",
            "npc_clawscanner"
        },
        source = "builtin"
    })

    EXP.RegisterProfile("combine_mine", {
        classes = { "combine_mine" },
        source = "builtin"
    })

    EXP.RegisterProfile("rpg", {
        classes = { "rpg_missile" },
        source = "builtin"
    })

    EXP.RegisterProfile("heli_bomb", {
        classes = { "grenade_helicopter" },
        effects = { "HelicopterMegaBomb" },
        source = "builtin"
    })

    EXP.RegisterProfile("hunter_flechette", {
        classes = { "hunter_flechette" },
        source = "builtin"
    })

    EXP.RegisterProfile("magnusson", {
        classes = { "weapon_striderbuster" },
        damageRemoval = true,
        source = "builtin"
    })
end
