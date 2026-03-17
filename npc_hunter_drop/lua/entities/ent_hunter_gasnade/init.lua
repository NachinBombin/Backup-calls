AddCSLuaFile("shared.lua")
include("shared.lua")

if not SERVER then return end

function ENT:Initialize()
	self:SetModel("models/Weapons/w_grenade.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
	end

	-- +50% Smoke Size Adjustments
	local smoke = ents.Create("env_smokestack")
	if IsValid(smoke) then
		smoke:SetPos(self:GetPos())
		smoke:SetParent(self)
		smoke:SetKeyValue("InitialState", "1")
		smoke:SetKeyValue("BaseSpread", "30")     -- Was 20
		smoke:SetKeyValue("SpreadSpeed", "45")    -- Was 30
		smoke:SetKeyValue("Speed", "40")          
		smoke:SetKeyValue("StartSize", "90")      -- Was 60
		smoke:SetKeyValue("EndSize", "270")       -- Was 180
		smoke:SetKeyValue("Rate", "50")           
		smoke:SetKeyValue("JetLength", "100")     
		smoke:SetKeyValue("Twist", "20")          
		smoke:SetKeyValue("SmokeMaterial", "particle/particle_smokegrenade")
		smoke:SetKeyValue("rendercolor", "10 10 10") 
		smoke:SetKeyValue("renderamt", "200")        
		smoke:Spawn()
		smoke:Activate()
		
		self:DeleteOnRemove(smoke)
	end

	self:EmitSound("ambient/gas/steam2.wav", 75, 100)
	SafeRemoveEntityDelayed(self, 30)
end
