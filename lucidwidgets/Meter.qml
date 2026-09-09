import QtQuick
import qs

Item {
    id: meter

    property real value: 0
    property color fillColor: Theme.accent
    property color trackColor: Theme.alpha(Theme.text, 0.12)
    property real thickness: 8
    property real animated: meter.value

    implicitHeight: meter.thickness
    implicitWidth: 120

    Behavior on animated {
        NumberAnimation {
            duration: Theme.ms(520)
            easing.type: Easing.OutCubic
        }

    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: meter.thickness
        radius: height / 2
        color: meter.trackColor
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(meter.thickness, parent.width * Math.max(0, Math.min(1, meter.animated)))
        height: meter.thickness
        radius: height / 2
        color: meter.fillColor
    }

}
