local animationConfig = FF_CONFIG.Animation or {}
local config = animationConfig.BlackMesaFirstPerson or {}
local spawnConfig = config.Spawn or {}
local damageConfig = config.Damage or {}
local fallFadeConfig = damageConfig.FallFade or {}

if config.Enabled == false then return end

local ANIMATION_NETWORK_KEY = "FF_BMFP_Animation"
local ANIMATION_CLASS = "ff_bmfp_animation"
local FALL_FADE_NETWORK_KEY = "FF_BMFP_FallFade"

util.AddNetworkString(FALL_FADE_NETWORK_KEY)

local pendingAnimations = setmetatable({}, { __mode = "k" })
local lastSpawnTimes = setmetatable({}, { __mode = "k" })
local lastFallAnimationTimes = setmetatable({}, { __mode = "k" })
local lastFallFadeTimes = setmetatable({}, { __mode = "k" })

local function isFallAnimationName(animationName)
    return animationName == "fall" or animationName == "fall_fast"
end

local function hasActiveAnimation(ply)
    return IsValid(ply:GetNW2Entity(ANIMATION_NETWORK_KEY))
end

local function canAnimate(ply)
    return IsValid(ply)
        and ply:IsPlayer()
        and ply:Alive()
        and not ply:InVehicle()
        and not hasActiveAnimation(ply)
end

function FF_StartBlackMesaFirstPersonAnimation(ply, animationName, yaw, allowPlayerMovement)
    if not canAnimate(ply) then return false end

    local animation = ents.Create(ANIMATION_CLASS)
    if not IsValid(animation) then return false end

    animation:SetPos(ply:GetPos())
    animation:SetOwner(ply)
    animation:Spawn()
    animation:Activate()

    if not animation:StartFoundFootageAnimation(
        ply,
        animationName,
        yaw,
        allowPlayerMovement
    ) then
        animation:Remove()
        return false
    end

    return true
end

local function queueAnimation(ply, animationName, yaw, delay, allowPlayerMovement)
    if not canAnimate(ply) or pendingAnimations[ply] then return false end

    pendingAnimations[ply] = animationName

    if isFallAnimationName(animationName) then
        lastFallAnimationTimes[ply] = CurTime()
    end

    timer.Simple(math.max(tonumber(delay) or 0, 0), function()
        pendingAnimations[ply] = nil

        if canAnimate(ply) then
            FF_StartBlackMesaFirstPersonAnimation(
                ply,
                animationName,
                yaw,
                allowPlayerMovement
            )
        end
    end)

    return true
end

local function hasRecentFallAnimation(ply)
    local pendingAnimation = pendingAnimations[ply]
    if isFallAnimationName(pendingAnimation) then return true end

    local activeAnimation = ply:GetNW2Entity(ANIMATION_NETWORK_KEY)
    if IsValid(activeAnimation) and isFallAnimationName(activeAnimation.AnimationName) then
        return true
    end

    return CurTime() - (lastFallAnimationTimes[ply] or -math.huge) <= 0.75
end

local function sendFallFade(ply)
    if fallFadeConfig.Enabled == false then return end

    local now = CurTime()
    local cooldown = math.max(
        (tonumber(fallFadeConfig.FadeToBlack) or 0.12)
            + (tonumber(fallFadeConfig.HoldBlack) or 0.08)
            + (tonumber(fallFadeConfig.FadeFromBlack) or 0.38),
        0.25
    )

    if now - (lastFallFadeTimes[ply] or -math.huge) < cooldown then return end
    lastFallFadeTimes[ply] = now

    net.Start(FALL_FADE_NETWORK_KEY)
    net.Send(ply)
end

local function removeActiveAnimation(ply)
    pendingAnimations[ply] = nil

    if not IsValid(ply) then return end

    local animation = ply:GetNW2Entity(ANIMATION_NETWORK_KEY)
    if IsValid(animation) then
        animation:Remove()
    end
end

hook.Add("PlayerSpawn", "FF_BMFP_SpawnAnimation", function(ply)
    removeActiveAnimation(ply)
    lastSpawnTimes[ply] = CurTime()
    lastFallAnimationTimes[ply] = nil
    lastFallFadeTimes[ply] = nil

    if ply.FF_IntroPending then return end
    if spawnConfig.Enabled == false then return end

    local allowPlayerMovement = ply.FF_IntroAuthorized
        or ply.FF_SuppressSpawnAnimation

    timer.Simple(math.max(tonumber(spawnConfig.Delay) or 0.35, 0), function()
        if not IsValid(ply) or not ply:Alive() then return end

        queueAnimation(
            ply,
            spawnConfig.Animation or "spawn",
            nil,
            nil,
            allowPlayerMovement
        )
    end)
end)

hook.Add("PlayerDeath", "FF_BMFP_ClearOnDeath", function(ply)
    removeActiveAnimation(ply)
    lastFallAnimationTimes[ply] = nil
    lastFallFadeTimes[ply] = nil
end)

hook.Add("PlayerDisconnected", "FF_BMFP_ClearOnDisconnect", function(ply)
    removeActiveAnimation(ply)
    lastSpawnTimes[ply] = nil
    lastFallAnimationTimes[ply] = nil
    lastFallFadeTimes[ply] = nil
end)

hook.Add("OnPlayerHitGround", "FF_BMFP_FallAnimation", function(ply, inWater, onFloater, speed)
    if damageConfig.Fall == false or inWater or onFloater then return end
    if not canAnimate(ply) then return end

    local lastSpawn = lastSpawnTimes[ply] or 0
    if CurTime() - lastSpawn < 1.5 then return end

    speed = math.abs(tonumber(speed) or 0)
    if speed < math.max(tonumber(damageConfig.FallMinimumSpeed) or 600, 0) then
        return
    end

    local horizontalSpeed = ply:GetVelocity():Length2D()
    local animationName = horizontalSpeed >= math.max(
        tonumber(damageConfig.FastFallHorizontalSpeed) or 250,
        0
    ) and "fall_fast" or "fall"

    queueAnimation(ply, animationName)
end)

local function isDamageType(damageInfo, damageType)
    return bit.band(damageInfo:GetDamageType(), damageType) ~= 0
end

local function animationYawFromDamage(ply, damageInfo)
    local damagePosition = damageInfo:GetDamagePosition()
    if damagePosition == vector_origin then return ply:EyeAngles().y end

    return (ply:GetPos() - damagePosition):Angle().y
end

hook.Add("EntityTakeDamage", "FF_BMFP_DamageAnimations", function(target, damageInfo)
    if not IsValid(target) or not target:IsPlayer() then return end
    if damageInfo:GetDamage() <= 0 then return end
    if target:Health() - damageInfo:GetDamage() <= 0 then return end

    local damage = damageInfo:GetDamage()
    local damageForce = damageInfo:GetDamageForce():Length()
    local yaw = animationYawFromDamage(target, damageInfo)
    local inflictor = damageInfo:GetInflictor()

    if isDamageType(damageInfo, DMG_FALL) then
        if damageConfig.Fall ~= false
            and damage >= math.max(tonumber(fallFadeConfig.MinimumDamage) or 20, 0) then
            if not hasRecentFallAnimation(target) and canAnimate(target) then
                local horizontalSpeed = target:GetVelocity():Length2D()
                local animationName = horizontalSpeed >= math.max(
                    tonumber(damageConfig.FastFallHorizontalSpeed) or 250,
                    0
                ) and "fall_fast" or "fall"

                queueAnimation(target, animationName)
            end

            if hasRecentFallAnimation(target) then
                sendFallFade(target)
            end
        end

        return
    end

    if not canAnimate(target) then return end

    local headshotChance = math.floor(tonumber(damageConfig.HeadshotChance) or 0)
    local headshotDamage = isDamageType(damageInfo, DMG_BULLET)
        or isDamageType(damageInfo, DMG_CLUB)

    if target:IsOnGround()
        and target:LastHitGroup() == HITGROUP_HEAD
        and headshotDamage
        and damage > 3
        and headshotChance > 0
        and math.random(1, headshotChance) == 1 then
        queueAnimation(target, "blackout", yaw)
        return
    end

    local shockChance = math.floor(tonumber(damageConfig.ShockChance) or 0)
    local isShock = isDamageType(damageInfo, DMG_SHOCK)
        or (IsValid(inflictor) and inflictor:GetClass() == "weapon_stunstick")

    if target:IsOnGround()
        and isShock
        and damage > math.max(tonumber(damageConfig.ShockMinimumDamage) or 5, 0)
        and shockChance > 0
        and math.random(1, shockChance) == 1 then
        queueAnimation(target, "knockout", yaw)
        return
    end

    if damageConfig.Explosion ~= false
        and target:IsOnGround()
        and isDamageType(damageInfo, DMG_BLAST)
        and damage > math.max(tonumber(damageConfig.ExplosionMinimumDamage) or 35, 0) then
        local animationName = damage > math.max(
            tonumber(damageConfig.FastExplosionDamage) or 50,
            0
        ) and "fall_fast" or "fall"

        queueAnimation(target, animationName, yaw)
        return
    end

    local isBlunt = isDamageType(damageInfo, DMG_CLUB)
        or isDamageType(damageInfo, DMG_CRUSH)

    if damageConfig.Blunt ~= false
        and target:IsOnGround()
        and isBlunt
        and damage > math.max(tonumber(damageConfig.BluntMinimumDamage) or 5, 0)
        and damageForce > math.max(tonumber(damageConfig.BluntMinimumForce) or 200, 0) then
        local animationName = damageForce > math.max(
            tonumber(damageConfig.FastBluntForce) or 600,
            0
        ) and "fall_fast" or "fall"

        queueAnimation(target, animationName, yaw)
        return
    end

    if damageConfig.LargeDamage == true
        and damage > math.max(tonumber(damageConfig.LargeDamageThreshold) or 50, 0) then
        queueAnimation(target, "fall", yaw)
    end
end)

local function resetExistingPlayers()
    for _, ply in ipairs(player.GetAll()) do
        removeActiveAnimation(ply)
        lastSpawnTimes[ply] = CurTime()
        lastFallAnimationTimes[ply] = nil
        lastFallFadeTimes[ply] = nil
    end
end

hook.Add("OnReloaded", "FF_BMFP_ResetOnReload", resetExistingPlayers)
