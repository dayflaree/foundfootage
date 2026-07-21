local config = FF_CONFIG.Effects.StepDust
if not config.Enabled then return end

local dustyMaterials = {}

local function addDustyMaterial(materialType, color)
    if materialType ~= nil then
        dustyMaterials[materialType] = color
    end
end

addDustyMaterial(MAT_CONCRETE, Color(145, 140, 130))
addDustyMaterial(MAT_DIRT, Color(118, 102, 78))
addDustyMaterial(MAT_SAND, Color(176, 160, 116))
addDustyMaterial(MAT_SNOW, Color(220, 225, 228))
addDustyMaterial(MAT_TILE, Color(160, 156, 150))

net.Receive("FF_FootstepDust", function()
    local position = net.ReadVector()
    local normal = net.ReadVector()
    local speed = net.ReadFloat()
    local materialType = net.ReadUInt(8)

    if speed < config.MinimumSpeed then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or ply:EyePos():DistToSqr(position) > config.MaximumDistance ^ 2 then return end

    local color = dustyMaterials[materialType]
    if not color then return end

    local emitter = ParticleEmitter(position, false)
    if not emitter then return end

    local speedScale = math.Clamp(speed / math.max(FF_CONFIG.Movement.RunSpeed, 1), 0.2, 1)
    local count = math.max(1, math.floor(config.ParticleCount * (0.65 + speedScale)))

    for _ = 1, count do
        local particle = emitter:Add("particle/particle_noisesphere", position + normal * 1.5)
        if particle then
            particle:SetDieTime(config.ParticleLifetime * math.Rand(0.65, 1.15))
            particle:SetStartAlpha(math.floor(70 + speedScale * 65))
            particle:SetEndAlpha(0)
            particle:SetStartSize(math.Rand(1.5, 3.5))
            particle:SetEndSize(math.Rand(7, 14) * (0.6 + speedScale))
            particle:SetColor(color.r, color.g, color.b)
            particle:SetVelocity(normal * math.Rand(6, 18) + VectorRand() * math.Rand(3, 11))
            particle:SetAirResistance(45)
            particle:SetGravity(Vector(0, 0, -18))
            particle:SetCollide(false)
            particle:SetLighting(true)
        end
    end

    emitter:Finish()
end)
