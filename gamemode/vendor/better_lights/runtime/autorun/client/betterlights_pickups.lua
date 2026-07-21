if CLIENT then
    local BL = BetterLights

    local bat_cvar_enable = BL.CreateClientConVar("betterlights_item_battery_enable", "1", true, false, "Enable dynamic light for item_battery")
    local bat_cvar_size = BL.CreateClientConVar("betterlights_item_battery_size", "55", true, false, "Dynamic light radius for item_battery")
    local bat_cvar_brightness = BL.CreateClientConVar("betterlights_item_battery_brightness", "0.2", true, false, "Dynamic light brightness for item_battery")
    local bat_cvar_decay = BL.CreateClientConVar("betterlights_item_battery_decay", "1800", true, false, "Dynamic light decay for item_battery")
    local bat_cvar_elight = BL.CreateClientConVar("betterlights_item_battery_models_elight", "1", true, false, "Also add an entity light (elight) for item_battery")
    local bat_cvar_elight_mult = BL.CreateClientConVar("betterlights_item_battery_models_elight_size_mult", "1.0", true, false, "Multiplier for item_battery elight radius")
    local bat_r = BL.CreateClientConVar("betterlights_item_battery_color_r", "110", true, false, "Battery color - red (0-255)")
    local bat_g = BL.CreateClientConVar("betterlights_item_battery_color_g", "190", true, false, "Battery color - green (0-255)")
    local bat_b = BL.CreateClientConVar("betterlights_item_battery_color_b", "255", true, false, "Battery color - blue (0-255)")

    local vial_cvar_enable = BL.CreateClientConVar("betterlights_item_healthvial_enable", "1", true, false, "Enable dynamic light for item_healthvial")
    local vial_cvar_size = BL.CreateClientConVar("betterlights_item_healthvial_size", "45", true, false, "Dynamic light radius for item_healthvial")
    local vial_cvar_brightness = BL.CreateClientConVar("betterlights_item_healthvial_brightness", "0.18", true, false, "Dynamic light brightness for item_healthvial")
    local vial_cvar_decay = BL.CreateClientConVar("betterlights_item_healthvial_decay", "1800", true, false, "Dynamic light decay for item_healthvial")
    local vial_cvar_elight = BL.CreateClientConVar("betterlights_item_healthvial_models_elight", "1", true, false, "Also add an entity light (elight) for item_healthvial")
    local vial_cvar_elight_mult = BL.CreateClientConVar("betterlights_item_healthvial_models_elight_size_mult", "1.0", true, false, "Multiplier for item_healthvial elight radius")
    local vial_r = BL.CreateClientConVar("betterlights_item_healthvial_color_r", "150", true, false, "Health vial color - red (0-255)")
    local vial_g = BL.CreateClientConVar("betterlights_item_healthvial_color_g", "255", true, false, "Health vial color - green (0-255)")
    local vial_b = BL.CreateClientConVar("betterlights_item_healthvial_color_b", "150", true, false, "Health vial color - blue (0-255)")

    local kit_cvar_enable = BL.CreateClientConVar("betterlights_item_healthkit_enable", "1", true, false, "Enable dynamic light for item_healthkit")
    local kit_cvar_size = BL.CreateClientConVar("betterlights_item_healthkit_size", "55", true, false, "Dynamic light radius for item_healthkit")
    local kit_cvar_brightness = BL.CreateClientConVar("betterlights_item_healthkit_brightness", "0.2", true, false, "Dynamic light brightness for item_healthkit")
    local kit_cvar_decay = BL.CreateClientConVar("betterlights_item_healthkit_decay", "1800", true, false, "Dynamic light decay for item_healthkit")
    local kit_cvar_elight = BL.CreateClientConVar("betterlights_item_healthkit_models_elight", "1", true, false, "Also add an entity light (elight) for item_healthkit")
    local kit_cvar_elight_mult = BL.CreateClientConVar("betterlights_item_healthkit_models_elight_size_mult", "1.0", true, false, "Multiplier for item_healthkit elight radius")
    local kit_r = BL.CreateClientConVar("betterlights_item_healthkit_color_r", "150", true, false, "Health kit color - red (0-255)")
    local kit_g = BL.CreateClientConVar("betterlights_item_healthkit_color_g", "255", true, false, "Health kit color - green (0-255)")
    local kit_b = BL.CreateClientConVar("betterlights_item_healthkit_color_b", "150", true, false, "Health kit color - blue (0-255)")

    BL.TrackClass("item_battery")
    BL.TrackClass("item_healthvial")
    BL.TrackClass("item_healthkit")

    local function processClass(class, r_cvar, g_cvar, b_cvar, c_en, c_size, c_bright, c_decay, c_elight, c_el_mult)
        if not c_en:GetBool() then return end

        local size = math.max(0, c_size:GetFloat())
        local brightness = math.max(0, c_bright:GetFloat())
        local decay = math.max(0, c_decay:GetFloat())
        local el_mult = math.max(0, c_el_mult:GetFloat())
        local doElight = c_elight:GetBool()

        local r, g, b = BL.GetColorFromCvars(r_cvar, g_cvar, b_cvar)

        local function update(ent)
            if not IsValid(ent) then return end
            local idx = ent:EntIndex()
            local pos = BL.GetEntityCenter(ent)
            if pos then
                BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size, false)

                if doElight then
                    BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size * el_mult, true)
                end
            end
        end

        BL.ForEach(class, update)
    end
    BL.AddThink("BetterLights_Pickups_DLight", function()
        processClass("item_battery", bat_r, bat_g, bat_b, bat_cvar_enable, bat_cvar_size, bat_cvar_brightness, bat_cvar_decay, bat_cvar_elight, bat_cvar_elight_mult)
        processClass("item_healthvial", vial_r, vial_g, vial_b, vial_cvar_enable, vial_cvar_size, vial_cvar_brightness, vial_cvar_decay, vial_cvar_elight, vial_cvar_elight_mult)
        processClass("item_healthkit", kit_r, kit_g, kit_b, kit_cvar_enable, kit_cvar_size, kit_cvar_brightness, kit_cvar_decay, kit_cvar_elight, kit_cvar_elight_mult)
    end)
end
