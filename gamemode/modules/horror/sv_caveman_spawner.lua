local config = ((FF_CONFIG or {}).Horror or {}).Caveman or {}
if config.Enabled == false then return end

local entityClass = tostring(config.Class or "backrooms_caveman")
local modelPath = tostring(config.Model or "models/brmovie/caveman_brmovie.mdl")
local populationTimer = "FF_CavemanMapPopulation"
local retryCount = 0

util.PrecacheModel(modelPath)

local spawnClasses = {
    "info_player_start",
    "info_player_deathmatch",
    "info_player_counterterrorist",
    "info_player_terrorist",
    "info_player_combine",
    "info_player_rebel",
    "info_player_allies",
    "info_player_axis",
}

local staticGroundClasses = {
    func_brush = true,
    func_detail = true,
    func_wall = true,
    func_wall_toggle = true,
    func_breakable = true,
    func_breakable_surf = true,
    func_illusionary = true,
}

local function shuffledCopy(values)
    local result = {}
    for index, value in ipairs(values) do
        result[index] = value
    end

    for index = #result, 2, -1 do
        local swap = math.random(1, index)
        result[index], result[swap] = result[swap], result[index]
    end

    return result
end

local cachedModelMins
local cachedModelMaxs

local function modelBounds()
    if cachedModelMins and cachedModelMaxs then
        return cachedModelMins, cachedModelMaxs
    end

    local probe = ents.Create("prop_dynamic")
    if IsValid(probe) then
        probe:SetModel(modelPath)
        probe:SetNoDraw(true)

        local mins
        local maxs

        if probe.GetModelBounds then
            local ok, resultMins, resultMaxs = pcall(probe.GetModelBounds, probe)
            if ok then
                mins = resultMins
                maxs = resultMaxs
            end
        end

        if (not mins or not maxs) and probe.OBBMins and probe.OBBMaxs then
            local minsOK, resultMins = pcall(probe.OBBMins, probe)
            local maxsOK, resultMaxs = pcall(probe.OBBMaxs, probe)
            if minsOK and maxsOK then
                mins = resultMins
                maxs = resultMaxs
            end
        end

        probe:Remove()

        if mins and maxs and (maxs - mins):LengthSqr() > 1 then
            cachedModelMins = mins
            cachedModelMaxs = maxs
            return cachedModelMins, cachedModelMaxs
        end
    end

    -- Exact hull bounds from the embedded movie-accurate model header.
    cachedModelMins = Vector(-9.30, -15.09, -0.25)
    cachedModelMaxs = Vector(6.60, 11.51, 74.01)
    return cachedModelMins, cachedModelMaxs
end

local function playerSpawnPositions()
    local positions = {}

    for _, className in ipairs(spawnClasses) do
        for _, entity in ipairs(ents.FindByClass(className)) do
            positions[#positions + 1] = entity:GetPos()
        end
    end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            positions[#positions + 1] = ply:GetPos()
        end
    end

    return positions
end

local function isFarFromPlayerSpawns(position, spawnPositions)
    local minimum = math.max(tonumber(config.MinimumPlayerSpawnDistance) or 640, 0)
    local minimumSqr = minimum * minimum

    for _, spawnPosition in ipairs(spawnPositions) do
        if position:DistToSqr(spawnPosition) < minimumSqr then
            return false
        end
    end

    return true
end

local function isAllowedGround(trace)
    if trace.HitWorld then return true end

    local entity = trace.Entity
    if not IsValid(entity) then return false end
    if entity.IsWorld and entity:IsWorld() then return true end

    local className = entity:GetClass()
    if not staticGroundClasses[className] then return false end

    return entity:GetMoveType() == MOVETYPE_NONE
end

local function hasEntityClearance(position, mins, maxs, groundEntity)
    local padding = math.max(tonumber(config.ClearancePadding) or 10, 0)
    local clearanceMins = Vector(mins.x - padding, mins.y - padding, mins.z)
    local clearanceMaxs = Vector(maxs.x + padding, maxs.y + padding, maxs.z + padding)

    local hullTrace = util.TraceHull({
        start = position,
        endpos = position + Vector(0, 0, 1),
        mins = clearanceMins,
        maxs = clearanceMaxs,
        mask = MASK_SOLID,
    })

    if hullTrace.StartSolid or hullTrace.AllSolid then
        return false, "solid_hull"
    end

    local world = game.GetWorld()
    for _, entity in ipairs(ents.FindInBox(position + clearanceMins, position + clearanceMaxs)) do
        if IsValid(entity)
            and entity ~= world
            and entity ~= groundEntity
            and entity:GetClass() ~= "worldspawn"
            and entity:GetClass() ~= entityClass
            and entity:IsSolid() then
            local className = entity:GetClass()
            local staticFloorBelow = false

            if staticGroundClasses[className] and entity.WorldSpaceAABB then
                local ok, _, entityMaxs = pcall(entity.WorldSpaceAABB, entity)
                staticFloorBelow = ok
                    and entityMaxs ~= nil
                    and entityMaxs.z <= position.z + 4
            end

            if not staticFloorBelow then
                return false, "solid_entity"
            end
        end
    end

    return true
end

local function resolveFlatGround(rawPosition, mins, maxs, spawnPositions)
    local traceHeight = math.max(tonumber(config.GroundTraceHeight) or 256, 1)
    local traceDepth = math.max(tonumber(config.GroundTraceDepth) or 1024, 1)
    local trace = util.TraceLine({
        start = rawPosition + Vector(0, 0, traceHeight),
        endpos = rawPosition - Vector(0, 0, traceDepth),
        mask = MASK_SOLID_BRUSHONLY,
    })

    if not trace.Hit or trace.StartSolid or trace.AllSolid then
        return nil
    end

    if not isAllowedGround(trace) then
        return nil
    end

    if trace.HitNormal.z < math.Clamp(tonumber(config.FlatNormalMinimum) or 0.995, 0, 1) then
        return nil
    end

    local position = trace.HitPos + Vector(0, 0, -mins.z + 2)
    local center = position + Vector(0, 0, (mins.z + maxs.z) * 0.5)
    if not util.IsInWorld(center) then
        return nil
    end

    local contents = util.PointContents(center)
    if bit.band(contents, CONTENTS_WATER) ~= 0
        or bit.band(contents, CONTENTS_SLIME) ~= 0 then
        return nil
    end

    if not isFarFromPlayerSpawns(position, spawnPositions) then
        return nil
    end

    local clear = hasEntityClearance(position, mins, maxs, trace.Entity)
    if not clear then
        return nil
    end

    return position
end

local function appendCandidate(candidates, position)
    local duplicateDistanceSqr = 160 * 160
    for _, candidate in ipairs(candidates) do
        if candidate:DistToSqr(position) < duplicateDistanceSqr then
            return false
        end
    end

    candidates[#candidates + 1] = position
    return true
end

local function collectNavCandidates(candidates, mins, maxs, spawnPositions, maximumAttempts)
    if not navmesh or not navmesh.GetAllNavAreas then return 0 end

    local areas = navmesh.GetAllNavAreas() or {}
    local shuffledAreas = shuffledCopy(areas)
    local attempts = math.min(#shuffledAreas, maximumAttempts)

    for index = 1, attempts do
        local area = shuffledAreas[index]
        local rawPosition

        if area.GetRandomPoint then
            local ok, point = pcall(area.GetRandomPoint, area)
            if ok then rawPosition = point end
        end

        if not rawPosition and area.GetCenter then
            local ok, point = pcall(area.GetCenter, area)
            if ok then rawPosition = point end
        end

        if rawPosition then
            local position = resolveFlatGround(rawPosition, mins, maxs, spawnPositions)
            if position then appendCandidate(candidates, position) end
        end
    end

    return #areas
end

local function fallbackAnchors(spawnPositions)
    local anchors = {}

    for _, position in ipairs(spawnPositions) do
        anchors[#anchors + 1] = position
    end

    local anchorClasses = {
        "info_node",
        "info_node_hint",
        "info_target",
        "info_landmark",
        "path_track",
    }

    for _, className in ipairs(anchorClasses) do
        for _, entity in ipairs(ents.FindByClass(className)) do
            local position = entity:GetPos()
            if util.IsInWorld(position) then
                anchors[#anchors + 1] = position
            end
        end
    end

    if #anchors == 0 then
        anchors[1] = Vector(0, 0, 0)
    end

    return shuffledCopy(anchors)
end

local function collectFallbackCandidates(candidates, mins, maxs, spawnPositions, maximumAttempts)
    local anchors = fallbackAnchors(spawnPositions)
    local minimumRadius = math.max(tonumber(config.FallbackRadiusMinimum) or 700, 0)
    local maximumRadius = math.max(tonumber(config.FallbackRadiusMaximum) or 3200, minimumRadius)
    local goldenAngle = math.pi * (3 - math.sqrt(5))

    for attempt = 1, maximumAttempts do
        local anchor = anchors[((attempt - 1) % #anchors) + 1]
        local sweep = ((attempt - 1) % 64) / 63
        local radius = Lerp(sweep, minimumRadius, maximumRadius)
        local angle = attempt * goldenAngle
        local rawPosition = anchor + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
        local position = resolveFlatGround(rawPosition, mins, maxs, spawnPositions)

        if position then appendCandidate(candidates, position) end
    end
end

local function collectWorldBoundsCandidates(candidates, mins, maxs, spawnPositions, maximumAttempts)
    local world = game.GetWorld()
    if not IsValid(world) or not world.GetModelBounds then return end

    local ok, worldMins, worldMaxs = pcall(world.GetModelBounds, world)
    if not ok or not worldMins or not worldMaxs then return end
    if (worldMaxs - worldMins):LengthSqr() < 10000 then return end

    local spanX = worldMaxs.x - worldMins.x
    local spanY = worldMaxs.y - worldMins.y
    if spanX <= 0 or spanY <= 0 then return end

    local attempts = math.min(maximumAttempts, 512)
    for _ = 1, attempts do
        local rawPosition = Vector(
            math.Rand(worldMins.x, worldMaxs.x),
            math.Rand(worldMins.y, worldMaxs.y),
            worldMaxs.z - 16
        )
        local position = resolveFlatGround(rawPosition, mins, maxs, spawnPositions)
        if position then appendCandidate(candidates, position) end
    end
end

local function minimumDistanceSqr(position, others)
    local minimum = math.huge
    for _, other in ipairs(others) do
        minimum = math.min(minimum, position:DistToSqr(other))
    end
    return minimum
end

local function selectSpreadOutPositions(candidates, count, spawnPositions)
    local selected = {}
    local available = shuffledCopy(candidates)
    local spacing = math.max(tonumber(config.MinimumSpacing) or 1200, 0)
    local spacingFloor = math.Clamp(
        tonumber(config.MinimumSpacingFloor) or 600,
        0,
        spacing
    )

    while #selected < count and #available > 0 do
        local bestIndex
        local bestScore = -1

        for index, candidate in ipairs(available) do
            local score
            if #selected > 0 then
                score = minimumDistanceSqr(candidate, selected)
            elseif #spawnPositions > 0 then
                score = minimumDistanceSqr(candidate, spawnPositions)
            else
                score = candidate:LengthSqr()
            end

            if score > bestScore then
                bestScore = score
                bestIndex = index
            end
        end

        if not bestIndex then break end

        if #selected == 0 or bestScore >= spacing * spacing then
            selected[#selected + 1] = table.remove(available, bestIndex)
        elseif spacing > spacingFloor then
            spacing = math.max(spacing * 0.80, spacingFloor)
        else
            break
        end
    end

    return selected, spacing
end

local function removeExistingCavemen()
    for _, entity in ipairs(ents.FindByClass(entityClass)) do
        if IsValid(entity) then entity:Remove() end
    end
end

local function desiredEntityCount(navAreaCount)
    local minimum = math.max(math.floor(tonumber(config.MinimumCount) or 3), 0)
    local maximum = math.max(math.floor(tonumber(config.MaximumCount) or 8), minimum)
    local areasPerEntity = math.max(math.floor(tonumber(config.NavAreasPerEntity) or 120), 1)

    if navAreaCount <= 0 then return minimum end
    return math.Clamp(math.ceil(navAreaCount / areasPerEntity), minimum, maximum)
end

local function schedulePopulation(delay, retry)
    timer.Remove(populationTimer)
    timer.Create(populationTimer, math.max(tonumber(delay) or 0, 0), 1, function()
        local stored = scripted_ents.GetStored and scripted_ents.GetStored(entityClass)
        if not stored and FF_RegisterCavemanEntity then
            FF_RegisterCavemanEntity()
            stored = scripted_ents.GetStored and scripted_ents.GetStored(entityClass)
        end

        if not stored then
            ErrorNoHalt("[Found Footage Caveman] Entity class registration failed: " .. entityClass .. "\n")
            return
        end

        removeExistingCavemen()

        if not util.IsValidModel(modelPath) then
            ErrorNoHalt("[Found Footage Caveman] Missing model: " .. modelPath .. "\n")
            return
        end

        local mins, maxs = modelBounds()
        local spawnPositions = playerSpawnPositions()
        local maximumAttempts = math.max(math.floor(tonumber(config.CandidateAttempts) or 1280), 1)
        local candidates = {}

        local navAreaCount = collectNavCandidates(
            candidates,
            mins,
            maxs,
            spawnPositions,
            maximumAttempts
        )

        local desired = desiredEntityCount(navAreaCount)
        if #candidates < desired * 4 then
            collectFallbackCandidates(
                candidates,
                mins,
                maxs,
                spawnPositions,
                maximumAttempts
            )
        end

        if #candidates < desired * 2 then
            collectWorldBoundsCandidates(
                candidates,
                mins,
                maxs,
                spawnPositions,
                maximumAttempts
            )
        end

        local selected = selectSpreadOutPositions(
            candidates,
            desired,
            spawnPositions
        )
        local spawned = 0

        for _, position in ipairs(selected) do
            local clear = hasEntityClearance(position, mins, maxs)
            if clear then
                local entity = ents.Create(entityClass)
                if IsValid(entity) then
                    entity:SetPos(position)
                    entity:SetAngles(Angle(0, math.Rand(0, 360), 0))
                    entity.FF_AutoSpawned = true
                    entity:Spawn()
                    entity:Activate()

                    if IsValid(entity) then
                        spawned = spawned + 1
                    end
                end
            end
        end

        local maximumRetries = math.max(math.floor(tonumber(config.MaximumRetries) or 3), 0)
        if spawned == 0 and retry < maximumRetries then
            retryCount = retry + 1
            schedulePopulation(config.RetryDelay or 5, retryCount)
        else
            retryCount = 0
        end
    end)
end

concommand.Add("ff_caveman_respawn", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    retryCount = 0
    schedulePopulation(0, 0)
end)

hook.Add("InitPostEntity", "FF_CavemanPopulateMap", function()
    retryCount = 0
    schedulePopulation(config.SpawnDelay or 2, 0)
end)

hook.Add("PlayerInitialSpawn", "FF_CavemanPopulateAfterPlayerJoin", function()
    timer.Simple(3, function()
        if #ents.FindByClass(entityClass) == 0 then
            retryCount = 0
            schedulePopulation(0, 0)
        end
    end)
end)

hook.Add("PostCleanupMap", "FF_CavemanRepopulateAfterCleanup", function()
    retryCount = 0
    schedulePopulation(config.SpawnDelay or 2, 0)
end)

hook.Add("OnReloaded", "FF_CavemanRepopulateAfterReload", function()
    retryCount = 0
    schedulePopulation(config.SpawnDelay or 2, 0)
end)
