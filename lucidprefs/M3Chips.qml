import QtQuick
import qs

// m3 filter chips, wrapping. options are { key, label, note } and the track
// colours match M3Segmented so a page can mix the two
Flow {
    id: chips

    property var options: []
    property var current: ""
    property bool enabled: true
    // a lone chip is worth showing as the current value even when there is
    // nothing else to pick, so this gates the click without dimming it
    property bool interactive: true

    signal chosen(var key)

    spacing: 8

    Repeater {
        model: chips.options

        Rectangle {
            id: chip

            required property var modelData
            readonly property bool selected: chips.current === chip.modelData.key

            width: label.implicitWidth + 30
            height: 36
            radius: Theme.shapeFull
            color: chip.selected ? Theme.accentContainer : Theme.bgSunken
            opacity: chips.enabled ? 1 : 0.38

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.text
                opacity: !chips.enabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            Text {
                id: label

                anchors.centerIn: parent
                text: chip.modelData.label
                color: chip.selected ? Theme.fgAccentContainer : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: chip.selected ? Font.DemiBold : Font.Medium
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: chips.enabled && chips.interactive
                enabled: chips.enabled && chips.interactive
                cursorShape: Qt.PointingHandCursor
                onClicked: chips.chosen(chip.modelData.key)
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

}
