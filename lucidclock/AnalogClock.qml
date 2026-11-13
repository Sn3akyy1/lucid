import QtQuick
import qs
import qs.lucidui

// a clock face in material's expressive manner: a scalloped dial, round-ended
// hands, the seconds a thin hand that ticks with a little overshoot. small
// faces (a city's) drop the seconds and the marks
Item {
    id: face

    // the wall time to show: a Date whose local fields read it
    property var time: new Date()
    property bool seconds: true
    property bool marks: true
    property color dial: Theme.primaryContainer
    property color ink: Theme.fgPrimaryContainer
    property color accent: Theme.primary
    property color secondColor: Theme.tertiary
    property string shape: "cookie12"
    // the dial turns a notch with each second, as pixel's does
    property bool spinDial: false
    readonly property real d: Math.min(width, height)
    readonly property real hourDeg: (face.time.getHours() % 12) * 30 + face.time.getMinutes() * 0.5
    readonly property real minuteDeg: face.time.getMinutes() * 6 + face.time.getSeconds() * 0.1
    readonly property real secondDeg: face.time.getSeconds() * 6

    implicitWidth: Theme.dp(280)
    implicitHeight: Theme.dp(280)

    MaterialShape {
        anchors.centerIn: parent
        width: face.d
        height: face.d
        shape: face.shape
        color: face.dial
        rotation: face.spinDial ? face.secondDeg / 6 : 0

        Behavior on rotation {
            enabled: face.spinDial

            RotationAnimation {
                duration: Theme.durDefaultSpatial
                direction: RotationAnimation.Clockwise
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    // a dot an hour, the quarters a little larger
    Repeater {
        model: face.marks ? 12 : 0

        Rectangle {
            required property int index
            readonly property bool quarter: index % 3 === 0
            readonly property real r: face.d * 0.36
            readonly property real a: index * Math.PI / 6

            width: face.d * (quarter ? 0.034 : 0.022)
            height: width
            radius: width / 2
            x: face.width / 2 + r * Math.sin(a) - width / 2
            y: face.height / 2 - r * Math.cos(a) - height / 2
            color: Theme.alpha(face.ink, quarter ? 0.7 : 0.4)
        }

    }

    Hand {
        length: face.d * 0.25
        thickness: face.d * 0.075
        color: face.ink
        angle: face.hourDeg
    }

    Hand {
        length: face.d * 0.36
        thickness: face.d * 0.05
        color: face.accent
        angle: face.minuteDeg
    }

    Item {
        id: second

        visible: face.seconds
        anchors.fill: parent
        rotation: face.secondDeg

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - face.d * 0.4
            width: Math.max(1, face.d * 0.012)
            height: face.d * 0.46
            radius: width / 2
            color: face.secondColor
        }

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - face.d * 0.4 - width / 2
            width: face.d * 0.04
            height: width
            radius: width / 2
            color: face.secondColor
        }

        Behavior on rotation {
            RotationAnimation {
                duration: 260
                direction: RotationAnimation.Clockwise
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }

        }

    }

    Rectangle {
        anchors.centerIn: parent
        width: face.d * (face.seconds ? 0.07 : 0.09)
        height: width
        radius: width / 2
        color: face.seconds ? face.secondColor : face.accent
    }

    component Hand: Item {
        id: hand

        property real length: 10
        property real thickness: 4
        property color color: "white"
        property real angle: 0

        anchors.fill: parent
        rotation: hand.angle

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - hand.length
            width: hand.thickness
            height: hand.length + hand.thickness / 2
            radius: width / 2
            color: hand.color
        }

        Behavior on rotation {
            RotationAnimation {
                duration: Theme.durShort
                direction: RotationAnimation.Shortest
            }

        }

    }

}
