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

sbar.add("item", {
	width = 5,
})

M.media_cover = sbar.add("item", "media.cover", {
	position = "left",
	background = {
		image = {
			string = "media.artwork",
			scale = 0.85,
			-- corner_radius = 10,
		},
		color = colors.transparent,
		-- corner_radius = 10,
	},
	label = { drawing = false },
	icon = { drawing = false },
	drawing = false,
	updates = true,
	popup = {
		align = "center",
		horizontal = true,
	},
	padding_right = -2,
	padding_left = -0.5,
})

M.media_artist = sbar.add("item", {
	position = "left",
	drawing = false,
	padding_left = 3,
	padding_right = 0,
	width = 0,
	icon = { drawing = false },
	label = {
		width = 0,
		font = { size = 9 },
		-- color = colors.with_alpha(colors.white, 0.6),
		color = colors.orange,
		max_chars = 18,
		y_offset = 6,
	},
})

M.media_title = sbar.add("item", {
	position = "left",
	drawing = false,
	padding_left = 3,
	padding_right = 0,
	icon = { drawing = false },
	label = {
		-- color = colors.with_alpha(colors.white, 0.6),
		color = colors.orange,
		font = { size = 11 },
		width = 0,
		max_chars = 16,
		y_offset = -5,
	},
})

-- SB-F2: album row shown as the first popup child
M.media_album = sbar.add("item", {
	position = "popup." .. M.media_cover.name,
	icon = {
		string = "♪",
		font = { size = 9 },
		color = colors.orange,
	},
	label = {
		font = { size = 9 },
		color = colors.orange,
		max_chars = 16,
		width = 90,
		align = "left",
	},
})

sbar.add("item", {
	position = "popup." .. M.media_cover.name,
	icon = { string = icons.media.back },
	label = { drawing = false },
	click_script = "nowplaying-cli previous",
})
-- SB-F2: named play/pause so its icon can reflect state; Next; Open Spotify
M.playpause = sbar.add("item", {
	position = "popup." .. M.media_cover.name,
	icon = { string = icons.media.play_pause },
	label = { drawing = false },
	click_script = "nowplaying-cli togglePlayPause",
})
sbar.add("item", {
	position = "popup." .. M.media_cover.name,
	icon = { string = icons.media.forward },
	label = { drawing = false },
	click_script = "nowplaying-cli next",
})
sbar.add("item", {
	position = "popup." .. M.media_cover.name,
	icon = { string = "♫", font = { size = 10 } },
	label = { drawing = false },
	click_script = "open -a Spotify",
})

local interrupt = 0
local function animate_detail(detail)
	if not detail then
		interrupt = interrupt - 1
	end
	if interrupt > 0 and not detail then
		return
	end

	sbar.animate("tanh", 30, function()
		M.media_artist:set({ label = { width = detail and "dynamic" or 0 } })
		M.media_title:set({ label = { width = detail and "dynamic" or 0 } })
		return
	end)
end

M.media_bracket = sbar.add("bracket", { M.media_cover.name, M.media_artist.name, M.media_title.name }, {
	background = {
		-- padding_right = -20,
		padding_left = 0,
		color = colors.bg3,
		border_width = 0,
	},
})

-- SB-F2: SF Symbol glyphs for playback state (play.fill / pause.fill)
local play_icon = "􀊄"
local pause_icon = "􀊆"

-- Custom event: sketchybar swallows external triggers of its built-in
-- media_change event (its internal media subsystem is dead on macOS 26),
-- so the provider re-emits as media_update (proven deliverable).
sbar.add("event", "media_update")

M.media_cover:subscribe({ "media_change", "media_update" }, function(env)
	-- guard: some sources emit media_change without INFO
	if not env.INFO then
		return
	end
	-- SB-fix: media-control reports bundleIdentifier + "playing" boolean;
	-- keep sketchybar-native schema (app/state) as fallback.
	local app_key = env.INFO.bundleIdentifier or env.INFO.app
	if not app_key then
		return
	end
	if whitelist[app_key] then
		-- SB-fix: with a custom event, artwork arrives as a decoded file path
		-- (the "media.artwork" placeholder only works for sketchybar's internal
		-- media_change machinery). Only use it when the file has content.
		local artwork_path = env.INFO.artwork_path
		if type(artwork_path) == "string" and #artwork_path > 0 then
			local af = io.open(artwork_path, "rb")
			local size = af and af:seek("end") or 0
			if af then
				af:close()
			end
			if size > 0 then
				M.media_cover:set({ background = { image = { string = artwork_path } } })
			end
		end
		local has_track = env.INFO.title ~= nil and env.INFO.title ~= ""
		local playing
		if env.INFO.playing ~= nil then
			playing = (env.INFO.playing == true or env.INFO.playing == "true" or env.INFO.playing == 1)
		else
			playing = (env.INFO.state == "playing") or (env.INFO.state == nil and has_track)
		end
		-- playing (or unknown-state-with-track): show; paused/stopped: hide
		local drawing = has_track and playing
		M.media_title:set({ drawing = drawing, label = env.INFO.title or "" })
		M.media_artist:set({ drawing = drawing, label = env.INFO.artist or "" })
		M.media_album:set({ label = env.INFO.album or "" })
		M.playpause:set({ icon = { string = playing and pause_icon or play_icon } })
		M.media_cover:set({ drawing = drawing })

		if drawing then
			animate_detail(true)
			interrupt = interrupt + 1
			sbar.delay(5, animate_detail)
		else
			M.media_cover:set({ popup = { drawing = false } })
		end
	end
end)

M.media_cover:subscribe("mouse.entered", function(env)
	interrupt = interrupt + 1
	animate_detail(true)
end)

M.media_cover:subscribe("mouse.exited", function(env)
	animate_detail(false)
end)

M.media_cover:subscribe("mouse.clicked", function(env)
	M.media_cover:set({ popup = { drawing = "toggle" } })
end)

M.media_title:subscribe("mouse.exited.global", function(env)
	M.media_cover:set({ popup = { drawing = false } })
end)

return M
