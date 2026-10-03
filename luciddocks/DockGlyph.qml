import QtQuick
import qs
import qs.lucidui

// a material symbol, by name
Item {
    id: glyph

    property string pathData: ""
    property color glyphColor: Theme.text
    property real fill: 0
    property bool animateColor: true

    implicitWidth: 24
    implicitHeight: 24

    Icon {
        anchors.centerIn: parent
        name: glyph.pathData
        size: Math.round(Math.min(glyph.width, glyph.height) * 1.08)
        fill: glyph.fill
        color: glyph.glyphColor
        animateColor: glyph.animateColor
    }

}
