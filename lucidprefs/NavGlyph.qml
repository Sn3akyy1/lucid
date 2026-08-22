import QtQuick
import qs

// Nav icons drawn from primitives rather than looked up in an icon theme -
// the same approach Network.qml's EthernetGlyph and the tray use. Three
// marks that say what they are by echoing the thing they configure: a tune
// glyph for the general page, a surface with pills along its top edge for the
// bar, and one with a row of dots along its bottom for the dock.
Item {
    id: glyph

    property string kind: "general"
    property color color: Theme.subtext

    implicitWidth: 22
    implicitHeight: 22

    // ---- general: M3's "tune" - two tracks, each with a knob ----
    Item {
        anchors.fill: parent
        visible: glyph.kind === "general"

        Rectangle {
            x: 2
            y: 6
            width: 18
            height: 2
            radius: 1
            color: glyph.color
        }

        Rectangle {
            x: 12
            y: 3.5
            width: 3.5
            height: 7
            radius: 1.75
            color: glyph.color
        }

        Rectangle {
            x: 2
            y: 14
            width: 18
            height: 2
            radius: 1
            color: glyph.color
        }

        Rectangle {
            x: 6
            y: 11.5
            width: 3.5
            height: 7
            radius: 1.75
            color: glyph.color
        }

    }

    // ---- bar: a screen with modules sitting along its top edge ----
    Item {
        anchors.fill: parent
        visible: glyph.kind === "bar"

        Rectangle {
            x: 2
            y: 3
            width: 18
            height: 16
            radius: 3
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Rectangle {
            x: 4.5
            y: 6
            width: 4.5
            height: 2.5
            radius: 1.25
            color: glyph.color
        }

        Rectangle {
            x: 10.5
            y: 6
            width: 3
            height: 2.5
            radius: 1.25
            color: glyph.color
        }

        Rectangle {
            x: 15
            y: 6
            width: 2.5
            height: 2.5
            radius: 1.25
            color: glyph.color
        }

    }

    // ---- dock: a screen with a row of icons along its bottom edge ----
    Item {
        anchors.fill: parent
        visible: glyph.kind === "dock"

        Rectangle {
            x: 2
            y: 3
            width: 18
            height: 16
            radius: 3
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Row {
            x: 5
            y: 13
            spacing: 2

            Repeater {
                model: 3

                Rectangle {
                    width: 3.3
                    height: 3.3
                    radius: 1
                    color: glyph.color
                }

            }

        }

    }

}
