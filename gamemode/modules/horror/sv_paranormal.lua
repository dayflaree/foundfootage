local config = FF_CONFIG.Horror.Paranormal
if not config.Enabled then return end

util.AddNetworkString("FF_ParanormalInterference")

local ambientSounds = {
    "gm_paranormal/whispers_01.wav",
    "gm_paranormal/creepy_breath.wav",
    "gm_paranormal/attention_getter_01.ogg",
    "gm_paranormal/attention_getter_02.wav",
    "gm_paranormal/attention_getter_03.ogg",
    "gm_paranormal/1shot_breathing_01.ogg",
    "gm_paranormal/1shot_breathing_02.ogg",
    "gm_paranormal/1shot_creep_01.ogg",
    "gm_paranormal/1shot_creep_02.ogg",
    "gm_paranormal/1shot_metalstress_01.ogg",
    "gm_paranormal/1shot_metalstress_02.ogg",
    "gm_paranormal/creepy_scrape2.wav",
    "gm_paranormal/creepy_scrape3.wav",
    "gm_paranormal/metallic_wail_01.ogg",
    "gm_paranormal/revcry_01.ogg",
    "gm_paranormal/sigh_03.ogg",
}

local function alivePlayers()
    local result = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            result[#result + 1] = ply
        end
    end
    return result
end

local function nearbyEntities(position, classes)
    local classSet = {}
    for _, class in ipairs(classes) do
        classSet[class] = true
    end

    local result = {}
    for _, entity in ipairs(ents.FindInSphere(position, config.Radius)) do
        if IsValid(entity) and classSet[entity:GetClass()] then
            result[#result + 1] = entity
        end
    end
    return result
end

local function ambientEvent(ply)
    local direction = VectorRand()
    direction.z = math.Rand(-0.15, 0.45)
    direction:Normalize()
    local position = ply:EyePos() + direction * math.Rand(180, 620)

    sound.Play(table.Random(ambientSounds), position, 68, math.random(92, 105), 0.72)
end

local function doorEvent(ply)
    local doors = nearbyEntities(ply:GetPos(), { "prop_door_rotating", "func_door", "func_door_rotating" })
    if #doors == 0 then return false end

    local door = table.Random(doors)
    door:Fire("Toggle", "", math.Rand(0.05, 0.65))
    door:EmitSound("doors/door_latch3.wav", 66, math.random(88, 102), 0.75)
    return true
end

local function buttonEvent(ply)
    local buttons = nearbyEntities(ply:GetPos(), { "func_button", "func_rot_button", "momentary_rot_button" })
    if #buttons == 0 then return false end

    local button = table.Random(buttons)
    button:Fire("Press", "", 0)
    return true
end

local function lightEvent(ply)
    local lights = nearbyEntities(ply:GetPos(), { "light", "light_spot", "light_dynamic" })
    if #lights == 0 then return false end

    local light = table.Random(lights)
    local flashes = math.random(2, 5)
    for index = 0, flashes - 1 do
        local delay = index * math.Rand(0.10, 0.22)
        light:Fire("TurnOff", "", delay)
        light:Fire("TurnOn", "", delay + math.Rand(0.035, 0.11))
    end
    return true
end

local function breakLightEvent(ply)
    local lights = nearbyEntities(ply:GetPos(), { "env_sprite", "env_glow", "light_dynamic" })
    if #lights == 0 then return false end

    local light = table.Random(lights)
    light:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 72, math.random(92, 106), 0.8)
    local effect = EffectData()
    effect:SetOrigin(light:WorldSpaceCenter())
    effect:SetMagnitude(1)
    effect:SetScale(0.5)
    util.Effect("Sparks", effect, true, true)
    light:Fire("HideSprite", "", 0)
    return true
end

local function propEvent(ply)
    local candidates = {}
    for _, entity in ipairs(ents.FindInSphere(ply:GetPos(), math.min(config.Radius, 900))) do
        if IsValid(entity) and entity:GetClass() == "prop_physics" then
            local physics = entity:GetPhysicsObject()
            if IsValid(physics) and physics:IsMotionEnabled() and physics:GetMass() <= 160 then
                candidates[#candidates + 1] = entity
            end
        end
    end
    if #candidates == 0 then return false end

    local entity = table.Random(candidates)
    local physics = entity:GetPhysicsObject()
    local away = (entity:GetPos() - ply:GetPos()):GetNormalized()
    physics:Wake()
    physics:ApplyForceCenter((away + Vector(0, 0, math.Rand(0.2, 0.7))) * physics:GetMass() * math.Rand(90, 180))
    physics:AddAngleVelocity(VectorRand() * math.Rand(30, 100))
    return true
end

local function ceilingBloodEvent(ply)
    local trace = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + Vector(0, 0, 900),
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })
    if not trace.Hit or trace.HitSky then return false end

    util.Decal("Blood", trace.HitPos - trace.HitNormal * 2, trace.HitPos + trace.HitNormal * 8)
    sound.Play("gm_paranormal/bsplat_0" .. math.random(6, 8) .. ".ogg", trace.HitPos, 63, math.random(90, 104), 0.58)
    return true
end

local function flashlightEvent(ply)
    net.Start("FF_ParanormalInterference")
        net.WriteFloat(math.Rand(0.35, 1.1))
    net.Send(ply)
    return true
end

local eventBuilders = {
    { enabled = function() return config.AmbientSounds end, run = ambientEvent },
    { enabled = function() return config.DoorManipulation end, run = doorEvent },
    { enabled = function() return config.ButtonManipulation end, run = buttonEvent },
    { enabled = function() return config.FlickeringLights end, run = lightEvent },
    { enabled = function() return config.BreakingLights end, run = breakLightEvent },
    { enabled = function() return config.PropFlinging end, run = propEvent },
    { enabled = function() return config.CeilingBlood end, run = ceilingBloodEvent },
    { enabled = function() return config.FlashlightInterference end, run = flashlightEvent },
}

local function scheduleNextEvent()
    timer.Create("FF_ParanormalEvent", math.Rand(config.MinimumEventDelay, config.MaximumEventDelay), 1, function()
        local players = alivePlayers()
        if #players > 0 then
            local available = {}
            for _, event in ipairs(eventBuilders) do
                if event.enabled() then
                    available[#available + 1] = event
                end
            end

            if #available > 0 then
                local ply = table.Random(players)
                for _ = 1, math.min(#available, 4) do
                    local index = math.random(1, #available)
                    local event = table.remove(available, index)
                    local result = event.run(ply)
                    if result ~= false then
                        hook.Run("FF_ParanormalEventOccurred", ply)
                        break
                    end
                end
            end
        end

        scheduleNextEvent()
    end)
end

hook.Add("InitPostEntity", "FF_StartParanormalEvents", scheduleNextEvent)
hook.Add("PostCleanupMap", "FF_RestartParanormalEvents", scheduleNextEvent)
