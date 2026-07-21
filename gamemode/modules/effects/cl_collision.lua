local config = FF_CONFIG.Effects.Collision
if not config.Enabled then return end

local sizeNames = { "small", "medium", "large", "huge" }

local function spawnImpactParticles(position, normal, force, materialType)
    if not config.Particles then return end

    local emitter = ParticleEmitter(position)
    if not emitter then return end

    local wood = materialType == MAT_WOOD
    local count = math.Clamp(math.floor(5 * force * config.ParticleScale), 3, 24)
    local color = wood and Color(135, 115, 82) or Color(115, 112, 106)

    for _ = 1, count do
        local material = wood and ("effects/fleck_wood" .. math.random(1, 2)) or "particle/smokesprites_0001"
        local particle = emitter:Add(material, position + normal * 2)
        if particle then
            particle:SetDieTime(math.Rand(0.35, 1.1) * math.Clamp(force, 0.7, 2.5))
            particle:SetStartAlpha(wood and 220 or 50)
            particle:SetEndAlpha(0)
            particle:SetStartSize(wood and 1 or math.Rand(3, 8))
            particle:SetEndSize(wood and 1 or math.Rand(16, 38) * config.ParticleScale)
            particle:SetColor(color.r, color.g, color.b)
            particle:SetVelocity(normal * math.Rand(25, 90) + VectorRand() * math.Rand(20, 120) * force)
            particle:SetGravity(Vector(0, 0, -420))
            particle:SetAirResistance(wood and 18 or 80)
            particle:SetCollide(true)
            particle:SetBounce(0.25)
            particle:SetLighting(true)
        end
    end

    emitter:Finish()
end

net.Receive("FF_ImmersiveCollision", function()
    local entity = net.ReadEntity()
    local position = net.ReadVector()
    local normal = net.ReadVector()
    local force = net.ReadFloat()
    local size = net.ReadFloat()
    local materialType = net.ReadUInt(8)

    spawnImpactParticles(position, normal, force, materialType)

    if force >= 1.6 then
        if FF_PushRecordingFault then
            FF_PushRecordingFault("TRACKING", 0.8, 0.62, 64)
        end

        if FF_PushCamcorderSignal then
            FF_PushCamcorderSignal(math.Clamp(force * 0.18, 0.22, 0.48), 0.75, "impact")
        end
    end

    local sizeIndex = math.Clamp(math.floor((size + 100) / 100), 1, 4)
    local forceIndex = math.Clamp(math.floor(force + 0.5), 1, 5)
    local wood = materialType == MAT_WOOD
    local root = wood and "violentimpacts/wood/" or "violentimpacts/"
    local category = sizeNames[wood and math.min(sizeIndex, 3) or sizeIndex]
    local soundPath = root .. category .. forceIndex .. ".wav"

    if IsValid(entity) then
        entity:EmitSound(
            soundPath,
            78 + sizeIndex * 5,
            math.random(88, 108) - sizeIndex * 2,
            config.Volume,
            CHAN_AUTO
        )
    else
        sound.Play(soundPath, position, 78 + sizeIndex * 5, 100, config.Volume)
    end
end)
