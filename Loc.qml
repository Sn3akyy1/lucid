import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property real lat: Prefs.locationLat
    readonly property real lon: Prefs.locationLon
    readonly property string place: {
        if (Prefs.locationLabel !== "")
            return Prefs.locationLabel;

        if (!Prefs.gpsEnabled && Prefs.locationName !== "")
            return Prefs.locationName;

        return "";
    }
    readonly property string coordText: Math.abs(root.lat).toFixed(3) + (root.lat >= 0 ? "°N" : "°S") + ", " + Math.abs(root.lon).toFixed(3) + (root.lon >= 0 ? "°E" : "°W")

    property bool busy: false
    property string lastError: ""
    property real fixedAt: 0

    // the machine's zone, not Lucid's; every app on the box shares it
    property string zone: ""
    property bool zoneRead: false
    property int trueOffsetMin: 0
    property int candidateOffsetMin: 0
    property int zoneTick: 0
    property bool zoneBusy: false
    property string zoneError: ""

    readonly property string zoneFromLocation: Prefs.locationTz
    readonly property bool locationAgrees: root.zoneFromLocation === "" || root.candidateOffsetMin === root.trueOffsetMin

    // Qt caches the zone for the life of the process, so after a change this
    // one keeps the shell's clocks right until it is next restarted
    readonly property int engineOffsetMin: {
        root.zoneTick;
        return -(new Date().getTimezoneOffset());
    }
    readonly property int shiftMs: root.zoneRead ? (root.trueOffsetMin - root.engineOffsetMin) * 60000 : 0
    readonly property bool stale: root.shiftMs !== 0
    readonly property string offsetText: root.utcText(root.trueOffsetMin)

    function now() {
        return new Date(Date.now() + root.shiftMs);
    }

    function nowMs() {
        return Date.now() + root.shiftMs;
    }

    function utcText(mins) {
        const sign = mins < 0 ? "-" : "+";
        const a = Math.abs(mins);
        return "UTC" + sign + String(Math.floor(a / 60)).padStart(2, "0") + ":" + String(a % 60).padStart(2, "0");
    }

    function apply(lat, lon, label, tz) {
        Prefs.locationLat = lat;
        Prefs.locationLon = lon;
        Prefs.locationLabel = label;
        if (tz !== "")
            Prefs.locationTz = tz;

        root.fixedAt = Date.now();
        root.lastError = "";
        root.zoneError = "";
        zonePoll.restart();
    }

    function detect() {
        if (root.busy)
            return ;

        root.busy = true;
        root.lastError = "";
        detectProc.running = false;
        detectProc.running = true;
    }

    function lookup(name) {
        const q = (name || "").trim();
        if (q === "") {
            root.lastError = "type a town or city first";
            return ;
        }
        if (root.busy)
            return ;

        root.busy = true;
        root.lastError = "";
        geocodeProc.running = false;
        geocodeProc.command = ["sh", "-c", "curl -sf --max-time 10 'https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name=" + encodeURIComponent(q) + "'"];
        geocodeProc.running = true;
    }

    function refresh() {
        if (Prefs.gpsEnabled)
            root.detect();
        else
            root.lookup(Prefs.locationName);
    }

    // hands the zone to the machine, so every application follows
    function setZone(z) {
        if (z === "" || root.zoneBusy)
            return ;

        root.zoneBusy = true;
        root.zoneError = "";
        setZoneProc.running = false;
        setZoneProc.command = ["timedatectl", "set-timezone", z];
        setZoneProc.running = true;
    }

    function useLocationZone() {
        root.setZone(root.zoneFromLocation);
    }

    Process {
        id: detectProc

        command: ["sh", "-c", "curl -sf --max-time 8 https://ipapi.co/json/ || curl -sf --max-time 8 http://ip-api.com/json/"]
        onExited: (code) => {
            root.busy = false;
            if (code !== 0)
                root.lastError = "could not reach the lookup service";

        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    const lat = d.latitude !== undefined ? d.latitude : d.lat;
                    const lon = d.longitude !== undefined ? d.longitude : d.lon;
                    if (typeof lat !== "number" || typeof lon !== "number") {
                        root.lastError = "the lookup service did not return a position";
                        return ;
                    }
                    const city = d.city || "";
                    const country = d.country_name || d.country || "";
                    root.apply(lat, lon, city !== "" ? (country !== "" ? city + ", " + country : city) : country, d.timezone || "");
                } catch (e) {
                    root.lastError = "could not read the lookup service reply";
                }
            }
        }

    }

    Process {
        id: geocodeProc

        onExited: (code) => {
            root.busy = false;
            if (code !== 0)
                root.lastError = "could not reach the place lookup";

        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    const r = (d.results && d.results.length > 0) ? d.results[0] : null;
                    if (!r) {
                        root.lastError = "no place by that name";
                        return ;
                    }
                    const parts = [r.name];
                    if (r.admin1 && r.admin1 !== r.name)
                        parts.push(r.admin1);

                    if (r.country)
                        parts.push(r.country);

                    root.apply(r.latitude, r.longitude, parts.join(", "), r.timezone || "");
                } catch (e) {
                    root.lastError = "could not read the place lookup reply";
                }
            }
        }

    }

    Process {
        id: setZoneProc

        onExited: (code) => {
            root.zoneBusy = false;
            if (code === 0) {
                zonePoll.restart();
                return ;
            }
            const err = setZoneErr.text.trim();
            root.zoneError = err.indexOf("uthenticat") >= 0 ? "no authentication agent is running to ask for your password" : (err.split("\n").pop() || "timedatectl refused the change");
        }

        stderr: StdioCollector {
            id: setZoneErr
        }

    }

    // the machine's zone name, its real offset, and the offset the location
    // would put us on, all read fresh so a change elsewhere still lands
    Process {
        id: zoneProc

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                const read = (s) => {
                    const m = /([+-])(\d{2})(\d{2})/.exec((s || "").trim());
                    return m ? (m[1] === "-" ? -1 : 1) * (parseInt(m[2]) * 60 + parseInt(m[3])) : null;
                };
                const name = (lines[0] || "").trim();
                if (name !== "")
                    root.zone = name;

                const real = read(lines[1]);
                if (real !== null)
                    root.trueOffsetMin = real;

                const cand = read(lines[2]);
                root.candidateOffsetMin = cand === null ? root.trueOffsetMin : cand;
                root.zoneRead = true;
                root.zoneTick += 1;
                if (Prefs.timeZoneAuto && !root.locationAgrees && !root.zoneBusy && root.zoneError === "")
                    root.useLocationZone();

            }
        }

    }

    Timer {
        id: zonePoll

        interval: 120000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            zoneProc.running = false;
            zoneProc.command = ["sh", "-c", "timedatectl show -p Timezone --value; date +%z; TZ='" + Prefs.locationTz.replace(/'/g, "") + "' date +%z"];
            zoneProc.running = true;
        }
    }

    Timer {
        interval: 21600000
        repeat: true
        running: Prefs.loaded && Prefs.gpsEnabled
        triggeredOnStart: true
        onTriggered: root.detect()
    }

    Connections {
        function onTimeZoneAutoChanged() {
            root.zoneError = "";
            if (Prefs.timeZoneAuto)
                zonePoll.restart();

        }

        function onGpsEnabledChanged() {
            if (!Prefs.gpsEnabled && Prefs.locationName !== "")
                root.lookup(Prefs.locationName);

        }

        target: Prefs
    }

}
