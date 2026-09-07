local settings = require("settings")
local colors = require("colors")

local M = {}

-- ---------------------------------------------------------------------------
-- Main clock/date item (behavior preserved)
-- ---------------------------------------------------------------------------

M.cal = sbar.add("item", "cal", {
	icon = {
		color = colors.white,
		padding_left = 6,
		font = {
			style = settings.font.style_map["Black"],
			size = 12.0,
		},
	},
	label = {
		color = colors.white,
		padding_right = 10,
		width = 80,
		align = "right",
		font = { family = settings.font.numbers },
	},
	position = "right",
	update_freq = 1,
	padding_left = 1,
	padding_right = 1,
	background = {
		color = colors.transparent,
		border_color = colors.black,
		border_width = 0,
	},
	popup = { align = "right" },
})

M.cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
	M.cal:set({ icon = os.date("%a. %b %d "), label = os.date("%H:%M:%S") })
end)

-- ---------------------------------------------------------------------------
-- F1: upcoming-event countdown — 12h horizon, "Event Name | Time Left",
-- urgency colors, compact font, no stale/negative countdowns
-- ---------------------------------------------------------------------------
local HORIZON = 12 * 3600
local SEP = " | "
local MAX_TOTAL = 34 -- hard cap on "Title | Countdown" so the countdown always survives

local POPUP_MAX_EVENTS = 8

local ICAL_CMD =
	"icalBuddy -nc -f -ec 'Holidays in United States,Japan Holidays' -iep 'title,datetime' -b '' -ss '' -tf '%H:%M' -df '%b %d' -li 12 eventsToday+2"

M.upcoming = sbar.add("item", "cal.upcoming", {
	position = "right",
	icon = { drawing = false },
	label = {
		color = colors.blue,
		font = {
			family = settings.font.numbers,
			size = 10.0, -- intentionally smaller than primary bar text (density)
		},
		max_chars = MAX_TOTAL + 2, -- backstop; Lua-side truncation is authoritative
		padding_left = 4,
		padding_right = 2,
	},
	update_freq = 60, -- local countdown re-render every minute
	drawing = false,
	click_script = "open -a Calendar",
})

-- upcoming events sorted by start time (only qualifying ones are kept)
local events = {}

local REL_DAY = { ["today"] = 0, ["tomorrow"] = 1, ["day after tomorrow"] = 2 }
local MONTHS = {
	Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
	Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12,
}

local function midnight(offset_days)
	local now = os.date("*t")
	return os.time({ year = now.year, month = now.month, day = now.day + offset_days, hour = 0, min = 0, sec = 0 })
end

local function parse_when(line)
	local times = line:match("^day after tomorrow%s+at%s+(.+)$")
	local day = times and "day after tomorrow"
	if not day then
		times = line:match("^tomorrow%s+at%s+(.+)$")
		day = times and "tomorrow"
	end
	if not day then
		times = line:match("^today%s+at%s+(.+)$")
		day = times and "today"
	end
	local offset
	if day then
		offset = REL_DAY[day]
	else
		local mon, d, abs_times = line:match("^(%a+)%s+(%d+),?%s+at%s+(.+)$")
		if mon and MONTHS[mon] and abs_times then
			local now = os.date("*t")
			local base = os.time({ year = now.year, month = MONTHS[mon], day = tonumber(d), hour = 0, min = 0 })
			offset = math.floor((base - midnight(0)) / 86400)
			times = abs_times
		else
			offset = REL_DAY[line]
			if offset == nil then
				return nil
			end
			return midnight(offset), midnight(offset) + 86399, true, offset
		end
	end

	local h1, m1, h2, m2 = times:match("^(%d+):(%d+)%s*%-%s*(%d+):(%d+)")
	if not h1 then
		return nil
	end
	local base = midnight(offset)
	local start_t = base + tonumber(h1) * 3600 + tonumber(m1) * 60
	local end_t = base + tonumber(h2) * 3600 + tonumber(m2) * 60
	if end_t < start_t then
		end_t = end_t + 86400
	end
	return start_t, end_t, false, offset
end

local function fetch_events()
	sbar.exec(ICAL_CMD, function(output)
		if type(output) ~= "string" or output == "" then
			-- provider failure or genuinely no events; re-render handles both
			return
		end

		local now = os.time()
		local clean = output:gsub("\27%[[0-9;]*m", "")
		local list = {}
		local title = nil
		for line in clean:gmatch("[^\r\n]+") do
			if line:match("^%s") then
				local when = line:match("^%s*(.-)%s*$")
				if title and when then
					local start_t, end_t = parse_when(when)
					if start_t and end_t and end_t > now and start_t < now + HORIZON then
						table.insert(list, { title = title, start = start_t, ends = end_t })
					end
					title = nil
				end
			else
				title = line:match("^%s*(.-)%s*$")
			end
		end
		table.sort(list, function(a, b)
			return a.start < b.start
		end)
		events = list
		M.render_upcoming(now)
	end)
end

-- compact countdown: "5h 18m" / "1h 04m" / "42m" / "Now" (no seconds)
local function fmt_countdown(secs)
	if secs <= 60 then
		return "Now"
	end
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	if h >= 1 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm", m)
end

-- urgency: cool far away, warming up, warning, urgent
local function urgency_color(start_t, now)
	local dt = start_t - now
	if dt <= 30 * 60 then
		return colors.red
	elseif dt <= 2 * 3600 then
		return colors.orange
	elseif dt <= 6 * 3600 then
		return colors.yellow
	else
		return colors.blue
	end
end

-- builds the exact "Event Name | Time Left" string; truncates ONLY the title
-- so the complete countdown is always visible
local function format_event(ev, now)
	local dt = ev.start - now
	local countdown = fmt_countdown(dt)
	local avail = MAX_TOTAL - #countdown - #SEP
	local title = ev.title
	if #title > avail then
		title = title:sub(1, math.max(1, avail - 1)) .. "…"
	end
	return title .. SEP .. countdown
end

function M.render_upcoming(now)
	now = now or os.time()
	-- drop events that have ended since the last fetch (staleness guard)
	local alive = {}
	for _, ev in ipairs(events) do
		if ev.ends > now and ev.start < now + HORIZON then
			table.insert(alive, ev)
		end
	end
	events = alive

	local next_ev = events[1]
	if next_ev then
		M.upcoming:set({
			drawing = true,
			label = {
				string = format_event(next_ev, now),
				color = urgency_color(next_ev.start, now),
			},
		})
	else
		M.upcoming:set({ drawing = false })
	end
end

M.upcoming:subscribe({ "routine", "system_woke", "forced" }, function()
	-- every 5th minute-level tick (i.e. ~every 5 min) re-fetch from icalBuddy;
	-- otherwise re-render the countdown locally (cheap, no subprocess)
	-- re-fetch from icalBuddy every minute (per user request); the fetch
	-- callback re-renders the countdown with fresh data
	fetch_events()
end)

M.upcoming:subscribe("display_change", fetch_events)

-- ---------------------------------------------------------------------------
-- F2: upcoming-events popup on the main calendar item
-- ---------------------------------------------------------------------------
local function build_events_popup()
	sbar.remove("/cal\\.popup\\..*/")

	local now = os.time()
	local count = math.min(#events, POPUP_MAX_EVENTS)
	if count == 0 then
		sbar.add("item", "cal.popup.none", {
			position = "popup." .. M.cal.name,
			width = 210,
			align = "center",
			label = { string = "No events in the next 12h", color = colors.grey },
		})
		return
	end

	for i = 1, count do
		sbar.add("item", "cal.popup.evt." .. i, {
			position = "popup." .. M.cal.name,
			width = 210,
			align = "left",
			label = {
				string = format_event(events[i], now),
				color = urgency_color(events[i].start, now),
				font = {
					family = settings.font.numbers,
					size = 10.0,
				},
				padding_left = 8,
			},
			click_script = "open -a Calendar",
		})
	end
end

M.cal:subscribe("mouse.clicked", function(env)
	local query = M.cal:query()
	local drawing = query and query.popup and query.popup.drawing
	if drawing ~= "on" then
		build_events_popup()
		M.render_upcoming() -- fresh countdowns for the popup rows
	end
	M.cal:set({ popup = { drawing = "toggle" } })
end)

return M
