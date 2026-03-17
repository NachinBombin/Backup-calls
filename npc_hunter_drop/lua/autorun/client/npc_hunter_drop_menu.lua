-- ============================================================
--  NPC Hunter Drop Menu  |  npc_hunter_drop_menu.lua
-- ============================================================

if SERVER then return end

hook.Add("PopulateToolMenu", "NPCHunterDrop_PopulateMenu", function()
    spawnmenu.AddToolMenuOption(
        "Options",
        "Bombin Addons",
        "npc_hunter_drop_settings",
        "Hunter Drop Pod",
        "", "",
        function(panel)
            panel:ClearControls()
            panel:AddControl("Header", { Description = "Hunter Drop Pod Settings", Height = "40" })

            panel:CheckBox("Enable Hunter Drop Calls", "npc_hunterdrop_enabled")
            panel:CheckBox("Debug Announce in Console", "npc_hunterdrop_announce")

            panel:AddControl("Label", { Text = "" })
            panel:AddControl("Header", { Description = "Probability & Timing", Height = "30" })

            panel:NumSlider("Drop Chance", "npc_hunterdrop_chance", 0, 1, 2)
            panel:NumSlider("Check Interval (seconds)", "npc_hunterdrop_interval", 1, 60, 0)
            panel:NumSlider("Cooldown (seconds)", "npc_hunterdrop_cooldown", 10, 180, 0)

            panel:AddControl("Label", { Text = "" })
            panel:AddControl("Header", { Description = "Engagement Range", Height = "30" })

            panel:NumSlider("Max Distance", "npc_hunterdrop_max_dist", 500, 8000, 0)
            panel:NumSlider("Min Distance", "npc_hunterdrop_min_dist", 0, 1000, 0)
        end
    )
end)