import QtQuick
import Quickshell.Io
import qs

WidgetBody {
    id: w

    readonly property bool use24: {
        var m = w.opt("hourMode");
        return m === "24" || (m === "auto" && Prefs.clock24h);
    }
    readonly property bool seconds: w.opt("seconds") === true
    readonly property bool showDate: w.opt("showDate") !== false
    readonly property color timeColor: w.opt("accentTime") === true ? Theme.accent : Theme.text
    readonly property var zoneSets: ({
        "eu": [{
            "city": "London",
            "tz": "Europe/London"
        }, {
            "city": "Paris",
            "tz": "Europe/Paris"
        }, {
            "city": "Moscow",
            "tz": "Europe/Moscow"
        }],
        "us": [{
            "city": "New York",
            "tz": "America/New_York"
        }, {
            "city": "Chicago",
            "tz": "America/Chicago"
        }, {
            "city": "Los Angeles",
            "tz": "America/Los_Angeles"
        }],
        "asia": [{
            "city": "Dubai",
            "tz": "Asia/Dubai"
        }, {
            "city": "Tokyo",
            "tz": "Asia/Tokyo"
        }, {
            "city": "Sydney",
            "tz": "Australia/Sydney"
        }]
    })
    readonly property var zones: w.zoneSets[w.opt("zones")] !== undefined ? w.zoneSets[w.opt("zones")] : w.zoneSets["eu"]
    // minutes east of UTC, one per city, filled in by the offset probe
    property var offsets: [0, 0, 0]

    property var now: Loc.now()

    function hourOf(d) {
        var h = d.getHours();
        if (w.use24)
            return String(h).padStart(2, "0");

        var x = h % 12;
        return String(x === 0 ? 12 : x);
    }

    function twoOf(n) {
        return String(n).padStart(2, "0");
    }

    function timeAt(minutesEast) {
        var real = new Date(w.now.getTime() - Loc.shiftMs);
        return new Date(real.getTime() + real.getTimezoneOffset() * 60000 + minutesEast * 60000);
    }

    function shortTime(d) {
        var h = d.getHours();
        var hs = w.use24 ? String(h).padStart(2, "0") : String(h % 12 === 0 ? 12 : h % 12);
        return hs + ":" + w.twoOf(d.getMinutes());
    }

    function offsetLabel(minutesEast) {
        var here = Loc.trueOffsetMin;
        var diff = (minutesEast - here) / 60;
        if (Math.abs(diff) < 0.01)
            return "same as here";

        var sign = diff > 0 ? "+" : "−";
        var abs = Math.abs(diff);
        var whole = Math.floor(abs);
        var frac = Math.round((abs - whole) * 60);
        return sign + whole + (frac ? ":" + w.twoOf(frac) : "") + "h";
    }

    bare: w.variant === "minimal"

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: w.now = Loc.now()
    }

    Timer {
        interval: 600000
        repeat: true
        running: w.variant === "world"
        triggeredOnStart: true
        onTriggered: offsetProbe.restart()
    }

    Process {
        id: offsetProbe

        function restart() {
            offsetProbe.running = false;
            var parts = w.zones.map((z) => {
                return "TZ=" + z.tz + " date +%z";
            });
            offsetProbe.command = ["sh", "-c", parts.join("; ")];
            offsetProbe.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = this.text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var m = /([+-])(\d{2})(\d{2})/.exec(lines[i].trim());
                    out.push(m ? (m[1] === "-" ? -1 : 1) * (parseInt(m[2]) * 60 + parseInt(m[3])) : 0);
                }
                w.offsets = out;
            }
        }

    }

    onZonesChanged: {
        if (w.variant === "world")
            offsetProbe.restart();

    }

    Column {
        id: digital

        visible: w.variant === "digital"
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Item {
            width: parent.width
            height: bigTime.implicitHeight

            Text {
                id: bigTime

                anchors.left: parent.left
                anchors.top: parent.top
                text: w.hourOf(w.now) + ":" + w.twoOf(w.now.getMinutes())
                color: w.timeColor
                font.family: Theme.fontFamily
                font.pixelSize: 52
                font.bold: true
                font.letterSpacing: -1.5
            }

            Column {
                anchors.left: bigTime.right
                anchors.leftMargin: 8
                anchors.baseline: bigTime.baseline
                anchors.baselineOffset: -2
                spacing: 0

                Text {
                    text: w.seconds ? w.twoOf(w.now.getSeconds()) : ""
                    color: Theme.accentMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                    visible: w.seconds
                }

                Text {
                    text: w.use24 ? "" : (w.now.getHours() < 12 ? "AM" : "PM")
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                    visible: !w.use24
                }

            }

        }

        Text {
            width: parent.width
            text: w.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 14
            elide: Text.ElideRight
            visible: w.showDate
        }

    }

    Item {
        id: stacked

        visible: w.variant === "stack"
        anchors.fill: parent

        Column {
            anchors.centerIn: parent
            spacing: -22

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: w.hourOf(w.now)
                color: w.timeColor
                font.family: Theme.fontFamily
                font.pixelSize: 86
                font.bold: true
                font.letterSpacing: -3
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: w.twoOf(w.now.getMinutes())
                color: Theme.accentMuted
                font.family: Theme.fontFamily
                font.pixelSize: 86
                font.bold: true
                font.letterSpacing: -3
            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            text: w.showDate ? w.now.toLocaleDateString(Qt.locale(), "ddd d MMM") : (w.use24 ? "" : (w.now.getHours() < 12 ? "AM" : "PM"))
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.letterSpacing: 1.4
            font.bold: true
        }

    }

    Item {
        id: analog

        readonly property real dial: Math.min(w.width, w.height) - 30
        readonly property real ringR: analog.dial / 2

        visible: w.variant === "analog"
        anchors.fill: parent

        Rectangle {
            anchors.centerIn: parent
            width: analog.dial
            height: analog.dial
            radius: width / 2
            color: Theme.alpha(Theme.text, 0.06)
        }

        Item {
            anchors.centerIn: parent

            Repeater {
                model: 12

                Item {
                    id: tick

                    required property int index

                    readonly property bool major: tick.index % 3 === 0

                    rotation: tick.index * 30

                    Rectangle {
                        x: -width / 2
                        y: -analog.ringR + 9
                        width: tick.major ? 2.6 : 2
                        height: tick.major ? 11 : 6
                        radius: width / 2
                        color: tick.major ? Theme.subtext : Theme.alpha(Theme.text, 0.34)
                    }

                }

            }

            // hour
            Item {
                rotation: (w.now.getHours() % 12) * 30 + w.now.getMinutes() * 0.5

                Rectangle {
                    x: -width / 2
                    y: -analog.ringR * 0.52
                    width: 5
                    height: analog.ringR * 0.52 + 5
                    radius: width / 2
                    color: w.timeColor
                }

            }

            // minute
            Item {
                rotation: w.now.getMinutes() * 6 + w.now.getSeconds() * 0.1

                Rectangle {
                    x: -width / 2
                    y: -analog.ringR * 0.76
                    width: 3.4
                    height: analog.ringR * 0.76 + 5
                    radius: width / 2
                    color: w.timeColor
                }

            }

            // second
            Item {
                rotation: w.now.getSeconds() * 6
                visible: w.seconds

                Rectangle {
                    x: -width / 2
                    y: -analog.ringR * 0.82
                    width: 1.8
                    height: analog.ringR * 0.82 + 14
                    radius: width / 2
                    color: Theme.accent
                }

            }

            Rectangle {
                x: -width / 2
                y: -height / 2
                width: 8
                height: 8
                radius: 4
                color: Theme.accent
            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: w.now.toLocaleDateString(Qt.locale(), "ddd d")
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            visible: w.showDate
        }

    }

    Column {
        id: minimal

        visible: w.variant === "minimal"
        anchors.centerIn: parent
        spacing: 2

        ShadowText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.hourOf(w.now) + ":" + w.twoOf(w.now.getMinutes()) + (w.seconds ? ":" + w.twoOf(w.now.getSeconds()) : "")
            color: w.opt("accentTime") === true ? Theme.accent : "#ffffff"
            pixelSize: 44
            bold: true
            letterSpacing: -1.5
        }

        ShadowText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            color: Qt.rgba(1, 1, 1, 0.82)
            pixelSize: 13
            bold: true
            visible: w.showDate
        }

    }

    Column {
        id: world

        visible: w.variant === "world"
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0

        Repeater {
            model: w.zones

            Item {
                id: cityRow

                required property int index
                required property var modelData

                readonly property date local: w.timeAt(w.offsets[cityRow.index] !== undefined ? w.offsets[cityRow.index] : 0)

                width: world.width
                height: (world.height - world.spacing * 2) / 3

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: cityRow.modelData.city
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: w.offsetLabel(w.offsets[cityRow.index] !== undefined ? w.offsets[cityRow.index] : 0)
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: w.shortTime(cityRow.local)
                    color: cityRow.local.getHours() >= 7 && cityRow.local.getHours() < 20 ? Theme.text : Theme.accentMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                    font.bold: true
                    font.letterSpacing: -0.5
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.alpha(Theme.outline, 0.5)
                    visible: cityRow.index < 2
                }

            }

        }

    }

}
