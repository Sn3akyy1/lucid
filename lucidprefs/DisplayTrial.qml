import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// "keep these display settings?" in the middle of every display while a
// change from the Displays page is on trial, so it can be answered from
// whichever one still shows a picture. left alone, the change goes back
Scope {
    id: root

    // the windows only exist while a trial runs (and fades out)
    property bool live: false

    Connections {
        function onOnTrialChanged() {
            if (Monitors.onTrial) {
                unloadTimer.stop();
                root.live = true;
            } else {
                unloadTimer.restart();
            }
        }

        target: Monitors
    }

    Timer {
        id: unloadTimer

        interval: 600
        onTriggered: root.live = false
    }

    LazyLoader {
        active: root.live

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property var modelData

                screen: win.modelData
                color: "transparent"
                exclusiveZone: 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "lucid-display-trial"
                implicitWidth: card.width
                implicitHeight: card.height

                Rectangle {
                    id: card

                    // starts hidden, so the first frame fades in
                    property bool up: false

                    width: Math.max(Theme.dp(360), body.implicitWidth + Theme.dp(56))
                    height: body.implicitHeight + Theme.dp(48)
                    radius: Theme.shapeXl
                    color: Theme.bgOpaque
                    border.width: 2
                    border.color: Theme.accent
                    opacity: card.up && Monitors.onTrial ? 1 : 0
                    scale: card.up && Monitors.onTrial ? 1 : 0.92
                    Component.onCompleted: card.up = true

                    Column {
                        id: body

                        anchors.centerIn: parent
                        spacing: Theme.dp(6)

                        Text {
                            text: "Keep these display settings?"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitleLg
                            font.weight: Font.Medium
                        }

                        Text {
                            text: (Monitors.trialLeft === 1 ? "Going back to the previous ones in " + Monitors.trialLeft + " second." : "Going back to the previous ones in " + Monitors.trialLeft + " seconds.")
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyMd
                        }

                        Item {
                            width: 1
                            height: Theme.dp(10)
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: Theme.dp(8)

                            M3Button {
                                text: "Go back"
                                variant: "text"
                                onClicked: Monitors.revertTrial()
                            }

                            M3Button {
                                text: "Keep"
                                variant: "filled"
                                onClicked: Monitors.keepTrial()
                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Theme.easeEmphasized
                            easing.overshoot: Theme.emphasizedOvershoot
                        }

                    }

                }

            }

        }

    }

}
