import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.lucidui

// one page of a tray menu: the app's own menu, or a submenu with the way back
// on top. its rows are the desktop menu's: 38 tall, the shape rounding out
// under the pointer, a chosen option on the secondary container
Item {
    id: page

    required property int index
    property var menu: null
    readonly property var handle: !page.menu ? null : (page.index === 0 ? page.menu.handle : (page.menu.trail[page.index - 1] || null))
    readonly property var from: page.menu && page.index > 0 ? (page.menu.trail[page.index - 1] || null) : null
    // separators only between groups: none to open or close it, never two together
    readonly property var entries: {
        const raw = opener.children ? opener.children.values : [];
        const out = [];
        for (const e of raw) {
            if (!e)
                continue;

            if (page.menu.isSep(e) && (out.length === 0 || page.menu.isSep(out[out.length - 1])))
                continue;

            out.push(e);
        }
        while (out.length > 0 && page.menu.isSep(out[out.length - 1]))
            out.pop();
        return out;
    }
    readonly property int count: page.entries.length
    // a column for icons and ticks, kept only when a row has one
    readonly property bool leads: page.entries.some((e) => {
        return !page.menu.isSep(e) && (String(e.icon || "") !== "" || e.buttonType !== QsMenuButtonType.None);
    })
    readonly property real contentHeight: list.implicitHeight + 2 * page.menu.pad
    property real wantWidth: page.menu ? page.menu.minW : 0

    function measure() {
        let w = page.menu.minW;
        if (page.index > 0)
            w = Math.max(w, backRow.want);

        for (let i = 0; i < rowsRep.count; i++) {
            const it = rowsRep.itemAt(i);
            if (it)
                w = Math.max(w, it.want);

        }
        page.wantWidth = w;
    }

    width: page.menu ? page.menu.width : 0
    height: page.contentHeight
    // the page in view at 0, the ones it came from off to the left, a page
    // leaving off to the right; they move only while a page slides
    x: page.menu ? (page.index - page.menu.shown) * page.menu.width : 0
    visible: page.menu && (page.index === page.menu.shown || page.menu.sliding)
    onEntriesChanged: measureSoon.restart()

    QsMenuOpener {
        id: opener

        menu: page.handle
    }

    // measured once the rows are in; a timer goes with the page, where a callLater
    // could outlive it
    Timer {
        id: measureSoon

        interval: 0
        onTriggered: page.measure()
    }

    Column {
        id: list

        x: page.menu.pad
        y: page.menu.pad
        width: page.width - 2 * page.menu.pad

        // a submenu leads with the way back, under the name of the row it came from
        Item {
            id: backRow

            readonly property string text: page.from ? Tray.label(page.from.text) : ""
            readonly property bool lit: backHover.hovered
            readonly property real want: Theme.dp(10) + Theme.dp(20) + Theme.dp(12) + backMetrics.width + Theme.dp(16) + 2 * page.menu.pad

            visible: page.index > 0
            width: list.width
            height: visible ? page.menu.rowH + page.menu.dividerH : 0
            onWantChanged: measureSoon.restart()

            TextMetrics {
                id: backMetrics

                font: backLabel.font
                text: backRow.text
            }

            Item {
                width: parent.width
                height: page.menu.rowH

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: Theme.dp(2)
                    anchors.bottomMargin: Theme.dp(2)
                    radius: backRow.lit ? Theme.radiusSm : Theme.radiusXs
                    color: Theme.text
                    opacity: backTap.pressed ? Theme.statePressed : (backRow.lit ? Theme.stateHover + 0.02 : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                    Behavior on radius {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Icon {
                    id: backIcon

                    x: Theme.dp(10) + Theme.dp(1)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow_back"
                    size: Theme.dp(18)
                    color: Theme.subtext
                }

                Text {
                    id: backLabel

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(10) + Theme.dp(20) + Theme.dp(12)
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: backRow.text
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.variableAxes: Theme.axes(Theme.fontBody, 600, 0)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: backHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: backTap

                    onTapped: page.menu.back()
                }

            }

            Rectangle {
                x: Theme.dp(6)
                y: page.menu.rowH + Math.round((page.menu.dividerH - 1) / 2)
                width: parent.width - Theme.dp(12)
                height: 1
                color: Theme.alpha(Theme.text, 0.1)
            }

        }

        Repeater {
            id: rowsRep

            model: page.entries

            Item {
                id: row

                required property var modelData
                readonly property var entry: row.modelData
                readonly property bool sep: page.menu.isSep(row.entry)
                readonly property bool off: !row.sep && !row.entry.enabled
                readonly property bool sub: !row.sep && row.entry.hasChildren
                readonly property bool checked: !row.sep && row.entry.buttonType !== QsMenuButtonType.None && row.entry.checkState !== Qt.Unchecked
                readonly property string text: row.sep ? "" : Tray.label(row.entry.text)
                readonly property string glyph: row.sep ? "" : Tray.iconSource(row.entry.icon)
                readonly property bool lit: rowHover.hovered && !row.off
                readonly property real inset: page.leads ? Theme.dp(10) + Theme.dp(20) + Theme.dp(12) : Theme.dp(14)
                readonly property real want: row.sep ? 0 : row.inset + metrics.width + Theme.dp(16) + (row.sub ? Theme.dp(24) : 0) + 2 * page.menu.pad

                width: list.width
                height: row.sep ? page.menu.dividerH : page.menu.rowH
                onWantChanged: measureSoon.restart()

                TextMetrics {
                    id: metrics

                    font: label.font
                    text: row.text
                }

                Rectangle {
                    visible: row.sep
                    x: Theme.dp(6)
                    y: Math.round((page.menu.dividerH - 1) / 2)
                    width: parent.width - Theme.dp(12)
                    height: 1
                    color: Theme.alpha(Theme.text, 0.1)
                }

                Item {
                    visible: !row.sep
                    anchors.fill: parent

                    // m3 expressive: a chosen option sits on the secondary container,
                    // and a lit row's shape rounds out under the pointer. inset, so two
                    // chosen rows in a row stay two shapes
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: Theme.dp(2)
                        anchors.bottomMargin: Theme.dp(2)
                        radius: row.lit || row.checked ? Theme.radiusSm : Theme.radiusXs
                        color: Theme.secondaryContainer
                        visible: row.checked
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: Theme.dp(2)
                        anchors.bottomMargin: Theme.dp(2)
                        radius: row.lit ? Theme.radiusSm : Theme.radiusXs
                        color: row.checked ? Theme.fgSecondaryContainer : Theme.text
                        opacity: row.off ? 0 : (rowTap.pressed ? Theme.statePressed : (row.lit ? Theme.stateHover + 0.02 : 0))

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                        Behavior on radius {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    // the app's icon for the row, or the tick of a chosen option
                    Item {
                        id: lead

                        visible: page.leads
                        x: Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(20)
                        height: Theme.dp(20)
                        opacity: row.off ? 0.38 : 1

                        Image {
                            readonly property bool symbolic: row.glyph.indexOf("symbolic") !== -1

                            anchors.centerIn: parent
                            width: Theme.dp(18)
                            height: Theme.dp(18)
                            visible: !row.checked && row.glyph !== "" && status === Image.Ready
                            source: row.glyph
                            sourceSize.width: Theme.dp(18) * 2
                            sourceSize.height: Theme.dp(18) * 2
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            // never off the main thread: icon theme sources take the shell down
                            asynchronous: false
                            // a symbolic icon is one shape meant to take the text's colour
                            layer.enabled: symbolic

                            layer.effect: MultiEffect {
                                brightness: 1
                                colorization: 1
                                colorizationColor: Theme.subtext
                            }

                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: row.checked
                            name: "check"
                            size: Theme.dp(18)
                            color: Theme.fgSecondaryContainer
                        }

                    }

                    Text {
                        id: label

                        anchors.left: parent.left
                        anchors.leftMargin: row.inset
                        anchors.right: chevron.visible ? chevron.left : parent.right
                        anchors.rightMargin: chevron.visible ? Theme.dp(4) : Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.text
                        color: row.checked ? Theme.fgSecondaryContainer : Theme.text
                        opacity: row.off ? 0.38 : 1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.variableAxes: Theme.axes(Theme.fontBody, row.checked ? 600 : 520, 0)
                        font.weight: row.checked ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }

                    Icon {
                        id: chevron

                        visible: row.sub
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(6)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_right"
                        size: Theme.dp(18)
                        color: Theme.subtext
                        opacity: row.off ? 0.38 : 1
                    }

                    HoverHandler {
                        id: rowHover

                        enabled: !row.off
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: rowTap

                        enabled: !row.off
                        onTapped: {
                            if (row.sub) {
                                page.menu.push(row.entry);
                                return ;
                            }
                            row.entry.triggered();
                            page.menu.chosen();
                        }
                    }

                }

            }

        }

    }

    Behavior on x {
        enabled: page.menu && page.menu.sliding

        NumberAnimation {
            duration: Theme.barDurEnter
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

}
