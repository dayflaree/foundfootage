-- Vendor runtime bootstrap.
-- This file lives at the gamemode root so every include path is unambiguous.

local animation = FF_CONFIG.Animation
local movement = FF_CONFIG.Movement
local flashlight = FF_CONFIG.Flashlight
local effects = FF_CONFIG.Effects
local betterLights = FF_CONFIG.BetterLights or {}

if movement.Leaning and movement.Leaning.Enabled ~= false then
    if SERVER then
        AddCSLuaFile("vendor/leaning/sh_leaning.lua")
    end

    include("vendor/leaning/sh_leaning.lua")
end

local betterLightsSharedFiles = {
    "vendor/better_lights/runtime/autorun/betterlights_00_shared.lua",
}

local betterLightsServerFiles = {
    "vendor/better_lights/runtime/autorun/server/betterlights_admin.lua",
    "vendor/better_lights/runtime/autorun/server/betterlights_network.lua",
    "vendor/better_lights/runtime/autorun/server/betterlights_network_muzzle_integrations.lua",
    "vendor/better_lights/runtime/autorun/server/betterlights_explosions.lua",
    "vendor/better_lights/runtime/autorun/server/betterlights_explosions_integrations.lua",
}

local betterLightsClientFiles = {
    "vendor/better_lights/runtime/autorun/client/betterlights_00_core.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_00_profiles.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_00_policy.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_01_runtime.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_02_entities.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_02z_explosions_api.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_03_variants.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_04_projected_textures.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_05_held_weapons.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_06_debug_dynamic_lights.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_ammo_pickups.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_antlion_grub.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_antlion_guardian.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_antlion_spit.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_antlion_worker.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_bullet_impact.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_chargers.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_combine_ball.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_combine_mine.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_combine_soldier.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_crossbow_bolt.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_crossbow_hold.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_cscanner.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_explosions.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_explosions_integrations.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_fire.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_grenade.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_heli_bomb.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_hunter.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_hunter_chopper.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_magnusson.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_manhack.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_muzzle_blacklist.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_muzzle_flash.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_muzzle_flash_integrations.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_npc_eye_glow.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_pickups.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_rollermine.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_rpg_hold.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_rpg_missile.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_strider.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_stunstick_impact.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_tfa_projectiles.lua",
    "vendor/better_lights/runtime/autorun/client/betterlights_world_weapons.lua",
}

local function includeFiles(paths)
    for _, path in ipairs(paths) do
        include(path)
    end
end

if betterLights.Enabled ~= false then
    if SERVER then
        for _, path in ipairs(betterLightsSharedFiles) do
            AddCSLuaFile(path)
        end

        for _, path in ipairs(betterLightsClientFiles) do
            AddCSLuaFile(path)
        end
    end

    includeFiles(betterLightsSharedFiles)

    if SERVER then
        includeFiles(betterLightsServerFiles)
    else
        includeFiles(betterLightsClientFiles)
    end
end

local function retireExcludedBetterLightsRuntime()
    if CLIENT then
        local shutdownHooks = hook.GetTable().ShutDown
        local cleanup = shutdownHooks and shutdownHooks.BetterLights_PlayerFlashlightsCleanup
        if isfunction(cleanup) then
            pcall(cleanup)
        end

        for _, entry in ipairs({
            { "InitPostEntity", "BetterLights_FlashlightSyncSettings" },
            { "OnReloaded", "BetterLights_FlashlightSyncSettingsReload" },
            { "BetterLights_EffectiveEnabledChanged", "BetterLights_GlobalEnableFlashlight" },
            { "BetterLights_ServerSettingsChanged", "BetterLights_ServerSettingsFlashlight" },
            { "ShutDown", "BetterLights_PlayerFlashlightsCleanup" },
            { "PostDrawTranslucentRenderables", "BetterLights_PlayerFlashlightFlares" },
            { "OnEntityCreated", "BetterLights_Flashlight_ArcCW_Client" },
            { "BetterLights_EffectiveEnabledChanged", "BetterLights_ArcCWFlashlightsGlobal" },
            { "BetterLights_ServerSettingsChanged", "BetterLights_ArcCWFlashlightsServerSettings" },
            { "InitPostEntity", "BetterLights_Flashlight_ArcCW_Init_Client" },
            { "BetterLights_ServerSettingsChanged", "BetterLights_RefreshForcedSettingsMenu" },
            { "BetterLights_ClientEnabledChangeBlocked", "BetterLights_NotifyClientEnableBlocked" },
            { "BetterLights_ClientEnabledPreferenceChanged", "BetterLights_RefreshClientSettingsPage" },
            { "AddToolMenuTabs", "BetterLights_AddTab" },
            { "AddToolMenuCategories", "BetterLights_AddCategories" },
            { "PopulateToolMenu", "BetterLights_Populate" },
        }) do
            hook.Remove(entry[1], entry[2])
        end

        timer.Remove("BetterLights_Flashlight_ArcCW_Scan_Client")

        if BetterLights and BetterLights.RemoveThink then
            BetterLights.RemoveThink("BetterLights_PlayerFlashlights")
        end
    else
        for _, entry in ipairs({
            { "StartCommand", "BetterLights_FlashlightImpulse" },
            { "PlayerSwitchFlashlight", "BetterLights_FlashlightSwitch" },
            { "PlayerSpawn", "BetterLights_FlashlightSpawn" },
            { "PlayerDeath", "BetterLights_FlashlightDeath" },
            { "PlayerSilentDeath", "BetterLights_FlashlightSilentDeath" },
            { "PlayerSwitchWeapon", "BetterLights_FlashlightIntegrationSwitch" },
            { "BetterLights_ServerSettingsChanged", "BetterLights_FlashlightServerSettingsChanged" },
            { "TFA_PreDeploy", "BetterLights_TFAFlashlightDeploy_Pre" },
            { "TFA_Deploy", "BetterLights_TFAFlashlightDeploy_Post" },
            { "FlashlightThink", "BetterLights_OxygenStaminaFlashlightBattery" },
        }) do
            hook.Remove(entry[1], entry[2])
        end

        local playerMeta = FindMetaTable and FindMetaTable("Player")
        if playerMeta then
            if isfunction(playerMeta.BetterLights_OldFlashlight) then
                playerMeta.Flashlight = playerMeta.BetterLights_OldFlashlight
            end

            if isfunction(playerMeta.BetterLights_OldFlashlightIsOn) then
                playerMeta.FlashlightIsOn = playerMeta.BetterLights_OldFlashlightIsOn
            end
        end

        if net.Receivers and BetterLights and BetterLights.NET_FLASHLIGHT_CLIENT_SETTINGS then
            net.Receivers[string.lower(BetterLights.NET_FLASHLIGHT_CLIENT_SETTINGS)] = nil
        end
    end
end

retireExcludedBetterLightsRuntime()
hook.Add("InitPostEntity", "FF_RetireExcludedBetterLightsRuntime", retireExcludedBetterLightsRuntime)
hook.Add("OnReloaded", "FF_RetireExcludedBetterLightsRuntime", retireExcludedBetterLightsRuntime)

local function removeRetiredDynamicHeight()
    local hooks = {
        { "PopulateToolMenu", "DynamicPlayerHeight:PopulateToolMenu" },
        { "InitPostEntity", "DynamicPlayerHeight" },
        { "OnReloaded", "DynamicPlayerHeight" },
        { "CreateMove", "DynamicPlayerHeight:CreateMove" },
        { "RenderScene", "DynamicPlayerHeight:UpdateViewOffset" },
        { "RenderScene", "dph.UpdateEntity" },
        { "SetupMove", "DynamicPlayerHeight:SetupMove" },
        { "FinishMove", "DynamicPlayerHeight:SetupMove" },
        { "StartCommand", "dph.CrouchJumpFix" },
        { "OnRequestFullUpdate", "dph.ShitFix" },
        { "dph.CanEditHull", "dph.Compatible" },
        { "dph.ProcessSetupMove", "dph.Compatible" },
        { "dph.ProcessFinishMove", "dph.Compatible" },
        { "dph.ProcessCreateMove", "dph.Compatible" },
        { "dph.OverrideCurrentMode", "dph.Compatible" },
        { "dph.OverrideVMOffsetSmoothStairs", "dph.Compat" },
        { "cl_body.OverrideForwardDistance", "dph.Compat" },
    }

    for _, entry in ipairs(hooks) do
        hook.Remove(entry[1], entry[2])
    end

    for _, timerName in ipairs({
        "dph.QueueProcess",
        "dph.QueueUpdating",
        "DynamicPlayerHeight:RequestFullUpdate",
    }) do
        timer.Remove(timerName)
    end

    if concommand and concommand.Remove then
        concommand.Remove("dph_update_hull")
        concommand.Remove("dph_reload")
    end

    if CLIENT and cvars and cvars.RemoveChangeCallback then
        cvars.RemoveChangeCallback("dph_cl_smoothstairs", "dph_cl_smoothstairs")
        cvars.RemoveChangeCallback("dph_cl_dynamicmode", "dph_cl_dynamicmode")
        cvars.RemoveChangeCallback("dph_sv_dynamicmode", "dph_cl_dynamicmode")
        cvars.RemoveChangeCallback("dph_sv_dynamicheight", "dph_sv_dynamicheight")
    end

    if CLIENT then
        local commandMeta = FindMetaTable and FindMetaTable("CUserCmd")
        if commandMeta and isfunction(_CMD_SetViewAngles) then
            commandMeta.SetViewAngles = _CMD_SetViewAngles
        end

        local playerMeta = FindMetaTable and FindMetaTable("Player")
        if playerMeta and isfunction(_PLAYER_SetEyeAngles) then
            playerMeta.SetEyeAngles = _PLAYER_SetEyeAngles
        end

        if DynamicPlayerHeight and IsValid(DynamicPlayerHeight.ViewOffsetEntity) then
            DynamicPlayerHeight.ViewOffsetEntity:Remove()
            DynamicPlayerHeight.ViewOffsetEntity = nil
        end
    end
end

removeRetiredDynamicHeight()
hook.Add("OnReloaded", "FF_RemoveRetiredDynamicHeight", removeRetiredDynamicHeight)

if animation.IKFeet.Enabled then
    IKFoot = IKFoot or {}
    include("vendor/ik_foot/shared/sh_ik_foot_config.lua")

    if IKFoot.Config then
        if SERVER then
            include("vendor/ik_foot/server/sv_ik_foot_sync.lua")
            hook.Remove("PlayerSay", "IKFoot_ChatOpenMenu")
        else
            include("vendor/ik_foot/client/cl_ik_foot_sync.lua")
            include("vendor/ik_foot/client/runtime/cl_ik_foot_context.lua")
            include("vendor/ik_foot/client/runtime/ik_ground.lua")
            include("vendor/ik_foot/client/runtime/ik_state.lua")
            include("vendor/ik_foot/client/runtime/ik_controller.lua")
            include("vendor/ik_foot/client/runtime/ik_apply.lua")
            include("vendor/ik_foot/client/runtime/cl_ik_foot_hooks.lua")
            IKFoot._runtimeLoaded = true
        end
    end
end

if flashlight.Enabled then
    if SERVER then
        include("vendor/immersive_custom_flashlight/sv_custom_flashlight_multiplayer.lua")
    else
        hook.Remove("CreateMove", "CustomFlashlight_BodycamCreateMove")
        if concommand and concommand.Remove then
            concommand.Remove("cflash_bodycam_toggle")
        end

        include("vendor/immersive_custom_flashlight/cl_custom_flashlight.lua")
        hook.Remove("PopulateToolMenu", "CustomFlashlightMenu")
    end
end

if CLIENT and effects.VHS.Enabled then
    include("vendor/realistic_vhs2/cl_realistic_vhs2.lua")
end

if CLIENT and effects.Threat.Enabled then
    include("vendor/threat_effects/cl_threateffects.lua")
    include("vendor/threat_effects/cl_threateffects_fall.lua")
    include("vendor/threat_effects/cl_threateffects_death.lua")
    hook.Remove("PopulateToolMenu", "ThreatEffects_Menu")

    -- Keep the threat screen/audio effects while preventing its recursive
    -- CalcView hook from replacing the found-footage camera.
    hook.Remove("CalcView", "ThreatEffects")
end

