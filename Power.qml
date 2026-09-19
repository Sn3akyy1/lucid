import QtQuick
import Quickshell
import Quickshell.Services.UPower
pragma Singleton

// power profiles over the power-profiles-daemon bus (tuned-ppd speaks it too):
// the names, icons and cycling shared by the system tile, its panel and the toasts
Singleton {
    id: root

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    // why performance is running below par, e.g. "lap-detected"; empty when it isn't
    readonly property string degradation: PowerProfiles.degradationReason || ""
    readonly property var holds: PowerProfiles.holds || []
    readonly property var available: root.hasPerformance ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced]

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

    // a bolt, a leaf and a gauge
    function icon(p) {
        if (p === PowerProfile.Performance)
            return "M13 2 4 14h7l-1 8 9-12h-7l1-8Z";

        if (p === PowerProfile.PowerSaver)
            return "M20 4C11 4 4 8 4 16c0 1.1.2 2.1.5 3L3 20.5 4.4 22l1.6-1.6c.9.4 2 .6 3 .6 8 0 11-8 11-17Z";

        return "M12 4A10 10 0 0 0 2 14a9.9 9.9 0 0 0 1.35 5h17.3A9.9 9.9 0 0 0 22 14 10 10 0 0 0 12 4Zm1.41 11.41a2 2 0 1 1-2.82-2.82L17 9Z";
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
