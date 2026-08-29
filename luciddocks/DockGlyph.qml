import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: glyph

    property real viewBox: 24
    property string pathData: ""
    property color glyphColor: Theme.text

    implicitWidth: 24
    implicitHeight: 24

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.glyphColor

            PathSvg {
                path: glyph.pathData
            }

        }

        transform: Scale {
            xScale: glyph.width / glyph.viewBox
            yScale: glyph.height / glyph.viewBox
        }

    }

}
