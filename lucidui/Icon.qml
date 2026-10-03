import QtQuick
import QtQuick.Shapes
import qs
import "SymbolPaths.js" as Symbols

// a material symbol by name, drawn from google's own svg paths. fill runs 0..1
// and eases, so a state change reads as the outline filling in
Item {
    id: icon

    property string name: ""
    property real size: 20
    property real fill: 0
    property color color: Theme.text
    property bool animateFill: true
    // off where the colour is already driven frame by frame
    property bool animateColor: true
    // kept so older callers still parse; the svgs come in one weight
    property real weight: 400
    property real grade: 0
    property real _fill: Math.max(0, Math.min(1, icon.fill))
    readonly property var paths: Symbols.p[icon.name] || null

    implicitWidth: icon.size
    implicitHeight: icon.size
    width: icon.size
    height: icon.size

    Behavior on _fill {
        enabled: icon.animateFill

        NumberAnimation {
            duration: Theme.durDefaultEffects
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEffects
        }

    }

    Behavior on color {
        enabled: icon.animateColor

        ColorAnimation {
            duration: Theme.durFastEffects
        }

    }

    Shape {
        visible: icon.paths !== null
        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            xScale: icon.width / 24
            yScale: icon.height / 24
        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: icon._fill >= 0.999 ? "transparent" : Qt.rgba(icon.color.r, icon.color.g, icon.color.b, icon.color.a * (1 - icon._fill))

            PathSvg {
                path: icon.paths ? icon.paths[0] : ""
            }

        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: icon._fill <= 0.001 ? "transparent" : Qt.rgba(icon.color.r, icon.color.g, icon.color.b, icon.color.a * icon._fill)

            PathSvg {
                path: icon.paths && icon._fill > 0.001 ? icon.paths[1] : ""
            }

        }

    }

}
