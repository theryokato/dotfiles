local colors = require("colors")
local settings = require("settings")

-- F6: microphone/input status widget.
-- Only uses data macOS reliably exposes:
--   current input device  -> SwitchAudioSource -t input -c
--   input volume (0-100)  -> AppleScript "input volume of (get volume settings)"
-- There is NO reliable public signal for "microphone in use" on macOS, so the
-- widget deliberately does NOT claim one. No audio is ever read or recorded.

local M = {}
local popup_width = 220

-- "device name\nvolume" in one spawn
local MIC_INFO_CMD = [[
printf '%s\n%s\n' "$(SwitchAudioSource -t input -c)" "$(osascript -e 'input volume of (get volume settings)')"
]]

local mic_icon_glyph = "\u{1F399} " -- microphone emoji, consistent with device widgets

local dim_white = colors.with_alpha(colors.white, 0.4)

M.mic = sbar.add("item", "widgets.mic", {
	position = "right",
	icon = {
		string = mic_icon_glyph,
		font = { size = 13.0 },
		color = colors.white,
	},
	label = {
		string = "--%",
		font = { family = settings.font.numbers, size = 10.0 },
		color = colors.white,
		padding_right = 6,
	},
	update_freq = 10,
	popup = { align = "center" },
})

local function render(volume)
	volume = tonumber(volume)
	if not volume then
		M.mic:set({ label = { string = "--%" } })
		return
	end
	local dim = (volume == 0)
	M.mic:set({
		icon = { color = dim and dim_white or colors.white },
		label = {
			string = string.format("%d%%", volume),
			color = dim and dim_white or colors.white,
		},
	})
end

local function update_mic()
	sbar.exec(MIC_INFO_CMD, function(out)
		local device, volume = (out or ""):match("^(.-)\r?\n(.*)$")
		M.device_name = device and device:match("^%s*(.-)%s*$") or ""
		render(volume)
		M.input_volume = tonumber(volume)
	end)
end

M.mic:subscribe({ "routine", "forced", "system_woke" }, update_mic)

-- ---------------------------------------------------------------------------
-- popup
-- ---------------------------------------------------------------------------
local popup_device = sbar.add("item", "mic.popup.device", {
	position = "popup." .. M.mic.name,
	width = popup_width,
	icon = {
		string = "Input:",
		width = popup_width / 3,
		align = "left",
		padding_left = 8,
	},
	label = {
		width = popup_width * 2 / 3 - 8,
		string = "--",
		align = "left",
		max_chars = 24,
	},
})

local popup_level = sbar.add("item", "mic.popup.level", {
	position = "popup." .. M.mic.name,
	width = popup_width,
	icon = {
		string = "Level:",
		width = popup_width / 3,
		align = "left",
		padding_left = 8,
	},
	label = {
		width = popup_width * 2 / 3 - 8,
		string = "--%",
		align = "left",
	},
})

local mic_slider = sbar.add("slider", popup_width - 20, {
	position = "popup." .. M.mic.name,
	slider = {
		highlight_color = colors.blue,
		background = {
			height = 6,
			corner_radius = 3,
			color = colors.bg2,
		},
		knob = {
			string = "\u{000100001}",
			drawing = true,
		},
	},
	background = { color = colors.bg1, height = 2 },
})

-- live input-volume slider (same mechanism as the output volume slider):
-- sliders fire "mouse.clicked" with $PERCENTAGE continuously while dragging
local last_applied = -1
local last_second = 0
mic_slider:subscribe("mouse.clicked", function(env)
	local pct = tonumber(env.PERCENTAGE)
	if not pct then
		return
	end
	pct = math.max(0, math.min(100, math.floor(pct)))
	if pct == last_applied then
		return
	end
	local now = os.time()
	local delta = math.abs(pct - last_applied)
	local min_delta = (now == last_second) and 8 or 3
	if delta < min_delta then
		return
	end
	last_applied = pct
	last_second = now
	sbar.exec('osascript -e "set volume input volume ' .. pct .. '"', function()
		render(pct)
		popup_level:set({ label = { string = pct .. "%" } })
	end)
end)

sbar.add("item", "mic.popup.settings", {
	position = "popup." .. M.mic.name,
	width = popup_width,
	align = "center",
	label = { string = "Open Sound Settings", color = colors.white },
	click_script = 'open "x-apple.systempreferences:com.apple.Sound-Settings.extension"',
})

local function toggle_popup()
	local drawing = M.mic:query().popup.drawing
	M.mic:set({ popup = { drawing = "toggle" } })
	if drawing ~= "on" then
		popup_device:set({ label = { string = M.device_name ~= "" and M.device_name or "--" } })
		local vol = M.input_volume and math.floor(M.input_volume) or 0
		popup_level:set({ label = { string = vol .. "%" } })
		mic_slider:set({ slider = { percentage = vol } })
		last_applied = -1
		update_mic()
	end
end

M.mic:subscribe("mouse.clicked", toggle_popup)
M.mic:subscribe("mouse.exited.global", function()
	M.mic:set({ popup = { drawing = false } })
end)

return M
