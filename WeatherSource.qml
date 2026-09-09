import QtQuick
import Quickshell
import Quickshell.Io
import qs
pragma Singleton

// one forecast for the whole shell: the bar clock, the lock screen and the
// weather widget all read this, so they can never disagree
Singleton {
    id: src

    readonly property int freshMs: 900000

    property var report: null
    property real fetchedAt: 0
    property string fetchedKey: ""
    property string lastError: ""
    property bool busy: false

    readonly property string key: Loc.lat.toFixed(3) + "," + Loc.lon.toFixed(3)
    readonly property bool ready: src.report !== null
    readonly property string place: Loc.place

    // wmo code -> the kinds WeatherIcon draws
    function kindFor(code, night) {
        const c = parseInt(code);
        if (c === 0)
            return night ? "clear-night" : "clear";

        if (c <= 3)
            return night ? "partly-night" : "partly";

        if (c <= 48)
            return "fog";

        if (c <= 67)
            return "rain";

        if (c <= 77)
            return "snow";

        if (c <= 82)
            return "rain";

        if (c <= 86)
            return "snow";

        if (c <= 99)
            return "storm";

        return "cloud";
    }

    function descFor(code) {
        const c = parseInt(code);
        if (c === 0)
            return "Clear";

        if (c === 1)
            return "Mostly Clear";

        if (c === 2)
            return "Partly Cloudy";

        if (c === 3)
            return "Overcast";

        if (c <= 48)
            return "Fog";

        if (c <= 57)
            return "Drizzle";

        if (c <= 67)
            return "Rain";

        if (c <= 77)
            return "Snow";

        if (c <= 82)
            return "Rain Showers";

        if (c <= 86)
            return "Snow Showers";

        if (c <= 99)
            return "Thunderstorm";

        return "—";
    }

    function toF(c) {
        return Math.round(c * 9 / 5 + 32);
    }

    function ensure() {
        if (src.report !== null && src.fetchedKey === src.key && Date.now() - src.fetchedAt < src.freshMs)
            return ;

        if (src.busy)
            return ;

        src.busy = true;
        fetcher.command = ["curl", "-sf", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?latitude=" + Loc.lat + "&longitude=" + Loc.lon + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,uv_index_max,sunrise,sunset&timezone=auto&forecast_days=4"];
        fetcher.running = true;
    }

    function refresh() {
        src.fetchedAt = 0;
        src.lastError = "";
        src.ensure();
    }

    function store(data) {
        const cur = data.current;
        const d = data.daily;
        const days = [];
        for (var i = 0; i < d.time.length; i++) days.push({
            "date": d.time[i],
            "code": d.weather_code[i],
            "maxC": Math.round(d.temperature_2m_max[i]),
            "maxF": src.toF(d.temperature_2m_max[i]),
            "minC": Math.round(d.temperature_2m_min[i]),
            "minF": src.toF(d.temperature_2m_min[i])
        })
        src.report = {
            "code": cur.weather_code,
            "tempC": Math.round(cur.temperature_2m),
            "tempF": src.toF(cur.temperature_2m),
            "feelsC": Math.round(cur.apparent_temperature),
            "feelsF": src.toF(cur.apparent_temperature),
            "humidity": Math.round(cur.relative_humidity_2m),
            "windKmph": Math.round(cur.wind_speed_10m),
            "windMph": Math.round(cur.wind_speed_10m * 0.621371),
            "uv": Math.round(d.uv_index_max[0]),
            "sunrise": d.sunrise[0],
            "sunset": d.sunset[0],
            "days": days
        };
        src.fetchedAt = Date.now();
        src.fetchedKey = src.key;
        src.lastError = "";
        cacheWrite.restart();
    }

    Process {
        id: fetcher

        onExited: (code) => {
            src.busy = false;
            if (code !== 0)
                src.lastError = "could not reach the forecast service";

        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "")
                    return ;

                try {
                    const data = JSON.parse(this.text);
                    if (data && data.current && data.daily)
                        src.store(data);
                    else
                        src.lastError = "no forecast for that position";
                } catch (e) {
                    src.lastError = "could not read the forecast";
                }
            }
        }

    }

    Timer {
        interval: 900000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: src.ensure()
    }

    // never kill a fetch in flight, or its empty stream reaches the parser
    Timer {
        id: moved

        interval: 600
        onTriggered: {
            if (src.busy)
                moved.restart();
            else if (src.fetchedKey !== src.key)
                src.refresh();
        }
    }

    onKeyChanged: moved.restart()

    Timer {
        id: cacheWrite

        interval: 1500
        onTriggered: cacheFile.setText(JSON.stringify({
            "key": src.fetchedKey,
            "at": src.fetchedAt,
            "report": src.report
        }))
    }

    FileView {
        id: cacheFile

        path: Quickshell.env("HOME") + "/.cache/quickshell/lucid-weather.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (parsed && parsed.report && parsed.key === src.key) {
                    src.report = parsed.report;
                    src.fetchedAt = parsed.at;
                    src.fetchedKey = parsed.key;
                }
            } catch (e) {
            }
        }
    }

}
