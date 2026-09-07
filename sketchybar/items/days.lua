local icons = require("icons")
local icons_map = require("helpers.app_icons")
local colors = require("colors")
local settings = require("settings")

local M = {}
local CACHE_FILE = os.getenv("HOME") .. "/.cache/sketchybar/last_time.txt"
local coming_days = ""

M.days = sbar.add("item", "widgets.days", {
	position = "right",
	padding_left = 0,
	padding_right = 0,
	icon = {
		string = icons.moon_data.new,
	},
	update_freq = 3600,
	popup = {
		align = "right",
	},
})

M.set_time = sbar.add("item", "widgets.set_time", {
	position = "popup." .. M.days.name,
	width = 170,
	align = "center",
	icon = {
		string = "set_time",
	},
})

M.last_time = sbar.add("item", {

	position = "popup." .. M.days.name,
	width = 170,
	icon = { string = "Last Date: ", align = "left" },
	drawing = true,
})

M.already_time = sbar.add("item", {
	position = "popup." .. M.days.name,
	width = 170,
	icon = { string = "", align = "center" },
	drawing = true,
})

local function days_between(date_str)
	-- Parse the input date string (assumed format "YYYY-MM-DD")
	local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
	year, month, day = tonumber(year), tonumber(month), tonumber(day)

	local current_time = os.time()
	local current_date = os.date("*t", current_time)

	local given_time = os.time({ year = year, month = month, day = day })

	local difference = os.difftime(current_time, given_time) / (24 * 3600)

	return math.floor(difference)
end

local function map_days_icon(date_str)
	if not date_str or date_str == "" then
		return "?"
	end

	local days_since = tonumber(days_between(date_str)) + 1

	local MOON_PHASES = {
		{ 1, 7, icons.moon_data.new }, -- new moon
		{ 7, 12, icons.moon_data.crescent }, -- waxing crescent
		{ 12, 18, icons.moon_data.quarter }, -- first quarter
		{ 18, 24, icons.moon_data.gibbous }, -- waxing gibbous
		{ 24, 30, icons.moon_data.full }, -- full moon
	}

	-- Iterate moon phases and return the matching icon
	for _, phase in ipairs(MOON_PHASES) do
		local min_days, max_days, icon = phase[1], phase[2], phase[3]
		if days_since >= min_days and days_since < max_days then
			return icon
		end
	end

	-- Default to a question mark for unknown states
	return "?"
end

local function write_time_to_cache()
	local current_time = os.time()
	local current_date = os.date("*t", current_time)
	local date_str = os.date("%Y-%m-%d", current_time)

	os.execute("mkdir -p " .. os.getenv("HOME") .. "/.cache/sketchybar")

	local file = io.open(CACHE_FILE, "w")
	if file then
		file:write(date_str)
		file:close()
	end
end

local function read_time_from_cache()
	local file = io.open(CACHE_FILE, "r")
	if file then
		local time_str = file:read("*a")
		file:close()
		return time_str
	end
	return nil
end

M.days:subscribe("mouse.clicked", function()
	local drawing = M.days:query().popup.drawing
	M.days:set({ popup = { drawing = "toggle" } })
	M.set_time:set({ icon = { string = "Set Date" }, drawing = true })
	local cached_time = read_time_from_cache()
	local time_length = days_between(cached_time)
	if cached_time then
		local time_length = days_between(cached_time)
		M.last_time:set({
			icon = { string = "Last Date: " .. cached_time },
		})
		M.already_time:set({ icon = { string = "Already    :   " .. time_length + 1 .. " days" } })
	end
	M.days:set({ icon = { string = map_days_icon(cached_time) } })
end)

M.set_time:subscribe("mouse.clicked", function()
	write_time_to_cache()
	local cached_time = read_time_from_cache()
	print(cached_time)
	local time_length = days_between(cached_time)
	if cached_time then
		local time_length = days_between(cached_time)
		M.last_time:set({
			icon = { string = "Last Date: " .. cached_time },
		})
		M.already_time:set({ icon = { string = "Already    :   " .. time_length + 1 .. " days" } })
	end
	M.days:set({ icon = { string = map_days_icon(cached_time) } })
end)

return M
