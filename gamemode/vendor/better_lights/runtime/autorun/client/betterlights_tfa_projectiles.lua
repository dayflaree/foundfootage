if CLIENT then
    local BL = BetterLights
    local TFA_ROCKET_CLASS = "tfa_exp_rocket"
    local cvar_enable = GetConVar("betterlights_rpg_enable")
    local cvar_size = GetConVar("betterlights_rpg_size")
    local cvar_brightness = GetConVar("betterlights_rpg_brightness")
    local cvar_decay = GetConVar("betterlights_rpg_decay")
    local cvar_r = GetConVar("betterlights_rpg_color_r")
    local cvar_g = GetConVar("betterlights_rpg_color_g")
    local cvar_b = GetConVar("betterlights_rpg_color_b")

    BL.TrackClass(TFA_ROCKET_CLASS)
    BL.AddThink("BetterLights_TFA_Rocket_DLight", function()
        if not (cvar_enable and cvar_enable:GetBool()) then return end

        local r, g, b = BL.GetColorFromCvars(cvar_r, cvar_g, cvar_b)
        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())

        BL.ForEach(TFA_ROCKET_CLASS, function(ent)
            if not IsValid(ent) then return end

            BL.CreateDLight(ent:EntIndex(), ent:WorldSpaceCenter(), r, g, b, brightness, decay, size, false)
        end)
    end)
end
