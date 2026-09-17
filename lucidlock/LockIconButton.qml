import QtQuick
import qs

// m3 icon button: a bare glyph that only grows a container when touched
Item {
    id: btn

    property string glyph: "close"
    property real diameter: 44
    property real glyphSize: 20
    property color glyphColor: Theme.text
    // a resting fill, for the one button on a card that is the point of it
    property color baseColor: "transparent"
    property color hoverColor: Theme.text
    property bool enabled: true
    property string tooltip: ""
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

    // the state layer, m3's one honest way to show a pointer is here
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

    LockGlyph {
        anchors.centerIn: parent
        name: btn.glyph
        size: btn.glyphSize
        color: btn.glyphColor

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(140)
            }

        }

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

    // a label that only exists while the pointer rests on the button
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 6
        width: tipText.implicitWidth + 16
        height: 24
        radius: Theme.shapeXs
        color: Theme.inverseSurface
        visible: btn.tooltip !== "" && btn.hovered
        opacity: btn.hovered ? 1 : 0

        Text {
            id: tipText

            anchors.centerIn: parent
            text: btn.tooltip
            color: Theme.fgInverseSurface
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelMd
            font.weight: Font.Medium
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(120)
            }

        }

    }

}
