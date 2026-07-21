if CLIENT then
    local BL = BetterLights
    local cvar_enable = BL.CreateClientConVar("betterlights_rollermine_enable", "1", true, false, "Enable dynamic light for Rollermines (npc_rollermine)")
    local cvar_size = BL.CreateClientConVar("betterlights_rollermine_size", "110", true, false, "Dynamic light radius for Rollermines")
    local cvar_brightness = BL.CreateClientConVar("betterlights_rollermine_brightness", "0.6", true, false, "Dynamic light brightness for Rollermines")
    local cvar_decay = BL.CreateClientConVar("betterlights_rollermine_decay", "2000", true, false, "Dynamic light decay for Rollermines")
    local cvar_models_elight = BL.CreateClientConVar("betterlights_rollermine_models_elight", "1", true, false, "Also add an entity light (elight) to light the rollermine model directly")
    local cvar_models_elight_size_mult = BL.CreateClientConVar("betterlights_rollermine_models_elight_size_mult", "1.0", true, false, "Multiplier for rollermine elight radius")

    local cvar_h_enable = BL.CreateClientConVar("betterlights_rollermine_hacked_enable", "1", true, false, "Enable dynamic light for Hacked Rollermines (ally)")
    local cvar_h_size = BL.CreateClientConVar("betterlights_rollermine_hacked_size", "110", true, false, "Dynamic light radius for Hacked Rollermines")
    local cvar_h_brightness = BL.CreateClientConVar("betterlights_rollermine_hacked_brightness", "0.6", true, false, "Dynamic light brightness for Hacked Rollermines")
    local cvar_h_decay = BL.CreateClientConVar("betterlights_rollermine_hacked_decay", "2000", true, false, "Dynamic light decay for Hacked Rollermines")
    local cvar_h_models_elight = BL.CreateClientConVar("betterlights_rollermine_hacked_models_elight", "1", true, false, "Also add an entity light (elight) to light the hacked rollermine model directly")
    local cvar_h_models_elight_mult = BL.CreateClientConVar("betterlights_rollermine_hacked_models_elight_size_mult", "1.0", true, false, "Multiplier for hacked rollermine elight radius")
    local cvar_debug = BL.CreateClientConVar("betterlights_rollermine_debug", "0", true, false, "Debug hacked rollermine detection (prints to console)")

    local rm0_r = BL.CreateClientConVar("betterlights_rollermine_color_r", "110", true, false, "Rollermine skin0 (default) color - red (0-255)")
    local rm0_g = BL.CreateClientConVar("betterlights_rollermine_color_g", "190", true, false, "Rollermine skin0 (default) color - green (0-255)")
    local rm0_b = BL.CreateClientConVar("betterlights_rollermine_color_b", "255", true, false, "Rollermine skin0 (default) color - blue (0-255)")
    local rm1_r = BL.CreateClientConVar("betterlights_rollermine_skin1_color_r", "255", true, false, "Rollermine skin1 (yellow) color - red (0-255)")
    local rm1_g = BL.CreateClientConVar("betterlights_rollermine_skin1_color_g", "220", true, false, "Rollermine skin1 (yellow) color - green (0-255)")
    local rm1_b = BL.CreateClientConVar("betterlights_rollermine_skin1_color_b", "60", true, false, "Rollermine skin1 (yellow) color - blue (0-255)")
    local rm2_r = BL.CreateClientConVar("betterlights_rollermine_skin2_color_r", "255", true, false, "Rollermine skin2 (red) color - red (0-255)")
    local rm2_g = BL.CreateClientConVar("betterlights_rollermine_skin2_color_g", "80", true, false, "Rollermine skin2 (red) color - green (0-255)")
    local rm2_b = BL.CreateClientConVar("betterlights_rollermine_skin2_color_b", "80", true, false, "Rollermine skin2 (red) color - blue (0-255)")
    local skinColors = {
        [0] = function() return BL.GetColorFromCvars(rm0_r, rm0_g, rm0_b) end,
        [1] = function() return BL.GetColorFromCvars(rm1_r, rm1_g, rm1_b) end,
        [2] = function() return BL.GetColorFromCvars(rm2_r, rm2_g, rm2_b) end
    }

    local function BL_GetRollermineColor(ent)
        local colorFn = BL.DetectSkinVariant(ent, skinColors)
        if colorFn then return colorFn() end
        return BL.GetColorFromCvars(rm0_r, rm0_g, rm0_b)
    end

    local function BL_IsRollermineHacked(ent)
        return BL.DetectEntityVariant(ent, {
            debugName = "hacked rollermine",
            debugCvar = cvar_debug,
            nwBools = { "m_bHacked", "hacked", "isHacked", "friendly", "is_friendly", "IsFriendly" },
            saveTableKeys = { "m_bHacked", "m_bIsHacked", "hacked" },
            checkDisposition = true
        })
    end

    BL.TrackClass("npc_rollermine")
    BL.AddThink("BetterLights_Rollermine_DLight", function()
        if not cvar_enable:GetBool() and not cvar_h_enable:GetBool() then return end
        local function update(ent)
            if not IsValid(ent) then return end

            local hacked = BL_IsRollermineHacked(ent)
            if hacked and not cvar_h_enable:GetBool() then return end
            if (not hacked) and not cvar_enable:GetBool() then return end

            local idx = ent:EntIndex()
            local pos = BL.GetEntityCenter(ent)
            if not pos then return end

            if cvar_debug:GetBool() and hacked then
                ent._bl_lastHackDbg = ent._bl_lastHackDbg or 0
                local now = CurTime()
                if now - (ent._bl_lastHackDbg or 0) > 1 then
                    ent._bl_lastHackDbg = now
                    print(string.format("[BetterLights] Rollermine #%d hacked=true skin=%s", ent:EntIndex(), tostring(ent.GetSkin and ent:GetSkin())))
                end
            end

            local r, g, b
            local size, brightness, decay, use_elight, el_mult
            if hacked then
                r, g, b = BL.GetColorFromCvars(rm1_r, rm1_g, rm1_b)
                size = math.max(0, cvar_h_size:GetFloat())
                brightness = math.max(0, cvar_h_brightness:GetFloat())
                decay = math.max(0, cvar_h_decay:GetFloat())
                use_elight = cvar_h_models_elight:GetBool()
                el_mult = math.max(0, cvar_h_models_elight_mult:GetFloat())
            else
                r, g, b = BL_GetRollermineColor(ent)
                size = math.max(0, cvar_size:GetFloat())
                brightness = math.max(0, cvar_brightness:GetFloat())
                decay = math.max(0, cvar_decay:GetFloat())
                use_elight = cvar_models_elight:GetBool()
                el_mult = math.max(0, cvar_models_elight_size_mult:GetFloat())
            end

            if BL.MatchesModel(ent, "roller_spikes") then
                brightness = brightness * 2.5
                size = size * 1.5
            end

            BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size, false)

            if use_elight then
                BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size * el_mult, true)
            end
        end

        BL.ForEach("npc_rollermine", update)
    end)
end
