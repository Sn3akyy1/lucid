import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

PopupWindow {
    id: menu

    property bool menuVisible: false
    property string appId: ""
    property string command: ""
    property bool isPinned: false
    property int windowCount: 0
    property var hostWindow: null
    property real anchorLocalX: 0
    property real anchorLocalY: 0

    readonly property var actions: {
        var arr = [];
        arr.push(menu.isPinned ? {
            "id": "unpin",
            "label": "Unpin from Dock",
            "glyph": DockIcons.unpin,
            "danger": false,
            "divider": false
        } : {
            "id": "pin",
            "label": "Pin to Dock",
            "glyph": DockIcons.pin,
            "danger": false,
            "divider": false
        });
        if (menu.command !== "")
            arr.push({
                "id": "newWindow",
                "label": "New Window",
                "glyph": DockIcons.newWindow,
                "danger": false,
                "divider": false
            });

        if (menu.windowCount > 0)
            arr.push({
                "id": "close",
                "label": "Close Window",
                "glyph": DockIcons.closeWindow,
                "danger": true,
                "divider": true
            });

        if (menu.windowCount > 1)
            arr.push({
                "id": "closeAll",
                "label": "Close All (" + menu.windowCount + ")",
                "glyph": DockIcons.closeWindow,
                "danger": true,
                "divider": false
            });

        return arr;
    }

    signal actionChosen(string id)

    property int fadeDuration: Theme.durEnter
    property var fadeEasing: Theme.easeEmphasizedDecel

    onMenuVisibleChanged: {
        menu.fadeDuration = menu.menuVisible ? Theme.durEnter : Theme.durExit;
        menu.fadeEasing = menu.menuVisible ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel;
    }

    function openFor(item, appId, isPinned, command, windowCount) {
        if (menu.menuVisible && menu.appId.toLowerCase() === appId.toLowerCase()) {
            menu.menuVisible = false;
            return;
        }

        var localPos = item.mapToItem(null, 0, 0);
        menu.appId = appId;
        menu.command = command;
        menu.isPinned = isPinned;
        menu.windowCount = windowCount;
        menu.anchorLocalX = localPos.x + item.width / 2;
        menu.anchorLocalY = localPos.y;
        menu.menuVisible = true;
    }

    anchor.window: menu.hostWindow
    anchor.rect.x: menu.anchorLocalX - menu.width / 2
    anchor.rect.y: menu.anchorLocalY - menu.height - 12
    color: "transparent"
    implicitWidth: 210
    implicitHeight: list.implicitHeight + 16
    visible: menu.menuVisible || fadeAnim.running

    HyprlandFocusGrab {
        id: focusGrab

        windows: [menu]
        active: menu.menuVisible
        onActiveChanged: {
            if (!active)
                menu.menuVisible = false;

        }
    }

    Rectangle {
        id: contentRoot

        anchors.fill: parent
        radius: Theme.radiusMd
        color: Theme.bg
        opacity: menu.menuVisible ? 1 : 0
        scale: menu.menuVisible ? 1 : 0.9
        transformOrigin: Item.Bottom

        Column {
            id: list

            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: menu.actions

                delegate: Item {
                    id: row

                    required property var modelData
                    readonly property bool hovered: hoverHandler.hovered
                    readonly property bool pressed: tapHandler.pressed
                    readonly property color tone: row.modelData.danger ? Theme.error : Theme.text

                    width: list.width
                    height: 40 + (row.modelData.divider ? 9 : 0)

                    Rectangle {
                        id: divider

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.topMargin: 4
                        height: 1
                        color: Theme.outline
                        visible: row.modelData.divider
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 40

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusXs
                            color: row.tone
                            opacity: row.pressed ? Theme.statePressed : (row.hovered ? Theme.stateHover : 0)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        DockGlyph {
                            id: rowGlyph

                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            pathData: row.modelData.glyph
                            glyphColor: row.modelData.danger ? Theme.error : Theme.subtext
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: rowGlyph.right
                            anchors.leftMargin: 12
                            text: row.modelData.label
                            color: row.tone
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.Medium
                        }

                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    TapHandler {
                        id: tapHandler

                        onTapped: {
                            menu.menuVisible = false;
                            menu.actionChosen(row.modelData.id);
                        }
                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                id: fadeAnim

                duration: menu.fadeDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: menu.fadeEasing
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: menu.fadeDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: menu.fadeEasing
            }

        }

    }

}
