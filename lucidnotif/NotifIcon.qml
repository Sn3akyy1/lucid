import QtQuick
import qs
import qs.lucidui

// one material symbol by name
Item {
    id: glyph

    property string path: ""
    property int size: 20
    property color color: Theme.text
    property real fill: 0

    implicitWidth: glyph.size
    implicitHeight: glyph.size

    Icon {
        anchors.centerIn: parent
        name: glyph.path
        size: Math.round(glyph.size * 1.1)
        fill: glyph.fill
        color: glyph.color
    }

}
