import QtQuick
import QtQuick.Shapes
import qs
import "Shapes.js" as Shapes

// one shape from the m3 expressive library, filled. `morph` eases it toward `to`
Shape {
    id: ms

    property string shape: "circle"
    property string to: ""
    property real morph: 0
    property color color: Theme.primary
    property real spin: 0

    width: 48
    height: 48
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: ms.color
        strokeColor: "transparent"
        strokeWidth: 0

        PathSvg {
            path: ms.to !== "" && ms.morph > 0 ? Shapes.svg(Shapes.mix(Shapes.radii(ms.shape), Shapes.radii(ms.to), ms.morph), ms.width, ms.spin * Math.PI / 180) : Shapes.path(ms.shape, ms.width, ms.spin * Math.PI / 180)
        }

    }

}
