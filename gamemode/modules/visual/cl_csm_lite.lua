-- Gamemode-owned integration of Workshop 3764410031 (Lite CSM).
-- The original settings menu and client-authoritative server messages are
-- omitted. Exact upstream defaults are restored every time a map loads.

local config = FF_CONFIG.CSMLite or {}
if config.Enabled == false then return end

local DEFAULTS = config.Defaults or {
    c_sh_en = "1",
    c_dis_shb = "1",
    c_fullbright = "0",
    c_lightstyle = "12",
    c_sh_res = "8",
    c_sh_fil = "0.1",
    c_sh_dist = "16",
    c_sun_br = "96",
    c_lamp_mul = "8",
    c_dark = "2",
    c_cam_y = "6",
    c_orto_d = "1",
    c_sh_r = "255",
    c_sh_g = "200",
    c_sh_b = "180",
    c_sh_dark = "1",
    c_pp_bright = "0",
    c_pp_sat = "1.15",
}

for name, defaultValue in pairs(DEFAULTS) do
    CreateClientConVar(name, tostring(defaultValue), true, false)
end

local function retireUpstreamRuntime()
    local hookTable = hook.GetTable()
    local opaqueHooks = hookTable.PostDrawOpaqueRenderables or {}
    local originalDraw = opaqueHooks.h_PostDraw
    local enableConVar = GetConVar("c_sh_en")

    if isfunction(originalDraw) and enableConVar then
        enableConVar:SetBool(false)
        pcall(originalDraw)
    end

    for _, entry in ipairs({
        { "PopulateToolMenu", "h_csmlite_Menu" },
        { "InitPostEntity", "h_StartPost" },
        { "PostDrawOpaqueRenderables", "h_PostDraw" },
        { "SetupWorldFog", "h_Darkness" },
        { "RenderScreenspaceEffects", "h_PostProcess" },
    }) do
        hook.Remove(entry[1], entry[2])
    end

    if concommand and concommand.Remove then
        concommand.Remove("f_restore_defaults")
        concommand.Remove("f_my_config")
    end

    if cvars and cvars.RemoveChangeCallback then
        for _, entry in ipairs({
            { "c_dis_shb", "cb_DisableBakedShadows" },
            { "c_fullbright", "cb_Fullbright" },
            { "c_lightstyle", "cb_LightStyle" },
            { "c_sh_res", "cb_Res" },
            { "c_sh_fil", "cb_Fil" },
            { "c_cam_y", "cb_Cam" },
            { "c_sh_dist", "cb_Dist" },
            { "c_sun_br", "cb_Bright" },
            { "c_dark", "cb_Darkness" },
            { "c_lamp_mul", "cb_Lamp" },
            { "c_orto_d", "cb_Ortho" },
            { "c_sh_r", "cb_R" },
            { "c_sh_g", "cb_G" },
            { "c_sh_b", "cb_B" },
            { "c_sh_dark", "cb_RGB" },
            { "c_pp_bright", "cb_PPBright" },
            { "c_pp_sat", "cb_PPSat" },
        }) do
            cvars.RemoveChangeCallback(entry[1], entry[2])
        end
    end

    if net.Receivers then
        net.Receivers.reloadlighting = nil
    end
end

local function getConVar(name)
    return GetConVar(name)
end

local lamp
local sunAngle = Angle()
local initialized = false

local function removeLamp()
    if IsValid(lamp) then
        lamp:Remove()
    end

    lamp = nil
    initialized = false
end

local function applyEngineSettings()
    local fullbright = getConVar("c_fullbright")
    local resolution = getConVar("c_sh_res")
    local filter = getConVar("c_sh_fil")

    RunConsoleCommand("mat_fullbright", fullbright and fullbright:GetString() or "0")
    RunConsoleCommand(
        "r_flashlightdepthres",
        tostring(math.max(resolution and resolution:GetInt() or 8, 1) * 1024)
    )
    RunConsoleCommand(
        "r_projectedtexture_filter",
        filter and filter:GetString() or "0.1"
    )
end

local function restoreDefaults()
    for name, defaultValue in pairs(DEFAULTS) do
        local convar = getConVar(name)
        if convar and convar:GetString() ~= tostring(defaultValue) then
            convar:SetString(tostring(defaultValue))
        end
    end

    applyEngineSettings()
    removeLamp()
end

local function readNumber(name, fallback)
    local convar = getConVar(name)
    if not convar then return fallback end
    return convar:GetFloat()
end

local function readBool(name, fallback)
    local convar = getConVar(name)
    if not convar then return fallback end
    return convar:GetBool()
end

local function updateSunAngle()
    local sun = util.GetSunInfo()
    if sun and sun.direction then
        sunAngle = (-sun.direction):Angle()
    else
        sunAngle = Angle()
    end
end

local function updateLamp()
    if not readBool("c_sh_en", true) then
        removeLamp()
        return
    end

    local ply = LocalPlayer()
    local world = game.GetWorld()
    if not IsValid(ply) or not IsValid(world) then return end

    if not IsValid(lamp) then
        lamp = ProjectedTexture()
        if not IsValid(lamp) then return end
        updateSunAngle()
        initialized = true
    end

    local mins, maxs = world:GetModelBounds()
    local centerX = (mins.x + maxs.x) * 0.5
    local centerY = (mins.y + maxs.y) * 0.5
    local distance = math.max(readNumber("c_sh_dist", 16), 0.25) * 1024
    local cameraOffset = readNumber("c_cam_y", 6) * 1024
    local lampMultiplier = readNumber("c_lamp_mul", 8) * 1024
    local orthoScale = math.max(readNumber("c_orto_d", 1), 0)
    local shadowDarkness = math.Clamp(readNumber("c_sh_dark", 1), 0, 1)

    local color = Color(
        math.Clamp(readNumber("c_sh_r", 255) * shadowDarkness, 0, 255),
        math.Clamp(readNumber("c_sh_g", 200) * shadowDarkness, 0, 255),
        math.Clamp(readNumber("c_sh_b", 180) * shadowDarkness, 0, 255)
    )

    local lampPosition = Vector(centerX, centerY + cameraOffset, ply:GetPos().z)
        - sunAngle:Forward() * lampMultiplier

    lamp:SetPos(lampPosition)
    lamp:SetOrthographic(
        true,
        distance * orthoScale,
        distance * orthoScale,
        distance * orthoScale,
        distance * orthoScale
    )
    lamp:SetEnableShadows(true)
    lamp:SetNearZ(0)
    lamp:SetFarZ(distance * 4)
    lamp:SetAngles(sunAngle)
    lamp:SetTexture("j_shadows")
    lamp:SetQuadraticAttenuation(0)
    lamp:SetColor(color)
    lamp:SetBrightness(math.max(readNumber("c_sun_br", 96), 0))
    lamp:Update()
end

local function initializeForMap()
    retireUpstreamRuntime()
    restoreDefaults()

    timer.Simple(0, function()
        if not IsValid(LocalPlayer()) then return end
        updateLamp()
    end)
end

retireUpstreamRuntime()
restoreDefaults()
hook.Add("InitPostEntity", "FF_CSMLite_MapDefaults", initializeForMap)
hook.Add("OnReloaded", "FF_CSMLite_ReloadDefaults", initializeForMap)

hook.Add("PostDrawOpaqueRenderables", "FF_CSMLite_ShadowPass", function()
    if not initialized or not IsValid(lamp) then
        updateLamp()
    end
end)

hook.Add("Think", "FF_CSMLite_TrackPlayerHeight", function()
    if not IsValid(lamp) or not readBool("c_sh_en", true) then return end

    local nextUpdate = FF_CSMLite_NextUpdate or 0
    if CurTime() < nextUpdate then return end
    FF_CSMLite_NextUpdate = CurTime() + 0.1
    updateLamp()
end)

hook.Add("SetupWorldFog", "FF_CSMLite_Darkness", function()
    if not readBool("c_sh_en", true) then return end

    local darkness = math.max(readNumber("c_dark", 2), 0)
    local distance = math.max(readNumber("c_sh_dist", 16), 0.25) * 1024

    render.FogMode(MATERIAL_FOG_LINEAR)
    render.FogStart(distance * 4)
    render.FogEnd(distance)
    render.FogColor(0, 0, 0)
    render.FogMaxDensity(math.Clamp(darkness * 0.05, 0, 1))
    return true
end)

hook.Add("RenderScreenspaceEffects", "FF_CSMLite_Color", function()
    if not readBool("c_sh_en", true) then return end

    DrawColorModify({
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = readNumber("c_pp_bright", 0),
        ["$pp_colour_contrast"] = 1,
        ["$pp_colour_colour"] = readNumber("c_pp_sat", 1.15),
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0,
    })
end)

net.Receive("FF_CSMLite_ReloadLighting", function()
    render.RedownloadAllLightmaps(true, true)
    removeLamp()
end)

hook.Add("ShutDown", "FF_CSMLite_Cleanup", removeLamp)
