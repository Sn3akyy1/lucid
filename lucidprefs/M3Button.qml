import QtQuick
import QtQuick.Shapes
import qs

// m3 expressive common button: full-shape at rest, corners morph in under press
Item {
    id: btn

    property string text: ""
    property string variant: "tonal" // "filled" | "tonal" | "outlined" | "text"
    property bool enabled: true
    property bool destructive: false
    property string iconPath: ""
    readonly property color baseColor: {
        if (btn.variant === "filled")
            return btn.destructive ? Theme.error : Theme.accent;

        if (btn.variant === "tonal")
            return btn.destructive ? Theme.errorContainer : Theme.secondaryContainer;

        return "transparent";
    }
    readonly property color labelColor: {
        if (btn.variant === "filled")
            return btn.destructive ? Theme.fgError : Theme.fgAccent;

        if (btn.variant === "tonal")
            return btn.destructive ? Theme.fgErrorContainer : Theme.fgSecondaryContainer;

        return btn.destructive ? Theme.error : Theme.text;
    }

    signal clicked()

    implicitHeight: 40
    implicitWidth: content.implicitWidth + (btn.variant === "text" ? 26 : 46)
    opacity: btn.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: area.pressed ? Theme.shapeMd : Theme.pill(height)
        color: btn.baseColor
        border.width: btn.variant === "outlined" ? 1 : 0
        border.color: Theme.outlineStrong

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: btn.labelColor
            opacity: !btn.enabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 8

        Shape {
            width: btn.iconPath === "" ? 0 : 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.iconPath !== ""
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillColor: btn.labelColor

                PathSvg {
                    path: btn.iconPath
                }

            }

            // authored on a 24x24 grid
            transform: Scale {
                xScale: 18 / 24
                yScale: 18 / 24
            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            color: btn.labelColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.weight: Font.Medium
            font.letterSpacing: 0.1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

}
