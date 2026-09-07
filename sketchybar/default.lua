local settings = require("settings")
local colors = require("colors")

-- Equivalent to the --default domain
sbar.default({
	updates = "when_shown",
	icon = {
		font = {
			family = settings.font.text,
			style = settings.font.style_map["Bold"],
			size = 14.0,
		},
		color = colors.white,
		padding_left = settings.paddings,
		padding_right = settings.paddings,
		background = { image = { corner_radius = 9 } },
	},
	label = {
		font = {
			family = settings.font.text,
			style = settings.font.style_map["Semibold"],
			size = 13.0,
		},
		color = colors.white,
		padding_left = settings.paddings,
		padding_right = settings.paddings,
	},
	background = {
		-- Individual items are transparent by default; the glass effect comes from the outer bracket capsule
		-- Prevents padding spacer items from showing glass fragments
		height = 26,
		corner_radius = 9,
		border_width = 0,
		image = { corner_radius = 9 },
	},
	popup = {
		background = {
			border_width = 1,
			corner_radius = 14,      -- More rounded, closer to the iOS 26 popup style
			border_color = colors.popup.border,
			color = colors.popup.bg, -- 33% opacity bg + blur_radius combine for the liquid glass effect
			shadow = { drawing = true },
		},
		blur_radius = 80,            -- Popups blur more than the bar itself for a stronger frosted feel
	},
	blur_radius = 70,
	padding_left = 4,
	padding_right = 4,
	scroll_texts = true,
})
