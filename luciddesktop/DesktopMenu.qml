import "../luciddocks"
import QtQuick
import Quickshell.Hyprland
import qs
import qs.lucidui

// the desktop's right-click menu: one card, and beside it a card for each submenu
// that is open, cascading the way windows and macos do. a row with an arrow opens
// its submenu on hover or click; the keyboard walks them too. it fills the overlay
// it lives in and places its cards itself
Item {
    id: menu

    property bool open: false
    // where the click landed, in layer coordinates
    property real originX: 0
    property real originY: 0
    property real fieldW: 1920
    property real fieldH: 1080
    // the strips the bar and the dock reserve stay clear, [left, top, right, bottom]
    property var monitor: null
    readonly property var reserved: (menu.monitor && menu.monitor.lastIpcObject && menu.monitor.lastIpcObject.reserved) || [0, 0, 0, 0]
    readonly property real minX: menu.edge + (menu.reserved[0] || 0)
    readonly property real minY: menu.edge + (menu.reserved[1] || 0)
    readonly property real maxX: menu.fieldW - menu.edge - (menu.reserved[2] || 0)
    readonly property real maxY: menu.fieldH - menu.edge - (menu.reserved[3] || 0)
    // the desktop icons are on this screen: their entries lead the menu
    property bool icons: false
    // a list of its own instead of the desktop's: an icon's menu
    property var custom: null
    readonly property real edge: Theme.dp(10)
    readonly property real gap: Theme.dp(10)
    readonly property real pad: Theme.dp(6)
    readonly property real rowH: Theme.dp(38)
    readonly property real stripH: Theme.dp(46)
    readonly property real dividerH: Theme.dp(9)
    readonly property real minW: Theme.dp(200)
    readonly property real maxW: Theme.dp(300)
    readonly property var rootRows: menu.custom !== null ? menu.custom : menu.desktopActions
    readonly property var desktopActions: {
        var arr = menu.icons ? DesktopIcons.desktopRows() : [];
        // the icons' own rows go with them, but turning them back on stays in reach
        if (!menu.icons) {
            var show = DesktopIcons.showRows();
            if (show.length > 0)
                arr.push({
                "label": "View",
                "glyph": "grid_view",
                "submenu": show
            });

        }
        var lead = arr.length > 0;
        arr.push({
            "id": "wallpaper",
            "label": "Change Wallpaper",
            "glyph": DockIcons.wallpaper,
            "divider": lead
        });
        arr.push({
            "id": "theme",
            "label": "Change Theme",
            "glyph": DockIcons.palette
        });
        arr.push({
            "id": "editMode",
            "label": Edit.active ? "Done Editing" : "Edit Desktop",
            "glyph": Edit.active ? "check" : "edit",
            "divider": true
        });
        arr.push({
            "id": "screenshot",
            "label": "Take a Screenshot",
            "glyph": DockIcons.camera,
            "divider": true
        });
        arr.push({
            "id": "keyboard",
            "label": "On-Screen Keyboard",
            "glyph": DockIcons.keyboard
        });
        arr.push({
            "id": "settings",
            "label": "Settings",
            "glyph": DockIcons.settings,
            "divider": true
        });
        return arr;
    }
    // the open cascade: the menu itself, then {src, from, row} for each submenu
    property var levels: [{
        "src": "root",
        "from": -1,
        "row": -1
    }]
    // the row lit at each level, by the pointer or the keyboard
    property var lit: [-1]
    property int focusLevel: 0
    // the cards as placed, for the blur
    property var cardItems: []
    readonly property bool showing: menu.open || (menu.cardItems.length > 0 && menu.cardItems[0] && menu.cardItems[0].opacity > 0.01)

    signal chosen(string id)

    function rowsAt(i) {
        var lv = menu.levels[i];
        if (!lv)
            return [];

        if (lv.src === "root")
            return menu.rootRows;

        if (typeof lv.src === "string")
            return DesktopIcons.submenu(lv.src);

        return lv.src || [];
    }

    function openAt(px, py) {
        // the reserved strips follow the bar, which can move or hide
        Hyprland.refreshMonitors();
        menu.originX = px;
        menu.originY = py;
        menu.levels = [{
            "src": "root",
            "from": -1,
            "row": -1
        }];
        menu.lit = [-1];
        menu.focusLevel = 0;
        openTimer.stop();
        closeTimer.stop();
        menu.open = true;
    }

    function setLit(level, row) {
        var l = menu.lit.slice(0, Math.max(level + 1, menu.levels.length));
        while (l.length <= level)l.push(-1)
        l[level] = row;
        menu.lit = l;
    }

    function openSub(level, row) {
        var r = menu.rowsAt(level)[row];
        if (!r || !r.submenu || r.disabled)
            return ;

        if (menu.levels.length > level + 1 && menu.levels[level + 1].row === row)
            return ;

        var lv = menu.levels.slice(0, level + 1);
        lv.push({
            "src": r.submenu,
            "from": level,
            "row": row
        });
        var l = menu.lit.slice(0, level + 1);
        l[level] = row;
        l.push(-1);
        menu.levels = lv;
        menu.lit = l;
    }

    function closeAfter(level) {
        if (menu.levels.length <= level + 1)
            return ;

        menu.levels = menu.levels.slice(0, level + 1);
        menu.lit = menu.lit.slice(0, level + 1);
        if (menu.focusLevel > level)
            menu.focusLevel = level;

    }

    function usable(r) {
        return r && !r.strip && !r.disabled && (r.id || r.submenu);
    }

    function step(level, from, dir) {
        var rows = menu.rowsAt(level);
        var n = rows.length;
        for (var k = 1; k <= n; k++) {
            var i = ((from + dir * k) % n + n) % n;
            if (from < 0 && dir < 0)
                i = ((n - k) % n + n) % n;

            if (menu.usable(rows[i]))
                return i;

        }
        return -1;
    }

    function activate(level, row) {
        var r = menu.rowsAt(level)[row];
        if (!menu.usable(r))
            return ;

        if (r.submenu) {
            menu.openSub(level, row);
            menu.focusLevel = level + 1;
            menu.setLit(level + 1, menu.step(level + 1, -1, 1));
            return ;
        }
        if (r.stay) {
            menu.chosen(r.id);
            return ;
        }
        menu.open = false;
        menu.chooseLater(r.id);
    }

    function choose(id) {
        menu.open = false;
        menu.chooseLater(id);
    }

    // what was picked runs once the cards have faded: a heavy action would stall the
    // fade, and anything it changes would reshape cards still on screen
    function chooseLater(id) {
        if (chosenTimer.running)
            menu.chosen(chosenTimer.pick);

        chosenTimer.pick = id;
        chosenTimer.restart();
    }

    function key(e) {
        var lv = menu.focusLevel;
        var at = menu.lit[lv] !== undefined ? menu.lit[lv] : -1;
        if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) {
            menu.setLit(lv, menu.step(lv, at, 1));
        } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) {
            menu.setLit(lv, menu.step(lv, at, -1));
        } else if (e.key === Qt.Key_Home) {
            menu.setLit(lv, menu.step(lv, -1, 1));
        } else if (e.key === Qt.Key_End) {
            menu.setLit(lv, menu.step(lv, -1, -1));
        } else if (e.key === Qt.Key_Right) {
            var r = menu.rowsAt(lv)[at];
            if (r && r.submenu)
                menu.activate(lv, at);

        } else if (e.key === Qt.Key_Left) {
            if (lv > 0) {
                menu.closeAfter(lv - 1);
                menu.focusLevel = lv - 1;
            }
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (at >= 0)
                menu.activate(lv, at);

        } else if (e.key === Qt.Key_Escape) {
            if (lv > 0) {
                menu.closeAfter(lv - 1);
                menu.focusLevel = lv - 1;
            } else {
                menu.open = false;
            }
        } else if (e.text.length === 1 && e.text.charCodeAt(0) > 32) {
            // a letter jumps to the next row that starts with it
            var rows = menu.rowsAt(lv);
            var ch = e.text.toLowerCase();
            for (var k = 1; k <= rows.length; k++) {
                var i = (Math.max(at, -1) + k) % rows.length;
                if (menu.usable(rows[i]) && (rows[i].label || "").toLowerCase().indexOf(ch) === 0) {
                    menu.setLit(lv, i);
                    break;
                }
            }
        } else {
            return ;
        }
        e.accepted = true;
    }

    // the painted rectangle of a card, scale included; empty past the open ones
    function cardRect(i) {
        var c = menu.cardItems[i];
        if (!c || i >= menu.levels.length || c.opacity < 0.01)
            return Qt.rect(0, 0, 0, 0);

        // scale and jelly both hold the same corner still
        var sx = c.scale * c.jellyX;
        var sy = c.scale * c.jellyY;
        var ox = c.flipX ? c.width : 0;
        var oy = c.flipY ? c.height : 0;
        return Qt.rect(c.x + c.slide + ox * (1 - sx), c.y + oy * (1 - sy), c.width * sx, c.height * sy);
    }

    function cardRadius(i) {
        var c = menu.cardItems[i];
        return c ? c.radius * c.scale : 0;
    }

    anchors.fill: parent
    visible: menu.showing

    // a submenu opens after a moment under the pointer, and goes after a moment away
    Timer {
        id: openTimer

        property int level: 0
        property int row: -1

        interval: 160
        onTriggered: menu.openSub(openTimer.level, openTimer.row)
    }

    Timer {
        id: chosenTimer

        property string pick: ""

        interval: Theme.durQuick + 20
        onTriggered: menu.chosen(chosenTimer.pick)
    }

    // one entry a card: an integer model rebuilds every card, the menu itself too,
    // each time a submenu comes or goes
    ListModel {
        id: cardModel

        ListElement {
            d: 0
        }

    }

    onLevelsChanged: {
        while (cardModel.count > menu.levels.length) {
            cardModel.remove(cardModel.count - 1);
        }
        while (cardModel.count < menu.levels.length) {
            cardModel.append({
                "d": 0
            });
        }
    }

    Timer {
        id: closeTimer

        property int level: 0

        interval: 300
        onTriggered: menu.closeAfter(closeTimer.level)
    }

    Repeater {
        id: cards

        model: cardModel

        Rectangle {
            id: card

            required property int index
            readonly property var level: menu.levels[card.index] || null
            readonly property var rows: menu.rowsAt(card.index)
            readonly property bool focused: menu.focusLevel === card.index
            readonly property var parentCard: card.level && card.level.from >= 0 ? menu.cardItems[card.level.from] || null : null
            // wide enough for its longest row, within m3's bounds
            property real want: menu.minW
            readonly property real cw: Math.round(Math.max(menu.minW, Math.min(menu.maxW, card.want)))
            readonly property real ch: list.implicitHeight + 2 * menu.pad
            // the menu opens down-right of the cursor and flips rather than run off; a
            // submenu sits beside its row, on whichever side has room
            readonly property bool flipX: card.index === 0 ? menu.originX + card.cw > menu.maxX : (card.parentCard ? card.parentCard.x + card.parentCard.width + menu.gap + card.cw > menu.maxX : false)
            readonly property bool flipY: card.index === 0 && menu.originY + card.ch > menu.maxY
            // the slide a submenu comes in on, from its parent's side
            property real slide: 0
            readonly property real jellyX: cardJelly.xScale
            readonly property real jellyY: cardJelly.yScale
            readonly property bool jellyWobbling: cardJelly.wobbling
            readonly property bool menuShown: menu.open

            // in: the menu grows out of the click and wobbles; out: m3's quick fade in
            // place, never shrinking away, and any wobble left plays out under it
            onMenuShownChanged: {
                if (card.menuShown) {
                    vanish.stop();
                    cardJelly.rest();
                    if (card.opacity < 0.05)
                        card.scale = card.index === 0 ? 0.8 : 1;

                    appear.restart();
                    if (card.index === 0)
                        cardJelly.kickAfter(Math.min(0.09, Theme.dp(20) / Math.max(1, card.ch)), Math.round(Theme.durEnter * 0.3));

                } else {
                    appear.stop();
                    vanish.restart();
                }
            }

            function rowY(i) {
                var y = menu.pad;
                for (var k = 0; k < i && k < card.rows.length; k++)
                    y += menu.heightOf(card.rows[k]);
                return y + (card.rows[i] && card.rows[i].divider ? menu.dividerH : 0);
            }

            function measure() {
                var w = menu.minW;
                for (var i = 0; i < rowsRep.count; i++) {
                    var it = rowsRep.itemAt(i);
                    if (it)
                        w = Math.max(w, it.want);

                }
                card.want = w;
            }

            width: card.cw
            height: card.ch
            x: {
                if (card.index === 0)
                    return Math.round(Math.max(menu.minX, card.flipX ? menu.originX - card.cw : menu.originX));

                if (!card.parentCard)
                    return 0;

                return Math.round(card.flipX ? card.parentCard.x - card.cw - menu.gap : card.parentCard.x + card.parentCard.width + menu.gap);
            }
            y: {
                if (card.index === 0)
                    return Math.round(Math.max(menu.minY, card.flipY ? menu.originY - card.ch : Math.min(menu.originY, menu.maxY - card.ch)));

                if (!card.parentCard)
                    return 0;

                var want = card.parentCard.y + card.parentCard.rowY(card.level.row) - menu.pad;
                return Math.round(Math.max(menu.minY, Math.min(menu.maxY - card.ch, want)));
            }
            // m3 expressive: the card in focus rounds out, the one it came from squares off a little
            radius: card.focused && menu.levels.length > 1 ? Theme.radiusLg : Theme.radiusMd
            color: Theme.bg
            border.width: Theme.blurAmount > 0 ? 0 : 1
            border.color: Theme.alpha(Theme.text, 0.06)
            transformOrigin: card.flipX ? (card.flipY ? Item.BottomRight : Item.TopRight) : (card.flipY ? Item.BottomLeft : Item.TopLeft)
            onRowsChanged: measureSoon.restart()
            Component.onCompleted: {
                // a submenu is made with the menu open; the menu's own card at startup
                card.opacity = menu.open ? 1 : 0;
                var c = menu.cardItems.slice();
                c[card.index] = card;
                menu.cardItems = c;
                if (card.index > 0)
                    enter.restart();

            }
            Component.onDestruction: {
                if (menu.cardItems[card.index] === card) {
                    var c = menu.cardItems.slice();
                    c[card.index] = null;
                    menu.cardItems = c;
                }
            }

            transform: [
                Jelly {
                    id: cardJelly

                    target: card
                    anchorX: card.flipX ? 1 : 0
                    anchorY: card.flipY ? 1 : 0
                    frequency: 4.4
                },
                Translate {
                    x: card.slide
                }
            ]

            // measured once the rows are in; a timer goes with the card, where a callLater
            // could outlive a submenu that closed first
            Timer {
                id: measureSoon

                interval: 0
                onTriggered: card.measure()
            }

            // a submenu swapped for another at the same depth comes in again
            Connections {
                function onLevelsChanged() {
                    if (card.index > 0 && card.level && card.level.row !== enter.lastRow)
                        enter.restart();

                }

                target: menu
            }

            ParallelAnimation {
                id: enter

                property int lastRow: -2

                onStarted: {
                    enter.lastRow = card.level ? card.level.row : -2;
                    cardJelly.kickAfter(Math.min(0.07, Theme.dp(14) / Math.max(1, card.ch)), Math.round(Theme.durMedium * 0.3));
                }

                NumberAnimation {
                    target: card
                    property: "slide"
                    from: card.flipX ? Theme.dp(10) : -Theme.dp(10)
                    to: 0
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

                NumberAnimation {
                    target: inner
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.durShort
                }

            }

            // the pointer inside a submenu keeps it, and its parent row, open
            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        closeTimer.stop();
                        if (openTimer.level < card.index)
                            openTimer.stop();

                        menu.focusLevel = card.index;
                    }
                }
            }

            Item {
                id: inner

                anchors.fill: parent

                Column {
                    id: list

                    x: menu.pad
                    y: menu.pad
                    width: card.width - 2 * menu.pad

                    Repeater {
                        id: rowsRep

                        model: card.rows

                        Item {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property bool isStrip: row.modelData.strip !== undefined
                            readonly property bool lit: menu.lit[card.index] === row.index
                            // its submenu is the one open beside it
                            readonly property bool opened: menu.levels.length > card.index + 1 && menu.levels[card.index + 1].row === row.index
                            readonly property bool checked: row.modelData.check === true
                            readonly property bool disabled: row.modelData.disabled === true || (!row.modelData.id && !row.modelData.submenu && !row.isStrip)
                            readonly property color ink: row.modelData.danger ? Theme.error : (row.checked ? Theme.fgSecondaryContainer : Theme.text)
                            readonly property real want: row.isStrip ? row.modelData.strip.length * menu.stripH + 2 * menu.pad : Theme.dp(10) + Theme.dp(20) + Theme.dp(12) + label.implicitWidth + Theme.dp(16) + (trail.visible ? trail.implicitWidth + Theme.dp(8) : 0) + (chev.visible ? Theme.dp(22) : 0) + 2 * menu.pad

                            width: list.width
                            height: menu.heightOf(row.modelData)
                            onWantChanged: measureSoon.restart()

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: Theme.dp(6)
                                anchors.rightMargin: Theme.dp(6)
                                y: Math.round((menu.dividerH - 1) / 2)
                                height: 1
                                color: Theme.alpha(Theme.text, 0.1)
                                visible: row.modelData.divider === true
                            }

                            // the everyday actions as icon buttons, windows 11 style
                            Row {
                                id: strip

                                visible: row.isStrip
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: Theme.dp(2)
                                spacing: Theme.dp(2)

                                Repeater {
                                    model: row.isStrip ? row.modelData.strip : []

                                    Item {
                                        id: btn

                                        required property var modelData
                                        readonly property bool off: btn.modelData.disabled === true

                                        width: menu.stripH
                                        height: menu.stripH - Theme.dp(4)

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: btnHover.hovered ? Theme.radiusMd : Theme.radiusSm
                                            color: Theme.text
                                            opacity: btn.off ? 0 : (btnTap.pressed ? Theme.statePressed + 0.04 : (btnHover.hovered ? Theme.stateHover + 0.02 : 0))

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: Theme.durQuick
                                                }

                                            }

                                            Behavior on radius {
                                                NumberAnimation {
                                                    duration: Theme.durShort
                                                }

                                            }

                                        }

                                        Icon {
                                            anchors.centerIn: parent
                                            size: Theme.dp(20)
                                            name: btn.modelData.glyph
                                            color: btn.modelData.danger ? Theme.error : Theme.text
                                            opacity: btn.off ? 0.38 : 1
                                        }

                                        HoverHandler {
                                            id: btnHover

                                            onHoveredChanged: {
                                                if (hovered) {
                                                    tipText.text = btn.modelData.label;
                                                    var p = btn.mapToItem(menu, btn.width / 2, 0);
                                                    tip.cx = p.x;
                                                    tip.cy = p.y;
                                                    tip.on = true;
                                                    menu.setLit(card.index, -1);
                                                    closeTimer.level = card.index;
                                                    if (menu.levels.length > card.index + 1)
                                                        closeTimer.restart();

                                                } else if (tipText.text === btn.modelData.label) {
                                                    tip.on = false;
                                                }
                                            }
                                        }

                                        TapHandler {
                                            id: btnTap

                                            onTapped: {
                                                if (!btn.off)
                                                    menu.choose(btn.modelData.id);

                                            }
                                        }

                                    }

                                }

                            }

                            Item {
                                visible: !row.isStrip
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: menu.rowH

                                // m3 expressive: a checked row sits on the secondary container, and a
                                // lit row's shape rounds out under the pointer
                                // inset, so two checked rows in a row stay two shapes
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: Theme.dp(2)
                                    anchors.bottomMargin: Theme.dp(2)
                                    radius: row.lit || row.opened || row.checked ? Theme.radiusSm : Theme.radiusXs
                                    color: Theme.secondaryContainer
                                    visible: row.checked
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: Theme.dp(2)
                                    anchors.bottomMargin: Theme.dp(2)
                                    radius: row.lit || row.opened ? Theme.radiusSm : Theme.radiusXs
                                    color: row.checked ? Theme.fgSecondaryContainer : Theme.text
                                    opacity: row.disabled ? 0 : (rowTap.pressed ? Theme.statePressed : (row.lit || row.opened ? Theme.stateHover + 0.02 : 0))

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

                                // what the row leads with: a colour, an app's icon, a symbol, or the check of a chosen option
                                Item {
                                    id: lead

                                    x: Theme.dp(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.dp(20)
                                    height: Theme.dp(20)
                                    opacity: row.disabled ? 0.38 : 1

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Theme.dp(12)
                                        height: width
                                        radius: width / 2
                                        visible: row.modelData.swatch !== undefined
                                        color: row.modelData.swatch || "transparent"
                                    }

                                    Image {
                                        anchors.fill: parent
                                        visible: !!row.modelData.image
                                        source: row.modelData.image || ""
                                        sourceSize.width: Math.round(width * DesktopIcons.dpr)
                                        sourceSize.height: Math.round(height * DesktopIcons.dpr)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }

                                    DockGlyph {
                                        anchors.centerIn: parent
                                        width: Theme.dp(18)
                                        height: Theme.dp(18)
                                        visible: !row.modelData.image && row.modelData.swatch === undefined && (row.checked || !!row.modelData.glyph)
                                        pathData: row.checked && !row.modelData.glyph ? "check" : (row.modelData.glyph || "")
                                        glyphColor: row.modelData.danger ? Theme.error : (row.checked ? Theme.fgSecondaryContainer : Theme.subtext)
                                    }

                                }

                                Text {
                                    id: label

                                    anchors.left: lead.right
                                    anchors.right: trail.visible ? trail.left : (chev.visible ? chev.left : parent.right)
                                    anchors.leftMargin: Theme.dp(12)
                                    anchors.rightMargin: Theme.dp(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.modelData.label || ""
                                    color: row.ink
                                    opacity: row.disabled ? 0.38 : 1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
                                    font.variableAxes: Theme.axes(Theme.fontBody, row.checked ? 600 : 520, 0)
                                    font.weight: row.checked ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                }

                                // a shortcut, or "default" against an app
                                Text {
                                    id: trail

                                    anchors.right: chev.visible ? chev.left : parent.right
                                    anchors.rightMargin: chev.visible ? Theme.dp(4) : Theme.dp(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !!row.modelData.shortcut
                                    text: row.modelData.shortcut || ""
                                    color: row.checked ? Theme.fgSecondaryContainer : Theme.subtext
                                    opacity: row.disabled ? 0.38 : 0.8
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabelMd
                                }

                                DockGlyph {
                                    id: chev

                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.dp(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.dp(18)
                                    height: Theme.dp(18)
                                    visible: !!row.modelData.submenu
                                    pathData: "chevron_right"
                                    glyphColor: Theme.subtext
                                    opacity: row.disabled ? 0.38 : 1
                                }

                                HoverHandler {
                                    onHoveredChanged: {
                                        if (!hovered)
                                            return ;

                                        menu.focusLevel = card.index;
                                        menu.setLit(card.index, row.disabled ? -1 : row.index);
                                        if (row.modelData.submenu && !row.disabled) {
                                            closeTimer.stop();
                                            if (!row.opened) {
                                                openTimer.level = card.index;
                                                openTimer.row = row.index;
                                                openTimer.restart();
                                            }
                                        } else {
                                            openTimer.stop();
                                            if (menu.levels.length > card.index + 1) {
                                                closeTimer.level = card.index;
                                                closeTimer.restart();
                                            }
                                        }
                                    }
                                }

                                TapHandler {
                                    id: rowTap

                                    onTapped: {
                                        openTimer.stop();
                                        closeTimer.stop();
                                        menu.activate(card.index, row.index);
                                    }
                                }

                            }

                        }

                    }

                }

            }

            ParallelAnimation {
                id: appear

                NumberAnimation {
                    target: card
                    property: "opacity"
                    to: 1
                    duration: Theme.durEnter
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

                NumberAnimation {
                    target: card
                    property: "scale"
                    to: 1
                    duration: Theme.durEnter
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

            NumberAnimation {
                id: vanish

                target: card
                property: "opacity"
                to: 0
                duration: Theme.durQuick
            }

            Behavior on radius {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

            Behavior on height {
                enabled: menu.open

                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    // a strip button's name, above it
    Rectangle {
        id: tip

        property bool on: false
        property real cx: 0
        property real cy: 0

        x: Math.round(tip.cx - width / 2)
        y: Math.round(tip.cy - height - Theme.dp(6))
        width: tipText.implicitWidth + Theme.dp(16)
        height: tipText.implicitHeight + Theme.dp(8)
        radius: Theme.radiusXs
        color: Theme.surfaceHighest
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.08)
        opacity: tip.on && menu.open ? 1 : 0
        visible: opacity > 0.01

        Text {
            id: tipText

            anchors.centerIn: parent
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelMd
            font.weight: Font.Medium
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

    function heightOf(r) {
        return (r.strip !== undefined ? menu.stripH : menu.rowH) + (r.divider ? menu.dividerH : 0);
    }

}
