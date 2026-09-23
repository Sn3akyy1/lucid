import QtQuick
import Quickshell
import Quickshell.Hyprland
pragma Singleton

// the session's power actions, in one place for every surface that offers them
Singleton {
    id: root

    readonly property var actions: [
        { "id": "lock", "label": "Lock", "icon": "lock" },
        { "id": "suspend", "label": "Suspend", "icon": "bedtime" },
        { "id": "logout", "label": "Log out", "icon": "logout" },
        { "id": "reboot", "label": "Restart", "icon": "restart_alt" },
        { "id": "shutdown", "label": "Shut down", "icon": "power_settings_new" }
    ]

    function run(id) {
        if (id === "lock") {
            Lockscreen.lock();
            return ;
        }
        if (id === "logout") {
            // uwsm only stops a session it started; hyprland 0.56 takes lua dispatches only
            Quickshell.execDetached(["sh", "-c", "uwsm stop 2>/dev/null || hyprctl dispatch 'hl.dsp.exit()'"]);
            return ;
        }
        var cmds = {
            "suspend": ["systemctl", "suspend"],
            "hibernate": ["systemctl", "hibernate"],
            "reboot": ["systemctl", "reboot"],
            "shutdown": ["systemctl", "poweroff"]
        };
        if (cmds[id])
            Quickshell.execDetached(cmds[id]);

    }
}
