local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- -----------------------------------------------------------------------------
-- Music widget: CAVA visualizer + media popup, two metadata sources.
--
--   local  : helpers/media_control.sh stream (media_update) — local Spotify,
--            Brave/browsers, Apple Music, Cider, any whitelisted Mac player.
--   remote : helpers/spotify_connect.sh daemon (spotify_update) — Spotify
--            Connect playback on phones/speakers via the Spotify Web API.
--            Metadata only: phone audio NEVER reaches the Mac, so CAVA stays
--            frozen/dimmed for remote playback (no fake visualization).
--
--   source selection (deterministic):
--     local actively playing          -> local wins
--     local idle/paused + remote play -> remote (phone) wins
--     neither                         -> widget hidden
--     paused local with no remote     -> visible dimmed (previous behavior)
--
--   bar    : 8 slim CAVA-driven bars (real local audio via cava_stream.sh on
--            the EXISTING "BlackHole 2ch" source) + state glyph (popup host).
--   popup  : artwork, title/artist/album, source-or-device row, seekable
--            progress, transport rows. Controls route to the active source:
--            local -> media-control, remote -> Spotify Web API.
-- -----------------------------------------------------------------------------

local FREEZE_FILE = "/tmp/sketchybar_cava_frozen_" .. (os.getenv("USER") or "user")

local POPUP_W = 220

local whitelist = {
	["Spotify"] = true,
	["Music"] = true,
	["Cider"] = true,
	["spotify_player"] = true,
	["com.spotify.client"] = true,
	["com.apple.Music"] = true,
	["com.ciderstore.Cider"] = true,
	-- browsers (Media Session exposes tab audio as Now Playing)
	["com.brave.Browser"] = true,
	["company.thebrowser.Browser"] = true,
	["com.google.Chrome"] = true,
	["org.mozilla.firefox"] = true,
	["com.apple.Safari"] = true,
}

-- pretty source names for the popup source row
local app_names = {
	["com.spotify.client"] = "Spotify",
	["Spotify"] = "Spotify",
	["com.apple.Music"] = "Music",
	["Music"] = "Music",
	["com.ciderstore.Cider"] = "Cider",
	["Cider"] = "Cider",
	["com.brave.Browser"] = "Brave",
	["company.thebrowser.Browser"] = "Arc",
	["com.google.Chrome"] = "Chrome",
	["org.mozilla.firefox"] = "Firefox",
	["com.apple.Safari"] = "Safari",
}

local play_icon = icons.media.play
local pause_icon = icons.media.pause

-- Catppuccin gradient across the 8 bars (existing palette, no new colors)
local bar_colors = {
	colors.peach,
	colors.yellow,
	colors.green,
	colors.teal,
	colors.sky,
	colors.sapphire,
	colors.blue,
	colors.lavender,
}
local dim_factor = 0.35

-- view state
local current_source = nil -- "local" | "remote" | nil
local playing = false      -- effective playing state of the displayed source

-- local source (media_update)
local local_has_track = false
local local_playing = false
local local_time = 0
local local_info = nil
local current_app = nil
local empty_gen = 0

-- remote source (spotify_update)
local remote_available = true
local remote = nil
local remote_time = 0
local remote_controls_ok = true

-- shared
local last_track_key = nil
local elapsed = 0
local duration = 0

local function freeze()
	local f = io.open(FREEZE_FILE, "w")
	if f then
		f:close()
	end
end

local function unfreeze()
	os.remove(FREEZE_FILE)
end

-- Managed processes: kill stale instances (bracket pattern prevents pkill from
-- matching this very command line), then spawn exactly one of each.
sbar.exec(
	"pkill -f '[c]ava_stream.sh' 2>/dev/null; pkill -f '[c]ava -p' 2>/dev/null; $CONFIG_DIR/helpers/cava_stream.sh"
)
sbar.exec(
	"pkill -f '[m]edia_control.sh' 2>/dev/null; pkill -f '[m]ediaremote-adapter.pl' 2>/dev/null; $CONFIG_DIR/helpers/media_control.sh"
)
sbar.exec("pkill -f '[s]potify_connect.sh' 2>/dev/null; $CONFIG_DIR/helpers/spotify_connect.sh")

-- PART2

-- -----------------------------------------------------------------------------
-- Bar items
-- -----------------------------------------------------------------------------

sbar.add("item", { width = 2, position = "left" })

local M = {}

M.anchor = sbar.add("item", "media.anchor", {
	position = "left",
	icon = {
		string = pause_icon,
		font = { size = 12 },
		color = colors.white,
		padding_left = 2,
		padding_right = 1,
	},
	label = { drawing = false },
	drawing = false,
	updates = true,
	padding_right = 0,
	popup = {
		align = "left",
		background = { padding_left = 10, padding_right = 10 },
	},
})

M.vis = {}
for i = 1, 8 do
	M.vis[i] = sbar.add("item", "media.vis" .. i, {
		position = "left",
		width = 3,
		padding_left = 0,
		padding_right = 1,
		icon = { drawing = false },
		label = { drawing = false },
		drawing = false,
		background = {
			height = 2,
			color = bar_colors[i],
			corner_radius = 1,
			border_width = 0,
		},
	})
end

M.capsule = sbar.add("bracket", { M.anchor.name, "media.vis1", "media.vis2", "media.vis3", "media.vis4",
	"media.vis5", "media.vis6", "media.vis7", "media.vis8" }, {
	background = {
		color = colors.bg3,
		border_color = colors.bg2, -- match the left/right glass capsules
		border_width = 1,
		padding_left = 6,
		padding_right = 6,
	},
})

-- PART3

-- -----------------------------------------------------------------------------
-- Popup rows (single vertical popup; one item per row)
-- -----------------------------------------------------------------------------

-- Row 1: artwork (click = open player app)
M.popup_art = sbar.add("item", "media.popup.art", {
	position = "popup." .. M.anchor.name,
	width = POPUP_W,
	padding_left = 0,
	padding_right = 0,
	background = {
		height = 100,
		color = colors.transparent,
		border_width = 0,
		image = {
			string = "",
			scale = 0.16,
			corner_radius = 10,
		},
	},
	label = { drawing = false },
	icon = { drawing = false },
})

-- Row 2: track title
M.popup_title = sbar.add("item", "media.popup.title", {
	position = "popup." .. M.anchor.name,
	width = POPUP_W,
	padding_left = 0,
	padding_right = 0,
	scroll_texts = false,
	icon = {
		string = "",
		width = POPUP_W - 20,
		align = "left",
		max_chars = 30,
		font = { size = 12 },
		color = colors.white,
		padding_left = 10,
		padding_right = 0,
	},
	label = { drawing = false },
})

-- Row 3: artist
M.popup_artist = sbar.add("item", "media.popup.artist", {
	position = "popup." .. M.anchor.name,
	width = POPUP_W,
	padding_left = 0,
	padding_right = 0,
	scroll_texts = false,
	icon = {
		string = "",
		width = POPUP_W - 20,
		align = "left",
		max_chars = 30,
		font = { size = 10 },
		color = colors.grey,
		padding_left = 10,
		padding_right = 0,
	},
	label = { drawing = false },
})

-- Row 4: album
M.popup_album = sbar.add("item", "media.popup.album", {
	position = "popup." .. M.anchor.name,
	width = POPUP_W,
	padding_left = 0,
	padding_right = 0,
	scroll_texts = false,
	icon = {
		string = "",
		width = POPUP_W - 20,
		align = "left",
		max_chars = 30,
		font = { size = 10 },
		color = colors.subtext0,
		padding_left = 10,
		padding_right = 0,
	},
	label = { drawing = false },
})

-- Row 5: source indicator — local app name, or "Playing on <device>"
M.popup_source = sbar.add("item", "media.popup.source", {
	position = "popup." .. M.anchor.name,
	width = POPUP_W,
	padding_left = 0,
	padding_right = 0,
	scroll_texts = false,
	icon = {
		string = "",
		width = POPUP_W - 20,
		align = "left",
		max_chars = 40,
		font = { size = 9 },
		color = colors.with_alpha(colors.grey, 0.8),
		padding_left = 10,
		padding_right = 0,
	},
	label = { drawing = false },
})

-- Row 6: progress bar (click = seek, LOCAL source only)
M.popup_slider = sbar.add("slider", "media.popup.slider", POPUP_W - 24, {
	position = "popup." .. M.anchor.name,
	padding_left = 12,
	padding_right = 12,
	slider = {
		highlight_color = colors.orange,
		background = {
			height = 6,
			corner_radius = 3,
			color = colors.bg2,
		},
		knob = {
			string = "\u{100001}",
			drawing = true,
		},
	},
	background = { color = colors.transparent, border_width = 0 },
	icon = { drawing = false },
	label = { drawing = false },
})

-- Row 7: elapsed (left) / total (right)
M.popup_time = sbar.add("item", "media.popup.time", {
	position = "popup." .. M.anchor.name,
	width = POPUP_W,
	padding_left = 0,
	padding_right = 0,
	icon = {
		string = "0:00",
		width = POPUP_W / 2,
		align = "left",
		font = { family = settings.font.numbers, size = 9 },
		color = colors.grey,
		padding_left = 12,
		padding_right = 0,
	},
	label = {
		string = "",
		width = POPUP_W / 2,
		align = "right",
		font = { family = settings.font.numbers, size = 9 },
		color = colors.grey,
		padding_left = 0,
		padding_right = 12,
	},
})

-- Rows 8-10: transport controls (route to the active source)
M.popup_prev = sbar.add("item", "media.popup.prev", {
	position = "popup." .. M.anchor.name,
	width = POPUP_W,
	padding_left = 0,
	padding_right = 0,
	icon = {
		string = icons.media.prev,
		font = { size = 13 },
		width = 50,
		align = "center",
		padding_left = 4,
	},
	label = {
		string = "Previous",
		align = "left",
		font = { size = 10 },
		color = colors.grey,
	},
})

M.popup_play = sbar.add("item", "media.popup.play", {
	position = "popup." .. M.anchor.name,
	width = POPUP_W,
	padding_left = 0,
	padding_right = 0,
	icon = {
		string = play_icon,
		font = { size = 13 },
		width = 50,
		align = "center",
		padding_left = 4,
	},
	label = {
		string = "Play",
		align = "left",
		font = { size = 10 },
		color = colors.grey,
	},
})

M.popup_next = sbar.add("item", "media.popup.next", {
	position = "popup." .. M.anchor.name,
	width = POPUP_W,
	padding_left = 0,
	padding_right = 0,
	icon = {
		string = icons.media.next,
		font = { size = 13 },
		width = 50,
		align = "center",
		padding_left = 4,
	},
	label = {
		string = "Next",
		align = "left",
		font = { size = 10 },
		color = colors.grey,
	},
})

-- PART4

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

local function set_bar_colors(dim)
	for i = 1, 8 do
		M.vis[i]:set({
			background = { color = dim and colors.with_alpha(bar_colors[i], dim_factor) or bar_colors[i] },
		})
	end
end

local function hide_all()
	freeze()
	M.anchor:set({ drawing = false, popup = { drawing = false } })
	for i = 1, 8 do
		M.vis[i]:set({ drawing = false })
	end
	M.capsule:set({ drawing = false })
end

local function show_all()
	M.anchor:set({ drawing = true })
	for i = 1, 8 do
		M.vis[i]:set({ drawing = true })
	end
	M.capsule:set({ drawing = true })
end

local function truncate(s, n)
	if not s or #s <= n then
		return s or ""
	end
	return s:sub(1, n - 1) .. "…"
end

local function fmt_time(t)
	t = math.floor(t or 0)
	return string.format("%d:%02d", t // 60, t % 60)
end

local function update_progress()
	local pct = 0
	if duration and duration > 0 then
		pct = math.max(0, math.min(100, (elapsed / duration) * 100))
	end
	M.popup_slider:set({ slider = { percentage = pct } })
	M.popup_time:set({
		icon = { string = fmt_time(elapsed) },
		label = { string = (duration and duration > 0) and fmt_time(duration) or "" },
	})
end

local function set_popups(open)
	M.anchor:set({ popup = { drawing = open } })
end

local function toggle_popup()
	local open = M.anchor:query().popup.drawing == "on"
	set_popups(not open)
end

-- apply_text: title/artist/album + subtle source-or-device row
local function apply_text(info, remote_mode)
	M.popup_title:set({ icon = { string = truncate(info.title, 30) } })
	M.popup_artist:set({ icon = { string = truncate(info.artist or "", 30) } })
	M.popup_album:set({ icon = { string = truncate(info.album or "", 30) } })
	if remote_mode then
		local dev = info.device_name
		if not dev or dev == "" then
			dev = "Spotify Connect"
		end
		M.popup_source:set({ icon = { string = truncate("Playing on " .. dev, 40) } })
	else
		local app = app_names[info.bundleIdentifier or ""] or app_names[info.app or ""] or info.app or "Local media"
		M.popup_source:set({ icon = { string = truncate(app, 40) } })
	end
end

-- apply_artwork: real cover when the file is non-empty, else app icon fallback
local function apply_artwork(path, fallback_bundle)
	local ok = false
	if type(path) == "string" and #path > 0 then
		local af = io.open(path, "rb")
		local size = af and af:seek("end") or 0
		if af then
			af:close()
		end
		ok = (size or 0) > 0
	end
	if ok then
		M.popup_art:set({ background = { image = { string = path, drawing = true } } })
	else
		M.popup_art:set({
			background = { image = { string = "app." .. (fallback_bundle or "com.spotify.client"), drawing = true } },
		})
	end
end

-- transport buttons dim when the active Connect device rejects commands
local function set_transport_enabled(ok)
	local c = ok and colors.white or colors.with_alpha(colors.white, 0.3)
	M.popup_prev:set({ icon = { color = c } })
	M.popup_play:set({ icon = { color = c } })
	M.popup_next:set({ icon = { color = c } })
end

-- -----------------------------------------------------------------------------
-- Source selection + render
-- -----------------------------------------------------------------------------

local function source_now()
	local now = os.time()
	local local_fresh = local_has_track and (now - local_time) <= 15
	local remote_active = remote_available and remote ~= nil
		and remote.playing and (now - remote_time) <= 35
		and (remote.title ~= nil and remote.title ~= "")
	if local_playing and local_fresh then
		return "local"
	end
	if remote_active then
		return "remote"
	end
	if local_fresh then
		return "local_paused"
	end
	return nil
end

local function render()
	local s = source_now()
	if s == nil then
		if current_source then
			current_source = nil
			playing = false
			freeze()
			hide_all()
		end
		return
	end

	local mode = (s == "remote") and "remote" or "local"
	local info = (mode == "remote") and remote or (local_info or {})
	local now_playing = (s == "local") or (mode == "remote" and info.playing == true)

	if current_source ~= mode then
		-- switching source: full re-apply
		current_source = mode
		last_track_key = nil
		freeze() -- remote NEVER drives CAVA; local unfreezes below when playing
		if mode == "remote" then
			-- subtle static indicator: low frozen bars, dimmed
			for i = 1, 8 do
				M.vis[i]:set({ background = { height = 4 } })
			end
		end
		show_all()
		if mode == "local" then
			remote_controls_ok = true
		end
		set_transport_enabled(mode == "local" or remote_controls_ok)
	end

	if mode == "local" then
		if now_playing then
			unfreeze()
		else
			freeze()
		end
		if now_playing ~= playing or last_track_key == nil then
			set_bar_colors(not now_playing)
			if now_playing then
				M.anchor:set({ icon = { string = pause_icon, color = colors.white } })
			else
				M.anchor:set({ icon = { string = play_icon, color = colors.with_alpha(colors.white, 0.5) } })
			end
			M.popup_play:set({
				icon = { string = now_playing and pause_icon or play_icon },
				label = { string = now_playing and "Pause" or "Play" },
			})
		end
	else
		freeze() -- never fake local audio reactivity for remote playback
		if now_playing ~= playing then
			M.anchor:set({ icon = { string = now_playing and pause_icon or play_icon, color = colors.with_alpha(colors.white, 0.5) } })
			M.popup_play:set({
				icon = { string = now_playing and pause_icon or play_icon },
				label = { string = now_playing and "Pause" or "Play" },
			})
		end
		remote_controls_ok = not (info.restricted == true
			or (info.disallows and (info.disallows.pausing
				or info.disallows.skipping_next
				or info.disallows.skipping_prev
				or info.disallows.toggling_play_context)) == true)
		set_transport_enabled(remote_controls_ok)
	end
	playing = now_playing

	-- text + artwork on track change only (keeps scroll/truncation stable)
	local key = mode .. "|" .. tostring(info.title) .. "|" .. tostring(info.artist) .. "|" .. tostring(info.album)
	if key ~= last_track_key then
		last_track_key = key
		apply_text(info, mode == "remote")
		if mode == "local" then
			apply_artwork(info.artwork_path, info.bundleIdentifier or info.app)
		else
			apply_artwork(info.artwork_path, nil)
		end
	end

	elapsed = tonumber(info.elapsed or info.elapsedTime) or elapsed
	duration = tonumber(info.duration) or duration
	update_progress()
end

-- staleness watchdog: if events stop (network death, killed stream), re-run
-- the source decision so stale playback never lingers
local function watchdog()
	render()
	sbar.delay(5, watchdog)
end

-- PART5

-- -----------------------------------------------------------------------------
-- Event handlers
-- -----------------------------------------------------------------------------

-- LOCAL: generic macOS Now Playing (Spotify-on-Mac, Brave, Music, ...)
M.anchor:subscribe({ "media_update" }, function(env)
	local info = env.INFO
	if type(info) ~= "table" then
		return
	end

	local app_key = info.bundleIdentifier or info.app
	local title = info.title

	if title == nil or title == "" then
		-- transient null-title payloads occur on track transitions; only clear
		-- the local source when no real track event follows within ~1.2s
		if app_key == nil or whitelist[app_key] then
			local gen = empty_gen + 1
			empty_gen = gen
			local gen_time = os.time()
			sbar.delay(1.2, function()
				if empty_gen == gen and local_time <= gen_time then
					local_has_track = false
					local_playing = false
					render()
				end
			end)
		end
		return
	end

	if not whitelist[app_key or ""] then
		return
	end

	local new_playing
	if info.playing ~= nil then
		new_playing = (info.playing == true or info.playing == "true" or info.playing == 1)
	else
		new_playing = (info.state == "playing") or (info.state == nil)
	end

	local_has_track = true
	local_playing = new_playing
	local_time = os.time()
	local_info = info
	current_app = app_key
	empty_gen = empty_gen + 1 -- cancel any pending hide
	render()
end)

-- REMOTE: Spotify Connect (phone/speakers) via the Web API
M.anchor:subscribe({ "spotify_update" }, function(env)
	local info = env.INFO
	if type(info) ~= "table" then
		return
	end
	remote_time = os.time()
	if info.available == false then
		-- auth failed / refresh broken: disable ONLY the remote fallback
		remote_available = false
		remote = nil
		render()
		return
	end
	remote_available = true
	remote = info
	render()
end)

-- -----------------------------------------------------------------------------
-- Interactions
-- -----------------------------------------------------------------------------

M.anchor:subscribe("mouse.clicked", toggle_popup)
for i = 1, 8 do
	M.vis[i]:subscribe("mouse.clicked", toggle_popup)
end

-- popup auto-close (leave the popup area)
for _, item in ipairs({
	M.popup_art,
	M.popup_title,
	M.popup_artist,
	M.popup_album,
	M.popup_source,
	M.popup_slider,
	M.popup_time,
	M.popup_prev,
	M.popup_play,
	M.popup_next,
}) do
	item:subscribe("mouse.exited.global", function()
		set_popups(false)
	end)
end

-- seek: LOCAL source only (remote Connect seek is intentionally not exposed)
local last_seek_pct = -1
local last_seek_second = 0
M.popup_slider:subscribe("mouse.clicked", function(env)
	if current_source ~= "local" then
		return
	end
	if not (duration and duration > 0) then
		return
	end
	local pct = tonumber(env.PERCENTAGE)
	if not pct then
		return
	end
	pct = math.max(0, math.min(100, pct))
	local now = os.time()
	local delta = math.abs(pct - last_seek_pct)
	local min_delta = (now == last_seek_second) and 8 or 3
	if delta < min_delta then
		return
	end
	last_seek_pct = pct
	last_seek_second = now
	elapsed = (pct / 100) * duration
	update_progress()
	sbar.exec(string.format("media-control seek %.2f", elapsed))
end)

-- transport: route to whichever source is actually active. Local ->
-- media-control; remote -> Spotify Web API against the active Connect device
-- (no playback transfer). Restricted devices reject with 403; the helper does
-- a single attempt per click, never a retry loop.
M.popup_play:subscribe("mouse.clicked", function()
	if current_source == "remote" then
		if not remote_controls_ok then
			return
		end
		playing = not playing
		M.popup_play:set({
			icon = { string = playing and pause_icon or play_icon },
			label = { string = playing and "Pause" or "Play" },
		})
		M.anchor:set({ icon = { string = playing and pause_icon or play_icon } })
		sbar.exec("$CONFIG_DIR/helpers/spotify_connect.sh control " .. (playing and "play" or "pause"))
		return
	end
	playing = not playing
	M.popup_play:set({
		icon = { string = playing and pause_icon or play_icon },
		label = { string = playing and "Pause" or "Play" },
	})
	M.anchor:set({ icon = { string = playing and pause_icon or play_icon } })
	sbar.exec("media-control toggle-play-pause")
end)

M.popup_prev:subscribe("mouse.clicked", function()
	if current_source == "remote" then
		if remote_controls_ok then
			sbar.exec("$CONFIG_DIR/helpers/spotify_connect.sh control previous")
		end
		return
	end
	sbar.exec("media-control previous-track")
end)

M.popup_next:subscribe("mouse.clicked", function()
	if current_source == "remote" then
		if remote_controls_ok then
			sbar.exec("$CONFIG_DIR/helpers/spotify_connect.sh control next")
		end
		return
	end
	sbar.exec("media-control next-track")
end)

-- open the player: the local app, or Spotify (phone session) for remote
local function open_app()
	if current_source == "remote" then
		sbar.exec("open -b com.spotify.client")
	elseif current_app then
		sbar.exec("open -b " .. current_app)
	end
end
M.popup_art:subscribe("mouse.clicked", open_app)
M.popup_title:subscribe("mouse.clicked", open_app)

-- start the staleness watchdog
sbar.delay(5, watchdog)

return M
