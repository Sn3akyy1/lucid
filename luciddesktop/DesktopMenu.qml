import "../luciddocks"
import QtQuick
import Quickshell.Hyprland
import qs

Item {
    id: menu

    property bool open: false
    // where the click landed, in layer coordinates
    property real originX: 0
    property real originY: 0
    property real fieldW: 1920
    property real fieldH: 1080
    readonly property real panelW: Theme.dp(218)
    readonly property real edge: Theme.dp(10)
    // the layer covers the whole screen; what the bar and dock hold stays out
    // of reach. Hyprland's monitor says how much, [left, top, right, bottom]
    property var monitor: null
    readonly property var reserved: (menu.monitor && menu.monitor.lastIpcObject && menu.monitor.lastIpcObject.reserved) || [0, 0, 0, 0]
    readonly property real minY: menu.edge + (menu.reserved[1] || 0)
    readonly property real maxY: menu.fieldH - menu.edge - (menu.reserved[3] || 0)
    readonly property real maxX: menu.fieldW - menu.edge - (menu.reserved[2] || 0)
    // a menu opens down-right of the cursor, and flips rather than run off screen
    readonly property bool toLeft: menu.originX + menu.panelW > menu.maxX
    readonly property bool toUp: menu.originY + panel.height > menu.maxY
    // a list of its own instead of the desktop's, for the icons' menu
    property var custom: null
    // an action with "children" opens them in a side panel; this is its row
    property Item subRow: null
    property var subItems: []
    property real subY: 0
    readonly property real subW: Theme.dp(236)
    readonly property int subVisibleRows: 8
    // the side panel goes right of the menu, or left when the screen ends first
    readonly property bool subToLeft: menu.x + menu.panelW + 4 + menu.subW > menu.maxX
    readonly property var actions: menu.custom !== null ? menu.custom : menu.desktopActions
    readonly property var desktopActions: {
        var arr = [];
        if (DesktopIcons.live) {
            arr.push({
                "id": "newFolder",
                "label": "New Folder",
                "glyph": DesktopIcons.glyphs.newFolder,
                "divider": false
            });
            if (DesktopIcons.canPaste)
                arr.push({
                "id": "paste",
                "label": "Paste",
                "glyph": DesktopIcons.glyphs.paste,
                "divider": false
            });

            arr.push({
                "id": "arrange",
                "label": "Arrange Icons",
                "glyph": DesktopIcons.glyphs.arrange,
                "divider": false
            });
        }
        arr.push({
            "id": "wallpaper",
            "label": "Change Wallpaper",
            "glyph": DockIcons.wallpaper,
            "divider": arr.length > 0
        });
        arr.push({
            "id": "theme",
            "label": "Change Theme",
            "glyph": DockIcons.palette,
            "divider": false
        });
        arr.push({
            "id": "widgetPanel",
            "label": "Widget Panel",
            "glyph": DockIcons.widgets,
            "divider": true
        });
        if (Widgets.count > 0)
            arr.push(Prefs.widgetsEnabled ? {
            "id": "hideWidgets",
            "label": "Hide Widgets",
            "glyph": DockIcons.hidden,
            "divider": false
        } : {
            "id": "showWidgets",
            "label": "Show Widgets",
            "glyph": DockIcons.visible,
            "divider": false
        });

        // put away and back, the way the widgets are; Settings keeps the switch
        // that turns the icons off altogether
        if (Prefs.desktopIcons)
            arr.push(Prefs.desktopIconsShown ? {
            "id": "hideIcons",
            "label": "Hide Icons",
            "glyph": DockIcons.hidden,
            "divider": !Prefs.widgetsEnabled && Widgets.count === 0
        } : {
            "id": "showIcons",
            "label": "Show Icons",
            "glyph": DockIcons.visible,
            "divider": !Prefs.widgetsEnabled && Widgets.count === 0
        });

        arr.push({
            "id": "screenshot",
            "label": "Take a Screenshot",
            "glyph": DockIcons.camera,
            "divider": true
        });
        arr.push({
            "id": "keyboard",
            "label": "On-Screen Keyboard",
            "glyph": DockIcons.keyboard,
            "divider": false
        });
        arr.push({
            "id": "settings",
            "label": "Settings",
            "glyph": DockIcons.settings,
            "divider": true
        });
        return arr;
    }

    // the panel as drawn, scale included, in the menu's parent's coordinates
    readonly property real paintedX: menu.x + (menu.toLeft ? panel.width : 0) * (1 - panel.scale)
    readonly property real paintedY: menu.y + (menu.toUp ? panel.height : 0) * (1 - panel.scale)
    readonly property real paintedW: panel.width * panel.scale
    readonly property real paintedH: panel.height * panel.scale
    readonly property real paintedRadius: panel.radius * panel.scale

    signal chosen(string id)

    function openAt(px, py) {
        // the reserved strips follow the bar, which can move or hide
        Hyprland.refreshMonitors();
        menu.subRow = null;
        menu.originX = px;
        menu.originY = py;
        menu.open = true;
    }

    function openSub(row) {
        if (menu.subRow === row)
            return ;

        menu.subItems = row.kids;
        const h = Math.min(row.kids.length, menu.subVisibleRows) * Theme.dp(40) + Theme.dp(16);
        // first entry level with the row, then kept on screen
        let y = row.mapToItem(menu, 0, 0).y + (row.modelData.divider ? 9 : 0) - 8;
        y = Math.min(y, menu.maxY - h - menu.y);
        y = Math.max(y, menu.minY - menu.y);
        menu.subY = y;
        menu.subRow = row;
    }

    onOpenChanged: {
        if (!menu.open)
            menu.subRow = null;

    }

    width: menu.panelW
    height: panel.height
    x: menu.toLeft ? menu.originX - menu.panelW : menu.originX
    y: Math.max(menu.minY, menu.toUp ? menu.originY - panel.height : menu.originY)
    visible: panel.opacity > 0.01

    Rectangle {
        id: panel

        width: menu.panelW
        height: list.implicitHeight + Theme.dp(16)
        radius: Theme.radiusMd
        color: Theme.bg
        opacity: menu.open ? 1 : 0
        scale: menu.open ? 1 : 0.9
        transformOrigin: menu.toLeft ? (menu.toUp ? Item.BottomRight : Item.TopRight) : (menu.toUp ? Item.BottomLeft : Item.TopLeft)

        Column {
            id: list

            anchors.fill: parent
            anchors.margins: Theme.dp(8)
            spacing: Theme.dp(2)

            Repeater {
                model: menu.actions

                Item {
                    id: row

                    required property var modelData
                    readonly property var kids: row.modelData.children || null
                    readonly property bool hovered: rowHover.hovered || menu.subRow === row
                    readonly property bool pressed: rowTap.pressed

                    width: list.width
                    height: Theme.dp(40) + (row.modelData.divider ? Theme.dp(9) : 0)

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.dp(8)
                        anchors.rightMargin: Theme.dp(8)
                        anchors.topMargin: Theme.dp(4)
                        height: 1
                        color: Theme.outline
                        visible: row.modelData.divider
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.dp(40)

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusXs
                            color: Theme.text
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
                            anchors.leftMargin: Theme.dp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.dp(18)
                            height: Theme.dp(18)
                            pathData: row.modelData.glyph
                            glyphColor: Theme.subtext
                        }

                        DockGlyph {
                            id: rowArrow

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(8)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.dp(16)
                            height: Theme.dp(16)
                            visible: !!row.kids
                            pathData: "M8.59 16.59 13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41Z"
                            glyphColor: Theme.subtext
                            rotation: menu.subToLeft ? 180 : 0
                        }

                        Text {
                            anchors.left: rowGlyph.right
                            anchors.right: row.kids ? rowArrow.left : parent.right
                            anchors.leftMargin: Theme.dp(12)
                            anchors.rightMargin: row.kids ? Theme.dp(4) : Theme.dp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            font.variableAxes: Theme.axes(Theme.fontBody, 520, 0)
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                    }

                    HoverHandler {
                        id: rowHover

                        onHoveredChanged: {
                            if (!rowHover.hovered || !menu.open)
                                return ;

                            if (row.kids)
                                menu.openSub(row);
                            else
                                menu.subRow = null;
                        }
                    }

                    TapHandler {
                        id: rowTap

                        onTapped: {
                            if (row.kids) {
                                menu.openSub(row);
                                return ;
                            }
                            menu.open = false;
                            menu.chosen(row.modelData.id);
                        }
                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: menu.open ? Theme.durEnter : Theme.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: menu.open ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: menu.open ? Theme.durEnter : Theme.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: menu.open ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

    }

    // the side panel: as long as the list is, it scrolls past a handful of rows
    Rectangle {
        id: sub

        readonly property bool shown: menu.open && menu.subRow !== null

        x: menu.subToLeft ? -menu.subW - Theme.dp(4) : menu.panelW + Theme.dp(4)
        y: menu.subY
        width: menu.subW
        height: Math.min(menu.subItems.length, menu.subVisibleRows) * Theme.dp(40) + Theme.dp(16)
        radius: Theme.radiusMd
        color: Theme.bg
        opacity: sub.shown ? 1 : 0
        visible: opacity > 0.01
        transformOrigin: menu.subToLeft ? Item.TopRight : Item.TopLeft
        scale: sub.shown ? 1 : 0.95

        ListView {
            id: subList

            anchors.fill: parent
            anchors.margins: Theme.dp(8)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: menu.subItems.length

            delegate: Item {
                id: subRowItem

                required property int index
                readonly property var entry: menu.subItems[subRowItem.index] || ({})

                width: subList.width
                height: Theme.dp(40)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusXs
                    color: Theme.text
                    opacity: subTap.pressed ? Theme.statePressed : (subHover.hovered ? Theme.stateHover : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                DockGlyph {
                    id: subGlyph

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(18)
                    height: Theme.dp(18)
                    pathData: subRowItem.entry.glyph || ""
                    glyphColor: Theme.subtext
                }

                Column {
                    anchors.left: subGlyph.right
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.dp(12)
                    anchors.rightMargin: Theme.dp(10)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: subRowItem.entry.label || ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: !!subRowItem.entry.note
                        text: subRowItem.entry.note || ""
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(10)
                        elide: Text.ElideRight
                    }

                }

                HoverHandler {
                    id: subHover
                }

                TapHandler {
                    id: subTap

                    onTapped: {
                        const id = subRowItem.entry.id;
                        menu.open = false;
                        if (id)
                            menu.chosen(id);

                    }
                }

            }

        }

        // a long list says so: a thin thumb on the edge, only when it scrolls
        Rectangle {
            visible: subList.contentHeight > subList.height + 1
            x: parent.width - Theme.dp(5)
            y: subList.y + subList.visibleArea.yPosition * subList.height
            width: Theme.dp(3)
            height: Math.max(Theme.dp(16), subList.visibleArea.heightRatio * subList.height)
            radius: 1.5
            color: Theme.subtext
            opacity: 0.5
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

}
