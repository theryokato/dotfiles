local battery = require("items.widgets.battery")
local wifi = require("items.widgets.wifi")
local bluetooth = require("items.widgets.bluetooth")
local mic = require("items.widgets.mic")
local device_battery = require("items.widgets.device_battery")
local weather = require("items.weather")
local workspaces = require("items.spaces_aero_dev")
local apple = require("items.apple")
local cal = require("items.calendar")
local cal_events = require("items.calendar_events")

local colors = require("colors")

-- Shared glass capsule (floating-island style)
local glass_capsule = {
	color = colors.bg3,        -- Base @ ~60%: dark glass base
	border_color = colors.bg2, -- Lavender @ ~22%: glass edge highlight
	border_width = 1,
	height = 30,
	corner_radius = 12,
	padding_left = 6,
	padding_right = 6,
}

-- RIGHT - C1: upcoming events (dynamic-width island; grows/shrinks on its own
-- so event text never shifts the status widgets or the clock)
sbar.add("bracket", {
	cal_events.upcoming.name,
}, { background = glass_capsule })

-- RIGHT - D: system status (network -> bluetooth -> audio-in -> power ->
-- per-device power; conditional `widgets.devices` sits outermost so its
-- appearance/disappearance does not shift the battery)
sbar.add("bracket", {
	wifi.wifi_up.name,
	wifi.wifi_down.name,
	wifi.wifi.name,
	bluetooth.bluetooth_icon.name,
	mic.mic.name,
	battery.battery.name,
	device_battery.devices.name,
}, { background = glass_capsule })

-- RIGHT - C2: weather + date/clock (both fixed-width; the clock anchors the
-- far-right corner and hosts the weather forecast + calendar events popups)
sbar.add("bracket", {
	weather.weather_icon.name,
	cal.cal.name,
}, { background = glass_capsule })

-- LEFT: navigation & context (global entry point before workspaces)
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
}, { background = glass_capsule })
