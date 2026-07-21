if CLIENT then
    local BL = BetterLights
    local IsValid = IsValid
    local cvar_enable = BL.CreateClientConVar("betterlights_antlion_guardian_enable", "1", true, false, "Enable green glow on Antlion Guardian")
    local cvar_size = BL.CreateClientConVar("betterlights_antlion_guardian_size", "180", true, false, "Guardian light radius")
    local cvar_brightness = BL.CreateClientConVar("betterlights_antlion_guardian_brightness", "0.6", true, false, "Guardian light brightness")
    local cvar_decay = BL.CreateClientConVar("betterlights_antlion_guardian_decay", "2000", true, false, "Guardian light decay")

    local cvar_debug = BL.CreateClientConVar("betterlights_antlion_guardian_debug", "0", false, false, "Debug guardian detection prints")

    local cvar_col_r = BL.CreateClientConVar("betterlights_antlion_guardian_color_r", "120", true, false, "Antlion Guardian color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_antlion_guardian_color_g", "255", true, false, "Antlion Guardian color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_antlion_guardian_color_b", "140", true, false, "Antlion Guardian color - blue (0-255)")
    local ATTACH_NAMES = { "attach_glow1", "attach_glow2" }

    local function looksLikeGuardian(ent)
        return BL.DetectEntityVariant(ent, {
            debugName = "guardian",
            debugCvar = cvar_debug,
            nwBools = { "guardian", "isguardian", "antlionguardian", "is_guardian", "antlion_guardian", "IsGuardian" },
            saveTableKeys = { "m_bGuardian", "guardian", "isguardian", "m_bIsGuardian", "IsGuardian" },
            saveTableKeyword = "guardian",
            skin = function(s) return s > 0 end,  -- Guardian typically uses non-default skin
            targetname = "guardian"
        })
    end

    BL.TrackClass("npc_antlionguard")
    BL.AddThink("BetterLights_AntlionGuardian", function()
        if not cvar_enable:GetBool() then return end

        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())
        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)

        local function update(ent)
            if not IsValid(ent) then return end
            if ent.GetNoDraw and ent:GetNoDraw() then return end
            if not looksLikeGuardian(ent) then return end

            for i, attachmentName in ipairs(ATTACH_NAMES) do
                local pos = BL.GetAttachmentPos(ent, { attachmentName })
                if pos then
                    BL.CreateDLight(ent:EntIndex() + 23100 + (i * 100), pos, r, g, b, brightness, decay, size, false)
                end
            end
        end

        BL.ForEach("npc_antlionguard", update)
    end)
end
