import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.lucidui

// m3's snackbar for the desktop icons: what just happened at the foot of the main
// screen, with undo when it can be. dark, on the toast's own surface and blur. a small
// overlay of its own, above windows and clear of the dock, that takes no keyboard and
// only its own clicks
PanelWindow {
    id: bar

    readonly property var snack: DesktopIcons.snack
    // held through the way out
    property var shown: null
    property bool up: false

    screen: DesktopIcons.screen
    visible: bar.up || pill.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.min(Theme.dp(560), (bar.screen ? bar.screen.width : 1920) - Theme.dp(32))
    implicitHeight: Theme.dp(72)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucid-desktop-snackbar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    margins.bottom: Widgets.spawnBottom + Theme.dp(4)
    BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && bar.visible) ? pillBlur : null
    onSnackChanged: {
        if (bar.snack) {
            bar.shown = bar.snack;
            bar.up = true;
        } else {
            bar.up = false;
        }
    }
    Component.onCompleted: {
        if (bar.snack) {
            bar.shown = bar.snack;
            bar.up = true;
        }
    }

    anchors {
        bottom: true
    }

    mask: Region {
        item: pill
    }

    // the toast's blur, a hair inside the rounded edge
    // clipped to the surface: hyprland frosts the whole layer for a region wholly
    // outside it, and the pill starts below the edge
    Region {
        id: pillBlur

        intersection: Intersection.Intersect
        x: Math.ceil(pill.x) + 1
        y: Math.ceil(pill.y)
        width: Math.max(0, Math.floor(pill.width) - 2)
        height: Math.max(0, Math.floor(pill.height))
        radius: Math.round(pill.radius)
    }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.up ? parent.height - height - Theme.dp(12) : parent.height
        width: Math.min(parent.width - Theme.dp(8), msg.implicitWidth + (undoBtn.visible ? undoBtn.width + Theme.dp(8) : 0) + closeBtn.width + Theme.dp(36))
        height: Theme.dp(48)
        radius: Theme.radiusSm
        color: Theme.bg
        border.width: Theme.blurAmount > 0 ? 0 : 1
        border.color: Theme.alpha(Theme.text, 0.08)
        opacity: bar.up ? 1 : 0
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.7
            shadowColor: Qt.rgba(0, 0, 0, 0.35)
            shadowVerticalOffset: Theme.dp(3)
        }

        HoverHandler {
            id: hover

            // the pointer on it holds it, as m3 asks
            onHoveredChanged: {
                if (hover.hovered && DesktopIcons.snack)
                    DesktopIcons.notify(DesktopIcons.snack.text, DesktopIcons.snack.undo);

            }
        }

        Text {
            id: msg

            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(16)
            anchors.right: undoBtn.visible ? undoBtn.left : closeBtn.left
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            text: bar.shown ? bar.shown.text : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            elide: Text.ElideMiddle
        }

        // undo, in the inverse primary
        Item {
            id: undoBtn

            anchors.right: closeBtn.left
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.shown !== null && bar.shown.undo === true
            width: undoText.implicitWidth + Theme.dp(24)
            height: Theme.dp(36)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.accent
                opacity: undoTap.pressed ? 0.16 : (undoHover.hovered ? 0.1 : 0)
            }

            Text {
                id: undoText

                anchors.centerIn: parent
                text: "Undo"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.DemiBold
            }

            HoverHandler {
                id: undoHover
            }

            TapHandler {
                id: undoTap

                onTapped: DesktopIcons.undo()
            }

        }

        Item {
            id: closeBtn

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(36)
            height: Theme.dp(36)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.text
                opacity: closeHover.hovered ? Theme.stateHover : 0
            }

            Icon {
                anchors.centerIn: parent
                size: Theme.dp(18)
                name: "close"
                color: Theme.subtext
            }

            HoverHandler {
                id: closeHover
            }

            TapHandler {
                onTapped: DesktopIcons.dropSnack()
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: bar.up ? Theme.durEnter : Theme.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: bar.up ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: bar.up ? Theme.durShort : Theme.durExit
            }

        }

    }

}
