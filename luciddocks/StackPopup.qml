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

    readonly property int cardW: 172
    readonly property int cardH: 106
    readonly property bool showOpenHere: {
        for (var i = 0; i < popup.groups.length; i++) {
            if (popup.groups[i].workspaceId === popup.activeWorkspaceId)
                return false;

        }
        return true;
    }

    property int fadeDuration: Theme.durEnter
    property var fadeEasing: Theme.easeEmphasizedDecel

    onPopupVisibleChanged: {
        popup.fadeDuration = popup.popupVisible ? Theme.durEnter : Theme.durExit;
        popup.fadeEasing = popup.popupVisible ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel;
    }

    function normalizeAddress(a) {
        a = (a || "").toLowerCase();
        return a.indexOf("0x") === 0 ? a : "0x" + a;
    }

    anchor.window: popup.hostWindow
    anchor.rect.x: popup.anchorLocalX - popup.width / 2
    anchor.rect.y: popup.anchorLocalY - popup.height - 12
    color: "transparent"
    implicitWidth: row.implicitWidth + 24
    implicitHeight: popup.cardH + 66
    visible: popup.popupVisible || fadeAnim.running

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
        radius: Theme.radiusXl
        color: Theme.bg
        opacity: popup.popupVisible ? 1 : 0
        scale: popup.popupVisible ? 1 : 0.92
        transformOrigin: Item.Bottom

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 14

            Repeater {
                model: popup.groups

                delegate: Item {
                    id: entry

                    required property var modelData

                    readonly property bool hovered: hoverHandler.hovered
                    readonly property var toplevel: {
                        var want = popup.normalizeAddress(entry.modelData.address);
                        for (var i = 0; i < Hyprland.toplevels.values.length; i++) {
                            var t = Hyprland.toplevels.values[i];
                            if (popup.normalizeAddress(t.address) === want)
                                return t;

                        }
                        return null;
                    }
                    readonly property string windowTitle: {
                        var t = entry.toplevel;
                        var o = t && t.lastIpcObject ? t.lastIpcObject : null;
                        return o && o.title ? o.title : ("Workspace " + entry.modelData.workspaceId);
                    }

                    width: popup.cardW
                    height: popup.cardH + 40

                    HoverHandler {
                        id: hoverHandler
                    }

                    ClippingRectangle {
                        id: mainCard

                        width: popup.cardW
                        height: popup.cardH
                        radius: Theme.radiusLg
                        color: Theme.bgTile
                        scale: entry.hovered ? 1.03 : 1

                        ScreencopyView {
                            id: preview

                            anchors.centerIn: parent
                            constraintSize.width: mainCard.width
                            constraintSize.height: mainCard.height
                            captureSource: entry.toplevel ? entry.toplevel.wayland : null
                            live: popup.popupVisible
                            visible: preview.hasContent

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
                            source: popup.iconName !== "" ? Quickshell.iconPath(popup.iconName, true) : ""
                            visible: !preview.hasContent
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.text
                            opacity: entry.hovered ? Theme.stateHover : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Rectangle {
                        anchors.fill: mainCard
                        radius: mainCard.radius
                        color: "transparent"
                        border.color: Theme.accent
                        border.width: 2
                        scale: mainCard.scale
                        opacity: entry.hovered ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    Rectangle {
                        visible: entry.modelData.count >= 2
                        width: 22
                        height: 22
                        radius: 11
                        color: Theme.accent
                        anchors.left: mainCard.left
                        anchors.top: mainCard.top
                        anchors.leftMargin: -6
                        anchors.topMargin: -6
                        z: 20

                        Text {
                            anchors.centerIn: parent
                            text: entry.modelData.count
                            color: Theme.onAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(10)
                            font.weight: Font.DemiBold
                        }

                    }

                    Column {
                        anchors.top: mainCard.bottom
                        anchors.topMargin: 7
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 1

                        Text {
                            width: parent.width
                            text: entry.windowTitle
                            color: entry.hovered ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        Text {
                            width: parent.width
                            text: "Workspace " + entry.modelData.workspaceId
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            horizontalAlignment: Text.AlignHCenter
                        }

                    }

                    TapHandler {
                        onTapped: {
                            popup.popupVisible = false;
                            Hyprland.dispatch("hl.dsp.focus({window='address:" + entry.modelData.address + "'})");
                        }
                    }

                }

            }

            Item {
                id: openHereEntry

                readonly property bool hovered: openHereHover.hovered

                visible: popup.showOpenHere
                width: popup.cardW
                height: popup.cardH + 40

                HoverHandler {
                    id: openHereHover
                }

                Rectangle {
                    id: openHereCard

                    width: popup.cardW
                    height: popup.cardH
                    radius: Theme.radiusLg
                    color: Theme.bgTile
                    scale: openHereEntry.hovered ? 1.03 : 1

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.text
                        opacity: openHereEntry.hovered ? Theme.stateHover : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    DockGlyph {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        pathData: DockIcons.newWindow
                        glyphColor: Theme.accent
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Text {
                    anchors.top: openHereCard.bottom
                    anchors.topMargin: 7
                    anchors.horizontalCenter: openHereCard.horizontalCenter
                    text: "Open here"
                    color: openHereEntry.hovered ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    font.weight: Font.Medium

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durQuick
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

                duration: popup.fadeDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: popup.fadeEasing
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: popup.fadeDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: popup.fadeEasing
            }

        }

    }

}
