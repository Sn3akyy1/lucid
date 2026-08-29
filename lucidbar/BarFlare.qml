import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: flare

    property bool mirrored: false
    property int size: 14
    property color fillColor: Theme.bg
    property bool hovered: false

    property real tint: flare.hovered ? 0.08 : 0

    Behavior on tint {
        NumberAnimation {
            duration: Theme.barMs(150)
            easing.type: Easing.OutCubic
        }

    }

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
            fillColor: Qt.tint(flare.fillColor, Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, flare.tint))
            startX: flare.size
            startY: flare.size

            PathArc {
                x: 0
                y: 0
                radiusX: flare.size
                radiusY: flare.size
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: flare.size
                y: 0
            }

            PathLine {
                x: flare.size
                y: flare.size
            }

        }

    }

}
