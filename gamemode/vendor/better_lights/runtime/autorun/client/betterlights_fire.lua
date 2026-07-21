if CLIENT then
    local BL = BetterLights
    local CurTime = CurTime
    local IsValid = IsValid
    local FIRE_LIGHT_ID_OFFSET = 70000
    -- Note: DynamicLight is NOT localized to ensure compatibility with wrappers like GShader Library
    local cvar_enable = BL.CreateClientConVar("betterlights_fire_enable", "1", true, false, "Enable dynamic light for entities that are on fire")
    local cvar_size = BL.CreateClientConVar("betterlights_fire_size", "160", true, false, "Dynamic light radius for burning entities")
    local cvar_brightness = BL.CreateClientConVar("betterlights_fire_brightness", "5.2", true, false, "Dynamic light brightness for burning entities")
    local cvar_decay = BL.CreateClientConVar("betterlights_fire_decay", "2000", true, false, "Dynamic light decay for burning entities")
    local cvar_models_elight = BL.CreateClientConVar("betterlights_fire_models_elight", "1", true, false, "Also add an entity light (elight) to light models directly")
    local cvar_models_elight_size_mult = BL.CreateClientConVar("betterlights_fire_models_elight_size_mult", "1.0", true, false, "Multiplier for elight radius on burning entities")
    local cvar_flicker_enable = BL.CreateClientConVar("betterlights_fire_flicker_enable", "1", true, false, "Enable flicker effect for burning entity lights")
    local cvar_flicker_amount = BL.CreateClientConVar("betterlights_fire_flicker_amount", "0.35", true, false, "Flicker intensity (as a fraction of brightness)")
    local cvar_flicker_size_amount = BL.CreateClientConVar("betterlights_fire_flicker_size_amount", "0.12", true, false, "Flicker intensity applied to light radius")
    local cvar_flicker_speed = BL.CreateClientConVar("betterlights_fire_flicker_speed", "11.5", true, false, "Flicker speed (higher = faster flicker)")

    local cvar_col_r = BL.CreateClientConVar("betterlights_fire_color_r", "255", true, false, "Burning entities color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_fire_color_g", "170", true, false, "Burning entities color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_fire_color_b", "60", true, false, "Burning entities color - blue (0-255)")

    BL.TrackClass("entityflame")
    BL.AddThink("BetterLights_Fire_DLight", function()
        if not cvar_enable:GetBool() then return end


        local size = math.max(0, cvar_size:GetFloat())
        local brightness = math.max(0, cvar_brightness:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())
        local doElight = cvar_models_elight:GetBool()
        local elMult = math.max(0, cvar_models_elight_size_mult:GetFloat())
        local doFlicker = cvar_flicker_enable:GetBool()
        local flickerSpeed = cvar_flicker_speed:GetFloat()
        local flickerAmt = math.max(0, cvar_flicker_amount:GetFloat())
        local flickerSizeAmt = math.max(0, cvar_flicker_size_amount:GetFloat())

        local seenTargets = {}

        local cr, cg, cb = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)

        local function handleFlame(flame)
            if IsValid(flame) then
                local target = flame:GetParent()
                if not IsValid(target) then
                    target = flame:GetOwner()
                end

                local pos
                local lightIndex
                if IsValid(target) then
                    local obbCenter = target.OBBCenter and target:OBBCenter() or Vector(0, 0, 0)
                    pos = target.LocalToWorld and target:LocalToWorld(obbCenter) or (target.WorldSpaceCenter and target:WorldSpaceCenter()) or target:GetPos()
                    lightIndex = target:EntIndex()
                    if seenTargets[lightIndex] then return end
                    seenTargets[lightIndex] = true
                else
                    pos = flame:GetPos()
                    lightIndex = flame:EntIndex()
                end

                local b_eff, s_eff = brightness, size
                if doFlicker then
                    local t = CurTime()
                    local phase = (flame:EntIndex() % 17) * 0.37
                    b_eff = BL.CreateFlickerEffect(brightness, t, flickerSpeed, flickerAmt, phase)
                    s_eff = BL.CreateFlickerEffect(size, t, flickerSpeed, flickerSizeAmt, phase)
                end

                local lightId = FIRE_LIGHT_ID_OFFSET + lightIndex
                BL.CreateDLight(lightId, pos, cr, cg, cb, b_eff, decay, s_eff, false, { dietime = 0.16 })

                if doElight then
                    BL.CreateDLight(lightId, pos, cr, cg, cb, b_eff, decay, s_eff * elMult, true, { dietime = 0.16 })
                end
            end
        end

        BL.ForEach("entityflame", handleFlame)
    end)
end
