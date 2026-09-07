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

local function executeShellCommand(command)
	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()

	local outputTable = {}
	for line in result:gmatch("[^\r\n]+") do
		local n = tonumber(line)
		if n then
			table.insert(outputTable, n)
		end
	end

	return outputTable
end

local empty_workspaces_command = "aerospace list-workspaces --empty --monitor all"
empty_workspaces_list = executeShellCommand(empty_workspaces_command)
-- local max_workspaces_command = "aerospace list-workspaces --count --all"
-- local max_workspaces = executeShellCommand(max_workspaces_command)
-- print("empty_workspaces_list: ", table.concat(max_workspaces, ", "))

local function updateWindows(workspace_index)
	local get_windows =
		string.format("aerospace list-windows --workspace %s --format '%%{app-name}' --json", workspace_index)
	local query_visible_workspaces =
		"aerospace list-workspaces --visible --monitor all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"
	local get_focus_workspaces = "aerospace list-workspaces --focused"
	sbar.exec(get_windows, function(open_windows)
		sbar.exec(get_focus_workspaces, function(focused_workspaces)
			sbar.exec(query_visible_workspaces, function(visible_workspaces)
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
									-- padding_right = 20,
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
					if no_app and workspace_index == tonumber(focused_workspaces) then
						icon_line = " —"
						workspaces[workspace_index]:set({
							icon = { drawing = true },
							label = {
								string = icon_line,
								drawing = true,
								-- padding_right = 20,
								font = "sketchybar-app-font:Regular:16.0",
								y_offset = -1,
							},
							background = { drawing = true },
							padding_right = 1,
							padding_left = 1,
						})
					end

					workspaces[workspace_index]:set({
						icon = { drawing = true },
						label = { drawing = true, string = icon_line },
						background = { drawing = true },
						padding_right = 1,
						padding_left = 1,
					})
				end)
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

	workspace:subscribe("SPACE_TRIGGER", function(env)
		local command = "aerospace list-workspaces --empty --monitor all"
		local empty_workspaces_list = executeShellCommand(command)
		-- local trigger_detail = env.detail == "true"
		if env.detail == "true" then
			for _, index_enter in ipairs(empty_workspaces_list) do
				updateWorkspaceHover(index_enter, true)
			end
		elseif env.detail == "false" then
			for _, index_exited in ipairs(empty_workspaces_list) do
				updateWindows(index_exited)
				-- print(index_exited)
				-- updateWorkspaceHover(index_exited, false)
			end
		end
	end)
	--
	-- workspace:subscribe("mouse.exited", function()
	-- 	updateWindows(workspace_index)
	-- end)

	workspace:subscribe("aerospace_focus_change", function()
		updateWindows(workspace_index)
	end)

	workspace:subscribe("display_change", function()
		updateWorkspaceMonitor(workspace_index)
		updateWindows(workspace_index)
	end)

	-- initial setup
	updateWorkspaceMonitor(workspace_index)
	updateWindows(workspace_index)

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

return workspaces
