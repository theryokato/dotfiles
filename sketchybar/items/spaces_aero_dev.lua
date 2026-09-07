-- items/aerospace.lua
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local app_icons = require("helpers.app_icons")

sbar.add("event", "SPACE_TRIGGER")
local max_workspaces = 10
local query_workspaces =
	"aerospace list-workspaces --all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"
local workspace_monitor = {}

-- Add padding to the left
sbar.add("item", {
	icon = {
		color = colors.white,
		highlight_color = colors.red,
		drawing = false,
	},
	label = {
		color = colors.grey,
		highlight_color = colors.white,
		drawing = false,
	},
	background = {
		-- color = colors.with_alpha(colors.bg1, colors.transparency),
		color = colors.bg3,
		border_width = 0,
		height = 28,
		border_color = colors.bg3,
		corner_radius = 9,
		drawing = false,
	},
	padding_left = 6,
	padding_right = 0,
})

local workspaces = {}
local empty_workspaces = {}

-- SB-M-03 fix: the old executeShellCommand used blocking io.popen inside the
-- event loop and was also called once at load time (stalling bar startup).
-- This async variant runs through sbar.exec so the event loop never blocks.
local function listEmptyWorkspaces(callback)
	sbar.exec("aerospace list-workspaces --empty --monitor all", function(result)
		local outputTable = {}
		for line in tostring(result):gmatch("[^\r\n]+") do
			local n = tonumber(line)
			if n then
				table.insert(outputTable, n)
			end
		end
		callback(outputTable)
	end)
end

-- SB-M-03 fix: render a single workspace from pre-fetched batched data
-- (no subprocesses inside this function).
local function renderWorkspace(workspace_index, open_windows, focused_workspaces, visible_workspaces)
	local icon_line = ""
	local no_app = true
	for i, open_window in ipairs(open_windows) do
		no_app = false
		local app = open_window["app-name"]
		local lookup = app_icons[app]
		local icon = ((lookup == nil) and app_icons["Default"] or lookup)
		icon_line = icon_line .. " " .. icon
	end

	sbar.animate("sin", 15, function()
		for i, visible_workspace in ipairs(visible_workspaces) do
			if no_app and workspace_index == tonumber(visible_workspace["workspace"]) then
				local monitor_id = visible_workspace["monitor-appkit-nsscreen-screens-id"]
				icon_line = " —"
				workspaces[workspace_index]:set({
					icon = { drawing = true },
					label = {
						string = icon_line,
						drawing = true,
						font = "sketchybar-app-font:Regular:16.0",
						y_offset = -1,
					},
					background = { drawing = true },
					padding_right = 1,
					padding_left = 1,
					display = monitor_id,
				})
				return
			end
		end

		if no_app and workspace_index ~= tonumber(focused_workspaces) then
			workspaces[workspace_index]:set({
				icon = { drawing = false },
				label = { drawing = false },
				background = { drawing = false },
				padding_right = 0,
				padding_left = 0,
			})
			return
		end
		if no_app then
			icon_line = " —"
		end

		workspaces[workspace_index]:set({
			icon = { drawing = true },
			label = { drawing = true, string = icon_line },
			background = { drawing = true },
			padding_right = 1,
			padding_left = 1,
		})
	end)
end

-- SB-M-03 fix: one batched refresh for all workspaces. Previously every
-- workspace item ran its own 3-query pipeline on aerospace_focus_change,
-- spawning ~30 aerospace processes per focus change.
local function updateAllWorkspaces()
	local get_windows = "aerospace list-windows --all --format '%{workspace}%{app-name}' --json"
	local query_visible_workspaces =
		"aerospace list-workspaces --visible --monitor all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"
	local get_focus_workspaces = "aerospace list-workspaces --focused"
	sbar.exec(get_windows, function(all_windows)
		local by_workspace = {}
		for _, win in ipairs(all_windows) do
			local ws = tonumber(win["workspace"])
			if ws then
				by_workspace[ws] = by_workspace[ws] or {}
				table.insert(by_workspace[ws], win)
			end
		end
		sbar.exec(get_focus_workspaces, function(focused_workspaces)
			sbar.exec(query_visible_workspaces, function(visible_workspaces)
				for index = 1, max_workspaces do
					renderWorkspace(index, by_workspace[index] or {}, focused_workspaces, visible_workspaces)
				end
			end)
		end)
	end)
end

local function updateWorkspaceMonitor(workspace_index)
	sbar.exec(query_workspaces, function(workspaces_and_monitors)
		for _, entry in ipairs(workspaces_and_monitors) do
			local space_index = tonumber(entry.workspace)
			local monitor_id = entry["monitor-appkit-nsscreen-screens-id"]
			-- Skip non-numeric (letter) workspaces; the bar only renders 1..max_workspaces
			if space_index and monitor_id then
				workspace_monitor[space_index] = math.floor(monitor_id)
			end
		end
		if workspaces[workspace_index] then
			workspaces[workspace_index]:set({
				display = workspace_monitor[workspace_index],
			})
		end
	end)
end

local function isInList(list, element)
	for _, v in ipairs(list) do
		if v == element then
			return true
		end
	end
	return false
end

local function updateWorkspaceHover(workspace_index, trigger)
	if trigger == true then
		sbar.animate("sin", 15, function()
			local icon_line = " —"
			workspaces[workspace_index]:set({
				icon = { drawing = true },
				label = {
					string = icon_line,
					drawing = true,
					font = "sketchybar-app-font:Regular:16.0",
					y_offset = -1,
				},
				background = { drawing = true },
				padding_right = 1,
				padding_left = 1,
			})
		end)
	else
		sbar.animate("sin", 15, function()
			workspaces[workspace_index]:set({
				icon = { drawing = false },
				label = { drawing = false },
				background = { drawing = false },
				padding_right = 0,
				padding_left = 0,
			})
			return
		end)
	end
end

for workspace_index = 1, max_workspaces do
	local workspace = sbar.add("item", {
		icon = {
			color = colors.aerospace_label_color, -- unfocused: dim grey
			highlight_color = colors.aerospace_icon_highlight_color, -- focused: light grey
			drawing = false,
			font = { family = settings.font.numbers },
			string = workspace_index,
			padding_left = 10,
			padding_right = 5,
		},
		label = {
			padding_right = 10,
			color = colors.aerospace_label_color, -- unfocused: dim grey
			highlight_color = colors.aerospace_label_highlight_color, -- focused: light grey
			font = "sketchybar-app-font:Regular:16.0",
			y_offset = -1,
		},
		padding_right = 2,
		padding_left = 2,
		background = {
			color = colors.transparent,
			border_width = 0,
			height = 28,
			border_color = colors.aerospace_border_color,
		},
		click_script = "aerospace workspace " .. workspace_index,
	})

	workspaces[workspace_index] = workspace

	workspace:subscribe("aerospace_workspace_change", function(env)
		local focused_workspace = tonumber(env.FOCUSED_WORKSPACE)
		local is_focused = focused_workspace == workspace_index

		sbar.animate("circ", 15, function()
			workspace:set({
				icon = { highlight = is_focused },
				label = { highlight = is_focused },
				background = {
					-- Focused: faint translucent white glass base + bright white border; unfocused: fully transparent
					color = is_focused and 0x20ffffff or colors.transparent,
					border_width = is_focused and 1 or 0,
					border_color = colors.aerospace_border_color,
				},
				blur_radius = 70,
			})
		end)
	end)

	workspace:subscribe("mouse.entered", function()
		sbar.animate("tanh", 30, function()
			workspace:set({
				background = {
					color = colors.with_alpha(colors.white, 0.15),
					border_color = colors.with_alpha(colors.white, 0.35),
				},
			})
		end)
	end)

	workspace:subscribe({ "mouse.exited", "mouse.exited.global" }, function()
		sbar.animate("tanh", 30, function()
			workspace:set({
				background = {
					color = colors.transparent,
					height = 28,
					border_color = colors.aerospace_border_color,
				},
			})
		end)
	end)

	-- initial setup
	updateWorkspaceMonitor(workspace_index)
	-- SB-M-03 fix: focus/display/SPACE_TRIGGER handling moved to the single
	-- bar-level watcher after the workspace loop (10 duplicated subscriptions
	-- here previously caused ~30 subprocesses per focus change).

	sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
		local focused_index = tonumber(focused_workspace)
		-- Letter workspaces have no bar item; skip them
		if not focused_index or not workspaces[focused_index] then
			return
		end
		sbar.animate("sin", 15, function()
			workspaces[tonumber(focused_workspace)]:set({
				icon = { highlight = true },
				label = { highlight = true },
				background = {
					color = 0x20ffffff,
					border_width = 1,
					border_color = colors.aerospace_border_color,
				},
			})
		end)
	end)
end

-- SB-M-03 fix: single bar-level watcher consolidates the events that were
-- previously subscribed per workspace item (10x duplication). All workspace
-- rendering now happens from 3 batched aerospace queries per event.
local aero_watcher = sbar.add("item", "aerospace.watcher", {
	drawing = false,
	updates = false,
})

aero_watcher:subscribe("aerospace_focus_change", updateAllWorkspaces)

aero_watcher:subscribe("display_change", function()
	for index = 1, max_workspaces do
		updateWorkspaceMonitor(index)
	end
	updateAllWorkspaces()
end)

local last_space_trigger = 0
aero_watcher:subscribe("SPACE_TRIGGER", function(env)
	-- Note: nothing currently fires SPACE_TRIGGER anywhere on this system;
	-- kept functional but debounced + async in case it gets wired up later.
	local now = os.time()
	if now - last_space_trigger < 1 then
		return
	end
	last_space_trigger = now
	listEmptyWorkspaces(function(empty_list)
		if env.detail == "true" then
			for _, index_enter in ipairs(empty_list) do
				updateWorkspaceHover(index_enter, true)
			end
		elseif env.detail == "false" then
			-- one batched refresh instead of one query per exited workspace
			updateAllWorkspaces()
		end
	end)
end)

-- initial full render (replaces the per-workspace updateWindows calls)
updateAllWorkspaces()

return workspaces
