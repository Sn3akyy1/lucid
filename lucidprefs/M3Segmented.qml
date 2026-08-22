import QtQuick
import qs

// Segmented button: a rounded track split into equal segments, the selected
// one filled with the accent container and carrying a check glyph. The track
// itself is sunk a step below the card it sits on, which is what separates the
// two halves - there is no outline, so the contrast between the filled half
// and the sunken one is doing all the work.
//
// Used for the either/or shape choices (islands vs notches) where a switch
// would force one option to be the unlabelled "off" state - both options here
// are real, named choices and deserve to be shown as such.
Item {
    id: seg

    // [{ "key": "island", "label": "Islands" }, ...]
    property var options: []
    // driven by its binding, never self-assigned - see the note in M3Switch
    property string current: ""
    property bool enabled: true

    signal chosen(string key)

    implicitHeight: 40
    implicitWidth: 240
    opacity: seg.enabled ? 1 : 0.38

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.bgSunken
    }

    Row {
        id: row

        anchors.fill: parent

        Repeater {
            model: seg.options

            Item {
                id: cell

                required property int index
                required property var modelData

                readonly property bool selected: seg.current === cell.modelData.key
                readonly property bool isFirst: cell.index === 0
                readonly property bool isLast: cell.index === seg.options.length - 1

                width: seg.options.length > 0 ? seg.width / seg.options.length : 0
                height: seg.height

                // Sits flush against the track - with the outline gone there
                // is no border to inset away from. Unselected stays
                // transparent so the track's own darker fill shows through,
                // rather than painting a second copy of it that would square
                // off the rounded ends.
                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: cell.isFirst ? seg.height / 2 : 0
                    bottomLeftRadius: cell.isFirst ? seg.height / 2 : 0
                    topRightRadius: cell.isLast ? seg.height / 2 : 0
                    bottomRightRadius: cell.isLast ? seg.height / 2 : 0
                    color: cell.selected ? Theme.accentContainer : (cellArea.containsMouse ? Theme.bgHover : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

                // divider on the leading edge, hidden whenever either side of
                // it is filled - M3 drops the divider next to a selected
                // segment rather than drawing a line through the fill
                Rectangle {
                    width: 1
                    height: parent.height
                    visible: !cell.isFirst && !cell.selected && !(cell.index > 0 && seg.current === seg.options[cell.index - 1].key)
                    color: Theme.outlineStrong
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Item {
                        width: cell.selected ? 18 : 0
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: cell.selected ? 1 : 0
                        clip: true

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Theme.easeStandard
                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Rectangle {
                            x: 3
                            y: 9
                            width: 6
                            height: 2
                            radius: 1
                            rotation: 45
                            transformOrigin: Item.Left
                            color: Theme.text
                        }

                        Rectangle {
                            x: 5.8
                            y: 12
                            width: 9
                            height: 2
                            radius: 1
                            rotation: -45
                            transformOrigin: Item.Left
                            color: Theme.text
                        }

                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cell.modelData.label
                        color: cell.selected ? Theme.text : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.bold: cell.selected

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                }

                MouseArea {
                    id: cellArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: seg.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.chosen(cell.modelData.key)
                }

            }

        }

    }

}
