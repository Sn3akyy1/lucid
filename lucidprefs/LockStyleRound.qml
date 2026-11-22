import QtQuick
import qs
import qs.lucidui

// a round button of the lock style editor's own, that squares off under the pointer
Rectangle {
    id: rb

    property string icon: "close"
    property bool on: false
    property real size: Theme.dp(52)

    signal clicked()

    width: rb.size
    height: rb.size
    radius: rbArea.containsMouse ? Theme.shapeLg : rb.size / 2
    color: rb.on ? Theme.accent : (rbArea.containsMouse ? Theme.surfaceHighest : Theme.alpha(Theme.surfaceContainer, 0.9))
    scale: rbArea.pressed ? 0.92 : 1

    Icon {
        anchors.centerIn: parent
        name: rb.icon
        size: rb.size * 0.44
        color: rb.on ? Theme.fgAccent : Theme.text
    }

    MouseArea {
        id: rbArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rb.clicked()
    }

    Behavior on radius {
        NumberAnimation {
            duration: Theme.ms(220)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveFastSpatial
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.ms(140)
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.ms(120)
            easing.type: Easing.OutCubic
        }

    }

}
