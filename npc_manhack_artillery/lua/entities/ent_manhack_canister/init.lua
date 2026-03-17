AddCSLuaFile("shared.lua")
include("shared.lua")

if not SERVER then return end

function ENT:Initialize()
	self:SetModel("models/xqm/afterburner1.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
	end
	
	-- 1. VARIABILITY: Black Trail
	local trailStartW = math.random(15, 35)      
	local trailLife   = math.Rand(1.0, 2.0)      
	local shade       = math.random(30, 50)      
	local trailAlpha  = math.random(160, 220)    
	local trailColor  = Color(shade, shade, shade, trailAlpha)
	
	local trail = util.SpriteTrail(self, 0, trailColor, false, trailStartW, 0, trailLife, 1 / trailStartW * 0.5, "trails/smoke.vmt")
	
	-- 2. VARIABILITY: White Gas
	local gas = ents.Create("env_smokestack")
	if IsValid(gas) then
		gas:SetPos(self:GetPos())
		gas:SetParent(self)
		gas:SetKeyValue("InitialState", "1")
		gas:SetKeyValue("BaseSpread", tostring(math.random(3, 8)))     
		gas:SetKeyValue("SpreadSpeed", tostring(math.random(8, 15)))   
		gas:SetKeyValue("Speed", tostring(math.random(20, 35)))        
		gas:SetKeyValue("StartSize", tostring(math.random(10, 20)))
		gas:SetKeyValue("EndSize", tostring(math.random(35, 55)))      
		gas:SetKeyValue("Rate", tostring(math.random(20, 35)))         
		gas:SetKeyValue("JetLength", tostring(math.random(40, 70)))
		gas:SetKeyValue("Twist", tostring(math.random(5, 15)))         
		gas:SetKeyValue("SmokeMaterial", "particle/particle_smokegrenade")
		
		local brightness = math.random(200, 240)
		gas:SetKeyValue("rendercolor", brightness .. " " .. brightness .. " " .. brightness) 
		gas:SetKeyValue("renderamt", tostring(math.random(90, 130)))
		
		gas:Spawn()
		gas:Activate()
		self:DeleteOnRemove(gas)
		
		timer.Simple(30, function()
			if IsValid(gas) then
				gas:Fire("TurnOff")
				SafeRemoveEntityDelayed(gas, 5)
			end
		end)
	end
	
	-- ============================================================
	-- 4 SECOND MARK: THE "FAKE" IMPACT
	-- ============================================================
	timer.Simple(4, function()
		if not IsValid(self) then return end
		
		-- Kill the trail early so it doesn't clip through the floor
		if IsValid(trail) then trail:Remove() end
		
		-- Kill the downward velocity instantly so it settles immediately
		local physObj = self:GetPhysicsObject()
		if IsValid(physObj) then
			physObj:SetVelocity(Vector(0,0,0))
		end

		local pos = self:GetPos()
		
		-- Shoot a tiny trace straight down to find the floor for the dust effect
		local tr = util.TraceLine({
			start = pos,
			endpos = pos - Vector(0, 0, 100),
			filter = self
		})

		-- If it found the ground, create a violent dirt/dust crater effect
		if tr.Hit then
			local effectData = EffectData()
			effectData:SetOrigin(tr.HitPos)
			effectData:SetNormal(tr.HitNormal)
			effectData:SetScale(math.Rand(1.5, 2.5))
			util.Effect("cball_bounce", effectData)  -- Hard impact shockwave
			util.Effect("WheelDust", effectData)     -- Cloud of debris
		end

		-- Play a brutal thud/crash sound right where the canister is
		self:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1, 5) .. ".wav", 95, math.random(80, 110))
		
		-- Screen shake for players near the impact (amplitude, frequency, duration, radius)
		util.ScreenShake(pos, 5, 5, 0.5, 500)
	end)

	-- ============================================================
	-- 5 SECOND MARK: MANHACK RELEASE
	-- ============================================================
	timer.Simple(5, function()
		if not IsValid(self) then return end

		self:EmitSound("physics/metal/metal_box_break1.wav", 80, math.random(90, 110))
		self:EmitSound("ambient/gas/steam2.wav", 80, 150)

		local spark = ents.Create("env_spark")
		if IsValid(spark) then
			spark:SetPos(self:GetPos() + Vector(0, 0, 10))
			spark:SetParent(self)
			spark:SetKeyValue("MaxDelay", "0.2")
			spark:SetKeyValue("Magnitude", "2")
			spark:SetKeyValue("TrailLength", "2")
			spark:Spawn()
			spark:Activate()
			spark:Fire("StartSpark")
			
			SafeRemoveEntityDelayed(spark, 5)
		end

		local manhack = ents.Create("npc_manhack")
		if IsValid(manhack) then
			manhack:SetPos(self:GetPos() + Vector(0, 0, 15))
			manhack:SetAngles(Angle(0, self:GetAngles().y, 0))
			manhack:Spawn()
			manhack:Activate()
			
			self:EmitSound("npc/manhack/release.wav", 85, math.random(95, 105))
			self:EmitSound("ambient/energy/spark5.wav", 100, math.random(95, 105))
			
			constraint.NoCollide(manhack, self, 0, 0)
			
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
		end
	end)
end
