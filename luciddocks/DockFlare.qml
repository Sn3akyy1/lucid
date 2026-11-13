import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: flare

    property bool mirrored: false
    // how far it sweeps out along the edge it meets
    property int size: Theme.dp(14)
    // how far up the side it reaches; shallower than size makes the curve a
    // quarter ellipse, so a short side still takes a wide sweep without a step
    property int depth: flare.size
    property color fillColor: Theme.bg

    implicitWidth: flare.size
    implicitHeight: flare.depth
    visible: flare.size > 0 && flare.depth > 0

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
                y: flare.depth
                radiusX: flare.size
                radiusY: flare.depth
                direction: PathArc.Clockwise
            }

            PathLine {
                x: flare.size
                y: flare.depth
            }

            PathLine {
                x: flare.size
                y: 0
            }

        }

    }

}
