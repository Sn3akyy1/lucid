import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// night light: warms the screen through hyprsunset's ipc. on by hand, or on a
// schedule (sunset to sunrise where Lucid's location says you are, or set
// hours). a flip by hand while a schedule runs holds until its next change,
// the way a phone does it. the colour fades in and out rather than snapping
Singleton {
    id: root

    // the colour with nothing warmed; hyprsunset's identity is the real off
    readonly property int neutral: 6500
    readonly property int minTemp: 2000
    readonly property int maxTemp: 6000

    // bumps every half minute so the schedule is re-read
    property int tick: 0
    // -1 none, 0 held off, 1 held on, until overrideUntil (ms)
    property int override: -1
    property real overrideUntil: 0
    // false once hyprsunset is known to be missing
    property bool available: true
    property bool started: false
    // one ipc call in flight at a time; the newest wish waits for it
    property string pending: ""
    property string sent: ""

    readonly property string schedule: Prefs.nightLightSchedule
    readonly property var sun: {
        root.tick;
        return root.sunTimes(Loc.now(), Loc.lat, Loc.lon);
    }
    // minutes after local midnight
    readonly property int fromMin: root.schedule === "sun" ? root.sun.set : Prefs.nightLightFrom
    readonly property int toMin: root.schedule === "sun" ? root.sun.rise : Prefs.nightLightTo
    readonly property bool scheduledOn: {
        root.tick;
        if (root.schedule !== "sun" && root.schedule !== "custom")
            return false;

        return root.inWindow(root.nowMin(), root.fromMin, root.toMin);
    }
    readonly property bool overridden: {
        root.tick;
        return root.override >= 0 && Loc.nowMs() < root.overrideUntil;
    }
    readonly property bool active: {
        if (root.schedule !== "sun" && root.schedule !== "custom")
            return Prefs.nightLight;

        return root.overridden ? root.override === 1 : root.scheduledOn;
    }
    readonly property int temperature: Math.max(root.minTemp, Math.min(root.maxTemp, Prefs.nightLightTemp))
    // what the tile and the panel say under the name
    readonly property string status: {
        if (!root.available)
            return "Install hyprsunset";

        // held by hand or not, on lasts to the window's end and off to its
        // start: a hold only ever runs up to the edge where the two agree
        if (root.schedule === "sun" || root.schedule === "custom")
            return root.active ? "On until " + root.clock(root.toMin) : "Off until " + root.clock(root.fromMin);

        return root.active ? "On" : "Off";
    }

    // how far the screen is warmed right now, 0 to 1. it chases active
    property real amount: 0

    function toggle() {
        root.set(!root.active);
    }

    function set(on) {
        if (root.schedule !== "sun" && root.schedule !== "custom") {
            Prefs.nightLight = on;
            return ;
        }
        if (on === root.scheduledOn) {
            root.override = -1;
            return ;
        }
        // held until the schedule next flips on its own
        root.override = on ? 1 : 0;
        let delta = root.nextChangeMin() - root.nowMin();
        if (delta <= 0)
            delta += 24 * 60;

        root.overrideUntil = Loc.nowMs() + delta * 60000 - Loc.now().getSeconds() * 1000;
    }

    function nowMin() {
        const d = Loc.now();
        return d.getHours() * 60 + d.getMinutes();
    }

    function inWindow(now, from, to) {
        if (from === to)
            return false;

        // an evening start and a morning end runs over midnight
        return from < to ? (now >= from && now < to) : (now >= from || now < to);
    }

    // whichever edge of the window comes next
    function nextChangeMin() {
        return root.inWindow(root.nowMin(), root.fromMin, root.toMin) ? root.toMin : root.fromMin;
    }

    function clock(mins) {
        const h = Math.floor(mins / 60) % 24;
        const m = mins % 60;
        if (Prefs.clock24h)
            return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0");

        return ((h % 12) || 12) + ":" + String(m).padStart(2, "0") + (h < 12 ? " am" : " pm");
    }

    // sunrise and sunset for a day, in local minutes, from NOAA's general
    // solar position equations: within a minute or two, no network needed.
    // where the sun never sets or never rises, a plain 21:00 to 7:00 stands in
    function sunTimes(date, lat, lon) {
        const rad = Math.PI / 180;
        const y = date.getFullYear();
        const day = Math.round((Date.UTC(y, date.getMonth(), date.getDate()) - Date.UTC(y, 0, 1)) / 86400000) + 1;
        const g = 2 * Math.PI / 365 * (day - 1);
        const eqtime = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g) - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
        const decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
        const cosH = Math.cos(90.833 * rad) / (Math.cos(lat * rad) * Math.cos(decl)) - Math.tan(lat * rad) * Math.tan(decl);
        if (!(cosH >= -1 && cosH <= 1))
            return {
            "rise": 7 * 60,
            "set": 21 * 60,
            "polar": true
        };

        const ha = Math.acos(cosH) / rad;
        const offset = Loc.zoneRead ? Loc.trueOffsetMin : Loc.engineOffsetMin;
        const wrap = (m) => {
            return ((Math.round(m) % 1440) + 1440) % 1440;
        };
        return {
            "rise": wrap(720 - 4 * (lon + ha) - eqtime + offset),
            "set": wrap(720 - 4 * (lon - ha) - eqtime + offset),
            "polar": false
        };
    }

    // the temperature for an amount, stepped in mireds so the fade looks even
    function tempAt(a) {
        const m0 = 1e6 / root.neutral;
        const m1 = 1e6 / root.temperature;
        return Math.round(1e6 / (m0 + a * (m1 - m0)));
    }

    function push() {
        const want = root.amount <= 0.001 ? "identity" : String(root.tempAt(root.amount));
        root.pending = want;
        if (!sender.running)
            root.flush();

    }

    function flush() {
        if (root.pending === "" || root.pending === root.sent)
            return ;

        const want = root.pending;
        sender.command = ["sh", "-c", root.sendScript, "sh"].concat(want === "identity" ? ["identity"] : ["temperature", want]);
        sender.target = want;
        sender.running = true;
    }

    // hyprsunset is started detached, so a reload of the shell leaves the
    // screen as it was instead of flashing back to neutral. the marker says
    // Lucid warmed it: a hyprsunset someone runs with their own profiles is
    // never reset by a night light that was never on
    readonly property string sendScript: "M=\"${XDG_RUNTIME_DIR:-/tmp}/lucid-nightlight\"\n" + "if [ \"$1\" = identity ]; then\n" + "  [ -f \"$M\" ] || exit 0\n" + "  hyprctl hyprsunset identity >/dev/null 2>&1; rm -f \"$M\"; exit 0\n" + "fi\n" + "hyprctl hyprsunset \"$@\" >/dev/null 2>&1 && { touch \"$M\"; exit 0; }\n" + "command -v hyprsunset >/dev/null 2>&1 || exit 127\n" + "pgrep -x hyprsunset >/dev/null || setsid -f hyprsunset -i >/dev/null 2>&1\n" + "for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do\n" + "  sleep 0.1; hyprctl hyprsunset \"$@\" >/dev/null 2>&1 && { touch \"$M\"; exit 0; }\n" + "done\n" + "exit 1"

    onActiveChanged: {
        if (!root.started)
            return ;

        fade.to = root.active ? 1 : 0;
        fade.restart();
    }
    onTemperatureChanged: {
        if (root.started && root.amount > 0)
            root.push();

    }
    onAmountChanged: {
        if (root.started)
            root.push();

    }
    // a shell that starts while it is night warms up at once, and one that
    // starts while it is day puts back a screen an older shell left warm
    Component.onCompleted: startTimer.start()

    NumberAnimation {
        id: fade

        target: root
        property: "amount"
        duration: Theme.ms(1600)
        easing.type: Easing.InOutSine
    }

    Timer {
        id: startTimer

        // Loc reads the machine's zone first; the schedule needs it
        interval: 1500
        onTriggered: {
            root.started = true;
            root.amount = root.active ? 1 : 0;
            root.sent = "";
            root.push();
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            root.tick++;
            if (root.override >= 0 && Loc.nowMs() >= root.overrideUntil)
                root.override = -1;

        }
    }

    Process {
        id: sender

        property string target: ""

        onExited: (code) => {
            if (code === 127) {
                root.available = false;
                root.pending = "";
                return ;
            }
            root.available = true;
            if (code === 0)
                root.sent = sender.target;

            root.flush();
        }
    }

    // qs ipc call nightlight toggle | on | off | status
    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            root.toggle();
        }

        function on(): void {
            root.set(true);
        }

        function off(): void {
            root.set(false);
        }

        function status(): string {
            return (root.active ? "on" : "off") + " " + root.temperature + "K, " + root.status;
        }
    }

}
