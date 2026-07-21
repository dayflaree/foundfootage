if CLIENT then
    local BL = BetterLights
    local IsValid = IsValid
    local cvar_enable = BL.CreateClientConVar("betterlights_manhack_enable", "1", true, false, "Enable dynamic light for Manhacks (npc_manhack)")
    local cvar_size = BL.CreateClientConVar("betterlights_manhack_size", "70", true, false, "Dynamic light radius for Manhacks")
    local cvar_brightness = BL.CreateClientConVar("betterlights_manhack_brightness", "0.6", true, false, "Dynamic light brightness for Manhacks")
    local cvar_decay = BL.CreateClientConVar("betterlights_manhack_decay", "2000", true, false, "Dynamic light decay for Manhacks")
    local cvar_models_elight = BL.CreateClientConVar("betterlights_manhack_models_elight", "1", true, false, "Also add an entity light (elight) to light the Manhack model directly")
    local cvar_models_elight_size_mult = BL.CreateClientConVar("betterlights_manhack_models_elight_size_mult", "1.0", true, false, "Multiplier for Manhack elight radius")

    local cvar_col_r = BL.CreateClientConVar("betterlights_manhack_color_r", "255", true, false, "Manhack color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_manhack_color_g", "60", true, false, "Manhack color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_manhack_color_b", "60", true, false, "Manhack color - blue (0-255)")
    local ATTACH_NAMES = { "Eye", "Light" }

    BL.TrackClass("npc_manhack")
    BL.AddThink("BetterLights_Manhack_DLight", function()
        if not cvar_enable:GetBool() then return end

        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())
        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)
        local doElight = cvar_models_elight:GetBool()
        local elMult = math.max(0, cvar_models_elight_size_mult:GetFloat())

        local function update(ent)
            if not IsValid(ent) then return end

            local idx = ent:EntIndex()
            for i, attachmentName in ipairs(ATTACH_NAMES) do
                local pos = BL.GetAttachmentPos(ent, { attachmentName })
                if pos then
                    local lightId = idx + (i * 10000)
                    BL.CreateDLight(lightId, pos, r, g, b, brightness, decay, size, false)

                    if doElight then
                        BL.CreateDLight(lightId, pos, r, g, b, brightness, decay, size * elMult, true)
                    end
                end
            end
        end

        BL.ForEach("npc_manhack", update)
    end)
end
