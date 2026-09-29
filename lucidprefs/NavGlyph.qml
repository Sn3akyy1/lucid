import QtQuick
import qs
import qs.lucidui

// a page's symbol in the rail; it fills in once the page is open
Item {
    id: glyph

    property string kind: "general"
    property color color: Theme.subtext
    property bool active: false

    implicitWidth: 22
    implicitHeight: 22

    Icon {
        anchors.centerIn: parent
        name: Prefs.settingsPage(glyph.kind) ? Prefs.settingsPage(glyph.kind).icon : "settings"
        size: 22
        fill: glyph.active ? 1 : 0
        color: glyph.color
    }


    Item {
        anchors.fill: parent
        visible: glyph.kind === "keybinds"

        Rectangle {
            x: 1.5
            y: 4.5
            width: 19
            height: 13.5
            radius: 3
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Repeater {
            model: [[4.6, 7.6], [8.3, 7.6], [12, 7.6], [15.7, 7.6], [4.6, 10.8], [8.3, 10.8], [12, 10.8], [15.7, 10.8]]

            Rectangle {
                required property var modelData

                x: modelData[0]
                y: modelData[1]
                width: 1.9
                height: 1.9
                radius: 0.5
                color: glyph.color
            }

        }

        Rectangle {
            x: 7.2
            y: 14
            width: 7.6
            height: 1.6
            radius: 0.8
            color: glyph.color
        }

    }

}
