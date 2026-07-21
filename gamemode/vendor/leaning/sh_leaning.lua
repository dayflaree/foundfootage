-- Curated integration of Workshop 3138563659 (Leaning) and
-- Workshop 3727438572 (Cloth Foley SFX For Leaning).
--
-- The upstream addon owns Player view offsets directly. Found Footage keeps one
-- authoritative CalcView, so this runtime exposes a collision-safe camera offset
-- instead and retains the hold controls, smoothing, networking, and cloth foley.

local config = ((FF_CONFIG or {}).Movement or {}).Leaning or {}
if config.Enabled == false then return end

local NET_INPUT = "FF_LeanInput"
local NW_FRACTION = "FF_LeanFraction"

local function smoothFraction(current, target, velocity, deltaTime)
    local response = math.max(tonumber(config.Response) or 3.5, 0.01)
    local maximumSpeed = math.max(tonumber(config.MaximumSpeed) or 1.8, 0.01)
    local acceleration = math.max(tonumber(config.Acceleration) or 6.0, 0.01)
    local dt = math.Clamp(tonumber(deltaTime) or 0, 0, 0.05)
    local desiredVelocity = math.Clamp((target - current) * response, -maximumSpeed, maximumSpeed)

    velocity = math.Approach(velocity or 0, desiredVelocity, acceleration * dt)

    local updated = current + velocity * dt
    if (target - current) * (target - updated) <= 0 then
        return target, 0
    end

    if math.abs(target - updated) < 0.002 and math.abs(velocity) < 0.02 then
        return target, 0
    end

    return math.Clamp(updated, -1, 1), velocity
end

local function canLean(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if not ply:IsOnGround() then return false end
    if config.AllowCrouch == false and ply:Crouching() then return false end

    local sprinting = ply:KeyDown(IN_SPEED) and ply:GetVelocity():Length2D() > 10
    if sprinting then return false end

    return true
end

if SERVER then
    util.AddNetworkString(NET_INPUT)

    local leanTargets = setmetatable({}, { __mode = "k" })
    local leanVelocities = setmetatable({}, { __mode = "k" })

    net.Receive(NET_INPUT, function(_, ply)
        if not IsValid(ply) then return end
        leanTargets[ply] = math.Clamp(net.ReadInt(2), -1, 1)
    end)

    hook.Add("SetupMove", "FF_LeaningNetworkState", function(ply)
        local target = leanTargets[ply] or 0
        if not canLean(ply) then
            target = 0
        end

        local current = ply:GetNW2Float(NW_FRACTION, 0)
        local updated, velocity = smoothFraction(
            current,
            target,
            leanVelocities[ply] or 0,
            engine.TickInterval()
        )
        leanVelocities[ply] = velocity

        if math.abs(updated) < 0.0001 and math.abs(velocity) < 0.0001 then
            updated = 0
        end

        if math.abs(updated - current) > 0.00001 then
            ply:SetNW2Float(NW_FRACTION, updated)
        end
    end)

    local function resetLean(ply)
        if not IsValid(ply) then return end
        leanTargets[ply] = 0
        leanVelocities[ply] = 0
        ply:SetNW2Float(NW_FRACTION, 0)
    end

    hook.Add("PlayerSpawn", "FF_LeaningResetSpawn", resetLean)
    hook.Add("PlayerDeath", "FF_LeaningResetDeath", resetLean)
    hook.Add("PlayerDisconnected", "FF_LeaningResetDisconnect", function(ply)
        leanTargets[ply] = nil
        leanVelocities[ply] = nil
    end)

    return
end

local leftHeld = false
local rightHeld = false
local localFraction = 0
local localVelocity = 0
local previousDesired = 0
local foleyActive = false
local lastAbsFraction = 0

local function desiredFraction()
    if leftHeld == rightHeld then return 0 end
    return leftHeld and -1 or 1
end

local function sendInput()
    net.Start(NET_INPUT)
    net.WriteInt(desiredFraction(), 2)
    net.SendToServer()
end

local function setHeld(side, held)
    held = held == true

    if side == "left" then
        if leftHeld == held then return end
        leftHeld = held
    else
        if rightHeld == held then return end
        rightHeld = held
    end

    sendInput()
end

concommand.Add("+ff_lean_left", function()
    setHeld("left", true)
end)

concommand.Add("-ff_lean_left", function()
    setHeld("left", false)
end)

concommand.Add("+ff_lean_right", function()
    setHeld("right", true)
end)

concommand.Add("-ff_lean_right", function()
    setHeld("right", false)
end)

local function keyboardCaptured()
    if gui.IsGameUIVisible and gui.IsGameUIVisible() then return true end
    if gui.IsConsoleVisible and gui.IsConsoleVisible() then return true end
    if vgui.GetKeyboardFocus and IsValid(vgui.GetKeyboardFocus()) then return true end

    return false
end

local function updatePhysicalLeanKeys()
    local captured = keyboardCaptured()

    -- Physical lean remains available even when E is also the normal +use
    -- binding. PlayerBindPress lets +use through, so doors/buttons still work
    -- while the same held key drives right lean.
    setHeld("left", not captured and input.IsKeyDown(KEY_Q))
    setHeld("right", not captured and input.IsKeyDown(KEY_E))
end

hook.Add("PlayerBindPress", "FF_LeaningConsumePhysicalKeys", function(_, bind, _, keyCode)
    bind = string.lower(string.Trim(tostring(bind or "")))
    if string.StartWith(bind, "+use") then return end

    if keyCode == KEY_Q or keyCode == KEY_E then
        return true
    end
end)

local function emitFoley(kind)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local maximum = kind == "enter" and 13 or 15
    local path = "foley_lean/" .. kind .. "/" .. kind .. "_" .. math.random(1, maximum) .. ".wav"
    ply:EmitSound(
        path,
        math.max(tonumber(config.FoleySoundLevel) or 50, 0),
        math.random(95, 105),
        math.Clamp(tonumber(config.FoleyVolume) or 0.7, 0, 1),
        CHAN_BODY
    )
end

hook.Add("Think", "FF_LeaningPredictionAndFoley", function()
    updatePhysicalLeanKeys()

    local ply = LocalPlayer()
    local desired = desiredFraction()

    if not canLean(ply) then
        desired = 0
    end

    localFraction, localVelocity = smoothFraction(
        localFraction,
        desired,
        localVelocity,
        math.min(FrameTime(), 0.05)
    )
    if math.abs(localFraction) < 0.0001 and math.abs(localVelocity) < 0.0001 then
        localFraction = 0
        localVelocity = 0
    end

    local absFraction = math.abs(localFraction)
    if not foleyActive and absFraction > 0.05 then
        foleyActive = true
        emitFoley("enter")
    elseif foleyActive and desired == 0 and (previousDesired ~= 0 or absFraction < lastAbsFraction) then
        foleyActive = false
        emitFoley("exit")
    end

    if not IsValid(ply) or not ply:Alive() then
        leftHeld = false
        rightHeld = false
        localFraction = 0
        localVelocity = 0
        desired = 0
        foleyActive = false
    end

    previousDesired = desired
    lastAbsFraction = absFraction
end)

function FF_GetLeanFraction(ply)
    if not IsValid(ply) then return 0 end
    if ply == LocalPlayer() then return localFraction end
    return ply:GetNW2Float(NW_FRACTION, 0)
end

function FF_GetLeanViewOffset(ply, origin, angles)
    if not IsValid(ply) or ply ~= LocalPlayer() or not ply:Alive() then
        return Vector(0, 0, 0), Angle(0, 0, 0), 0
    end

    local fraction = localFraction
    if math.abs(fraction) < 0.0001 then
        return Vector(0, 0, 0), Angle(0, 0, 0), 0
    end

    local amount = fraction * math.max(tonumber(config.Amount) or 16, 0)
    local right = angles:Right()
    local hull = math.max(tonumber(config.CollisionHull) or 5, 1)
    local target = origin + right * amount
    local trace = util.TraceHull({
        start = origin,
        endpos = target,
        mins = Vector(-hull, -hull, -hull),
        maxs = Vector(hull, hull, hull),
        mask = MASK_SOLID,
        filter = ply,
    })

    local positionOffset = trace.HitPos - origin
    local clearanceFraction = math.Clamp(trace.Fraction or 0, 0, 1)
    local roll = fraction * math.max(tonumber(config.Roll) or 10, 0) * clearanceFraction

    return positionOffset, Angle(0, 0, roll), fraction * clearanceFraction
end

hook.Add("ShutDown", "FF_LeaningReleaseInput", function()
    leftHeld = false
    rightHeld = false
    localFraction = 0
    localVelocity = 0
end)
