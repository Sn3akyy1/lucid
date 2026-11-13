import QtQuick
import Quickshell
import qs
import qs.lucidlumen
import qs.lucidui
import "ClockMath.js" as CM

// one stopwatch, the shell's: a ring as big as the pane lets it be that goes
// round once a minute, the time to the hundredth, and the laps as a grouped
// list with the quickest and the slowest marked
Item {
    id: page

    property var app: null
    property var win: null
    property bool shown: false
    property real frameNow: Date.now()
    readonly property var c: page.app ? page.app.chrono : null
    readonly property bool running: page.c !== null && page.c.swRunning === true
    readonly property real elapsed: !page.c ? 0 : (page.running ? page.c.swBank + (page.frameNow - page.c.swStart) : page.c.swBank)
    readonly property bool active: page.running || page.elapsed > 0
    readonly property var laps: {
        const out = [];
        const list = page.c ? (page.c.laps || []) : [];
        let prev = 0;
        for (let i = 0; i < list.length; i++) {
            out.push({
                "n": i + 1,
                "split": list[i] - prev,
                "total": list[i]
            });
            prev = list[i];
        }
        return out.reverse();
    }
    readonly property real lastLap: page.c && page.c.laps && page.c.laps.length ? page.c.laps[page.c.laps.length - 1] : 0
    readonly property real fastest: page.laps.length >= 2 ? Math.min.apply(null, page.laps.map((l) => {
        return l.split;
    })) : -1
    readonly property real slowest: page.laps.length >= 2 ? Math.max.apply(null, page.laps.map((l) => {
        return l.split;
    })) : -1
    readonly property bool wide: page.width >= Theme.dp(900)
    readonly property int edge: Theme.dp(32)
    readonly property real bodyH: page.height - head.height - Theme.dp(24)
    // the sidebar's button starts and stops it too
    readonly property string primaryIcon: page.running ? "pause" : "play_arrow"
    readonly property string primaryLabel: page.running ? "Pause" : (page.active ? "Resume" : "Start")

    function primaryAction() {
        page.app.send("sw.toggle");
    }

    function handleKey(e) {
        if (e.key === Qt.Key_Space) {
            page.app.send("sw.toggle");
            return true;
        }
        if (e.key === Qt.Key_L && page.running) {
            page.app.send("sw.lap");
            return true;
        }
        if ((e.key === Qt.Key_R || e.key === Qt.Key_Backspace) && !page.running && page.active) {
            page.app.send("sw.reset");
            return true;
        }
        return false;
    }

    function copyLaps() {
        const lines = page.laps.slice().reverse().map((l) => {
            return "Lap " + l.n + "\t" + CM.clock(l.split, true) + "\t" + CM.clock(l.total, true);
        });
        lines.push("Total\t" + CM.clock(page.elapsed, true));
        Quickshell.execDetached(["wl-copy", "--", lines.join("\n")]);
        page.win.toast("Laps copied");
    }

    // hundredths run smoothly only on screen; the shell keeps the real time
    FrameAnimation {
        running: page.shown && page.running
        onTriggered: page.frameNow = Date.now()
    }

    Timer {
        interval: 250
        running: page.shown && !page.running
        triggeredOnStart: true
        onTriggered: page.frameNow = Date.now()
    }

    PageHead {
        id: head

        x: page.edge
        width: parent.width - page.edge * 2
        title: "Stopwatch"
        subtitle: page.running ? "Running" + (page.laps.length ? ", lap " + (page.laps.length + 1) : "") : (page.active ? "Paused at " + CM.clock(page.elapsed, true) : "Space starts it, L takes a lap")
    }

    // ---- the ring, as big as the room it has
    Item {
        id: dialZone

        x: page.edge
        y: head.height
        width: page.wide ? Math.min(page.width * 0.5, Theme.dp(600)) : page.width - page.edge * 2
        height: page.wide ? page.bodyH : dialCol.implicitHeight + Theme.dp(8)

        Column {
            id: dialCol

            anchors.horizontalCenter: parent.horizontalCenter
            y: page.wide ? Math.max(0, (dialZone.height - implicitHeight) / 2) : 0
            spacing: Theme.dp(26)

            Item {
                id: ring

                readonly property real size: page.wide ? Math.max(Theme.dp(220), Math.min(dialZone.width - Theme.dp(24), page.bodyH - Theme.dp(130), Theme.dp(480))) : Math.min(dialZone.width, Theme.dp(260))

                anchors.horizontalCenter: parent.horizontalCenter
                width: ring.size
                height: ring.size

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    // withBlur sets the alpha itself, so the faint running tint stays out of it
                    color: page.running ? Theme.alpha(Theme.primary, 0.1) : Theme.withBlur(Theme.bgTile)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

                CircularProgress {
                    anchors.fill: parent
                    anchors.margins: Math.round(ring.size * 0.035)
                    thickness: Math.max(Theme.dp(8), Math.round(ring.size * 0.03))
                    value: page.active ? (page.elapsed % 60000) / 60000 : 0
                    animated: false
                    wavy: false
                    color: Theme.primary
                    trackColor: Theme.alpha(Theme.primary, 0.14)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter

                        LText {
                            id: mainTime

                            // an hour's place takes room, so the figures step down for it
                            size: Math.round(ring.size * (page.elapsed >= 3600000 ? 0.145 : 0.2))
                            weight: 500
                            rounded: 100
                            tabular: true
                            text: CM.clock(page.elapsed, false)
                        }

                        LText {
                            anchors.baseline: mainTime.baseline
                            size: Math.round(mainTime.size * 0.5)
                            weight: 520
                            rounded: 100
                            tabular: true
                            color: Theme.primary
                            text: "." + CM.pad(Math.floor((page.elapsed % 1000) / 10))
                        }

                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: page.laps.length > 0
                        role: ring.size > Theme.dp(320) ? "titleMedium" : "bodyMedium"
                        tabular: true
                        color: Theme.subtext
                        text: "Lap " + (page.laps.length + 1) + "  " + CM.clock(page.elapsed - page.lastLap, true)
                    }

                }

            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.dp(16)

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    size: "m"
                    icon: "replay"
                    tooltip: "Reset"
                    disabled: page.running || !page.active
                    onClicked: page.app.send("sw.reset")
                }

                Rectangle {
                    width: Theme.dp(120)
                    height: Theme.dp(76)
                    radius: page.running ? Theme.dp(24) : height / 2
                    color: page.running ? Theme.secondaryContainer : Theme.primary

                    Icon {
                        anchors.centerIn: parent
                        name: page.running ? "pause" : "play_arrow"
                        size: Theme.dp(34)
                        fill: 1
                        color: page.running ? Theme.fgSecondaryContainer : Theme.fgPrimary
                    }

                    StateLayer {
                        objectName: "swToggle"
                        radius: parent.radius
                        tint: page.running ? Theme.fgSecondaryContainer : Theme.fgPrimary
                        onClicked: page.app.send("sw.toggle")
                    }

                    Behavior on radius {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    size: "m"
                    icon: "flag"
                    tooltip: "Lap"
                    disabled: !page.running
                    onClicked: page.app.send("sw.lap")
                }

            }

        }

    }

    // ---- the laps, one grouped list
    Item {
        id: lapZone

        x: page.wide ? dialZone.x + dialZone.width + Theme.dp(28) : page.edge
        y: page.wide ? head.height : dialZone.y + dialZone.height + Theme.dp(18)
        width: page.wide ? page.width - x - page.edge : page.width - page.edge * 2
        height: page.height - y

        Item {
            id: lapHead

            width: parent.width
            height: Theme.dp(40)

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "titleMedium"
                text: page.laps.length ? page.laps.length + (page.laps.length === 1 ? " lap" : " laps") : "Laps"
            }

            Button {
                visible: page.laps.length > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: "text"
                icon: "content_copy"
                text: "Copy"
                onClicked: page.copyLaps()
            }

        }

        Scroller {
            anchors.top: lapHead.bottom
            anchors.topMargin: Theme.dp(8)
            anchors.bottom: parent.bottom
            width: parent.width
            contentHeight: lapList.implicitHeight + Theme.dp(24)

            Column {
                id: lapList

                width: parent.width
                spacing: Theme.dp(3)

                Repeater {
                    model: page.laps

                    GroupRow {
                        id: lap

                        required property var modelData
                        required property int index
                        readonly property bool quick: page.fastest >= 0 && lap.modelData.split === page.fastest
                        readonly property bool slow: page.slowest >= 0 && lap.modelData.split === page.slowest && page.slowest !== page.fastest

                        width: lapList.width
                        height: Theme.dp(60)
                        first: lap.index === 0
                        last: lap.index === page.laps.length - 1

                        LText {
                            x: Theme.dp(24)
                            anchors.verticalCenter: parent.verticalCenter
                            role: "titleSmall"
                            text: "Lap " + lap.modelData.n
                        }

                        Rectangle {
                            visible: lap.quick || lap.slow
                            x: Theme.dp(104)
                            anchors.verticalCenter: parent.verticalCenter
                            width: tag.implicitWidth + Theme.dp(16)
                            height: Theme.dp(24)
                            radius: height / 2
                            color: lap.quick ? Theme.alpha(Theme.success, 0.18) : Theme.alpha(Theme.error, 0.16)

                            LText {
                                id: tag

                                anchors.centerIn: parent
                                role: "labelMedium"
                                color: lap.quick ? Theme.success : Theme.error
                                text: lap.quick ? "Fastest" : "Slowest"
                            }

                        }

                        LText {
                            anchors.right: totalText.left
                            anchors.rightMargin: Theme.dp(28)
                            anchors.verticalCenter: parent.verticalCenter
                            role: "titleMedium"
                            tabular: true
                            color: lap.quick ? Theme.success : (lap.slow ? Theme.error : Theme.text)
                            text: CM.clock(lap.modelData.split, true)
                        }

                        LText {
                            id: totalText

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(24)
                            anchors.verticalCenter: parent.verticalCenter
                            role: "bodyMedium"
                            tabular: true
                            color: Theme.subtext
                            text: CM.clock(lap.modelData.total, true)
                        }

                    }

                }

                // no laps yet: a row that says what goes here
                GroupRow {
                    visible: page.laps.length === 0
                    width: lapList.width
                    height: Theme.dp(72)
                    hoverable: false

                    Row {
                        x: Theme.dp(24)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(14)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "flag"
                            size: Theme.dp(22)
                            color: Theme.subtext
                        }

                        LText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "bodyMedium"
                            color: Theme.subtext
                            text: "Laps you take land here, the quickest and the slowest marked"
                        }

                    }

                }

            }

        }

    }

}
