import QtQuick
import QtQuick.Shapes
import "blob.js" as Blob

// one filled shape from the m3 expressive library. `to` and `morph` ease it
// toward another, `spin` turns it in degrees
Shape {
    id: blob

    property string shape: "cookie12"
    property string to: ""
    property real morph: 0
    property real spin: 0
    property color color: "white"

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: blob.color
        strokeColor: "transparent"
        strokeWidth: 0

        PathSvg {
            path: blob.width <= 0 || blob.height <= 0 ? "" : (blob.to !== "" && blob.morph > 0 ? Blob.svg(Blob.mix(Blob.radii(blob.shape), Blob.radii(blob.to), blob.morph), blob.width, blob.height, blob.spin * Math.PI / 180) : Blob.path(blob.shape, blob.width, blob.height, blob.spin * Math.PI / 180))
        }

    }

}
