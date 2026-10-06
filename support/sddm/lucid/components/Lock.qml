pragma Singleton

import QtQuick

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

        root.closeSheet();
    }

    // ── the card's sheets ──────────────────────────────────────────────────
    // "" | "users" | "sessions": what the card has turned over to show
    property string sheet: ""

    function openSheet(kind) {
        if (!root.acceptsInput)
            return ;

        root.engage();
        root.sheet = kind;
    }

    function closeSheet() {
        root.sheet = "";
    }

    property bool focused: false

    // ── auth ───────────────────────────────────────────────────────────────
    // idle | checking | failed | granted
    property string phase: "idle"
    property int attempts: 0
    property string message: ""

    readonly property bool busy: root.phase === "checking"
    readonly property bool granted: root.phase === "granted"
    readonly property bool acceptsInput: !root.busy && !root.granted

    signal failed()
    // the account changed under the field, so whatever was typed is stale
    signal switched()

    function reset() {
        root.phase = "idle";
        root.message = "";
    }

    function submit(text) {
        if (!root.acceptsInput || root.userName === "")
            return ;

        root.closeSheet();
        root.message = "";
        root.phase = "checking";
        sddm.login(root.userName, text, root.sessionIndex);
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
            root.attempts += 1;
            root.phase = "failed";
            root.focused = true;
            root.failed();
        }

        function onLoginSucceeded() {
            root.phase = "granted";
        }
    }

}
