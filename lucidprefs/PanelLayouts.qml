import QtQuick
import qs
import qs.lucidui

// ready-made arrangements of the control centre and the ones the user saved,
// each drawn small from where its blocks would sit, with a tile to save the
// one in use. a ready-made one only moves the blocks that are on; a saved one
// brings back everything: which blocks, where, and what each holds
Item {
    id: layouts

    // the rows each block's pieces take, as the builder measures them
    property var needs: ({})
    property bool naming: false
    property string draft: ""
    readonly property var clash: layouts.naming ? Prefs.systemLayoutNamed(layouts.draft) : null
    readonly property int cols: Math.max(1, Math.floor((layouts.width + Theme.dp(10)) / Theme.dp(210)))
    readonly property real tileW: Math.floor((layouts.width - Theme.dp(10) * (layouts.cols - 1)) / layouts.cols)

    // the rows a block takes in another layout: the sliders, turned, take
    // what turned sliders take
    function needsFor(grid) {
        const out = Object.assign({}, layouts.needs);
        const lie = !grid.sliders || grid.sliders.lie === undefined || !!grid.sliders.lie;
        const nowLie = !Prefs.systemGridSaved.sliders || Prefs.systemGridSaved.sliders.lie === undefined || !!Prefs.systemGridSaved.sliders.lie;
        if (lie !== nowLie) {
            const n = Math.max(1, Prefs.systemSliderKeys.length);
            out.sliders = lie ? Math.ceil((n * 50) / 32) : 6;
        }
        return out;
    }

    function suggestion() {
        for (let n = Prefs.systemLayoutList.length + 1; n < 1000; n++) {
            if (Prefs.systemLayoutNamed("Layout " + n) === null)
                return "Layout " + n;

        }
        return "Layout";
    }

    function begin() {
        layouts.draft = layouts.suggestion();
        field.clear();
        field.set(layouts.draft);
        layouts.naming = true;
        field.focusInput();
    }

    function commit() {
        if (layouts.draft.trim() === "")
            return ;

        Prefs.saveSystemLayout(layouts.draft);
        layouts.naming = false;
    }

    width: parent ? parent.width : 0
    implicitHeight: flow.implicitHeight

    Flow {
        id: flow

        width: parent.width
        spacing: Theme.dp(10)

        Repeater {
            model: Prefs.systemLayoutPresets

            LayoutTile {
                required property var modelData
                readonly property var grid: Prefs.systemPresetGrid(modelData.id)

                title: modelData.name
                blurb: modelData.blurb
                keys: Prefs.systemBlockKeys
                place: Prefs.systemGridPlace(Prefs.systemBlockKeys, layouts.needsFor(grid), grid)
                current: Prefs.systemGrid === (Object.keys(grid).length === 0 ? "" : JSON.stringify(grid))
                onChosen: Prefs.applySystemPreset(modelData.id)
            }

        }

        Repeater {
            model: Prefs.systemLayoutList

            LayoutTile {
                required property var modelData
                readonly property var grid: Prefs.systemLayoutGrid(modelData.layout)
                readonly property var shown: Prefs.prefList(modelData.layout.systemBlocks, Prefs.systemBlockCatalog)

                title: modelData.name
                blurb: "Saved " + Qt.formatDate(new Date(Number(modelData.saved) || 0), "d MMMM yyyy")
                keys: shown
                place: Prefs.systemGridPlace(shown, layouts.needsFor(grid), grid)
                current: Prefs.systemLayoutSame(Prefs.systemLayoutNow(), modelData.layout)
                removable: true
                onChosen: Prefs.applySystemLayout(modelData.id)
                onRemoveRequested: Prefs.askConfirm("Delete “" + modelData.name + "”?", "The saved layout goes. The control centre stays as it is now.", "Delete", "cc-layout:" + modelData.id)
            }

        }

        // the layout in use, a name away from being one of these
        LayoutTile {
            id: saveTile

            title: "Save this layout"
            blurb: "Keep the control centre as it is now, to come back to."
            keys: Prefs.systemBlockKeys
            place: Prefs.systemGridPlace(Prefs.systemBlockKeys, layouts.needs)
            mark: "add"
            hideText: layouts.naming
            onChosen: layouts.begin()

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.dp(10)
                spacing: Theme.dp(6)
                visible: layouts.naming
                z: 3

                M3TextField {
                    id: field

                    width: parent.width - save.width - parent.spacing
                    height: Theme.dp(42)
                    placeholder: "Name it"
                    commitOnBlur: false
                    onEdited: (v) => {
                        return layouts.draft = v;
                    }
                    onAccepted: (v) => {
                        layouts.draft = v;
                        layouts.commit();
                    }
                    onCancelled: layouts.naming = false
                }

                M3IconButton {
                    id: save

                    anchors.verticalCenter: field.verticalCenter
                    size: Theme.dp(42)
                    variant: "filled"
                    enabled: layouts.draft.trim() !== ""
                    iconPath: "check"
                    onClicked: layouts.commit()
                }

            }

            // what enter will do, said on the drawing while you type
            Rectangle {
                visible: layouts.naming
                z: 3
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.dp(10) + saveTile.thumbH - height - Theme.dp(6)
                width: hint.implicitWidth + Theme.dp(20)
                height: Theme.dp(24)
                radius: height / 2
                color: Theme.bgOpaque

                Text {
                    id: hint

                    anchors.centerIn: parent
                    text: layouts.clash !== null ? "Updates “" + layouts.clash.name + "”" : "Enter to save · Esc to cancel"
                    color: layouts.clash !== null ? Theme.accent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    font.bold: layouts.clash !== null
                }

            }

        }

    }

    // one layout to pick: its blocks drawn small over its name
    component LayoutTile: Item {
        id: tile

        property string title: ""
        property string blurb: ""
        property var keys: []
        property var place: ({})
        property bool current: false
        property bool removable: false
        property bool hideText: false
        // the mark shown on hover: "check" to put it on, "add" to save
        property string mark: "check"
        readonly property real thumbH: Theme.dp(96)
        // how far the blocks reach, so the drawing fits them
        readonly property int reachX: tile.keys.reduce((n, k) => {
            return tile.place[k] ? Math.max(n, tile.place[k].x + tile.place[k].w) : n;
        }, 1)
        readonly property int reachY: tile.keys.reduce((n, k) => {
            return tile.place[k] ? Math.max(n, tile.place[k].y + tile.place[k].h) : n;
        }, 1)
        readonly property real stepX: Theme.dp(52) + Theme.dp(12)
        readonly property real stepY: Theme.dp(20) + Theme.dp(12)
        readonly property real fullW: tile.reachX * tile.stepX - Theme.dp(12)
        readonly property real fullH: tile.reachY * tile.stepY - Theme.dp(12)
        readonly property real fit: Math.min((tile.width - Theme.dp(36)) / tile.fullW, (tile.thumbH - Theme.dp(16)) / tile.fullH)

        signal chosen()
        signal removeRequested()

        width: layouts.tileW
        height: tile.thumbH + Theme.dp(78)

        // on the tile or its cross alike
        HoverHandler {
            id: hov
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLg
            color: hov.hovered && !tile.hideText ? Theme.bgHover : Theme.bgSunken
            border.width: tile.current ? Theme.dp(2) : 0
            border.color: Theme.accent

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

        // the blocks where they would sit, the grid drawn down to fit
        Item {
            id: thumb

            x: Theme.dp(10)
            y: Theme.dp(10)
            width: tile.width - Theme.dp(20)
            height: tile.thumbH

            Item {
                width: tile.fullW * tile.fit
                height: tile.fullH * tile.fit
                anchors.centerIn: parent

                Repeater {
                    model: tile.keys

                    Rectangle {
                        required property string modelData
                        readonly property var r: tile.place[modelData] || null

                        visible: r !== null
                        x: r ? r.x * tile.stepX * tile.fit : 0
                        y: r ? r.y * tile.stepY * tile.fit : 0
                        width: r ? (r.w * tile.stepX - Theme.dp(12)) * tile.fit : 0
                        height: r ? (r.h * tile.stepY - Theme.dp(12)) * tile.fit : 0
                        radius: Math.min(Theme.dp(6), width / 4, height / 4)
                        color: Theme.alpha(Theme.accent, 0.22)
                        border.width: 1
                        border.color: Theme.alpha(Theme.accent, 0.5)

                        Icon {
                            visible: parent.width > Theme.dp(18) && parent.height > Theme.dp(18)
                            anchors.centerIn: parent
                            name: (Prefs.systemBlockCatalog.find((b) => {
                                return b.key === modelData;
                            }) || {
                                "icon": ""
                            }).icon
                            size: Math.min(Theme.dp(16), parent.height - Theme.dp(4))
                            color: Theme.accent
                        }

                    }

                }

            }

            Rectangle {
                anchors.centerIn: parent
                width: Theme.dp(34)
                height: Theme.dp(34)
                radius: width / 2
                color: Theme.accent
                visible: hov.hovered && !tile.hideText && !(tile.current && tile.mark === "check")

                Icon {
                    anchors.centerIn: parent
                    name: tile.mark
                    size: Theme.dp(20)
                    color: Theme.fgAccent
                }

            }

        }

        Column {
            visible: !tile.hideText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: thumb.bottom
            anchors.leftMargin: Theme.dp(14)
            anchors.rightMargin: Theme.dp(14)
            anchors.topMargin: Theme.dp(8)
            spacing: Theme.dp(2)

            LText {
                width: parent.width
                role: "titleSmall"
                weight: 600
                text: tile.title
                elide: Text.ElideRight
            }

            LText {
                width: parent.width
                role: "bodySmall"
                color: Theme.subtextDim
                text: tile.blurb
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            enabled: !tile.hideText
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.chosen()
        }

        M3IconButton {
            visible: tile.removable && hov.hovered
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(6)
            size: Theme.dp(30)
            iconPath: "close"
            onClicked: tile.removeRequested()
        }

    }

}
