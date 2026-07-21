if CLIENT then
    local BL = BetterLights
    local EXP = BL.Explosions
    local IsValid = IsValid
    local cvar_enable = BL.CreateClientConVar("betterlights_rpg_enable", "1", true, false, "Enable dynamic light for fired RPG rockets")
    local cvar_size = BL.CreateClientConVar("betterlights_rpg_size", "280", true, false, "Dynamic light radius for RPG rockets")
    local cvar_brightness = BL.CreateClientConVar("betterlights_rpg_brightness", "2.2", true, false, "Dynamic light brightness for RPG rockets")
    local cvar_decay = BL.CreateClientConVar("betterlights_rpg_decay", "2000", true, false, "Dynamic light decay for RPG rockets")

    local cvar_col_r = BL.CreateClientConVar("betterlights_rpg_color_r", "255", true, false, "RPG rocket color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_rpg_color_g", "170", true, false, "RPG rocket color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_rpg_color_b", "60", true, false, "RPG rocket color - blue (0-255)")

    local cvar_flash_enable = BL.CreateClientConVar("betterlights_rpg_flash_enable", "1", true, false, "Add a brief light flash when an RPG rocket explodes")
    local cvar_flash_size = BL.CreateClientConVar("betterlights_rpg_flash_size", "340", true, false, "Explosion flash radius for RPG rockets")
    local cvar_flash_brightness = BL.CreateClientConVar("betterlights_rpg_flash_brightness", "4.8", true, false, "Explosion flash brightness for RPG rockets")
    local cvar_flash_time = BL.CreateClientConVar("betterlights_rpg_flash_time", "0.18", true, false, "Duration of the RPG explosion flash (seconds)")
    local cvar_flash_r = BL.CreateClientConVar("betterlights_rpg_flash_color_r", "255", true, false, "RPG flash color - red (0-255)")
    local cvar_flash_g = BL.CreateClientConVar("betterlights_rpg_flash_color_g", "210", true, false, "RPG flash color - green (0-255)")
    local cvar_flash_b = BL.CreateClientConVar("betterlights_rpg_flash_color_b", "120", true, false, "RPG flash color - blue (0-255)")

    EXP.RegisterClientProfile("rpg", {
        enableCvar = cvar_flash_enable,
        sizeCvar = cvar_flash_size,
        brightnessCvar = cvar_flash_brightness,
        durationCvar = cvar_flash_time,
        rCvar = cvar_flash_r,
        gCvar = cvar_flash_g,
        bCvar = cvar_flash_b,
        baseId = 58000,
        suppressionKey = "explosion"
    })

    BL.TrackClass("rpg_missile")
    BL.AddThink("BetterLights_RPGMissile_DLight", function()
        if not cvar_enable:GetBool() then return end

        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)
        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())

        local function update(ent)
            if not IsValid(ent) then return end
            local pos = ent:WorldSpaceCenter()
            BL.CreateDLight(ent:EntIndex(), pos, r, g, b, brightness, decay, size, false)
        end

        BL.ForEach("rpg_missile", update)
    end)
end
