import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// the shell's timekeeping: countdown timers, one stopwatch and a pomodoro
// cycle. every running thing is stored as the moment it ends or started, so it
// keeps counting across a reload and even a restart
Singleton {
    id: root

    // wall clock, only ticking while something is counting
    property real now: Date.now()
    readonly property bool ticking: root.anyTimerRunning || root.swRunning || root.pomoRunning

    // [{ id, label, total, left, endsAt, running }] in ms
    property alias timers: store.timers
    property alias swRunning: store.swRunning
    property alias swStart: store.swStart
    property alias swBank: store.swBank
    property alias laps: store.laps
    // "idle" | "focus" | "short" | "long"
    property alias pomoPhase: store.pomoPhase
    property alias pomoRound: store.pomoRound
    property alias pomoRunning: store.pomoRunning
    property alias pomoEndsAt: store.pomoEndsAt
    property alias pomoLeft: store.pomoLeft

    readonly property bool anyTimerRunning: root.timers.some((t) => {
        return t.running;
    })
    readonly property real swElapsed: root.swRunning ? root.swBank + (root.now - root.swStart) : root.swBank
    readonly property bool swActive: root.swRunning || root.swBank > 0
    readonly property real pomoRemaining: root.pomoRunning ? Math.max(0, root.pomoEndsAt - root.now) : root.pomoLeft
    readonly property real pomoTotal: root.phaseMinutes(root.pomoPhase) * 60000
    readonly property bool pomoActive: root.pomoPhase !== "idle"

    // what the bar shows: the timer closest to done, else the pomodoro, else the stopwatch
    readonly property var headline: {
        root.now;
        var best = null;
        for (var i = 0; i < root.timers.length; i++) {
            var t = root.timers[i];
            if (!t.running)
                continue;

            var r = root.remaining(t);
            if (best === null || r < best.left)
                best = { "kind": "timer", "left": r, "total": t.total, "running": true, "label": t.label };
        }
        if (best !== null)
            return best;

        if (root.pomoActive)
            return { "kind": "pomodoro", "left": root.pomoRemaining, "total": root.pomoTotal, "running": root.pomoRunning, "label": root.phaseLabel(root.pomoPhase) };

        for (var j = 0; j < root.timers.length; j++) {
            var p = root.timers[j];
            if (p.left > 0 && p.left < p.total)
                return { "kind": "timer", "left": p.left, "total": p.total, "running": false, "label": p.label };

        }
        if (root.swActive)
            return { "kind": "stopwatch", "left": root.swElapsed, "total": 0, "running": root.swRunning, "label": "Stopwatch" };

        return null;
    }

    signal finished(string title, string body)

    function remaining(t) {
        return t.running ? Math.max(0, t.endsAt - root.now) : t.left;
    }

    // 3:05, 1:02:09
    function clock(ms, withTenths) {
        var total = Math.max(0, ms);
        var s = Math.floor(total / 1000);
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        var sec = s % 60;
        var out = (h > 0 ? h + ":" + String(m).padStart(2, "0") : String(m)) + ":" + String(sec).padStart(2, "0");
        if (withTenths)
            out += "." + String(Math.floor((total % 1000) / 10)).padStart(2, "0");

        return out;
    }

    // a countdown rounds up, so a fresh 5:00 timer never reads 4:59
    function countdown(ms) {
        return root.clock(Math.ceil(Math.max(0, ms) / 1000) * 1000, false);
    }

    function phaseMinutes(phase) {
        if (phase === "short")
            return Prefs.pomodoroShort;

        if (phase === "long")
            return Prefs.pomodoroLong;

        return Prefs.pomodoroFocus;
    }

    function phaseLabel(phase) {
        return phase === "short" ? "Short break" : (phase === "long" ? "Long break" : (phase === "focus" ? "Focus" : ""));
    }

    function uid() {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    }

    function label(sec) {
        return sec >= 3600 ? Math.round(sec / 360) / 10 + " h timer" : Math.round(sec / 60) + " min timer";
    }

    function update(id, fn) {
        root.now = Date.now();
        root.timers = root.timers.map((t) => {
            if (t.id !== id)
                return t;

            var c = Object.assign({}, t);
            fn(c);
            return c;
        });
    }

    function addTimer(sec, name) {
        root.now = Date.now();
        var ms = Math.round(sec * 1000);
        root.timers = root.timers.concat([{
            "id": root.uid(),
            "label": name || root.label(sec),
            "total": ms,
            "left": ms,
            "endsAt": root.now + ms,
            "running": true
        }]);
    }

    function pause(id) {
        root.update(id, (t) => {
            if (!t.running)
                return ;

            t.left = Math.max(0, t.endsAt - root.now);
            t.running = false;
        });
    }

    function resume(id) {
        root.update(id, (t) => {
            if (t.running || t.left <= 0)
                return ;

            t.endsAt = root.now + t.left;
            t.running = true;
        });
    }

    function toggle(id) {
        var t = root.timers.find((x) => {
            return x.id === id;
        });
        if (!t)
            return ;

        if (t.running)
            root.pause(id);
        else if (t.left <= 0)
            root.reset(id);
        else
            root.resume(id);
    }

    function reset(id) {
        root.update(id, (t) => {
            t.left = t.total;
            t.running = false;
        });
    }

    // add or take off time; a finished timer comes back to life
    function extend(id, sec) {
        root.update(id, (t) => {
            var d = sec * 1000;
            t.total = Math.max(1000, t.total + d);
            if (t.running) {
                t.endsAt = Math.max(root.now + 1000, t.endsAt + d);
            } else {
                t.left = Math.max(0, t.left + d);
                if (t.left > 0 && d > 0 && t.left === d) {
                    t.endsAt = root.now + t.left;
                    t.running = true;
                }
            }
        });
    }

    function remove(id) {
        root.timers = root.timers.filter((t) => {
            return t.id !== id;
        });
    }

    function clearFinished() {
        root.timers = root.timers.filter((t) => {
            return t.running || t.left > 0;
        });
    }

    function swToggle() {
        root.now = Date.now();
        if (root.swRunning) {
            root.swBank = root.swBank + (root.now - root.swStart);
            root.swRunning = false;
        } else {
            root.swStart = root.now;
            root.swRunning = true;
        }
    }

    function swLap() {
        if (!root.swRunning)
            return ;

        root.now = Date.now();
        root.laps = root.laps.concat([root.swElapsed]);
    }

    function swReset() {
        root.swRunning = false;
        root.swBank = 0;
        root.swStart = 0;
        root.laps = [];
    }

    function pomoBegin(phase) {
        root.now = Date.now();
        root.pomoPhase = phase;
        root.pomoLeft = root.phaseMinutes(phase) * 60000;
        root.pomoEndsAt = root.now + root.pomoLeft;
        root.pomoRunning = true;
    }

    function pomoStart() {
        root.pomoRound = 0;
        root.pomoBegin("focus");
    }

    function pomoToggle() {
        root.now = Date.now();
        if (!root.pomoActive) {
            root.pomoStart();
        } else if (root.pomoRunning) {
            root.pomoLeft = Math.max(0, root.pomoEndsAt - root.now);
            root.pomoRunning = false;
        } else {
            root.pomoEndsAt = root.now + root.pomoLeft;
            root.pomoRunning = true;
        }
    }

    // the phase after this one, counting focus rounds toward the long break
    function pomoAdvance(announce) {
        var next;
        if (root.pomoPhase === "focus") {
            root.pomoRound = root.pomoRound + 1;
            next = root.pomoRound % Math.max(1, Prefs.pomodoroRounds) === 0 ? "long" : "short";
        } else {
            next = "focus";
        }
        if (announce)
            root.finished(root.pomoPhase === "focus" ? "Focus session done" : "Break's over", next === "focus" ? "Time to focus for " + Prefs.pomodoroFocus + " minutes" : root.phaseLabel(next) + " — " + root.phaseMinutes(next) + " minutes");

        if (Prefs.pomodoroAutoStart || !announce) {
            root.pomoBegin(next);
        } else {
            root.pomoPhase = next;
            root.pomoLeft = root.phaseMinutes(next) * 60000;
            root.pomoRunning = false;
        }
    }

    function pomoSkip() {
        if (root.pomoActive)
            root.pomoAdvance(false);

    }

    function pomoStop() {
        root.pomoPhase = "idle";
        root.pomoRunning = false;
        root.pomoRound = 0;
        root.pomoLeft = 0;
    }

    function check() {
        var done = [];
        for (var i = 0; i < root.timers.length; i++) {
            var t = root.timers[i];
            if (t.running && t.endsAt <= root.now)
                done.push(t.id);

        }
        for (var j = 0; j < done.length; j++) {
            var id = done[j];
            var t2 = root.timers.find((x) => {
                return x.id === id;
            });
            root.update(id, (x) => {
                x.left = 0;
                x.running = false;
            });
            root.finished("Time's up", t2 ? t2.label : "Timer");
        }
        if (root.pomoRunning && root.pomoEndsAt <= root.now)
            root.pomoAdvance(true);

    }

    onFinished: (title, body) => {
        Quickshell.execDetached(["notify-send", "-a", "Clock", "-i", "alarm-symbolic", "-u", "critical", title, body]);
        if (Prefs.timerSound)
            Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]);

    }

    Timer {
        interval: 200
        repeat: true
        running: root.ticking
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            root.check();
        }
    }

    IpcHandler {
        target: "timer"

        // qs ipc call timer start 300
        function start(seconds: int): void {
            root.addTimer(Math.max(1, seconds), "");
        }

        function stopwatch(): void {
            root.swToggle();
        }

        function pomodoro(): void {
            root.pomoToggle();
        }

        function status(): string {
            var h = root.headline;
            return h ? h.label + " " + (h.kind === "stopwatch" ? root.clock(h.left, false) : root.countdown(h.left)) : "idle";
        }
    }

    Timer {
        id: saveDebounce

        interval: 400
        onTriggered: file.writeAdapter()
    }

    // no watch on the file this also writes: a watched self-write drops writes
    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/quickshell/lucidbar/chrono.json"
        blockLoading: true
        // absent until the first timer; nothing to report
        printErrors: false
        onAdapterUpdated: saveDebounce.restart()
        onLoaded: {
            root.now = Date.now();
            root.check();
        }

        adapter: JsonAdapter {
            id: store

            property var timers: []
            property bool swRunning: false
            property real swStart: 0
            property real swBank: 0
            property var laps: []
            property string pomoPhase: "idle"
            property int pomoRound: 0
            property bool pomoRunning: false
            property real pomoEndsAt: 0
            property real pomoLeft: 0
        }

    }

}
