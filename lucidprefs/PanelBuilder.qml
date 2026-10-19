import QtQuick
import qs
import qs.lucidcc
import qs.lucidui

// the control centre, built like bricks: its blocks (sliders, big tiles,
// tiles, media, gauges) on the panel's own grid, bento style. each is the
// panel's own CcBlock with made-up readings, drawn full size and the whole
// grid scaled down to fit, so it reads as the panel does. a block is dragged
// by anything but its pieces, or by its name, to any cell and stretched by any
// edge or corner; the bar above names each, with its + to put pieces back, its
// eye to hide it and, for the sliders, whether they stand or lie. inside a
// block the pieces are dragged into order and taken out with their cross; a
// tile is dragged, or tapped, across to the other kind of tile
Item {
    id: builder

    // the panel's measures, as System.qml takes them: a column a tile wide, a
    // row a thin strip, and the gap between
    readonly property real unit: Theme.dp(52)
    readonly property real rowUnit: Theme.dp(20)
    readonly property real gridGap: Theme.dp(12)
    readonly property int boardCols: Prefs.systemGridCols
    // how much the grid is drawn down to fit the page
    readonly property real k: Math.max(0.3, Math.min(1, builder.width / builder.span(builder.boardCols)))
    readonly property real stepX: builder.unit + builder.gridGap
    readonly property real stepY: builder.rowUnit + builder.gridGap
    // across, where each block sits does not hang on what it holds
    readonly property var spots: Prefs.systemGridPlace(Prefs.systemBlockKeys)
    // the rows each block's pieces need, as the panel's will
    readonly property var needs: {
        const out = {};
        for (let i = 0; i < boardRepeater.count; i++) {
            const it = boardRepeater.itemAt(i);
            if (it)
                out[it.blockKey] = it.needRows;

        }
        return out;
    }
    readonly property var place: Prefs.systemGridPlace(Prefs.systemBlockKeys, builder.needs)
    readonly property bool slidersStand: !!(builder.spots.sliders && !builder.spots.sliders.lie)
    // down to the lowest block, and room under it to drop one
    readonly property int boardRows: Prefs.systemBlockKeys.reduce((n, key) => {
        const r = builder.place[key];
        return r ? Math.max(n, r.y + r.h) : n;
    }, 0) + 6
    // where a block is being carried or stretched to, outlined on the grid
    property var target: null
    // the block whose left-out pieces are on offer under the bar
    property string adding: ""
    // the piece being dragged, under the pointer, and where it would land
    property var ghost: null
    property point ghostAt: Qt.point(0, 0)
    property var drop: null

    function span(n) {
        return n * builder.unit + Math.max(0, n - 1) * builder.gridGap;
    }

    function rowSpan(n) {
        return n * builder.rowUnit + Math.max(0, n - 1) * builder.gridGap;
    }

    // a spot on the grid, in the grid's own pixels
    function boxOf(r) {
        return Qt.rect(r.x * builder.stepX, r.y * builder.stepY, builder.span(r.w), builder.rowSpan(r.h));
    }

    function freeFor(key, r) {
        return !Prefs.systemBlockKeys.some((k) => {
            return k !== key && builder.place[k] && Prefs.systemGridOverlap(r, builder.place[k]);
        });
    }

    // the card under a point on the grid
    function cardAt(p) {
        for (let i = 0; i < boardRepeater.count; i++) {
            const it = boardRepeater.itemAt(i);
            if (it && p.x >= it.x && p.x < it.x + it.width && p.y >= it.y && p.y < it.y + it.height)
                return it;

        }
        return null;
    }

    function isTiles(block) {
        return block === "bigtiles" || block === "tiles";
    }

    function catalogueOf(block) {
        if (block === "sliders")
            return Prefs.systemSliderCatalog;

        if (block === "gauges")
            return Prefs.systemInfoCatalog;

        return builder.isTiles(block) ? Prefs.systemTileCatalog : [];
    }

    function keysOf(block) {
        switch (block) {
        case "sliders":
            return Prefs.systemSliderKeys;
        case "bigtiles":
            return Prefs.systemBigTileKeys;
        case "tiles":
            return Prefs.systemSmallTileKeys;
        case "media":
            return ["media"];
        }
        return Prefs.systemInfoKeys;
    }

    // what can still go in a block: either tile block offers every tile in neither
    function spareOf(block) {
        const keys = builder.isTiles(block) ? Prefs.systemTileKeys : builder.keysOf(block);
        return builder.catalogueOf(block).map((e) => {
            return e.key;
        }).filter((k) => {
            return keys.indexOf(k) === -1;
        });
    }

    function setKeys(block, keys) {
        if (block === "sliders")
            Prefs.systemSliders = keys.join(",");
        else if (block === "bigtiles")
            Prefs.setSystemTileBlocks(keys, Prefs.systemSmallTileKeys);
        else if (block === "tiles")
            Prefs.setSystemTileBlocks(Prefs.systemBigTileKeys, keys);
        else if (block === "gauges")
            Prefs.systemInfo = keys.join(",");
    }

    // a tile into the other tile block, at a place in it or at its end
    function moveTile(key, to, index) {
        const big = Prefs.systemBigTileKeys.filter((k) => {
            return k !== key;
        });
        const small = Prefs.systemSmallTileKeys.filter((k) => {
            return k !== key;
        });
        const list = to === "bigtiles" ? big : small;
        list.splice(index < 0 || index > list.length ? list.length : index, 0, key);
        Prefs.setSystemTileBlocks(big, small);
        if (Prefs.systemBlockKeys.indexOf(to) === -1)
            builder.setBlockShown(to, true);

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

    width: parent ? parent.width : 0
    implicitHeight: boardWrap.y + boardWrap.height
    // the three blocks there were once are written out as the five
    Component.onCompleted: Prefs.systemMigrate()

    // made-up readings, so the blocks show as they would in the panel
    QtObject {
        id: sample

        readonly property bool expanded: false
        readonly property var tilePages: ["wifi", "bluetooth", "profile", "nightlight"]
        readonly property string mediaTitle: "Song title"
        readonly property string mediaArtist: "Artist"
        readonly property string mediaArt: ""
        readonly property real mediaProgress: 0.4
        readonly property bool mediaPlaying: false

        function tileEntry(k) {
            return builder.entryOf("tiles", k) || {
                "icon": "",
                "name": k
            };
        }

        function tileIcon(k) {
            return sample.tileEntry(k).icon;
        }

        function tileLabel(k) {
            return sample.tileEntry(k).name;
        }

        function bigName(k) {
            return sample.tileEntry(k).name;
        }

        function bigSub(k) {
            return k === "wifi" ? "Connected" : (k === "bluetooth" ? "On" : "Off");
        }

        function tileChecked(k) {
            return k === "wifi" || k === "bluetooth";
        }

        function tileAct(k) {
        }

        function showView(v) {
        }

        function sliderIcon(k) {
            const e = builder.entryOf("sliders", k);
            return e ? e.icon : "";
        }

        function sliderValue(k) {
            return k === "brightness" ? 60 : (k === "volume" ? 45 : 70);
        }

        function sliderMuted(k) {
            return false;
        }

        function sliderMove(k, v) {
        }

        function sliderIconClick(k) {
        }

        function mediaPrev() {
        }

        function mediaToggle() {
        }

        function mediaNext() {
        }

        function mediaOpen() {
        }

        function gauge(k) {
            const e = builder.entryOf("gauges", k);
            const v = {
                "cpu": [0.28, "62 °C"],
                "ram": [0.62, "9.4 GB"],
                "disk": [0.38, "297 GB free"],
                "battery": [0.8, "Full"]
            }[k] || [0.5, ""];
            return {
                "value": v[0],
                "center": Math.round(v[0] * 100) + "",
                "label": e ? e.name : k,
                "detail": v[1],
                "tone": Theme.accent,
                "icon": ""
            };
        }

        function gaugeClick(k) {
        }

    }

    // each block by name: its + for the pieces left out, the sliders' stand
    // or lie, and its eye, which hides it with all it holds or brings it back
    Flow {
        id: bar

        width: parent.width
        spacing: Theme.dp(8)

        Repeater {
            model: Prefs.systemBlockCatalog

            Rectangle {
                id: chip

                required property var modelData
                readonly property bool shown: Prefs.systemBlockKeys.indexOf(chip.modelData.key) !== -1
                readonly property bool hasSpare: builder.spareOf(chip.modelData.key).length > 0

                width: chipRow.implicitWidth + Theme.dp(18)
                height: Theme.dp(40)
                radius: height / 2
                color: chip.shown ? Theme.bgSunken : "transparent"
                border.width: chip.shown ? 0 : Theme.dp(1.5)
                border.color: Theme.outline

                Row {
                    id: chipRow

                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.dp(12)
                    spacing: Theme.dp(2)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: chip.modelData.icon
                        size: Theme.dp(18)
                        color: chip.shown ? Theme.accent : Theme.subtext
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: Theme.dp(6)
                        rightPadding: Theme.dp(4)
                        text: chip.modelData.name
                        color: chip.shown ? Theme.text : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                        font.weight: Font.DemiBold
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: chip.shown && chip.modelData.key !== "media"
                        size: Theme.dp(30)
                        enabled: chip.hasSpare
                        iconPath: builder.adding === chip.modelData.key && chip.hasSpare ? "close" : "add"
                        onClicked: builder.adding = builder.adding === chip.modelData.key ? "" : chip.modelData.key
                    }

                    // the sliders stand side by side or lie one under another
                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: chip.shown && chip.modelData.key === "sliders"
                        size: Theme.dp(30)
                        iconPath: builder.slidersStand ? "width" : "height"
                        onClicked: Prefs.systemGridSet("sliders", {
                            "lie": builder.slidersStand
                        }, builder.needs)
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.dp(30)
                        iconPath: chip.shown ? "visibility" : "visibility_off"
                        enabled: !chip.shown || Prefs.systemBlockKeys.length > 1
                        onClicked: {
                            if (chip.shown && builder.adding === chip.modelData.key)
                                builder.adding = "";

                            builder.setBlockShown(chip.modelData.key, !chip.shown);
                        }
                    }

                }

            }

        }

    }

    // the pieces left out of one block; tapping one puts it at the end
    Flow {
        id: adds

        readonly property var spare: builder.adding !== "" ? builder.spareOf(builder.adding) : []

        visible: adds.spare.length > 0
        y: bar.height + Theme.dp(10)
        width: parent.width
        spacing: Theme.dp(6)

        Repeater {
            model: adds.spare

            Rectangle {
                id: spareChip

                required property string modelData
                readonly property var entry: builder.entryOf(builder.adding, spareChip.modelData)

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
                    onClicked: builder.setKeys(builder.adding, builder.keysOf(builder.adding).concat([spareChip.modelData]))
                }

            }

        }

    }

    // the grid, full size and scaled down as one
    Item {
        id: boardWrap

        y: bar.height + (adds.visible ? adds.height + Theme.dp(10) : 0) + Theme.dp(12)
        width: Math.round(board.width * builder.k)
        height: Math.round(board.height * builder.k)
        x: Math.max(0, Math.round((builder.width - width) / 2))

        Item {
            id: board

            width: builder.span(builder.boardCols)
            height: builder.rowSpan(builder.boardRows)
            scale: builder.k
            transformOrigin: Item.TopLeft

            // a faint stripe for each column
            Repeater {
                model: builder.boardCols

                Rectangle {
                    required property int index

                    x: index * builder.stepX
                    width: builder.unit
                    height: board.height
                    radius: Theme.dp(8)
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

                model: Prefs.systemBlockKeys

                BlockCard {
                    required property string modelData

                    blockKey: modelData
                }

            }

            // the piece being dragged, over everything
            Rectangle {
                id: ghostItem

                readonly property var entry: builder.ghost ? builder.entryOf(builder.ghost.block, builder.ghost.key) : null

                visible: builder.ghost !== null
                z: 10
                width: builder.ghost ? builder.ghost.w : 0
                height: builder.ghost ? builder.ghost.h : 0
                x: builder.ghostAt.x - width / 2
                y: builder.ghostAt.y - height / 2
                radius: Math.min(Theme.radiusMd, height / 2)
                color: Theme.withBlur(Theme.surfaceHighest)
                border.width: Theme.dp(2)
                border.color: Theme.accent

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: ghostItem.entry ? ghostItem.entry.icon : ""
                        size: Theme.dp(20)
                        color: Theme.text
                    }

                    Text {
                        visible: ghostItem.width > Theme.dp(90)
                        anchors.verticalCenter: parent.verticalCenter
                        text: ghostItem.entry ? ghostItem.entry.name : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                    }

                }

            }

        }

    }

    // a block on the grid, the panel's own, filling its cells. dragged by
    // anything but its pieces it moves; its edges and corners stretch it; its
    // pieces are dragged into order, a tile across to the other tile block
    component BlockCard: Item {
        id: card

        property string blockKey: ""
        // the pieces in the order shown, while one is dragged too
        property var liveOrder: null
        readonly property var order: card.liveOrder || builder.keysOf(card.blockKey)
        readonly property var spot: builder.spots[card.blockKey] || null
        readonly property var cell: builder.place[card.blockKey] || card.spot
        readonly property rect box: card.cell ? builder.boxOf(card.cell) : Qt.rect(0, 0, 0, 0)
        readonly property bool editable: card.blockKey !== "media"
        readonly property int needRows: Math.max(1, Math.ceil((view.implicitHeight + builder.gridGap) / builder.stepY))
        readonly property bool busy: area.mode === 1 || tagArea.pressed || card.sizing
        property bool sizing: false
        // the piece the pointer is on, and the one showing its cross
        readonly property int hovered: hover.hovered && builder.ghost === null && card.editable ? view.pieceAt(hover.point.position.x, hover.point.position.y) : -1
        property int crossAt: -1
        // how far the pointer has carried this block, and where it took hold
        property real dragDX: 0
        property real dragDY: 0
        property point grab

        // carrying the block: the card follows the pointer, its outline snaps to a cell
        function moveFrom(p) {
            card.grab = Qt.point(p.x - card.x, p.y - card.y);
        }

        function moveTo(p) {
            const left = p.x - card.grab.x, top = p.y - card.grab.y;
            card.dragDX = left - card.box.x;
            card.dragDY = top - card.box.y;
            builder.target = {
                "x": Math.max(0, Math.min(builder.boardCols - card.cell.w, Math.round(left / builder.stepX))),
                "y": Math.max(0, Math.round(top / builder.stepY)),
                "w": card.cell.w,
                "h": card.cell.h
            };
        }

        // the blocks it lands on take the spot it left, or go under it
        function moveEnd() {
            card.dragDX = 0;
            card.dragDY = 0;
            const t = builder.target;
            builder.target = null;
            if (t && (t.x !== card.cell.x || t.y !== card.cell.y))
                Prefs.systemGridSet(card.blockKey, {
                "x": t.x,
                "y": t.y
            }, builder.needs);

        }

        // stretching it by an edge or corner, in widths it can take, no
        // shorter than it needs and as far as the blocks around leave room
        function sizeTo(p, e) {
            const c = card.cell;
            let x = c.x, y = c.y, w = c.w, h = c.h;
            const minH = card.needRows;
            const snap = (want, room) => {
                let v = Prefs.systemGridSnapW(card.blockKey, c.lie, want);
                while (v > room && v > Prefs.systemGridMinW(card.blockKey, c.lie))
                    v = Prefs.systemGridSnapW(card.blockKey, c.lie, v - 1);
                return v;
            };
            if (e.r)
                w = snap(Math.round((p.x + builder.gridGap) / builder.stepX) - x, builder.boardCols - x);

            if (e.l) {
                const right = c.x + c.w;
                w = snap(right - Math.round(p.x / builder.stepX), right);
                x = right - w;
            }
            if (e.b)
                h = Math.max(minH, Math.round((p.y + builder.gridGap) / builder.stepY) - y);

            if (e.t) {
                const bottom = c.y + c.h;
                y = Math.max(0, Math.min(bottom - minH, Math.round(p.y / builder.stepY)));
                h = bottom - y;
            }
            const want = {
                "x": x,
                "y": y,
                "w": w,
                "h": h
            };
            if (builder.freeFor(card.blockKey, want))
                builder.target = want;
            else if (!builder.target)
                builder.target = {
                "x": c.x,
                "y": c.y,
                "w": c.w,
                "h": c.h
            };
        }

        function sizeEnd() {
            card.sizing = false;
            const t = builder.target;
            builder.target = null;
            const c = card.cell;
            if (t && (t.x !== c.x || t.y !== c.y || t.w !== c.w || t.h !== c.h))
                Prefs.systemGridSet(card.blockKey, t, builder.needs);

        }

        // where a tile dropped here from the other block would go
        function pieceIndexAt(x, y) {
            return view.pieceAt(x, y);
        }

        onHoveredChanged: {
            if (card.hovered >= 0)
                card.crossAt = card.hovered;
            else if (!crossArea.containsMouse)
                card.crossAt = -1;
        }
        x: card.box.x + card.dragDX
        y: card.box.y + card.dragDY
        // its width from its columns alone; down, the rows decide
        width: card.spot ? builder.span(card.spot.w) : 0
        height: card.box.height
        z: card.busy ? 5 : 0

        HoverHandler {
            id: hover
        }

        // its cells, so the room it was given shows past what it holds
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: Theme.alpha(Theme.text, card.busy ? 0.08 : 0.04)
        }

        CcBlock {
            id: view

            anchors.fill: parent
            enabled: false
            kind: card.blockKey
            keys: card.order
            host: sample
            cols: card.spot ? card.spot.w : 6
            bigCols: card.spot ? Math.max(1, Math.floor(card.spot.w / 3)) : 2
            gap: builder.gridGap
            standing: card.blockKey === "sliders" && builder.slidersStand
            cards: Prefs.systemBlockCards
        }

        // and their outline, over what it holds
        Rectangle {
            readonly property bool lit: card.busy || hover.hovered || (!!builder.drop && builder.drop.card === card)

            anchors.fill: parent
            z: 2
            radius: Theme.radiusMd
            color: "transparent"
            border.width: lit ? Theme.dp(2) : Theme.dp(1)
            border.color: lit ? Theme.accent : Theme.alpha(Theme.text, 0.1)
        }

        // a press on a piece drags it, anywhere else the block; a tap on a
        // tile sends it to the other tile block
        MouseArea {
            id: area

            // 0 nothing, 1 the block, 2 a piece pressed, 3 a piece dragged
            property int mode: 0
            property point start
            property int from: -1

            anchors.fill: parent
            z: 1
            preventStealing: true
            cursorShape: area.mode === 1 || area.mode === 3 ? Qt.ClosedHandCursor : (card.hovered >= 0 ? Qt.PointingHandCursor : Qt.OpenHandCursor)
            onPressed: (mouse) => {
                area.start = Qt.point(mouse.x, mouse.y);
                area.from = card.editable ? view.pieceAt(mouse.x, mouse.y) : -1;
                if (area.from >= 0) {
                    area.mode = 2;
                } else {
                    area.mode = 1;
                    card.moveFrom(mapToItem(board, mouse.x, mouse.y));
                }
            }
            onPositionChanged: (mouse) => {
                const p = mapToItem(board, mouse.x, mouse.y);
                if (area.mode === 1) {
                    card.moveTo(p);
                    return ;
                }
                if (area.mode === 2 && Math.abs(mouse.x - area.start.x) + Math.abs(mouse.y - area.start.y) > Theme.dp(8)) {
                    const b = view.pieceBox(area.from);
                    area.mode = 3;
                    card.liveOrder = card.order.slice();
                    builder.ghost = {
                        "block": card.blockKey,
                        "key": card.liveOrder[area.from],
                        "w": b.width,
                        "h": b.height
                    };
                }
                if (area.mode !== 3)
                    return ;

                builder.ghostAt = p;
                const over = builder.cardAt(p);
                if (over === card) {
                    builder.drop = null;
                    const to = view.pieceAt(mouse.x, mouse.y);
                    const at = card.liveOrder.indexOf(builder.ghost.key);
                    if (to >= 0 && to !== at) {
                        const l = card.liveOrder.slice();
                        l.splice(at, 1);
                        l.splice(to, 0, builder.ghost.key);
                        card.liveOrder = l;
                    }
                } else if (over && builder.isTiles(card.blockKey) && builder.isTiles(over.blockKey)) {
                    const q = over.mapFromItem(board, p.x, p.y);
                    builder.drop = {
                        "card": over,
                        "index": over.pieceIndexAt(q.x, q.y)
                    };
                } else {
                    builder.drop = null;
                }
            }
            onReleased: {
                if (area.mode === 1) {
                    card.moveEnd();
                } else if (area.mode === 2) {
                    // a tap: a tile goes to the end of the other tile block
                    const key = card.order[area.from];
                    if (builder.isTiles(card.blockKey))
                        builder.moveTile(key, card.blockKey === "tiles" ? "bigtiles" : "tiles", -1);

                } else if (area.mode === 3) {
                    const key = builder.ghost.key;
                    const d = builder.drop;
                    const l = card.liveOrder;
                    builder.ghost = null;
                    builder.drop = null;
                    card.liveOrder = null;
                    if (d)
                        builder.moveTile(key, d.card.blockKey, d.index);
                    else
                        builder.setKeys(card.blockKey, l);
                }
                area.mode = 0;
            }
            onCanceled: {
                card.dragDX = 0;
                card.dragDY = 0;
                builder.target = null;
                builder.ghost = null;
                builder.drop = null;
                card.liveOrder = null;
                area.mode = 0;
            }
        }

        // the cross on the piece the pointer is on
        Rectangle {
            readonly property rect pb: card.crossAt >= 0 ? view.pieceBox(card.crossAt) : Qt.rect(0, 0, 0, 0)
            readonly property bool removable: builder.isTiles(card.blockKey) || card.order.length > 1

            visible: card.crossAt >= 0 && removable && area.mode === 0
            z: 3
            width: Theme.dp(22)
            height: Theme.dp(22)
            radius: width / 2
            // inside the piece's corner, so it never sits past the block's edge
            x: pb.x + pb.width - width - Theme.dp(2)
            y: pb.y + Theme.dp(2)
            color: Theme.error

            Icon {
                anchors.centerIn: parent
                name: "close"
                size: Theme.dp(14)
                color: Theme.fgError
            }

            MouseArea {
                id: crossArea

                anchors.fill: parent
                anchors.margins: -Theme.dp(3)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onExited: {
                    if (card.hovered < 0)
                        card.crossAt = -1;

                }
                onClicked: {
                    const key = card.order[card.crossAt];
                    card.crossAt = -1;
                    builder.setKeys(card.blockKey, card.order.filter((k) => {
                        return k !== key;
                    }));
                }
            }

        }

        // its name, with a handle, while the pointer is on the block
        Rectangle {
            visible: hover.hovered || card.busy
            x: Theme.dp(6)
            y: Theme.dp(6)
            z: 3
            width: tagRow.implicitWidth + Theme.dp(16)
            height: Theme.dp(28)
            radius: height / 2
            color: Theme.accent

            Row {
                id: tagRow

                anchors.centerIn: parent
                spacing: Theme.dp(4)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "drag_indicator"
                    size: Theme.dp(16)
                    color: Theme.fgAccent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (Prefs.systemBlockCatalog.find((b) => {
                        return b.key === card.blockKey;
                    }) || {
                        "name": card.blockKey
                    }).name
                    color: Theme.fgAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: Font.DemiBold
                }

            }

            MouseArea {
                id: tagArea

                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true
                onPressed: (mouse) => {
                    return card.moveFrom(mapToItem(board, mouse.x, mouse.y));
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        card.moveTo(mapToItem(board, mouse.x, mouse.y));

                }
                onReleased: card.moveEnd()
                onCanceled: {
                    card.dragDX = 0;
                    card.dragDY = 0;
                    builder.target = null;
                }
            }

        }

        // a grip in each corner and on each edge's middle, shown on hover
        Repeater {
            model: [{"l": 1, "t": 1}, {"r": 1, "t": 1}, {"l": 1, "b": 1}, {"r": 1, "b": 1}, {"t": 1}, {"b": 1}, {"l": 1}, {"r": 1}]

            Rectangle {
                required property var modelData
                readonly property bool corner: (modelData.l || modelData.r) && (modelData.t || modelData.b)
                readonly property real len: corner ? Theme.dp(10) : Theme.dp(24)

                visible: hover.hovered || card.sizing
                z: 4
                width: modelData.l || modelData.r ? (corner ? len : Theme.dp(5)) : len
                height: modelData.t || modelData.b ? (corner ? len : Theme.dp(5)) : len
                x: modelData.l ? -width / 2 : (modelData.r ? card.width - width / 2 : (card.width - width) / 2)
                y: modelData.t ? -height / 2 : (modelData.b ? card.height - height / 2 : (card.height - height) / 2)
                radius: Math.min(width, height) / 2
                color: Theme.accent
            }

        }

        // the edges and corners themselves: a strip along each, a square at each corner
        Repeater {
            model: [{"l": 1, "t": 1}, {"r": 1, "t": 1}, {"l": 1, "b": 1}, {"r": 1, "b": 1}, {"t": 1}, {"b": 1}, {"l": 1}, {"r": 1}]

            MouseArea {
                required property var modelData
                readonly property real e: Theme.dp(12)

                z: 5
                width: modelData.l || modelData.r ? e : card.width - e * 2
                height: modelData.t || modelData.b ? e : card.height - e * 2
                x: modelData.l ? -e / 2 : (modelData.r ? card.width - e / 2 : e)
                y: modelData.t ? -e / 2 : (modelData.b ? card.height - e / 2 : e)
                preventStealing: true
                cursorShape: (modelData.l || modelData.r) && (modelData.t || modelData.b) ? ((!!modelData.l === !!modelData.t) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : (modelData.l || modelData.r ? Qt.SizeHorCursor : Qt.SizeVerCursor)
                onPressed: card.sizing = true
                onPositionChanged: (mouse) => {
                    if (pressed)
                        card.sizeTo(mapToItem(board, mouse.x, mouse.y), modelData);

                }
                onReleased: card.sizeEnd()
                onCanceled: {
                    card.sizing = false;
                    builder.target = null;
                }
            }

        }

    }

}
