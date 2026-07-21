if CLIENT then
    local BL = BetterLights
    local IsValid = IsValid
    local timer_Simple = timer.Simple

    local cvar_enable = BL.CreateClientConVar("betterlights_antlion_spit_enable", "1", true, false, "Enable dynamic light for Antlion spit projectiles (grenade_spit)")
    local cvar_size = BL.CreateClientConVar("betterlights_antlion_spit_size", "100", true, false, "Dynamic light radius for Antlion spit")
    local cvar_brightness = BL.CreateClientConVar("betterlights_antlion_spit_brightness", "1.0", true, false, "Dynamic light brightness for Antlion spit")
    local cvar_decay = BL.CreateClientConVar("betterlights_antlion_spit_decay", "1800", true, false, "Dynamic light decay for Antlion spit")

    local cvar_flash_enable = BL.CreateClientConVar("betterlights_antlion_spit_flash_enable", "1", true, false, "Add a brief light flash when Antlion spit impacts")
    local cvar_flash_size = BL.CreateClientConVar("betterlights_antlion_spit_flash_size", "160", true, false, "Impact flash radius for Antlion spit")
    local cvar_flash_brightness = BL.CreateClientConVar("betterlights_antlion_spit_flash_brightness", "1.5", true, false, "Impact flash brightness for Antlion spit")
    local cvar_flash_time = BL.CreateClientConVar("betterlights_antlion_spit_flash_time", "1.0", true, false, "Duration of the impact flash (seconds)")

    local cvar_col_r = BL.CreateClientConVar("betterlights_antlion_spit_color_r", "120", true, false, "Antlion spit glow color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_antlion_spit_color_g", "255", true, false, "Antlion spit glow color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_antlion_spit_color_b", "140", true, false, "Antlion spit glow color - blue (0-255)")
    local cvar_flash_r = BL.CreateClientConVar("betterlights_antlion_spit_flash_color_r", "180", true, false, "Antlion spit flash color - red (0-255)")
    local cvar_flash_g = BL.CreateClientConVar("betterlights_antlion_spit_flash_color_g", "255", true, false, "Antlion spit flash color - green (0-255)")
    local cvar_flash_b = BL.CreateClientConVar("betterlights_antlion_spit_flash_color_b", "120", true, false, "Antlion spit flash color - blue (0-255)")

    local TARGET_CLASS = "grenade_spit"

    local BL_Spit_Tracked = BL_Spit_Tracked or {}
    local BL_Spit_LastPos = BL_Spit_LastPos or {}

    BL.TrackClass(TARGET_CLASS)
    hook.Add("OnEntityCreated", "BetterLights_AntlionSpit_TrackSpawn", function(ent)
        timer_Simple(0, function()
            if not IsValid(ent) then return end
            local cls = (ent.GetClass and ent:GetClass()) or ""
            if cls == TARGET_CLASS then
                BL_Spit_Tracked[ent] = CurTime()
                BL_Spit_LastPos[ent] = BL.GetEntityCenter(ent)
            end
        end)
    end)

    timer_Simple(0, function()
        local now = CurTime()
        BL.ForEach(TARGET_CLASS, function(ent)
            BL_Spit_Tracked[ent] = now
            BL_Spit_LastPos[ent] = BL.GetEntityCenter(ent)
        end)
    end)

    hook.Add("EntityRemoved", "BetterLights_AntlionSpit_OnRemove", function(ent, fullUpdate)
        if fullUpdate then return end
        local spawnTime = BL_Spit_Tracked[ent]
        if spawnTime ~= nil then
            local pos = BL_Spit_LastPos[ent]
            BL_Spit_Tracked[ent] = nil
            BL_Spit_LastPos[ent] = nil
            if not cvar_flash_enable:GetBool() then return end
            local now = CurTime()
            local lived = now - spawnTime
            if lived < 0.05 then return end

            pos = pos or BL.GetEntityCenter(ent)
            if not pos then return end

            local dur = math.max(0, cvar_flash_time:GetFloat())
            if dur <= 0 then return end

            local fr, fg, fb = BL.GetColorFromCvars(cvar_flash_r, cvar_flash_g, cvar_flash_b)
            local flashSize = math.max(0, cvar_flash_size:GetFloat())
            local flashBrightness = math.max(0, cvar_flash_brightness:GetFloat())
            BL.CreateFlash(pos, fr, fg, fb, flashSize, flashBrightness, dur, 59200)
        end
    end)
    BL.AddThink("BetterLights_AntlionSpit", function()
        local doGlow = cvar_enable:GetBool()
        local size
        local brightness
        local decay
        local gr
        local gg
        local gb

        if doGlow then
            size = math.max(0, cvar_size:GetFloat())
            brightness = math.max(0, cvar_brightness:GetFloat())
            decay = math.max(0, cvar_decay:GetFloat())
            gr, gg, gb = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)

            BL.ForEach(TARGET_CLASS, function(ent)
                if not IsValid(ent) then return end
                if BL_Spit_Tracked[ent] == nil then BL_Spit_Tracked[ent] = CurTime() end

                local pos = BL.GetEntityCenter(ent)
                if not pos then return end

                BL_Spit_LastPos[ent] = pos
                BL.CreateDLight(ent:EntIndex(), pos, gr, gg, gb, brightness, decay, size, false)
            end)
        else
            BL.ForEach(TARGET_CLASS, function(ent)
                if not IsValid(ent) then return end
                if BL_Spit_Tracked[ent] == nil then BL_Spit_Tracked[ent] = CurTime() end

                BL_Spit_LastPos[ent] = BL.GetEntityCenter(ent) or BL_Spit_LastPos[ent]
            end)
        end

        for ent, _ in pairs(BL_Spit_Tracked) do
            if not IsValid(ent) then
                BL_Spit_Tracked[ent] = nil
                BL_Spit_LastPos[ent] = nil
            end
        end
    end)
end
