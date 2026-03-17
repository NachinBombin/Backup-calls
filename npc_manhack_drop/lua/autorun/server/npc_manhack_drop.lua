-- ============================================================
-- NPC Manhack Drop | npc_manhack_drop.lua
-- Shared file (SERVER logic + CLIENT light).
-- ============================================================

util.AddNetworkString("NPCManhackDrop_CanSpawned")

if SERVER then
	AddCSLuaFile()

	local SHARED_FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)
	local cv_enabled = CreateConVar("npc_manhackdrop_enabled", "1", SHARED_FLAGS, "Enable/disable Manhack Drop calls.")
	local cv_chance = CreateConVar("npc_manhackdrop_chance", "0.05", SHARED_FLAGS, "Probability (0-1) per check.")
	local cv_interval = CreateConVar("npc_manhackdrop_interval", "15", SHARED_FLAGS, "Seconds between checks.")
	local cv_cooldown = CreateConVar("npc_manhackdrop_cooldown", "90", SHARED_FLAGS, "Cooldown per NPC.")
	local cv_max_dist = CreateConVar("npc_manhackdrop_max_dist", "4000", SHARED_FLAGS, "Max distance to player.")
	local cv_min_dist = CreateConVar("npc_manhackdrop_min_dist", "500", SHARED_FLAGS, "Min distance to player.")
	local cv_announce = CreateConVar("npc_manhackdrop_announce", "0", SHARED_FLAGS, "Debug prints.")

	local CALLERS = {
		["npc_combine_s"] = true,
		["npc_metropolice"] = true,
		["npc_combine_elite"] = true,
	}

	local function CheckSkyAbove(pos)
		local trace = util.TraceLine({
			start = pos + Vector(0, 0, 50),
			endpos = pos + Vector(0, 0, 1050),
		})
		if trace.Hit and not trace.HitSky then
			trace = util.TraceLine({
				start = trace.HitPos + Vector(0, 0, 50),
				endpos = trace.HitPos + Vector(0, 0, 1000),
			})
		end
		return not (trace.Hit and not trace.HitSky), trace
	end

	local function FireManhackDrop(npc, target)
		local skyOpen, skyTrace = CheckSkyAbove(target:GetPos())
		if not skyOpen then return false end -- Jet requires sky

		local eyeTrace = {
			StartPos = npc:GetPos(),
			HitPos = target:GetPos(),
		}

		-- Toss the flare
		local targetPos = target:GetPos() + Vector(0, 0, 36)
		local npcEyePos = npc:EyePos()
		local toTarget = (targetPos - npcEyePos):GetNormalized()

		-- Kept as blue flare. If you have a red variant, you can change this to "ent_bombin_flare_red"
		local can = ents.Create("ent_bombin_flare_blue")
		if IsValid(can) then
			can:SetPos(npcEyePos + toTarget * 52)
			can:SetAngles(npc:GetAngles())
			can:Spawn()
			can:Activate()

			local dir = (targetPos - can:GetPos())
			local dist = dir:Length()
			dir:Normalize()

			timer.Simple(0, function()
				if IsValid(can) then
					local phys = can:GetPhysicsObject()
					if IsValid(phys) then
						phys:SetVelocity(dir * 700 + Vector(0, 0, dist * 0.25))
						phys:Wake()
					end
				end
			end)

			net.Start("NPCManhackDrop_CanSpawned")
			net.WriteEntity(can)
			net.Broadcast()
		end

		-- Call the F-4E to drop the washing machine container
		timer.Simple(5, function()
			if not gred or not gred.STRIKE then return end
			-- Parameters: ply, tr, eyeTrace, sound, plane model, bomb entity class, amount, spread, interval, planes, use_physics
			-- Ensure "ent_manhack_washer" matches the exact folder name of your new container entity
			gred.STRIKE.BOMBER(npc, skyTrace, eyeTrace,
				"artillery/flyby/f4_napalm.ogg",
				"models/gredwitch/static/f4.mdl",
				"ent_manhack_washer", 1, 0, 11, 1, true)
		end)

		if cv_announce:GetBool() then
			print("[Manhack Drop] Called on " .. target:Nick())
		end

		return true
	end

	timer.Create("NPCManhackDrop_Think", 0.5, 0, function()
		if not cv_enabled:GetBool() then return end
		if not gred or not gred.STRIKE then return end

		local now = CurTime()
		for _, npc in ipairs(ents.GetAll()) do
			if not IsValid(npc) or not CALLERS[npc:GetClass()] then continue end

			if not npc.__manhackdrop_hooked then
				npc.__manhackdrop_hooked = true
				npc.__manhackdrop_nextCheck = now + math.Rand(1, cv_interval:GetFloat())
				npc.__manhackdrop_lastCall = 0
			end

			if now < npc.__manhackdrop_nextCheck then continue end
			npc.__manhackdrop_nextCheck = now + cv_interval:GetFloat() + math.Rand(-2, 2)

			if now - npc.__manhackdrop_lastCall < cv_cooldown:GetFloat() then continue end
			if npc:Health() <= 0 then continue end

			local enemy = npc:GetEnemy()
			if not IsValid(enemy) or not enemy:IsPlayer() or not enemy:Alive() then continue end

			local dist = npc:GetPos():Distance(enemy:GetPos())
			if dist > cv_max_dist:GetFloat() or dist < cv_min_dist:GetFloat() then continue end

			if math.random() > cv_chance:GetFloat() then continue end

			if FireManhackDrop(npc, enemy) then
				npc.__manhackdrop_lastCall = now
			end
		end
	end)
end

if CLIENT then
	local activeFlares = {}
	net.Receive("NPCManhackDrop_CanSpawned", function()
		local flare = net.ReadEntity()
		if IsValid(flare) then activeFlares[flare:EntIndex()] = flare end
	end)

	hook.Add("Think", "NPCManhackDrop_FlareLight", function()
		for idx, flare in pairs(activeFlares) do
			if not IsValid(flare) then
				activeFlares[idx] = nil
				continue
			end
			local dlight = DynamicLight(flare:EntIndex())
			if dlight then
				dlight.Pos = flare:GetPos()
				-- Flare color (Blue). Change to red by using 255, 0, 0 if preferred
				dlight.r, dlight.g, dlight.b = 0, 80, 255
				dlight.Brightness = (math.random() > 0.4) and math.Rand(4.0, 6.0) or math.Rand(0.0, 0.2)
				dlight.Size = 55
				dlight.Decay = 3000
				dlight.DieTime = CurTime() + 0.05
			end
		end
	end)
end
