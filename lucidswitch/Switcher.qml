import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.lucidui

// every open window on every workspace, most recent first. like windows'
// ctrl+alt+tab it stays up once the keys are let go
PanelWindow {
    id: sw

    property var dockMod: null
    property bool open: false
    property var onScreen: null
    property int index: 0
    property bool openedBack: false
    // set once the selection is moved by hand, so a late reorder keeps it
    property bool moved: false
    // hover only picks once the pointer has travelled, not where it rested at open
    property point pointerAt: Qt.point(-1, -1)
    property bool pointerLive: false
    property bool glide: false
    property real reveal: sw.open ? 1 : 0
    // address -> the tick it last had the focus at
    property var stamps: ({})
    property int tick: 0
    readonly property int count: rows.count
    readonly property int pad: Theme.dp(16)
    readonly property int gap: Theme.dp(18)
    readonly property int footH: Theme.dp(40)
    readonly property var fit: {
        const n = Math.max(1, sw.count);
        const availW = Math.max(Theme.dp(360), sw.width - Theme.dp(160)) - sw.pad * 2 - Theme.dp(12);
        const availH = Math.max(Theme.dp(260), sw.height * 0.8) - sw.pad * 2 - sw.footH - Theme.dp(12);
        let out = null;
        for (let w = Theme.dp(264); w >= Theme.dp(168); w -= Theme.dp(8)) {
            const h = sw.tileHeight(w);
            const cols = Math.max(1, Math.min(n, Math.floor((availW + sw.gap) / (w + sw.gap))));
            const lines = Math.ceil(n / cols);
            out = {
                "w": w,
                "h": h,
                "cols": cols,
                "lines": lines,
                "availH": availH
            };
            if (lines * h + (lines - 1) * sw.gap <= availH)
                break;

        }
        out.fullW = out.cols * out.w + (out.cols - 1) * sw.gap;
        out.fullH = out.lines * out.h + (out.lines - 1) * sw.gap;
        out.viewH = Math.min(out.fullH, out.availH);
        return out;
    }

    // thumbnails take the screen's shape, which most windows are close to
    function thumbHeight(w) {
        const aspect = sw.width > 0 && sw.height > 0 ? Math.max(1.3, Math.min(2.4, sw.width / sw.height)) : 1.78;
        return Math.round(w / aspect);
    }

    function tileHeight(w) {
        return sw.thumbHeight(w) + Theme.dp(8) + Theme.dp(20);
    }

    // the last line sits centred under the full ones
    function cellX(i) {
        const f = sw.fit;
        const line = Math.floor(i / f.cols);
        const inLine = Math.min(f.cols, sw.count - line * f.cols);
        return (f.cols - inLine) * (f.w + sw.gap) / 2 + (i % f.cols) * (f.w + sw.gap);
    }

    function cellY(i) {
        return Math.floor(i / sw.fit.cols) * (sw.fit.h + sw.gap);
    }

    function norm(a) {
        const s = String(a || "").trim().toLowerCase();
        if (s === "")
            return "";

        return s.indexOf("0x") === 0 ? s : "0x" + s;
    }

    function addr(t) {
        return t ? sw.norm(t.address) : "";
    }

    function toplevelOf(a) {
        return Hyprland.toplevels.values.find((t) => {
            return sw.addr(t) === a;
        }) || null;
    }

    function history(t) {
        const o = t.lastIpcObject;
        return o && typeof o.focusHistoryID === "number" && o.focusHistoryID >= 0 ? o.focusHistoryID : 1e+06;
    }

    // focus seen since the shell started goes first, hyprland's own history after.
    // quickshell can keep a toplevel hyprland has forgotten; it has no workspace
    function ranked() {
        const list = Hyprland.toplevels.values.filter((t) => {
            return t && t.workspace && sw.addr(t) !== "" && !(t.lastIpcObject && t.lastIpcObject.mapped === false);
        });
        list.sort((x, y) => {
            const sx = sw.stamps[sw.addr(x)] || 0;
            const sy = sw.stamps[sw.addr(y)] || 0;
            if (sx !== sy)
                return sy - sx;

            return sw.history(x) - sw.history(y);
        });
        return list.map(sw.addr);
    }

    function rowOf(a) {
        for (let i = 0; i < rows.count; i++) {
            if (rows.get(i).address === a)
                return i;

        }
        return -1;
    }

    function selected() {
        return sw.index >= 0 && sw.index < rows.count ? rows.get(sw.index).address : "";
    }

    // the window in front comes first, so the switch lands on the one before it
    function startIndex() {
        if (sw.openedBack)
            return Math.max(0, sw.count - 1);

        if (sw.count < 2)
            return 0;

        const t = Hyprland.activeToplevel;
        if (!t || sw.addr(t) !== rows.get(0).address || !t.workspace)
            return 0;

        return t.workspace === Hyprland.focusedWorkspace || String(t.workspace.name || "").indexOf("special:") === 0 ? 1 : 0;
    }

    function show(back) {
        sw.onScreen = Monitors.focusedScreen || Monitors.mainScreen;
        Hyprland.refreshToplevels();
        rows.clear();
        const list = sw.ranked();
        for (let i = 0; i < list.length; i++) rows.append({
            "address": list[i]
        });
        sw.openedBack = back === true;
        sw.moved = false;
        sw.pointerAt = Qt.point(-1, -1);
        sw.pointerLive = false;
        sw.glide = false;
        sw.index = sw.startIndex();
        view.contentY = 0;
        sw.open = true;
        settle.restart();
    }

    function hide() {
        sw.open = false;
        sw.glide = false;
    }

    function step(d) {
        if (!sw.open)
            sw.show(d < 0);
        else
            sw.move(d);
    }

    function move(d) {
        if (sw.count === 0)
            return ;

        sw.moved = true;
        sw.index = (sw.index + d + sw.count) % sw.count;
    }

    function moveLine(d) {
        const c = sw.fit.cols;
        const to = sw.index + d * c;
        sw.moved = true;
        if (to >= 0 && to < sw.count)
            sw.index = to;
        else if (d > 0 && Math.floor(sw.index / c) < sw.fit.lines - 1)
            sw.index = sw.count - 1;
    }

    function jump(i) {
        if (sw.count === 0)
            return ;

        sw.moved = true;
        sw.index = Math.max(0, Math.min(sw.count - 1, i));
    }

    function commit(i) {
        if (i < 0 || i >= sw.count) {
            sw.hide();
            return ;
        }
        focusLater.address = rows.get(i).address;
        sw.hide();
        focusLater.restart();
    }

    function closeAt(i) {
        if (i < 0 || i >= sw.count)
            return ;

        Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + rows.get(i).address + "\" })");
    }

    // the order the refresh brings back, moved into place without rebuilding
    function reorder() {
        const have = [];
        for (let i = 0; i < rows.count; i++) have.push(rows.get(i).address)
        const order = sw.ranked().filter((a) => {
            return have.indexOf(a) !== -1;
        });
        if (order.join() === have.join())
            return ;

        const keep = sw.selected();
        for (let i = 0; i < order.length; i++) {
            const j = sw.rowOf(order[i]);
            if (j > i)
                rows.move(j, i, 1);

        }
        sw.index = sw.moved ? Math.max(0, sw.rowOf(keep)) : sw.startIndex();
    }

    // a window closed while the switcher is up leaves it; new ones wait for next time
    function prune() {
        const live = {};
        const all = Hyprland.toplevels.values;
        for (let i = 0; i < all.length; i++) live[sw.addr(all[i])] = true
        const keep = sw.selected();
        let gone = false;
        for (let i = rows.count - 1; i >= 0; i--) {
            if (!live[rows.get(i).address]) {
                rows.remove(i, 1);
                gone = true;
            }
        }
        if (!gone)
            return ;

        const at = sw.rowOf(keep);
        sw.index = at >= 0 ? at : Math.min(sw.index, Math.max(0, rows.count - 1));
    }

    function pointerMoved(item, mx, my) {
        if (sw.pointerLive)
            return true;

        const p = item.mapToItem(null, mx, my);
        if (sw.pointerAt.x < 0) {
            sw.pointerAt = Qt.point(p.x, p.y);
            return false;
        }
        if (Math.abs(p.x - sw.pointerAt.x) + Math.abs(p.y - sw.pointerAt.y) > 6)
            sw.pointerLive = true;

        return sw.pointerLive;
    }

    function appClass(t) {
        if (!t)
            return "";

        const o = t.lastIpcObject || {};
        return String((t.wayland && t.wayland.appId) || o.class || "");
    }

    function appName(cls) {
        const e = cls !== "" ? DesktopEntries.heuristicLookup(cls) : null;
        return e && e.name ? e.name : cls;
    }

    function iconFor(cls) {
        if (cls === "")
            return "";

        return sw.dockMod ? sw.dockMod.iconForClass(cls) : Quickshell.iconPath(cls, true);
    }

    function ensureVisible() {
        if (!view.interactive)
            return ;

        const top = sw.cellY(sw.index);
        if (top < view.contentY)
            view.contentY = top;
        else if (top + sw.fit.h + Theme.dp(12) > view.contentY + view.height)
            view.contentY = top + sw.fit.h + Theme.dp(12) - view.height;
    }

    onIndexChanged: sw.ensureVisible()
    screen: sw.onScreen
    visible: (sw.open || sw.reveal > 0.01) && Monitors.surfacesUp
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: sw.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucid-switcher"
    BackgroundEffect.blurRegion: Theme.blurAmount > 0 && sw.open ? cardRegion : null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    ListModel {
        id: rows
    }

    Region {
        id: cardRegion

        x: Math.ceil(card.x - 0.002)
        y: Math.ceil(card.y - 0.002)
        width: Math.max(0, Math.floor(card.x + card.width + 0.002) - Math.ceil(card.x - 0.002))
        height: Math.max(0, Math.floor(card.y + card.height + 0.002) - Math.ceil(card.y - 0.002))
        radius: Theme.shapeXl
    }

    Behavior on reveal {
        NumberAnimation {
            duration: sw.open ? Theme.durFastEffects : Theme.ms(90)
            easing.type: sw.open ? Easing.OutCubic : Easing.InCubic
        }

    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "activewindowv2") {
                const a = sw.norm(event.data);
                if (a !== "" && a !== "0x,") {
                    sw.tick += 1;
                    sw.stamps[a] = sw.tick;
                }
            } else if (event.name === "closewindow") {
                delete sw.stamps[sw.norm(event.data)];
            }
        }

        target: Hyprland
    }

    Connections {
        function onValuesChanged() {
            if (sw.visible)
                sw.prune();

        }

        target: Hyprland.toplevels
    }

    // the refresh asked for on open has landed by now
    Timer {
        id: settle

        interval: 60
        onTriggered: {
            if (!sw.open)
                return ;

            sw.reorder();
            sw.glide = true;
        }
    }

    // the switcher lets go of the keyboard first, or the focus comes back to it
    Timer {
        id: focusLater

        property string address: ""

        interval: 80
        onTriggered: Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + focusLater.address + "\" })")
    }

    IpcHandler {
        // qs ipc call switcher next
        function next(): void {
            sw.step(1);
        }

        function prev(): void {
            sw.step(-1);
        }

        function toggle(): void {
            if (sw.open)
                sw.hide();
            else
                sw.show(false);
        }

        function open(): void {
            if (!sw.open)
                sw.show(false);

        }

        function close(): void {
            sw.hide();
        }

        function status(): string {
            const out = [];
            for (let i = 0; i < rows.count; i++) {
                const a = rows.get(i).address;
                const t = sw.toplevelOf(a);
                out.push({
                    "address": a,
                    "class": sw.appClass(t),
                    "title": t ? String(t.title || "") : "",
                    "workspace": t && t.workspace ? String(t.workspace.name) : ""
                });
            }
            return JSON.stringify({
                "open": sw.open,
                "index": sw.index,
                "windows": out
            });
        }

        target: "switcher"
    }

    Item {
        id: stage

        anchors.fill: parent
        focus: sw.open
        Keys.onPressed: (e) => {
            const shift = (e.modifiers & Qt.ShiftModifier) !== 0;
            switch (e.key) {
            case Qt.Key_Escape:
                sw.hide();
                break;
            case Qt.Key_Backtab:
                sw.move(-1);
                break;
            case Qt.Key_Tab:
                sw.move(shift ? -1 : 1);
                break;
            case Qt.Key_Right:
                sw.move(1);
                break;
            case Qt.Key_Left:
                sw.move(-1);
                break;
            case Qt.Key_Down:
                sw.moveLine(1);
                break;
            case Qt.Key_Up:
                sw.moveLine(-1);
                break;
            case Qt.Key_Home:
                sw.jump(0);
                break;
            case Qt.Key_End:
                sw.jump(sw.count - 1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                sw.commit(sw.index);
                break;
            case Qt.Key_Delete:
                sw.closeAt(sw.index);
                break;
            default:
                return ;
            }
            e.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.cShadow, Theme.blurAmount > 0 ? 0.28 : 0.45)
            opacity: sw.reveal

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: sw.hide()
            }

        }

        Rectangle {
            id: card

            readonly property real innerW: Math.max(sw.fit.fullW + Theme.dp(12), Theme.dp(520))

            anchors.centerIn: parent
            width: Math.round(card.innerW + sw.pad * 2)
            height: Math.round((sw.count > 0 ? sw.fit.viewH + Theme.dp(12) : Theme.dp(132)) + sw.pad * 2 + sw.footH)
            radius: Theme.shapeXl
            color: Theme.bg
            opacity: sw.reveal

            // clicks between the tiles must not reach the dimmer
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Flickable {
                id: view

                visible: sw.count > 0
                x: sw.pad + Math.round((card.innerW - sw.fit.fullW - Theme.dp(12)) / 2)
                y: sw.pad
                width: sw.fit.fullW + Theme.dp(12)
                height: sw.fit.viewH + Theme.dp(12)
                contentWidth: view.width
                contentHeight: sw.fit.fullH + Theme.dp(12)
                interactive: view.contentHeight > view.height + 1
                clip: view.interactive
                boundsBehavior: Flickable.StopAtBounds

                Item {
                    id: grid

                    x: Theme.dp(6)
                    y: Theme.dp(6)
                    width: sw.fit.fullW
                    height: sw.fit.fullH
                    transform: Translate {
                        y: (1 - sw.reveal) * 10
                    }

                    Repeater {
                        model: rows

                        delegate: Item {
                            id: tile

                            required property string address
                            required property int index
                            readonly property var toplevel: sw.toplevelOf(tile.address)
                            readonly property var info: tile.toplevel && tile.toplevel.lastIpcObject ? tile.toplevel.lastIpcObject : ({})
                            readonly property string cls: sw.appClass(tile.toplevel)
                            readonly property string label: {
                                const s = tile.toplevel ? String(tile.toplevel.title || tile.info.title || "") : "";
                                return s !== "" ? s : sw.appName(tile.cls);
                            }
                            readonly property string iconSource: sw.iconFor(tile.cls)
                            readonly property var ws: tile.toplevel ? tile.toplevel.workspace : null
                            readonly property string wsName: tile.ws ? String(tile.ws.name || "") : ""
                            readonly property bool special: tile.wsName.indexOf("special:") === 0
                            readonly property bool here: tile.ws !== null && tile.ws === Hyprland.focusedWorkspace
                            readonly property bool isSelected: sw.index === tile.index
                            readonly property real aspect: {
                                const s = tile.info.size;
                                return s && s.length === 2 && s[0] > 0 && s[1] > 0 ? s[0] / s[1] : 1.6;
                            }

                            x: sw.cellX(tile.index)
                            y: sw.cellY(tile.index)
                            width: sw.fit.w
                            height: sw.fit.h

                            MouseArea {
                                id: tap

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: (mouse) => {
                                    if (sw.pointerMoved(tap, mouse.x, mouse.y) && sw.index !== tile.index) {
                                        sw.moved = true;
                                        sw.index = tile.index;
                                    }
                                }
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.MiddleButton)
                                        sw.closeAt(tile.index);
                                    else
                                        sw.commit(tile.index);
                                }
                            }

                            // the workspace overview's card: the window sits inset, bordered
                            Rectangle {
                                id: card

                                width: tile.width
                                height: sw.thumbHeight(tile.width)
                                radius: tile.isSelected ? Theme.rad(18) : Theme.rad(12)
                                color: Theme.withBlur(tile.isSelected ? Theme.surfaceHighest : Theme.surfaceHigh)
                                border.color: tile.isSelected ? Theme.primary : "transparent"
                                border.width: tile.isSelected ? 3 : 0
                                scale: tap.pressed ? 0.985 : (tile.isSelected ? 1.03 : 1)

                                // the window fills it, cropped at the sides or the bottom
                                ClippingRectangle {
                                    id: shot

                                    readonly property bool wide: tile.aspect >= shot.width / shot.height

                                    anchors.fill: parent
                                    anchors.margins: Theme.dp(5)
                                    radius: Theme.dp(6)
                                    color: Theme.withBlur(Theme.bgSunken)
                                    border.width: tile.isSelected ? 2 : 1
                                    border.color: tile.isSelected ? Theme.accent : Theme.alpha(Theme.text, 0.25)

                                    ScreencopyView {
                                        id: preview

                                        property bool seen: false

                                        x: Math.round((shot.width - preview.width) / 2)
                                        width: Math.ceil(shot.wide ? shot.height * tile.aspect : shot.width)
                                        height: Math.ceil(shot.wide ? shot.height : shot.width / tile.aspect)
                                        captureSource: sw.visible && tile.toplevel ? tile.toplevel.wayland : null
                                        live: sw.open
                                        visible: preview.seen || preview.hasContent
                                        onHasContentChanged: {
                                            if (preview.hasContent)
                                                preview.seen = true;

                                        }
                                    }

                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: Math.round(Math.min(Theme.dp(56), shot.height * 0.42))
                                        source: tile.iconSource
                                        visible: !preview.visible && tile.iconSource !== ""
                                    }

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: Theme.barMs(150)
                                        }

                                    }

                                }

                                Rectangle {
                                    id: chip

                                    x: shot.width >= chip.width + Theme.dp(12) ? shot.x + Theme.dp(6) : Math.round(shot.x + (shot.width - chip.width) / 2)
                                    y: shot.y + shot.height - chip.height - Theme.dp(6)
                                    visible: tile.ws !== null
                                    height: Theme.dp(22)
                                    radius: Theme.dp(11)
                                    width: chipRow.implicitWidth + Theme.dp(14)
                                    color: tile.here ? Theme.primary : Theme.alpha(Theme.surfaceHighest, 0.92)

                                    Row {
                                        id: chipRow

                                        anchors.centerIn: parent
                                        spacing: Theme.dp(4)

                                        Icon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: tile.special
                                            name: tile.special ? Specials.glyph(tile.wsName) : ""
                                            size: Theme.dp(14)
                                            fill: 1
                                            color: tile.here ? Theme.fgPrimary : Theme.subtext
                                        }

                                        LText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            role: "labelSmall"
                                            tabular: true
                                            color: tile.here ? Theme.fgPrimary : Theme.text
                                            text: tile.special ? Specials.label(tile.wsName) : (tile.ws ? "Workspace " + tile.ws.id : "")
                                        }

                                    }

                                }

                                IconButton {
                                    anchors.top: shot.top
                                    anchors.right: shot.right
                                    anchors.margins: Theme.dp(6)
                                    visible: tile.isSelected
                                    variant: "tonal"
                                    size: "xs"
                                    icon: "close"
                                    onClicked: sw.closeAt(tile.index)
                                }

                                Behavior on radius {
                                    NumberAnimation {
                                        duration: Theme.durDefaultSpatial
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.curveDefaultSpatial
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.barMs(150)
                                    }

                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Theme.barMs(150)
                                    }

                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.barMs(150)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            TextMetrics {
                                id: captionMetrics

                                font: captionText.font
                                text: tile.label
                            }

                            Row {
                                anchors.top: card.bottom
                                anchors.topMargin: Theme.dp(8)
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Theme.dp(6)

                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.dp(16)
                                    height: Theme.dp(16)

                                    IconImage {
                                        anchors.fill: parent
                                        source: tile.iconSource
                                        visible: tile.iconSource !== ""
                                    }

                                    Icon {
                                        anchors.centerIn: parent
                                        visible: tile.iconSource === ""
                                        name: "select_window"
                                        size: Theme.dp(16)
                                        color: tile.isSelected ? Theme.primary : Theme.subtext
                                    }

                                }

                                LText {
                                    id: captionText

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(Math.ceil(captionMetrics.advanceWidth) + 1, tile.width - Theme.dp(22))
                                    size: Theme.dp(13)
                                    weight: tile.isSelected ? 620 : 480
                                    color: tile.isSelected ? Theme.primary : Theme.subtext
                                    elide: Text.ElideRight
                                    text: tile.label

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.barMs(150)
                                        }

                                    }

                                }

                            }

                            Behavior on x {
                                enabled: sw.glide

                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveDefaultSpatial
                                }

                            }

                            Behavior on y {
                                enabled: sw.glide

                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveDefaultSpatial
                                }

                            }

                        }

                    }

                }

            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -sw.footH / 2
                visible: sw.count === 0
                spacing: Theme.dp(8)

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "select_window"
                    size: Theme.dp(36)
                    color: Theme.subtext
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "titleMedium"
                    color: Theme.subtext
                    text: "No windows open"
                }

            }

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: sw.pad + Theme.dp(8)
                anchors.rightMargin: sw.pad + Theme.dp(8)
                height: sw.footH + sw.pad / 2

                Row {
                    id: countRow

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -sw.pad / 4
                    spacing: Theme.dp(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "select_window"
                        size: Theme.dp(16)
                        color: Theme.subtext
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelMedium"
                        color: Theme.subtext
                        text: sw.count === 1 ? "1 window" : sw.count + " windows"
                    }

                }

                LText {
                    anchors.right: parent.right
                    anchors.left: countRow.right
                    anchors.leftMargin: Theme.dp(16)
                    anchors.verticalCenter: countRow.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    role: "labelMedium"
                    color: Theme.subtextDim
                    text: sw.count > 0 ? "Tab to move  ·  Enter to switch  ·  Del to close  ·  Esc to cancel" : "Esc to close"
                }

            }

        }

    }

}
