import QtQuick
import qs

// m3 expressive connected button group: separate segments with a hairline gap,
// full-shape on the group's outer edges, and the selected one filled tonally
Item {
    id: seg

    // fills the unselected segments; there is no continuous track any more
    property color trackColor: Theme.bgSunken
    // [{ "key": "island", "label": "Islands" }, ...]
    property var options: []
    // driven by its binding, never self-assigned
    property string current: ""
    property bool enabled: true
    property int gap: 2

    signal chosen(string key)

    implicitHeight: 40
    implicitWidth: 240
    opacity: seg.enabled ? 1 : 0.38

    Row {
        id: row

        anchors.fill: parent
        spacing: seg.gap

        Repeater {
            model: seg.options

            Item {
                id: cell

                required property int index
                required property var modelData
                readonly property bool selected: seg.current === cell.modelData.key
                readonly property bool isFirst: cell.index === 0
                readonly property bool isLast: cell.index === seg.options.length - 1
                readonly property real outer: seg.height / 2
                readonly property real inner: cell.selected ? Theme.shapeMd : Theme.shapeXs

                width: seg.options.length > 0 ? (seg.width - seg.gap * (seg.options.length - 1)) / seg.options.length : 0
                height: seg.height

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: cell.isFirst ? cell.outer : cell.inner
                    bottomLeftRadius: cell.isFirst ? cell.outer : cell.inner
                    topRightRadius: cell.isLast ? cell.outer : cell.inner
                    bottomRightRadius: cell.isLast ? cell.outer : cell.inner
                    color: cell.selected ? Theme.accentContainer : seg.trackColor

                    Rectangle {
                        anchors.fill: parent
                        topLeftRadius: parent.topLeftRadius
                        bottomLeftRadius: parent.bottomLeftRadius
                        topRightRadius: parent.topRightRadius
                        bottomRightRadius: parent.bottomRightRadius
                        color: Theme.text
                        opacity: !seg.enabled ? 0 : (cellArea.pressed ? Theme.statePressed : (cellArea.containsMouse ? Theme.stateHover : 0))

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                    Behavior on topLeftRadius {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Theme.easeStandard
                        }

                    }

                    Behavior on topRightRadius {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Theme.easeStandard
                        }

                    }

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

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durMedium
                                easing.type: Theme.easeEmphasized
                                easing.overshoot: Theme.emphasizedOvershoot
                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cell.modelData.label
                        color: cell.selected ? Theme.text : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                        font.weight: cell.selected ? Font.DemiBold : Font.Medium

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

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

}
