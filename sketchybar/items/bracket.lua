local battery = require("items.widgets.battery")
local volume = require("items.widgets.volume")
local wifi = require("items.widgets.wifi")
local bluetooth = require("items.widgets.bluetooth")
local cpu_and_temp = require("items.widgets.cpu_and_temp")
local weather = require("items.weather")
-- local workspaces = require("items.spaces_aero")
-- local workspaces = require("items.spaces_yabai_dev")
local workspaces = require("items.spaces_aero_dev")
-- local workspaces = require("items.spaces")
-- local workspaces = require("items.spaces_flash_dev")
local apple = require("items.apple")
local cal = require("items.calendar")
-- local media = require("items.media")
-- local front_app = require("items.front_app")

local colors = require("colors")

-- Right outer glass capsule (wraps all right-side widgets)
local glass_capsule = {
	color = colors.bg3,        -- Base @ ~90%: dark glass base
	border_color = colors.bg2, -- Lavender @ ~22%: glass edge highlight
	border_width = 1,
	height = 30,
	corner_radius = 12,
}

sbar.add("bracket", {
	cpu_and_temp.cpu.name,
	cpu_and_temp.temp.name,
	wifi.wifi.name,
	wifi.wifi_up.name,
	wifi.wifi_down.name,
	volume.volume_icon.name,
	volume.volume_percent.name,
	bluetooth.bluetooth_icon.name,
	cal.cal.name,
	"cal.upcoming",
	weather.weather_icon.name,
	battery.battery.name,
	"widgets.devices",
}, { background = glass_capsule })

-- Left glass capsule (Apple icon + workspaces)
sbar.add("bracket", {
	apple.apple.name,
	workspaces[1].name,
	workspaces[2].name,
	workspaces[3].name,
	workspaces[4].name,
	workspaces[5].name,
	workspaces[6].name,
	workspaces[7].name,
	workspaces[8].name,
	workspaces[9].name,
	workspaces[10].name,
	-- media.media_cover.name,
	-- media.media_artist.name,
	-- media.media_title.name,
	-- front_app.front_app.name,
}, { background = glass_capsule })
