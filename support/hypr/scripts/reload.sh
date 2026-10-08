#!/bin/sh
# SUPER+R: reload Hyprland, then restart the shell the way a login starts it,
# through launch-shell.sh, so it comes back on the same render backend
hyprctl reload

conf="$HOME/.config/quickshell"
qs kill -p "$conf" >/dev/null 2>&1 || pkill -x quickshell
# a second instance must not start while the first still holds its surfaces
i=0
while [ $i -lt 30 ] && qs list 2>/dev/null | grep -F "Config path: $conf/shell.qml" >/dev/null; do
    sleep 0.1
    i=$((i + 1))
done

launcher="$HOME/.config/lucid/launch-shell.sh"
if [ -x "$launcher" ]; then
    setsid "$launcher" >/dev/null 2>&1 &
else
    setsid quickshell >/dev/null 2>&1 &
fi
