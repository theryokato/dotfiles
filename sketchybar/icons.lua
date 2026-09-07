local settings = require("settings")

local icons = {
	sf_symbols = {
		plus = "􀅼",
		loading = "􀖇",
		apple = "􀣺",
		gear = "􀍟",
		cpu = "􀫥",
		clipboard = "􀉄",
		control_center = "􀜊",
		switch = {
			on = "􁏮",
			off = "􁏯",
		},
		volume = {
			_100 = "􀊩",
			_66 = "􀊧",
			_33 = "􀊥",
			_10 = "􀊡",
			_0 = "􀊣",
		},
		temperature = {
			_66 = "􁏄",
			_33 = "􀇬",
			_0 = "􁏃",
		},
		percent = {
			_0 = "􁐙",
			_25 = "􁰉",
			_50 = "􁐚",
			_75 = "􀍾",
			_100 = "􁐛",
		},

		weather = {
			sunny = "􀆭",
			partly = "􀇔",
			cloudy = "􀇂",
			rainy = "􀇆",
			snowy = "􀇎",
			clear = "􀇀",
			foggy = "􀇊",
			stormy = "􀇞",
		},
		battery = {
			_100 = "􀛨",
			_75 = "􀺸",
			_50 = "􀺶",
			_25 = "􀛩",
			_0 = "􀛪",
			charging = "􀢋",
		},
		wifi = {
			upload = "􀄨",
			download = "􀄩",
			connected = "􀙇",
			disconnected = "􀙈",
			router = "􁓤",
		},
		media = {
			back = "􀊊",
			forward = "􀊌",
			play_pause = "􀊈",
			-- Correct transport symbols (verified against the SF Pro glyph set):
			-- play.fill / pause.fill / backward.end.fill / forward.end.fill
			play = "\u{100284}",
			pause = "\u{100286}",
			prev = "\u{10028E}",
			next = "\u{100290}",
		},
		tempture = {
			tempture_icon_1 = "󱤋",
			tempture_icon_2 = "􀇬",
		},
	},

	-- Alternative NerdFont icons
	nerdfont = {
		plus = "",
		loading = "",
		apple = "",
		gear = "",
		cpu = "",
		clipboard = "Missing Icon",

		switch = {
			on = "󱨥",
			off = "󱨦",
		},
		volume = {
			_100 = "",
			_66 = "",
			_33 = "",
			_10 = "",
			_0 = "",
		},
		battery = {
			_100 = "",
			_75 = "",
			_50 = "",
			_25 = "",
			_0 = "",
			charging = "",
		},
		wifi = {
			upload = "",
			download = "",
			connected = "󰖩",
			disconnected = "󰖪",
			router = "Missing Icon",
		},
		media = {
			back = "",
			forward = "",
			play_pause = "",
		},
	},
}

if not (settings.icons == "NerdFont") then
	return icons.sf_symbols
else
	return icons.nerdfont
end
