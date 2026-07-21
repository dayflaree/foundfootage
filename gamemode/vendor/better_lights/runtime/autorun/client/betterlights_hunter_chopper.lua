if CLIENT then
    local BL = BetterLights

    local CHOPPER_CLASS = "npc_helicopter"
    local SPOTLIGHT_ATTACHMENT = { "Spotlight" }

    BL.CreateClientConVar("betterlights_hunter_chopper_muzzle_flash_enable", "1", true, false, "Enable blue muzzle flash light for Hunter Choppers")
    BL.CreateClientConVar("betterlights_hunter_chopper_muzzle_flash_size", "260", true, false, "Hunter Chopper muzzle flash radius")
    BL.CreateClientConVar("betterlights_hunter_chopper_muzzle_flash_brightness", "2.2", true, false, "Hunter Chopper muzzle flash brightness")
    BL.CreateClientConVar("betterlights_hunter_chopper_muzzle_flash_time", "0.08", true, false, "Hunter Chopper muzzle flash duration")
    local cvar_impact_enable = BL.CreateClientConVar("betterlights_hunter_chopper_bullet_impact_enable", "1", true, false, "Enable blue bullet impact light for Hunter Choppers")
    local cvar_impact_size = BL.CreateClientConVar("betterlights_hunter_chopper_bullet_impact_size", "80", true, false, "Hunter Chopper bullet impact radius")
    local cvar_impact_brightness = BL.CreateClientConVar("betterlights_hunter_chopper_bullet_impact_brightness", "0.4", true, false, "Hunter Chopper bullet impact brightness")
    local cvar_impact_time = BL.CreateClientConVar("betterlights_hunter_chopper_bullet_impact_time", "0.12", true, false, "Hunter Chopper bullet impact duration")

    local cvar_spotlight_enable = BL.CreateClientConVar("betterlights_hunter_chopper_spotlight_enable", "1", true, false, "Enable Hunter Chopper spotlight")
    local cvar_spotlight_fov = BL.CreateClientConVar("betterlights_hunter_chopper_spotlight_fov", "34", true, false, "Hunter Chopper spotlight FOV")
    local cvar_spotlight_distance = BL.CreateClientConVar("betterlights_hunter_chopper_spotlight_distance", "1400", true, false, "Hunter Chopper spotlight distance")
    local cvar_spotlight_near = BL.CreateClientConVar("betterlights_hunter_chopper_spotlight_near", "8", true, false, "Hunter Chopper spotlight near plane")
    local cvar_spotlight_brightness = BL.CreateClientConVar("betterlights_hunter_chopper_spotlight_brightness", "0.85", true, false, "Hunter Chopper spotlight brightness")
    local cvar_spotlight_shadows = BL.CreateClientConVar("betterlights_hunter_chopper_spotlight_shadows", "1", true, false, "Enable Hunter Chopper spotlight shadows")

    BL.CreateClientConVar("betterlights_hunter_chopper_muzzle_flash_color_r", "80", true, false, "Hunter Chopper muzzle flash color - red (0-255)")
    BL.CreateClientConVar("betterlights_hunter_chopper_muzzle_flash_color_g", "210", true, false, "Hunter Chopper muzzle flash color - green (0-255)")
    BL.CreateClientConVar("betterlights_hunter_chopper_muzzle_flash_color_b", "255", true, false, "Hunter Chopper muzzle flash color - blue (0-255)")
    local cvar_impact_r = BL.CreateClientConVar("betterlights_hunter_chopper_bullet_impact_color_r", "80", true, false, "Hunter Chopper bullet impact color - red (0-255)")
    local cvar_impact_g = BL.CreateClientConVar("betterlights_hunter_chopper_bullet_impact_color_g", "210", true, false, "Hunter Chopper bullet impact color - green (0-255)")
    local cvar_impact_b = BL.CreateClientConVar("betterlights_hunter_chopper_bullet_impact_color_b", "255", true, false, "Hunter Chopper bullet impact color - blue (0-255)")
    local cvar_spotlight_r = BL.CreateClientConVar("betterlights_hunter_chopper_spotlight_color_r", "210", true, false, "Hunter Chopper spotlight color - red (0-255)")
    local cvar_spotlight_g = BL.CreateClientConVar("betterlights_hunter_chopper_spotlight_color_g", "235", true, false, "Hunter Chopper spotlight color - green (0-255)")
    local cvar_spotlight_b = BL.CreateClientConVar("betterlights_hunter_chopper_spotlight_color_b", "255", true, false, "Hunter Chopper spotlight color - blue (0-255)")

    local chopperProjectors = {}

    BL.TrackClass(CHOPPER_CLASS)

    local function readFlashSettings(rCvar, gCvar, bCvar, sizeCvar, brightnessCvar, timeCvar)
        local duration = math.max(0, timeCvar:GetFloat())
        if duration <= 0 then return nil end

        local r, g, b = BL.GetColorFromCvars(rCvar, gCvar, bCvar)
        return r, g, b, math.max(0, sizeCvar:GetFloat()), math.max(0, brightnessCvar:GetFloat()), duration
    end

    BL.AddNetworkHandler(BL.NET_HUNTER_CHOPPER_BULLET_IMPACT, function()
        if not cvar_impact_enable:GetBool() then return end

        local pos = net.ReadVector()
        local r, g, b, size, brightness, duration = readFlashSettings(cvar_impact_r, cvar_impact_g, cvar_impact_b, cvar_impact_size, cvar_impact_brightness, cvar_impact_time)
        if not duration then return end

        BL.CreateFlash(pos, r, g, b, size, brightness, duration, 59800)
    end)

    if not ProjectedTexture then return end

    local function getSpotlightAttachment(ent)
        local attachId = BL.LookupAttachmentCached(ent, SPOTLIGHT_ATTACHMENT)
        if not attachId or attachId == 0 then return nil end
        return ent:GetAttachment(attachId)
    end
    BL.AddThink("BetterLights_HunterChopperSpotlight", function()
        local spotlightEnabled = cvar_spotlight_enable:GetBool()
        local seen = {}

        local function updateChopper(ent)
            if not IsValid(ent) then return end

            if not spotlightEnabled then return end

            local attachment = getSpotlightAttachment(ent)
            if not (attachment and attachment.Pos and attachment.Ang) then return end

            local lamp = BL.GetOrCreateProjectedTexture(chopperProjectors, ent, "effects/flashlight001")
            if not lamp then return end

            local r, g, b = BL.GetColorFromCvars(cvar_spotlight_r, cvar_spotlight_g, cvar_spotlight_b)
            if BL.UpdateProjectedTexture(lamp, {
                pos = attachment.Pos,
                ang = attachment.Ang,
                nearZ = math.max(0.1, cvar_spotlight_near:GetFloat()),
                farZ = math.max(1, cvar_spotlight_distance:GetFloat()),
                fov = math.Clamp(cvar_spotlight_fov:GetFloat(), 1, 175),
                brightness = math.max(0, cvar_spotlight_brightness:GetFloat()),
                color = Color(r, g, b),
                shadows = cvar_spotlight_shadows:GetBool()
            }) then
                seen[ent] = true
            end
        end

        BL.ForEach(CHOPPER_CLASS, updateChopper)

        BL.RemoveStaleProjectedTextures(chopperProjectors, seen, function(ent)
            return (not spotlightEnabled) or (not IsValid(ent))
        end)
    end)
end
