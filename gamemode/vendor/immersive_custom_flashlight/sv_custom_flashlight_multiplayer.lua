
if not SERVER then return end

util.AddNetworkString("ICF_MP_State")
util.AddNetworkString("ICF_MP_State2")
util.AddNetworkString("ICF_MP_State3")
util.AddNetworkString("ICF_MP_State4")

CreateConVar(
    "sv_icf_multiplayer_visibility",
    "1",
    {FCVAR_ARCHIVE, FCVAR_REPLICATED},
    "Allow Immersive Custom Flashlight clients to relay experimental multiplayer flashlight visibility."
)

CreateConVar(
    "sv_icf_multiplayer_distance",
    "3500",
    {FCVAR_ARCHIVE, FCVAR_REPLICATED},
    "Maximum distance for relaying Immersive Custom Flashlight remote beams."
)

CreateConVar(
    "sv_icf_multiplayer_max_rate",
    "12",
    {FCVAR_ARCHIVE, FCVAR_REPLICATED},
    "Maximum network updates per second per player for Immersive Custom Flashlight remote beams."
)

local nextAllowedSend = {}

local function ICF_MP_SanitizeTexturePath(texturePath, fallback)
    fallback = fallback or "effects/flashlight001"
    texturePath = tostring(texturePath or fallback)

    if string.Trim then
        texturePath = string.Trim(texturePath)
    end

    texturePath = string.gsub(texturePath, "^materials/", "")
    texturePath = string.gsub(texturePath, "%.vmt$", "")
    texturePath = string.gsub(texturePath, "%.vtf$", "")
    texturePath = string.sub(texturePath, 1, 128)

    if texturePath == "" then return fallback end
    if string.find(texturePath, "\\", 1, true) or string.find(texturePath, "..", 1, true) or string.find(texturePath, ":", 1, true) then
        return fallback
    end

    if texturePath ~= "effects/flashlight001" and not string.find(texturePath, "^effects/lightspill/") then
        return fallback
    end

    return texturePath
end

local function ICF_MP_GetRecipients(sender, distance)
    local recipients = {}
    local senderPos = sender:GetPos()
    local maxDistSqr = distance * distance

    for _, ply in ipairs(player.GetAll()) do
        if ply ~= sender and IsValid(ply) and ply:Alive() and senderPos:DistToSqr(ply:GetPos()) <= maxDistSqr then
            recipients[#recipients + 1] = ply
        end
    end

    return recipients
end

local function ICF_MP_RelayState(_, ply, hasNetworkPos, hasLightspillData, hasBeamTexture)
    if not IsValid(ply) then return end

    local enabled = GetConVar("sv_icf_multiplayer_visibility")
    if enabled and not enabled:GetBool() then return end

    local now = CurTime()
    local maxRate = math.Clamp(GetConVar("sv_icf_multiplayer_max_rate"):GetFloat(), 2, 20)
    local nextTime = nextAllowedSend[ply] or 0

    if now < nextTime then
        return
    end

    nextAllowedSend[ply] = now + (1 / maxRate)

    local active = net.ReadBool()
    local dir = net.ReadVector()
    local beamPos = nil

    if hasNetworkPos then
        beamPos = net.ReadVector()
    else
        beamPos = ply:EyePos()
    end

    net.ReadUInt(8)
    net.ReadUInt(8)
    net.ReadUInt(8)
    -- Found Footage uses a fixed white beam. Client-provided colors are read
    -- for protocol compatibility and discarded.
    local r, g, b = 255, 255, 255
    local brightness = net.ReadFloat()
    local farz = net.ReadFloat()
    local fov = net.ReadFloat()
    local beamTexture = "effects/flashlight001"

    if hasBeamTexture then
        beamTexture = ICF_MP_SanitizeTexturePath(net.ReadString() or "effects/flashlight001", "effects/flashlight001")
    end

    local spillEnabled = false
    local spillTexture = "effects/lightspill/spill1"
    local spillBrightness = 0.24
    local spillSize = 1
    local spillFov = 112
    local spillFarz = 720
    local spillNearz = 8
    local spillForward = 5
    local spillRight = 0
    local spillUp = 0
    local spillR = 255
    local spillG = 255
    local spillB = 255

    if hasLightspillData then
        spillEnabled = net.ReadBool()

        if spillEnabled then
            spillTexture = string.sub(tostring(net.ReadString() or "effects/lightspill/spill1"), 1, 128)
            spillBrightness = math.Clamp(tonumber(net.ReadFloat()) or 0.24, 0, 4)
            spillSize = math.Clamp(tonumber(net.ReadFloat()) or 1, 0.25, 1.25)
            spillFov = math.Clamp(tonumber(net.ReadFloat()) or 112, 10, 140)
            spillFarz = math.Clamp(tonumber(net.ReadFloat()) or 720, 64, 4000)
            spillNearz = math.Clamp(tonumber(net.ReadFloat()) or 8, 2, 64)
            spillForward = math.Clamp(tonumber(net.ReadFloat()) or 5, -64, 64)
            spillRight = math.Clamp(tonumber(net.ReadFloat()) or 0, -64, 64)
            spillUp = math.Clamp(tonumber(net.ReadFloat()) or 0, -64, 64)
            net.ReadUInt(8)
            net.ReadUInt(8)
            net.ReadUInt(8)
            spillR, spillG, spillB = 255, 255, 255
        end
    end

    if string.find(spillTexture, "\\", 1, true) or string.find(spillTexture, "..", 1, true) or string.find(spillTexture, ":", 1, true) then
        spillTexture = "effects/lightspill/spill1"
    end

    if not ply:Alive() then
        active = false
    end

    if dir:LengthSqr() < 0.001 then
        dir = ply:EyeAngles():Forward()
    end

    dir:Normalize()

    brightness = math.Clamp(tonumber(brightness) or 1, 0.05, 10)
    farz = math.Clamp(tonumber(farz) or 1837, 128, 6000)
    fov = math.Clamp(tonumber(fov) or 40, 5, 140)

    local distance = math.Clamp(GetConVar("sv_icf_multiplayer_distance"):GetFloat(), 512, 8000)
    local recipients = ICF_MP_GetRecipients(ply, distance)

    if #recipients <= 0 then return end

    net.Start("ICF_MP_State")
        net.WriteEntity(ply)
        net.WriteBool(active)
        net.WriteVector(dir)
        net.WriteUInt(math.Clamp(r, 0, 255), 8)
        net.WriteUInt(math.Clamp(g, 0, 255), 8)
        net.WriteUInt(math.Clamp(b, 0, 255), 8)
        net.WriteFloat(brightness)
        net.WriteFloat(math.min(farz, distance))
        net.WriteFloat(fov)
    net.Send(recipients)

    net.Start("ICF_MP_State2")
        net.WriteEntity(ply)
        net.WriteBool(active)
        net.WriteVector(dir)
        net.WriteVector(beamPos or ply:EyePos())
        net.WriteUInt(math.Clamp(r, 0, 255), 8)
        net.WriteUInt(math.Clamp(g, 0, 255), 8)
        net.WriteUInt(math.Clamp(b, 0, 255), 8)
        net.WriteFloat(brightness)
        net.WriteFloat(math.min(farz, distance))
        net.WriteFloat(fov)
    net.Send(recipients)

    net.Start("ICF_MP_State3")
        net.WriteEntity(ply)
        net.WriteBool(active)
        net.WriteVector(dir)
        net.WriteVector(beamPos or ply:EyePos())
        net.WriteUInt(math.Clamp(r, 0, 255), 8)
        net.WriteUInt(math.Clamp(g, 0, 255), 8)
        net.WriteUInt(math.Clamp(b, 0, 255), 8)
        net.WriteFloat(brightness)
        net.WriteFloat(math.min(farz, distance))
        net.WriteFloat(fov)
        net.WriteBool(active and spillEnabled)

        if active and spillEnabled then
            net.WriteString(spillTexture)
            net.WriteFloat(spillBrightness)
            net.WriteFloat(spillSize)
            net.WriteFloat(spillFov)
            net.WriteFloat(math.min(spillFarz, distance))
            net.WriteFloat(spillNearz)
            net.WriteFloat(spillForward)
            net.WriteFloat(spillRight)
            net.WriteFloat(spillUp)
            net.WriteUInt(spillR, 8)
            net.WriteUInt(spillG, 8)
            net.WriteUInt(spillB, 8)
        end
    net.Send(recipients)

    net.Start("ICF_MP_State4")
        net.WriteEntity(ply)
        net.WriteBool(active)
        net.WriteVector(dir)
        net.WriteVector(beamPos or ply:EyePos())
        net.WriteUInt(math.Clamp(r, 0, 255), 8)
        net.WriteUInt(math.Clamp(g, 0, 255), 8)
        net.WriteUInt(math.Clamp(b, 0, 255), 8)
        net.WriteFloat(brightness)
        net.WriteFloat(math.min(farz, distance))
        net.WriteFloat(fov)
        net.WriteString(beamTexture)
        net.WriteBool(active and spillEnabled)

        if active and spillEnabled then
            net.WriteString(spillTexture)
            net.WriteFloat(spillBrightness)
            net.WriteFloat(spillSize)
            net.WriteFloat(spillFov)
            net.WriteFloat(math.min(spillFarz, distance))
            net.WriteFloat(spillNearz)
            net.WriteFloat(spillForward)
            net.WriteFloat(spillRight)
            net.WriteFloat(spillUp)
            net.WriteUInt(spillR, 8)
            net.WriteUInt(spillG, 8)
            net.WriteUInt(spillB, 8)
        end
    net.Send(recipients)
end

net.Receive("ICF_MP_State", function(len, ply)
    ICF_MP_RelayState(len, ply, false, false, false)
end)

net.Receive("ICF_MP_State2", function(len, ply)
    ICF_MP_RelayState(len, ply, true, false, false)
end)

net.Receive("ICF_MP_State3", function(len, ply)
    ICF_MP_RelayState(len, ply, true, true, false)
end)

net.Receive("ICF_MP_State4", function(len, ply)
    ICF_MP_RelayState(len, ply, true, true, true)
end)

hook.Add("PlayerDisconnected", "ICF_MP_ClearRateLimit", function(ply)
    nextAllowedSend[ply] = nil
end)
