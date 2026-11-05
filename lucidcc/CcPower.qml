import QtQuick
import Quickshell.Services.UPower
import qs
import qs.lucidui

// the power profile, picked in one tap: saver, balanced and, where the
// machine has it, performance. its looks: a connected button group under the
// one in use and what it does (buttons); the group alone, icons only (icons);
// one row each with what it does (list)
Item {
    id: pc

    // buttons, icons or list
    property string look: "buttons"

    readonly property var profiles: Power.available
    readonly property bool listed: pc.look === "list"
    readonly property bool bare: pc.look === "icons"
    // names fit in the buttons once each has room for one
    readonly property bool named: !pc.bare && (pc.width - Theme.dp(4) * (pc.profiles.length - 1)) / Math.max(1, pc.profiles.length) >= Theme.dp(92)
    readonly property real head: pc.bare || pc.listed ? 0 : Theme.dp(26)
    // on a taller block it keeps to the middle
    readonly property real drop: Math.max(0, Math.round((pc.height - pc.implicitHeight) / 2))

    implicitHeight: pc.listed ? pc.profiles.length * Theme.dp(48) + Math.max(0, pc.profiles.length - 1) * Theme.dp(4) : pc.head + Theme.dp(48)

    // the one in use, and what it does
    Item {
        visible: pc.head > 0
        y: pc.drop
        width: parent.width
        height: pc.head

        LText {
            id: modeName

            y: Math.round((pc.head - Theme.dp(8) - height) / 2)
            role: "titleSmall"
            weight: 600
            text: Power.name(Power.profile)
        }

        LText {
            x: modeName.width + Theme.dp(8)
            y: modeName.y + modeName.baselineOffset - baselineOffset
            width: Math.max(0, parent.width - x)
            role: "bodySmall"
            color: Theme.subtext
            elide: Text.ElideRight
            text: Power.degradation !== "" && Power.profile === PowerProfile.Performance ? "Held back" : Power.description(Power.profile)
        }

    }

    // a connected group, as lucidui's ButtonGroup draws one but on the panel's
    // glass: the outer ends round, the inner corners tight, the one in use a pill
    Row {
        visible: !pc.listed
        y: pc.drop + pc.head
        width: parent.width
        spacing: Theme.dp(4)

        Repeater {
            model: pc.profiles

            Rectangle {
                id: seg

                required property int modelData
                required property int index
                readonly property bool on: Power.profile === seg.modelData
                readonly property real outer: Theme.pill(height)
                property real lead: seg.on || seg.index === 0 ? seg.outer : Theme.dp(8)
                property real tail: seg.on || seg.index === pc.profiles.length - 1 ? seg.outer : Theme.dp(8)

                width: (parent.width - parent.spacing * (pc.profiles.length - 1)) / Math.max(1, pc.profiles.length)
                height: Theme.dp(48)
                topLeftRadius: seg.lead
                bottomLeftRadius: seg.lead
                topRightRadius: seg.tail
                bottomRightRadius: seg.tail
                color: seg.on ? Theme.primary : Theme.withBlur(Theme.surfaceHighest)

                Behavior on lead {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

                Behavior on tail {
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

                StateLayer {
                    radius: Math.min(seg.lead, seg.tail)
                    tint: seg.on ? Theme.fgPrimary : Theme.text
                    onClicked: Power.set(seg.modelData)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Power.symbol(seg.modelData)
                        size: Theme.dp(20)
                        fill: seg.on ? 1 : 0
                        color: seg.on ? Theme.fgPrimary : Theme.text
                    }

                    LText {
                        visible: pc.named
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        color: seg.on ? Theme.fgPrimary : Theme.text
                        text: seg.modelData === PowerProfile.PowerSaver ? "Saver" : Power.name(seg.modelData)
                    }

                }

            }

        }

    }

    // a row each: its icon, name and what it does, the one in use filled
    Column {
        visible: pc.listed
        y: pc.drop
        width: parent.width
        spacing: Theme.dp(4)

        Repeater {
            model: pc.listed ? pc.profiles : []

            Rectangle {
                id: prof

                required property int modelData
                readonly property bool on: Power.profile === prof.modelData

                width: parent.width
                height: Theme.dp(48)
                radius: prof.on ? height / 2 : Theme.shapeMd
                color: prof.on ? Theme.withBlur(Theme.primaryContainer) : "transparent"

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durDefaultSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

                StateLayer {
                    radius: prof.radius
                    tint: prof.on ? Theme.fgPrimaryContainer : Theme.text
                    onClicked: Power.set(prof.modelData)
                }

                Icon {
                    id: itemIcon

                    x: Theme.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    name: Power.symbol(prof.modelData)
                    size: Theme.dp(20)
                    fill: prof.on ? 1 : 0
                    color: prof.on ? Theme.fgPrimaryContainer : Theme.subtext
                }

                Column {
                    x: itemIcon.x + itemIcon.width + Theme.dp(12)
                    width: parent.width - x - Theme.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -Theme.dp(1)

                    LText {
                        role: "labelLarge"
                        color: prof.on ? Theme.fgPrimaryContainer : Theme.text
                        text: Power.name(prof.modelData)
                    }

                    LText {
                        width: parent.width
                        role: "bodySmall"
                        color: prof.on ? Theme.alpha(Theme.fgPrimaryContainer, 0.78) : Theme.subtext
                        elide: Text.ElideRight
                        text: Power.description(prof.modelData)
                    }

                }

            }

        }

    }

}
