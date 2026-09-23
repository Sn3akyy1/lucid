import QtQuick
import QtQuick.Shapes
import qs
import qs.lucidui

// a material symbol when handed a name, else raw 24dp svg path data
Item {
    id: glyph

    property real viewBox: 24
    property string pathData: ""
    property color glyphColor: Theme.text
    property real fill: 0
    readonly property bool named: /^[a-z0-9_]+$/.test(glyph.pathData)

    implicitWidth: 24
    implicitHeight: 24

    Icon {
        visible: glyph.named
        anchors.centerIn: parent
        name: glyph.named ? glyph.pathData : ""
        size: Math.round(Math.min(glyph.width, glyph.height) * 1.08)
        fill: glyph.fill
        color: glyph.glyphColor
    }

    Shape {
        visible: !glyph.named
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.glyphColor

            PathSvg {
                path: glyph.named ? "" : glyph.pathData
            }

        }

        transform: Scale {
            xScale: glyph.width / glyph.viewBox
            yScale: glyph.height / glyph.viewBox
        }

    }

}
