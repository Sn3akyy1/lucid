import QtQuick
import qs
import qs.lucidui

// the control centre, built like bricks: its blocks (sliders, toggles, system)
// drawn as the panel lays them out, one under another or side by side. a block
// is dragged by its handle, carrying what it holds; inside it the pieces are
// dragged into order, taken out with their cross and put back from its +. a
// tile is tapped to go big (half a row, with its name) or back to small
Item {
    id: builder

    readonly property bool wide: Prefs.systemPanelStyle === "wide"
    // the blocks shown, in order, then the hidden ones
    readonly property var blockOrder: Prefs.systemBlockKeys.concat(Prefs.systemBlockCatalog.map((b) => {
        return b.key;
    }).filter((k) => {
        return Prefs.systemBlockKeys.indexOf(k) === -1;
    }))
    property bool blockDragging: false
    // the piece being dragged, drawn under the pointer while its place shows faded
    property var ghost: null
    property point ghostAt: Qt.point(0, 0)

    function catalogueOf(block) {
        return block === "sliders" ? Prefs.systemSliderCatalog : (block === "toggles" ? Prefs.systemTileCatalog : Prefs.systemInfoCatalog);
    }

    function keysOf(block) {
        return block === "sliders" ? Prefs.systemSliderKeys : (block === "toggles" ? Prefs.systemTileKeys : Prefs.systemInfoKeys);
    }

    function setKeys(block, keys) {
        if (block === "sliders")
            Prefs.systemSliders = keys.join(",");
        else if (block === "toggles")
            Prefs.setSystemTiles(keys);
        else
            Prefs.systemInfo = keys.join(",");
    }

    function entryOf(block, key) {
        return builder.catalogueOf(block).find((e) => {
            return e.key === key;
        }) || null;
    }

    function setBlockShown(key, on) {
        const l = Prefs.systemBlockKeys.filter((k) => {
            return k !== key;
        });
        if (on)
            l.push(key);

        Prefs.systemBlocks = l.join(",");
    }

    // in the wide panel the tiles take the most room, the sliders the least
    function weightOf(key) {
        return key === "toggles" ? 2 : (key === "system" ? 1.3 : 0.9);
    }

    readonly property real weightSum: Prefs.systemBlockKeys.reduce((w, k) => {
        return w + builder.weightOf(k);
    }, 0)

    width: parent ? parent.width : 0
    implicitHeight: blockFlow.implicitHeight

    ListModel {
        id: blockModel
    }

    function syncBlocks() {
        if (builder.blockDragging)
            return ;

        const now = [];
        for (let i = 0; i < blockModel.count; i++) now.push(blockModel.get(i).key)
        if (now.join(",") === builder.blockOrder.join(","))
            return ;

        blockModel.clear();
        for (const k of builder.blockOrder) blockModel.append({
            "key": k
        })
    }

    onBlockOrderChanged: builder.syncBlocks()
    Component.onCompleted: builder.syncBlocks()

    Flow {
        id: blockFlow

        width: builder.width
        spacing: Theme.dp(12)
        // side by side while wide; the hidden ones wrap under, one under another otherwise
        flow: Flow.LeftToRight

        Repeater {
            id: blockRepeater

            model: blockModel

            BlockCard {
                required property string key
                required property int index

                blockKey: key
                slot: index
                shown: Prefs.systemBlockKeys.indexOf(key) !== -1
                width: {
                    if (!builder.wide || !shown)
                        return builder.width;

                    const free = builder.width - blockFlow.spacing * Math.max(0, Prefs.systemBlockKeys.length - 1);
                    return Math.floor(free * builder.weightOf(key) / Math.max(0.1, builder.weightSum));
                }
            }

        }

    }

    // the dragged piece, over everything
    Item {
        visible: builder.ghost !== null
        x: builder.ghostAt.x - width / 2
        y: builder.ghostAt.y - height / 2
        z: 10
        width: ghostPiece.width
        height: ghostPiece.height

        Piece {
            id: ghostPiece

            block: builder.ghost ? builder.ghost.block : ""
            pieceKey: builder.ghost ? builder.ghost.key : ""
            big: builder.ghost ? builder.ghost.big : false
            lifted: true
        }

    }

    // a block: its handle, name and eye, then the pieces it holds and the ones
    // that can go in it
    component BlockCard: Rectangle {
        id: card

        property string blockKey: ""
        property int slot: 0
        property bool shown: true
        property bool adding: false
        property bool pieceDragging: false
        readonly property var entry: Prefs.systemBlockCatalog.find((b) => {
            return b.key === card.blockKey;
        })
        readonly property var keys: builder.keysOf(card.blockKey)
        readonly property var spare: builder.catalogueOf(card.blockKey).map((e) => {
            return e.key;
        }).filter((k) => {
            return card.keys.indexOf(k) === -1;
        })
        // how far the pointer has carried this block by its handle
        property real dragDX: 0
        property real dragDY: 0

        function syncPieces() {
            if (card.pieceDragging)
                return ;

            const now = [];
            for (let i = 0; i < pieceModel.count; i++) now.push(pieceModel.get(i).key)
            if (now.join(",") === card.keys.join(","))
                return ;

            pieceModel.clear();
            for (const k of card.keys) pieceModel.append({
                "key": k
            })
        }

        function commitPieces() {
            const l = [];
            for (let i = 0; i < pieceModel.count; i++) l.push(pieceModel.get(i).key)
            builder.setKeys(card.blockKey, l);
        }

        // the piece slot under a point given in the pieces' flow, or -1
        function pieceAt(p) {
            for (let i = 0; i < pieceRepeater.count; i++) {
                const it = pieceRepeater.itemAt(i);
                if (it && p.x >= it.x && p.x < it.x + it.width + pieceFlow.spacing && p.y >= it.y && p.y < it.y + it.height + pieceFlow.spacing)
                    return i;

            }
            return -1;
        }

        onKeysChanged: card.syncPieces()
        Component.onCompleted: card.syncPieces()
        implicitHeight: body.implicitHeight + Theme.dp(20)
        height: implicitHeight
        radius: Theme.radiusMd
        color: Theme.bgSunken
        opacity: card.shown ? 1 : 0.6
        border.width: card.dragDX !== 0 || card.dragDY !== 0 ? Theme.dp(2) : 0
        border.color: Theme.accent
        z: card.dragDX !== 0 || card.dragDY !== 0 ? 5 : 0

        transform: Translate {
            x: card.dragDX
            y: card.dragDY
        }

        ListModel {
            id: pieceModel
        }

        Column {
            id: body

            x: Theme.dp(10)
            y: Theme.dp(10)
            width: card.width - Theme.dp(20)
            spacing: Theme.dp(8)

            Item {
                width: parent.width
                height: Theme.dp(32)

                // the handle: dragging it moves the block, with all it holds
                Rectangle {
                    id: handle

                    width: Theme.dp(28)
                    height: Theme.dp(32)
                    radius: Theme.dp(8)
                    color: handleArea.pressed ? Theme.alpha(Theme.text, 0.12) : (handleArea.containsMouse ? Theme.alpha(Theme.text, 0.06) : "transparent")

                    Icon {
                        anchors.centerIn: parent
                        name: "drag_indicator"
                        size: Theme.dp(20)
                        color: Theme.subtext
                    }

                    MouseArea {
                        id: handleArea

                        property point start

                        anchors.fill: parent
                        enabled: card.shown
                        hoverEnabled: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true
                        onPressed: (mouse) => {
                            start = mapToItem(blockFlow, mouse.x, mouse.y);
                            builder.blockDragging = true;
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed)
                                return ;

                            const p = mapToItem(blockFlow, mouse.x, mouse.y);
                            card.dragDX = p.x - start.x;
                            card.dragDY = p.y - start.y;
                            // the shown block whose middle the pointer has passed takes its place
                            const n = Prefs.systemBlockKeys.length;
                            for (let i = 0; i < n; i++) {
                                if (i === card.slot)
                                    continue;

                                const other = blockRepeater.itemAt(i);
                                if (!other)
                                    continue;

                                const mid = builder.wide ? other.x + other.width / 2 : other.y + other.height / 2;
                                const at = builder.wide ? p.x : p.y;
                                if ((i < card.slot && at < mid) || (i > card.slot && at > mid)) {
                                    const before = builder.wide ? card.x : card.y;
                                    blockModel.move(card.slot, i, 1);
                                    // the block jumped; keep it under the pointer
                                    Qt.callLater(() => {
                                        const shift = (builder.wide ? card.x : card.y) - before;
                                        if (builder.wide) {
                                            start.x += shift;
                                            card.dragDX -= shift;
                                        } else {
                                            start.y += shift;
                                            card.dragDY -= shift;
                                        }
                                    });
                                    break;
                                }
                            }
                        }
                        onReleased: {
                            card.dragDX = 0;
                            card.dragDY = 0;
                            builder.blockDragging = false;
                            const l = [];
                            for (let i = 0; i < blockModel.count; i++) {
                                const k = blockModel.get(i).key;
                                if (Prefs.systemBlockKeys.indexOf(k) !== -1)
                                    l.push(k);

                            }
                            Prefs.systemBlocks = l.join(",");
                        }
                        onCanceled: {
                            card.dragDX = 0;
                            card.dragDY = 0;
                            builder.blockDragging = false;
                            builder.syncBlocks();
                        }
                    }

                }

                Icon {
                    id: blockIcon

                    anchors.left: handle.right
                    anchors.leftMargin: Theme.dp(4)
                    anchors.verticalCenter: parent.verticalCenter
                    name: card.entry ? card.entry.icon : ""
                    size: Theme.dp(18)
                    color: Theme.accent
                }

                Text {
                    anchors.left: blockIcon.right
                    anchors.leftMargin: Theme.dp(8)
                    anchors.right: eye.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.entry ? card.entry.name : card.blockKey
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                // shown or hidden; a hidden block keeps what it holds
                M3IconButton {
                    id: eye

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(32)
                    iconPath: card.shown ? "visibility" : "visibility_off"
                    enabled: !card.shown || Prefs.systemBlockKeys.length > 1
                    onClicked: builder.setBlockShown(card.blockKey, !card.shown)
                }

            }

            Flow {
                id: pieceFlow

                visible: card.shown
                width: parent.width
                spacing: Theme.dp(6)

                Repeater {
                    id: pieceRepeater

                    model: pieceModel

                    Item {
                        id: slotItem

                        required property string key
                        required property int index
                        readonly property bool big: card.blockKey === "toggles" && Prefs.systemBigKeys.indexOf(key) !== -1
                        readonly property bool held: builder.ghost !== null && builder.ghost.key === key && builder.ghost.block === card.blockKey
                        // the last slider or card stays; a block can be hidden instead
                        readonly property bool removable: card.blockKey === "toggles" || card.keys.length > 1

                        width: piece.width
                        height: piece.height

                        Piece {
                            id: piece

                            block: card.blockKey
                            pieceKey: slotItem.key
                            big: slotItem.big
                            opacity: slotItem.held ? 0.25 : 1
                            removable: slotItem.removable
                        }

                        // a tap switches a tile's size; a drag moves the piece
                        MouseArea {
                            id: pieceArea

                            property point start
                            property bool moved: false

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: moved ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            preventStealing: true
                            onPressed: (mouse) => {
                                start = Qt.point(mouse.x, mouse.y);
                                moved = false;
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed)
                                    return ;

                                if (!moved && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) < Theme.dp(6))
                                    return ;

                                if (!moved) {
                                    moved = true;
                                    card.pieceDragging = true;
                                    builder.ghost = {
                                        "block": card.blockKey,
                                        "key": slotItem.key,
                                        "big": slotItem.big
                                    };
                                }
                                builder.ghostAt = mapToItem(builder, mouse.x, mouse.y);
                                const to = card.pieceAt(mapToItem(pieceFlow, mouse.x, mouse.y));
                                if (to >= 0 && to !== slotItem.index)
                                    pieceModel.move(slotItem.index, to, 1);

                            }
                            onReleased: {
                                if (moved) {
                                    builder.ghost = null;
                                    card.pieceDragging = false;
                                    card.commitPieces();
                                } else if (card.blockKey === "toggles") {
                                    Prefs.setTileBig(slotItem.key, !slotItem.big);
                                }
                                moved = false;
                            }
                            onCanceled: {
                                builder.ghost = null;
                                card.pieceDragging = false;
                                moved = false;
                                card.syncPieces();
                            }
                        }

                        // its cross, while the pointer is on it
                        Rectangle {
                            visible: slotItem.removable && builder.ghost === null && (pieceArea.containsMouse || crossArea.containsMouse)
                            x: slotItem.width - width + (piece.iconOnly ? -Theme.dp(2) : Theme.dp(4))
                            y: -Theme.dp(4)
                            width: Theme.dp(18)
                            height: Theme.dp(18)
                            radius: width / 2
                            color: Theme.error

                            Icon {
                                anchors.centerIn: parent
                                name: "close"
                                size: Theme.dp(12)
                                color: Theme.fgError
                            }

                            MouseArea {
                                id: crossArea

                                anchors.fill: parent
                                anchors.margins: -Theme.dp(3)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: builder.setKeys(card.blockKey, card.keys.filter((k) => {
                                    return k !== slotItem.key;
                                }))
                            }

                        }

                    }

                }

                // the ones left out, behind a +
                Rectangle {
                    visible: card.spare.length > 0
                    width: Theme.dp(40)
                    height: Theme.dp(40)
                    radius: Theme.dp(12)
                    color: card.adding ? Theme.accent : Theme.alpha(Theme.text, 0.06)

                    Icon {
                        anchors.centerIn: parent
                        name: card.adding ? "close" : "add"
                        size: Theme.dp(20)
                        color: card.adding ? Theme.fgAccent : Theme.subtext
                    }

                    StateLayer {
                        radius: parent.radius
                        tint: card.adding ? Theme.fgAccent : Theme.text
                        onClicked: card.adding = !card.adding
                    }

                }

            }

            // tapping one puts it at the end
            Flow {
                visible: card.shown && card.adding && card.spare.length > 0
                width: parent.width
                spacing: Theme.dp(6)

                Repeater {
                    model: card.adding ? card.spare : []

                    Piece {
                        required property string modelData

                        block: card.blockKey
                        pieceKey: modelData
                        spareLook: true

                        StateLayer {
                            radius: Theme.dp(12)
                            onClicked: builder.setKeys(card.blockKey, card.keys.concat([modelData]))
                        }

                    }

                }

            }

        }

    }

    // one piece: a tile (small, or big with its name), a slider or a card
    component Piece: Item {
        id: pc

        property string block: ""
        property string pieceKey: ""
        property bool big: false
        property bool lifted: false
        property bool spareLook: false
        property bool removable: false
        readonly property var entry: builder.entryOf(pc.block, pc.pieceKey)
        // the toggles' small tiles are icons; everything else carries its name
        readonly property bool iconOnly: pc.block === "toggles" && !pc.big

        width: pc.iconOnly ? Theme.dp(52) : pcRow.implicitWidth + Theme.dp(24)
        height: pc.iconOnly ? Theme.dp(58) : Theme.dp(40)

        Rectangle {
            id: pcFace

            width: pc.iconOnly ? Theme.dp(40) : pc.width
            height: Theme.dp(40)
            anchors.horizontalCenter: parent.horizontalCenter
            radius: pc.iconOnly ? width / 2 : Theme.dp(12)
            color: pc.spareLook ? "transparent" : (pc.big ? Theme.primary : Theme.withBlur(Theme.surfaceHighest))
            border.width: pc.spareLook || pc.lifted ? Theme.dp(1.5) : 0
            border.color: pc.lifted ? Theme.accent : Theme.outline

            Row {
                id: pcRow

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: pc.iconOnly ? undefined : parent.left
                anchors.leftMargin: Theme.dp(12)
                anchors.horizontalCenter: pc.iconOnly ? parent.horizontalCenter : undefined
                spacing: Theme.dp(8)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: pc.entry ? pc.entry.icon : ""
                    size: Theme.dp(20)
                    color: pc.big && !pc.spareLook ? Theme.fgPrimary : Theme.text
                }

                Text {
                    visible: !pc.iconOnly
                    anchors.verticalCenter: parent.verticalCenter
                    text: pc.entry ? pc.entry.name : pc.pieceKey
                    color: pc.big && !pc.spareLook ? Theme.fgPrimary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                }

            }

        }

        Text {
            visible: pc.iconOnly
            anchors.top: pcFace.bottom
            anchors.topMargin: Theme.dp(2)
            anchors.horizontalCenter: parent.horizontalCenter
            width: pc.width
            horizontalAlignment: Text.AlignHCenter
            text: pc.entry ? pc.entry.name : pc.pieceKey
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelSm
            elide: Text.ElideRight
        }

    }

}
