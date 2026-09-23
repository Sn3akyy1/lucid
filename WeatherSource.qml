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
        fetcher.command = ["curl", "-sf", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?latitude=" + Loc.lat + "&longitude=" + Loc.lon + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,is_day,precipitation,pressure_msl&hourly=temperature_2m,weather_code,precipitation_probability,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,uv_index_max,sunrise,sunset,precipitation_probability_max&timezone=auto&forecast_days=7&forecast_hours=25"];
        fetcher.running = true;
    }

    function refresh() {
        src.fetchedAt = 0;
        src.lastError = "";
        src.ensure();
    }

    // 0 north, clockwise
    function compass(deg) {
        const names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        return names[Math.round(((deg % 360) + 360) % 360 / 45) % 8];
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
            "minF": src.toF(d.temperature_2m_min[i]),
            "pop": d.precipitation_probability_max ? (d.precipitation_probability_max[i] || 0) : 0
        })
        // the next day in hours, starting with the one we are in
        const hours = [];
        const h = data.hourly;
        if (h && h.time) {
            for (var j = 0; j < h.time.length; j++) hours.push({
                "time": h.time[j],
                "code": h.weather_code[j],
                "tempC": Math.round(h.temperature_2m[j]),
                "tempF": src.toF(h.temperature_2m[j]),
                "pop": h.precipitation_probability ? (h.precipitation_probability[j] || 0) : 0,
                "day": h.is_day ? h.is_day[j] === 1 : true
            })
        }
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
            "isDay": cur.is_day === undefined ? true : cur.is_day === 1,
            "windDir": cur.wind_direction_10m === undefined ? "" : src.compass(cur.wind_direction_10m),
            "precip": cur.precipitation || 0,
            "pressure": cur.pressure_msl ? Math.round(cur.pressure_msl) : 0,
            "pop": days.length > 0 ? days[0].pop : 0,
            "hours": hours,
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
