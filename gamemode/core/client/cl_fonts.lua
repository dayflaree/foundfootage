local FONT_FAMILY = "VCR OSD Mono"

FF_VHS_FONT_FAMILY = FONT_FAMILY

local function createVHSFont(name, size, weight)
    surface.CreateFont(name, {
        font = FONT_FAMILY,
        extended = true,
        size = size,
        weight = weight,
        antialias = false,
        shadow = false,
    })
end

local FONT_ALIASES = {
    -- Core Derma aliases used by labels, buttons, text entries, lists,
    -- forms, menus, dialogs, tooltips, number controls, and skin helpers.
    DermaDefault = { 14, 500 },
    DermaDefaultBold = { 14, 800 },
    DermaMedium = { 24, 500 },
    DermaLarge = { 32, 500 },

    -- Source/Garry's Mod fallback aliases still used by some VGUI panels.
    Default = { 16, 500 },
    default = { 16, 500 },
    DefaultSmall = { 11, 500 },
    DefaultVerySmall = { 10, 500 },
    DefaultFixed = { 12, 500 },
    DefaultFixedDropShadow = { 12, 500 },
    DefaultSmallDropShadow = { 11, 500 },
    Trebuchet18 = { 18, 500 },
    Trebuchet19 = { 19, 500 },
    Trebuchet20 = { 20, 500 },
    Trebuchet22 = { 22, 500 },
    Trebuchet24 = { 24, 500 },

    -- Base-gamemode and engine-owned text that can surface inside this
    -- gamemode through notifications, chat, scoreboards, and world tips.
    ChatFont = { 18, 500 },
    ChatFontSmall = { 14, 500 },
    TargetID = { 22, 500 },
    TargetIDSmall = { 16, 500 },
    HudHintTextLarge = { 14, 500 },
    HudHintTextSmall = { 11, 500 },
    HudSelectionText = { 11, 500 },
    GModNotify = { 17, 500 },
    GModVoiceNotify = { 21, 500 },
    GModWorldtip = { 20, 700 },
    ScoreboardDefault = { 22, 800 },
    ScoreboardDefaultTitle = { 32, 800 },
    ContentHeader = { 50, 800 },
    GModToolName = { 80, 800 },
    GModToolSubtitle = { 24, 800 },
    GModToolHelp = { 17, 800 },
    GModToolScreen = { 60, 800 },
    SuperDofText = { 20, 700 },
    WorkshopLarge = { 19, 800 },

    -- Found Footage-owned HUD and menu aliases.
    FF_VHSCamcorderHUD = { 13, 500 },
    FF_VHSPauseTitle = { 34, 500 },
    FF_VHSPauseButton = { 17, 500 },
}

local function registerVHSFonts()
    for name, definition in pairs(FONT_ALIASES) do
        createVHSFont(name, definition[1], definition[2])
    end
end

FF_RegisterVHSFonts = registerVHSFonts

-- Register immediately, then repeat after the client Lua environment has
-- finished loading so later stock/addon font declarations cannot win.
registerVHSFonts()
hook.Add("Initialize", "FF_RegisterVHSFontsInitialize", registerVHSFonts)
hook.Add("InitPostEntity", "FF_RegisterVHSFontsInitPostEntity", registerVHSFonts)
hook.Add("OnReloaded", "FF_RegisterVHSFontsReload", registerVHSFonts)
