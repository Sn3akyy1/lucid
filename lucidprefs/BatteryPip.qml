import QtQuick
import qs
import qs.lucidui

Row {
    id: pip

    property int charge: -1
    property bool charging: false

    readonly property bool low: pip.charge >= 0 && pip.charge < 20 && !pip.charging

    visible: pip.charge >= 0
    spacing: Theme.dp(6)

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: pip.charge + "%"
        color: pip.low ? Theme.error : Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: pip.charging
        name: "bolt"
        size: Theme.dp(14)
        fill: 1
        color: Theme.accent
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.dp(26)
        height: Theme.dp(6)
        radius: Theme.dp(3)
        color: Theme.bgTrack

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Theme.dp(3), parent.width * Math.max(0, Math.min(1, pip.charge / 100)))
            height: parent.height
            radius: Theme.dp(3)
            color: pip.charging ? Theme.accent : (pip.low ? Theme.error : Theme.success)

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeStandard
                }

            }

        }

    }

}
