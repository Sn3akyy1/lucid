import QtQuick
import qs
import qs.lucidui

// a toolbar button: an icon on nothing at rest. switched on it takes a tonal
// container and squares off; under a press the corners tighten and it squishes
Item {
    id: b

    property string icon: ""
    property string tip: ""
    property bool checked: false
    property bool disabled: false
    // a count or a number of seconds, in a small primary badge
    property string badge: ""
    property bool tipAbove: true
    property color onFill: Theme.secondaryContainer
    property color onInk: Theme.fgSecondaryContainer
    property color ink: Theme.subtext
    property int size: Theme.dp(48)
    // a colour shown as itself in place of the icon
    property color dot: "transparent"
    readonly property bool hovered: area.containsMouse
    readonly property bool jellyWobbling: squish.wobbling

    signal clicked()

    implicitWidth: b.size
    implicitHeight: b.size

    Rectangle {
        id: box

        anchors.fill: parent
        radius: area.pressed ? Theme.rad(12) : (b.checked ? Theme.rad(16) : height / 2)
        color: b.checked ? b.onFill : Theme.alpha(b.onFill, 0)

        StateLayer {
            id: area

            radius: box.radius
            tint: b.checked ? b.onInk : Theme.text
            disabled: b.disabled
            onPressedChanged: squish.kick(area.pressed ? -0.12 : 0.09)
            onClicked: b.clicked()
        }

        Behavior on radius {
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

    Rectangle {
        visible: b.dot.a > 0
        anchors.centerIn: parent
        width: Theme.dp(22)
        height: Theme.dp(22)
        radius: width / 2
        color: b.dot
        border.width: Theme.dp(2)
        border.color: Theme.alpha(Theme.text, 0.35)
        scale: area.pressed ? 0.88 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    Icon {
        visible: b.dot.a === 0
        anchors.centerIn: parent
        name: b.icon
        size: Theme.dp(24)
        fill: b.checked ? 1 : 0
        color: b.disabled ? Theme.alpha(Theme.text, Theme.disabledContent) : (b.checked ? b.onInk : b.ink)
        scale: area.pressed ? 0.9 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    Rectangle {
        visible: b.badge !== ""
        x: b.width - width - Theme.dp(3)
        y: Theme.dp(3)
        width: Math.max(height, badgeText.implicitWidth + Theme.dp(8))
        height: Theme.dp(16)
        radius: height / 2
        color: Theme.primary

        LText {
            id: badgeText

            anchors.centerIn: parent
            role: "labelSmall"
            tabular: true
            color: Theme.fgPrimary
            text: b.badge
        }

    }

    ShotTip {
        text: b.tip
        hovered: area.containsMouse && !area.pressed
        above: b.tipAbove
    }

    transform: Jelly {
        id: squish

        target: b
        frequency: 6.5
    }

}
