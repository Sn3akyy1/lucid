import QtQuick
import qs
import qs.lucidui

// the control centre, built like bricks: its blocks (sliders, toggles, system)
// drawn to the panel's own measures. one under another, a block is dragged by
// its handle into order; on the wide panel they sit on a grid, bento style,
// where the handle carries a block to any cell and its corner makes it span
// more or fewer columns and rows. inside a block the pieces are dragged into
// order, taken out with their cross and put back from its +. a tile is tapped
// to go big (half a row, with its name) or back to small
Item {
    id: builder

    // the panel goes wide only with more than one block to lay out
    readonly property bool wide: Prefs.systemPanelStyle === "wide" && Prefs.systemBlockKeys.length > 1
    // the panel's measures, as System.qml takes them: its column, the tiles'
    // gap, and the wide panel's grid of tile-wide columns
    readonly property real col: Theme.dp(400) - Theme.dp(32)
    readonly property real tileGap: Theme.dp(8)
    readonly property real unit: Theme.dp(52)
    readonly property real gridGap: Theme.dp(12)
    readonly property int boardCols: Prefs.systemGridCols
    // a block's card: its padding, and the gap between two one under another
    readonly property real cardPad: Theme.dp(8)
    readonly property real cardGap: Theme.dp(10)
    // how much the panel is drawn down to fit the page: the column, or the whole grid
    readonly property real k: builder.wide ? Math.max(0.3, Math.min(1, builder.width / builder.span(builder.boardCols))) : Math.max(0.3, Math.min(1, (builder.width - builder.cardPad * 2) / builder.col))
    readonly property real stepX: (builder.unit + builder.gridGap) * builder.k
    readonly property real gapK: Math.round(builder.gridGap * builder.k)
    // a row nothing sits in yet, kept open to drop a block into
    readonly property real emptyRowH: Theme.dp(44)
    readonly property var place: Prefs.systemGridPlace(Prefs.systemBlockKeys)
    readonly property bool slidersStand: builder.wide && !(builder.place.sliders && builder.place.sliders.lie)
    // the grid's rows: down to the lowest block, and one more below it
    readonly property int boardRows: Prefs.systemBlockKeys.reduce((n, key) => {
        const r = builder.place[key];
        return r ? Math.max(n, r.y + r.h) : n;
    }, 0) + 1
    // each row as tall as the tallest card sitting in it alone, a card
    // spanning rows stretching the last of them, as the panel does
    readonly property var rowH: {
        const h = [];
        for (let i = 0; i < builder.boardRows; i++)
            h.push(0);
        const cards = [];
        for (let i = 0; i < boardRepeater.count; i++) {
            const it = boardRepeater.itemAt(i);
            if (it && builder.place[it.blockKey])
                cards.push(it);

        }
        cards.sort((a, b) => {
            return builder.place[a.blockKey].h - builder.place[b.blockKey].h;
        });
        for (const it of cards) {
            const r = builder.place[it.blockKey];
            let have = (r.h - 1) * builder.gapK;
            for (let i = 0; i < r.h; i++)
                have += h[r.y + i];
            if (it.natural > have)
                h[r.y + r.h - 1] += it.natural - have;

        }
        return h.map((v) => {
            return v > 0 ? v : builder.emptyRowH;
        });
    }
    readonly property real boardH: builder.rowH.reduce((t, v) => {
        return t + v;
    }, 0) + Math.max(0, builder.rowH.length - 1) * builder.gapK
    // where a block is being carried or stretched to, outlined on the grid
    property var target: null
    readonly property var hiddenKeys: Prefs.systemBlockCatalog.map((b) => {
        return b.key;
    }).filter((key) => {
        return Prefs.systemBlockKeys.indexOf(key) === -1;
    })
    property bool blockDragging: false
    // the piece being dragged, drawn under the pointer while its place shows faded
    property var ghost: null
    property point ghostAt: Qt.point(0, 0)

    function span(n) {
        return n * builder.unit + Math.max(0, n - 1) * builder.gridGap;
    }

    function rowTop(r) {
        let y = 0;
        for (let i = 0; i < r && i < builder.rowH.length; i++)
            y += builder.rowH[i] + builder.gapK;
        return y;
    }

    // a spot on the grid, in the board's pixels
    function boxOf(r) {
        let h = (r.h - 1) * builder.gapK;
        for (let i = 0; i < r.h; i++)
            h += builder.rowH[r.y + i] || builder.emptyRowH;
        return Qt.rect(Math.round(r.x * builder.stepX), builder.rowTop(r.y), Math.round(builder.span(r.w) * builder.k), h);
    }

    // the row whose top is nearest y, and the one y falls in
    function rowNear(y) {
        let best = 0;
        for (let i = 1; i < builder.rowH.length; i++)
            if (Math.abs(builder.rowTop(i) - y) < Math.abs(builder.rowTop(best) - y))
                best = i;
        return best;
    }

    function rowIn(y) {
        for (let i = builder.rowH.length - 1; i > 0; i--)
            if (y >= builder.rowTop(i) - builder.gapK / 2)
                return i;
        return 0;
    }

    function freeFor(key, r) {
        return !Prefs.systemBlockKeys.some((k) => {
            return k !== key && builder.place[k] && Prefs.systemGridOverlap(r, builder.place[k]);
        });
    }

    // gauges sharing a card, as System.qml lays them: as many to a row as
    // leave each its 88, in rows as even as can be
    function gaugeCols(n, width) {
        const most = Math.max(1, Math.min(n, Math.floor(width / Theme.dp(88))));
        return Math.max(1, Math.ceil(n / Math.ceil(n / most)));
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
    implicitHeight: (builder.wide ? board.height : blockFlow.height) + (builder.hiddenKeys.length > 0 ? hiddenRow.height + Theme.dp(12) : 0)
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

    // one under another, centred, as the panel is
    Flow {
        id: blockFlow

        visible: !builder.wide
        width: Math.round(builder.col * builder.k) + builder.cardPad * 2
        x: Math.max(0, Math.round((builder.width - width) / 2))
        spacing: builder.cardGap

        Repeater {
            id: blockRepeater

            model: builder.wide ? 0 : blockModel

            BlockCard {
                required property string key
                required property int index

                blockKey: key
                slot: index
                width: blockFlow.width
            }

        }

    }

    // the wide panel's grid: a faint stripe for each column, the blocks on it
    Item {
        id: board

        visible: builder.wide
        width: Math.round(builder.span(builder.boardCols) * builder.k)
        height: builder.wide ? builder.boardH : 0
        x: Math.max(0, Math.round((builder.width - width) / 2))

        Repeater {
            model: builder.wide ? builder.boardCols : 0

            Rectangle {
                required property int index

                x: Math.round(index * builder.stepX)
                width: Math.round(builder.unit * builder.k)
                height: board.height
                radius: Theme.dp(6)
                color: Theme.alpha(Theme.text, 0.035)
            }

        }

        // where the block being carried or stretched would go
        Rectangle {
            readonly property rect box: builder.target ? builder.boxOf(builder.target) : Qt.rect(0, 0, 0, 0)

            visible: builder.target !== null
            x: box.x
            y: box.y
            width: box.width
            height: box.height
            radius: Theme.radiusMd
            color: Theme.alpha(Theme.accent, 0.12)
            border.width: Theme.dp(2)
            border.color: Theme.accent
        }

        Repeater {
            id: boardRepeater

            model: builder.wide ? Prefs.systemBlockKeys : []

            BlockCard {
                id: boardCard

                required property string modelData
                readonly property var spot: builder.place[boardCard.modelData] || null
                readonly property rect box: boardCard.spot ? builder.boxOf(boardCard.spot) : Qt.rect(0, 0, 0, 0)

                blockKey: modelData
                x: box.x + dragDX
                y: box.y + dragDY
                // its width from its columns alone; down, the rows decide
                width: boardCard.spot ? Math.round(builder.span(boardCard.spot.w) * builder.k) : 0
                height: box.height
            }

        }

    }

    // the blocks left out, each with its eye to bring it back
    Row {
        id: hiddenRow

        visible: builder.hiddenKeys.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: (builder.wide ? board.height : blockFlow.height) + Theme.dp(12)
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

    // a block: its handle, name and buttons, then what it holds on the panel's
    // grid, and the pieces that can go in it. on the grid it fills its cells,
    // with a grip in its corner to stretch it
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
        readonly property var gridSpot: builder.wide ? (builder.place[card.blockKey] || null) : null
        // the block's width on the panel, and drawn down
        readonly property real realW: card.gridSpot ? builder.span(card.gridSpot.w) : builder.col
        readonly property real bodyW: card.width - builder.cardPad * 2
        readonly property real pieceGap: Math.round(builder.tileGap * builder.k)
        // the tiles keep six to a row in the column; on the grid a column is a tile
        readonly property int tileCols: card.gridSpot ? card.gridSpot.w : 6
        readonly property bool standing: card.blockKey === "sliders" && builder.slidersStand
        readonly property real addsH: adds.visible ? adds.height + body.spacing : 0
        // the room the standing sliders get: what the cells leave them
        readonly property real standH: Math.max(Math.round(Theme.dp(60) * builder.k), card.height - builder.cardPad * 2 - header.height - body.spacing - card.addsH)
        // what the card needs down; the standing sliders take what they are given
        readonly property real natural: card.standing ? builder.cardPad * 2 + header.height + body.spacing + Math.round(Theme.dp(160) * builder.k) + card.addsH : body.implicitHeight + builder.cardPad * 2
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

        // the system block reads as cards: a run of gauges shares a row, as
        // many to it as the block's width allows
        function gaugeCols(i) {
            let a = i, b = i;
            while (a > 0 && card.order[a - 1] !== "media")
                a--;
            while (b < card.order.length - 1 && card.order[b + 1] !== "media")
                b++;
            return builder.gaugeCols(b - a + 1, card.realW - Theme.dp(16));
        }

        function pieceW(key, big, i) {
            if (card.blockKey === "toggles") {
                if (big)
                    return Math.floor((card.bodyW - card.pieceGap) / 2);

                return Math.floor((card.bodyW - card.pieceGap * (card.tileCols - 1)) / card.tileCols);
            }
            if (card.blockKey === "sliders") {
                const n = Math.max(1, card.keys.length);
                return card.standing ? Math.floor((card.bodyW - card.pieceGap * (n - 1)) / n) : card.bodyW;
            }
            if (key === "media")
                return card.bodyW;

            const n = Math.max(1, card.gaugeCols(i));
            return Math.floor((card.bodyW - card.pieceGap * (n - 1)) / n);
        }

        function pieceH(key, big, i) {
            if (card.blockKey === "toggles")
                return big ? Math.round(Theme.dp(64) * builder.k) : card.pieceW(key, big, i) + Math.round(Theme.dp(24) * builder.k);

            if (card.blockKey === "sliders")
                return card.standing ? card.standH : Math.round(Theme.dp(50) * builder.k);

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
            let y = 0;
            let i = 0;
            while (i < card.order.length) {
                if (card.order[i] === "media") {
                    y += card.pieceH("media", false, i) + card.pieceGap;
                    i++;
                    continue;
                }
                let j = i;
                while (j < card.order.length && card.order[j] !== "media")
                    j++;
                const rows = Math.ceil((j - i) / card.gaugeCols(i));
                const h = rows * card.pieceH(card.order[i], false, i) + (rows - 1) * card.pieceGap;
                out.push({
                    "y": y,
                    "h": h
                });
                y += h + card.pieceGap;
                i = j;
            }
            return out;
        }

        onKeysChanged: card.syncPieces()
        Component.onCompleted: card.syncPieces()
        implicitHeight: card.natural
        height: implicitHeight
        radius: Theme.radiusMd
        color: Theme.bgSunken
        border.width: card.dragDX !== 0 || card.dragDY !== 0 ? Theme.dp(2) : 0
        border.color: Theme.accent
        z: card.dragDX !== 0 || card.dragDY !== 0 || grip.pressed ? 5 : 0

        ListModel {
            id: pieceModel
        }

        Column {
            id: body

            x: builder.cardPad
            y: builder.cardPad
            width: card.bodyW
            spacing: Theme.dp(8)

            // the handle, the name while there is room for it, and the buttons,
            // which wrap under the handle on a narrow block
            Flow {
                id: header

                readonly property real btn: Theme.dp(28)
                readonly property int buttons: card.blockKey === "sliders" && builder.wide ? 3 : 2
                readonly property bool named: width >= handle.width + header.btn * header.buttons + Theme.dp(70)

                width: parent.width
                spacing: Theme.dp(2)

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
                        // on the grid: where in the card the pointer took hold of it
                        property point grab

                        anchors.fill: parent
                        enabled: Prefs.systemBlockKeys.length > 1
                        hoverEnabled: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true
                        onPressed: (mouse) => {
                            if (builder.wide) {
                                const p = mapToItem(board, mouse.x, mouse.y);
                                grab = Qt.point(p.x - card.x, p.y - card.y);
                                return ;
                            }
                            start = mapToItem(blockFlow, mouse.x, mouse.y);
                            builder.blockDragging = true;
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed)
                                return ;

                            if (builder.wide) {
                                // the card follows the pointer; its outline snaps to the cell it would take
                                const p = mapToItem(board, mouse.x, mouse.y);
                                const left = p.x - grab.x, top = p.y - grab.y;
                                card.dragDX = left - card.x + card.dragDX;
                                card.dragDY = top - card.y + card.dragDY;
                                const s = card.gridSpot;
                                builder.target = {
                                    "x": Math.max(0, Math.min(builder.boardCols - s.w, Math.round(left / builder.stepX))),
                                    "y": builder.rowNear(top),
                                    "w": s.w,
                                    "h": s.h
                                };
                                return ;
                            }
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

                                const mid = other.y + other.height / 2;
                                if ((i < card.slot && p.y < mid) || (i > card.slot && p.y > mid)) {
                                    const before = card.y;
                                    blockModel.move(card.slot, i, 1);
                                    // the block jumped; keep it under the pointer
                                    Qt.callLater(() => {
                                        const shift = card.y - before;
                                        start.y += shift;
                                        card.dragDY -= shift;
                                    });
                                    break;
                                }
                            }
                        }
                        onReleased: {
                            card.dragDX = 0;
                            card.dragDY = 0;
                            if (builder.wide) {
                                // the blocks it lands on move to where it was
                                const t = builder.target;
                                builder.target = null;
                                if (t && (t.x !== card.gridSpot.x || t.y !== card.gridSpot.y))
                                    Prefs.systemGridSet(card.blockKey, {
                                    "x": t.x,
                                    "y": t.y
                                });

                                return ;
                            }
                            builder.blockDragging = false;
                            const l = [];
                            for (let i = 0; i < blockModel.count; i++) l.push(blockModel.get(i).key)
                            Prefs.systemBlocks = l.join(",");
                        }
                        onCanceled: {
                            card.dragDX = 0;
                            card.dragDY = 0;
                            builder.target = null;
                            builder.blockDragging = false;
                            builder.syncBlocks();
                        }
                    }

                }

                Item {
                    visible: header.named
                    width: header.width - handle.width - header.btn * header.buttons - header.spacing * (header.buttons + 1)
                    height: handle.height

                    Icon {
                        id: blockIcon

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.dp(4)
                        anchors.verticalCenter: parent.verticalCenter
                        name: card.entry ? card.entry.icon : ""
                        size: Theme.dp(18)
                        color: Theme.accent
                    }

                    Text {
                        anchors.left: blockIcon.right
                        anchors.leftMargin: Theme.dp(8)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.entry ? card.entry.name : card.blockKey
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyLg
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                }

                // the ones left out, behind a +
                M3IconButton {
                    size: header.btn
                    enabled: card.spare.length > 0
                    iconPath: card.adding && card.spare.length > 0 ? "close" : "add"
                    onClicked: card.adding = !card.adding
                }

                // on the grid the sliders stand side by side or lie one under another
                M3IconButton {
                    visible: card.blockKey === "sliders" && builder.wide
                    size: header.btn
                    iconPath: card.standing ? "width" : "height"
                    onClicked: Prefs.systemGridSet("sliders", {
                        "lie": card.standing
                    })
                }

                // hiding a block keeps what it holds
                M3IconButton {
                    size: header.btn
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

                    width: card.bodyW
                    spacing: card.pieceGap

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
                id: adds

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

        // the grip: dragging the corner makes the block span more or fewer
        // columns and rows, as far as the blocks around it leave room
        Item {
            visible: card.gridSpot !== null
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Theme.dp(22)
            height: Theme.dp(22)

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.dp(5)
                width: Theme.dp(10)
                height: Theme.dp(2.5)
                radius: height / 2
                color: grip.containsMouse || grip.pressed ? Theme.accent : Theme.subtext
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.dp(5)
                width: Theme.dp(2.5)
                height: Theme.dp(10)
                radius: width / 2
                color: grip.containsMouse || grip.pressed ? Theme.accent : Theme.subtext
            }

            MouseArea {
                id: grip

                anchors.fill: parent
                anchors.margins: -Theme.dp(4)
                hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor
                preventStealing: true
                onPositionChanged: (mouse) => {
                    if (!pressed)
                        return ;

                    const s = card.gridSpot;
                    const p = mapToItem(board, mouse.x, mouse.y);
                    const want = {
                        "x": s.x,
                        "y": s.y,
                        "w": Math.max(Prefs.systemGridMinW(card.blockKey, s.lie), Math.min(builder.boardCols - s.x, Math.round((p.x - Math.round(s.x * builder.stepX) + builder.gapK) / builder.stepX))),
                        "h": Math.max(1, Math.min(Prefs.systemGridMaxRows, builder.rowIn(p.y) - s.y + 1))
                    };
                    // up to the blocks around it: the last size that fitted stays
                    if (builder.freeFor(card.blockKey, want))
                        builder.target = want;
                    else if (!builder.target)
                        builder.target = {
                        "x": s.x,
                        "y": s.y,
                        "w": s.w,
                        "h": s.h
                    };
                }
                onReleased: {
                    const t = builder.target;
                    builder.target = null;
                    if (t && (t.w !== card.gridSpot.w || t.h !== card.gridSpot.h))
                        Prefs.systemGridSet(card.blockKey, {
                        "w": t.w,
                        "h": t.h
                    });

                }
                onCanceled: builder.target = null
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
                return builder.slidersStand ? "standing" : "lying";

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
