if CLIENT then return end
if not IKFoot or not IKFoot.Config then return end

local CONFIG_MESSAGE = "IKFoot_ConfigUpdate"
local OPEN_MENU_NET = "IKFoot_OpenMenu"
local CONFIG_PROTOCOL_VERSION = 1
local CONFIG_UPDATE_INTERVAL = 0.1
local nextAllowedConfigUpdate = {}

util.AddNetworkString(CONFIG_MESSAGE)
util.AddNetworkString(OPEN_MENU_NET)

local function ApplyEntryToPlayer(ply, entry, value)
	local nwName = IKFoot.Config.NWName(entry.key)

	if entry.type == "bool" then
		ply:SetNWBool(nwName, value and true or false)
		return
	end

	ply:SetNWFloat(nwName, IKFoot.Config.ClampNumber(entry, value))
end

net.Receive(CONFIG_MESSAGE, function(_, ply)
	if not IsValid(ply) then return end
	local now = CurTime()
	if now < (nextAllowedConfigUpdate[ply] or 0) then return end
	nextAllowedConfigUpdate[ply] = now + CONFIG_UPDATE_INTERVAL

	local protocolVersion = net.ReadUInt(8)
	if protocolVersion ~= CONFIG_PROTOCOL_VERSION then return end

	local fieldCount = net.ReadUInt(8)
	if fieldCount ~= #IKFoot.Config.entries then return end

	for _, entry in ipairs(IKFoot.Config.entries) do
		if entry.type == "bool" then
			ApplyEntryToPlayer(ply, entry, net.ReadBool())
		else
			ApplyEntryToPlayer(ply, entry, net.ReadFloat())
		end
	end
end)

hook.Add("PlayerDisconnected", "IKFoot_ClearRateLimit", function(ply)
	nextAllowedConfigUpdate[ply] = nil
end)

hook.Add("PlayerInitialSpawn", "IKFoot_InitDefaults", function(ply)
	for _, entry in ipairs(IKFoot.Config.entries) do
		ApplyEntryToPlayer(ply, entry, entry.default)
	end
end)

hook.Add("PlayerSay", "IKFoot_ChatOpenMenu", function(ply, text)
	if not IsValid(ply) or not isstring(text) then return end

	local normalized = string.Trim(string.lower(text))
	if normalized ~= "!ikfoot" and normalized ~= "/ikfoot" then return end

	net.Start(OPEN_MENU_NET)
	net.Send(ply)

	return ""
end)