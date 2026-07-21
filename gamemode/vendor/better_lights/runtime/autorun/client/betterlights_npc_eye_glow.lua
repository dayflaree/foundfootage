if CLIENT then
    local BL = BetterLights
    local IsValid = IsValid

    local EYE_ATTACHMENT = { "eyes" }

    local dogEyes = BL.CreateConVarSet("betterlights_dog_eye", {
        enable = 1,
        size = 70,
        brightness = 0.4,
        decay = 1500,
        r = 255,
        g = 60,
        b = 60
    })

    local function createEyeLight(ent, settings, lightOffset)
        if not IsValid(ent) then return end
        if ent.GetNoDraw and ent:GetNoDraw() then return end
        if not settings.enable:GetBool() then return end

        local pos = BL.GetAttachmentPos(ent, EYE_ATTACHMENT)
        if not pos then return end

        local r, g, b = BL.GetColorFromCvars(settings.r, settings.g, settings.b)
        BL.CreateDLight(
            ent:EntIndex() + lightOffset,
            pos,
            r,
            g,
            b,
            math.max(0, settings.brightness:GetFloat()),
            math.max(0, settings.decay:GetFloat()),
            math.max(0, settings.size:GetFloat()),
            false
        )
    end

    BL.TrackClass("npc_dog")

    BL.AddThink("BetterLights_NPCEyeGlow", function()
        BL.ForEach("npc_dog", function(ent)
            createEyeLight(ent, dogEyes, 24300)
        end)
    end)
end
