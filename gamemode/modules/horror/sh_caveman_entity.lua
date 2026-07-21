local config = ((FF_CONFIG or {}).Horror or {}).Caveman or {}
local entityClass = tostring(config.Class or "backrooms_caveman")

local ENTITY = {
    Type = "anim",
    Base = "base_gmodentity",

    PrintName = "Backrooms Caveman",
    Author = "Darvan; Found Footage integration",
    Information = "A static movie-accurate caveman cutout with a proximity greeting loop.",
    Category = "Found Footage",

    Spawnable = false,
    AdminOnly = false,

    ModelPath = "models/brmovie/caveman_brmovie.mdl",
    SoundName = "caveman/caveman_greetings.wav",
    SoundDuration = 265.17,
    SoundLevel = 75,
    SoundVolume = 0.65,
}

if SERVER then
    function ENTITY:Initialize()
        local configured = (((FF_CONFIG or {}).Horror or {}).Caveman or {}).Model
        local model = tostring(configured or self.ModelPath)

        self:SetModel(model)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local physics = self:GetPhysicsObject()
        if IsValid(physics) then
            physics:EnableMotion(false)
            physics:Sleep()
        else
            self:SetMoveType(MOVETYPE_NONE)
        end
    end

    function ENTITY:PhysgunPickup()
        return false
    end

    function ENTITY:CanTool()
        return false
    end
end

if CLIENT then
    local function timerName(entity)
        return "FF_CavemanGreetingLoop_" .. entity:EntIndex()
    end

    local function visualizerSourceId(entity)
        return "caveman_greeting_" .. entity:EntIndex()
    end

    function ENTITY:StartGreetingLoop()
        if self.SoundLoop then
            self.SoundLoop:Stop()
        end

        self.SoundLoop = CreateSound(self, self.SoundName)
        if not self.SoundLoop then return end

        self.SoundLoop:SetSoundLevel(self.SoundLevel or 75)
        self.SoundLoop:PlayEx(math.Clamp(self.SoundVolume or 0.65, 0, 1), 100)

        timer.Create(timerName(self), math.max(self.SoundDuration or 265.17, 1), 0, function()
            if not IsValid(self) then
                timer.Remove(timerName(self))
                return
            end

            if self.SoundLoop then
                self.SoundLoop:Stop()
                self.SoundLoop:PlayEx(math.Clamp(self.SoundVolume or 0.65, 0, 1), 100)
                self.SoundLoop:SetSoundLevel(self.SoundLevel or 75)
            end
        end)
    end

    function ENTITY:Initialize()
        self:StartGreetingLoop()
    end

    function ENTITY:Think()
        local playing = self.SoundLoop
            and self.SoundLoop.IsPlaying
            and self.SoundLoop:IsPlaying()

        if playing and FF_SetAudioVisualizerSoundSource then
            FF_SetAudioVisualizerSoundSource(
                visualizerSourceId(self),
                self.SoundName,
                self.SoundVolume,
                self.SoundLevel,
                self:WorldSpaceCenter(),
                self
            )
        elseif FF_ClearAudioVisualizerSoundSource then
            FF_ClearAudioVisualizerSoundSource(visualizerSourceId(self))
        end

        self:NextThink(CurTime() + 0.1)
        return true
    end

    function ENTITY:OnRemove()
        if self.SoundLoop then
            self.SoundLoop:Stop()
            self.SoundLoop = nil
        end
        if FF_ClearAudioVisualizerSoundSource then
            FF_ClearAudioVisualizerSoundSource(visualizerSourceId(self))
        end

        timer.Remove(timerName(self))
    end

    function ENTITY:Draw()
        self:DrawModel()
    end
end

function FF_RegisterCavemanEntity()
    scripted_ents.Register(ENTITY, entityClass)
    return scripted_ents.GetStored(entityClass) ~= nil
end

local registered = FF_RegisterCavemanEntity()

if SERVER then
    if not registered then
        ErrorNoHalt("[Found Footage Caveman] Failed to register entity class: " .. entityClass .. "\n")
    end
end
