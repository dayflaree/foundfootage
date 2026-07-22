-- Remove legacy Found Footage VHS hooks from earlier builds. The original
-- RealisticVHSEffect2 runtime is now the sole VHS renderer.
hook.Remove("RenderScreenspaceEffects", "FF_PreRealisticVHSEffect2")
hook.Remove("DrawOverlay", "FF_ForcedCameraEffects")
hook.Remove("RenderScreenspaceEffects", "FF_ForcedCameraEffects")

local fisheyeConfig = FF_CONFIG.Effects.Fisheye

local useCustomFisheyeShader = system and system.IsWindows and system.IsWindows()
local fisheyeMaterial = useCustomFisheyeShader and Material(fisheyeConfig.Material) or nil
local fallbackFisheyeMaterial = Material("pp/fb")

local fisheyeAvailable = fisheyeMaterial and not fisheyeMaterial:IsError()
local fallbackFisheyeAvailable = fallbackFisheyeMaterial and not fallbackFisheyeMaterial:IsError()
local warned = false

local function warnOnce(materialName)
    if warned then return end
    warned = true

    FF_DiscardOutput(
        Color(255, 170, 70),
        "[Found Footage] Material unavailable: ",
        color_white,
        materialName,
        "\n"
    )
end

local function addFisheyeVertex(x, y, u, v)
    mesh.Position(Vector(x, y, 0))
    mesh.TexCoord(0, u, v)
    mesh.Color(255, 255, 255, 255)
    mesh.AdvanceVertex()
end

local function warpedUV(u, v, strength)
    local x = (u - 0.5) * 2
    local y = (v - 0.5) * 2
    local radiusSquared = x * x + y * y
    local scale = 1 + math.max(strength, 0) * 0.7 * radiusSquared

    return math.Clamp(0.5 + x * scale * 0.5, 0, 1),
        math.Clamp(0.5 + y * scale * 0.5, 0, 1)
end

local function drawFallbackFisheye()
    local width = ScrW()
    local height = ScrH()
    local columns = 24
    local rows = 14

    render.UpdateScreenEffectTexture()
    cam.Start2D()
        render.SetMaterial(fallbackFisheyeMaterial)
        mesh.Begin(MATERIAL_TRIANGLES, columns * rows * 2)

        for row = 0, rows - 1 do
            local v0 = row / rows
            local v1 = (row + 1) / rows
            local y0 = v0 * height
            local y1 = v1 * height

            for column = 0, columns - 1 do
                local u0 = column / columns
                local u1 = (column + 1) / columns
                local x0 = u0 * width
                local x1 = u1 * width

                local su00, sv00 = warpedUV(u0, v0, fisheyeConfig.Strength)
                local su10, sv10 = warpedUV(u1, v0, fisheyeConfig.Strength)
                local su11, sv11 = warpedUV(u1, v1, fisheyeConfig.Strength)
                local su01, sv01 = warpedUV(u0, v1, fisheyeConfig.Strength)

                addFisheyeVertex(x0, y0, su00, sv00)
                addFisheyeVertex(x1, y0, su10, sv10)
                addFisheyeVertex(x1, y1, su11, sv11)

                addFisheyeVertex(x0, y0, su00, sv00)
                addFisheyeVertex(x1, y1, su11, sv11)
                addFisheyeVertex(x0, y1, su01, sv01)
            end
        end

        mesh.End()
    cam.End2D()
end

local function drawFisheye()
    if not fisheyeConfig.Enabled then return end

    if useCustomFisheyeShader and fisheyeAvailable then
        render.UpdateScreenEffectTexture()
        fisheyeMaterial:SetFloat("$c0_x", fisheyeConfig.Strength)
        render.SetMaterial(fisheyeMaterial)
        render.DrawScreenQuad()
        return
    end

    if not fallbackFisheyeAvailable then
        warnOnce("pp/fb")
        return
    end

    drawFallbackFisheye()
end

-- RealisticVHSEffect2 owns the complete VHS pipeline and final DrawOverlay
-- framing. This module now provides only the requested fisheye distortion.
hook.Add("RenderScreenspaceEffects", "FF_FisheyeOnly", drawFisheye)
