import QtQuick
import Quickshell
import Quickshell.Io
import qs

// the login screen's view of the world, for the settings' preview of it: what
// sddm's greeter can know before anyone has logged in. no media, no
// notifications, no network names; the weather only as the last reading this
// account sent it, and only when allowed to
QtObject {
    id: data

    readonly property var now: Lockscreen.now
    readonly property string hourText: Lockscreen.hourText
    readonly property string minuteText: Lockscreen.minuteText
    readonly property string meridiem: Lockscreen.meridiem
    readonly property string greeting: Lockscreen.greeting
    readonly property string displayName: Lockscreen.displayName
    readonly property bool focused: Lockscreen.focused
    property string host: ""
    readonly property string lockedWord: data.host !== "" ? data.host : I18n.tr("Locked")
    readonly property var locale: I18n.locale

    function tr(text, ...args) {
        return I18n.tr(text, ...args); // i18n-dynamic
    }

    readonly property var weather: {
        var w = LockStyle.weatherSnap;
        if (!w)
            return ({
                "ok": false
            });

        return {
            "ok": true,
            "kind": w.kind,
            "temp": w.temp,
            "desc": w.desc,
            "hi": w.hi,
            "lo": w.lo,
            "feels": w.feels,
            "at": ""
        };
    }
    // sysfs can say a radio is up, not what it is joined to
    readonly property var statusItems: {
        var out = [];
        if (Lockscreen.hasBattery)
            out.push({
                "key": "battery",
                "glyph": Lockscreen.batteryGlyph,
                "label": Lockscreen.batteryPercent + "%",
                "short": Lockscreen.batteryPercent + "%",
                "tone": Lockscreen.batteryLow ? "error" : (Lockscreen.charging ? "success" : "normal")
            });

        out.push({
            "key": "network",
            "glyph": Lockscreen.netGlyph,
            "label": Lockscreen.ethernet ? I18n.tr("Ethernet") : (Lockscreen.wifiUp ? I18n.tr("Wi-Fi") : I18n.tr("Offline")),
            "tone": (Lockscreen.ethernet || Lockscreen.wifiUp) ? "accent" : "dim"
        });
        if (Lockscreen.btAdapter)
            out.push({
                "key": "bluetooth",
                "glyph": Lockscreen.btOn ? "bluetooth" : "bluetoothOff",
                "label": Lockscreen.btOn ? I18n.tr("Bluetooth on") : I18n.tr("Bluetooth off"),
                "tone": "dim"
            });

        if (Lockscreen.layoutShort !== "")
            out.push({
                "key": "keyboard",
                "glyph": "keyboard",
                "label": Lockscreen.layoutShort,
                "short": Lockscreen.layoutShort,
                "tone": "dim",
                "interactive": true
            });

        return out;
    }
    // no one is logged in to log out
    readonly property var powerActions: Lockscreen.powerActions.filter((a) => {
        return a.id !== "logout";
    })

    function activateStatus(key) {
    }

    function runPower(id) {
    }

    property FileView _hostFile: FileView {
        path: "/etc/hostname"
        onLoaded: data.host = this.text().trim()
    }

}
