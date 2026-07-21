local hudConfig = FF_CONFIG.HUD or {}
local config = hudConfig.PauseMenu or {}

local CANVAS_WIDTH = math.max(math.floor(tonumber(config.CanvasWidth) or 720), 320)
local CANVAS_HEIGHT = math.max(math.floor(tonumber(config.CanvasHeight) or 576), 240)

local pauseMenu
local pauseHookSuppressedUntil = 0
local disconnectPending = false

local function closePauseMenu(soundName)
    if soundName and FF_PlayUISound then
        FF_PlayUISound(soundName)
    end

    if IsValid(pauseMenu) then
        pauseMenu:Remove()
    end

    pauseMenu = nil
end

local function getButtonRect(index)
    local width = math.max(math.floor(tonumber(config.ButtonWidth) or 240), 120)
    local height = math.max(math.floor(tonumber(config.ButtonHeight) or 34), 24)
    local gap = math.max(math.floor(tonumber(config.ButtonGap) or 12), 0)
    local x = math.floor((CANVAS_WIDTH - width) * 0.5)
    local y = math.floor(tonumber(config.ButtonY) or 286)
        + (index - 1) * (height + gap)

    return x, y, width, height
end

local function getEntries()
    return {
        {
            label = "Continue Recording",
            action = function()
                if FF_PlayUISound then
                    FF_PlayUISound("confirm_01")
                end
                closePauseMenu()
            end,
        },
        {
            label = "End Recording",
            action = function(panel)
                if disconnectPending then return end
                disconnectPending = true

                if IsValid(panel) then
                    panel.endingRecording = true
                    panel:SetMouseInputEnabled(false)
                end

                local played, duration = false, 0
                if FF_PlayUISound then
                    played, duration = FF_PlayUISound("record_stop")
                end

                local delay = played and math.max(tonumber(duration) or 0, 0) + 0.035 or 0
                timer.Simple(delay, function()
                    closePauseMenu()
                    RunConsoleCommand("disconnect")
                end)
            end,
        },
    }
end

local PANEL = {}

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:SetCursor("arrow")
    self:SetDrawOnTop(true)
    self:MakePopup()

    self.selectedIndex = 1
    self.hoveredIndex = nil
    self.lastCursorX = nil
    self.lastCursorY = nil
    self.endingRecording = false
end

function PANEL:SetSelectedEntry(index, soundName)
    index = math.Clamp(math.floor(tonumber(index) or 1), 1, 2)
    if self.selectedIndex == index then return false end

    self.selectedIndex = index
    if soundName and FF_PlayUISound then
        FF_PlayUISound(soundName)
    end

    return true
end

function PANEL:CursorToCanvas()
    local cursorX, cursorY = self:LocalCursorPos()
    local width = math.max(self:GetWide(), 1)
    local height = math.max(self:GetTall(), 1)

    return cursorX / width * CANVAS_WIDTH,
        cursorY / height * CANVAS_HEIGHT
end

function PANEL:UpdateHoveredEntry()
    local canvasX, canvasY = self:CursorToCanvas()
    local moved = self.lastCursorX == nil
        or math.abs(canvasX - self.lastCursorX) > 0.25
        or math.abs(canvasY - self.lastCursorY) > 0.25
    self.lastCursorX = canvasX
    self.lastCursorY = canvasY

    local hovered
    for index = 1, 2 do
        local x, y, width, height = getButtonRect(index)
        if canvasX >= x and canvasX <= x + width
            and canvasY >= y and canvasY <= y + height then
            hovered = index
            break
        end
    end

    local previousHovered = self.hoveredIndex
    self.hoveredIndex = hovered
    if moved and hovered then
        local changed = self:SetSelectedEntry(hovered)
        if changed and previousHovered ~= hovered and FF_PlayUISound then
            FF_PlayUISound("hover_01")
        end
    end
end

function PANEL:ActivateEntry(index)
    if self.endingRecording then return end

    local entry = getEntries()[index]
    if not entry then return end

    entry.action(self)
end

function PANEL:Think()
    if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then
        self:SetSize(ScrW(), ScrH())
        self:SetPos(0, 0)
    end

    self:UpdateHoveredEntry()
end

function PANEL:OnMousePressed(mouseCode)
    if self.endingRecording then return end
    if mouseCode ~= MOUSE_LEFT or not self.hoveredIndex then return end
    self:ActivateEntry(self.hoveredIndex)
end

function PANEL:OnMouseWheeled(delta)
    if self.endingRecording then return true end

    local index = delta > 0 and 1 or 2
    self:SetSelectedEntry(index, delta > 0 and "navigate_up" or "navigate_down")
    return true
end

function PANEL:OnKeyCodePressed(keyCode)
    if self.endingRecording then return end

    if keyCode == KEY_UP or keyCode == KEY_W then
        self:SetSelectedEntry(1, "navigate_up")
        return
    end

    if keyCode == KEY_DOWN or keyCode == KEY_S then
        self:SetSelectedEntry(2, "navigate_down")
        return
    end

    if keyCode == KEY_ENTER or keyCode == KEY_PAD_ENTER or keyCode == KEY_SPACE then
        self:ActivateEntry(self.selectedIndex)
        return
    end

    if keyCode == KEY_ESCAPE then
        pauseHookSuppressedUntil = RealTime() + 0.15
        closePauseMenu("pause_close")
    end
end

function PANEL:Paint()
    return false
end

function PANEL:OnRemove()
    if pauseMenu == self then
        pauseMenu = nil
    end
end

vgui.Register("FFVHSPauseMenu", PANEL, "EditablePanel")

local function drawPauseMenuBehindVHS()
    if not IsValid(pauseMenu) then return end

    local backgroundAlpha = math.Clamp(tonumber(config.BackgroundAlpha) or 96, 0, 255)
    surface.SetDrawColor(0, 0, 0, backgroundAlpha)
    surface.DrawRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT)

    draw.SimpleText(
        "PAUSED",
        "FF_VHSPauseTitle",
        math.floor(CANVAS_WIDTH * 0.5),
        math.floor(tonumber(config.TitleY) or 214),
        Color(255, 255, 255, 255),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )

    local entries = getEntries()
    local outlineThickness = math.max(
        math.floor(tonumber(config.OutlineThickness) or 1),
        1
    )

    for index, entry in ipairs(entries) do
        local x, y, width, height = getButtonRect(index)
        local selected = pauseMenu.selectedIndex == index

        if selected then
            surface.SetDrawColor(255, 255, 255, 225)
            surface.DrawRect(x, y, width, height)
        else
            surface.SetDrawColor(0, 0, 0, 120)
            surface.DrawRect(x, y, width, height)
            surface.SetDrawColor(255, 255, 255, 180)
            surface.DrawOutlinedRect(x, y, width, height, outlineThickness)
        end

        draw.SimpleText(
            entry.label,
            "FF_VHSPauseButton",
            x + math.floor(width * 0.5),
            y + math.floor(height * 0.5),
            selected and Color(0, 0, 0, 255) or Color(255, 255, 255, 225),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end
end

hook.Add(
    "FF_DrawBehindRealisticVHSEffect2",
    "FF_VHSCustomPauseMenuDraw",
    drawPauseMenuBehindVHS
)

local function openPauseMenu()
    if disconnectPending then return false end

    closePauseMenu()

    pauseMenu = vgui.Create("FFVHSPauseMenu")
    if not IsValid(pauseMenu) then
        pauseMenu = nil
        return false
    end

    if FF_PlayUISound then
        FF_PlayUISound("pause_open")
    end

    return true
end

local function togglePauseMenu()
    if IsValid(pauseMenu) then
        if pauseMenu.endingRecording then return false end
        closePauseMenu("pause_close")
        return false
    end

    return openPauseMenu()
end

function FF_OpenVHSPauseMenu()
    return openPauseMenu()
end

function FF_CloseVHSPauseMenu()
    closePauseMenu()
end

function FF_IsVHSPauseMenuOpen()
    return IsValid(pauseMenu)
end

hook.Add("OnPauseMenuShow", "FF_VHSCustomPauseMenu", function()
    if config.Enabled == false then return end

    local current = RealTime()
    if current <= pauseHookSuppressedUntil then
        pauseHookSuppressedUntil = 0
        return false
    end

    togglePauseMenu()
    return false
end)

hook.Add("OnGameUIVisible", "FF_VHSCustomPauseMenuNativeVisible", function()
    if IsValid(pauseMenu) and not pauseMenu.endingRecording then
        closePauseMenu()
    end
end)

hook.Add("OnReloaded", "FF_VHSCustomPauseMenuReload", function()
    disconnectPending = false
    closePauseMenu()
end)
hook.Add("ShutDown", "FF_VHSCustomPauseMenuShutdown", closePauseMenu)

concommand.Add("ff_pausemenu", function()
    if config.Enabled == false then return end
    togglePauseMenu()
end)
