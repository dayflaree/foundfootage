local enabled = CreateClientConVar("threateffects_death_enabled", "1", true, false, "Enable Threat Effects Death", 0, 1)
local timings = CreateClientConVar("threateffects_death_capturetime", "30", true, false, "Time (in seconds) between screenshot captures", 1, 120)

local include_shots = CreateClientConVar("threateffects_death_includeshots", "1", true, false, "Include pictures from screenshots folder", 0, 1)
local include_sess = CreateClientConVar("threateffects_death_includesess", "1", true, false, "Include pictures captured from current session", 0, 1)

local intensity_shake = CreateClientConVar("threateffects_death_intensity_shake", "1", true, false, "Screenshot shaking intensity", 0, 2)
local intensity_flash = CreateClientConVar("threateffects_death_intensity_flash", "1", true, false, "Flashes intensity", 0, 1)

local volume_scream = CreateClientConVar("threateffects_death_volume_scream", "0.75", true, false, "\"Screamer\" volume", 0, 1)
local volume_background = CreateClientConVar("threateffects_death_volume_background", "0.75", true, false, "Background volume", 0, 1)


local customs = CreateClientConVar("threateffects_death_custom", "", true, false, "Custom images")

local dead, firstdead = nil, true
local screenshots, session, nextcapture = {}, {}, timings:GetFloat()

local _rt_1 = GetRenderTarget("ThreatEffects_DeathEffects_Capture1", ScrW(), ScrH())
local _rt_2 = GetRenderTarget("ThreatEffects_DeathEffects_Capture2", ScrW(), ScrH())
local _rt_3 = GetRenderTarget("ThreatEffects_DeathEffects_Capture3", ScrW(), ScrH())
local _rt_4 = GetRenderTarget("ThreatEffects_DeathEffects_Capture4", ScrW(), ScrH())

session[1] = CreateMaterial("ThreatEffects_DeathEffects_Capture1", "UnlitGeneric", {["$basetexture"] = _rt_1:GetName()})
session[2] = CreateMaterial("ThreatEffects_DeathEffects_Capture2", "UnlitGeneric", {["$basetexture"] = _rt_2:GetName()})
session[3] = CreateMaterial("ThreatEffects_DeathEffects_Capture3", "UnlitGeneric", {["$basetexture"] = _rt_3:GetName()})
session[4] = CreateMaterial("ThreatEffects_DeathEffects_Capture4", "UnlitGeneric", {["$basetexture"] = _rt_4:GetName()})

local noise = {}
-- honestly, garry, why the fuck would Material return time??
noise[1] = Material("gui/threateffects/static/noise_1.png")
noise[2] = Material("gui/threateffects/static/noise_2.png")
noise[3] = Material("gui/threateffects/static/noise_3.png")

local static = {}
static[1] = Material("gui/threateffects/static/static_1.png")
static[2] = Material("gui/threateffects/static/static_2.png")
static[3] = Material("gui/threateffects/static/static_3.png")
static[4] = Material("gui/threateffects/static/static_4.png")

local color_mod = {
    ["$pp_colour_inv"] = 0,
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}
local color_material = Material("color")
-- thankyou https://steamcommunity.com/sharedfiles/filedetails/?id=864612139
hook.Add("HUDShouldDraw", "RemoveThatShit", function(name)
    if not enabled:GetBool() then return end
    if name == "CHudDamageIndicator" then return false end
end)

hook.Add("PostRender", "ThreatEffects_DeathEffects", function()
    if not include_sess:GetBool() then return end
    if not enabled:GetBool() then return end
    if not LocalPlayer():Alive() then return end
    if nextcapture - CurTime() >= 0 then return end
    nextcapture = CurTime() + timings:GetFloat()
    render.PushRenderTarget(_rt_3) render.CopyRenderTargetToTexture(_rt_4) render.PopRenderTarget()
    render.PushRenderTarget(_rt_2) render.CopyRenderTargetToTexture(_rt_3) render.PopRenderTarget()
    render.PushRenderTarget(_rt_1) render.CopyRenderTargetToTexture(_rt_2) render.PopRenderTarget()
    render.CopyRenderTargetToTexture(_rt_1)
end)

local drawn, lastchange, lastchange2, static_draw, noise_draw = color_material, -1, -1, static[1], noise[1]
hook.Add("PostDrawHUD", "ThreatEffects_DeathEffects", function()
    if CurTime() < 3 then return end
    if not enabled:GetBool() then return end
    local ply = LocalPlayer()
    if ply:Alive() then firstdead = nil dead = nil return end
    if firstdead then return end -- we are "dead" before completely loaded in
    if not dead then
        dead = RealTime()
        if include_sess:GetBool() then
            screenshots = session
        else
            screenshots = {}
        end
        if include_shots:GetBool() then
            for _,file in pairs(file.Find("screenshots/*", "GAME", "datedesc")) do
                screenshots[#screenshots+1] = Material("screenshots/"..file)
                if _ > 10 then break end -- failsafe if we have too many screenshots
            end
        end
        for _,file in pairs(file.Find("materials/gui/threateffects/death/*", "GAME")) do
            screenshots[#screenshots+1] = Material("gui/threateffects/death/"..file)
        end
        for _,file in pairs(string.Split(customs:GetString(), ";")) do
            screenshots[#screenshots+1] = Material(file)
        end
        sound.PlayFile("sound/gui/threateffects/death/slideshow.wav", "noplay", function(station, errCode, errStr)
            if not IsValid(station) then return print("Failed to create IGModAudioChannel! "..errCode..": "..errStr) end
            station:Play()
            station:SetVolume(volume_background:GetFloat())
        end)
        sound.PlayFile("sound/gui/threateffects/death/hit_"..math.random(1, 4)..".wav", "noplay", function(station, errCode, errStr)
            if not IsValid(station) then return print("Failed to create IGModAudioChannel! "..errCode..": "..errStr) end
            station:Play()
            station:SetVolume(volume_scream:GetFloat())
        end)
    end
    local wasdeadfor = RealTime() - dead
    local intensity = math.sin(RealTime()*20)/2+0.5
    local strength = math.min(1, wasdeadfor/4)
    if wasdeadfor >= 4.5 then
        intensity = 1
    end
    cam.Start2D() cam.IgnoreZ(true)

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(static_draw)
    surface.DrawRect(0, 0, ScrW(), ScrH())

    local screenshot = drawn
    if math.floor(RealTime()*20) ~= lastchange2 then
        lastchange2 = math.floor(RealTime()*20)
        static_draw = static[math.random(1, #static)]
        noise_draw = static[math.random(1, #noise)]
    end
    if math.floor(RealTime()*3) ~= lastchange then
        lastchange = math.floor(RealTime()*3)
        local attempts = 0
        while screenshot == drawn and attempts < 5 do
            if include_sess:GetBool() and math.random(1, 100) > 50 then
                screenshot = screenshots[math.random(1, 4)]
            else
                screenshot = screenshots[math.random(1, #screenshots)]
            end
            attempts = attempts + 1
        end
        drawn = screenshot
    end
    if wasdeadfor < 4.5 then
        surface.SetMaterial(screenshot)
        surface.SetDrawColor(255, 255, 255, 255)
        local maxmove = 100*strength
        local mx, my = math.random(-maxmove/2, maxmove/2)*strength*intensity_shake:GetFloat(),
                       math.random(-maxmove/2, maxmove/2)*strength*intensity_shake:GetFloat()
        maxmove = maxmove + 40*intensity
        local off = math.sin(RealTime()*20)*20*intensity
        surface.DrawTexturedRect(-maxmove/2+mx-off, -maxmove/2+my-off, ScrW()+maxmove+off*2, ScrH()+maxmove+off*2)
        color_mod["$pp_colour_brightness"] = -intensity*0.75*strength*intensity_flash:GetFloat()
        DrawColorModify(color_mod)
        surface.SetDrawColor(255, 255, 255, 127)
        surface.SetMaterial(static_draw)
        surface.DrawTexturedRect(math.random(-40, 0)*intensity,
                                 math.random(-40, 0)*intensity,
                                 ScrW()+40*intensity,
                                 ScrH()+40*intensity)
        surface.SetMaterial(noise_draw)
        surface.DrawTexturedRect(math.random(-40, 0)*intensity,
                                 math.random(-40, 0)*intensity,
                                 ScrW()+40*intensity,
                                 ScrH()+40*intensity)
    end
    if wasdeadfor < 1 then
        surface.SetDrawColor(0, 0, 0, 255-255*math.min(1, wasdeadfor))
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end
    if wasdeadfor > 4 then
        surface.SetDrawColor(0, 0, 0, 255*math.min(1, (wasdeadfor-4)*2))
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end
    if wasdeadfor > 6 then
        draw.DrawText("You died", "DermaLarge", ScrW()/2, ScrH()/2, Color(255, 255, 255, math.min(255, (wasdeadfor-6)*255)), TEXT_ALIGN_CENTER)
    end
    if wasdeadfor > 8 then
        draw.DrawText("Press [JUMP], [ATTACK1] or [ATTACK2] to respawn", "DermaDefault", ScrW()/2, ScrH()/2+36, Color(255, 255, 255, math.min(255, (wasdeadfor-8)*255)), TEXT_ALIGN_CENTER)
    end
    --surface.SetMaterial(color_material)
    --for _=1,math.min(1, wasdeadfor/8)*50,1 do
    --    local c = math.random(15, 255)
    --    surface.SetDrawColor(c, c, c, 255)
    --    surface.DrawTexturedRect(math.random(0, ScrW()), math.random(0, ScrH()), 2, 2)
    --end
    cam.IgnoreZ(false) cam.End2D()
end)