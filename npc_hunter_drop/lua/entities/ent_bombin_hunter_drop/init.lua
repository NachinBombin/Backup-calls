AddCSLuaFile("shared.lua")
include("shared.lua")

if not SERVER then return end

function ENT:Initialize()
	self:SetModel("models/props_junk/TrashDumpster02.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableDrag(false)
	end

	self.HasLanded = false
end

function ENT:Think()
	if not self.HasLanded then
		local phys = self:GetPhysicsObject()
		if IsValid(phys) and phys:IsAsleep() then
			phys:Wake()
		end
		self:NextThink(CurTime() + 0.2)
		return true
	end
	return false
end

function ENT:PhysicsCollide(data, phys)
	if self.HasLanded then return end

	if data.Speed > 50 and data.HitNormal.z > 0.5 then
		self.HasLanded = true
		phys:EnableDrag(true)

		local hitNormal = data.HitNormal

		timer.Simple(0, function()
			if IsValid(self) and IsValid(phys) then
				phys:SetVelocity(Vector(0, 0, 0))
				phys:AddAngleVelocity(-phys:GetAngleVelocity())
				self:SetPos(self:GetPos() + hitNormal * 5)
				phys:Sleep()
			end
		end)

		-- Sequence begins 1 second after landing
		timer.Simple(1, function()
			if not IsValid(self) then return end

			-- Play the canister opening sounds once
			self:EmitSound("doors/heavy_metal_stop1.wav", 100, math.random(95, 105))
			self:EmitSound("physics/metal/metal_box_break1.wav", 100, 100)

			local flatAngle = Angle(0, self:GetAngles().y, 0)

			-- CALMLY SPAWN THE GAS GRENADES
			local grenadeOffsets = {
				flatAngle:Right() * 50 + Vector(0, 0, 20),
				flatAngle:Right() * -50 + Vector(0, 0, 20),
				flatAngle:Forward() * -45 + Vector(0, 0, 20)
			}

			for _, offset in ipairs(grenadeOffsets) do
				local nade = ents.Create("ent_hunter_gasnade")
				if IsValid(nade) then
					nade:SetPos(self:GetPos() + offset)
					nade:SetAngles(Angle(math.random(0,360), math.random(0,360), math.random(0,360)))
					nade:Spawn()
					nade:Activate()

					local nphys = nade:GetPhysicsObject()
					if IsValid(nphys) then
						nphys:Wake()
						local pushDir = Vector(offset.x, offset.y, 0):GetNormalized()
						nphys:SetVelocity(pushDir * 75 + Vector(0, 0, 100))
						nphys:AddAngleVelocity(Vector(math.random(-200,200), math.random(-200,200), math.random(-200,200)))
					end
				end
			end
			
			-- DETERMINE HUNTER COUNT (2 to 3)
			local numHunters = math.random(2, 3)
			
			-- SPAWN HUNTERS WITH 3-SECOND DELAYS
			for i = 1, numHunters do
				-- i=1 -> spawns at 0s, i=2 -> spawns at 3s, i=3 -> spawns at 6s 
				-- (All of this is relative to the T+1 second timer we are currently inside)
				local spawnDelay = (i - 1) * 3 

				timer.Simple(spawnDelay, function()
					if not IsValid(self) then return end

					-- Play an alert roar for each Hunter as it exits
					self:EmitSound("npc/hunter/hunter_alert1.wav", 100, math.random(95, 105))

					local hunter = ents.Create("npc_hunter")
					if not IsValid(hunter) then return end
					
					-- Calculate a circular direction based on which hunter it is (e.g., 0°, 120°, 240°)
					local angleOffset = (i - 1) * (360 / numHunters)
					local rotAngle = Angle(0, flatAngle.y + angleOffset, 0)
					
					-- Push them 140 units outward from the center in their unique direction
					local spawnPos = self:GetPos() + rotAngle:Forward() * 140 + Vector(0, 0, 60)
					
					hunter:SetPos(spawnPos)
					hunter:SetAngles(rotAngle)
					hunter:Spawn()
					hunter:Activate()
					
					constraint.NoCollide(hunter, self, 0, 0)

					local closestPly = NULL
					local closestDist = math.huge
					for _, ply in ipairs(player.GetAll()) do
						if ply:Alive() then
							local dist = hunter:GetPos():DistToSqr(ply:GetPos())
							if dist < closestDist then
								closestDist = dist
								closestPly = ply
							end
						end
					end

					if IsValid(closestPly) then
						hunter:UpdateEnemyMemory(closestPly, closestPly:GetPos())
						hunter:SetEnemy(closestPly)
					end
				end)
			end
		end)
	end
end
