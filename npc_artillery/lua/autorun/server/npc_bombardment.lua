-- ============================================================
--  NPC Bombardment  |  npc_bombardment.lua
--  Shared file (SERVER logic + CLIENT light).
--
--  PLACE IN:  lua/autorun/npc_bombardment.lua
--  (NOT lua/autorun/server/ — must run on BOTH realms.)
--
--  Combine soldiers, metrocops, and elites periodically lob a
--  blue VJ flare and call in a Gredwitch artillery/aircraft strike.
--  The flare is purely cosmetic; the strike is the damage source.
--
--  Requires: Gredwitch's Artillery SWEPs base addon.
--            VJ Base (for obj_vj_flareround_blue entity).
-- ============================================================

-- ============================================================
--  Network strings  (shared scope — must be above SERVER/CLIENT blocks)
-- ============================================================
util.AddNetworkString("NPCBombardment_CanSpawned")

-- ============================================================
--  SERVER
-- ============================================================
if SERVER then

AddCSLuaFile()   -- send this file to every connecting client

-- ============================================================
--  ConVars
-- ============================================================
local SHARED_FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)

local cv_enabled    = CreateConVar("npc_bombardment_enabled",       "1",    SHARED_FLAGS, "Enable/disable NPC bombardment calls.")
local cv_chance     = CreateConVar("npc_bombardment_chance",        "0.12", SHARED_FLAGS, "Probability (0-1) that an eligible NPC calls a strike each check.")
local cv_interval   = CreateConVar("npc_bombardment_interval",      "12",   SHARED_FLAGS, "Seconds between strike-eligibility checks per NPC.")
local cv_cooldown   = CreateConVar("npc_bombardment_cooldown",      "50",   SHARED_FLAGS, "Minimum seconds between strikes for the same NPC.")
local cv_max_dist   = CreateConVar("npc_bombardment_max_dist",      "3000", SHARED_FLAGS, "Max distance to player for a strike to be attempted.")
local cv_min_dist   = CreateConVar("npc_bombardment_min_dist",      "400",  SHARED_FLAGS, "Min distance to player (no strike closer than this).")
local cv_allow_air  = CreateConVar("npc_bombardment_allow_air",     "1",    SHARED_FLAGS, "Allow aircraft strikes.")
local cv_allow_spec = CreateConVar("npc_bombardment_allow_special", "1",    SHARED_FLAGS, "Allow special strikes (WP, Napalm).")
local cv_announce   = CreateConVar("npc_bombardment_announce",      "0",    SHARED_FLAGS, "Print debug message each time an NPC calls a strike.")

-- ============================================================
--  NPC whitelist
-- ============================================================
local BOMBARDMENT_CALLERS = {
    ["npc_combine_s"]     = true,
    ["npc_metropolice"]   = true,
    ["npc_combine_elite"] = true,
}

local function IsEligibleCaller(npc)
    if not IsValid(npc) or not npc:IsNPC() then return false end
    return BOMBARDMENT_CALLERS[npc:GetClass()] == true
end

-- ============================================================
--  Sky validation  (mirrors HandleStrike double-pass)
-- ============================================================
local function CheckSkyAbove(pos)
    local trace = util.TraceLine({
        start  = pos + Vector(0, 0, 50),
        endpos = pos + Vector(0, 0, 1050),
    })
    if trace.Hit and not trace.HitSky then
        trace = util.TraceLine({
            start  = trace.HitPos + Vector(0, 0, 50),
            endpos = trace.HitPos + Vector(0, 0, 1000),
        })
    end
    local skyOpen = not (trace.Hit and not trace.HitSky)
    return skyOpen, trace
end

local function BuildTraces(npc, enemy)
    local skyOpen, skyTrace = CheckSkyAbove(enemy:GetPos())
    local eyeTrace = {
        StartPos = npc:GetPos(),
        HitPos   = enemy:GetPos(),
    }
    return skyTrace, eyeTrace, skyOpen
end

-- ============================================================
--  Strike pool  (all weight = 10, equal probability)
-- ============================================================
local STRIKE_POOL = {
    -- -------------------------------------------------------
    --  Artillery / Mortar  (no skybox needed)
    -- -------------------------------------------------------
    {
        name = "Single 155mm HE", weight = 10,
        needs_sky = false, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.ARTILLERY(ply, tr, "ARTILLERY", "BIGARTILLERY", 1, 155, "HE", 10, 15000)
            end)
        end,
    },
    {
        name = "155mm HE Barrage", weight = 10,
        needs_sky = false, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.ARTILLERY(ply, tr, "ARTILLERY", "BIGARTILLERY", math.random(24, 30), 155, "HE", 1200, 15000)
            end)
        end,
    },
    {
        name = "120mm Mortar HE", weight = 10,
        needs_sky = false, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.ARTILLERY(ply, tr, "MORTAR", "MORTAR", math.random(18, 24), 120, "HE", 900, 1400)
            end)
        end,
    },
    {
        name = "120mm Smoke Mortar", weight = 10,
        needs_sky = false, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.ARTILLERY(ply, tr, "MORTAR", "MORTAR", math.random(12, 16), 120, "Smoke", 900)
            end)
        end,
    },
    {
        name = "105mm Smoke Artillery", weight = 10,
        needs_sky = false, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.ARTILLERY(ply, tr, "ARTILLERY", "ARTILLERY", math.random(14, 16), 105, "Smoke", 600)
            end)
        end,
    },
    {
        name = "105mm WP Artillery", weight = 10,
        needs_sky = false, needs_special = true,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.ARTILLERY(ply, tr, "ARTILLERY", "ARTILLERY", math.random(14, 16), 105, "WP", 600)
            end)
        end,
    },
    -- -------------------------------------------------------
    --  Aircraft  (requires open skybox + allow_air)
    -- -------------------------------------------------------
    {
        name = "F-4E Napalm Run", weight = 10,
        needs_sky = true, needs_special = true,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.BOMBER(ply, tr, eyeTrace,
                    "artillery/flyby/f4_napalm.ogg",
                    "models/gredwitch/static/f4.mdl",
                    "gb_bomb_mk77", 2, 13, 11, 1, true)
            end)
        end,
    },
    -- -------------------------------------------------------
    --  F-4E CBU Cluster Run
    --
    --  Same plane and flyby as the napalm strike.
    --  Drops 4 gb_bomb_cbu munitions in a stretched line
    --  along the flight path, one per second.
    --
    --  BOMBER parameter reference (from gred source):
    --    arg7  = bomb count          → 4
    --    arg8  = along-track spread  → 280  (units between drops along flight vector)
    --                                   ↑ TUNE THIS: larger = more spread out line
    --    arg9  = drop interval       → 22   (internal gred time unit ≈ 1 real second per bomb)
    --                                   ↑ TUNE THIS: lower = faster sequence
    --    arg10 = plane count         → 1
    --    arg11 = use bomb physics    → true
    -- -------------------------------------------------------
    {
        name = "F-4E CBU Cluster Run", weight = 10,
        needs_sky = true, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.BOMBER(ply, tr, eyeTrace,
                    "artillery/flyby/f4_napalm.ogg",
                    "models/gredwitch/static/f4.mdl",
                    "grdn_bomb_sc500",  -- Mk 20 Rockeye CBU (cluster munition)
                    4,               -- drop 4 bombs
                    280,             -- along-track spread
                    22,              -- interval between drops
                    3,               -- single plane pass
                    true)
            end)
        end,
    },
    {
        name = "A-10 Strafing Run", weight = 10,
        needs_sky = true, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                tr.HitPos.z = tr.HitPos.z + 400
                gred.STRIKE.GUNRUN(ply, tr, eyeTrace,
                    "wac_base_30mm", 0.0154, 1, "red",
                    1, 40, 80, nil,
                    "artillery/flyby/a10_strafingrun_0" .. math.random(1, 6) .. ".ogg",
                    "models/gredwitch/static/a10.mdl",
                    0, 4, true, nil)
            end)
        end,
    },
    {
        name = "AH-6 Littlebird Strafing Run", weight = 10,
        needs_sky = true, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.GUNRUN(ply, tr, eyeTrace,
                    "wac_base_7mm", 0.005, 1.5, "red",
                    2, 0.3, 30, nil,
                    "artillery/flyby/ah6_flyby.wav",
                    "models/gredwitch/static/littlebird.mdl",
                    0, 5, true,
                    "artillery/flyby/ah6_guns.wav")
            end)
        end,
    },
    {
        name = "OH-58 Kiowa Rocket Run", weight = 10,
        needs_sky = true, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.GUNRUN(ply, tr, eyeTrace,
                    "wac_base_7mm", 0.01, 1.5, "red",
                    1, 0.3, 30, nil,
                    "artillery/flyby/ah6_flyby.wav",
                    "models/gredwitch/static/kiowa.mdl",
                    0, 5, true,
                    "artillery/flyby/ah6_guns.wav")
                gred.STRIKE.TYPHOON(ply, tr, eyeTrace,
                    "gb_rocket_hydra", 0.7, 14, 30,
                    nil, nil, 0, 5, true)
            end)
        end,
    },
    {
        name = "P-47D Strafing Run", weight = 10,
        needs_sky = true, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.GUNRUN(ply, tr, eyeTrace,
                    "wac_base_12mm", 0.01, 1.3, "red",
                    8, 0.7, 60, 120,
                    "artillery/flyby/p47d_flyby.ogg",
                    "models/gredwitch/static/p47.mdl",
                    0, 2, true,
                    "artillery/flyby/p47d_guns.wav")
            end)
        end,
    },
    {
        name = "Typhoon Rocket Run", weight = 10,
        needs_sky = true, needs_special = false,
        func = function(ply, tr, eyeTrace)
            timer.Simple(5, function()
                if not gred or not gred.STRIKE then return end
                gred.STRIKE.TYPHOON(ply, tr, eyeTrace,
                    "gb_rocket_rp3", 0.7, 8, 60,
                    "artillery/flyby/typhoon_flyby.ogg",
                    "models/gredwitch/static/typhoon.mdl",
                    0, 2, true)
            end)
        end,
    },
}

-- ============================================================
--  Weighted random strike selection
-- ============================================================
local function PickStrike(skyOpen, allowAir, allowSpecial)
    local pool        = {}
    local totalWeight = 0

    for _, entry in ipairs(STRIKE_POOL) do
        if entry.needs_sky     and (not skyOpen or not allowAir) then continue end
        if entry.needs_special and not allowSpecial               then continue end
        table.insert(pool, entry)
        totalWeight = totalWeight + entry.weight
    end

    if #pool == 0 or totalWeight == 0 then return nil end

    local roll       = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(pool) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then return entry end
    end
    return pool[#pool]
end

-- ============================================================
--  Launch velocity helper
-- ============================================================
local function CalcLaunchVelocity(from, to, speed, arcFactor)
    local dir        = (to - from)
    local horizontal = Vector(dir.x, dir.y, 0)
    local dist       = horizontal:Length()
    if dist < 1 then dist = 1 end
    horizontal:Normalize()
    local velH = horizontal * speed
    local velZ = dist * arcFactor + (to.z - from.z) * 0.3
    velZ = math.Clamp(velZ, -speed * 0.5, speed * 0.8)
    return Vector(velH.x, velH.y, velZ)
end

-- ============================================================
--  Constants
-- ============================================================

local CAN_ENTITY   = "ent_bombin_flare_blue"

local MIN_FLIGHT   = 0.25   -- seconds before impact detection starts
local MAX_CAN_LIFE = 20     -- seconds before we force-remove the flare.
                             -- Must be long enough for the VJ flare's own
                             -- timer.Simple(2) mass-drop to have resolved.
                             -- (The mass-drop makes the flare slow to ~0 u/s
                             -- at 2s, so we CANNOT use velocity to detect landing.)
local canCounter   = 0

-- ============================================================
--  ThrowFlare
--
--  Spawns a VJ flare round, recolors it blue, and throws it.
--  Velocity is applied one frame after Activate() so the
--  flare's own Initialize() fully settles before we touch
--  the physics object — prevents the NULL phys crash.
-- ============================================================
local function ThrowFlare(npc, target)

    -- Step 1 (immediate): throw gesture animation
    do
        local gestureAct  = ACT_GESTURE_RANGE_ATTACK_THROW
        local fallbackAct = ACT_RANGE_ATTACK_THROW
        local seq = npc:SelectWeightedSequence(gestureAct)
        if seq <= 0 then
            seq = npc:SelectWeightedSequence(fallbackAct)
            if seq > 0 then gestureAct = fallbackAct end
        end
        if seq > 0 then npc:AddGesture(gestureAct) end
    end

    -- Stamp cooldown immediately so the think loop cannot re-queue
    -- a second call while we are waiting for the 1-second delay.
    npc.__bombard_lastCall = CurTime()

    -- Step 2 (1 second later): spawn and throw the flare
    timer.Simple(1, function()

        if not IsValid(npc) or not IsValid(target) then return end

        local targetPos = target:GetPos() + Vector(0, 0, 36)
        local npcEyePos = npc:EyePos()
        local toTarget  = (targetPos - npcEyePos):GetNormalized()
        local spawnDist = 52
        local spawnPos  = npcEyePos + toTarget * spawnDist

        -- Safety trace: pull back if brush geometry is in the way.
        local safetyTr = util.TraceLine({
            start  = npcEyePos,
            endpos = spawnPos,
            filter = { npc },
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if safetyTr.Hit then
            spawnPos = npcEyePos + toTarget * (safetyTr.Fraction * spawnDist * 0.85)
        end

        -- ---- Spawn flare entity ----
        -- The subclass handles its own blue color in Initialize().
        local can = ents.Create(CAN_ENTITY)
        if not IsValid(can) then return end

        local eyeAng = toTarget:Angle()
        can:SetPos(spawnPos + eyeAng:Right() * 6 + eyeAng:Up() * -2)
        can:SetAngles(npc:GetAngles())
        can:Spawn()
        can:Activate()

        can.BombardOwner = npc

        -- ---- Apply velocity ONE FRAME LATER ----
        -- Deferring with timer.Simple(0) lets the flare's own
        -- Initialize() fully settle before we touch the physics object.
        local vel = CalcLaunchVelocity(spawnPos, targetPos, 700, 0.25)
        timer.Simple(0, function()
            if not IsValid(can) then return end
            local phys = can:GetPhysicsObject()
            if IsValid(phys) then
                phys:SetVelocity(vel)
                phys:Wake()
            end
        end)

        -- ---- Broadcast entity to clients for DynamicLight flicker ----
        net.Start("NPCBombardment_CanSpawned")
            net.WriteEntity(can)
        net.Broadcast()

        -- ---- Expiry removal ----
        -- We do NOT use velocity to detect landing because the VJ flare's
        -- own timer.Simple(2) drops mass to 0.005 at high speeds, causing
        -- the entity to slow to near-zero while still in the air — this
        -- would falsely trigger a velocity-based landing check every time.
        -- Instead we simply remove after MAX_CAN_LIFE seconds.
        canCounter = canCounter + 1
        local uid       = canCounter
        local timerName = "BombardFlare_" .. uid

        timer.Simple(MAX_CAN_LIFE, function()
            if IsValid(can) then can:Remove() end
            timer.Remove(timerName) -- no-op if already gone, but clean
        end)

    end)  -- end timer.Simple(1)

    return true
end

-- ============================================================
--  Core bombardment function
-- ============================================================
local function CallBombardment(npc, target)
    local tr, eyeTrace, skyOpen = BuildTraces(npc, target)

    local allowAir     = cv_allow_air:GetBool()
    local allowSpecial = cv_allow_spec:GetBool()

    local strike = PickStrike(skyOpen, allowAir, allowSpecial)
    if not strike then
        if cv_announce:GetBool() then
            print(string.format("[NPC Bombardment] %s: no valid strike (skyOpen=%s air=%s spec=%s)",
                npc:GetClass(), tostring(skyOpen), tostring(allowAir), tostring(allowSpecial)))
        end
        return false
    end

    ThrowFlare(npc, target)        -- cosmetic throw (also stamps cooldown)
    strike.func(npc, tr, eyeTrace) -- fire the real bombardment

    if cv_announce:GetBool() then
        print(string.format("[NPC Bombardment] %s called '%s' on %s (dist:%.0f sky:%s)",
            npc:GetClass(), strike.name, target:Nick(),
            npc:GetPos():Distance(target:GetPos()), tostring(skyOpen)))
    end

    return true
end

-- ============================================================
--  Per-NPC state initialisation (lazy)
-- ============================================================
local function InitNPCState(npc)
    if not IsValid(npc) then return end
    if npc.__bombard_hooked then return end
    npc.__bombard_hooked    = true
    npc.__bombard_nextCheck = CurTime() + math.Rand(1, cv_interval:GetFloat())
    npc.__bombard_lastCall  = 0
end

-- ============================================================
--  Main Think loop
-- ============================================================
timer.Create("NPCBombardment_Think", 0.5, 0, function()
    if not cv_enabled:GetBool() then return end
    if not gred or not gred.STRIKE then return end

    local now      = CurTime()
    local interval = cv_interval:GetFloat()
    local cooldown = cv_cooldown:GetFloat()
    local chance   = cv_chance:GetFloat()
    local maxDist  = cv_max_dist:GetFloat()
    local minDist  = cv_min_dist:GetFloat()

    for _, npc in ipairs(ents.GetAll()) do
        if not IsValid(npc) or not npc:IsNPC() then continue end
        if not IsEligibleCaller(npc) then continue end

        InitNPCState(npc)

        if now < (npc.__bombard_nextCheck or 0) then continue end
        npc.__bombard_nextCheck = now + interval + math.Rand(-2, 2)

        if now - (npc.__bombard_lastCall or 0) < cooldown then continue end

        if npc:Health() <= 0 then continue end
        local enemy = npc:GetEnemy()
        if not IsValid(enemy) or not enemy:IsPlayer() then continue end
        if not enemy:Alive() then continue end

        local dist = npc:GetPos():Distance(enemy:GetPos())
        if dist > maxDist or dist < minDist then continue end

        local losTr = util.TraceLine({
            start  = npc:EyePos(),
            endpos = enemy:EyePos(),
            filter = { npc },
            mask   = MASK_SOLID,
        })
        if losTr.Entity ~= enemy and losTr.Fraction < 0.7 then continue end

        if math.random() > chance then continue end

        CallBombardment(npc, enemy)
    end
end)

-- ============================================================
--  Startup message
-- ============================================================
hook.Add("InitPostEntity", "NPCBombardment_Init", function()
    print("[NPC Bombardment] Loaded.")
    if not gred or not gred.STRIKE then
        print("[NPC Bombardment] WARNING: gred.STRIKE not found.")
    end
end)

end  -- SERVER

-- ============================================================
--  CLIENT
--
--  The blue VJ flare entity produces its own env_flare glow,
--  SpriteTrail, and burn sound entirely on its own — no
--  ParticleEmitter needed here.
--
--  We add ONE thing the flare entity doesn't have: a fast
--  flickering DynamicLight that strobes on top of the steady
--  env_flare glow, giving the canister a rapid electric pulse.
-- ============================================================
if CLIENT then

local activeFlares = {}

net.Receive("NPCBombardment_CanSpawned", function()
    local flare = net.ReadEntity()
    if IsValid(flare) then
        activeFlares[flare:EntIndex()] = flare
    end
end)

hook.Add("Think", "NPCBombardment_FlareLight", function()

    if not next(activeFlares) then return end

    for idx, flare in pairs(activeFlares) do
        if not IsValid(flare) then
            activeFlares[idx] = nil
            continue
        end

        -- Fast irregular strobe: math.random() is re-evaluated every
        -- Think tick (~60/s), so the on/off pattern is never periodic.
        local bright = math.random() > 0.4   -- 60% frames lit, 40% near-off

        local dlight = DynamicLight(flare:EntIndex())
        if dlight then
            dlight.Pos        = flare:GetPos()
            dlight.r          = 0
            dlight.g          = 80
            dlight.b          = 255           -- matches the blue flare color
            dlight.Brightness = bright and math.Rand(4.0, 6.0) or math.Rand(0.0, 0.2)
            dlight.Size       = 55            -- tight radius: strong, not spilling far
            dlight.Decay      = 3000
            dlight.DieTime    = CurTime() + 0.05
        end
    end
end)

end  -- CLIENT
