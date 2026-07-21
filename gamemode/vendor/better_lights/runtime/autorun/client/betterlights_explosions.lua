if CLIENT then
    local BL = BetterLights
    local EXP = BL.Explosions

    local cvar_enable = BL.CreateClientConVar("betterlights_explosion_flash_enable", "1", true, false, "Enable generic explosion flashes (env_explosion, explosive barrels, etc.)")
    local cvar_size = BL.CreateClientConVar("betterlights_explosion_flash_size", "460", true, false, "Generic explosion flash radius")
    local cvar_brightness = BL.CreateClientConVar("betterlights_explosion_flash_brightness", "4.6", true, false, "Generic explosion flash brightness")
    local cvar_time = BL.CreateClientConVar("betterlights_explosion_flash_time", "0.18", true, false, "Generic explosion flash duration (seconds)")
    local cvar_r = BL.CreateClientConVar("betterlights_explosion_flash_color_r", "255", true, false, "Explosion flash color - red component (0-255)")
    local cvar_g = BL.CreateClientConVar("betterlights_explosion_flash_color_g", "210", true, false, "Explosion flash color - green component (0-255)")
    local cvar_b = BL.CreateClientConVar("betterlights_explosion_flash_color_b", "120", true, false, "Explosion flash color - blue component (0-255)")

    local function registerGenericProfile(id)
        EXP.RegisterClientProfile(id, {
            enableCvar = cvar_enable,
            sizeCvar = cvar_size,
            brightnessCvar = cvar_brightness,
            durationCvar = cvar_time,
            rCvar = cvar_r,
            gCvar = cvar_g,
            bCvar = cvar_b,
            baseId = 61000,
            suppressionKey = "explosion"
        })
    end

    registerGenericProfile("generic")
    registerGenericProfile("env")
    registerGenericProfile("barrel")
    registerGenericProfile("scanner")
    registerGenericProfile("combine_mine")
end
