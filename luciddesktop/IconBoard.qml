import QtQuick
import qs
import qs.lucidui

// the desktop icons on the main screen's background layer: the same surface as
// the selection box and the right-click menu, so a box across the icons never
// changes hands. widgets never sit over them, the icons step aside
Item {
    id: board

    // the nearest icon from the cursor one, in a screen direction
    function step(dx, dy, extend) {
        var fromKey = DesktopIcons.placed[DesktopIcons.cursorKey] ? DesktopIcons.cursorKey : DesktopIcons.anchorKey;
        var from = DesktopIcons.placed[fromKey];
        if (!from) {
            board.first();
            return ;
        }
        var fx = DesktopIcons.cellX(from.c);
        var fy = DesktopIcons.cellY(from.r);
        var best = "";
        var bd = 1e+09;
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
        if (best === "")
            return ;

        if (extend)
            DesktopIcons.selectRange(best);
        else
            DesktopIcons.selectOnly(best);
    }

    function first() {
        var keys = DesktopIcons.inGridOrder(Object.keys(DesktopIcons.placed));
        if (keys.length > 0)
            DesktopIcons.selectOnly(keys[0]);

    }

    function last() {
        var keys = DesktopIcons.inGridOrder(Object.keys(DesktopIcons.placed));
        if (keys.length > 0)
            DesktopIcons.selectOnly(keys[keys.length - 1]);

    }

    // one row per name, kept in step with the folder by adding only what came: the
    // rest are never rebuilt. what went is marked gone, plays its way out, and asks
    // to be removed (dispose)
    function syncTiles() {
        var want = {};
        DesktopIcons.items.forEach((it) => {
            want[it.key] = true;
        });
        var have = {};
        for (var i = tiles.count - 1; i >= 0; i--) {
            var row = tiles.get(i);
            if (want[row.key]) {
                have[row.key] = true;
                if (row.gone)
                    tiles.setProperty(i, "gone", false);

            } else if (!row.gone) {
                tiles.setProperty(i, "gone", true);
            }
        }
        DesktopIcons.items.forEach((it) => {
            if (!have[it.key])
                tiles.append({
                "key": it.key,
                "gone": false
            });

        });
    }

    function dispose(key) {
        for (var i = tiles.count - 1; i >= 0; i--) {
            var row = tiles.get(i);
            if (row.key === key && row.gone)
                tiles.remove(i);

        }
    }

    // quick look or get info is up, or shrinking back: the layer lifts over the windows for it
    readonly property bool looking: look.active || infoLoader.active

    anchors.fill: parent
    focus: true
    Component.onCompleted: board.syncTiles()
    Keys.onPressed: (e) => {
        return board.handleKey(e);
    }

    function handleKey(e) {
        var shift = (e.modifiers & Qt.ShiftModifier) !== 0;
        var keys = DesktopIcons.selectedKeys;
        var act = DesktopIcons.actionFor(Keybinds.comboFromEvent(e));
        // get info, then quick look, have the keys while they are open
        if (DesktopIcons.infoKey !== "") {
            if (e.key === Qt.Key_Escape || act === "info")
                DesktopIcons.closeInfo();

            e.accepted = true;
            return ;
        }
        if (DesktopIcons.lookKey !== "") {
            if (e.key === Qt.Key_Escape || act === "look") {
                DesktopIcons.closeLook();
            } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) {
                DesktopIcons.lookStep(-1);
            } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) {
                DesktopIcons.lookStep(1);
            } else if (act === "open") {
                DesktopIcons.openSelection();
                DesktopIcons.closeLook();
            }
            e.accepted = true;
            return ;
        }
        // a space halfway through typing a name belongs to the name
        if (DesktopIcons.typed !== "" && e.key === Qt.Key_Space && e.modifiers === Qt.NoModifier) {
            DesktopIcons.typeAhead(" ");
            e.accepted = true;
            return ;
        }
        // everything remappable, from settings > keybinds
        if (act !== "") {
            DesktopIcons.doKey(act);
            e.accepted = true;
            return ;
        }
        // and what stays put, the way it does in any file manager
        if (e.key === Qt.Key_Escape) {
            DesktopIcons.clearSelection();
        } else if (e.key === Qt.Key_Menu || (shift && e.key === Qt.Key_F10)) {
            var at = DesktopIcons.placed[DesktopIcons.cursorKey] || DesktopIcons.placed[keys[0]];
            if (keys.length > 0 && at)
                DesktopIcons.openMenu(keys, DesktopIcons.tileX(at.c) + DesktopIcons.tileW / 2, DesktopIcons.tileY(at.r) + DesktopIcons.iconPx);

        } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            DesktopIcons.focusVisible = true;
            board.step(e.key === Qt.Key_Left ? -1 : (e.key === Qt.Key_Right ? 1 : 0), e.key === Qt.Key_Up ? -1 : (e.key === Qt.Key_Down ? 1 : 0), shift);
        } else if (e.key === Qt.Key_Home) {
            DesktopIcons.focusVisible = true;
            board.first();
        } else if (e.key === Qt.Key_End) {
            DesktopIcons.focusVisible = true;
            board.last();
        } else if ((e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0 && e.text.length === 1 && e.text.charCodeAt(0) > 32) {
            DesktopIcons.typeAhead(e.text);
        } else {
            return ;
        }
        e.accepted = true;
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

    // the icons step back while quick look or get info is lifted over the windows, or they would float over them too
    Item {
        anchors.fill: parent
        opacity: 1 - Math.max(look.item ? look.item.t : 0, infoLoader.item ? infoLoader.item.t : 0)
        visible: opacity > 0.01

        Repeater {
            model: tiles

            DesktopIcon {
                host: board
            }

        }

    }

    // while our icons are dragged, the widgets' hitboxes: an icon never goes
    // under one, and some (a silent visualiser) show nothing to say so
    Repeater {
        model: DesktopIcons.dragOver && DesktopIcons.dragKey !== "" ? DesktopIcons.widgetRects : []

        Rectangle {
            id: hitbox

            required property var modelData
            required property int index
            readonly property bool blocking: DesktopIcons.dragBlockers.indexOf(hitbox.index) >= 0
            readonly property color tone: hitbox.blocking ? Theme.error : "#ffffff"

            x: hitbox.modelData.x
            y: hitbox.modelData.y
            width: hitbox.modelData.w
            height: hitbox.modelData.h
            radius: Theme.radiusMd
            color: Theme.alpha(hitbox.tone, hitbox.blocking ? 0.14 : 0.05)
            // the card sits a layer above and covers the fill: the edge has to say it
            border.width: hitbox.blocking ? 3 : 1
            border.color: Theme.alpha(hitbox.tone, hitbox.blocking ? 0.85 : 0.35)

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Theme.dp(10)
                visible: hitbox.blocking && text !== ""
                text: hitbox.modelData.name
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.DemiBold
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

        }

    }

    // where each of our dragged icons would land; next to a widget in the way, the free cell it steps aside to
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
            color: Theme.alpha(Theme.accent, 0.14)
            border.width: 1
            border.color: Theme.alpha(Theme.accent, 0.75)
        }

    }

    // where an app pulled off the dock will land
    Rectangle {
        readonly property var spot: DesktopIcons.appSpot

        visible: spot !== null
        x: spot ? DesktopIcons.tileX(spot.c) + Theme.dp(4) : 0
        y: spot ? DesktopIcons.tileY(spot.r) + Theme.dp(2) : 0
        width: DesktopIcons.tileW - Theme.dp(8)
        height: DesktopIcons.tileH - Theme.dp(4)
        radius: Theme.radiusMd
        color: Theme.alpha(Theme.accent, 0.14)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.75)

        Behavior on x {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.OutCubic
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.OutCubic
            }

        }

    }

    // the selection box, drawn over the icons, with how many it holds on its corner.
    // square, on whole pixels, a solid edge over a clear tint, as Desktop's own box
    Rectangle {
        id: band

        readonly property int count: DesktopIcons.selectedKeys.length

        x: Math.round(DesktopIcons.band.x)
        y: Math.round(DesktopIcons.band.y)
        width: Math.round(DesktopIcons.band.width)
        height: Math.round(DesktopIcons.band.height)
        visible: DesktopIcons.banding
        z: 10
        color: Theme.alpha(Theme.accent, 0.28)
        border.width: 1
        border.color: Theme.accent
        antialiasing: false

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(6)
            width: bandCount.implicitWidth + Theme.dp(14)
            height: Theme.dp(22)
            radius: height / 2
            color: Theme.accentContainer
            visible: band.count > 0 && band.width > width + Theme.dp(12) && band.height > height + Theme.dp(12)

            Text {
                id: bandCount

                anchors.centerIn: parent
                text: band.count + " selected"
                color: Theme.fgAccentContainer
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelMd
                font.weight: Font.DemiBold
            }

        }

    }

    // what letting go would do, beside the pointer: move to a folder, copy with ctrl, the trash...
    Rectangle {
        id: hint

        readonly property bool on: DesktopIcons.dragOver && DesktopIcons.dropHint !== ""

        x: Math.round(Math.min(board.width - width - Theme.dp(8), DesktopIcons.dragX + Theme.dp(18)))
        y: Math.round(Math.min(board.height - height - Theme.dp(8), DesktopIcons.dragY + Theme.dp(26)))
        z: 30
        width: hintRow.implicitWidth + Theme.dp(20)
        height: Theme.dp(30)
        radius: height / 2
        color: Theme.surfaceHighest
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.08)
        opacity: hint.on ? 1 : 0
        visible: opacity > 0.01

        Row {
            id: hintRow

            anchors.centerIn: parent
            spacing: Theme.dp(6)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.dp(16)
                name: DesktopIcons.dropHintIcon
                color: Theme.accent
                fill: 1
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: DesktopIcons.dropHint
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.Medium
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

    // a moment on an icon: what it is, how big, when it changed
    Rectangle {
        id: tip

        property string key: ""
        readonly property var it: DesktopIcons.byKey[tip.key] || null
        readonly property var spot: DesktopIcons.placed[tip.key] || null
        readonly property var peek: tip.it && (tip.it.kind === "dir" || tip.it.kind === "home") ? DesktopIcons.peeks[tip.it.path] : undefined
        readonly property bool wanted: tip.key !== "" && DesktopIcons.hoverKey === tip.key && !DesktopIcons.dragOver && DesktopIcons.lookKey === "" && DesktopIcons.renaming === "" && !DesktopIcons.banding && !DesktopIcons.tipHold
        readonly property real maxW: Theme.dp(280)
        readonly property bool toLeft: tip.spot ? DesktopIcons.tileX(tip.spot.c) + DesktopIcons.tileW + Theme.dp(6) + tip.width > board.width - Theme.dp(8) : false
        readonly property string detail: {
            var it = tip.it;
            if (!it)
                return "";

            var parts = [];
            if (it.kind === "file" || it.kind === "app")
                parts.push(it.desc);

            if (it.kind === "file")
                parts.push(DesktopIcons.human(it.size));

            if (it.kind === "dir" || it.kind === "home")
                parts.push(tip.peek ? (tip.peek.count === 0 ? "Empty folder" : (tip.peek.count === 1 ? "1 item" : tip.peek.count + " items")) : "Folder");

            if (it.kind === "trash" || it.kind === "drive")
                parts.push(it.desc);

            return parts.filter((x) => {
                return x;
            }).join("  ·  ");
        }

        function show() {
            tip.key = DesktopIcons.hoverKey;
            if (tip.it && (tip.it.kind === "dir" || tip.it.kind === "home"))
                DesktopIcons.peek(tip.it.path);

        }

        z: 30
        visible: opacity > 0.01
        opacity: tip.wanted && tip.spot !== null ? 1 : 0
        width: Math.min(tip.maxW, Math.max(tipName.implicitWidth, tipDetail.implicitWidth, tipWhen.implicitWidth) + Theme.dp(24))
        height: tipCol.implicitHeight + Theme.dp(18)
        x: !tip.spot ? 0 : (tip.toLeft ? DesktopIcons.tileX(tip.spot.c) - tip.width - Theme.dp(6) : DesktopIcons.tileX(tip.spot.c) + DesktopIcons.tileW + Theme.dp(6))
        y: !tip.spot ? 0 : Math.max(Theme.dp(8), Math.min(board.height - tip.height - Theme.dp(8), DesktopIcons.tileY(tip.spot.r) + Theme.dp(10)))
        radius: Theme.radiusSm
        color: Theme.surfaceHigh
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.08)

        Connections {
            function onHoverKeyChanged() {
                if (DesktopIcons.hoverKey !== "" && tip.opacity > 0.5)
                    tip.show();
                else if (DesktopIcons.hoverKey !== "")
                    tipTimer.restart();
                else
                    tipTimer.stop();
            }

            target: DesktopIcons
        }

        Timer {
            id: tipTimer

            interval: 700
            onTriggered: tip.show()
        }

        Column {
            id: tipCol

            x: Theme.dp(12)
            y: Theme.dp(9)
            width: tip.width - Theme.dp(24)
            spacing: Theme.dp(2)

            Text {
                id: tipName

                width: Math.min(implicitWidth, parent.width)
                text: tip.it ? tip.it.label : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.DemiBold
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Text {
                id: tipDetail

                visible: text !== ""
                width: Math.min(implicitWidth, parent.width)
                text: tip.detail
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelMd
                elide: Text.ElideRight
            }

            Text {
                id: tipWhen

                visible: text !== ""
                width: Math.min(implicitWidth, parent.width)
                text: tip.it && tip.it.mtime ? "Modified " + DesktopIcons.when(tip.it.mtime) : ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelMd
                elide: Text.ElideRight
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: tip.wanted ? Theme.durShort : Theme.durQuick
            }

        }

    }

    // space on an icon; built only while one is open, and kept until it has shrunk away
    Loader {
        id: look

        property bool keep: false

        anchors.fill: parent
        z: 20
        active: DesktopIcons.lookKey !== "" || look.keep

        Connections {
            function onLookKeyChanged() {
                if (DesktopIcons.lookKey !== "")
                    look.keep = true;

            }

            target: DesktopIcons
        }

        Connections {
            function onClosed() {
                look.keep = false;
            }

            target: look.item
            ignoreUnknownSignals: true
        }

        sourceComponent: QuickLook {
        }

    }

    // get info: the file's details on a sheet; built only while it is open
    Loader {
        id: infoLoader

        property bool keep: false

        anchors.fill: parent
        z: 21
        active: DesktopIcons.infoKey !== "" || infoLoader.keep

        Connections {
            function onInfoKeyChanged() {
                if (DesktopIcons.infoKey !== "")
                    infoLoader.keep = true;

            }

            target: DesktopIcons
        }

        Connections {
            function onClosed() {
                infoLoader.keep = false;
            }

            target: infoLoader.item
            ignoreUnknownSignals: true
        }

        sourceComponent: IconInfo {
        }

    }

}
