import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// a big number in the middle of every display for a moment, the same number
// its box carries on the Displays page
Scope {
    id: root

    property bool shown: false
    // the windows only exist while the numbers are up (and fading out), so a
    // config reload never has to carry them
    property bool live: false

    Connections {
        function onIdentifyRequested() {
            unloadTimer.stop();
            root.live = true;
            root.shown = true;
            hideTimer.restart();
        }

        target: Monitors
    }

    Timer {
        id: hideTimer

        interval: 2600
        onTriggered: {
            root.shown = false;
            unloadTimer.restart();
        }
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
                readonly property string key: Monitors.keyForName(win.modelData.name)
                readonly property var mon: Monitors.output(win.key)

                screen: win.modelData
                color: "transparent"
                exclusiveZone: 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "lucid-identify"
                implicitWidth: card.width
                implicitHeight: card.height

                Rectangle {
                    id: card

                    // starts hidden, so the first frame fades in
                    property bool up: false

                    width: Math.max(220, info.implicitWidth + 64)
                    height: info.implicitHeight + 52
                    radius: Theme.shapeXl
                    color: Theme.bgOpaque
                    border.width: 2
                    border.color: Theme.accent
                    opacity: card.up && root.shown ? 1 : 0
                    scale: card.up && root.shown ? 1 : 0.9
                    Component.onCompleted: card.up = true

                    Column {
                        id: info

                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.mon ? Monitors.numberFor(win.key) : "?"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 96
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.mon ? Monitors.labelFor(win.key) : win.modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitleLg
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.mon ? win.mon.name + " · " + win.mon.width + " × " + win.mon.height + " · " + Monitors.rateLabel(win.mon.refresh) : ""
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyMd
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

                mask: Region {
                }

            }

        }

    }

}
