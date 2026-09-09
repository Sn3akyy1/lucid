import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: gauge

    property real value: 0
    property real thickness: 8
    property color trackColor: Theme.alpha(Theme.text, 0.12)
    property color fillColor: Theme.accent
    // where the arc begins, and how much of the circle it walks
    property real startAngle: -90
    property real sweep: 360
    property real animated: gauge.value

    implicitWidth: 72
    implicitHeight: 72

    Behavior on animated {
        NumberAnimation {
            duration: Theme.ms(520)
            easing.type: Easing.OutCubic
        }

    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: gauge.trackColor
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: gauge.width / 2
                centerY: gauge.height / 2
                radiusX: (Math.min(gauge.width, gauge.height) - gauge.thickness) / 2
                radiusY: (Math.min(gauge.width, gauge.height) - gauge.thickness) / 2
                startAngle: gauge.startAngle
                sweepAngle: gauge.sweep
            }

        }

        ShapePath {
            strokeColor: gauge.fillColor
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: gauge.width / 2
                centerY: gauge.height / 2
                radiusX: (Math.min(gauge.width, gauge.height) - gauge.thickness) / 2
                radiusY: (Math.min(gauge.width, gauge.height) - gauge.thickness) / 2
                startAngle: gauge.startAngle
                sweepAngle: gauge.sweep * Math.max(0, Math.min(1, gauge.animated))
            }

        }

    }

}
