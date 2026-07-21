if CLIENT then

    local BL = BetterLights
    local DEFAULT_SURFACE_SMOOTHING = 28
    local DEFAULT_SURFACE_SNAP_DISTANCE = 160

    BL._heldSurfaceLightStates = BL._heldSurfaceLightStates or {}

    local function isLocalFirstPerson(ply)
        return IsValid(ply) and ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer()
    end

    local function getSurfaceStateKey(ply, wep, key)
        return tostring(key) .. ":" .. ply:EntIndex() .. ":" .. (IsValid(wep) and wep:EntIndex() or 0)
    end

    local function smoothSurfaceLightPos(ply, wep, key, targetPos, options)
        local smoothing = options.smoothing
        if smoothing == nil then smoothing = DEFAULT_SURFACE_SMOOTHING end
        if smoothing <= 0 then return targetPos end

        local stateKey = getSurfaceStateKey(ply, wep, key)
        local state = BL._heldSurfaceLightStates[stateKey]
        if not state then
            state = {}
            BL._heldSurfaceLightStates[stateKey] = state
        end

        local snapDistance = options.snapDistance or DEFAULT_SURFACE_SNAP_DISTANCE
        if not state.pos or state.pos:DistToSqr(targetPos) > snapDistance * snapDistance then
            state.pos = targetPos
        else
            local t = math.Clamp(FrameTime() * smoothing, 0, 1)
            state.pos = state.pos + (targetPos - state.pos) * t
        end

        return state.pos
    end

    local function getPlacementNames(placements, useViewModel)
        if not placements then return nil end
        if placements.view or placements.world then
            return useViewModel and placements.view or placements.world
        end

        return placements
    end

    function BL.GetHeldWeaponAttachmentTransform(ply, wep, placements, options)
        local useViewModel = isLocalFirstPerson(ply)
        local attachNames = getPlacementNames(placements, useViewModel)
        if not attachNames then return nil end

        if useViewModel then
            local vm = ply:GetViewModel()
            if not IsValid(vm) then return nil end

            return BL.GetAttachmentTransform(vm, attachNames, options)
        end

        if not IsValid(wep) then return nil end
        return BL.GetAttachmentTransform(wep, attachNames, options)
    end

    function BL.GetHeldWeaponAttachmentPos(ply, wep, placements, options)
        local attachment = BL.GetHeldWeaponAttachmentTransform(ply, wep, placements, options)
        return (attachment and attachment.Pos) or nil
    end

    function BL.CreateHeldWeaponAttachmentLight(ply, wep, placements, index, r, g, b, brightness, decay, size, isElight, options)
        local pos = BL.GetHeldWeaponAttachmentPos(ply, wep, placements, options)
        if not pos then return false end

        BL.CreateDLight(index, pos, r, g, b, brightness, decay, size, isElight, options)
        return true, pos
    end

    function BL.GetHeldWeaponSurfaceLightPos(ply, wep, options)
        if not IsValid(ply) then return nil end

        options = options or {}
        local distance = options.distance or 48
        local missDistance = options.missDistance or 24
        local hitOffset = options.hitOffset or 6
        local eye = ply:EyePos()
        local fwd = ply.GetAimVector and ply:GetAimVector() or ply:EyeAngles():Forward()
        local key = options.key or "held_weapon_surface"
        local filter = IsValid(wep) and { ply, wep } or ply
        local tr = BL.TraceLineReuse(key, {
            start = eye,
            endpos = eye + fwd * distance,
            filter = filter
        })

        local targetPos
        if tr.Hit and tr.HitPos then
            targetPos = tr.HitPos + (tr.HitNormal or vector_origin) * hitOffset
        else
            targetPos = eye + fwd * missDistance
        end

        return smoothSurfaceLightPos(ply, wep, key, targetPos, options)
    end

    function BL.CreateHeldWeaponSurfaceLight(ply, wep, surfaceOptions, index, r, g, b, brightness, decay, size, isElight, lightOptions)
        local pos = BL.GetHeldWeaponSurfaceLightPos(ply, wep, surfaceOptions)
        if not pos then return false end

        BL.CreateDLight(index, pos, r, g, b, brightness, decay, size, isElight, lightOptions or surfaceOptions)
        return true, pos
    end
end
