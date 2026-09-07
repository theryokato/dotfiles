require("items.apple")
-- require("items.spaces_aero")
-- require("items.spaces_yabai_dev") --yabai
require("items.spaces_aero_dev") --aerospace
-- require("items.spaces_flash_dev") --flash
-- require("items.front_app") -- removed per user request (frontmost-app widget)
require("items.media") -- left, right after the workspace capsule (CAVA visualizer + media popup)
-- require("items.menus")
-- require("items.spaces") --yabai
-- Right region — ORDER MATTERS, and it is REVERSED on screen: sketchybar lays
-- out right-positioned items in reverse creation order (first created = the
-- rightmost on screen). Desired right-side flow (left -> right on screen):
--   cal.upcoming (dynamic events island) -> status widgets -> weather -> clock
-- Therefore the creation order below is: clock, weather, status, events.
require("items.calendar")
require("items.weather")
require("items.widgets")
require("items.wallpaper")
require("items.calendar_events")
require("items.bracket")
