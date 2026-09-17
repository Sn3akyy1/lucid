-------------------
---- AUTOSTART ----
-------------------

 hl.on("hyprland.start", function () 
   hl.exec_cmd("awww-daemon")
   --hl.exec_cmd("waybar")
   --hl.exec_cmd("swaync")
   -- launch-shell.sh picks the Qt scene graph backend before starting the
   -- shell: the proprietary nvidia driver needs Vulkan to get animations off
   -- the 60fps basic render loop. plain quickshell if it is not installed yet
   local launcher = os.getenv("HOME") .. "/.config/lucid/launch-shell.sh"
   hl.exec_cmd("[ -x '" .. launcher .. "' ] && exec '" .. launcher .. "' || exec quickshell")
   hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'")
   hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
   hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'FairyWren_Dark'")
 end)