// the clock's arithmetic, shared by the shell's alarm engine, the bar's clock
// and the clock app: plain functions over plain data, nothing that ticks.
// times of day are wall-clock fields (a Date's local hours and minutes); spans
// and instants are milliseconds

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

// "7:05 AM" or "07:05", as Agenda writes reminder times
function time(h, m, h24) {
    if (h24)
        return pad(h) + ":" + pad(m);

    return (h % 12 === 0 ? 12 : h % 12) + ":" + pad(m) + " " + (h < 12 ? "AM" : "PM");
}

// the hour as the clock face shows it: never padded on a 12-hour clock
function hourText(h, h24) {
    return h24 ? pad(h) : String(h % 12 === 0 ? 12 : h % 12);
}

// ---- alarms
// an alarm is { id, hour, minute, label, days, on, from, skip, sound }.
// days are js weekday numbers (0 is sunday); none means it rings once.
// `from` is the moment it may next ring from, so one set at 7:00:30 for 7:00
// waits for tomorrow; `skip` is one coming ring passed over

var WEEKDAYS = [1, 2, 3, 4, 5];
var WEEKEND = [0, 6];
var EVERY_DAY = [0, 1, 2, 3, 4, 5, 6];

function sorted(days) {
    return (days || []).slice().sort(function(a, b) {
        return a - b;
    });
}

function sameDays(a, b) {
    var x = sorted(a), y = sorted(b);
    if (x.length !== y.length)
        return false;

    for (var i = 0; i < x.length; i++) {
        if (x[i] !== y[i])
            return false;

    }
    return true;
}

// the week in the order the calendar shows it
function weekOrder(mondayFirst) {
    return mondayFirst ? [1, 2, 3, 4, 5, 6, 0] : [0, 1, 2, 3, 4, 5, 6];
}

// a weekday's name, long or short, from the locale: a sunday in 2023 counts up
function dayName(d, format) {
    return new Date(2023, 0, 1 + d).toLocaleDateString(Qt.locale(), format || "ddd");
}

// "Every day", "Weekdays", "Weekends", "Mon, Wed, Fri"; "" for a one-off
function daysText(days, mondayFirst) {
    var d = sorted(days);
    if (d.length === 0)
        return "";

    if (d.length === 7)
        return "Every day";

    if (sameDays(d, WEEKDAYS))
        return "Weekdays";

    if (sameDays(d, WEEKEND))
        return "Weekends";

    if (d.length === 1)
        return "Every " + dayName(d[0], "dddd");

    var order = weekOrder(mondayFirst);
    return order.filter(function(x) {
        return d.indexOf(x) >= 0;
    }).map(function(x) {
        return dayName(x, "ddd");
    }).join(", ");
}

// the first time an alarm rings at or after `from`, or 0. any one of the next
// eight days holds it, whichever days it keeps
function nextRing(a, from) {
    var f = new Date(from);
    var days = a.days || [];
    for (var i = 0; i < 8; i++) {
        var d = new Date(f.getFullYear(), f.getMonth(), f.getDate() + i, a.hour, a.minute, 0, 0);
        if (d.getTime() >= from && (days.length === 0 || days.indexOf(d.getDay()) >= 0))
            return d.getTime();

    }
    return 0;
}

// the same, stepping over the one ring set to be skipped
function nextFor(a, from) {
    var t = nextRing(a, from);
    if (t && a.skip && t === a.skip)
        t = nextRing(a, t + 60000);

    return t;
}

// when an alarm will ring next as seen at `now`: a snooze wins; off, it does not
function upcomingAt(a, now, snoozedUntil) {
    if (snoozedUntil && snoozedUntil > now)
        return snoozedUntil;

    if (!a.on)
        return 0;

    return nextFor(a, Math.max(a.from || 0, now));
}

// "in 8 h 12 min", "in 25 min", "in under a minute"
function untilText(ms) {
    if (ms < 60000)
        return "in under a minute";

    var mins = Math.round(ms / 60000);
    if (mins < 60)
        return "in " + mins + " min";

    var h = Math.floor(mins / 60), m = mins % 60;
    if (h < 24)
        return "in " + h + " h" + (m ? " " + m + " min" : "");

    var days = Math.floor(h / 24), hr = h % 24;
    return "in " + days + (days === 1 ? " day" : " days") + (hr ? " " + hr + " h" : "");
}

// "Today", "Tomorrow", "Thu", "Thu 21 Nov": how far off a day is, briefly
function dayWord(at, now) {
    var a = new Date(at), n = new Date(now);
    var days = Math.round((new Date(a.getFullYear(), a.getMonth(), a.getDate()) - new Date(n.getFullYear(), n.getMonth(), n.getDate())) / 86400000);
    if (days === 0)
        return "Today";

    if (days === 1)
        return "Tomorrow";

    if (days > 1 && days < 7)
        return a.toLocaleDateString(Qt.locale(), "dddd");

    return a.toLocaleDateString(Qt.locale(), "ddd d MMM");
}

// ---- spans

// 3:05, 1:02:09, and with hundredths 3:05.27
function clock(ms, hundredths) {
    var total = Math.max(0, ms);
    var s = Math.floor(total / 1000);
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var out = (h > 0 ? h + ":" + pad(m) : String(m)) + ":" + pad(sec);
    if (hundredths)
        out += "." + pad(Math.floor((total % 1000) / 10));

    return out;
}

// a countdown rounds up, so a fresh 5:00 timer never reads 4:59
function countdown(ms) {
    return clock(Math.ceil(Math.max(0, ms) / 1000) * 1000, false);
}

// "1 h 15 min", "50 min", "45 s"
function span(ms) {
    var s = Math.round(ms / 1000);
    if (s < 60)
        return s + " s";

    var m = Math.round(s / 60);
    if (m < 60)
        return m + " min";

    var h = Math.floor(m / 60);
    return h + " h" + (m % 60 ? " " + (m % 60) + " min" : "");
}

// ---- reminders, as Agenda keeps them:
// { id, year, month, day, hour, minute, name, repeat }, repeat "" | "daily" |
// "weekdays" | "weekly", counted from the stored date

function dayStart(y, m, d) {
    return new Date(y, m, d, 0, 0, 0, 0);
}

function occursOn(r, y, m, d) {
    var day = dayStart(y, m, d);
    var start = dayStart(r.year, r.month, r.day);
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

function hasOn(items, y, m, d) {
    for (var i = 0; i < items.length; i++) {
        if (occursOn(items[i], y, m, d))
            return true;

    }
    return false;
}

function forDay(items, y, m, d) {
    return items.filter(function(r) {
        return occursOn(r, y, m, d);
    }).sort(function(a, b) {
        return (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute);
    });
}

// the next time a reminder comes round at or after `from` (a Date), or null
function reminderNext(r, from) {
    if (!r.repeat) {
        var at = new Date(r.year, r.month, r.day, r.hour, r.minute, 0, 0);
        return at >= from ? at : null;
    }
    var fromDay = dayStart(from.getFullYear(), from.getMonth(), from.getDate());
    var startDay = dayStart(r.year, r.month, r.day);
    var probe = startDay > fromDay ? startDay : fromDay;
    for (var i = 0; i < 8; i++) {
        if (occursOn(r, probe.getFullYear(), probe.getMonth(), probe.getDate())) {
            var a = new Date(probe.getFullYear(), probe.getMonth(), probe.getDate(), r.hour, r.minute, 0, 0);
            if (a >= from)
                return a;

        }
        probe = new Date(probe.getFullYear(), probe.getMonth(), probe.getDate() + 1);
    }
    return null;
}

// [{ item, at }] soonest first
function reminderUpcoming(items, from, limit) {
    var out = [];
    for (var i = 0; i < items.length; i++) {
        var at = reminderNext(items[i], from);
        if (at)
            out.push({
                "item": items[i],
                "at": at
            });

    }
    out.sort(function(a, b) {
        return a.at - b.at;
    });
    return out.slice(0, limit || out.length);
}

function repeatText(r) {
    switch (r.repeat || "") {
    case "daily":
        return "Every day";
    case "weekdays":
        return "Weekdays";
    case "weekly":
        return "Every " + dayStart(r.year, r.month, r.day).toLocaleDateString(Qt.locale(), "dddd");
    }
    return "";
}

// ---- time elsewhere

// a zone's wall clock as a Date whose local fields read that zone's time.
// realMs is the true instant; east, the zone's minutes east of utc
function zoneTime(realMs, east) {
    var real = new Date(realMs);
    return new Date(realMs + real.getTimezoneOffset() * 60000 + east * 60000);
}

// "+2 h", "−5:30 h", "Same time"
function offsetText(diffMin) {
    if (Math.abs(diffMin) < 1)
        return "Same time";

    var abs = Math.abs(diffMin);
    var whole = Math.floor(abs / 60);
    var frac = Math.round(abs - whole * 60);
    return (diffMin > 0 ? "+" : "−") + whole + (frac ? ":" + pad(frac) : "") + " h";
}

// "UTC+3", "UTC−5:30", "UTC"
function utcText(mins) {
    if (mins === 0)
        return "UTC";

    var abs = Math.abs(mins);
    var h = Math.floor(abs / 60), m = abs % 60;
    return "UTC" + (mins > 0 ? "+" : "−") + h + (m ? ":" + pad(m) : "");
}

function cityOf(tz) {
    var parts = String(tz).split("/");
    return parts[parts.length - 1].replace(/_/g, " ");
}

function regionOf(tz) {
    var parts = String(tz).split("/");
    return parts.length > 2 ? parts[1].replace(/_/g, " ") + ", " + parts[0].replace(/_/g, " ") : (parts.length > 1 ? parts[0].replace(/_/g, " ") : "");
}

// "Today", "Tomorrow" or "Yesterday" there, against the day here
function relDay(there, here) {
    var d = Math.round((new Date(there.getFullYear(), there.getMonth(), there.getDate()) - new Date(here.getFullYear(), here.getMonth(), here.getDate())) / 86400000);
    return d === 0 ? "Today" : (d > 0 ? "Tomorrow" : "Yesterday");
}

// rough daylight from the hour alone: there is no location for a zone
function daytime(d) {
    var h = d.getHours() + d.getMinutes() / 60;
    return h >= 6.5 && h < 18.5;
}
