import QtQuick

// what the login screen can see of the machine: battery, network and the
// bluetooth radio, read off sysfs, the one place a greeter can see them.
// local reads need the greeter's QML_XHR_ALLOW_FILE_READ=1 (install-theme.sh);
// without it nothing shows and the machine's name stands in. the keymap comes
// from sddm itself. Lock turns these into the status widget's items
Item {
    id: sys

    property bool readable: true
    property string batPath: ""
    property string acPath: ""
    property bool hasBattery: false
    property int batteryPercent: 0
    property bool charging: false
    readonly property bool batteryLow: sys.hasBattery && !sys.charging && sys.batteryPercent <= 15
    property bool netKnown: false
    property bool ethernet: false
    property bool wifiUp: false
    // -1 no adapter, 0 off, 1 on
    property int btState: -1
    // "" for a file that is not there; a refusal turns the polling off
    function read(path) {
        try {
            var x = new XMLHttpRequest();
            x.open("GET", "file://" + path, false);
            x.send();
            return String(x.responseText || "").trim();
        } catch (e) {
            sys.readable = false;
            return "";
        }
    }

    function poll() {
        if (sys.batPath === "") {
            for (const n of ["BAT0", "BAT1", "BAT2", "BATT", "BATC", "CMB0"]) {
                if (sys.read("/sys/class/power_supply/" + n + "/type") === "Battery") {
                    sys.batPath = "/sys/class/power_supply/" + n;
                    break;
                }
            }
        }
        if (sys.acPath === "") {
            for (const n of ["AC", "ACAD", "AC0", "ADP0", "ADP1"]) {
                if (sys.read("/sys/class/power_supply/" + n + "/type") === "Mains") {
                    sys.acPath = "/sys/class/power_supply/" + n;
                    break;
                }
            }
        }
        if (!sys.readable)
            return ;

        if (sys.batPath !== "") {
            const cap = parseInt(sys.read(sys.batPath + "/capacity"));
            const st = sys.read(sys.batPath + "/status");
            sys.hasBattery = !isNaN(cap);
            sys.batteryPercent = isNaN(cap) ? 0 : Math.max(0, Math.min(100, cap));
            // what upower calls charging or fully charged, as the lock reads it:
            // held at its limit on mains power is fully charged to upower
            const mains = sys.acPath !== "" && sys.read(sys.acPath + "/online") === "1";
            sys.charging = st === "Charging" || st === "Full" || (st === "Not charging" && mains);
        }
        var any = false, eth = false, wifi = false;
        for (const line of sys.read("/proc/net/dev").split("\n").slice(2)) {
            const name = line.split(":")[0].trim();
            if (name === "" || name === "lo")
                continue;

            any = true;
            if (sys.read("/sys/class/net/" + name + "/operstate") !== "up")
                continue;

            if (sys.read("/sys/class/net/" + name + "/uevent").indexOf("DEVTYPE=wlan") !== -1)
                wifi = true;
            else if (/^(en|eth)/.test(name))
                eth = true;
        }
        sys.netKnown = any;
        sys.ethernet = eth;
        sys.wifiUp = wifi;
        var bt = -1;
        for (var i = 0; i < 32; i++) {
            if (sys.read("/sys/class/rfkill/rfkill" + i + "/type") === "bluetooth")
                bt = Math.max(bt, sys.read("/sys/class/rfkill/rfkill" + i + "/state") === "1" ? 1 : 0);

        }
        sys.btState = bt;
    }

    readonly property var layouts: keyboard.layouts || []
    readonly property bool canCycle: sys.layouts.length > 1
    readonly property string layoutName: {
        var l = sys.layouts[keyboard.currentLayout];
        if (!l)
            return "";

        return l.longName !== undefined && l.longName !== "" ? l.longName : String(l.shortName || "").toUpperCase();
    }

    Timer {
        running: sys.readable
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: sys.poll()
    }

}
