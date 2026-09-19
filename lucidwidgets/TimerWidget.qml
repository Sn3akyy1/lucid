import QtQuick
import Quickshell
import qs

WidgetBody {
    id: w

    readonly property string mode: w.variant === "" ? "countdown" : w.variant
    // the running state lives in the card's own options as wall-clock times, so a
    // reload or a reboot finds the count where it really is. a card switched to
    // another style ignores whatever the previous style left behind
    readonly property bool mine: String(w.opt("mode")) === w.mode
    readonly property real endsAt: w.mine ? Number(w.opt("endsAt")) || 0 : 0
    readonly property real pausedLeft: w.mine ? Number(w.opt("left")) || 0 : 0
    readonly property bool counting: w.endsAt > 0
    readonly property bool paused: !w.counting && w.pausedLeft > 0
    readonly property bool finished: w.mine && !w.counting && !w.paused && (Number(w.opt("doneAt")) || 0) > 0
    readonly property string phase: (w.mine && w.mode === "pomodoro") ? String(w.opt("phase") || "focus") : "focus"
    readonly property int round: (w.mine && w.mode === "pomodoro") ? Math.max(1, Number(w.opt("round")) || 1) : (w.preview ? 2 : 1)
    readonly property real duration: w.mode === "pomodoro" ? w.phaseLength(w.phase) : Math.max(60000, Number(w.opt("duration")) || 300000)
    readonly property real swStart: (w.mine && w.mode === "stopwatch") ? Number(w.opt("swStart")) || 0 : 0
    readonly property real swAccum: (w.mine && w.mode === "stopwatch") ? Number(w.opt("swAccum")) || 0 : 0
    readonly property bool swRunning: w.swStart > 0
    readonly property var laps: {
        if (w.preview)
            return [42100, 83300];

        try {
            var parsed = JSON.parse(String(w.opt("laps") || "[]"));
            return (w.mine && Array.isArray(parsed)) ? parsed : [];
        } catch (e) {
            return [];
        }
    }
    // only moves while something is counting; everything at rest reads the options
    property real now: Date.now()
    property real wheelAcc: 0

    readonly property real remaining: {
        if (w.preview)
            return w.duration * 0.62;

        if (w.counting)
            return Math.max(0, w.endsAt - w.now);

        if (w.paused)
            return w.pausedLeft;

        return w.finished ? 0 : w.duration;
    }
    readonly property real elapsed: w.preview ? 96400 : w.swAccum + (w.swRunning ? Math.max(0, w.now - w.swStart) : 0)
    readonly property real progress: w.remaining / Math.max(w.duration, w.remaining, 1)
    // rounds finished in the current set of four
    readonly property int roundsDone: w.phase === "focus" ? (w.round - 1) % 4 : (w.phase === "long" ? 4 : (w.round - 1) % 4 + 1)
    readonly property color ringColor: {
        if (w.mode === "pomodoro" && w.phase !== "focus")
            return Theme.hasTonalContainers ? Theme.cSecondary : Theme.accentMuted;

        return w.paused ? Theme.alpha(Theme.accent, 0.55) : Theme.accent;
    }
    readonly property string phaseLabel: w.phase === "long" ? "LONG BREAK" : (w.phase === "break" ? "BREAK" : "FOCUS")
    readonly property string status: {
        if (w.finished)
            return "Time's up";

        if (w.paused)
            return "Paused";

        if (w.counting)
            return "";

        if (w.mode === "pomodoro")
            return w.preview ? "" : "Click to start";

        return "Scroll to set";
    }
    readonly property string lapText: {
        var n = w.laps.length;
        if (n === 0)
            return w.swRunning ? "" : (w.elapsed > 0 ? "Paused" : "Click to start");

        return "Lap " + n + " · " + w.watch(w.laps[n - 1] - (n > 1 ? w.laps[n - 2] : 0));
    }

    function two(n) {
        return n < 10 ? "0" + n : String(n);
    }

    // a countdown rounds up, so it reads 00:01 until the very end
    function clock(ms) {
        var s = Math.ceil(Math.max(0, ms) / 1000);
        var h = Math.floor(s / 3600);
        var m = Math.floor(s % 3600 / 60);
        var body = w.two(m) + ":" + w.two(s % 60);
        return h > 0 ? h + ":" + body : body;
    }

    function watch(ms) {
        var tenths = Math.floor(Math.max(0, ms) / 100);
        var s = Math.floor(tenths / 10);
        var h = Math.floor(s / 3600);
        var m = Math.floor(s % 3600 / 60);
        if (h > 0)
            return h + ":" + w.two(m) + ":" + w.two(s % 60);

        return w.two(m) + ":" + w.two(s % 60) + "." + (tenths % 10);
    }

    function phaseLength(p) {
        var focus = parseInt(w.opt("focusMinutes")) || 25;
        var rest = parseInt(w.opt("breakMinutes")) || 5;
        return (p === "focus" ? focus : (p === "long" ? rest * 3 : rest)) * 60000;
    }

    function write(changes) {
        changes.mode = w.mode;
        w.setOpts(changes);
        w.now = Date.now();
    }

    function start() {
        w.write({
            "endsAt": Date.now() + (w.paused ? w.pausedLeft : w.duration),
            "left": 0,
            "doneAt": 0
        });
    }

    function pause() {
        w.write({
            "left": Math.max(1, w.endsAt - Date.now()),
            "endsAt": 0
        });
    }

    function toggle() {
        if (w.preview)
            return ;

        if (w.counting)
            w.pause();
        else
            w.start();
    }

    // back to the top of this phase; a second press, from rest, back to round one
    function reset() {
        if (w.preview)
            return ;

        var atRest = !w.counting && !w.paused && !w.finished;
        var changes = {
            "endsAt": 0,
            "left": 0,
            "doneAt": 0
        };
        if (w.mode === "pomodoro" && atRest) {
            changes.phase = "focus";
            changes.round = 1;
        }
        w.write(changes);
    }

    function addMinute() {
        if (w.counting)
            w.write({
                "endsAt": w.endsAt + 60000
            });
        else if (w.paused)
            w.write({
                "left": w.pausedLeft + 60000
            });
    }

    function setDuration(ms) {
        if (w.preview)
            return ;

        w.write({
            "duration": Math.max(60000, Math.min(99 * 60000, ms)),
            "endsAt": 0,
            "left": 0,
            "doneAt": 0
        });
    }

    function following() {
        if (w.phase === "focus") {
            var long = w.opt("longBreak") !== false && w.round % 4 === 0;
            return ({
                "phase": long ? "long" : "break",
                "round": w.round
            });
        }
        return ({
            "phase": "focus",
            "round": w.phase === "long" ? 1 : w.round + 1
        });
    }

    function skip() {
        if (w.preview)
            return ;

        var n = w.following();
        w.write({
            "phase": n.phase,
            "round": n.round,
            "endsAt": 0,
            "left": 0
        });
    }

    function finish() {
        // ran out while the shell was down: settle quietly rather than announce
        // something that ended an hour ago
        var late = Date.now() - w.endsAt > 60000;
        if (w.mode === "pomodoro") {
            var n = w.following();
            var auto = w.opt("autoContinue") === true && !late;
            w.write({
                "phase": n.phase,
                "round": n.round,
                "left": 0,
                "endsAt": auto ? Date.now() + w.phaseLength(n.phase) : 0
            });
            if (late)
                return ;

            if (n.phase === "focus")
                w.alert("Break's over", "Round " + ((n.round - 1) % 4 + 1) + " of 4, back to it.");
            else
                w.alert("Focus round done", "Take a " + Math.round(w.phaseLength(n.phase) / 60000) + " minute " + (n.phase === "long" ? "long break." : "break."));
            return ;
        }
        w.write({
            "endsAt": 0,
            "left": 0,
            "doneAt": late ? 0 : Date.now()
        });
        if (!late)
            w.alert("Time's up", "The " + w.clock(w.duration) + " timer has finished.");

    }

    function alert(title, body) {
        var sound = w.opt("sound") !== false;
        if (w.opt("notify") !== false)
            Quickshell.execDetached(["notify-send", "-a", "Timer", "-h", "boolean:suppress-sound:" + sound, title, body]);

        if (sound)
            Quickshell.execDetached(["sh", "-c", "canberra-gtk-play -i alarm-clock-elapsed 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]);

    }

    function toggleWatch() {
        if (w.preview)
            return ;

        var t = Date.now();
        if (w.swRunning)
            w.write({
                "swAccum": w.swAccum + t - w.swStart,
                "swStart": 0
            });
        else
            w.write({
                "swStart": t
            });
    }

    function lap() {
        if (w.preview || !w.swRunning)
            return ;

        w.write({
            "laps": JSON.stringify(w.laps.concat([w.swAccum + Date.now() - w.swStart]).slice(-99))
        });
    }

    function resetWatch() {
        if (w.preview)
            return ;

        w.write({
            "swStart": 0,
            "swAccum": 0,
            "laps": "[]"
        });
    }

    Timer {
        interval: w.mode === "stopwatch" ? 50 : 200
        repeat: true
        running: !w.preview && (w.counting || w.swRunning)
        triggeredOnStart: true
        onTriggered: {
            w.now = Date.now();
            if (w.counting && w.now >= w.endsAt && w.live)
                w.finish();

        }
    }

    Item {
        id: dialFace

        visible: w.mode !== "stopwatch"
        anchors.fill: parent

        Item {
            id: dial

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 16
            width: parent.height - 72
            height: width

            Gauge {
                anchors.fill: parent
                thickness: 8
                value: w.progress
                fillColor: w.ringColor
                startAngle: -90
                sweep: 360
            }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: w.mode === "pomodoro"
                    text: w.phaseLabel
                    color: w.ringColor
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.4
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: w.clock(w.remaining)
                    color: w.finished ? Theme.accent : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: w.remaining >= 3600000 ? 28 : 36
                    font.bold: true
                    font.letterSpacing: -1
                    font.features: {
                        "tnum": 1
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 15
                    visible: w.mode !== "pomodoro" || w.status !== ""
                    text: w.status
                    color: w.finished ? Theme.accent : Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: w.finished
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: w.mode === "pomodoro"
                    topPadding: 4
                    spacing: 5

                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index

                            width: 6
                            height: 6
                            radius: 3
                            color: index < w.roundsDone ? w.ringColor : Theme.alpha(Theme.text, 0.18)
                        }

                    }

                }

            }

            MouseArea {
                anchors.centerIn: parent
                width: parent.width - 24
                height: width
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (w.finished)
                        w.reset();
                    else
                        w.toggle();
                }
                // one notch a minute, five with shift; touchpads add up their deltas
                onWheel: (wheel) => {
                    if (w.preview || w.mode !== "countdown" || w.counting || w.paused) {
                        wheel.accepted = false;
                        return ;
                    }
                    var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                    w.wheelAcc += d;
                    var step = (wheel.modifiers & Qt.ShiftModifier) ? 300000 : 60000;
                    var next = w.duration;
                    while (Math.abs(w.wheelAcc) >= 120) {
                        next += w.wheelAcc > 0 ? step : -step;
                        w.wheelAcc += w.wheelAcc > 0 ? -120 : 120;
                    }
                    if (next !== w.duration)
                        w.setDuration(next);

                }
            }

        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            spacing: 8

            Repeater {
                model: (w.mode === "countdown" && !w.counting && !w.paused && !w.finished) ? [1, 5, 10, 25] : []

                Chip {
                    required property var modelData

                    label: modelData + "m"
                    on: w.duration === modelData * 60000
                    onClicked: w.setDuration(modelData * 60000)
                }

            }

            WidgetButton {
                visible: w.mode === "pomodoro" || w.counting || w.paused || w.finished
                icon: "refresh"
                diameter: 32
                iconSize: 17
                surface: true
                onClicked: w.reset()
            }

            WidgetButton {
                visible: w.mode === "pomodoro" || w.counting || w.paused
                icon: w.counting ? "pause" : "play"
                diameter: 32
                iconSize: 18
                filled: true
                onClicked: w.toggle()
            }

            WidgetButton {
                visible: w.mode === "pomodoro"
                icon: "next"
                diameter: 32
                iconSize: 17
                surface: true
                onClicked: w.skip()
            }

            Chip {
                visible: w.mode === "countdown" && (w.counting || w.paused)
                label: "+1m"
                onClicked: w.addMinute()
            }

        }

    }

    Item {
        id: watchFace

        visible: w.mode === "stopwatch"
        anchors.fill: parent
        anchors.margins: 16

        Text {
            id: watchTime

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            text: w.watch(w.elapsed)
            color: (w.swRunning || w.elapsed === 0 || w.preview) ? Theme.text : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 40
            font.bold: true
            font.letterSpacing: -1
            font.features: {
                "tnum": 1
            }
        }

        MouseArea {
            anchors.fill: watchTime
            cursorShape: Qt.PointingHandCursor
            onClicked: w.toggleWatch()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: watchTime.bottom
            text: w.lapText
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.features: {
                "tnum": 1
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 10

            WidgetButton {
                icon: "refresh"
                diameter: 34
                iconSize: 17
                surface: true
                enabled: w.preview || w.elapsed > 0
                onClicked: w.resetWatch()
            }

            WidgetButton {
                icon: w.swRunning ? "pause" : "play"
                diameter: 34
                iconSize: 19
                filled: true
                onClicked: w.toggleWatch()
            }

            WidgetButton {
                icon: "flag"
                diameter: 34
                iconSize: 16
                surface: true
                enabled: w.preview || w.swRunning
                onClicked: w.lap()
            }

        }

    }

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property bool on: false

        signal clicked()

        implicitWidth: chipText.implicitWidth + 22
        implicitHeight: 32
        radius: height / 2
        color: chip.on ? Theme.accent : Theme.alpha(Theme.text, chipArea.containsMouse ? 0.13 : 0.07)

        Text {
            id: chipText

            anchors.centerIn: parent
            text: chip.label
            color: chip.on ? Theme.fgAccent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

    }

}
