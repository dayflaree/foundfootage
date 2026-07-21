if SERVER then return end

if not IKFoot or not IKFoot.Config then return end

IKFoot.Runtime = IKFoot.Runtime or {}
local RT = IKFoot.Runtime

RT.Colors = {
	white = Color(255, 255, 255),
	green = Color(0, 255, 0),
}

RT.CVars = RT.CVars or {}

for _, entry in ipairs(IKFoot.Config.entries) do
	local default = entry.default
	if entry.type == "bool" then default = default and 1 or 0 end
	RT.CVars[entry.key] = CreateClientConVar(entry.cvar, tostring(default), true, true, entry.desc)
end

function RT.GetIKParam(ply, key)
	if ply == LocalPlayer() then
		local cvar = RT.CVars[key]
		if not cvar then
			local entry = IKFoot.Config.byKey[key]
			return entry and entry.default or 0
		end
		return cvar:GetFloat()
	end
	return ply:GetNWFloat(IKFoot.Config.NWName(key), 0)
end

function RT.GetIKParamBool(ply, key)
	if ply == LocalPlayer() then
		local cvar = RT.CVars[key]
		if not cvar then
			local entry = IKFoot.Config.byKey[key]
			return entry and entry.default or false
		end
		return cvar:GetBool()
	end
	return ply:GetNWBool(IKFoot.Config.NWName(key), false)
end

-- pac3 compat. if pac is loaded we use its bone api instead
-- without this pac and ik fight each other and everything breaks

local function UsePAC()
	return istable(pac) and pac.IsEnabled and pac.IsEnabled()
		and isfunction(pac.ManipulateBonePosition) and isfunction(pac.ManipulateBoneAngles)
end

function RT.SetBonePosition(ply, bone, pos)
	if bone == nil then return end
	if UsePAC() then
		pac.ManipulateBonePosition(ply, bone, pos)
	else
		ply:ManipulateBonePosition(bone, pos)
	end
end

function RT.SetBoneAngles(ply, bone, ang)
	if bone == nil then return end
	if UsePAC() then
		pac.ManipulateBoneAngles(ply, bone, ang)
	else
		ply:ManipulateBoneAngles(bone, ang)
	end
end

function RT.GetCurrentBonePosition(ply, bone)
	if bone == nil then return Vector() end
	if UsePAC() and ply.pac_boneanim and ply.pac_boneanim.positions then
		local pos = ply.pac_boneanim.positions[bone]
		if pos then return Vector(pos) end
	end
	return Vector(ply:GetManipulateBonePosition(bone) or Vector())
end

function RT.GetCurrentBoneAngles(ply, bone)
	if bone == nil then return Angle() end
	if UsePAC() and ply.pac_boneanim and ply.pac_boneanim.angles then
		local ang = ply.pac_boneanim.angles[bone]
		if ang then return Angle(ang) end
	end
	return Angle(ply:GetManipulateBoneAngles(bone) or Angle())
end

-- tracks what ik changed on each bone so we dont fight other addons
-- this took forever to get right

function RT.GetIKBlendState(ply)
	ply.IKBlendState = ply.IKBlendState or { pos = {}, ang = {} }
	return ply.IKBlendState
end

local NEAR_EPS_VEC = 0.01
local NEAR_EPS_ANG = 0.05

local function VecNear(a, b)
	return math.abs(a.x - b.x) <= NEAR_EPS_VEC
		and math.abs(a.y - b.y) <= NEAR_EPS_VEC
		and math.abs(a.z - b.z) <= NEAR_EPS_VEC
end

local function AngNear(a, b)
	return math.abs(math.AngleDifference(a.p, b.p)) <= NEAR_EPS_ANG
		and math.abs(math.AngleDifference(a.y, b.y)) <= NEAR_EPS_ANG
		and math.abs(math.AngleDifference(a.r, b.r)) <= NEAR_EPS_ANG
end

function RT.ApplyBlendedBonePosition(ply, bone, offset)
	if bone == nil then return end
	local state = RT.GetIKBlendState(ply)
	local entry = state.pos[bone]
	if not entry then
		entry = { applied = Vector(), final = nil }
		state.pos[bone] = entry
	end

	local current = RT.GetCurrentBonePosition(ply, bone)
	local base = current
	if entry.final and VecNear(current, entry.final) then
		base = current - entry.applied
	end

	local final = base + offset
	RT.SetBonePosition(ply, bone, final)
	entry.applied = Vector(offset)
	entry.final = Vector(final)
end

function RT.ApplyBlendedBoneAngles(ply, bone, offset)
	if bone == nil then return end
	local state = RT.GetIKBlendState(ply)
	local entry = state.ang[bone]
	if not entry then
		entry = { applied = Angle(), final = nil }
		state.ang[bone] = entry
	end

	local current = RT.GetCurrentBoneAngles(ply, bone)
	local base = current
	if entry.final and AngNear(current, entry.final) then
		base = Angle(current.p - entry.applied.p, current.y - entry.applied.y, current.r - entry.applied.r)
	end

	local final = Angle(base.p + offset.p, base.y + offset.y, base.r + offset.r)
	RT.SetBoneAngles(ply, bone, final)
	entry.applied = Angle(offset)
	entry.final = Angle(final)
end

-- bone ids. cached per model so we dont look them up every frame

-- base bone count per model path. weapon bone merge adds bones AFTER
-- the models native bones so we need to know where the models bones end
local ModelBaseBoneCount = {}

local function GetBaseBoneCount(model)
	if ModelBaseBoneCount[model] then return ModelBaseBoneCount[model] end
	local mdl = ClientsideModel(model, RENDERGROUP_OTHER)
	if IsValid(mdl) then
		local count = mdl:GetBoneCount() or 0
		mdl:Remove()
		ModelBaseBoneCount[model] = count
		return count
	end
	return 0
end

-- find auxiliary root bones (hair, eyebrows, lashes etc) that arent
-- children of bone 0. only scans the models native bones to avoid
-- picking up weapon bones from bone merge
function RT.FindAuxRootBones(ply, model)
	local baseBoneCount = GetBaseBoneCount(model)
	local auxRoots = {}
	if baseBoneCount <= 0 then return auxRoots end
	for i = 1, baseBoneCount - 1 do
		if ply:GetBoneParent(i) == -1 then
			local name = ply:GetBoneName(i)
			if name and name ~= "" then
				auxRoots[#auxRoots + 1] = i
			end
		end
	end
	return auxRoots
end

function RT.GetIKBones(ply)
	local model = ply:GetModel()
	local bones = ply.IKBones
	if bones and bones.model == model then return bones end

	if bones then ply.IKBlendState = nil end

	bones = {
		model  = model,
		lFoot  = ply:LookupBone("ValveBiped.Bip01_L_Foot"),
		rFoot  = ply:LookupBone("ValveBiped.Bip01_R_Foot"),
		lCalf  = ply:LookupBone("ValveBiped.Bip01_L_Calf"),
		rCalf  = ply:LookupBone("ValveBiped.Bip01_R_Calf"),
		lThigh = ply:LookupBone("ValveBiped.Bip01_L_Thigh"),
		rThigh = ply:LookupBone("ValveBiped.Bip01_R_Thigh"),
		-- Spine1 preferred; falls back to Spine if the model only has the lower spine bone.
		-- Roll on bone 0 (Bip01) has no visible effect since it's the world-reference root.
		leanBone = ply:LookupBone("ValveBiped.Bip01_Spine1") or ply:LookupBone("ValveBiped.Bip01_Spine"),
		auxRoots = RT.FindAuxRootBones(ply, model),
		baseBoneCount = GetBaseBoneCount(model),
	}

	ply.IKBones = bones
	return bones
end

-- detect if weapon bone merge is active by comparing bone count
-- weapon models add bones on top of the models native ones
function RT.IsBoneMergeActive(ply, bones)
	local base = bones.baseBoneCount or 0
	if base <= 0 then return false end
	return (ply:GetBoneCount() or 0) > base
end

-- zero out aux bone manipulations. must be called when bone merge
-- activates or the stale ManipulateBone values corrupt SetupBones
function RT.ClearAuxBoneManipulations(ply, bones)
	local auxRoots = bones.auxRoots
	if not auxRoots or #auxRoots == 0 then return end
	local blendState = ply.IKBlendState
	for _, auxBone in ipairs(auxRoots) do
		RT.SetBonePosition(ply, auxBone, Vector())
		RT.SetBoneAngles(ply, auxBone, Angle())
		if blendState then
			blendState.pos[auxBone] = nil
			blendState.ang[auxBone] = nil
		end
	end
end

function RT.CanManipulateBones(ply)
	if ply:InVehicle() then return false end
	if istable(ActionGmod) and ply:IsDive() then return false end
	if istable(prone) and ply:IsProne() then return false end
	return true
end

-- model mesh cache. wiped on reload so formula changes take effect
IKFoot.ModelAnalysisCache = {}

function IKFoot.InvalidateModelCache(model)
	if model then
		IKFoot.ModelAnalysisCache[model] = nil
		ModelBaseBoneCount[model] = nil
	else
		IKFoot.ModelAnalysisCache = {}
		ModelBaseBoneCount = {}
	end
end

function IKFoot.MeasureModel(ply)
	-- scans the model mesh and bones to figure out ik settings
	-- this is basically black magic at this point
	if not IsValid(ply) then return nil, "Invalid player" end

	local model = ply:GetModel()
	if not model or model == "" then return nil, "No model" end

	local cached = IKFoot.ModelAnalysisCache[model]
	if cached then return cached.suggested, nil, cached.info end

	local lFootBone  = ply:LookupBone("ValveBiped.Bip01_L_Foot")
	local rFootBone  = ply:LookupBone("ValveBiped.Bip01_R_Foot")
	local lCalfBone  = ply:LookupBone("ValveBiped.Bip01_L_Calf")
	local rCalfBone  = ply:LookupBone("ValveBiped.Bip01_R_Calf")
	local lThighBone = ply:LookupBone("ValveBiped.Bip01_L_Thigh")
	local rThighBone = ply:LookupBone("ValveBiped.Bip01_R_Thigh")
	local lToeBone   = ply:LookupBone("ValveBiped.Bip01_L_Toe0")
	local rToeBone   = ply:LookupBone("ValveBiped.Bip01_R_Toe0")

	if not lFootBone or not rFootBone or not lCalfBone or not rCalfBone or not lThighBone or not rThighBone then
		return nil, "Model has no ValveBiped leg bones"
	end

	ply:SetupBones()

	local function BonePosAng(bone)
		if not bone then return nil, nil end
		local mat = ply:GetBoneMatrix(bone)
		if mat then return mat:GetTranslation(), mat:GetAngles() end
		return ply:GetBonePosition(bone)
	end

	local lThighPos          = BonePosAng(lThighBone)
	local lCalfPos           = BonePosAng(lCalfBone)
	local lFootPos, lFootAng = BonePosAng(lFootBone)
	local rThighPos          = BonePosAng(rThighBone)
	local rCalfPos           = BonePosAng(rCalfBone)
	local rFootPos, rFootAng = BonePosAng(rFootBone)
	local lToePos            = BonePosAng(lToeBone)
	local rToePos            = BonePosAng(rToeBone)

	if not lThighPos or not lCalfPos or not lFootPos or not rThighPos or not rCalfPos or not rFootPos then
		return nil, "Could not read bone positions"
	end

	-- measure the leg bones. this math took ages to get right
	local lUpperLeg = lThighPos:Distance(lCalfPos)
	local lLowerLeg = lCalfPos:Distance(lFootPos)
	local rUpperLeg = rThighPos:Distance(rCalfPos)
	local rLowerLeg = rCalfPos:Distance(rFootPos)
	local legLength = (lUpperLeg + lLowerLeg + rUpperLeg + rLowerLeg) * 0.5

	-- figure out which way the foot points. harder than it sounds
	local lFootFwd, rFootFwd = Vector(1, 0, 0), Vector(1, 0, 0)
	if lFootAng then
		lFootFwd = lFootAng:Forward()
		lFootFwd.z = 0
		if lFootFwd:LengthSqr() > 0.001 then lFootFwd:Normalize() else lFootFwd = Vector(1, 0, 0) end
	end
	if rFootAng then
		rFootFwd = rFootAng:Forward()
		rFootFwd.z = 0
		if rFootFwd:LengthSqr() > 0.001 then rFootFwd:Normalize() else rFootFwd = Vector(1, 0, 0) end
	end

	local footBoneLength = 0
	if lToePos and rToePos then
		footBoneLength = (lFootPos:Distance(lToePos) + rFootPos:Distance(rToePos)) * 0.5
	end

	local plyZ = ply:GetPos().z
	local footBoneHeight = ((lFootPos.z - plyZ) + (rFootPos.z - plyZ)) * 0.5
	local thighHeight = ((lThighPos.z - plyZ) + (rThighPos.z - plyZ)) * 0.5

	-- scan actual mesh verts to figure out where the feet really are
	local meshes = util.GetModelMeshes(model)
	local meshBottomZ = 0
	local footMeshLength, footMeshWidth = 0, 0
	local footVertCount = 0

	if meshes then
		local lowestZ = math.huge
		local footRegionVerts = {}
		local footZThresholdHigh = footBoneHeight + 4
		local footZThresholdLow = -6

		for _, meshGroup in ipairs(meshes) do
			if not meshGroup.triangles then continue end
			for _, vert in ipairs(meshGroup.triangles) do
				if not vert.pos then continue end
				if vert.pos.z < lowestZ then
					lowestZ = vert.pos.z
				end
				if vert.pos.z <= footZThresholdHigh and vert.pos.z >= footZThresholdLow then
					footRegionVerts[#footRegionVerts + 1] = vert.pos
				end
			end
		end

		if lowestZ < math.huge then
			meshBottomZ = lowestZ
		end

		-- try to figure out foot dimensions from mesh. this is cursed
		if #footRegionVerts >= 10 then
			local avgFwd = (lFootFwd + rFootFwd)
			if avgFwd:LengthSqr() > 0.001 then avgFwd:Normalize() else avgFwd = Vector(1, 0, 0) end
			local avgRight = avgFwd:Cross(Vector(0, 0, 1))
			if avgRight:LengthSqr() > 0.001 then avgRight:Normalize() else avgRight = Vector(0, 1, 0) end

			local minFwd, maxFwd = math.huge, -math.huge
			local minRight, maxRight = math.huge, -math.huge

			for _, v in ipairs(footRegionVerts) do
				local fP = v.x * avgFwd.x + v.y * avgFwd.y
				local rP = v.x * avgRight.x + v.y * avgRight.y
				if fP < minFwd then minFwd = fP end
				if fP > maxFwd then maxFwd = fP end
				if rP < minRight then minRight = rP end
				if rP > maxRight then maxRight = rP end
			end

			footMeshLength = maxFwd - minFwd
			footMeshWidth = math.max((maxRight - minRight) * 0.35, 2)
			footVertCount = #footRegionVerts
		end
	end

	-- scale relative to standard valve skeleton
	local refLeg = 45
	local scale = math.Clamp(legLength / refLeg, 0.4, 2.5)

	-- how much the model floats above ground. dont ask why this is so complicated
	local groundGap = math.Clamp(math.max(meshBottomZ, 0), 0, footBoneHeight * 0.8)
	local belowOrigin = math.max(0, -meshBottomZ)

	-- sole offset hack. accounts for shoes and floating meshes somehow
	local soleOffset = math.Clamp(belowOrigin * 0.35 + groundGap * 0.5, 0, 2)

	-- extra drop for meshes that dont touch the ground properly
	local meshGapRef = groundGap / scale
	local extraBodyDrop = math.Round(math.max(0.3, 0.3 + meshGapRef), 1)
	local extraDropUneven = math.Round(math.max(1.2, 1.2 + meshGapRef), 1)

	-- thighHeight is already in world units; don't divide by scale again or
	-- the offset stays constant regardless of model size
	local traceStartRef = math.Clamp(math.Round(thighHeight * 0.85, 0), 20, 40)

	local suggested = {
		leg_length             = math.Round(legLength, 0),
		trace_start_offset     = traceStartRef,
		sole_offset            = math.Round(soleOffset, 2),
		extra_body_drop        = extraBodyDrop,
		extra_body_drop_uneven = extraDropUneven,
		max_body_drop          = math.Round(math.Clamp(legLength * 0.95, 42, 80), 0),
		high_foot_bend_boost   = 1.70,
		foot_rotation_scale    = 0.15,
	}

	local info = {
		model             = model,
		legLength         = legLength,
		upperLegLength    = (lUpperLeg + rUpperLeg) * 0.5,
		lowerLegLength    = (lLowerLeg + rLowerLeg) * 0.5,
		footBoneHeight    = footBoneHeight,
		footBoneLength    = footBoneLength,
		footForwardL      = lFootFwd,
		footForwardR      = rFootFwd,
		meshBottomZ       = meshBottomZ,
		meshFootLength    = footMeshLength,
		meshFootWidth     = footMeshWidth,
		meshFootVertCount = footVertCount,
		soleOffset        = soleOffset,
		groundGap         = groundGap,
		thighHeight       = thighHeight,
		scale             = scale,
	}

	IKFoot.ModelAnalysisCache[model] = { suggested = suggested, info = info }

	return suggested, nil, info
end

-- auto applies settings on model change. without this everything looks wrong after playermodel swap
function IKFoot.AutoApplyModelSettings(ply)
	if not IsValid(ply) or ply ~= LocalPlayer() then return end

	local suggested, err, info = IKFoot.MeasureModel(ply)
	if not suggested then return end

	local byKey = IKFoot.Config.byKey
	for key, value in pairs(suggested) do
		local entry = byKey[key]
		if entry then
			RunConsoleCommand(entry.cvar, tostring(value))
		end
	end

	-- reset sole correction or old values haunt you
	if RT.Controller and RT.Controller.ResetDynSole then
		RT.Controller.ResetDynSole(ply)
	end

	local modelShort = string.GetFileFromFilename(info.model or "unknown") or "model"
	chat.AddText(
		Color(100, 255, 100), "[IK Foot] ",
		Color(255, 255, 255), "Auto-configured for ",
		Color(100, 200, 255), modelShort,
		Color(255, 255, 255), string.format(" (leg=%.0f, sole=%.2f, scale=%.2f)", info.legLength, info.soleOffset, info.scale)
	)
end

function IKFoot.HardReset(ply)
	if not IsValid(ply) then return end
	RT.Apply.HardResetPlayer(ply)
	IKFoot.InvalidateModelCache(ply:GetModel())
end

function IKFoot.HardResetAll()
	IKFoot.InvalidateModelCache()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) then
			RT.Apply.HardResetPlayer(ply)
		end
	end
end

concommand.Add("ik_foot_hard_reset", function()
	local ply = LocalPlayer()
	if IsValid(ply) then
		IKFoot.HardReset(ply)
		chat.AddText(Color(100, 255, 100), "[IK Foot] ", Color(255, 255, 255), "Hard reset complete - all IK state cleared")
	end
end)
