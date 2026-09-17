import QtQuick
import QtQuick.Shapes
import qs

// m3 indeterminate circular progress: an arc that breathes while it spins
Item {
    id: spin

    property real diameter: 22
    property real thickness: 2.5
    property color color: Theme.fgAccent
    property bool running: true

    implicitWidth: Math.round(spin.diameter)
    implicitHeight: Math.round(spin.diameter)
    visible: spin.running

    Shape {
        id: ring

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // the head runs ahead of the tail, so the arc grows and shrinks as it turns
        property real sweep: 30

        ShapePath {
            strokeColor: spin.color
            strokeWidth: spin.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: spin.width / 2
                centerY: spin.height / 2
                radiusX: (spin.width - spin.thickness) / 2
                radiusY: (spin.height - spin.thickness) / 2
                startAngle: -90
                sweepAngle: ring.sweep
            }

        }

        SequentialAnimation on sweep {
            running: spin.running
            loops: Animation.Infinite

            NumberAnimation {
                to: 300
                duration: 700
                easing.type: Easing.InOutCubic
            }

            NumberAnimation {
                to: 30
                duration: 700
                easing.type: Easing.InOutCubic
            }

        }

        RotationAnimator on rotation {
            running: spin.running
            from: 0
            to: 360
            duration: 1400
            loops: Animation.Infinite
        }

    }

}
