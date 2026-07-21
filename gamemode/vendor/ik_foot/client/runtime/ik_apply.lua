if SERVER then return end
if not IKFoot or not IKFoot.Runtime then return end

local RT = IKFoot.Runtime
RT.Apply = RT.Apply or {}
local Apply = RT.Apply

local function IsFiniteNumber(value)
	return isnumber(value) and value == value and value > -math.huge and value < math.huge
end

local function IsFiniteVector(vec)
	return isvector(vec)
		and IsFiniteNumber(vec.x)
		and IsFiniteNumber(vec.y)
		and IsFiniteNumber(vec.z)
end

local function IsReasonableBonePosition(ply, pos)
	if not (IsValid(ply) and IsFiniteVector(pos)) then return false end
	local plyPos = ply:GetPos()
	if not IsFiniteVector(plyPos) then return false end
	return pos:DistToSqr(plyPos) <= (260 * 260)
end

local function GetBoneWorldTransform(ply, bone)
	if not bone or bone < 0 then return nil, nil end

	if ply.GetBoneMatrix then
		local matrix = ply:GetBoneMatrix(bone)
		if matrix then
			local pos = matrix:GetTranslation()
			local ang = matrix:GetAngles()
			if IsFiniteVector(pos) and IsReasonableBonePosition(ply, pos) and ang then
				return pos, ang
			end
		end
	end

	local pos, ang = ply:GetBonePosition(bone)
	if IsFiniteVector(pos) and IsReasonableBonePosition(ply, pos) and ang then
		return pos, ang
	end

	return nil, nil
end

local function SpringScalar(current, velocity, target, smoothTime, dt)
	-- nan check. if numbers go insane just snap to target and pray
	if not (IsFiniteNumber(current) and IsFiniteNumber(velocity) and IsFiniteNumber(target)) then
		return IsFiniteNumber(target) and target or 0, 0
	end
	smoothTime = math.max(smoothTime, 0.0001)
	local omega = 2 / smoothTime
	local x = omega * dt
	local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
	local change = current - target
	local temp = (velocity + omega * change) * dt
	local newVelocity = (velocity - omega * temp) * exp
	local newValue = target + (change + temp) * exp
	if not IsFiniteNumber(newValue) then return IsFiniteNumber(target) and target or 0, 0 end
	if not IsFiniteNumber(newVelocity) then newVelocity = 0 end
	return newValue, newVelocity
end

local function SpringVector(current, velocity, target, smoothTime, dt)
	local x, xv = SpringScalar(current.x, velocity.x, target.x, smoothTime, dt)
	local y, yv = SpringScalar(current.y, velocity.y, target.y, smoothTime, dt)
	local z, zv = SpringScalar(current.z, velocity.z, target.z, smoothTime, dt)
	return Vector(x, y, z), Vector(xv, yv, zv)
end

local function SpringAngle(current, velocity, target, smoothTime, dt)
	local targetP = current.p + math.AngleDifference(target.p, current.p)
	local targetY = current.y + math.AngleDifference(target.y, current.y)
	local targetR = current.r + math.AngleDifference(target.r, current.r)
	local p, pv = SpringScalar(current.p, velocity.p, targetP, smoothTime, dt)
	local y, yv = SpringScalar(current.y, velocity.y, targetY, smoothTime, dt)
	local r, rv = SpringScalar(current.r, velocity.r, targetR, smoothTime, dt)
	return Angle(p, y, r), Angle(pv, yv, rv)
end

local SPRING_FIELDS = {"leftThigh", "leftCalf", "leftFoot", "rightThigh", "rightCalf", "rightFoot", "lean"}

local function EnsureApplyState(ply)
	if not ply.IKApplyState then
		local s = {
			basePos = Vector(), basePosVel = Vector(),
			baseAng = Angle(), baseAngVel = Angle(),
		}
		for _, name in ipairs(SPRING_FIELDS) do
			s[name] = Angle()
			s[name .. "Vel"] = Angle()
		end
		ply.IKApplyState = s
	end
	return ply.IKApplyState
end

local STRIP_POS_EPS = 0.1
local STRIP_ANG_EPS = 0.15

local function VecNearEps(a, b, eps)
	return math.abs(a.x - b.x) <= eps and math.abs(a.y - b.y) <= eps and math.abs(a.z - b.z) <= eps
end

local function AngNearEps(a, b, eps)
	return math.abs(math.AngleDifference(a.p, b.p)) <= eps
		and math.abs(math.AngleDifference(a.y, b.y)) <= eps
		and math.abs(math.AngleDifference(a.r, b.r)) <= eps
end

function Apply.StripIKFromBones(ply, bones)
	-- undo what ik did to the bones before recalculating
	-- if we skip this everything drifts into oblivion
	-- note: aux root bones (hair, eyebrows etc) are NOT stripped here.
	-- stripping them before SetupBones interferes with weapon bone merging.
	-- ApplyBlendedBone handles their delta internally so its fine
	-- i hate this addon
	local blendState = RT.GetIKBlendState(ply)
	if not blendState then return end

	local posEntry = blendState.pos[0]
	if posEntry and posEntry.applied and posEntry.final then
		local current = RT.GetCurrentBonePosition(ply, 0)
		if VecNearEps(current, posEntry.final, STRIP_POS_EPS) then
			RT.SetBonePosition(ply, 0, current - posEntry.applied)
		end
	end

	local allBones = {0, bones.lThigh, bones.rThigh, bones.lCalf, bones.rCalf, bones.lFoot, bones.rFoot, bones.leanBone}
	for _, bone in ipairs(allBones) do
		if bone then
			local angEntry = blendState.ang[bone]
			if angEntry and angEntry.applied and angEntry.final then
				local current = RT.GetCurrentBoneAngles(ply, bone)
				if AngNearEps(current, angEntry.final, STRIP_ANG_EPS) then
					RT.SetBoneAngles(ply, bone, Angle(current.p - angEntry.applied.p, current.y - angEntry.applied.y, current.r - angEntry.applied.r))
				end
			end
		end
	end
end

function Apply.BuildSkeleton(ply, bones)
	-- reads all bone positions and builds skeleton data for ik
	local lThighPos, lThighAng = GetBoneWorldTransform(ply, bones.lThigh)
	local lCalfPos, lCalfAng = GetBoneWorldTransform(ply, bones.lCalf)
	local lFootPos, lFootAng = GetBoneWorldTransform(ply, bones.lFoot)
	local rThighPos, rThighAng = GetBoneWorldTransform(ply, bones.rThigh)
	local rCalfPos, rCalfAng = GetBoneWorldTransform(ply, bones.rCalf)
	local rFootPos, rFootAng = GetBoneWorldTransform(ply, bones.rFoot)

	if not lThighPos or not lCalfPos or not lFootPos or not rThighPos or not rCalfPos or not rFootPos then
		return nil
	end

	-- measure leg length from actual bones. cached so we dont do this every frame.
	-- only cache if the measurement looks sane (> 20 units). on first frame bones can
	-- return bad positions if SetupBones hasn't run yet, which would cache garbage forever.
	if ply.IKMeasuredModel ~= (bones and bones.model) then
		local lLen = lThighPos:Distance(lCalfPos) + lCalfPos:Distance(lFootPos)
		local rLen = rThighPos:Distance(rCalfPos) + rCalfPos:Distance(rFootPos)
		local measured = (lLen + rLen) * 0.5
		if measured > 20 then
			ply.IKMeasuredLegLength = measured
			ply.IKMeasuredModel = bones and bones.model
		end
	end

	return {
		measuredLegLength = ply.IKMeasuredLegLength or 45,
		left = {
			thighPos = lThighPos,
			thighAng = lThighAng,
			calfPos = lCalfPos,
			calfAng = lCalfAng,
			footPos = lFootPos,
			footAng = lFootAng,
		},
		right = {
			thighPos = rThighPos,
			thighAng = rThighAng,
			calfPos = rCalfPos,
			calfAng = rCalfAng,
			footPos = rFootPos,
			footAng = rFootAng,
		},
	}
end

function Apply.ResetPlayer(ply, bones)
	-- reset everything before it goes to shit
	-- without this the character turns into a pretzel
	bones = bones or RT.GetIKBones(ply)
	RT.ApplyBlendedBonePosition(ply, 0, Vector())
	RT.ApplyBlendedBoneAngles(ply, 0, Angle())

	if bones.auxRoots and #bones.auxRoots > 0 and not RT.IsBoneMergeActive(ply, bones) then
		for _, auxBone in ipairs(bones.auxRoots) do
			RT.ApplyBlendedBonePosition(ply, auxBone, Vector())
			RT.ApplyBlendedBoneAngles(ply, auxBone, Angle())
		end
	end

	if bones.lCalf then RT.ApplyBlendedBoneAngles(ply, bones.lCalf, Angle()) end
	if bones.rCalf then RT.ApplyBlendedBoneAngles(ply, bones.rCalf, Angle()) end
	if bones.lThigh then RT.ApplyBlendedBoneAngles(ply, bones.lThigh, Angle()) end
	if bones.rThigh then RT.ApplyBlendedBoneAngles(ply, bones.rThigh, Angle()) end
	if bones.lFoot then RT.ApplyBlendedBoneAngles(ply, bones.lFoot, Angle()) end
	if bones.rFoot then RT.ApplyBlendedBoneAngles(ply, bones.rFoot, Angle()) end
	if bones.leanBone then RT.ApplyBlendedBoneAngles(ply, bones.leanBone, Angle()) end

	ply.IKApplyState = nil
	RT.State.Reset(ply)
end

function Apply.HardResetPlayer(ply)
	-- the nuclear reset. when normal reset isnt enough
	-- bypasses everything and zeros all bones directly
	local bones = RT.GetIKBones(ply)

	-- bypass blend layer and zero everything. nuclear option
	local allBones = {0, bones.lThigh, bones.rThigh, bones.lCalf, bones.rCalf, bones.lFoot, bones.rFoot}
	if bones.leanBone then allBones[#allBones + 1] = bones.leanBone end
	if bones.auxRoots then
		for _, auxBone in ipairs(bones.auxRoots) do
			allBones[#allBones + 1] = auxBone
		end
	end
	for _, bone in ipairs(allBones) do
		if bone then
			ply:ManipulateBonePosition(bone, Vector())
			ply:ManipulateBoneAngles(bone, Angle())
		end
	end

	-- nuke pac3 bone state too if its around
	if istable(pac) and isfunction(pac.ManipulateBonePosition) and isfunction(pac.ManipulateBoneAngles) then
		for _, bone in ipairs(allBones) do
			if bone then
				pcall(pac.ManipulateBonePosition, ply, bone, Vector())
				pcall(pac.ManipulateBoneAngles, ply, bone, Angle())
			end
		end
	end

	-- wipe all runtime state
	RT.State.HardReset(ply)

	if IsValid(ply) then
		ply:SetupBones()
	end
end

function Apply.ApplyResult(ply, bones, result)
	-- takes ik result and applies it to bones with spring smoothing
	-- without smoothing it looks like a robot having a seizure
	local s = EnsureApplyState(ply)
	local dt = math.Clamp(FrameTime(), 1 / 300, 1 / 20)
	local posST = math.max(0.02, 0.28 / math.max(RT.GetIKParam(ply, "smoothing"), 1))
	local rotST = math.max(0.02, 0.28 / math.max(RT.GetIKParam(ply, "rotation_smoothing"), 1))
	local hardIdle = result.debug and result.debug.idleActive and (result.debug.velocity2D or 0) <= RT.GetIKParam(ply, "idle_velocity")

	local targets = {
		leftThigh = result.left.thigh, leftCalf = result.left.calf, leftFoot = result.left.foot,
		rightThigh = result.right.thigh, rightCalf = result.right.calf, rightFoot = result.right.foot,
		lean = result.leanAng or Angle(),
	}

	if hardIdle then
		s.basePos = result.basePos
		s.baseAng = result.baseAng
		s.basePosVel = Vector()
		s.baseAngVel = Angle()
		for _, name in ipairs(SPRING_FIELDS) do
			s[name] = targets[name]
			s[name .. "Vel"] = Angle()
		end
	else
		s.basePos, s.basePosVel = SpringVector(s.basePos, s.basePosVel, result.basePos, posST, dt)
		s.baseAng, s.baseAngVel = SpringAngle(s.baseAng, s.baseAngVel, result.baseAng, rotST, dt)
		for _, name in ipairs(SPRING_FIELDS) do
			s[name], s[name .. "Vel"] = SpringAngle(s[name], s[name .. "Vel"], targets[name], rotST, dt)
		end
	end

	-- if spring state got corrupted by nan nuke it from orbit
	if not IsFiniteVector(s.basePos) or not IsFiniteNumber(s.baseAng.p) then
		ply.IKApplyState = nil
		s = EnsureApplyState(ply)
	end

	RT.ApplyBlendedBonePosition(ply, 0, s.basePos)
	RT.ApplyBlendedBoneAngles(ply, 0, s.baseAng)

	-- apply same body offset to auxiliary root bones (hair, eyebrows, lashes)
	-- without this they desync from the body and appear doubled
	-- SKIP when bone merge is active (weapon equipped) because ManipulateBone
	-- on root bones corrupts SetupBones during bone merge
	local auxRoots = bones.auxRoots
	if auxRoots and #auxRoots > 0 then
		if RT.IsBoneMergeActive(ply, bones) then
			-- weapon equipped. clear any leftover aux manipulations
			if not ply.IKAuxCleared then
				RT.ClearAuxBoneManipulations(ply, bones)
				ply.IKAuxCleared = true
			end
		else
			ply.IKAuxCleared = nil
			for _, auxBone in ipairs(auxRoots) do
				RT.ApplyBlendedBonePosition(ply, auxBone, s.basePos)
				RT.ApplyBlendedBoneAngles(ply, auxBone, s.baseAng)
			end
		end
	end

	RT.ApplyBlendedBoneAngles(ply, bones.lThigh, s.leftThigh)
	RT.ApplyBlendedBoneAngles(ply, bones.rThigh, s.rightThigh)
	RT.ApplyBlendedBoneAngles(ply, bones.lCalf, s.leftCalf)
	RT.ApplyBlendedBoneAngles(ply, bones.rCalf, s.rightCalf)
	RT.ApplyBlendedBoneAngles(ply, bones.lFoot, s.leftFoot)
	RT.ApplyBlendedBoneAngles(ply, bones.rFoot, s.rightFoot)
	if bones.leanBone then
		RT.ApplyBlendedBoneAngles(ply, bones.leanBone, s.lean)
	end
end