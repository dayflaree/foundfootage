if CLIENT then
    local BL = BetterLights

    local cvar_enable = BL.CreateClientConVar("betterlights_debug_light_origins_enable", "0", true, false, "Draw wireframe spheres at active Better Lights dynamic light origins")
    local cvar_radius = BL.CreateClientConVar("betterlights_debug_light_origins_radius", "8", true, false, "Wireframe sphere radius for active Better Lights dynamic light origins", 1, 128)
    local cvar_elights = BL.CreateClientConVar("betterlights_debug_light_origins_elights", "1", true, false, "Include Better Lights entity lights in the dynamic light origin debug view")
    local cvar_depth = BL.CreateClientConVar("betterlights_debug_light_origins_depth", "0", true, false, "Depth-test Better Lights dynamic light origin wireframes")

    local drawColor = Color(255, 255, 255, 220)

    local function isDeveloperMode()
        local developer = GetConVar("developer")
        return developer and developer:GetInt() >= 1
    end

    hook.Add("PostDrawTranslucentRenderables", "BetterLights_DebugDLightOrigins", function(drawingDepth, drawingSkybox)
        if drawingDepth or drawingSkybox then return end
        if not BL.IsEnabled() then return end
        if not cvar_enable:GetBool() then return end
        if not isDeveloperMode() then return end
        if not BL.GetActiveDLightRecords then return end

        local records = BL.GetActiveDLightRecords()
        local radius = math.max(cvar_radius:GetFloat(), 1)
        local includeElights = cvar_elights:GetBool()
        local writeZ = cvar_depth:GetBool()

        render.SetColorMaterial()

        for _, record in pairs(records) do
            if record.pos and (includeElights or not record.elight) then
                drawColor.r = math.Clamp(math.floor((record.r or 255) + 0.5), 0, 255)
                drawColor.g = math.Clamp(math.floor((record.g or 255) + 0.5), 0, 255)
                drawColor.b = math.Clamp(math.floor((record.b or 255) + 0.5), 0, 255)
                drawColor.a = record.elight and 150 or 220

                render.DrawWireframeSphere(record.pos, radius, 12, 6, drawColor, writeZ)
            end
        end
    end)
end
