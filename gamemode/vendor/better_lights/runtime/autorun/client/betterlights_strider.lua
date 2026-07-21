if CLIENT then
    local BL = BetterLights

    BL.CreateClientConVar("betterlights_strider_muzzle_flash_enable", "1", true, false, "Enable blue muzzle flash light for Striders")
    BL.CreateClientConVar("betterlights_strider_muzzle_flash_size", "320", true, false, "Strider muzzle flash radius")
    BL.CreateClientConVar("betterlights_strider_muzzle_flash_brightness", "2.4", true, false, "Strider muzzle flash brightness")
    BL.CreateClientConVar("betterlights_strider_muzzle_flash_time", "0.08", true, false, "Strider muzzle flash duration")
    local cvar_impact_enable = BL.CreateClientConVar("betterlights_strider_bullet_impact_enable", "1", true, false, "Enable blue bullet impact light for Striders")
    local cvar_impact_size = BL.CreateClientConVar("betterlights_strider_bullet_impact_size", "90", true, false, "Strider bullet impact radius")
    local cvar_impact_brightness = BL.CreateClientConVar("betterlights_strider_bullet_impact_brightness", "0.45", true, false, "Strider bullet impact brightness")
    local cvar_impact_time = BL.CreateClientConVar("betterlights_strider_bullet_impact_time", "0.14", true, false, "Strider bullet impact duration")

    BL.CreateClientConVar("betterlights_strider_muzzle_flash_color_r", "80", true, false, "Strider muzzle flash color - red (0-255)")
    BL.CreateClientConVar("betterlights_strider_muzzle_flash_color_g", "210", true, false, "Strider muzzle flash color - green (0-255)")
    BL.CreateClientConVar("betterlights_strider_muzzle_flash_color_b", "255", true, false, "Strider muzzle flash color - blue (0-255)")
    local cvar_impact_r = BL.CreateClientConVar("betterlights_strider_bullet_impact_color_r", "80", true, false, "Strider bullet impact color - red (0-255)")
    local cvar_impact_g = BL.CreateClientConVar("betterlights_strider_bullet_impact_color_g", "210", true, false, "Strider bullet impact color - green (0-255)")
    local cvar_impact_b = BL.CreateClientConVar("betterlights_strider_bullet_impact_color_b", "255", true, false, "Strider bullet impact color - blue (0-255)")

    BL.AddNetworkHandler(BL.NET_STRIDER_BULLET_IMPACT, function()
        if not cvar_impact_enable:GetBool() then return end

        local pos = net.ReadVector()
        local r, g, b = BL.GetColorFromCvars(cvar_impact_r, cvar_impact_g, cvar_impact_b)
        local size = math.max(0, cvar_impact_size:GetFloat())
        local brightness = math.max(0, cvar_impact_brightness:GetFloat())
        local duration = math.max(0, cvar_impact_time:GetFloat())
        if duration <= 0 then return end

        BL.CreateFlash(pos, r, g, b, size, brightness, duration, 59600)
    end)
end
