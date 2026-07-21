if CLIENT then
    local BL = BetterLights

    local IsValid = IsValid

    local function createScannerSettings(prefix, label, glowColor)
        return {
            glow = {
                enable = BL.CreateClientConVar(prefix .. "_enable", "1", true, false, "Enable dynamic light for " .. label),
                size = BL.CreateClientConVar(prefix .. "_size", "120", true, false, "Dynamic light radius for " .. label),
                brightness = BL.CreateClientConVar(prefix .. "_brightness", "0.7", true, false, "Dynamic light brightness for " .. label),
                decay = BL.CreateClientConVar(prefix .. "_decay", "2000", true, false, "Dynamic light decay for " .. label),
                modelsElight = BL.CreateClientConVar(prefix .. "_models_elight", "1", true, false, "Also add an entity light (elight) to light the scanner model directly"),
                modelsElightSizeMult = BL.CreateClientConVar(prefix .. "_models_elight_size_mult", "1.0", true, false, "Multiplier for scanner elight radius"),
                r = BL.CreateClientConVar(prefix .. "_color_r", tostring(glowColor.r), true, false, label .. " glow color - red (0-255)"),
                g = BL.CreateClientConVar(prefix .. "_color_g", tostring(glowColor.g), true, false, label .. " glow color - green (0-255)"),
                b = BL.CreateClientConVar(prefix .. "_color_b", tostring(glowColor.b), true, false, label .. " glow color - blue (0-255)")
            },
            searchlight = {
                enable = BL.CreateClientConVar(prefix .. "_searchlight_enable", "1", true, false, "Add a directional, shadow-casting searchlight to " .. label),
                fov = BL.CreateClientConVar(prefix .. "_searchlight_fov", "38", true, false, label .. " searchlight FOV (degrees)"),
                far = BL.CreateClientConVar(prefix .. "_searchlight_distance", "900", true, false, label .. " searchlight distance (FarZ)"),
                near = BL.CreateClientConVar(prefix .. "_searchlight_near", "8", true, false, label .. " searchlight near plane (NearZ)"),
                brightness = BL.CreateClientConVar(prefix .. "_searchlight_brightness", "1.25", true, false, label .. " searchlight brightness (0-1+)"),
                shadows = BL.CreateClientConVar(prefix .. "_searchlight_shadows", "1", true, false, "Enable " .. label .. " searchlight shadows"),
                falloff = BL.CreateClientConVar(prefix .. "_searchlight_falloff", "25", true, false, label .. " searchlight falloff"),
                r = BL.CreateClientConVar(prefix .. "_searchlight_color_r", "255", true, false, label .. " searchlight color - red (0-255)"),
                g = BL.CreateClientConVar(prefix .. "_searchlight_color_g", "255", true, false, label .. " searchlight color - green (0-255)"),
                b = BL.CreateClientConVar(prefix .. "_searchlight_color_b", "255", true, false, label .. " searchlight color - blue (0-255)")
            }
        }
    end

    local cityScanner = createScannerSettings("betterlights_cscanner", "City Scanners", { r = 180, g = 230, b = 255 })
    local shieldScanner = createScannerSettings("betterlights_shieldscanner", "Shield Scanners", { r = 180, g = 230, b = 255 })

    local scannerProjectors = {}
    local SCANNER_ATTACHMENTS = {
        npc_cscanner = {
            glow = { "eyes" },
            searchlight = { "light" },
            searchlightAimAtLocalPlayer = true,
            searchlightNearZ = 1,
            settings = cityScanner
        },
        npc_clawscanner = {
            glow = { "eye" },
            searchlight = { "light" },
            searchlightAimAtLocalPlayer = true,
            searchlightNearZ = 1,
            settings = shieldScanner
        }
    }

    local function getScannerAttachments(ent)
        if not (IsValid(ent) and ent.GetClass) then return nil end
        return SCANNER_ATTACHMENTS[ent:GetClass()]
    end

    local function getPlayerAimAngle(pos)
        local ply = LocalPlayer()
        if not IsValid(ply) then return nil end

        local target = (ply.WorldSpaceCenter and ply:WorldSpaceCenter()) or (ply.EyePos and ply:EyePos()) or ply:GetPos()
        local direction = target - pos
        if direction:LengthSqr() <= 1 then return nil end

        return direction:Angle()
    end

    local function getFallbackSearchlightTransform(ent, attachments)
        local glow = BL.GetAttachmentTransform(ent, attachments.glow)
        if glow and glow.Pos then
            glow.Ang = glow.Ang or (ent.GetAngles and ent:GetAngles()) or Angle(0, 0, 0)
            return glow
        end

        local pos = BL.GetEntityCenter(ent)
        if not pos then return nil end

        return {
            Pos = pos,
            Ang = (ent.GetAngles and ent:GetAngles()) or Angle(0, 0, 0)
        }
    end

    local function getSearchlightTransform(ent, attachments)
        local light = BL.GetAttachmentTransform(ent, attachments.searchlight) or getFallbackSearchlightTransform(ent, attachments)
        if not (light and light.Pos and light.Ang) then return nil end

        local pos = light.Pos
        local ang

        if attachments.searchlightAimAtLocalPlayer then
            ang = getPlayerAimAngle(pos)
        end

        if not ang and ent.GetAimVector then
            local aim = ent:GetAimVector()
            if aim and aim ~= vector_origin then
                ang = aim:Angle()
            end
        end

        ang = ang or light.Ang

        return pos, ang, attachments.searchlightNearZ
    end

    BL.TrackClass("npc_cscanner")
    BL.TrackClass("npc_clawscanner")
    BL.AddThink("BetterLights_CScanner_DLight", function()
        local seen = {}

        local function processScanner(ent)
            if not IsValid(ent) then return end
            local attachments = getScannerAttachments(ent)
            local settings = attachments and attachments.settings
            if not settings then return end

            local idx = ent:EntIndex()
            local glow = BL.GetAttachmentTransform(ent, attachments.glow)
            local glowPos = glow and glow.Pos
            local glowSettings = settings.glow

            if glowSettings.enable:GetBool() and glowPos then
                local size = math.max(0, glowSettings.size:GetFloat())
                local brightness = math.max(0, glowSettings.brightness:GetFloat())
                local decay = math.max(0, glowSettings.decay:GetFloat())
                local r, g, b = BL.GetColorFromCvars(glowSettings.r, glowSettings.g, glowSettings.b)

                BL.CreateDLight(idx, glowPos, r, g, b, brightness, decay, size, false)

                if glowSettings.modelsElight:GetBool() then
                    local elMult = math.max(0, glowSettings.modelsElightSizeMult:GetFloat())
                    BL.CreateDLight(idx, glowPos, r, g, b, brightness, decay, size * elMult, true)
                end
            end

            local searchlight = settings.searchlight
            if searchlight.enable:GetBool() then
                local slNear = math.max(0.1, searchlight.near:GetFloat())
                local lightPos, lightAng, lightNear = getSearchlightTransform(ent, attachments)
                if not (lightPos and lightAng) then return end

                local lamp = BL.GetOrCreateProjectedTexture(scannerProjectors, ent, "effects/flashlight001")
                if not lamp then return end

                local slR, slG, slB = BL.GetColorFromCvars(searchlight.r, searchlight.g, searchlight.b)

                seen[ent] = true
                BL.UpdateProjectedTexture(lamp, {
                    pos = lightPos,
                    ang = lightAng,
                    nearZ = lightNear and math.min(slNear, lightNear) or slNear,
                    farZ = math.max(1, searchlight.far:GetFloat()),
                    fov = math.Clamp(searchlight.fov:GetFloat(), 1, 175),
                    brightness = math.max(0, searchlight.brightness:GetFloat()),
                    color = Color(slR, slG, slB),
                    shadows = searchlight.shadows:GetBool(),
                    noCull = true,
                    linearAttenuation = math.max(0, searchlight.falloff:GetFloat())
                })
            end
        end

        BL.ForEach("npc_cscanner", processScanner)
        BL.ForEach("npc_clawscanner", processScanner)

        BL.RemoveStaleProjectedTextures(scannerProjectors, seen, function(ent)
            if not IsValid(ent) then return true end

            local attachments = getScannerAttachments(ent)
            local settings = attachments and attachments.settings
            return not (settings and settings.searchlight.enable:GetBool())
        end)
    end)
end
