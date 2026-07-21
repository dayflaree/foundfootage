local config = FF_CONFIG.Shadows
if not config.Enabled then return end

local refreshPending = false

local function requestRefresh()
    refreshPending = true
end

hook.Add("InitPostEntity", "FF_QueueInitialShadowRefresh", requestRefresh)

hook.Add("OnEntityCreated", "FF_QueueEntityShadowRefresh", function(entity)
    if not IsValid(entity) then return end

    local class = entity:GetClass()
    if class == "prop_door_rotating" or entity:IsPlayer() or entity:IsNPC() then
        refreshPending = true
    end
end)

net.Receive("FF_ShadowRefresh", requestRefresh)

hook.Add("PostRender", "FF_RefreshSourceShadows", function()
    if not refreshPending then return end
    refreshPending = false

    for _, entity in ipairs(ents.GetAll()) do
        if IsValid(entity) then
            entity:MarkShadowAsDirty()

            if entity:IsPlayer() or entity:IsNPC() or entity:IsNextBot() then
                entity:DestroyShadow()
                entity:CreateShadow()
            elseif entity:GetClass() == "prop_door_rotating" then
                entity:DrawShadow(config.DoorShadows)

                if config.DoorShadows then
                    entity:CreateShadow()
                else
                    entity:DestroyShadow()
                end
            end
        end
    end
end)
