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
    // breathing room either side of a segment's check and label
    property int padding: 16
    readonly property real _gaps: seg.gap * Math.max(0, seg.options.length - 1)
    readonly property real _widest: {
        var w = 0;
        for (var i = 0; i < row.children.length; i++) {
            var c = row.children[i];
            if (c.content !== undefined)
                w = Math.max(w, c.content);

        }
        return w;
    }
    readonly property real _contentSum: {
        var s = 0;
        for (var i = 0; i < row.children.length; i++) {
            var c = row.children[i];
            if (c.content !== undefined)
                s += c.content;

        }
        return s;
    }
    // narrowest width that keeps every segment padded at equal widths
    readonly property real fitWidth: (Math.ceil(seg._widest) + seg.padding * 2) * seg.options.length + seg._gaps

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
                // check and label at selected weight, so a pick never shifts widths
                readonly property real content: 18 + 6 + probe.implicitWidth

                // equal widths when they fit; too tight, each sizes to its label
                // and the spare room is shared out as padding
                width: seg.options.length === 0 ? 0 : seg.width >= seg.fitWidth ? (seg.width - seg._gaps) / seg.options.length : cell.content + (seg.width - seg._gaps - seg._contentSum) / seg.options.length
                height: seg.height

                LText {
                    id: probe

                    visible: false
                    role: "labelLarge"
                    weight: 620
                    text: cell.modelData.label
                }

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
