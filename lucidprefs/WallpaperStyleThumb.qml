import QtQuick
import qs

// one wallpaper picker style as a flat miniature of itself; a tap uses it
Rectangle {
    id: tile

    property string styleId: ""
    property string label: ""
    readonly property bool selected: Prefs.wallpaperPickerStyle === tile.styleId
    readonly property color ink: Theme.alpha(Theme.text, 0.28)
    // strip: how fast the neighbours shrink and how many show, as widths in the miniature
    readonly property var stripShare: Prefs.wallpaperStripSteps === "soft" ? [0.82, 0.64] : (Prefs.wallpaperStripSteps === "steep" ? [0.56, 0.30] : [0.70, 0.44])
    readonly property int stripSides: Prefs.wallpaperStripSides === 3 ? 3 : 2
    readonly property var stripWidths: {
        var base = 34;
        var tiers = [base, base * tile.stripShare[0], base * tile.stripShare[1], base * tile.stripShare[1] * 0.68];
        var total = 0;
        var out = [];
        for (var o = -tile.stripSides; o <= tile.stripSides; o++) {
            out.push(tiers[Math.abs(o)]);
            total += tiers[Math.abs(o)] + 4;
        }
        var k = Math.min(1, (screenBox.width - 8) / total);
        return out.map(function (w) {
            return { "w": Math.round(w * k), "h": Math.round(w * k * 1.12), "main": false };
        }).map(function (c, i) {
            c.main = i === tile.stripSides;
            return c;
        });
    }
    // tiles: rows and shape
    readonly property int tileRows: Math.max(2, Math.min(5, Math.round(Prefs.wallpaperTilesRows) || 2))
    readonly property bool tilesWide: Prefs.wallpaperTilesAspect === "wide"
    readonly property real tileH: (screenBox.height - 8 - (tile.tileRows - 1) * 4) / tile.tileRows
    readonly property real tileW: tile.tilesWide ? tile.tileH * 16 / 9 : tile.tileH
    readonly property int tileCols: Math.max(1, Math.floor((screenBox.width - 4) / (tile.tileW + 4)))
    // the picked tile: a column in from the middle, in the middle row, whatever fits
    readonly property int tilePick: Math.min(tile.tileRows * tile.tileCols - 1, tile.tileRows * Math.floor(tile.tileCols / 2) + Math.floor(tile.tileRows / 2))
    // bento: the main wallpaper's share and whether the two before it show
    readonly property bool bentoPrev: Prefs.wallpaperBentoPrev !== false
    readonly property real bentoHero: Prefs.wallpaperBentoHero === "small" ? 30 : (Prefs.wallpaperBentoHero === "large" ? 52 : 38)
    // pills is drawn in the shape it is set to
    readonly property string pills: Prefs.wallpaperPillsShape === "full" || Prefs.wallpaperPillsShape === "wave" ? Prefs.wallpaperPillsShape : "uniform"

    width: Theme.dp(150)
    height: screenBox.height + caption.implicitHeight + Theme.dp(28)
    radius: Theme.radiusMd
    color: tile.selected ? Theme.alpha(Theme.accent, 0.14) : (area.containsMouse ? Theme.bgHover : Theme.bgSunken)
    border.width: tile.selected ? 2 : 0
    border.color: Theme.accent

    Behavior on color {
        ColorAnimation {
            duration: Theme.durShort
        }

    }

    Rectangle {
        id: screenBox

        x: Theme.dp(10)
        y: Theme.dp(10)
        width: parent.width - Theme.dp(20)
        height: Theme.dp(58)
        radius: Theme.radiusXs
        color: Theme.bgSunken
        clip: true

        // every miniature is drawn from the shell's own radii, so it squares off with them
        // strip: the picked card big, its neighbours stepping down
        Row {
            anchors.centerIn: parent
            spacing: Theme.dp(4)
            visible: tile.styleId === "strip"

            Repeater {
                model: tile.stripWidths

                Rectangle {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: modelData.w
                    height: modelData.h
                    radius: Theme.rad(modelData.main ? 6 : 4)
                    color: modelData.main ? Theme.accent : tile.ink
                }

            }

        }

        // pills: narrow pills with one opened into a card
        Row {
            anchors.centerIn: parent
            spacing: Theme.dp(4)
            visible: tile.styleId === "pills" && tile.pills === "uniform"

            Repeater {
                model: 7

                Rectangle {
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter
                    width: index === 3 ? Theme.dp(34) : Theme.dp(7)
                    height: index === 3 ? Theme.dp(38) : Theme.dp(22)
                    radius: index === 3 ? Theme.rad(6) : Theme.pill(7)
                    color: index === 3 ? Theme.accent : tile.ink
                }

            }

        }

        // tiles: as many rows as set, square or wide, the picked one rounder
        Grid {
            anchors.centerIn: parent
            rows: tile.tileRows
            flow: Grid.TopToBottom
            spacing: Theme.dp(4)
            visible: tile.styleId === "tiles"

            Repeater {
                model: tile.tileRows * tile.tileCols

                Rectangle {
                    required property int index

                    width: tile.tileW
                    height: tile.tileH
                    radius: Theme.rad(index === tile.tilePick ? 5 : 3)
                    color: index === tile.tilePick ? Theme.accent : tile.ink
                }

            }

        }

        // accordion: slices of the whole height, one opened
        Row {
            anchors.centerIn: parent
            spacing: Theme.dp(3)
            visible: tile.styleId === "pills" && tile.pills === "full"

            Repeater {
                model: 11

                Rectangle {
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter
                    width: index === 5 ? Theme.dp(30) : Theme.dp(6)
                    height: Theme.dp(50)
                    radius: index === 5 ? Theme.rad(8) : Theme.pill(6)
                    color: index === 5 ? Theme.accent : tile.ink
                }

            }

        }

        // wave: pills as tall as a bell around the picked one
        Row {
            anchors.centerIn: parent
            spacing: Theme.dp(3)
            visible: tile.styleId === "pills" && tile.pills === "wave"

            Repeater {
                model: 11

                Rectangle {
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter
                    width: index === 5 ? Theme.dp(26) : Theme.dp(7)
                    height: index === 5 ? Theme.dp(50) : Math.round(Theme.dp(12) + 26 * Math.exp(-Math.pow(index - 5, Theme.dp(2)) / 10))
                    radius: index === 5 ? Theme.rad(8) : Theme.pill(7)
                    color: index === 5 ? Theme.accent : tile.ink
                }

            }

        }

        // bento: the picked one large, the others in tiles of different sizes
        Item {
            id: bento

            readonly property real x0: tile.bentoPrev ? 14 : 0
            readonly property real rest: bento.width - bento.x0 - tile.bentoHero - 4
            readonly property real xa: bento.x0 + tile.bentoHero + 4

            anchors.fill: parent
            anchors.margins: Theme.dp(5)
            visible: tile.styleId === "bento"

            Rectangle {
                visible: tile.bentoPrev
                x: 0
                y: 0
                width: Theme.dp(10)
                height: Theme.dp(21)
                radius: Theme.rad(3)
                color: tile.ink
            }

            Rectangle {
                visible: tile.bentoPrev
                x: 0
                y: Theme.dp(25)
                width: Theme.dp(10)
                height: Theme.dp(21)
                radius: Theme.rad(3)
                color: tile.ink
            }

            Rectangle {
                x: bento.x0
                y: 0
                width: tile.bentoHero
                height: Theme.dp(46)
                radius: Theme.rad(8)
                color: Theme.accent
            }

            Rectangle {
                x: bento.xa
                y: 0
                width: bento.rest * 0.4 - Theme.dp(2)
                height: Theme.dp(46)
                radius: Theme.rad(5)
                color: tile.ink
            }

            Rectangle {
                x: bento.xa + bento.rest * 0.4 + Theme.dp(2)
                y: 0
                width: bento.rest * 0.3 - Theme.dp(2)
                height: Theme.dp(27)
                radius: Theme.rad(4)
                color: tile.ink
            }

            Rectangle {
                x: bento.xa + bento.rest * 0.4 + Theme.dp(2)
                y: Theme.dp(31)
                width: bento.rest * 0.3 - Theme.dp(2)
                height: Theme.dp(15)
                radius: Theme.rad(4)
                color: tile.ink
            }

            Rectangle {
                x: bento.xa + bento.rest * 0.7 + Theme.dp(2)
                y: 0
                width: bento.rest * 0.3 - Theme.dp(2)
                height: Theme.dp(15)
                radius: Theme.rad(4)
                color: tile.ink
            }

            Rectangle {
                x: bento.xa + bento.rest * 0.7 + Theme.dp(2)
                y: Theme.dp(19)
                width: bento.rest * 0.3 - Theme.dp(2)
                height: Theme.dp(27)
                radius: Theme.rad(4)
                color: tile.ink
            }

        }

    }

    Text {
        id: caption

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: screenBox.bottom
        anchors.topMargin: Theme.dp(8)
        text: tile.label
        color: tile.selected ? Theme.accent : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
        font.weight: tile.selected ? Font.DemiBold : Font.Medium
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Prefs.wallpaperPickerStyle = tile.styleId
    }

}
