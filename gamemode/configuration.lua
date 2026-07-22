-- Found Footage gamemode configuration.
-- All gameplay values and forced addon settings belong in this file.

FF_CONFIG = {
    Movement = {
        -- Source uses roughly 16 units per foot.
        -- 78 u/s ~= 1.49 m/s (3.3 mph), a normal walking pace.
        -- 210 u/s ~= 4.00 m/s (9.0 mph), a believable short indoor sprint
        -- while carrying a camera and equipment.
        WalkSpeed = 78,
        SlowWalkSpeed = 58,
        RunSpeed = 210,
        MaxSpeed = 210,
        LadderSpeed = 64,
        CrouchedWalkMultiplier = 0.27,
        DuckTransitionSeconds = 0.75,
        UnDuckTransitionSeconds = 0.48,
        JumpEnabled = true,
        JumpPower = 200,
        SprintEnabled = true,
        Stamina = {
            Enabled = true,
            Maximum = 100,
            DrainPerSecond = 18,
            RegenerationPerSecond = 14,
            RegenerationDelay = 1.25,
            RecoveryThreshold = 20,
        },
        Leaning = {
            Enabled = true,
            Amount = 16,
            Roll = 10,
            Response = 3.5,
            MaximumSpeed = 1.8,
            Acceleration = 6.0,
            AllowCrouch = true,
            CollisionHull = 5,
            FoleyVolume = 0.7,
            FoleySoundLevel = 50,
        },
        FlashlightEnabled = true,
        SuitZoomEnabled = false,
    },

    Restrictions = {
        SandboxTools = true,
        SpawnMenu = true,
        ContextMenu = true,
        Weapons = true,
        Noclip = false,
        PlayerPickup = true,
        DefaultHUD = false,
        Scoreboard = false,
        VoiceHUD = false,
        TextChat = false,
    },

    HUD = {
        Enabled = true,
        ViewportAspectRatio = 4 / 3,

        ResourceBars = {
            MarginX = 22,
            MarginY = 22,
            Width = 132,
            Height = 14,
            RowSpacing = 24,
            DashCount = 20,
            DashGap = 2,
            Padding = 3,
            OutlineThickness = 1,
            LowHealthThreshold = 0.25,
            LowStaminaThreshold = 0.20,
            LowFlashSpeed = 2.4,
            LowFlashMinimumAlpha = 0.18,
        },

        ZoomBar = {
            Enabled = true,
            Width = 112,
            Height = 10,
            TopMargin = 12,
            MarkerSize = 7,
            LabelGap = 7,
            GuideCount = 3,
            OutlineThickness = 1,
        },

        AudioVisualizer = {
            Enabled = true,
            MarginX = 22,
            MarginY = 22,
            Width = 14,
            Height = 112,
            DashCount = 18,
            DashGap = 2,
            Padding = 3,
            OutlineThickness = 1,
            Label = "A",

            AttackSpeed = 48,
            ReleaseSpeed = 10,
            Sensitivity = 1.0,
            OwnSoundGain = 1.05,
            NoOriginGain = 0.65,
            ReferenceSoundLevel = 75,
            ReferenceDistance = 850,
            SoundLevelDistanceDoubling = 12,
            SoundLevelLoudnessRange = 24,

            NoiseFloorMinimum = 0.035,
            NoiseFloorMaximum = 0.070,
            NoiseFloorSpeed = 0.22,

            SourceGains = {
                Footsteps = 0.30,
                Foley = 0.24,
                Impact = 0.62,
                Door = 0.48,
                Paranormal = 0.78,
                Ambient = 0.22,
                Other = 0.38,
            },

            MinimumImpulseDuration = 0.08,
            DefaultImpulseDuration = 0.22,
            MaximumImpulseDuration = 1.5,
            ImpulseDecayExponent = 1.15,
            MaximumSources = 64,
            SurroundGain = 2.2,

            DirectionalIndicators = true,
            DirectionAttackSpeed = 28,
            DirectionReleaseSpeed = 10,
            DirectionMinimumLevel = 0.08,
            DirectionIndicatorSize = 5,
            DirectionIndicatorGap = 8,
        },

        FlashlightBattery = {
            Enabled = true,
            MarginX = 22,
            MarginY = 22,
            Width = 42,
            Height = 14,
            SegmentCount = 5,
            SegmentGap = 2,
            Padding = 3,
            OutlineThickness = 1,
            LowThreshold = 0.20,
            FlashSpeed = 2.4,
            FlashMinimumAlpha = 0.20,
        },

        SignalIndicator = {
            Enabled = true,
            MarginX = 22,
            Top = 46,
            Width = 42,
            Height = 14,
            BarCount = 4,
            BarGap = 2,
            Padding = 3,
            OutlineThickness = 1,
            Label = "SIG",
            HighFlashThreshold = 0.70,
        },

        RecordingFaults = {
            Enabled = true,
            Top = 34,
            FadeTime = 0.22,
            DefaultDuration = 1.2,
            MinimumGap = 0.35,
            LowLightThreshold = 0.055,
            LowLightDelay = 1.5,
            LowLightCooldown = 8,
            BatteryCooldown = 8,
            WaterCooldown = 7,
            ZoomCooldown = 4,
            ImpactCooldown = 3,
        },

        PauseMenu = {
            Enabled = true,
            CanvasWidth = 720,
            CanvasHeight = 576,
            BackgroundAlpha = 96,
            TitleY = 214,
            ButtonY = 286,
            ButtonWidth = 240,
            ButtonHeight = 34,
            ButtonGap = 12,
            OutlineThickness = 1,
        },

        InteractionIndicator = {
            Enabled = true,
            TraceDistance = 96,
            TraceInterval = 0.05,
            OffsetX = 0,
            OffsetY = 0,
            Size = 24,
            Thickness = 2,
            PulseSpeed = 1.35,
        },
    },

    Player = {
        Model = "models/judah/async_researcher/async_researcher_pm.mdl",
        HandsModel = "models/judah/async_researcher/async_pm_arms.mdl",
        Skin = 0,
        BodyGroups = "00000000",
        StandingViewHeight = 64,
        CrouchedViewHeight = 28,
        SpawnIntro = {
            Enabled = true,
            Delay = 0,
            InitialBlackDuration = 1.5,
            BlueDuration = 2,
            DashesDelay = 0.5,
            PlayDelay = 1,
            FinalBlackDuration = 1,
            SpawnBeforeEnd = 0,
            Sound = "foundfootage/vhs_startup.wav",
            BlueColor = {
                Red = 8,
                Green = 42,
                Blue = 178,
            },
        },
        DeathSequence = {
            Enabled = true,
            BackgroundSound = "gui/threateffects/death/slideshow.wav",
            HitSoundPattern = "gui/threateffects/death/hit_%d.wav",
            HitSoundCount = 4,
            AudioMinimumDuration = 4.878662,
            AudioLoadGrace = 1,
            EndCardDuration = 5,
            Title = "END OF RECORDING",
        },
        HealthRegeneration = {
            Enabled = true,
            DelayAfterDamage = 8,
            HealthPerSecond = 1,
            UpdateInterval = 0.25,
        },
    },

    Camera = {
        Enabled = true,
        BaseFOV = 60,
        MinimumFOV = 4,
        ZoomDegreesPerScroll = 4,
        ZoomSmoothing = 8,

        MouseSmoothing = {
            Enabled = true,
            ResponseSeconds = 0.055,
            DegreesPerCount = 0.022,
        },

        DownwardLookLimit = {
            Enabled = true,
            MaximumPitch = 60,
            SoftZone = 18,
            MinimumInputScale = 0.06,
        },

        SmoothStairs = {
            Enabled = true,
            Speed = 1,
            Response = 10,
        },

        Camcorder = {
            Enabled = true,
            Speed = 1,
            Intensity = 1,

            BaseDrift = {
                Pitch = 5.5,
                Yaw = 6,
                Roll = 3.2,
                PositionX = 3.8,
                PositionY = 2.5,
                PositionZ = 2.8,
            },

            Jitter = {
                MinimumIntensity = 0.5,
                MaximumIntensity = 2.5,
                MinimumInterval = 0.04,
                MaximumInterval = 0.22,
            },

            Tremble = {
                PitchYaw = 0.18,
                Roll = 0.12,
            },

            MovementSway = {
                Enabled = true,
                RunningThreshold = 180,
                WalkVertical = 6.5,
                WalkSide = 3.8,
                WalkPitch = 3.8,
                WalkRoll = 4.5,
                WalkYaw = 2.5,
                RunVertical = 10,
                RunSide = 5,
                RunPitch = 4.5,
                RunRoll = 5.5,
                RunYaw = 3.5,
            },

            FOVWobble = {
                Enabled = true,
                BaseAmplitude = 0.7,
                JitterMultiplier = 0.25,
            },

            WindMaximumVolume = 0.6,
        },


        Regrip = {
            Enabled = true,
            MinimumDelay = 5,
            MaximumDelay = 14,
            RunningDelayMultiplier = 0.25,
            LongChance = 0.3,
            Intensity = 1,
            Volume = 0.6,
        },

        DeathCamera = {
            Enabled = true,
            Model = "models/maxofs2d/camera.mdl",
            CleanupOnRespawn = true,
        },
    },

    Effects = {
        VHS = {
            Enabled = true,
            HookClass = "DrawOverlay",
            EqualizeSound = true,
            EqualizeDSPPreset = 14,

            -- Original RealisticVHSEffect2 PAL defaults.
            PreSize = true,
            ViewType = 1,
            FrameSynchronization = 576,
            ShuttleRing = 0,
            Paused = false,

            -- Explicit project overrides retained from the original brief.
            OSD = false,
            OSDUseCurrentTime = false,
            Comets = true,

            Wave = {
                Enabled = true,
                Frequency = 4,
                Detail = 2,
                Amplitude = 0.025,
                Noise = 0,
            },

            Lines = {
                Enabled = false,
                Amplitude = 2,
                Bottom = {
                    Enabled = false,
                    Height = 8,
                    Amplitude = 5,
                    Noise = 0,
                    RandomAmplitude = 4,
                    RandomColor = 0,
                },
                Upper = {
                    Enabled = false,
                    Height = 64,
                    Scale = -0.1,
                    Noise = 0,
                    RandomAmplitude = 0,
                },
            },

            Sharpen = {
                Enabled = true,
                Size = 1,
                Strength = 3,
            },

            CameraColorDistortion = {
                Red = 0,
                Green = 0,
                Blue = 0,
            },

            Interlacing = {
                Enabled = true,
                Blend = 1,
            },

            Channels = {
                ChromaLineDrop = false,
                ChromaLineDropMaximum = 1,
                ChromaBlur = 4,
                ChromaOffsetX = 0,
                ChromaOffsetY = 0,
                ChromaNoise = false,
                ChromaNoiseScaleX = 16,
                ChromaNoiseScaleY = 8,
                ChromaNoiseAlpha = 0.004125,
                GeneralBlur = 1.5,
                LumaNoise = false,
                LumaNoiseScaleX = 32,
                LumaNoiseScaleY = 18,
                LumaNoiseAlpha = 0.025,
            },

            CometSettings = {
                Factor = 50000,
                Size = 0.5,
            },

            NoiseOverlay = {
                Enabled = false,
                GapEnabled = false,
                GapPosition = 0.5,
                GapSize = 0.25,
                GapAnimation = false,
            },

            Wrinkle = {
                Enabled = false,
                Animated = true,
                AnimationSpeed = 0.25,
                Position = 0,
                Size = 0.25,
            },

            VideoFader = {
                Enabled = false,
                Alpha = 0,
                Red = 1,
                Green = 1,
                Blue = 1,
                Animation = 0,
                AnimationSpeed = 1,
            },

            TubeDelay = {
                Enabled = false,
                AddAlpha = 0.02,
                DrawAlpha = 0.2,
            },

            PostColorModify = {
                ["pp_colour_addr"] = 0,
                ["pp_colour_addg"] = 0,
                ["pp_colour_addb"] = 0,
                ["pp_colour_brightness"] = 0,
                ["pp_colour_colour"] = 1,
                ["pp_colour_inv"] = 0,
                ["pp_colour_contrast"] = 1,
                ["pp_colour_mulr"] = 0,
                ["pp_colour_mulg"] = 0,
                ["pp_colour_mulb"] = 0,
            },
        },


        Fisheye = {
            Enabled = true,
            Material = "effects/shaders/merc_fisheye",
            Strength = 0.20,
        },

        Underwater = {
            Enabled = true,
            TriggerWaterLevel = 3,
            Duration = 3,
            Intensity = 1.3,
            BlurRadius = 5,
            BlurPasses = 0.8,
        },

        StepDust = {
            Enabled = true,
            MaximumDistance = 768,
            MinimumSpeed = 35,
            ParticleLifetime = 1.1,
            ParticleCount = 3,
        },

        Collision = {
            Enabled = true,
            MinimumMass = 12,
            MinimumSpeed = 150,
            MinimumSize = 24,
            MinimumDelay = 0.25,
            MaximumEventsPerSecond = 36,
            ScreenShake = 0.72,
            Particles = true,
            ParticleScale = 0.8,
            Volume = 0.8,
        },

        Threat = {
            Enabled = true,
            IntensityMultiplier = 0.72,
            TimeMultiplier = 0.85,
            NPCFactor = 1,
            DamageFactor = 1,
            HealthFactor = 1,
            HeightFactor = 0.75,
            SpeedFactor = 0.65,
            FallEffects = true,
            DeathEffects = true,
        },

    },

    Audio = {
        SurroundAmbience = {
            Enabled = true,
            Directory = "surround_ambience",

            InitialMinimumDelay = 45,
            InitialMaximumDelay = 120,
            MinimumDelay = 90,
            MaximumDelay = 210,

            MinimumDistance = 520,
            MaximumDistance = 1200,
            TooCloseDistance = 260,
            VerticalVariation = 160,
            PositionAttempts = 10,

            MinimumVolume = 0.08,
            MaximumVolume = 0.16,
            FadeMinimumDistance = 280,
            FadeMaximumDistance = 1800,

            UpdateInterval = 0.05,
            RetryDelay = 20,
        },

        Reverb = {
            Enabled = true,
            UpdateInterval = 0.25,
            TraceDistance = 3000,
            DSPVolume = 1.15,
        },

        Muffling = {
            Enabled = true,
            Attenuation = true,
            MinimumThickness = 96,
            FarDistance = 5000,
        },

        Footsteps = {
            Enabled = true,

            -- DSteps: Dynamic Footsteps (Workshop 2782265858).
            SoundLevel = 64,
            MinimumMovementSpeed = 4,
            WalkStepDistance = 42,
            SlowWalkStepDistance = 30,
            CrouchStepDistance = 24,
            SprintStepDistance = 56,
            WalkVolume = 0.36,
            SlowWalkVolume = 0.27,
            SprintVolume = 0.43,
            CrouchVolume = 0.20,
            WanderVolume = 0.18,
            LandingVolume = 0.41,
            MinimumLandingSpeed = 150,
            PitchVariation = 2,

            -- Dynamic Footstep Reverb (Workshop 3438360859).
            Reverb = {
                Enabled = true,
                NPCs = true,
                SoundLevel = 57,
                WalkVolume = 0.09,
                SlowWalkVolume = 0.067,
                SprintVolume = 0.15,
                CrouchVolume = 0.05,
                WanderVolume = 0.058,
                LandingVolume = 0.125,
                NPCVolume = 0.07,
                MinimumEnclosureHits = 23,
                RayLength = 9999,
                CacheSeconds = 0.22,
                PitchMinimum = 90,
                PitchMaximum = 100,
            },
        },

        Crouch = {
            Enabled = true,
            SoundRoot = "crounchandjump/player_crouch_",
            Variants = 3,
            SoundLevel = 66,
            Volume = 0.58,
            MinimumInterval = 0.22,
            JumpVolume = 0.46,
            JumpLandingVolume = 0.38,
            JumpSoundLevel = 64,
        },

        FallingWind = {
            Enabled = true,
            Sound = "fallingwind/woosh0.wav",
            MinimumFallSpeed = 500,
            MaximumFallSpeed = 1450,
            MaximumVolume = 0.74,
            MinimumPitch = 45,
            MaximumPitch = 135,
            CameraShake = 0.18,
        },

        PropAmbience = {
            Enabled = true,
            ScanInterval = 4,
            MinimumDelay = 14,
            MaximumDelay = 38,
            SoundLevel = 66,
            Volume = 0.56,
            MaximumActiveProps = 64,
        },
    },

    Horror = {
        Paranormal = {
            Enabled = true,
            MinimumEventDelay = 18,
            MaximumEventDelay = 70,
            Radius = 1900,
            AmbientSounds = true,
            DoorManipulation = true,
            ButtonManipulation = true,
            FlickeringLights = true,
            BreakingLights = true,
            PropFlinging = true,
            CeilingBlood = true,
            FlashlightInterference = true,

            -- Explicitly prohibited event classes.
            CockroachSwarms = false,
            ShadowFigures = false,
            VisibleGhosts = false,
            GhostOrbs = false,
        },

        Caveman = {
            Enabled = true,
            Class = "backrooms_caveman",
            Model = "models/brmovie/caveman_brmovie.mdl",
            MinimumCount = 3,
            MaximumCount = 8,
            NavAreasPerEntity = 120,
            MinimumSpacing = 1200,
            MinimumSpacingFloor = 600,
            MinimumPlayerSpawnDistance = 640,
            FlatNormalMinimum = 0.995,
            GroundTraceHeight = 256,
            GroundTraceDepth = 1024,
            ClearancePadding = 10,
            CandidateAttempts = 1280,
            FallbackRadiusMinimum = 700,
            FallbackRadiusMaximum = 3200,
            SpawnDelay = 2,
            RetryDelay = 5,
            MaximumRetries = 3,
        },
    },

    Animation = {
        BlackMesaFirstPerson = {
            Enabled = true,
            PlaybackRate = 1,
            UsePlayerHandsOnly = true,
            FoleySounds = true,
            FootstepSounds = false,
            ParticleEffects = false,

            Spawn = {
                Enabled = true,
                Delay = 0.35,
                -- Only the non-particle wake-up set is used.
                Animation = "spawn",
            },

            Damage = {
                Fall = true,
                FallMinimumSpeed = 600,
                FastFallHorizontalSpeed = 250,
                FallFade = {
                    Enabled = true,
                    MinimumDamage = 20,
                    FadeToBlack = 0.12,
                    HoldBlack = 0.08,
                    FadeFromBlack = 0.38,
                },
                Explosion = true,
                ExplosionMinimumDamage = 35,
                FastExplosionDamage = 50,
                Blunt = true,
                BluntMinimumDamage = 5,
                BluntMinimumForce = 200,
                FastBluntForce = 600,
                LargeDamage = false,
                LargeDamageThreshold = 50,
                HeadshotChance = 6,
                ShockChance = 5,
                ShockMinimumDamage = 5,
            },
        },

        IKFeet = {
            Enabled = true,
            Lean = false,
            Debug = 0,
            GroundDistance = 70,
            Smoothing = 17,
            AutoModelDetect = true,
            AntiClip = true,
            DynamicSole = true,
        },

    },

    Flashlight = {
        Enabled = true,
        DisableStockBeam = true,
        FixedColor = { r = 255, g = 255, b = 255 },
        Brightness = 2.35,
        FOV = 52,
        Range = 1600,
        DynamicShadows = true,
        WallDetection = true,
        ToggleSound = true,
        ToggleSoundPath = "foundfootage/flashlight_toggle.wav",
        WalkSway = true,
        Breathing = true,
        SprintBob = true,
        Lightspill = true,
        MultiplayerVisibility = true,
        BatteryEnabled = true,
        BatteryDrainRate = 0.80,
        BatteryRechargeRate = 0.85,
        BatteryLowThreshold = 20,
    },

    Shadows = {
        Enabled = true,
        UseSunDirection = true,
        Color = "187 187 187",
        Distance = 1000,
        DisableAll = false,
        Direction = "0 0 0",
        DoorShadows = false,
    },

    PlayerShadow = {
        Enabled = true,
    },

    BetterLights = {
        Enabled = true,
        PlayerFlashlight = false,
        Menus = false,
        Tools = false,
    },

    CSMLite = {
        Enabled = true,

        -- Exact upstream CSM-Lite defaults. The client module reapplies every
        -- value at load and InitPostEntity so archived settings never carry
        -- into a new map.
        Defaults = {
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
        },
    },

    -- These values are reapplied if a client changes them while this gamemode
    -- is active. Addon menus are omitted, and all public controls are locked.
    LockedClientConVars = {
        mat_postprocess_enable = "1",
        mat_motion_blur_enabled = "1",
        r_drawscreenspaceeffects = "1",
        r_shadowrendertotexture = "1",
        cl_drawownshadow = "1",
        r_shadow_shortenfactor = "1",
        r_shadow_lightpos_lerptime = "0.5",

        realisticvhseffect2_enabled = "1",
        realisticvhseffect2_autodisable = "0",
        realisticvhseffect2_osdautocurtime = "0",
        realisticvhseffect2_dspenabled = "1",

        cflash_enabled = "1",
        cflash_disable_stock = "1",
        cflash_play_sound = "1",
        cflash_wall_detection = "1",
        cflash_dynamic_shadows = "1",
        cflash_walksway = "1",
        cflash_breath = "1",
        cflash_sprint_bob = "1",
        cflash_lightspill_enabled = "1",
        cflash_multiplayer_visibility = "1",
        cflash_texture = "effects/flashlight001",
        cflash_custom_key_enabled = "0",
        cflash_vmanip_compat = "0",
        cflash_vmanip_emptyhands_bridge = "0",
        cflash_vehicle_flashlight = "0",
        cflash_keep_on_death = "0",
        cflash_color_r = "255",
        cflash_color_g = "255",
        cflash_color_b = "255",
        cflash_lightspill_color_r = "255",
        cflash_lightspill_color_g = "255",
        cflash_lightspill_color_b = "255",
        cflash_brightness = "2.35",
        cflash_fov = "52",
        cflash_farz = "1600",
        cflash_battery_enabled = "1",
        cflash_battery_drain_rate = "0.80",
        cflash_battery_recharge_rate = "0.85",
        cflash_battery_low_threshold = "20",
        cflash_battery_dim = "0",
        cflash_battery_flicker = "0",
        cflash_battery_hud = "0",
        cflash_battery_reload_enabled = "0",
        cflash_battery_reload_allow_weapon_reload = "0",
        cflash_battery_spares = "0",


        ik_foot = "1",
        ik_foot_lean = "0",
        ik_foot_debug = "0",
        ik_foot_ground_distance = "70",
        ik_foot_smoothing = "17",
        ik_foot_leg_length = "45",
        ik_foot_trace_start_offset = "30",
        ik_foot_sole_offset = "0",
        ik_foot_uneven_drop_scale = "0.15",
        ik_foot_extra_body_drop = "0.3",
        ik_foot_extra_body_drop_uneven = "1.2",
        ik_foot_high_foot_bend_boost = "1.70",
        ik_foot_rotation_scale = "0.15",
        ik_foot_lock_strength = "0.85",
        ik_foot_release_speed = "65",
        ik_foot_stair_step_min_height = "6",
        ik_foot_stair_step_max_height = "28",
        ik_foot_stair_sequence_window = "0.33",
        ik_foot_stair_release_multiplier = "1.2",
        ik_foot_stair_adaptive_maxstep = "1.0",
        ik_foot_moving_surface_max_speed = "45",
        ik_foot_rotation_smoothing = "20",
        ik_foot_max_body_drop = "42",
        ik_foot_stabilize_idle = "1",
        ik_foot_idle_velocity = "5",
        ik_foot_auto_model_detect = "1",
        ik_foot_anti_clip = "1",
        ik_foot_dynamic_sole = "1",

        threateffects_enabled = "1",
        threateffects_intensity_const = "0",
        threateffects_intensity_mul = "0.72",
        threateffects_time_mul = "0.85",
        threateffects_factor_violentnpc = "1",
        threateffects_factor_violentnpccount = "1",
        threateffects_factor_violentnpcradius = "500",
        threateffects_factor_violentnpclist = "",
        threateffects_factor_damage = "1",
        threateffects_factor_health = "1",
        threateffects_factor_height = "0.75",
        threateffects_factor_speed = "0.65",
        threateffects_volume_glitch = "1",
        threateffects_volume_heartbeat = "1",
        threateffects_intensity_glitch = "1",
        threateffects_intensity_vignette = "1",
        threateffects_intensity_heartbeat = "1",
        threateffects_intensity_glitchsound = "1",
        threateffects_fall_enabled = "1",
        threateffects_fall_alarm = "1",
        threateffects_fall_panting = "1",
        threateffects_fall_pantvolume = "1",
        threateffects_fall_alarmhigh = "0.95",
        threateffects_fall_alarmvolume = "0.5",
        threateffects_death_enabled = "1",
        threateffects_death_volume_scream = "0.75",
        threateffects_death_volume_background = "0.75",

    },

    MapMessages = {
        Enabled = true,

        -- Set this to the deployed Cloudflare Worker URL, with no trailing slash.
        -- Example: https://foundfootage-messages.example.workers.dev
        APIBaseURL = "https://foundfootage-messages.foundfootage-elijah.workers.dev",

        PollInterval = 60,
        SnapshotChunkSize = 20,
        PlacementDistance = 220,
        MaximumLength = 100,

        CassetteModel = "models/angry_builder/insidethebackrooms/cassette.mdl",
        CassetteScale = 1,
        InteractionDistance = 150,

        TypewriterCharactersPerSecond = 28,
        ReadingAutoCloseDistance = 360,
    },

    LockedServerConVars = {
        mp_falldamage = "1",
        sv_icf_multiplayer_visibility = "1",
        sv_icf_multiplayer_distance = "3500",
        sv_icf_multiplayer_max_rate = "12",
    },
}
