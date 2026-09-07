-- require("items.widgets.control_center")
-- Right region ORDER MATTERS and is REVERSED on screen (first created =
-- rightmost). Created below: device batteries, battery, mic, bluetooth, wifi
-- so the on-screen left->right flow is: wifi -> bluetooth -> mic -> battery
-- -> device batteries.
require("items.widgets.device_battery")
require("items.widgets.battery")
require("items.widgets.mic")
require("items.widgets.bluetooth")
require("items.widgets.wifi")
-- require("items.widgets.weather")
-- require("items.widgets.cpu_and_temp") -- removed per user request (CPU graph)
-- require("items.widgets.front_app")
-- require("items.widgets.temperature")
-- require("items.widgets.cpu")
