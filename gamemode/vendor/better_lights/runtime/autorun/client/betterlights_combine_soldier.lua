if CLIENT then
    local BL = BetterLights

    local colorCvars = {
        elite = BL.CreateConVarSet("bl_combine_soldier_elite", {
            enable = 1,
            size = 40,
            brightness = 0.5,
            decay = 1500,
            r = 255,
            g = 72,
            b = 72
        }),
        prisonYellow = BL.CreateConVarSet("bl_combine_soldier_prisonguard_yellow", {
            enable = 1,
            size = 40,
            brightness = 0.5,
            decay = 1500,
            r = 255,
            g = 220,
            b = 70
        }),
        prisonRed = BL.CreateConVarSet("bl_combine_soldier_prisonguard_red", {
            enable = 1,
            size = 40,
            brightness = 0.5,
            decay = 1500,
            r = 255,
            g = 72,
            b = 72
        }),
        standardBlue = BL.CreateConVarSet("bl_combine_soldier_standard_blue", {
            enable = 1,
            size = 40,
            brightness = 0.5,
            decay = 1500,
            r = 95,
            g = 150,
            b = 255
        }),
        standardOrange = BL.CreateConVarSet("bl_combine_soldier_standard_orange", {
            enable = 1,
            size = 40,
            brightness = 0.5,
            decay = 1500,
            r = 255,
            g = 155,
            b = 48
        })
    }

    BL.TrackClass("npc_combine_s")

    local modelVariants = {
        ["models/combine_super_soldier.mdl"] = {
            default = "elite"
        },
        ["models/combine_soldier_prisonguard.mdl"] = {
            skinMap = {[0] = "prisonYellow", [1] = "prisonRed"},
            default = "prisonYellow"
        },
        ["models/combine_soldier.mdl"] = {
            skinMap = {[0] = "standardBlue", [1] = "standardOrange"},
            default = "standardBlue"
        }
    }

    local function getColorKey(ent)
        if not (IsValid(ent) and ent.GetModel) then return nil end

        local model = ent:GetModel()
        local variant = model and modelVariants[model]
        if not variant then return nil end

        if variant.skinMap then
            local skin = (ent.GetSkin and ent:GetSkin()) or 0
            return variant.skinMap[skin] or variant.default
        end

        return variant.default
    end

    local function getSettings(colorKey)
        local selected = colorCvars[colorKey] or colorCvars.standardBlue
        return selected,
            math.max(0, selected.size:GetFloat()),
            math.max(0, selected.brightness:GetFloat()),
            math.max(0, selected.decay:GetFloat()),
            BL.GetColorFromCvars(selected.r, selected.g, selected.b)
    end

    BL.AddThink("BetterLights_CombineSoldier", function()
        BL.ForEach("npc_combine_s", function(ent)
            local colorKey = getColorKey(ent)
            if not colorKey then return end

            local settings, size, brightness, decay, red, green, blue = getSettings(colorKey)
            if not settings.enable:GetBool() then return end

            BL.CreateLightFromAttachment(ent, {"eyes"},
                red, green, blue, brightness, decay, size, false)
        end)
    end)
end
