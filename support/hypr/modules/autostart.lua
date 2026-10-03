-------------------
---- AUTOSTART ----
-------------------

 hl.on("hyprland.start", function () 
   hl.exec_cmd("awww-daemon")
   --hl.exec_cmd("waybar")
   --hl.exec_cmd("swaync")
   -- the tilting cursor modules/plugins.lua configures. Hyprland never loads a
   -- plugin on its own, so without this it is gone again after every login.
   -- the script does nothing until the plugin has been built once, and builds
   -- it again by itself when Hyprland has changed since
   local cursor = os.getenv("HOME") .. "/.config/hypr/scripts/cursor-plugin.sh"
   hl.exec_cmd("test -x '" .. cursor .. "' && exec '" .. cursor .. "' ensure")
   -- launch-shell.sh picks the Qt scene graph backend before starting the
   -- shell: the proprietary nvidia driver needs Vulkan to get animations off
   -- the 60fps basic render loop. plain quickshell if it is not installed yet.
   -- `test`, not `[`: hyprland reads a leading [...] as exec rules (as in
   -- "[workspace 2] kitty"), so with `[ -x ... ]` nothing after it ran
   local launcher = os.getenv("HOME") .. "/.config/lucid/launch-shell.sh"
   hl.exec_cmd("test -x '" .. launcher .. "' && exec '" .. launcher .. "' || exec quickshell")
 end)