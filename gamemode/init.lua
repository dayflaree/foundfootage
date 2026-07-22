AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("configuration.lua")
AddCSLuaFile("vendor_loader.lua")

local clientFiles = {
    "core/client/cl_fonts.lua",
    "core/client/cl_restrictions.lua",
    "modules/effects/cl_vhs_startup.lua",

    "modules/animation/sh_black_mesa_firstperson.lua",
    "modules/camera/cl_smooth_stairs.lua",
    "modules/visual/cl_csm_lite.lua",
    "modules/hud/cl_hud.lua",
    "modules/hud/cl_pause_menu.lua",
    "modules/map_messages/sh_map_messages.lua",
    "modules/map_messages/cl_map_messages.lua",
    "modules/camera/cl_camera.lua",

    "modules/effects/cl_effects.lua",
    "modules/effects/cl_underwater.lua",
    "modules/effects/cl_step_dust.lua",
    "modules/effects/cl_collision.lua",

    "modules/audio/cl_reverb.lua",
    "modules/audio/cl_muffling.lua",
    "modules/audio/cl_falling_wind.lua",
    "modules/audio/cl_footsteps.lua",
    "modules/audio/cl_surround_ambience.lua",
    "modules/hud/cl_camcorder_status.lua",
    "modules/audio/cl_audio_visualizer.lua",
    "modules/audio/cl_ui_sounds.lua",

    "modules/visual/cl_shadows.lua",
    "modules/visual/cl_player_shadow.lua",
    "modules/horror/sh_caveman_entity.lua",
    "modules/horror/cl_paranormal.lua",

    "vendor/immersive_custom_flashlight/cl_custom_flashlight.lua",
    "vendor/realistic_vhs2/cl_realistic_vhs2.lua",
    "vendor/threat_effects/cl_threateffects.lua",
    "vendor/threat_effects/cl_threateffects_fall.lua",
    "vendor/threat_effects/cl_threateffects_death.lua",

    "vendor/ik_foot/shared/sh_ik_foot_config.lua",
    "vendor/ik_foot/client/cl_ik_foot_sync.lua",
    "vendor/ik_foot/client/runtime/cl_ik_foot_context.lua",
    "vendor/ik_foot/client/runtime/ik_ground.lua",
    "vendor/ik_foot/client/runtime/ik_state.lua",
    "vendor/ik_foot/client/runtime/ik_controller.lua",
    "vendor/ik_foot/client/runtime/ik_apply.lua",
    "vendor/ik_foot/client/runtime/cl_ik_foot_hooks.lua",
}

for _, path in ipairs(clientFiles) do
    AddCSLuaFile(path)
end

include("shared.lua")
include("modules/animation/sh_black_mesa_firstperson.lua")
include("core/server/sv_resources.lua")
include("core/server/sv_lua_run_guard.lua")
include("core/server/sv_vhs_dsp.lua")

-- Vendor systems load before gameplay enforcement so their convars and hooks
-- exist when the central configuration is applied.
include("vendor_loader.lua")

include("core/server/sv_player.lua")
include("core/server/sv_health_regeneration.lua")
include("modules/animation/sv_black_mesa_firstperson.lua")
include("modules/audio/sv_audio_visualizer.lua")
include("modules/audio/sv_footsteps.lua")
include("modules/audio/sv_crouch.lua")
include("modules/audio/sv_prop_ambience.lua")
include("modules/effects/sv_collision.lua")
include("modules/horror/sh_caveman_entity.lua")
include("modules/horror/sv_paranormal.lua")
include("modules/horror/sv_caveman_spawner.lua")
include("modules/camera/sv_death_camera.lua")
include("modules/visual/sv_shadows.lua")
include("modules/visual/sv_csm_lite.lua")
include("modules/map_messages/sh_map_messages.lua")
include("modules/map_messages/sv_map_messages.lua")

include("core/server/sv_configuration.lua")
