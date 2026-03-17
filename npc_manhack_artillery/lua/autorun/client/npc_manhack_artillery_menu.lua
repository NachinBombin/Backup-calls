if SERVER then return end

local ADDON_CATEGORY = "Bombin Addons"

hook.Add("PopulateToolMenu", "NPCManhackArt_PopulateMenu", function()
	spawnmenu.AddToolMenuOption(
		"Options",
		ADDON_CATEGORY,
		"npc_manhack_artillery_settings",
		"Manhack Artillery",
		"", "",
		function(panel)
			panel:ClearControls()
			panel:AddControl("Header", { Description = "Manhack Artillery Settings", Height = "40" })

			panel:CheckBox("Enable Artillery Calls", "npc_manhackart_enabled")
			panel:CheckBox("Debug Announce in Console", "npc_manhackart_announce")

			panel:AddControl("Label", { Text = "" })
			panel:AddControl("Header", { Description = "Probability & Timing", Height = "30" })

			panel:NumSlider("Strike Chance", "npc_manhackart_chance", 0, 1, 2)
			panel:NumSlider("Check Interval (seconds)", "npc_manhackart_interval", 1, 60, 0)
			panel:NumSlider("Strike Cooldown (seconds)", "npc_manhackart_cooldown", 10, 180, 0)

			panel:AddControl("Label", { Text = "" })
			panel:AddControl("Header", { Description = "Engagement Range", Height = "30" })

			panel:NumSlider("Max Distance", "npc_manhackart_max_dist", 500, 8000, 0)
			panel:NumSlider("Min Distance", "npc_manhackart_min_dist", 0, 1000, 0)
		end
	)
end)
