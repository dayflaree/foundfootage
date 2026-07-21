local config = FF_CONFIG.Audio.Crouch
if not config.Enabled then return end

local movement = FF_CONFIG.Movement
local states = setmetatable({}, { __mode = "k" })

local function getState(ply)
    local state = states[ply]
    if state then return state end

    state = {
        lastSound = 0,
        nextJumpFoley = 0,
        jumped = false,
    }
    states[ply] = state
    return state
end

local function emitFoley(ply, volume, soundLevel)
    if not IsValid(ply) or not ply:Alive() then return end

    ply:EmitSound(
        config.SoundRoot .. math.random(1, config.Variants) .. ".wav",
        soundLevel or config.SoundLevel,
        math.random(97, 103),
        volume or config.Volume,
        CHAN_BODY
    )
end

local function emitCrouchTransition(ply)
    if not IsValid(ply) or not ply:Alive() or not ply:IsOnGround() then return end

    local state = getState(ply)
    local now = CurTime()
    local minimumInterval = math.max(tonumber(config.MinimumInterval) or 0.22, 0)
    if now - state.lastSound < minimumInterval then return end

    state.lastSound = now
    emitFoley(ply, config.Volume, config.SoundLevel)
end

hook.Add("KeyPress", "FF_CrouchPressedSound", function(ply, key)
    if key ~= IN_DUCK then return end
    emitCrouchTransition(ply)
end)

hook.Add("KeyRelease", "FF_CrouchReleasedSound", function(ply, key)
    if key ~= IN_DUCK then return end
    emitCrouchTransition(ply)
end)

hook.Add("KeyPress", "FF_JumpTakeoffFoley", function(ply, key)
    if key ~= IN_JUMP or not movement.JumpEnabled then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if not ply:IsOnGround() or ply:Crouching() then return end

    local state = getState(ply)
    local now = CurTime()
    if now < state.nextJumpFoley then return end

    state.nextJumpFoley = now + math.max(tonumber(config.MinimumInterval) or 0.22, 0)
    state.jumped = true
    emitFoley(ply, config.JumpVolume or 0.46, config.JumpSoundLevel or 64)
end)

hook.Add("OnPlayerHitGround", "FF_JumpLandingFoley", function(ply)
    local state = states[ply]
    if not state or not state.jumped then return end

    state.jumped = false
    emitFoley(
        ply,
        config.JumpLandingVolume or 0.38,
        config.JumpSoundLevel or 64
    )
end)

hook.Add("PlayerDeath", "FF_ClearCrouchSoundState", function(ply)
    states[ply] = nil
end)

hook.Add("PlayerDisconnected", "FF_ForgetCrouchSoundState", function(ply)
    states[ply] = nil
end)
