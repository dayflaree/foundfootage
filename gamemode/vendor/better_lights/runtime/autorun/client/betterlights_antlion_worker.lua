if CLIENT then
    local BL = BetterLights
    local IsValid = IsValid
    local cvar_enable = BL.CreateClientConVar("betterlights_antlion_worker_enable", "1", true, false, "Enable subtle glow on Antlion Workers")
    local cvar_size = BL.CreateClientConVar("betterlights_antlion_worker_size", "120", true, false, "Antlion Worker light radius")
    local cvar_brightness = BL.CreateClientConVar("betterlights_antlion_worker_brightness", "0.55", true, false, "Antlion Worker light brightness")
    local cvar_decay = BL.CreateClientConVar("betterlights_antlion_worker_decay", "2000", true, false, "Antlion Worker light decay")

    local cvar_col_r = BL.CreateClientConVar("betterlights_antlion_worker_color_r", "180", true, false, "Antlion Worker color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_antlion_worker_color_g", "240", true, false, "Antlion Worker color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_antlion_worker_color_b", "120", true, false, "Antlion Worker color - blue (0-255)")

    BL.TrackClass("npc_antlion_worker")
    BL.AddThink("BetterLights_AntlionWorker", function()
        if not cvar_enable:GetBool() then return end

        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())
        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)

        local function update(ent)
            if not IsValid(ent) then return end
            if ent.GetNoDraw and ent:GetNoDraw() then return end

            BL.CreateLightAtEntityCenter(ent, ent:EntIndex() + 23200, r, g, b, brightness, decay, size, false)
        end

        BL.ForEach("npc_antlion_worker", update)
    end)
end
