include("shared.lua")
include("modules/animation/sh_black_mesa_firstperson.lua")
include("core/client/cl_fonts.lua")
include("modules/effects/cl_vhs_startup.lua")
include("modules/audio/cl_audio_visualizer.lua")
include("modules/audio/cl_ui_sounds.lua")

-- Define and lock the found-footage camera before vendor systems load.
include("modules/camera/cl_smooth_stairs.lua")
include("modules/camera/cl_camera.lua")
include("vendor_loader.lua")

include("modules/effects/cl_effects.lua")
include("modules/effects/cl_underwater.lua")
include("modules/effects/cl_step_dust.lua")
include("modules/effects/cl_collision.lua")

include("modules/audio/cl_reverb.lua")
include("modules/audio/cl_muffling.lua")
include("modules/audio/cl_falling_wind.lua")
include("modules/audio/cl_footsteps.lua")
include("modules/audio/cl_surround_ambience.lua")
include("modules/hud/cl_camcorder_status.lua")

include("modules/visual/cl_shadows.lua")
include("modules/visual/cl_player_shadow.lua")
include("modules/visual/cl_csm_lite.lua")
include("modules/horror/sh_caveman_entity.lua")
include("modules/horror/cl_paranormal.lua")

-- Restrictions and convar locks run after vendor convars have been created.
include("core/client/cl_restrictions.lua")
include("modules/hud/cl_hud.lua")
include("modules/hud/cl_pause_menu.lua")
