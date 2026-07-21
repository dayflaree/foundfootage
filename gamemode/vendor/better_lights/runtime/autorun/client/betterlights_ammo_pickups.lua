if CLIENT then
    local BL = BetterLights

    local AMMO = {
        {
            class = "item_ammo_ar2",
            slug = "ar2",
            nameKey = "ammo.ar2",
            name = "AR2 Ammo",
            enable = 1,
            size = 40,
            brightness = 0.14,
            r = 90,
            g = 170,
            b = 255
        },
        {
            class = "item_ammo_ar2_large",
            slug = "ar2_large",
            nameKey = "ammo.ar2_large",
            name = "AR2 Ammo Large",
            enable = 1,
            size = 48,
            brightness = 0.16,
            r = 90,
            g = 170,
            b = 255
        },
        {
            class = "item_ammo_ar2_altfire",
            slug = "ar2_alt",
            nameKey = "ammo.ar2_alt",
            name = "AR2 Alt Ammo",
            enable = 1,
            size = 60,
            brightness = 0.25,
            r = 255,
            g = 220,
            b = 60
        },
        { class = "item_ammo_smg1", slug = "smg1", nameKey = "ammo.smg1", name = "SMG Ammo", enable = 0 },
        { class = "item_ammo_smg1_large", slug = "smg1_large", nameKey = "ammo.smg1_large", name = "SMG Ammo Large", enable = 0 },
        { class = "item_ammo_smg1_grenade", slug = "smg1_grenade", nameKey = "ammo.smg1_grenade", name = "SMG Grenade", enable = 0 },
        { class = "item_ammo_357", slug = "357", nameKey = "ammo.357", name = ".357 Ammo", enable = 0 },
        { class = "item_ammo_357_large", slug = "357_large", nameKey = "ammo.357_large", name = ".357 Ammo Large", enable = 0 },
        { class = "item_ammo_crossbow", slug = "crossbow", nameKey = "ammo.crossbow", name = "Crossbow Bolts", enable = 0 },
        { class = "item_ammo_pistol", slug = "pistol", nameKey = "ammo.pistol", name = "Pistol Ammo", enable = 0 },
        { class = "item_ammo_pistol_large", slug = "pistol_large", nameKey = "ammo.pistol_large", name = "Pistol Ammo Large", enable = 0 },
        { class = "item_rpg_round", slug = "rpg_round", nameKey = "ammo.rpg_round", name = "RPG Round", enable = 0 },
        { class = "item_box_buckshot", slug = "buckshot", nameKey = "ammo.buckshot", name = "Buckshot", enable = 0 }
    }

    for _, info in ipairs(AMMO) do
        info.size = info.size or 32
        info.brightness = info.brightness or 0.08
        info.decay = info.decay or 0
        info.elight = info.elight or 1
        info.elightMult = info.elightMult or 1.0
        info.r = info.r or 235
        info.g = info.g or 235
        info.b = info.b or 235

        local prefix = "betterlights_ammo_" .. info.slug
        info.cvar_enable = BL.CreateClientConVar(prefix .. "_enable", tostring(info.enable), true, false, "Enable ammo pickup light for " .. info.name)
        info.cvar_size = BL.CreateClientConVar(prefix .. "_size", tostring(info.size), true, false, "Dynamic light radius for " .. info.name)
        info.cvar_brightness = BL.CreateClientConVar(prefix .. "_brightness", tostring(info.brightness), true, false, "Dynamic light brightness for " .. info.name)
        info.cvar_decay = BL.CreateClientConVar(prefix .. "_decay", tostring(info.decay), true, false, "Dynamic light decay for " .. info.name)
        info.cvar_models_elight = BL.CreateClientConVar(prefix .. "_models_elight", tostring(info.elight), true, false, "Also add an entity light (elight) for " .. info.name)
        info.cvar_models_elight_size_mult = BL.CreateClientConVar(prefix .. "_models_elight_size_mult", tostring(info.elightMult), true, false, "Multiplier for " .. info.name .. " elight radius")
        info.cvar_r = BL.CreateClientConVar(prefix .. "_color_r", tostring(info.r), true, false, info.name .. " color - red (0-255)")
        info.cvar_g = BL.CreateClientConVar(prefix .. "_color_g", tostring(info.g), true, false, info.name .. " color - green (0-255)")
        info.cvar_b = BL.CreateClientConVar(prefix .. "_color_b", tostring(info.b), true, false, info.name .. " color - blue (0-255)")

        BL.TrackClass(info.class)
    end

    function BL.GetAmmoPickupLightDefinitions()
        return AMMO
    end

    local function updateAmmo(info)
        if not info.cvar_enable:GetBool() then return end

        local size = math.max(0, info.cvar_size:GetFloat())
        local brightness = math.max(0, info.cvar_brightness:GetFloat())
        local decay = math.max(0, info.cvar_decay:GetFloat())
        local doElight = info.cvar_models_elight:GetBool()
        local elMult = math.max(0, info.cvar_models_elight_size_mult:GetFloat())
        local r, g, b = BL.GetColorFromCvars(info.cvar_r, info.cvar_g, info.cvar_b)

        local function update(ent)
            if not IsValid(ent) then return end

            local pos = BL.GetEntityCenter(ent)
            if not pos then return end

            local idx = ent:EntIndex() + 42000
            BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size, false)

            if doElight then
                BL.CreateDLight(idx + 10000, pos, r, g, b, brightness, decay, size * elMult, true)
            end
        end

        BL.ForEach(info.class, update)
    end
    BL.AddThink("BetterLights_AmmoPickups_DLight", function()
        for _, info in ipairs(AMMO) do
            updateAmmo(info)
        end
    end)
end
