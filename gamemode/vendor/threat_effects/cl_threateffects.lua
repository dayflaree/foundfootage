local enabled = CreateClientConVar("threateffects_enabled", "1", true, false, "Enable Threat Effects", 0, 1)

local intensity_const = CreateClientConVar("threateffects_intensity_const", "0", true, false, "Constant Intensity Factor", 0, 1)

local intensity_mul = CreateClientConVar("threateffects_intensity_mul", "1", true, false, "Effect intensity multiplier", 0, 2)
local time_mul = CreateClientConVar("threateffects_time_mul", "1", true, false, "Effect time multiplier", 0, 2)

local factor_violentnpc = CreateClientConVar("threateffects_factor_violentnpc", "1", true, false, "How much does Violent NPC nearby impact effect intensity", 0, 1)
local factor_violentnpc_count = CreateClientConVar("threateffects_factor_violentnpccount", "1", true, false, "At most, how many enemies should we search for around us", 0, 10)
local factor_violentnpc_radius = CreateClientConVar("threateffects_factor_violentnpcradius", "500", true, false, "The radius in which we search for enemies", 0, 1500)
local factor_violentnpc_list = CreateClientConVar("threateffects_factor_violentnpclist", "", true, false, "List of custom entity enemies, separated with ;")
local factor_speed = CreateClientConVar("threateffects_factor_speed", "1", true, false, "How much does Player Speed impact effect intensity", 0, 1)
local factor_damage = CreateClientConVar("threateffects_factor_damage", "1", true, false, "How much does Damage impact effect intensity", 0, 1)
local factor_health = CreateClientConVar("threateffects_factor_health", "1", true, false, "How much does Low Health impact effect intensity", 0, 1)
local factor_height = CreateClientConVar("threateffects_factor_height", "1", true, false, "How much does Relative Height impact effect intensity", 0, 1)

local volume_glitch = CreateClientConVar("threateffects_volume_glitch", "1", true, false, "Glitches volume", 0, 1)
local volume_heartbeat = CreateClientConVar("threateffects_volume_heartbeat", "1", true, false, "Heartbeat volume", 0, 1)

local intensity_glitch = CreateClientConVar("threateffects_intensity_glitch", "1", true, false, "How much does effect intensity affect screen glitches", 0, 1)
local intensity_vignette = CreateClientConVar("threateffects_intensity_vignette", "1", true, false, "How much does effect intensity affect screen vignette", 0, 1)
local intensity_heartbeat = CreateClientConVar("threateffects_intensity_heartbeat", "1", true, false, "How much does effect intensity affect heartbeat sound", 0, 1)
local intensity_glitchsound = CreateClientConVar("threateffects_intensity_glitchsound", "1", true, false, "How much does effect intensity affect sound glitches", 0, 1)


local intensity, time = 0, 0
local function calc_delta()
    return math.ease.InOutQuad(((math.sin(time * 5) + 1) / 2 - 0.5)) * intensity
end

local function NPCIsViolent(ent)
    return ({
        -- combine
        npc_combine_s = true,
        CombinePrison = true,
        PrisonShotgunner = true,
        ShotgunSoldier = true,
        npc_metropolice = true,
        npc_hunter = true,
        npc_manhack = true,
        npc_rollermine = true,
        npc_turret_floor = true,
        npc_turret_ceiling = true,
        npc_strider = true,

        -- antlions
        npc_antlion = true,
        npc_antlion_worker = true,
        npc_antlionguard = true,
        npc_antlionguardian = true,

        -- xenians
        npc_barnacle = true,
        npc_headcrab = true,
        npc_zombie = true,
        npc_zombie_torso = true,
        npc_zombine = true,
        npc_headcrab_fast = true,
        npc_fastzombie = true,
        npc_fastzombie_torso = true,
        npc_headcrab_black = true,
        npc_poisonzombie = true,
        
        -- some easter eggs
        npc_gman = true, -- gman, bad guy
        npc_mossman = true, -- traitor !!!
        npc_breen = true, -- average earth surrender enjoyer
    })[ent:GetClass()] ~= nil
end

local function __low_pitch(x)
    if x <= 0.112 then return 0 end
    if x >= 0.320 then return 1 end
    return (x-0.112) / 0.208
end
local function __low_volume(x)
    if x <= 0.208 then return x / 0.208 * 0.22 end
    if x <= 0.408 then return __low_volume(0.208) + (x - 0.208) / 0.26 end
    if x <= 0.640 then return __low_volume(0.408) end
    return __low_volume(0.640) - (x-0.640)*(x-0.640)*7.5
end

local function __med_volume(x)
    if x <= 0.240 then return 0 end
    if x <= 0.640 then return (x-0.240) / 0.80 end
    if x <= 0.740 then local a = ((x-0.640)/0.150) return __med_volume(0.640) + a*a*a end
    return 1
end
local function __med_pitch(x)
    if x <= 0.240 then return 0 end
    if x <= 0.640 then local a = (x-0.240)/0.4 return a*a*a end
    return 1
end

local function __high_volume(x)
    if x <= 0.800 then return 0 end
    return (x-0.800) / 0.200
end

local last_low, last_med, last_high, duration = nil, nil, nil, 0
local function do_glitch_sound()
    local ply = LocalPlayer()
    local low_pitch, low_volume = (__low_pitch(intensity * intensity_glitchsound:GetFloat()) * 13.9) - 12.5, __low_volume(intensity * intensity_glitchsound:GetFloat())
    local med_pitch, med_volume = (__med_pitch(intensity * intensity_glitchsound:GetFloat()) * 13.9) - 12.5, __med_volume(intensity * intensity_glitchsound:GetFloat())
    local high_volume = __high_volume(intensity * intensity_glitchsound:GetFloat())

    local low, med, high

    while low == last_low or low == nil do low = "gui/threateffects/glitch/glitch_low_"..math.random(1, 29)..".wav" end
    last_low = low
    while med == last_med or med == nil do med = "gui/threateffects/glitch/glitch_med_"..math.random(1, 21)..".wav" end
    last_med = med
    while high == last_high or high == nil do high = "gui/threateffects/glitch/glitch_high_"..math.random(1, 40)..".wav" end
    last_high = high

    duration = CurTime() + math.max(SoundDuration(low), SoundDuration(med), SoundDuration(high))

    ply:EmitSound(low, 75, 100 + low_pitch*5, low_volume * 0.25 * volume_glitch:GetFloat(), CHAN_STATIC, SND_CHANGE_PITCH)
    ply:EmitSound(med, 75, 100 + med_pitch*5, med_volume * 0.15 * volume_glitch:GetFloat(), CHAN_STATIC, SND_CHANGE_PITCH)
    ply:EmitSound(high, 75, 100, high_volume * 0.1 * volume_glitch:GetFloat(), CHAN_STATIC)
end

local old_health = 0

hook.Add("PreRender", "ThreatEffects", function()
    if not enabled:GetBool() then return end
    if duration - CurTime() < 0 then do_glitch_sound() end
    local ply = LocalPlayer()
    local intensity_real = 0

    -- do glitches on damage
    if old_health > ply:Health() then
        intensity = intensity + ((100 - ply:Health()) / 25) * factor_damage:GetFloat()
    end
    old_health = ply:Health()
    
    -- NEVER do glitches when dead
    if not ply:Alive() then
        intensity_real = -100
    end
    
    -- falling effect
    if (ply:GetMoveType() ~= 8 or ply:InVehicle()) and ply:GetVelocity():LengthSqr() > 650*650 then
        intensity_real = intensity_real + math.max(0, math.min(1, (ply:GetVelocity():Length()-650) / 1500)) * factor_speed:GetFloat()
    end

    do -- glitches when close to enemy
        local entities = ents.FindInSphere(ply:EyePos(), factor_violentnpc_radius:GetFloat())
        local found = {}
        local customs = factor_violentnpc_list:GetString():Split(";")
        for _, ent in ipairs(entities) do
            local included = table.HasValue(customs, ent:GetClass())
                or ent:IsNextBot()
                or (ent:IsNPC() and NPCIsViolent(ent))

            if included then
                found[#found + 1] = ent
            end
        end 

        table.sort(found, function(e1, e2)
            return e1:GetPos():DistToSqr(ply:EyePos()) < e2:GetPos():DistToSqr(ply:EyePos())
        end)

        local factor = 0

        for _, ent in ipairs(found) do
            if _-1 >= factor_violentnpc_count:GetInt() then break end
            factor = factor + math.max(0, 1 - ent:GetPos():Distance(ply:EyePos()) / factor_violentnpc_radius:GetFloat()) / factor_violentnpc_count:GetInt()
        end
        
        intensity_real = intensity_real + factor * factor_violentnpc:GetFloat()
    end

    -- do glitches when low on health
    if ply:Health() < 50 then
        intensity_real = intensity_real + ((100 - ply:Health()) / 150) * factor_health:GetFloat()
    end
    
    -- do glitches when looking into the abyss
    if ply:GetVelocity():LengthSqr() < 650*650 and ply:EyeAngles().p > 60 then
        local ang = ply:EyeAngles()
        ang.p = 0
        intensity_real = intensity_real + 
            ((math.log(util.QuickTrace(ply:GetPos() + ang:Forward()*50, Vector(0, 0, -32767), ply).HitPos:Distance(ply:GetPos()) / 52) / 22)
            * (ply:EyeAngles().p - 60) / 20) * factor_height:GetFloat()
    end

    intensity_real = intensity_real * intensity_mul:GetFloat()

    intensity_real = intensity_real + intensity_const:GetFloat()
    
    intensity = math.max(0, math.min(math.Approach(intensity, intensity_real, FrameTime()), 1))
    time = time + FrameTime() * intensity * 2 * time_mul:GetFloat()
end)

-- Found Footage integration: threat FOV modulation removed so the
-- found-footage camera remains the sole CalcView owner.

local glitchmat = Material("gui/threateffects/screen_edgedistort")
local vignette =  Material("gui/threateffects/vignette.png")

local wastime = -1

local heartbeat_last = 0
hook.Add("RenderScreenspaceEffects", "ThreatEffects", function()
    render.UpdateScreenEffectTexture()
    if not enabled:GetBool() then return end
    if heartbeat_last + (1.25-intensity) <= CurTime() then
        heartbeat_last = CurTime()
        LocalPlayer():EmitSound("gui/threateffects/heartbeat/heartbeat_"..math.random(1,8)..".wav", 75,
                                100+math.random(-20, 20)*intensity_heartbeat:GetFloat(),
                                intensity*2*intensity_heartbeat:GetFloat()*volume_heartbeat:GetFloat())
    end
    local delta = calc_delta()

    if wastime ~= math.floor(((time-1) * 5) / (math.pi)) and delta > 0 then
        wastime = math.floor(((time-1) * 5) / (math.pi))
    end
    
    glitchmat:SetFloat("$refractamount", delta * -0.2 * intensity_glitch:GetFloat())
    local mov = math.random(-30*intensity, 30*intensity)
    for i=1,250*intensity*intensity_glitch:GetFloat(),1 do
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(glitchmat)
        local x = math.floor(util.SharedRandom("ThreatEffects_X_"..i, 0, math.floor(ScrW()/64)-1, math.floor((time * 5) / (math.pi))))
        local y = math.floor(util.SharedRandom("ThreatEffects_Y_"..i, 0, math.floor(ScrH()/16)-1, math.floor((time * 5) / (math.pi))))
        surface.DrawTexturedRect(x*64+mov*delta*intensity_glitch:GetFloat(), y*16, 64, 16)
    end

    surface.SetMaterial(vignette)
    surface.SetDrawColor(255, 255, 255, (127+63*delta)*intensity*intensity_vignette:GetFloat())
    surface.DrawTexturedRect(-1, -1, ScrW()+1, ScrH()+1)
end)