import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: flare

    property bool mirrored: false
    property int size: 14
    property color fillColor: Theme.bg

    implicitWidth: flare.size
    implicitHeight: flare.size
    visible: flare.size > 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        transform: Scale {
            xScale: flare.mirrored ? -1 : 1
            origin.x: flare.width / 2
        }

        ShapePath {
            strokeWidth: 0
            fillColor: flare.fillColor
            startX: flare.size
            startY: 0

            PathArc {
                x: 0
                y: flare.size
                radiusX: flare.size
                radiusY: flare.size
                direction: PathArc.Clockwise
            }

            PathLine {
                x: flare.size
                y: flare.size
            }

            PathLine {
                x: flare.size
                y: 0
            }

        }

    }

}


