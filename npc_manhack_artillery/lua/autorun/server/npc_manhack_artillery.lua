-- ============================================================
-- NPC Manhack Artillery | npc_manhack_artillery.lua
-- Shared file (SERVER logic + CLIENT light).
-- ============================================================

util.AddNetworkString("NPCManhackArt_CanSpawned")

if SERVER then
	AddCSLuaFile()

	local SHARED_FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)
	local cv_enabled = CreateConVar("npc_manhackart_enabled", "1", SHARED_FLAGS, "Enable/disable calls.")
	local cv_chance = CreateConVar("npc_manhackart_chance", "0.12", SHARED_FLAGS, "Probability per check.")
	local cv_interval = CreateConVar("npc_manhackart_interval", "12", SHARED_FLAGS, "Check interval.")
	local cv_cooldown = CreateConVar("npc_manhackart_cooldown", "50", SHARED_FLAGS, "Cooldown.")
	local cv_max_dist = CreateConVar("npc_manhackart_max_dist", "3000", SHARED_FLAGS, "Max distance.")
	local cv_min_dist = CreateConVar("npc_manhackart_min_dist", "400", SHARED_FLAGS, "Min distance.")
	local cv_announce = CreateConVar("npc_manhackart_announce", "0", SHARED_FLAGS, "Debug prints.")

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
		return not (trace.Hit and not trace.HitSky)
	end

	local FIRE_SOUNDS = {
		"artillery/far/distant_artillery_fire_01.wav",
		"artillery/far/distant_artillery_fire_02.wav",
		"artillery/far/distant_artillery_fire_03.wav",
		"artillery/far/distant_artillery_fire_04.wav",
	}

	local WHISTLE_SOUNDS = {
		"artillery/flyby/artillery_strike_incoming_01.wav",
		"artillery/flyby/artillery_strike_incoming_02.wav",
		"artillery/flyby/artillery_strike_incoming_03.wav",
		"artillery/flyby/artillery_strike_incoming_04.wav",
	}

	local function FireManhackBarrage(npc, target)
		local skyOpen = CheckSkyAbove(target:GetPos())
		if not skyOpen then return false end

		-- Toss the flare
		local targetPos = target:GetPos() + Vector(0, 0, 36)
		local npcEyePos = npc:EyePos()
		local toTarget = (targetPos - npcEyePos):GetNormalized()

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

			net.Start("NPCManhackArt_CanSpawned")
			net.WriteEntity(can)
			net.Broadcast()
		end

		-- ============================================================
		-- NEW: 3 SECOND GLOBAL DELAY BEFORE EVENT BEGINS
		-- ============================================================
		timer.Simple(5, function()
			
			local trHitPos = target:GetPos()
			local rounds = math.random(24, 30)
			local spread = 1200
			
			sound.Play("ambient/explosions/battle_loop1.wav", trHitPos, 140, 100, 0.6)
			
			for i = 1, rounds do
				local shotDelay = i * math.Rand(0.2, 0.5)
				
				timer.Simple(shotDelay, function()
					net.Start("gred_net_artiplaysound")
					net.WriteString(table.Random(FIRE_SOUNDS))
					net.Broadcast()

					local dropPos = trHitPos + Vector(math.Rand(-spread, spread), math.Rand(-spread, spread), 3500)
					
					local snd = table.Random(WHISTLE_SOUNDS)
					local sndDuration = SoundDuration(snd)
					
					local timeToFall = (3500 / 1500) + (sndDuration - 0.2)
					
					timer.Simple(4, function()
						local p = ents.Create("prop_dynamic")
						p:SetModel("models/hunter/blocks/cube025x025x025.mdl")
						p:SetPos(dropPos - Vector(0, 0, 3400)) 
						p:Spawn()
						p:SetRenderMode(RENDERMODE_TRANSALPHA)
						p:SetColor(Color(0,0,0,0))
						p:EmitSound(snd, 140, 100, 1)
						p:Remove()

						timer.Simple(timeToFall, function()
							local canister = ents.Create("ent_manhack_canister")
							if IsValid(canister) then
								canister:SetPos(dropPos)
								canister:SetAngles(Angle(math.random(-45, 45), math.random(0, 360), math.random(-45, 45)))
								canister:Spawn()
								canister:Activate()
								
								local phys = canister:GetPhysicsObject()
								if IsValid(phys) then
									phys:Wake()
									phys:SetVelocityInstantaneous(Vector(0, 0, -1500))
								end
							end
						end)
					end)
				end)
			end

			if cv_announce:GetBool() then
				print("[Manhack Artillery] Called on " .. target:Nick() .. " (" .. rounds .. " rounds)")
			end

		end) -- End of 3 second wrapper
		return true
	end

	timer.Create("NPCManhackArt_Think", 0.5, 0, function()
		if not cv_enabled:GetBool() then return end

		local now = CurTime()
		for _, npc in ipairs(ents.GetAll()) do
			if not IsValid(npc) or not CALLERS[npc:GetClass()] then continue end

			if not npc.__manhackart_hooked then
				npc.__manhackart_hooked = true
				npc.__manhackart_nextCheck = now + math.Rand(1, cv_interval:GetFloat())
				npc.__manhackart_lastCall = 0
			end

			if now < npc.__manhackart_nextCheck then continue end
			npc.__manhackart_nextCheck = now + cv_interval:GetFloat() + math.Rand(-2, 2)

			if now - npc.__manhackart_lastCall < cv_cooldown:GetFloat() then continue end
			if npc:Health() <= 0 then continue end

			local enemy = npc:GetEnemy()
			if not IsValid(enemy) or not enemy:IsPlayer() or not enemy:Alive() then continue end

			local dist = npc:GetPos():Distance(enemy:GetPos())
			if dist > cv_max_dist:GetFloat() or dist < cv_min_dist:GetFloat() then continue end

			if math.random() > cv_chance:GetFloat() then continue end

			if FireManhackBarrage(npc, enemy) then
				npc.__manhackart_lastCall = now
			end
		end
	end)
end

if CLIENT then
	local activeFlares = {}
	net.Receive("NPCManhackArt_CanSpawned", function()
		local flare = net.ReadEntity()
		if IsValid(flare) then activeFlares[flare:EntIndex()] = flare end
	end)

	hook.Add("Think", "NPCManhackArt_FlareLight", function()
		for idx, flare in pairs(activeFlares) do
			if not IsValid(flare) then
				activeFlares[idx] = nil
				continue
			end
			local dlight = DynamicLight(flare:EntIndex())
			if dlight then
				dlight.Pos = flare:GetPos()
				dlight.r, dlight.g, dlight.b = 0, 80, 255
				dlight.Brightness = (math.random() > 0.4) and math.Rand(4.0, 6.0) or math.Rand(0.0, 0.2)
				dlight.Size = 55
				dlight.Decay = 3000
				dlight.DieTime = CurTime() + 0.05
			end
		end
	end)
end
