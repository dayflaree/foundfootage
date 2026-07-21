if CLIENT then
    local BL = BetterLights
    local cvar_enable = BL.CreateClientConVar("betterlights_rpg_hold_enable", "1", true, false, "Enable subtle red lights on the RPG while held")
    local cvar_size = BL.CreateClientConVar("betterlights_rpg_hold_size", "24", true, false, "Dynamic light radius for held RPG lights")
    local cvar_brightness = BL.CreateClientConVar("betterlights_rpg_hold_brightness", "0.22", true, false, "Dynamic light brightness for held RPG lights")
    local cvar_decay = BL.CreateClientConVar("betterlights_rpg_hold_decay", "2000", true, false, "Dynamic light decay for held RPG lights")

    local cvar_col_r = BL.CreateClientConVar("betterlights_rpg_hold_color_r", "255", true, false, "RPG (Held) color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_rpg_hold_color_g", "60", true, false, "RPG (Held) color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_rpg_hold_color_b", "60", true, false, "RPG (Held) color - blue (0-255)")

    local SURFACE_LIGHT = { key = "rpg_hold", distance = 8192, missDistance = 1024, hitOffset = 6 }

    BL.AddThink("BetterLights_RPG_Held_DLight", function()
        if not cvar_enable:GetBool() then return end

        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        if not BL.IsPlayerHoldingWeapon("weapon_rpg") then return end

        local wep = ply:GetActiveWeapon()
        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())

        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)

        local idx = ply:EntIndex() + 1520

        BL.CreateHeldWeaponSurfaceLight(ply, wep, SURFACE_LIGHT, idx, r, g, b, brightness, decay, size, false)
    end)
end
