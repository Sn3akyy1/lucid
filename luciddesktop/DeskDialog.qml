import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.lucidui

// m3's basic dialog, for what the desktop icons cannot take back: emptying the
// trash, deleting for good. it holds the keyboard while it is up: enter confirms,
// escape cancels
PanelWindow {
    id: dlg

    readonly property var ask: DesktopIcons.dialog
    // held through the way out
    property var shown: null
    property bool up: false

    screen: DesktopIcons.screen
    visible: dlg.up || card.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucid-desktop-dialog"
    WlrLayershell.keyboardFocus: dlg.up ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onAskChanged: {
        if (dlg.ask) {
            dlg.shown = dlg.ask;
            dlg.up = true;
            keys.forceActiveFocus();
        } else if (dlg.up) {
            // only a dialog that was up hands the keys back
            dlg.up = false;
            DesktopIcons.armSoon();
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        width: dlg.up ? dlg.width : 0
        height: dlg.up ? dlg.height : 0
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) {
                DesktopIcons.answer(false);
                e.accepted = true;
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                DesktopIcons.answer(true);
                e.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.cShadow, 0.4)
            opacity: dlg.up ? 1 : 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: DesktopIcons.answer(false)
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: dlg.up ? Theme.durEnter : Theme.durExit
                }

            }

        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Theme.dp(360)
            height: body.implicitHeight + Theme.dp(48)
            radius: Theme.radiusXl
            color: Theme.surfaceHigh
            opacity: dlg.up ? 1 : 0
            scale: dlg.up ? 1 : 0.9
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 1
                shadowColor: Qt.rgba(0, 0, 0, 0.45)
                shadowVerticalOffset: Theme.dp(8)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Column {
                id: body

                x: Theme.dp(24)
                y: Theme.dp(24)
                width: parent.width - Theme.dp(48)
                spacing: Theme.dp(16)

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: Theme.dp(24)
                    name: dlg.shown ? dlg.shown.icon : ""
                    color: Theme.error
                }

                Text {
                    width: parent.width
                    text: dlg.shown ? dlg.shown.title : ""
                    color: Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(22)
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                Text {
                    width: parent.width
                    text: dlg.shown ? dlg.shown.body : ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    wrapMode: Text.Wrap
                    lineHeight: 1.15
                }

                Row {
                    anchors.right: parent.right
                    spacing: Theme.dp(8)

                    Button {
                        variant: "text"
                        text: I18n.tr("Cancel")
                        onClicked: DesktopIcons.answer(false)
                    }

                    Button {
                        variant: "filled"
                        danger: true
                        text: dlg.shown ? dlg.shown.confirm : ""
                        onClicked: DesktopIcons.answer(true)
                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: dlg.up ? Theme.durEnter : Theme.durExit
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: dlg.up ? Theme.durEnter : Theme.durExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: dlg.up ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
                }

            }

        }

    }

}
