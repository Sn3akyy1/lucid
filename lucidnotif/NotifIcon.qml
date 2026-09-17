import QtQuick
import QtQuick.Shapes
import qs

// one material symbol, authored on a 24dp grid
Item {
    id: glyph

    property string path: ""
    property int size: 20
    property color color: Theme.text

    implicitWidth: glyph.size
    implicitHeight: glyph.size

    Shape {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: glyph.size / 24
        visible: glyph.path !== ""
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: glyph.color
            strokeWidth: 0

            PathSvg {
                path: glyph.path
            }

        }

    }

}
