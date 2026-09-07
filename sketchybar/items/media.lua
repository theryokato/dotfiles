local icons = require("icons")
local colors = require("colors")

local whitelist = {
	["Spotify"] = true, ["Music"] = true, ["Cider"] = true, ["Arc"] = true, ["spotify_player"] = true,
	-- SB-fix: media-control (the macOS 26 media source) reports bundle ids
	["com.spotify.client"] = true,
	["com.apple.Music"] = true,
	["com.ciderstore.Cider"] = true,
	["company.thebrowser.Browser"] = true,
	["com.brave.Browser"] = true,
}

-- SB-fix: spawn the media-control stream provider (sketchybar's native
-- media_change is dead on macOS 26; see helpers/media_control.sh).
-- Kill both the wrapper script AND its media-control child (the child
-- survives pkill-by-script-name and would orphan otherwise).
sbar.exec(
	"pkill -f 'helpers/media_control.sh' 2>/dev/null; pkill -f 'mediaremote-adapter.pl' 2>/dev/null; $CONFIG_DIR/helpers/media_control.sh"
)

local M = {}

-- ---------------------------------------------------------------------------
-- UX design (rev 2):
--   bar    : glyph + fixed-width scrolling title/artist - NO artwork on the
--            bar; stays visible while paused (dimmed) so the layout never
--            jumps; the glyph is a direct play/pause toggle.
--   popup  : artwork thumbnail (fixed 32px box), title / artist-album
--            (scrolling), working transport buttons (media-control -
--            nowplaying-cli is dead on macOS 26), elapsed/duration, and an
--            "Open <app>" control driven by the playing bundle id.
-- ---------------------------------------------------------------------------

local BAR_TITLE_WIDTH = 130
local BAR_ARTIST_WIDTH = 100
local POPUP_TEXT_WIDTH = 120

-- dimmed palette for the paused state
local dim_white = colors.with_alpha(colors.white, 0.45)
local dim_grey = colors.with_alpha(colors.grey, 0.45)
local dim_orange = colors.with_alpha(colors.orange, 0.45)

local play_icon = "\u{0001004C4}"
local pause_icon = "\u{0001004C6}"

local current_app = nil

sbar.add("item", { width = 5 })

-- Anchor: shows play/pause glyph, toggles playback on click, hosts the popup
M.media_anchor = sbar.add("item", "media.anchor", {
	position = "left",
	icon = {
		string = play_icon,
		font = { size = 13 },
		color = colors.white,
	},
	label = { drawing = false },
	drawing = false,
	updates = true,
	click_script = "media-control toggle-play-pause",
	padding_right = 2,
	popup = { align = "left", horizontal = true },
})

M.media_title = sbar.add("item", "media.title", {
	position = "left",
	drawing = false,
	padding_left = 4,
	padding_right = 0,
	icon = { drawing = false },
	scroll_texts = true,
	label = {
		string = "",
		width = BAR_TITLE_WIDTH,
		align = "left",
		font = { size = 10 },
		color = colors.white,
		y_offset = 6,
	},
})

M.media_artist = sbar.add("item", "media.artist", {
	position = "left",
	drawing = false,
	padding_left = 0,
	padding_right = 0,
	icon = { drawing = false },
	scroll_texts = true,
	label = {
		string = "",
		width = BAR_ARTIST_WIDTH,
		align = "left",
		font = { size = 9 },
		color = colors.grey,
		y_offset = -6,
	},
})

M.media_bracket = sbar.add("bracket", { M.media_anchor.name, M.media_title.name, M.media_artist.name }, {
	background = {
		padding_left = 0,
		color = colors.bg3,
		border_width = 0,
	},
})

-- ---------------------------------------------------------------------------
-- Popup
-- ---------------------------------------------------------------------------
M.popup_art = sbar.add("item", "media.popup.art", {
	position = "popup." .. M.media_anchor.name,
	width = 32,
	background = {
		height = 26,
		color = colors.transparent,
		border_width = 0,
		image = {
			string = "",
			scale = 0.18, -- ~150px source artwork -> ~27px inside the 32px box
			corner_radius = 6,
		},
	},
	label = { drawing = false },
	icon = { drawing = false },
	click_script = "open -b com.spotify.client", -- replaced dynamically per app
})

M.popup_title = sbar.add("item", "media.popup.title", {
	position = "popup." .. M.media_anchor.name,
	padding_left = 4,
	padding_right = 0,
	icon = { drawing = false },
	scroll_texts = true,
	label = {
		string = "",
		width = POPUP_TEXT_WIDTH,
		align = "left",
		font = { size = 10 },
		color = colors.white,
		y_offset = 5,
	},
})

M.popup_artist = sbar.add("item", "media.popup.artist", {
	position = "popup." .. M.media_anchor.name,
	padding_left = 4,
	padding_right = 0,
	icon = { drawing = false },
	scroll_texts = true,
	label = {
		string = "",
		width = POPUP_TEXT_WIDTH,
		align = "left",
		font = { size = 8 },
		color = colors.grey,
		y_offset = -5,
	},
})

sbar.add("item", "media.popup.prev", {
	position = "popup." .. M.media_anchor.name,
	icon = { string = icons.media.back },
	label = { drawing = false },
	click_script = "media-control previous-track",
})
M.playpause = sbar.add("item", "media.popup.playpause", {
	position = "popup." .. M.media_anchor.name,
	icon = { string = play_icon },
	label = { drawing = false },
	click_script = "media-control toggle-play-pause",
})
sbar.add("item", "media.popup.next", {
	position = "popup." .. M.media_anchor.name,
	icon = { string = icons.media.forward },
	label = { drawing = false },
	click_script = "media-control next-track",
})

M.popup_time = sbar.add("item", "media.popup.time", {
	position = "popup." .. M.media_anchor.name,
	icon = { drawing = false },
	label = {
		string = "",
		width = 52,
		align = "center",
		font = { size = 8 },
		color = colors.grey,
	},
})

M.popup_openapp = sbar.add("item", "media.popup.openapp", {
	position = "popup." .. M.media_anchor.name,
	icon = { drawing = false },
	label = {
		string = "",
		width = 64,
		align = "center",
		font = { size = 8 },
		color = colors.grey,
	},
	click_script = "open -b com.spotify.client", -- replaced dynamically per app
})

local function fmt_time(sec)
	sec = math.floor(tonumber(sec) or 0)
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function short_app_name(bundle)
	local names = {
		["com.spotify.client"] = "Spotify",
		["com.apple.Music"] = "Music",
		["com.ciderstore.Cider"] = "Cider",
		["company.thebrowser.Browser"] = "Arc",
		["com.brave.Browser"] = "Brave",
	}
	return names[bundle] or bundle:match("[%w%s]+$") or "Open"
end

M.media_anchor:subscribe({ "media_change", "media_update" }, function(env)
	if not env.INFO then
		return
	end
	local app_key = env.INFO.bundleIdentifier or env.INFO.app
	if not app_key or not whitelist[app_key] then
		return
	end

	current_app = app_key
	local info = env.INFO
	local has_track = info.title ~= nil and info.title ~= ""

	if not has_track then
		-- nothing to show at all
		M.media_anchor:set({ drawing = false })
		M.media_title:set({ drawing = false })
		M.media_artist:set({ drawing = false })
		return
	end

	local playing
	if info.playing ~= nil then
		playing = (info.playing == true or info.playing == "true" or info.playing == 1)
	else
		playing = (info.state == "playing") or (info.state == nil)
	end

	-- Paused: keep visible but dimmed so the bar layout never jumps and
	-- playback can be resumed directly from the bar.
	local title_color = playing and colors.white or dim_white
	local artist_color = playing and colors.grey or dim_grey
	local anchor_color = playing and colors.white or dim_orange

	-- artwork: popup thumbnail only (no image on the bar anymore)
	local artwork_path = info.artwork_path
	if type(artwork_path) == "string" and #artwork_path > 0 then
		local af = io.open(artwork_path, "rb")
		local size = af and af:seek("end") or 0
		if af then
			af:close()
		end
		if size > 0 then
			M.popup_art:set({ background = { image = { string = artwork_path } } })
		end
	end

	-- bar text
	M.media_title:set({
		drawing = true,
		label = { string = info.title or "", color = title_color },
	})
	M.media_artist:set({
		drawing = true,
		label = { string = info.artist or "", color = artist_color },
	})
	M.media_anchor:set({
		drawing = true,
		icon = { string = playing and pause_icon or play_icon, color = anchor_color },
	})

	-- popup contents
	M.popup_title:set({ label = { string = info.title or "" } })
	local artist_line = info.artist or ""
	if info.album ~= nil and info.album ~= "" then
		artist_line = artist_line .. " \u{2014} " .. info.album
	end
	M.popup_artist:set({ label = { string = artist_line } })
	M.playpause:set({ icon = { string = playing and pause_icon or play_icon } })

	local elapsed = info.elapsedTime
	local duration = info.duration
	if elapsed and duration then
		M.popup_time:set({ label = { string = fmt_time(elapsed) .. "/" .. fmt_time(duration) } })
	elseif duration then
		M.popup_time:set({ label = { string = "-:--/" .. fmt_time(duration) } })
	else
		M.popup_time:set({ label = { string = "" } })
	end

	M.popup_openapp:set({
		label = { string = short_app_name(app_key) },
		click_script = "open -b " .. app_key,
	})
	M.popup_art:set({
		click_script = "open -b " .. app_key,
	})
end)

M.media_title:subscribe("mouse.clicked", function()
	M.media_anchor:set({ popup = { drawing = "toggle" } })
end)

M.media_artist:subscribe("mouse.clicked", function()
	M.media_anchor:set({ popup = { drawing = "toggle" } })
end)

M.popup_artist:subscribe("mouse.exited.global", function()
	M.media_anchor:set({ popup = { drawing = false } })
end)

return M
