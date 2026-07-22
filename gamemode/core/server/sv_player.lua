local movement = FF_CONFIG.Movement
local restrictions = FF_CONFIG.Restrictions
local playerConfig = FF_CONFIG.Player
local staminaConfig = movement.Stamina or {}
local spawnIntroConfig = playerConfig.SpawnIntro or {}
local deathSequenceConfig = playerConfig.DeathSequence or {}

local STAMINA_NETWORK_KEY = "FF_Stamina"
local STAMINA_EXHAUSTED_NETWORK_KEY = "FF_StaminaExhausted"
local VHS_STARTUP_NETWORK_MESSAGE = "FF_VHSStartup"
local VHS_STARTUP_READY_NETWORK_MESSAGE = "FF_VHSStartupReady"
local VHS_STARTUP_COMPLETE_NETWORK_MESSAGE = "FF_VHSStartupComplete"
local VHS_STARTUP_FINISH_NETWORK_MESSAGE = "FF_VHSStartupFinish"
local DEATH_SEQUENCE_START_NETWORK_MESSAGE = "FF_DeathSequenceStart"
local DEATH_AUDIO_COMPLETE_NETWORK_MESSAGE = "FF_DeathAudioComplete"
local DEATH_END_CARD_NETWORK_MESSAGE = "FF_DeathEndCard"
local DEATH_SEQUENCE_FINISH_NETWORK_MESSAGE = "FF_DeathSequenceFinish"
local staminaEnabled = movement.SprintEnabled and staminaConfig.Enabled ~= false
local staminaStates = setmetatable({}, { __mode = "k" })

util.AddNetworkString(VHS_STARTUP_NETWORK_MESSAGE)
util.AddNetworkString(VHS_STARTUP_READY_NETWORK_MESSAGE)
util.AddNetworkString(VHS_STARTUP_COMPLETE_NETWORK_MESSAGE)
util.AddNetworkString(VHS_STARTUP_FINISH_NETWORK_MESSAGE)
util.AddNetworkString(DEATH_SEQUENCE_START_NETWORK_MESSAGE)
util.AddNetworkString(DEATH_AUDIO_COMPLETE_NETWORK_MESSAGE)
util.AddNetworkString(DEATH_END_CARD_NETWORK_MESSAGE)
util.AddNetworkString(DEATH_SEQUENCE_FINISH_NETWORK_MESSAGE)

local function maximumStamina()
    return math.max(tonumber(staminaConfig.Maximum) or 100, 1)
end

local function publishStamina(ply, state, force)
    if not IsValid(ply) then return end

    local networkValue = math.floor(state.value + 0.5)
    if force or state.networkValue ~= networkValue then
        state.networkValue = networkValue
        ply:SetNW2Float(STAMINA_NETWORK_KEY, networkValue)
    end

    if force or state.networkExhausted ~= state.exhausted then
        state.networkExhausted = state.exhausted
        ply:SetNW2Bool(STAMINA_EXHAUSTED_NETWORK_KEY, state.exhausted)
    end
end

local function resetStamina(ply)
    if not IsValid(ply) then return end

    local state = {
        value = maximumStamina(),
        exhausted = false,
        regenerateAt = 0,
        lastUpdate = CurTime(),
    }

    staminaStates[ply] = state
    publishStamina(ply, state, true)
end

local function getStaminaState(ply)
    local state = staminaStates[ply]
    if state then return state end

    resetStamina(ply)
    return staminaStates[ply]
end

local blockedButtons = 0
if not movement.JumpEnabled then
    blockedButtons = bit.bor(blockedButtons, IN_JUMP)
end
if not movement.SprintEnabled then
    blockedButtons = bit.bor(blockedButtons, IN_SPEED)
end
if not movement.SuitZoomEnabled then
    blockedButtons = bit.bor(blockedButtons, IN_ZOOM)
end

local function applyPlayerModel(ply)
    if not IsValid(ply) then return end

    if util.IsValidModel(playerConfig.Model) then
        ply:SetModel(playerConfig.Model)
        ply:SetSkin(playerConfig.Skin or 0)
    end

    local hands = ply:GetHands()
    if IsValid(hands) and util.IsValidModel(playerConfig.HandsModel) then
        hands:SetModel(playerConfig.HandsModel)
        hands:SetSkin(playerConfig.Skin or 0)
        hands:SetBodyGroups(playerConfig.BodyGroups or "00000000")
    end
end

local function applyStableViewOffsets(ply)
    if not IsValid(ply) then return end

    local standing = Vector(0, 0, playerConfig.StandingViewHeight or 64)
    local crouched = Vector(0, 0, playerConfig.CrouchedViewHeight or 28)

    ply:SetViewOffset(standing)
    ply:SetViewOffsetDucked(crouched)

    if ply.SetCurrentViewOffset then
        ply:SetCurrentViewOffset(ply:Crouching() and crouched or standing)
    end
end

local function applyMovementSettings(ply)
    if not IsValid(ply) then return end

    ply:SetWalkSpeed(movement.WalkSpeed)
    ply:SetSlowWalkSpeed(movement.SlowWalkSpeed)
    ply:SetRunSpeed(movement.RunSpeed)
    ply:SetMaxSpeed(movement.MaxSpeed)
    ply:SetCrouchedWalkSpeed(movement.CrouchedWalkMultiplier)
    ply:SetDuckSpeed(movement.DuckTransitionSeconds)
    ply:SetUnDuckSpeed(movement.UnDuckTransitionSeconds)
    ply:SetJumpPower(movement.JumpPower or 200)

    if ply.SetLadderClimbSpeed then
        ply:SetLadderClimbSpeed(movement.LadderSpeed)
    end
end

local function applyPlayerSettings(ply)
    if not IsValid(ply) then return end

    applyMovementSettings(ply)
    ply:AllowFlashlight(movement.FlashlightEnabled)
    if restrictions.Weapons == false then
        ply:StripWeapons()
        ply:StripAmmo()
    end
    applyPlayerModel(ply)
    applyStableViewOffsets(ply)
end

local function callBaseGamemodeMethod(gamemode, methodName, ...)
    local baseClass = gamemode.BaseClass
    local callback = baseClass and baseClass[methodName]

    if not isfunction(callback) then
        ErrorNoHalt(
            "[Found Footage] Missing inherited gamemode method: "
                .. tostring(methodName)
                .. "\n"
        )
        return
    end

    return callback(gamemode, ...)
end

local function spawnIntroDuration()
    local totalDuration = math.max(tonumber(spawnIntroConfig.InitialBlackDuration) or 1.5, 0)
        + math.max(tonumber(spawnIntroConfig.BlueDuration) or 1.5, 0)
        + math.max(tonumber(spawnIntroConfig.FinalBlackDuration) or 1, 0)
    local spawnBeforeEnd = math.max(tonumber(spawnIntroConfig.SpawnBeforeEnd) or 0, 0)

    return math.max(totalDuration - spawnBeforeEnd, 0)
end

local function beginSpawnIntro(ply)
    if not IsValid(ply)
        or not ply.FF_IntroPending
        or ply.FF_IntroStarted
        or not ply.FF_VHSClientReady then
        return
    end

    ply.FF_IntroStarted = true
    ply.FF_IntroToken = ((tonumber(ply.FF_IntroToken) or 0) % 65535) + 1

    local token = ply.FF_IntroToken
    local delay = math.max(tonumber(spawnIntroConfig.Delay) or 0, 0)
    timer.Simple(delay, function()
        if not IsValid(ply)
            or not ply.FF_IntroPending
            or not ply.FF_IntroStarted
            or ply.FF_IntroToken ~= token then
            return
        end

        ply.FF_IntroEarliestCompletion = CurTime() + spawnIntroDuration()

        net.Start(VHS_STARTUP_NETWORK_MESSAGE)
        net.WriteUInt(token, 16)
        net.Send(ply)
    end)
end

local function queueSpawnIntro(ply)
    if spawnIntroConfig.Enabled == false or not IsValid(ply) or ply:IsBot() then
        return false
    end

    if not ply.FF_IntroPending then
        ply.FF_IntroPending = true
        ply.FF_IntroStarted = false
        ply.FF_IntroEarliestCompletion = nil
    end

    beginSpawnIntro(ply)
    return true
end

local function restorePlayerControl(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    ply:UnSpectate()
    ply:Freeze(false)
    ply:SetMoveType(MOVETYPE_WALK)
    ply:SetLocalVelocity(vector_origin)
end

local function deathAudioMinimumDuration()
    return math.max(tonumber(deathSequenceConfig.AudioMinimumDuration) or 4.878662, 0)
end

local function deathEndCardDuration()
    return math.max(tonumber(deathSequenceConfig.EndCardDuration) or 5, 0)
end


local function deathSequenceMatches(ply, token)
    return IsValid(ply)
        and ply.FF_DeathSequencePending
        and ply.FF_DeathSequenceToken == token
end

local function sendDeathSequenceFinish(ply, token)
    if not IsValid(ply) then return end

    net.Start(DEATH_SEQUENCE_FINISH_NETWORK_MESSAGE)
    net.WriteUInt(token, 16)
    net.Send(ply)
end

local function clearDeathSequenceState(ply)
    if not IsValid(ply) then return end

    ply.FF_DeathSequencePending = false
    ply.FF_DeathEndCardStarted = false
    ply.FF_DeathAudioEarliestCompletion = nil
end

local beginDeathEndCard
beginDeathEndCard = function(ply, token)
    if not deathSequenceMatches(ply, token) or ply.FF_DeathEndCardStarted then return end

    local earliestCompletion = tonumber(ply.FF_DeathAudioEarliestCompletion)
    if not earliestCompletion then return end

    local remainingAudio = earliestCompletion - CurTime()
    if remainingAudio > 0 then
        timer.Simple(remainingAudio, function()
            beginDeathEndCard(ply, token)
        end)
        return
    end

    ply.FF_DeathEndCardStarted = true

    local endCardDuration = deathEndCardDuration()
    net.Start(DEATH_END_CARD_NETWORK_MESSAGE)
    net.WriteUInt(token, 16)
    net.WriteFloat(endCardDuration)
    net.Send(ply)

    timer.Simple(endCardDuration, function()
        if not deathSequenceMatches(ply, token) then return end

        clearDeathSequenceState(ply)

        ply:StripWeapons()
        ply:Spectate(OBS_MODE_FIXED)

        if not queueSpawnIntro(ply) then
            sendDeathSequenceFinish(ply, token)
            ply.FF_IntroAuthorized = true
            ply:UnSpectate()
            ply:Spawn()
            restorePlayerControl(ply)
        end
    end)
end

local function startDeathSequence(ply)
    if deathSequenceConfig.Enabled == false or not IsValid(ply) or ply:IsBot() then
        return false
    end

    ply.FF_DeathSequenceToken = ((tonumber(ply.FF_DeathSequenceToken) or 0) % 65535) + 1
    ply.FF_DeathSequencePending = true
    ply.FF_DeathEndCardStarted = false
    ply.FF_DeathAudioEarliestCompletion = CurTime() + deathAudioMinimumDuration()

    local token = ply.FF_DeathSequenceToken

    net.Start(DEATH_SEQUENCE_START_NETWORK_MESSAGE)
    net.WriteUInt(token, 16)
    net.Send(ply)

    local fallbackDelay = deathAudioMinimumDuration()
        + math.max(tonumber(deathSequenceConfig.AudioLoadGrace) or 1, 0)
    timer.Simple(fallbackDelay, function()
        beginDeathEndCard(ply, token)
    end)

    return true
end

local function completeSpawnIntro(ply, token)
    if not IsValid(ply)
        or not ply.FF_IntroPending
        or not ply.FF_IntroStarted
        or ply.FF_IntroToken ~= token then
        return
    end

    local earliestCompletion = tonumber(ply.FF_IntroEarliestCompletion)
    if not earliestCompletion then return end

    local remaining = earliestCompletion - CurTime()
    if remaining > 0 then
        timer.Simple(remaining, function()
            completeSpawnIntro(ply, token)
        end)
        return
    end

    ply.FF_IntroPending = false
    ply.FF_IntroStarted = false
    ply.FF_IntroEarliestCompletion = nil
    ply.FF_IntroAuthorized = true
    ply.FF_SuppressSpawnAnimation = true

    if ply:Team() == TEAM_SPECTATOR then
        ply:SetTeam(TEAM_UNASSIGNED)
    end

    ply:UnSpectate()
    ply:Spawn()
    restorePlayerControl(ply)

    timer.Simple(0, function()
        if not IsValid(ply) then return end

        ply.FF_SuppressSpawnAnimation = nil
        restorePlayerControl(ply)

        net.Start(VHS_STARTUP_FINISH_NETWORK_MESSAGE)
        net.WriteUInt(token, 16)
        net.Send(ply)
    end)
end

hook.Add("PlayerInitialSpawn", "FF_QueueInitialVHSStartup", function(ply, transition)
    ply.FF_VHSClientReady = false

    if transition then
        ply.FF_IntroPending = false
        ply.FF_IntroStarted = false
        ply.FF_IntroEarliestCompletion = nil
        return
    end

    if spawnIntroConfig.Enabled ~= false and not ply:IsBot() then
        ply.FF_IntroPending = true
        ply.FF_IntroStarted = false
        ply.FF_IntroEarliestCompletion = nil
    end
end)

net.Receive(VHS_STARTUP_READY_NETWORK_MESSAGE, function(_, ply)
    if not IsValid(ply) then return end

    ply.FF_VHSClientReady = true
    beginSpawnIntro(ply)
end)

net.Receive(VHS_STARTUP_COMPLETE_NETWORK_MESSAGE, function(_, ply)
    completeSpawnIntro(ply, net.ReadUInt(16))
end)

net.Receive(DEATH_AUDIO_COMPLETE_NETWORK_MESSAGE, function(_, ply)
    beginDeathEndCard(ply, net.ReadUInt(16))
end)

hook.Add("PlayerDeath", "FF_StartDeathSequence", function(ply)
    startDeathSequence(ply)
end)

function GM:PlayerSpawn(ply, transition)
    if transition then
        ply.FF_IntroPending = false
        ply.FF_IntroStarted = false
        ply.FF_IntroEarliestCompletion = nil
    end

    if not transition and not ply.FF_IntroAuthorized and queueSpawnIntro(ply) then
        ply:StripWeapons()
        ply:Spectate(OBS_MODE_FIXED)
        return
    end

    ply.FF_IntroAuthorized = nil
    return callBaseGamemodeMethod(self, "PlayerSpawn", ply, transition)
end

function GM:PlayerDeathThink(ply)
    if ply.FF_DeathSequencePending or ply.FF_IntroPending then return end

    local canRespawn = not ply.NextSpawnTime or ply.NextSpawnTime <= CurTime()
    local requestedRespawn = ply:IsBot()
        or ply:KeyPressed(IN_ATTACK)
        or ply:KeyPressed(IN_ATTACK2)
        or ply:KeyPressed(IN_JUMP)

    if canRespawn and requestedRespawn and queueSpawnIntro(ply) then
        ply:Spectate(OBS_MODE_FIXED)
        return
    end

    return callBaseGamemodeMethod(self, "PlayerDeathThink", ply)
end

hook.Add("PlayerSpawn", "FF_ApplyPlayerSettings", function(ply)
    if ply.FF_IntroPending then return end

    resetStamina(ply)

    timer.Simple(0, function()
        applyPlayerSettings(ply)
    end)
end)

local function resetExistingPlayerViews()
    for _, ply in ipairs(player.GetAll()) do
        applyStableViewOffsets(ply)
    end
end

local function resetExistingPlayerMovement()
    for _, ply in ipairs(player.GetAll()) do
        applyMovementSettings(ply)
    end
end

local function resetExistingPlayerStamina()
    for _, ply in ipairs(player.GetAll()) do
        resetStamina(ply)
    end
end

timer.Simple(0, resetExistingPlayerViews)
timer.Simple(0, resetExistingPlayerMovement)
timer.Simple(0, resetExistingPlayerStamina)
hook.Add("OnReloaded", "FF_ResetStableViewOffsets", resetExistingPlayerViews)
hook.Add("OnReloaded", "FF_ResetMovementSettings", resetExistingPlayerMovement)
hook.Add("OnReloaded", "FF_ResetStamina", resetExistingPlayerStamina)

hook.Add("PlayerLoadout", "FF_EmptyLoadout", function(ply)
    applyPlayerSettings(ply)
    return true
end)

hook.Add("PlayerSetModel", "FF_ForceFoundFootageModel", function(ply)
    timer.Simple(0, function()
        applyPlayerModel(ply)
    end)
end)

hook.Add("StartCommand", "FF_BlockMovementInputs", function(ply, cmd)
    local buttons = cmd:GetButtons()

    if blockedButtons ~= 0 then
        buttons = bit.band(buttons, bit.bnot(blockedButtons))
    end


    if staminaEnabled then
        local staminaState = getStaminaState(ply)
        if staminaState and staminaState.exhausted then
            buttons = bit.band(buttons, bit.bnot(IN_SPEED))
        end
    end

    cmd:SetButtons(buttons)

    if not movement.FlashlightEnabled and cmd:GetImpulse() == 100 then
        cmd:SetImpulse(0)
    end
end)

hook.Add("PlayerDeath", "FF_ClearStaminaState", function(ply)
    staminaStates[ply] = nil

    if IsValid(ply) then
        ply:SetNW2Float(STAMINA_NETWORK_KEY, 0)
        ply:SetNW2Bool(STAMINA_EXHAUSTED_NETWORK_KEY, false)
    end
end)

hook.Add("PlayerDisconnected", "FF_ForgetStaminaState", function(ply)
    staminaStates[ply] = nil
end)

hook.Add("SetupMove", "FF_EnforceMovementSpeed", function(ply, mv, cmd)
    local wantsToSprint = movement.SprintEnabled
        and bit.band(cmd:GetButtons(), IN_SPEED) ~= 0
        and not ply:Crouching()
        and ply:WaterLevel() < 2

    local sprinting = wantsToSprint

    if staminaEnabled then
        local state = getStaminaState(ply)
        if state then
            local now = CurTime()
            local deltaTime = math.Clamp(now - state.lastUpdate, 0, 0.1)
            state.lastUpdate = now

            sprinting = wantsToSprint and not state.exhausted and state.value > 0

            local moving = mv:GetVelocity():Length2DSqr() > 625
            local draining = sprinting and moving and ply:IsOnGround()

            if draining then
                state.value = math.max(
                    state.value - (tonumber(staminaConfig.DrainPerSecond) or 18) * deltaTime,
                    0
                )
                state.regenerateAt = now + math.max(tonumber(staminaConfig.RegenerationDelay) or 1.25, 0)

                if state.value <= 0 then
                    state.exhausted = true
                    sprinting = false
                end
            elseif now >= state.regenerateAt and state.value < maximumStamina() then
                state.value = math.min(
                    state.value + (tonumber(staminaConfig.RegenerationPerSecond) or 14) * deltaTime,
                    maximumStamina()
                )
            end

            if state.exhausted then
                local recoveryThreshold = math.Clamp(
                    tonumber(staminaConfig.RecoveryThreshold) or 20,
                    0,
                    maximumStamina()
                )

                if state.value >= recoveryThreshold then
                    state.exhausted = false
                end
            end

            publishStamina(ply, state, false)
        end
    end

    local maximum = sprinting and movement.RunSpeed or movement.WalkSpeed
    mv:SetMaxSpeed(maximum)
    mv:SetMaxClientSpeed(maximum)
end)

if not movement.FlashlightEnabled then
    hook.Add("PlayerSwitchFlashlight", "FF_DisableFlashlight", function()
        return false
    end)
end

hook.Remove("PlayerCanPickupWeapon", "FF_DisableWeaponPickup")
hook.Remove("WeaponEquip", "FF_RemoveEquippedWeapon")

if restrictions.Weapons == false then
    hook.Add("PlayerCanPickupWeapon", "FF_DisableWeaponPickup", function()
        return false
    end)

    hook.Add("WeaponEquip", "FF_RemoveEquippedWeapon", function(weapon)
        timer.Simple(0, function()
            if IsValid(weapon) then
                weapon:Remove()
            end
        end)
    end)
end

local function deny()
    return false
end

hook.Add("CanPlayerSuicide", "FF_DisableKillCommand", deny)

if restrictions.TextChat == false then
    hook.Add("PlayerSay", "FF_DisableTextChat", function()
        return ""
    end)
end

if not restrictions.Noclip then
    hook.Add("PlayerNoClip", "FF_DisableNoclip", deny)
end

hook.Remove("AllowPlayerPickup", "FF_DisablePlayerPickup")
hook.Remove("PhysgunPickup", "FF_DisablePhysgun")
hook.Remove("GravGunPickupAllowed", "FF_DisableGravGunPickup")
hook.Remove("GravGunPunt", "FF_DisableGravGunPunt")

if not restrictions.PlayerPickup then
    hook.Add("AllowPlayerPickup", "FF_DisablePlayerPickup", deny)
    hook.Add("PhysgunPickup", "FF_DisablePhysgun", deny)
    hook.Add("GravGunPickupAllowed", "FF_DisableGravGunPickup", deny)
    hook.Add("GravGunPunt", "FF_DisableGravGunPunt", deny)
end

hook.Remove("CanTool", "FF_DisableToolgun")
hook.Remove("PlayerGiveSWEP", "FF_DisableGiveSWEP")
hook.Remove("PlayerSpawnSWEP", "FF_DisableSpawnSWEP")
hook.Remove("PlayerSpawnProp", "FF_DisableSpawnProp")
hook.Remove("PlayerSpawnRagdoll", "FF_DisableSpawnRagdoll")
hook.Remove("PlayerSpawnEffect", "FF_DisableSpawnEffect")
hook.Remove("PlayerSpawnNPC", "FF_DisableSpawnNPC")
hook.Remove("PlayerSpawnSENT", "FF_DisableSpawnSENT")
hook.Remove("PlayerSpawnVehicle", "FF_DisableSpawnVehicle")

if not restrictions.SandboxTools then
    hook.Add("CanTool", "FF_DisableToolgun", deny)
    hook.Add("PlayerGiveSWEP", "FF_DisableGiveSWEP", deny)
    hook.Add("PlayerSpawnSWEP", "FF_DisableSpawnSWEP", deny)
    hook.Add("PlayerSpawnProp", "FF_DisableSpawnProp", deny)
    hook.Add("PlayerSpawnRagdoll", "FF_DisableSpawnRagdoll", deny)
    hook.Add("PlayerSpawnEffect", "FF_DisableSpawnEffect", deny)
    hook.Add("PlayerSpawnNPC", "FF_DisableSpawnNPC", deny)
    hook.Add("PlayerSpawnSENT", "FF_DisableSpawnSENT", deny)
    hook.Add("PlayerSpawnVehicle", "FF_DisableSpawnVehicle", deny)
end

hook.Add("ShowHelp", "FF_DisableHelpMenu", deny)
hook.Add("ShowTeam", "FF_DisableTeamMenu", deny)
hook.Add("ShowSpare1", "FF_DisableSpareMenu1", deny)
hook.Add("ShowSpare2", "FF_DisableSpareMenu2", deny)
