AddCSLuaFile("shared.lua")
include("shared.lua")

if not SERVER then return end

ENT.FuseTime = 60

local BLUE = Color(0, 80, 255)
local colorTrailBlue = Color(0, 80, 255, 150)

function ENT:Initialize()
    self:SetModel("models/items/ar2_grenade.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetColor(BLUE)
    self:SetUseType(SIMPLE_USE)
    self:SetModelScale(0.5)

    -- Physics
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableGravity(true)
        phys:SetBuoyancyRatio(0)
    end

    -- Effects
    util.SpriteTrail(self, 0, colorTrailBlue, false, 1, 100, 5, 5 / ((2 + 10) * 0.5), "trails/smoke.vmt")

    local envFlare = ents.Create("env_flare")
    envFlare:SetPos(self:GetPos())
    envFlare:SetAngles(self:GetAngles())
    envFlare:SetParent(self)
    envFlare:SetKeyValue("Scale", "5")
    envFlare:SetKeyValue("spawnflags", "4")
    envFlare:Spawn()
    envFlare:Fire("Start", tostring(self.FuseTime))
    envFlare:SetOwner(self)
    envFlare:SetColor(BLUE)

    -- Burn sound
    self.CurrentIdleSound = CreateSound(self, "weapons/flaregun/burn.wav")
    if self.CurrentIdleSound then
        self.CurrentIdleSound:SetSoundLevel(60)
        self.CurrentIdleSound:PlayEx(1, 100)
    end
    
    -- Make it drop mass after some time in the air
    timer.Simple(2, function()
        if IsValid(self) then
            local physObj = self:GetPhysicsObject()
            if IsValid(physObj) and physObj:GetVelocity():Length() > 500 then
                physObj:SetMass(0.005)
                timer.Simple(10, function()
                    if IsValid(self) then
                        local p2 = self:GetPhysicsObject()
                        if IsValid(p2) then p2:SetMass(5) end
                    end
                end)
            end
        end
    end)
    
    -- Remove after fuse time
    timer.Simple(self.FuseTime, function()
        if IsValid(self) then
            self:Remove()
        end
    end)
end

function ENT:Use(activator, caller)
    if IsValid(activator) and activator:IsPlayer() then
        activator:PickupObject(self)
    end
end

function ENT:PhysicsCollide(data, physobj)
    local hitEnt = data.HitEntity
    if IsValid(hitEnt) and (hitEnt:IsNPC() or hitEnt:IsPlayer()) then
        local dmg = DamageInfo()
        dmg:SetDamage(math.random(4, 8))
        dmg:SetDamageType(DMG_BURN)
        
        -- Improved kill attribution: checks if your main script assigned an owner
        local attacker = IsValid(self.BombardOwner) and self.BombardOwner or self
        dmg:SetAttacker(attacker)
        
        dmg:SetInflictor(self)
        dmg:SetDamagePosition(data.HitPos)
        hitEnt:TakeDamageInfo(dmg, self)
    end
end

function ENT:OnTakeDamage(dmginfo)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:AddVelocity(dmginfo:GetDamageForce() * 0.1)
    end
end

function ENT:OnRemove()
    -- Replaced VJ.STOPSOUND with native GMod sound stopping
    if self.CurrentIdleSound then
        self.CurrentIdleSound:Stop()
    end
    self:StopParticles()
end