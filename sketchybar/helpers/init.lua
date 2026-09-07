-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

-- SB-M-04 fix: removed `os.execute("(cd helpers && make)")`, which rebuilt the
-- C helpers on every bar launch/reload, ignored failures, and depended on the
-- working directory. Build helpers manually when their sources change:
--   make -C ~/.config/sketchybar/helpers
