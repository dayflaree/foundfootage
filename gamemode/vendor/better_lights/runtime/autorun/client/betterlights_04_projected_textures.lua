if CLIENT then

    local BL = BetterLights

    BL._projectedTextureUpdates = BL._projectedTextureUpdates or {}
    BL._projectedTextureStores = BL._projectedTextureStores or {}
    setmetatable(BL._projectedTextureStores, { __mode = "k" })

    function BL.RegisterProjectedTextureStore(store, dataStore)
        if type(store) ~= "table" then return false end

        local registration = BL._projectedTextureStores[store]
        if not registration then
            registration = {}
            BL._projectedTextureStores[store] = registration
        end

        if dataStore then
            registration.dataStore = dataStore
        end

        return true
    end

    function BL.UnregisterProjectedTextureStore(store, shouldClear)
        if type(store) ~= "table" then return end

        local registration = BL._projectedTextureStores[store]
        if shouldClear then
            BL.ClearProjectedTextures(store, registration and registration.dataStore)
        end

        BL._projectedTextureStores[store] = nil
    end

    function BL.GetOrCreateProjectedTexture(store, key, texture)
        if not ProjectedTexture then return nil end
        if not BL.IsEnabled() then return nil end

        BL.RegisterProjectedTextureStore(store)

        local lamp = store[key]
        if lamp and lamp.IsValid and lamp:IsValid() then return lamp end

        lamp = ProjectedTexture()
        if not lamp then return nil end

        if texture then
            lamp:SetTexture(texture)
        end

        store[key] = lamp
        return lamp
    end

    function BL.UpdateProjectedTexture(lamp, options)
        if not (lamp and lamp.IsValid and lamp:IsValid()) then return false end

        if options.texture then lamp:SetTexture(options.texture) end
        lamp:SetPos(options.pos)
        lamp:SetAngles(options.ang)
        lamp:SetNearZ(options.nearZ)
        lamp:SetFarZ(options.farZ)
        lamp:SetFOV(options.fov)
        lamp:SetBrightness(options.brightness)
        lamp:SetColor(options.color)
        lamp:SetEnableShadows(options.shadows)
        if options.shadowDepthBias then lamp:SetShadowDepthBias(options.shadowDepthBias) end
        if options.shadowSlopeScaleDepthBias then lamp:SetShadowSlopeScaleDepthBias(options.shadowSlopeScaleDepthBias) end
        if options.shadowFilter then lamp:SetShadowFilter(options.shadowFilter) end
        if options.noCull ~= nil then lamp:SetNoCull(options.noCull) end
        if options.linearAttenuation then lamp:SetLinearAttenuation(options.linearAttenuation) end
        if options.constantAttenuation then lamp:SetConstantAttenuation(options.constantAttenuation) end
        if options.quadraticAttenuation then lamp:SetQuadraticAttenuation(options.quadraticAttenuation) end
        BL._projectedTextureUpdates[lamp] = true
        return true
    end

    function BL.RemoveProjectedTexture(store, key, dataStore)
        BL.RegisterProjectedTextureStore(store, dataStore)

        local lamp = store[key]

        if lamp then
            BL._projectedTextureUpdates[lamp] = nil
        end

        if lamp and lamp.IsValid and lamp:IsValid() then
            lamp:Remove()
        end

        store[key] = nil
        if dataStore then
            dataStore[key] = nil
        end
    end

    function BL.RemoveStaleProjectedTextures(store, seen, shouldRemove, dataStore)
        BL.RegisterProjectedTextureStore(store, dataStore)

        for key in pairs(store) do
            if (not seen[key]) or (shouldRemove and shouldRemove(key)) then
                BL.RemoveProjectedTexture(store, key, dataStore)
            end
        end
    end

    function BL.ClearProjectedTextures(store, dataStore)
        BL.RegisterProjectedTextureStore(store, dataStore)

        for key in pairs(store) do
            BL.RemoveProjectedTexture(store, key, dataStore)
        end
    end

    function BL.ClearAllProjectedTextures()
        for store, registration in pairs(BL._projectedTextureStores) do
            BL.ClearProjectedTextures(store, registration.dataStore)
        end

        for lamp in pairs(BL._projectedTextureUpdates) do
            BL._projectedTextureUpdates[lamp] = nil
        end
    end

    hook.Add("BetterLights_EffectiveEnabledChanged", "BetterLights_ProjectorEffectiveEnable", function(enabled)
        if not enabled then
            BL.ClearAllProjectedTextures()
        end
    end)

    hook.Add("ShutDown", "BetterLights_ProjectorStoreCleanup", function()
        BL.ClearAllProjectedTextures()
    end)

    if not BL.IsEnabled() then
        BL.ClearAllProjectedTextures()
    end

    hook.Add("PreDrawOpaqueRenderables", "BetterLights_ProjectorUpdate", function(isDrawingDepth)
        if not BL.IsMainViewRender(isDrawingDepth) then return end

        for lamp in pairs(BL._projectedTextureUpdates) do
            BL._projectedTextureUpdates[lamp] = nil

            if lamp and lamp.IsValid and lamp:IsValid() then
                lamp:Update()
            end
        end
    end)
end
