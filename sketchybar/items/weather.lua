local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local M = {}
local popup_width = 210

-- ---------------------------------------------------------------------------
-- F5: weather — Open-Meteo (no API key, reliable, lat/lon based)
--   location : ipinfo.io city-level coordinates, cached on disk so the bar
--              never blocks on network at startup and does not re-query
--              ipinfo every refresh (privacy: city precision only, no GPS)
--   units    : Fahrenheit (US locale)
--   payload  : ONE request returns current conditions AND a 5-day forecast
--              (single timestamp source, no mixed fields)
--   failure  : cached response reused when fresh (< 6h); otherwise the last
--              rendered value stays until the next 30-min retry
-- ---------------------------------------------------------------------------

local CACHE_DIR = os.getenv("HOME") .. "/.cache/weather/"
os.execute("mkdir -p " .. CACHE_DIR)
local LOC_FILE = CACHE_DIR .. "location.txt" -- "lat,lon|City"
local WX_CACHE = CACHE_DIR .. "openmeteo_cache.txt" -- "ts|temp|code|daily..."
local CACHE_TTL = 6 * 3600
local WX_URL =
	"https://api.open-meteo.com/v1/forecast?current=temperature_2m,weather_code"
	.. "&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=5"
	.. "&temperature_unit=celsius&timezone=auto"

-- WMO weather interpretation codes -> existing icon set
local function wmo_icon(code)
	code = tonumber(code) or -1
	if code == 0 then
		return icons.weather.sunny
	elseif code == 1 or code == 2 then
		return icons.weather.partly
	elseif code == 3 then
		return icons.weather.cloudy
	elseif code == 45 or code == 48 then
		return icons.weather.foggy
	elseif (code >= 95 and code <= 99) then
		return icons.weather.stormy
	elseif (code >= 71 and code <= 77) or code == 85 or code == 86 then
		return icons.weather.snowy
	elseif (code >= 51 and code <= 67) or (code >= 80 and code <= 82) then
		return icons.weather.rainy
	end
	return icons.weather.partly
end

local function write_cache(temp, code, daily)
	local parts = { tostring(os.time()), tostring(temp), tostring(code) }
	for _, d in ipairs(daily) do
		parts[#parts + 1] = table.concat({ d.date, d.code, d.max, d.min }, ",")
	end
	local f = io.open(WX_CACHE, "w")
	if f then
		f:write(table.concat(parts, "|"))
		f:close()
	end
end

local function read_cache()
	local f = io.open(WX_CACHE, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	local ts, temp, code, rest = content:match("^(%d+)|(.-)|(.-)|(.*)$")
	if not ts then
		ts, temp, code = content:match("^(%d+)|(.-)|(.-)$")
		rest = ""
	end
	if not ts then
		return nil
	end
	local daily = {}
	for row in rest:gmatch("[^|]+") do
		local d, c, hi, lo = row:match("^([^,]*),([^,]*),([^,]*),([^,]*)$")
		if d then
			daily[#daily + 1] = { date = d, code = c, max = hi, min = lo }
		end
	end
	return { ts = tonumber(ts), temp = temp, code = code, daily = daily }
end

-- ---------------------------------------------------------------------------
-- items
-- ---------------------------------------------------------------------------
M.weather_icon = sbar.add("item", "widgets.weather", {
	position = "right",
	padding_left = -5,
	padding_right = -3,
	icon = {
		font = {
			style = settings.font.style_map["Regular"],
			size = 13.0,
		},
	},
	label = {
		font = {
			family = settings.font.numbers,
			style = settings.font.style_map["Bold"],
			size = 12.0,
		},
		string = "--\u{00B0}",
		color = colors.white,
	},
	update_freq = 600,
	popup = { align = "right" },
})

M.weather_location = sbar.add("item", {
	position = "popup." .. M.weather_icon.name,
	icon = {
		width = popup_width / 2,
		string = "Location 􀋑 :",
		font = { style = settings.font.style_map["Bold"] },
		align = "left",
	},
	label = {
		width = popup_width / 2,
		string = "--",
		align = "right",
	},
})

M.weather_cuurent_temp = sbar.add("item", {
	position = "popup." .. M.weather_icon.name,
	icon = {
		width = popup_width / 2,
		string = "Current 􂬮:",
		font = { style = settings.font.style_map["Bold"] },
		align = "left",
	},
	label = {
		width = popup_width / 2,
		align = "right",
		font = { family = settings.font.family },
		string = "--",
	},
})

-- ---------------------------------------------------------------------------
-- rendering / fetching
-- ---------------------------------------------------------------------------
local daily = {} -- cached forecast rows for the popup
local location_label = "--"

local function render_current(temp, code)
	M.weather_icon:set({
		icon = { string = wmo_icon(code) },
		label = { string = string.format("%.0f\u{00B0}", tonumber(temp) or 0) },
	})
	M.weather_cuurent_temp:set({ label = { string = string.format("%.0f\u{00B0}C", tonumber(temp) or 0) } })
end

local function apply_payload(payload, ts)
	local cur = payload.current
	if not cur then
		return
	end
	render_current(cur.temperature_2m, cur.weather_code)

	daily = {}
	local times = payload.daily and payload.daily.time or {}
	local codes = payload.daily and payload.daily.weather_code or {}
	local maxs = payload.daily and payload.daily.temperature_2m_max or {}
	local mins = payload.daily and payload.daily.temperature_2m_min or {}
	for i = 1, #times do
		daily[#daily + 1] = { date = times[i], code = codes[i], max = maxs[i], min = mins[i] }
	end
	write_cache(cur.temperature_2m, cur.weather_code, daily)
end

local function fetch_weather(loc)
	local lat, lon = loc:match("^(%-?%d+%.?%d*),(%-?%d+%.?%d*)$")
	if not lat or not lon then
		return
	end
	-- lat/lon are validated digits-only before they reach the shell/URL
	sbar.exec(
		"curl -x '' -s --max-time 8 '"
			.. WX_URL
			.. "&latitude="
			.. lat
			.. "&longitude="
			.. lon
			.. "'",
		function(payload)
			if type(payload) == "table" and payload.current then
				apply_payload(payload, os.time())
				return
			end
			-- failure path: reuse cached response if it is fresh enough
			local cache = read_cache()
			if cache and (os.time() - cache.ts) < CACHE_TTL then
				render_current(cache.temp, cache.code)
			end
			-- otherwise: keep the last rendered value; next routine retries
		end
	)
end

local function read_location()
	local f = io.open(LOC_FILE, "r")
	if not f then
		return nil, nil
	end
	local content = f:read("*a") or ""
	f:close()
	local coords, city = content:match("^(.-)|(.*)$")
	return coords, city
end

local function ensure()
	local coords, city = read_location()
	if coords and coords ~= "" then
		if city and city ~= "" then
			location_label = city
			M.weather_location:set({ label = { string = city } })
		end
		fetch_weather(coords)
	else
		-- one-time location bootstrap (async; never blocks the bar)
		sbar.exec("curl -x '' -s --max-time 5 'https://ipinfo.io/json' | jq -r '[.loc, .city] | @tsv'", function(out)
			local loc, city = (out or ""):match("^(.-)\t(.*)$")
			if loc and loc ~= "" and loc ~= "null" and loc:match("^%-?%d+%.?%d*,%-?%d+%.?%d*$") then
				local f = io.open(LOC_FILE, "w")
				if f then
					f:write(loc .. "|" .. (city or ""))
					f:close()
				end
				location_label = city or location_label
				M.weather_location:set({ label = { string = location_label } })
				fetch_weather(loc)
			end
		end)
	end
end

-- first paint shortly after the bar loads (async, non-blocking)
sbar.delay(2, ensure)

M.weather_icon:subscribe({ "routine", "forced", "system_woke" }, ensure)

-- popup: click toggles; forecast rows are built from cached daily data
local function weather_collapse()
	M.weather_icon:set({ popup = { drawing = false } })
	sbar.remove("/weather.item\\.*/")
end

local function build_forecast_rows()
	sbar.remove("/weather.item\\.*/")
	for i, d in ipairs(daily) do
		if i > 5 then
			break
		end
		sbar.add("item", "weather.item." .. i, {
			position = "popup." .. M.weather_icon.name,
			width = popup_width,
			icon = {
				width = 30,
				string = wmo_icon(d.code),
				align = "left",
				padding_left = 8,
			},
			label = {
				width = popup_width - 40,
				string = string.format("%s   %.0f\u{00B0} / %.0f\u{00B0}", d.date, tonumber(d.max) or 0, tonumber(d.min) or 0),
				align = "left",
				font = { family = settings.font.numbers, size = 10.0 },
				color = colors.white,
			},
		})
	end
end

M.weather_icon:subscribe("mouse.clicked", function()
	local drawing = M.weather_icon:query().popup.drawing
	M.weather_icon:set({ popup = { drawing = "toggle" } })
	if drawing ~= "on" then
		build_forecast_rows()
	end
end)

M.weather_icon:subscribe("mouse.exited.global", weather_collapse)

return M
