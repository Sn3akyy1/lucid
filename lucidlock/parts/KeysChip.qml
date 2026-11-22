import QtQuick

// the on-screen keyboard's chip, in the line under the field, beside the
// keymap's: the lock's sign-in and the login screen's both wear it
Rectangle {
    id: chip

    property var theme: null
    property bool on: false
    // what it sits on, so it reads one step up from it
    property color base: "transparent"

    signal toggled()

    function dp(px) {
        return chip.theme ? chip.theme.dp(px) : px;
    }

    width: chip.dp(32)
    height: chip.dp(20)
    radius: height / 2
    color: chip.on && chip.theme ? chip.theme.accentContainer : chip.base

    Behavior on color {
        ColorAnimation {
            duration: chip.theme ? chip.theme.ms(160) : 160
        }

    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: chip.theme ? (chip.on ? chip.theme.fgAccentContainer : chip.theme.text) : "white"
        opacity: chip.theme ? (area.pressed ? chip.theme.statePressed : (area.containsMouse ? chip.theme.stateHover : 0)) : 0
    }

    Glyph {
        anchors.centerIn: parent
        name: "keyboard"
        size: chip.dp(15)
        color: chip.theme ? (chip.on ? chip.theme.fgAccentContainer : chip.theme.subtext) : "white"
    }

    // a little past its edges: it is small for a finger
    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -chip.dp(6)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.toggled()
    }

}
