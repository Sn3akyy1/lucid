import QtQuick
import qs
import qs.lucidui

// the control centre, built like bricks: its blocks (sliders, toggles, system)
// drawn on the panel's own grid, to its measures, one under another or side by
// side. a block is dragged by its handle, carrying what it holds; inside it the
// pieces are dragged into order, taken out with their cross and put back from
// its +. a tile is tapped to go big (half a row, with its name) or back to small
Item {
    id: builder

    // the panel goes wide only with more than one block to lay side by side
    readonly property bool wide: Prefs.systemPanelStyle === "wide" && Prefs.systemBlockKeys.length > 1
    // the panel's measures, as System.qml takes them: its column, the gaps, the
    // six tiles to a row, the standing sliders and the system block's width
    readonly property real col: Theme.dp(400) - Theme.dp(32)
    readonly property real tileGap: Theme.dp(8)
    readonly property int cols: 6
    readonly property real smallTile: Math.floor((builder.col - builder.tileGap * (builder.cols - 1)) / builder.cols)
    readonly property real bigTile: Math.floor((builder.col - builder.tileGap) / 2)
    readonly property real vSlider: Theme.dp(56)
    readonly property real systemCol: Theme.dp(296)
    // a block's card: its padding, the least it can be to hold its header, and the gap between two
    readonly property real cardPad: Theme.dp(8)
    readonly property real minCard: Theme.dp(100)
    readonly property real cardGap: Theme.dp(10)
    // how much the panel is drawn down to fit the page
    readonly property real k: {
        const keys = Prefs.systemBlockKeys;
        if (!builder.wide)
            return Math.max(0.3, Math.min(1, (builder.width - builder.cardPad * 2) / builder.col));

        // a block too narrow for its header keeps the card's least width, and the rest share what is left
        let room = builder.width - builder.cardGap * (keys.length - 1);
        let real = 0;
        for (const key of keys) {
            room -= builder.cardPad * 2;
            real += builder.realWidth(key);
        }
        let scale = room / Math.max(1, real);
        for (const key of keys) {
            if (builder.realWidth(key) * scale + builder.cardPad * 2 < builder.minCard) {
                room -= builder.minCard - builder.cardPad * 2;
                real -= builder.realWidth(key);
            }
        }
        scale = room / Math.max(1, real);
        return Math.max(0.3, Math.min(1, scale));
    }
    // the standing sliders reach as far down as the tallest of the rest
    property real togglesH: 0
    property real systemH: 0
    readonly property real tallH: Math.max(Theme.dp(240) * builder.k, Prefs.systemBlockKeys.indexOf("toggles") !== -1 ? builder.togglesH : 0, Prefs.systemBlockKeys.indexOf("system") !== -1 ? builder.systemH : 0)
    readonly property var hiddenKeys: Prefs.systemBlockCatalog.map((b) => {
        return b.key;
    }).filter((key) => {
        return Prefs.systemBlockKeys.indexOf(key) === -1;
    })
    property bool blockDragging: false
    // the piece being dragged, drawn under the pointer while its place shows faded
    property var ghost: null
    property point ghostAt: Qt.point(0, 0)

    // a block's width on the panel
    function realWidth(key) {
        if (!builder.wide || key === "toggles")
            return builder.col;

        if (key === "sliders") {
            const n = Math.max(1, Prefs.systemSliderKeys.length);
            return n * builder.vSlider + (n - 1) * builder.tileGap;
        }
        return builder.systemCol;
    }

    function cardWidth(key) {
        return Math.max(builder.wide ? builder.minCard : 0, Math.round(builder.realWidth(key) * builder.k) + builder.cardPad * 2);
    }

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

    function syncBlocks() {
        if (builder.blockDragging)
            return ;

        const now = [];
        for (let i = 0; i < blockModel.count; i++) now.push(blockModel.get(i).key)
        if (now.join(",") === Prefs.systemBlockKeys.join(","))
            return ;

        blockModel.clear();
        for (const k of Prefs.systemBlockKeys) blockModel.append({
            "key": k
        })
    }

    width: parent ? parent.width : 0
    implicitHeight: blockFlow.height + (builder.hiddenKeys.length > 0 ? hiddenRow.height + Theme.dp(12) : 0)
    Component.onCompleted: builder.syncBlocks()

    Connections {
        function onSystemBlockKeysChanged() {
            builder.syncBlocks();
        }

        target: Prefs
    }

    ListModel {
        id: blockModel
    }

    Flow {
        id: blockFlow

        // side by side while wide, one under another otherwise; centred, as the panel is
        width: builder.wide ? Prefs.systemBlockKeys.reduce((w, key) => {
            return w + builder.cardWidth(key);
        }, 0) + builder.cardGap * (Prefs.systemBlockKeys.length - 1) : builder.cardWidth("toggles")
        x: Math.max(0, Math.round((builder.width - width) / 2))
        spacing: builder.cardGap

        Repeater {
            id: blockRepeater

            model: blockModel

            BlockCard {
                required property string key
                required property int index

                blockKey: key
                slot: index
                width: builder.cardWidth(key)
            }

        }

    }

    // the blocks left out, each with its eye to bring it back
    Row {
        id: hiddenRow

        visible: builder.hiddenKeys.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: blockFlow.height + Theme.dp(12)
        spacing: Theme.dp(8)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Hidden"
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
        }

        Repeater {
            model: builder.hiddenKeys

            Rectangle {
                id: hiddenChip

                required property string modelData
                readonly property var entry: Prefs.systemBlockCatalog.find((b) => {
                    return b.key === hiddenChip.modelData;
                })

                width: hiddenChipRow.implicitWidth + Theme.dp(20)
                height: Theme.dp(36)
                radius: height / 2
                color: "transparent"
                border.width: Theme.dp(1.5)
                border.color: Theme.outline

                Row {
                    id: hiddenChipRow

                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: hiddenChip.entry ? hiddenChip.entry.icon : ""
                        size: Theme.dp(18)
                        color: Theme.subtext
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: hiddenChip.entry ? hiddenChip.entry.name : hiddenChip.modelData
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "visibility_off"
                        size: Theme.dp(18)
                        color: Theme.subtext
                    }

                }

                StateLayer {
                    radius: parent.radius
                    onClicked: builder.setBlockShown(hiddenChip.modelData, true)
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
            width: builder.ghost ? builder.ghost.w : 0
            height: builder.ghost ? builder.ghost.h : 0
            lifted: true
        }

    }

    // a block: its handle, name, + and eye, then what it holds on the panel's
    // grid, and the pieces that can go in it
    component BlockCard: Rectangle {
        id: card

        property string blockKey: ""
        property int slot: 0
        property bool adding: false
        property bool pieceDragging: false
        // the pieces in the order shown, while one is dragged too
        property var order: []
        readonly property var entry: Prefs.systemBlockCatalog.find((b) => {
            return b.key === card.blockKey;
        })
        readonly property var keys: builder.keysOf(card.blockKey)
        readonly property var spare: builder.catalogueOf(card.blockKey).map((e) => {
            return e.key;
        }).filter((k) => {
            return card.keys.indexOf(k) === -1;
        })
        // the room the block takes on the panel, drawn down
        readonly property real bodyW: Math.round(builder.realWidth(card.blockKey) * builder.k)
        readonly property bool narrow: card.width < Theme.dp(170)
        // how far the pointer has carried this block by its handle
        property real dragDX: 0
        property real dragDY: 0

        function syncPieces() {
            if (card.pieceDragging)
                return ;

            const now = [];
            for (let i = 0; i < pieceModel.count; i++) now.push(pieceModel.get(i).key)
            if (now.join(",") === card.keys.join(",")) {
                card.order = now;
                return ;
            }
            pieceModel.clear();
            for (const k of card.keys) pieceModel.append({
                "key": k
            })
            card.order = card.keys.slice();
        }

        function readOrder() {
            const l = [];
            for (let i = 0; i < pieceModel.count; i++) l.push(pieceModel.get(i).key)
            card.order = l;
            return l;
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

        // the system block reads as cards: a run of gauges shares a row, all
        // of them on the single column, two to a row on the wide panel
        function gaugeCols(i) {
            let a = i, b = i;
            while (a > 0 && card.order[a - 1] !== "media")
                a--;
            while (b < card.order.length - 1 && card.order[b + 1] !== "media")
                b++;
            const run = b - a + 1;
            return builder.wide ? Math.min(2, run) : run;
        }

        function pieceW(key, big, i) {
            if (card.blockKey === "toggles")
                return Math.floor((big ? builder.bigTile : builder.smallTile) * builder.k);

            if (card.blockKey === "sliders")
                return builder.wide ? Math.floor(builder.vSlider * builder.k) : card.bodyW;

            if (key === "media")
                return card.bodyW;

            const n = Math.max(1, card.gaugeCols(i));
            return Math.floor((card.bodyW - pieceFlow.spacing * (n - 1)) / n);
        }

        function pieceH(key, big, i) {
            if (card.blockKey === "toggles")
                return Math.round((big ? Theme.dp(64) : builder.smallTile + Theme.dp(24)) * builder.k);

            if (card.blockKey === "sliders")
                return builder.wide ? builder.tallH : Math.round(Theme.dp(50) * builder.k);

            if (key === "media")
                return Math.round(Theme.dp(84) * builder.k);

            // a gauge: its ring, as wide as its share allows, with the name under it
            const real = card.pieceW(key, big, i) / builder.k;
            return Math.round((Math.max(Theme.dp(54), Math.min(Theme.dp(84), real - Theme.dp(20))) + Theme.dp(44)) * builder.k);
        }

        // where each run of gauges sits, for the card it shares drawn behind it
        readonly property var runs: {
            if (card.blockKey !== "system")
                return [];

            const out = [];
            const gap = Math.round(builder.tileGap * builder.k);
            let y = 0;
            let i = 0;
            while (i < card.order.length) {
                if (card.order[i] === "media") {
                    y += card.pieceH("media", false, i) + gap;
                    i++;
                    continue;
                }
                let j = i;
                while (j < card.order.length && card.order[j] !== "media")
                    j++;
                const rows = Math.ceil((j - i) / card.gaugeCols(i));
                const h = rows * card.pieceH(card.order[i], false, i) + (rows - 1) * gap;
                out.push({
                    "y": y,
                    "h": h
                });
                y += h + gap;
                i = j;
            }
            return out;
        }

        onKeysChanged: card.syncPieces()
        Component.onCompleted: card.syncPieces()
        implicitHeight: body.implicitHeight + builder.cardPad * 2
        height: implicitHeight
        radius: Theme.radiusMd
        color: Theme.bgSunken
        border.width: card.dragDX !== 0 || card.dragDY !== 0 ? Theme.dp(2) : 0
        border.color: Theme.accent
        z: card.dragDX !== 0 || card.dragDY !== 0 ? 5 : 0

        // the sliders stand as tall as these two
        Binding {
            when: card.blockKey === "toggles"
            target: builder
            property: "togglesH"
            value: pieceFlow.implicitHeight
        }

        Binding {
            when: card.blockKey === "system"
            target: builder
            property: "systemH"
            value: pieceFlow.implicitHeight
        }

        ListModel {
            id: pieceModel
        }

        Column {
            id: body

            x: builder.cardPad
            y: builder.cardPad
            width: card.width - builder.cardPad * 2
            spacing: Theme.dp(8)

            Item {
                width: parent.width
                height: Theme.dp(30)

                // the handle: dragging it moves the block, with all it holds
                Rectangle {
                    id: handle

                    width: Theme.dp(26)
                    height: Theme.dp(30)
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
                        enabled: Prefs.systemBlockKeys.length > 1
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
                            // the block whose middle the pointer has passed takes its place
                            for (let i = 0; i < blockModel.count; i++) {
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
                            for (let i = 0; i < blockModel.count; i++) l.push(blockModel.get(i).key)
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

                    visible: !card.narrow
                    anchors.left: handle.right
                    anchors.leftMargin: Theme.dp(4)
                    anchors.verticalCenter: parent.verticalCenter
                    name: card.entry ? card.entry.icon : ""
                    size: Theme.dp(18)
                    color: Theme.accent
                }

                Text {
                    visible: !card.narrow
                    anchors.left: blockIcon.right
                    anchors.leftMargin: Theme.dp(8)
                    anchors.right: addBtn.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.entry ? card.entry.name : card.blockKey
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                // the ones left out, behind a +
                M3IconButton {
                    id: addBtn

                    anchors.right: eye.left
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(30)
                    enabled: card.spare.length > 0
                    iconPath: card.adding && card.spare.length > 0 ? "close" : "add"
                    onClicked: card.adding = !card.adding
                }

                // hiding a block keeps what it holds
                M3IconButton {
                    id: eye

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(30)
                    iconPath: "visibility"
                    enabled: Prefs.systemBlockKeys.length > 1
                    onClicked: builder.setBlockShown(card.blockKey, false)
                }

            }

            // what the block holds, on the panel's grid
            Item {
                width: parent.width
                height: pieceFlow.implicitHeight

                Repeater {
                    model: card.runs

                    Rectangle {
                        required property var modelData

                        x: pieceFlow.x
                        y: modelData.y
                        width: card.bodyW
                        height: modelData.h
                        radius: Math.round(Theme.dp(20) * builder.k)
                        color: Theme.withBlur(Theme.surfaceHigh)
                    }

                }

                Flow {
                    id: pieceFlow

                    x: Math.max(0, Math.round((parent.width - width) / 2))
                    width: card.bodyW
                    spacing: Math.round(builder.tileGap * builder.k)
                    // the sliders stand side by side on the wide panel and lie one under another otherwise
                    flow: Flow.LeftToRight

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

                            width: card.pieceW(key, big, index)
                            height: card.pieceH(key, big, index)

                            Piece {
                                id: piece

                                anchors.fill: parent
                                block: card.blockKey
                                pieceKey: slotItem.key
                                big: slotItem.big
                                opacity: slotItem.held ? 0.25 : 1
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
                                            "big": slotItem.big,
                                            "w": slotItem.width,
                                            "h": slotItem.height
                                        };
                                    }
                                    builder.ghostAt = mapToItem(builder, mouse.x, mouse.y);
                                    const to = card.pieceAt(mapToItem(pieceFlow, mouse.x, mouse.y));
                                    if (to >= 0 && to !== slotItem.index) {
                                        pieceModel.move(slotItem.index, to, 1);
                                        card.readOrder();
                                    }
                                }
                                onReleased: {
                                    if (moved) {
                                        builder.ghost = null;
                                        card.pieceDragging = false;
                                        builder.setKeys(card.blockKey, card.readOrder());
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
                                x: slotItem.width - width + Theme.dp(4)
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

                }

            }

            // tapping one puts it at the end
            Flow {
                visible: card.adding && card.spare.length > 0
                width: parent.width
                spacing: Theme.dp(6)

                Repeater {
                    model: card.adding ? card.spare : []

                    Rectangle {
                        id: spareChip

                        required property string modelData
                        readonly property var entry: builder.entryOf(card.blockKey, spareChip.modelData)

                        width: Math.min(parent.width, spareRow.implicitWidth + Theme.dp(20))
                        height: Theme.dp(34)
                        radius: Theme.dp(12)
                        color: "transparent"
                        border.width: Theme.dp(1.5)
                        border.color: Theme.outline
                        clip: true

                        Row {
                            id: spareRow

                            anchors.centerIn: parent
                            spacing: Theme.dp(6)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: spareChip.entry ? spareChip.entry.icon : ""
                                size: Theme.dp(18)
                                color: Theme.text
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: spareChip.entry ? spareChip.entry.name : spareChip.modelData
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabelLg
                            }

                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: builder.setKeys(card.blockKey, card.keys.concat([spareChip.modelData]))
                        }

                    }

                }

            }

        }

    }

    // one piece, drawn as the panel draws it: a round tile with its name under
    // it or a big one with the name inside, a slider lying or standing, the
    // media card or a gauge
    component Piece: Item {
        id: pc

        property string block: ""
        property string pieceKey: ""
        property bool big: false
        property bool lifted: false
        readonly property var entry: builder.entryOf(pc.block, pc.pieceKey)
        readonly property string look: {
            if (pc.block === "toggles")
                return pc.big ? "big" : "tile";

            if (pc.block === "sliders")
                return builder.wide ? "standing" : "lying";

            return pc.pieceKey === "media" ? "media" : "gauge";
        }
        readonly property string name: pc.entry ? pc.entry.name : pc.pieceKey
        readonly property string icon: pc.entry ? pc.entry.icon : ""
        readonly property real iconSize: Math.max(Theme.dp(14), Math.round(Theme.dp(20) * builder.k))

        // a small tile: a circle, its name in the gap under it
        Rectangle {
            id: tileFace

            visible: pc.look === "tile"
            width: pc.width
            height: pc.width
            radius: width / 2
            color: Theme.withBlur(Theme.surfaceHighest)
            border.width: pc.lifted ? Theme.dp(1.5) : 0
            border.color: Theme.accent

            Icon {
                anchors.centerIn: parent
                name: pc.icon
                size: pc.iconSize
                color: Theme.text
            }

        }

        Text {
            visible: pc.look === "tile"
            anchors.top: tileFace.bottom
            anchors.topMargin: Theme.dp(2)
            width: pc.width + Theme.dp(6)
            x: -Theme.dp(3)
            horizontalAlignment: Text.AlignHCenter
            text: pc.name
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelSm
            elide: Text.ElideRight
        }

        // a big tile, the lying slider and the media card: a bar with the name in it
        Rectangle {
            visible: pc.look === "big" || pc.look === "lying" || pc.look === "media"
            width: pc.width
            height: pc.look === "lying" ? Math.round(Theme.dp(38) * builder.k) : pc.height
            anchors.verticalCenter: parent.verticalCenter
            radius: Math.round((pc.look === "big" ? Theme.dp(18) : Theme.dp(12)) * builder.k)
            color: pc.look === "big" ? Theme.primary : Theme.withBlur(pc.look === "media" ? Theme.surfaceHigh : Theme.surfaceHighest)
            border.width: pc.lifted ? Theme.dp(1.5) : 0
            border.color: Theme.accent
            clip: true

            // the lying slider shows its fill, as the panel's does
            Rectangle {
                visible: pc.look === "lying"
                width: parent.width * 0.55
                height: parent.height
                radius: parent.radius
                color: Theme.alpha(Theme.primary, 0.35)
            }

            // the media card's cover
            Rectangle {
                id: cover

                visible: pc.look === "media"
                x: Math.round(Theme.dp(10) * builder.k)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(Theme.dp(64) * builder.k)
                height: width
                radius: Math.round(Theme.dp(12) * builder.k)
                color: Theme.withBlur(Theme.surfaceHighest)

                Icon {
                    anchors.centerIn: parent
                    name: pc.icon
                    size: pc.iconSize
                    color: Theme.subtext
                }

            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: pc.look === "media" ? cover.x + cover.width + Math.round(Theme.dp(12) * builder.k) : Math.round(Theme.dp(12) * builder.k)
                width: parent.width - x - Theme.dp(6)
                spacing: Theme.dp(8)

                Icon {
                    id: barIcon

                    visible: pc.look !== "media"
                    anchors.verticalCenter: parent.verticalCenter
                    name: pc.icon
                    size: pc.iconSize
                    color: pc.look === "big" ? Theme.fgPrimary : Theme.text
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (barIcon.visible ? barIcon.width + parent.spacing : 0)
                    text: pc.name
                    color: pc.look === "big" ? Theme.fgPrimary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: pc.look === "big" ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

            }

        }

        // the standing slider: filled from the foot, its icon at the bottom
        Rectangle {
            visible: pc.look === "standing"
            anchors.fill: parent
            radius: Math.round(Theme.dp(16) * builder.k)
            color: Theme.withBlur(Theme.surfaceHighest)
            border.width: pc.lifted ? Theme.dp(1.5) : 0
            border.color: Theme.accent
            clip: true

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.55
                radius: parent.radius
                color: Theme.alpha(Theme.primary, 0.35)
            }

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(Theme.dp(12) * builder.k)
                name: pc.icon
                size: pc.iconSize
                color: Theme.text
            }

        }

        // a gauge: its ring, its name under it, on the card the run shares
        Rectangle {
            visible: pc.look === "gauge"
            anchors.fill: parent
            radius: Math.round(Theme.dp(16) * builder.k)
            color: pc.lifted ? Theme.withBlur(Theme.surfaceHigh) : "transparent"
            border.width: pc.lifted ? Theme.dp(1.5) : 0
            border.color: Theme.accent

            Rectangle {
                id: ring

                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(Theme.dp(10) * builder.k)
                width: Math.max(Theme.dp(20), Math.min(parent.width - Theme.dp(8), parent.height - y - Theme.dp(22)))
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(Theme.dp(3), Math.round(width * 0.1))
                border.color: Theme.alpha(Theme.accent, 0.55)

                Icon {
                    anchors.centerIn: parent
                    name: pc.icon
                    size: Math.round(ring.width * 0.36)
                    color: Theme.text
                }

            }

            Text {
                anchors.top: ring.bottom
                anchors.topMargin: Theme.dp(3)
                width: parent.width - Theme.dp(4)
                x: Theme.dp(2)
                horizontalAlignment: Text.AlignHCenter
                text: pc.name
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
                elide: Text.ElideRight
            }

        }

    }

}
