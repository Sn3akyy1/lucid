import "./lucidbar"
import "./luciddocks"
import "./lucidlock"
import "./lucidosd"
import "./lucidshot"
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: bar

        color: "transparent"
        implicitHeight: 800
        exclusiveZone: 35

        anchors {
            top: true
            bottom: false
            left: true
            right: true
        }

        margins {
            top: 22
        }

        Row {
            id: leftSection

            anchors.left: parent.left
            anchors.leftMargin: 17
            anchors.top: parent.top
            spacing: 8

            Item {
                id: workspacesSlot

                width: workspacesMod.compactWidth
                height: workspacesMod.compactHeight

                states: State {
                    name: "collapsedForExpand"
                    when: workspacesMod.expanded

                    PropertyChanges {
                        target: workspacesSlot
                        width: 0
                    }

                }

                transitions: Transition {
                    NumberAnimation {
                        properties: "width"
                        duration: 380
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Mpris {
                id: mprisMod

                hostWindow: bar
                anchors.top: parent.top
            }

        }

        Clock {
            id: clockMod

            readonly property int sideGap: 28

            hostWindow: bar
            anchors.top: parent.top
            x: Math.min(Math.max((parent.width - width) / 2, leftSection.x + leftSection.width + sideGap), rightSection.x - width - sideGap)
        }

        Row {
            id: rightSection

            anchors.right: parent.right
            anchors.rightMargin: 17
            anchors.top: parent.top
            spacing: 8

            BluetoothWidget {
                id: bluetoothMod

                hostWindow: bar
                anchors.top: parent.top
            }

            Network {
                id: networkMod

                hostWindow: bar
                anchors.top: parent.top
            }

            Notifications {
                id: notifMod

                hostWindow: bar
                anchors.top: parent.top
            }

            System {
                id: systemMod

                hostWindow: bar
                networkMod: networkMod
                bluetoothMod: bluetoothMod
                notifMod: notifMod
                mprisMod: mprisMod
                anchors.top: parent.top
            }

            Dock {
                id: dock
            }

            Screenshot {
                id: screenshotMod

                onCaptured: snapMod.open = false
            }

            SnapOverlay {
                id: snapMod

                onFullscreenRequested: screenshotMod.captureFull(false)
                onRegionRequested: (x, y, w, h) => {
                    return screenshotMod.captureRegion(x, y, w, h, false);
                }
            }

        }

        Workspaces {
            id: workspacesMod

            hostWindow: bar
            clients: dock.clientsData
            iconByClass: dock.iconByClass
            restX: leftSection.x
            restY: leftSection.y
        }

        mask: Region {
            Region {
                item: workspacesMod
            }

            Region {
                item: mprisMod
            }

            Region {
                item: clockMod
            }

            Region {
                item: bluetoothMod
            }

            Region {
                item: networkMod
            }

            Region {
                item: notifMod
            }

            Region {
                item: systemMod
            }

        }

        // real compositor blur (ext-background-effect-v1, not a Hyprland
        // config rule) scoped to just the visible pills instead of this
        // window's whole oversized transparent canvas - see mask above for
        // the same per-widget region pattern. Paired with Theme.blurAmount
        // fading each pill's own opacity, so what shows through is a real
        // frosted-glass blur of the desktop behind. Off entirely at
        // blurAmount 0 so the compositor isn't blurring behind fully
        // opaque pills for no reason.
        BackgroundEffect.blurRegion: Theme.blurAmount > 0 ? barBlurRegion : null

        Region {
            id: barBlurRegion

            Region {
                item: workspacesMod
                radius: workspacesMod.cornerRadius
            }

            Region {
                item: mprisMod
                radius: mprisMod.cornerRadius
            }

            Region {
                item: clockMod
                radius: clockMod.cornerRadius
            }

            Region {
                item: bluetoothMod
                radius: bluetoothMod.cornerRadius
            }

            Region {
                item: networkMod
                radius: networkMod.cornerRadius
            }

            Region {
                item: notifMod
                radius: notifMod.cornerRadius
            }

            Region {
                item: systemMod
                radius: systemMod.cornerRadius
            }

        }

    }

    Osd {
        id: osdMod
    }

    Lock {
        id: lockMod

        notifMod: notifMod
    }

    PanelWindow {
        id: clickCatcher

        visible: dock.menuOpen
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: dock.menuOpen = false
        }

    }

    Connections {
        function onExpandedChanged() {
            if (workspacesMod.expanded)
                dock.menuOpen = false;

        }

        target: workspacesMod
    }

    Connections {
        function onMenuOpenChanged() {
            if (dock.menuOpen)
                workspacesMod.expanded = false;

        }

        target: dock
    }

}
