if CLIENT then
    local BL = BetterLights

    local cvar_enable = BL.CreateClientConVar("betterlights_stunstick_impact_enable", "1", true, false, "Enable Stun Stick impact light")
    local cvar_size = BL.CreateClientConVar("betterlights_stunstick_impact_size", "120", true, false, "Stun Stick impact radius")
    local cvar_brightness = BL.CreateClientConVar("betterlights_stunstick_impact_brightness", "1.6", true, false, "Stun Stick impact brightness")
    local cvar_time = BL.CreateClientConVar("betterlights_stunstick_impact_time", "0.14", true, false, "Stun Stick impact duration")

    local cvar_col_r = BL.CreateClientConVar("betterlights_stunstick_impact_color_r", "120", true, false, "Stun Stick impact color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_stunstick_impact_color_g", "190", true, false, "Stun Stick impact color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_stunstick_impact_color_b", "255", true, false, "Stun Stick impact color - blue (0-255)")

    BL.AddNetworkHandler(BL.NET_STUNSTICK_IMPACT, function()
        if not cvar_enable:GetBool() then return end

        local pos = net.ReadVector()
        local duration = math.max(0, cvar_time:GetFloat())
        if duration <= 0 then return end

        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)
        BL.CreateFlash(
            pos,
            r,
            g,
            b,
            math.max(0, cvar_size:GetFloat()),
            math.max(0, cvar_brightness:GetFloat()),
            duration,
            59900
        )
    end)
end
