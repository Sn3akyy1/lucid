import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// reminders: what the clock rings for, what the calendar marks, and what the
// widgets and the lock screen list as coming up
Singleton {
    id: root

    // [{ id, year, month, day, hour, minute, name, repeat }]; repeat is
    // "" | "daily" | "weekdays" | "weekly", counted from the stored date
    property alias items: store.items
    property int tick: 0
    // reminders due and not yet dealt with, oldest first
    property var ringing: []
    readonly property var firing: root.ringing.length > 0 ? root.ringing[0] : null
    property var snoozedUntil: ({})
    property var dismissedAt: ({})
    property string checkedDay: ""
    // when this copy of the shell started, so a reload does not ring out loud
    readonly property real bornAt: Date.now()
    // changes once a minute; what the countdown text needs, instead of every tick
    property string minuteKey: ""

    readonly property var next: {
        root.tick;
        return root.upcoming(1)[0] || null;
    }
    readonly property bool soon: {
        var n = root.next;
        return n !== null && n.at.getTime() - Loc.nowMs() <= 7 * 86400000;
    }

    readonly property var repeatOptions: [
        { "key": "", "label": "Once" },
        { "key": "daily", "label": "Daily" },
        { "key": "weekdays", "label": "Weekdays" },
        { "key": "weekly", "label": "Weekly" }
    ]

    function dayStart(y, m, d) {
        return new Date(y, m, d, 0, 0, 0, 0);
    }

    // does this reminder happen on the given day?
    function occursOn(r, y, m, d) {
        var day = root.dayStart(y, m, d);
        var start = root.dayStart(r.year, r.month, r.day);
        if (day < start)
            return false;

        switch (r.repeat || "") {
        case "daily":
            return true;
        case "weekdays":
            return day.getDay() !== 0 && day.getDay() !== 6;
        case "weekly":
            return day.getDay() === start.getDay();
        }
        return day.getTime() === start.getTime();
    }

    // the next time a reminder rings at or after `from`
    // `next` re-reads this every second for every reminder, so it must not walk
    // the calendar: a one-off happens on exactly its own date, and daily,
    // weekdays and weekly all come round inside a week of whichever is later,
    // today or the date the repeat starts from
    function nextAt(r, from) {
        if (!r.repeat) {
            var at = new Date(r.year, r.month, r.day, r.hour, r.minute, 0, 0);
            return at >= from ? at : null;
        }
        var fromDay = root.dayStart(from.getFullYear(), from.getMonth(), from.getDate());
        var startDay = root.dayStart(r.year, r.month, r.day);
        var probe = startDay > fromDay ? startDay : fromDay;
        for (var i = 0; i < 8; i++) {
            if (root.occursOn(r, probe.getFullYear(), probe.getMonth(), probe.getDate())) {
                var a = new Date(probe.getFullYear(), probe.getMonth(), probe.getDate(), r.hour, r.minute, 0, 0);
                if (a >= from)
                    return a;

            }
            probe.setDate(probe.getDate() + 1);
        }
        return null;
    }

    function upcoming(limit) {
        var now = Loc.now();
        var out = [];
        for (var i = 0; i < root.items.length; i++) {
            var at = root.nextAt(root.items[i], now);
            if (at)
                out.push({ "item": root.items[i], "at": at });

        }
        out.sort((a, b) => {
            return a.at - b.at;
        });
        return out.slice(0, limit || out.length);
    }

    function forDay(y, m, d) {
        return root.items.filter((r) => {
            return root.occursOn(r, y, m, d);
        }).sort((a, b) => {
            return (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute);
        });
    }

    function hasOn(y, m, d) {
        for (var i = 0; i < root.items.length; i++) {
            if (root.occursOn(root.items[i], y, m, d))
                return true;

        }
        return false;
    }

    function add(y, m, d, hour, minute, name, repeat) {
        root.items = root.items.concat([{
            "id": Date.now() + "-" + Math.random().toString(36).slice(2, 7),
            "year": y,
            "month": m,
            "day": d,
            "hour": hour,
            "minute": minute,
            "name": name,
            "repeat": repeat || ""
        }]);
        root.tick++;
    }

    function remove(id) {
        root.items = root.items.filter((r) => {
            return r.id !== id;
        });
        root.ringing = root.ringing.filter((r) => {
            return r.id !== id;
        });
        root.tick++;
    }

    function timeText(r) {
        if (!r)
            return "";

        if (Prefs.clock24h)
            return String(r.hour).padStart(2, "0") + ":" + String(r.minute).padStart(2, "0");

        var h = r.hour % 12 === 0 ? 12 : r.hour % 12;
        return h + ":" + String(r.minute).padStart(2, "0") + " " + (r.hour < 12 ? "AM" : "PM");
    }

    function untilText(at) {
        if (!at)
            return "";

        var mins = Math.round((at - Loc.now()) / 60000);
        if (mins < 1)
            return "now";

        if (mins < 60)
            return "in " + mins + " min";

        var hrs = Math.round(mins / 60);
        if (hrs < 24)
            return "in " + hrs + (hrs === 1 ? " hour" : " hours");

        var days = Math.round(hrs / 24);
        return days === 1 ? "tomorrow" : "in " + days + " days";
    }

    function repeatText(r) {
        switch (r.repeat || "") {
        case "daily":
            return "Every day";
        case "weekdays":
            return "Weekdays";
        case "weekly":
            return "Every " + root.dayStart(r.year, r.month, r.day).toLocaleDateString(Qt.locale(), "dddd");
        }
        return "";
    }

    function snooze(id, minutes) {
        var m = Object.assign({}, root.snoozedUntil);
        m[id] = Loc.nowMs() + minutes * 60000;
        root.snoozedUntil = m;
        root.ringing = root.ringing.filter((q) => {
            return q.id !== id;
        });
    }

    // a one-off goes once it has rung; a repeating one waits for its next turn
    function dismiss(id) {
        var m = Object.assign({}, root.dismissedAt);
        m[id] = Loc.nowMs();
        root.dismissedAt = m;
        root.ringing = root.ringing.filter((q) => {
            return q.id !== id;
        });
        var r = root.items.find((x) => {
            return x.id === id;
        });
        if (r && !r.repeat)
            root.remove(id);

    }

    function prune(now) {
        var today = root.dayStart(now.getFullYear(), now.getMonth(), now.getDate());
        var kept = root.items.filter((r) => {
            return r.repeat || root.dayStart(r.year, r.month, r.day) >= today;
        });
        if (kept.length !== root.items.length)
            root.items = kept;

    }

    function check() {
        var now = Loc.now();
        var key = now.getFullYear() + "-" + now.getMonth() + "-" + now.getDate();
        if (root.checkedDay !== key) {
            root.prune(now);
            root.checkedDay = key;
        }
        var mkey = key + "-" + now.getHours() + "-" + now.getMinutes();
        if (root.minuteKey !== mkey)
            root.minuteKey = mkey;

        var fresh = false;
        for (var i = 0; i < root.items.length; i++) {
            var r = root.items[i];
            if (root.ringing.some((q) => {
                return q.id === r.id;
            }))
                continue;

            var until = root.snoozedUntil[r.id];
            if (until && now.getTime() < until)
                continue;

            // today's occurrence, if there is one and it has come round
            if (!root.occursOn(r, now.getFullYear(), now.getMonth(), now.getDate()))
                continue;

            var due = new Date(now.getFullYear(), now.getMonth(), now.getDate(), r.hour, r.minute, 0, 0);
            if (now < due)
                continue;

            var last = root.dismissedAt[r.id];
            if (last && last >= due.getTime())
                continue;

            // an hour late is too late to ring
            if (!until && now.getTime() - due.getTime() > 3600000)
                continue;

            root.ringing = root.ringing.concat([r]);
            // a reload forgets dismissals, so one already overdue as the shell
            // starts rings without a sound; after that, one that came due while
            // the machine slept still gets it
            if (until || Date.now() - root.bornAt > 5000 || now.getTime() - due.getTime() < 60000)
                fresh = true;

        }
        if (fresh && Prefs.reminderSound)
            Sounds.play("reminder", 1);

        root.tick++;
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.check()
    }

    Timer {
        id: saveDebounce

        interval: 300
        onTriggered: file.writeAdapter()
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/quickshell/lucidbar/clock_reminders.json"
        blockLoading: true
        onAdapterUpdated: saveDebounce.restart()

        adapter: JsonAdapter {
            id: store

            property var items: []
        }

    }

}
