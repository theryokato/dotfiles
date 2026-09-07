-- Catppuccin Macchiato + iOS 26 Liquid Glass liquid glass color scheme
-- Design: high transparency + high blur radius + soft edge highlights = liquid glass look
-- https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md
return {
	-- Catppuccin Macchiato palette
	rosewater = 0xfff4dbd6,
	flamingo = 0xfff0c6c6,
	pink = 0xfff5bde6,
	mauve = 0xffc6a0f6,
	red = 0xffed8796,
	maroon = 0xffee99a0,
	peach = 0xfff5a97f,
	yellow = 0xffeed49f,
	green = 0xffa6da95,
	teal = 0xff8bd5ca,
	sky = 0xff91d7e3,
	sapphire = 0xff7dc4e4,
	blue = 0xff8aadf4,
	lavender = 0xffb7bdf8,
	text = 0xffcad3f5,
	subtext1 = 0xffb8c0e0,
	subtext0 = 0xffa5adcb,
	overlay2 = 0xff939ab7,
	overlay1 = 0xff8087a2,
	overlay0 = 0xff6e738d,
	surface2 = 0xff5b6078,
	surface1 = 0xff494d64,
	surface0 = 0xff363a4f,
	base = 0xff24273a,
	mantle = 0xff1e2030,
	crust = 0xff181926,

	-- Semantic aliases (consumed by items/widgets/default.lua)
	black = 0xff181926,      -- Crust
	white = 0xffcad3f5,      -- Text: primary icon/label color
	grey = 0xff939ab7,       -- Overlay2
	orange = 0xfff5a97f,     -- Peach
	magenta = 0xffc6a0f6,    -- Mauve
	transparent = 0x00000000,

	-- AeroSpace workspace colors (unfocused=Overlay1, focused=Text/Lavender highlights)
	aerospace_label_color = 0xff8087a2,          -- unfocused: Overlay1
	aerospace_border_color = 0x30b7bdf8,         -- focused border: Lavender highlight
	aerospace_label_highlight_color = 0xffcad3f5, -- focused label: Text
	aerospace_icon_highlight_color = 0xffb7bdf8,  -- focused icon: Lavender
	front_app_color = 0xffcad3f5,

	-- Full-width bar: fully transparent (floating capsule look)
	bar = {
		bg = 0x00000000,     -- transparent bar strip
		border = 0x30b7bdf8, -- Lavender glass edge highlight
	},
	-- Popups: liquid glass (high transparency + high blur)
	popup = {
		bg = 0x551e2030,     -- Mantle @33%: semi-transparent, glassy with blur_radius
		border = 0x55b7bdf8, -- Lavender glass edge highlight
	},
	-- Widget group backgrounds (translucent dark glass capsules)
	bg1 = 0x731e2030,  -- Mantle @ ~45%: translucent dark layer (menus, slider backdrop)
	bg2 = 0x38b7bdf8,  -- Lavender @ ~22%: capsule edge highlight
	bg3 = 0x9924273a,  -- Base @ ~60%: outer capsule, glassy but readable
	transparency = 0.85,
	blur_radius = 70,

	with_alpha = function(color, alpha)
		if alpha > 1.0 or alpha < 0.0 then
			return color
		end
		return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
	end,
}
