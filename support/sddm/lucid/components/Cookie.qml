import QtQuick
import QtQuick.Shapes
import "Shapes.js" as Shapes

// one filled m3 expressive shape, lucidui's MaterialShape for a greeter
Shape {
    id: sh

    property string shape: "cookie12"
    property color color: Theme.accent
    property real spin: 0

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: sh.color
        strokeColor: "transparent"
        strokeWidth: 0

        PathSvg {
            path: Shapes.path(sh.shape, sh.width, sh.spin * Math.PI / 180)
        }

    }

}
