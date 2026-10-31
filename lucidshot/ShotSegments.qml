import QtQuick
import qs
import qs.lucidui

// an m3 expressive connected button group, lucidui's ButtonGroup with room for
// a tooltip: members 2dp apart with tight inner corners, the picked one fills
// with primary and rounds right off
Row {
    id: grp

    // [{ key, icon, label, tip }]
    property var options: []
    property string current: ""
    property bool tipAbove: true
    property bool disabled: false
    readonly property int h: Theme.dp(40)
    readonly property real inner: Theme.dp(6)

    signal picked(string key)

    spacing: Theme.dp(2)
    opacity: grp.disabled ? 0.45 : 1

    Repeater {
        id: rep

        model: grp.options

        Item {
            id: seg

            required property var modelData
            required property int index
            readonly property bool on: grp.current === seg.modelData.key
            readonly property bool first: seg.index === 0
            readonly property bool last: seg.index === rep.count - 1
            readonly property real outer: grp.h / 2
            readonly property real press: area.pressed ? grp.inner * 0.6 : 0

            width: seg.modelData.label ? Math.max(Theme.dp(52), lbl.implicitWidth + Theme.dp(28)) : Theme.dp(52)
            height: grp.h

            Rectangle {
                id: box

                anchors.fill: parent
                color: seg.on ? Theme.primary : Theme.surfaceHighest
                topLeftRadius: seg.on || seg.first ? seg.outer - seg.press : grp.inner
                bottomLeftRadius: seg.on || seg.first ? seg.outer - seg.press : grp.inner
                topRightRadius: seg.on || seg.last ? seg.outer - seg.press : grp.inner
                bottomRightRadius: seg.on || seg.last ? seg.outer - seg.press : grp.inner

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

            StateLayer {
                id: area

                radius: Math.min(box.topLeftRadius, box.topRightRadius)
                tint: seg.on ? Theme.fgPrimary : Theme.text
                disabled: grp.disabled
                onClicked: grp.picked(seg.modelData.key)
            }

            Icon {
                visible: !!seg.modelData.icon
                anchors.centerIn: parent
                name: seg.modelData.icon || ""
                size: Theme.dp(22)
                fill: seg.on ? 1 : 0
                color: seg.on ? Theme.fgPrimary : Theme.subtext
            }

            LText {
                id: lbl

                anchors.centerIn: parent
                visible: !seg.modelData.icon
                text: seg.modelData.label || ""
                role: "labelLarge"
                color: seg.on ? Theme.fgPrimary : Theme.subtext
            }

            ShotTip {
                text: seg.modelData.tip || ""
                hovered: area.containsMouse && !area.pressed
                above: grp.tipAbove
            }

        }

    }

}
