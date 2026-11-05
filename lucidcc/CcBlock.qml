import QtQuick
import qs
import qs.lucidui

// one block of the control centre, drawn the same in the panel and in the
// editor on its module card: the big tiles, the small ones, the sliders, what
// is playing, the gauges, or one of the blocks that read the shell's own
// sources (weather, network, power, agenda). it fills the box it is given:
// standing sliders stretch, lying ones and the gauges spread out, the media
// card keeps to the middle and the tiles to the top. the host says what each
// piece shows and takes its taps:
//   tiles   tileIcon(k) tileLabel(k) bigName(k) bigSub(k) tileChecked(k)
//           tilePages tileAct(k) showView(v)
//   sliders sliderIcon(k) sliderValue(k) sliderMuted(k) sliderMove(k, v)
//           sliderIconClick(k)
//   media   mediaUp mediaTitle mediaArtist mediaArt mediaProgress mediaPlaying
//           mediaPosition mediaLength (seconds) mediaPrev() mediaToggle()
//           mediaNext() mediaOpen() mediaSeek(s)
//   gauges  gauge(k), as { value, center, label, detail, tone, icon,
//           clickable, history }, and gaugeClick(k)
//   the rest blockOpen(kind), for a tap on one
//   expanded, while the values may ease; sampling, while what the blocks
//           read is kept fresh (the panel open, or its editor)
// look picks how the block draws its pieces (Prefs.systemStyleCatalog); ""
// is the first, the look it always had
Item {
    id: block

    // sliders, bigtiles, tiles, media, gauges, weather, network, power or agenda
    property string kind: ""
    property var keys: []
    property var host: null
    // small tiles and big ones to a row, and the gap between pieces
    property int cols: 6
    property int bigCols: 2
    property real gap: Theme.dp(8)
    property bool standing: false
    property string look: ""
    // a card behind the tiles and the sliders too; media and gauges always have one
    property bool cards: false
    // the panel's single column, as it always was: its ring gauges keep their old
    // size, four to a row, on the card's old margins
    property bool classic: false
    readonly property bool carded: block.kind !== "sliders" && block.kind !== "bigtiles" && block.kind !== "tiles" || block.cards
    // the small tile whose name shows, kept over its neighbours
    property string tipKey: ""
    z: block.tipKey !== "" ? 1 : 0

    readonly property real pad: block.carded && block.kind !== "media" ? Theme.dp(12) : 0
    readonly property bool classicRings: block.classic && block.kind === "gauges" && (block.look === "" || block.look === "rings")
    // 16 across in all, rounded as one, and centred the way anchors centre an odd
    // width, as the old row was
    readonly property real padL: block.classicRings ? Math.floor(Theme.dp(16) / 2) : block.pad
    readonly property real padW: block.classicRings ? Theme.dp(16) : block.pad * 2
    readonly property real padY: block.classicRings ? Theme.dp(14) : block.pad
    readonly property bool ease: !!block.host && !!block.host.expanded
    readonly property bool live: !!block.host && !!block.host.sampling
    // what its pieces need down, before it is given more
    readonly property real natural: body.item ? body.item.natural : 0
    // big tiles keep to the middle of a taller box, beside the media card they line up with
    readonly property real lift: block.kind === "bigtiles" ? Math.max(0, Math.floor((block.height - block.padY * 2 - block.natural) / 2)) : 0

    // gauges sharing a card: as many to a row as leave each its least (88
    // for a ring), in rows as even as can be
    function gaugeCols(n, width, least, gap) {
        const room = least || Theme.dp(88);
        const most = Math.max(1, Math.min(n, Math.floor((width + (gap || 0)) / (room + (gap || 0)))));
        return Math.max(1, Math.ceil(n / Math.ceil(n / most)));
    }

    // the shape a tile turns into in the shapes look, the same for a tile
    // wherever it sits
    readonly property var litShapes: ["cookie9", "clover4", "sunny", "flower"]

    function shapeOf(k) {
        if (block.look !== "shapes")
            return "";

        let h = 0;
        for (let i = 0; i < k.length; i++)
            h = (h * 31 + k.charCodeAt(i)) % 997;
        return block.litShapes[h % block.litShapes.length];
    }

    // where piece i sits in the block, and the piece under a point, or -1
    function pieceBox(i) {
        const r = body.item ? body.item.pieces : null;
        const it = r ? r.itemAt(i) : null;
        if (!it)
            return Qt.rect(0, 0, 0, 0);

        const p = it.mapToItem(block, 0, 0);
        return Qt.rect(p.x, p.y, it.width, it.height);
    }

    function pieceAt(x, y) {
        const half = block.gap / 2;
        for (let i = 0; i < block.keys.length; i++) {
            const b = block.pieceBox(i);
            if (b.width > 0 && x >= b.x - half && x < b.x + b.width + half && y >= b.y - half && y < b.y + b.height + half)
                return i;

        }
        return -1;
    }

    implicitHeight: block.natural + block.padY * 2

    Rectangle {
        anchors.fill: parent
        visible: block.carded
        radius: Theme.shapeLgInc
        color: Theme.withBlur(Theme.surfaceHigh)
    }

    Loader {
        id: body

        x: block.padL
        y: block.padY + block.lift
        width: Math.max(0, block.width - block.padW)
        height: Math.max(0, block.height - block.padY * 2 - block.lift * 2)
        sourceComponent: {
            switch (block.kind) {
            case "sliders":
                return block.standing ? standingC : lyingC;
            case "media":
                return mediaC;
            case "gauges":
                return gaugesC;
            case "weather":
                return weatherC;
            case "network":
                return networkC;
            case "power":
                return powerC;
            case "agenda":
                return agendaC;
            }
            return tilesC;
        }
    }

    // a small tile takes a column, a big one its share of the row
    Component {
        id: tilesC

        Flow {
            id: flow

            readonly property Item pieces: tileRep
            readonly property bool big: block.kind === "bigtiles"
            // the column's small tiles step down as the old grid did, a name's 20 under
            // each and 12 between rows, rounded the way it rounded them
            readonly property bool oldRows: block.classic && !flow.big && block.look !== "icons"
            readonly property real tail: flow.oldRows ? Theme.dp(12) - block.gap : 0
            readonly property real natural: flow.implicitHeight - flow.tail
            readonly property int perRow: Math.max(1, flow.big ? block.bigCols : block.cols)
            readonly property real pieceW: Math.floor((flow.width - flow.spacing * (flow.perRow - 1)) / flow.perRow)

            spacing: block.gap

            Repeater {
                id: tileRep

                model: block.keys

                Item {
                    id: slot

                    required property string modelData

                    z: block.tipKey === slot.modelData ? 1 : 0
                    readonly property bool hasPage: block.host.tilePages.indexOf(slot.modelData) !== -1

                    width: flow.pieceW
                    // the small ones' names sit in the gap, so their row keeps the grid's
                    height: flow.big ? (block.look === "compact" ? Theme.dp(48) : Theme.dp(64)) : flow.pieceW + (block.look === "icons" ? 0 : (flow.oldRows ? Theme.dp(20) + flow.tail : Theme.dp(24)))

                    CcBigTile {
                        visible: flow.big
                        width: parent.width
                        icon: block.host.tileIcon(slot.modelData)
                        name: block.host.bigName(slot.modelData)
                        sub: block.host.bigSub(slot.modelData)
                        checked: block.host.tileChecked(slot.modelData)
                        hasPage: slot.hasPage
                        look: block.look === "" ? "pill" : block.look
                        shape: block.shapeOf(slot.modelData)
                        onToggled: block.host.tileAct(slot.modelData)
                        onExpandRequested: slot.hasPage ? block.host.showView(slot.modelData) : block.host.tileAct(slot.modelData)
                    }

                    CcSmallTile {
                        visible: !flow.big
                        width: parent.width
                        gutter: block.gap
                        icon: block.host.tileIcon(slot.modelData)
                        label: block.host.tileLabel(slot.modelData)
                        checked: block.host.tileChecked(slot.modelData)
                        hasMore: slot.hasPage
                        square: block.look === "square"
                        labelled: block.look !== "icons"
                        // above it is the panel's edge on the top row of a block at the top
                        tipUp: block.y + flow.y + slot.y >= Theme.dp(28)
                        onTipShownChanged: {
                            if (tipShown)
                                block.tipKey = slot.modelData;
                            else if (block.tipKey === slot.modelData)
                                block.tipKey = "";
                        }
                        shape: block.shapeOf(slot.modelData)
                        onToggled: block.host.tileAct(slot.modelData)
                        onMore: block.host.showView(slot.modelData)
                    }

                }

            }

        }

    }

    // lying down, one under another, spread over the height they are given
    Component {
        id: lyingC

        Item {
            id: lying

            readonly property Item pieces: lyingRep
            readonly property int n: Math.max(1, block.keys.length)
            // each as tall as its handle
            readonly property real each: block.look === "bold" ? Theme.dp(64) : (block.look === "thin" ? Theme.dp(36) : Theme.dp(50))
            readonly property real natural: lying.n * lying.each + (lying.n - 1) * Theme.dp(8)

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: lying.n > 1 ? Math.max(Theme.dp(8), (lying.height - lying.n * lying.each) / (lying.n - 1)) : 0

                Repeater {
                    id: lyingRep

                    model: block.keys

                    CcLyingSlider {
                        required property string modelData

                        width: lying.width
                        icon: block.host.sliderIcon(modelData)
                        value: block.host.sliderValue(modelData)
                        muted: block.host.sliderMuted(modelData)
                        iconClickable: modelData !== "brightness"
                        footIcon: modelData === "volume" ? "speaker" : ""
                        easeValue: block.ease
                        look: block.look === "" ? "plain" : block.look
                        onMoved: (v) => {
                            return block.host.sliderMove(modelData, v);
                        }
                        onIconClicked: block.host.sliderIconClick(modelData)
                        onFootClicked: block.host.showView("output")
                    }

                }

            }

        }

    }

    // standing up side by side, as tall as the block
    Component {
        id: standingC

        Row {
            id: standing

            readonly property Item pieces: standRep
            readonly property int n: Math.max(1, block.keys.length)
            // the least they stand
            readonly property real natural: Theme.dp(160)

            spacing: block.gap

            Repeater {
                id: standRep

                model: block.keys

                CcStandingSlider {
                    required property string modelData

                    width: Math.floor((standing.width - standing.spacing * (standing.n - 1)) / standing.n)
                    height: standing.height
                    icon: block.host.sliderIcon(modelData)
                    value: block.host.sliderValue(modelData)
                    muted: block.host.sliderMuted(modelData)
                    iconClickable: modelData !== "brightness"
                    footIcon: modelData === "volume" ? "speaker" : ""
                    easeValue: block.ease
                    look: block.look === "" ? "plain" : block.look
                    onMoved: (v) => {
                        return block.host.sliderMove(modelData, v);
                    }
                    onIconClicked: block.host.sliderIconClick(modelData)
                    onFootClicked: block.host.showView("output")
                }

            }

        }

    }

    Component {
        id: mediaC

        CcMedia {
            readonly property Item pieces: null
            readonly property real natural: implicitHeight

            title: block.host.mediaTitle
            artist: block.host.mediaArtist
            artUrl: block.host.mediaArt
            progress: block.host.mediaProgress
            playing: block.host.mediaPlaying
            idle: block.host.mediaUp === false
            position: block.host.mediaPosition || 0
            length: block.host.mediaLength || 0
            easeValue: block.ease
            look: block.look === "" ? "card" : block.look
            onPrevious: block.host.mediaPrev()
            onToggle: block.host.mediaToggle()
            onNext: block.host.mediaNext()
            onOpened: block.host.mediaOpen()
            onSeek: (s) => {
                return block.host.mediaSeek(s);
            }
        }

    }

    Component {
        id: weatherC

        CcWeather {
            readonly property Item pieces: null
            readonly property real natural: implicitHeight

            look: block.look === "" ? "card" : block.look
            live: block.live
            onOpened: block.host.blockOpen("weather")
        }

    }

    Component {
        id: networkC

        CcNetwork {
            readonly property Item pieces: null
            readonly property real natural: implicitHeight

            look: block.look === "" ? "graph" : block.look
            live: block.live
            onOpened: block.host.blockOpen("network")
        }

    }

    Component {
        id: powerC

        CcPower {
            readonly property Item pieces: null
            readonly property real natural: implicitHeight

            look: block.look === "" ? "buttons" : block.look
        }

    }

    Component {
        id: agendaC

        CcAgenda {
            readonly property Item pieces: null
            readonly property real natural: implicitHeight

            look: block.look === "" ? "list" : block.look
            onOpened: block.host.blockOpen("agenda")
        }

    }

    // the gauges in rows, spread evenly over the height they are given
    Component {
        id: gaugesC

        Item {
            id: gauges

            readonly property Item pieces: gaugeRep
            readonly property int n: block.keys.length
            readonly property string look: block.look === "" ? "rings" : block.look
            // tiles stretch to fill the block; the rest spread out over it
            readonly property bool stretch: gauges.look === "tiles" || gauges.look === "graph"
            readonly property real colGap: gauges.stretch ? Theme.dp(8) : (gauges.look === "bars" ? Theme.dp(20) : 0)
            readonly property real rowGap: gauges.stretch ? Theme.dp(8) : Theme.dp(12)
            readonly property real least: ({
                "bars": Theme.dp(180),
                "tiles": Theme.dp(104),
                "compact": Theme.dp(112),
                "graph": Theme.dp(140)
            })[gauges.look] || Theme.dp(88)
            readonly property int perRow: block.classicRings ? Math.min(Math.max(1, gauges.n), 4) : block.gaugeCols(Math.max(1, gauges.n), gauges.width, gauges.least, gauges.colGap)
            readonly property int rows: Math.ceil(gauges.n / gauges.perRow)
            readonly property real gaugeH: gaugeRep.count > 0 && gaugeRep.itemAt(0) ? gaugeRep.itemAt(0).implicitHeight : 0
            readonly property real natural: gauges.rows * gauges.gaugeH + Math.max(0, gauges.rows - 1) * gauges.rowGap
            readonly property real spare: Math.max(0, gauges.height - gauges.natural)

            Grid {
                id: grid

                anchors.centerIn: parent
                width: parent.width
                columns: gauges.perRow
                columnSpacing: gauges.colGap
                rowSpacing: gauges.stretch ? gauges.rowGap : gauges.rowGap + gauges.spare / (gauges.rows + 1)

                Repeater {
                    id: gaugeRep

                    model: block.keys

                    CcGauge {
                        required property string modelData
                        readonly property var reading: block.host.gauge(modelData)

                        width: (grid.width - grid.columnSpacing * (grid.columns - 1)) / grid.columns
                        height: gauges.stretch ? Math.max(implicitHeight, (gauges.height - gauges.rowGap * (gauges.rows - 1)) / Math.max(1, gauges.rows)) : implicitHeight
                        look: gauges.look
                        grows: !block.classicRings
                        icon: (Prefs.systemInfoCatalog.find((c) => {
                            return c.key === modelData;
                        }) || {
                            "icon": ""
                        }).icon
                        value: reading.value
                        history: reading.history || []
                        center: reading.center
                        label: reading.label
                        detail: reading.detail
                        tone: reading.tone
                        centerIcon: reading.icon
                        clickable: !!reading.clickable
                        onClicked: block.host.gaugeClick(modelData)
                    }

                }

            }

        }

    }

}
