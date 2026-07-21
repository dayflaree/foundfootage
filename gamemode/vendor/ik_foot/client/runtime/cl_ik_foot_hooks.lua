if SERVER then return end
if not IKFoot or not IKFoot.Runtime then return end

local RT = IKFoot.Runtime
local RESET_COOLDOWN = 0.5

hook.Add("PostPlayerDraw", "IKFoot_PostPlayerDraw", function(ply)
	-- the main ik hook. runs every frame for every player. no pressure
	if not IsValid(ply) then return end

	-- detect death/respawn and hard reset to prevent bone distortion
	local alive = ply:Alive()
	if ply.IKWasAlive == false and alive then
		RT.Apply.HardResetPlayer(ply)
		ply.IKWasAlive = alive
		return
	end
	ply.IKWasAlive = alive

	if not alive then
		RT.Apply.ResetPlayer(ply)
		return
	end

	local bones = RT.GetIKBones(ply)
	if not RT.GetIKParamBool(ply, "enabled") then
		RT.Apply.ResetPlayer(ply, bones)
		return
	end

	if not RT.CanManipulateBones(ply) then
		RT.Apply.ResetPlayer(ply, bones)
		return
	end

	if not bones.lFoot or not bones.rFoot or not bones.lCalf or not bones.rCalf or not bones.lThigh or not bones.rThigh then
		RT.Apply.ResetPlayer(ply, bones)
		return
	end

	-- detect model swap and fix settings before everything looks cursed
	if ply == LocalPlayer() then
		local currentModel = ply:GetModel()
		if ply.IKLastKnownModel ~= currentModel then
			ply.IKLastKnownModel = currentModel
			IKFoot.InvalidateModelCache(currentModel)
			if RT.GetIKParamBool(ply, "auto_model_detect") then
				timer.Simple(0.15, function()
					if IsValid(ply) then
						IKFoot.AutoApplyModelSettings(ply)
					end
				end)
			end
		end
	end

	RT.Apply.StripIKFromBones(ply, bones)
	ply:SetupBones()

	local ok, errOrResult = pcall(function()
		local skeleton = RT.Apply.BuildSkeleton(ply, bones)
		if not skeleton then return nil end

		local result = RT.Controller.Calculate(ply, skeleton)
		if not result then return nil end

		RT.Apply.ApplyResult(ply, bones, result)
		return result
	end)

	if not ok then
		-- ik pipeline exploded. if it keeps failing we give up and reset
		ply.IKFailCount = (ply.IKFailCount or 0) + 1
		if ply.IKFailCount >= 5 and ply.IKFailCount < 10 then
			RT.State.SoftRecover(ply)
		elseif ply.IKFailCount >= 10 and ply.IKFailCount < 15 then
			if (ply.IKLastResetTime or 0) + RESET_COOLDOWN <= CurTime() then
				RT.Apply.ResetPlayer(ply, bones)
				ply.IKLastResetTime = CurTime()
			end
		elseif ply.IKFailCount >= 15 then
			if (ply.IKLastResetTime or 0) + RESET_COOLDOWN <= CurTime() then
				RT.Apply.HardResetPlayer(ply)
				ply.IKLastResetTime = CurTime()
			end
			ply.IKFailCount = 0
		end
		return
	end

	local result = errOrResult
	if not result then
		-- skeleton came back empty. probably loading or something idk
		ply.IKFailCount = (ply.IKFailCount or 0) + 1
		if ply.IKFailCount >= 6 and ply.IKFailCount < 12 then
			RT.State.SoftRecover(ply)
		elseif ply.IKFailCount >= 12 then
			if (ply.IKLastResetTime or 0) + RESET_COOLDOWN <= CurTime() then
				RT.Apply.ResetPlayer(ply, bones)
				ply.IKLastResetTime = CurTime()
			end
			ply.IKFailCount = 0
		end
		return
	end

	ply.IKFailCount = 0

	local debugCvar = RT.CVars.debug
	if debugCvar and debugCvar:GetInt() > 0 then
		RT.Controller.DrawDebug(ply, result)
	end
end)

hook.Add("HUDPaint", "IKFoot_Debug2D", function()
	local debugCvar = RT.CVars and RT.CVars.debug
	if not debugCvar or debugCvar:GetInt() <= 0 then return end

	local debug2D = RT.Debug2D
	if not debug2D or not debug2D.lines then return end
	if (debug2D.expireAt or 0) < CurTime() then return end

	local x, y = 24, 92
	local lineH = 18
	local width = 0
	surface.SetFont("DermaDefaultBold")

	for _, line in ipairs(debug2D.lines) do
		local tw = surface.GetTextSize(line)
		width = math.max(width, tw)
	end

	local height = (#debug2D.lines * lineH) + 16
	draw.RoundedBox(6, x - 10, y - 8, width + 20, height, Color(15, 18, 24, 210))

	for idx, line in ipairs(debug2D.lines) do
		draw.SimpleText(line, "DermaDefaultBold", x, y + (idx - 1) * lineH, Color(220, 230, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end)
