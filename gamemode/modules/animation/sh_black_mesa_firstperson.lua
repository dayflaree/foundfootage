-- Conflict-safe integration of Workshop 3521142957.
-- Portal particles, particle spawn variants, concrete footstep audio, weapon
-- mutation, menus, public commands, and SetViewEntity ownership are omitted.

local animationConfig = FF_CONFIG.Animation or {}
local config = animationConfig.BlackMesaFirstPerson or {}
local damageConfig = config.Damage or {}
local fallFadeConfig = damageConfig.FallFade or {}

if config.Enabled == false then return end

local ANIMATION_NETWORK_KEY = "FF_BMFP_Animation"
local PLAYER_NETWORK_KEY = "FF_BMFP_Player"
local CAMERA_ATTACHMENT_KEY = "FF_BMFP_CameraAttachment"
local ANIMATION_CLASS = "ff_bmfp_animation"
local BONEMERGE_CLASS = "ff_bmfp_bonemerge"
local FALL_FADE_NETWORK_KEY = "FF_BMFP_FallFade"

local function retireUpstreamRuntime()
    hook.Remove("RenderScreenspaceEffects", "BloomEffect")
    hook.Remove("PrePlayerDraw", "xen_teleport_effect")
    hook.Remove("PlayerSpawn", "xen_teleport_effect")
    hook.Remove("PlayerCanPickupWeapon", "xen_teleport_effect")
    hook.Remove("EntityTakeDamage", "xen_teleport_effect")

    concommand.Remove("lima_xte_doorknock")
    concommand.Remove("lima_xte_getup")
    concommand.Remove("lima_xte_doanim")
end

retireUpstreamRuntime()
hook.Add("InitPostEntity", "FF_BMFP_RetireUpstreamRuntime", retireUpstreamRuntime)
hook.Add("OnReloaded", "FF_BMFP_RetireUpstreamRuntime", retireUpstreamRuntime)

local function addFoleySound(name, level, pitch, channel, volume, sounds)
    if config.FoleySounds == false then return end

    sound.Add({
        name = name,
        level = level,
        pitch = pitch,
        channel = channel,
        volume = volume,
        sound = sounds,
    })
end

-- Original non-footstep sound scripts used by the retained animation models.
addFoleySound("Interaction.BlackoutExit", 80, 100, CHAN_STATIC, 0.9, {
    "bs_ia_blackoutexit.wav",
})
addFoleySound("BSKnockKnock_Metal", 70, { 95, 105 }, CHAN_STATIC, 0.8, {
    "tele/pd_intro_doorknock.wav",
})
addFoleySound("BSKnockKnock_Metal_Hard", 75, { 95, 105 }, CHAN_STATIC, 0.9, {
    "tele/pd_intro_doorknock_hard.wav",
})
addFoleySound("BSKnockKnock", 75, { 95, 105 }, CHAN_STATIC, 0.5, {
    "tele/door_hit1.wav",
})
addFoleySound("BSKnockKnock_Squish", 75, { 95, 105 }, CHAN_STATIC, 0.9, {
    "tele/flesh_squishy_impact_hard1.wav",
    "tele/flesh_squishy_impact_hard2.wav",
})
addFoleySound("BSKnockKnock_Concrete", 75, { 95, 105 }, CHAN_STATIC, 0.9, {
    "tele/concrete_impact_hard1.wav",
    "tele/concrete_impact_hard2.wav",
})
addFoleySound("BSKnockKnock_Flesh", 75, { 95, 105 }, CHAN_STATIC, 0.9, {
    "tele/flesh_impact_hard1.wav",
    "tele/flesh_impact_hard2.wav",
})
addFoleySound("BSKnockKnock_Glass", 75, { 95, 105 }, CHAN_STATIC, 0.9, {
    "tele/glass_sheet_impact_hard1.wav",
    "tele/glass_sheet_impact_hard2.wav",
    "tele/glass_sheet_impact_hard3.wav",
})
addFoleySound("BS_Crash_Cloth1", 75, { 95, 105 }, CHAN_STATIC, 0.8, {
    "sprintin6.wav",
})
addFoleySound("BS_Crash_Cloth2", 75, { 95, 105 }, CHAN_STATIC, 0.9, {
    "sprintin7.wav",
})
addFoleySound("BS_Crash_Cloth3", 75, { 95, 105 }, CHAN_STATIC, 0.9, {
    "sprintout2.wav",
})
addFoleySound("BS_Crash_Cloth4", 75, { 95, 105 }, CHAN_STATIC, 0.9, {
    "sprintout3.wav",
})
addFoleySound("BS_Crash_BOEx", 75, { 95, 105 }, CHAN_STATIC, 0.8, {
    "bs_ia_blackoutexit.wav",
})
addFoleySound("BS_Cloth", 65, 100, CHAN_STATIC, 1, {
    "bs_ia_xenintro_part3.wav",
})
addFoleySound("BS_Cloth2", 65, 100, CHAN_WEAPON, 1, {
    "sprintin6.wav",
})
addFoleySound("BS_BodyImpact", 75, { 95, 105 }, CHAN_STATIC, 0.9, {
    "tele/body_medium_impact_hard4.wav",
    "tele/body_medium_impact_hard5.wav",
})
addFoleySound("tele.xen_crowbar_pickup_foley1", 75, { 95, 105 }, CHAN_STATIC, 0.7, {
    "tele/xen_crowbar_pickup_foley1.wav",
})
addFoleySound("tele.xen_crowbar_pickup_foley2", 75, { 95, 105 }, CHAN_STATIC, 0.7, {
    "tele/xen_crowbar_pickup_foley2.wav",
})
addFoleySound("tele.xen_crowbar_pickup", 75, { 95, 105 }, CHAN_STATIC, 0.7, {
    "tele/xen_crowbar_pickup.wav",
})

local ANIMATION_SETS = {
    spawn = {
        {
            model = "models/tele/interaction_hands2.mdl",
            sequence = "uc_wakeup",
            cameraAttachment = "ViewmodelEyes",
            up = 1.1,
            sound = "uc_wakeup.wav",
            fadeIn = 2,
        },
        {
            model = "models/tele/interaction_hands2.mdl",
            sequence = "rp_wakeup",
            cameraAttachment = "ViewmodelEyes",
            up = 0.1,
            sound = "rp_wakeup.wav",
            fadeIn = 2,
        },
        {
            model = "models/tele/bs_interaction_hands2.mdl",
            sequence = "blackout_exit1",
            cameraAttachment = "ViewmodelEyes",
            up = 0.1,
            sound = "bs_ia_blackoutexit.wav",
            fadeIn = 1.4,
        },
    },
    fall = {
        {
            model = "models/tele/interaction_hands2.mdl",
            sequence = "uc_wakeup",
            cameraAttachment = "ViewmodelEyes",
            up = 1.1,
            sound = "uc_wakeup.wav",
        },
        {
            model = "models/tele/interaction_hands2.mdl",
            sequence = "rp_wakeup",
            cameraAttachment = "ViewmodelEyes",
            up = 0.1,
            sound = "rp_wakeup.wav",
        },
        {
            model = "models/tele/bs_interaction_hands2.mdl",
            sequence = "blackout_exit1",
            cameraAttachment = "ViewmodelEyes",
            up = 0.1,
            sound = "bs_ia_blackoutexit.wav",
        },
    },
    fall_fast = {
        {
            model = "models/tele/bs_interaction_hands2.mdl",
            sequence = "mantaride_crash",
            cameraAttachment = "ViewmodelEyes",
            up = 13.8,
            playbackRate = 1.5,
        },
    },
    blackout = {
        {
            model = "models/tele/blackout.mdl",
            sequence = "enter1",
            cameraAttachment = "vehicle_driver_eyes",
            up = 1,
            addTime = 2.1666667461395,
            behavior = "blackout",
        },
    },
    knockout = {
        {
            model = "models/tele/blackout.mdl",
            sequence = "knockout",
            cameraAttachment = "knockout_camera_parent",
            up = 1,
            addTime = 2.4,
            behavior = "knockout",
        },
    },
}

local blockedAnimationSounds = {
    ["bs_step"] = true,
    ["interaction.uc_wakeup"] = true,
    ["interaction.rp_wakeup"] = true,
}

local AnimationEntity = {}
AnimationEntity.Type = "anim"
AnimationEntity.Base = "base_anim"
AnimationEntity.PrintName = "Found Footage BM First-Person Animation"
AnimationEntity.Spawnable = false
AnimationEntity.AutomaticFrameAdvance = true

function AnimationEntity:Initialize()
    self:DrawShadow(false)
    self:AddEffects(EF_NOINTERP)

    if SERVER then
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:AddSolidFlags(FSOLID_NOT_STANDABLE)
        self:SetSolid(SOLID_NONE)
    end
end

function AnimationEntity:Draw()
    -- The animation model is a hidden bone driver. The player's hands are
    -- rendered by ff_bmfp_bonemerge.
end

function AnimationEntity:HandleAnimEvent(event, eventTime, cycle, eventType, options)
    if not SERVER or event ~= 12 or config.FoleySounds == false then return end

    options = tostring(options or "")
    local lowered = string.lower(options)

    -- The retained models contain BS_Step events. They are deliberately
    -- suppressed, and the concrete_step*.wav assets are not shipped.
    if config.FootstepSounds == false then
        if blockedAnimationSounds[lowered] or string.find(lowered, "step", 1, true) then
            return
        end
    end

    if options ~= "" then
        self:EmitSound(options)
    end
end

function AnimationEntity:Think()
    if SERVER then
        local ply = self:GetNW2Entity(PLAYER_NETWORK_KEY)
        if not IsValid(ply) or not ply:Alive() then
            self:Remove()
            return
        end

        if self.AllowPlayerMovement then
            local definition = self.Definition or {}
            self:SetPos(ply:GetPos() + Vector(0, 0, definition.up or 0))
            self:SetAngles(Angle(0, ply:EyeAngles().y, 0))
        end

        if self.PlaybackRateValue then
            self:SetPlaybackRate(self.PlaybackRateValue)
        end
    end

    self:NextThink(CurTime())
    return true
end

function AnimationEntity:StartFoundFootageAnimation(
    ply,
    animationName,
    yaw,
    allowPlayerMovement
)
    if not SERVER or not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then
        return false
    end

    local choices = ANIMATION_SETS[animationName]
    if not choices or #choices == 0 then return false end

    local active = ply:GetNW2Entity(ANIMATION_NETWORK_KEY)
    if IsValid(active) and active ~= self then
        active:Remove()
    end

    local definition = table.Random(choices)
    self.AnimationName = animationName
    self.Definition = definition
    self.MyPlayer = ply
    self.AllowPlayerMovement = allowPlayerMovement == true
    self.LockedPlayerMovement = not self.AllowPlayerMovement
    self.PreviousMoveType = ply:GetMoveType()
    self:SetOwner(ply)
    self:SetNW2Entity(PLAYER_NETWORK_KEY, ply)
    self:SetNW2String(CAMERA_ATTACHMENT_KEY, definition.cameraAttachment or "ViewmodelEyes")
    self:SetModel(definition.model)
    self:SetPos(ply:GetPos() + Vector(0, 0, definition.up or 0))
    self:SetAngles(Angle(0, yaw or ply:EyeAngles().y, 0))
    self:SetNoDraw(true)
    self:ResetSequenceInfo()
    self:SetCycle(0)
    self:ResetSequence(definition.sequence)

    self.PlaybackRateValue = math.max(
        (definition.playbackRate or 1) * (tonumber(config.PlaybackRate) or 1),
        0.05
    )
    self:SetPlaybackRate(self.PlaybackRateValue)

    ply:SetNW2Entity(ANIMATION_NETWORK_KEY, self)

    if self.LockedPlayerMovement then
        ply:SetMoveType(MOVETYPE_NONE)
        ply:Freeze(true)
        ply:SetLocalVelocity(vector_origin)
    end

    if config.FoleySounds ~= false and definition.sound then
        self:EmitSound(definition.sound)
    end

    if definition.fadeIn and self.LockedPlayerMovement then
        ply:ScreenFade(
            SCREENFADE.IN,
            Color(0, 0, 0, 255),
            definition.fadeIn / self.PlaybackRateValue,
            0
        )
    end

    local bonemerge = ents.Create(BONEMERGE_CLASS)
    if IsValid(bonemerge) then
        local hands = ply:GetHands()
        local handsModel = FF_CONFIG.Player.HandsModel
        local handsSkin = FF_CONFIG.Player.Skin or 0

        if IsValid(hands) and hands:GetModel() ~= "" then
            handsModel = hands:GetModel()
            handsSkin = hands:GetSkin()
        end

        bonemerge:SetModel(handsModel)
        bonemerge:SetSkin(handsSkin)
        bonemerge:SetOwner(self)
        bonemerge:SetParent(self)
        bonemerge:AddEffects(EF_BONEMERGE)
        bonemerge:AddEffects(EF_NOINTERP)
        bonemerge:SetSolid(SOLID_NONE)
        bonemerge:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        bonemerge:Spawn()

        if IsValid(hands) then
            for bodyGroup = 0, hands:GetNumBodyGroups() - 1 do
                bonemerge:SetBodygroup(bodyGroup, hands:GetBodygroup(bodyGroup))
            end
        end

        self:DeleteOnRemove(bonemerge)
    end

    if definition.behavior == "blackout" then
        ply:ScreenFade(
            SCREENFADE.OUT,
            Color(0, 0, 0, 255),
            3 / self.PlaybackRateValue,
            1
        )

        timer.Simple(3 / self.PlaybackRateValue, function()
            if not IsValid(self) or not IsValid(ply) then return end

            ply:ScreenFade(
                SCREENFADE.IN,
                Color(0, 0, 0, 255),
                3 / self.PlaybackRateValue,
                0
            )
            self:ResetSequenceInfo()
            self:SetCycle(0)
            self:ResetSequence("exit1")
        end)
    elseif definition.behavior == "knockout" then
        ply:ScreenFade(
            SCREENFADE.OUT,
            Color(0, 0, 0, 255),
            1.5 / self.PlaybackRateValue,
            1
        )

        timer.Simple(2 / self.PlaybackRateValue, function()
            if not IsValid(self) or not IsValid(ply) then return end

            self.ChainAnimation = "fall"
            self:Remove()
        end)
    end

    timer.Simple(
        (self:SequenceDuration(self:LookupSequence(definition.sequence))
            + (definition.addTime or 0)) / self.PlaybackRateValue,
        function()
            if IsValid(self) then
                self:Remove()
            end
        end
    )

    return true
end

function AnimationEntity:OnRemove()
    if not SERVER then return end

    local ply = self.MyPlayer
    if not IsValid(ply) then return end

    if ply:GetNW2Entity(ANIMATION_NETWORK_KEY) == self then
        ply:SetNW2Entity(ANIMATION_NETWORK_KEY, NULL)
    end

    local cameraAttachment = self:GetNW2String(CAMERA_ATTACHMENT_KEY, "ViewmodelEyes")
    local attachmentIndex = self:LookupAttachment(cameraAttachment)
    local attachment = attachmentIndex > 0 and self:GetAttachment(attachmentIndex) or nil

    if ply:Alive() and self.LockedPlayerMovement then
        ply:Freeze(false)
        ply:SetMoveType(self.PreviousMoveType or MOVETYPE_WALK)
        ply:SetLocalVelocity(vector_origin)

        if attachment and attachment.Ang then
            ply:SetEyeAngles(Angle(attachment.Ang.p, attachment.Ang.y, 0))
        end
    end

    local chainAnimation = self.ChainAnimation
    if chainAnimation and ply:Alive() then
        timer.Simple(0.01, function()
            if IsValid(ply) and ply:Alive() and FF_StartBlackMesaFirstPersonAnimation then
                FF_StartBlackMesaFirstPersonAnimation(ply, chainAnimation)
            end
        end)
    end
end

scripted_ents.Register(AnimationEntity, ANIMATION_CLASS)

local BonemergeEntity = {}
BonemergeEntity.Type = "anim"
BonemergeEntity.Base = "base_anim"
BonemergeEntity.PrintName = "Found Footage BM Animation Hands"
BonemergeEntity.Spawnable = false

function BonemergeEntity:Initialize()
    self:DrawShadow(false)
    self:AddEffects(EF_BONEMERGE)
    self:AddEffects(EF_NOINTERP)

    if SERVER then
        self:SetSolid(SOLID_NONE)
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    end
end

function BonemergeEntity:Draw()
    local animation = self:GetOwner()
    if not IsValid(animation) then return end

    local ply = animation:GetNW2Entity(PLAYER_NETWORK_KEY)
    if not IsValid(ply) or LocalPlayer() ~= ply then return end

    animation:SetupBones()
    self:SetupBones()
    self:DrawModel()
end

function BonemergeEntity:Think()
    if SERVER and not IsValid(self:GetOwner()) then
        self:Remove()
        return
    end

    self:NextThink(CurTime())
    return true
end

scripted_ents.Register(BonemergeEntity, BONEMERGE_CLASS)

if CLIENT then
    local fallFadeStartedAt

    net.Receive(FALL_FADE_NETWORK_KEY, function()
        if fallFadeConfig.Enabled == false then return end
        fallFadeStartedAt = RealTime()
    end)

    hook.Add("FF_DrawVHSFrameOverlay", "FF_BMFP_FallFadeBehindVHS", function(canvasWidth, canvasHeight)
        if not fallFadeStartedAt or fallFadeConfig.Enabled == false then return end

        local fadeToBlack = math.max(tonumber(fallFadeConfig.FadeToBlack) or 0.12, 0)
        local holdBlack = math.max(tonumber(fallFadeConfig.HoldBlack) or 0.08, 0)
        local fadeFromBlack = math.max(tonumber(fallFadeConfig.FadeFromBlack) or 0.38, 0)
        local elapsed = RealTime() - fallFadeStartedAt
        local alpha

        if fadeToBlack > 0 and elapsed < fadeToBlack then
            alpha = elapsed / fadeToBlack
        elseif elapsed < fadeToBlack + holdBlack then
            alpha = 1
        elseif fadeFromBlack > 0 and elapsed < fadeToBlack + holdBlack + fadeFromBlack then
            alpha = 1 - ((elapsed - fadeToBlack - holdBlack) / fadeFromBlack)
        else
            fallFadeStartedAt = nil
            return
        end

        surface.SetDrawColor(0, 0, 0, math.floor(math.Clamp(alpha, 0, 1) * 255))
        surface.DrawRect(
            0,
            0,
            tonumber(canvasWidth) or 720,
            tonumber(canvasHeight) or 576
        )
    end)

    local fallbackAttachments = {
        "camera_parent",
        "vehicle_driver_eyes",
        "knockout_camera_parent",
        "ViewmodelEyes",
    }

    function FF_GetBlackMesaFirstPersonView(ply, fov, znear, zfar)
        if not IsValid(ply) then return nil end

        local animation = ply:GetNW2Entity(ANIMATION_NETWORK_KEY)
        if not IsValid(animation) then return nil end

        animation:SetupBones()

        local requestedAttachment = animation:GetNW2String(
            CAMERA_ATTACHMENT_KEY,
            "ViewmodelEyes"
        )
        local attachmentNames = { requestedAttachment }

        for _, name in ipairs(fallbackAttachments) do
            if name ~= requestedAttachment then
                attachmentNames[#attachmentNames + 1] = name
            end
        end

        for _, attachmentName in ipairs(attachmentNames) do
            local attachmentIndex = animation:LookupAttachment(attachmentName)
            if attachmentIndex > 0 then
                local attachment = animation:GetAttachment(attachmentIndex)
                if attachment and attachment.Pos and attachment.Ang then
                    return {
                        origin = attachment.Pos,
                        angles = attachment.Ang,
                        fov = fov,
                        znear = math.min(tonumber(znear) or 4, 1),
                        zfar = zfar,
                        drawviewer = false,
                    }
                end
            end
        end

        return nil
    end
end
