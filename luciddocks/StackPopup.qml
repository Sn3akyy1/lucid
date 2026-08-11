import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs

PopupWindow {
    id: popup

    property bool popupVisible: false
    property string appId: ""
    property string iconName: ""
    property string launchCommand: ""
    property var groups: []
    property int activeWorkspaceId: -1
    property var hostWindow: null
    property real anchorLocalX: 0
    property real anchorLocalY: 0
    property bool showOpenHere: {
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].workspaceId === activeWorkspaceId)
                return false;

        }
        return true;
    }

    function normalizeAddress(a) {
        a = (a || "").toLowerCase();
        return a.indexOf("0x") === 0 ? a : "0x" + a;
    }

    anchor.window: hostWindow
    anchor.rect.x: anchorLocalX - width / 2
    anchor.rect.y: anchorLocalY - height - 10
    color: "transparent"
    width: row.implicitWidth + 20
    height: 152
    visible: popupVisible || fadeAnim.running

    HyprlandFocusGrab {
        id: focusGrab

        windows: [popup]
        active: popup.popupVisible
        onActiveChanged: {
            if (!active)
                popup.popupVisible = false;

        }
    }

    Rectangle {
        id: contentRoot

        anchors.fill: parent
        radius: 14
        color: Theme.bg
        opacity: popup.popupVisible ? 1 : 0

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 16

            Repeater {
                model: popup.groups

                delegate: Item {
                    id: entry

                    property bool hovered: hoverHandler.hovered
                    property var toplevel: {
                        var want = popup.normalizeAddress(modelData.address);
                        for (var i = 0; i < Hyprland.toplevels.values.length; i++) {
                            var t = Hyprland.toplevels.values[i];
                            if (popup.normalizeAddress(t.address) === want)
                                return t;

                        }
                        return null;
                    }

                    width: 160
                    height: 122

                    HoverHandler {
                        id: hoverHandler
                    }

                    Rectangle {
                        id: stackCard

                        width: 160
                        height: 100
                        radius: 10
                        color: "transparent"
                        border.color: Theme.alpha(Theme.text, 0.25)
                        border.width: 1
                        visible: modelData.count >= 2
                        x: -6
                        y: -6
                    }

                    ClippingRectangle {
                        id: mainCard

                        width: 160
                        height: 100
                        radius: 10
                        color: entry.hovered ? Theme.withBlur(Theme.bgHover) : "transparent"
                        border.color: Theme.accent
                        border.width: entry.hovered ? 2 : 1
                        scale: entry.hovered ? 1.03 : 1

                        ScreencopyView {
                            id: preview

                            anchors.centerIn: parent
                            constraintSize.width: mainCard.width
                            constraintSize.height: mainCard.height
                            captureSource: entry.toplevel ? entry.toplevel.wayland : null
                            live: popup.popupVisible
                            visible: hasContent

                            transform: Scale {
                                id: coverScale

                                origin.x: preview.width / 2
                                origin.y: preview.height / 2
                                xScale: preview.width > 0 && preview.height > 0 ? Math.max(mainCard.width / preview.width, mainCard.height / preview.height) : 1
                                yScale: coverScale.xScale
                            }

                        }

                        IconImage {
                            width: 40
                            height: 40
                            anchors.centerIn: parent
                            source: popup.iconName !== "" ? Quickshell.iconPath(popup.iconName, "") : ""
                            visible: !preview.hasContent
                        }

                        Rectangle {
                            id: iconBadge

                            visible: preview.hasContent
                            width: 26
                            height: 26
                            radius: 7
                            color: Theme.alpha(Theme.bg, 0.85)
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 6

                            IconImage {
                                anchors.fill: parent
                                anchors.margins: 4
                                source: popup.iconName !== "" ? Quickshell.iconPath(popup.iconName, "") : ""
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Rectangle {
                        visible: modelData.count >= 2
                        width: 20
                        height: 20
                        radius: 10
                        color: Theme.accent
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: -8
                        anchors.topMargin: -8
                        z: 20

                        Text {
                            anchors.centerIn: parent
                            text: modelData.count
                            color: Theme.onAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                    }

                    Text {
                        anchors.top: mainCard.bottom
                        anchors.horizontalCenter: mainCard.horizontalCenter
                        anchors.topMargin: 6
                        text: "Workspace " + modelData.workspaceId
                        color: entry.hovered ? Theme.text : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 12

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }

                        }

                    }

                    TapHandler {
                        onTapped: {
                            popup.popupVisible = false;
                            if (modelData.workspaceId !== popup.activeWorkspaceId) {
                                var lua = "local w=nil for i,win in pairs(hl.get_windows()) do if win.address=='" + modelData.address + "' then w=win end end if w then hl.dispatch(hl.dsp.focus({window=w})) end";
                                Quickshell.execDetached(["hyprctl", "eval", lua]);
                            } else if (popup.launchCommand !== "") {
                                Quickshell.execDetached(["sh", "-c", popup.launchCommand]);
                            }
                        }
                    }

                }

            }

            Item {
                id: openHereEntry

                property bool hovered: openHereHover.hovered

                visible: popup.showOpenHere
                width: 160
                height: 122

                HoverHandler {
                    id: openHereHover
                }

                Rectangle {
                    id: openHereCard

                    width: 160
                    height: 100
                    radius: 10
                    color: openHereEntry.hovered ? Theme.withBlur(Theme.bgHover) : "transparent"
                    border.color: Theme.alpha(Theme.text, 0.25)
                    border.width: openHereEntry.hovered ? 2 : 1
                    scale: openHereEntry.hovered ? 1.03 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Text {
                    anchors.top: openHereCard.bottom
                    anchors.horizontalCenter: openHereCard.horizontalCenter
                    anchors.topMargin: 6
                    text: "Open here"
                    color: openHereEntry.hovered ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 12

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }

                    }

                }

                TapHandler {
                    onTapped: {
                        popup.popupVisible = false;
                        if (popup.launchCommand !== "")
                            Quickshell.execDetached(["sh", "-c", popup.launchCommand]);

                    }
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                id: fadeAnim

                duration: 180
                easing.type: Easing.OutCubic
            }

        }

    }

}
