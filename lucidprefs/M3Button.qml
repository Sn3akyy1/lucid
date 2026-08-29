import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: btn

    property string text: ""
    property string variant: "tonal" // "filled" | "tonal" | "text"
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
            return btn.destructive ? Theme.onError : Theme.onAccent;

        if (btn.variant === "tonal")
            return btn.destructive ? Theme.onErrorContainer : Theme.onSecondaryContainer;

        return btn.destructive ? Theme.error : Theme.text;
    }

    signal clicked()

    implicitHeight: 40
    implicitWidth: content.implicitWidth + (btn.variant === "text" ? 24 : 48)
    opacity: btn.enabled ? 1 : 0.38

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: btn.baseColor

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

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
            font.pixelSize: Theme.fontBody
            font.bold: true

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

}
