import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "ClockMath.js" as CM

// the clock app's process side. the alarms, timers and reminders it shows are
// the shell's (ClockLink.qml): they keep going with this closed, so this only
// mirrors them, sends what the window does back over the line, and keeps its
// own small settings. one window; it lingers five minutes after it closes
Scope {
    id: app

    property string home: Quickshell.env("HOME")
    // a saved state to draw instead of the shell's, for previews
    readonly property string fixture: Quickshell.env("CLOCK_FIXTURE") || ""
    // the shell's last word on everything, see ClockLink.state
    property var st: null
    // a reload of the shell drops the line for a second or two: only a longer
    // silence counts as being away, so the window does not blink each time
    property bool away: false
    readonly property bool linked: app.st !== null && (app.fixture !== "" || !app.away)
    readonly property bool ready: app.linked && app.st.ready === true
    property int _rid: 1
    property var _pending: ({})
    property var _queue: []
    property alias prefs: state
    property bool stateReady: false
    property bool windowOpen: false
    property string startPage: Quickshell.env("CLOCK_PAGE") || ""
    // what a window is handed: inside its own scope `app` would be itself
    readonly property var clockApp: app
    readonly property var window: loader.item

    // ---- what the shell holds, with something sensible before it has said
    readonly property var shellPrefs: app.st ? app.st.prefs : ({
        "clock24h": false,
        "weekStartMonday": true,
        "timerSound": true,
        "reminderSound": true,
        "pomodoroFocus": 25,
        "pomodoroShort": 5,
        "pomodoroLong": 15,
        "pomodoroRounds": 4,
        "pomodoroGoal": 0,
        "pomodoroAutoStart": false,
        "pomodoroAutoFocus": false,
        "pomodoroRepeat": true,
        "pomodoroSilence": false,
        "doNotDisturb": false
    })
    readonly property bool h24: app.shellPrefs.clock24h === true
    readonly property bool mondayFirst: app.shellPrefs.weekStartMonday !== false
    readonly property var alarmState: app.st ? app.st.alarms : ({
        "list": [],
        "ringing": [],
        "snoozed": {},
        "snoozeMinutes": 10,
        "silenceMinutes": 10,
        "gradual": true,
        "sound": "alarm",
        "volume": 0.8,
        "sounds": []
    })
    readonly property var alarms: app.alarmState.list || []
    readonly property var ringing: app.alarmState.ringing || []
    readonly property var snoozed: app.alarmState.snoozed || ({})
    readonly property var chrono: app.st ? app.st.chrono : ({
        "timers": [],
        "swRunning": false,
        "swStart": 0,
        "swBank": 0,
        "laps": [],
        "pomoPhase": "idle",
        "pomoRound": 0,
        "pomoRunning": false,
        "pomoEndsAt": 0,
        "pomoLeft": 0,
        "pomoSpan": 0,
        "pomoDay": "",
        "pomoDone": 0,
        "pomoFocusMs": 0,
        "presets": []
    })
    readonly property var reminders: app.st ? (app.st.reminders.items || []) : []
    readonly property var remindersRinging: app.st ? (app.st.reminders.ringing || []) : []
    readonly property var cities: app.st ? (app.st.zones.cities || []) : []
    readonly property var offsets: app.st ? (app.st.zones.offsets || {}) : ({})
    // the zone here, in minutes east of utc, as the shell has it from `date`
    readonly property int hereOffset: app.st && app.st.tz.read ? app.st.tz.offset : -(new Date().getTimezoneOffset())
    // what this process's own clock is out by: non-zero only between a change
    // of zone and a restart of whichever process cached the old one
    readonly property real shift: app.st && app.st.tz.read ? (app.st.tz.offset + new Date().getTimezoneOffset()) * 60000 : 0
    // the zone's name ("Europe/Warsaw", or "Poland" as some systems read back);
    // not a bare offset, which is all `date` gives without timedated
    readonly property string hereZone: app.st && app.st.tz.zone && !/^[+-]?\d/.test(app.st.tz.zone) ? app.st.tz.zone : ""

    signal replied(var m)

    function nowMs() {
        return Date.now() + app.shift;
    }

    function now() {
        return new Date(app.nowMs());
    }

    function time(h, m) {
        return CM.time(h, m, app.h24);
    }

    // ---- the line to the shell

    function send(op, args, cb) {
        if (app.fixture !== "") {
            console.log("clock (preview): " + op + " " + JSON.stringify(args || {}));
            return ;
        }
        const rid = app._rid++;
        if (cb)
            app._pending[rid] = cb;

        const text = JSON.stringify({
            "op": op,
            "args": args || {},
            "rid": rid
        }) + "\n";
        if (link.connected) {
            link.write(text);
            link.flush();
        } else if (app._queue.length < 32) {
            app._queue = app._queue.concat([text]);
        }
    }

    function receive(text) {
        let m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return ;
        }
        if (m.ev === "state") {
            app.st = m;
            return ;
        }
        if (m.re !== undefined && m.re !== null) {
            const cb = app._pending[m.re];
            if (cb) {
                delete app._pending[m.re];
                cb(m);
            } else if (m.ok === false) {
                console.warn("clock: " + (m.error || "the shell refused that"));
            }
            app.replied(m);
        }
    }

    // ---- alarms, as the window asks for them

    function alarmNext(a) {
        return CM.upcomingAt(a, app.nowMs(), app.snoozed[a.id]);
    }

    // the next to ring of them all: { alarm, at } or null
    function nextAlarm() {
        const now = app.nowMs();
        let best = null;
        for (const a of app.alarms) {
            const at = CM.upcomingAt(a, now, app.snoozed[a.id]);
            if (at && (best === null || at < best.at))
                best = {
                "alarm": a,
                "at": at
            };

        }
        return best;
    }

    function soundLabel(key) {
        const list = app.alarmState.sounds || [];
        const s = list.find((x) => {
            return x.key === key;
        });
        return s ? s.label : "Alarm";
    }

    // ---- the window

    function open(page) {
        if (!app.stateReady) {
            app.startPage = page || app.startPage;
            return ;
        }
        idle.stop();
        if (page)
            app.prefs.page = page;

        if (!app.windowOpen)
            app.windowOpen = true;
        else if (loader.item)
            loader.item.present(page || "");
    }

    function closeWindow() {
        app.windowOpen = false;
        idle.restart();
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", app.home + "/.local/state/lucid"]);
        if (app.fixture !== "")
            fixtureFile.reload();

    }
    onStateReadyChanged: {
        if (app.stateReady)
            app.open(app.startPage);

    }

    Socket {
        id: link

        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-clock.sock"
        connected: app.fixture === ""
        onConnectedChanged: {
            if (link.connected) {
                awayLater.stop();
                app.away = false;
                const q = app._queue;
                app._queue = [];
                for (const t of q) link.write(t)
                link.flush();
            } else {
                // the shell went (a reload, a restart): it is asked again shortly
                awayLater.restart();
                retry.restart();
            }
        }
        onError: retry.restart()

        parser: SplitParser {
            onRead: (text) => {
                return app.receive(text);
            }
        }

    }

    Timer {
        id: awayLater

        interval: 3500
        onTriggered: app.away = !link.connected
    }

    // the shell comes back within a second or two of a reload
    Timer {
        id: retry

        interval: 700
        onTriggered: {
            if (app.fixture === "" && !link.connected)
                link.connected = true;

        }
    }

    // and while it is away for longer, keep asking
    Timer {
        interval: 2500
        repeat: true
        running: app.fixture === "" && !link.connected
        onTriggered: link.connected = true
    }

    FileView {
        id: fixtureFile

        path: app.fixture
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                app.st = JSON.parse(fixtureFile.text());
            } catch (e) {
                console.warn("clock: the preview state does not parse");
            }
        }
    }

    Timer {
        id: idle

        interval: Quickshell.env("CLOCK_EXIT_ON_CLOSE") === "1" ? 0 : 300000
        onTriggered: {
            if (!app.windowOpen)
                Qt.quit();

        }
    }

    Loader {
        id: loader

        active: app.windowOpen

        sourceComponent: ClockWindow {
            app: clockApp
        }

    }

    // the app's own settings. only this process writes it, so it is not watched
    FileView {
        id: stateFile

        path: app.home + "/.local/state/lucid/clock.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeLater.restart()
        onLoaded: app.stateReady = true
        onLoadFailed: (err) => {
            if (err === FileViewError.FileNotFound)
                writeLater.restart();

            app.stateReady = true;
        }

        adapter: JsonAdapter {
            id: state

            // "alarms" | "clock" | "timer" | "stopwatch" | "focus" | "reminders" | "settings"
            property string page: "alarms"
            property int width: 1040
            property int height: 720
            // the face on the clock page: "analog" | "digital"
            property string face: "analog"
            // the last few timers started, newest first, in seconds
            property var recentTimers: []
        }

    }

    Timer {
        id: writeLater

        interval: 200
        onTriggered: {
            Quickshell.execDetached(["mkdir", "-p", app.home + "/.local/state/lucid"]);
            stateFile.writeAdapter();
        }
    }

    IpcHandler {
        // qs ipc -p ~/.config/quickshell/clock.qml call clock open timer
        function open(page: string): void {
            app.open(page);
        }

        function count(): int {
            return app.windowOpen ? 1 : 0;
        }

        function close(): void {
            app.closeWindow();
        }

        target: "clock"
    }

}
