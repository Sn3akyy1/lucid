import QtQuick
import qs
import qs.lucidui

// a short note at the bottom of the window, with one action (usually undo)
Rectangle {
    id: snack

    property string message: ""
    property string action: ""
    property var payload: null
    property bool shown: false

    signal acted(var payload)

    function show(msg, act, data) {
        snack.message = msg;
        snack.action = act || "";
        snack.payload = data || null;
        snack.shown = true;
        life.restart();
    }

    anchors.horizontalCenter: parent.horizontalCenter
    y: snack.shown ? parent.height - height - Theme.dp(20) : parent.height + Theme.dp(8)
    width: Math.min(parent.width - Theme.dp(48), row.implicitWidth + Theme.dp(36))
    height: Theme.dp(48)
    radius: height / 2
    // the window's own tones, not m3's inverse: dark in dark mode
    color: Theme.surfaceHighest
    border.width: 1
    border.color: Theme.alpha(Theme.text, 0.08)
    opacity: snack.shown ? 1 : 0
    visible: opacity > 0

    Timer {
        id: life

        interval: snack.action !== "" ? 6500 : 3800
        onTriggered: snack.shown = false
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: containsMouse ? life.stop() : life.restart()
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        x: Theme.dp(20)
        spacing: Theme.dp(12)

        LText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, snack.parent.width - Theme.dp(200))
            role: "bodyMedium"
            text: snack.message
            color: Theme.text
            elide: Text.ElideRight
        }

        Item {
            visible: snack.action !== ""
            width: act.implicitWidth + Theme.dp(20)
            height: snack.height

            LText {
                id: act

                anchors.centerIn: parent
                role: "labelLarge"
                text: snack.action
                color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    snack.shown = false;
                    snack.acted(snack.payload);
                }
            }

        }

    }

    Behavior on y {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

}
