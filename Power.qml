import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
pragma Singleton

// the session's power actions, in one place for every surface that offers them,
// and the power profiles over the power-profiles-daemon bus (tuned-ppd speaks it
// too): the names, icons and cycling shared by the system tile, its panel and the toasts
Singleton {
    id: root

    readonly property var actions: [
        { "id": "lock", "label": "Lock", "icon": "lock" },
        { "id": "suspend", "label": "Suspend", "icon": "bedtime" },
        { "id": "logout", "label": "Log out", "icon": "logout" },
        { "id": "reboot", "label": "Restart", "icon": "restart_alt" },
        { "id": "shutdown", "label": "Shut down", "icon": "power_settings_new" }
    ]

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    // why performance is running below par, e.g. "lap-detected"; empty when it isn't
    readonly property string degradation: PowerProfiles.degradationReason || ""
    readonly property var holds: PowerProfiles.holds || []
    readonly property var available: root.hasPerformance ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    // settled: the caller has already waited out its own exit
    function run(id, settled) {
        if (id === "lock") {
            Lockscreen.lock(settled ? 0 : Theme.barDurEnter + Theme.ms(60));
            return ;
        }
        if (id === "logout") {
            // uwsm only stops a session it started; a lua config reads a dispatch as
            // lua, where a bare "exit" is no dispatcher, and a hyprlang one wants it bare
            Quickshell.execDetached(["sh", "-c", "uwsm stop 2>/dev/null || hyprctl dispatch 'hl.dsp.exit()' || hyprctl dispatch exit"]);
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

    function name(p) {
        if (p === PowerProfile.Performance)
            return "Performance";

        if (p === PowerProfile.PowerSaver)
            return "Power saver";

        return "Balanced";
    }

    function description(p) {
        if (p === PowerProfile.Performance)
            return "Full speed, for more heat and less battery";

        if (p === PowerProfile.PowerSaver)
            return "Cooler and quieter, and the battery lasts longer";

        return "Speed and battery life kept in step";
    }

    // a bolt, a leaf and a gauge, as material symbol names
    function symbol(p) {
        if (p === PowerProfile.Performance)
            return "bolt";

        if (p === PowerProfile.PowerSaver)
            return "eco";

        return "speed";
    }

    function degradationText(reason) {
        if (reason === "lap-detected")
            return "Performance is held back while the laptop sits on a lap.";

        if (reason === "high-operating-temperature")
            return "Performance is held back until the machine cools down.";

        return "Performance is held back (" + reason + ").";
    }

    function set(p) {
        if (root.available.indexOf(p) >= 0 && p !== root.profile)
            PowerProfiles.profile = p;

    }

    function cycle() {
        const i = root.available.indexOf(root.profile);
        root.set(root.available[(i + 1) % root.available.length]);
    }
}
