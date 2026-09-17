import QtQuick
import qs

// m3 linear progress: active track, gap, remaining track, stop indicator
Item {
    id: bar

    property real value: 0
    property color color: Theme.accent
    readonly property real frac: Math.max(0, Math.min(1, bar.value / 100))
    readonly property int gap: 4
    readonly property int dot: 4

    implicitHeight: 4

    Rectangle {
        id: active

        height: parent.height
        width: Math.max(0, bar.frac * (bar.width - bar.dot - bar.gap))
        radius: height / 2
        color: bar.color

        Behavior on width {
            NumberAnimation {
                duration: Theme.ms(320)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

    Rectangle {
        height: parent.height
        anchors.left: active.right
        anchors.leftMargin: bar.gap
        anchors.right: parent.right
        anchors.rightMargin: bar.dot + bar.gap
        radius: height / 2
        color: Theme.bgHigh
        visible: width > 0
    }

    Rectangle {
        width: bar.dot
        height: bar.dot
        radius: width / 2
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: bar.color
    }

}
