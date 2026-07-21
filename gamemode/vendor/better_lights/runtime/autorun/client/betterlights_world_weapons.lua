if CLIENT then
    local BL = BetterLights

    local WEAPONS = {
        {
            class = "weapon_crossbow",
            slug = "crossbow",
            nameKey = "weapon.crossbow",
            name = "Crossbow",
            size = 34,
            brightness = 0.12,
            decay = 0,
            elight = 1,
            elightMult = 1.0,
            r = 255,
            g = 110,
            b = 25,
            placement = { attachments = { "muzzle" } }
        },
        {
            class = "gmod_tool",
            slug = "toolgun",
            nameKey = "weapon.toolgun",
            name = "Tool Gun",
            size = 42,
            brightness = 0.22,
            decay = 0,
            elight = 1,
            elightMult = 1.0,
            r = 255,
            g = 255,
            b = 255,
            placement = { attachments = { "muzzle" } }
        },
        {
            class = "weapon_physcannon",
            slug = "gravitygun",
            nameKey = "weapon.gravitygun",
            name = "Gravity Gun",
            size = 48,
            brightness = 0.25,
            decay = 0,
            elight = 1,
            elightMult = 1.0,
            r = 255,
            g = 140,
            b = 40,
            placement = { attachments = { "core" } }
        },
        {
            class = "weapon_physgun",
            slug = "physgun",
            nameKey = "weapon.physgun",
            name = "Physics Gun",
            size = 48,
            brightness = 0.25,
            decay = 0,
            elight = 1,
            elightMult = 1.0,
            r = 70,
            g = 130,
            b = 255,
            placement = { attachments = { "core" } }
        },
        {
            class = "weapon_medkit",
            slug = "medkit",
            nameKey = "weapon.medkit",
            name = "Medkit",
            size = 42,
            brightness = 0.22,
            decay = 0,
            elight = 1,
            elightMult = 1.0,
            r = 150,
            g = 255,
            b = 150,
            placement = { center = true }
        },
        {
            class = "weapon_bugbait",
            slug = "bugbait",
            nameKey = "weapon.bugbait",
            name = "Bugbait",
            size = 34,
            brightness = 0.12,
            decay = 0,
            elight = 1,
            elightMult = 1.0,
            r = 90,
            g = 170,
            b = 255,
            placement = { center = true }
        },
        {
            class = "weapon_ar2",
            slug = "ar2",
            nameKey = "weapon.pulse_rifle",
            name = "Pulse Rifle",
            size = 38,
            brightness = 0.14,
            decay = 0,
            elight = 1,
            elightMult = 1.0,
            r = 255,
            g = 70,
            b = 55,
            placement = { attachments = { "muzzle" } }
        },
        {
            class = "weapon_frag",
            slug = "frag",
            nameKey = "weapon.frag_grenade",
            name = "Frag Grenade",
            size = 36,
            brightness = 0.2,
            decay = 0,
            elight = 1,
            elightMult = 1.0,
            r = 255,
            g = 40,
            b = 40,
            placement = { center = true }
        }
    }

    for _, info in ipairs(WEAPONS) do
        local prefix = "betterlights_world_weapon_" .. info.slug
        info.cvar_enable = BL.CreateClientConVar(prefix .. "_enable", "1", true, false, "Enable world weapon light for " .. info.name)
        info.cvar_size = BL.CreateClientConVar(prefix .. "_size", tostring(info.size), true, false, "Dynamic light radius for world " .. info.name)
        info.cvar_brightness = BL.CreateClientConVar(prefix .. "_brightness", tostring(info.brightness), true, false, "Dynamic light brightness for world " .. info.name)
        info.cvar_decay = BL.CreateClientConVar(prefix .. "_decay", tostring(info.decay), true, false, "Dynamic light decay for world " .. info.name)
        info.cvar_models_elight = BL.CreateClientConVar(prefix .. "_models_elight", tostring(info.elight), true, false, "Also add an entity light (elight) for world " .. info.name)
        info.cvar_models_elight_size_mult = BL.CreateClientConVar(prefix .. "_models_elight_size_mult", tostring(info.elightMult), true, false, "Multiplier for world " .. info.name .. " elight radius")
        info.cvar_r = BL.CreateClientConVar(prefix .. "_color_r", tostring(info.r), true, false, info.name .. " world weapon color - red (0-255)")
        info.cvar_g = BL.CreateClientConVar(prefix .. "_color_g", tostring(info.g), true, false, info.name .. " world weapon color - green (0-255)")
        info.cvar_b = BL.CreateClientConVar(prefix .. "_color_b", tostring(info.b), true, false, info.name .. " world weapon color - blue (0-255)")

        BL.TrackClass(info.class)
    end

    function BL.GetWorldWeaponLightDefinitions()
        return WEAPONS
    end

    local function isWorldWeapon(ent)
        if not IsValid(ent) then return false end

        if ent.GetOwner and IsValid(ent:GetOwner()) then return false end
        if ent.GetParent and IsValid(ent:GetParent()) then return false end

        return true
    end

    local function getLightPosition(ent, info)
        local placement = info.placement
        if not placement then return nil end

        if placement.attachments then
            return BL.GetAttachmentPos(ent, placement.attachments, placement)
        end

        return nil
    end

    local function updateWeapon(info)
        if not info.cvar_enable:GetBool() then return end

        local size = math.max(0, info.cvar_size:GetFloat())
        local brightness = math.max(0, info.cvar_brightness:GetFloat())
        local decay = math.max(0, info.cvar_decay:GetFloat())
        local doElight = info.cvar_models_elight:GetBool()
        local elMult = math.max(0, info.cvar_models_elight_size_mult:GetFloat())
        local r, g, b = BL.GetColorFromCvars(info.cvar_r, info.cvar_g, info.cvar_b)

        local function update(ent)
            if not isWorldWeapon(ent) then return end

            local idx = ent:EntIndex() + 28000
            local placement = info.placement or {}

            if placement.center then
                local created, pos = BL.CreateLightAtEntityCenter(ent, idx, r, g, b, brightness, decay, size, false, placement)
                if not created then return end

                if doElight then
                    BL.CreateDLight(idx + 10000, pos, r, g, b, brightness, decay, size * elMult, true)
                end

                return
            end

            local pos = getLightPosition(ent, info)
            if not pos then return end

            BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size, false)

            if doElight then
                BL.CreateDLight(idx + 10000, pos, r, g, b, brightness, decay, size * elMult, true)
            end
        end

        BL.ForEach(info.class, update)
    end
    BL.AddThink("BetterLights_WorldWeapons_DLight", function()
        for _, info in ipairs(WEAPONS) do
            updateWeapon(info)
        end
    end)
end
