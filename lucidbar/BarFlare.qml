import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: flare

    property bool mirrored: false
    // upside down, for an edge below it
    property bool flipped: false
    // how far it sweeps out along the edge it meets
    property int size: Theme.dp(14)
    // how far down the side it reaches; shallower than size makes the curve a
    // quarter ellipse, so a short side still takes a wide sweep without a step
    property int depth: flare.size
    property color fillColor: Theme.bg
    property bool hovered: false

    // a wash over the fill, as the module's own hover lays one over its body
    property real tint: flare.hovered ? Theme.stateHover : 0

    Behavior on tint {
        NumberAnimation {
            duration: Theme.barMs(150)
            easing.type: Easing.OutCubic
        }

    }

    implicitWidth: flare.size
    implicitHeight: flare.depth
    visible: flare.size > 0 && flare.depth > 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        transform: Scale {
            xScale: flare.mirrored ? -1 : 1
            yScale: flare.flipped ? -1 : 1
            origin.x: flare.width / 2
            origin.y: flare.height / 2
        }

        ShapePath {
            strokeWidth: 0
            fillColor: flare.fillColor
            startX: flare.size
            startY: flare.depth

            PathArc {
                x: 0
                y: 0
                radiusX: flare.size
                radiusY: flare.depth
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: flare.size
                y: 0
            }

            PathLine {
                x: flare.size
                y: flare.depth
            }

        }

        ShapePath {
            strokeWidth: 0
            fillColor: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, flare.tint)
            startX: flare.size
            startY: flare.depth

            PathArc {
                x: 0
                y: 0
                radiusX: flare.size
                radiusY: flare.depth
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: flare.size
                y: 0
            }

            PathLine {
                x: flare.size
                y: flare.depth
            }

        }

    }

}
