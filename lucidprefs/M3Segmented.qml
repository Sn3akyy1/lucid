import QtQuick
import qs
import qs.lucidui

// m3 expressive connected button group: segments 2px apart, full-shape on the
// group's outer edges, and the selected one filled with the primary colour
Item {
    id: seg

    // fills the unselected segments
    property color trackColor: Theme.surfaceHighest
    // [{ "key": "island", "label": "Islands" }, ...]
    property var options: []
    // driven by its binding, never self-assigned. var, not string: a numeric
    // key coerces to "0" and then never matches its own option
    property var current: ""
    property bool enabled: true
    property int gap: 2

    signal chosen(var key)

    implicitHeight: 40
    implicitWidth: 240
    opacity: seg.enabled ? 1 : Theme.disabledContent

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
                readonly property real inner: cell.selected ? seg.height / 2 : Theme.shapeSm
                readonly property real squeeze: area.pressed ? 4 : 0

                width: seg.options.length > 0 ? (seg.width - seg.gap * (seg.options.length - 1)) / seg.options.length : 0
                height: seg.height

                Rectangle {
                    id: box

                    anchors.fill: parent
                    topLeftRadius: (cell.isFirst ? cell.outer : cell.inner) - cell.squeeze
                    bottomLeftRadius: (cell.isFirst ? cell.outer : cell.inner) - cell.squeeze
                    topRightRadius: (cell.isLast ? cell.outer : cell.inner) - cell.squeeze
                    bottomRightRadius: (cell.isLast ? cell.outer : cell.inner) - cell.squeeze
                    color: cell.selected ? Theme.primary : seg.trackColor

                    Behavior on topLeftRadius {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                    Behavior on bottomLeftRadius {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                    Behavior on topRightRadius {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                    Behavior on bottomRightRadius {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durDefaultEffects
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
                        clip: true

                        Icon {
                            anchors.centerIn: parent
                            name: "check"
                            size: 18
                            weight: 600
                            color: Theme.fgPrimary
                            opacity: cell.selected ? 1 : 0
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        weight: cell.selected ? 620 : 520
                        text: cell.modelData.label
                        color: cell.selected ? Theme.fgPrimary : Theme.subtext
                    }

                }

                StateLayer {
                    id: area

                    radius: Math.min(box.topLeftRadius, box.topRightRadius)
                    tint: cell.selected ? Theme.fgPrimary : Theme.text
                    disabled: !seg.enabled
                    onClicked: {
                        if (!cell.selected)
                            seg.chosen(cell.modelData.key);

                    }
                }

            }

        }

    }

}
