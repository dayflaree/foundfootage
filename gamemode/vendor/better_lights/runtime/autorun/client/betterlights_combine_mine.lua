if CLIENT then
    local BL = BetterLights

    local cvar_enable = BL.CreateClientConVar("betterlights_combine_mine_enable", "1", true, false, "Enable dynamic light for Combine Mines when the player is nearby")
    local cvar_range = BL.CreateClientConVar("betterlights_combine_mine_range", "260", true, false, "Distance at which the mine starts glowing (units)")
    local cvar_size_alert = BL.CreateClientConVar("betterlights_combine_mine_size", "140", true, false, "Dynamic light radius for alert mines")
    local cvar_brightness_alert = BL.CreateClientConVar("betterlights_combine_mine_brightness", "1.2", true, false, "Dynamic light brightness for alert mines")
    local cvar_decay = BL.CreateClientConVar("betterlights_combine_mine_decay", "2000", true, false, "Dynamic light decay for Combine Mines")

    local cvar_res_enable = BL.CreateClientConVar("betterlights_combine_mine_resistance_enable", "1", true, false, "Enable dynamic light for Resistance Mines")
    local cvar_res_size = BL.CreateClientConVar("betterlights_combine_mine_resistance_size", "140", true, false, "Dynamic light radius for Resistance Mines")
    local cvar_res_brightness = BL.CreateClientConVar("betterlights_combine_mine_resistance_brightness", "1.0", true, false, "Dynamic light brightness for Resistance Mines")
    local cvar_res_decay = BL.CreateClientConVar("betterlights_combine_mine_resistance_decay", "2000", true, false, "Dynamic light decay for Resistance Mines")

    local cvar_idle_enable = BL.CreateClientConVar("betterlights_combine_mine_idle_enable", "1", true, false, "Also emit a very dim idle glow when out of range")
    local cvar_size_idle = BL.CreateClientConVar("betterlights_combine_mine_idle_size", "80", true, false, "Dynamic light radius for idle mines")
    local cvar_brightness_idle = BL.CreateClientConVar("betterlights_combine_mine_idle_brightness", "0.25", true, false, "Dynamic light brightness for idle mines")

    local cvar_models_elight = BL.CreateClientConVar("betterlights_combine_mine_models_elight", "1", true, false, "Also add an entity light (elight) to light the mine model directly")
    local cvar_models_elight_size_mult = BL.CreateClientConVar("betterlights_combine_mine_models_elight_size_mult", "1.0", true, false, "Multiplier for mine elight radius")

    local cvar_pulse_enable = BL.CreateClientConVar("betterlights_combine_mine_pulse_enable", "1", true, false, "Enable a subtle pulse on alert mines")
    local cvar_pulse_amount = BL.CreateClientConVar("betterlights_combine_mine_pulse_amount", "0.15", true, false, "Pulse intensity as a fraction of brightness")
    local cvar_pulse_speed = BL.CreateClientConVar("betterlights_combine_mine_pulse_speed", "6.0", true, false, "Pulse speed for alert mines")

    local cvar_idle_r = BL.CreateClientConVar("betterlights_combine_mine_idle_color_r", "90", true, false, "Combine mine idle color - red (0-255)")
    local cvar_idle_g = BL.CreateClientConVar("betterlights_combine_mine_idle_color_g", "180", true, false, "Combine mine idle color - green (0-255)")
    local cvar_idle_b = BL.CreateClientConVar("betterlights_combine_mine_idle_color_b", "255", true, false, "Combine mine idle color - blue (0-255)")
    local cvar_alert_r = BL.CreateClientConVar("betterlights_combine_mine_alert_color_r", "255", true, false, "Combine mine alert color - red (0-255)")
    local cvar_alert_g = BL.CreateClientConVar("betterlights_combine_mine_alert_color_g", "60", true, false, "Combine mine alert color - green (0-255)")
    local cvar_alert_b = BL.CreateClientConVar("betterlights_combine_mine_alert_color_b", "60", true, false, "Combine mine alert color - blue (0-255)")

    local cvar_res_r = BL.CreateClientConVar("betterlights_combine_mine_resistance_color_r", "60", true, false, "Resistance mine color - red (0-255)")
    local cvar_res_g = BL.CreateClientConVar("betterlights_combine_mine_resistance_color_g", "255", true, false, "Resistance mine color - green (0-255)")
    local cvar_res_b = BL.CreateClientConVar("betterlights_combine_mine_resistance_color_b", "100", true, false, "Resistance mine color - blue (0-255)")

    local cvar_debug = BL.CreateClientConVar("betterlights_combine_mine_debug", "0", true, false, "Debug mine type detection (prints to console)")

    local function isFriendlyMine(ent)
        return BL.DetectEntityVariant(ent, {
            debugName = "friendly mine",
            debugCvar = cvar_debug,
            classes = { "combine_mine_resistance" },
            nwBools = { "friendly", "resistance", "is_friendly", "IsFriendly", "is_resistance", "rebel" },
            saveTableKeys = { "m_bFriendly", "friendly", "resistance", "m_bResistance", "is_friendly" },
            checkDisposition = true,
            skin = function(s) return s == 1 or s == 2 end  -- Resistance mines use skin 1 or 2
        })
    end

    BL.TrackClass("combine_mine")
    BL.TrackClass("combine_mine_resistance")
    BL.AddThink("BetterLights_CombineMine_DLight", function()
        if not cvar_enable:GetBool() and not cvar_res_enable:GetBool() then return end

        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local eye = lp:EyePos()

        local range = math.max(0, cvar_range:GetFloat())
        local decay = math.max(0, cvar_decay:GetFloat())
        local size_alert = math.max(0, cvar_size_alert:GetFloat())
        local size_idle = math.max(0, cvar_size_idle:GetFloat())
        local brightness_alert = math.max(0, cvar_brightness_alert:GetFloat())
        local brightness_idle = math.max(0, cvar_brightness_idle:GetFloat())
        local idle_r, idle_g, idle_b = BL.GetColorFromCvars(cvar_idle_r, cvar_idle_g, cvar_idle_b)
        local alert_r, alert_g, alert_b = BL.GetColorFromCvars(cvar_alert_r, cvar_alert_g, cvar_alert_b)
        local doPulse = cvar_pulse_enable:GetBool()
        local pulseAmt = math.max(0, cvar_pulse_amount:GetFloat())
        local pulseSpd = cvar_pulse_speed:GetFloat()
        local doElight = cvar_models_elight:GetBool()
        local elMult = math.max(0, cvar_models_elight_size_mult:GetFloat())
        local now = CurTime()

        local res_size = math.max(0, cvar_res_size:GetFloat())
        local res_brightness = math.max(0, cvar_res_brightness:GetFloat())
        local res_decay = math.max(0, cvar_res_decay:GetFloat())
        local res_r, res_g, res_b = BL.GetColorFromCvars(cvar_res_r, cvar_res_g, cvar_res_b)

        local function updateMine(mine)
            if not IsValid(mine) then return end

            local isFriendly = isFriendlyMine(mine)

            if isFriendly and not cvar_res_enable:GetBool() then return end
            if not isFriendly and not cvar_enable:GetBool() then return end

            local pos = BL.GetEntityCenter(mine)
            if not pos then return end

            local r, g, b, size, brightness, useDecay

            local dist = eye:DistToSqr(pos)
            local inRange = dist <= (range * range)
            if not inRange and not cvar_idle_enable:GetBool() then return end

            if isFriendly then
                size = inRange and res_size or size_idle
                brightness = inRange and res_brightness or brightness_idle
                r, g, b = inRange and res_r or idle_r, inRange and res_g or idle_g, inRange and res_b or idle_b
                useDecay = res_decay
            else
                size = inRange and size_alert or size_idle
                brightness = inRange and brightness_alert or brightness_idle
                r, g, b = inRange and alert_r or idle_r, inRange and alert_g or idle_g, inRange and alert_b or idle_b
                useDecay = decay

                if inRange and doPulse then
                    local osc = 0.5 + 0.5 * math.sin(now * pulseSpd + mine:EntIndex())
                    brightness = math.max(0, brightness * (1 - pulseAmt + pulseAmt * (0.6 + 0.4 * osc)))
                end
            end

            BL.CreateDLight(mine:EntIndex(), pos, r, g, b, brightness, useDecay, size, false)

            if doElight then
                BL.CreateDLight(mine:EntIndex(), pos, r, g, b, brightness, useDecay, size * elMult, true)
            end
        end

        BL.ForEach("combine_mine", updateMine)
        BL.ForEach("combine_mine_resistance", updateMine)
    end)
end
