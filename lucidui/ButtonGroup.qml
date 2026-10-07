import QtQuick
import qs

// m3 expressive connected button group. members sit 2px apart with tight inner
// corners; the selected one fills and rounds fully, and squeezes under press
Item {
    id: grp

    // [{ key, label, icon }]
    property var options: []
    property var current: ""
    // "xs" | "s" | "m"
    property string size: "s"
    property bool equalWidth: true
    property bool showCheck: false

    signal picked(var key)

    readonly property int h: grp.size === "xs" ? Theme.dp(30) : (grp.size === "m" ? Theme.dp(48) : Theme.dp(36))
    readonly property int gap: Theme.dp(2)
    readonly property real inner: grp.size === "m" ? Theme.dp(8) : Theme.dp(6)

    implicitHeight: grp.h
    implicitWidth: {
        var w = 0;
        for (var i = 0; i < rep.count; i++) {
            var it = rep.itemAt(i);
            if (it)
                w += (grp.equalWidth ? grp.widest : it.natural) + (i > 0 ? grp.gap : 0);

        }
        return w;
    }

    property real widest: {
        var w = 0;
        for (var i = 0; i < rep.count; i++) {
            var it = rep.itemAt(i);
            if (it)
                w = Math.max(w, it.natural);

        }
        return w;
    }

    Row {
        id: row

        anchors.fill: parent
        spacing: grp.gap

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
                readonly property real natural: lbl.implicitWidth + (seg.modelData.icon ? Theme.dp(26) : 0) + (grp.showCheck && seg.on ? Theme.dp(22) : 0) + Theme.dp(32)
                readonly property real outer: Theme.pill(grp.h)
                readonly property real press: area.pressed ? grp.inner * 0.6 : 0

                width: grp.equalWidth ? (row.width - grp.gap * (rep.count - 1)) / Math.max(1, rep.count) : seg.natural
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
                    onClicked: grp.picked(seg.modelData.key)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Icon {
                        visible: (grp.showCheck && seg.on) || !!seg.modelData.icon
                        anchors.verticalCenter: parent.verticalCenter
                        name: grp.showCheck && seg.on ? "check" : (seg.modelData.icon || "")
                        size: grp.size === "m" ? Theme.dp(22) : Theme.dp(18)
                        fill: seg.on ? 1 : 0
                        color: seg.on ? Theme.fgPrimary : Theme.subtext
                    }

                    LText {
                        id: lbl

                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: seg.modelData.label || ""
                        role: "labelLarge"
                        color: seg.on ? Theme.fgPrimary : Theme.subtext
                    }

                }

            }

        }

    }

}
