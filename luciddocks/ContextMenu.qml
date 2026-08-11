import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

PopupWindow {
    id: menu

    component ActionRow: Item {
        id: row

        required property var modelData
        required property int index
        property bool hovered: hoverHandler.hovered

        width: list.width
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: row.hovered ? Theme.withBlur(Theme.bgHover) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }

            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: row.modelData.label
            color: row.modelData.danger ? Theme.error : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }

        HoverHandler {
            id: hoverHandler
        }

        TapHandler {
            onTapped: {
                menu.menuVisible = false;
                menu.actionChosen(row.modelData.id);
            }
        }

    }

    property bool menuVisible: false
    property string appId: ""
    property string command: ""
    property bool isPinned: false
    property int windowCount: 0
    property var hostWindow: null
    property real anchorLocalX: 0
    property real anchorLocalY: 0
    property var actions: {
        var arr = [];
        arr.push(menu.isPinned ? {
            "id": "unpin",
            "label": "Unpin from Dock"
        } : {
            "id": "pin",
            "label": "Pin to Dock"
        });
        if (menu.command !== "")
            arr.push({
                "id": "newWindow",
                "label": "New Window"
            });
        if (menu.windowCount > 0)
            arr.push({
                "id": "close",
                "label": "Close Window",
                "danger": true
            });
        if (menu.windowCount > 1)
            arr.push({
                "id": "closeAll",
                "label": "Close All (" + menu.windowCount + ")",
                "danger": true
            });
        return arr;
    }

    signal actionChosen(string id)

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
    anchor.rect.x: menu.anchorLocalX - width / 2
    anchor.rect.y: menu.anchorLocalY - height - 10
    color: "transparent"
    width: 172
    height: list.implicitHeight + 16
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
        radius: 12
        color: Theme.bg
        opacity: menu.menuVisible ? 1 : 0

        Column {
            id: list

            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: menu.actions
                delegate: ActionRow {
                }
            }

        }

        Behavior on opacity {
            NumberAnimation {
                id: fadeAnim

                duration: 150
                easing.type: Easing.OutCubic
            }

        }

    }

}
