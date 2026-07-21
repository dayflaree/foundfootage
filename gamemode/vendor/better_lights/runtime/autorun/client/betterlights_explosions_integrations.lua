if CLIENT then
    local BL = BetterLights
    local EXP = BL.Explosions

    local cvar_enable = GetConVar("betterlights_explosion_flash_enable")
    local cvar_size = GetConVar("betterlights_explosion_flash_size")
    local cvar_brightness = GetConVar("betterlights_explosion_flash_brightness")
    local cvar_time = GetConVar("betterlights_explosion_flash_time")
    local cvar_r = GetConVar("betterlights_explosion_flash_color_r")
    local cvar_g = GetConVar("betterlights_explosion_flash_color_g")
    local cvar_b = GetConVar("betterlights_explosion_flash_color_b")

    EXP.RegisterClientProfile("weapon_base_explosion", {
        enableCvar = cvar_enable,
        sizeCvar = cvar_size,
        brightnessCvar = cvar_brightness,
        durationCvar = cvar_time,
        rCvar = cvar_r,
        gCvar = cvar_g,
        bCvar = cvar_b,
        baseId = 61200,
        suppressionKey = "explosion"
    })

    EXP.RegisterClientProfile("cw2_flashbang", {
        enableCvar = cvar_enable,
        sizeCvar = cvar_size,
        brightnessCvar = cvar_brightness,
        durationCvar = cvar_time,
        r = 255,
        g = 255,
        b = 255,
        baseId = 61300,
        suppressionKey = "explosion"
    })
end
