if CLIENT then
    local BL = BetterLights
    local sc_enable = BL.CreateClientConVar("betterlights_suitcharger_enable", "1", true, false, "Enable glow for item_suitcharger")
    local sc_size = BL.CreateClientConVar("betterlights_suitcharger_size", "75", true, false, "Glow radius for item_suitcharger")
    local sc_bright = BL.CreateClientConVar("betterlights_suitcharger_brightness", "0.25", true, false, "Glow brightness for item_suitcharger")
    local sc_decay = BL.CreateClientConVar("betterlights_suitcharger_decay", "1800", true, false, "Glow decay for item_suitcharger")
    local sc_elight = BL.CreateClientConVar("betterlights_suitcharger_models_elight", "1", true, false, "Add elight to light the charger model")
    local sc_elmult = BL.CreateClientConVar("betterlights_suitcharger_models_elight_size_mult", "1.0", true, false, "Elight radius multiplier for item_suitcharger")
    local sc_r = BL.CreateClientConVar("betterlights_suitcharger_color_r", "255", true, false, "Suit charger color - red (0-255)")
    local sc_g = BL.CreateClientConVar("betterlights_suitcharger_color_g", "180", true, false, "Suit charger color - green (0-255)")
    local sc_b = BL.CreateClientConVar("betterlights_suitcharger_color_b", "80", true, false, "Suit charger color - blue (0-255)")

    local hc_enable = BL.CreateClientConVar("betterlights_healthcharger_enable", "1", true, false, "Enable glow for item_healthcharger")
    local hc_size = BL.CreateClientConVar("betterlights_healthcharger_size", "75", true, false, "Glow radius for item_healthcharger")
    local hc_bright = BL.CreateClientConVar("betterlights_healthcharger_brightness", "0.25", true, false, "Glow brightness for item_healthcharger")
    local hc_decay = BL.CreateClientConVar("betterlights_healthcharger_decay", "1800", true, false, "Glow decay for item_healthcharger")
    local hc_elight = BL.CreateClientConVar("betterlights_healthcharger_models_elight", "1", true, false, "Add elight to light the charger model")
    local hc_elmult = BL.CreateClientConVar("betterlights_healthcharger_models_elight_size_mult", "1.0", true, false, "Elight radius multiplier for item_healthcharger")
    local hc_r = BL.CreateClientConVar("betterlights_healthcharger_color_r", "110", true, false, "Health charger color - red (0-255)")
    local hc_g = BL.CreateClientConVar("betterlights_healthcharger_color_g", "190", true, false, "Health charger color - green (0-255)")
    local hc_b = BL.CreateClientConVar("betterlights_healthcharger_color_b", "255", true, false, "Health charger color - blue (0-255)")

    BL.TrackClass("item_suitcharger")
    BL.TrackClass("item_healthcharger")

    local function process(class, en, sz, br, de, el, elmult, rcv, gcv, bcv)
        if not en:GetBool() then return end

        local size = math.max(0, sz:GetFloat())
        local brightness = math.max(0, br:GetFloat())
        local decay = math.max(0, de:GetFloat())
        local el_mult = math.max(0, elmult:GetFloat())
        local cr, cg, cb = BL.GetColorFromCvars(rcv, gcv, bcv)
        local doElight = el:GetBool()

        local function update(ent)
            if not IsValid(ent) then return end
            local idx = ent:EntIndex()
            local pos = BL.GetEntityCenter(ent)
            if pos then
                BL.CreateDLight(idx, pos, cr, cg, cb, brightness, decay, size, false)

                if doElight then
                    BL.CreateDLight(idx, pos, cr, cg, cb, brightness, decay, size * el_mult, true)
                end
            end
        end

        BL.ForEach(class, update)
    end
    BL.AddThink("BetterLights_Chargers_DLight", function()
        process("item_suitcharger", sc_enable, sc_size, sc_bright, sc_decay, sc_elight, sc_elmult, sc_r, sc_g, sc_b)
        process("item_healthcharger", hc_enable, hc_size, hc_bright, hc_decay, hc_elight, hc_elmult, hc_r, hc_g, hc_b)
    end)
end
