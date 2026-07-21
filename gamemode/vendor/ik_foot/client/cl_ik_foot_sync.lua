if SERVER then return end
if not IKFoot or not IKFoot.Config then return end

local lastConfigSync = 0
local lastSignature = nil
local configUpdateMessageName = "IKFoot_ConfigUpdate"
local configProtocolVersion = 1

local function ReadEntryValue(entry)
	local cvar = GetConVar(entry.cvar)
	if not cvar then
		return entry.default
	end

	if entry.type == "bool" then
		return cvar:GetBool()
	end

	return IKFoot.Config.ClampNumber(entry, cvar:GetFloat())
end

local function BuildSyncPayload()
	local payload = {}
	local signatureParts = {}

	for _, entry in ipairs(IKFoot.Config.entries) do
		local value = ReadEntryValue(entry)
		payload[#payload + 1] = {
			entry = entry,
			value = value,
		}

		signatureParts[#signatureParts + 1] = string.format("%s=%s", entry.key, tostring(value))
	end

	return payload, table.concat(signatureParts, "|")
end

hook.Add("Think", "IKFoot_SyncConfigToServer", function()
	local now = UnPredictedCurTime()
	if now - lastConfigSync < 0.5 then return end
	lastConfigSync = now

	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if util.NetworkStringToID(configUpdateMessageName) == 0 then return end

	local payload, signature = BuildSyncPayload()
	if signature == lastSignature then return end

	net.Start(configUpdateMessageName)
	net.WriteUInt(configProtocolVersion, 8)
	net.WriteUInt(#payload, 8)
	for _, item in ipairs(payload) do
		if item.entry.type == "bool" then
			net.WriteBool(item.value and true or false)
		else
			net.WriteFloat(item.value)
		end
	end
	net.SendToServer()

	lastSignature = signature
end)