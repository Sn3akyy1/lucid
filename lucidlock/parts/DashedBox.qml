import QtQuick
import QtQuick.Shapes

// a dashed rounded outline, for the editor's empty slots and stand-ins
Shape {
    id: box

    property color color: "white"
    property real line: 1.5
    property real radius: 12
    property real dash: 4

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: box.color
        strokeWidth: box.line
        fillColor: "transparent"
        strokeStyle: ShapePath.DashLine
        dashPattern: [box.dash, box.dash * 0.8]
        capStyle: ShapePath.RoundCap
        startX: box.radius
        startY: box.line / 2

        PathLine {
            x: box.width - box.radius
            y: box.line / 2
        }

        PathArc {
            x: box.width - box.line / 2
            y: box.radius
            radiusX: box.radius - box.line / 2
            radiusY: box.radius - box.line / 2
        }

        PathLine {
            x: box.width - box.line / 2
            y: box.height - box.radius
        }

        PathArc {
            x: box.width - box.radius
            y: box.height - box.line / 2
            radiusX: box.radius - box.line / 2
            radiusY: box.radius - box.line / 2
        }

        PathLine {
            x: box.radius
            y: box.height - box.line / 2
        }

        PathArc {
            x: box.line / 2
            y: box.height - box.radius
            radiusX: box.radius - box.line / 2
            radiusY: box.radius - box.line / 2
        }

        PathLine {
            x: box.line / 2
            y: box.radius
        }

        PathArc {
            x: box.radius
            y: box.line / 2
            radiusX: box.radius - box.line / 2
            radiusY: box.radius - box.line / 2
        }

    }

}
