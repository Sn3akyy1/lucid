import QtQuick
import QtQuick.Shapes
import qs

// Material 3 button in the three variants this app actually needs: filled
// (the one primary action on a page), tonal (secondary actions), and text
// (destructive or low-stakes ones). M3's own outlined/elevated variants are
// left out rather than shipped unused.
Item {
    id: btn

    property string text: ""
    property string variant: "tonal" // "filled" | "tonal" | "text"
    property bool enabled: true
    property bool destructive: false
    // optional 24x24 Material path drawn ahead of the label
    property string iconPath: ""

    readonly property color baseColor: {
        if (btn.variant === "filled")
            return btn.destructive ? Theme.error : Theme.accent;

        // M3's filled-tonal button is a *tinted* surface - secondary
        // container - not a neutral one. This reached for bgHigh only
        // because the palette had no container token to reach for; with
        // secondary_container now coming through, it can be what the spec
        // actually asks for, and a tonal button reads as a button rather
        // than as a slightly lighter patch of the panel behind it.
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

        // state layer sits on top of the base fill rather than replacing it,
        // so hover reads the same on every variant including the transparent
        // one
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

        // Shape rather than Canvas: the fill colour is a live binding on the
        // button's variant/state, and a Canvas would need an explicit
        // repaint on every one of those changes
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

            // Material paths are authored on a 24x24 grid
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
