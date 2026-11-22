pragma Singleton

import QtQuick
import "../parts/Catalog.js" as Catalog

// the greeter's brain, the same shape as the shell's Lockscreen.qml. sddm
// hands us the auth instead of pam, and there is no session to read media or
// notifications out of, so the glance is only the clock and the day
QtObject {
    id: root

    // ── who is being asked ─────────────────────────────────────────────────
    // {name, realName, icon, needsPassword}, in sddm's own order
    property var accounts: []
    property int index: 0
    // "other account": someone sddm does not list, typed in by hand
    property bool manual: false
    property string manualName: ""
    readonly property var account: (!root.manual && root.index >= 0 && root.index < root.accounts.length) ? root.accounts[root.index] : null
    readonly property string userName: root.manual ? root.manualName.trim() : (root.account ? root.account.name : "")
    readonly property string displayName: root.account ? root.nameOf(root.account) : ""
    readonly property string avatar: root.account ? root.account.icon : ""
    readonly property bool needsPassword: root.account ? root.account.needsPassword : true
    readonly property string initials: root.initialsOf(root.displayName)
    // a picker is only worth offering when there is a choice to make
    readonly property bool canSwitchUser: root.accounts.length > 1 || root.manual
    // whose wallpaper and colours the greeter wears. a typed, unlisted name
    // keeps the last account's rather than dropping to the fallback
    property string lookName: ""

    onAccountChanged: {
        if (root.account)
            root.lookName = root.account.name;

    }

    function nameOf(a) {
        return a.realName !== "" ? a.realName : a.name;
    }

    function initialsOf(n) {
        if (n === "")
            return "?";

        var parts = n.trim().split(/\s+/);
        if (parts.length > 1)
            return (parts[0][0] + parts[1][0]).toUpperCase();

        return n.substring(0, 2).toUpperCase();
    }

    function pick(i) {
        if (i < 0 || i >= root.accounts.length)
            return ;

        root.manual = false;
        root.index = i;
        root.fresh();
    }

    function pickOther() {
        root.manual = true;
        root.manualName = "";
        root.fresh();
    }

    // a new account starts with a clean slate: no verdict, no tally
    function fresh() {
        root.attempts = 0;
        root.reset();
        root.closeSheet();
        root.switched();
    }

    // ── session ────────────────────────────────────────────────────────────
    // {name, comment}, in sddm's own order
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: (root.sessionIndex >= 0 && root.sessionIndex < root.sessions.length) ? root.sessions[root.sessionIndex] : null
    readonly property string sessionName: root.session ? root.session.name : "Session"

    function pickSession(i) {
        if (i >= 0 && i < root.sessions.length)
            root.sessionIndex = i;

        root.listenSoon(500);
        root.closeSheet();
    }

    // ── the pickers ────────────────────────────────────────────────────────
    // "" | "users" | "sessions": the picker open over the greeter (Picker.qml)
    property string sheet: ""
    // what asked for it, so the picker opens beside it
    property var sheetFrom: null

    // the layout is left as it is: opening a list is not typing, so the clock
    // and the field stay where they are under it. it closes on its own the
    // way the focus does, when nothing happens for a while
    function openSheet(kind, from) {
        if (!root.acceptsInput)
            return ;

        root.sheetFrom = from || null;
        root.sheet = kind;
        idleBack.restart();
    }

    function closeSheet() {
        root.sheet = "";
    }

    // the on-screen keyboard (parts/OnScreenKeys.qml): opened by its chip or
    // a finger on a field, gone again with the focus
    property bool keysOpen: false

    function openKeys() {
        root.keysOpen = true;
        root.engage();
    }

    function toggleKeys() {
        if (root.keysOpen)
            root.keysOpen = false;
        else
            root.openKeys();
    }

    property bool focused: false

    onFocusedChanged: {
        if (!root.focused)
            root.keysOpen = false;

    }

    // ── auth ───────────────────────────────────────────────────────────────
    // idle | checking | failed | granted
    property string phase: "idle"
    property int attempts: 0
    property string message: ""

    // the login screen's pam takes a fingerprint (install-theme.sh) and this
    // account has a finger enrolled (sync-sddm.sh)
    readonly property bool fingerprint: !root.manual && root.needsPassword && Theme.conf("fingerprintLogin", "false") === "true" && Theme.conf("fingerprint", "false") === "true"
    // an empty login kept open while idle; sddm cannot cancel it, so a password waits its turn
    property bool listening: false
    // sddm gives every screen its own copy of this; only the one with the card listens
    property bool driver: true
    property string listenKey: ""
    property double listenedAt: 0
    property string queued: ""
    property bool typing: false
    property bool fingerMiss: false
    property int fingerQuiet: 0
    // pam_fprintd's own words while it waits on the reader
    property string fingerText: ""
    readonly property bool fingerReady: root.listening && root.listenKey === root.userName + "/" + root.sessionIndex

    readonly property bool busy: root.phase === "checking"
    readonly property bool granted: root.phase === "granted"
    readonly property bool acceptsInput: !root.busy && !root.granted

    signal failed()
    // the account changed under the field, so whatever was typed is stale
    signal switched()

    function reset() {
        root.phase = "idle";
        root.message = "";
        root.fingerMiss = false;
        root.listenSoon(500);
    }

    function submit(text) {
        if (!root.acceptsInput || root.userName === "")
            return ;

        root.closeSheet();
        root.message = "";
        if (text === "" && root.fingerprint) {
            root.listen();
            return ;
        }
        root.phase = "checking";
        if (root.listening) {
            root.queued = text;
            return ;
        }
        sddm.login(root.userName, text, root.sessionIndex);
    }

    function listen() {
        if (!root.driver || !root.fingerprint || root.listening || !root.acceptsInput || root.typing || root.userName === "")
            return ;

        listenTimer.stop();
        root.listening = true;
        root.listenKey = root.userName + "/" + root.sessionIndex;
        root.listenedAt = Date.now();
        root.fingerText = "";
        root.fingerMiss = false;
        sddm.login(root.userName, "", root.sessionIndex);
    }

    function listenSoon(ms) {
        listenTimer.interval = ms;
        listenTimer.restart();
    }

    onFingerprintChanged: root.listenSoon(500)
    onTypingChanged: {
        if (!root.typing)
            root.listenSoon(500);

    }

    function engage() {
        if (!root.focused)
            root.focused = true;

        idleBack.restart();
    }

    function disengage() {
        root.focused = false;
        root.closeSheet();
        idleBack.stop();
        if (root.phase === "failed")
            root.phase = "idle";

    }

    // ── the one line under the field ───────────────────────────────────────
    readonly property string statusKind: {
        if (root.granted)
            return "good";

        if (root.phase === "failed")
            return "error";

        if (root.phase === "checking")
            return "info";

        if (root.fingerMiss)
            return "error";

        if (root.fingerReady)
            return "info";

        return "none";
    }
    readonly property string statusText: {
        if (root.granted)
            return "Welcome back";

        if (root.phase === "checking")
            return "Checking…";

        if (root.phase === "failed") {
            if (root.message !== "")
                return root.message;

            if (root.manual)
                return "Unknown account or wrong password";

            return root.attempts > 1 ? "Incorrect password — " + root.attempts + " attempts" : "Incorrect password";
        }
        if (root.fingerMiss)
            return "Fingerprint not recognised";

        if (root.fingerReady)
            return "Touch the fingerprint sensor or type your password";

        return "";
    }

    // ── the day ────────────────────────────────────────────────────────────
    property int tick: 0
    readonly property var now: {
        void root.tick;
        return new Date();
    }
    readonly property bool clock24h: Theme.conf("clock24h", "false") === "true"
    readonly property string timeText: {
        var d = root.now;
        var h = d.getHours();
        var hh = root.clock24h ? h : (h % 12 === 0 ? 12 : h % 12);
        return (root.clock24h && hh < 10 ? "0" : "") + hh + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes();
    }
    readonly property string hourText: root.timeText.split(":")[0]
    readonly property string minuteText: root.timeText.split(":")[1]
    readonly property string meridiem: root.clock24h ? "" : (root.now.getHours() < 12 ? "AM" : "PM")
    readonly property string dateText: root.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
    readonly property string greeting: {
        var h = root.now.getHours();
        if (h < 5)
            return "Still up?";

        if (h < 12)
            return "Good morning";

        if (h < 18)
            return "Good afternoon";

        if (h < 22)
            return "Good evening";

        return "Good night";
    }

    // ── what the shared parts read (parts/, the lock's own files) ─────────
    // the picked account's lock layout, checked against the catalogue: a
    // layout is data, and whatever an account wrote can only choose among
    // the presets and widgets the theme already has
    readonly property var layout: {
        var b = Theme.lockValue("layout");
        var obj = null;
        if (b !== "") {
            try {
                obj = JSON.parse(Qt.atob(b));
            } catch (e) {
                obj = null;
            }
        }
        return Catalog.rebuild(obj);
    }
    // the last reading the account's shell took, if it was allowed to send
    // one. six hours on, it says nothing rather than something stale
    // decoded once per file, not once per tick
    readonly property var weatherData: {
        var b = Theme.lockValue("weather");
        if (b === "")
            return null;

        try {
            var w = JSON.parse(Qt.atob(b));
            return (w && typeof w === "object") ? w : null;
        } catch (e) {
            return null;
        }
    }
    readonly property var weather: {
        void root.tick;
        var w = root.weatherData;
        if (!w)
            return ({
                "ok": false
            });

        try {
            var age = Date.now() / 1000 - Number(w.at || 0);
            if (!(age >= 0 && age < 6 * 3600))
                return ({
                    "ok": false
                });

            var at = age > 45 * 60 ? new Date(Number(w.at) * 1000).toLocaleTimeString(Qt.locale(), root.clock24h ? "HH:mm" : "h:mm AP") : "";
            return {
                "ok": true,
                "kind": String(w.kind || "cloud"),
                "temp": String(w.temp || ""),
                "desc": String(w.desc || ""),
                "hi": String(w.hi || ""),
                "lo": String(w.lo || ""),
                "feels": String(w.feels || ""),
                "at": at
            };
        } catch (e) {
            return ({
                "ok": false
            });
        }
    }
    readonly property string lockedWord: sddm.hostName !== "" ? sddm.hostName : "Locked"
    // the shell's catalogues do not reach the login screen: the parts ask
    // here for their words and get the English, and the machine's locale
    readonly property var locale: Qt.locale()

    function tr(text, ...args) {
        return String(text).replace(/%([1-9])/g, (m, n) => {
            return Number(n) <= args.length ? String(args[Number(n) - 1]) : m;
        });
    }

    // the machine as sysfs shows it, handed over by Main.qml
    property var sys: null
    readonly property var statusItems: {
        var s = root.sys;
        var out = [];
        if (s && s.hasBattery) {
            const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"];
            out.push({
                "key": "battery",
                "glyph": s.charging ? "battery_charging_full" : steps[Math.max(0, Math.min(7, Math.floor(s.batteryPercent / 100 * 8)))],
                "label": s.batteryPercent + "%",
                "short": s.batteryPercent + "%",
                "tone": s.batteryLow ? "error" : (s.charging ? "success" : "normal")
            });
        }
        // sysfs has no network name, so wi-fi is only ever "Wi-Fi"
        if (s && s.netKnown)
            out.push({
                "key": "network",
                "glyph": s.ethernet ? "ethernet" : (s.wifiUp ? "wifi" : "wifiOff"),
                "label": s.ethernet ? "Ethernet" : (s.wifiUp ? "Wi-Fi" : "Offline"),
                "tone": (s.ethernet || s.wifiUp) ? "accent" : "dim"
            });

        // rfkill: whether the radio is on, not what is paired to it
        if (s && s.btState >= 0)
            out.push({
                "key": "bluetooth",
                "glyph": s.btState === 1 ? "bluetooth" : "bluetoothOff",
                "label": s.btState === 1 ? "Bluetooth on" : "Bluetooth off",
                "tone": "dim"
            });

        if (out.length === 0 && sddm.hostName !== "")
            out.push({
                "key": "host",
                "glyph": "host",
                "label": sddm.hostName,
                "tone": "dim"
            });

        // one tap per layout, round and round
        if (s && s.canCycle)
            out.push({
                "key": "keyboard",
                "glyph": "keyboard",
                "label": s.layoutName,
                "short": s.layoutName,
                "tone": "dim",
                "interactive": true
            });

        return out;
    }

    function activateStatus(key) {
        if (key === "keyboard" && root.sys && root.sys.canCycle)
            keyboard.currentLayout = (keyboard.currentLayout + 1) % root.sys.layouts.length;

    }

    // ── the ways out ───────────────────────────────────────────────────────
    // no log out: there is nothing logged in yet
    readonly property var powerActions: {
        var out = [];
        if (sddm.canSuspend)
            out.push({
                "id": "suspend",
                "label": "Suspend",
                "glyph": "suspend",
                "confirm": false
            });

        if (sddm.canHibernate)
            out.push({
                "id": "hibernate",
                "label": "Hibernate",
                "glyph": "hibernate",
                "confirm": false
            });

        out.push({
            "id": "reboot",
            "label": "Restart",
            "glyph": "restart",
            "confirm": true
        });
        out.push({
            "id": "shutdown",
            "label": "Shut down",
            "glyph": "power",
            "confirm": true
        });
        return out;
    }

    function runPower(id) {
        if (id === "suspend")
            sddm.suspend();
        else if (id === "hibernate")
            sddm.hibernate();
        else if (id === "reboot")
            sddm.reboot();
        else if (id === "shutdown")
            sddm.powerOff();

    }

    // focus falls back to the glance face when the keyboard goes quiet
    property Timer _idleBack: Timer {
        id: idleBack

        interval: 25000
        onTriggered: {
            if (!root.busy) {
                root.focused = false;
                root.closeSheet();
            }
        }
    }

    property Timer _listen: Timer {
        id: listenTimer

        onTriggered: root.listen()
    }

    property Timer _tick: Timer {
        running: true
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick += 1
    }

    // sddm answers out of band, so the verdict arrives here
    property Connections _auth: Connections {
        target: sddm

        function onLoginFailed() {
            if (root.listening) {
                root.listening = false;
                var heard = root.fingerText !== "";
                root.fingerText = "";
                root.fingerQuiet = heard ? 0 : root.fingerQuiet + 1;
                if (root.queued !== "") {
                    var text = root.queued;
                    root.queued = "";
                    sddm.login(root.userName, text, root.sessionIndex);
                    return ;
                }
                // ended before the 10s timeout: a finger was read and did not match
                root.fingerMiss = heard && Date.now() - root.listenedAt < 9000;
                root.listenSoon(heard ? 1500 : Math.min(60000, 2000 * Math.pow(2, root.fingerQuiet)));
                return ;
            }
            root.attempts += 1;
            root.phase = "failed";
            root.focused = true;
            root.failed();
            root.listenSoon(1500);
        }

        function onLoginSucceeded() {
            root.listening = false;
            root.phase = "granted";
        }

        // pam's info lines, which is how the reader asks for a finger
        function onInformationMessage(message) {
            if (root.listening)
                root.fingerText = message;

        }
    }

}
