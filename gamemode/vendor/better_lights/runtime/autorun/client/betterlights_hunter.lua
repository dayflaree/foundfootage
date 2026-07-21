if CLIENT then
    local BL = BetterLights
    local EXP = BL.Explosions
    local MF = BL.MuzzleFlash

    local HUNTER_CLASS = "npc_hunter"
    local FLECHETTE_CLASS = "hunter_flechette"
    local EYE_ATTACHMENTS = { "top_eye", "bottom_eye" }
    local MUZZLE_ATTACHMENT = { "MiniGunBase" }
    local MUZZLE_SEARCH_DIST_SQR = 360 * 360

    local cvar_hunter_enable = BL.CreateClientConVar("betterlights_hunter_enable", "1", true, false, "Enable blue light on Hunters")
    local cvar_hunter_size = BL.CreateClientConVar("betterlights_hunter_size", "55", true, false, "Hunter light radius")
    local cvar_hunter_brightness = BL.CreateClientConVar("betterlights_hunter_brightness", "0.45", true, false, "Hunter light brightness")
    local cvar_hunter_decay = BL.CreateClientConVar("betterlights_hunter_decay", "2000", true, false, "Hunter light decay")
    local cvar_hunter_models_elight = BL.CreateClientConVar("betterlights_hunter_models_elight", "1", true, false, "Also add an entity light (elight) to light the Hunter model directly")
    local cvar_hunter_models_elight_size_mult = BL.CreateClientConVar("betterlights_hunter_models_elight_size_mult", "1.0", true, false, "Multiplier for Hunter elight radius")

    local cvar_projectile_enable = BL.CreateClientConVar("betterlights_hunter_flechette_enable", "1", true, false, "Enable blue light on Hunter flechettes")
    local cvar_projectile_size = BL.CreateClientConVar("betterlights_hunter_flechette_size", "90", true, false, "Hunter flechette light radius")
    local cvar_projectile_brightness = BL.CreateClientConVar("betterlights_hunter_flechette_brightness", "1.25", true, false, "Hunter flechette light brightness")
    local cvar_projectile_decay = BL.CreateClientConVar("betterlights_hunter_flechette_decay", "1800", true, false, "Hunter flechette light decay")

    BL.CreateClientConVar("betterlights_hunter_muzzle_flash_enable", "1", true, false, "Add blue light when Hunters fire flechettes")
    BL.CreateClientConVar("betterlights_hunter_muzzle_flash_size", "220", true, false, "Hunter muzzle flash radius")
    BL.CreateClientConVar("betterlights_hunter_muzzle_flash_brightness", "2.0", true, false, "Hunter muzzle flash brightness")
    BL.CreateClientConVar("betterlights_hunter_muzzle_flash_time", "0.08", true, false, "Hunter muzzle flash duration")

    local cvar_blast_enable = BL.CreateClientConVar("betterlights_hunter_flechette_blast_enable", "1", true, false, "Add blue light when Hunter flechettes explode")
    local cvar_blast_size = BL.CreateClientConVar("betterlights_hunter_flechette_blast_size", "260", true, false, "Hunter flechette blast radius")
    local cvar_blast_brightness = BL.CreateClientConVar("betterlights_hunter_flechette_blast_brightness", "2.4", true, false, "Hunter flechette blast brightness")
    local cvar_blast_time = BL.CreateClientConVar("betterlights_hunter_flechette_blast_time", "0.35", true, false, "Hunter flechette blast duration")

    local cvar_col_r = BL.CreateClientConVar("betterlights_hunter_color_r", "30", true, false, "Hunter light color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_hunter_color_g", "230", true, false, "Hunter light color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_hunter_color_b", "255", true, false, "Hunter light color - blue (0-255)")
    local cvar_projectile_r = BL.CreateClientConVar("betterlights_hunter_flechette_color_r", "0", true, false, "Hunter flechette color - red (0-255)")
    local cvar_projectile_g = BL.CreateClientConVar("betterlights_hunter_flechette_color_g", "235", true, false, "Hunter flechette color - green (0-255)")
    local cvar_projectile_b = BL.CreateClientConVar("betterlights_hunter_flechette_color_b", "255", true, false, "Hunter flechette color - blue (0-255)")
    BL.CreateClientConVar("betterlights_hunter_muzzle_flash_color_r", "70", true, false, "Hunter muzzle flash color - red (0-255)")
    BL.CreateClientConVar("betterlights_hunter_muzzle_flash_color_g", "220", true, false, "Hunter muzzle flash color - green (0-255)")
    BL.CreateClientConVar("betterlights_hunter_muzzle_flash_color_b", "255", true, false, "Hunter muzzle flash color - blue (0-255)")
    local cvar_blast_r = BL.CreateClientConVar("betterlights_hunter_flechette_blast_color_r", "80", true, false, "Hunter flechette blast color - red (0-255)")
    local cvar_blast_g = BL.CreateClientConVar("betterlights_hunter_flechette_blast_color_g", "230", true, false, "Hunter flechette blast color - green (0-255)")
    local cvar_blast_b = BL.CreateClientConVar("betterlights_hunter_flechette_blast_color_b", "255", true, false, "Hunter flechette blast color - blue (0-255)")

    BL.TrackClass(HUNTER_CLASS)
    BL.TrackClass(FLECHETTE_CLASS)

    EXP.RegisterClientProfile("hunter_flechette", {
        enableCvar = cvar_blast_enable,
        sizeCvar = cvar_blast_size,
        brightnessCvar = cvar_blast_brightness,
        durationCvar = cvar_blast_time,
        rCvar = cvar_blast_r,
        gCvar = cvar_blast_g,
        bCvar = cvar_blast_b,
        baseId = 59400,
        suppressionKey = "explosion"
    })

    local function getHunterMuzzlePos(projectilePos)
        local bestPos
        local bestHunter
        local bestDist = MUZZLE_SEARCH_DIST_SQR

        local function checkHunter(ent)
            if not IsValid(ent) then return end

            local muzzlePos = BL.GetAttachmentPos(ent, MUZZLE_ATTACHMENT)
            if not muzzlePos then return end

            local dist = muzzlePos:DistToSqr(projectilePos)
            if dist < bestDist then
                bestDist = dist
                bestPos = muzzlePos
                bestHunter = ent
            end
        end

        BL.ForEach(HUNTER_CLASS, checkHunter)

        return bestPos, bestHunter
    end

    hook.Add("OnEntityCreated", "BetterLights_HunterFlechette_Track", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            if ent:GetClass() ~= FLECHETTE_CLASS then return end

            local pos = BL.GetEntityCenter(ent)
            if not pos then return end

            local muzzlePos, hunter = getHunterMuzzlePos(pos)
            if not muzzlePos then return end

            MF.EmitProfileFlash("hunter", muzzlePos, {
                baseId = 59300,
                key = IsValid(hunter) and ("hunter:" .. tostring(hunter:EntIndex())) or nil,
                other = true
            })
        end)
    end)

    BL.AddThink("BetterLights_Hunter", function()
        if cvar_hunter_enable:GetBool() then
            local size = math.max(0, cvar_hunter_size:GetFloat())
            local brightness = math.max(0, cvar_hunter_brightness:GetFloat())
            local decay = math.max(0, cvar_hunter_decay:GetFloat())
            local doElight = cvar_hunter_models_elight:GetBool()
            local elMult = math.max(0, cvar_hunter_models_elight_size_mult:GetFloat())
            local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)

            local function createHunterEyeLight(idx, pos)
                BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size, false)

                if doElight then
                    BL.CreateDLight(idx, pos, r, g, b, brightness, decay, size * elMult, true)
                end
            end

            local function updateHunter(ent)
                if not IsValid(ent) then return end

                for i, attachmentName in ipairs(EYE_ATTACHMENTS) do
                    local pos = BL.GetAttachmentPos(ent, { attachmentName })
                    if pos then
                        createHunterEyeLight(ent:EntIndex() + 23300 + (i * 100), pos)
                    end
                end
            end

            BL.ForEach(HUNTER_CLASS, updateHunter)
        end

        local doProjectileGlow = cvar_projectile_enable:GetBool()
        local size
        local brightness
        local decay
        local r
        local g
        local b

        if doProjectileGlow then
            size = math.max(0, cvar_projectile_size:GetFloat())
            brightness = math.max(0, cvar_projectile_brightness:GetFloat())
            decay = math.max(0, cvar_projectile_decay:GetFloat())
            r, g, b = BL.GetColorFromCvars(cvar_projectile_r, cvar_projectile_g, cvar_projectile_b)
        end

        local function updateFlechette(ent)
            if not IsValid(ent) then return end
            local pos = BL.GetEntityCenter(ent)
            if not pos then return end

            if not doProjectileGlow then return end

            BL.CreateDLight(ent:EntIndex(), pos, r, g, b, brightness, decay, size, false)
        end

        BL.ForEach(FLECHETTE_CLASS, updateFlechette)
    end)
end
