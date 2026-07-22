local UI_SOUNDS = {
    hover_01 = { path = "vhs_ui/hover_01.wav", duration = 0.105011 },
    hover_02 = { path = "vhs_ui/hover_02.wav", duration = 0.132381 },
    navigate_up = { path = "vhs_ui/navigate_up.wav", duration = 0.108753 },
    navigate_down = { path = "vhs_ui/navigate_down.wav", duration = 0.092857 },
    navigate_left = { path = "vhs_ui/navigate_left.wav", duration = 0.080907 },
    navigate_right = { path = "vhs_ui/navigate_right.wav", duration = 0.080930 },
    select_01 = { path = "vhs_ui/select_01.wav", duration = 0.149070 },
    select_02 = { path = "vhs_ui/select_02.wav", duration = 0.130952 },
    confirm_01 = { path = "vhs_ui/confirm_01.wav", duration = 0.305374 },
    confirm_02 = { path = "vhs_ui/confirm_02.wav", duration = 0.402971 },
    cancel_01 = { path = "vhs_ui/cancel_01.wav", duration = 0.432517 },
    cancel_02 = { path = "vhs_ui/cancel_02.wav", duration = 0.505896 },
    menu_open = { path = "vhs_ui/menu_open.wav", duration = 0.362290 },
    menu_close = { path = "vhs_ui/menu_close.wav", duration = 0.376077 },
    pause_open = { path = "vhs_ui/pause_open.wav", duration = 0.415873 },
    pause_close = { path = "vhs_ui/pause_close.wav", duration = 0.498707 },
    record_start = { path = "vhs_ui/record_start.wav", duration = 0.425782 },
    record_stop = { path = "vhs_ui/record_stop.wav", duration = 0.299365 },
    tape_insert = { path = "vhs_ui/tape_insert.wav", duration = 0.450408 },
    tape_eject = { path = "vhs_ui/tape_eject.wav", duration = 0.540045 },
    warning = { path = "vhs_ui/warning.wav", duration = 0.553696 },
    error = { path = "vhs_ui/error.wav", duration = 0.435850 },
    battery_low = { path = "vhs_ui/battery_low.wav", duration = 0.403084 },
    signal_lost = { path = "vhs_ui/signal_lost.wav", duration = 0.539433 },
}

FF_UI_SOUNDS = UI_SOUNDS

function FF_GetUISound(name)
    local entry = UI_SOUNDS[tostring(name or "")]
    if not entry then return nil end

    return entry.path, entry.duration
end

local function normalizedSoundPath(path)
    path = string.lower(string.Trim(tostring(path or "")))
    if string.sub(path, 1, 6) == "sound/" then
        path = string.sub(path, 7)
    end
    return path
end

function FF_IsDermaSoundPath(path)
    local normalized = normalizedSoundPath(path)
    return string.sub(normalized, 1, 7) == "vhs_ui/"
        or string.sub(normalized, 1, 3) == "ui/"
        or string.sub(normalized, 1, 13) == "garrysmod/ui_"
end

function FF_PlayUISound(name, volume, soundLevel)
    local path, duration = FF_GetUISound(name)
    if not path or not FF_PlayPlayerSound then
        return false, 0, path
    end

    local played, actualDuration = FF_PlayPlayerSound(
        path,
        volume or 1,
        soundLevel or 75,
        100,
        CHAN_AUTO,
        0,
        1
    )

    return played, duration or actualDuration or 0, path
end

-- Stock Derma controls call surface.PlaySound directly. Route only recognized
-- UI paths through the same local-player entity path so the forced VHS DSP is
-- applied. Other surface sounds retain the engine's original behavior.
FF_OriginalSurfacePlaySound = FF_OriginalSurfacePlaySound or surface.PlaySound
surface.PlaySound = function(soundName)
    if FF_IsDermaSoundPath(soundName) and FF_PlayPlayerSound then
        local played = FF_PlayPlayerSound(soundName, 1, 75, 100, CHAN_AUTO, 0, 1)
        if played then return end
    end

    return FF_OriginalSurfacePlaySound(soundName)
end
