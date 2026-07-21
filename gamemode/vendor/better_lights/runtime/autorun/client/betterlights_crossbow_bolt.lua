if CLIENT then
    local BL = BetterLights
    local IsValid = IsValid
    local cvar_enable = BL.CreateClientConVar("betterlights_bolt_enable", "1", true, false, "Enable dynamic light for crossbow bolts")
    local cvar_size = BL.CreateClientConVar("betterlights_bolt_size", "220", true, false, "Dynamic light radius for crossbow bolts")
    local cvar_brightness = BL.CreateClientConVar("betterlights_bolt_brightness", "0.96", true, false, "Dynamic light brightness for crossbow bolts")
    local cvar_decay = BL.CreateClientConVar("betterlights_bolt_decay", "2000", true, false, "Dynamic light decay for crossbow bolts")

    local cvar_col_r = BL.CreateClientConVar("betterlights_bolt_color_r", "255", true, false, "Crossbow bolt color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_bolt_color_g", "140", true, false, "Crossbow bolt color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_bolt_color_b", "40", true, false, "Crossbow bolt color - blue (0-255)")

    BL.TrackClass("crossbow_bolt")
    BL.AddThink("BetterLights_CrossbowBolt_DLight", function()
        if not cvar_enable:GetBool() then return end

        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())
        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)

        local function update(ent)
            if not IsValid(ent) then return end
            local pos = ent:WorldSpaceCenter()
            BL.CreateDLight(ent:EntIndex(), pos, r, g, b, brightness, decay, size, false)
        end

        BL.ForEach("crossbow_bolt", update)
    end)
end
