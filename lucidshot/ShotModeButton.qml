import QtQuick
import qs
import qs.lucidui

// a capture mode: an icon at rest, a labelled pill once it is the one in use.
// the pill grows out of the icon on the spatial spring, so a switch reads as
// the choice moving rather than two things blinking
Item {
    id: m

    property string icon: ""
    property string label: ""
    property string tip: ""
    property bool selected: false
    property bool disabled: false
    property bool tipAbove: true
    property color activeFill: Theme.secondaryContainer
    property color activeInk: Theme.fgSecondaryContainer
    readonly property real wide: Theme.dp(16) + Theme.dp(24) + Theme.dp(8) + labelText.implicitWidth + Theme.dp(20)
    readonly property bool jellyWobbling: squish.wobbling

    signal clicked()

    implicitWidth: m.selected ? m.wide : Theme.dp(48)
    implicitHeight: Theme.dp(48)
    opacity: m.disabled ? 0.45 : 1

    Rectangle {
        id: box

        anchors.fill: parent
        radius: height / 2
        color: m.selected ? m.activeFill : Theme.alpha(m.activeFill, 0)

        StateLayer {
            id: area

            radius: box.radius
            tint: m.selected ? m.activeInk : Theme.text
            disabled: m.disabled
            onPressedChanged: squish.kick(area.pressed ? -0.1 : 0.08)
            onClicked: m.clicked()
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

    }

    Item {
        anchors.fill: parent
        clip: true

        Icon {
            id: glyph

            x: m.selected ? Theme.dp(16) : Math.round((m.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            name: m.icon
            size: Theme.dp(24)
            fill: m.selected ? 1 : 0
            color: m.selected ? m.activeInk : Theme.subtext

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

        }

        LText {
            id: labelText

            x: glyph.x + glyph.width + Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            role: "labelLarge"
            color: m.activeInk
            text: m.label
            opacity: m.selected ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: m.selected ? Theme.durDefaultEffects : Theme.durFastEffects
                }

            }

        }

    }

    ShotTip {
        text: m.selected ? "" : m.tip
        hovered: area.containsMouse && !area.pressed
        above: m.tipAbove
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durDefaultSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    transform: Jelly {
        id: squish

        target: m
        frequency: 6
    }

}
