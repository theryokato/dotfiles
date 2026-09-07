local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

-- F7: the Apple icon now toggles a compact settings popup.
-- (The old click_script opened the native Apple menu via the menus helper;
-- requested behavior is an in-bar settings popup instead.)

local M = {}
M.apple = sbar.add("item", "menu.apple", {
	icon = {
		font = { size = 18.0 },
		string = icons.apple,
		padding_right = 0,
		padding_left = 8,
		color = colors.orange,
	},
	label = { drawing = false },
	background = {
		border_width = 0, -- transparent; the outer bracket glass capsule provides the container
	},
	padding_left = 3,
	padding_right = 0,
	popup = { align = "left" },
})

sbar.add("item", "menu.apple.sysprefs", {
	position = "popup." .. M.apple.name,
	width = 150,
	align = "left",
	label = { string = "System Settings", color = colors.white, padding_left = 8 },
	click_script = "open -a 'System Settings'",
})

sbar.add("item", "menu.apple.reload", {
	position = "popup." .. M.apple.name,
	width = 150,
	align = "left",
	label = { string = "Reload SketchyBar", color = colors.white, padding_left = 8 },
	click_script = "sketchybar --reload",
})

M.apple:subscribe("mouse.clicked", function()
	local drawing = M.apple:query().popup.drawing
	M.apple:set({ popup = { drawing = "toggle" } })
end)

M.apple:subscribe("mouse.exited.global", function()
	M.apple:set({ popup = { drawing = false } })
end)

return M
