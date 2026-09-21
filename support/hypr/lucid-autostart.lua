-- starts the shell when Hyprland starts. the installer adds this to a Hyprland
-- config it did not replace; Lucid's own config does the same from
-- modules/autostart.lua (see there for why it is `test` and not `[`)
hl.on("hyprland.start", function ()
    local launcher = os.getenv("HOME") .. "/.config/lucid/launch-shell.sh"
    hl.exec_cmd("test -x '" .. launcher .. "' && exec '" .. launcher .. "' || exec quickshell")
end)
