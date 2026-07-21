if CLIENT then
    local BL = BetterLights
    local IsValid = IsValid
    local cvar_enable = BL.CreateClientConVar("betterlights_grenade_enable", "1", true, false, "Enable dim red light on frag grenades (npc_grenade_frag)")
    local cvar_size = BL.CreateClientConVar("betterlights_grenade_size", "80", true, false, "Dynamic light radius for frag grenades")
    local cvar_brightness = BL.CreateClientConVar("betterlights_grenade_brightness", "0.9", true, false, "Dynamic light brightness for frag grenades")
    local cvar_decay = BL.CreateClientConVar("betterlights_grenade_decay", "1800", true, false, "Dynamic light decay for frag grenades")
    local cvar_models_elight = BL.CreateClientConVar("betterlights_grenade_models_elight", "1", true, false, "Also add an entity light (elight) to light the grenade model directly")
    local cvar_models_elight_size_mult = BL.CreateClientConVar("betterlights_grenade_models_elight_size_mult", "1.0", true, false, "Multiplier for grenade elight radius")

    local cvar_col_r = BL.CreateClientConVar("betterlights_grenade_color_r", "255", true, false, "Frag grenade color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_grenade_color_g", "40", true, false, "Frag grenade color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_grenade_color_b", "40", true, false, "Frag grenade color - blue (0-255)")

    BL.TrackClass("npc_grenade_frag")
    BL.AddThink("BetterLights_Grenade_DLight", function()
        if not cvar_enable:GetBool() then return end

        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())
        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)
        local doElight = cvar_models_elight:GetBool()
        local elMult = math.max(0, cvar_models_elight_size_mult:GetFloat())

        local function update(n)
            if not IsValid(n) then return end

            local pos = BL.GetEntityCenter(n)
            if not pos then return end

            local idx = n:EntIndex()

            BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size, false)

            if doElight then
                BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size * elMult, true)
            end
        end

        BL.ForEach("npc_grenade_frag", update)
    end)
end
