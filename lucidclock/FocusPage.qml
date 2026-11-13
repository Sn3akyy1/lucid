import QtQuick
import qs
import qs.lucidlumen
import qs.lucidui
import "ClockMath.js" as CM

// the pomodoro, the shell's: focus, a short break, and after a few rounds a
// long one. the ring (as big as the pane lets it be) empties through each,
// the dots count the rounds, and how it runs is a grouped list beside it
Item {
    id: page

    property var app: null
    property var win: null
    property bool shown: false
    property real nowMs: Date.now()
    readonly property var c: page.app ? page.app.chrono : null
    readonly property var p: page.app ? page.app.shellPrefs : ({})
    readonly property string phase: page.c ? page.c.pomoPhase : "idle"
    readonly property bool active: page.phase !== "idle"
    readonly property bool running: page.c !== null && page.c.pomoRunning === true
    readonly property real total: page.c && page.c.pomoSpan > 0 ? page.c.pomoSpan : page.phaseMinutes(page.active ? page.phase : "focus") * 60000
    readonly property real remaining: !page.c ? 0 : (!page.active ? page.total : (page.running ? Math.max(0, page.c.pomoEndsAt - page.nowMs) : page.c.pomoLeft))
    readonly property int rounds: Math.max(1, page.p.pomodoroRounds || 4)
    readonly property string todayKey: Qt.formatDate(new Date(page.nowMs + (page.app ? page.app.shift : 0)), "yyyy-MM-dd")
    readonly property int doneToday: page.c && page.c.pomoDay === page.todayKey ? page.c.pomoDone : 0
    readonly property real focusedToday: page.c && page.c.pomoDay === page.todayKey ? page.c.pomoFocusMs : 0
    readonly property bool onBreak: page.phase === "short" || page.phase === "long"
    readonly property color tone: page.onBreak ? Theme.tertiary : Theme.primary
    readonly property bool wide: page.width >= Theme.dp(900)
    readonly property int edge: Theme.dp(32)
    readonly property real bodyH: page.height - head.height - Theme.dp(24)
    readonly property string preset: {
        if (!page.c)
            return "";

        for (const q of (page.c.presets || [])) {
            if (q.focus === page.p.pomodoroFocus && q.short === page.p.pomodoroShort && q.long === page.p.pomodoroLong && q.rounds === page.p.pomodoroRounds)
                return q.key;

        }
        return "";
    }
    // the sidebar's button starts and pauses it too
    readonly property string primaryIcon: page.running ? "pause" : "play_arrow"
    readonly property string primaryLabel: !page.active ? "Start focus" : (page.running ? "Pause" : "Resume")

    function primaryAction() {
        page.app.send("pomo.toggle");
    }

    function phaseMinutes(ph) {
        if (ph === "short")
            return page.p.pomodoroShort || 5;

        if (ph === "long")
            return page.p.pomodoroLong || 15;

        return page.p.pomodoroFocus || 25;
    }

    function phaseName(ph) {
        return ph === "short" ? "Short break" : (ph === "long" ? "Long break" : (ph === "focus" ? "Focus" : "Ready to focus"));
    }

    function setPref(key, value) {
        page.app.send("pref.set", {
            "key": key,
            "value": value
        });
    }

    function handleKey(e) {
        if (e.key === Qt.Key_Space) {
            page.app.send("pomo.toggle");
            return true;
        }
        if (e.key === Qt.Key_S && page.active) {
            page.app.send("pomo.skip");
            return true;
        }
        return false;
    }

    Timer {
        interval: 250
        repeat: true
        running: page.shown
        triggeredOnStart: true
        onTriggered: page.nowMs = Date.now()
    }

    PageHead {
        id: head

        x: page.edge
        width: parent.width - page.edge * 2
        title: "Focus"
        subtitle: {
            const bits = [];
            if (page.doneToday > 0)
                bits.push(page.doneToday + (page.doneToday === 1 ? " session" : " sessions") + " today");

            if (page.focusedToday > 0)
                bits.push(CM.span(page.focusedToday) + " focused");

            if ((page.p.pomodoroGoal || 0) > 0)
                bits.push(page.doneToday >= page.p.pomodoroGoal ? "goal reached" : "goal " + page.p.pomodoroGoal);

            return bits.length ? bits.join("  ·  ") : "Work in rounds, with breaks between";
        }
    }

    // ---- the ring
    Item {
        id: dialZone

        x: page.edge
        y: head.height
        width: page.wide ? Math.min(page.width * 0.48, Theme.dp(580)) : page.width - page.edge * 2
        height: page.wide ? page.bodyH : dialCol.implicitHeight + Theme.dp(8)

        Column {
            id: dialCol

            anchors.horizontalCenter: parent.horizontalCenter
            y: page.wide ? Math.max(0, (dialZone.height - implicitHeight) / 2) : 0
            spacing: Theme.dp(24)

            Item {
                id: ring

                readonly property real size: page.wide ? Math.max(Theme.dp(220), Math.min(dialZone.width - Theme.dp(24), page.bodyH - Theme.dp(((page.p.pomodoroGoal || 0) > 0) ? 210 : 130), Theme.dp(460))) : Math.min(dialZone.width, Theme.dp(260))

                anchors.horizontalCenter: parent.horizontalCenter
                width: ring.size
                height: ring.size

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: page.running ? Theme.alpha(page.tone, 0.1) : Theme.withBlur(Theme.bgTile)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

                CircularProgress {
                    anchors.fill: parent
                    anchors.margins: Math.round(ring.size * 0.035)
                    thickness: Math.max(Theme.dp(10), Math.round(ring.size * 0.035))
                    value: page.active ? page.remaining / Math.max(1, page.total) : 1
                    wavy: page.running
                    color: page.active ? page.tone : Theme.alpha(Theme.text, 0.25)
                    trackColor: Theme.alpha(page.tone, 0.14)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.dp(6)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: page.onBreak ? "coffee" : "psychiatry"
                            size: Math.round(ring.size * 0.07)
                            fill: 1
                            color: page.active ? page.tone : Theme.subtext
                        }

                        LText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: ring.size > Theme.dp(320) ? "titleLarge" : "titleMedium"
                            color: page.active ? page.tone : Theme.subtext
                            text: page.phaseName(page.phase)
                        }

                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: Math.round(ring.size * (page.remaining >= 3600000 ? 0.15 : 0.2))
                        weight: 500
                        rounded: 100
                        tabular: true
                        opacity: page.active && !page.running ? 0.6 : 1
                        text: CM.countdown(page.remaining)
                    }

                    // a dot a round: done, the one in hand, still to come
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.dp(6)

                        Repeater {
                            model: page.rounds

                            Rectangle {
                                required property int index
                                readonly property int inSet: page.c ? page.c.pomoRound % page.rounds : 0
                                readonly property bool done: index < inSet
                                readonly property bool current: page.phase === "focus" && index === inSet

                                width: current ? Theme.dp(24) : Theme.dp(9)
                                height: Theme.dp(9)
                                radius: height / 2
                                color: done || current ? page.tone : Theme.alpha(Theme.text, 0.2)

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.durFastSpatial
                                    }

                                }

                            }

                        }

                    }

                }

            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.dp(14)

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    size: "m"
                    icon: "stop"
                    tooltip: "Stop"
                    disabled: !page.active
                    onClicked: page.app.send("pomo.stop")
                }

                Rectangle {
                    width: Theme.dp(120)
                    height: Theme.dp(76)
                    radius: page.running ? Theme.dp(24) : height / 2
                    color: page.running ? Theme.secondaryContainer : page.tone

                    Icon {
                        anchors.centerIn: parent
                        name: page.running ? "pause" : "play_arrow"
                        size: Theme.dp(34)
                        fill: 1
                        color: page.running ? Theme.fgSecondaryContainer : (page.onBreak ? Theme.fgTertiary : Theme.fgPrimary)
                    }

                    StateLayer {
                        radius: parent.radius
                        tint: Theme.fgPrimary
                        onClicked: page.app.send("pomo.toggle")
                    }

                    Behavior on radius {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                        }

                    }

                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    size: "m"
                    icon: "skip_next"
                    tooltip: page.phase === "focus" ? "Skip to the break" : "Skip to focus"
                    disabled: !page.active
                    onClicked: page.app.send("pomo.skip")
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    size: "m"
                    icon: "more_time"
                    tooltip: "A minute more"
                    disabled: !page.active
                    onClicked: page.app.send("pomo.extend", {
                        "sec": 60
                    })
                }

            }

            // today's tally against the goal
            Item {
                visible: (page.p.pomodoroGoal || 0) > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(ring.size, Theme.dp(360))
                height: Theme.dp(44)

                LText {
                    role: "labelLarge"
                    color: page.doneToday >= page.p.pomodoroGoal ? Theme.success : Theme.subtext
                    text: page.doneToday >= page.p.pomodoroGoal ? "Daily goal reached" : page.doneToday + " of " + page.p.pomodoroGoal + " sessions today"
                }

                LinearProgress {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    value: Math.min(1, page.doneToday / Math.max(1, page.p.pomodoroGoal))
                    color: page.doneToday >= page.p.pomodoroGoal ? Theme.success : Theme.primary
                }

            }

        }

    }

    // ---- how it runs, one grouped list
    Scroller {
        id: scroller

        x: page.wide ? dialZone.x + dialZone.width + Theme.dp(28) : 0
        y: page.wide ? head.height : dialZone.y + dialZone.height + Theme.dp(18)
        width: page.wide ? page.width - x : page.width
        height: page.height - y
        contentHeight: setCol.implicitHeight + Theme.dp(28)

        Column {
            id: setCol

            x: page.wide ? 0 : page.edge
            width: scroller.width - page.edge - (page.wide ? 0 : page.edge)
            spacing: Theme.dp(3)

            Section {
                text: "Rhythm"
            }

            GroupRow {
                width: setCol.width
                height: presetFlow.implicitHeight + Theme.dp(30)
                first: true
                last: false
                hoverable: false

                Flow {
                    id: presetFlow

                    x: Theme.dp(20)
                    y: Theme.dp(15)
                    width: parent.width - Theme.dp(40)
                    spacing: Theme.dp(8)

                    Repeater {
                        model: page.c ? page.c.presets : []

                        Chip {
                            required property var modelData

                            kind: "filter"
                            text: modelData.name + "  " + modelData.label
                            selected: page.preset === modelData.key
                            onClicked: page.app.send("pomo.preset", {
                                "key": modelData.key
                            })
                        }

                    }

                }

            }

            Stepper {
                label: "Focus"
                note: "One session"
                value: page.p.pomodoroFocus || 25
                unit: "min"
                lo: 5
                hi: 180
                step: 5
                key: "pomodoroFocus"
            }

            Stepper {
                label: "Short break"
                value: page.p.pomodoroShort || 5
                unit: "min"
                lo: 1
                hi: 60
                step: 1
                key: "pomodoroShort"
            }

            Stepper {
                label: "Long break"
                value: page.p.pomodoroLong || 15
                unit: "min"
                lo: 5
                hi: 90
                step: 5
                key: "pomodoroLong"
            }

            Stepper {
                label: "Rounds before a long break"
                value: page.p.pomodoroRounds || 4
                unit: ""
                lo: 1
                hi: 12
                step: 1
                key: "pomodoroRounds"
            }

            Stepper {
                label: "Daily goal"
                note: "Sessions to aim for each day"
                value: page.p.pomodoroGoal || 0
                unit: (page.p.pomodoroGoal || 0) === 0 ? "" : "sessions"
                zeroText: "None"
                lo: 0
                hi: 24
                step: 1
                key: "pomodoroGoal"
                isLast: true
            }

            Section {
                text: "Going on by itself"
            }

            Toggle {
                label: "Start breaks by themselves"
                key: "pomodoroAutoStart"
                isFirst: true
            }

            Toggle {
                label: "Start focus again after a break"
                key: "pomodoroAutoFocus"
            }

            Toggle {
                label: "Start a new set after the long break"
                key: "pomodoroRepeat"
            }

            Toggle {
                label: "Do not disturb while focusing"
                note: "Notifications wait until the break"
                key: "pomodoroSilence"
                isLast: true
            }

        }

    }

    component Section: LText {
        topPadding: Theme.dp(14)
        bottomPadding: Theme.dp(8)
        leftPadding: Theme.dp(4)
        role: "titleSmall"
        color: Theme.primary
    }

    component Stepper: GroupRow {
        id: st

        property string label: ""
        property string note: ""
        property int value: 0
        property string unit: ""
        property string zeroText: ""
        property int lo: 0
        property int hi: 100
        property int step: 1
        property string key: ""
        property bool isLast: false

        width: setCol.width
        height: Theme.dp(64)
        first: false
        last: st.isLast

        Column {
            x: Theme.dp(22)
            anchors.verticalCenter: parent.verticalCenter

            LText {
                role: "bodyLarge"
                text: st.label
            }

            LText {
                visible: st.note !== ""
                role: "bodySmall"
                color: Theme.subtext
                text: st.note
            }

        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(4)

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                variant: "tonal"
                size: "xs"
                icon: "remove"
                disabled: st.value <= st.lo
                onClicked: page.setPref(st.key, Math.max(st.lo, st.value - st.step))
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(92)
                horizontalAlignment: Text.AlignHCenter
                role: "labelLarge"
                tabular: true
                text: st.value === 0 && st.zeroText !== "" ? st.zeroText : st.value + (st.unit !== "" ? " " + st.unit : "")
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                variant: "tonal"
                size: "xs"
                icon: "add"
                disabled: st.value >= st.hi
                onClicked: page.setPref(st.key, Math.min(st.hi, st.value + st.step))
            }

        }

    }

    component Toggle: GroupRow {
        id: tg

        property string label: ""
        property string note: ""
        property string key: ""
        property bool isFirst: false
        property bool isLast: false
        readonly property bool on: page.p[tg.key] === true

        width: setCol.width
        height: Theme.dp(64)
        first: tg.isFirst
        last: tg.isLast

        Column {
            x: Theme.dp(22)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.dp(110)

            LText {
                width: parent.width
                elide: Text.ElideRight
                role: "bodyLarge"
                text: tg.label
            }

            LText {
                visible: tg.note !== ""
                role: "bodySmall"
                color: Theme.subtext
                text: tg.note
            }

        }

        Switch {
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(20)
            anchors.verticalCenter: parent.verticalCenter
            checked: tg.on
            onToggled: (v) => {
                return page.setPref(tg.key, v);
            }
        }

    }

}
