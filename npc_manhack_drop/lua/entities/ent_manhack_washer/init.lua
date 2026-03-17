AddCSLuaFile("shared.lua")
include("shared.lua")

if not SERVER then return end

function ENT:Initialize()
	self:SetModel("models/props_wasteland/laundry_washer003.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
	end

	self.HasLanded = false
end

-- Keep Think() so the engine doesn't put it to sleep mid-air during a long fall
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

	-- A natural landing. We only check for speed > 100 because the washer is falling slower
	if data.Speed > 100 and data.HitNormal.z > 0.5 then
		self.HasLanded = true

		-- No artificial teleporting or velocity killing. Let it bounce and settle natively!

		-- Sequence begins 1 second after landing
		timer.Simple(1, function()
			if not IsValid(self) then return end

			-- Play the opening sounds
			self:EmitSound("doors/heavy_metal_stop1.wav", 100, math.random(95, 105))
			self:EmitSound("physics/metal/metal_box_break1.wav", 100, 100)

			local flatAngle = Angle(0, self:GetAngles().y, 0)

			-- SPAWN THE GAS GRENADES
			local grenadeOffsets = {
				flatAngle:Right() * 30 + Vector(0, 0, 20),
				flatAngle:Right() * -30 + Vector(0, 0, 20),
				flatAngle:Forward() * -30 + Vector(0, 0, 20)
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
			
			-- DETERMINE MANHACK COUNT (16 to 20)
			local totalManhacks = math.random(16, 20)
			
			-- BATCH SPAWNING LOGIC
			for i = 1, totalManhacks do
				local index = i - 1
				local batchIndex = math.floor(index / 4)      
				local withinBatchIndex = index % 4            
				
				-- 2 seconds between full batches, 150ms between individual manhacks
				local spawnDelay = (batchIndex * 2.0) + (withinBatchIndex * 0.15)
				
				timer.Simple(spawnDelay, function()
					if not IsValid(self) then return end

					self:EmitSound("npc/manhack/release.wav", 85, math.random(95, 105))

					local manhack = ents.Create("npc_manhack")
					if not IsValid(manhack) then return end
					
					local angleOffset = withinBatchIndex * 90
					local rotAngle = Angle(0, flatAngle.y + angleOffset, 0)
					
					-- Offset 50 units away from the washing machine center
					local spawnPos = self:GetPos() + rotAngle:Forward() * 50 + Vector(0, 0, 40)
					
					manhack:SetPos(spawnPos)
					manhack:SetAngles(rotAngle)
					manhack:Spawn()
					manhack:Activate()
					
					constraint.NoCollide(manhack, self, 0, 0)

					-- Auto-target nearby players
					local closestPly = NULL
					local closestDist = math.huge
					for _, ply in ipairs(player.GetAll()) do
						if ply:Alive() then
							local dist = manhack:GetPos():DistToSqr(ply:GetPos())
							if dist < closestDist then
								closestDist = dist
								closestPly = ply
							end
						end
					end

					if IsValid(closestPly) then
						manhack:UpdateEnemyMemory(closestPly, closestPly:GetPos())
						manhack:SetEnemy(closestPly)
					end
				end)
			end
		end)
	end
end
