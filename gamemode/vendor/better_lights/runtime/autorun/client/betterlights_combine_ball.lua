if CLIENT then
    local BL = BetterLights
    local cvar_enable = BL.CreateClientConVar("betterlights_combineball_enable", "1", true, false, "Enable dynamic light for Combine AR2 orb")
    local cvar_size = BL.CreateClientConVar("betterlights_combineball_size", "320", true, false, "Dynamic light radius for Combine AR2 orb")
    local cvar_brightness = BL.CreateClientConVar("betterlights_combineball_brightness", "2.5", true, false, "Dynamic light brightness for Combine AR2 orb")
    local cvar_decay = BL.CreateClientConVar("betterlights_combineball_decay", "2000", true, false, "Dynamic light decay for Combine AR2 orb (higher = faster fade)")

    local cvar_world_enable = BL.CreateClientConVar("betterlights_combineball_world_light_enable", "1", true, false, "Enable world lighting (turn off to avoid lighting static world surfaces)")
    local cvar_models_enable = BL.CreateClientConVar("betterlights_combineball_model_light_enable", "1", true, false, "Enable model lighting")
    local cvar_models_elight = BL.CreateClientConVar("betterlights_combineball_models_elight", "0", true, false, "Also add an entity light (elight) for models (useful when world light is disabled)")
    local cvar_models_elight_size_mult = BL.CreateClientConVar("betterlights_combineball_models_elight_size_mult", "1.0", true, false, "Multiplier for model elight radius")

    local cvar_col_r = BL.CreateClientConVar("betterlights_combineball_color_r", "80", true, false, "Combine ball color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_combineball_color_g", "180", true, false, "Combine ball color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_combineball_color_b", "255", true, false, "Combine ball color - blue (0-255)")

    BL.TrackClass("prop_combine_ball")
    BL.AddThink("BetterLights_CombineBall_DLight", function()
        if not cvar_enable:GetBool() then return end

        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())
        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)
        local wantWorld = cvar_world_enable:GetBool()
        local wantModels = cvar_models_enable:GetBool()
        local wantElight = cvar_models_elight:GetBool()
        local elMult = math.max(0, cvar_models_elight_size_mult:GetFloat())

        local function update(ent)
            if not IsValid(ent) then return end
            local pos = ent:WorldSpaceCenter()

            if wantWorld then
                BL.CreateDLight(ent:EntIndex(), pos, r, g, b, brightness, decay, size, false, {
                    nomodel = not wantModels
                })
            end

            if wantModels and (not wantWorld) then
                if wantElight then
                    BL.CreateDLight(ent:EntIndex(), pos, r, g, b, brightness, decay, size * elMult, true)
                else
                    BL.CreateDLight(ent:EntIndex(), pos, r, g, b, brightness, decay, size, false, {
                        noworld = true
                    })
                end
            end
        end

        BL.ForEach("prop_combine_ball", update)
    end)
end
