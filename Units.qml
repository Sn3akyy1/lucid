import QtQuick
import Quickshell
pragma Singleton

// how the shell reads out temperatures and speeds, from Prefs.units
Singleton {
    id: root

    readonly property bool imperial: Prefs.units === "imperial"

    // c in celsius; f is the source's own fahrenheit if it has one, else c is converted
    function temp(c, f) {
        if (!root.imperial)
            return Math.round(c);

        return f !== undefined ? f : Math.round(c * 9 / 5 + 32);
    }

    function deg(c, f) {
        return root.temp(c, f) + "°";
    }

    function degUnit(c) {
        return root.temp(c) + (root.imperial ? " °F" : " °C");
    }

    function wind(kmh, mph) {
        return root.imperial ? I18n.tr("%1 mph", mph) : kmh + " km/h";
    }

}
