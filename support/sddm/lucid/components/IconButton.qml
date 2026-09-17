import QtQuick

// m3 icon button: a bare glyph that only grows a container when touched
Item {
    id: btn

    property string glyph: "close"
    property real diameter: 44
    property real glyphSize: 20
    property color glyphColor: Theme.text
    property color baseColor: "transparent"
    property color hoverColor: Theme.text
    // no `enabled` of our own: Item already has one, and shadowing it warns
    readonly property bool hovered: hover.hovered && btn.enabled
    readonly property bool pressed: tap.pressed && btn.enabled

    signal clicked()

    implicitWidth: Math.round(btn.diameter)
    implicitHeight: Math.round(btn.diameter)
    opacity: btn.enabled ? 1 : 0.38
    scale: btn.pressed ? 0.88 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.ms(110)
            easing.type: Easing.OutCubic
        }

    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: btn.baseColor
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: btn.hoverColor
        opacity: btn.pressed ? Theme.statePressed : (btn.hovered ? Theme.stateHover : 0)

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.OutCubic
            }

        }

    }

    Glyph {
        anchors.centerIn: parent
        name: btn.glyph
        size: btn.glyphSize
        color: btn.glyphColor
    }

    HoverHandler {
        id: hover

        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        enabled: btn.enabled
        onTapped: btn.clicked()
    }

}
