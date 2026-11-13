import QtQuick
import Quickshell
import Quickshell.Io
import "lucidclock/ClockMath.js" as CM
pragma Singleton

// alarms, the kind you wake up to: a time of day, once or on chosen days. they
// live in the shell rather than in the clock app, so they ring with the app
// closed; the app, the bar's clock and the ipc all go through here. instants
// are on Loc's clock, as Agenda's are
Singleton {
    id: root

    // [{ id, hour, minute, label, days, on, from, skip, sound }], see ClockMath
    property alias alarms: store.alarms
    // { id: ms } a snoozed alarm comes back at
    property alias snoozed: store.snoozed
    // [{ id, label, hour, minute, sound, since, due }] ringing now, oldest first;
    // kept in the file, so a reload of the shell carries on ringing
    property alias ringing: store.ringing
    property alias snoozeMinutes: store.snoozeMinutes
    // a ring nobody answers stops after this long
    property alias silenceMinutes: store.silenceMinutes
    // the ring starts quiet and swells over its first minute
    property alias gradual: store.gradual
    property alias sound: store.sound
    property alias volume: store.volume
    property bool loaded: false
    property int tick: 0
    readonly property var firing: root.ringing.length > 0 ? root.ringing[0] : null
    readonly property bool anyOn: root.alarms.some((a) => {
        return a.on;
    })
    readonly property bool busy: root.anyOn || root.ringing.length > 0 || Object.keys(root.snoozed).length > 0
    // when this copy of the shell started: one that finds an alarm long overdue
    // as it starts up was not running at the time, so it says it was missed
    readonly property real bornAt: Date.now()
    // rung this late, an alarm still rings; later than this it was missed
    readonly property real graceMs: 30 * 60000
    // the next to ring, a snoozed one included: { alarm, at } or null
    readonly property var next: {
        root.tick;
        const now = Loc.nowMs();
        let best = null;
        for (const a of root.alarms) {
            const at = CM.upcomingAt(a, now, root.snoozed[a.id]);
            if (at && (best === null || at < best.at))
                best = {
                "alarm": a,
                "at": at
            };

        }
        return best;
    }
    // the sounds an alarm can ring with, all lucid's own
    readonly property var soundChoices: [{
        "key": "alarm",
        "label": "Alarm"
    }, {
        "key": "beacon",
        "label": "Beacon"
    }, {
        "key": "chime",
        "label": "Chime"
    }, {
        "key": "halo",
        "label": "Halo"
    }, {
        "key": "reminder",
        "label": "Reminder"
    }, {
        "key": "pulse",
        "label": "Pulse"
    }, {
        "key": "glint",
        "label": "Glint"
    }, {
        "key": "orbit",
        "label": "Orbit"
    }]
    // the notification that stands in for the bar's clock, while it is up
    property int noticeId: -1
    property string noticeFor: ""

    function find(id) {
        return root.alarms.find((a) => {
            return a.id === id;
        }) || null;
    }

    function uid() {
        return "a" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    }

    function soundOf(a) {
        const key = a && a.sound ? a.sound : root.sound;
        return root.soundChoices.some((s) => {
            return s.key === key;
        }) ? key : "alarm";
    }

    function soundLabel(key) {
        const s = root.soundChoices.find((x) => {
            return x.key === key;
        });
        return s ? s.label : "Alarm";
    }

    // anything that arrives over ipc or the clock app's line is checked here
    function cleanDays(days) {
        const out = [];
        for (const d of (days || [])) {
            const n = parseInt(d, 10);
            if (n >= 0 && n <= 6 && out.indexOf(n) < 0)
                out.push(n);

        }
        return out.sort((a, b) => {
            return a - b;
        });
    }

    function add(fields) {
        const f = fields || {
        };
        const a = {
            "id": root.uid(),
            "hour": Math.max(0, Math.min(23, parseInt(f.hour, 10) || 0)),
            "minute": Math.max(0, Math.min(59, parseInt(f.minute, 10) || 0)),
            "label": String(f.label || "").slice(0, 80),
            "days": root.cleanDays(f.days),
            "sound": String(f.sound || ""),
            "on": f.on !== false,
            "from": Loc.nowMs(),
            "skip": 0
        };
        root.alarms = root.alarms.concat([a]);
        root.tick++;
        return a.id;
    }

    // a change to when it rings, or turning it back on, starts it from now
    function update(id, fields) {
        const f = fields || {
        };
        let unsnooze = false;
        root.alarms = root.alarms.map((a) => {
            if (a.id !== id)
                return a;

            const c = Object.assign({
            }, a);
            let retime = false;
            if (f.hour !== undefined) {
                c.hour = Math.max(0, Math.min(23, parseInt(f.hour, 10) || 0));
                retime = retime || c.hour !== a.hour;
            }
            if (f.minute !== undefined) {
                c.minute = Math.max(0, Math.min(59, parseInt(f.minute, 10) || 0));
                retime = retime || c.minute !== a.minute;
            }
            if (f.days !== undefined) {
                c.days = root.cleanDays(f.days);
                retime = retime || !CM.sameDays(c.days, a.days);
            }
            if (f.label !== undefined)
                c.label = String(f.label).slice(0, 80);

            if (f.sound !== undefined)
                c.sound = String(f.sound);

            if (f.on !== undefined) {
                c.on = f.on === true;
                if (c.on && !a.on)
                    retime = true;

                if (!c.on)
                    unsnooze = true;

            }
            if (retime) {
                c.from = Loc.nowMs();
                c.skip = 0;
                unsnooze = true;
            }
            return c;
        });
        if (unsnooze)
            root.unsnooze(id);

        root.tick++;
    }

    function setOn(id, on) {
        root.update(id, {
            "on": on
        });
    }

    function remove(id) {
        root.alarms = root.alarms.filter((a) => {
            return a.id !== id;
        });
        root.unsnooze(id);
        root.quiet(id);
        root.tick++;
    }

    function unsnooze(id) {
        if (root.snoozed[id] === undefined)
            return ;

        const m = Object.assign({
        }, root.snoozed);
        delete m[id];
        root.snoozed = m;
    }

    // passes over the next ring of a repeating alarm, or takes that back
    function skipNext(id, yes) {
        const a = root.find(id);
        if (!a || !a.on)
            return ;

        if (!a.days || a.days.length === 0) {
            if (yes)
                root.setOn(id, false);

            return ;
        }
        const plain = Object.assign({
        }, a, {
            "skip": 0
        });
        const at = yes ? CM.nextFor(plain, Math.max(a.from || 0, Loc.nowMs())) : 0;
        root.alarms = root.alarms.map((x) => {
            return x.id === id ? Object.assign({
            }, x, {
                "skip": at
            }) : x;
        });
        root.unsnooze(id);
        root.tick++;
    }

    // ---- ringing

    function startRing(a, due) {
        if (root.ringing.some((r) => {
            return r.id === a.id;
        }))
            return ;

        root.ringing = root.ringing.concat([{
            "id": a.id,
            "label": a.label,
            "hour": a.hour,
            "minute": a.minute,
            "sound": root.soundOf(a),
            "since": Loc.nowMs(),
            "due": due
        }]);
        if (!bell.running && !gap.running)
            root.ringOnce();

        root.syncNotice();
    }

    // takes one off the ringing list, quietening the bell when it was the last
    function quiet(id) {
        const left = root.ringing.filter((r) => {
            return r.id !== id;
        });
        if (left.length === root.ringing.length)
            return ;

        root.ringing = left;
        if (left.length === 0) {
            gap.stop();
            bell.running = false;
        }
        root.syncNotice();
    }

    function stop(id) {
        root.unsnooze(id);
        root.quiet(id);
        root.tick++;
    }

    function snooze(id, minutes) {
        const r = root.ringing.find((x) => {
            return x.id === id;
        });
        if (!r)
            return ;

        const m = Object.assign({
        }, root.snoozed);
        m[id] = Loc.nowMs() + Math.max(1, minutes || root.snoozeMinutes) * 60000;
        root.snoozed = m;
        root.quiet(id);
        root.tick++;
    }

    function stopAll() {
        for (const r of root.ringing.slice()) root.stop(r.id)
    }

    function snoozeAll() {
        for (const r of root.ringing.slice()) root.snooze(r.id)
    }

    // the swell: a tenth of the volume at first, all of it a minute in
    function ringVolume() {
        const r = root.firing;
        if (!r)
            return root.volume;

        if (!root.gradual)
            return root.volume;

        const t = Math.max(0, Loc.nowMs() - r.since) / 60000;
        return root.volume * Math.min(1, 0.1 + 0.9 * t);
    }

    function ringOnce() {
        const r = root.firing;
        if (!r)
            return ;

        bell.command = ["paplay", "--client-name=Lucid", "--stream-name=alarm", "--property=media.role=event", "--volume=" + Sounds.paVolume(root.ringVolume()), Sounds.dir + "/" + r.sound + ".oga"];
        bell.running = true;
    }

    function preview(key) {
        Sounds.play(root.soundChoices.some((s) => {
            return s.key === key;
        }) ? key : root.sound, root.volume, 400);
    }

    function setSetting(key, value) {
        switch (key) {
        case "snoozeMinutes":
            root.snoozeMinutes = Math.max(1, Math.min(60, parseInt(value, 10) || 10));
            break;
        case "silenceMinutes":
            root.silenceMinutes = Math.max(1, Math.min(60, parseInt(value, 10) || 10));
            break;
        case "gradual":
            root.gradual = value === true;
            break;
        case "sound":
            if (root.soundChoices.some((s) => {
                return s.key === value;
            }))
                root.sound = value;

            break;
        case "volume":
            root.volume = Math.max(0, Math.min(1, Number(value)));
            break;
        }
        root.tick++;
    }

    function timeText(a) {
        return a ? CM.time(a.hour, a.minute, Prefs.clock24h) : "";
    }

    function say(title, body, urgent) {
        Quickshell.execDetached(["notify-send", "-a", "Clock", "-i", "alarm-symbolic", "-u", urgent ? "critical" : "normal", title, body]);
    }

    // the bar's clock has no card for a ring, so a notification with snooze and
    // stop is where a ringing alarm shows, with or without a clock in the bar
    readonly property bool barShowsRing: false

    function syncNotice() {
        const r = root.firing;
        const want = r !== null && !root.barShowsRing ? r.id : "";
        if (want === root.noticeFor)
            return ;

        root.dropNotice();
        if (want === "")
            return ;

        root.noticeFor = want;
        asker.command = ["notify-send", "-a", "Clock", "-i", "alarm-symbolic", "-u", "critical", "-p", "-A", "snooze=Snooze", "-A", "stop=Stop", "--wait", r.label !== "" ? r.label : "Alarm", root.timeText(r) + (r.label !== "" ? "  ·  Alarm" : "")];
        asker.running = true;
    }

    function dropNotice() {
        root.noticeFor = "";
        asker.running = false;
        if (root.noticeId >= 0) {
            const n = Notifs.entries.find((e) => {
                return e.id === root.noticeId;
            });
            if (n)
                Notifs.dismiss(n);

        }
        root.noticeId = -1;
    }

    function check() {
        if (!root.loaded || !Prefs.loaded)
            return ;

        const now = Loc.nowMs();
        let changed = false;
        // snoozes that have come round
        const due = [];
        for (const id in root.snoozed) {
            if (now >= root.snoozed[id])
                due.push(id);

        }
        for (const id of due) {
            const at = root.snoozed[id];
            root.unsnooze(id);
            const a = root.find(id);
            if (a)
                root.startRing(a, at);

            changed = true;
        }
        // alarms whose time has come, or went by unrung
        const rings = [];
        const missed = [];
        const starting = Date.now() - root.bornAt < 8000;
        const list = root.alarms.map((a) => {
            if (!a.on)
                return a;

            const at = CM.nextFor(a, a.from || 0);
            if (!at || at > now)
                return a;

            const c = Object.assign({
            }, a);
            const late = now - at;
            c.from = late > root.graceMs ? now : at + 60000;
            c.skip = 0;
            if (!c.days || c.days.length === 0)
                c.on = false;

            if (late <= root.graceMs && !(starting && late > 90000))
                rings.push([c, at]);
            else if (late < 12 * 3600000)
                missed.push([c, at]);
            return c;
        });
        if (rings.length > 0 || missed.length > 0) {
            root.alarms = list;
            changed = true;
        }
        for (const p of rings) root.startRing(p[0], p[1])
        for (const p of missed) root.say("Missed alarm", root.timeText(p[0]) + (p[0].label !== "" ? "  ·  " + p[0].label : ""), false)
        // a ring nobody answers stops in the end
        const limit = root.silenceMinutes * 60000;
        const gone = root.ringing.filter((r) => {
            return now - r.since >= limit;
        });
        for (const r of gone) {
            root.quiet(r.id);
            root.say("Alarm went unanswered", root.timeText(r) + (r.label !== "" ? "  ·  " + r.label : "") + " rang for " + root.silenceMinutes + " min", false);
            changed = true;
        }
        if (changed)
            root.tick++;

    }

    onBarShowsRingChanged: root.syncNotice()

    Timer {
        interval: 1000
        repeat: true
        running: root.loaded && root.busy
        triggeredOnStart: true
        onTriggered: root.check()
    }

    // the countdowns that read `next` move on once a minute without anything ringing
    Timer {
        interval: 60000
        repeat: true
        running: root.loaded && root.anyOn
        onTriggered: root.tick++
    }

    // one play of the ring at a time, then a breath, until it is answered
    Process {
        id: bell

        onExited: {
            if (root.firing !== null)
                gap.restart();

        }
    }

    Timer {
        id: gap

        interval: 600
        onTriggered: root.ringOnce()
    }

    Process {
        id: asker

        stdout: SplitParser {
            onRead: (line) => {
                const s = line.trim();
                const id = root.noticeFor;
                if (/^\d+$/.test(s)) {
                    root.noticeId = parseInt(s, 10);
                    return ;
                }
                root.noticeId = -1;
                if (s === "snooze" && id !== "")
                    root.snooze(id);
                else if (s === "stop" && id !== "")
                    root.stop(id);
            }
        }

    }

    Connections {
        function onLoadedChanged() {
            root.check();
        }

        target: Prefs
    }

    IpcHandler {
        // qs ipc call -- alarm add 7 30 "Wake up"
        function add(hour: int, minute: int, label: string): string {
            return root.add({
                "hour": hour,
                "minute": minute,
                "label": label
            });
        }

        function remove(id: string): void {
            root.remove(id);
        }

        function list(): string {
            return JSON.stringify(root.alarms);
        }

        function stop(): void {
            root.stopAll();
        }

        function snooze(): void {
            root.snoozeAll();
        }

        function status(): string {
            if (root.firing)
                return "ringing " + root.timeText(root.firing) + (root.firing.label !== "" ? " " + root.firing.label : "");

            const n = root.next;
            return n ? "next " + new Date(n.at).toLocaleString(Qt.locale(), "ddd HH:mm") + " " + CM.untilText(n.at - Loc.nowMs()) : "none";
        }

        target: "alarm"
    }

    Timer {
        id: saveDebounce

        interval: 300
        onTriggered: file.writeAdapter()
    }

    // no watch on the file this also writes: a watched self-write drops writes
    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/quickshell/lucidbar/alarms.json"
        blockLoading: true
        // finished inside writeAdapter(), as Chrono's: see there
        blockWrites: true
        // absent until the first alarm; nothing to report
        printErrors: false
        onAdapterUpdated: saveDebounce.restart()
        onLoaded: {
            root.loaded = true;
            if (root.ringing.length > 0)
                root.ringOnce();

            root.check();
            root.syncNotice();
        }
        onLoadFailed: root.loaded = true

        adapter: JsonAdapter {
            id: store

            property var alarms: []
            property var snoozed: ({
            })
            property var ringing: []
            property int snoozeMinutes: 10
            property int silenceMinutes: 10
            property bool gradual: true
            property string sound: "alarm"
            property real volume: 0.8
        }

    }

}
