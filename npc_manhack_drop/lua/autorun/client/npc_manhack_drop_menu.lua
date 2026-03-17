-- ============================================================
-- NPC Manhack Drop Menu | npc_manhack_drop_menu.lua
-- ============================================================

if SERVER then return end

hook.Add("PopulateToolMenu", "NPCManhackDrop_PopulateMenu", function()
	spawnmenu.AddToolMenuOption(
		"Options",
		"Bombin Addons",
		"npc_manhack_drop_settings",
		"Manhack Drop Pod",
		"", "",
		function(panel)
			panel:ClearControls()
			panel:AddControl("Header", { Description = "Manhack Drop Pod Settings", Height = "40" })

			panel:CheckBox("Enable Manhack Drop Calls", "npc_manhackdrop_enabled")
			panel:CheckBox("Debug Announce in Console", "npc_manhackdrop_announce")

			panel:AddControl("Label", { Text = "" })
			panel:AddControl("Header", { Description = "Probability & Timing", Height = "30" })

			panel:NumSlider("Drop Chance", "npc_manhackdrop_chance", 0, 1, 2)
			panel:NumSlider("Check Interval (seconds)", "npc_manhackdrop_interval", 1, 60, 0)
			panel:NumSlider("Cooldown (seconds)", "npc_manhackdrop_cooldown", 10, 180, 0)

			panel:AddControl("Label", { Text = "" })
			panel:AddControl("Header", { Description = "Engagement Range", Height = "30" })

			panel:NumSlider("Max Distance", "npc_manhackdrop_max_dist", 500, 8000, 0)
			panel:NumSlider("Min Distance", "npc_manhackdrop_min_dist", 0, 1000, 0)
		end
	)
end)
