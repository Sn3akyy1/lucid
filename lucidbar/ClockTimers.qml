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
    readonly property bool shown: page.visible && (!page.host || page.host.expanded)

    // 50 min, 1 h 15 min
    function spanText(ms) {
        const m = Math.round(ms / 60000);
        return m >= 60 ? Math.floor(m / 60) + " h" + (m % 60 ? " " + (m % 60) + " min" : "") : m + " min";
    }

    function nudgeSetup(sec) {
        page.setup = Math.max(10, Math.min(24 * 3600, page.setup + sec));
    }

    function start() {
        Chrono.addTimer(page.setup, "");
        page.focusId = Chrono.timers[Chrono.timers.length - 1].id;
    }

    implicitHeight: Theme.dp(404)
    onShownChanged: {
        if (page.shown)
            Chrono.rollDay();
        else
            pomo.tuning = false;
    }

    component Stepper: Item {
        id: st

        property string label: ""
        property int value: 0
        property int from: 0
        property int to: 10
        property int step: 1
        // what a value of 0 reads as, when it means something other than none
        property string zeroText: ""

        signal moved(int v)

        function nudge(by) {
            const v = Math.max(st.from, Math.min(st.to, st.value + by * st.step));
            if (v !== st.value)
                st.moved(v);

        }

        implicitHeight: Theme.dp(30)

        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: "bodyMedium"
            text: st.label
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: "xs"
                widthKind: "narrow"
                icon: "remove"
                disabled: st.value <= st.from
                onClicked: st.nudge(-1)
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(30)
                horizontalAlignment: Text.AlignHCenter
                role: "titleSmall"
                weight: 640
                rounded: 100
                tabular: true
                text: st.value === 0 && st.zeroText !== "" ? st.zeroText : String(st.value)
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: "xs"
                widthKind: "narrow"
                icon: "add"
                disabled: st.value >= st.to
                onClicked: st.nudge(1)
            }

        }

        WheelHandler {
            onWheel: (e) => {
                st.nudge(e.angleDelta.y > 0 ? 1 : -1);
            }
        }

    }

    Rectangle {
        id: dialCard

        width: Theme.dp(312)
        height: parent.height
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        LText {
            x: Theme.dp(20)
            y: Theme.dp(18)
            role: "titleMedium"
            weight: 600
            text: page.focused ? page.focused.label : "New timer"
        }

        Item {
            id: dial

            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.dp(46)
            width: Theme.dp(200)
            height: Theme.dp(200)

            MaterialShape {
                anchors.centerIn: parent
                width: Theme.dp(176)
                height: Theme.dp(176)
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
                thickness: Theme.dp(10)
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
            anchors.topMargin: Theme.dp(6)
            anchors.bottom: controls.top
            anchors.bottomMargin: Theme.dp(6)
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.dp(280)
            clip: true

            Flow {
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.dp(6)

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
            anchors.bottomMargin: Theme.dp(18)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.dp(10)

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                variant: "tonal"
                icon: page.focused ? "replay" : "remove"
                onClicked: page.focused ? Chrono.reset(page.focused.id) : page.nudgeSetup(-60)
            }

            // the one big control, filled, the way a clock app's start button is
            Rectangle {
                width: Theme.dp(72)
                height: Theme.dp(56)
                radius: playArea.pressed ? Theme.dp(16) : Theme.dp(28)
                color: Theme.primary

                Icon {
                    anchors.centerIn: parent
                    name: page.focused && page.focused.running ? "pause" : "play_arrow"
                    size: Theme.dp(30)
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

        // opened over the timer list, showing its options
        property bool tuning: false
        // 0 closed .. 1 open
        readonly property real t: Math.max(0, Math.min(1, (pomo.height - 176) / Math.max(1, page.height - 176)))
        readonly property bool tinted: Chrono.pomoActive && !pomo.tuning
        readonly property color ink: pomo.tinted ? Theme.fgTertiaryContainer : Theme.text

        anchors.left: dialCard.right
        anchors.leftMargin: Theme.dp(12)
        anchors.right: parent.right
        height: pomo.tuning ? page.height : Theme.dp(176)
        radius: Theme.shapeXl
        color: pomo.tinted ? Theme.withBlur(Theme.tertiaryContainer) : Theme.withBlur(Theme.surfaceHigh)

        Column {
            id: pomoHead

            x: Theme.dp(20)
            y: Theme.dp(16)
            spacing: Theme.dp(2)

            Row {
                spacing: Theme.dp(8)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Chrono.pomoPhase === "focus" ? "psychiatry" : (Chrono.pomoActive ? "coffee" : "timer")
                    size: Theme.dp(20)
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

            LText {
                visible: Prefs.pomodoroGoal > 0 || Chrono.pomoToday > 0
                role: "bodySmall"
                weight: Chrono.pomoGoalMet ? 600 : 400
                color: Theme.alpha(pomo.ink, Chrono.pomoGoalMet ? 1 : 0.75)
                text: {
                    const n = Chrono.pomoToday;
                    const bits = [Prefs.pomodoroGoal > 0 ? n + " of " + Prefs.pomodoroGoal + " today" : n + (n === 1 ? " session today" : " sessions today")];
                    if (Chrono.pomoTodayMs > 0)
                        bits.push(page.spanText(Chrono.pomoTodayMs) + " focused");

                    return bits.join(" · ");
                }
            }

        }

        IconButton {
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            y: Theme.dp(10)
            icon: pomo.tuning ? "close" : "tune"
            tintOverride: pomo.ink
            onClicked: pomo.tuning = !pomo.tuning
        }

        Item {
            anchors.top: pomoHead.bottom
            anchors.topMargin: Theme.dp(10)
            anchors.bottom: pomoCount.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.dp(20)
            anchors.rightMargin: Theme.dp(20)
            visible: opacity > 0
            opacity: Math.max(0, (pomo.t - 0.4) / 0.6)
            clip: true

            Column {
                width: parent.width
                spacing: Theme.dp(8)

                Row {
                    spacing: Theme.dp(6)

                    Repeater {
                        model: Chrono.pomoPresets

                        Chip {
                            required property var modelData

                            kind: "filter"
                            selected: Chrono.pomoPreset === modelData.key
                            text: modelData.label
                            onClicked: Chrono.pomoUsePreset(modelData.key)
                        }

                    }

                }

                Grid {
                    id: lengths

                    readonly property real cell: (width - columnSpacing) / 2

                    width: parent.width
                    columns: 2
                    columnSpacing: Theme.dp(16)
                    rowSpacing: Theme.dp(2)

                    Stepper {
                        width: lengths.cell
                        label: "Focus"
                        from: 5
                        to: 90
                        step: 5
                        value: Prefs.pomodoroFocus
                        onMoved: (v) => {
                            return Prefs.pomodoroFocus = v;
                        }
                    }

                    Stepper {
                        width: lengths.cell
                        label: "Rounds"
                        from: 2
                        to: 8
                        value: Prefs.pomodoroRounds
                        onMoved: (v) => {
                            return Prefs.pomodoroRounds = v;
                        }
                    }

                    Stepper {
                        width: lengths.cell
                        label: "Break"
                        from: 1
                        to: 30
                        value: Prefs.pomodoroShort
                        onMoved: (v) => {
                            return Prefs.pomodoroShort = v;
                        }
                    }

                    Stepper {
                        width: lengths.cell
                        label: "Long break"
                        from: 5
                        to: 60
                        step: 5
                        value: Prefs.pomodoroLong
                        onMoved: (v) => {
                            return Prefs.pomodoroLong = v;
                        }
                    }

                    Stepper {
                        width: lengths.cell
                        label: "Daily goal"
                        to: 16
                        zeroText: "Off"
                        value: Prefs.pomodoroGoal
                        onMoved: (v) => {
                            return Prefs.pomodoroGoal = v;
                        }
                    }

                }

                Flow {
                    width: parent.width
                    spacing: Theme.dp(6)

                    Chip {
                        text: "Auto breaks"
                        selected: Prefs.pomodoroAutoStart
                        onClicked: Prefs.pomodoroAutoStart = !Prefs.pomodoroAutoStart
                    }

                    Chip {
                        text: "Auto focus"
                        selected: Prefs.pomodoroAutoFocus
                        onClicked: Prefs.pomodoroAutoFocus = !Prefs.pomodoroAutoFocus
                    }

                    Chip {
                        text: "Repeat sets"
                        selected: Prefs.pomodoroRepeat
                        onClicked: Prefs.pomodoroRepeat = !Prefs.pomodoroRepeat
                    }

                    Chip {
                        text: "Do not disturb"
                        selected: Prefs.pomodoroSilence
                        onClicked: Prefs.pomodoroSilence = !Prefs.pomodoroSilence
                    }

                }

            }

        }

        LText {
            id: pomoCount

            x: Theme.dp(20)
            anchors.bottom: dots.top
            anchors.bottomMargin: Theme.dp(6)
            size: Theme.fs(text.length > 5 ? 34 : 42)
            weight: 620
            rounded: 100
            tabular: true
            color: pomo.ink
            text: Chrono.countdown(Chrono.pomoActive ? Chrono.pomoRemaining : Prefs.pomodoroFocus * 60000)
        }

        Row {
            id: dots

            x: Theme.dp(22)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(22)
            spacing: Theme.dp(6)

            Repeater {
                model: Prefs.pomodoroRounds

                Rectangle {
                    required property int index
                    readonly property bool done: index < Chrono.pomoRound % Math.max(1, Prefs.pomodoroRounds)
                    readonly property bool current: Chrono.pomoPhase === "focus" && index === Chrono.pomoRound % Math.max(1, Prefs.pomodoroRounds)

                    anchors.verticalCenter: parent.verticalCenter
                    width: current ? Theme.dp(22) : Theme.dp(8)
                    height: Theme.dp(8)
                    radius: Theme.dp(4)
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
            anchors.rightMargin: Theme.dp(16)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(16)
            spacing: Theme.dp(6)

            IconButton {
                visible: Chrono.pomoActive
                anchors.verticalCenter: parent.verticalCenter
                icon: "more_time"
                tintOverride: pomo.ink
                onClicked: Chrono.pomoExtend(60)
            }

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

        Behavior on height {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveStandard
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
        anchors.leftMargin: Theme.dp(12)
        anchors.right: parent.right
        anchors.top: pomo.bottom
        anchors.topMargin: Theme.dp(12)
        anchors.bottom: parent.bottom
        visible: opacity > 0
        opacity: 1 - Math.min(1, pomo.t * 2.5)
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        LText {
            id: listHead

            x: Theme.dp(20)
            y: Theme.dp(16)
            role: "titleSmall"
            text: Chrono.timers.length ? "Timers" : "No timers running"
            color: Chrono.timers.length ? Theme.text : Theme.subtext
        }

        Button {
            visible: Chrono.timers.some((t) => {
                return !t.running && t.left <= 0;
            })
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            anchors.verticalCenter: listHead.verticalCenter
            variant: "text"
            size: "xs"
            text: "Clear done"
            onClicked: Chrono.clearFinished()
        }

        Flickable {
            anchors.top: listHead.bottom
            anchors.topMargin: Theme.dp(8)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.dp(10)
            anchors.rightMargin: Theme.dp(10)
            anchors.bottomMargin: Theme.dp(10)
            contentHeight: timerCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: timerCol

                width: parent.width
                spacing: Theme.dp(2)

                Repeater {
                    model: Chrono.timers

                    Rectangle {
                        id: trow

                        required property var modelData
                        required property int index
                        readonly property real rem: Chrono.remaining(trow.modelData)
                        readonly property bool isFocus: page.focused !== null && page.focused.id === trow.modelData.id

                        width: timerCol.width
                        height: Theme.dp(52)
                        radius: trow.isFocus ? Theme.dp(26) : Theme.dp(12)
                        color: trow.isFocus ? Theme.withBlur(Theme.secondaryContainer) : Theme.withBlur(Theme.surfaceHighest)

                        StateLayer {
                            radius: parent.radius
                            onClicked: page.focusId = trow.modelData.id
                        }

                        CircularProgress {
                            x: Theme.dp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.dp(32)
                            height: Theme.dp(32)
                            thickness: Theme.dp(4)
                            value: trow.modelData.total > 0 ? trow.rem / trow.modelData.total : 0
                            color: trow.rem <= 0 ? Theme.error : Theme.primary
                        }

                        Column {
                            x: Theme.dp(54)
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
                            anchors.rightMargin: Theme.dp(6)
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
