-- Found Footage suppresses bundled debug-only console output.
local MsgC = FF_DiscardOutput

if CLIENT then

    local BL = BetterLights

    BL._thinks = BL._thinks or {}
    BL._thinkErrors = BL._thinkErrors or {}
    BL._tickers = BL._tickers or {}
    BL._flashPool = BL._flashPool or {}
    BL._flashPoolSize = 0
    BL._flashPoolMax = 100
    BL._suppressionRecords = BL._suppressionRecords or {}
    BL._activeFlashes = BL._activeFlashes or {}
    BL._activeFlashByKey = BL._activeFlashByKey or {}
    BL._activeFlashIds = BL._activeFlashIds or {}
    BL._activeDLightRecords = BL._activeDLightRecords or {}
    BL._flashKeyIds = BL._flashKeyIds or {}
    BL._flashIdCounter = BL._flashIdCounter or 0
    BL._idCounter = BL._idCounter or 0
    BL._nextDLightRecordPrune = BL._nextDLightRecordPrune or 0

    for key in pairs(BL._activeFlashByKey) do
        BL._activeFlashByKey[key] = nil
    end
    for id in pairs(BL._activeFlashIds) do
        BL._activeFlashIds[id] = nil
    end
    for key in pairs(BL._flashKeyIds) do
        BL._flashKeyIds[key] = nil
    end

    for _, flash in ipairs(BL._activeFlashes) do
        if flash and flash.id then
            BL._activeFlashIds[flash.id] = flash
        end

        if flash and flash.key then
            BL._activeFlashByKey[flash.key] = flash
            BL._flashKeyIds[flash.key] = flash.id
        end
    end

    local THINK_ERROR_DISABLE_COUNT = 3

    local function getDLightRecordKey(index, isElight)
        return (isElight and "e" or "d") .. tostring(index)
    end

    local function pruneDLightRecords(now)
        now = now or CurTime()

        for key, record in pairs(BL._activeDLightRecords) do
            if not record or not record.die or record.die <= now then
                BL._activeDLightRecords[key] = nil
            end
        end
    end

    local function recordDLight(index, pos, r, g, b, size, isElight, dieTime)
        if not index or not pos then return nil end

        local now = CurTime()
        if now >= BL._nextDLightRecordPrune then
            pruneDLightRecords(now)
            BL._nextDLightRecordPrune = now + 1
        end

        local key = getDLightRecordKey(index, isElight)
        local record = BL._activeDLightRecords[key]
        if not record then
            record = {}
            BL._activeDLightRecords[key] = record
        end

        record.id = index
        record.pos = pos
        record.r = r or 255
        record.g = g or 255
        record.b = b or 255
        record.size = size or 0
        record.elight = isElight == true
        record.die = dieTime or now

        return record
    end

    function BL.GetFlashTable()
        if BL._flashPoolSize > 0 then
            local flash = BL._flashPool[BL._flashPoolSize]
            BL._flashPool[BL._flashPoolSize] = nil
            BL._flashPoolSize = BL._flashPoolSize - 1
            return flash
        end
        return {}
    end

    function BL.RecycleFlashTable(flash)
        if BL._flashPoolSize < BL._flashPoolMax then
            for k in pairs(flash) do
                flash[k] = nil
            end
            BL._flashPoolSize = BL._flashPoolSize + 1
            BL._flashPool[BL._flashPoolSize] = flash
        end
    end

    function BL.ShouldSuppressFlash(key, pos, minDistSq, maxAge)
        minDistSq = minDistSq or (40 * 40)
        maxAge = maxAge or 0.15

        local record = BL._suppressionRecords[key]
        if not record then
            record = {}
            BL._suppressionRecords[key] = record
        end

        local now = CurTime()

        for i = #record, 1, -1 do
            local e = record[i]
            if now - e.t > maxAge then
                record[i] = record[#record]
                record[#record] = nil
            elseif e.pos:DistToSqr(pos) < minDistSq then
                return true
            end
        end

        return false
    end

    function BL.RecordFlashPosition(key, pos)
        local record = BL._suppressionRecords[key]
        if not record then
            record = {}
            BL._suppressionRecords[key] = record
        end
        record[#record + 1] = { pos = pos, t = CurTime() }
    end

    function BL.GetActiveDLightRecords()
        pruneDLightRecords()
        return BL._activeDLightRecords
    end

    local function getFlashId(baseId, key)
        if key then
            local id = BL._flashKeyIds[key]
            if id and not BL._activeFlashIds[id] then
                return id
            end
        end

        local id
        for _ = 1, 4096 do
            BL._flashIdCounter = (BL._flashIdCounter + 1) % 4096
            id = (baseId or 60000) + BL._flashIdCounter
            if not BL._activeFlashIds[id] then break end
        end

        if key then
            BL._flashKeyIds[key] = id
        end

        return id
    end

    function BL.CreateFlash(pos, r, g, b, size, brightness, duration, baseId, key)
        if not BL.IsEnabled() then return nil end

        local now = CurTime()
        local flash = key and BL._activeFlashByKey[key] or nil
        if flash and flash.key ~= key then
            BL._activeFlashByKey[key] = nil
            flash = nil
        end

        if not flash then
            flash = BL.GetFlashTable()
            flash.id = getFlashId(baseId, key)
            flash.key = key
            table.insert(BL._activeFlashes, flash)
            BL._activeFlashIds[flash.id] = flash

            if key then
                BL._activeFlashByKey[key] = flash
            end
        end

        flash.pos = pos
        flash.r = r
        flash.g = g
        flash.b = b
        flash.baseSize = size
        flash.baseBrightness = brightness
        flash.start = now
        flash.die = now + duration
        return flash
    end

    function BL.UpdateFlashes()
        if #BL._activeFlashes == 0 then return end

        local now = CurTime()
        for i = #BL._activeFlashes, 1, -1 do
            local f = BL._activeFlashes[i]
            if not f or now >= f.die then
                if f then
                    if f.key and BL._activeFlashByKey[f.key] == f then
                        BL._activeFlashByKey[f.key] = nil
                        BL._flashKeyIds[f.key] = nil
                    end

                    if BL._activeFlashIds[f.id] == f then
                        BL._activeFlashIds[f.id] = nil
                    end

                    BL.RecycleFlashTable(f)
                end
                BL._activeFlashes[i] = BL._activeFlashes[#BL._activeFlashes]
                BL._activeFlashes[#BL._activeFlashes] = nil
            else
                local dur = math.max(0.001, f.die - f.start)
                local t = (f.die - now) / dur
                local brightness = f.baseBrightness * t
                local size = f.baseSize * (0.4 + 0.6 * t)
                local dl = DynamicLight(f.id)

                if dl then
                    local dieTime = now + 0.05
                    dl.pos = f.pos
                    dl.r = f.r
                    dl.g = f.g
                    dl.b = f.b
                    dl.brightness = brightness
                    dl.decay = 0
                    dl.size = size
                    dl.minlight = 0
                    dl.noworld = false
                    dl.nomodel = false
                    dl.dietime = dieTime
                    recordDLight(f.id, f.pos, f.r, f.g, f.b, size, false, dieTime)
                end
            end
        end
    end

    function BL.AddThink(name, fn)
        if not isfunction(fn) then return end
        BL._thinks[name] = fn
        BL._thinkErrors[name] = nil
    end

    function BL.RemoveThink(name)
        BL._thinks[name] = nil
        BL._thinkErrors[name] = nil
    end

    function BL.ShouldTick(name, hz)
        if not hz or hz <= 0 then return true end

        local now = CurTime()
        local nextt = BL._tickers[name] or 0
        if now >= nextt then
            BL._tickers[name] = now + (1 / hz)
            return true
        end
        return false
    end

    function BL.NewLightId(base)
        BL._idCounter = (BL._idCounter + 1) % 4096
        return (base or 60000) + BL._idCounter
    end

    function BL.GetColorFromCvars(r_cvar, g_cvar, b_cvar)
        return math.Clamp(math.floor(r_cvar:GetFloat() + 0.5), 0, 255),
               math.Clamp(math.floor(g_cvar:GetFloat() + 0.5), 0, 255),
               math.Clamp(math.floor(b_cvar:GetFloat() + 0.5), 0, 255)
    end

    function BL.CreateDLight(index, pos, r, g, b, brightness, decay, size, isElight, options)
        if not BL.IsEnabled() then return nil end

        options = options or {}

        local dl = DynamicLight(index, isElight or false)
        if dl then
            local dieTime = CurTime() + (options.dietime or 0.1)
            dl.pos = pos
            dl.r = r
            dl.g = g
            dl.b = b
            dl.brightness = brightness
            dl.decay = decay
            dl.size = size
            dl.minlight = 0
            if not isElight then
                dl.noworld = options.noworld == true
                dl.nomodel = options.nomodel == true
            end
            dl.dietime = dieTime
            recordDLight(index, pos, r, g, b, size, isElight, dieTime)
        end
        return dl
    end

    function BL.LerpColor(r1, g1, b1, r2, g2, b2, t)
        t = math.Clamp(t, 0, 1)
        return math.floor(r1 + (r2 - r1) * t),
               math.floor(g1 + (g2 - g1) * t),
               math.floor(b1 + (b2 - b1) * t)
    end

    function BL.CreateFlickerEffect(baseValue, time, speed, amount, phase)
        phase = phase or 0
        local osc = 0.65 * math.sin(time * speed + phase) + 0.35 * math.sin(time * (speed * 1.7) + phase * 1.13)
        return math.max(0, baseValue * (1 + amount * osc))
    end

    hook.Add("Think", "BetterLights_CoreThink", function()
        if not BL.IsEnabled() then return end

        BL.UpdateFlashes()

        for name, fn in pairs(BL._thinks) do
            local ok, err = xpcall(fn, debug and debug.traceback or tostring)
            if ok then
                BL._thinkErrors[name] = nil
            else
                local errorCount = (BL._thinkErrors[name] or 0) + 1
                BL._thinkErrors[name] = errorCount

                MsgC(Color(255, 100, 100), "[BetterLights] Think '" .. tostring(name) .. "' error (" .. tostring(errorCount) .. "/" .. tostring(THINK_ERROR_DISABLE_COUNT) .. "): " .. tostring(err) .. "\n")

                if errorCount >= THINK_ERROR_DISABLE_COUNT then
                    BL._thinks[name] = nil
                    BL._thinkErrors[name] = nil
                    MsgC(Color(255, 100, 100), "[BetterLights] Disabled Think '" .. tostring(name) .. "' after repeated errors.\n")
                end
            end
        end
    end)
end
