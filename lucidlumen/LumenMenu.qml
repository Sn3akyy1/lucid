import QtQuick
import qs
import qs.lucidui

// a context menu inside the window, on lucid's own menu card. an item is
// {id, label, icon, hint, danger, disabled, checked, radio, sub: [...]},
// {sep: true}, {heading: "…"}, a row of buttons that leave the menu open:
// {label, buttons: [{id, icon, tip, off: function}]}, or a row of colours to
// pick from: {swatches: [{id, color, tip, checked}]}, no color being none. a submenu opens to the
// side on hover. each card is made once and stays while others come and go
Item {
    id: menu

    property var handler: null
    property int hot: -1
    property int depth: 0
    // what the open cards hold, by depth; a card reads its own when it is made
    property var store: []
    readonly property bool shown: menu.depth > 0
    readonly property real rowH: Theme.dp(38)
    readonly property real sepH: Theme.dp(9)
    readonly property real headH: Theme.dp(30)
    readonly property real pad: Theme.dp(6)
    readonly property real edge: Theme.dp(8)
    readonly property real btnW: Theme.dp(32)
    readonly property real swatchW: Theme.dp(32)

    function open(items, x, y, cb) {
        menu.close();
        menu.handler = cb;
        menu.hot = -1;
        menu.push({
            "items": items,
            "x": x,
            "y": y,
            "w": menu.widthOf(items),
            "h": menu.heightOf(items)
        });
        keys.forceActiveFocus();
    }

    function push(level) {
        menu.store = menu.store.concat([level]);
        levels.append({
            "lvl": menu.store.length - 1
        });
        menu.depth = levels.count;
    }

    // keeps the first n cards
    function trim(n) {
        while (levels.count > n)levels.remove(levels.count - 1)
        menu.store = menu.store.slice(0, n);
        menu.depth = levels.count;
    }

    function close() {
        subLater.stop();
        menu.trim(0);
        menu.handler = null;
    }

    function selectable(it) {
        return !it.sep && it.heading === undefined && !it.buttons && !it.swatches && !it.disabled;
    }

    // a colour from a row of them: picked, and the menu goes
    function choose(sw) {
        var cb = menu.handler;
        menu.close();
        if (cb)
            cb(sw.id, sw);

    }

    function pick(it) {
        if (!menu.selectable(it) || it.sub)
            return ;

        var cb = menu.handler;
        menu.close();
        if (cb)
            cb(it.id, it);

    }

    // a button in a row: the menu stays open for the next press
    function press(b) {
        if (menu.handler)
            menu.handler(b.id, b);

    }

    function rowHeight(it) {
        return it.sep ? menu.sepH : it.heading !== undefined ? menu.headH : it.swatches ? Theme.dp(46) : menu.rowH;
    }

    function heightOf(items) {
        var h = 2 * menu.pad;
        for (var i = 0; i < items.length; i++) h += menu.rowHeight(items[i])
        return h;
    }

    function widthOf(items) {
        var w = Theme.dp(180);
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            if (it.sep)
                continue;

            metrics.text = it.heading !== undefined ? it.heading : (it.label || "");
            var row = (it.icon || it.radio ? Theme.dp(42) : Theme.dp(12)) + metrics.advanceWidth + Theme.dp(16);
            if (it.hint) {
                hintMetrics.text = it.hint;
                row += hintMetrics.advanceWidth + Theme.dp(14);
            }
            if (it.sub || (it.checked !== undefined && !it.radio))
                row += Theme.dp(24);

            if (it.buttons)
                row += it.buttons.length * menu.btnW + Theme.dp(8);

            if (it.swatches)
                row = it.swatches.length * menu.swatchW + Theme.dp(12);

            w = Math.max(w, row + 2 * menu.pad);
        }
        return Math.min(Theme.dp(340), Math.ceil(w));
    }

    function openSub(level, it, rowY) {
        subLater.stop();
        if (menu.depth > level + 1 && menu.store[level + 1].from === it)
            return ;

        menu.trim(level + 1);
        var card = cards.itemAt(level);
        if (!card)
            return ;

        var w = menu.widthOf(it.sub);
        var x = card.x + card.width - menu.pad;
        if (x + w > menu.width - menu.edge)
            x = card.x - w + menu.pad;

        menu.push({
            "items": it.sub,
            "x": x,
            "y": card.y + rowY - menu.pad,
            "w": w,
            "h": menu.heightOf(it.sub),
            "fixed": true,
            "from": it
        });
    }

    // another row of a card with a submenu open closes it after a moment, so a
    // pointer cutting the corner on its way into the submenu does not lose it
    function leave(level) {
        if (menu.depth <= level + 1)
            return ;

        subLater.keep = level + 1;
        subLater.restart();
    }

    anchors.fill: parent
    visible: menu.shown

    // measured as LText draws a label: its weight, axes and spacing, or a long
    // label comes out wider than its row and is cut short
    TextMetrics {
        id: metrics

        readonly property real wght: Theme.typeWeight("labelLarge")

        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeSize("labelLarge")
        font.weight: metrics.wght >= 650 ? Font.Bold : metrics.wght >= 540 ? Font.DemiBold : metrics.wght >= 470 ? Font.Medium : Font.Normal
        font.variableAxes: Theme.axes(Theme.typeSize("labelLarge"), metrics.wght, Theme.typeRound("labelLarge"))
        font.letterSpacing: 0.2
    }

    TextMetrics {
        id: hintMetrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeSize("bodySmall")
    }

    Timer {
        id: subLater

        property int keep: 0

        interval: 260
        onTriggered: menu.trim(subLater.keep)
    }

    ListModel {
        id: levels
    }

    // takes the keys while it is open
    Item {
        id: keys

        focus: menu.shown
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (menu.depth > 1)
                    menu.trim(menu.depth - 1);
                else
                    menu.close();
                event.accepted = true;
            } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_Up) && menu.depth > 0) {
                var items = menu.store[0].items, n = items.length, i = menu.hot;
                for (var k = 0; k < n; k++) {
                    i = (i + (event.key === Qt.Key_Down ? 1 : -1) + n) % n;
                    if (menu.selectable(items[i]))
                        break;

                }
                menu.hot = i;
                event.accepted = true;
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && menu.hot >= 0 && menu.depth > 0) {
                menu.pick(menu.store[0].items[menu.hot]);
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menu.close()
        onWheel: (wheel) => {
            return menu.close();
        }
    }

    Repeater {
        id: cards

        model: levels

        delegate: Rectangle {
            id: card

            required property int lvl
            // read once: the store is rewritten as cards come and go, and the rows
            // under the pointer must never be made again
            property var level: null
            readonly property var items: card.level ? card.level.items : []
            readonly property real cw: card.level ? card.level.w : 0
            readonly property real ch: card.level ? card.level.h : 0
            readonly property real ax: card.level ? card.level.x : 0
            readonly property real ay: card.level ? card.level.y : 0
            readonly property bool fixedRow: card.level ? card.level.fixed === true : false

            x: Math.max(menu.edge, Math.min(card.ax, menu.width - card.cw - menu.edge))
            y: card.ay + card.ch > menu.height - menu.edge ? Math.max(menu.edge, (card.fixedRow ? card.ay + menu.rowH : card.ay) - card.ch) : card.ay
            width: card.cw
            height: card.ch
            radius: Theme.radiusMd
            color: Theme.bgOpaque
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.08)
            opacity: 0
            scale: 0.96
            transformOrigin: Item.TopLeft
            Component.onCompleted: {
                card.level = menu.store[card.lvl];
                card.opacity = 1;
                card.scale = 1;
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // reaching a submenu keeps it, whatever the pointer crossed on the way
            HoverHandler {
                onHoveredChanged: {
                    if (hovered && card.lvl >= subLater.keep)
                        subLater.stop();

                }
            }

            Column {
                x: menu.pad
                y: menu.pad
                width: card.width - 2 * menu.pad

                Repeater {
                    model: card.items

                    delegate: Item {
                        id: entry

                        required property var modelData
                        required property int index
                        readonly property bool isSep: entry.modelData.sep === true
                        readonly property bool isHead: entry.modelData.heading !== undefined
                        readonly property bool isButtons: entry.modelData.buttons !== undefined
                        readonly property bool isSwatches: entry.modelData.swatches !== undefined
                        readonly property bool plain: !entry.isSep && !entry.isHead && !entry.isButtons && !entry.isSwatches
                        // the row a submenu hangs off stays lit while it is open
                        readonly property bool parentOfOpen: entry.modelData.sub !== undefined && menu.depth > card.lvl + 1 && menu.store[card.lvl + 1] !== undefined && menu.store[card.lvl + 1].from === entry.modelData
                        readonly property bool hot: entry.plain && (hover.containsMouse || entry.parentOfOpen || (card.lvl === 0 && menu.hot === entry.index))
                        readonly property color ink: entry.modelData.danger ? Theme.error : Theme.text
                        readonly property bool lead: (entry.modelData.icon || "") !== "" || entry.modelData.radio === true

                        width: parent.width
                        height: menu.rowHeight(entry.modelData)
                        opacity: entry.modelData.disabled ? 0.38 : 1

                        Rectangle {
                            visible: entry.isSep
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.dp(6)
                            width: parent.width - Theme.dp(12)
                            height: 1
                            color: Theme.alpha(Theme.text, 0.1)
                        }

                        LText {
                            visible: entry.isHead
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.dp(5)
                            x: Theme.dp(12)
                            width: parent.width - Theme.dp(24)
                            role: "labelMedium"
                            text: entry.isHead ? entry.modelData.heading : ""
                            color: Theme.subtext
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: entry.plain
                            anchors.fill: parent
                            radius: Theme.radiusSm
                            color: entry.ink
                            opacity: entry.hot && !entry.modelData.disabled ? (hover.pressed ? Theme.statePressed : Theme.stateHover) : 0
                        }

                        Icon {
                            visible: !entry.isSep && !entry.isHead && (entry.modelData.icon || "") !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.dp(10)
                            name: entry.modelData.icon || ""
                            size: Theme.dp(20)
                            color: entry.modelData.danger ? Theme.error : Theme.subtext
                        }

                        // one of a set: a ring, with a dot in the one that is on
                        Rectangle {
                            visible: entry.modelData.radio === true
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.dp(11)
                            width: Theme.dp(18)
                            height: Theme.dp(18)
                            radius: width / 2
                            color: "transparent"
                            border.width: Theme.dp(2)
                            border.color: entry.modelData.checked ? Theme.accent : Theme.subtext

                            Rectangle {
                                anchors.centerIn: parent
                                width: Theme.dp(8)
                                height: Theme.dp(8)
                                radius: width / 2
                                color: Theme.accent
                                visible: entry.modelData.checked === true
                            }

                        }

                        // colours in a row: a ring and a tick on the one in use, a ring
                        // with a slash through it for none
                        Row {
                            visible: entry.isSwatches
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.dp(6)

                            Repeater {
                                model: entry.isSwatches ? entry.modelData.swatches : []

                                delegate: Item {
                                    id: sw

                                    required property var modelData
                                    readonly property bool none: sw.modelData.color === undefined
                                    readonly property bool checked: sw.modelData.checked === true

                                    width: menu.swatchW
                                    height: menu.swatchW

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Theme.dp(30)
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: Theme.dp(2)
                                        border.color: sw.none ? Theme.text : sw.modelData.color
                                        opacity: sw.checked ? 1 : 0
                                        scale: sw.checked ? 1 : 0.8

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: Theme.curveFastSpatial
                                            }

                                        }

                                    }

                                    Rectangle {
                                        id: dot

                                        anchors.centerIn: parent
                                        width: Theme.dp(22)
                                        height: width
                                        radius: width / 2
                                        color: sw.none ? "transparent" : sw.modelData.color
                                        border.width: sw.none ? Theme.dp(2) : 0
                                        border.color: Theme.subtext
                                        scale: swArea.pressed ? 0.88 : swArea.containsMouse ? 1.12 : 1

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: Theme.curveFastSpatial
                                            }

                                        }

                                        Rectangle {
                                            visible: sw.none
                                            anchors.centerIn: parent
                                            width: parent.width * 0.74
                                            height: Theme.dp(2)
                                            radius: height / 2
                                            rotation: -45
                                            color: Theme.subtext
                                        }

                                        Icon {
                                            visible: sw.checked && !sw.none
                                            anchors.centerIn: parent
                                            name: "check"
                                            size: Theme.dp(16)
                                            color: Theme.isLight ? "#ffffff" : Theme.bgOpaque
                                        }

                                    }

                                    MouseArea {
                                        id: swArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: menu.choose(sw.modelData)
                                    }

                                    Tip {
                                        text: sw.modelData.tip || ""
                                    }

                                }

                            }

                        }

                        LText {
                            visible: !entry.isSep && !entry.isHead && !entry.isSwatches
                            anchors.verticalCenter: parent.verticalCenter
                            x: entry.lead ? Theme.dp(42) : Theme.dp(12)
                            width: parent.width - x - Theme.dp(12) - (entry.isButtons ? buttons.width : trail.width)
                            role: "labelLarge"
                            text: entry.modelData.label || ""
                            color: entry.ink
                            elide: Text.ElideRight
                        }

                        Item {
                            id: trail

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            width: entry.modelData.sub || (entry.modelData.checked !== undefined && !entry.modelData.radio) ? Theme.dp(20) : hintText.implicitWidth
                            height: Theme.dp(20)
                            visible: entry.plain

                            LText {
                                id: hintText

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !entry.modelData.sub && (entry.modelData.checked === undefined || entry.modelData.radio === true)
                                role: "bodySmall"
                                text: entry.modelData.hint || ""
                                color: Theme.subtext
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: entry.modelData.sub !== undefined || (entry.modelData.checked === true && !entry.modelData.radio)
                                name: entry.modelData.sub ? "chevron_right" : "check"
                                size: Theme.dp(18)
                                color: entry.modelData.sub ? Theme.subtext : Theme.accent
                            }

                        }

                        // buttons that act in place: the menu stays for the next press
                        Row {
                            id: buttons

                            visible: entry.isButtons
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(2)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Repeater {
                                model: entry.isButtons ? entry.modelData.buttons : []

                                delegate: IconButton {
                                    required property var modelData

                                    size: "xs"
                                    icon: modelData.icon
                                    disabled: modelData.off ? modelData.off() : false
                                    onClicked: menu.press(modelData)

                                    Tip {
                                        text: modelData.tip || ""
                                    }

                                }

                            }

                        }

                        HoverHandler {
                            enabled: entry.isButtons || entry.isSwatches
                            onHoveredChanged: {
                                if (hovered)
                                    menu.leave(card.lvl);

                            }
                        }

                        MouseArea {
                            id: hover

                            anchors.fill: parent
                            enabled: entry.plain
                            hoverEnabled: true
                            onContainsMouseChanged: {
                                if (!containsMouse)
                                    return ;

                                if (entry.modelData.sub && !entry.modelData.disabled)
                                    menu.openSub(card.lvl, entry.modelData, entry.y + menu.pad);
                                else
                                    menu.leave(card.lvl);
                            }
                            onClicked: menu.pick(entry.modelData)
                        }

                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

        }

    }

}
