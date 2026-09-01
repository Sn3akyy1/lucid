-------------------
---- AUTOSTART ----
-------------------

 hl.on("hyprland.start", function () 
   hl.exec_cmd("awww-daemon")
   --hl.exec_cmd("waybar")
   --hl.exec_cmd("swaync")
   hl.exec_cmd("quickshell")
   hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'")
   hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
 end)