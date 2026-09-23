import QtQuick
import qs
import qs.lucidui

WidgetBody {
    id: w

    // the timer this card follows: the one running closest to done, else the newest
    readonly property var timer: {
        Chrono.now;
        var best = null;
        var list = Chrono.timers;
        for (var i = 0; i < list.length; i++) {
            if (list[i].running && (best === null || Chrono.remaining(list[i]) < Chrono.remaining(best)))
                best = list[i];

        }
        return best !== null ? best : (list.length ? list[list.length - 1] : null);
    }
    readonly property real remain: w.preview ? 204000 : (w.timer ? Chrono.remaining(w.timer) : 0)
    readonly property real total: w.preview ? 300000 : (w.timer ? w.timer.total : 0)
    readonly property bool running: w.preview ? true : (w.timer ? w.timer.running : false)
    readonly property bool done: w.timer !== null && !w.running && w.remain <= 0
    readonly property var presets: (w.opt("presets") || "1,5,10,25").split(",").map((s) => {
        return parseInt(s);
    }).filter((n) => {
        return n > 0;
    }).slice(0, 4)
    // the stopwatch's own clock while it is on screen, so hundredths run smoothly
    property real frameNow: Date.now()
    readonly property real swElapsed: w.preview ? 83460 : (Chrono.swRunning ? Chrono.swBank + (w.frameNow - Chrono.swStart) : Chrono.swBank)
    readonly property real pomoLeft: w.preview ? 1122000 : Chrono.pomoRemaining
    readonly property real pomoTotal: w.preview ? 1500000 : Chrono.pomoTotal
    readonly property string phase: w.preview ? "focus" : Chrono.pomoPhase

    defaultTone: w.variant === "pomodoro" ? "secondary" : "primary"

    Timer {
        interval: 33
        repeat: true
        running: w.variant === "stopwatch" && Chrono.swRunning && w.visible && !w.preview
        onTriggered: w.frameNow = Date.now()
    }

    // the big round action: pill at rest, squarer under the finger
    component Fab: Rectangle {
        id: fab

        property string icon: "play_arrow"
        property real d: 56
        property bool quiet: false

        signal tapped()

        width: fab.d * 1.25
        height: fab.d
        radius: fabTap.pressed ? fab.d * 0.28 : fab.d / 2
        color: fab.quiet ? Theme.alpha(w.ink, 0.1) : w.inkAccent

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Icon {
            anchors.centerIn: parent
            name: fab.icon
            size: fab.d * 0.46
            fill: 1
            color: fab.quiet ? w.ink : w.onInkAccent
        }

        StateLayer {
            id: fabTap

            radius: parent.radius
            tint: fab.quiet ? w.ink : w.onInkAccent
            onClicked: fab.tapped()
        }

    }

    // ring: the countdown in a thick ring, or a row of one-tap presets
    Item {
        id: ring

        readonly property real d: Math.min(width - 32, height - 84)

        visible: w.variant === "ring"
        anchors.fill: parent

        Item {
            visible: w.timer !== null || w.preview
            anchors.fill: parent

            Item {
                id: dial

                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                width: ring.d
                height: ring.d

                MaterialShape {
                    anchors.centerIn: parent
                    width: parent.width - 30
                    height: width
                    shape: w.done ? "sunny" : "cookie12"
                    color: Theme.alpha(w.inkAccent, w.done ? 0.3 : 0.1)

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: w.done ? 6000 : 40000
                        loops: Animation.Infinite
                        running: (w.running || w.done) && w.visible && !w.preview
                    }

                }

                CircularProgress {
                    anchors.fill: parent
                    thickness: 9
                    value: w.total > 0 ? w.remain / w.total : 0
                    animated: false
                    color: w.inkAccent
                    trackColor: Theme.alpha(w.ink, 0.1)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: -4

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "labelMedium"
                        color: w.inkDim
                        text: w.preview ? "5 min timer" : (w.timer ? w.timer.label : "")
                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: Math.round(ring.d * (w.remain >= 3600000 ? 0.2 : 0.25))
                        weight: 640
                        rounded: 100
                        tabular: true
                        color: w.ink
                        text: w.done ? "Done" : Chrono.countdown(w.remain)
                    }

                }

            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 8

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "replay"
                    tintOverride: w.ink
                    onClicked: {
                        if (w.timer)
                            Chrono.reset(w.timer.id);

                    }
                }

                Fab {
                    anchors.verticalCenter: parent.verticalCenter
                    d: 46
                    icon: w.running ? "pause" : (w.done ? "replay" : "play_arrow")
                    onTapped: {
                        if (w.timer)
                            Chrono.toggle(w.timer.id);

                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: w.done ? "close" : "more_time"
                    tintOverride: w.ink
                    tooltip: w.done ? "Dismiss" : "Add a minute"
                    onClicked: {
                        if (!w.timer)
                            return ;

                        if (w.done)
                            Chrono.remove(w.timer.id);
                        else
                            Chrono.extend(w.timer.id, 60);
                    }
                }

            }

        }

        // nothing set: tap a length to start it
        Column {
            visible: w.timer === null && !w.preview
            anchors.centerIn: parent
            spacing: 12

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "timer"
                size: 30
                color: w.inkAccent
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "titleSmall"
                color: w.ink
                text: "Start a timer"
            }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 2
                spacing: 6

                Repeater {
                    model: w.presets

                    Rectangle {
                        id: pre

                        required property int modelData

                        width: 64
                        height: 40
                        radius: preTap.pressed ? 12 : 20
                        color: Theme.alpha(w.inkAccent, 0.16)

                        LText {
                            anchors.centerIn: parent
                            role: "labelLarge"
                            weight: 660
                            color: w.ink
                            text: pre.modelData + " min"
                        }

                        StateLayer {
                            id: preTap

                            radius: parent.radius
                            tint: w.ink
                            onClicked: Chrono.addTimer(pre.modelData * 60, "")
                        }

                    }

                }

            }

        }

    }

    // pomodoro: the phase in a cookie, dots for the rounds, and the controls
    Item {
        id: pomo

        readonly property real d: Math.min(width - 40, height - 124)

        visible: w.variant === "pomodoro"
        anchors.fill: parent

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            role: "titleSmall"
            color: w.ink
            text: w.phase === "idle" ? "Pomodoro" : Chrono.phaseLabel(w.phase)
        }

        Item {
            id: pomoDial

            anchors.horizontalCenter: parent.horizontalCenter
            y: 40
            width: pomo.d
            height: pomo.d

            MaterialShape {
                anchors.fill: parent
                shape: w.phase === "focus" || w.phase === "idle" ? "cookie9" : "clover4"
                color: Theme.alpha(w.inkAccent, 0.14)
            }

            CircularProgress {
                anchors.centerIn: parent
                width: parent.width * 0.78
                height: width
                thickness: 6
                value: w.pomoTotal > 0 && w.phase !== "idle" ? w.pomoLeft / w.pomoTotal : 0
                animated: false
                color: w.inkAccent
                trackColor: Theme.alpha(w.ink, 0.1)
            }

            LText {
                anchors.centerIn: parent
                size: Math.round(pomo.d * 0.2)
                weight: 640
                rounded: 100
                tabular: true
                color: w.ink
                text: w.phase === "idle" ? Prefs.pomodoroFocus + ":00" : Chrono.countdown(w.pomoLeft)
            }

        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: pomoDial.bottom
            anchors.topMargin: 10
            spacing: 5

            Repeater {
                model: Math.max(1, Prefs.pomodoroRounds)

                Rectangle {
                    required property int index
                    readonly property int doneRounds: w.preview ? 1 : Chrono.pomoRound % Math.max(1, Prefs.pomodoroRounds)
                    readonly property bool current: index === doneRounds && w.phase === "focus"

                    width: current ? 18 : 7
                    height: 7
                    radius: 3.5
                    color: index < doneRounds || current ? w.inkAccent : Theme.alpha(w.ink, 0.2)

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durDefaultSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                }

            }

        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            spacing: 8

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "stop"
                iconFill: 1
                tintOverride: w.ink
                disabled: w.phase === "idle"
                onClicked: Chrono.pomoStop()
            }

            Fab {
                anchors.verticalCenter: parent.verticalCenter
                d: 46
                icon: (w.preview || Chrono.pomoRunning) ? "pause" : "play_arrow"
                onTapped: Chrono.pomoToggle()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_next"
                iconFill: 1
                tintOverride: w.ink
                disabled: w.phase === "idle"
                onClicked: Chrono.pomoSkip()
            }

        }

    }

    // stopwatch: the reading, hundredths in the accent, lap and reset either side
    Item {
        visible: w.variant === "stopwatch"
        anchors.fill: parent
        anchors.margins: 16

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, (parent.height - 58 - height) / 2)

            LText {
                id: swMain

                size: 52
                weight: 640
                rounded: 100
                tabular: true
                color: w.ink
                text: Chrono.clock(w.swElapsed, false)
            }

            LText {
                anchors.baseline: swMain.baseline
                size: 24
                weight: 600
                tabular: true
                color: w.inkAccent
                text: "." + String(Math.floor((w.swElapsed % 1000) / 10)).padStart(2, "0")
            }

        }

        LText {
            visible: Chrono.laps.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: swCtl.top
            anchors.bottomMargin: 6
            role: "labelMedium"
            tabular: true
            color: w.inkDim
            text: "Lap " + Chrono.laps.length + " · " + Chrono.clock(Chrono.laps[Chrono.laps.length - 1] - (Chrono.laps.length > 1 ? Chrono.laps[Chrono.laps.length - 2] : 0), true)
        }

        Row {
            id: swCtl

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 8

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "replay"
                tintOverride: w.ink
                disabled: !Chrono.swActive
                onClicked: Chrono.swReset()
            }

            Fab {
                anchors.verticalCenter: parent.verticalCenter
                d: 46
                icon: (w.preview || Chrono.swRunning) ? "pause" : "play_arrow"
                onTapped: Chrono.swToggle()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "flag"
                tintOverride: w.ink
                disabled: !Chrono.swRunning
                onClicked: Chrono.swLap()
            }

        }

    }

}
