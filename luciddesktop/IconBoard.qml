import QtQuick
import qs

// the desktop icons, drawn on the background layer of the main screen: the
// same surface that keeps the selection box and the right-click menu, so a box
// dragged across the icons never changes hands. Widgets never sit over them -
// the icons step aside - so being a layer below the widgets shows nowhere
Item {
    id: board

    // the nearest icon from the last selected one, in a screen direction
    function step(dx, dy) {
        var from = DesktopIcons.placed[DesktopIcons.anchorKey];
        if (!from) {
            if (DesktopIcons.items.length > 0)
                DesktopIcons.selectOnly(DesktopIcons.items[0].key);

            return ;
        }
        var fx = DesktopIcons.cellX(from.c);
        var fy = DesktopIcons.cellY(from.r);
        var best = "";
        var bd = 1e9;
        var keys = Object.keys(DesktopIcons.placed);
        for (var i = 0; i < keys.length; i++) {
            var p = DesktopIcons.placed[keys[i]];
            var ox = (DesktopIcons.cellX(p.c) - fx) / DesktopIcons.cellW;
            var oy = (DesktopIcons.cellY(p.r) - fy) / DesktopIcons.cellH;
            var along = ox * dx + oy * dy;
            if (along <= 0)
                continue;

            var across = Math.abs(ox * dy) + Math.abs(oy * dx);
            var d = along + across * 2;
            if (d < bd) {
                bd = d;
                best = keys[i];
            }
        }
        if (best !== "")
            DesktopIcons.selectOnly(best);

    }

    anchors.fill: parent
    focus: true
    Component.onCompleted: board.syncTiles()
    Keys.onPressed: (e) => {
        var ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
        var keys = DesktopIcons.selectedKeys;
        // the quick look has the keys while it is open
        if (DesktopIcons.lookKey !== "") {
            if (e.key === Qt.Key_Space || e.key === Qt.Key_Escape) {
                DesktopIcons.closeLook();
            } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) {
                DesktopIcons.lookStep(-1);
            } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) {
                DesktopIcons.lookStep(1);
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                DesktopIcons.openSelection();
                DesktopIcons.closeLook();
            }
            e.accepted = true;
            return ;
        }
        if (e.key === Qt.Key_Space) {
            if (keys.length > 0)
                DesktopIcons.quickLook(DesktopIcons.isSelected(DesktopIcons.anchorKey) ? DesktopIcons.anchorKey : keys[0]);

            e.accepted = true;
            return ;
        }
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            DesktopIcons.openSelection();
        } else if (e.key === Qt.Key_Delete) {
            DesktopIcons.trash(keys);
        } else if (e.key === Qt.Key_F2) {
            if (keys.length === 1 && DesktopIcons.filesOf(keys).length === 1)
                DesktopIcons.renaming = keys[0];

        } else if (e.key === Qt.Key_Escape) {
            DesktopIcons.clearSelection();
        } else if (ctrl && e.key === Qt.Key_A) {
            DesktopIcons.selectAll();
        } else if (ctrl && e.key === Qt.Key_C) {
            DesktopIcons.copy(keys);
        } else if (ctrl && e.key === Qt.Key_V) {
            // a paste from the keyboard lands in the first free cell
            DesktopIcons.menuX = DesktopIcons.cellX(0) + 1;
            DesktopIcons.menuY = DesktopIcons.cellY(0) + 1;
            DesktopIcons.paste();
        } else if (e.key === Qt.Key_Left) {
            board.step(-1, 0);
        } else if (e.key === Qt.Key_Right) {
            board.step(1, 0);
        } else if (e.key === Qt.Key_Up) {
            board.step(0, -1);
        } else if (e.key === Qt.Key_Down) {
            board.step(0, 1);
        } else {
            return ;
        }
        e.accepted = true;
    }

    // one row per name, kept in step with the folder by adding and removing
    // only what came and went: the other icons are never rebuilt, so they
    // neither fade in again nor slide over to a neighbour's place
    function syncTiles() {
        var want = {};
        DesktopIcons.items.forEach((it) => {
            want[it.key] = true;
        });
        var have = {};
        for (var i = tiles.count - 1; i >= 0; i--) {
            var k = tiles.get(i).key;
            if (want[k])
                have[k] = true;
            else
                tiles.remove(i);
        }
        DesktopIcons.items.forEach((it) => {
            if (!have[it.key])
                tiles.append({
                "key": it.key
            });

        });
    }

    ListModel {
        id: tiles
    }

    Connections {
        function onItemsChanged() {
            board.syncTiles();
        }

        target: DesktopIcons
    }

    Repeater {
        model: tiles

        DesktopIcon {
        }

    }

    // while our icons are dragged, the widgets' hitboxes: icons never go
    // under a widget, and some (a silent visualiser) show nothing to say so
    Repeater {
        model: DesktopIcons.dragOver && DesktopIcons.dragKey !== "" ? DesktopIcons.widgetRects : []

        Rectangle {
            id: hitbox

            required property var modelData
            required property int index
            readonly property bool blocking: DesktopIcons.dragBlockers.indexOf(hitbox.index) >= 0
            readonly property color tone: hitbox.blocking ? Theme.error : Theme.text

            x: hitbox.modelData.x
            y: hitbox.modelData.y
            width: hitbox.modelData.w
            height: hitbox.modelData.h
            radius: Theme.radiusSm
            color: Theme.alpha(hitbox.tone, hitbox.blocking ? 0.14 : 0.05)
            border.width: hitbox.blocking ? 2 : 1
            border.color: Theme.alpha(hitbox.tone, hitbox.blocking ? 0.85 : 0.35)

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }

            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Theme.dp(10)
                visible: hitbox.blocking && text !== ""
                text: hitbox.modelData.name
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(13)
                font.weight: Font.DemiBold
            }

        }

    }

    // where a drag of our own icons would put each of them; when a widget
    // holds the cell, the nearest free one the drop steps aside to
    Repeater {
        model: DesktopIcons.dragOver && DesktopIcons.dragKey !== "" && DesktopIcons.dropInto === "" ? DesktopIcons.dragKeys : []

        Rectangle {
            id: ghost

            required property var modelData

            readonly property var spot: DesktopIcons.dragSpot(ghost.modelData)

            visible: ghost.spot !== null
            x: ghost.spot ? DesktopIcons.tileX(ghost.spot.lc) + Theme.dp(4) : 0
            y: ghost.spot ? DesktopIcons.tileY(ghost.spot.lr) + Theme.dp(2) : 0
            width: DesktopIcons.tileW - Theme.dp(8)
            height: DesktopIcons.tileH - Theme.dp(4)
            radius: Theme.radiusSm
            color: Theme.alpha(Theme.accent, 0.12)
            border.width: 1.5
            border.color: Theme.alpha(Theme.accent, 0.75)
        }

    }

    // the selection box, drawn over the icons
    Rectangle {
        x: DesktopIcons.band.x
        y: DesktopIcons.band.y
        width: DesktopIcons.band.width
        height: DesktopIcons.band.height
        visible: DesktopIcons.banding
        z: 10
        radius: Math.min(4, width / 2, height / 2)
        color: Theme.alpha(Theme.accent, 0.16)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.8)
        antialiasing: true
    }

    QuickLook {
        z: 20
    }

}
