import QtQuick
import qs
import qs.lucidui

// countdowns and the pomodoro. the dial shows the timer in focus, or the
// length a new one will have; the list on the right holds every timer running
Item {
    id: page

    property var host: null
    property string focusId: ""
    // seconds a new timer starts with; the wheel over the dial sets it
    property int setup: 300
    readonly property var presets: [60, 300, 600, 900, 1500, 3600]
    readonly property var focused: {
        Chrono.now;
        let f = Chrono.timers.find((t) => {
            return t.id === page.focusId;
        });
        if (!f)
            f = Chrono.timers.find((t) => {
            return t.running;
        });

        return f || null;
    }
    readonly property real remainMs: page.focused ? Chrono.remaining(page.focused) : page.setup * 1000
    readonly property real totalMs: page.focused ? page.focused.total : page.setup * 1000

    function nudgeSetup(sec) {
        page.setup = Math.max(10, Math.min(24 * 3600, page.setup + sec));
    }

    function start() {
        Chrono.addTimer(page.setup, "");
        page.focusId = Chrono.timers[Chrono.timers.length - 1].id;
    }

    implicitHeight: 404

    Rectangle {
        id: dialCard

        width: 312
        height: parent.height
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        LText {
            x: 20
            y: 18
            role: "titleMedium"
            weight: 600
            text: page.focused ? page.focused.label : "New timer"
        }

        Item {
            id: dial

            anchors.horizontalCenter: parent.horizontalCenter
            y: 46
            width: 200
            height: 200

            MaterialShape {
                anchors.centerIn: parent
                width: 176
                height: 176
                shape: "cookie12"
                color: page.focused && page.focused.running ? Theme.alpha(Theme.primary, 0.1) : Theme.withBlur(Theme.surfaceHighest)

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 36000
                    loops: Animation.Infinite
                    running: page.visible && page.focused !== null && page.focused.running
                }

            }

            CircularProgress {
                anchors.fill: parent
                thickness: 10
                value: page.totalMs > 0 ? page.remainMs / page.totalMs : 0
                color: page.focused && page.remainMs <= 0 ? Theme.error : Theme.primary
                trackColor: Theme.withBlur(Theme.surfaceHighest)
            }

            Column {
                anchors.centerIn: parent
                spacing: 0

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: Theme.fs(page.remainMs >= 3.6e+06 ? 38 : 48)
                    weight: 620
                    rounded: 100
                    tabular: true
                    color: page.focused && page.remainMs <= 0 ? Theme.error : Theme.text
                    text: Chrono.countdown(page.remainMs)
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "labelMedium"
                    color: Theme.subtext
                    text: {
                        if (!page.focused)
                            return "Scroll to set";

                        if (page.remainMs <= 0)
                            return "Done";

                        if (!page.focused.running)
                            return "Paused";

                        const end = new Date(Loc.nowMs() + page.remainMs);
                        return "Ends " + end.toLocaleTimeString(Qt.locale(), Prefs.clock24h ? "HH:mm" : "h:mm AP");
                    }
                }

            }

            WheelHandler {
                enabled: !page.focused
                onWheel: (e) => {
                    const step = page.setup >= 600 ? 60 : (page.setup >= 120 ? 30 : 10);
                    page.nudgeSetup(e.angleDelta.y > 0 ? step : -step);
                }
            }

        }

        Item {
            id: presetRow

            visible: !page.focused
            anchors.top: dial.bottom
            anchors.topMargin: 6
            anchors.bottom: controls.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            clip: true

            Flow {
                anchors.centerIn: parent
                width: parent.width
                spacing: 6

                Repeater {
                    model: page.presets

                    Chip {
                        required property var modelData

                        kind: "filter"
                        selected: page.setup === modelData
                        text: modelData >= 3600 ? "1 h" : Math.round(modelData / 60) + " min"
                        onClicked: page.setup = modelData
                    }

                }

            }

        }

        Row {
            id: controls

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                variant: "tonal"
                icon: page.focused ? "replay" : "remove"
                onClicked: page.focused ? Chrono.reset(page.focused.id) : page.nudgeSetup(-60)
            }

            // the one big control, filled, the way a clock app's start button is
            Rectangle {
                width: 72
                height: 56
                radius: playArea.pressed ? 16 : 28
                color: Theme.primary

                Icon {
                    anchors.centerIn: parent
                    name: page.focused && page.focused.running ? "pause" : "play_arrow"
                    size: 30
                    fill: 1
                    color: Theme.fgPrimary
                }

                StateLayer {
                    id: playArea

                    radius: parent.radius
                    tint: Theme.fgPrimary
                    onClicked: page.focused ? Chrono.toggle(page.focused.id) : page.start()
                }

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                variant: "tonal"
                icon: "add"
                onClicked: page.focused ? Chrono.extend(page.focused.id, 60) : page.nudgeSetup(60)
            }

        }

    }

    Rectangle {
        id: pomo

        readonly property color ink: Chrono.pomoActive ? Theme.fgTertiaryContainer : Theme.text

        anchors.left: dialCard.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        height: 176
        radius: Theme.shapeXl
        color: Chrono.pomoActive ? Theme.withBlur(Theme.tertiaryContainer) : Theme.withBlur(Theme.surfaceHigh)

        Column {
            x: 20
            y: 16
            spacing: 2

            Row {
                spacing: 8

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Chrono.pomoPhase === "focus" ? "psychiatry" : (Chrono.pomoActive ? "coffee" : "timer")
                    size: 20
                    fill: 1
                    color: pomo.ink
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "titleMedium"
                    weight: 600
                    color: pomo.ink
                    text: Chrono.pomoActive ? Chrono.phaseLabel(Chrono.pomoPhase) : "Pomodoro"
                }

            }

            LText {
                role: "bodySmall"
                color: Theme.alpha(pomo.ink, 0.75)
                text: Prefs.pomodoroFocus + " min focus · " + Prefs.pomodoroShort + " min break · long break every " + Prefs.pomodoroRounds
            }

        }

        LText {
            x: 20
            anchors.bottom: dots.top
            anchors.bottomMargin: 6
            size: Theme.fs(42)
            weight: 620
            rounded: 100
            tabular: true
            color: pomo.ink
            text: Chrono.countdown(Chrono.pomoActive ? Chrono.pomoRemaining : Prefs.pomodoroFocus * 60000)
        }

        Row {
            id: dots

            x: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
            spacing: 6

            Repeater {
                model: Prefs.pomodoroRounds

                Rectangle {
                    required property int index
                    readonly property bool done: index < Chrono.pomoRound % Math.max(1, Prefs.pomodoroRounds)
                    readonly property bool current: Chrono.pomoPhase === "focus" && index === Chrono.pomoRound % Math.max(1, Prefs.pomodoroRounds)

                    anchors.verticalCenter: parent.verticalCenter
                    width: current ? 22 : 8
                    height: 8
                    radius: 4
                    color: done || current ? pomo.ink : Theme.alpha(pomo.ink, 0.25)

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durDefaultSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                }

            }

        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            spacing: 6

            IconButton {
                visible: Chrono.pomoActive
                anchors.verticalCenter: parent.verticalCenter
                icon: "stop"
                tintOverride: pomo.ink
                onClicked: Chrono.pomoStop()
            }

            IconButton {
                visible: Chrono.pomoActive
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_next"
                tintOverride: pomo.ink
                onClicked: Chrono.pomoSkip()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                variant: "filled"
                size: "m"
                icon: Chrono.pomoRunning ? "pause" : "play_arrow"
                iconFill: 1
                onClicked: Chrono.pomoToggle()
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durSlowEffects
            }

        }

    }

    Rectangle {
        anchors.left: dialCard.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.top: pomo.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        LText {
            id: listHead

            x: 20
            y: 16
            role: "titleSmall"
            text: Chrono.timers.length ? "Timers" : "No timers running"
            color: Chrono.timers.length ? Theme.text : Theme.subtext
        }

        Button {
            visible: Chrono.timers.some((t) => {
                return !t.running && t.left <= 0;
            })
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: listHead.verticalCenter
            variant: "text"
            size: "xs"
            text: "Clear done"
            onClicked: Chrono.clearFinished()
        }

        Flickable {
            anchors.top: listHead.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 10
            contentHeight: timerCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: timerCol

                width: parent.width
                spacing: 2

                Repeater {
                    model: Chrono.timers

                    Rectangle {
                        id: trow

                        required property var modelData
                        required property int index
                        readonly property real rem: Chrono.remaining(trow.modelData)
                        readonly property bool isFocus: page.focused !== null && page.focused.id === trow.modelData.id

                        width: timerCol.width
                        height: 52
                        radius: trow.isFocus ? 26 : 12
                        color: trow.isFocus ? Theme.withBlur(Theme.secondaryContainer) : Theme.withBlur(Theme.surfaceHighest)

                        StateLayer {
                            radius: parent.radius
                            onClicked: page.focusId = trow.modelData.id
                        }

                        CircularProgress {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            thickness: 4
                            value: trow.modelData.total > 0 ? trow.rem / trow.modelData.total : 0
                            color: trow.rem <= 0 ? Theme.error : Theme.primary
                        }

                        Column {
                            x: 54
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            LText {
                                role: "titleSmall"
                                weight: 640
                                tabular: true
                                rounded: 100
                                color: trow.isFocus ? Theme.fgSecondaryContainer : Theme.text
                                text: Chrono.countdown(trow.rem)
                            }

                            LText {
                                role: "bodySmall"
                                color: trow.isFocus ? Theme.alpha(Theme.fgSecondaryContainer, 0.75) : Theme.subtext
                                text: trow.modelData.label + (trow.rem <= 0 ? " · done" : (trow.modelData.running ? "" : " · paused"))
                            }

                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter

                            IconButton {
                                size: "xs"
                                icon: trow.rem <= 0 ? "replay" : (trow.modelData.running ? "pause" : "play_arrow")
                                iconFill: 1
                                onClicked: Chrono.toggle(trow.modelData.id)
                            }

                            IconButton {
                                size: "xs"
                                icon: "close"
                                onClicked: Chrono.remove(trow.modelData.id)
                            }

                        }

                        Behavior on radius {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveDefaultSpatial
                            }

                        }

                    }

                }

            }

        }

    }

}
