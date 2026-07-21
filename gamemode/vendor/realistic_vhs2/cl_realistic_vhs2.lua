if not CLIENT then return end
-- Please note: this effect simulates the PAL 720x576 25f-fps system. For NTSC you will need to replace the following values: 720->640; 576->480; 25->30; 288->240

-- terms used in this file:
--  INTERLACED: Display of frames, when the signal generator produces two half-frames which the TV draws through the lines, adding them on top of each other.
--   Example:
--    Progressive   Interlaced
--       1  2          1  2
--       3  4          5  6
--       5  6          3  4
--       7  8          7  8
--  OSD: ON-SCREEN-DISPLAY. Its a signal generator that creates its own signal and synchronizes it with the input signal, overlapping the input signal with its own.
--  FRAME-SYNC(VERTICAL SYNC): Frame synchronization. From this the TV starts drawing the frame. This is vertical sync.
--  HORIZONTAL SYNCHRONIZATION: This is the beginning of each line in the frame. If this synchronization is delayed, the line will be shifted.
--  CHROMA: Colour Channel
--  LUMA: Brightness Channel

-- If you dont understand something - you should contact more knowledgeable people.

local REALISTICVHSEFFECT2_CFG_LOADING = false -- Default value: true. When editing switch the value to 'false' if you want to change the values in this file. this also disables automatic config saving.
-- Also, please do not enable resource-intensive filters by default and
-- filters that vary greatly over time(such as wrinkle or noise overlay) or set them to the lowest settings, like a wave filter.

local cachedcurtime = CurTime()
local rt = render.GetScreenEffectTexture(0)
local blurmat = CreateMaterial("realisticvhseffect2/blurxmat","g_blurx",{["$basetexture"]=rt:GetName()})--,["$vertexalpha"] = "1",["$translucent"] = "1"})--Material("pp/blurx")
local finalcopymat = CreateMaterial("realisticvhseffect2/finalcopymat", "UnLitGeneric", {
    ["$basetexture"] = rt:GetName(),
    ["$ignorez"] = "1",
    ["$vertexcolor"] = "1",
    ["$vertexalpha"] = "1",
})
local morphrt = GetRenderTarget("realisticvhseffect2/morphrt",720,576)
local morphmat = CreateMaterial("realisticvhseffect2/morphmat","g_refract",{["$fbtexture"] = rt:GetName(),["$normalmap"] = morphrt:GetName(),["$refractamount"] = 1,["$bluramout"] = 0})
local morphrt2 = GetRenderTarget("realisticvhseffect2/morphrt2",720,576)
local morphmat2 = CreateMaterial("realisticvhseffect2/morphmat2","g_refract",{["$fbtexture"] = rt:GetName(),["$normalmap"] = morphrt2:GetName(),["$refractamount"] = 1,["$bluramout"] = 0})
local matred = CreateMaterial("realisticvhseffect2/redmat","UnLitGeneric",{
    ["$basetexture"] = rt:GetName(),
    ["$color2"] = "[1 0 0]",
    ["$ignorez"] = 1,
    ["$additive"] = 1
})
local matgreen = CreateMaterial("realisticvhseffect2/greenmat","UnLitGeneric",{
    ["$basetexture"] = rt:GetName(),
    ["$color2"] = "[0 1 0]",
    ["$ignorez"] = 1,
    ["$additive"] = 1
})
local matblue = CreateMaterial("realisticvhseffect2/bluemat","UnLitGeneric",{
    ["$basetexture"] = rt:GetName(),
    ["$color2"] = "[0 0 1]",
    ["$ignorez"] = 1,
    ["$additive"] = 1
})
local colormod = CreateMaterial("realisticvhseffect2/colormod","g_colourmodify",{["$fbtexture"] = rt:GetName(),["$pp_colour_addr"] = 0,["$pp_colour_addg"] = 0,["$pp_colour_addb"] = 0,["$pp_colour_brightness"] = 0.1,["$pp_colour_inv"] = 0,["$pp_colour_colour"] = 0,["$pp_colour_contrast"] = 1,["$pp_colour_mulr"] = 0,["$pp_colour_mulg"] = 0,["$pp_colour_mulb"] = 0,})
local interlacedbufferrt = GetRenderTargetEx("realisticvhseffect2/interlacedbufferrt",ScrW(),ScrH(),
    RT_SIZE_NO_CHANGE,
    3,
    bit.bor(2, 256),
    0,
    IMAGE_FORMAT_BGR888) -- remove alpha channel for buffer. update 09.06.2025
local interlacedbuffermat = CreateMaterial("realisticvhseffect2/interlacedbuffermat","UnLitGeneric",{["$basetexture"] = interlacedbufferrt:GetName(),["$ignorez"] = "1",["$translucent"] = "1",["$alpha"] = "1"})
local interlacedcopyrt = GetRenderTarget("realisticvhseffect2/interlacedcopyrt",ScrW(),ScrH())
local interlacedcopymat = CreateMaterial("realisticvhseffect2/interlacedcopymat","UnLitGeneric",{["$basetexture"] = interlacedcopyrt:GetName(),["$ignorez"] = "1",["$translucent"] = "1"})

local noisert = GetRenderTarget("realisticvhseffect2/noisert",720,576)
local noisemat = CreateMaterial("realisticvhseffect2/noisemat","UnLitGeneric",{["$basetexture"] = noisert:GetName(),["$ignorez"] = "1",["$translucent"] = "1",["$vertexalpha"] = "1"})

local noiseoverlayrt = GetRenderTargetEx("realisticvhseffect2/noiseoverlayrt",720,576,
    RT_SIZE_NO_CHANGE,
    3,
    bit.bor(2, 256),
    0,
    IMAGE_FORMAT_BGR888) -- remove alpha channel for buffer.
local noiseoverlaymat = CreateMaterial("realisticvhseffect2/noiseoverlaymat","UnLitGeneric",{["$basetexture"] = noiseoverlayrt:GetName()})

local screencopymat = CreateMaterial("realisticvhseffect2/screencopymat","GMODScreenspace",{["$basetexture"]=rt:GetName(),["$translucent"] = "0",["$ignorez"] = "1"})
local tubedelayrt = GetRenderTargetEx("realisticvhseffect2/tubedelayrt",ScrW(),ScrH(),
    RT_SIZE_NO_CHANGE,
    2,
    bit.bor(2, 256),
    0,
    IMAGE_FORMAT_BGR888) -- remove alpha channel for buffer.
local tubedelaymat = CreateMaterial("realisticvhseffect2/tubedelaymat","UnLitGeneric",{["$basetexture"] = tubedelayrt:GetName(),["$ignorez"] = "1",["$translucent"] = "1"})

-- i have not been able to get this system to work yet, so i will leave it here for a while
--[[
local lensdistortionrt = GetRenderTarget("realisticvhseffect2/lensdistortionrt",512,512)
local lensdistortionmat = CreateMaterial("realisticvhseffect2/lensdistortionmat","g_refract",{["$fbtexture"] = rt:GetName(),["$normalmap"] = lensdistortionrt:GetName(),["$refractamount"] = 1,["$bluramout"] = 0})
--lensdistortionmat:SetFloat("$refractamount","-0.125")
render.PushRenderTarget(lensdistortionrt)
local cx,cy = 512/2,512/2
for j = 1,512 do--ScrW() do
    for i = 1,512 do--ScrH() do
        local distx,disty = (i-cx)/255,(j-cy)/255
        local distc = math.sqrt(((i-cx)^2) + ((j-cy)^2))/256
        render.SetViewPort(i,j,1,1)
        render.Clear((distx*255)+127,(disty*255)+127,(distc*255)+127,255,true,true)
    end
end
render.PopRenderTarget()
]]

local screenratio = 4/3-- PAL has a large horizontal resolution(possible) but an aspect ratio of 4:3.

-- prepare wave and lines
render.PushRenderTarget(morphrt)
render.Clear(127,127,0,255,true,true)
render.PopRenderTarget()
render.PushRenderTarget(morphrt2)
render.Clear(127,127,0,255,true,true)
render.PopRenderTarget()
--

-- fill the buffer for noise overlay
render.PushRenderTarget(noiseoverlayrt)
render.Clear(0,0,0,255,true,true)
for y = 0,576 do
    for x = math.random(0,20),720,20 do
        render.SetViewPort(x,y,20,1)
        if math.random(0,1) == 1 then
            render.Clear(255,255,255,255,true,true)
        else
            render.Clear(0,0,0,255,true,true)
        end
    end
end
render.PopRenderTarget()
--

-- prepare tube delay rt
render.PushRenderTarget(tubedelayrt)
render.Clear(0,0,0,255,true,true)
render.PopRenderTarget()
--

REALISTICVHSEFFECT2_CFG = {}

-- these variables have been moved to convars due to their use, this may be useful in the future
local REALISTICVHSEFFECT2_CFG_enabled = CreateClientConVar("realisticvhseffect2_enabled", "1", true, false, nil, 0, 1 )
local REALISTICVHSEFFECT2_CFG_autodisable = CreateClientConVar("realisticvhseffect2_autodisable", "0", true, false, nil, 0, 1 )

local REALISTICVHSEFFECT2_CFG_osdautocurtime = CreateClientConVar("realisticvhseffect2_osdautocurtime", "0", true, false, nil, 0, 1 )

if REALISTICVHSEFFECT2_CFG_autodisable:GetInt() == 1 then
     REALISTICVHSEFFECT2_CFG_enabled:SetInt(0)
end
--

REALISTICVHSEFFECT2_CFG.currenthookclass = "DrawOverlay"
local foundFootageHUDMatrix = Matrix()

REALISTICVHSEFFECT2_CFG.framesynchro = 576
REALISTICVHSEFFECT2_CFG.shuttlering = 0
REALISTICVHSEFFECT2_CFG.paused = false

REALISTICVHSEFFECT2_CFG.testtable = nil-- = Material("crt_testpicture_full.png")

REALISTICVHSEFFECT2_CFG.osd = {
    middletext = nil,
    hours = 2,
    minutes = 22,
    seconds = 15,
    days = 9,
    months = 1,
    years = 2025,
    fixsize = {m = {" ",2},s = {"0",2},ms = {" ",4},f = {"0",2},h = {" ",2},h12 = {" ",2}}, -- fixed size
    dateenabled = false,
    datepos = 3,
    -- 1: LEFTTOP;2: RIGHTTOP;3:LEFTDOWN;4:RIGHTDOWN;
    datetbl = {
        "%h",":","%mi",":","%s","\n","%d",".","%m",".","%y"
    },
    vcr_text_enabled = false,
    vcr_text = "PLAY",
    timepassageenabled = true,
}

REALISTICVHSEFFECT2_CFG.postclrmod = {
    ["pp_colour_addr"] = 0,
    ["pp_colour_addg"] = 0,
    ["pp_colour_addb"] = 0,
    ["pp_colour_brightness"] = 0,
    ["pp_colour_colour"] = 1,
    ["pp_colour_inv"] = 0,
    ["pp_colour_contrast"] = 1,
    ["pp_colour_mulr"] = 0,
    ["pp_colour_mulg"] = 0,
    ["pp_colour_mulb"] = 0,
}
REALISTICVHSEFFECT2_CFG.presize = true
REALISTICVHSEFFECT2_CFG.viewtype = 1
local REALISTICVHSEFFECT2_CFG_dspenabled = CreateClientConVar("realisticvhseffect2_dspenabled", "1", true, false, nil, 0, 1 )
REALISTICVHSEFFECT2_CFG_enabled:SetInt(1)
REALISTICVHSEFFECT2_CFG_autodisable:SetInt(0)
REALISTICVHSEFFECT2_CFG_osdautocurtime:SetInt(0)
REALISTICVHSEFFECT2_CFG_dspenabled:SetInt(1)
REALISTICVHSEFFECT2_CFG.wave = {enabled = true,freq = 4,detail = 2,amp = 0.025,noise = 0}
REALISTICVHSEFFECT2_CFG.lines = {enabled = false,amp = 2,bottomline = {enabled = false,height = 8,amp = 5,noise = 0,randamp = 4,randclr = 0},upperline = {enabled = false,height = 64,scale = -0.1,noise = 0,randamp = 0}}
REALISTICVHSEFFECT2_CFG.sharpen = {enabled = true,size = 1,value = 3}
REALISTICVHSEFFECT2_CFG.cameraclrdist = {r = 0,g = 0,b = 0}
REALISTICVHSEFFECT2_CFG.interlaced = {enabled = true,pos = 0,blend = 1}
-- please note that the variable is called channelssettings, not channelsettings
REALISTICVHSEFFECT2_CFG.channelssettings = {
    chroma_line_drop = false,
    chroma_line_drop_maxdrops = 1,
    chroma_blur = 4,
    chroma_offsetx = 0,
    chroma_offsety = 0,
    chroma_noise_enabled = false,--true,
    chroma_noise_scalex = 16,
    chroma_noise_scaley = 8,
    chroma_noise_alpha = 0.004125,
    
    general_blur = 1.5,
    luma_noise_enabled = false,--true,
    luma_noise_scalex = 32,
    luma_noise_scaley = 18,
    luma_noise_alpha = 0.025,
}
REALISTICVHSEFFECT2_CFG.comets = {factor = 50000,enabled = true,size = 0.5}
REALISTICVHSEFFECT2_CFG.noise_overlay = {
    enabled = false,
    gapenabled = false,
    gappos = 0.5,
    gapsize = 0.25,
    gapanim = false,
}
REALISTICVHSEFFECT2_CFG.wrinkle = {
    enabled = false,
    anim = true,
    animspeed = 0.25,
    pos = 0,
    size = 0.25,
}
REALISTICVHSEFFECT2_CFG.videofader = {
    enabled = false,
    alpha = 0,
    r = 1,
    g = 1,
    b = 1,
    anim = 0,
    animspeed = 1,
}
REALISTICVHSEFFECT2_CFG.tubedelay = {
    enabled = false,
    addalpha = 0.02,
    drawalpha = 0.2
}


-- please, do not copy this table using direct assignment,
-- since you are not copying the table, but a pointer to it.
-- in fact, any action on the copy of the table will be reflected in the original table!
-- The correct example is:
-- REALISTICVHSEFFECT2_CFG = table.Copy(REALISTICVHSEFFECT2_CFG_DEFAULT)
-- the same for child elements.

local function applyfoundfootageprofile(resettransient)
    local cfg = FF_CONFIG and FF_CONFIG.Effects and FF_CONFIG.Effects.VHS
    if not cfg then return end

    REALISTICVHSEFFECT2_CFG_enabled:SetInt(cfg.Enabled == false and 0 or 1)
    REALISTICVHSEFFECT2_CFG_autodisable:SetInt(0)
    REALISTICVHSEFFECT2_CFG_osdautocurtime:SetInt(cfg.OSDUseCurrentTime == true and 1 or 0)
    REALISTICVHSEFFECT2_CFG_dspenabled:SetInt(cfg.EqualizeSound == false and 0 or 1)

    REALISTICVHSEFFECT2_CFG.currenthookclass = cfg.HookClass or "DrawOverlay"
    REALISTICVHSEFFECT2_CFG.presize = cfg.PreSize ~= false
    REALISTICVHSEFFECT2_CFG.viewtype = tonumber(cfg.ViewType) or 1
    REALISTICVHSEFFECT2_CFG.shuttlering = tonumber(cfg.ShuttleRing) or 0
    REALISTICVHSEFFECT2_CFG.paused = cfg.Paused == true

    if resettransient then
        REALISTICVHSEFFECT2_CFG.framesynchro = tonumber(cfg.FrameSynchronization) or 0
    end

    REALISTICVHSEFFECT2_CFG.osd.dateenabled = cfg.OSD == true
    REALISTICVHSEFFECT2_CFG.osd.vcr_text_enabled = false

    local wave = cfg.Wave or {}
    REALISTICVHSEFFECT2_CFG.wave.enabled = wave.Enabled ~= false
    REALISTICVHSEFFECT2_CFG.wave.freq = tonumber(wave.Frequency) or 4
    REALISTICVHSEFFECT2_CFG.wave.detail = tonumber(wave.Detail) or 2
    REALISTICVHSEFFECT2_CFG.wave.amp = tonumber(wave.Amplitude) or 0.025
    REALISTICVHSEFFECT2_CFG.wave.noise = tonumber(wave.Noise) or 0

    local lines = cfg.Lines or {}
    REALISTICVHSEFFECT2_CFG.lines.enabled = lines.Enabled == true
    REALISTICVHSEFFECT2_CFG.lines.amp = tonumber(lines.Amplitude) or 2

    local bottom = lines.Bottom or {}
    REALISTICVHSEFFECT2_CFG.lines.bottomline.enabled = bottom.Enabled == true
    REALISTICVHSEFFECT2_CFG.lines.bottomline.height = tonumber(bottom.Height) or 8
    REALISTICVHSEFFECT2_CFG.lines.bottomline.amp = tonumber(bottom.Amplitude) or 5
    REALISTICVHSEFFECT2_CFG.lines.bottomline.noise = tonumber(bottom.Noise) or 0
    REALISTICVHSEFFECT2_CFG.lines.bottomline.randamp = tonumber(bottom.RandomAmplitude) or 4
    REALISTICVHSEFFECT2_CFG.lines.bottomline.randclr = tonumber(bottom.RandomColor) or 0

    local upper = lines.Upper or {}
    REALISTICVHSEFFECT2_CFG.lines.upperline.enabled = upper.Enabled == true
    REALISTICVHSEFFECT2_CFG.lines.upperline.height = tonumber(upper.Height) or 64
    REALISTICVHSEFFECT2_CFG.lines.upperline.scale = tonumber(upper.Scale) or -0.1
    REALISTICVHSEFFECT2_CFG.lines.upperline.noise = tonumber(upper.Noise) or 0
    REALISTICVHSEFFECT2_CFG.lines.upperline.randamp = tonumber(upper.RandomAmplitude) or 0

    local sharpen = cfg.Sharpen or {}
    REALISTICVHSEFFECT2_CFG.sharpen.enabled = sharpen.Enabled ~= false
    REALISTICVHSEFFECT2_CFG.sharpen.size = tonumber(sharpen.Size) or 1
    REALISTICVHSEFFECT2_CFG.sharpen.value = tonumber(sharpen.Strength) or 3

    local colorDistortion = cfg.CameraColorDistortion or {}
    REALISTICVHSEFFECT2_CFG.cameraclrdist.r = tonumber(colorDistortion.Red) or 0
    REALISTICVHSEFFECT2_CFG.cameraclrdist.g = tonumber(colorDistortion.Green) or 0
    REALISTICVHSEFFECT2_CFG.cameraclrdist.b = tonumber(colorDistortion.Blue) or 0

    local interlacing = cfg.Interlacing or {}
    REALISTICVHSEFFECT2_CFG.interlaced.enabled = interlacing.Enabled ~= false
    REALISTICVHSEFFECT2_CFG.interlaced.blend = tonumber(interlacing.Blend) or 1

    local channels = cfg.Channels or {}
    local channelSettings = REALISTICVHSEFFECT2_CFG.channelssettings
    channelSettings.chroma_line_drop = channels.ChromaLineDrop == true
    channelSettings.chroma_line_drop_maxdrops = tonumber(channels.ChromaLineDropMaximum) or 1
    channelSettings.chroma_blur = tonumber(channels.ChromaBlur) or 4
    channelSettings.chroma_offsetx = tonumber(channels.ChromaOffsetX) or 0
    channelSettings.chroma_offsety = tonumber(channels.ChromaOffsetY) or 0
    channelSettings.chroma_noise_enabled = channels.ChromaNoise == true
    channelSettings.chroma_noise_scalex = tonumber(channels.ChromaNoiseScaleX) or 16
    channelSettings.chroma_noise_scaley = tonumber(channels.ChromaNoiseScaleY) or 8
    channelSettings.chroma_noise_alpha = tonumber(channels.ChromaNoiseAlpha) or 0.004125
    channelSettings.general_blur = tonumber(channels.GeneralBlur) or 1.5
    channelSettings.luma_noise_enabled = channels.LumaNoise == true
    channelSettings.luma_noise_scalex = tonumber(channels.LumaNoiseScaleX) or 32
    channelSettings.luma_noise_scaley = tonumber(channels.LumaNoiseScaleY) or 18
    channelSettings.luma_noise_alpha = tonumber(channels.LumaNoiseAlpha) or 0.025

    local comets = cfg.CometSettings or {}
    REALISTICVHSEFFECT2_CFG.comets.enabled = cfg.Comets == true
    REALISTICVHSEFFECT2_CFG.comets.factor = tonumber(comets.Factor) or 50000
    REALISTICVHSEFFECT2_CFG.comets.size = tonumber(comets.Size) or 0.5

    local noiseOverlay = cfg.NoiseOverlay or {}
    REALISTICVHSEFFECT2_CFG.noise_overlay.enabled = noiseOverlay.Enabled == true
    REALISTICVHSEFFECT2_CFG.noise_overlay.gapenabled = noiseOverlay.GapEnabled == true
    REALISTICVHSEFFECT2_CFG.noise_overlay.gappos = tonumber(noiseOverlay.GapPosition) or 0.5
    REALISTICVHSEFFECT2_CFG.noise_overlay.gapsize = tonumber(noiseOverlay.GapSize) or 0.25
    REALISTICVHSEFFECT2_CFG.noise_overlay.gapanim = noiseOverlay.GapAnimation == true

    local wrinkle = cfg.Wrinkle or {}
    REALISTICVHSEFFECT2_CFG.wrinkle.enabled = wrinkle.Enabled == true
    REALISTICVHSEFFECT2_CFG.wrinkle.anim = wrinkle.Animated ~= false
    REALISTICVHSEFFECT2_CFG.wrinkle.animspeed = tonumber(wrinkle.AnimationSpeed) or 0.25
    REALISTICVHSEFFECT2_CFG.wrinkle.pos = tonumber(wrinkle.Position) or 0
    REALISTICVHSEFFECT2_CFG.wrinkle.size = tonumber(wrinkle.Size) or 0.25

    local videoFader = cfg.VideoFader or {}
    REALISTICVHSEFFECT2_CFG.videofader.enabled = videoFader.Enabled == true
    REALISTICVHSEFFECT2_CFG.videofader.alpha = tonumber(videoFader.Alpha) or 0
    REALISTICVHSEFFECT2_CFG.videofader.r = tonumber(videoFader.Red) or 1
    REALISTICVHSEFFECT2_CFG.videofader.g = tonumber(videoFader.Green) or 1
    REALISTICVHSEFFECT2_CFG.videofader.b = tonumber(videoFader.Blue) or 1
    REALISTICVHSEFFECT2_CFG.videofader.anim = tonumber(videoFader.Animation) or 0
    REALISTICVHSEFFECT2_CFG.videofader.animspeed = tonumber(videoFader.AnimationSpeed) or 1

    local tubeDelay = cfg.TubeDelay or {}
    REALISTICVHSEFFECT2_CFG.tubedelay.enabled = tubeDelay.Enabled == true
    REALISTICVHSEFFECT2_CFG.tubedelay.addalpha = tonumber(tubeDelay.AddAlpha) or 0.02
    REALISTICVHSEFFECT2_CFG.tubedelay.drawalpha = tonumber(tubeDelay.DrawAlpha) or 0.2

    for key, value in pairs(cfg.PostColorModify or {}) do
        if REALISTICVHSEFFECT2_CFG.postclrmod[key] ~= nil then
            REALISTICVHSEFFECT2_CFG.postclrmod[key] = tonumber(value) or 0
        end
    end
end

applyfoundfootageprofile(true)

REALISTICVHSEFFECT2_CFG_DEFAULT = table.Copy(REALISTICVHSEFFECT2_CFG)

local function cfg_readstring(cfile)
    return cfile:Read(cfile:ReadByte())
end

local function cfg_readdata(cfile)
    local type = cfile:ReadByte()
    local name = cfg_readstring(cfile)
    if not name then return end
    if type == 3 then
        return name,cfile:ReadBool()
    elseif type == 2 then
        local tbl = {}
        for i = 1,cfile:ReadByte() do
            local name,data = cfg_readdata(cfile)
            if name then tbl[tonumber(name) or name] = data else break end
            -- there is an obvious problem here - keys are always serialized as strings and lua wont be able to index them correctly.
            -- of course, this can be fixed, but for now it works
        end
        return name,tbl
    elseif type == 1 then
        return name,cfg_readstring(cfile)
    elseif type == 0 then
        return name,cfile:ReadDouble()
    end
    return name,nil
end

local function LoadCFG()
    local cfile = file.Open("realisticvhseffect2cfg.dat","rb","DATA")
    if cfile then
        if cfile:Read(9) == "RVHSE2CFG" then
            cfile:Skip(4) -- skip date stamp
            local name,data = cfg_readdata(cfile)
            if name == "REALISTICVHSEFFECT2_CFG" then
                table.Merge(REALISTICVHSEFFECT2_CFG,data)
                --for k,v in pairs(data) do
                --    REALISTICVHSEFFECT2_CFG[k] = v
                --end
            end
        end
        cfile:Close()
    end
end

if REALISTICVHSEFFECT2_CFG_LOADING then LoadCFG() end

-- OSD support

local osdfontsize = math.min(ScrH()/8,ScrW()/8)
surface.CreateFont("RealisticVHSEffect2Font", {
    font = FF_VHS_FONT_FAMILY or "VCR OSD Mono",
    extended = false, -- this font only supports ascii set
    size = osdfontsize,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
})

local function getdateosd_monthdays()
    local days = {31,28,31,30,31,30,31,31,30,31,30,31}

    if (REALISTICVHSEFFECT2_CFG.osd.months == 2 and ((REALISTICVHSEFFECT2_CFG.osd.years % 4 == 0 and REALISTICVHSEFFECT2_CFG.osd.years % 100 ~= 0) or (REALISTICVHSEFFECT2_CFG.osd.years % 400 == 0))) then
        return 29
    end

    return days[REALISTICVHSEFFECT2_CFG.osd.months]
end

local function getdateosd_value(val,type)
    local val = tostring(val)
    local tbl = REALISTICVHSEFFECT2_CFG.osd.fixsize[type]
    if tbl then
        local diff = tbl[2]-#val
        if diff < 0 then
            val = string.sub(val,1,diff)
        elseif diff > 0 then
            val = string.rep(tbl[1],diff) .. val
        end
        return val
    end
    return val
end

local realframetime = 0
local function formattostring(tbl,y,m,d,h,mi,s,ms,f,h12,mer,mw)
    local str = ""
    for k,v in pairs(tbl) do
        if v == "%y" then str = str .. y       -- years
        elseif v == "%mi" then str = str .. mi -- minutes
        elseif v == "%d" then str = str .. d   -- days
        elseif v == "%h" then str = str .. h   -- hours
        elseif v == "%m" then str = str .. m   -- mounths
        elseif v == "%s" then str = str .. s   -- seconds
        elseif v == "%ms" then str = str .. ms -- miliseconds
        elseif v == "%f" then str = str .. f   -- frames

        elseif v == "%h12" then str = str .. h12  -- hours 12-based
        elseif v == "%mer" then str = str .. mer  -- meridiem

        elseif v == "%mw" then str = str .. mw -- month word
        else str = str .. v end                -- raw
    end
    return str
end

local function getdateosd()
    if REALISTICVHSEFFECT2_CFG.osd.timepassageenabled then
        REALISTICVHSEFFECT2_CFG.osd.seconds = REALISTICVHSEFFECT2_CFG.osd.seconds + realframetime -- fixes the cause of time speeding up when the menu is open
        if REALISTICVHSEFFECT2_CFG.osd.seconds >= 60 then
            REALISTICVHSEFFECT2_CFG.osd.seconds = 0
            REALISTICVHSEFFECT2_CFG.osd.minutes = REALISTICVHSEFFECT2_CFG.osd.minutes + 1 -- please note that the difference between the current seconds and the maximum is not taken into account!
            if REALISTICVHSEFFECT2_CFG.osd.minutes >= 60 then
                REALISTICVHSEFFECT2_CFG.osd.minutes = 0
                REALISTICVHSEFFECT2_CFG.osd.hours = REALISTICVHSEFFECT2_CFG.osd.hours + 1
                if REALISTICVHSEFFECT2_CFG.osd.hours >= 24 then
                    REALISTICVHSEFFECT2_CFG.osd.hours = 0
                    REALISTICVHSEFFECT2_CFG.osd.days = REALISTICVHSEFFECT2_CFG.osd.days + 1
                    if REALISTICVHSEFFECT2_CFG.osd.days > getdateosd_monthdays() then
                        REALISTICVHSEFFECT2_CFG.osd.days = 1
                        REALISTICVHSEFFECT2_CFG.osd.months = REALISTICVHSEFFECT2_CFG.osd.months + 1
                        if REALISTICVHSEFFECT2_CFG.osd.months > 12 then
                            REALISTICVHSEFFECT2_CFG.osd.months = 1
                            REALISTICVHSEFFECT2_CFG.osd.years = REALISTICVHSEFFECT2_CFG.osd.years + 1
                        end
                    end
                end
            end
        end
    end
    local mer = "ER"
    local hours12 = 0
    if REALISTICVHSEFFECT2_CFG.osd.hours < 12 then
        mer = "AM"
        hours12 = REALISTICVHSEFFECT2_CFG.osd.hours
    else
        mer = "PM"
        hours12 = REALISTICVHSEFFECT2_CFG.osd.hours - 12
    end
    if hours12 == 0 then
        hours12 = 12
    end

    return formattostring(REALISTICVHSEFFECT2_CFG.osd.datetbl,getdateosd_value(REALISTICVHSEFFECT2_CFG.osd.years,"y"),
    getdateosd_value(REALISTICVHSEFFECT2_CFG.osd.months,"m"),getdateosd_value(REALISTICVHSEFFECT2_CFG.osd.days,"d"),
    getdateosd_value(REALISTICVHSEFFECT2_CFG.osd.hours,"h"),getdateosd_value(REALISTICVHSEFFECT2_CFG.osd.minutes,"mi"),
    getdateosd_value(math.floor(REALISTICVHSEFFECT2_CFG.osd.seconds),"s"),getdateosd_value(math.floor((REALISTICVHSEFFECT2_CFG.osd.seconds-math.floor(REALISTICVHSEFFECT2_CFG.osd.seconds))*1000),"ms"), -- seconds and miliseconds
    getdateosd_value(math.floor((REALISTICVHSEFFECT2_CFG.osd.seconds-math.floor(REALISTICVHSEFFECT2_CFG.osd.seconds))*25),"f"), -- frames(25 f-fps)
    getdateosd_value(hours12,"h12"),getdateosd_value(mer,"mer"), -- hours 12-based and meridiem
    getdateosd_value(({"JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE","JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"})[REALISTICVHSEFFECT2_CFG.osd.months] or "NUL","mw")) -- month word(JAN,FEB,MAR ... )
end

local function draw_osdtext(a,b,c,d,e,f,g)
    draw.SimpleText(a,b,c+4,d,Color(0,0,0,255),f,g)
    return draw.SimpleText(a,b,c,d,e,f,g)
end

local function addosd()
    if REALISTICVHSEFFECT2_CFG.osd.dateenabled then
        local datealign = TEXT_ALIGN_LEFT
        local datex = 0
        local datey = 0
        if REALISTICVHSEFFECT2_CFG.osd.datepos == 1 then     -- left up
            datex = ScrW()/8
            datey = ScrH()/6
            if REALISTICVHSEFFECT2_CFG.viewtype == 2 then -- fix cropping date
                datex = ((ScrW()-(ScrW()/screenratio))/2)+(ScrW()/16)
            end
        elseif REALISTICVHSEFFECT2_CFG.osd.datepos == 2 then -- right up
            datealign = TEXT_ALIGN_RIGHT
            datex = ScrW()-(ScrW()/8)
            datey = ScrH()/6
            if REALISTICVHSEFFECT2_CFG.viewtype == 2 then -- fix cropping date
                datex = ScrW()-((((ScrW()/screenratio))/2)-(ScrW()/4))
            end
        elseif REALISTICVHSEFFECT2_CFG.osd.datepos == 3 then -- left down
            datex = ScrW()/8
            datey = ScrH()/1.4
            if REALISTICVHSEFFECT2_CFG.viewtype == 2 then -- fix cropping date
                datex = ((ScrW()-(ScrW()/screenratio))/2)+(ScrW()/16)
            end
        elseif REALISTICVHSEFFECT2_CFG.osd.datepos == 4 then -- right down
            datealign = TEXT_ALIGN_RIGHT
            datex = ScrW()-(ScrW()/8)
            datey = ScrH()/1.4
            if REALISTICVHSEFFECT2_CFG.viewtype == 2 then -- fix cropping date
                datex = ScrW()-((((ScrW()/screenratio))/2)-(ScrW()/4))
            end
        end
        local datetbl = string.Explode("\n",getdateosd())
        for i = 0,#datetbl-1 do
            draw_osdtext(datetbl[i+1],"RealisticVHSEffect2Font",datex,datey+((osdfontsize/2)*i),Color(255,255,255),datealign,TEXT_ALIGN_TOP)
        end
    end
    if REALISTICVHSEFFECT2_CFG.osd.middletext then
        local middletexttbl = string.Explode("\n",REALISTICVHSEFFECT2_CFG.osd.middletext)
        if #middletexttbl > 1 then
            for i = 0,#middletexttbl-1 do
                draw_osdtext(string.upper(middletexttbl[i+1]),"RealisticVHSEffect2Font",ScrW()/2,(ScrH()/2)+((osdfontsize/2)*i),Color(255,255,255),TEXT_ALIGN_CENTER)
            end
        else
            draw_osdtext(string.upper(REALISTICVHSEFFECT2_CFG.osd.middletext),"RealisticVHSEffect2Font",ScrW()/2,ScrH()/2,Color(255,255,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end
    if REALISTICVHSEFFECT2_CFG.osd.vcr_text_enabled then -- of course, this is not the best place for this. however, for now, it is the best that can be done.
        surface.SetFont("RealisticVHSEffect2Font")
        local vcr_text_w,vcr_text_h = surface.GetTextSize(REALISTICVHSEFFECT2_CFG.osd.vcr_text)
        local vcr_text_x,vcr_text_y = ScrW()/8,ScrH()/6
        draw.RoundedBox(0,vcr_text_x,vcr_text_y+(ScrH()/32),vcr_text_w+(ScrW()/128),vcr_text_h-(ScrH()/32),Color(10,10,10))
        draw.SimpleText(tostring(REALISTICVHSEFFECT2_CFG.osd.vcr_text),"RealisticVHSEffect2Font",vcr_text_x,vcr_text_y,Color(255,255,255))
    end
end
-- Horizontal Synchronization Support

local function getwavex(i,shift,initval)
    local val = initval + math.Rand(0,REALISTICVHSEFFECT2_CFG.wave.noise)
    for j = 1,REALISTICVHSEFFECT2_CFG.wave.detail do
        val = val + (math.sin((i/64)+(cachedcurtime*(REALISTICVHSEFFECT2_CFG.wave.freq*j))*shift)/j)
    end
    return val*10
end

local function updatemorphrt()
    render.PushRenderTarget(morphrt)
    render.Clear(127,127,0,255,true,true)
    local shift = math.Rand(0,1)
    if REALISTICVHSEFFECT2_CFG.shuttlering == 0 then
        for i = 1,576 do
            render.SetViewPort(0,i,720,1)
            render.Clear(127+getwavex(i,shift,0),127,0,255,true,true)
        end
    else
        local height3 = (576/3)
        local cshift = 0
        local cshiftn = 0
        for i = 1,576 do
            render.SetViewPort(0,i,720,1)
            render.Clear(127+getwavex(i,shift,cshift),127,0,255,true,true)
            cshiftn = cshiftn + 1
            cshift = cshift+((cshiftn/height3)*REALISTICVHSEFFECT2_CFG.shuttlering)
            if cshift > 32 or cshift < -32 then
                cshift = 0
                cshiftn = 0
            end
        end
    end
    render.PopRenderTarget()
end

local function getwavex2(upscaleinit,btscaleinit,i)
    local up_height = 0
    local up_scale = 0
    if REALISTICVHSEFFECT2_CFG.lines.upperline.enabled then
        up_height = REALISTICVHSEFFECT2_CFG.lines.upperline.height -- 64
        up_scale = upscaleinit -- -0.1
        up_scale = up_scale + math.Rand(0,REALISTICVHSEFFECT2_CFG.lines.upperline.noise) -- 0.1
    end
    local bt_height = 0
    local bt_scale = 0
    if REALISTICVHSEFFECT2_CFG.lines.bottomline.enabled then
        bt_height = REALISTICVHSEFFECT2_CFG.lines.bottomline.height -- 8
        bt_scale = btscaleinit -- 5
        bt_scale = bt_scale + math.Rand(0,REALISTICVHSEFFECT2_CFG.lines.bottomline.noise)
    end
    return (((math.max((up_height-i)/20,0)^2)*up_scale)-((math.max((i-(307-bt_height))/bt_height,0))*bt_scale))*10 -- 288+16
end

local function updatemorphrt2()
    local upscale = REALISTICVHSEFFECT2_CFG.lines.upperline.scale+math.Rand(0,REALISTICVHSEFFECT2_CFG.lines.upperline.randamp)
    local btscale = math.Rand(0,REALISTICVHSEFFECT2_CFG.lines.bottomline.randamp)+REALISTICVHSEFFECT2_CFG.lines.bottomline.amp
    render.PushRenderTarget(morphrt2)
        render.Clear(127,127,0,255,true,true)
        for i = 1,576 do
            render.SetViewPort(0,i,720,1)
            render.Clear(127+getwavex2(upscale,btscale,i),127,0,255,true,true)
        end
    render.PopRenderTarget()
end

--

local function fillwithnoise(ystart,yend)
    surface.SetMaterial(noiseoverlaymat)
    surface.SetDrawColor(255,255,255,255)
    local ox,oy = math.Rand(0.125,1),math.Rand(0.75,1)
    if math.random(0,1) == 1 then
        surface.DrawTexturedRectUV(0,ystart,ScrW(),yend,0,oy,ox,oy+(1/(ScrH()/yend)))
    else
        surface.DrawTexturedRectUV(0,ystart,ScrW(),yend,1-ox,oy,ox,oy+(1/(ScrH()/yend)))
    end
end

local function drawnoiseoverlay()
    if REALISTICVHSEFFECT2_CFG.noise_overlay.gapenabled then
        local gapstart = ScrH()*REALISTICVHSEFFECT2_CFG.noise_overlay.gappos
        local gapsize = ScrH()*REALISTICVHSEFFECT2_CFG.noise_overlay.gapsize
        fillwithnoise(0,gapstart)
        fillwithnoise(gapstart+gapsize,ScrH()-(gapstart+gapsize))
        -- this is a very bad animation that only partially corresponds to reality, but if i try to fix it, i will make it even worse
        if REALISTICVHSEFFECT2_CFG.noise_overlay.gapanim then
            REALISTICVHSEFFECT2_CFG.noise_overlay.gapsize = math.Clamp(REALISTICVHSEFFECT2_CFG.noise_overlay.gapsize+((RealFrameTime()/40)),0,1)
            if REALISTICVHSEFFECT2_CFG.noise_overlay.gapsize == 1 then
                REALISTICVHSEFFECT2_CFG.noise_overlay.gappos = math.Clamp((REALISTICVHSEFFECT2_CFG.noise_overlay.gappos-(RealFrameTime()/20)),0,1)
            else
                if REALISTICVHSEFFECT2_CFG.noise_overlay.gapsize*10 % 1 > math.Round(REALISTICVHSEFFECT2_CFG.noise_overlay.gapsize*10)/20 then
                    REALISTICVHSEFFECT2_CFG.noise_overlay.gappos = math.Clamp((REALISTICVHSEFFECT2_CFG.noise_overlay.gappos-(RealFrameTime()/20)),0,1)
                else
                    REALISTICVHSEFFECT2_CFG.noise_overlay.gappos = math.Clamp((REALISTICVHSEFFECT2_CFG.noise_overlay.gappos+(RealFrameTime()/20)),0,1)
                end
            end
        end
        render.UpdateScreenEffectTexture(0)
    else
        fillwithnoise(0,ScrH())
        render.UpdateScreenEffectTexture(0)
    end
end

--

local function updatenoisert(chroma)
    -- i know that i can buffer all this, but it will take up more memory space, right?
    render.PushRenderTarget(noisert)
    render.Clear(0,0,0,0,true,true)
    if chroma then -- chroma noise is very resource-intensive! when it is turned on, the FPS drops from 150 to 70
        local scalex = 720/REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_scalex
        for y = 1,576/REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_scaley do
            for x = 0,scalex do
                render.SetViewPort(x,y,1,1)
                render.Clear(math.random(1,255),math.random(1,255),math.random(1,255),255,true,true)
            end
        end
    else
        local scalex = 720/REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_scalex
        for y = 1,576/REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_scaley do
            for x = 0,scalex do
                render.SetViewPort(x,y,1,1)
                local br = math.random(1,255)
                render.Clear(br,br,br,255,true,true)
            end
        end
    end
    render.PopRenderTarget()
end

local function drawcomets()
    if REALISTICVHSEFFECT2_CFG.comets.enabled then
        local maxrand = -REALISTICVHSEFFECT2_CFG.comets.factor
        local maxsizediff = REALISTICVHSEFFECT2_CFG.comets.size
        local xw = 720/4
        for y = 1,576/2 do
            local cometval = 0
            local curmin = math.random(maxrand,0)
            for x = 0,xw do
                if cometval > 0 then
                    draw.RoundedBox(0,x*4,y*2,4,2,Color(cometval*255,cometval*255,cometval*255,255))
                end
                cometval = cometval - math.Rand(0,maxsizediff)
                if cometval < curmin then
                    cometval = 1
                    curmin = math.random(maxrand,0)
                end
            end
        end
        render.UpdateScreenEffectTexture(0)
    end
end
local bottomlineclr = Color(0,0,0,0)

local function addblur()
    render.OverrideAlphaWriteEnable(true,false)

    -- draw a black and white picture on top of the screen
    render.UpdateScreenEffectTexture(0)
    colormod:SetFloat("$pp_colour_brightness",0.1)colormod:SetFloat("$pp_colour_contrast",1)colormod:SetFloat("$pp_colour_colour",0)
    render.SetMaterial(colormod)
    render.DrawScreenQuadEx(0,0,ScrW()*(ScrW()/720),ScrH()*(ScrH()/576))
    if REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_enabled then
        updatenoisert(false)
        surface.SetMaterial(noisemat)
        surface.SetDrawColor(255,255,255,REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_alpha*255)
        surface.DrawTexturedRectUV(0,0,(ScrW()*(ScrW()/720))*REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_scalex,(ScrH()*(ScrH()/576))*REALISTICVHSEFFECT2_CFG.channelssettings.luma_noise_scaley,-2,-1,0,0)
    end

    -- now add some colours
    
    if REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_enabled or REALISTICVHSEFFECT2_CFG.channelssettings.chroma_line_drop or (REALISTICVHSEFFECT2_CFG.lines.enabled and REALISTICVHSEFFECT2_CFG.lines.bottomline.enabled and REALISTICVHSEFFECT2_CFG.lines.bottomline.randclr ~= 0) then
        if REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_enabled then
            updatenoisert(true)
        end
        render.PushRenderTarget(rt)
        if REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_enabled then
            surface.SetMaterial(noisemat)
            surface.SetDrawColor(255,255,255,REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_alpha*255)
            -- increase the size by repetition(for speed)
            surface.DrawTexturedRectUV(0,0,(ScrW()*(ScrW()/720))*REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_scalex,(ScrH()*(ScrH()/576))*REALISTICVHSEFFECT2_CFG.channelssettings.chroma_noise_scaley,-1,-1,1,1)
        end
        if REALISTICVHSEFFECT2_CFG.channelssettings.chroma_line_drop then
            for i = 1,math.random(1,REALISTICVHSEFFECT2_CFG.channelssettings.chroma_line_drop_maxdrops) do
                render.SetViewPort(0,math.random(1,576),720,math.random(1,5))
                render.Clear(0,0,0,0,true,true)
            end
        end
        if REALISTICVHSEFFECT2_CFG.lines.enabled then
            if REALISTICVHSEFFECT2_CFG.lines.bottomline.enabled then
                if REALISTICVHSEFFECT2_CFG.lines.bottomline.randclr ~= 0 then
                    local btheight = REALISTICVHSEFFECT2_CFG.lines.bottomline.height*(ScrH()/576)
                    draw.RoundedBox(0,0,576-btheight,720,btheight,bottomlineclr)
                    if not REALISTICVHSEFFECT2_CFG.interlaced.enabled or (REALISTICVHSEFFECT2_CFG.interlaced.enabled and REALISTICVHSEFFECT2_CFG.interlaced.pos == 0) then
                        bottomlineclr = Color(math.random(0,255),math.random(0,255),math.random(0,255),math.Round(REALISTICVHSEFFECT2_CFG.lines.bottomline.randclr*255))
                    end
                end
            end
        end
        render.PopRenderTarget()
    end

    render.OverrideBlend(true,3,2,0) -- approximately the same blending effect
    
    blurmat:SetTexture("$basetexture",rt)
    blurmat:SetFloat("$size",REALISTICVHSEFFECT2_CFG.channelssettings.chroma_blur)
    render.SetMaterial(blurmat)
    render.DrawScreenQuadEx(REALISTICVHSEFFECT2_CFG.channelssettings.chroma_offsetx*(ScrW()/720),REALISTICVHSEFFECT2_CFG.channelssettings.chroma_offsety*(ScrH()/576),ScrW()*(ScrW()/720),ScrH()*(ScrH()/576))

    render.OverrideAlphaWriteEnable(false,false)
    render.OverrideBlend(false)
    -- in the original version the pixel colour is the average value. double the colour
    render.UpdateScreenEffectTexture(0)
    colormod:SetFloat("$pp_colour_brightness",0)colormod:SetFloat("$pp_colour_colour",2)colormod:SetFloat("$pp_colour_contrast",1)
    render.SetMaterial(colormod)
    render.DrawScreenQuadEx(0,0,ScrW(),ScrH())
    render.UpdateScreenEffectTexture(0)
end

local function renderinterlacing()
    if REALISTICVHSEFFECT2_CFG.interlaced.enabled then
        -- principle: buffer frame 1 and draw frame 2 on it
        render.SetWriteDepthToDestAlpha(false)
        render.UpdateScreenEffectTexture(0)
        if REALISTICVHSEFFECT2_CFG.interlaced.pos == 1 then
            REALISTICVHSEFFECT2_CFG.interlaced.pos = 0
            render.CopyTexture(rt,interlacedbufferrt)
            render.PushRenderTarget(interlacedbufferrt)
            render.PopRenderTarget()
        else
            render.CopyTexture(rt,interlacedcopyrt)
            render.PushRenderTarget(interlacedcopyrt)
            render.PopRenderTarget()
            REALISTICVHSEFFECT2_CFG.interlaced.pos = 1
        end
        render.SetMaterial(interlacedcopymat)
        render.DrawScreenQuad()
        render.SetStencilEnable(true)
        render.ClearStencil()
        render.SetStencilTestMask(255)
        render.SetStencilWriteMask(255)
        render.SetStencilPassOperation(STENCILOPERATION_KEEP)
        render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
        render.SetStencilReferenceValue(9)
        render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
        
        local linesize2 = math.ceil(ScrH()/288)
        local linesize = linesize2/2
        for j = 0,ScrH()/linesize2 do
            draw.RoundedBox(0,0,(j*linesize2)+linesize,ScrW(),linesize,Color(0,0,0))
        end

        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
        render.SetStencilFailOperation(STENCILOPERATION_KEEP)
        interlacedbuffermat:SetFloat("$alpha",REALISTICVHSEFFECT2_CFG.interlaced.blend)
        render.SetMaterial(interlacedbuffermat)
        render.DrawScreenQuad()

        render.SetStencilEnable(false)
        render.UpdateScreenEffectTexture(0)
        render.SetWriteDepthToDestAlpha(true)
    end
end

local function drawtubedelay()
    render.UpdateScreenEffectTexture(0)
        render.PushRenderTarget(tubedelayrt)
            screencopymat:SetFloat("$alpha",REALISTICVHSEFFECT2_CFG.tubedelay.addalpha)--0.02)
            render.SetMaterial(screencopymat)
            render.DrawScreenQuad()
        render.PopRenderTarget()
    tubedelaymat:SetFloat("$alpha",REALISTICVHSEFFECT2_CFG.tubedelay.drawalpha)--0.2)
    render.SetMaterial(tubedelaymat)
render.OverrideBlend(true,BLEND_SRC_ALPHA,BLEND_ONE,0)
    render.DrawScreenQuad()
render.OverrideBlend(false)

    screencopymat:SetFloat("$alpha",1)
    render.UpdateScreenEffectTexture(0)
end

local lastquery = 0

local function drawClampedFinalFrame(x, y, width, height)
    local textureWidth = math.max(rt:Width(), 1)
    local textureHeight = math.max(rt:Height(), 1)
    local edgeInset = 2

    -- _rt_FullFrameFB can be larger than the visible viewport. Sample only
    -- valid screen pixels and trim two edge rows so padded/stale data cannot
    -- appear as stretched top or bottom bands.
    local u0 = 0.5 / textureWidth
    local v0 = (edgeInset + 0.5) / textureHeight
    local u1 = (ScrW() - 0.5) / textureWidth
    local v1 = (ScrH() - edgeInset - 0.5) / textureHeight

    finalcopymat:SetTexture("$basetexture", rt)
    surface.SetMaterial(finalcopymat)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRectUV(x, y, width, height, u0, v0, u1, v1)
end

local function rendervhseffect()
    applyfoundfootageprofile(false)
    if not REALISTICVHSEFFECT2_CFG_enabled:GetBool() then return end

    -- Player:SetDSP is server-side in this GMod build. The forced VHS DSP
    -- preset is applied by core/server/sv_vhs_dsp.lua.
    if REALISTICVHSEFFECT2_CFG_osdautocurtime:GetBool() then
        local osdatereturn = os.date("*t")
        REALISTICVHSEFFECT2_CFG.osd.hours = osdatereturn.hour
        REALISTICVHSEFFECT2_CFG.osd.minutes = osdatereturn.min
        REALISTICVHSEFFECT2_CFG.osd.seconds = osdatereturn.sec
        REALISTICVHSEFFECT2_CFG.osd.days = osdatereturn.day
        REALISTICVHSEFFECT2_CFG.osd.months = osdatereturn.month
        REALISTICVHSEFFECT2_CFG.osd.years = osdatereturn.year
    end
    render.UpdateScreenEffectTexture(0)
    --[[
    render.SetMaterial(lensdistortionmat)
    render.DrawScreenQuadEx(-ScrW()/2,-ScrH()/2,ScrW()*2,ScrH()*2)
    render.UpdateScreenEffectTexture(0)
    --]]
    if REALISTICVHSEFFECT2_CFG.testtable then
        render.SetMaterial(REALISTICVHSEFFECT2_CFG.testtable)
        render.DrawScreenQuad()
        render.UpdateScreenEffectTexture(0)
    else
        if REALISTICVHSEFFECT2_CFG.cameraclrdist.r ~= 0 or REALISTICVHSEFFECT2_CFG.cameraclrdist.g ~= 0 or REALISTICVHSEFFECT2_CFG.cameraclrdist.b ~= 0 then
            render.UpdateScreenEffectTexture(0)
            render.SetMaterial(matred)
            render.DrawScreenQuadEx(-REALISTICVHSEFFECT2_CFG.cameraclrdist.r,-REALISTICVHSEFFECT2_CFG.cameraclrdist.r,ScrW()+REALISTICVHSEFFECT2_CFG.cameraclrdist.r,ScrH()+REALISTICVHSEFFECT2_CFG.cameraclrdist.r)
            render.SetMaterial(matgreen)
            render.DrawScreenQuadEx(-REALISTICVHSEFFECT2_CFG.cameraclrdist.g,-REALISTICVHSEFFECT2_CFG.cameraclrdist.g,ScrW()+REALISTICVHSEFFECT2_CFG.cameraclrdist.g,ScrH()+REALISTICVHSEFFECT2_CFG.cameraclrdist.g)
            render.SetMaterial(matblue)
            render.DrawScreenQuadEx(-REALISTICVHSEFFECT2_CFG.cameraclrdist.b,-REALISTICVHSEFFECT2_CFG.cameraclrdist.b,ScrW()+REALISTICVHSEFFECT2_CFG.cameraclrdist.b,ScrH()+REALISTICVHSEFFECT2_CFG.cameraclrdist.b)
            render.UpdateScreenEffectTexture(0)
            colormod:SetFloat("$pp_colour_brightness",0)colormod:SetFloat("$pp_colour_contrast",0.82)colormod:SetFloat("$pp_colour_colour",1)
            render.SetMaterial(colormod)
            render.DrawScreenQuad()

            render.UpdateScreenEffectTexture(0)
        end
    end
    if REALISTICVHSEFFECT2_CFG.wave.enabled then
        updatemorphrt()
    end
    if REALISTICVHSEFFECT2_CFG.lines.enabled then
        updatemorphrt2()
    end

    if REALISTICVHSEFFECT2_CFG.tubedelay.enabled then
        drawtubedelay()
    end

    if REALISTICVHSEFFECT2_CFG.presize then
        blurmat:SetTexture("$basetexture",rt)
        blurmat:SetFloat("$size",0)
        render.SetMaterial(blurmat)
        render.DrawScreenQuadEx(-(ScrW()/screenratio)/4,0,ScrW()+((ScrW()/screenratio)/2),ScrH())
        render.UpdateScreenEffectTexture(0)
    end

    -- Draw the gamemode HUD in a stable 720x576 coordinate space before the
    -- VHS date/time OSD and every remaining distortion/final-frame pass.
    foundFootageHUDMatrix:SetScale(Vector(ScrW() / 720, ScrH() / 576, 1))
    cam.PushModelMatrix(foundFootageHUDMatrix)
    hook.Run("FF_DrawBehindRealisticVHSEffect2", 720, 576)
    cam.PopModelMatrix()

    addosd()
    
    render.UpdateScreenEffectTexture(0)
    blurmat:SetTexture("$basetexture",rt)
    blurmat:SetFloat("$size",REALISTICVHSEFFECT2_CFG.channelssettings.general_blur)
    render.SetMaterial(blurmat)
    render.DrawScreenQuadEx(0,0,720,576)
    -- Please note that starting from this line the image is in 720 x 576 format (for ease of adding effects)

    if REALISTICVHSEFFECT2_CFG.paused then -- removes colour. not in use yet.
        colormod:SetFloat("$pp_colour_brightness",0)colormod:SetFloat("$pp_colour_contrast",1)colormod:SetFloat("$pp_colour_colour",0)
        render.SetMaterial(colormod)
        render.DrawScreenQuadEx(0,0,720,576)
    end

    if REALISTICVHSEFFECT2_CFG.videofader.enabled then
        if REALISTICVHSEFFECT2_CFG.videofader.alpha ~= 0 then
            draw.RoundedBox(0,0,0,720,576,Color(REALISTICVHSEFFECT2_CFG.videofader.r*255,
                REALISTICVHSEFFECT2_CFG.videofader.g*255,
                REALISTICVHSEFFECT2_CFG.videofader.b*255,
                REALISTICVHSEFFECT2_CFG.videofader.alpha*255))
            render.UpdateScreenEffectTexture(0)
        end
        if REALISTICVHSEFFECT2_CFG.videofader.anim == 1 then
            REALISTICVHSEFFECT2_CFG.videofader.alpha = math.Clamp(REALISTICVHSEFFECT2_CFG.videofader.alpha - (RealFrameTime()*REALISTICVHSEFFECT2_CFG.videofader.animspeed),0,1)
        elseif REALISTICVHSEFFECT2_CFG.videofader.anim == 2 then
            REALISTICVHSEFFECT2_CFG.videofader.alpha = math.Clamp(REALISTICVHSEFFECT2_CFG.videofader.alpha + (RealFrameTime()*REALISTICVHSEFFECT2_CFG.videofader.animspeed),0,1)
        end
    end

    drawcomets()

    draw.RoundedBox(0,-2,0,4,576,Color(0,0,0))
    draw.RoundedBox(0,720,0,ScrW()-720,576,Color(0,0,0))
    render.UpdateScreenEffectTexture(0)
    if REALISTICVHSEFFECT2_CFG.wave.enabled then
        morphmat:SetFloat("$refractamount",REALISTICVHSEFFECT2_CFG.wave.amp/2)
        render.SetMaterial(morphmat)
        render.DrawScreenQuad()
        draw.RoundedBox(0,-2,0,4,576,Color(0,0,0))
        draw.RoundedBox(0,720,0,ScrW()-720,576,Color(0,0,0))
        render.UpdateScreenEffectTexture(0)
    end
    if REALISTICVHSEFFECT2_CFG.lines.enabled then
        morphmat2:SetFloat("$refractamount",REALISTICVHSEFFECT2_CFG.lines.amp/2)
        render.SetMaterial(morphmat2)
        render.DrawScreenQuad()
        render.UpdateScreenEffectTexture(0)
    end
    if REALISTICVHSEFFECT2_CFG.shuttlering ~= 0 then -- 2-head VCR emulation. not yet developed well enough to be mentioned in documentation.
        for i = 1,2 do
            local cometval = 0
            local curmin = -math.random(0,10)
            for y = 0,ScrH()/40 do
                for x = 0,ScrW()/4 do
                    if cometval > 0 then
                        draw.RoundedBox(0,x*4,(y+((576/3)*i))+10,4,3,Color(cometval*255,cometval*255,cometval*255,255))
                    end
                    cometval = cometval - math.Rand(0,1)/5
                    if cometval < curmin then
                        cometval = 1
                        curmin = -math.random(0,10)
                    end
                end
            end
        end
        render.UpdateScreenEffectTexture(0)
    end

    -- Full-frame transient overlays draw after the HUD and OSD while still remaining
    -- inside the VHS pipeline. This keeps impact fades behind every later VHS
    -- blur, interlace, colour, noise, and pillarbox pass.
    hook.Run("FF_DrawVHSFrameOverlay", 720, 576)

    -- Back to original resolution
    addblur()
    if REALISTICVHSEFFECT2_CFG.sharpen.enabled then
        if REALISTICVHSEFFECT2_CFG.sharpen.size > 0 and REALISTICVHSEFFECT2_CFG.sharpen.value > 0 then
            DrawSharpen(REALISTICVHSEFFECT2_CFG.sharpen.size,REALISTICVHSEFFECT2_CFG.sharpen.value)
            render.UpdateScreenEffectTexture(0)
        end
    end
    if REALISTICVHSEFFECT2_CFG.wrinkle.enabled then
        colormod:SetFloat("$pp_colour_brightness",0)colormod:SetFloat("$pp_colour_contrast",1)colormod:SetFloat("$pp_colour_colour",1)
        surface.SetMaterial(colormod)
        local wrinkleypos = REALISTICVHSEFFECT2_CFG.wrinkle.pos
        local wrinkleysize = REALISTICVHSEFFECT2_CFG.wrinkle.size
        surface.DrawTexturedRectUV(0,wrinkleypos*ScrH(),ScrW(),wrinkleysize*ScrH(),0,wrinkleypos,1,wrinkleypos)
        render.UpdateScreenEffectTexture(0)
        if REALISTICVHSEFFECT2_CFG.wrinkle.anim then
            REALISTICVHSEFFECT2_CFG.wrinkle.pos = REALISTICVHSEFFECT2_CFG.wrinkle.pos + (RealFrameTime()*REALISTICVHSEFFECT2_CFG.wrinkle.animspeed)
            if REALISTICVHSEFFECT2_CFG.wrinkle.pos > 1 then
                REALISTICVHSEFFECT2_CFG.wrinkle.pos = -REALISTICVHSEFFECT2_CFG.wrinkle.size
            end
        end
    end
    renderinterlacing()
    for k,v in pairs(REALISTICVHSEFFECT2_CFG.postclrmod) do
        colormod:SetFloat("$" .. k,v)
    end
    render.SetMaterial(colormod)
    render.DrawScreenQuad()
    render.UpdateScreenEffectTexture(0)
    if REALISTICVHSEFFECT2_CFG.noise_overlay.enabled then
        drawnoiseoverlay()
    end
    if REALISTICVHSEFFECT2_CFG.framesynchro > 0 then
        draw.RoundedBox(0,0,0,ScrW(),ScrH(),Color(0,0,0))
        blurmat:SetTexture("$basetexture",rt)
        blurmat:SetFloat("$size",0)
        render.SetMaterial(blurmat)
        render.DrawScreenQuadEx(0,REALISTICVHSEFFECT2_CFG.framesynchro,ScrW(),ScrH())
        REALISTICVHSEFFECT2_CFG.framesynchro = math.max(REALISTICVHSEFFECT2_CFG.framesynchro - 288,0)
        render.UpdateScreenEffectTexture(0)
    end
    if REALISTICVHSEFFECT2_CFG.viewtype == 1 then
        -- Resize to 4:3 with black side bars. Use a clamped viewport copy so
        -- padded full-frame-buffer rows cannot become distorted edge strips.
        draw.RoundedBox(0, -1, -1, ScrW() + 1, ScrH() + 1, Color(0, 0, 0))
        local frameWidth = ScrW() / screenratio
        local frameX = (ScrW() - frameWidth) / 2
        drawClampedFinalFrame(frameX, 0, frameWidth, ScrH())
        render.UpdateScreenEffectTexture(0)
    elseif REALISTICVHSEFFECT2_CFG.viewtype == 2 then
        -- cropping
        local cropwidth = (ScrW()-(ScrW()/screenratio))/2
        draw.RoundedBox(0,0,0,cropwidth,ScrH(),Color(0,0,0))
        draw.RoundedBox(0,ScrW()-cropwidth,0,cropwidth,ScrH(),Color(0,0,0))
        render.UpdateScreenEffectTexture(0)
    elseif REALISTICVHSEFFECT2_CFG.viewtype == 3 then
        -- crop to fit width
        draw.RoundedBox(0,0,0,ScrW(),ScrH(),Color(0,0,0))
        blurmat:SetTexture("$basetexture",rt)
        blurmat:SetFloat("$size",0)
        render.SetMaterial(blurmat)
        local cropwidth = (ScrW()-(ScrW()/screenratio))
        local cropheight = ScrH()*(ScrW()/(ScrW()+cropwidth*2))
        render.DrawScreenQuadEx(-cropwidth/2,-cropheight/2,ScrW()+cropwidth,ScrH()+cropheight)
        render.UpdateScreenEffectTexture(0)
    end
    cachedcurtime = CurTime()
    realframetime = SysTime()-lastquery
    lastquery = SysTime()
end

hook.Add(REALISTICVHSEFFECT2_CFG.currenthookclass,"realisticvhseffect2_hook",rendervhseffect)
