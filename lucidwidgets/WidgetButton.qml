import QtQuick
import qs

Item {
    id: btn

    property string icon: "close"
    property real diameter: 28
    property real iconSize: 16
    property color iconColor: Theme.subtext
    property color activeColor: Theme.accent
    property bool active: false
    property bool filled: false
    // the bar's IconBtn look: a surface circle behind the glyph, and it grows on hover
    property bool surface: false
    // overridable so a button sitting on artwork can go white-on-scrim
    property color surfaceColor: Theme.withBlur(Theme.bgHigh)
    property color stateColor: btn.filled ? Theme.fgAccent : Theme.text
    property bool hoverGrow: false
    property bool enabled: true
    property string tip: ""
    readonly property bool hovered: area.containsMouse && btn.enabled

    signal clicked()

    implicitWidth: btn.diameter
    implicitHeight: btn.diameter
    opacity: btn.enabled ? 1 : 0.35
    scale: area.pressed && btn.enabled ? 0.9 : (btn.hoverGrow && btn.hovered ? 1.07 : 1)

    Rectangle {
        anchors.fill: parent
        radius: Theme.pill(width)
        color: btn.filled ? Theme.accent : (btn.active ? Theme.alpha(btn.activeColor, 0.18) : (btn.surface ? btn.surfaceColor : "transparent"))

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.pill(width)
        color: btn.stateColor
        opacity: !btn.enabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

    WidgetGlyph {
        anchors.centerIn: parent
        name: btn.icon
        size: btn.iconSize
        color: btn.filled ? Theme.fgAccent : (btn.active ? btn.activeColor : btn.iconColor)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: btn.clicked()
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durQuick
            easing.type: Theme.easeStandard
        }

    }

}
