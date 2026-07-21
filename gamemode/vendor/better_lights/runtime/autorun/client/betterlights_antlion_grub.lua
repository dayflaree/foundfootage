if CLIENT then
    local BL = BetterLights
    local IsValid = IsValid
    local cvar_enable = BL.CreateClientConVar("betterlights_antlion_grub_enable", "1", true, false, "Enable green glow on Antlion Grubs")
    local cvar_size = BL.CreateClientConVar("betterlights_antlion_grub_size", "70", true, false, "Grub light radius")
    local cvar_brightness = BL.CreateClientConVar("betterlights_antlion_grub_brightness", "0.35", true, false, "Grub light brightness")
    local cvar_decay = BL.CreateClientConVar("betterlights_antlion_grub_decay", "2000", true, false, "Grub light decay")
    local cvar_squashed_enable = BL.CreateClientConVar("betterlights_antlion_grub_squashed_enable", "1", true, false, "Enable dim glow on squashed Antlion Grubs")
    local cvar_squashed_size = BL.CreateClientConVar("betterlights_antlion_grub_squashed_size", "42", true, false, "Squashed grub light radius")
    local cvar_squashed_brightness = BL.CreateClientConVar("betterlights_antlion_grub_squashed_brightness", "0.08", true, false, "Squashed grub light brightness")
    local cvar_squashed_decay = BL.CreateClientConVar("betterlights_antlion_grub_squashed_decay", "2000", true, false, "Squashed grub light decay")

    local cvar_col_r = BL.CreateClientConVar("betterlights_antlion_grub_color_r", "120", true, false, "Antlion grub color - red (0-255)")
    local cvar_col_g = BL.CreateClientConVar("betterlights_antlion_grub_color_g", "255", true, false, "Antlion grub color - green (0-255)")
    local cvar_col_b = BL.CreateClientConVar("betterlights_antlion_grub_color_b", "120", true, false, "Antlion grub color - blue (0-255)")

    local ATTACH_NAMES = { "glow" }
    local SQUASHED_MODEL = "models/antlion_grub_squashed.mdl"
    local SQUASHED_LIGHT_BASE = 23400
    local squashedGrubs = {}
    local squashedLightIds = {}
    local squashedLightCounter = 0

    BL.TrackClass("npc_antlion_grub")

    local function isSquashedGrub(ent)
        if not (IsValid(ent) and ent.GetModel) then return false end
        return string.lower(ent:GetModel() or "") == SQUASHED_MODEL
    end

    local function trackSquashedGrub(ent)
        if isSquashedGrub(ent) then
            squashedGrubs[ent] = true
        end
    end

    local function getSquashedLightId(ent)
        local id = squashedLightIds[ent]
        if id then return id end

        squashedLightCounter = (squashedLightCounter + 1) % 1000
        id = SQUASHED_LIGHT_BASE + squashedLightCounter
        squashedLightIds[ent] = id
        return id
    end

    hook.Add("OnEntityCreated", "BetterLights_AntlionGrub_SquashedTrack", function(ent)
        timer.Simple(0, function()
            trackSquashedGrub(ent)
        end)
    end)

    hook.Add("EntityRemoved", "BetterLights_AntlionGrub_SquashedRemove", function(ent, fullUpdate)
        if fullUpdate then return end

        squashedGrubs[ent] = nil
        squashedLightIds[ent] = nil
    end)

    timer.Simple(0, function()
        for _, ent in ipairs(ents.GetAll()) do
            trackSquashedGrub(ent)
        end
    end)
    BL.AddThink("BetterLights_AntlionGrub", function()
        local r, g, b = BL.GetColorFromCvars(cvar_col_r, cvar_col_g, cvar_col_b)

        local function updateGrub(ent)
            if not IsValid(ent) then return end
            if ent.GetNoDraw and ent:GetNoDraw() then return end
            if isSquashedGrub(ent) then
                squashedGrubs[ent] = true
                return
            end
            if not cvar_enable:GetBool() then return end

            local size = math.max(0, cvar_size:GetFloat())
            local brightness = math.max(0, cvar_brightness:GetFloat())
            local decay = math.max(0, cvar_decay:GetFloat())
            BL.CreateLightFromAttachment(ent, ATTACH_NAMES, r, g, b, brightness, decay, size, false)
        end

        BL.ForEach("npc_antlion_grub", updateGrub)

        if not cvar_squashed_enable:GetBool() then return end

        local size = math.max(0, cvar_squashed_size:GetFloat())
        local brightness = math.max(0, cvar_squashed_brightness:GetFloat())
        local decay = math.max(0, cvar_squashed_decay:GetFloat())

        for ent, _ in pairs(squashedGrubs) do
            if not isSquashedGrub(ent) then
                squashedGrubs[ent] = nil
                squashedLightIds[ent] = nil
            elseif not (ent.GetNoDraw and ent:GetNoDraw()) then
                local pos = BL.GetEntityCenter(ent)
                if pos then
                    BL.CreateDLight(getSquashedLightId(ent), pos, r, g, b, brightness, decay, size, false)
                end
            end
        end
    end)
end
