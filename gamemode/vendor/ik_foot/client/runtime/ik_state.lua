if SERVER then return end
if not IKFoot or not IKFoot.Runtime then return end

local RT = IKFoot.Runtime
RT.State = RT.State or {}
local State = RT.State

local IDLE_ACQUIRE_DELAY = 0.14
local CROUCH_TRANSITION_TIME = 0.3

local function IsFiniteNumber(v)
	return isnumber(v) and v == v and v > -math.huge and v < math.huge
end

local function IsFiniteVector(vec)
	return isvector(vec) and IsFiniteNumber(vec.x) and IsFiniteNumber(vec.y) and IsFiniteNumber(vec.z)
end

local PROC_DEFAULT = function()
	return { phase = "planted", plantPos = nil, swingStart = nil, swingTarget = nil, swingT = 0, liftH = 0, blendT = 0 }
end

local function EnsureFootState(container, side)
	container.legs = container.legs or {}
	container.legs[side] = container.legs[side] or {
		planted = false,
		lockPos = nil,
		lastRawPos = nil,
		lastTargetPos = nil,
		footSpeed = 0,
		released = false,
		proc = PROC_DEFAULT(),
	}
	if not container.legs[side].proc then
		container.legs[side].proc = PROC_DEFAULT()
	end
	return container.legs[side]
end

function State.Get(ply)
	ply.IKRuntimeState = ply.IKRuntimeState or {
		idle = { active = false, candidateTime = 0 },
		legs = {},
		stairs = { sequence = 0, lastStepTime = 0, confidence = 0, upHeight = 0, downHeight = 0, eventHeight = 0, mode = false, prevLeftReq = 0, prevRightReq = 0 },
		crouch = { crouching = false, transitionTime = 0, inTransition = false },
	}
	EnsureFootState(ply.IKRuntimeState, "left")
	EnsureFootState(ply.IKRuntimeState, "right")
	if not ply.IKRuntimeState.crouch then
		ply.IKRuntimeState.crouch = { crouching = false, transitionTime = 0, inTransition = false }
	end
	if not ply.IKRuntimeState.stairs then
		ply.IKRuntimeState.stairs = { sequence = 0, lastStepTime = 0, confidence = 0, upHeight = 0, downHeight = 0, eventHeight = 0, mode = false, prevLeftReq = 0, prevRightReq = 0 }
	end
	return ply.IKRuntimeState
end

function State.Reset(ply)
	-- wipe everything. without this the character becomes a horror show
	ply.IKRuntimeState = nil
	ply.IKResult = nil
	ply.IKFootLastPos = nil
	ply.IKFootBoneLastPos = nil
	ply.IKLastBodyDrop = nil
	ply.IKMeasuredLegLength = nil
	ply.IKMeasuredModel = nil
	ply.IKApplyState = nil
	ply.IKBlendState = nil
	ply.IKFailCount = nil
	ply.IKAuxCleared = nil
end

function State.HardReset(ply)
	-- nuclear wipe. clears absolutely everything including bone cache
	State.Reset(ply)
	ply.IKBones = nil
	ply.IKLastKnownModel = nil
	if IsValid(ply) and RT.Controller and RT.Controller.ResetDynSole then
		RT.Controller.ResetDynSole(ply)
	end
end

function State.SoftRecover(ply)
	if not IsValid(ply) then return end
	local state = State.Get(ply)
	state.bodyDrop = nil
	state.idle.active = false
	state.idle.candidateTime = 0

	for _, side in ipairs({"left", "right"}) do
		local leg = EnsureFootState(state, side)
		leg.planted = false
		leg.lockPos = nil
		leg.lastRawPos = nil
		leg.lastTargetPos = nil
		leg.footSpeed = 0
		leg.released = true
		leg.lockAge = 0
		leg.proc = PROC_DEFAULT()
	end

	state.stairs = { sequence = 0, lastStepTime = 0, confidence = 0, upHeight = 0, downHeight = 0, eventHeight = 0, mode = false, prevLeftReq = 0, prevRightReq = 0 }

	if RT.Controller and RT.Controller.ResetDynSole then
		RT.Controller.ResetDynSole(ply)
	end

	ply.IKSoftRecoverCount = (ply.IKSoftRecoverCount or 0) + 1
end

function State.UpdateCrouch(runtimeState, isCrouching)
	local crouch = runtimeState.crouch
	if crouch.crouching ~= isCrouching then
		crouch.crouching = isCrouching
		crouch.transitionTime = 0
		crouch.inTransition = true
		-- unlock feet during crouch or they get stuck in weird places
		for _, side in ipairs({"left", "right"}) do
			local leg = runtimeState.legs[side]
			if leg then
				leg.planted = false
				leg.lockPos = nil
				leg.lastRawPos = nil
			end
		end
		runtimeState.idle.active = false
		runtimeState.idle.candidateTime = 0
	end
	if crouch.inTransition then
		crouch.transitionTime = crouch.transitionTime + FrameTime()
		if crouch.transitionTime >= CROUCH_TRANSITION_TIME then
			crouch.inTransition = false
		end
	end
	return crouch
end

function State.UpdateIdle(runtimeState, onGround, velocity2D, vertVel, idleVelocityThreshold, leftRawPos, rightRawPos)
	local idle = runtimeState.idle
	local isCandidate = onGround and velocity2D <= idleVelocityThreshold and math.abs(vertVel) <= (idleVelocityThreshold * 0.5)

	if isCandidate then
		idle.candidateTime = idle.candidateTime + FrameTime()
	else
		idle.candidateTime = 0
		idle.active = false
	end

	if isCandidate and idle.candidateTime >= IDLE_ACQUIRE_DELAY then
		idle.active = true
		idle.leftRaw = Vector(leftRawPos)
		idle.rightRaw = Vector(rightRawPos)
	end

	return idle, isCandidate
end

function State.MeasureFootSpeed(footState, rawFootPos, frameDt)
	if frameDt <= 0 then
		footState.footSpeed = 0
	elseif footState.lastRawPos and IsFiniteVector(rawFootPos) and IsFiniteVector(footState.lastRawPos) then
		local speed = rawFootPos:Distance(footState.lastRawPos) / math.max(frameDt, 1 / 300)
		footState.footSpeed = IsFiniteNumber(speed) and speed or 0
	else
		footState.footSpeed = 0
	end
	if IsFiniteVector(rawFootPos) then
		footState.lastRawPos = Vector(rawFootPos)
	end
	return footState.footSpeed
end

function State.UpdateFoot(footState, data)
	-- decides if foot should lock to ground or release
	-- the most fragile part of the whole system. dont touch
	footState.released = false

	if data.contact.hasHit and not IsFiniteVector(data.contact.position) then
		data.contact.hasHit = false
	end

	if not data.onGround then
		footState.planted = false
		footState.lockPos = nil
	end

	-- if lock drifted way too far from foot something went wrong. let go
	if footState.lockPos then
		local lockDist = data.rawFootPos:Distance(footState.lockPos)
		if lockDist > math.max(40, data.lockStrength * 25) then
			footState.planted = false
			footState.lockPos = nil
			footState.released = true
		end
	end

	local acquireDistance = math.max(4, 8 * data.lockStrength)
	local releaseDistance = math.max(acquireDistance * 1.3, 6 + data.lockStrength * 6)
	local stairReleaseMul = math.max(tonumber(data.stairReleaseMultiplier) or 1, 1)
	local releaseSpeed = math.max(data.releaseSpeed, 5)
	local stairMode = data.stairMode and (data.stairConfidence or 0) >= 0.2
	if stairMode then
		if data.isSupportFoot then
			releaseDistance = releaseDistance * math.max(1.05, stairReleaseMul * 0.9)
			acquireDistance = acquireDistance * math.Clamp(1 + (data.stairConfidence or 0) * 0.2, 1, 1.2)
		else
			-- swing foot must release sooner on stairs to avoid giant stretched steps
			releaseDistance = releaseDistance * 0.82
			acquireDistance = acquireDistance * 0.9
			releaseSpeed = releaseSpeed * 0.82
		end
	end
	local shouldAcquire = data.contact.hasHit and data.onGround and (
		data.idleActive
		or (data.footSpeed <= releaseSpeed * 0.55 and data.rawFootPos:Distance(data.contact.position) <= acquireDistance)
		or (data.isSupportFoot and data.rawFootPos:Distance(data.contact.position) <= acquireDistance * 1.2)
	)

	if footState.lockPos then
		footState.lockAge = (footState.lockAge or 0) + FrameTime()
		local distToLock = data.rawFootPos:Distance(footState.lockPos)
		local wantsStrideRelease = data.footSpeed > releaseSpeed and distToLock > releaseDistance * 0.5
		local stairHardLimit = stairMode and (data.isSupportFoot and releaseDistance * 0.85 or releaseDistance * 0.55) or math.huge

		if not data.idleActive and (wantsStrideRelease or distToLock > releaseDistance or distToLock > stairHardLimit) then
			footState.planted = false
			footState.lockPos = nil
			footState.released = true
		end
	end

	if not footState.lockPos and shouldAcquire then
		footState.lockPos = Vector(data.contact.position)
		footState.planted = true
		footState.lockAge = 0
	elseif footState.lockPos then
		footState.planted = true
	end

	if footState.lockPos and (footState.lockAge or 0) > 10 then
		footState.planted = false
		footState.lockPos = nil
		footState.released = true
		footState.lockAge = 0
	end

	if data.idleActive and data.contact.hasHit then
		if not footState.lockPos then
			footState.lockPos = Vector(data.contact.position)
		end
		footState.planted = true
	end

	local desiredPos
	if footState.lockPos then
		desiredPos = Vector(footState.lockPos)
	elseif data.contact.hasHit then
		desiredPos = Vector(data.contact.position)
	else
		desiredPos = Vector(data.rawFootPos)
	end

	if not IsFiniteVector(desiredPos) then
		desiredPos = IsFiniteVector(data.rawFootPos) and Vector(data.rawFootPos) or Vector(0, 0, 0)
	end

	footState.lastTargetPos = Vector(desiredPos)

	return {
		planted = footState.planted and footState.lockPos ~= nil,
		lockPos = footState.lockPos and Vector(footState.lockPos) or nil,
		targetPos = desiredPos,
		footSpeed = footState.footSpeed,
		released = footState.released,
	}
end

function State.UpdateStairSequence(runtimeState, stairData)
	local stairs = runtimeState.stairs
	local now = CurTime()
	local window = math.max(tonumber(stairData.sequenceWindow) or 0.33, 0.12)
	local stepUp = math.max(stairData.leftRise or 0, stairData.rightRise or 0)
	local stepDown = math.max(stairData.leftDrop or 0, stairData.rightDrop or 0)
	local asymmetry = math.max(stairData.heightDiff or 0, 0)
	local eventHeight = math.max(stepUp, stepDown, asymmetry * 0.75)

	if eventHeight > 0.2 and stairData.eligible then
		if now - (stairs.lastStepTime or 0) <= window then
			stairs.sequence = math.min((stairs.sequence or 0) + 1, 8)
		else
			stairs.sequence = 1
		end
		stairs.lastStepTime = now
	else
		stairs.sequence = math.max((stairs.sequence or 0) - FrameTime() * 4, 0)
	end

	local confidenceBase = stairData.edgeConfidence or 0
	local asymmetrySignal = math.Clamp(asymmetry / math.max(tonumber(stairData.stepMax) or 24, 1), 0, 1)
	local sequenceBonus = math.Clamp((stairs.sequence or 0) / 3, 0, 1)
	local confidence = math.Clamp(confidenceBase * 0.55 + asymmetrySignal * 0.5 + sequenceBonus * 0.4, 0, 1)
	if not stairData.surfaceStable then
		confidence = confidence * 0.5
	end

	stairs.confidence = confidence
	stairs.upHeight = stepUp
	stairs.downHeight = stepDown
	stairs.eventHeight = eventHeight
	stairs.mode = stairData.eligible and confidence >= 0.4

	return {
		mode = stairs.mode,
		confidence = confidence,
		sequence = stairs.sequence,
		upHeight = stepUp,
		downHeight = stepDown,
		eventHeight = eventHeight,
	}
end

-- Manages the procedural step arc for one foot when in stair mode.
-- Returns an overridden world position for the foot this frame, or nil to use animation pos.
-- data fields:
--   stairMode (bool), stairConfidence (0-1), dt (FrameTime),
--   playerPos (Vector), moveDir (normalized XY Vector), vel2D (number),
--   strideLen (number), liftHeight (number),
--   currentLock (Vector or nil) -- existing IK lock pos for initial plant
--   rawFootPos (Vector) -- animation bone pos (fallback / blend target)
--   swingTarget (Vector or nil) -- predicted landing from PredictLanding
function State.UpdateStepperFoot(footState, otherFootState, data)
	local proc = footState.proc
	if not proc then
		footState.proc = PROC_DEFAULT()
		proc = footState.proc
	end

	-- blend IN (stair active) or OUT (returning to animation)
	local fadeRate = data.stairMode and 6 or -5
	proc.blendT = math.Clamp((proc.blendT or 0) + data.dt * fadeRate, 0, 1)

	-- seeding plant pos from best available source
	if not proc.plantPos then
		proc.plantPos = data.currentLock and Vector(data.currentLock)
			or Vector(data.rawFootPos)
		proc.phase = "planted"
		proc.swingT = 0
	end

	if data.stairMode then
		local otherProc = otherFootState and otherFootState.proc
		local otherSwinging = otherProc and otherProc.phase == "swinging"

		if proc.phase == "planted" then
			-- how many units has the player moved ahead of where this foot is planted?
			local dx = data.playerPos.x - proc.plantPos.x
			local dy = data.playerPos.y - proc.plantPos.y
			local behindDist = dx * data.moveDir.x + dy * data.moveDir.y

			if not otherSwinging
				and behindDist >= data.strideLen * 0.45
				and data.vel2D > 5
				and data.swingTarget ~= nil then
				proc.phase = "swinging"
				proc.swingStart = Vector(proc.plantPos)
				proc.swingT = 0
				proc.liftH = data.liftHeight
				proc.swingTarget = Vector(data.swingTarget)
			end
		end

		if proc.phase == "swinging" then
			-- T goes 0→1 over one "stride" of movement
			local swingRate = math.max(data.vel2D, 8) / math.max(data.strideLen, 10)
			proc.swingT = math.min(proc.swingT + data.dt * swingRate, 1.0)

			if proc.swingT >= 1.0 then
				proc.phase = "planted"
				proc.plantPos = proc.swingTarget and Vector(proc.swingTarget) or Vector(data.rawFootPos)
				proc.swingStart = nil
			end
		end
	else
		-- outside stair mode: slowly zero out state so re-entry starts clean
		if proc.blendT <= 0 then
			proc.plantPos = nil
			proc.phase = "planted"
			proc.swingT = 0
		end
	end

	-- compute world position for this frame
	local procPos
	if proc.phase == "swinging" and proc.swingStart and proc.swingTarget then
		local t = proc.swingT
		local x = proc.swingStart.x + (proc.swingTarget.x - proc.swingStart.x) * t
		local y = proc.swingStart.y + (proc.swingTarget.y - proc.swingStart.y) * t
		local baseZ = proc.swingStart.z + (proc.swingTarget.z - proc.swingStart.z) * t
		-- sine-arc gives enough clearance over step edges
		procPos = Vector(x, y, baseZ + math.sin(t * math.pi) * proc.liftH)
	elseif proc.plantPos then
		procPos = Vector(proc.plantPos)
	else
		return nil
	end

	if not (isvector(procPos) and procPos.x == procPos.x) then return nil end

	-- blend toward full proc when entering stair mode, back to animation when leaving
	if proc.blendT < 1 then
		local raw = data.rawFootPos
		return Vector(
			raw.x + (procPos.x - raw.x) * proc.blendT,
			raw.y + (procPos.y - raw.y) * proc.blendT,
			raw.z + (procPos.z - raw.z) * proc.blendT
		)
	end
	return procPos
end