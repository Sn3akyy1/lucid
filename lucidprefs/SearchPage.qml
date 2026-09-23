import QtQuick
import QtQuick.Shapes
import qs

// Settings search: every page with a hit, and under it the rows that matched.
// loaded into a pane like the other pages, so `win` is Settings itself; the
// query, the results and the selection all live there, next to the rail's field
Column {
    id: page

    readonly property var results: win.searchResults
    readonly property var words: win.searchQuery.toLowerCase().split(/\s+/).filter((w) => {
        return w !== "";
    })

    // the nearest Flickable up the tree is this page's pane
    function paneFlick() {
        let p = page.parent;
        while (p) {
            if (p.contentY !== undefined && p.contentHeight !== undefined)
                return p;

            p = p.parent;
        }
        return null;
    }

    // keep the keyboard's pick on screen, clear of the app bar floating on top
    function follow() {
        const flick = page.paneFlick();
        const item = items.itemAt(win.searchSel);
        if (!flick || !item)
            return ;

        if (win.searchSel <= 1) {
            flick.contentY = 0;
            return ;
        }
        const y = item.mapToItem(flick.contentItem, 0, 0).y;
        const top = flick.contentY + win.barShort + 12;
        const bottom = flick.contentY + flick.height - 16;
        if (y < top)
            flick.contentY = Math.max(0, y - win.barShort - 12);
        else if (y + item.height > bottom)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), y + item.height - flick.height + 16);
    }

    // the words of the query picked out in the accent colour, the rest escaped
    function mark(text) {
        const low = text.toLowerCase();
        const hot = [];
        for (let w = 0; w < page.words.length; w++) {
            const word = page.words[w];
            for (let at = low.indexOf(word); at !== -1; at = low.indexOf(word, at + 1)) {
                for (let k = at; k < at + word.length; k++)
                    hot[k] = true;

            }
        }
        const esc = (s) => {
            return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        };
        let out = "";
        let i = 0;
        while (i < text.length) {
            let j = i;
            while (j < text.length && !!hot[j] === !!hot[i])
                j++;
            out += hot[i] ? "<font color=\"" + Theme.accent + "\">" + esc(text.substring(i, j)) + "</font>" : esc(text.substring(i, j));
            i = j;
        }
        return out;
    }

    spacing: 3

    Connections {
        function onSearchSelChanged() {
            Qt.callLater(page.follow);
        }

        target: win
    }

    Text {
        width: parent.width
        visible: page.results.length === 0
        text: !win.searchReady ? "Reading the pages…" : "Nothing in Settings matches “" + win.searchQuery + "”. Search looks through the name and the description of every option, on every page."
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        wrapMode: Text.WordWrap
        leftPadding: 22
        rightPadding: 22
        topPadding: 8
    }

    Repeater {
        id: items

        model: page.results

        Item {
            id: item

            required property var modelData
            required property int index
            readonly property bool isPage: item.modelData.kind === "page"
            readonly property bool selected: win.searchSel === item.index
            readonly property var prev: item.index > 0 ? page.results[item.index - 1] : null
            readonly property var next: item.index < page.results.length - 1 ? page.results[item.index + 1] : null
            readonly property bool groupFirst: !item.prev || item.prev.kind === "page"
            readonly property bool groupLast: !item.next || item.next.kind === "page"
            readonly property color fg: item.selected ? Theme.fgSecondaryContainer : Theme.text

            width: parent.width
            height: item.isPage ? 46 + (item.index > 0 ? 20 : 0) : Math.max(64, labels.implicitHeight + 28)

            Rectangle {
                id: container

                anchors.fill: parent
                anchors.topMargin: item.isPage && item.index > 0 ? 20 : 0
                topLeftRadius: item.isPage || item.groupFirst ? 26 : 6
                topRightRadius: item.isPage || item.groupFirst ? 26 : 6
                bottomLeftRadius: item.isPage || item.groupLast ? 26 : 6
                bottomRightRadius: item.isPage || item.groupLast ? 26 : 6
                color: item.selected ? Theme.secondaryContainer : (item.isPage ? "transparent" : Theme.withBlur(Theme.bgTile))

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    topRightRadius: parent.topRightRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    bottomRightRadius: parent.bottomRightRadius
                    color: item.fg
                    opacity: area.pressed ? Theme.statePressed : (area.containsMouse && !item.selected ? Theme.stateHover * 0.5 : 0)
                }

            }

            // the page: its rail glyph and name, and a way straight to it
            Item {
                anchors.fill: container
                visible: item.isPage

                Item {
                    id: pageMark

                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22

                    NavGlyph {
                        anchors.fill: parent
                        visible: item.modelData.key !== "about" && item.modelData.key !== "users"
                        kind: item.modelData.key
                        color: item.selected ? item.fg : Theme.accent
                    }

                    LucidaMark {
                        anchors.fill: parent
                        strokeWidth: 3.4
                        visible: item.modelData.key === "about"
                        ringColor: item.selected ? item.fg : Theme.accent
                        starColor: item.selected ? item.fg : Theme.accent
                    }

                    Shape {
                        anchors.fill: parent
                        visible: item.modelData.key === "users"
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: 0
                            fillColor: item.selected ? item.fg : Theme.accent

                            PathSvg {
                                path: "M12 19.2c-2.5 0-4.71-1.28-6-3.2.03-2 4-3.1 6-3.1s5.97 1.1 6 3.1a7.232 7.232 0 0 1-6 3.2M12 5a3 3 0 0 1 3 3 3 3 0 0 1-3 3 3 3 0 0 1-3-3 3 3 0 0 1 3-3m0-3A10 10 0 0 0 2 12a10 10 0 0 0 10 10 10 10 0 0 0 10-10c0-5.53-4.5-10-10-10Z"
                            }

                        }

                        transform: Scale {
                            xScale: 22 / 24
                            yScale: 22 / 24
                        }

                    }

                }

                Text {
                    anchors.left: pageMark.right
                    anchors.leftMargin: 14
                    anchors.right: pageGo.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.mark(item.modelData.title)
                    textFormat: Text.StyledText
                    color: item.selected ? item.fg : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleSm
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    id: pageGo

                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open page"
                    color: item.selected ? item.fg : Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelMd
                    opacity: item.selected || area.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

            }

            // a row: its title with the match picked out, then the card it sits
            // in and its description
            Column {
                id: labels

                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.right: chevron.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                visible: !item.isPage

                Text {
                    width: parent.width
                    text: item.isPage ? "" : page.mark(item.modelData.title)
                    textFormat: Text.StyledText
                    color: item.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: item.isPage ? "" : [item.modelData.cardLabel, item.modelData.description].filter((s) => {
                        return s !== "";
                    }).join("  ·  ")
                    visible: text !== ""
                    color: item.selected ? item.fg : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    opacity: item.selected ? 0.8 : 1
                }

            }

            Shape {
                id: chevron

                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                visible: !item.isPage
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: item.selected ? item.fg : Theme.subtextDim

                    PathSvg {
                        path: "M8.59 16.59 13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41Z"
                    }

                }

                transform: Scale {
                    xScale: 20 / 24
                    yScale: 20 / 24
                }

            }

            MouseArea {
                id: area

                anchors.fill: container
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.openResult(item.modelData)
            }

        }

    }

}
