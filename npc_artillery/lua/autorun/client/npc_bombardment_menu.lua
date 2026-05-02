-- ============================================================
--  NPC Bombardment  |  npc_bombardment_menu.lua
--  Client-side Options menu panel.
--
--  PLACE IN:  lua/autorun/client/npc_bombardment_menu.lua
--
--  The trail and particle logic lives in npc_bombardment.lua
--  (the shared file).  This file is ONLY the spawnmenu panel.
--
--  Visual pass: black bg, colored category headers, adaptive text
-- ============================================================

if SERVER then return end

local ADDON_CATEGORY = "Bombin Addons"

-- ----------------------------------------
-- Color palette & helpers
-- ----------------------------------------
local col_bg_panel      = Color(0, 0, 0, 255)       -- pure black background
local col_section_title = Color(210, 210, 210, 255)
local col_label         = Color(200, 200, 200, 255)
local col_accent        = Color(0, 180, 255, 255)
local col_text_dark     = Color(0, 0, 0, 255)       -- black text (for light bg)
local col_text_light    = Color(255, 255, 255, 255) -- white text (for dark bg)

-- Category colors (section headers)
local SECTION_COLORS = {
    ["Probability & Timing"]              = Color(255, 160, 80,  120),  -- orange
    ["Engagement Range"]                  = Color(80,  160, 220, 120),  -- steel blue
    ["Strike Types"]                      = Color(220, 80,  80,  120),  -- red
    ["Available Strikes (all equal weight)"] = Color(90, 180, 120, 120), -- toxic green
}

-- ----------------------------------------
-- Helper: colored section header panel
-- ----------------------------------------
local function AddColoredHeader(panel, text, height)
    local bgColor = SECTION_COLORS[text]
    height = height or 30

    if not bgColor then
        -- Fallback: plain bold label
        local lbl = vgui.Create("DLabel", panel)
        lbl:SetText(text)
        lbl:SetFont("DermaDefaultBold")
        lbl:SetTextColor(col_label)
        lbl:SetTall(height)
        lbl:Dock(TOP)
        lbl:DockMargin(0, 8, 0, 4)
        panel:AddItem(lbl)
        return
    end

    local cat = vgui.Create("DPanel", panel)
    cat:SetTall(height)
    cat:Dock(TOP)
    cat:DockMargin(0, 8, 0, 4)
    cat.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, bgColor)
        surface.SetDrawColor(0, 0, 0, 35)
        surface.DrawOutlinedRect(0, 0, w, h)

        -- Adaptive text: black on light bg, white on dark bg
        local textColor = col_text_dark
        if (bgColor.r + bgColor.g + bgColor.b) < 200 then
            textColor = col_text_light
        end

        draw.SimpleText(
            text,
            "DermaDefaultBold",
            8, h / 2,
            textColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end
    panel:AddItem(cat)
end

-- ----------------------------------------
-- Derma skin tweaks: pure black panels
-- ----------------------------------------
hook.Add("PreRenderVGUI", "NPCBombardment_SkinTweak", function()
    local skin = derma.GetDefaultSkin()
    if not skin.NPCBombardmentSkinned then
        skin.NPCBombardmentSkinned = true

        local oldPaintCPanel = skin.PaintCategoryPanel
        skin.PaintCategoryPanel = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, col_bg_panel)
            if oldPaintCPanel then
                surface.SetDrawColor(255, 255, 255, 20)
                surface.DrawOutlinedRect(0, 0, w, h)
            end
        end

        local oldPaintLabel = skin.PaintLabel
        skin.PaintLabel = function(self, w, h)
            self:SetTextColor(col_label)
            if oldPaintLabel then
                oldPaintLabel(self, w, h)
            end
        end
    end
end)

-- ----------------------------------------
-- Spawnmenu category
-- ----------------------------------------
hook.Add("AddToolMenuCategories", "NPCBombardment_AddCategory", function()
    spawnmenu.AddToolMenuCategory(ADDON_CATEGORY)
end)

-- ----------------------------------------
-- Main tool menu
-- ----------------------------------------
hook.Add("PopulateToolMenu", "NPCBombardment_PopulateMenu", function()
    spawnmenu.AddToolMenuOption(
        "Options",
        ADDON_CATEGORY,
        "npc_bombardment_settings",
        "NPC Bombardment",
        "", "",
        function(panel)

            panel:ClearControls()

            -- Header banner
            local header = vgui.Create("DPanel", panel)
            header:SetTall(40)
            header:Dock(TOP)
            header:DockMargin(0, 0, 0, 8)
            header.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, col_bg_panel)
                surface.SetDrawColor(col_accent)
                surface.DrawRect(0, h - 2, w, 2)
                draw.SimpleText(
                    "NPC Bombardment Settings",
                    "DermaLarge",
                    8, h / 2,
                    col_section_title,
                    TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_CENTER
                )
            end
            panel:AddItem(header)

            -- ---- Master toggles ----
            panel:CheckBox("Enable NPC Bombardment Calls", "npc_bombardment_enabled")
            panel:ControlHelp("  Master on/off switch for the entire addon.")

            panel:CheckBox("Debug Announce in Console", "npc_bombardment_announce")
            panel:ControlHelp("  Print a console message every time an NPC calls a strike.")

            panel:AddControl("Label", { Text = "" })

            -- ---- Probability & Timing ----
            AddColoredHeader(panel, "Probability & Timing", 30)

            panel:NumSlider("Strike Chance", "npc_bombardment_chance", 0, 1, 2)
            panel:ControlHelp("  Probability (0.00 - 1.00) each check.  Default: 0.12")

            panel:NumSlider("Check Interval (seconds)", "npc_bombardment_interval", 1, 60, 0)
            panel:ControlHelp("  Seconds between eligibility checks per NPC.  Default: 12")

            panel:NumSlider("Strike Cooldown (seconds)", "npc_bombardment_cooldown", 10, 180, 0)
            panel:ControlHelp("  Minimum seconds between strikes from the same NPC.  Default: 50")

            panel:AddControl("Label", { Text = "" })

            -- ---- Engagement Range ----
            AddColoredHeader(panel, "Engagement Range", 30)

            panel:NumSlider("Max Distance", "npc_bombardment_max_dist", 500, 8000, 0)
            panel:ControlHelp("  Max range in units.  Default: 3000")

            panel:NumSlider("Min Distance", "npc_bombardment_min_dist", 0, 1000, 0)
            panel:ControlHelp("  Min range in units.  Default: 400")

            panel:AddControl("Label", { Text = "" })

            -- ---- Strike Types ----
            AddColoredHeader(panel, "Strike Types", 30)

            panel:CheckBox("Allow Aircraft Strikes", "npc_bombardment_allow_air")
            panel:ControlHelp("  A-10, AH-6, OH-58, P-47D, Typhoon, F-4E.\n  Auto-suppressed if skybox is sealed above target.")

            panel:CheckBox("Allow Special Strikes  (WP / Napalm)", "npc_bombardment_allow_special")
            panel:ControlHelp("  White Phosphorus artillery and F-4E Napalm runs.")

            panel:AddControl("Label", { Text = "" })

            -- ---- Strike reference ----
            AddColoredHeader(panel, "Available Strikes (all equal weight)", 30)

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
