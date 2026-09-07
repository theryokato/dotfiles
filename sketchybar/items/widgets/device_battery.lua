local colors = require("colors")
local settings = require("settings")

-- SB-F3: Connected-device battery (AirPods, Magic Mouse/Keyboard/Trackpad).
-- Data source: system_profiler SPBluetoothDataType -json (the only reliable
-- source on this system; ioreg exposes no battery for AirPods here).
-- Poll: every 150s (routine) + on bluetooth_change / system_woke / popup open.
-- No Bluetooth scans, no persistent processes, no network, no identifiers
-- displayed: friendly device names + battery percentages only.

local D = {}
local popup_width = 220

local ICON_BY_TYPE = {
	Headphones = "🎧",
	Keyboard = "⌨️ ",
	Mouse = "🖱",
	Trackpad = "🖱",
}
local DEFAULT_ICON = "🔋"

-- jq: flatten the name-keyed entries of device_connected into a compact array.
-- Missing battery keys become JSON null and are never fabricated in Lua.
local PROFILE_CMD =
	"system_profiler SPBluetoothDataType -json | jq -c "
	.. "'[.SPBluetoothDataType[0].device_connected[]? "
	.. "| to_entries[0] | .value + {name: .key} "
	.. "| {name: .name, minor: .device_minorType, "
	.. "left: .device_batteryLevelLeft, right: .device_batteryLevelRight, "
	.. "case: .device_batteryLevelCase, batt: .device_batteryLevel}]'"

local function pct(value)
	if type(value) ~= "string" then
		return nil
	end
	return tonumber(value:match("(%d+)"))
end

D.devices = sbar.add("item", "widgets.devices", {
	position = "right",
	icon = {
		string = DEFAULT_ICON,
		font = { size = 13.0 },
	},
	label = {
		font = { family = settings.font.numbers },
		padding_right = 6,
	},
	update_freq = 150,
	drawing = false,
	popup = { align = "center" },
})

sbar.add("item", "devices.header", {
	position = "popup." .. D.devices.name,
	icon = {
		string = "Device Batteries",
		width = popup_width,
		align = "center",
		font = {
			family = settings.font.text,
			style = settings.font.style_map["Bold"],
		},
	},
	label = { drawing = false },
})

local function remove_entries()
	sbar.remove("/devices\\.entry\\..*/")
end

local last_update = 0
local function update_devices()
	-- Cooldown: system_profiler itself churns Bluetooth state, which makes
	-- sketchybar emit bluetooth_change again. Without this cooldown the refresh
	-- becomes a self-sustaining loop.
	local now = os.time()
	if now - last_update < 15 then
		return
	end
	last_update = now

	sbar.exec(PROFILE_CMD, function(devices)
		if type(devices) ~= "table" then
			devices = {}
		end

		local battery_devices = {}
		for _, dev in ipairs(devices) do
			local values = {}
			for _, v in ipairs({ dev.left, dev.right, dev["case"], dev.batt }) do
				local n = pct(v)
				if n then
					table.insert(values, n)
				end
			end
			if #values > 0 then
				table.sort(values)
				table.insert(battery_devices, {
					name = dev.name or "Device",
					minor = dev.minor,
					min = values[1], -- honest aggregate: lowest available level
					left = pct(dev.left),
					right = pct(dev.right),
					batt = pct(dev.batt),
					case = pct(dev["case"]),
				})
			end
		end

		remove_entries()

		if #battery_devices == 0 then
			-- nothing connected with battery data: hide entirely
			D.devices:set({ drawing = false, popup = { drawing = false } })
			return
		end

		local primary = battery_devices[1]
		D.devices:set({
			drawing = true,
			icon = { string = ICON_BY_TYPE[primary.minor] or DEFAULT_ICON },
			label = { string = primary.min .. "%" },
		})

		-- popup rows: one name row per device + detail rows for AirPods-style data
		for i, dev in ipairs(battery_devices) do
			sbar.add("item", "devices.entry." .. i .. ".name", {
				position = "popup." .. D.devices.name,
				icon = {
					string = ICON_BY_TYPE[dev.minor] or DEFAULT_ICON,
					width = popup_width / 2,
					align = "left",
				},
				label = {
					string = dev.name,
					max_chars = 18,
					width = popup_width / 2,
					align = "right",
				},
			})
			local rows = {}
			if dev.left or dev.right or dev["case"] then
				if dev.left then
					table.insert(rows, { "Left", dev.left })
				end
				if dev.right then
					table.insert(rows, { "Right", dev.right })
				end
				if dev["case"] then
					table.insert(rows, { "Case", dev["case"] })
				end
			else
				table.insert(rows, { "Battery", dev.batt })
			end
			for j, row in ipairs(rows) do
				sbar.add("item", "devices.entry." .. i .. "." .. j, {
					position = "popup." .. D.devices.name,
					icon = {
						string = row[1],
						width = popup_width / 2,
						align = "left",
						color = colors.grey,
					},
					label = {
						string = row[2] .. "%",
						width = popup_width / 2,
						align = "right",
						font = { family = settings.font.numbers },
					},
				})
			end
		end
	end)
end

D.devices:subscribe({ "routine", "forced", "system_woke", "bluetooth_change" }, update_devices)

D.devices:subscribe("mouse.clicked", function()
	local should_draw = D.devices:query().popup.drawing == "off"
	D.devices:set({ popup = { drawing = "toggle" } })
	if should_draw then
		-- refresh on open so values are never stale (user-initiated: bypass cooldown)
		last_update = 0
		update_devices()
	end
end)

D.devices:subscribe("mouse.exited.global", function()
	D.devices:set({ popup = { drawing = false } })
end)

return D