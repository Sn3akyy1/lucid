import QtQuick
import qs

// the hour over the minute, material you's own lock clock. it steps aside —
// smaller, quieter — the moment the field becomes the point of the screen
Item {
    id: clock

    property real unit: 160
    // one animated number drives both the scale and the space it gives back,
    // so the date underneath rides up with the clock instead of jumping
    property real k: Lockscreen.focused ? 0.52 : 1

    implicitWidth: Math.max(stack.implicitWidth, meta.implicitWidth)
    implicitHeight: stack.implicitHeight * clock.k + 18 + meta.implicitHeight

    Behavior on k {
        NumberAnimation {
            duration: Theme.ms(520)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Item {
        id: stack

        implicitWidth: Math.max(hour.implicitWidth, minute.implicitWidth + (ampm.visible ? ampm.implicitWidth + 12 : 0))
        implicitHeight: Math.round(clock.unit * 1.64)
        width: implicitWidth
        height: implicitHeight * clock.k
        transformOrigin: Item.TopLeft
        scale: clock.k

        Text {
            id: hour

            y: 0
            height: Math.round(clock.unit * 0.82)
            verticalAlignment: Text.AlignVCenter
            text: Lockscreen.hourText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(clock.unit)
            font.weight: Font.DemiBold
            font.letterSpacing: -Math.round(clock.unit * 0.03)
        }

        Text {
            id: minute

            y: Math.round(clock.unit * 0.82)
            height: Math.round(clock.unit * 0.82)
            verticalAlignment: Text.AlignVCenter
            text: Lockscreen.minuteText
            color: Theme.accentMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(clock.unit)
            font.weight: Font.DemiBold
            font.letterSpacing: -Math.round(clock.unit * 0.03)
        }

        Text {
            id: ampm

            anchors.left: minute.right
            anchors.leftMargin: 12
            anchors.bottom: minute.bottom
            anchors.bottomMargin: Math.round(clock.unit * 0.16)
            text: Lockscreen.meridiem
            visible: Lockscreen.meridiem !== ""
            color: Theme.alpha(Theme.accentMuted, 0.7)
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(clock.unit * 0.16)
            font.weight: Font.Medium
        }

    }

    Column {
        id: meta

        anchors.top: stack.bottom
        anchors.topMargin: 18
        spacing: 4

        Text {
            text: Lockscreen.dateText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitleLg
            font.weight: Font.Medium
        }

        Text {
            text: Lockscreen.greeting + (Lockscreen.displayName !== "" ? ", " + Lockscreen.displayName.split(" ")[0] : "")
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyLg
        }

    }

}
