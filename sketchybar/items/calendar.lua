local settings = require("settings")
local colors = require("colors")

local M = {}

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

local days_per_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function get_days_in_month(y, m)
	if m == 2 and ((y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0) then
		return 29
	end
	return days_per_month[m]
end

local function build_calendar()
	sbar.remove("/cal\\.popup\\..*/")

	local now = os.time()
	local year = tonumber(os.date("%Y", now))
	local month = tonumber(os.date("%m", now))
	local today = tonumber(os.date("%d", now))

	local month_names = {
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December",
	}

	local wday = tonumber(os.date("%w", os.time({ year = year, month = month, day = 1 })))
	local first_wday = wday == 0 and 7 or wday -- 1=Mon .. 7=Sun

	local num_days = get_days_in_month(year, month)

	local mono = {
		family = settings.font.numbers,
		style = settings.font.style_map["Regular"],
		size = 12.0,
	}
	local CHAR_W = 7.2

	sbar.add("item", "cal.popup.header", {
		position = "popup." .. M.cal.name,
		width = 220,
		icon = {
			width = 200,
			string = month_names[month] .. " " .. year,
			font = {
				family = settings.font.text,
				style = settings.font.style_map["Bold"],
				size = 14.0,
			},
			color = colors.white,
			align = "center",
		},
		label = { drawing = false },
	    align = "center",
	})

	sbar.add("item", "cal.popup.wdays", {
		position = "popup." .. M.cal.name,
		icon = {
			string = " Mo  Tu  We  Th  Fr  Sa  Su ",
			font = {
				family = settings.font.numbers,
				style = settings.font.style_map["Bold"],
				size = 12.0,
			},
			color = colors.grey,
			padding_left = 10,
			padding_right = 10,
		},
		label = { drawing = false },
	})

	local day = 1
	local week = 0
	while day <= num_days do
		week = week + 1
		local row = ""
		local leading_empty = 0

		for col = 1, 7 do
			if day == 1 and col < first_wday then
				leading_empty = leading_empty + 1
			elseif day > num_days then
				row = row .. "    "
			else
				if day == today then
					row = row .. string.format("[%2d]", day)
				else
					row = row .. string.format(" %2d ", day)
				end
				day = day + 1
			end
		end

		sbar.add("item", "cal.popup.week" .. week, {
			position = "popup." .. M.cal.name,
			icon = {
				string = row,
				font = mono,
				color = colors.white,
				padding_right = 10,
				padding_left = 10 + math.floor(leading_empty * 4 * CHAR_W),
			},
		})
	end
end

M.cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
	M.cal:set({ icon = os.date("%a. %d %b "), label = os.date("%H:%M:%S") })
end)

M.cal:subscribe("mouse.clicked", function(env)
	local query = M.cal:query()
	local drawing = query and query.popup and query.popup.drawing
	if drawing ~= "on" then
		build_calendar()
	end
	M.cal:set({ popup = { drawing = "toggle" } })
end)

-- M.cal:subscribe("mouse.exited.global", function(env)
-- 	M.cal:set({ popup = { drawing = false } })
-- end)

-- ---------------------------------------------------------------------------
-- SB-F1: compact upcoming-event item (icalBuddy)
-- Privacy: only title + datetime are ever requested (-iep title,datetime);
-- notes, locations, attendees and URLs are never fetched or displayed.
-- ---------------------------------------------------------------------------
M.upcoming = sbar.add("item", "cal.upcoming", {
	position = "right",
	icon = { drawing = false },
	label = {
		color = colors.white,
		font = { family = settings.font.numbers },
		max_chars = 22,
		padding_left = 4,
		padding_right = 2,
	},
	update_freq = 120,
	drawing = false,
	click_script = "open -a Calendar",
})

local ICAL_CMD =
	"icalBuddy -nc -f -iep 'title,datetime' -b '' -ss '' -tf '%H:%M' -df '%b %d' -li 12 eventsToday+2"

local REL_DAY = { ["today"] = 0, ["tomorrow"] = 1, ["day after tomorrow"] = 2 }
local MONTHS = {
	Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
	Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12,
}

local function midnight(offset_days)
	local now = os.date("*t")
	return os.time({ year = now.year, month = now.month, day = now.day + offset_days, hour = 0, min = 0, sec = 0 })
end

-- Parses an icalBuddy datetime line. Returns start_t, end_t, is_all_day, day_offset.
local function parse_when(line)
	-- note: Lua patterns have no alternation, so match each relative day explicitly
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
			-- all-day event: whole day
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
	-- events crossing midnight: treat end before start as "next day"
	if end_t < start_t then
		end_t = end_t + 86400
	end
	return start_t, end_t, false, offset
end

local function update_upcoming()
	sbar.exec(ICAL_CMD, function(output)
		if type(output) ~= "string" or output == "" then
			M.upcoming:set({ drawing = false })
			return
		end

		local now = os.time()
		local clean = output:gsub("\27%[[0-9;]*m", "") -- strip ANSI color codes
		local title = nil
		for line in clean:gmatch("[^\r\n]+") do
			if line:match("^%s") then
				-- indented line: the datetime of the last seen title
				local when = line:match("^%s*(.-)%s*$")
				if title and when then
					local start_t, end_t, is_all_day, offset = parse_when(when)
					if start_t and end_t and end_t > now then
						-- found the next event that has not ended
						local context
						if is_all_day then
							context = (offset == 0) and "today" or os.date("%a", start_t)
						elseif start_t <= now then
							-- currently ongoing: show minutes remaining
							context = math.max(1, math.ceil((end_t - now) / 60)) .. "m left"
						elseif os.date("%j", start_t) == os.date("%j", now) then
							context = os.date("%H:%M", start_t)
						else
							context = os.date("%a %H:%M", start_t)
						end
						M.upcoming:set({ drawing = true, label = title .. " · " .. context })
						return
					end
					title = nil
				end
			else
				title = line:match("^%s*(.-)%s*$")
			end
		end
		-- no upcoming events within the window
		M.upcoming:set({ drawing = false })
	end)
end

M.upcoming:subscribe({ "routine", "forced", "system_woke" }, update_upcoming)

return M
