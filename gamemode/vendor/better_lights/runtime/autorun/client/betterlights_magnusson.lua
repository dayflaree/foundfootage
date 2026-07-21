if CLIENT then
    local BL = BetterLights
    local EXP = BL.Explosions

    local cvar_enable = BL.CreateClientConVar("betterlights_magnusson_enable", "1", true, false, "Enable dynamic light for Magnusson devices (Strider Busters)")
    local cvar_size = BL.CreateClientConVar("betterlights_magnusson_size", "130", true, false, "Dynamic light radius for Magnusson devices")
    local cvar_brightness = BL.CreateClientConVar("betterlights_magnusson_brightness", "0.48", true, false, "Dynamic light brightness for Magnusson devices")
    local cvar_decay = BL.CreateClientConVar("betterlights_magnusson_decay", "2000", true, false, "Dynamic light decay for Magnusson devices")
    local cvar_models_elight = BL.CreateClientConVar("betterlights_magnusson_models_elight", "1", true, false, "Also add an entity light (elight) to light the device model directly")
    local cvar_models_elight_size_mult = BL.CreateClientConVar("betterlights_magnusson_models_elight_size_mult", "1.0", true, false, "Multiplier for Magnusson device elight radius")

    local cvar_flash_enable = BL.CreateClientConVar("betterlights_magnusson_flash_enable", "1", true, false, "Add a brief light flash when a Magnusson device explodes")
    local cvar_flash_size = BL.CreateClientConVar("betterlights_magnusson_flash_size", "360", true, false, "Explosion flash radius for Magnusson devices")
    local cvar_flash_brightness = BL.CreateClientConVar("betterlights_magnusson_flash_brightness", "2.2", true, false, "Explosion flash brightness for Magnusson devices")
    local cvar_flash_time = BL.CreateClientConVar("betterlights_magnusson_flash_time", "2.0", true, false, "Duration of the explosion flash (seconds)")

    local cvar_col_r = BL.CreateClientConVar("betterlights_magnusson_color_r", "130", true, false, "Magnusson device glow color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_magnusson_color_g", "180", true, false, "Magnusson device glow color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_magnusson_color_b", "255", true, false, "Magnusson device glow color - blue (0-255)")
    local cvar_flash_r = BL.CreateClientConVar("betterlights_magnusson_flash_color_r", "180", true, false, "Magnusson flash color - red (0-255)")
    local cvar_flash_g = BL.CreateClientConVar("betterlights_magnusson_flash_color_g", "220", true, false, "Magnusson flash color - green (0-255)")
    local cvar_flash_b = BL.CreateClientConVar("betterlights_magnusson_flash_color_b", "255", true, false, "Magnusson flash color - blue (0-255)")

    local TARGET_CLASS = "weapon_striderbuster"

    BL.TrackClass(TARGET_CLASS)

    EXP.RegisterClientProfile("magnusson", {
        enableCvar = cvar_flash_enable,
        sizeCvar = cvar_flash_size,
        brightnessCvar = cvar_flash_brightness,
        durationCvar = cvar_flash_time,
        rCvar = cvar_flash_r,
        gCvar = cvar_flash_g,
        bCvar = cvar_flash_b,
        baseId = 59000,
        suppressionKey = "explosion"
    })

    BL.AddThink("BetterLights_Magnusson_DLight", function()
        if not cvar_enable:GetBool() then return end

        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())
        local doElight = cvar_models_elight:GetBool()
        local elMult = math.max(0, cvar_models_elight_size_mult:GetFloat())

        local gr, gg, gb = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)

        local function update(ent)
            local idx = ent:EntIndex()
            local pos = BL.GetEntityCenter(ent)
            if not pos then return end

            BL.CreateDLight(idx, pos, gr, gg, gb, brightness, decay, size, false)

            if doElight then
                BL.CreateDLight(idx, pos, gr, gg, gb, brightness, decay, size * elMult, true)
            end
        end

        BL.ForEach(TARGET_CLASS, update)
    end)
end
