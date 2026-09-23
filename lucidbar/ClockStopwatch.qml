import QtQuick
import qs
import qs.lucidui

// one stopwatch: a sweep that goes round once a minute, and a lap list that
// marks the quickest lap and the slowest
Item {
    id: page

    property var host: null
    // the stopwatch's own frame clock while it is on screen, so hundredths run smoothly
    property real frameNow: Date.now()
    readonly property real elapsed: Chrono.swRunning ? Chrono.swBank + (page.frameNow - Chrono.swStart) : Chrono.swBank

    Timer {
        interval: 33
        repeat: true
        running: page.visible && Chrono.swRunning
        onTriggered: page.frameNow = Date.now()
    }
    readonly property var splits: {
        const out = [];
        let prev = 0;
        for (let i = 0; i < Chrono.laps.length; i++) {
            out.push({ "n": i + 1, "split": Chrono.laps[i] - prev, "total": Chrono.laps[i] });
            prev = Chrono.laps[i];
        }
        return out.reverse();
    }
    readonly property real best: page.splits.length > 1 ? Math.min.apply(null, page.splits.map((s) => {
        return s.split;
    })) : -1
    readonly property real worst: page.splits.length > 1 ? Math.max.apply(null, page.splits.map((s) => {
        return s.split;
    })) : -1

    implicitHeight: 404

    Rectangle {
        id: face

        width: 360
        height: parent.height
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        Item {
            id: dial

            anchors.horizontalCenter: parent.horizontalCenter
            y: 28
            width: 250
            height: 250

            MaterialShape {
                anchors.centerIn: parent
                width: 206
                height: 206
                shape: "sunny"
                color: Chrono.swRunning ? Theme.alpha(Theme.primary, 0.1) : Theme.withBlur(Theme.surfaceHighest)

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 60000
                    loops: Animation.Infinite
                    running: Chrono.swRunning && page.visible
                }

            }

            CircularProgress {
                anchors.fill: parent
                thickness: 8
                value: Chrono.swActive ? (page.elapsed % 60000) / 60000 : 0
                trackColor: Theme.withBlur(Theme.surfaceHighest)
                animated: false
            }

            Column {
                anchors.centerIn: parent
                spacing: -4

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: Theme.fs(page.elapsed >= 3600000 ? 40 : 50)
                    weight: 620
                    rounded: 100
                    tabular: true
                    text: Chrono.clock(page.elapsed, false)
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "titleMedium"
                    weight: 560
                    tabular: true
                    color: Theme.primary
                    text: "." + String(Math.floor((page.elapsed % 1000) / 10)).padStart(2, "0")
                }

            }

        }

        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "tonal"
                icon: "flag"
                text: "Lap"
                disabled: !Chrono.swRunning
                onClicked: Chrono.swLap()
            }

            Rectangle {
                width: 76
                height: 58
                radius: swArea.pressed ? 16 : 29
                color: Chrono.swRunning ? Theme.secondaryContainer : Theme.primary

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }

                }

                Icon {
                    anchors.centerIn: parent
                    name: Chrono.swRunning ? "pause" : "play_arrow"
                    size: 30
                    fill: 1
                    color: Chrono.swRunning ? Theme.fgSecondaryContainer : Theme.fgPrimary
                }

                StateLayer {
                    id: swArea

                    radius: parent.radius
                    tint: Theme.fgPrimary
                    onClicked: Chrono.swToggle()
                }

            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "tonal"
                icon: "replay"
                text: "Reset"
                disabled: !Chrono.swActive
                onClicked: Chrono.swReset()
            }

        }

    }

    Rectangle {
        anchors.left: face.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        height: parent.height
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)

        LText {
            id: lapHead

            x: 20
            y: 16
            role: "titleSmall"
            text: page.splits.length ? page.splits.length + (page.splits.length === 1 ? " lap" : " laps") : "Laps"
        }

        Column {
            visible: page.splits.length === 0
            anchors.centerIn: parent
            spacing: 8

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "flag"
                size: 32
                color: Theme.subtextDim
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "bodyMedium"
                color: Theme.subtext
                text: "Laps you take land here"
            }

        }

        ListView {
            anchors.top: lapHead.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 10
            clip: true
            spacing: 2
            model: page.splits
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: lap

                required property var modelData
                required property int index
                readonly property bool isBest: lap.modelData.split === page.best
                readonly property bool isWorst: lap.modelData.split === page.worst

                width: ListView.view.width
                height: 44
                radius: 12
                color: Theme.withBlur(Theme.surfaceHighest)

                LText {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    color: Theme.subtext
                    text: "Lap " + lap.modelData.n
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        visible: lap.isBest || lap.isWorst
                        anchors.verticalCenter: parent.verticalCenter
                        name: lap.isBest ? "arrow_downward" : "arrow_upward"
                        size: 15
                        color: lap.isBest ? Theme.success : Theme.error
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "titleSmall"
                        weight: 640
                        tabular: true
                        color: lap.isBest ? Theme.success : (lap.isWorst ? Theme.error : Theme.text)
                        text: Chrono.clock(lap.modelData.split, true)
                    }

                }

                LText {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodySmall"
                    tabular: true
                    color: Theme.subtext
                    text: Chrono.clock(lap.modelData.total, true)
                }

            }

        }

    }

}
