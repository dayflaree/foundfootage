if CLIENT then
    local BL = BetterLights
    local MF = BL.MuzzleFlash

    local BLACKLIST_PATH = "betterlights/muzzle_flash_blacklist.json"
    local SCHEMA_VERSION = 1
    local MAX_CLASS_LENGTH = 128
    local MAX_CLASSES = 512

    MF.BlacklistedWeaponClasses = MF.BlacklistedWeaponClasses or {}

    local function normalizeClassName(value)
        if IsValid(value) and value.GetClass then
            value = value:GetClass()
        end

        value = string.lower(string.Trim(tostring(value or "")))
        if value == "" or #value > MAX_CLASS_LENGTH then return nil end
        if string.find(value, "%s") then return nil end

        for i = 1, #value do
            local byte = string.byte(value, i)
            if byte < 33 or byte > 126 then return nil end
        end

        return value
    end

    local function getSortedClasses()
        local classes = {}
        for className in pairs(MF.BlacklistedWeaponClasses) do
            classes[#classes + 1] = className
        end

        table.sort(classes)
        return classes
    end

    local function buildClassMap(classes)
        if type(classes) ~= "table" then return nil, "invalid_classes" end

        local classMap = {}
        local count = 0

        for i = 1, #classes do
            local className = normalizeClassName(classes[i])
            if not className then return nil, "invalid_class" end

            if not classMap[className] then
                count = count + 1
                if count > MAX_CLASSES then return nil, "too_many_classes" end
                classMap[className] = true
            end
        end

        return classMap
    end

    local function emitChanged()
        hook.Run("BetterLights_MuzzleBlacklistChanged", getSortedClasses())
    end

    function MF.NormalizeWeaponClass(value)
        return normalizeClassName(value)
    end

    function MF.GetBlacklistedWeaponClasses()
        return getSortedClasses()
    end

    function MF.IsWeaponClassBlacklisted(value)
        local className = normalizeClassName(value)
        return className ~= nil and MF.BlacklistedWeaponClasses[className] == true
    end

    function MF.SaveWeaponBlacklist()
        local encoded = util.TableToJSON({
            schemaVersion = SCHEMA_VERSION,
            classes = getSortedClasses()
        }, true)
        if not encoded then return false, "encode_failed" end

        file.CreateDir("betterlights")
        if not file.Write(BLACKLIST_PATH, encoded) then return false, "write_failed" end

        return true
    end

    function MF.LoadWeaponBlacklist()
        local source = file.Read(BLACKLIST_PATH, "DATA")
        if not source or source == "" then
            MF.BlacklistedWeaponClasses = {}
            emitChanged()
            return true
        end

        local decoded = util.JSONToTable(source)
        if type(decoded) ~= "table" then return false, "invalid_json" end
        if decoded.schemaVersion ~= SCHEMA_VERSION then return false, "unsupported_schema" end

        local classMap, err = buildClassMap(decoded.classes)
        if not classMap then return false, err end

        MF.BlacklistedWeaponClasses = classMap
        emitChanged()
        return true
    end

    function MF.AddWeaponClassToBlacklist(value)
        local className = normalizeClassName(value)
        if not className then return false, "invalid_class" end
        if MF.BlacklistedWeaponClasses[className] then return false, "already_exists", className end
        if #getSortedClasses() >= MAX_CLASSES then return false, "too_many_classes" end

        MF.BlacklistedWeaponClasses[className] = true
        local saved, err = MF.SaveWeaponBlacklist()
        if not saved then
            MF.BlacklistedWeaponClasses[className] = nil
            return false, err
        end

        emitChanged()
        return true, nil, className
    end

    function MF.RemoveWeaponClassFromBlacklist(value)
        local className = normalizeClassName(value)
        if not className then return false, "invalid_class" end
        if not MF.BlacklistedWeaponClasses[className] then return false, "not_found", className end

        MF.BlacklistedWeaponClasses[className] = nil
        local saved, err = MF.SaveWeaponBlacklist()
        if not saved then
            MF.BlacklistedWeaponClasses[className] = true
            return false, err
        end

        emitChanged()
        return true, nil, className
    end

    function MF.ClearWeaponBlacklist()
        if next(MF.BlacklistedWeaponClasses) == nil then return true end

        local previous = MF.BlacklistedWeaponClasses
        MF.BlacklistedWeaponClasses = {}

        local saved, err = MF.SaveWeaponBlacklist()
        if not saved then
            MF.BlacklistedWeaponClasses = previous
            return false, err
        end

        emitChanged()
        return true
    end

    local function notify(key, kind, ...)
        local MENU = BL.Menu
        local text = select("#", ...) > 0 and MENU.PhraseFormat(key, ...) or MENU.Phrase(key)
        notification.AddLegacy(text, kind or NOTIFY_GENERIC, 4)
        if FF_PlayUISound then
            FF_PlayUISound(kind == NOTIFY_ERROR and "error" or "confirm_02")
        end
    end

    local function notifyFailure(reason, className)
        if reason == "already_exists" then
            notify("notice.muzzle_blacklist_exists", NOTIFY_ERROR, className)
        elseif reason == "too_many_classes" then
            notify("notice.muzzle_blacklist_full", NOTIFY_ERROR)
        elseif reason == "write_failed" or reason == "encode_failed" then
            notify("notice.muzzle_blacklist_save_failed", NOTIFY_ERROR)
        else
            notify("notice.muzzle_blacklist_invalid", NOTIFY_ERROR)
        end
    end

    function MF.BuildWeaponBlacklistEditor(panel)
        local MENU = BL.Menu
        local list = vgui.Create("DListView")
        list:SetTall(150)
        list:SetMultiSelect(false)
        list:AddColumn(MENU.Phrase("label.weapon_class"))
        panel:AddItem(list)

        local entry = vgui.Create("DTextEntry")
        entry:SetTall(24)
        entry:SetPlaceholderText(MENU.Phrase("placeholder.weapon_class_blacklist"))
        panel:AddItem(entry)

        local removeSelected
        local clearBlacklist

        local function refreshList()
            list:Clear()

            local classes = MF.GetBlacklistedWeaponClasses()
            for i = 1, #classes do
                list:AddLine(classes[i])
            end

            if IsValid(removeSelected) then removeSelected:SetEnabled(false) end
            if IsValid(clearBlacklist) then clearBlacklist:SetEnabled(#classes > 0) end
        end

        local function addClass(className)
            local added, reason, normalized = MF.AddWeaponClassToBlacklist(className)
            if not added then
                notifyFailure(reason, normalized)
                return false
            end

            entry:SetText("")
            refreshList()
            notify("notice.muzzle_blacklist_added", NOTIFY_GENERIC, normalized)
            return true
        end

        local addTyped = MENU.AddStyledButton(panel, MENU.Phrase("button.add_weapon_class"))
        addTyped.DoClick = function()
            addClass(entry:GetText())
        end

        entry.OnEnter = function()
            addClass(entry:GetText())
        end

        local addHeld = MENU.AddStyledButton(panel, MENU.Phrase("button.blacklist_held_weapon"))
        addHeld.DoClick = function()
            local ply = LocalPlayer()
            local weapon = IsValid(ply) and ply:Alive() and ply:GetActiveWeapon() or nil
            if not (IsValid(weapon) and weapon.IsWeapon and weapon:IsWeapon()) then
                notify("notice.muzzle_blacklist_no_weapon", NOTIFY_ERROR)
                return
            end

            addClass(weapon:GetClass())
        end

        removeSelected = MENU.AddStyledButton(panel, MENU.Phrase("button.remove_selected"))
        removeSelected:SetEnabled(false)
        removeSelected.DoClick = function()
            local line = list:GetSelectedLine()
            local row = line and list:GetLine(line) or nil
            if not row then return end

            local className = row:GetColumnText(1)
            local removed, reason, normalized = MF.RemoveWeaponClassFromBlacklist(className)
            if not removed then
                notifyFailure(reason, normalized)
                return
            end

            refreshList()
            notify("notice.muzzle_blacklist_removed", NOTIFY_GENERIC, normalized)
        end

        list.OnRowSelected = function(_, _, row)
            entry:SetText(row:GetColumnText(1))
            removeSelected:SetEnabled(true)
        end

        clearBlacklist = MENU.AddStyledButton(panel, MENU.Phrase("button.clear_muzzle_blacklist"))
        clearBlacklist.DoClick = function()
            Derma_Query(
                MENU.Phrase("dialog.clear_muzzle_blacklist.message"),
                MENU.Phrase("dialog.clear_muzzle_blacklist.title"),
                MENU.Phrase("button.clear_muzzle_blacklist"),
                function()
                    local cleared, reason = MF.ClearWeaponBlacklist()
                    if not cleared then
                        notifyFailure(reason)
                        return
                    end

                    refreshList()
                    notify("notice.muzzle_blacklist_cleared", NOTIFY_GENERIC)
                end,
                MENU.Phrase("button.cancel")
            )
        end

        refreshList()
    end

    local loaded, loadError = MF.LoadWeaponBlacklist()
    if not loaded then
        ErrorNoHalt("[BetterLights] Could not load the muzzle flash blacklist: " .. tostring(loadError) .. "\n")
    end
end
