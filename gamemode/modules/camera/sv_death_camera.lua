local config = FF_CONFIG.Camera.DeathCamera
if not config.Enabled then return end

local function cleanup(ply)
    if not ply then return end

    if IsValid(ply) then
        ply:SetViewEntity(ply)
    end

    if IsValid(ply.FF_DeathCamera) then
        ply.FF_DeathCamera:Remove()
    end
    ply.FF_DeathCamera = nil
end

hook.Add("PlayerDeath", "FF_DropCameraOnDeath", function(ply)
    cleanup(ply)

    local camera = ents.Create("prop_physics")
    if not IsValid(camera) then return end

    camera:SetModel(config.Model)
    camera:SetPos(ply:EyePos() - Vector(0, 0, 8))
    camera:SetAngles(ply:EyeAngles())
    camera:Spawn()
    camera:Activate()
    camera:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
    camera.FF_DeathCameraOwner = ply
    ply.FF_DeathCamera = camera

    local physics = camera:GetPhysicsObject()
    if IsValid(physics) then
        physics:Wake()
        physics:SetVelocity(ply:GetVelocity() + VectorRand() * 55 + Vector(0, 0, 80))
        physics:AddAngleVelocity(VectorRand() * 170)
    end

    timer.Simple(0.05, function()
        if IsValid(ply) and IsValid(camera) and not ply:Alive() then
            ply:SetViewEntity(camera)
        end
    end)
end)

hook.Add("PlayerSpawn", "FF_CleanupDeathCameraOnSpawn", function(ply)
    if config.CleanupOnRespawn then
        cleanup(ply)
    end
end)

hook.Add("PlayerDisconnected", "FF_CleanupDeathCameraOnLeave", cleanup)
hook.Add("PostCleanupMap", "FF_CleanupDeathCamerasAfterMapCleanup", function()
    for _, ply in ipairs(player.GetAll()) do
        cleanup(ply)
    end
end)
