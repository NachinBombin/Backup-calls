-- ============================================================
--  NPC Bombardment  |  npc_bombardment_menu.lua
--  Client-side Options menu panel.
--
--  PLACE IN:  lua/autorun/client/npc_bombardment_menu.lua
--
--  The trail and particle logic lives in npc_bombardment.lua
--  (the shared file).  This file is ONLY the spawnmenu panel.
-- ============================================================

if SERVER then return end

local ADDON_CATEGORY = "Bombin Addons"

hook.Add("AddToolMenuCategories", "NPCBombardment_AddCategory", function()
    spawnmenu.AddToolMenuCategory(ADDON_CATEGORY)
end)

hook.Add("PopulateToolMenu", "NPCBombardment_PopulateMenu", function()
    spawnmenu.AddToolMenuOption(
        "Options",
        ADDON_CATEGORY,
        "npc_bombardment_settings",
        "NPC Bombardment",
        "", "",
        function(panel)

            panel:ClearControls()

            panel:AddControl("Header", { Description = "NPC Bombardment Settings", Height = "40" })

            panel:CheckBox("Enable NPC Bombardment Calls", "npc_bombardment_enabled")
            panel:ControlHelp("  Master on/off switch for the entire addon.")

            panel:CheckBox("Debug Announce in Console", "npc_bombardment_announce")
            panel:ControlHelp("  Print a console message every time an NPC calls a strike.")

            panel:AddControl("Label", { Text = "" })

            -- ---- Probability & Timing ----
            panel:AddControl("Header", { Description = "Probability & Timing", Height = "30" })

            panel:NumSlider("Strike Chance", "npc_bombardment_chance", 0, 1, 2)
            panel:ControlHelp("  Probability (0.00 - 1.00) each check.  Default: 0.12")

            panel:NumSlider("Check Interval (seconds)", "npc_bombardment_interval", 1, 60, 0)
            panel:ControlHelp("  Seconds between eligibility checks per NPC.  Default: 12")

            panel:NumSlider("Strike Cooldown (seconds)", "npc_bombardment_cooldown", 10, 180, 0)
            panel:ControlHelp("  Minimum seconds between strikes from the same NPC.  Default: 50")

            panel:AddControl("Label", { Text = "" })

            -- ---- Engagement Range ----
            panel:AddControl("Header", { Description = "Engagement Range", Height = "30" })

            panel:NumSlider("Max Distance", "npc_bombardment_max_dist", 500, 8000, 0)
            panel:ControlHelp("  Max range in units.  Default: 3000")

            panel:NumSlider("Min Distance", "npc_bombardment_min_dist", 0, 1000, 0)
            panel:ControlHelp("  Min range in units.  Default: 400")

            panel:AddControl("Label", { Text = "" })

            -- ---- Strike Types ----
            panel:AddControl("Header", { Description = "Strike Types", Height = "30" })

            panel:CheckBox("Allow Aircraft Strikes", "npc_bombardment_allow_air")
            panel:ControlHelp("  A-10, AH-6, OH-58, P-47D, Typhoon, F-4E.\n  Auto-suppressed if skybox is sealed above target.")

            panel:CheckBox("Allow Special Strikes  (WP / Napalm)", "npc_bombardment_allow_special")
            panel:ControlHelp("  White Phosphorus artillery and F-4E Napalm runs.")

            panel:AddControl("Label", { Text = "" })

            -- ---- Strike reference ----
            panel:AddControl("Header", { Description = "Available Strikes (all equal weight)", Height = "30" })

            panel:ControlHelp(
                "  Ground (always available):\n" ..
                "    Single 155mm HE  |  155mm HE Barrage\n" ..
                "    120mm Mortar HE  |  120mm Smoke Mortar\n" ..
                "    105mm Smoke Artillery\n" ..
                "    105mm WP Artillery  (requires Special Strikes)\n\n" ..
                "  Aircraft (requires open sky + Aircraft Strikes enabled):\n" ..
                "    A-10 Thunderbolt II — 30mm strafing run\n" ..
                "    AH-6 Little Bird    — minigun strafing run\n" ..
                "    OH-58 Kiowa         — minigun + Hydra rocket salvo\n" ..
                "    P-47D Thunderbolt   — 8x .50 cal strafing run\n" ..
                "    Typhoon             — RP-3 rocket run\n" ..
                "    F-4E Napalm         — napalm bomb run  (requires Special)\n" ..
                "    F-4E CBU Cluster    — 4x cluster munitions in a line\n\n" ..
                "  All 13 strikes share equal probability.\n" ..
                "  Aircraft suppressed automatically on sealed maps.\n" ..
                "  Requires: Gredwitch Artillery SWEPs base."
            )

        end
    )
end)
