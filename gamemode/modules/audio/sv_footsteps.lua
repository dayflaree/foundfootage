-- Integrated footstep system:
--   DSteps: Dynamic Footsteps, Workshop 2782265858
--   Dynamic Footstep Reverb, Workshop 3438360859
--
-- DSteps supplies movement/material selection. Dynamic Footstep Reverb adds a
-- separate indoor echo layer. Both are centrally configured and quieter than
-- their Workshop defaults.

local config = FF_CONFIG.Audio.Footsteps
if not config.Enabled then return end

util.AddNetworkString("FF_FootstepDust")

-- Prevent duplicate output when either original addon is also mounted, and
-- remove hooks from earlier Found Footage builds during a hot reload.
local retiredHooks = {
    { "FinishMove", "FF_MaterialFootsteps" },
    { "PlayerFootstep", "FF_IntegratedDynamicFootsteps" },
    { "PlayerFootstep", "FF_SuppressSourceFootsteps" },
    { "PlayerSpawn", "FF_ResetFootstepState" },
    { "PlayerDeath", "FF_ClearFootstepState" },
    { "PlayerDisconnected", "FF_ForgetFootstepState" },
    { "PlayerFootstep", "zzzzzz_dstep_main" },
    { "EntityEmitSound", "zzzzz_dsteps_maskfootstep" },
    { "OnPlayerHitGround", "dstep_fall" },
    { "PlayerTick", "dstep_fidget" },
    { "OnEntityCreated", "FootstepReverbs_sv" },
    { "EntityRemoved", "FootstepReverbs_sv" },
    { "Think", "FootstepReverbs_sv" },
    { "EntityEmitSound", "FootstepReverbs_sv" },
    { "PlayerFootstep", "FootstepReverbs_sv" },
}

for _, entry in ipairs(retiredHooks) do
    hook.Remove(entry[1], entry[2])
end

local function numbered(folder, stem, count)
    local sounds = {}
    for index = 1, count do
        sounds[index] = "dsteps/" .. folder .. "/" .. stem .. index .. ".ogg"
    end
    return sounds
end

local pools = {
    grass = {
        walk = numbered("grass", "grass_walk", 10),
        run = numbered("grass", "grass_run", 4),
        wander = numbered("grass", "grass_wander", 6),
    },
    concrete = {
        walk = numbered("stone", "stone_walk", 11),
        run = numbered("concrete", "concrete_run", 11),
        wander = numbered("concrete", "concrete_wander", 5),
        pitch = 75,
    },
    marble = {
        walk = numbered("marble", "marble_walk", 11),
        run = numbered("marble", "marble_run", 11),
        wander = numbered("marble", "marble_wander", 7),
        pitch = 85,
    },
    dirt = {
        walk = numbered("grass", "grass_walk", 10),
        run = numbered("grass", "grass_run", 4),
        wander = numbered("grass", "grass_wander", 6),
    },
    sand = {
        walk = numbered("sand", "sand_walk", 11),
        run = numbered("sand", "sand_run", 11),
        wander = numbered("dirt", "dirt_wander", 5),
    },
    snow = {
        walk = numbered("snow", "snow_walk", 11),
        run = numbered("snow", "snow_run", 11),
        wander = numbered("snow", "snow_wander", 5),
    },
    metalbar = {
        walk = numbered("metalbar", "metalbar_walk", 11),
        run = numbered("metalbar", "metalbar_run", 11),
        wander = numbered("metalbar", "metalbar_wander", 6),
    },
    metalbox = {
        walk = numbered("metalbox", "metalbox_walk", 9),
        run = numbered("metalbox", "metalbox_run", 10),
        wander = numbered("metalbox", "metalbox_wander", 4),
    },
    glass = {
        walk = {
            "dsteps/glass/glass_hard1.ogg",
            "dsteps/glass/glass_hit1.ogg",
            "dsteps/glass/glass_hit2.ogg",
        },
        run = {
            "dsteps/glass/glass_hard1.ogg",
            "dsteps/glass/glass_hit1.ogg",
            "dsteps/glass/glass_hit2.ogg",
        },
        wander = {
            "dsteps/glass/glass_hit1.ogg",
            "dsteps/glass/glass_hit2.ogg",
        },
    },
    mud = {
        walk = numbered("mud", "mud_walk", 6),
        run = numbered("mud", "mud_walk", 6),
        wander = numbered("mud", "mud_wander", 4),
    },
    gravel = {
        walk = numbered("gravel", "gravel_walk", 11),
        run = numbered("gravel", "gravel_run", 11),
        wander = numbered("gravel", "gravel_wander", 3),
    },
    wood = {
        walk = numbered("wood", "wood_walk", 11),
        run = numbered("wood", "wood_walk", 11),
        wander = {
            "dsteps/squeakywood/squeakywood_wander1.ogg",
            "dsteps/squeakywood/squeakywood_wander2.ogg",
            "dsteps/squeakywood/squeakywood_wander6.ogg",
            "dsteps/squeakywood/squeakywood_wander7.ogg",
        },
    },
    squeakywood = {
        walk = numbered("squeakywood", "squeakywood_walk", 11),
        run = numbered("squeakywood", "squeakywood_walk", 11),
        wander = numbered("squeakywood", "squeakywood_wander", 7),
    },
    water = {
        walk = numbered("water", "water_through", 11),
        run = numbered("water", "water_through", 11),
        wander = numbered("water", "water_wander", 5),
    },
}

local materialCategories = {}
local function mapMaterial(materialType, category)
    if materialType ~= nil then
        materialCategories[materialType] = category
    end
end

mapMaterial(MAT_GRASS, "grass")
mapMaterial(MAT_CONCRETE, "concrete")
mapMaterial(MAT_TILE, "marble")
mapMaterial(MAT_DIRT, "dirt")
mapMaterial(MAT_SAND, "sand")
mapMaterial(MAT_SNOW, "snow")
mapMaterial(MAT_METAL, "metalbar")
mapMaterial(MAT_GRATE, "metalbox")
mapMaterial(MAT_WOOD, "wood")
mapMaterial(MAT_GLASS, "glass")
mapMaterial(MAT_SLOSH, "mud")
mapMaterial(MAT_PLASTIC, "concrete")
mapMaterial(MAT_COMPUTER, "metalbox")
mapMaterial(MAT_VENT, "metalbox")
mapMaterial(MAT_FOLIAGE, "grass")

local surfaceRules = {
    { "woodpanel", "squeakywood" },
    { "wood_panel", "squeakywood" },
    { "squeak", "squeakywood" },
    { "gravel", "gravel" },
    { "pebble", "gravel" },
    { "metalgrate", "metalbox" },
    { "grate", "metalbox" },
    { "duct", "metalbox" },
    { "vent", "metalbox" },
    { "tile", "marble" },
    { "marble", "marble" },
    { "grass", "grass" },
    { "foliage", "grass" },
    { "mud", "mud" },
    { "slosh", "mud" },
    { "sand", "sand" },
    { "snow", "snow" },
    { "wood", "wood" },
    { "glass", "glass" },
    { "metal", "metalbar" },
    { "dirt", "dirt" },
    { "soil", "dirt" },
    { "stone", "concrete" },
    { "concrete", "concrete" },
    { "brick", "concrete" },
}

local function traceFoot(ply, foot)
    local footOffset = (foot - 0.5) * 15
    local startPosition = ply:LocalToWorld(Vector(0, footOffset, 50))

    local function traceAt(position)
        return util.TraceLine({
            start = position,
            endpos = position + Vector(0, 0, -60),
            filter = ply,
            mask = MASK_PLAYERSOLID,
        })
    end

    local trace = traceAt(startPosition)
    if trace.Hit then return trace end

    trace = traceAt(ply:LocalToWorld(Vector(0, -footOffset, 50)))
    if trace.Hit then return trace end

    return traceAt(ply:GetPos() + Vector(0, 0, 40))
end

local function classifySurface(ply, trace, originalSound)
    if ply:WaterLevel() > 0 then
        return "water"
    end

    local soundName = string.lower(originalSound or "")
    if trace.MatType == MAT_CONCRETE and string.find(soundName, "gravel", 1, true) then
        return "gravel"
    end
    if trace.MatType == MAT_WOOD and string.find(soundName, "woodpanel", 1, true) then
        return "squeakywood"
    end
    if trace.MatType == MAT_DIRT and string.find(soundName, "mud", 1, true) then
        return "mud"
    end

    local surfaceName = ""
    if trace.SurfaceProps and trace.SurfaceProps >= 0 then
        surfaceName = string.lower(util.GetSurfacePropName(trace.SurfaceProps) or "")
    end

    for _, rule in ipairs(surfaceRules) do
        if string.find(surfaceName, rule[1], 1, true) then
            return rule[2]
        end
    end

    return materialCategories[trace.MatType] or "dirt"
end

local function numberedReverb(stem, count)
    local sounds = {}
    for index = 1, count do
        sounds[index] = "ft_reverb/" .. stem .. "0" .. index .. ".ogg"
    end
    return sounds
end

local reverbPools = {
    concrete = numberedReverb("reverb-", 9),
    dirt = numberedReverb("reverbdirt-", 6),
    grass = numberedReverb("reverbgrass-", 8),
    metal = numberedReverb("reverbmetal-", 10),
    tile = numberedReverb("reverbtile-", 8),
    wood = numberedReverb("reverbwood-", 10),
}

local reverbCategory = {
    concrete = "concrete",
    marble = "tile",
    dirt = "dirt",
    sand = "dirt",
    snow = "dirt",
    gravel = "dirt",
    mud = "dirt",
    grass = "grass",
    metalbar = "metal",
    metalbox = "metal",
    wood = "wood",
    squeakywood = "wood",
    glass = "tile",
}

local enclosureDirections = {
    Vector(-1, 0, 0), Vector(1, 0, 0),
    Vector(0, 1, 0), Vector(0, -1, 0),
    Vector(0, 0, 1), Vector(0, 0, -1),
    Vector(-1, 1, 0), Vector(-1, -1, 0),
    Vector(-1, 0, 1), Vector(-1, 0, -1),
    Vector(1, 1, 0), Vector(1, -1, 0),
    Vector(1, 0, 1), Vector(1, 0, -1),
    Vector(0, 1, 1), Vector(0, 1, -1),
    Vector(0, -1, 1), Vector(0, -1, -1),
    Vector(-1, 1, 1), Vector(-1, 1, -1),
    Vector(-1, -1, 1), Vector(-1, -1, -1),
    Vector(1, 1, 1), Vector(1, 1, -1),
    Vector(1, -1, 1), Vector(1, -1, -1),
}

local enclosureCache = setmetatable({}, { __mode = "k" })
local function isEnclosed(entity)
    local reverb = config.Reverb
    local currentTime = CurTime()
    local cached = enclosureCache[entity]
    if cached and cached.expires > currentTime then
        return cached.enclosed
    end

    local origin = entity:GetPos() + Vector(0, 0, 50)
    local hitCount = 0

    for _, direction in ipairs(enclosureDirections) do
        local trace = util.TraceLine({
            start = origin,
            endpos = origin + direction * reverb.RayLength,
            filter = entity,
            mask = MASK_VISIBLE_AND_NPCS,
        })

        if trace.Hit and not trace.HitSky then
            hitCount = hitCount + 1
        end
    end

    local enclosed = hitCount >= reverb.MinimumEnclosureHits
    enclosureCache[entity] = {
        enclosed = enclosed,
        expires = currentTime + reverb.CacheSeconds,
    }

    return enclosed
end

local function modeVolume(mode, crouching)
    if mode == "wander" then return config.WanderVolume end
    if mode == "land" then return config.LandingVolume end
    if crouching then return config.CrouchVolume end
    if mode == "run" then return config.SprintVolume end
    if mode == "slow" then return config.SlowWalkVolume end
    return config.WalkVolume
end

local function reverbVolume(mode, crouching, npc)
    local reverb = config.Reverb
    if npc then return reverb.NPCVolume end
    if mode == "wander" then return reverb.WanderVolume end
    if mode == "land" then return reverb.LandingVolume end
    if crouching then return reverb.CrouchVolume end
    if mode == "run" then return reverb.SprintVolume end
    if mode == "slow" then return reverb.SlowWalkVolume end
    return reverb.WalkVolume
end

local function playIndoorReverb(entity, category, mode, crouching, npc)
    local reverb = config.Reverb
    if not reverb.Enabled or not isEnclosed(entity) then return end

    local pool = reverbPools[reverbCategory[category]]
    if not pool or #pool == 0 then return end

    sound.Play(
        pool[math.random(1, #pool)],
        entity:GetPos(),
        reverb.SoundLevel,
        math.random(reverb.PitchMinimum, reverb.PitchMaximum),
        reverbVolume(mode, crouching, npc)
    )
end

local function sendStepDust(trace, speed)
    local dust = FF_CONFIG.Effects.StepDust
    if not dust.Enabled or not trace.Hit then return end

    net.Start("FF_FootstepDust")
        net.WriteVector(trace.HitPos)
        net.WriteVector(trace.HitNormal)
        net.WriteFloat(speed)
        net.WriteUInt(trace.MatType or 0, 8)
    net.SendPVS(trace.HitPos)
end

local function playFootstep(ply, position, foot, originalSound, mode, volume)
    local trace = traceFoot(ply, foot)
    local category = classifySurface(ply, trace, originalSound)
    local categoryPools = pools[category] or pools.dirt
    local poolKey = mode == "land" and "run" or mode
    local pool = categoryPools[poolKey] or categoryPools.walk
    if not pool or #pool == 0 then return end

    local basePitch = categoryPools.pitch or 100
    if mode == "land" then
        basePitch = basePitch + 25
    end
    local pitchVariation = config.PitchVariation or 0
    local pitch = basePitch + math.random(-pitchVariation, pitchVariation)

    sound.Play(
        pool[math.random(1, #pool)],
        position or trace.HitPos or ply:GetPos(),
        config.SoundLevel,
        pitch,
        volume
    )

    sendStepDust(trace, ply:GetVelocity():Length2D())
    playIndoorReverb(ply, category, mode, ply:Crouching(), false)
end

local landingSuppressUntil = setmetatable({}, { __mode = "k" })
local cadenceStates = setmetatable({}, { __mode = "k" })

local function copyVector(vector)
    return Vector(vector.x, vector.y, vector.z)
end

local function resetCadenceState(ply, origin)
    local state = cadenceStates[ply]
    if not state then
        state = {
            distance = 0,
            foot = 0,
            lastOrigin = nil,
        }
        cadenceStates[ply] = state
    end

    state.distance = 0
    state.lastOrigin = origin and copyVector(origin) or nil
    return state
end

local function movementMode(ply, move, speed)
    if ply:Crouching() then
        return "slow", config.CrouchStepDistance, true
    end

    if move:KeyDown(IN_SPEED)
        and speed > FF_CONFIG.Movement.WalkSpeed * 1.2 then
        return "run", config.SprintStepDistance, false
    end

    if move:KeyDown(IN_WALK)
        or speed <= FF_CONFIG.Movement.SlowWalkSpeed * 1.15 then
        return "slow", config.SlowWalkStepDistance, false
    end

    return "walk", config.WalkStepDistance, false
end

-- Source does not emit PlayerFootstep consistently at very low speed. Keep
-- this hook solely for suppressing the stock sound; cadence is generated from
-- actual horizontal distance in FinishMove below.
hook.Add("PlayerFootstep", "FF_SuppressSourceForIntegratedSteps", function(_, _, _, originalSound)
    local lowerSound = string.lower(originalSound or "")
    if string.find(lowerSound, "ladder", 1, true)
        or string.find(lowerSound, "chainlink", 1, true) then
        return
    end

    return true
end)

hook.Add("FinishMove", "FF_DStepsDistanceCadence", function(ply, move)
    if not IsValid(ply) then return end

    local origin = move:GetOrigin()
    local state = cadenceStates[ply] or resetCadenceState(ply, origin)

    if not ply:Alive()
        or not ply:IsOnGround()
        or ply:GetMoveType() == MOVETYPE_LADDER
        or (landingSuppressUntil[ply] or 0) > CurTime() then
        resetCadenceState(ply, origin)
        return
    end

    local velocity = move:GetVelocity()
    local speed = velocity:Length2D()
    local hasMovementInput = math.abs(move:GetForwardSpeed()) > 0.5
        or math.abs(move:GetSideSpeed()) > 0.5

    if speed < config.MinimumMovementSpeed or not hasMovementInput then
        resetCadenceState(ply, origin)
        return
    end

    if not state.lastOrigin then
        state.lastOrigin = copyVector(origin)
        return
    end

    local delta = origin - state.lastOrigin
    state.lastOrigin = copyVector(origin)
    delta.z = 0

    local traveled = delta:Length()
    if traveled > 128 then
        state.distance = 0
        return
    end

    local mode, stepDistance, crouching = movementMode(ply, move, speed)
    state.distance = state.distance + traveled

    while state.distance >= stepDistance do
        state.distance = state.distance - stepDistance
        state.foot = 1 - state.foot

        playFootstep(
            ply,
            nil,
            state.foot,
            "",
            mode,
            modeVolume(mode, crouching)
        )
    end
end)

hook.Add("OnPlayerHitGround", "FF_DStepsLanding", function(ply, inWater, onFloater, speed)
    if not IsValid(ply) or not ply:Alive() then return end
    if inWater or onFloater or speed <= config.MinimumLandingSpeed then return end

    landingSuppressUntil[ply] = CurTime() + 0.18
    local delay = math.Clamp(speed - 70, 20, 70) / 1000

    for foot = 0, 1 do
        timer.Simple(foot * delay, function()
            if not IsValid(ply) or not ply:Alive() then return end
            playFootstep(
                ply,
                ply:GetPos(),
                foot,
                "",
                "land",
                config.LandingVolume
            )
        end)
    end
end)

local movementState = setmetatable({}, { __mode = "k" })
hook.Add("PlayerTick", "FF_DStepsStoppingFidget", function(ply, move)
    if not IsValid(ply) or not ply:Alive() then return end

    local state = movementState[ply] or { moving = false }
    movementState[ply] = state

    local stealthy = move:KeyDown(IN_WALK) or ply:Crouching()
    local moving = move:GetForwardSpeed() ~= 0 or move:GetSideSpeed() ~= 0

    if not moving then
        if state.moving and not stealthy and ply:IsOnGround() then
            playFootstep(
                ply,
                ply:GetPos(),
                0,
                "",
                "wander",
                config.WanderVolume
            )
        end
        state.moving = false
    elseif not stealthy then
        state.moving = true
    else
        state.moving = false
    end
end)

local npcReverbCooldown = setmetatable({}, { __mode = "k" })
hook.Add("EntityEmitSound", "FF_DynamicFootstepNPCReverb", function(data)
    local reverb = config.Reverb
    if not reverb.Enabled or not reverb.NPCs then return end

    local entity = data.Entity
    if not IsValid(entity) or not entity:IsNPC() then return end

    local soundName = string.lower(data.SoundName or "")
    if not string.find(soundName, "step", 1, true)
        and not string.find(soundName, "foot", 1, true) then
        return
    end

    local currentTime = CurTime()
    if (npcReverbCooldown[entity] or 0) > currentTime then return end
    npcReverbCooldown[entity] = currentTime + 0.12

    if entity.GetHullType and entity:GetHullType() ~= 0 then return end

    local trace = util.TraceLine({
        start = entity:GetPos() + Vector(0, 0, 10),
        endpos = entity:GetPos() - Vector(0, 0, 50),
        filter = entity,
        mask = MASK_PLAYERSOLID,
    })
    if not trace.Hit then return end

    local category = materialCategories[trace.MatType] or "concrete"
    playIndoorReverb(entity, category, "walk", false, true)
end)

hook.Add("PlayerDeath", "FF_ClearIntegratedFootstepState", function(ply)
    movementState[ply] = nil
    cadenceStates[ply] = nil
    landingSuppressUntil[ply] = nil
    enclosureCache[ply] = nil
end)

hook.Add("PlayerSpawn", "FF_ResetIntegratedFootstepCadence", function(ply)
    cadenceStates[ply] = nil
    landingSuppressUntil[ply] = nil
end)

hook.Add("PlayerDisconnected", "FF_ForgetIntegratedFootstepState", function(ply)
    movementState[ply] = nil
    cadenceStates[ply] = nil
    landingSuppressUntil[ply] = nil
    enclosureCache[ply] = nil
end)
