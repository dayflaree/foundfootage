IKFoot = IKFoot or {}

IKFoot.Config = {
	entries = {
		{ key = "enabled",               cvar = "ik_foot",                        type = "bool",  default = true,  min = 0,   max = 1,   decimals = 0, desc = "Enable/Disable IK Foot" },
		{ key = "lean_enabled",          cvar = "ik_foot_lean",                   type = "bool",  default = false, min = 0,   max = 1,   decimals = 0, desc = "Enable/Disable Body Lean" },
		{ key = "debug",                 cvar = "ik_foot_debug",                  type = "float", default = 0,     min = 0,   max = 2,   decimals = 0, desc = "Debug Visualization Level" },
		{ key = "ground_distance",       cvar = "ik_foot_ground_distance",        type = "float", default = 70,    min = 20,  max = 100, decimals = 0, desc = "Ground Trace Distance" },
		{ key = "smoothing",             cvar = "ik_foot_smoothing",              type = "float", default = 17,    min = 1,   max = 50,  decimals = 0, desc = "Smoothing Factor" },
		{ key = "leg_length",            cvar = "ik_foot_leg_length",             type = "float", default = 45,    min = 30,  max = 60,  decimals = 0, desc = "Leg Length for IK" },
		{ key = "trace_start_offset",    cvar = "ik_foot_trace_start_offset",     type = "float", default = 30,    min = 20,  max = 40,  decimals = 0, desc = "Trace Start Height" },
		{ key = "sole_offset",           cvar = "ik_foot_sole_offset",            type = "float", default = 0,     min = 0,   max = 5,   decimals = 2, desc = "Sole Contact Offset" },
		{ key = "uneven_drop_scale",     cvar = "ik_foot_uneven_drop_scale",      type = "float", default = 0.15,  min = 0,   max = 1,   decimals = 2, desc = "Height Diff Multiplier" },
		{ key = "extra_body_drop",       cvar = "ik_foot_extra_body_drop",        type = "float", default = 0.3,   min = 0,   max = 5,   decimals = 1, desc = "Body Drop (Flat)" },
		{ key = "extra_body_drop_uneven",cvar = "ik_foot_extra_body_drop_uneven", type = "float", default = 1.2,   min = 0,   max = 10,  decimals = 1, desc = "Body Drop (Uneven)" },
		{ key = "high_foot_bend_boost",  cvar = "ik_foot_high_foot_bend_boost",   type = "float", default = 1.70,  min = 1,   max = 2,   decimals = 2, desc = "High Foot Bend Boost" },
		{ key = "foot_rotation_scale",   cvar = "ik_foot_rotation_scale",         type = "float", default = 0.15,  min = 0,   max = 1,   decimals = 2, desc = "Foot Rotation Scale" },
		{ key = "lock_strength",         cvar = "ik_foot_lock_strength",          type = "float", default = 0.85,  min = 0.1, max = 2,   decimals = 2, desc = "Foot Lock Strength" },
		{ key = "release_speed",         cvar = "ik_foot_release_speed",          type = "float", default = 65,    min = 5,   max = 200, decimals = 0, desc = "Foot Release Speed" },
		{ key = "stair_step_min_height", cvar = "ik_foot_stair_step_min_height",  type = "float", default = 6,     min = 2,   max = 24,  decimals = 1, desc = "Minimum Stair Step Height" },
		{ key = "stair_step_max_height", cvar = "ik_foot_stair_step_max_height",  type = "float", default = 28,    min = 8,   max = 50,  decimals = 1, desc = "Maximum Stair Step Height" },
		{ key = "stair_sequence_window", cvar = "ik_foot_stair_sequence_window",  type = "float", default = 0.33,  min = 0.12,max = 1.2, decimals = 2, desc = "Stair Sequence Time Window" },
		{ key = "stair_release_multiplier", cvar = "ik_foot_stair_release_multiplier", type = "float", default = 1.2, min = 0.8, max = 2.5, decimals = 2, desc = "Foot Release Multiplier On Stairs" },
		{ key = "stair_adaptive_maxstep", cvar = "ik_foot_stair_adaptive_maxstep", type = "float", default = 1.0, min = 0.25, max = 2.0, decimals = 2, desc = "Adaptive BodyDrop Step Factor On Stairs" },
		{ key = "moving_surface_max_speed", cvar = "ik_foot_moving_surface_max_speed", type = "float", default = 45, min = 5, max = 180, decimals = 0, desc = "Max Surface Speed For Stable Stair Contact" },
		{ key = "rotation_smoothing",    cvar = "ik_foot_rotation_smoothing",     type = "float", default = 20,    min = 1,   max = 60,  decimals = 0, desc = "Rotation Smoothing" },
		{ key = "max_body_drop",         cvar = "ik_foot_max_body_drop",          type = "float", default = 42,    min = 15,  max = 80,  decimals = 0, desc = "Maximum Body Drop" },
		{ key = "stabilize_idle",        cvar = "ik_foot_stabilize_idle",         type = "bool",  default = true,  min = 0,   max = 1,   decimals = 0, desc = "Stabilize Idle Feet" },
		{ key = "idle_velocity",         cvar = "ik_foot_idle_velocity",          type = "float", default = 5,     min = 1,   max = 20,  decimals = 0, desc = "Idle Velocity Threshold" },
		{ key = "auto_model_detect",     cvar = "ik_foot_auto_model_detect",      type = "bool",  default = true,  min = 0,   max = 1,   decimals = 0, desc = "Auto-detect Model Settings" },
		{ key = "anti_clip",             cvar = "ik_foot_anti_clip",              type = "bool",  default = true,  min = 0,   max = 1,   decimals = 0, desc = "Foot Anti-clip Guard" },
		{ key = "dynamic_sole",          cvar = "ik_foot_dynamic_sole",           type = "bool",  default = true,  min = 0,   max = 1,   decimals = 0, desc = "Dynamic Sole Correction" },
	},
}

IKFoot.Config.byKey = {}
for _, entry in ipairs(IKFoot.Config.entries) do
	IKFoot.Config.byKey[entry.key] = entry
end

function IKFoot.Config.NWName(key)
	return "IK_" .. key
end

function IKFoot.Config.ClampNumber(entry, value)
	return math.Clamp(tonumber(value) or 0, entry.min, entry.max)
end