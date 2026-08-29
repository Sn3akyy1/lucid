import QtQuick
import qs

Item {
    id: glyph

    property string kind: "general"
    property color color: Theme.subtext

    implicitWidth: 22
    implicitHeight: 22

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
