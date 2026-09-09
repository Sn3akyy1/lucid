import QtQuick
import qs

Row {
    id: pip

    property int charge: -1
    property bool charging: false

    readonly property bool low: pip.charge >= 0 && pip.charge < 20 && !pip.charging

    visible: pip.charge >= 0
    spacing: 6

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: pip.charge + "%" + (pip.charging ? " ⚡" : "")
        color: pip.low ? Theme.error : Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 6
        radius: 3
        color: Theme.bgTrack

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(3, parent.width * Math.max(0, Math.min(1, pip.charge / 100)))
            height: parent.height
            radius: 3
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
