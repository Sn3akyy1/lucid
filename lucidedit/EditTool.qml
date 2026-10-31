import QtQuick
import qs
import qs.lucidui

// one of edit mode's toolbar buttons: a glyph and a word, lit while its sheet is open
Item {
    id: tool

    property string icon: ""
    property string text: ""
    property bool selected: false
    property bool disabled: false
    // the way out, filled in the accent
    property bool filled: false
    readonly property color ink: tool.disabled ? Theme.alpha(Theme.text, Theme.disabledContent) : (tool.filled ? Theme.fgAccent : (tool.selected ? Theme.accent : Theme.text))

    signal clicked()

    implicitWidth: row.implicitWidth + Theme.dp(16) * 2
    implicitHeight: Theme.dp(40)

    Rectangle {
        id: box

        anchors.fill: parent
        radius: area.pressed && !tool.disabled ? Theme.rad(10) : height / 2
        color: tool.filled ? (tool.disabled ? Theme.alpha(Theme.text, Theme.disabledContainer) : Theme.accent) : (tool.selected ? Theme.alpha(Theme.accent, 0.16) : "transparent")

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: tool.ink
            opacity: tool.disabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.dp(8)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: tool.icon !== ""
            name: tool.icon
            size: Theme.dp(20)
            fill: tool.selected || tool.filled ? 1 : 0
            color: tool.ink
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: tool.text !== ""
            text: tool.text
            color: tool.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.weight: Font.Medium
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: !tool.disabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tool.clicked()
    }

}
