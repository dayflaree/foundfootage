-- Immersive Custom Flashlight v1.2.5
-- By SamuraiCyanide

local enabled = false
local proj = nil
local spillProj = nil

local CreateLight
local DestroyLight
local PlayToggleSound
local DoFlashlightToggle
local RequestFlashlightToggle
local flashlightConfig = FF_CONFIG and FF_CONFIG.Flashlight or {}
local ICF_WebKnightBatteryDepletedRecovery
local ICF_GetVManipMode
local MaintainVManipDefaultFlashlightHook


CreateClientConVar("cflash_enabled", "0", true, false)
CreateClientConVar("cflash_disable_stock", "1", true, false)
CreateClientConVar("cflash_play_sound", "0", true, false)
CreateClientConVar("cflash_wall_detection", "0", true, false)
CreateClientConVar("cflash_vehicle_flashlight", "0", true, false)
CreateClientConVar("cflash_keep_on_death", "0", true, false)
CreateClientConVar("cflash_custom_key_enabled", "0", true, false)
CreateClientConVar("cflash_custom_key", tostring(KEY_F), true, false)
CreateClientConVar("cflash_input_text_guard", "1", true, false)
CreateClientConVar("cflash_vmanip_compat", "0", true, false)
CreateClientConVar("cflash_vmanip_mode", "default", true, false)
CreateClientConVar("cflash_vmanip_emptyhands_bridge", "0", true, false)
CreateClientConVar("cflash_vmanip_bridge_hands_classes", "weapon_hands,gmod_hands,weapon_fists,hands,weapon_empty_hands", true, false)
CreateClientConVar("cflash_vmanip_anim_lockout", "1.15", true, false)
CreateClientConVar("cflash_vmanip_strict_hook_guard", "1", true, false)
CreateClientConVar("cflash_stock_beam_guard_debug", "0", true, false)
CreateClientConVar("cflash_vmanip_webknight_follow_light", "0", true, false)
CreateClientConVar("cflash_vmanip_webknight_shoulder_key_enabled", "0", true, false)
CreateClientConVar("cflash_vmanip_webknight_shoulder_key", "0", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_light", "0", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_delay", "1.10", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_strength", "8.5", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_max_angle", "20", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_local", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_bones", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_pitch_sign", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_yaw_sign", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_bone_scale", "0.39", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_side", "main_left", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_fade_time", "0.45", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_deadzone", "0.35", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_tune_version", "48", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_use_camera_relative", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_return_strength", "5", true, false)
CreateClientConVar("cflash_vmanip_webknight_model_follow_left_weight", "1.0", true, false)
CreateClientConVar("cflash_vmanip_webknight_proc_spring", "72", true, false)
CreateClientConVar("cflash_vmanip_webknight_proc_damping", "15", true, false)
CreateClientConVar("cflash_vmanip_webknight_proc_max_speed", "115", true, false)
CreateClientConVar("cflash_vmanip_webknight_proc_lag", "0.05", true, false)
CreateClientConVar("cflash_vmanip_webknight_proc_axis_preset", "swapped", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_latch", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_pseudo_weld", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_pitch_flip", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_pos_weld", "0", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_pos_weld_amount", "0", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_pos_weld_forearm", "0", true, false)
CreateClientConVar("cflash_vmanip_webknight_stiff_arm", "0", true, false)
CreateClientConVar("cflash_vmanip_webknight_handle_support_arm", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_side_yaw_fix", "1", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_side_amount", "0.56", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_vertical_amount", "0.72", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_handle_roll_amount", "0.72", true, false)
CreateClientConVar("cflash_vmanip_webknight_hand_vertical_roll_amount", "0.12", true, false)
CreateClientConVar("cflash_firstperson_viewmodel_push", "0", true, false)

timer.Simple(0, function()
    local version = GetConVar("cflash_vmanip_webknight_model_follow_tune_version")
    if version and version:GetInt() >= 48 then return end

    RunConsoleCommand("cflash_vmanip_webknight_model_follow_delay", "1.10")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_strength", "8.5")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_max_angle", "20")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_bone_scale", "0.39")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_side", "main_left")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_fade_time", "0.42")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_deadzone", "0.25")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_use_camera_relative", "1")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_return_strength", "6")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_left_weight", "1.0")
    RunConsoleCommand("cflash_vmanip_webknight_proc_spring", "72")
    RunConsoleCommand("cflash_vmanip_webknight_proc_damping", "15")
    RunConsoleCommand("cflash_vmanip_webknight_proc_max_speed", "115")
    RunConsoleCommand("cflash_vmanip_webknight_proc_lag", "0.025")
    RunConsoleCommand("cflash_vmanip_webknight_proc_axis_preset", "swapped")
    RunConsoleCommand("cflash_vmanip_webknight_hand_latch", "1")
    RunConsoleCommand("cflash_vmanip_webknight_hand_pseudo_weld", "1")
    RunConsoleCommand("cflash_vmanip_webknight_hand_pitch_flip", "1")
    RunConsoleCommand("cflash_vmanip_webknight_hand_pos_weld", "0")
    RunConsoleCommand("cflash_vmanip_webknight_hand_pos_weld_amount", "0")
    RunConsoleCommand("cflash_vmanip_webknight_hand_pos_weld_forearm", "0")
    RunConsoleCommand("cflash_vmanip_webknight_stiff_arm", "0")
    RunConsoleCommand("cflash_vmanip_webknight_handle_support_arm", "1")
    RunConsoleCommand("cflash_vmanip_webknight_hand_side_yaw_fix", "1")
    RunConsoleCommand("cflash_vmanip_webknight_hand_side_amount", "0.56")
    RunConsoleCommand("cflash_vmanip_webknight_hand_vertical_amount", "0.72")
    RunConsoleCommand("cflash_vmanip_webknight_hand_handle_roll_amount", "0.72")
    RunConsoleCommand("cflash_vmanip_webknight_hand_vertical_roll_amount", "0.12")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_pitch_sign", "1")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_yaw_sign", "1")
    RunConsoleCommand("cflash_vmanip_webknight_model_follow_tune_version", "48")
end) -- ICF_ApplyWebKnightFollowTest48Defaults


CreateClientConVar("cflash_brightness", "2.6", true, false)
CreateClientConVar("cflash_dynamic_shadows", "1", true, false)
CreateClientConVar("cflash_lightspill_enabled", "0", true, false)
CreateClientConVar("cflash_lightspill_texture", "effects/lightspill/spill1", true, false)
CreateClientConVar("cflash_lightspill_brightness", "0.24", true, false)
CreateClientConVar("cflash_lightspill_size", "1", true, false)
CreateClientConVar("cflash_lightspill_fov", "112", true, false)
CreateClientConVar("cflash_lightspill_farz", "720", true, false)
CreateClientConVar("cflash_lightspill_nearz", "8", true, false)
CreateClientConVar("cflash_lightspill_forward", "5", true, false)
CreateClientConVar("cflash_lightspill_right", "0", true, false)
CreateClientConVar("cflash_lightspill_up", "0", true, false)
CreateClientConVar("cflash_lightspill_color_r", "255", true, false)
CreateClientConVar("cflash_lightspill_color_g", "255", true, false)
CreateClientConVar("cflash_lightspill_color_b", "255", true, false)
CreateClientConVar("cflash_multiplayer_visibility", "0", true, false)
CreateClientConVar("cflash_multiplayer_show_others", "1", true, false)
CreateClientConVar("cflash_multiplayer_update_rate", "10", true, false)
CreateClientConVar("cflash_multiplayer_distance", "2500", true, false)
CreateClientConVar("cflash_multiplayer_max_remote_lights", "4", true, false)
CreateClientConVar("cflash_multiplayer_remote_shadows", "0", true, false)
CreateClientConVar("cflash_multiplayer_remote_lightspill", "0", true, false)
CreateClientConVar("cflash_multiplayer_remote_textures", "1", true, false)
CreateClientConVar("cflash_multiplayer_remote_emitter_glow", "1", true, false)
CreateClientConVar("cflash_multiplayer_emitter_forward", "8", true, false)
CreateClientConVar("cflash_multiplayer_emitter_right", "0", true, false)
CreateClientConVar("cflash_multiplayer_emitter_up", "0", true, false)
CreateClientConVar("cflash_color_r", "255", true, false)
CreateClientConVar("cflash_color_g", "255", true, false)
CreateClientConVar("cflash_color_b", "255", true, false)
CreateClientConVar("cflash_startup_flicker_enabled", "0", true, false)
CreateClientConVar("cflash_startup_flicker_time", "0.45", true, false)
CreateClientConVar("cflash_startup_flicker_intensity", "0.55", true, false)


CreateClientConVar("cflash_battery_enabled", "0", true, false)
CreateClientConVar("cflash_battery_level", "100", true, false)
CreateClientConVar("cflash_battery_drain_rate", "1.25", true, false)
CreateClientConVar("cflash_battery_recharge_rate", "2.5", true, false)
CreateClientConVar("cflash_battery_low_threshold", "20", true, false)
CreateClientConVar("cflash_battery_dim", "0", true, false)
CreateClientConVar("cflash_battery_flicker", "0", true, false)
CreateClientConVar("cflash_battery_hud", "0", true, false)
CreateClientConVar("cflash_battery_reload_enabled", "0", true, false)
CreateClientConVar("cflash_battery_reload_key", tostring(KEY_N), true, false)
CreateClientConVar("cflash_battery_reload_allow_weapon_reload", "0", true, false)
CreateClientConVar("cflash_battery_spares", "0", true, false)
CreateClientConVar("cflash_battery_spares_max", "3", true, false)
CreateClientConVar("cflash_battery_reload_time", "0.85", true, false)
CreateClientConVar("cflash_battery_reload_blackout_time", "0.18", true, false)
CreateClientConVar("cflash_battery_reload_flicker_time", "1.0", true, false)
CreateClientConVar("cflash_battery_reload_flicker_intensity", "0.85", true, false)
CreateClientConVar("cflash_battery_reload_sound", "immersive_custom_flashlight/battery_reload.wav", true, false)

CreateClientConVar("cflash_thirdperson_enabled", "0", true, false)
CreateClientConVar("cflash_thirdperson_anchor", "head", true, false)
CreateClientConVar("cflash_thirdperson_right", "5", true, false)
CreateClientConVar("cflash_thirdperson_up", "-2", true, false)
CreateClientConVar("cflash_thirdperson_forward", "6", true, false)

CreateClientConVar("cflash_texture", "effects/flashlight001", true, false)

CreateClientConVar("cflash_offset_right", "0", true, false)
CreateClientConVar("cflash_offset_up", "0", true, false)
CreateClientConVar("cflash_offset_forward", "0", true, false)


CreateClientConVar("cflash_strength", "49", true, false)
CreateClientConVar("cflash_damping", "9", true, false)

CreateClientConVar("cflash_walksway", "0", true, false)
CreateClientConVar("cflash_breath", "0", true, false)

CreateClientConVar("cflash_shake", "0", true, false)
CreateClientConVar("cflash_shake_speed", "6", true, false)

CreateClientConVar("cflash_sprint_bob", "0", true, false)
CreateClientConVar("cflash_sprint_bob_intensity", "10.00", true, false)
CreateClientConVar("cflash_sprint_bob_speed", "11", true, false)
CreateClientConVar("cflash_sprint_pos_bob", "0.00", true, false)
CreateClientConVar("cflash_sprint_bob_turn_stabilize", "1", true, false)

CreateClientConVar("cflash_fov", "52", true, false)
CreateClientConVar("cflash_farz", "1600", true, false)


local pitch = 0
local yaw = 0
local pitchVel = 0
local yawVel = 0

local walkBlend = 0
local sprintBlend = 0
local sprintBobPhase = 0
local lastF = false
local lastBatteryReloadKey = false
local ICF_MenuInputBlockedUntil = 0
local batteryLevel = 100
local batteryInitialized = false
local batteryLowNotified = false
local nextBatterySave = 0
local batteryFlickerMul = 1
local nextBatteryFlicker = 0
local batteryReloading = false
local batteryReloadStart = 0
local batteryReloadEnd = 0
local batteryReloadWasEnabled = false
local batteryReloadRelit = false
local batteryReloadRelightTime = 0
local batteryReloadFlickerEnd = 0
local batteryReloadFlickerMul = 1
local nextBatteryReloadFlicker = 0
local startupFlickerEnd = 0
local startupFlickerMul = 1
local nextStartupFlicker = 0
local startupFlickerIntensityOverride = nil

local ICF_SafeDestroyLight
local ICF_TryBatteryReloadRelight


local wasAlive = true

local fearX = 0
local fearY = 0
local fearTargetX = 0
local fearTargetY = 0
local nextFearTarget = 0

local function SafeConVarFloat(name, fallback)
    local cv = GetConVar(name)
    if not cv then return fallback end
    return cv:GetFloat()
end

local function SafeConVarBool(name, fallback)
    local cv = GetConVar(name)
    if not cv then return fallback end
    return cv:GetBool()
end

local function SafeConVarString(name, fallback)
    local cv = GetConVar(name)
    if not cv then return fallback end

    local value = cv:GetString()

    if not value or value == "" then
        return fallback
    end

    return value
end

local function ICF_ShouldForceStockFlashlightOff()
    return SafeConVarBool("cflash_enabled", false)
end

local function GetFlashlightTexture()
    return SafeConVarString("cflash_texture", "effects/flashlight001")
end


local function GetFlashlightColor()
    return Color(
        math.Clamp(math.Round(SafeConVarFloat("cflash_color_r", 255)), 0, 255),
        math.Clamp(math.Round(SafeConVarFloat("cflash_color_g", 255)), 0, 255),
        math.Clamp(math.Round(SafeConVarFloat("cflash_color_b", 255)), 0, 255)
    )
end


function ICF_ShouldEnableProjectedShadows()
    return SafeConVarBool("cflash_dynamic_shadows", true)
end

function ICF_GetProjectedNearZ(baseNearZ)
    return tonumber(baseNearZ) or 2
end

function ICF_UpdateMainProjectedTexture(projectedTexture, finalPos, finalAng, dynamicNearZ)
    if not IsValid(projectedTexture) then return end

    projectedTexture:SetTexture(GetFlashlightTexture())
    projectedTexture:SetEnableShadows(ICF_ShouldEnableProjectedShadows())
    projectedTexture:SetColor(GetFlashlightColor())
    projectedTexture:SetPos(finalPos)
    projectedTexture:SetAngles(finalAng)
    projectedTexture:SetBrightness(ICF_MainLightTemporarilyHidden and 0 or ICF_GetEffectiveProjectedBrightness())
    projectedTexture:SetFOV(SafeConVarFloat("cflash_fov", 40))
    projectedTexture:SetFarZ(SafeConVarFloat("cflash_farz", 1837))
    projectedTexture:SetNearZ(ICF_GetProjectedNearZ(dynamicNearZ))
    projectedTexture:Update()
end

local function ICF_BatteryEnabled()
    return SafeConVarBool("cflash_battery_enabled", false)
end

local function ICF_InitBattery()
    if batteryInitialized then return end

    batteryInitialized = true
    batteryLevel = math.Clamp(SafeConVarFloat("cflash_battery_level", 100), 0, 100)
    batteryLowNotified = batteryLevel <= math.max(
        SafeConVarFloat("cflash_battery_low_threshold", 20),
        0
    )
end

local function ICF_GetBatteryLevel()
    ICF_InitBattery()
    return math.Clamp(batteryLevel, 0, 100)
end

function FF_GetFlashlightBatteryFraction()
    if not ICF_BatteryEnabled() then return 1 end
    return math.Clamp(ICF_GetBatteryLevel() / 100, 0, 1)
end

function FF_IsFlashlightActive()
    return enabled == true and IsValid(proj)
end

function FF_IsFlashlightBatteryCharging()
    return ICF_BatteryEnabled()
        and not FF_IsFlashlightActive()
        and ICF_GetBatteryLevel() < 99.95
end

local function ICF_SaveBattery(force)
    if not force and CurTime() < nextBatterySave then return end

    nextBatterySave = CurTime() + 0.5
    RunConsoleCommand("cflash_battery_level", tostring(math.Round(ICF_GetBatteryLevel(), 1)))
end

local function ICF_SetBatteryLevel(value, forceSave)
    ICF_InitBattery()
    batteryLevel = math.Clamp(tonumber(value) or 0, 0, 100)
    ICF_SaveBattery(forceSave)
end

local function ICF_BatteryCanTurnOn()
    if not ICF_BatteryEnabled() then return true end
    return ICF_GetBatteryLevel() > 0.1
end

local function ICF_GetBatteryBrightnessMultiplier()
    if not ICF_BatteryEnabled() then return 1 end
    if not SafeConVarBool("cflash_battery_dim", true) then return 1 end

    local threshold = math.max(SafeConVarFloat("cflash_battery_low_threshold", 20), 1)
    local level = ICF_GetBatteryLevel()

    if level >= threshold then return 1 end

    local frac = math.Clamp(level / threshold, 0, 1)
    return Lerp(frac, 0.35, 1)
end

local function ICF_GetBatteryFlickerMultiplier()
    if not ICF_BatteryEnabled() then return 1 end
    if not SafeConVarBool("cflash_battery_flicker", true) then return 1 end

    local threshold = math.max(SafeConVarFloat("cflash_battery_low_threshold", 20), 1)
    local level = ICF_GetBatteryLevel()

    if level >= threshold then
        batteryFlickerMul = Lerp(FrameTime() * 8, batteryFlickerMul, 1)
        return batteryFlickerMul
    end

    local lowFrac = 1 - math.Clamp(level / threshold, 0, 1)

    if CurTime() >= nextBatteryFlicker then
        nextBatteryFlicker = CurTime() + math.Rand(0.04, 0.18)
        batteryFlickerMul = 1 - math.Rand(0.05, 0.45) * lowFrac
    end

    return math.Clamp(batteryFlickerMul, 0.35, 1)
end


local function ICF_StartStartupFlicker(durationOverride, intensityOverride, force)
    if not force and not SafeConVarBool("cflash_startup_flicker_enabled", false) then return end

    local dur = math.Clamp(tonumber(durationOverride) or SafeConVarFloat("cflash_startup_flicker_time", 0.45), 0, 5)
    local intensity = math.Clamp(tonumber(intensityOverride) or SafeConVarFloat("cflash_startup_flicker_intensity", 0.55), 0, 1)

    if dur <= 0 or intensity <= 0 then return end

    startupFlickerEnd = CurTime() + dur
    startupFlickerMul = math.Clamp(1 - intensity, 0.03, 1)
    nextStartupFlicker = 0
    startupFlickerIntensityOverride = intensity
end

local function ICF_GetStartupFlickerMultiplier()
    if CurTime() >= startupFlickerEnd then
        startupFlickerMul = Lerp(FrameTime() * 12, startupFlickerMul, 1)
        startupFlickerIntensityOverride = nil
        return startupFlickerMul
    end

    local total = math.max(SafeConVarFloat("cflash_startup_flicker_time", 0.45), 0.01)
    local remaining = math.Clamp((startupFlickerEnd - CurTime()) / total, 0, 1)
    local intensity = math.Clamp(startupFlickerIntensityOverride or SafeConVarFloat("cflash_startup_flicker_intensity", 0.55), 0, 1)

    if CurTime() >= nextStartupFlicker then
        nextStartupFlicker = CurTime() + math.Rand(0.018, 0.09)

        if math.Rand(0, 1) < 0.35 * intensity * remaining then
            startupFlickerMul = math.Rand(0.03, 0.22)
        else
            startupFlickerMul = 1 - math.Rand(0.12, intensity) * remaining
        end
    end

    return math.Clamp(startupFlickerMul, 0.03, 1)
end

local function ICF_GetBatteryReloadFlickerMultiplier()
    if CurTime() >= batteryReloadFlickerEnd then
        batteryReloadFlickerMul = Lerp(FrameTime() * 14, batteryReloadFlickerMul, 1)
        return batteryReloadFlickerMul
    end

    local total = math.max(SafeConVarFloat("cflash_battery_reload_flicker_time", 1.0), 0.01)
    local remaining = math.Clamp((batteryReloadFlickerEnd - CurTime()) / total, 0, 1)
    local intensity = math.Clamp(SafeConVarFloat("cflash_battery_reload_flicker_intensity", 0.85), 0, 1)

    if CurTime() >= nextBatteryReloadFlicker then
        nextBatteryReloadFlicker = CurTime() + math.Rand(0.014, 0.075)

        if math.Rand(0, 1) < 0.45 * intensity * remaining then
            batteryReloadFlickerMul = math.Rand(0.02, 0.18)
        else
            batteryReloadFlickerMul = 1 - math.Rand(0.18, intensity) * remaining
        end
    end

    return math.Clamp(batteryReloadFlickerMul, 0.02, 1)
end

local function ICF_GetEffectiveBrightness()
    return SafeConVarFloat("cflash_brightness", 1.0) *
        ICF_GetBatteryBrightnessMultiplier() *
        ICF_GetBatteryFlickerMultiplier() *
        ICF_GetBatteryReloadFlickerMultiplier() *
        ICF_GetStartupFlickerMultiplier()
end


function ICF_GetEffectiveProjectedBrightness()
    return ICF_GetEffectiveBrightness()
end

function ICF_RemoveLightspill()
    if IsValid(spillProj) then
        spillProj:Remove()
    end

    spillProj = nil
end

function ICF_LightspillEnabled()
    return SafeConVarBool("cflash_lightspill_enabled", false)
end

function ICF_GetLightspillTexture()
    return SafeConVarString("cflash_lightspill_texture", "effects/lightspill/spill1")
end

function ICF_GetLightspillColor()
    return Color(
        math.Clamp(math.Round(SafeConVarFloat("cflash_lightspill_color_r", 255)), 0, 255),
        math.Clamp(math.Round(SafeConVarFloat("cflash_lightspill_color_g", 255)), 0, 255),
        math.Clamp(math.Round(SafeConVarFloat("cflash_lightspill_color_b", 255)), 0, 255)
    )
end

function ICF_UpdateLightspill(pos, ang, baseNearZ)
    if not ICF_LightspillEnabled() then
        ICF_RemoveLightspill()
        return
    end

    if not IsValid(proj) then
        ICF_RemoveLightspill()
        return
    end

    if not IsValid(spillProj) then
        spillProj = ProjectedTexture()

        if not spillProj then return end
    end

    local spillAng = Angle(ang.p, ang.y, ang.r)
    local spillPos = pos + spillAng:Forward() * SafeConVarFloat("cflash_lightspill_forward", 5)
    spillPos = spillPos + spillAng:Right() * SafeConVarFloat("cflash_lightspill_right", 0)
    spillPos = spillPos + spillAng:Up() * SafeConVarFloat("cflash_lightspill_up", 0)
    local spillBrightness = ICF_GetEffectiveProjectedBrightness() * SafeConVarFloat("cflash_lightspill_brightness", 0.24)
    local spillNearZ = math.max(tonumber(baseNearZ) or 2, SafeConVarFloat("cflash_lightspill_nearz", 8))

    spillProj:SetTexture(ICF_GetLightspillTexture())
    spillProj:SetEnableShadows(false)
    spillProj:SetColor(ICF_GetLightspillColor())
    spillProj:SetPos(spillPos)
    spillProj:SetAngles(spillAng)
    spillProj:SetBrightness(math.Clamp(spillBrightness, 0.01, 10))
    local spillFov = SafeConVarFloat("cflash_lightspill_fov", 112) * math.Clamp(SafeConVarFloat("cflash_lightspill_size", 1), 0.25, 1.25)
    spillProj:SetFOV(math.Clamp(spillFov, 10, 140))
    spillProj:SetFarZ(math.Clamp(SafeConVarFloat("cflash_lightspill_farz", 720), 64, 4000))
    spillProj:SetNearZ(ICF_GetProjectedNearZ(spillNearZ))
    spillProj:Update()
end

local function ICF_GetMaxSpareBatteries()
    return math.Clamp(math.Round(SafeConVarFloat("cflash_battery_spares_max", 3)), 0, 99)
end

local function ICF_GetSpareBatteryCount()
    return math.Clamp(math.Round(SafeConVarFloat("cflash_battery_spares", 0)), 0, ICF_GetMaxSpareBatteries())
end

local function ICF_SetSpareBatteryCount(value)
    value = math.Clamp(math.Round(tonumber(value) or 0), 0, ICF_GetMaxSpareBatteries())
    RunConsoleCommand("cflash_battery_spares", tostring(value))
end

local function ICF_AddSpareBatteries(amount)
    local before = ICF_GetSpareBatteryCount()
    local after = math.Clamp(before + math.Round(tonumber(amount) or 1), 0, ICF_GetMaxSpareBatteries())

    ICF_SetSpareBatteryCount(after)

    if after > before then
        FF_PlaySurfaceSound("items/battery_pickup.wav")
    elseif FF_PlayUISound then
        FF_PlayUISound("error")
    end

    return after > before
end

local function ICF_IsBatteryReloading()
    return batteryReloading and CurTime() < batteryReloadEnd
end

local function ICF_FinishBatteryReload()
    if not batteryReloading then return end

    ICF_TryBatteryReloadRelight()

    batteryReloading = false
    ICF_SetBatteryLevel(100, true)

    if batteryReloadWasEnabled then
        enabled = true

        if not IsValid(proj) and isfunction(CreateLight) then
            CreateLight()
        end
    end
end

local function ICF_CanBatteryReload()
    if not ICF_BatteryEnabled() then return false end
    if not SafeConVarBool("cflash_battery_reload_enabled", true) then return false end
    if ICF_IsBatteryReloading() then return false end
    if ICF_GetSpareBatteryCount() <= 0 then return false end
    if ICF_GetBatteryLevel() >= 99.5 then return false end

    return true
end


ICF_TryBatteryReloadRelight = function()
    if not batteryReloading then return end
    if batteryReloadRelit then return end
    if not batteryReloadWasEnabled then return end
    if CurTime() < batteryReloadRelightTime then return end

    batteryReloadRelit = true

    enabled = true
    ICF_SetBatteryLevel(100, true)

    if isfunction(CreateLight) then
        CreateLight()
    end

    local reloadFlickerTime = math.Clamp(SafeConVarFloat("cflash_battery_reload_flicker_time", 1.0), 0, 5)
    local reloadFlickerIntensity = math.Clamp(SafeConVarFloat("cflash_battery_reload_flicker_intensity", 0.85), 0, 1)

    batteryReloadFlickerEnd = CurTime() + reloadFlickerTime
    nextBatteryReloadFlicker = 0
    batteryReloadFlickerMul = math.Clamp(1 - reloadFlickerIntensity, 0.02, 0.45)

    ICF_StartStartupFlicker(reloadFlickerTime, reloadFlickerIntensity, true)
end

local function ICF_StartBatteryReload()
    if not ICF_CanBatteryReload() then return false end

    ICF_SetSpareBatteryCount(ICF_GetSpareBatteryCount() - 1)

    batteryReloading = true
    batteryReloadStart = CurTime()
    batteryReloadEnd = CurTime() + math.Clamp(SafeConVarFloat("cflash_battery_reload_time", 0.85), 0.1, 5)
    batteryReloadWasEnabled = enabled
    batteryReloadRelit = false
    batteryReloadRelightTime = CurTime() + math.Clamp(SafeConVarFloat("cflash_battery_reload_blackout_time", 0.18), 0, 2)

    if batteryReloadWasEnabled then
        enabled = false
        ICF_SafeDestroyLight()
    end

    FF_PlaySurfaceSound(SafeConVarString("cflash_battery_reload_sound", "immersive_custom_flashlight/battery_reload.wav"))

    return true
end

local function ICF_GetReloadAnimFraction()
    if not batteryReloading then return 0 end

    ICF_TryBatteryReloadRelight()

    local dur = math.max(batteryReloadEnd - batteryReloadStart, 0.01)
    local frac = math.Clamp((CurTime() - batteryReloadStart) / dur, 0, 1)

    if frac >= 1 then
        ICF_FinishBatteryReload()
        return 0
    end

    return frac
end

local function ICF_ApplyBatteryReloadAnimation(pos, ang)
    local frac = ICF_GetReloadAnimFraction()

    if frac <= 0 then
        return pos, ang
    end

    local dip = math.sin(frac * math.pi)
    local swap = math.sin(frac * math.pi * 2)

    local newAng = Angle(ang.p, ang.y, ang.r)
    newAng.p = newAng.p + dip * 7
    newAng.y = newAng.y + swap * 2.5

    local newPos =
        pos +
        newAng:Up() * (-7 * dip) +
        newAng:Right() * (2.5 * swap) +
        newAng:Forward() * (-3 * dip)

    return newPos, newAng
end

net.Receive("ICF_AddSpareBattery", function()
    local amount = net.ReadUInt(8)
    ICF_AddSpareBatteries(amount)
end)

ICF_SafeDestroyLight = function()
    if isfunction(DestroyLight) then
        DestroyLight()
        return
    end

    if IsValid(proj) then
        proj:Remove()
    end

    proj = nil

    if isfunction(ICF_RemoveLightspill) then
        ICF_RemoveLightspill()
    end
end


local function ICF_UpdateBattery(dt)
    if not ICF_BatteryEnabled() then
        ICF_InitBattery()
        return
    end

    ICF_InitBattery()

    if batteryReloading then
        ICF_GetReloadAnimFraction()
        return
    end

    dt = math.Clamp(dt or FrameTime(), 0, 0.25)

    if enabled and IsValid(proj) then
        local drainPerSecond = math.Clamp(SafeConVarFloat("cflash_battery_drain_rate", 1.25), 0, 100)
        ICF_SetBatteryLevel(batteryLevel - drainPerSecond * dt, false)

        if batteryLevel <= 0.1 then
            batteryLevel = 0
            enabled = false
            ICF_SafeDestroyLight()
            ICF_SaveBattery(true)
            if isfunction(ICF_WebKnightBatteryDepletedRecovery) then
                ICF_WebKnightBatteryDepletedRecovery()
            end
        end
    else
        local rechargePerSecond = math.Clamp(SafeConVarFloat("cflash_battery_recharge_rate", 2.5), 0, 100)
        ICF_SetBatteryLevel(batteryLevel + rechargePerSecond * dt, false)
    end

    local lowThreshold = math.max(
        SafeConVarFloat("cflash_battery_low_threshold", 20),
        0
    )
    local isLow = batteryLevel <= lowThreshold
    if enabled and isLow and not batteryLowNotified and FF_PlayUISound then
        FF_PlayUISound("battery_low")
    end
    batteryLowNotified = isLow
end

local function ICF_IsThirdPersonActive(ply)
    if not SafeConVarBool("cflash_thirdperson_enabled", true) then return false end
    if not IsValid(ply) then return false end

    local viewEnt = GetViewEntity and GetViewEntity() or nil

    if IsValid(viewEnt) and viewEnt ~= ply then
        return true
    end

    if ply.ShouldDrawLocalPlayer and ply:ShouldDrawLocalPlayer() then
        return true
    end

    return false
end

local function ICF_GetAttachmentPos(ply, names)
    if not IsValid(ply) then return nil end

    for _, name in ipairs(names or {}) do
        local id = ply:LookupAttachment(name)

        if id and id > 0 then
            local att = ply:GetAttachment(id)

            if att and att.Pos then
                return att.Pos
            end
        end
    end

    return nil
end

local function ICF_GetThirdPersonBasePosition(ply, ang)
    if not ICF_IsThirdPersonActive(ply) then
        return nil
    end

    local anchor = string.lower(SafeConVarString("cflash_thirdperson_anchor", "head"))
    local basePos = nil

    if anchor == "right_hand" then
        basePos = ICF_GetAttachmentPos(ply, {"anim_attachment_RH", "anim_attachment_rh", "right_hand"})
    elseif anchor == "left_hand" then
        basePos = ICF_GetAttachmentPos(ply, {"anim_attachment_LH", "anim_attachment_lh", "left_hand"})
    elseif anchor == "chest" then
        local bone = ply:LookupBone("ValveBiped.Bip01_Spine2") or ply:LookupBone("ValveBiped.Bip01_Spine")

        if bone then
            local pos = ply:GetBonePosition(bone)
            if pos then basePos = pos end
        end
    else
        basePos = ICF_GetAttachmentPos(ply, {"eyes", "forward"})
    end

    if not basePos then
        if anchor == "chest" then
            basePos = ply:GetPos() + Vector(0, 0, 48)
        else
            basePos = ply:EyePos()
        end
    end

    return basePos +
        ang:Right() * SafeConVarFloat("cflash_thirdperson_right", 5) +
        ang:Up() * SafeConVarFloat("cflash_thirdperson_up", -2) +
        ang:Forward() * SafeConVarFloat("cflash_thirdperson_forward", 6)
end


local function CFlashMeshVertex(pos, u, v, r, g, b, a)
    mesh.Position(pos)
    mesh.TexCoord(0, u, v)
    mesh.Color(r, g, b, a)
    mesh.AdvanceVertex()
end


local pendingVManipToggle = false
local nextCustomToggleTime = 0
local nextVManipNoticeTime = 0
local vmanipBindHandledUntil = 0
local nextVManipHookMaintenance = 0
local lastNativeStockImpulse = 0
local nextNativeStockSuppress = 0
local stockBeamGuardTrips = 0
local lastStockBeamGuardPrint = 0
local storedSmartFlashlightAnimHook = nil
local storedWBKFlashlightKeyHook = nil
local storedWBKFlashlightThinkHook = nil
local nextBridgeWeaponRequest = 0
local bridgeWeaponPendingUntil = 0
local nextVManipAnimAllowed = 0
local icfForcedEmptyHandsVManip = false
local icfForcedEmptyHandsUntil = 0
local icfLastManualVManipDrawFrame = -1
local lastVManipAnimRequest = -999
local wbkLightFollowsAnimUntil = 0
local wbkModelFollowsLightAfter = 0

ICF_WBKAnimLightLastPos = nil
ICF_WBKAnimLightLastAng = nil
ICF_WBKAnimLightBlendOutUntil = 0
ICF_WBKAnimLightBlendOutDuration = 0.32
ICF_WBKAnimLightBlendOutStartPos = nil
ICF_WBKAnimLightBlendOutStartAng = nil
ICF_WBKAnimLightHoldUntil = 0
ICF_MainLightTemporarilyHidden = false
local wbkLastDesiredLightPos = nil
local wbkLastDesiredLightAng = nil
local wbkModelFollowPitch = 0
local wbkModelFollowYaw = 0
local wbkModelFollowFrame = -1
local wbkModelFollowFade = 0
local wbkModelFollowPitchVel = 0
local wbkModelFollowYawVel = 0
local wbkModelFollowLastTargetPitch = 0
local wbkModelFollowLastTargetYaw = 0
local wbkModelFollowLastTargetTime = 0


local function GetFlashlightKey()
    if not SafeConVarBool("cflash_custom_key_enabled", false) then
        return KEY_F
    end

    local keyNum = tonumber(SafeConVarString("cflash_custom_key", tostring(KEY_F)))

    if not keyNum then
        return KEY_F
    end

    return keyNum
end


local function GetBatteryReloadKey()
    local keyNum = tonumber(SafeConVarString("cflash_battery_reload_key", tostring(KEY_N)))

    if not keyNum then
        return KEY_N
    end

    return keyNum
end


local function ICF_IsMouseButtonCode(buttonCode)
    buttonCode = tonumber(buttonCode)

    if not buttonCode then
        return false
    end

    if MOUSE_FIRST and MOUSE_LAST and buttonCode >= MOUSE_FIRST and buttonCode <= MOUSE_LAST then
        return true
    end

    return
        (MOUSE_LEFT and buttonCode == MOUSE_LEFT) or
        (MOUSE_RIGHT and buttonCode == MOUSE_RIGHT) or
        (MOUSE_MIDDLE and buttonCode == MOUSE_MIDDLE) or
        (MOUSE_4 and buttonCode == MOUSE_4) or
        (MOUSE_5 and buttonCode == MOUSE_5)
end


local function ICF_IsBindDown(buttonCode)
    buttonCode = tonumber(buttonCode)

    if not buttonCode then
        return false
    end

    if input.IsButtonDown then
        return input.IsButtonDown(buttonCode)
    end

    if ICF_IsMouseButtonCode(buttonCode) and input.IsMouseDown then
        return input.IsMouseDown(buttonCode)
    end

    if input.IsKeyDown then
        return input.IsKeyDown(buttonCode)
    end

    return false
end


local function ICF_IsMenuOrTextInputActive()
    local now = CurTime()

    local function BlockForMenu()
        ICF_MenuInputBlockedUntil = math.max(ICF_MenuInputBlockedUntil or 0, now + 0.20)
        return true
    end

    if gui then
        if gui.IsGameUIVisible and gui.IsGameUIVisible() then return BlockForMenu() end
        if gui.IsConsoleVisible and gui.IsConsoleVisible() then return BlockForMenu() end
    end

    if IsValid(g_SpawnMenu) and g_SpawnMenu:IsVisible() then return BlockForMenu() end
    if IsValid(g_ContextMenu) and g_ContextMenu:IsVisible() then return BlockForMenu() end

    if vgui then
        if vgui.GetKeyboardFocus then
            local focus = vgui.GetKeyboardFocus()

            if IsValid(focus) then
                return BlockForMenu()
            end
        end

        if vgui.CursorVisible and vgui.CursorVisible() then
            return BlockForMenu()
        end
    end

    if input and input.IsKeyDown then
        if KEY_Q and input.IsKeyDown(KEY_Q) then return BlockForMenu() end
        if KEY_C and input.IsKeyDown(KEY_C) then return BlockForMenu() end
    end

    if hook and hook.GetTable then
        local hooks = hook.GetTable()
        local bindHooks = hooks and hooks.PlayerBindPress

        if bindHooks and bindHooks.wire_keyboard_blockinput then
            return BlockForMenu()
        end
    end

    if now < (ICF_MenuInputBlockedUntil or 0) then
        return true
    end

    return false
end

local ICF_LastWebKnightShoulderBindDown = false
local ICF_NextWebKnightShoulderBind = 0

local function ICF_GetWebKnightShoulderKey()
    local keyNum = tonumber(SafeConVarString("cflash_vmanip_webknight_shoulder_key", "0"))

    if not keyNum then
        return 0
    end

    return keyNum
end

local function ICF_HandleWebKnightShoulderBind()
    if ICF_IsMenuOrTextInputActive() then
        ICF_LastWebKnightShoulderBindDown = false
        return
    end

    if not SafeConVarBool("cflash_vmanip_webknight_shoulder_key_enabled", false) then
        ICF_LastWebKnightShoulderBindDown = false
        return
    end

    local keyNum = ICF_GetWebKnightShoulderKey()

    if keyNum <= 0 then
        ICF_LastWebKnightShoulderBindDown = false
        return
    end

    local down = ICF_IsBindDown(keyNum)

    if not down then
        ICF_LastWebKnightShoulderBindDown = false
        return
    end

    if ICF_LastWebKnightShoulderBindDown then return end

    ICF_LastWebKnightShoulderBindDown = true

    if not SafeConVarBool("cflash_vmanip_compat", false) then return end
    local shoulderBackendMode = string.lower(SafeConVarString("cflash_vmanip_mode", "default"))
    if shoulderBackendMode ~= "webknight" and shoulderBackendMode ~= "gcal" then return end
    if not VManip then return end

    local cmdTable = concommand.GetTable and concommand.GetTable() or nil

    if not cmdTable or not cmdTable.putFlashlightOnShoulder then
        return
    end

    local now = CurTime()

    if now < ICF_NextWebKnightShoulderBind then return end

    ICF_NextWebKnightShoulderBind = now + 0.45

    RunConsoleCommand("putFlashlightOnShoulder")
end


local function ICF_GetVManipLockout()
    local mode = string.lower(SafeConVarString("cflash_vmanip_mode", "default"))
    local minimum = 1.15

    if mode == "webknight" or mode == "wbk" or mode == "vmanip_flashlight" or mode == "gcal" then
        minimum = 1.95
    end

    return math.max(SafeConVarFloat("cflash_vmanip_anim_lockout", minimum), minimum)
end

local function ICF_GetVManipLockoutForAnim(animName)
    local mode = string.lower(SafeConVarString("cflash_vmanip_mode", "default"))

    if mode == "webknight" or mode == "wbk" or mode == "vmanip_flashlight" or mode == "gcal" then
        if animName == "Flashlight_In" or animName == "Flashlight_Out" then
            return mode == "gcal" and 1.55 or 1.15
        end

        if animName == "Flashlight_EnableDisable" then
            return mode == "gcal" and 2.15 or 1.75
        end
    end

    return ICF_GetVManipLockout()
end

local function ICF_StartVManipCooldown(lockoutOverride)
    local untilTime = CurTime() + (lockoutOverride or ICF_GetVManipLockout())

    nextVManipAnimAllowed = untilTime
    vmanipBindHandledUntil = math.max(vmanipBindHandledUntil or 0, untilTime)
    nextCustomToggleTime = math.max(nextCustomToggleTime or 0, untilTime)
end


ICF_GetVManipMode = function()
    local mode = string.lower(SafeConVarString("cflash_vmanip_mode", "default"))

    if mode == "webknight" or mode == "wbk" or mode == "vmanip_flashlight" then
        return "webknight"
    end

    if mode == "gcal" or mode == "gmod_compliant_armature_layer" then
        return "webknight"
    end

    return "default"
end

local function ICF_GetCurrentVManipAnimName()
    if VManip and isfunction(VManip.GetCurrentAnim) then
        return tostring(VManip:GetCurrentAnim() or "")
    end

    return ""
end

local function ICF_WebKnightShouldUseEnableDisableToggle()
    if ICF_GetVManipMode() ~= "webknight" then return false end

    if WBK_IsFlashlightOnShoulder == true then return true end

    if not enabled and ICF_GetCurrentVManipAnimName() == "Flashlight_Shoulder_Take" then
        return true
    end

    return false
end

local function ICF_GetVManipToggleAnimName()
    if ICF_GetVManipMode() == "webknight" then
        if ICF_WebKnightShouldUseEnableDisableToggle() then
            return "Flashlight_EnableDisable"
        end

        if enabled then
            return "Flashlight_Out"
        end

        return "Flashlight_In"
    end

    return "Flashlight_EnableDisable"
end

local function ICF_GetVManipToggleDelay(animName)
    if ICF_GetVManipMode() == "webknight" then
        if animName == "Flashlight_Out" then return 0.30 end
        if animName == "Flashlight_In" then return 0.40 end
        if animName == "Flashlight_EnableDisable" then return 0.25 end
    end

    return 0.40
end

local function ICF_SyncWebKnightLightMirror()
    if ICF_GetVManipMode() ~= "webknight" then return end

    if WBK_IsFlashlightOnShoulder == true then
        WBK_FlashlightIsActive = true
    else
        WBK_FlashlightIsActive = enabled == true
    end
end

local function ICF_ClearWBKFlashlightObject(preserveActiveMirror)
    if IsValid(WBK_FlashlightObject) then
        WBK_FlashlightObject:Remove()
    end

    WBK_FlashlightObject = nil

    if preserveActiveMirror then
        ICF_SyncWebKnightLightMirror()
    else
        WBK_FlashlightIsActive = false
    end
end

local function ApplyPositionOffset(pos, ang)
    local rightOffset = SafeConVarFloat("cflash_offset_right", 0)
    local upOffset = SafeConVarFloat("cflash_offset_up", 0)
    local forwardOffset = SafeConVarFloat("cflash_offset_forward", 0)

    if rightOffset == 0 and upOffset == 0 and forwardOffset == 0 then
        return pos
    end

    return pos +
        ang:Right() * rightOffset +
        ang:Up() * upOffset +
        ang:Forward() * forwardOffset
end


local function ICF_ClassListContains(listString, className)
    if not className or className == "" then return false end

    className = string.lower(className)
    listString = string.lower(tostring(listString or ""))

    for token in string.gmatch(listString, "([^,%s;]+)") do
        token = string.Trim(token)

        if token ~= "" and token == className then
            return true
        end
    end

    return false
end

local function ICF_IsHandsLikeWeapon(wep)
    if not IsValid(wep) then return true end

    local className = ""

    if wep.GetClass then
        className = tostring(wep:GetClass() or "")
    end

    className = string.lower(className)

    if className == "weapon_icf_vmanip_bridge" then
        return true
    end

    local configured = SafeConVarString("cflash_vmanip_bridge_hands_classes", "weapon_hands,gmod_hands,weapon_fists,hands,weapon_empty_hands")

    if ICF_ClassListContains(configured, className) then
        return true
    end

    if string.find(className, "hands", 1, true) then
        return true
    end

    return false
end


local function ICF_RequestVManipBridgeWeapon()
    if CurTime() < nextBridgeWeaponRequest then return false end
    nextBridgeWeaponRequest = CurTime() + 0.65

    if not SafeConVarBool("cflash_vmanip_compat", false) then return false end
    if not SafeConVarBool("cflash_vmanip_emptyhands_bridge", false) then return false end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then return false end

    local active = ply:GetActiveWeapon()

    if IsValid(active) and active:GetClass() == "weapon_icf_vmanip_bridge" then
        return true
    end

    if IsValid(active) and not ICF_IsHandsLikeWeapon(active) then
        return false
    end

    bridgeWeaponPendingUntil = CurTime() + 0.5

    net.Start("ICF_VManipBridgeWeapon")
    net.WriteBool(true)
    net.SendToServer()

    return true
end


function ICF_ClearVManipBridgeWeapon()
    bridgeWeaponPendingUntil = 0
    icfForcedEmptyHandsVManip = false
    icfForcedEmptyHandsUntil = 0

    if not net then return end

    pcall(function()
        net.Start("ICF_VManipBridgeWeapon")
        net.WriteBool(false)
        net.SendToServer()
    end)
end
cvars.AddChangeCallback("cflash_vmanip_compat", function(_, _, newValue)
    if tostring(newValue) == "0" or tostring(newValue) == "false" then
        if _G.ICF_ClearVManipBridgeWeapon then
            _G.ICF_ClearVManipBridgeWeapon()
        end

        if VManip and isfunction(VManip.Remove) then
            pcall(function()
                VManip:Remove()
            end)
        end

        pendingVManipToggle = false
        nextVManipAnimAllowed = 0
        vmanipBindHandledUntil = 0
        nextCustomToggleTime = 0
        nextVManipHookMaintenance = 0
        if isfunction(MaintainVManipDefaultFlashlightHook) then
            MaintainVManipDefaultFlashlightHook(true)
        end
    else
        nextVManipHookMaintenance = 0
        if isfunction(MaintainVManipDefaultFlashlightHook) then
            MaintainVManipDefaultFlashlightHook(true)
        end
    end
end, "ICF_ClearBridgeWhenVManipDisabled")

cvars.AddChangeCallback("cflash_vmanip_emptyhands_bridge", function(_, _, newValue)
    if tostring(newValue) == "0" or tostring(newValue) == "false" then
        if _G.ICF_ClearVManipBridgeWeapon then
            _G.ICF_ClearVManipBridgeWeapon()
        end
    end
end, "ICF_ClearBridgeWhenBridgeDisabled")

hook.Add("Think", "ICF_VManipBridgeCleanupWhenDisabled", function()
    if SafeConVarBool("cflash_enabled", true)
        and SafeConVarBool("cflash_vmanip_compat", false)
        and SafeConVarBool("cflash_vmanip_emptyhands_bridge", false) then
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local active = ply:GetActiveWeapon()

    if IsValid(active) and active:GetClass() == "weapon_icf_vmanip_bridge" then
        if _G.ICF_ClearVManipBridgeWeapon then
            _G.ICF_ClearVManipBridgeWeapon()
        end
    end
end)


local function ICF_HasOrWantsVManipBridgeWeapon()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end

    local active = ply:GetActiveWeapon()

    if IsValid(active) and active:GetClass() == "weapon_icf_vmanip_bridge" then
        return true
    end

    return CurTime() < bridgeWeaponPendingUntil
end

local function ICF_MaintainVManipBridgeForEmptyHands()
    if not SafeConVarBool("cflash_vmanip_compat", false) then return end
    if not SafeConVarBool("cflash_vmanip_emptyhands_bridge", false) then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then return end

    local active = ply:GetActiveWeapon()

    if IsValid(active) and active:GetClass() == "weapon_icf_vmanip_bridge" then
        return
    end

    if ICF_IsHandsLikeWeapon(active) then
        ICF_RequestVManipBridgeWeapon()
    end
end


function ICF_IsFlashlightCompatAnimName(animName)
    animName = tostring(animName or "")

    if animName == "" then return false end
    if animName == "Flashlight_EnableDisable" then return true end
    if animName == "Flashlight_In" then return true end
    if animName == "Flashlight_Out" then return true end
    if string.find(animName, "Flashlight_Shoulder", 1, true) then return true end

    return false
end

function ICF_DisableGCALFlashlightCamera(track)
    if not track then return end

    track.camAngInt = {0, 0, 0}
    track.Cam_AngInt = {0, 0, 0}
    track.camAng = nil
    track.Cam_Ang = nil
    track.attachment = nil
    track.Attachment = nil

    if IsValid(track.camModel) then
        track.camModel:Remove()
    end

    if IsValid(track.CamModel) then
        track.CamModel:Remove()
    end

    track.camModel = nil
    track.CamModel = nil
end

function ICF_DisableVManipFlashlightCamera()
    if not VManip then return end

    local currentAnim = ""
    if isfunction(VManip.GetCurrentAnim) then
        currentAnim = tostring(VManip:GetCurrentAnim() or "")
    else
        currentAnim = tostring(VManip.CurGesture or "")
    end

    if not ICF_IsFlashlightCompatAnimName(currentAnim) then return end

    VManip.Cam_AngInt = {0, 0, 0}
    VManip.Cam_Ang = angle_zero or Angle(0, 0, 0)
    VManip.Attachment = nil
end

hook.Add("GCALTrackStarted", "ICF_GCALShimCameraPassthrough", function(trackID, name, track)
    if not SafeConVarBool("cflash_vmanip_compat", false) then return end
    if not ICF_IsFlashlightCompatAnimName(name) then return end

    ICF_DisableGCALFlashlightCamera(track)
end)

hook.Add("Think", "ICF_CompatAnimationCameraPassthroughThink", function()
    if not SafeConVarBool("cflash_vmanip_compat", false) then return end

    if GCAL and GCAL.ActiveTracks then
        for _, track in pairs(GCAL.ActiveTracks) do
            local name = track and (track.name or track.animName or track.anim or track.current)
            if track and ICF_IsFlashlightCompatAnimName(name) then
                ICF_DisableGCALFlashlightCamera(track)
            end
        end
    end

    ICF_DisableVManipFlashlightCamera()
end)

local function EnsureVManipFlashlightAnim(animName)
    animName = animName or ICF_GetVManipToggleAnimName()

    if not VManip or not isfunction(VManip.GetAnim) then
        return false
    end

    if VManip:GetAnim(animName) then
        return true
    end

    pcall(function()
        include("vmanip/anims/vm_anipflashlight_anims.lua")
    end)

    if VManip:GetAnim(animName) then
        return true
    end

    pcall(function()
        RunConsoleCommand("VManip_FindAndImport")
    end)

    return VManip:GetAnim(animName) ~= nil
end

local function ForcePlayVManipFlashlightAnim(animName)
    animName = animName or ICF_GetVManipToggleAnimName()
    if not SafeConVarBool("cflash_vmanip_compat", false) then return false end
    if not VManip or not isfunction(VManip.GetAnim) then return false end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then return false end
    if ply:GetViewEntity() ~= ply and not VManip:IsActive() then return false end
    if VManip:IsActive() then return false end

    local vm = ply:GetViewModel()
    if not IsValid(vm) then return false end

    if not EnsureVManipFlashlightAnim(animName) then return false end

    local animtoplay = VManip:GetAnim(animName)
    if not animtoplay then return false end

    if hook.Run("VManipPrePlayAnim", animName) == false then
        return false
    end

    local now = CurTime()
    local properang = Angle(-79.750, 0, -90)
    local tableintensity = {1, 1, 1}

    pcall(function()
        if isfunction(VManip.Remove) then
            VManip.Remove()
        end
    end)

    VManip.GesturePastHold = false
    VManip.GestureOnHold = false
    VManip.CurGestureData = animtoplay
    VManip.CurGesture = animName
    VManip.Lerp_Peak = now + (animtoplay["lerp_peak"] or 0.75)
    vmatrixpeakinfo = animtoplay["lerp_peak"] or 0.75
    VManip.Lerp_Speed_In = animtoplay["lerp_speed_in"] or 1
    VManip.Lerp_Speed_Out = animtoplay["lerp_speed_out"] or 1
    VManip.Loop = animtoplay["loop"]
    VManip_modelname = animtoplay["model"]
    vmanipholdtime = animtoplay["holdtime"]

    if not VManip_modelname then return false end

    VManip.VMGesture = ClientsideModel("models/" .. VManip_modelname, RENDERGROUP_BOTH)
    VManip.VMCam = ClientsideModel("models/" .. VManip_modelname, RENDERGROUP_BOTH)

    if not IsValid(VManip.VMGesture) or not IsValid(VManip.VMCam) then
        if IsValid(VManip.VMGesture) then VManip.VMGesture:Remove() end
        if IsValid(VManip.VMCam) then VManip.VMCam:Remove() end
        return false
    end

    VManip.Cam_AngInt = {0, 0, 0}
    VManip.SeqID = VManip.VMGesture:LookupSequence(animName)

    if VManip.SeqID == -1 then
        VManip.VMGesture:Remove()
        VManip.VMCam:Remove()
        VManip.VMGesture = nil
        VManip.VMCam = nil
        return false
    end

    if animtoplay["assurepos"] then
        VManip.VMGesture:SetPos(ply:EyePos())
        VManip.AssurePos = true
    elseif not animtoplay["locktoply"] then
        VManip.VMGesture:SetPos(vm:GetPos())
    end

    if animtoplay["locktoply"] then
        VManip.LockToPly = true
        local eyepos = ply:EyePos()
        VManip.VMGesture:SetAngles(ply:EyeAngles())
        VManip.VMGesture:SetPos(eyepos)
        VManip.LockZ = eyepos.z
    else
        VManip.VMGesture:SetAngles(vm:GetAngles())
        VManip.VMGesture:SetParent(vm)
    end

    VManip.Cam_Ang = animtoplay["cam_ang"] or properang
    VManip.VMCam:SetPos(vector_origin)
    VManip.VMCam:SetAngles(angle_zero)

    VManip.VMGesture:ResetSequenceInfo()
    VManip.VMGesture:SetPlaybackRate(1)
    VManip.VMGesture:ResetSequence(VManip.SeqID)

    VManip.VMCam:ResetSequenceInfo()
    VManip.VMCam:SetPlaybackRate(1)
    VManip.VMCam:ResetSequence(VManip.SeqID)

    VManip.VMatrixlerp = 1
    VManip.Speed = animtoplay["speed"] or 1
    VManip.Lerp_Curve = animtoplay["lerp_curve"] or 1
    VManip.StartCycle = animtoplay["startcycle"] or 0
    VManip.Segmented = animtoplay["segmented"] or false
    VManip.HoldTime = animtoplay["holdtime"] or nil
    VManip.HoldTimeData = VManip.HoldTime
    VManip.PreventQuit = animtoplay["preventquit"] or false

    if VManip.HoldTime then
        VManip.HoldTime = now + VManip.HoldTime
    end

    VManip.Cycle = VManip.StartCycle
    VManip.VMGesture:SetNoDraw(true)
    VManip.VMCam:SetNoDraw(true)
    VManip.Duration = VManip.VMGesture:SequenceDuration(VManip.SeqID)

    hook.Run("VManipPostPlayAnim", animName)

    icfForcedEmptyHandsVManip = true
    icfForcedEmptyHandsUntil = CurTime() + math.max((VManip.Duration or 1.0) + 0.35, 1.2)

    lastVManipAnimRequest = CurTime()
    return true
end


ICF_WebKnightBatteryDepletedRecovery = function()
    if ICF_GetVManipMode() ~= "webknight" then return end

    pendingVManipToggle = false
    wbkLightFollowsAnimUntil = 0
    wbkModelFollowsLightAfter = 0
    wbkLastDesiredLightPos = nil
    wbkLastDesiredLightAng = nil
    wbkModelFollowPitch = 0
    wbkModelFollowYaw = 0
    wbkModelFollowFrame = -1
    wbkModelFollowPitchVel = 0
    wbkModelFollowYawVel = 0
    wbkModelFollowLastTargetPitch = 0
    wbkModelFollowLastTargetYaw = 0
    wbkModelFollowLastTargetTime = 0
    wbkModelFollowFade = 0

    if isfunction(ICF_ClearWBKFlashlightObject) then
        ICF_ClearWBKFlashlightObject()
    end

    if VManip and isfunction(VManip.IsActive) and VManip:IsActive() then
        local current = ""

        if isfunction(VManip.GetCurrentAnim) then
            current = tostring(VManip:GetCurrentAnim() or "")
        end

        local playedOut = false

        if (current == "Flashlight_In" or current == "Flashlight_Shoulder_Take")
            and isfunction(VManip.PlaySegment)
            and isfunction(EnsureVManipFlashlightAnim)
            and EnsureVManipFlashlightAnim("Flashlight_Out") then

            local ok, result = pcall(function()
                return VManip:PlaySegment("Flashlight_Out", true)
            end)

            playedOut = ok and result == true
        end

        if not playedOut and isfunction(VManip.Remove) then
            pcall(function()
                VManip:Remove()
            end)
        elseif playedOut then
            wbkLightFollowsAnimUntil = CurTime() + 0.75

            timer.Simple(1.2, function()
                if enabled then return end
                if not VManip or not isfunction(VManip.GetCurrentAnim) then return end

                local stillCurrent = tostring(VManip:GetCurrentAnim() or "")

                if stillCurrent == "Flashlight_In" or stillCurrent == "Flashlight_Out" then
                    if isfunction(VManip.Remove) then
                        pcall(function()
                            VManip:Remove()
                        end)
                    end
                end
            end)
        end
    end

    nextVManipAnimAllowed = CurTime() + 0.35
    vmanipBindHandledUntil = CurTime() + 0.35
    nextCustomToggleTime = CurTime() + 0.35
end

local function TryPlayVManipFlashlightAnim(animName)
    animName = animName or ICF_GetVManipToggleAnimName()

    if not SafeConVarBool("cflash_vmanip_compat", false) then
        return false
    end

    local ply = LocalPlayer()

    if not IsValid(ply) or not ply:Alive() then
        return false
    end

    if not VManip or not isfunction(VManip.PlayAnim) then
        return false
    end

    local vm = ply:GetViewModel()

    if not IsValid(vm) then
        return false
    end

    if not EnsureVManipFlashlightAnim(animName) then
        return false
    end

    local ok, result = pcall(function()
        if ICF_GetVManipMode() == "webknight" and animName == "Flashlight_Out" and isfunction(VManip.PlaySegment) then
            local current = ""

            if isfunction(VManip.GetCurrentAnim) then
                current = tostring(VManip:GetCurrentAnim() or "")
            end

            if current == "Flashlight_In" or current == "Flashlight_Shoulder_Take" then
                return VManip:PlaySegment("Flashlight_Out", true)
            end
        end

        return VManip:PlayAnim(animName)
    end)

    if ok and result == true then
        lastVManipAnimRequest = CurTime()
        ICF_DisableVManipFlashlightCamera()
        return true
    end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then
        return ForcePlayVManipFlashlightAnim(animName)
    end

    return false
end

function MaintainVManipDefaultFlashlightHook(force)
    local icflEnabled = SafeConVarBool("cflash_enabled", true)
    local strictGuard = icflEnabled and SafeConVarBool("cflash_vmanip_strict_hook_guard", true)

    if not force and CurTime() < nextVManipHookMaintenance then return end

    nextVManipHookMaintenance = CurTime() + (strictGuard and 0.03 or 0.5)

    local hooks = hook.GetTable()
    local bindHooks = hooks.PlayerBindPress
    local thinkHooks = hooks.Think

    if not bindHooks then return end

    local shouldQuarantine = true

    if not icflEnabled then
        shouldQuarantine = true
    end

    if shouldQuarantine then
        if bindHooks.SmartFlashlightAnim then
            storedSmartFlashlightAnimHook = storedSmartFlashlightAnimHook or bindHooks.SmartFlashlightAnim
            hook.Remove("PlayerBindPress", "SmartFlashlightAnim")
        end

        if bindHooks.FlashLight_KeyPress then
            storedWBKFlashlightKeyHook = storedWBKFlashlightKeyHook or bindHooks.FlashLight_KeyPress
            hook.Remove("PlayerBindPress", "FlashLight_KeyPress")
        end

        if thinkHooks and thinkHooks.FlashLight_EnableFlashlight then
            storedWBKFlashlightThinkHook = storedWBKFlashlightThinkHook or thinkHooks.FlashLight_EnableFlashlight
            hook.Remove("Think", "FlashLight_EnableFlashlight")
        end

        ICF_ClearWBKFlashlightObject(true)
        return
    end

    if storedSmartFlashlightAnimHook and not bindHooks.SmartFlashlightAnim then
        hook.Add("PlayerBindPress", "SmartFlashlightAnim", storedSmartFlashlightAnimHook)
        storedSmartFlashlightAnimHook = nil
    end

    if storedWBKFlashlightKeyHook and not bindHooks.FlashLight_KeyPress then
        hook.Add("PlayerBindPress", "FlashLight_KeyPress", storedWBKFlashlightKeyHook)
        storedWBKFlashlightKeyHook = nil
    end

    if storedWBKFlashlightThinkHook then
        local currentThinkHooks = hook.GetTable().Think or {}

        if not currentThinkHooks.FlashLight_EnableFlashlight then
            hook.Add("Think", "FlashLight_EnableFlashlight", storedWBKFlashlightThinkHook)
        end

        storedWBKFlashlightThinkHook = nil
    end
end

cvars.AddChangeCallback("cflash_vmanip_strict_hook_guard", function()
    nextVManipHookMaintenance = 0
    MaintainVManipDefaultFlashlightHook(true)
end, "ICF_StrictVManipHookGuardToggle")

cvars.AddChangeCallback("cflash_enabled", function(_, _, newValue)
    if tostring(newValue) == "0" or tostring(newValue) == "false" then
        if enabled then
            enabled = false

            if isfunction(DestroyLight) then
                DestroyLight()
            end
        end

        pendingVManipToggle = false
        nextCustomToggleTime = 0
        vmanipBindHandledUntil = 0
        nextVManipAnimAllowed = 0
        if _G.ICF_ClearVManipBridgeWeapon then
            _G.ICF_ClearVManipBridgeWeapon()
        end


        nextVManipHookMaintenance = 0
        MaintainVManipDefaultFlashlightHook()
    end
end, "ICF_RestoreHooksWhenDisabled")


local function ICF_ShouldSwallowVManipAnimFail(animName, animAvailable)
    if ICF_GetVManipMode() ~= "webknight" then return false end
    if not animAvailable then return false end

    return animName == "Flashlight_In" or animName == "Flashlight_Out"
end

local function ICF_HandleWebKnightShoulderLightToggle()
    if not ICF_WebKnightShouldUseEnableDisableToggle() then return false end

    local now = CurTime()
    local animName = "Flashlight_EnableDisable"
    local toggleDelay = ICF_GetVManipToggleDelay(animName)
    local animAvailable = EnsureVManipFlashlightAnim(animName)
    local played = false

    ICF_StartVManipCooldown(ICF_GetVManipLockoutForAnim(animName))

    if animAvailable then
        played = TryPlayVManipFlashlightAnim(animName)
    end

    if played then
        pendingVManipToggle = true

        timer.Simple(toggleDelay, function()
            pendingVManipToggle = false

            if not SafeConVarBool("cflash_enabled", true) then return end

            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            if not ply:Alive() then return end

            DoFlashlightToggle()
            ICF_ClearWBKFlashlightObject(true)
        end)
    else
        DoFlashlightToggle()
        ICF_ClearWBKFlashlightObject(true)
    end

    return true
end

local function HandleVManipFlashlightBindPress()
    if not SafeConVarBool("cflash_vmanip_compat", false) then
        return false
    end

    local plyForThirdPerson = LocalPlayer()

    if ICF_GetVManipMode() == "webknight" and ICF_IsThirdPersonActive(plyForThirdPerson) then
        pendingVManipToggle = false
        ICF_ClearWBKFlashlightObject()
        DoFlashlightToggle()

        nextVManipAnimAllowed = CurTime() + 0.25
        vmanipBindHandledUntil = CurTime() + 0.25
        nextCustomToggleTime = CurTime() + 0.25

        return true
    end

    if CurTime() < nextVManipAnimAllowed then
        vmanipBindHandledUntil = math.max(vmanipBindHandledUntil or 0, nextVManipAnimAllowed)
        nextCustomToggleTime = math.max(nextCustomToggleTime or 0, nextVManipAnimAllowed)
        return true
    end

    if pendingVManipToggle then
        return true
    end

    if CurTime() < nextCustomToggleTime then
        return true
    end

    if ICF_HandleWebKnightShoulderLightToggle() then
        return true
    end

    local ply = LocalPlayer()
    local active = IsValid(ply) and ply:GetActiveWeapon() or nil

    if IsValid(ply)
        and SafeConVarBool("cflash_vmanip_emptyhands_bridge", false)
        and ICF_IsHandsLikeWeapon(active)
        and (not IsValid(active) or active:GetClass() ~= "weapon_icf_vmanip_bridge") then

        ICF_RequestVManipBridgeWeapon()

        pendingVManipToggle = true
        vmanipBindHandledUntil = CurTime() + 1.0
        nextCustomToggleTime = CurTime() + 0.05
        ICF_StartVManipCooldown()

        timer.Simple(0.30, function()
            pendingVManipToggle = false
            nextCustomToggleTime = 0

            if not SafeConVarBool("cflash_enabled", true) then return end

            local ply2 = LocalPlayer()
            if not IsValid(ply2) or not ply2:Alive() then return end

            local active2 = ply2:GetActiveWeapon()

            if IsValid(active2) and active2:GetClass() == "weapon_icf_vmanip_bridge" then
                nextVManipAnimAllowed = 0
                HandleVManipFlashlightBindPress()
            else
                DoFlashlightToggle()
            end
        end)

        return true
    end

    local animName = ICF_GetVManipToggleAnimName()
    local toggleDelay = ICF_GetVManipToggleDelay(animName)
    local animAvailable = EnsureVManipFlashlightAnim(animName)
    local played = false

    nextCustomToggleTime = CurTime() + 0.7
    vmanipBindHandledUntil = CurTime() + 0.45
    ICF_StartVManipCooldown(ICF_GetVManipLockoutForAnim(animName))

    if animAvailable then
        played = TryPlayVManipFlashlightAnim(animName)
    end

    if played then
        pendingVManipToggle = true

        if ICF_GetVManipMode() == "webknight" then
            local now = CurTime()

            if animName == "Flashlight_In" then
                wbkModelFollowPitch = 0
                wbkModelFollowYaw = 0
                wbkModelFollowFrame = -1
                wbkModelFollowFade = 0
                wbkModelFollowPitchVel = 0
                wbkModelFollowYawVel = 0
                wbkModelFollowLastTargetPitch = 0
                wbkModelFollowLastTargetYaw = 0
                wbkModelFollowLastTargetTime = 0
                wbkLightFollowsAnimUntil = now + math.max(toggleDelay, SafeConVarFloat("cflash_vmanip_webknight_model_follow_delay", 1.10))
                ICF_WBKAnimLightBlendOutUntil = wbkLightFollowsAnimUntil + (ICF_WBKAnimLightBlendOutDuration or 0.32)
                ICF_WBKAnimLightHoldUntil = ICF_WBKAnimLightBlendOutUntil + 0.10
                ICF_WBKAnimLightBlendOutStartPos = nil
                ICF_WBKAnimLightBlendOutStartAng = nil
                wbkModelFollowsLightAfter = now + SafeConVarFloat("cflash_vmanip_webknight_model_follow_delay", 1.10)
            elseif animName == "Flashlight_Out" then
                wbkLightFollowsAnimUntil = now + toggleDelay + 0.25
                ICF_WBKAnimLightBlendOutUntil = 0
                ICF_WBKAnimLightHoldUntil = wbkLightFollowsAnimUntil + 0.10
                ICF_WBKAnimLightBlendOutStartPos = nil
                ICF_WBKAnimLightBlendOutStartAng = nil
                wbkModelFollowsLightAfter = 0
            end
        end

        timer.Simple(toggleDelay, function()
            pendingVManipToggle = false

            if not SafeConVarBool("cflash_enabled", true) then return end

            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            if not ply:Alive() then return end

            DoFlashlightToggle()
        end)
    else
        if ICF_ShouldSwallowVManipAnimFail(animName, animAvailable) then
            ICF_StartVManipCooldown()
            return true
        end

        DoFlashlightToggle()
    end

    return true
end

RequestFlashlightToggle = function()
    if ICF_IsMenuOrTextInputActive() then
        lastF = ICF_IsBindDown(GetFlashlightKey())
        lastBatteryReloadKey = ICF_IsBindDown(GetBatteryReloadKey())
        return
    end

    if pendingVManipToggle then return end

    if SafeConVarBool("cflash_vmanip_compat", false) then
        if CurTime() < nextVManipAnimAllowed then
            vmanipBindHandledUntil = math.max(vmanipBindHandledUntil or 0, nextVManipAnimAllowed)
            nextCustomToggleTime = math.max(nextCustomToggleTime or 0, nextVManipAnimAllowed)
            return
        end

        if CurTime() < nextCustomToggleTime then return end

        HandleVManipFlashlightBindPress()
        return
    end

    if CurTime() < nextCustomToggleTime then return end

    nextCustomToggleTime = CurTime() + 0.25
    DoFlashlightToggle()
end

PlayToggleSound = function()
    if SafeConVarBool("cflash_play_sound", true) then
        FF_PlaySurfaceSound(
            tostring(flashlightConfig.ToggleSoundPath or "foundfootage/flashlight_toggle.wav")
        )
    end
end

DestroyLight = function()
    if IsValid(proj) then
        proj:Remove()
    end

    proj = nil

    if isfunction(ICF_RemoveLightspill) then
        ICF_RemoveLightspill()
    end
end


CreateLight = function()
    DestroyLight()

    if not ICF_BatteryCanTurnOn() then
        enabled = false
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local ang = ply:EyeAngles()

    pitch = ang.p
    yaw = ang.y
    pitchVel = 0
    yawVel = 0

    fearX = 0
    fearY = 0
    fearTargetX = 0
    fearTargetY = 0

    walkBlend = 0
    sprintBlend = 0
    sprintBobPhase = 0

    proj = ProjectedTexture()
    if not proj then return end

    proj:SetTexture(GetFlashlightTexture())
    proj:SetEnableShadows(ICF_ShouldEnableProjectedShadows())
    proj:SetBrightness(ICF_GetEffectiveBrightness())
    proj:SetColor(GetFlashlightColor())
    proj:SetFOV(SafeConVarFloat("cflash_fov", 40))
    proj:SetFarZ(SafeConVarFloat("cflash_farz", 1837))
    proj:SetNearZ(ICF_GetProjectedNearZ(2))

    local startPos = ply:EyePos()
    local startAng = ang
    local startHidden = false

    if isfunction(ICF_GetCompatAnimLightInitialTransform) then
        local animPos, animAng = ICF_GetCompatAnimLightInitialTransform()
        if animPos and animAng then
            startPos = animPos
            startAng = animAng
        elseif isfunction(ICF_IsCompatAnimLightTransitionActive) and ICF_IsCompatAnimLightTransitionActive() then
            startHidden = true
        end
    end

    if startHidden then
        proj:SetBrightness(0)
    end

    proj:SetPos(startPos)
    proj:SetAngles(startAng)
    proj:Update()

    ICF_StartStartupFlicker()
end

local function Spring(pos, vel, target, strength, damping, dt)
    local force = (target - pos) * strength
    vel = vel + force * dt
    vel = vel * math.exp(-damping * dt)
    pos = pos + vel * dt
    return pos, vel
end

local function ICF_ForceNativeStockFlashlight()
    local now = CurTime()

    if now < (lastNativeStockImpulse or 0) then
        return
    end

    lastNativeStockImpulse = now + 0.12

    RunConsoleCommand("impulse", "100")
end


local function ICF_SuppressNativeStockFlashlight(force)
    if not ICF_ShouldForceStockFlashlightOff() then return end

    local now = CurTime()
    if not force and now < (nextNativeStockSuppress or 0) then return end
    nextNativeStockSuppress = now + 0.08

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not ply.FlashlightIsOn or not ply:FlashlightIsOn() then return end

    stockBeamGuardTrips = (stockBeamGuardTrips or 0) + 1

    if SafeConVarBool("cflash_stock_beam_guard_debug", false) and now >= (lastStockBeamGuardPrint or 0) then
        lastStockBeamGuardPrint = now + 0.75
        print("[ICFL] Stock flashlight guard tripped #" .. tostring(stockBeamGuardTrips) .. " - native GMod/VManip beam was on while ICFL stock blocking was active. Turning it back off.")
    end

    lastNativeStockImpulse = now + 0.12
    RunConsoleCommand("impulse", "100")
end


concommand.Add("cflash_stock_beam_guard_status", function()
    local ply = LocalPlayer()
    print("----- ICFL Stock Beam Guard Status -----")
    print("ICFL enabled = " .. tostring(SafeConVarBool("cflash_enabled", true)))
    print("Stock flashlight force-blocked while ICFL enabled = " .. tostring(ICF_ShouldForceStockFlashlightOff()))
    print("VManip compatibility = " .. tostring(SafeConVarBool("cflash_vmanip_compat", false)))
    print("Strict VManip hook guard = " .. tostring(SafeConVarBool("cflash_vmanip_strict_hook_guard", true)))
    print("Debug prints = " .. tostring(SafeConVarBool("cflash_stock_beam_guard_debug", false)))
    print("Guard trip count = " .. tostring(stockBeamGuardTrips or 0))
    if IsValid(ply) and ply.FlashlightIsOn then
        print("Native flashlight currently on = " .. tostring(ply:FlashlightIsOn()))
    else
        print("Native flashlight currently on = unknown")
    end
    print("----------------------------------------")
end)

hook.Add("PlayerBindPress", "CustomFlashlight_BlockStock", function(_, bind, pressed)
    bind = string.lower(bind or "")

    MaintainVManipDefaultFlashlightHook(true)

    ICF_SuppressNativeStockFlashlight(true)

    if not SafeConVarBool("cflash_enabled", true) then
        if ICF_IsMenuOrTextInputActive() then
            if string.find(bind, "impulse 100", 1, true) then return true end
            return
        end

        if string.find(bind, "impulse 100", 1, true) then
            if pressed == false then return true end
            ICF_ForceNativeStockFlashlight()
            return true
        end

        return
    end

    if ICF_IsMenuOrTextInputActive() then
        if string.find(bind, "impulse 100", 1, true) then return true end
        if string.find(bind, "+reload", 1, true) then return end
        return
    end

    if string.find(bind, "+reload", 1, true) then
        if pressed == false then return end

        if not SafeConVarBool("cflash_battery_reload_allow_weapon_reload", false) then
            return
        end

        if ICF_StartBatteryReload() then
            return true
        end
    end

    if string.find(bind, "impulse 100", 1, true) then
        if SafeConVarBool("cflash_vmanip_compat", false) then
            if pressed == false then return true end
            return HandleVManipFlashlightBindPress()
        end

        if pressed == false then return true end

        lastF = true
        vmanipBindHandledUntil = CurTime() + 0.20
        RequestFlashlightToggle()

        return true
    end
end)

local function ICF_GetWebKnightVManipGestureModel()
    if not VManip then return nil end

    if isfunction(VManip.GetVMGesture) then
        local ok, mdl = pcall(function()
            return VManip:GetVMGesture()
        end)

        if ok and IsValid(mdl) then
            return mdl
        end
    end

    if IsValid(VManip.VMGesture) then
        return VManip.VMGesture
    end

    return nil
end

local function ICF_GetWebKnightVManipLightTransform()
    if not SafeConVarBool("cflash_vmanip_compat", false) then return nil end
    if ICF_GetVManipMode() ~= "webknight" then return nil end
    if not SafeConVarBool("cflash_vmanip_webknight_follow_light", true) then return nil end

    local ply = LocalPlayer()

    if not IsValid(ply) then return nil end
    if ICF_IsThirdPersonActive(ply) then return nil end
    if WBK_IsFlashlightOnShoulder == true then return nil end

    local mdl = ICF_GetWebKnightVManipGestureModel()

    if not IsValid(mdl) then return nil end

    local att = mdl:LookupAttachment("FlashLight")

    if not att or att <= 0 then return nil end

    local posang = mdl:GetAttachment(att)

    if not posang or not posang.Pos or not posang.Ang then return nil end

    local pos = posang.Pos - (posang.Ang:Forward() * 10)
    local ang = Angle(posang.Ang.p, posang.Ang.y, posang.Ang.r)
    ang = ang + Angle(180, -10, 0)

    return pos, ang
end


function ICF_IsCompatAnimLightTransitionActive()
    if ICF_GetVManipMode() ~= "webknight" then return false end
    if not SafeConVarBool("cflash_vmanip_compat", false) then return false end
    if WBK_IsFlashlightOnShoulder == true then return false end

    local now = CurTime()
    return now < (wbkLightFollowsAnimUntil or 0) or now < (ICF_WBKAnimLightBlendOutUntil or 0)
end

function ICF_GetCompatAnimLightInitialTransform()
    if ICF_GetVManipMode() ~= "webknight" then return nil end
    if not SafeConVarBool("cflash_vmanip_compat", false) then return nil end
    if WBK_IsFlashlightOnShoulder == true then return nil end

    local pos, ang = ICF_GetWebKnightVManipLightTransform()
    if pos and ang then
        return pos, ang
    end

    if ICF_WBKAnimLightLastPos and ICF_WBKAnimLightLastAng and CurTime() < (ICF_WBKAnimLightHoldUntil or 0) then
        return ICF_WBKAnimLightLastPos, ICF_WBKAnimLightLastAng
    end

    return nil
end

local function ICF_WebKnightAnimBlendOutActive()
    if ICF_GetVManipMode() ~= "webknight" then return false end
    if not SafeConVarBool("cflash_vmanip_compat", false) then return false end
    if WBK_IsFlashlightOnShoulder == true then return false end
    if not ICF_WBKAnimLightLastPos or not ICF_WBKAnimLightLastAng then return false end

    local now = CurTime()
    return now >= (wbkLightFollowsAnimUntil or 0) and now < (ICF_WBKAnimLightBlendOutUntil or 0)
end

local function ICF_WebKnightLightShouldFollowAnim()
    if ICF_GetVManipMode() ~= "webknight" then return false end
    if not SafeConVarBool("cflash_vmanip_webknight_follow_light", true) then return false end

    return CurTime() < (wbkLightFollowsAnimUntil or 0)
end

local function ICF_WebKnightModelFollowActive()
    if ICF_GetVManipMode() ~= "webknight" then return false end
    if not SafeConVarBool("cflash_vmanip_compat", false) then return false end
    if not SafeConVarBool("cflash_vmanip_webknight_model_follow_light", true) then return false end
    if not enabled then return false end
    if CurTime() < (wbkModelFollowsLightAfter or 0) then return false end

    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if ICF_IsThirdPersonActive(ply) then return false end
    if WBK_IsFlashlightOnShoulder == true then return false end

    return true
end

local function ICF_AngleApproach(currentValue, targetValue, scale, maxDelta)
    local diff = math.Clamp(math.AngleDifference(targetValue, currentValue), -maxDelta, maxDelta)
    return currentValue + diff * scale
end

local function ICF_GetWebKnightModelFollowPrefixes()
    local side = string.lower(SafeConVarString("cflash_vmanip_webknight_model_follow_side", "main_left"))

    if side == "main" or side == "flashlight" then
        return {"MAIN"}
    elseif side == "left" or side == "l" then
        return {"L"}
    end

    return {"MAIN", "L"}
end

local function ICF_ResetWebKnightModelFollowBones(mdl)
    if not IsValid(mdl) then return end

    local bones = {
        "Main",
        "Camera",
        "ValveBiped.Bip01_L_Clavicle",
        "ValveBiped.Bip01_L_UpperArm",
        "ValveBiped.Bip01_L_Forearm",
        "ValveBiped.Bip01_L_Hand",
        "ValveBiped.Bip01_R_Clavicle",
        "ValveBiped.Bip01_R_UpperArm",
        "ValveBiped.Bip01_R_Forearm",
        "ValveBiped.Bip01_R_Hand"
    }

    for _, boneName in ipairs(bones) do
        local bone = mdl:LookupBone(boneName)

        if bone then
            mdl:ManipulateBoneAngles(bone, Angle(0, 0, 0))

            if isfunction(mdl.ManipulateBonePosition) then
                mdl:ManipulateBonePosition(bone, Vector(0, 0, 0))
            end
        end
    end

    mdl:InvalidateBoneCache()
end

local function ICF_GetWebKnightProcAxisPreset()
    local preset = string.lower(SafeConVarString("cflash_vmanip_webknight_proc_axis_preset", "swapped"))

    if preset == "original" or preset == "legacy" then
        return "original"
    elseif preset == "inverted" or preset == "invert" then
        return "inverted"
    elseif preset == "swapped" or preset == "swap" then
        return "swapped"
    end

    return "swapped"
end

local function ICF_WebKnightAxisCorrectInput(pitch, yaw)
    local preset = ICF_GetWebKnightProcAxisPreset()

    if preset == "original" then
        return pitch, yaw
    elseif preset == "inverted" then
        return -pitch, -yaw
    elseif preset == "corrected" then
        return -pitch, -yaw
    end

    return -yaw, -pitch
end

local function ICF_GetWebKnightMainDriverAngles(pitch, yaw)
    local aimA, aimB = ICF_WebKnightAxisCorrectInput(pitch, yaw)

    return aimA, aimB, Angle(aimA * 0.72, aimB * 0.22, aimB * 0.52)
end

local function ICF_ApplyWebKnightModelFollowBoneSet(mdl, prefix, pitch, yaw)
    local preset = ICF_GetWebKnightProcAxisPreset()
    local leftWeight = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_model_follow_left_weight", 1.0), 0, 2)
    local pseudoWeld = SafeConVarBool("cflash_vmanip_webknight_hand_pseudo_weld", true)
    local handPitchFlip = SafeConVarBool("cflash_vmanip_webknight_hand_pitch_flip", true)
    local stiffArm = SafeConVarBool("cflash_vmanip_webknight_stiff_arm", false)
    local handleSupport = SafeConVarBool("cflash_vmanip_webknight_handle_support_arm", true)

    local aimA, aimB, mainDriver = ICF_GetWebKnightMainDriverAngles(pitch, yaw)

    if prefix == "MAIN" then
        local main = mdl:LookupBone("Main")
        local camera = mdl:LookupBone("Camera")

        if main then
            if preset == "original" then
                mdl:ManipulateBoneAngles(main, Angle(pitch * 0.62, yaw * 0.70, yaw * 0.07))
            elseif preset == "inverted" or preset == "corrected" then
                mdl:ManipulateBoneAngles(main, Angle(aimA * 0.56, aimB * 0.08, aimB * 0.82))
            else
                mdl:ManipulateBoneAngles(main, mainDriver)
            end
        end

        if camera then
            mdl:ManipulateBoneAngles(camera, Angle(aimA * 0.015, aimB * 0.015, 0))
        end

        return
    end

    if prefix ~= "L" then return end

    local clav = mdl:LookupBone("ValveBiped.Bip01_L_Clavicle")
    local upper = mdl:LookupBone("ValveBiped.Bip01_L_UpperArm")
    local fore = mdl:LookupBone("ValveBiped.Bip01_L_Forearm")
    local hand = mdl:LookupBone("ValveBiped.Bip01_L_Hand")

    if handleSupport then
        local handAimB = handPitchFlip and -aimB or aimB
        local sideYawFix = SafeConVarBool("cflash_vmanip_webknight_hand_side_yaw_fix", true)
        local sideAmount = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_hand_side_amount", 0.56), 0, 2)
        local verticalAmount = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_hand_vertical_amount", 0.72), 0, 2)
        local handleRollAmount = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_hand_handle_roll_amount", 0.72), 0, 2)
        local verticalRollAmount = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_hand_vertical_roll_amount", 0.12), 0, 2)

        local side = -aimA * leftWeight
        local vertical = handAimB * leftWeight

        if clav then
            mdl:ManipulateBoneAngles(clav, Angle(0, 0, 0))
        end

        if upper then
            mdl:ManipulateBoneAngles(upper, Angle(0, 0, 0))
        end

        if sideYawFix then
            if fore then
                mdl:ManipulateBoneAngles(fore, Angle(
                    vertical * 0.035 * verticalAmount,
                    side * 0.055 * sideAmount,
                    (side * 0.12 * handleRollAmount) + (vertical * 0.03 * verticalRollAmount)
                ))
            end

            if hand then
                mdl:ManipulateBoneAngles(hand, Angle(
                    vertical * 0.96 * verticalAmount,
                    side * 0.40 * sideAmount,
                    (side * 0.68 * handleRollAmount) + (vertical * 0.06 * verticalRollAmount)
                ))
            end
        else
            local handleDriver = Angle(aimA * 0.72 * leftWeight, handAimB * 0.22 * leftWeight, handAimB * 0.52 * leftWeight)

            if fore then
                mdl:ManipulateBoneAngles(fore, Angle(handleDriver.p * 0.16, handleDriver.y * 0.08, handleDriver.r * 0.18))
            end

            if hand then
                mdl:ManipulateBoneAngles(hand, Angle(handleDriver.p * 0.72, handleDriver.y * 0.18, handleDriver.r * 0.78))
            end
        end

        return
    end

    if stiffArm then
        local armAimA = aimA * leftWeight
        local armAimB = (handPitchFlip and -aimB or aimB) * leftWeight
        local armDriver = Angle(armAimA * 0.72, armAimB * 0.22, armAimB * 0.52)

        if clav then
            mdl:ManipulateBoneAngles(clav, Angle(armDriver.p * 0.02, armDriver.y * 0.02, armDriver.r * 0.02))
        end

        if upper then
            mdl:ManipulateBoneAngles(upper, Angle(armDriver.p * 0.06, armDriver.y * 0.05, armDriver.r * 0.06))
        end

        if fore then
            mdl:ManipulateBoneAngles(fore, Angle(armDriver.p * 0.92, armDriver.y * 0.92, armDriver.r * 0.92))
        end

        if hand then
            mdl:ManipulateBoneAngles(hand, armDriver)
        end

        return
    end

    if not pseudoWeld then
        local a = aimA * leftWeight
        local b = aimB * leftWeight

        if handPitchFlip then b = -b end

        if clav then mdl:ManipulateBoneAngles(clav, Angle(a * 0.04, b * 0.03, b * 0.02)) end
        if upper then mdl:ManipulateBoneAngles(upper, Angle(a * 0.13, b * 0.07, b * 0.09)) end
        if fore then mdl:ManipulateBoneAngles(fore, Angle(a * 0.46, b * 0.18, b * 0.32)) end
        if hand then mdl:ManipulateBoneAngles(hand, Angle(a * 0.78, b * 0.24, b * 0.52)) end

        return
    end

    local handAimB = handPitchFlip and -aimB or aimB
    local handDriver = Angle(aimA * 0.72 * leftWeight, handAimB * 0.22 * leftWeight, handAimB * 0.52 * leftWeight)

    if clav then
        mdl:ManipulateBoneAngles(clav, Angle(handDriver.p * 0.06, handDriver.y * 0.06, handDriver.r * 0.08))
    end

    if upper then
        mdl:ManipulateBoneAngles(upper, Angle(handDriver.p * 0.18, handDriver.y * 0.14, handDriver.r * 0.20))
    end

    if fore then
        mdl:ManipulateBoneAngles(fore, Angle(handDriver.p * 0.62, handDriver.y * 0.42, handDriver.r * 0.58))
    end

    if hand then
        mdl:ManipulateBoneAngles(hand, Angle(handDriver.p, handDriver.y, handDriver.r))
    end
end

local function ICF_WebKnightWorldDeltaToModelLocal(mdl, delta)
    if not IsValid(mdl) or not delta then return Vector(0, 0, 0) end

    local ang = mdl:GetAngles()

    return Vector(
        delta:Dot(ang:Forward()),
        delta:Dot(ang:Right()),
        delta:Dot(ang:Up())
    )
end

local function ICF_CalcWebKnightMainAttachmentDelta(mdl, pitch, yaw)
    if not IsValid(mdl) then return nil end
    if not SafeConVarBool("cflash_vmanip_webknight_hand_pos_weld", true) then return nil end

    local att = mdl:LookupAttachment("FlashLight")
    if not att or att <= 0 then return nil end

    ICF_ResetWebKnightModelFollowBones(mdl)
    mdl:SetupBones()

    local baseAtt = mdl:GetAttachment(att)
    if not baseAtt or not baseAtt.Pos then return nil end

    ICF_ApplyWebKnightModelFollowBoneSet(mdl, "MAIN", pitch, yaw)
    mdl:InvalidateBoneCache()
    mdl:SetupBones()

    local movedAtt = mdl:GetAttachment(att)
    if not movedAtt or not movedAtt.Pos then return nil end

    local delta = movedAtt.Pos - baseAtt.Pos
    ICF_ResetWebKnightModelFollowBones(mdl)

    return delta
end

local function ICF_ApplyWebKnightHandPositionWeld(mdl, worldDelta)
    if not IsValid(mdl) or not worldDelta then return end
    if not SafeConVarBool("cflash_vmanip_webknight_hand_pos_weld", true) then return end
    if not isfunction(mdl.ManipulateBonePosition) then return end

    local amount = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_hand_pos_weld_amount", 0), 0, 1.5)
    local foreAmount = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_hand_pos_weld_forearm", 0), 0, 1.5)

    if amount <= 0 and foreAmount <= 0 then return end

    local localDelta = ICF_WebKnightWorldDeltaToModelLocal(mdl, worldDelta)
    local fore = mdl:LookupBone("ValveBiped.Bip01_L_Forearm")
    local hand = mdl:LookupBone("ValveBiped.Bip01_L_Hand")

    if fore then
        mdl:ManipulateBonePosition(fore, localDelta * foreAmount)
    end

    if hand then
        mdl:ManipulateBonePosition(hand, localDelta * amount)
    end
end

local function ICF_ApplyWebKnightModelFollowBones(mdl, pitchDiff, yawDiff, response)
    if not IsValid(mdl) then return false end
    if not SafeConVarBool("cflash_vmanip_webknight_model_follow_bones", true) then return false end

    local frame = FrameNumber and FrameNumber() or 0
    local dt = math.Clamp(FrameTime(), 0.001, 0.05)
    local scale = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_model_follow_bone_scale", 0.39), 0, 1.25)
    local pitchSign = SafeConVarFloat("cflash_vmanip_webknight_model_follow_pitch_sign", 1) >= 0 and 1 or -1
    local yawSign = SafeConVarFloat("cflash_vmanip_webknight_model_follow_yaw_sign", 1) >= 0 and 1 or -1
    local deadzone = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_model_follow_deadzone", 0.25), 0, 10)

    if math.abs(pitchDiff) < deadzone then pitchDiff = 0 end
    if math.abs(yawDiff) < deadzone then yawDiff = 0 end

    local fadeTime = math.max(SafeConVarFloat("cflash_vmanip_webknight_model_follow_fade_time", 0.42), 0.01)
    local targetFade = math.Clamp((CurTime() - (wbkModelFollowsLightAfter or 0)) / fadeTime, 0, 1)

    wbkModelFollowFade = Lerp(math.Clamp(dt * 5.5, 0, 1), wbkModelFollowFade or 0, targetFade)

    if wbkModelFollowFrame ~= frame then
        local targetPitch = pitchDiff * pitchSign
        local targetYaw = yawDiff * yawSign

        local lag = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_proc_lag", 0.025), 0, 0.25)
        local now = CurTime()

        if lag > 0 and (wbkModelFollowLastTargetTime or 0) > 0 then
            local targetDt = math.max(now - wbkModelFollowLastTargetTime, 0.001)
            local targetPitchVel = math.AngleDifference(targetPitch, wbkModelFollowLastTargetPitch or 0) / targetDt
            local targetYawVel = math.AngleDifference(targetYaw, wbkModelFollowLastTargetYaw or 0) / targetDt
            local lagLimit = math.max(SafeConVarFloat("cflash_vmanip_webknight_model_follow_max_angle", 20), 1) * 0.35

            targetPitch = targetPitch - math.Clamp(targetPitchVel * lag, -lagLimit, lagLimit)
            targetYaw = targetYaw - math.Clamp(targetYawVel * lag, -lagLimit, lagLimit)
        end

        wbkModelFollowLastTargetPitch = targetPitch
        wbkModelFollowLastTargetYaw = targetYaw
        wbkModelFollowLastTargetTime = now

        local spring = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_proc_spring", 72), 1, 220)
        local damping = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_proc_damping", 15), 1, 40)
        local maxSpeed = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_proc_max_speed", 115), 5, 360)

        local pitchAccel = math.AngleDifference(targetPitch, wbkModelFollowPitch or 0) * spring
        local yawAccel = math.AngleDifference(targetYaw, wbkModelFollowYaw or 0) * spring

        wbkModelFollowPitchVel = (wbkModelFollowPitchVel or 0) + pitchAccel * dt
        wbkModelFollowYawVel = (wbkModelFollowYawVel or 0) + yawAccel * dt

        local dampMul = math.exp(-damping * dt)
        wbkModelFollowPitchVel = math.Clamp(wbkModelFollowPitchVel * dampMul, -maxSpeed, maxSpeed)
        wbkModelFollowYawVel = math.Clamp(wbkModelFollowYawVel * dampMul, -maxSpeed, maxSpeed)

        wbkModelFollowPitch = (wbkModelFollowPitch or 0) + wbkModelFollowPitchVel * dt
        wbkModelFollowYaw = (wbkModelFollowYaw or 0) + wbkModelFollowYawVel * dt

        wbkModelFollowFrame = frame
    end

    local pitch = (wbkModelFollowPitch or 0) * scale * (wbkModelFollowFade or 0)
    local yaw = (wbkModelFollowYaw or 0) * scale * (wbkModelFollowFade or 0)

    local handWeldDelta = ICF_CalcWebKnightMainAttachmentDelta(mdl, pitch, yaw)

    ICF_ResetWebKnightModelFollowBones(mdl)

    for _, prefix in ipairs(ICF_GetWebKnightModelFollowPrefixes()) do
        ICF_ApplyWebKnightModelFollowBoneSet(mdl, prefix, pitch, yaw)
    end

    if handWeldDelta then
        ICF_ApplyWebKnightHandPositionWeld(mdl, handWeldDelta)
    end

    mdl:InvalidateBoneCache()
    mdl:SetupBones()

    return true
end

local function ICF_GetWebKnightCameraRelativeFollowTarget(desiredAng)
    local ply = LocalPlayer()
    if not IsValid(ply) or not desiredAng then return 0, 0 end

    local eyeAng = ply:EyeAngles()
    local pitchTarget = math.AngleDifference(desiredAng.p, eyeAng.p)
    local yawTarget = math.AngleDifference(desiredAng.y, eyeAng.y)

    return pitchTarget, yawTarget
end

local function ICF_GetWebKnightAttachmentRelativeFollowTarget(mdl, desiredAng)
    if not IsValid(mdl) or not desiredAng then return 0, 0 end

    local att = mdl:LookupAttachment("FlashLight")
    if not att or att <= 0 then return 0, 0 end

    local posang = mdl:GetAttachment(att)
    if not posang or not posang.Ang then return 0, 0 end

    local currentLightAng = Angle(posang.Ang.p, posang.Ang.y, posang.Ang.r)
    currentLightAng = currentLightAng + Angle(180, -10, 0)

    return math.AngleDifference(desiredAng.p, currentLightAng.p),
        math.AngleDifference(desiredAng.y, currentLightAng.y)
end

local function ICF_ApplyWebKnightModelFollow(desiredPos, desiredAng)
    if not ICF_WebKnightModelFollowActive() then
        local mdl = ICF_GetWebKnightVManipGestureModel()

        if IsValid(mdl) then
            ICF_ResetWebKnightModelFollowBones(mdl)
        end

        local returnStrength = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_model_follow_return_strength", 5), 0.5, 20)
        local returnResponse = math.Clamp(FrameTime() * returnStrength, 0, 1)

        wbkModelFollowPitch = Lerp(returnResponse, wbkModelFollowPitch or 0, 0)
        wbkModelFollowYaw = Lerp(returnResponse, wbkModelFollowYaw or 0, 0)
        wbkModelFollowPitchVel = Lerp(returnResponse, wbkModelFollowPitchVel or 0, 0)
        wbkModelFollowYawVel = Lerp(returnResponse, wbkModelFollowYawVel or 0, 0)
        wbkModelFollowFade = Lerp(returnResponse, wbkModelFollowFade or 0, 0)

        return
    end

    if not desiredAng then return end

    local mdl = ICF_GetWebKnightVManipGestureModel()
    if not IsValid(mdl) then return end

    local strength = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_model_follow_strength", 8.5), 0.25, 12)
    local response = math.Clamp(FrameTime() * strength, 0, 0.20)
    local maxDelta = math.Clamp(SafeConVarFloat("cflash_vmanip_webknight_model_follow_max_angle", 20), 1, 32)

    local pitchTarget = 0
    local yawTarget = 0

    if SafeConVarBool("cflash_vmanip_webknight_model_follow_use_camera_relative", true) then
        pitchTarget, yawTarget = ICF_GetWebKnightCameraRelativeFollowTarget(desiredAng)
    else
        pitchTarget, yawTarget = ICF_GetWebKnightAttachmentRelativeFollowTarget(mdl, desiredAng)
    end

    pitchTarget = math.Clamp(pitchTarget, -maxDelta, maxDelta)
    yawTarget = math.Clamp(yawTarget, -maxDelta, maxDelta)

    if ICF_ApplyWebKnightModelFollowBones(mdl, pitchTarget, yawTarget, response) then
        return
    end

    if SafeConVarBool("cflash_vmanip_webknight_model_follow_local", true) and isfunction(mdl.GetLocalAngles) and isfunction(mdl.SetLocalAngles) then
        local localAng = mdl:GetLocalAngles()
        local newLocalAng = Angle(localAng.p, localAng.y, localAng.r)

        newLocalAng.p = newLocalAng.p + pitchTarget * response
        newLocalAng.y = newLocalAng.y + yawTarget * response

        mdl:SetLocalAngles(newLocalAng)
    else
        local modelAng = mdl:GetAngles()
        local newAng = Angle(modelAng.p, modelAng.y, modelAng.r)

        newAng.p = newAng.p + pitchTarget * response
        newAng.y = newAng.y + yawTarget * response

        mdl:SetAngles(newAng)
    end

    mdl:SetupBones()
end

local function ApplyWallDetection(ply, pos, ang)
    local nearZ = 2

    if not SafeConVarBool("cflash_wall_detection", true) then
        return pos, nearZ
    end

    if not IsValid(ply) then
        return pos, nearZ
    end

    local boxMin = Vector(-1, -1, -1)
    local boxMax = Vector(1, 1, 1)

    local pushBack = 40
    local offset = 10

    if ply:InVehicle() and SafeConVarBool("cflash_vehicle_flashlight", true) then
        offset = 0
    end

    local forwardTR = util.TraceHull({
        start = pos,
        endpos = pos + ang:Forward() * pushBack,
        mins = boxMin,
        maxs = boxMax,
        mask = MASK_SOLID,
        filter = ply
    })

    local backwardTR = util.TraceHull({
        start = forwardTR.HitPos,
        endpos = forwardTR.HitPos + ang:Forward() * -(pushBack + offset),
        mins = boxMin,
        maxs = boxMax,
        mask = MASK_SOLID,
        filter = ply
    })

    local adjustedPos = backwardTR.HitPos
    local pushBackOffset = (pushBack + offset) * backwardTR.Fraction - pushBack * forwardTR.Fraction

    nearZ = math.Clamp(2 + pushBackOffset, 2, 120)

    return adjustedPos, nearZ
end

local ICF_MP_RemoteLights = {}
local ICF_MP_NextSend = 0
local ICF_MP_LastSentActive = nil
local ICF_MP_LastNetFailNotice = 0

local function ICF_MP_NetworkAvailable()
    if not net or not net.Start or not net.SendToServer then return false end
    if game and game.SinglePlayer and game.SinglePlayer() then return false end

    if util and util.NetworkStringToID then
        local id = util.NetworkStringToID("ICF_MP_State")

        if not id or id == 0 then
            return false
        end
    end

    return true
end

local function ICF_MP_SanitizeTexturePath(texturePath, fallback)
    fallback = fallback or "effects/flashlight001"
    texturePath = tostring(texturePath or fallback)

    if string.Trim then
        texturePath = string.Trim(texturePath)
    end

    texturePath = string.gsub(texturePath, "^materials/", "")
    texturePath = string.gsub(texturePath, "%.vmt$", "")
    texturePath = string.gsub(texturePath, "%.vtf$", "")
    texturePath = string.sub(texturePath, 1, 128)

    if texturePath == "" then return fallback end
    if string.find(texturePath, "\\", 1, true) or string.find(texturePath, "..", 1, true) or string.find(texturePath, ":", 1, true) then
        return fallback
    end

    if texturePath ~= "effects/flashlight001" and not string.find(texturePath, "^effects/lightspill/") then
        return fallback
    end

    return texturePath
end

local function ICF_MP_TextureExists(texturePath)
    texturePath = ICF_MP_SanitizeTexturePath(texturePath, "effects/flashlight001")

    if texturePath == "effects/flashlight001" then
        return true
    end

    if file and file.Exists then
        return file.Exists("materials/" .. texturePath .. ".vmt", "GAME")
    end

    return false
end

local function ICF_MP_GetRemoteBeamTexture(data)
    if not SafeConVarBool("cflash_multiplayer_remote_textures", true) then
        return GetFlashlightTexture()
    end

    local texturePath = data and data.texture or nil

    if not texturePath then
        return GetFlashlightTexture()
    end

    texturePath = ICF_MP_SanitizeTexturePath(texturePath, GetFlashlightTexture())

    if not ICF_MP_TextureExists(texturePath) then
        return GetFlashlightTexture()
    end

    return texturePath
end

local function ICF_MP_DestroyRemoteLight(entIndex)
    local data = ICF_MP_RemoteLights[entIndex]

    if data and IsValid(data.proj) then
        data.proj:Remove()
    end

    if data and IsValid(data.spillProj) then
        data.spillProj:Remove()
    end

    ICF_MP_RemoteLights[entIndex] = nil
end

local function ICF_MP_DestroyAllRemoteLights()
    for entIndex, _ in pairs(ICF_MP_RemoteLights) do
        ICF_MP_DestroyRemoteLight(entIndex)
    end
end

local function ICF_MP_SendLocalState(active, ang, force, beamPos)
    if not SafeConVarBool("cflash_multiplayer_visibility", false) then
        if ICF_MP_LastSentActive ~= false then
            ICF_MP_LastSentActive = false
        end

        return
    end

    if not ICF_MP_NetworkAvailable() then
        return
    end

    active = active == true

    if not force and ICF_MP_LastSentActive == active and not active then
        return
    end

    local now = CurTime()
    local rate = math.Clamp(SafeConVarFloat("cflash_multiplayer_update_rate", 10), 2, 20)

    if not force and now < ICF_MP_NextSend then
        return
    end

    ICF_MP_NextSend = now + (1 / rate)
    ICF_MP_LastSentActive = active

    local ply = LocalPlayer()
    local dir = Vector(0, 0, 0)

    if active then
        if ang and ang.Forward then
            dir = ang:Forward()
        elseif IsValid(ply) then
            dir = ply:EyeAngles():Forward()
        end

        if dir:LengthSqr() < 0.001 then
            dir = Vector(1, 0, 0)
        end

        dir:Normalize()
    end

    local col = GetFlashlightColor()
    local msgName = "ICF_MP_State"

    if util and util.NetworkStringToID then
        local state4ID = util.NetworkStringToID("ICF_MP_State4")
        local state3ID = util.NetworkStringToID("ICF_MP_State3")
        local state2ID = util.NetworkStringToID("ICF_MP_State2")

        if state4ID and state4ID ~= 0 then
            msgName = "ICF_MP_State4"
        elseif state3ID and state3ID ~= 0 then
            msgName = "ICF_MP_State3"
        elseif state2ID and state2ID ~= 0 then
            msgName = "ICF_MP_State2"
        end
    end

    local sendPos = Vector(0, 0, 0)

    if active then
        if beamPos and beamPos.x then
            sendPos = beamPos
        elseif IsValid(ply) then
            sendPos = ply:EyePos()
        end
    end

    local ok = pcall(net.Start, msgName)

    if not ok then
        if now > ICF_MP_LastNetFailNotice then
            ICF_MP_LastNetFailNotice = now + 10
            print("[ICF] Experimental multiplayer visibility could not network. The server probably does not have the addon installed.")
        end

        return
    end

    net.WriteBool(active)
    net.WriteVector(dir)

    if msgName == "ICF_MP_State2" or msgName == "ICF_MP_State3" or msgName == "ICF_MP_State4" then
        net.WriteVector(sendPos)
    end

    net.WriteUInt(math.Clamp(col.r or 255, 0, 255), 8)
    net.WriteUInt(math.Clamp(col.g or 255, 0, 255), 8)
    net.WriteUInt(math.Clamp(col.b or 255, 0, 255), 8)
    net.WriteFloat(math.Clamp(ICF_GetEffectiveBrightness(), 0.05, 10))
    net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_farz", 1837), 128, 6000))
    net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_fov", 40), 5, 140))

    if msgName == "ICF_MP_State4" then
        net.WriteString(string.sub(ICF_MP_SanitizeTexturePath(GetFlashlightTexture(), "effects/flashlight001"), 1, 128))
    end

    if msgName == "ICF_MP_State3" or msgName == "ICF_MP_State4" then
        local sendSpill = active and ICF_LightspillEnabled()
        net.WriteBool(sendSpill)

        if sendSpill then
            local spillCol = ICF_GetLightspillColor()
            net.WriteString(string.sub(ICF_GetLightspillTexture() or "effects/lightspill/spill1", 1, 128))
            net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_lightspill_brightness", 0.24), 0, 4))
            net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_lightspill_size", 1), 0.25, 1.25))
            net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_lightspill_fov", 112), 10, 140))
            net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_lightspill_farz", 720), 64, 4000))
            net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_lightspill_nearz", 8), 2, 64))
            net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_lightspill_forward", 5), -64, 64))
            net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_lightspill_right", 0), -64, 64))
            net.WriteFloat(math.Clamp(SafeConVarFloat("cflash_lightspill_up", 0), -64, 64))
            net.WriteUInt(math.Clamp(spillCol.r or 255, 0, 255), 8)
            net.WriteUInt(math.Clamp(spillCol.g or 255, 0, 255), 8)
            net.WriteUInt(math.Clamp(spillCol.b or 255, 0, 255), 8)
        end
    end

    net.SendToServer()
end

local function ICF_MP_GetRemoteBeamPosition(ply, ang, data)
    if data and data.netPos and data.netPos.x then
        if not data.smoothedPos then
            data.smoothedPos = data.netPos
        else
            data.smoothedPos = LerpVector(math.Clamp(FrameTime() * 18, 0, 1), data.smoothedPos, data.netPos)
        end

        return data.smoothedPos
    end

    if not IsValid(ply) then return nil end

    local basePos = ICF_GetAttachmentPos(ply, {
        "anim_attachment_RH",
        "anim_attachment_rh",
        "right_hand"
    })

    if not basePos then
        basePos = ICF_GetAttachmentPos(ply, {"eyes", "forward"})
    end

    if not basePos then
        basePos = ply:EyePos()
    end

    return basePos +
        ang:Right() * SafeConVarFloat("cflash_thirdperson_right", 5) +
        ang:Up() * SafeConVarFloat("cflash_thirdperson_up", -2) +
        ang:Forward() * SafeConVarFloat("cflash_thirdperson_forward", 6)
end

local function ICF_MP_RemoveRemoteSpill(data)
    if data and IsValid(data.spillProj) then
        data.spillProj:Remove()
        data.spillProj = nil
    end
end

local function ICF_MP_UpdateRemoteLightspill(data, pos, ang, distanceLimit)
    if not data then return end

    if not SafeConVarBool("cflash_multiplayer_remote_lightspill", false) or not data.spillEnabled then
        ICF_MP_RemoveRemoteSpill(data)
        return
    end

    if not IsValid(data.spillProj) then
        data.spillProj = ProjectedTexture()

        if data.spillProj then
            data.spillProj:SetEnableShadows(false)
        end
    end

    if not IsValid(data.spillProj) then return end

    local spillAng = Angle(ang.p, ang.y, ang.r)
    local spillPos = pos + spillAng:Forward() * (data.spillForward or 5)
    spillPos = spillPos + spillAng:Right() * (data.spillRight or 0)
    spillPos = spillPos + spillAng:Up() * (data.spillUp or 0)
    local spillFov = (data.spillFov or 112) * math.Clamp(data.spillSize or 1, 0.25, 1.25)
    local spillFarZ = math.min(data.spillFarz or 720, distanceLimit or 2500)
    local spillNearZ = math.Clamp(data.spillNearz or 8, 2, 64)

    data.spillProj:SetTexture(data.spillTexture or "effects/lightspill/spill1")
    data.spillProj:SetEnableShadows(false)
    data.spillProj:SetColor(data.spillColor or color_white)
    data.spillProj:SetPos(spillPos)
    data.spillProj:SetAngles(spillAng)
    data.spillProj:SetBrightness(math.Clamp((data.brightness or 1) * (data.spillBrightness or 0.24), 0.01, 10))
    data.spillProj:SetFOV(math.Clamp(spillFov, 10, 140))
    data.spillProj:SetFarZ(math.Clamp(spillFarZ, 64, 4000))
    data.spillProj:SetNearZ(ICF_GetProjectedNearZ(spillNearZ))
    data.spillProj:Update()
end


local function ICF_MP_GetRemoteEmitterPosition(owner, ang)
    if not IsValid(owner) then return nil end

    local ownerUp = owner.GetUp and owner:GetUp() or Vector(0, 0, 1)
    local ownerRight = owner.GetRight and owner:GetRight() or (ang and ang.Right and ang:Right() or Vector(0, 1, 0))
    local forward = ang and ang.Forward and ang:Forward() or (owner.GetForward and owner:GetForward() or Vector(1, 0, 0))
    local basePos = nil

    if owner.EyePos then
        basePos = owner:EyePos() - ownerUp * 16
    end

    if not basePos then
        basePos = owner:WorldSpaceCenter() + ownerUp * 18
    end

    local fwdOffset = math.Clamp(SafeConVarFloat("cflash_multiplayer_emitter_forward", 8), -64, 64)
    local rightOffset = math.Clamp(SafeConVarFloat("cflash_multiplayer_emitter_right", 0), -64, 64)
    local upOffset = math.Clamp(SafeConVarFloat("cflash_multiplayer_emitter_up", 0), -64, 64)

    return basePos + forward * fwdOffset + ownerRight * rightOffset + ownerUp * upOffset
end

local function ICF_MP_UpdateRemoteLights(localPly)
    if not SafeConVarBool("cflash_multiplayer_show_others", true) or not SafeConVarBool("cflash_enabled", true) then
        ICF_MP_DestroyAllRemoteLights()
        return
    end

    local maxLights = math.max(math.floor(SafeConVarFloat("cflash_multiplayer_max_remote_lights", 4)), 0)
    local distanceLimit = math.max(SafeConVarFloat("cflash_multiplayer_distance", 2500), 128)
    local now = CurTime()
    local rendered = 0

    for entIndex, data in pairs(ICF_MP_RemoteLights) do
        local owner = data.owner

        if not IsValid(owner) or owner == localPly or not data.active or now > (data.expire or 0) then
            ICF_MP_DestroyRemoteLight(entIndex)
        elseif maxLights > 0 and rendered >= maxLights then
            if IsValid(data.proj) then
                data.proj:Remove()
                data.proj = nil
            end

            ICF_MP_RemoveRemoteSpill(data)
        else
            local distSqr = IsValid(localPly) and localPly:GetPos():DistToSqr(owner:GetPos()) or 0

            if distSqr > distanceLimit * distanceLimit then
                if IsValid(data.proj) then
                    data.proj:Remove()
                    data.proj = nil
                end

                ICF_MP_RemoveRemoteSpill(data)
            else
                local dir = data.dir or owner:EyeAngles():Forward()

                if dir:LengthSqr() < 0.001 then
                    dir = owner:EyeAngles():Forward()
                end

                dir = dir:GetNormalized()
                local ang = dir:Angle()
                local pos = ICF_MP_GetRemoteBeamPosition(owner, ang, data)

                if pos then
                    if not IsValid(data.proj) then
                        data.proj = ProjectedTexture()

                        if data.proj then
                            data.proj:SetEnableShadows(SafeConVarBool("cflash_multiplayer_remote_shadows", false))
                        end
                    end

                    if IsValid(data.proj) then
                        data.proj:SetTexture(ICF_MP_GetRemoteBeamTexture(data))
                        data.proj:SetEnableShadows(SafeConVarBool("cflash_multiplayer_remote_shadows", false))
                        data.proj:SetPos(pos)
                        data.proj:SetAngles(ang)
                        data.proj:SetColor(data.color or color_white)
                        data.proj:SetBrightness(math.Clamp((data.brightness or 1) * 0.9, 0.05, 10))
                        data.proj:SetFOV(math.Clamp(data.fov or 40, 5, 140))
                        data.proj:SetFarZ(math.min(data.farz or 1837, distanceLimit))
                        data.proj:SetNearZ(4)
                        data.proj:Update()

                        ICF_MP_UpdateRemoteLightspill(data, pos, ang, distanceLimit)

                        if SafeConVarBool("cflash_multiplayer_remote_emitter_glow", true) then
                            data.glowPos = ICF_MP_GetRemoteEmitterPosition(owner, ang)
                            data.glowColor = data.color or color_white
                            data.glowSize = math.Clamp((data.brightness or 1) * 28, 18, 72)
                        else
                            data.glowPos = nil
                        end

                        rendered = rendered + 1
                    end
                end
            end
        end
    end
end

function ICF_MP_ReceiveRemoteState(hasNetworkPos, hasLightspillData, hasBeamTexture)
    local owner = net.ReadEntity()
    local active = net.ReadBool()
    local dir = net.ReadVector()
    local netPos = nil

    if hasNetworkPos then
        netPos = net.ReadVector()
    end

    local r = net.ReadUInt(8)
    local g = net.ReadUInt(8)
    local b = net.ReadUInt(8)
    local brightness = net.ReadFloat()
    local farz = net.ReadFloat()
    local fov = net.ReadFloat()
    local beamTexture = nil

    if hasBeamTexture then
        beamTexture = net.ReadString() or "effects/flashlight001"
    end

    local spillEnabled = false
    local spillTexture = "effects/lightspill/spill1"
    local spillBrightness = 0.24
    local spillSize = 1
    local spillFov = 112
    local spillFarz = 720
    local spillNearz = 8
    local spillForward = 5
    local spillRight = 0
    local spillUp = 0
    local spillColor = color_white

    if hasLightspillData then
        spillEnabled = net.ReadBool()

        if spillEnabled then
            spillTexture = net.ReadString() or "effects/lightspill/spill1"
            spillBrightness = net.ReadFloat()
            spillSize = net.ReadFloat()
            spillFov = net.ReadFloat()
            spillFarz = net.ReadFloat()
            spillNearz = net.ReadFloat()
            spillForward = net.ReadFloat()
            spillRight = net.ReadFloat()
            spillUp = net.ReadFloat()
            spillColor = Color(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8))
        end
    end

    if not IsValid(owner) or owner == LocalPlayer() then return end

    local entIndex = owner:EntIndex()

    if not active then
        ICF_MP_DestroyRemoteLight(entIndex)
        return
    end

    if dir:LengthSqr() < 0.001 then
        dir = owner:EyeAngles():Forward()
    end

    dir:Normalize()

    local data = ICF_MP_RemoteLights[entIndex] or {}

    data.owner = owner
    data.active = true
    data.dir = dir
    data.netPos = netPos
    data.color = Color(r, g, b)
    data.brightness = math.Clamp(brightness or 1, 0.05, 10)
    data.farz = math.Clamp(farz or 1837, 128, 6000)
    data.fov = math.Clamp(fov or 40, 5, 140)

    if hasBeamTexture then
        data.texture = ICF_MP_SanitizeTexturePath(beamTexture, "effects/flashlight001")
    elseif not data.texture then
        data.texture = "effects/flashlight001"
    end

    data.spillEnabled = spillEnabled == true
    data.spillTexture = string.sub(tostring(spillTexture or "effects/lightspill/spill1"), 1, 128)

    if string.find(data.spillTexture, "\\", 1, true) or string.find(data.spillTexture, "..", 1, true) or string.find(data.spillTexture, ":", 1, true) then
        data.spillTexture = "effects/lightspill/spill1"
    end

    data.spillBrightness = math.Clamp(tonumber(spillBrightness) or 0.24, 0, 4)
    data.spillSize = math.Clamp(tonumber(spillSize) or 1, 0.25, 1.25)
    data.spillFov = math.Clamp(tonumber(spillFov) or 112, 10, 140)
    data.spillFarz = math.Clamp(tonumber(spillFarz) or 720, 64, 4000)
    data.spillNearz = math.Clamp(tonumber(spillNearz) or 8, 2, 64)
    data.spillForward = math.Clamp(tonumber(spillForward) or 5, -64, 64)
    data.spillRight = math.Clamp(tonumber(spillRight) or 0, -64, 64)
    data.spillUp = math.Clamp(tonumber(spillUp) or 0, -64, 64)
    data.spillColor = spillColor or color_white
    data.lastUpdate = CurTime()
    data.expire = CurTime() + 1.5

    ICF_MP_RemoteLights[entIndex] = data
end

if net and net.Receive then
    net.Receive("ICF_MP_State", function()
        ICF_MP_ReceiveRemoteState(false, false, false)
    end)

    net.Receive("ICF_MP_State2", function()
        ICF_MP_ReceiveRemoteState(true, false, false)
    end)

    net.Receive("ICF_MP_State3", function()
        ICF_MP_ReceiveRemoteState(true, true, false)
    end)

    net.Receive("ICF_MP_State4", function()
        ICF_MP_ReceiveRemoteState(true, true, true)
    end)
end

ICF_MP_RemoteGlowMaterial = ICF_MP_RemoteGlowMaterial or Material("sprites/light_glow02_add")

hook.Add("PostDrawTranslucentRenderables", "ICF_MultiplayerRemoteEmitterGlow", function(depth, skybox)
    if skybox then return end
    if not SafeConVarBool("cflash_multiplayer_show_others", true) or not SafeConVarBool("cflash_enabled", true) then return end
    if not SafeConVarBool("cflash_multiplayer_remote_emitter_glow", true) then return end
    if not ICF_MP_RemoteGlowMaterial then return end

    render.SetMaterial(ICF_MP_RemoteGlowMaterial)

    for _, data in pairs(ICF_MP_RemoteLights) do
        if data and data.active and data.glowPos and data.glowColor and CurTime() <= (data.expire or 0) then
            render.DrawSprite(data.glowPos, data.glowSize or 32, data.glowSize or 32, data.glowColor)
        end
    end
end)

hook.Add("ShutDown", "ICF_MultiplayerCleanup", function()
    ICF_MP_SendLocalState(false, nil, true)
    ICF_MP_DestroyAllRemoteLights()
end)

concommand.Add("cflash_multiplayer_status", function()
    print("----- ICFL Multiplayer Visibility Status -----")
    print("local visibility send enabled =", SafeConVarBool("cflash_multiplayer_visibility", false))
    print("show other players =", SafeConVarBool("cflash_multiplayer_show_others", true))
    print("remote Lightspill enabled =", SafeConVarBool("cflash_multiplayer_remote_lightspill", false))
    print("remote beam textures enabled =", SafeConVarBool("cflash_multiplayer_remote_textures", true))
    print("remote cosmetic emitter glow =", SafeConVarBool("cflash_multiplayer_remote_emitter_glow", true))
    print("remote emitter offset f/r/u =", SafeConVarFloat("cflash_multiplayer_emitter_forward", 8), SafeConVarFloat("cflash_multiplayer_emitter_right", 0), SafeConVarFloat("cflash_multiplayer_emitter_up", 0))
    print("network string ICF_MP_State =", util and util.NetworkStringToID and util.NetworkStringToID("ICF_MP_State") or "unknown")
    print("network string ICF_MP_State2 =", util and util.NetworkStringToID and util.NetworkStringToID("ICF_MP_State2") or "unknown")
    print("network string ICF_MP_State3 =", util and util.NetworkStringToID and util.NetworkStringToID("ICF_MP_State3") or "unknown")
    print("network string ICF_MP_State4 =", util and util.NetworkStringToID and util.NetworkStringToID("ICF_MP_State4") or "unknown")
    print("remote light count =", table.Count(ICF_MP_RemoteLights or {}))
    print("last sent active =", tostring(ICF_MP_LastSentActive))
    print("---------------------------------------------")
end)


local cflashLastRecommendedSettings = nil


DoFlashlightToggle = function()
    if ICF_IsMenuOrTextInputActive() then
        lastF = ICF_IsBindDown(GetFlashlightKey())
        lastBatteryReloadKey = ICF_IsBindDown(GetBatteryReloadKey())
        return
    end

    if not enabled and not ICF_BatteryCanTurnOn() then
        enabled = false
        DestroyLight()
        PlayToggleSound()
        return
    end

    enabled = not enabled

    if enabled then
        CreateLight()
    else
        DestroyLight()
    end

    PlayToggleSound()

    if not enabled then
        ICF_MP_SendLocalState(false, nil, true)
    end

    if SafeConVarBool("cflash_vmanip_compat", false) and ICF_GetVManipMode() == "webknight" then
        ICF_ClearWBKFlashlightObject(true)
    end
end

concommand.Add("cflash_texture_default", function()
    RunConsoleCommand("cflash_texture", "effects/flashlight001")
end)

concommand.Add("cflash_alt_recommended", function()
    cflashLastRecommendedSettings = {
        texture = SafeConVarString("cflash_texture", "effects/flashlight001"),
        fov = tostring(SafeConVarFloat("cflash_fov", 40)),
        brightness = tostring(SafeConVarFloat("cflash_brightness", 1.0)),
        farz = tostring(SafeConVarFloat("cflash_farz", 1837))
    }

    RunConsoleCommand("cflash_texture", "effects/lightspill/actual_flashlight")
    RunConsoleCommand("cflash_fov", "110")
    RunConsoleCommand("cflash_brightness", "2.5")
    RunConsoleCommand("cflash_farz", "1837")
end)

concommand.Add("cflash_alt_recommended_undo", function()
    if not cflashLastRecommendedSettings then return end

    RunConsoleCommand("cflash_texture", cflashLastRecommendedSettings.texture or "effects/flashlight001")
    RunConsoleCommand("cflash_fov", cflashLastRecommendedSettings.fov or "40")
    RunConsoleCommand("cflash_brightness", cflashLastRecommendedSettings.brightness or "1.0")
    RunConsoleCommand("cflash_farz", cflashLastRecommendedSettings.farz or "1837")
end)


local ICF_FakeScriptedWeaponForVManip = {
    UseHands = false,
    Base = "",
    ViewModelFlipDefault = false,
    ViewModelFlip = false,
    IsScripted = function() return true end,
    GetStatus = function() return 0 end,
    GetClass = function() return "icf_fake_emptyhands_weapon" end,
    GetHoldType = function() return "normal" end
}

local function ICF_ShouldManualDrawEmptyHandsVManip()
    if not SafeConVarBool("cflash_vmanip_compat", false) then return false end
    if not icfForcedEmptyHandsVManip then return false end
    if CurTime() > icfForcedEmptyHandsUntil then
        icfForcedEmptyHandsVManip = false
        return false
    end
    if not VManip then return false end

    local isActive = false

    if isfunction(VManip.IsValid) then
        local ok, result = pcall(function()
            return VManip:IsValid()
        end)
        isActive = ok and result
    elseif isfunction(VManip.IsActive) then
        local ok, result = pcall(function()
            return VManip:IsActive()
        end)
        isActive = ok and result
    else
        isActive = IsValid(VManip.VMGesture)
    end

    if not isActive then
        icfForcedEmptyHandsVManip = false
        return false
    end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        icfForcedEmptyHandsVManip = false
        return false
    end

    if IsValid(ply:GetActiveWeapon()) then
        icfForcedEmptyHandsVManip = false
        return false
    end

    local vm = ply:GetViewModel()
    if not IsValid(vm) then return false end

    return true
end

local function ICF_ManualCallVManipDrawHooks()
    if not ICF_ShouldManualDrawEmptyHandsVManip() then return end

    local frame = FrameNumber()
    if icfLastManualVManipDrawFrame == frame then return end
    icfLastManualVManipDrawFrame = frame

    local ply = LocalPlayer()
    local vm = ply:GetViewModel()
    local hands = ply:GetHands()
    local fakeWep = ICF_FakeScriptedWeaponForVManip

    local hooks = hook.GetTable()

    local handHooks = hooks.PreDrawPlayerHands
    local handFn = handHooks and handHooks.VManip
    if isfunction(handFn) and IsValid(hands) then
        pcall(handFn, hands, vm, ply, fakeWep)
    end

    local vmHooks = hooks.PostDrawViewModel
    local vmFn = vmHooks and vmHooks.VManip
    if isfunction(vmFn) then
        pcall(vmFn, vm, ply, fakeWep, STUDIO_RENDER)
    end
end

hook.Add("PostDrawEffects", "ICF_ManualEmptyHandsVManipDraw_PostEffects", function()
    ICF_ManualCallVManipDrawHooks()
end)

hook.Add("PostDrawTranslucentRenderables", "ICF_ManualEmptyHandsVManipDraw_Translucent", function(depth, skybox)
    if skybox then return end
    ICF_ManualCallVManipDrawHooks()
end)

hook.Add("RenderScreenspaceEffects", "ICF_ManualEmptyHandsVManipDraw_Screenspace", function()
    if not ICF_ShouldManualDrawEmptyHandsVManip() then return end

    cam.Start3D(EyePos(), EyeAngles(), LocalPlayer():GetFOV(), 0, 0, ScrW(), ScrH(), 1, 4096)
        ICF_ManualCallVManipDrawHooks()
    cam.End3D()
end)


concommand.Add("cflash_vmanip_bridge_enable", function()
    RunConsoleCommand("cflash_vmanip_compat", "1")
    RunConsoleCommand("cflash_vmanip_emptyhands_bridge", "1")

    timer.Simple(0.05, function()
        ICF_RequestVManipBridgeWeapon()
    end)

    chat.AddText(
        Color(120, 220, 255), "[Immersive Custom Flashlight] ",
        Color(255, 255, 255), "Enabled VManip compatibility and experimental empty-hands bridge."
    )
end)


concommand.Add("cflash_vmanip_webknight_model_follow_debug", function()
    print("---- ICF WebKnight Model-Follows-Light Debug ----")
    print("model follow enabled =", SafeConVarBool("cflash_vmanip_webknight_model_follow_light", true))
    print("light follows anim =", ICF_WebKnightLightShouldFollowAnim())
    print("model follow active =", ICF_WebKnightModelFollowActive())
    print("follow delay =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_delay", 0.85))
    print("follow strength =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_strength", 12))
    print("follow max angle =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_max_angle", 35))
    print("uses local angles =", SafeConVarBool("cflash_vmanip_webknight_model_follow_local", true))
    print("bone follow =", SafeConVarBool("cflash_vmanip_webknight_model_follow_bones", true))
    print("bone scale =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_bone_scale", 0.22))
    print("bone side =", SafeConVarString("cflash_vmanip_webknight_model_follow_side", "main_left"))
    print("fade time =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_fade_time", 0.55))
    print("deadzone =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_deadzone", 0.75))
    print("fade =", wbkModelFollowFade)
    print("pitch sign =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_pitch_sign", 1))
    print("yaw sign =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_yaw_sign", 1))
    print("camera-relative follow =", SafeConVarBool("cflash_vmanip_webknight_model_follow_use_camera_relative", true))
    print("return strength =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_return_strength", 5))
    print("left weight =", SafeConVarFloat("cflash_vmanip_webknight_model_follow_left_weight", 0.95))
    print("spring =", SafeConVarFloat("cflash_vmanip_webknight_proc_spring", 72))
    print("damping =", SafeConVarFloat("cflash_vmanip_webknight_proc_damping", 15))
    print("max speed =", SafeConVarFloat("cflash_vmanip_webknight_proc_max_speed", 115))
    print("procedural lag =", SafeConVarFloat("cflash_vmanip_webknight_proc_lag", 0.025))
    print("axis preset =", SafeConVarString("cflash_vmanip_webknight_proc_axis_preset", "swapped"))
    print("hand latch =", SafeConVarFloat("cflash_vmanip_webknight_hand_latch", 1))
    print("pseudo weld =", SafeConVarBool("cflash_vmanip_webknight_hand_pseudo_weld", true))
    print("hand pitch flip =", SafeConVarBool("cflash_vmanip_webknight_hand_pitch_flip", true))
    print("hand pos weld =", SafeConVarBool("cflash_vmanip_webknight_hand_pos_weld", true))
    print("hand pos weld amount =", SafeConVarFloat("cflash_vmanip_webknight_hand_pos_weld_amount", 0))
    print("hand pos weld forearm =", SafeConVarFloat("cflash_vmanip_webknight_hand_pos_weld_forearm", 0))
    print("stiff arm =", SafeConVarBool("cflash_vmanip_webknight_stiff_arm", false))
    print("handle support arm =", SafeConVarBool("cflash_vmanip_webknight_handle_support_arm", true))
    print("hand side yaw fix =", SafeConVarBool("cflash_vmanip_webknight_hand_side_yaw_fix", true))
    print("hand side amount =", SafeConVarFloat("cflash_vmanip_webknight_hand_side_amount", 0.56))
    print("hand vertical amount =", SafeConVarFloat("cflash_vmanip_webknight_hand_vertical_amount", 0.72))
    print("hand handle roll amount =", SafeConVarFloat("cflash_vmanip_webknight_hand_handle_roll_amount", 0.72))
    print("hand vertical roll amount =", SafeConVarFloat("cflash_vmanip_webknight_hand_vertical_roll_amount", 0.12))
    print("pitch vel =", wbkModelFollowPitchVel)
    print("yaw vel =", wbkModelFollowYawVel)
    print("smoothed pitch =", wbkModelFollowPitch)
    print("smoothed yaw =", wbkModelFollowYaw)
    print("anim light follow remaining =", math.Round(math.max((wbkLightFollowsAnimUntil or 0) - CurTime(), 0), 3))
    print("anim light blend remaining =", math.Round(math.max((ICF_WBKAnimLightBlendOutUntil or 0) - CurTime(), 0), 3))
    print("anim light last transform =", tostring(ICF_WBKAnimLightLastPos ~= nil and ICF_WBKAnimLightLastAng ~= nil))
    print("model follow starts in =", math.Round(math.max((wbkModelFollowsLightAfter or 0) - CurTime(), 0), 3))
    print("has desired angle =", wbkLastDesiredLightAng ~= nil)

    local mdl = ICF_GetWebKnightVManipGestureModel()
    print("gesture model valid =", IsValid(mdl))

    if IsValid(mdl) then
        print("model angles =", tostring(mdl:GetAngles()))
        local att = mdl:LookupAttachment("FlashLight")
        print("FlashLight attachment id =", att or 0)

        if att and att > 0 then
            local posang = mdl:GetAttachment(att)
            print("attachment valid =", posang ~= nil)

            if posang then
                print("attachment corrected angle =", tostring(posang.Ang + Angle(180, -10, 0)))
            end
        end
    end

    if wbkLastDesiredLightAng then
        print("desired light angle =", tostring(wbkLastDesiredLightAng))
    end
end)

concommand.Add("cflash_vmanip_webknight_follow_debug", function()
    print("---- ICF WebKnight Light Follow Debug ----")
    print("compat =", SafeConVarBool("cflash_vmanip_compat", false))
    print("mode =", ICF_GetVManipMode())
    print("follow light =", SafeConVarBool("cflash_vmanip_webknight_follow_light", true))
    print("third-person active =", ICF_IsThirdPersonActive(LocalPlayer()))
    print("WBK shoulder =", WBK_IsFlashlightOnShoulder == true)

    local mdl = ICF_GetWebKnightVManipGestureModel()
    print("gesture model valid =", IsValid(mdl))

    if IsValid(mdl) then
        local att = mdl:LookupAttachment("FlashLight")
        print("FlashLight attachment id =", att or 0)

        if att and att > 0 then
            local posang = mdl:GetAttachment(att)
            print("attachment valid =", posang ~= nil)
            if posang then
                print("attachment pos =", tostring(posang.Pos))
                print("attachment ang =", tostring(posang.Ang))
            end
        end
    end

    local pos, ang = ICF_GetWebKnightVManipLightTransform()
    print("using follow transform =", pos ~= nil and ang ~= nil)

    if pos and ang then
        print("light pos =", tostring(pos))
        print("light ang =", tostring(ang))
    end
end)

concommand.Add("cflash_vmanip_webknight_spam_debug", function()
    print("---- ICF WebKnight VManip Spam Debug ----")
    print("mode =", ICF_GetVManipMode())
    print("effective lockout =", ICF_GetVManipLockout())
    print("nextVManipAnimAllowed remaining =", math.Round(math.max((nextVManipAnimAllowed or 0) - CurTime(), 0), 3))
    print("pendingVManipToggle =", pendingVManipToggle)
    print("enabled light state =", enabled)
    print("third-person active =", ICF_IsThirdPersonActive(LocalPlayer()))

    if VManip then
        local current = ""

        if isfunction(VManip.GetCurrentAnim) then
            current = tostring(VManip:GetCurrentAnim() or "")
        end

        local active = false
        if isfunction(VManip.IsActive) then
            local ok, result = pcall(function() return VManip:IsActive() end)
            if ok then active = result end
        end

        print("VManip current anim =", current)
        print("VManip active =", active)
        print("Flashlight_In registered =", VManip.GetAnim and VManip:GetAnim("Flashlight_In") ~= nil)
        print("Flashlight_Out registered =", VManip.GetAnim and VManip:GetAnim("Flashlight_Out") ~= nil)
    else
        print("VManip missing")
    end
end)

concommand.Add("cflash_vmanip_webknight_debug", function()
    local hooks = hook.GetTable()
    local bindHooks = hooks.PlayerBindPress or {}
    local thinkHooks = hooks.Think or {}

    print("---- ICF WebKnight VManip Debug ----")
    print("compat enabled =", SafeConVarBool("cflash_vmanip_compat", false))
    print("vmanip mode =", ICF_GetVManipMode())
    print("VManip exists =", VManip ~= nil)
    print("Flashlight_In anim =", VManip and isfunction(VManip.GetAnim) and VManip:GetAnim("Flashlight_In") ~= nil)
    print("Flashlight_Out anim =", VManip and isfunction(VManip.GetAnim) and VManip:GetAnim("Flashlight_Out") ~= nil)
    print("Flashlight_EnableDisable anim =", VManip and isfunction(VManip.GetAnim) and VManip:GetAnim("Flashlight_EnableDisable") ~= nil)
    print("WBK PlayerBindPress hook active =", bindHooks.FlashLight_KeyPress ~= nil)
    print("WBK Think hook active =", thinkHooks.FlashLight_EnableFlashlight ~= nil)
    print("Default PlayerBindPress hook active =", bindHooks.SmartFlashlightAnim ~= nil)
    print("stored WBK bind hook =", storedWBKFlashlightKeyHook ~= nil)
    print("stored WBK think hook =", storedWBKFlashlightThinkHook ~= nil)
    print("stored Default hook =", storedSmartFlashlightAnimHook ~= nil)
end)

concommand.Add("cflash_vmanip_lockout_debug", function()
    print("---- ICF VManip Lockout Debug ----")
    print("raw cflash_vmanip_anim_lockout =", SafeConVarFloat("cflash_vmanip_anim_lockout", 1.15))
    print("effective lockout =", ICF_GetVManipLockout())
    print("nextVManipAnimAllowed remaining =", math.Round(math.max(nextVManipAnimAllowed - CurTime(), 0), 2))
    print("vmanipBindHandledUntil remaining =", math.Round(math.max(vmanipBindHandledUntil - CurTime(), 0), 2))
    print("nextCustomToggleTime remaining =", math.Round(math.max(nextCustomToggleTime - CurTime(), 0), 2))
end)


concommand.Add("cflash_vmanip_bridge_debug", function()
    local ply = LocalPlayer()
    print("---- ICF VManip Bridge Debug ----")
    print("bridge enabled =", SafeConVarBool("cflash_vmanip_emptyhands_bridge", false))
    print("vmanip compat =", SafeConVarBool("cflash_vmanip_compat", false))
    print("player valid =", IsValid(ply))

    if IsValid(ply) then
        local active = ply:GetActiveWeapon()
        print("active valid =", IsValid(active))
        print("active class =", IsValid(active) and active:GetClass() or "nil")
        print("hands-like active =", ICF_IsHandsLikeWeapon(active))
        print("hands class list =", SafeConVarString("cflash_vmanip_bridge_hands_classes", ""))
        print("has bridge weapon =", ply:HasWeapon("weapon_icf_vmanip_bridge"))
    end

    print("pending until =", math.Round(math.max(bridgeWeaponPendingUntil - CurTime(), 0), 2))

    if not SafeConVarBool("cflash_vmanip_emptyhands_bridge", false) then
        print("Bridge is OFF. Run cflash_vmanip_bridge_enable or enable the menu checkbox.")
    end

    chat.AddText(Color(120, 220, 255), "[Immersive Custom Flashlight] ", Color(255, 255, 255), "Bridge debug printed to console.")
end)


concommand.Add("cflash_test_manual_vmanip_draw", function()
    local started = ForcePlayVManipFlashlightAnim()

    print("[Immersive Custom Flashlight] Manual VManip draw test started =", started)
    print("[Immersive Custom Flashlight] VManip.VMGesture valid =", IsValid(VManip and VManip.VMGesture))
    print("[Immersive Custom Flashlight] VManip.VMCam valid =", IsValid(VManip and VManip.VMCam))
    print("[Immersive Custom Flashlight] Forced empty-hands flag =", icfForcedEmptyHandsVManip)

    chat.AddText(
        Color(120, 220, 255), "[Immersive Custom Flashlight] ",
        Color(255, 255, 255), "Manual VManip draw test ran. Check for the flashlight animation."
    )
end)


hook.Add("VManipPreActCheck", "ICF_VManipFlashlightBypass", function(name, vm)
    if not SafeConVarBool("cflash_vmanip_compat", false) then return end
    if name ~= "Flashlight_EnableDisable" then return end

    return true
end)

concommand.Add("cflash_test_vmanip_anim", function()
    local played = TryPlayVManipFlashlightAnim()

    if played then
        chat.AddText(Color(120, 220, 255), "[Immersive Custom Flashlight] ", Color(255, 255, 255), "VManip animation call succeeded. If you did not see it, run cflash_vmanip_debug and send the console output.")
    else
        chat.AddText(Color(120, 220, 255), "[Immersive Custom Flashlight] ", Color(255, 255, 255), "Direct VManip animation call failed. Compatibility will still block stock flashlight and toggle this addon's light normally.")
    end
end)


concommand.Add("cflash_vmanip_debug", function()
    local ply = LocalPlayer()
    local lines = {}

    local function safe(value)
        if value == nil then return "nil" end
        return tostring(value)
    end

    local function add(msg)
        table.insert(lines, safe(msg))
    end

    add("---- Immersive Custom Flashlight / VManip Debug ----")
    add("cflash_vmanip_compat = " .. safe(SafeConVarBool("cflash_vmanip_compat", false)))
    add("VManip exists = " .. safe(VManip ~= nil))

    if VManip then
        add("VManip.PlayAnim exists = " .. safe(isfunction(VManip.PlayAnim)))
        add("VManip.GetAnim exists = " .. safe(isfunction(VManip.GetAnim)))
        add("VManip.IsActive exists = " .. safe(isfunction(VManip.IsActive)))

        if isfunction(VManip.IsActive) then
            local ok, active = pcall(function() return VManip:IsActive() end)
            add("VManip:IsActive() = " .. safe(ok and active))
        end

        if isfunction(VManip.GetAnim) then
            local ok, anim = pcall(function() return VManip:GetAnim("Flashlight_EnableDisable") end)
            add("Flashlight_EnableDisable registered before ensure = " .. safe(ok and anim ~= nil))
        end
    end

    add("player valid = " .. safe(IsValid(ply)))

    if IsValid(ply) then
        add("player alive = " .. safe(ply:Alive()))
        add("in vehicle = " .. safe(ply:InVehicle()))
        add("view entity is player = " .. safe(ply:GetViewEntity() == ply))

        local wep = ply:GetActiveWeapon()
        add("active weapon valid = " .. safe(IsValid(wep)))

        if not IsValid(wep) then
            add("VManip fallback reason: active weapon invalid, force path will be tried.")
        end

        if IsValid(wep) then
            add("weapon class = " .. safe(wep:GetClass()))
            add("weapon holdtype = " .. safe(wep:GetHoldType()))

            if isfunction(wep.GetStatus) then
                local ok, status = pcall(function() return wep:GetStatus() end)
                add("weapon GetStatus = " .. safe(ok and status))
            end
        end

        local vm = ply:GetViewModel()
        add("viewmodel valid = " .. safe(IsValid(vm)))

        if IsValid(vm) then
            add("viewmodel model = " .. safe(vm:GetModel()))
            add("viewmodel sequence = " .. safe(vm:GetSequence()))
            add("viewmodel activity = " .. safe(vm:GetSequenceActivity(vm:GetSequence())))
        end
    end

    local ensured = EnsureVManipFlashlightAnim()
    add("EnsureVManipFlashlightAnim() = " .. safe(ensured))

    if VManip and isfunction(VManip.GetAnim) then
        local ok, anim = pcall(function() return VManip:GetAnim("Flashlight_EnableDisable") end)
        add("Flashlight_EnableDisable registered after ensure = " .. safe(ok and anim ~= nil))
    end

    local ok, played = pcall(function()
        return TryPlayVManipFlashlightAnim()
    end)

    add("TryPlayVManipFlashlightAnim pcall ok = " .. safe(ok))
    add("TryPlayVManipFlashlightAnim result = " .. safe(played))
    add("manual forced empty-hands flag = " .. safe(icfForcedEmptyHandsVManip))
    add("manual forced empty-hands until remaining = " .. safe(math.Round(math.max(icfForcedEmptyHandsUntil - CurTime(), 0), 2)))

    for _, line in ipairs(lines) do
        print(line)
    end

    chat.AddText(
        Color(120, 220, 255), "[Immersive Custom Flashlight] ",
        Color(255, 255, 255), "VManip debug printed to console."
    )
end)


hook.Add("Think", "CustomFlashlightThink", function()
    local modEnabled = SafeConVarBool("cflash_enabled", true)

    if not modEnabled then
        if enabled then
            enabled = false
            DestroyLight()
            ICF_MP_SendLocalState(false, nil, true)
        end

        ICF_MP_DestroyAllRemoteLights()

        pendingVManipToggle = false
        nextCustomToggleTime = 0
        vmanipBindHandledUntil = 0
        nextVManipAnimAllowed = 0
        nextVManipHookMaintenance = 0
        MaintainVManipDefaultFlashlightHook()


        lastF = ICF_IsBindDown(GetFlashlightKey())
        lastBatteryReloadKey = ICF_IsBindDown(GetBatteryReloadKey())
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local alive = ply:Alive()

    MaintainVManipDefaultFlashlightHook(SafeConVarBool("cflash_vmanip_strict_hook_guard", true))

    ICF_SuppressNativeStockFlashlight(false)

    ICF_MP_UpdateRemoteLights(ply)

    if not alive then
        if not SafeConVarBool("cflash_keep_on_death", true) then
            enabled = false
            ICF_MP_SendLocalState(false, nil, true)
        end

        DestroyLight()
        wasAlive = false
        lastF = ICF_IsBindDown(GetFlashlightKey())
        lastBatteryReloadKey = ICF_IsBindDown(GetBatteryReloadKey())
        return
    end

    ICF_HandleWebKnightShoulderBind()

    if not wasAlive then
        wasAlive = true

        if enabled and SafeConVarBool("cflash_keep_on_death", true) then
            CreateLight()
        end
    end

    ICF_UpdateBattery(FrameTime())

    if ICF_IsMenuOrTextInputActive() then
        lastF = ICF_IsBindDown(GetFlashlightKey())
        lastBatteryReloadKey = ICF_IsBindDown(GetBatteryReloadKey())
    else
        local f = ICF_IsBindDown(GetFlashlightKey())

        if f and not lastF then
            if CurTime() >= vmanipBindHandledUntil then
                RequestFlashlightToggle()
            end
        end

        lastF = f

        local batteryReloadKeyDown = ICF_IsBindDown(GetBatteryReloadKey())

        if batteryReloadKeyDown and not lastBatteryReloadKey then
            ICF_StartBatteryReload()
        end

        lastBatteryReloadKey = batteryReloadKeyDown
    end

    if enabled and ply:InVehicle() and not SafeConVarBool("cflash_vehicle_flashlight", true) then
        DestroyLight()
        ICF_MP_SendLocalState(false, nil, true)
        return
    end

    if enabled and not IsValid(proj) then
        CreateLight()
    end

    if not enabled or not IsValid(proj) then
        ICF_MP_SendLocalState(false, nil, false)
        return
    end

    local dt = FrameTime()
    local t = CurTime()

    local eyeAng = ply:EyeAngles()
    local eyePos = ply:EyePos()

    local flashlightBaseAng = Angle(eyeAng.p, eyeAng.y, 0)

    local pitchTarget = pitch + math.AngleDifference(flashlightBaseAng.p, pitch)
    local yawTarget = yaw + math.AngleDifference(flashlightBaseAng.y, yaw)

    pitch, pitchVel = Spring(
        pitch,
        pitchVel,
        pitchTarget,
        SafeConVarFloat("cflash_strength", 49),
        SafeConVarFloat("cflash_damping", 9),
        dt
    )

    yaw, yawVel = Spring(
        yaw,
        yawVel,
        yawTarget,
        SafeConVarFloat("cflash_strength", 49),
        SafeConVarFloat("cflash_damping", 9),
        dt
    )

    yaw = math.NormalizeAngle(yaw)
    pitch = math.NormalizeAngle(pitch)

    local swayPitch = 0
    local swayYaw = 0

    local breath = SafeConVarFloat("cflash_breath", 1.05)
    swayPitch = swayPitch + math.sin(t * 1.6) * breath
    swayYaw = swayYaw + math.cos(t * 1.3) * breath

    local fearAmount = SafeConVarFloat("cflash_shake", 0.17)
    local fearSpeed = SafeConVarFloat("cflash_shake_speed", 6)

    if fearAmount > 0 then
        if t >= nextFearTarget then
            local interval = math.Clamp(1 / math.max(fearSpeed, 1), 0.04, 0.5)
            nextFearTarget = t + math.Rand(interval * 0.4, interval * 1.4)
            fearTargetX = math.Rand(-1, 1)
            fearTargetY = math.Rand(-1, 1)
        end

        fearX = Lerp(dt * math.Clamp(fearSpeed * 1.5, 1, 30), fearX, fearTargetX)
        fearY = Lerp(dt * math.Clamp(fearSpeed * 1.5, 1, 30), fearY, fearTargetY)

        swayPitch = swayPitch + fearX * fearAmount
        swayYaw = swayYaw + fearY * fearAmount
    else
        fearX = Lerp(dt * 8, fearX, 0)
        fearY = Lerp(dt * 8, fearY, 0)
    end

    local speed = ply:GetVelocity():Length2D()

    walkBlend = Lerp(dt * 4, walkBlend, math.Clamp(speed / 200, 0, 1))

    local walkAmount = SafeConVarFloat("cflash_walksway", 1.49)
    swayPitch = swayPitch + math.sin(t * 8) * walkAmount * walkBlend
    swayYaw = swayYaw + math.cos(t * 6) * walkAmount * walkBlend

    local isSprinting =
        ply:KeyDown(IN_SPEED) and
        speed > 120 and
        SafeConVarBool("cflash_sprint_bob", false)

    sprintBlend = Lerp(dt * 3, sprintBlend, isSprinting and 1 or 0)

    local posOffset = Vector(0, 0, 0)

    if sprintBlend > 0.01 then
        local bobIntensity = SafeConVarFloat("cflash_sprint_bob_intensity", 10.00)
        local bobSpeed = SafeConVarFloat("cflash_sprint_bob_speed", 11)
        local posBob = SafeConVarFloat("cflash_sprint_pos_bob", 0.00)

        local speedScale = math.Clamp(speed / 300, 0.8, 1.5)
        sprintBobPhase = (sprintBobPhase + dt * bobSpeed * speedScale) % (math.pi * 2)

        local verticalSwing = math.sin(sprintBobPhase)
        local sideSwing = math.sin(sprintBobPhase * 0.5)
        local stepPulse = (1 - math.cos(sprintBobPhase)) * 0.5

        local turnStabilizer = 1

        if SafeConVarBool("cflash_sprint_bob_turn_stabilize", true) then
            local yawLag = math.abs(math.AngleDifference(flashlightBaseAng.y, yaw))
            local pitchLag = math.abs(math.AngleDifference(flashlightBaseAng.p, pitch))
            local lookLag = yawLag + pitchLag * 0.5
            turnStabilizer = 1 - math.Clamp((lookLag - 8) / 42, 0, 0.85)
        end

        local sprintBasisAng = Angle(pitch, yaw, 0)
        local bobBlend = sprintBlend * turnStabilizer

        swayPitch = swayPitch + verticalSwing * bobIntensity * bobBlend
        swayYaw = swayYaw + sideSwing * bobIntensity * 0.35 * bobBlend

        posOffset =
            sprintBasisAng:Up() * (stepPulse * posBob * bobBlend) +
            sprintBasisAng:Right() * (sideSwing * posBob * 0.45 * bobBlend)
    else
        sprintBobPhase = 0
    end

    local finalPos = eyePos + posOffset
    local finalAng = Angle(
        pitch + swayPitch,
        yaw + swayYaw,
        0
    )

    local thirdPersonPos = ICF_GetThirdPersonBasePosition(ply, finalAng)

    if thirdPersonPos then
        finalPos = thirdPersonPos + posOffset
    end

    finalPos = ApplyPositionOffset(finalPos, finalAng)

    finalPos, finalAng = ICF_ApplyBatteryReloadAnimation(finalPos, finalAng)

    local vmanipLightPos, vmanipLightAng = ICF_GetWebKnightVManipLightTransform()
    local didAnimLightFollow = false

    if vmanipLightPos and vmanipLightAng and ICF_WebKnightLightShouldFollowAnim() then
        finalPos = vmanipLightPos
        finalAng = vmanipLightAng
        didAnimLightFollow = true

        ICF_WBKAnimLightLastPos = vmanipLightPos
        ICF_WBKAnimLightLastAng = vmanipLightAng
        ICF_WBKAnimLightBlendOutStartPos = vmanipLightPos
        ICF_WBKAnimLightBlendOutStartAng = vmanipLightAng
    elseif ICF_WebKnightLightShouldFollowAnim() and ICF_WBKAnimLightLastPos and ICF_WBKAnimLightLastAng then
        finalPos = ICF_WBKAnimLightLastPos
        finalAng = ICF_WBKAnimLightLastAng
        didAnimLightFollow = true
    else
        if not ICF_IsThirdPersonActive(ply) then
            local push = SafeConVarFloat("cflash_firstperson_viewmodel_push", 8)

            if push ~= 0 then
                finalPos = finalPos + finalAng:Forward() * push
            end
        end

        if ICF_WebKnightAnimBlendOutActive() then
            local blendDuration = math.max(ICF_WBKAnimLightBlendOutDuration or 0.32, 0.05)
            local blendStart = (ICF_WBKAnimLightBlendOutUntil or 0) - blendDuration
            local blendFrac = math.Clamp((CurTime() - blendStart) / blendDuration, 0, 1)
            blendFrac = blendFrac * blendFrac * (3 - 2 * blendFrac)

            if ICF_WBKAnimLightBlendOutStartPos and ICF_WBKAnimLightBlendOutStartAng then
                ICF_WBKBlendOutNormalAng = finalAng
                finalPos = LerpVector(blendFrac, ICF_WBKAnimLightBlendOutStartPos, finalPos)

                ICF_WBKBlendOutFromDir = ICF_WBKAnimLightBlendOutStartAng:Forward()
                ICF_WBKBlendOutToDir = ICF_WBKBlendOutNormalAng:Forward()
                ICF_WBKBlendOutMixedDir = (ICF_WBKBlendOutFromDir * (1 - blendFrac)) + (ICF_WBKBlendOutToDir * blendFrac)

                if ICF_WBKBlendOutMixedDir:LengthSqr() > 0.0001 then
                    finalAng = ICF_WBKBlendOutMixedDir:GetNormalized():Angle()
                    finalAng.r = 0
                else
                    finalAng = ICF_WBKBlendOutNormalAng
                    finalAng.r = 0
                end
            end
        end

        wbkLastDesiredLightPos = finalPos
        wbkLastDesiredLightAng = finalAng
        ICF_ApplyWebKnightModelFollow(finalPos, finalAng)
    end

    ICF_MainLightTemporarilyHidden = false
    if ICF_WebKnightLightShouldFollowAnim() and not vmanipLightPos and not ICF_WBKAnimLightLastPos then
        ICF_MainLightTemporarilyHidden = true
    end

    local dynamicNearZ = 2
    finalPos, dynamicNearZ = ApplyWallDetection(ply, finalPos, finalAng)

    ICF_UpdateMainProjectedTexture(proj, finalPos, finalAng, dynamicNearZ)
    ICF_UpdateLightspill(finalPos, finalAng, dynamicNearZ)

    ICF_MP_SendLocalState(true, finalAng, false, finalPos)

end)


concommand.Add("cflash_color_reset", function()
    RunConsoleCommand("cflash_color_r", "255")
    RunConsoleCommand("cflash_color_g", "255")
    RunConsoleCommand("cflash_color_b", "255")
end)

concommand.Add("cflash_lightspill_color_reset", function()
    RunConsoleCommand("cflash_lightspill_color_r", "255")
    RunConsoleCommand("cflash_lightspill_color_g", "255")
    RunConsoleCommand("cflash_lightspill_color_b", "255")
end)


timer.Simple(0, function()
    local cv = GetConVar("cflash_battery_reload_sound")

    if cv and cv:GetString() == "items/battery_pickup.wav" then
        RunConsoleCommand("cflash_battery_reload_sound", "immersive_custom_flashlight/battery_reload.wav")
    end
end)

concommand.Add("cflash_battery_reload_sound_default", function()
    RunConsoleCommand("cflash_battery_reload_sound", "immersive_custom_flashlight/battery_reload.wav")
end)


CreateClientConVar("cflash_battery_reload_n_migrated", "0", true, false)

timer.Simple(0, function()
    local migrated = GetConVar("cflash_battery_reload_n_migrated")
    local reloadKey = GetConVar("cflash_battery_reload_key")

    if migrated and reloadKey and migrated:GetBool() == false and tonumber(reloadKey:GetString() or "") == KEY_B then
        RunConsoleCommand("cflash_battery_reload_key", tostring(KEY_N))
        RunConsoleCommand("cflash_battery_reload_n_migrated", "1")
    end
end)

concommand.Add("cflash_battery_add_spare", function(_, _, args)
    ICF_AddSpareBatteries(tonumber(args and args[1]) or 1)
end)

concommand.Add("cflash_battery_clear_spares", function()
    ICF_SetSpareBatteryCount(0)
end)

concommand.Add("cflash_battery_reload", function()
    ICF_StartBatteryReload()
end)

concommand.Add("cflash_battery_refill", function()
    ICF_SetBatteryLevel(100, true)
end)


concommand.Add("cflash_reload_scope_debug", function()
    print("---- ICF Reload Scope Debug ----")
    print("ICF_SafeDestroyLight exists =", isfunction(ICF_SafeDestroyLight))
    print("ICF_TryBatteryReloadRelight exists =", isfunction(ICF_TryBatteryReloadRelight))
    print("batteryReloading =", batteryReloading)
    print("batteryReloadWasEnabled =", batteryReloadWasEnabled)
    print("batteryReloadRelit =", batteryReloadRelit)
    print("batteryReloadRelightTime remaining =", math.Round(math.max((batteryReloadRelightTime or 0) - CurTime(), 0), 3))
    print("batteryReloadFlickerEnd remaining =", math.Round(math.max((batteryReloadFlickerEnd or 0) - CurTime(), 0), 3))
    print("startup flicker remaining =", math.Round(math.max((startupFlickerEnd or 0) - CurTime(), 0), 3))
    print("startup flicker enabled =", SafeConVarBool("cflash_startup_flicker_enabled", false))
end)

concommand.Add("cflash_scope_debug", function()
    print("---- ICF Scope Debug ----")
    print("DestroyLight local exists =", isfunction(DestroyLight))
    print("CreateLight local exists =", isfunction(CreateLight))
    print("DoFlashlightToggle local exists =", isfunction(DoFlashlightToggle))
    print("proj valid =", IsValid(proj))
end)

concommand.Add("cflash_battery_debug", function()
    print("---- ICF Battery Debug ----")
    print("battery enabled =", ICF_BatteryEnabled())
    print("battery level =", math.Round(ICF_GetBatteryLevel(), 2))
    print("spare batteries =", ICF_GetSpareBatteryCount() .. "/" .. ICF_GetMaxSpareBatteries())
    print("battery reload enabled =", SafeConVarBool("cflash_battery_reload_enabled", true))
    print("battery reload key =", GetBatteryReloadKey())
    print("allow normal reload key =", SafeConVarBool("cflash_battery_reload_allow_weapon_reload", false))
    print("drain per second =", math.Clamp(SafeConVarFloat("cflash_battery_drain_rate", 1.25), 0, 100))
    print("recharge per second =", math.Clamp(SafeConVarFloat("cflash_battery_recharge_rate", 2.5), 0, 100))
    print("estimated full-drain seconds =", math.Round(100 / math.max(math.Clamp(SafeConVarFloat("cflash_battery_drain_rate", 1.25), 0, 100), 0.001), 2))
end)


concommand.Add("cflash_battery_empty", function()
    ICF_SetBatteryLevel(0, true)

    if enabled then
        enabled = false
        DestroyLight()
    end
end)


hook.Add("VManipVMEntity", "ICF_WebKnightModelFollowVMEntity", function(ply, weapon)
    if wbkLastDesiredLightAng then
        ICF_ApplyWebKnightModelFollow(wbkLastDesiredLightPos, wbkLastDesiredLightAng)
    end

end)

hook.Add("Think", "ICF_WebKnightModelFollowThink", function()
    if wbkLastDesiredLightAng then
        ICF_ApplyWebKnightModelFollow(wbkLastDesiredLightPos, wbkLastDesiredLightAng)
    end
end)

hook.Add("PreDrawViewModel", "ICF_WebKnightModelFollowPreDraw", function()
    if wbkLastDesiredLightAng then
        ICF_ApplyWebKnightModelFollow(wbkLastDesiredLightPos, wbkLastDesiredLightAng)
    end
end)

hook.Add("PostDrawViewModel", "ICF_WebKnightModelFollowPostDraw", function()
    if wbkLastDesiredLightAng then
        ICF_ApplyWebKnightModelFollow(wbkLastDesiredLightPos, wbkLastDesiredLightAng)
    end
end)

hook.Add("HUDPaint", "ICF_BatteryHUD", function()
    if not ICF_BatteryEnabled() then return end
    if not SafeConVarBool("cflash_battery_hud", true) then return end

    local pct = ICF_GetBatteryLevel()
    local w = 245
    local h = 18
    local x = ScrW() - w - 36
    local y = ScrH() - h - 72
    local fill = math.Clamp(pct / 100, 0, 1)

    draw.RoundedBox(4, x - 2, y - 2, w + 4, h + 4, Color(0, 0, 0, 170))
    draw.RoundedBox(3, x, y, w, h, Color(25, 25, 25, 210))

    local barColor = Color(120, 220, 255, 230)

    if pct <= SafeConVarFloat("cflash_battery_low_threshold", 20) then
        barColor = Color(255, 180, 70, 235)
    end

    if pct <= 5 then
        barColor = Color(255, 80, 70, 240)
    end

    draw.RoundedBox(3, x, y, math.floor(w * fill), h, barColor)
    draw.SimpleText("FLASHLIGHT " .. math.Round(pct) .. "%  |  BATTERIES " .. ICF_GetSpareBatteryCount() .. "/" .. ICF_GetMaxSpareBatteries(), "DermaDefaultBold", x + w / 2, y + h / 2, Color(255, 255, 255, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)


hook.Add("ShutDown", "CustomFlashlightCleanup", DestroyLight)
hook.Add("OnReloaded", "CustomFlashlightCleanupReload", DestroyLight)


concommand.Add("cflash_gcal_status", function()
    print("----- ICFL GCAL Minimal Shim Status -----")
    print("Animation compatibility enabled = " .. tostring(SafeConVarBool("cflash_vmanip_compat", false)))
    print("Raw animation backend cvar = " .. tostring(SafeConVarString("cflash_vmanip_mode", "default")))
    print("Effective ICFL animation logic = " .. tostring(ICF_GetVManipMode and ICF_GetVManipMode() or "nil"))
    print("GCAL exists = " .. tostring(GCAL ~= nil))
    print("VManip exists = " .. tostring(VManip ~= nil))
    if VManip and isfunction(VManip.GetCurrentAnim) then
        print("Current VManip/GCAL shim anim = " .. tostring(VManip:GetCurrentAnim()))
    end
    if VManip and isfunction(VManip.GetAnim) then
        print("Flashlight_In anim = " .. tostring(VManip:GetAnim("Flashlight_In") ~= nil))
        print("Flashlight_Out anim = " .. tostring(VManip:GetAnim("Flashlight_Out") ~= nil))
        print("Flashlight_EnableDisable anim = " .. tostring(VManip:GetAnim("Flashlight_EnableDisable") ~= nil))
    end
    print("WBK shoulder state = " .. tostring(WBK_IsFlashlightOnShoulder == true))
    print("ICFL enabled light state = " .. tostring(enabled == true))
    print("nextVManipAnimAllowed remaining = " .. tostring(math.Round(math.max((nextVManipAnimAllowed or 0) - CurTime(), 0), 2)))
    print("pendingVManipToggle = " .. tostring(pendingVManipToggle == true))
    print("GCAL/VManip camera passthrough = enabled for flashlight animations")
    print("GCAL note = Minimal shim test: cflash_vmanip_mode gcal uses the same WebKnight code path as standard support, with GCAL replacing VManip underneath. No direct GCAL state machine, no attachment-follow.")
    print("-----------------------------------------")
end)
