import QtQuick
import QtQuick.Shapes
import qs
import qs.lucidui

WidgetBody {
    id: w

    defaultTone: "tertiary"

    readonly property bool metric: w.opt("units") !== "imperial"
    readonly property var report: (WeatherSource.report === null && w.preview) ? w.sample : WeatherSource.report
    readonly property var sample: ({
        "code": 2, "tempC": 19, "tempF": 66, "feelsC": 18, "feelsF": 64, "humidity": 58, "windKmph": 11, "windMph": 7,
        "uv": 4, "isDay": true, "pop": 20, "windDir": "W",
        "days": [
            { "date": "", "code": 2, "maxC": 21, "maxF": 70, "minC": 12, "minF": 54, "pop": 20 },
            { "date": "", "code": 0, "maxC": 23, "maxF": 73, "minC": 13, "minF": 55, "pop": 0 },
            { "date": "", "code": 61, "maxC": 18, "maxF": 64, "minC": 11, "minF": 52, "pop": 70 },
            { "date": "", "code": 3, "maxC": 17, "maxF": 63, "minC": 10, "minF": 50, "pop": 30 },
            { "date": "", "code": 1, "maxC": 20, "maxF": 68, "minC": 11, "minF": 52, "pop": 10 },
            { "date": "", "code": 80, "maxC": 16, "maxF": 61, "minC": 9, "minF": 48, "pop": 60 }
        ],
        "hours": [19, 20, 20, 19, 17, 15, 14, 13, 13, 12, 12, 13, 15, 17, 19, 20, 21, 20, 19].map((t, i) => {
            return { "time": "", "code": i > 6 && i < 12 ? 0 : 2, "tempC": t, "tempF": Math.round(t * 1.8 + 32), "pop": 10, "day": i < 5 || i > 12 };
        })
    })
    readonly property bool ready: w.report !== null && w.report !== undefined
    readonly property string place: WeatherSource.place !== "" ? WeatherSource.place.split(",")[0] : "Here"
    readonly property bool night: w.report && w.report.isDay !== undefined ? !w.report.isDay : (Loc.now().getHours() < 6 || Loc.now().getHours() >= 20)
    readonly property var days: w.report && w.report.days ? w.report.days.slice(0, 6) : []
    readonly property var hours: {
        if (!w.report || !w.report.hours)
            return [];

        const out = [];
        for (let i = 0; i < w.report.hours.length && out.length < 7; i += 3) out.push(w.report.hours[i])
        return out;
    }

    function t(c, f) {
        return (w.metric ? c : f) + "°";
    }

    function dayName(d, i) {
        if (!d || !d.date) {
            const fake = Loc.now();
            fake.setDate(fake.getDate() + i);
            return i === 0 ? "Today" : fake.toLocaleDateString(Qt.locale(), "ddd");
        }
        return i === 0 ? "Today" : new Date(d.date + "T12:00").toLocaleDateString(Qt.locale(), "ddd");
    }

    function hourName(h, i) {
        if (i === 0)
            return "Now";

        if (!h.time)
            return (i * 3) + "h";

        return new Date(h.time).toLocaleTimeString(Qt.locale(), Prefs.clock24h ? "HH:00" : "h AP");
    }

    Component.onCompleted: {
        if (!w.preview)
            WeatherSource.ensure();

    }

    Column {
        visible: !w.ready
        anchors.centerIn: parent
        spacing: Theme.dp(8)

        LoadingIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: WeatherSource.busy
            color: w.inkAccent
        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "labelLarge"
            color: w.inkDim
            text: WeatherSource.lastError !== "" ? "Weather unavailable" : "Fetching weather"
        }

    }

    // current: one big number and the sky it belongs to
    Item {
        visible: w.ready && w.variant === "current"
        anchors.fill: parent

        Item {
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(12)
            anchors.top: parent.top
            anchors.topMargin: Theme.dp(12)
            width: Theme.dp(96)
            height: Theme.dp(96)

            MaterialShape {
                anchors.fill: parent
                shape: "sunny"
                color: Theme.alpha(w.ink, 0.1)

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 90000
                    loops: Animation.Infinite
                    running: w.visible && !w.preview
                }

            }

            WeatherIcon {
                anchors.centerIn: parent
                size: Theme.dp(72)
                kind: w.report ? WeatherSource.kindFor(w.report.code, w.night) : "clear"
                tint: w.inkAccent
                cloudColor: w.ink
            }

        }

        LText {
            x: Theme.dp(20)
            y: Theme.dp(16)
            role: "labelLarge"
            color: w.inkDim
            text: w.place
        }

        LText {
            x: Theme.dp(16)
            anchors.bottom: descCol.top
            anchors.bottomMargin: -Theme.dp(8)
            size: Theme.dp(64)
            weight: 600
            rounded: 100
            color: w.ink
            text: w.report ? w.t(w.report.tempC, w.report.tempF) : ""
        }

        Column {
            id: descCol

            x: Theme.dp(20)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(16)
            spacing: 0

            LText {
                role: "titleSmall"
                color: w.ink
                text: w.report ? WeatherSource.descFor(w.report.code) : ""
            }

            LText {
                role: "bodySmall"
                color: w.inkDim
                text: w.days.length ? "High " + w.t(w.days[0].maxC, w.days[0].maxF) + " · Low " + w.t(w.days[0].minC, w.days[0].minF) : ""
            }

        }

    }

    // compact: a chip's worth
    Row {
        visible: w.ready && w.variant === "compact"
        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(12)

        Item {
            width: Theme.dp(60)
            height: Theme.dp(60)

            MaterialShape {
                anchors.fill: parent
                shape: "cookie9"
                color: Theme.alpha(w.ink, 0.1)
            }

            WeatherIcon {
                anchors.centerIn: parent
                size: Theme.dp(44)
                kind: w.report ? WeatherSource.kindFor(w.report.code, w.night) : "clear"
                tint: w.inkAccent
                cloudColor: w.ink
            }

        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -Theme.dp(2)

            LText {
                role: "headlineMedium"
                weight: 620
                rounded: 100
                color: w.ink
                text: w.report ? w.t(w.report.tempC, w.report.tempF) : ""
            }

            LText {
                role: "bodySmall"
                color: w.inkDim
                text: w.report ? WeatherSource.descFor(w.report.code) : ""
            }

        }

    }

    // forecast: today, then the week, each day with its range
    Item {
        id: fc

        readonly property real lo: {
            let m = 99;
            for (const d of w.days.slice(1, 6)) m = Math.min(m, d.minC)
            return m;
        }
        readonly property real hi: {
            let m = -99;
            for (const d of w.days.slice(1, 6)) m = Math.max(m, d.maxC)
            return m;
        }

        visible: w.ready && w.variant === "forecast"
        anchors.fill: parent
        anchors.margins: Theme.dp(16)

        Row {
            id: fcHead

            spacing: Theme.dp(10)

            WeatherIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.dp(46)
                kind: w.report ? WeatherSource.kindFor(w.report.code, w.night) : "clear"
                tint: w.inkAccent
                cloudColor: w.ink
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "displaySmall"
                weight: 600
                rounded: 100
                color: w.ink
                text: w.report ? w.t(w.report.tempC, w.report.tempF) : ""
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                LText {
                    role: "titleSmall"
                    color: w.ink
                    text: w.report ? WeatherSource.descFor(w.report.code) : ""
                }

                LText {
                    role: "bodySmall"
                    color: w.inkDim
                    text: w.place
                }

            }

        }

        Column {
            anchors.top: fcHead.bottom
            anchors.topMargin: Theme.dp(10)
            width: parent.width
            spacing: Theme.dp(2)

            Repeater {
                model: w.days.slice(1, 6)

                Item {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: Theme.dp(26)

                    LText {
                        width: Theme.dp(40)
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        color: w.ink
                        text: w.dayName(modelData, index + 1)
                    }

                    WeatherIcon {
                        x: Theme.dp(42)
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.dp(22)
                        animate: false
                        kind: WeatherSource.kindFor(modelData.code, false)
                        tint: w.inkAccent
                        cloudColor: w.inkDim
                    }

                    LText {
                        x: Theme.dp(72)
                        width: Theme.dp(32)
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        role: "labelMedium"
                        color: w.inkDim
                        text: w.t(modelData.minC, modelData.minF)
                    }

                    // where this day's range sits in the week's
                    Rectangle {
                        x: Theme.dp(112)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.dp(112) - Theme.dp(40)
                        height: Theme.dp(6)
                        radius: Theme.dp(3)
                        color: Theme.alpha(w.ink, 0.12)

                        Rectangle {
                            readonly property real span: Math.max(1, fc.hi - fc.lo)

                            x: parent.width * (modelData.minC - fc.lo) / span
                            width: Math.max(Theme.dp(6), parent.width * (modelData.maxC - modelData.minC) / span)
                            height: parent.height
                            radius: Theme.dp(3)
                            color: w.inkAccent
                        }

                    }

                    LText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelMedium"
                        weight: 620
                        color: w.ink
                        text: w.t(modelData.maxC, modelData.maxF)
                    }

                }

            }

        }

    }

    // hourly: the next day as a curve through the temperatures
    Item {
        id: hr

        readonly property var temps: w.hours.map((h) => {
            return w.metric ? h.tempC : h.tempF;
        })
        readonly property real lo: Math.min.apply(null, hr.temps.length ? hr.temps : [0])
        readonly property real hi: Math.max.apply(null, hr.temps.length ? hr.temps : [1])
        readonly property real colW: (hr.width - Theme.dp(32)) / Math.max(1, w.hours.length)

        function yAt(i) {
            const span = Math.max(1, hr.hi - hr.lo);
            return 62 + (1 - (hr.temps[i] - hr.lo) / span) * 34;
        }

        visible: w.ready && w.variant === "hourly"
        anchors.fill: parent

        LText {
            x: Theme.dp(18)
            y: Theme.dp(14)
            role: "titleSmall"
            color: w.ink
            text: w.report ? WeatherSource.descFor(w.report.code) + " · " + w.t(w.report.tempC, w.report.tempF) : ""
        }

        LText {
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(18)
            y: Theme.dp(14)
            role: "labelMedium"
            color: w.inkDim
            text: w.place
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: hr.temps.length > 1

            ShapePath {
                strokeColor: w.inkAccent
                strokeWidth: 3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: {
                        let d = "";
                        for (let i = 0; i < hr.temps.length; i++) {
                            const x = 16 + hr.colW * (i + 0.5);
                            const y = hr.yAt(i);
                            if (i === 0) {
                                d = "M" + x + " " + y;
                            } else {
                                const px = 16 + hr.colW * (i - 0.5);
                                const py = hr.yAt(i - 1);
                                d += " C" + (px + hr.colW / 2) + " " + py + " " + (x - hr.colW / 2) + " " + y + " " + x + " " + y;
                            }
                        }
                        return d;
                    }
                }

            }

        }

        Repeater {
            model: w.hours

            Item {
                required property var modelData
                required property int index

                x: Theme.dp(16) + hr.colW * index
                width: hr.colW
                height: hr.height

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: hr.yAt(index) - Theme.dp(22)
                    role: "labelMedium"
                    weight: 640
                    color: w.ink
                    text: w.t(modelData.tempC, modelData.tempF)
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: hr.yAt(index) - Theme.dp(4)
                    width: Theme.dp(8)
                    height: Theme.dp(8)
                    radius: Theme.dp(4)
                    color: w.inkAccent
                }

                WeatherIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: hourLabel.top
                    anchors.bottomMargin: Theme.dp(2)
                    size: Theme.dp(24)
                    animate: false
                    kind: WeatherSource.kindFor(modelData.code, !modelData.day)
                    tint: w.inkAccent
                    cloudColor: w.inkDim
                }

                LText {
                    id: hourLabel

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.dp(12)
                    role: "labelSmall"
                    color: index === 0 ? w.inkAccent : w.inkDim
                    text: w.hourName(modelData, index)
                }

            }

        }

    }

}
