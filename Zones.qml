import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// what time it is elsewhere. qml has no Intl, so each zone's offset is asked
// of `date` once, then again every ten minutes for daylight saving
Singleton {
    id: root

    // "Europe/London" -> minutes east of utc
    property var offsets: ({})
    property var wanted: []
    readonly property var cities: Prefs.splitList(Prefs.clockWorldZones)

    function cityOf(tz) {
        var parts = String(tz).split("/");
        return parts[parts.length - 1].replace(/_/g, " ");
    }

    function regionOf(tz) {
        var parts = String(tz).split("/");
        return parts.length > 1 ? parts[0].replace(/_/g, " ") : "";
    }

    function has(tz) {
        return root.offsets[tz] !== undefined;
    }

    // the wall clock in a zone, as a Date whose local fields read that zone's time
    function timeIn(tz, nowMs) {
        var real = new Date((nowMs !== undefined ? nowMs : Loc.nowMs()) - Loc.shiftMs);
        var east = root.offsets[tz] !== undefined ? root.offsets[tz] : Loc.trueOffsetMin;
        return new Date(real.getTime() + real.getTimezoneOffset() * 60000 + east * 60000);
    }

    // "+2h", "−5:30h", "same as here"
    function offsetText(tz) {
        if (!root.has(tz))
            return "";

        var diff = (root.offsets[tz] - Loc.trueOffsetMin) / 60;
        if (Math.abs(diff) < 0.01)
            return "Same time";

        var abs = Math.abs(diff);
        var whole = Math.floor(abs);
        var frac = Math.round((abs - whole) * 60);
        return (diff > 0 ? "+" : "−") + whole + (frac ? ":" + String(frac).padStart(2, "0") : "") + " h";
    }

    function dayText(tz) {
        var there = root.timeIn(tz);
        var here = Loc.now();
        var d = Math.round((new Date(there.getFullYear(), there.getMonth(), there.getDate()) - new Date(here.getFullYear(), here.getMonth(), here.getDate())) / 86400000);
        return d === 0 ? "Today" : (d > 0 ? "Tomorrow" : "Yesterday");
    }

    // ask for zones beyond the configured ones, e.g. a widget's own set
    function watch(list) {
        var merged = root.wanted.slice();
        for (var i = 0; i < list.length; i++) {
            if (merged.indexOf(list[i]) < 0)
                merged.push(list[i]);

        }
        if (merged.length !== root.wanted.length) {
            root.wanted = merged;
            probe.restart();
        }
    }

    // every zone the system knows, loaded the first time someone asks
    property var all: []

    function loadAll() {
        if (root.all.length === 0 && !lister.running)
            lister.running = true;

    }

    function search(q, limit) {
        var t = String(q).trim().toLowerCase().replace(/ /g, "_");
        if (t === "")
            return [];

        var out = [];
        for (var i = 0; i < root.all.length && out.length < limit; i++) {
            if (root.all[i].toLowerCase().indexOf(t) >= 0 && root.cities.indexOf(root.all[i]) < 0)
                out.push(root.all[i]);

        }
        return out;
    }

    function addCity(tz) {
        if (root.cities.indexOf(tz) < 0)
            Prefs.clockWorldZones = root.cities.concat([tz]).join(",");

    }

    function removeCity(tz) {
        Prefs.clockWorldZones = root.cities.filter((z) => {
            return z !== tz;
        }).join(",");
    }

    Process {
        id: lister

        command: ["sh", "-c", "timedatectl list-timezones 2>/dev/null || find /usr/share/zoneinfo -type f -printf '%P\\n' | grep -E '^[A-Z][A-Za-z_]+/' | sort"]

        stdout: StdioCollector {
            onStreamFinished: root.all = this.text.split("\n").filter((z) => {
                return z.indexOf("/") > 0;
            })
        }

    }

    onCitiesChanged: root.watch(root.cities)
    Component.onCompleted: root.watch(root.cities)

    Process {
        id: probe

        function restart() {
            probe.running = false;
            var zones = root.wanted.filter((z) => {
                return /^[A-Za-z0-9_+\-\/]+$/.test(z);
            });
            if (zones.length === 0)
                return ;

            // argv, never interpolated: a zone name is user input
            probe.command = ["sh", "-c", "for z in \"$@\"; do printf '%s %s\\n' \"$z\" \"$(TZ=\"$z\" date +%z)\"; done", "sh"].concat(zones);
            probe.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var m = Object.assign({}, root.offsets);
                var lines = this.text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(" ");
                    if (p.length !== 2 || !/^[+-]\d{4}$/.test(p[1]))
                        continue;

                    var sign = p[1][0] === "-" ? -1 : 1;
                    m[p[0]] = sign * (parseInt(p[1].slice(1, 3), 10) * 60 + parseInt(p[1].slice(3, 5), 10));
                }
                root.offsets = m;
            }
        }

    }

    Timer {
        interval: 600000
        repeat: true
        running: root.wanted.length > 0
        onTriggered: probe.restart()
    }

}
