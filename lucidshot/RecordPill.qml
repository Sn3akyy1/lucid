import QtQuick
import qs
import qs.lucidui

// the recording's controls: how long it has run, pause, the two sources, stop,
// and a way to tuck it all into the bar. a floating toolbar of its own
Item {
    id: pill

    readonly property bool saving: Capture.state === "saving"
    readonly property bool paused: Capture.state === "paused"
    property bool tipAbove: true
    readonly property bool jellyWobbling: squish.wobbling

    implicitWidth: (pill.saving ? savingRow.implicitWidth : row.implicitWidth) + Theme.dp(16)
    implicitHeight: Theme.dp(56)

    function kick() {
        squish.kick(0.1);
    }

    Rectangle {
        id: face

        anchors.fill: parent
        radius: height / 2
        color: Theme.bg
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.06)
    }

    Row {
        id: row

        x: Theme.dp(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(4)
        visible: !pill.saving

        // the drag handle and the clock in one: grab here to move it
        Item {
            id: clock

            anchors.verticalCenter: parent.verticalCenter
            width: clockRow.implicitWidth + Theme.dp(20)
            height: Theme.dp(40)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.errorContainer
            }

            Row {
                id: clockRow

                anchors.centerIn: parent
                spacing: Theme.dp(8)

                Rectangle {
                    id: dot

                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(10)
                    height: width
                    radius: width / 2
                    color: pill.paused ? Theme.fgErrorContainer : Theme.error

                    SequentialAnimation on opacity {
                        running: pill.visible && Capture.state === "recording"
                        loops: Animation.Infinite
                        onRunningChanged: {
                            if (!running)
                                dot.opacity = 1;

                        }

                        NumberAnimation {
                            to: 0.3
                            duration: 700
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 1
                            duration: 700
                            easing.type: Easing.InOutSine
                        }

                    }

                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    tabular: true
                    color: Theme.fgErrorContainer
                    text: pill.paused ? "Paused  " + Capture.clock(Capture.seconds) : Capture.clock(Capture.seconds)
                }

            }

            HoverHandler {
                cursorShape: Qt.SizeAllCursor
            }

        }

        ShotButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: pill.paused ? "play_arrow" : "pause"
            tip: pill.paused ? "Carry on" : "Pause"
            tipAbove: pill.tipAbove
            onClicked: Capture.togglePause()
        }

        ShotButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Capture.mic ? "mic" : "mic_off"
            tip: Capture.mic ? "The microphone is in it" : "The microphone is left out"
            tipAbove: pill.tipAbove
            checked: Capture.mic
            onClicked: Capture.setMic(!Capture.mic)
        }

        ShotButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Capture.system ? "volume_up" : "volume_off"
            tip: Capture.system ? "What is playing is in it" : "What is playing is left out"
            tipAbove: pill.tipAbove
            checked: Capture.system
            onClicked: Capture.setSystem(!Capture.system)
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            variant: "filled"
            danger: true
            size: "s"
            icon: "stop"
            text: "Stop"
            onClicked: Capture.stop()
        }

        ShotButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "expand_more"
            tip: "Tuck it into the bar"
            tipAbove: pill.tipAbove
            onClicked: Capture.hidden = true
        }

    }

    Row {
        id: savingRow

        anchors.centerIn: parent
        spacing: Theme.dp(10)
        visible: pill.saving

        LoadingIndicator {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(32)
            height: width
            running: pill.saving && pill.visible
        }

        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: "labelLarge"
            color: Theme.text
            text: "Saving the recording…"
        }

        Item {
            width: Theme.dp(6)
            height: 1
        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durDefaultSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    transform: Jelly {
        id: squish

        target: pill
        spread: 0.3
    }

}
