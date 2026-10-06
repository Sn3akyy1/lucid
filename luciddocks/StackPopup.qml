import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs

// the dock's window previews. a layer window of its own, like the right-click
// menu: hyprland only frosts layer surfaces, never popups
Item {
    id: popup

    property var grabWindow: null
    property real originX: 0
    property real originY: 0
    readonly property real cardW2: row.implicitWidth + Theme.dp(24)
    readonly property real cardH2: popup.cardH + Theme.dp(66)
    readonly property real cardX: Math.max(Theme.dp(8), Math.min(popup.width - popup.cardW2 - Theme.dp(8), popup.originX + popup.anchorLocalX - popup.cardW2 / 2))
    readonly property real cardY: Math.max(Theme.dp(8), popup.originY + popup.anchorLocalY - popup.cardH2 - Theme.dp(12))
    readonly property bool showing: popup.popupVisible || fadeAnim.running
    property bool popupVisible: false
    property string appId: ""
    property string iconName: ""
    property string launchCommand: ""
    property var groups: []
    property int activeWorkspaceId: -1
    property var hostWindow: null
    property real anchorLocalX: 0
    property real anchorLocalY: 0
    readonly property int cardW: Theme.dp(172)
    readonly property int cardH: Theme.dp(106)
    readonly property bool showOpenHere: {
        for (var i = 0; i < popup.groups.length; i++) {
            if (popup.groups[i].workspaceId === popup.activeWorkspaceId)
                return false;

        }
        return true;
    }
    property int fadeDuration: Theme.durEnter
    property var fadeEasing: Theme.easeEmphasizedDecel

    function normalizeAddress(a) {
        a = (a || "").toLowerCase();
        return a.indexOf("0x") === 0 ? a : "0x" + a;
    }

    function workspaceLabel(group) {
        var name = group.workspaceName || "";
        if (name.indexOf("special:") !== 0)
            return "Workspace " + group.workspaceId;

        var s = name.slice(8);
        return s === "" || s === "special" ? "Scratchpad" : "Scratchpad · " + s;
    }

    onPopupVisibleChanged: {
        popup.fadeDuration = popup.popupVisible ? Theme.durEnter : Theme.durExit;
        popup.fadeEasing = popup.popupVisible ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel;
    }

    HyprlandFocusGrab {
        windows: popup.grabWindow ? [popup.grabWindow] : []
        active: popup.popupVisible
        onActiveChanged: {
            if (!active)
                popup.popupVisible = false;

        }
    }

    Rectangle {
        id: contentRoot

        x: popup.cardX
        y: popup.cardY
        width: popup.cardW2
        height: popup.cardH2
        radius: Theme.radiusXl
        color: Theme.bg
        opacity: popup.popupVisible ? 1 : 0
        scale: popup.popupVisible ? 1 : 0.92
        transformOrigin: Item.Bottom

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Theme.dp(14)

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
                        return o && o.title ? o.title : popup.workspaceLabel(entry.modelData);
                    }

                    width: popup.cardW
                    height: popup.cardH + Theme.dp(40)

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
                            width: Theme.dp(40)
                            height: Theme.dp(40)
                            anchors.centerIn: parent
                            source: popup.iconName === "" ? "" : (IconTheme.generation >= 0 && IconTheme.pathFor(popup.iconName) !== "" ? IconTheme.pathFor(popup.iconName) : Quickshell.iconPath(popup.iconName, true))
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
                        width: Theme.dp(22)
                        height: Theme.dp(22)
                        radius: Theme.dp(11)
                        color: Theme.accent
                        anchors.left: mainCard.left
                        anchors.top: mainCard.top
                        anchors.leftMargin: -Theme.dp(6)
                        anchors.topMargin: -Theme.dp(6)
                        z: 20

                        Text {
                            anchors.centerIn: parent
                            text: entry.modelData.count
                            color: Theme.fgAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(10)
                            font.variableAxes: Theme.axes(Theme.fs(10), 600, 0)
                            font.weight: Font.DemiBold
                        }

                    }

                    Column {
                        anchors.top: mainCard.bottom
                        anchors.topMargin: Theme.dp(7)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 1

                        Text {
                            width: parent.width
                            text: entry.windowTitle
                            color: entry.hovered ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.variableAxes: Theme.axes(Theme.fontLabel, 520, 0)
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
                            text: popup.workspaceLabel(entry.modelData)
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
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
                height: popup.cardH + Theme.dp(40)

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
                        width: Theme.dp(30)
                        height: Theme.dp(30)
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
                    anchors.topMargin: Theme.dp(7)
                    anchors.horizontalCenter: openHereCard.horizontalCenter
                    text: "Open here"
                    color: openHereEntry.hovered ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    font.variableAxes: Theme.axes(Theme.fontLabel, 520, 0)
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
