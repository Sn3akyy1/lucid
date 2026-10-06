import "../luciddocks"
import QtQuick
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
    // a menu opens down-right of the cursor, and flips rather than run off screen
    readonly property bool toLeft: menu.originX + menu.panelW + menu.edge > menu.fieldW
    readonly property bool toUp: menu.originY + panel.height + menu.edge > menu.fieldH
    readonly property var actions: {
        var arr = [];
        arr.push({
            "id": "wallpaper",
            "label": "Change Wallpaper",
            "glyph": DockIcons.wallpaper,
            "divider": false
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
        menu.originX = px;
        menu.originY = py;
        menu.open = true;
    }

    width: menu.panelW
    height: panel.height
    x: menu.toLeft ? menu.originX - menu.panelW : menu.originX
    y: menu.toUp ? menu.originY - panel.height : menu.originY
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
                    readonly property bool hovered: rowHover.hovered
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

                        Text {
                            anchors.left: rowGlyph.right
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.dp(12)
                            anchors.rightMargin: Theme.dp(10)
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
                    }

                    TapHandler {
                        id: rowTap

                        onTapped: {
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

}
