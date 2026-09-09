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
    readonly property real panelW: 218
    readonly property real edge: 10
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
        if (Prefs.widgetsEnabled)
            arr.push({
            "id": "addWidget",
            "label": "Add a Widget",
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
            "divider": true
        });

        arr.push({
            "id": "screenshot",
            "label": "Take a Screenshot",
            "glyph": DockIcons.camera,
            "divider": true
        });
        arr.push({
            "id": "settings",
            "label": "Settings",
            "glyph": DockIcons.settings,
            "divider": true
        });
        return arr;
    }

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
        height: list.implicitHeight + 16
        radius: Theme.radiusMd
        color: Theme.bg
        opacity: menu.open ? 1 : 0
        scale: menu.open ? 1 : 0.9
        transformOrigin: menu.toLeft ? (menu.toUp ? Item.BottomRight : Item.TopRight) : (menu.toUp ? Item.BottomLeft : Item.TopLeft)

        Column {
            id: list

            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: menu.actions

                Item {
                    id: row

                    required property var modelData
                    readonly property bool hovered: rowHover.hovered
                    readonly property bool pressed: rowTap.pressed

                    width: list.width
                    height: 40 + (row.modelData.divider ? 9 : 0)

                    Rectangle {
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
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            pathData: row.modelData.glyph
                            glyphColor: Theme.subtext
                        }

                        Text {
                            anchors.left: rowGlyph.right
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
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
