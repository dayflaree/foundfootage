---@diagnostic disable: undefined-field, inject-field

local enabled = CreateClientConVar("threateffects_fall_enabled", "1", true, false, "Enable Fall Threat Effects", 0, 1)
local alarm_enabled = CreateClientConVar("threateffects_fall_alarm", "1", true, false, "Do falling alarm", 0, 1)
local pant_enabled = CreateClientConVar("threateffects_fall_panting", "1", true, false, "Do falling panting", 0, 1)
local pant_volume = CreateClientConVar("threateffects_fall_pantvolume", "1", true, false, "Panting volume", 0, 1)
local alrm_high_req = CreateClientConVar("threateffects_fall_alarmhigh", "0.95", true, false, "High alarm cooficient", 0, 1)
local alarm_volume = CreateClientConVar("threateffects_fall_alarmvolume", "0.5", true, false, "Alarm volume", 0, 1)

local function do_alarm(ply, strength)
    if strength < alrm_high_req:GetFloat() then
        if ply.threateffects_emitting_alarmhigh then
            ply.threateffects_emitting_alarmhigh = false
            return ply:StopSound("gui/threateffects/fall/alarm_high.wav")
        end
        if ply.threateffects_emitting_alarmlow then return end
        ply:EmitSound("gui/threateffects/fall/alarm_low.wav", 75, 100, alarm_volume:GetFloat())
        ply.threateffects_emitting_alarmlow = true
    else
        if ply.threateffects_emitting_alarmlow then
            ply.threateffects_emitting_alarmlow = false
            return ply:StopSound("gui/threateffects/fall/alarm_low.wav")
        end
        if ply.threateffects_emitting_alarmhigh then return end
        ply:EmitSound("gui/threateffects/fall/alarm_high.wav", 75, 100, alarm_volume:GetFloat())
        ply.threateffects_emitting_alarmhigh = true
    end
end

local function do_pant(ply, strength)
    local level = math.floor(strength * 4) + 1
    if ply.threateffects_emitting_pant_level == level then return end
    ply:StopSound("gui/threateffects/fall/panting_1.wav")
    ply:StopSound("gui/threateffects/fall/panting_2.wav")
    ply:StopSound("gui/threateffects/fall/panting_3.wav")
    ply:StopSound("gui/threateffects/fall/panting_4.wav")
    ply:StopSound("gui/threateffects/fall/panting_5.wav")
    ply:EmitSound("gui/threateffects/fall/panting_"..level..".wav", 75, 100, pant_volume:GetFloat())
    ply.threateffects_emitting_pant_level = level
end

local function undo(ply, pant, alarm)
    if pant and ply.threateffects_emitting_pant_level ~= 1 then
        ply:StopSound("gui/threateffects/fall/panting_2.wav")
        ply:StopSound("gui/threateffects/fall/panting_3.wav")
        ply:StopSound("gui/threateffects/fall/panting_4.wav")
        ply:StopSound("gui/threateffects/fall/panting_5.wav")
        if ply:Alive() then
            ply:EmitSound("gui/threateffects/fall/panting_1.wav", 75, 100, pant_volume:GetFloat())
        else
            ply:StopSound("gui/threateffects/fall/panting_1.wav")
        end
        ply.threateffects_emitting_pant_level = 1
    end

    if alarm and ply.threateffects_emitting_alarmlow then
        ply.threateffects_emitting_alarmlow = false
        ply:StopSound("gui/threateffects/fall/alarm_low.wav")
    end
    if alarm and ply.threateffects_emitting_alarmhigh then
        ply.threateffects_emitting_alarmhigh = false
        ply:StopSound("gui/threateffects/fall/alarm_high.wav")
    end
end

hook.Add("PreRender", "ThreatEffects_FallEffects", function()
    local ply = LocalPlayer()
    if not enabled:GetBool() then return undo(ply, true, true) end
    if ply:GetMoveType() == 8 then return undo(ply, true, true) end
    if ply:InVehicle() then return undo(ply, true, true) end
    if ply:GetVelocity():LengthSqr() < 650*650 then return undo(ply, true, true) end
    local strength = math.max(0, math.min(1, (ply:GetVelocity():Length()-650) / 1500))
    if pant_enabled:GetBool() then
        do_pant(ply, strength)
    end
    if alarm_enabled:GetBool() then
        if strength > 0.5 then
            do_alarm(ply, (strength-0.5)*2)
        else
            undo(ply, false, true)
        end
    end
end)