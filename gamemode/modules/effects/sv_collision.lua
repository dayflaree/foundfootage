local config = FF_CONFIG.Effects.Collision
if not config.Enabled then return end

util.AddNetworkString("FF_ImmersiveCollision")

local eventsThisSecond = 0
timer.Create("FF_ResetCollisionBudget", 1, 0, function()
    eventsThisSecond = 0
end)

local function collisionCallback(entity, data)
    if not IsValid(entity) or eventsThisSecond >= config.MaximumEventsPerSecond then return end

    local physics = entity:GetPhysicsObject()
    if not IsValid(physics) then return end

    local now = CurTime()
    if now < (entity.FF_NextCollisionEffect or 0) then return end

    local size = (entity:OBBMaxs() - entity:OBBMins()):Length()
    local speed = tonumber(data.Speed) or 0
    if physics:GetMass() < config.MinimumMass then return end
    if size < config.MinimumSize or speed < config.MinimumSpeed then return end
    if IsValid(data.HitEntity) and data.HitEntity:IsPlayer() then return end

    entity.FF_NextCollisionEffect = now + config.MinimumDelay
    eventsThisSecond = eventsThisSecond + 1

    local force = math.Clamp((speed / 320) * (size / 90), 0.55, 5)
    local materialType = entity:GetMaterialType() or 0

    util.ScreenShake(
        data.HitPos,
        force * config.ScreenShake,
        3,
        math.Clamp(force, 0.4, 4),
        math.Clamp(size * 10, 300, 2200),
        true
    )

    net.Start("FF_ImmersiveCollision")
        net.WriteEntity(entity)
        net.WriteVector(data.HitPos)
        net.WriteVector(data.HitNormal or Vector(0, 0, 1))
        net.WriteFloat(force)
        net.WriteFloat(size)
        net.WriteUInt(math.Clamp(materialType, 0, 255), 8)
    net.SendPVS(data.HitPos)
end

local function attach(entity)
    if not IsValid(entity) or entity.FF_CollisionEffectAttached then return end

    local class = entity:GetClass()
    if class ~= "prop_physics" and class ~= "prop_physics_multiplayer" and class ~= "func_physbox" then return end

    entity.FF_CollisionEffectAttached = true
    entity:AddCallback("PhysicsCollide", collisionCallback)
end

hook.Add("OnEntityCreated", "FF_AttachCollisionEffects", function(entity)
    timer.Simple(0, function()
        attach(entity)
    end)
end)

hook.Add("InitPostEntity", "FF_AttachExistingCollisionEffects", function()
    for _, entity in ipairs(ents.GetAll()) do
        attach(entity)
    end
end)
