import QtQuick
import qs

// m3 switch: the thumb grows when on and again under press, and carries a check
Item {
    id: sw

    property bool checked: false
    property bool disabled: false
    property bool icons: true

    signal toggled(bool value)

    implicitWidth: Theme.dp(48)
    implicitHeight: Theme.dp(28)
    opacity: sw.disabled ? Theme.disabledContent : 1

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.primary : Theme.bgSunken
        border.width: sw.checked ? 0 : 2
        border.color: Theme.outlineStrong

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

    }

    Rectangle {
        id: thumb

        property real d: area.pressed && !sw.disabled ? Theme.dp(26) : (sw.checked || sw.icons ? Theme.dp(22) : Theme.dp(14))
        // the travel eases on its own; an eased x that also followed the easing
        // size restarted every frame and sat still until the size had settled
        property real pos: sw.checked ? 1 : 0

        width: thumb.d
        height: thumb.d
        radius: thumb.d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.dp(3) + (Theme.dp(22) - thumb.d) / 2 + thumb.pos * (sw.width - Theme.dp(28))
        color: sw.checked ? Theme.fgPrimary : Theme.outlineStrong

        Behavior on pos {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Behavior on d {
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

        Rectangle {
            anchors.centerIn: parent
            width: Theme.dp(38)
            height: Theme.dp(38)
            radius: Theme.dp(19)
            color: sw.checked ? Theme.primary : Theme.text
            opacity: sw.disabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))
        }

        Icon {
            anchors.centerIn: parent
            visible: sw.icons
            name: sw.checked ? "check" : "close"
            size: Theme.dp(15)
            weight: 600
            color: sw.checked ? Theme.fgPrimaryContainer : Theme.surfaceHighest
            opacity: sw.checked ? 1 : 0.9
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -Theme.dp(4)
        hoverEnabled: true
        enabled: !sw.disabled
        cursorShape: Qt.PointingHandCursor
        // the caller owns `checked`; assigning it here would cut their binding
        onClicked: sw.toggled(!sw.checked)
    }

}
