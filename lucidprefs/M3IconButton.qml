import QtQuick
import QtQuick.Shapes
import qs

// m3 expressive icon button: round at rest, morphs square-ish under press
Item {
    id: btn

    property string variant: "standard" // "standard" | "tonal" | "filled" | "outlined"
    property int size: 40
    property int iconSize: Math.round(btn.size * 0.55)
    property string iconPath: ""
    property bool enabled: true
    property bool destructive: false
    readonly property color baseColor: {
        if (btn.variant === "filled")
            return btn.destructive ? Theme.error : Theme.accent;

        if (btn.variant === "tonal")
            return btn.destructive ? Theme.errorContainer : Theme.secondaryContainer;

        return "transparent";
    }
    readonly property color fgColor: {
        if (btn.variant === "filled")
            return btn.destructive ? Theme.fgError : Theme.fgAccent;

        if (btn.variant === "tonal")
            return btn.destructive ? Theme.fgErrorContainer : Theme.fgSecondaryContainer;

        return btn.destructive ? Theme.error : (area.containsMouse ? Theme.text : Theme.subtext);
    }

    signal clicked()

    implicitWidth: btn.size
    implicitHeight: btn.size
    opacity: btn.enabled ? 1 : 0.38

    Rectangle {
        id: container

        anchors.fill: parent
        // shape morph: full -> medium while held
        radius: area.pressed ? Theme.shapeMd : Theme.pill(btn.size)
        color: btn.baseColor
        border.width: btn.variant === "outlined" ? 1 : 0
        border.color: Theme.outlineStrong

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: btn.fgColor
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

    Shape {
        anchors.centerIn: parent
        width: btn.iconSize
        height: btn.iconSize
        visible: btn.iconPath !== ""
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: btn.fgColor

            PathSvg {
                path: btn.iconPath
            }

        }

        // icons are authored on a 24x24 grid
        transform: Scale {
            xScale: btn.iconSize / 24
            yScale: btn.iconSize / 24
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
