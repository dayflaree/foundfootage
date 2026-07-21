if SERVER then return end
if not IKFoot or not IKFoot.Runtime then return end

local RT = IKFoot.Runtime
RT.Ground = RT.Ground or {}
local Ground = RT.Ground

local WALKABLE_Z = 0.35
local DEFAULT_SURFACE_MAX_SPEED = 45
local COLOR_LEFT  = Color(80, 190, 255)
local COLOR_RIGHT = Color(255, 165, 90)
-- only average samples within this many units of the highest hit.
-- prevents low-side (ground/air) samples from dragging the contact down
-- when the foot is half on a curb or step edge.
local CLUSTER_TOLERANCE = 3.0

local SAMPLE_WEIGHTS = {
	center = 4, toe = 2, heel = 2,
	left = 2, right = 2,
	toeInner = 1, toeOuter = 1, inner = 1, outer = 1,
}

local function IsWalkable(normal)
	return normal and normal.z >= WALKABLE_Z
end

local function ClassifySurface(trace)
	if trace.HitWorld then return "world", true, NULL end

	local ent = trace.Entity
	if not IsValid(ent) then
		return "none", false, NULL
	end

	if ent:IsPlayer() then
		return "player", false, ent
	end

	if ent:IsRagdoll() then
		return "ragdoll", true, ent
	end

	local class = ent:GetClass()
	if string.StartWith(class, "prop_") or class == "func_physbox" then
		return "prop", true, ent
	end

	return "other", false, ent
end

function Ground.TraceSample(ply, startPos, groundDist)
	-- shoots a trace down to find ground. sometimes finds it sometimes not
	local soleOffset = RT.GetIKParam(ply, "sole_offset")
	local maxSurfaceSpeed = RT.GetIKParam(ply, "moving_surface_max_speed")
	if maxSurfaceSpeed <= 0 then maxSurfaceSpeed = DEFAULT_SURFACE_MAX_SPEED end
	local endPos = startPos - Vector(0, 0, groundDist)

	local trace = util.TraceHull({
		start = startPos, endpos = endPos,
		mins = Vector(-2, -2, 0), maxs = Vector(2, 2, 4),
		mask = MASK_PLAYERSOLID,
		filter = function(ent) return ent ~= ply and not ent:IsPlayer() end,
	})

	if trace.Hit and not IsWalkable(trace.HitNormal) then
		local fallback = util.TraceLine({
			start = startPos, endpos = endPos,
			filter = function(ent) return ent ~= ply and not ent:IsPlayer() end,
		})
		if fallback.Hit and IsWalkable(fallback.HitNormal) then
			trace = fallback
		else
			trace.Hit = false
		end
	end

	if trace.Hit then
		local normal = trace.HitNormal or vector_up
		local hitPos = trace.HitPos + normal * soleOffset
		local surfaceType, surfaceAllowed, surfaceEnt = ClassifySurface(trace)
		local surfaceSpeed = 0
		if IsValid(surfaceEnt) and surfaceEnt.GetVelocity then
			surfaceSpeed = surfaceEnt:GetVelocity():Length()
		end
		local surfaceStable = surfaceType == "world" or (surfaceAllowed and surfaceSpeed <= maxSurfaceSpeed)

		-- if trace gave us nan pretend nothing happened
		if not (isvector(hitPos) and hitPos.x == hitPos.x and hitPos.y == hitPos.y and hitPos.z == hitPos.z) then
			return {
				hit = false,
				hitPos = endPos,
				normal = vector_up,
				distance = groundDist,
				startPos = startPos,
				surfaceType = "none",
				surfaceAllowed = false,
				surfaceStable = false,
				surfaceSpeed = 0,
				hitWorld = false,
				entity = NULL,
			}
		end
		return {
			hit = true,
			hitPos = hitPos,
			normal = normal,
			distance = math.max(startPos.z - hitPos.z, 0),
			startPos = startPos,
			surfaceType = surfaceType,
			surfaceAllowed = surfaceAllowed,
			surfaceStable = surfaceStable,
			surfaceSpeed = surfaceSpeed,
			hitWorld = trace.HitWorld and true or false,
			entity = surfaceEnt,
		}
	end

	return {
		hit = false,
		hitPos = endPos,
		normal = vector_up,
		distance = groundDist,
		startPos = startPos,
		surfaceType = "none",
		surfaceAllowed = false,
		surfaceStable = false,
		surfaceSpeed = 0,
		hitWorld = false,
		entity = NULL,
	}
end

function Ground.SampleFoot(ply, footPos, footAng, traceStartZ, groundDist, isLeft)
	-- traces a bunch of points around the foot to figure out where ground is
	-- center toe heel and sides. probably overkill but whatever
	local fwd = footAng:Forward()
	fwd.z = 0
	if fwd:LengthSqr() < 0.001 then fwd = Vector(1, 0, 0) else fwd:Normalize() end

	local right = footAng:Right()
	right.z = 0
	if right:LengthSqr() < 0.001 then right = Vector(0, 1, 0) else right:Normalize() end

	local sideSign = isLeft and -1 or 1
	local outer = right * (2.5 * sideSign)
	local inner = -outer
	-- always start from player ground reference, not animated bone position.
	-- weapon holdtype animations can elevate foot bones far above actual ground level,
	-- which would push startZ up and potentially cause traces to miss the ground entirely.
	local base = Vector(footPos.x, footPos.y, traceStartZ)

	local offsets = {
		center   = Vector(),
		toe      = fwd * 5.5,
		heel     = -fwd * 3.5,
		left     = -right * 2.25,
		right    = right * 2.25,
		toeInner = fwd * 4 + inner * 0.75,
		toeOuter = fwd * 4 + outer * 0.75,
		outer    = outer,
		inner    = inner,
	}

	local samples = {}
	for name, offset in pairs(offsets) do
		samples[name] = Ground.TraceSample(ply, base + offset, groundDist)
	end
	return samples
end

function Ground.ResolveContact(samples, fallbackPos, fallbackNormal)
	-- find the highest valid hit first so we can cluster around it.
	-- this stops low-side samples (the "air" side of a curb) from dragging
	-- the contact position down into geometry or off into space.
	local highestHitZ = -math.huge
	for _, s in pairs(samples) do
		if s.hit and IsWalkable(s.normal) and s.hitPos.z > highestHitZ then
			highestHitZ = s.hitPos.z
		end
	end
	local clusterFloor = highestHitZ - CLUSTER_TOLERANCE

	local totalWeight, hitCount = 0, 0
	local posSum = Vector()
	local normalSum = Vector()
	local distSum = 0
	local surfaceWeights = {}
	local bestEntity, bestEntityWeight = NULL, 0
	local stableWeight = 0

	for name, s in pairs(samples) do
		if s.hit and IsWalkable(s.normal) and s.hitPos.z >= clusterFloor then
			local w = SAMPLE_WEIGHTS[name] or 1
			totalWeight = totalWeight + w
			posSum = posSum + s.hitPos * w
			normalSum = normalSum + s.normal * w
			distSum = distSum + s.distance * w
			hitCount = hitCount + 1
			local surfaceType = s.surfaceType or "none"
			surfaceWeights[surfaceType] = (surfaceWeights[surfaceType] or 0) + w
			if s.surfaceStable then
				stableWeight = stableWeight + w
			end
			if IsValid(s.entity) and w > bestEntityWeight then
				bestEntity = s.entity
				bestEntityWeight = w
			end
		end
	end

	local pos, normal, dist = fallbackPos, fallbackNormal or vector_up, 0

	if totalWeight > 0 then
		pos = posSum / totalWeight
		normal = normalSum / totalWeight
		if normal:LengthSqr() < 0.001 then normal = vector_up else normal:Normalize() end
		dist = distSum / totalWeight
		-- weighted average went nan somehow. fall back to defaults
		if pos.x ~= pos.x or pos.y ~= pos.y or pos.z ~= pos.z then
			pos = fallbackPos
			hitCount = 0
		end
		if normal.x ~= normal.x or normal.y ~= normal.y or normal.z ~= normal.z then
			normal = vector_up
		end
	end

	local dominantSurfaceType = "none"
	local dominantWeight = 0
	for surfaceType, weight in pairs(surfaceWeights) do
		if weight > dominantWeight then
			dominantWeight = weight
			dominantSurfaceType = surfaceType
		end
	end

	return {
		hasHit = hitCount > 0,
		hitCount = hitCount,
		position = Vector(pos),
		normal = Vector(normal),
		supportDistance = dist,
		samples = samples,
		surfaceType = dominantSurfaceType,
		surfaceStable = stableWeight >= math.max(totalWeight * 0.5, 1),
		surfaceEntity = bestEntity,
		surfaceFromWorld = dominantSurfaceType == "world",
	}
end

function Ground.GetStepSignal(contact, legLength)
	if not contact or not contact.hasHit then
		return { confidence = 0, edge = 0, toeDelta = 0, heelDelta = 0 }
	end

	local samples = contact.samples
	if not samples then
		return { confidence = 0, edge = 0, toeDelta = 0, heelDelta = 0 }
	end

	local center = samples.center
	local toe = samples.toe
	local heel = samples.heel
	if not center or not toe or not heel or not center.hit or not toe.hit or not heel.hit then
		return { confidence = 0, edge = 0, toeDelta = 0, heelDelta = 0 }
	end

	local toeDelta = toe.hitPos.z - center.hitPos.z
	local heelDelta = heel.hitPos.z - center.hitPos.z
	local gradient = math.abs(toeDelta - heelDelta)
	local edge = math.max(math.abs(toeDelta), math.abs(heelDelta), gradient)
	local minStep = math.max(legLength * 0.11, 4)
	local confidence = math.Clamp((edge - minStep * 0.35) / math.max(minStep, 0.5), 0, 1)

	if contact.surfaceType == "world" then
		confidence = confidence * 1.05
	elseif contact.surfaceType == "prop" or contact.surfaceType == "ragdoll" then
		confidence = confidence * 0.92
	else
		confidence = confidence * 0.75
	end

	if not contact.surfaceStable then
		confidence = confidence * 0.45
	end

	return {
		confidence = math.Clamp(confidence, 0, 1),
		edge = edge,
		toeDelta = toeDelta,
		heelDelta = heelDelta,
	}
end

function Ground.BuildTerrainHint(leftContact, rightContact, legLength)
	local lSignal = Ground.GetStepSignal(leftContact, legLength)
	local rSignal = Ground.GetStepSignal(rightContact, legLength)

	local surfaceCounts = {
		world = 0,
		prop = 0,
		ragdoll = 0,
		other = 0,
	}

	for _, contact in ipairs({ leftContact, rightContact }) do
		if contact and contact.hasHit then
			if contact.surfaceType == "world" then
				surfaceCounts.world = surfaceCounts.world + 1
			elseif contact.surfaceType == "prop" then
				surfaceCounts.prop = surfaceCounts.prop + 1
			elseif contact.surfaceType == "ragdoll" then
				surfaceCounts.ragdoll = surfaceCounts.ragdoll + 1
			else
				surfaceCounts.other = surfaceCounts.other + 1
			end
		end
	end

	local bestSurface = "none"
	local bestCount = -1
	for surfaceType, count in pairs(surfaceCounts) do
		if count > bestCount then
			bestSurface = surfaceType
			bestCount = count
		end
	end

	local stableCount = 0
	if leftContact and leftContact.surfaceStable then stableCount = stableCount + 1 end
	if rightContact and rightContact.surfaceStable then stableCount = stableCount + 1 end

	return {
		surfaceType = bestSurface,
		stable = stableCount > 0,
		leftSignal = lSignal,
		rightSignal = rSignal,
		edgeConfidence = math.max(lSignal.confidence, rSignal.confidence),
		edgeMagnitude = math.max(lSignal.edge, rSignal.edge),
	}
end

function Ground.ValidateContact(contact, samples, footBoneZ, soleOffset, tolerance)
	-- checks if contact makes sense or if foot is stuck in geometry
	-- this is the last line of defense against cursed terrain
	tolerance = tolerance or 0.5

	local result = {
		isValid = true,
		penetrationCount = 0,
		correctionZ = 0,
		highestValidZ = -math.huge,
		lowestHitZ = math.huge,
		invalidReason = nil,
		normalVariance = 0,
	}

	if not contact.hasHit then
		result.isValid = false
		result.invalidReason = "no_hit"
		return result
	end

	local expectedSoleZ = footBoneZ - soleOffset
	local totalHits = 0
	local belowSole = 0
	local penetrating = 0
	local normals = {}

	for _, s in pairs(samples) do
		if not s.hit then continue end
		totalHits = totalHits + 1
		normals[#normals + 1] = s.normal

		local rawHitZ = s.hitPos.z - soleOffset

		-- foot is inside the ground. this is bad
		if rawHitZ > footBoneZ + tolerance then
			penetrating = penetrating + 1
		end

		if rawHitZ < expectedSoleZ - tolerance * 2 then
			belowSole = belowSole + 1
		end

		if rawHitZ <= footBoneZ + tolerance and s.hitPos.z > result.highestValidZ then
			result.highestValidZ = s.hitPos.z
		end

		if s.hitPos.z < result.lowestHitZ then
			result.lowestHitZ = s.hitPos.z
		end
	end

	result.penetrationCount = penetrating

	-- most samples say foot is underground. time to correct
	if totalHits > 0 and penetrating / totalHits > 0.4 then
		result.isValid = false
		result.invalidReason = "penetrating"
		if result.highestValidZ > -math.huge then
			result.correctionZ = result.highestValidZ + soleOffset - footBoneZ
		else
			result.correctionZ = contact.position.z - footBoneZ
		end
	end

	if totalHits > 0 and belowSole / totalHits > 0.6 then
		result.invalidReason = result.invalidReason or "below_sole"
	end

	-- check if normals agree. if they dont the surface is sketchy
	if #normals >= 3 then
		local avgNormal = Vector()
		for _, n in ipairs(normals) do avgNormal:Add(n) end
		avgNormal:Div(#normals)
		if avgNormal:LengthSqr() > 0.001 then avgNormal:Normalize() end

		local variance = 0
		for _, n in ipairs(normals) do
			variance = variance + (1 - n:Dot(avgNormal))
		end
		result.normalVariance = variance / #normals

		if result.normalVariance > 0.35 then
			result.invalidReason = result.invalidReason or "inconsistent_normals"
		end
	end

	if contact.normal.z < WALKABLE_Z then
		result.isValid = false
		result.invalidReason = result.invalidReason or "steep_surface"
	end

	return result
end

function Ground.DrawSamples(samples, boxColor, normalColor, debugLevel)
	for name, s in pairs(samples) do
		if not s.hit then continue end
		local isCenter = name == "center"
		if debugLevel <= 1 and not isCenter then continue end
		local col = isCenter and boxColor or Color(boxColor.r, boxColor.g, boxColor.b, 110)
		render.DrawWireframeBox(s.hitPos, angle_zero, Vector(-2, -2, 0), Vector(2, 2, 4), col, true)
		render.DrawLine(s.startPos, s.hitPos, col)
		render.DrawLine(s.hitPos, s.hitPos + s.normal * 6, normalColor)
	end
end

function Ground.DebugColors(isLeft)
	return isLeft and COLOR_LEFT or COLOR_RIGHT
end

-- looks ahead in movement direction and returns where the foot should land on the next step.
-- fromPos: start of search (player hip-height at foot's lateral position)
-- moveDir: normalized XY movement direction
-- lookDist: how far ahead to check
-- upClear: how far above fromPos to start the downward trace (handles steps up and down)
function Ground.PredictLanding(ply, fromPos, moveDir, lookDist, upClear, groundDist)
	local searchX = fromPos.x + moveDir.x * lookDist
	local searchY = fromPos.y + moveDir.y * lookDist
	local searchTop = Vector(searchX, searchY, fromPos.z + upClear)
	local searchBot = Vector(searchX, searchY, fromPos.z - groundDist)

	local trace = util.TraceHull({
		start = searchTop, endpos = searchBot,
		mins = Vector(-2, -2, 0), maxs = Vector(2, 2, 4),
		mask = MASK_PLAYERSOLID,
		filter = function(ent) return ent ~= ply and not ent:IsPlayer() end,
	})

	if trace.Hit and IsWalkable(trace.HitNormal) then
		local soleOffset = RT.GetIKParam(ply, "sole_offset")
		local landPos = trace.HitPos + (trace.HitNormal or vector_up) * soleOffset
		if landPos.x == landPos.x and landPos.y == landPos.y and landPos.z == landPos.z then
			return landPos
		end
	end
	return nil
end