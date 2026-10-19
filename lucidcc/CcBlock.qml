import QtQuick
import qs
import qs.lucidui

// one block of the control centre, drawn the same in the panel and in the
// editor on its module card: the big tiles, the small ones, the sliders, what
// is playing or the gauges. it fills the box it is given: standing sliders
// stretch, lying ones and the gauges spread out, the media card keeps to the
// middle and the tiles to the top. the host says what each piece shows and
// takes its taps:
//   tiles   tileIcon(k) tileLabel(k) bigName(k) bigSub(k) tileChecked(k)
//           tilePages tileAct(k) showView(v)
//   sliders sliderIcon(k) sliderValue(k) sliderMuted(k) sliderMove(k, v)
//           sliderIconClick(k)
//   media   mediaTitle mediaArtist mediaArt mediaProgress mediaPlaying
//           mediaPrev() mediaToggle() mediaNext() mediaOpen()
//   gauges  gauge(k), as { value, center, label, detail, tone, icon,
//           clickable }, and gaugeClick(k)
//   expanded, while the values may ease
Item {
    id: block

    // sliders, bigtiles, tiles, media or gauges
    property string kind: ""
    property var keys: []
    property var host: null
    // small tiles and big ones to a row, and the gap between pieces
    property int cols: 6
    property int bigCols: 2
    property real gap: Theme.dp(8)
    property bool standing: false
    // a card behind the tiles and the sliders too; media and gauges always have one
    property bool cards: false
    readonly property bool carded: block.kind === "media" || block.kind === "gauges" || block.cards
    readonly property real pad: block.carded && block.kind !== "media" ? Theme.dp(12) : 0
    readonly property bool ease: !!block.host && !!block.host.expanded
    // what its pieces need down, before it is given more
    readonly property real natural: body.item ? body.item.natural : 0

    // gauges sharing a card: as many to a row as leave each its 88, in rows as even as can be
    function gaugeCols(n, width) {
        const most = Math.max(1, Math.min(n, Math.floor(width / Theme.dp(88))));
        return Math.max(1, Math.ceil(n / Math.ceil(n / most)));
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

    implicitHeight: block.natural + block.pad * 2

    Rectangle {
        anchors.fill: parent
        visible: block.carded
        radius: Theme.shapeLgInc
        color: Theme.withBlur(Theme.surfaceHigh)
    }

    Loader {
        id: body

        x: block.pad
        y: block.pad
        width: Math.max(0, block.width - block.pad * 2)
        height: Math.max(0, block.height - block.pad * 2)
        sourceComponent: {
            switch (block.kind) {
            case "sliders":
                return block.standing ? standingC : lyingC;
            case "media":
                return mediaC;
            case "gauges":
                return gaugesC;
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
            readonly property real natural: flow.implicitHeight
            readonly property bool big: block.kind === "bigtiles"
            readonly property int perRow: Math.max(1, flow.big ? block.bigCols : block.cols)
            readonly property real pieceW: Math.floor((flow.width - flow.spacing * (flow.perRow - 1)) / flow.perRow)

            spacing: block.gap

            Repeater {
                id: tileRep

                model: block.keys

                Item {
                    id: slot

                    required property string modelData
                    readonly property bool hasPage: block.host.tilePages.indexOf(slot.modelData) !== -1

                    width: flow.pieceW
                    // the small ones' names sit in the gap, so their row keeps the grid's
                    height: flow.big ? Theme.dp(64) : flow.pieceW + Theme.dp(24)

                    CcBigTile {
                        visible: flow.big
                        width: parent.width
                        icon: block.host.tileIcon(slot.modelData)
                        name: block.host.bigName(slot.modelData)
                        sub: block.host.bigSub(slot.modelData)
                        checked: block.host.tileChecked(slot.modelData)
                        hasPage: slot.hasPage
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
            readonly property real natural: lying.n * Theme.dp(50) + (lying.n - 1) * Theme.dp(8)

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: lying.n > 1 ? Math.max(Theme.dp(8), (lying.height - lying.n * Theme.dp(50)) / (lying.n - 1)) : 0

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
            easeValue: block.ease
            onPrevious: block.host.mediaPrev()
            onToggle: block.host.mediaToggle()
            onNext: block.host.mediaNext()
            onOpened: block.host.mediaOpen()
        }

    }

    // the gauges in rows, spread evenly over the height they are given
    Component {
        id: gaugesC

        Item {
            id: gauges

            readonly property Item pieces: gaugeRep
            readonly property int n: block.keys.length
            readonly property int perRow: block.gaugeCols(Math.max(1, gauges.n), gauges.width)
            readonly property int rows: Math.ceil(gauges.n / gauges.perRow)
            readonly property real gaugeH: gaugeRep.count > 0 && gaugeRep.itemAt(0) ? gaugeRep.itemAt(0).implicitHeight : 0
            readonly property real natural: gauges.rows * gauges.gaugeH + Math.max(0, gauges.rows - 1) * Theme.dp(12)
            readonly property real spare: Math.max(0, gauges.height - gauges.natural)

            Grid {
                id: grid

                anchors.centerIn: parent
                width: parent.width
                columns: gauges.perRow
                rowSpacing: Theme.dp(12) + gauges.spare / (gauges.rows + 1)

                Repeater {
                    id: gaugeRep

                    model: block.keys

                    CcGauge {
                        required property string modelData
                        readonly property var reading: block.host.gauge(modelData)

                        width: grid.width / grid.columns
                        value: reading.value
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
