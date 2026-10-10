import QtQuick
import qs
import qs.lucidui

Item {
    id: frame

    required property string uid
    required property string wtype
    required property string wvariant
    required property real wx
    required property real wy
    required property real bw
    required property real bh
    required property bool pinned
    required property real zoom
    required property int zOrder
    required property string screenName
    required property string optsJson
    required property bool closing
    required property bool born

    property Item board: null

    readonly property var opts: {
        try {
            return JSON.parse(frame.optsJson);
        } catch (e) {
            return ({});
        }
    }
    readonly property bool locked: frame.pinned || Prefs.widgetLockAll
    readonly property bool onThisScreen: frame.board !== null && (frame.screenName === "" ? frame.board.isPrimary : frame.screenName === frame.board.screenName)
    readonly property var variantInfo: Widgets.variantAt(frame.wtype, frame.wvariant)
    // a variant that carries its own size: drag any edge instead of picking S/M/L/XL
    readonly property bool resizable: frame.variantInfo !== null && frame.variantInfo.resizable === true
    readonly property real safeZoom: frame.zoom > 0 ? frame.zoom : 1
    // a catalogue size is drawn at the interface size; a hand-sized card keeps its own
    readonly property real sizeScale: frame.resizable ? 1 : Theme.uiScale
    // while a grip is held the card runs off the live drag, not off the store
    readonly property real bodyW: frame.resizing ? frame.resW / frame.safeZoom : Math.round(frame.bw * frame.sizeScale)
    readonly property real bodyH: frame.resizing ? frame.resH / frame.safeZoom : Math.round(frame.bh * frame.sizeScale)
    readonly property real cardW: Math.round(frame.bodyW * frame.zoom)
    readonly property real cardH: Math.round(frame.bodyH * frame.zoom)
    readonly property int radius: Math.round(Math.min(Theme.radiusXl * frame.zoom, frame.cardH / 2, frame.cardW / 2))
    // the same corner expressed in the body's own unscaled coordinates
    readonly property real bodyRadius: frame.zoom > 0 ? frame.radius / frame.zoom : frame.radius
    readonly property bool active: frame.hovered || frame.dragging || frame.menuOpen
    // a variant can ask for no container at all and draw straight onto the wallpaper
    readonly property bool bare: body.item !== null && body.item.bare === true
    // ... or for nothing at all. never while you are working on the card, and the
    // fade to zero takes it out of the mask on its own, since visible follows opacity
    readonly property bool blanked: body.item !== null && body.item.hidden === true && !frame.dragging && !frame.resizing && !frame.menuOpen && !frame.selected
    // the desktop's box is over this card right now; a pinned or unseen card never counts
    readonly property bool marked: {
        var m = Widgets.marquee;
        if (!m || frame.locked || frame.closing || !frame.visible || !frame.board || m.screen !== frame.board.screenName)
            return false;

        return m.x < frame.x + frame.width && m.x + m.w > frame.x && m.y < frame.y + frame.height && m.y + m.h > frame.y;
    }
    readonly property bool selected: !frame.locked && Widgets.selection[frame.uid] === true
    // the widget panel is pointing at this card from its list
    readonly property bool spotted: Widgets.spotUid !== "" && Widgets.spotUid === frame.uid
    // dropped here from the panel: it settles where the ghost was rather than popping in
    readonly property bool landed: Widgets.landingUid !== "" && Widgets.landingUid === frame.uid
    readonly property bool editMode: frame.board !== null && frame.board.panelUp === true
    // held over the open widget panel, where letting go takes it off the desktop
    readonly property bool overBin: frame.dragging && frame.editMode && frame.board.binHit(frame.pointerX, frame.pointerY)

    property bool dragging: false
    property bool resizing: false
    property bool hovered: false
    property bool menuOpen: false
    // where the right-click landed, in the frame's own coordinates
    property real menuAtX: 0
    property real menuAtY: 0
    property real dragX: 0
    property real dragY: 0
    property real grabX: 0
    property real grabY: 0
    property real guideX: -1
    property real guideY: -1
    // the pointer during a drag, in board coordinates
    property real pointerX: -1
    property real pointerY: -1
    // the other selected cards riding along with this one's drag
    property var crew: []
    // where the card sat when the drag began
    property real homeX: 0
    property real homeY: 0
    // -1 / 0 / 1 for the edge the held grip pulls on
    property int gripH: 0
    property int gripV: 0
    property real pressBX: 0
    property real pressBY: 0
    property real startX: 0
    property real startY: 0
    property real startW: 0
    property real startH: 0
    property real resX: 0
    property real resY: 0
    property real resW: 0
    property real resH: 0

    readonly property real gripSize: Theme.dp(12)
    // the eight handles, clockwise from the top left corner
    readonly property var gripSpecs: [{
        "h": -1,
        "v": -1
    }, {
        "h": 0,
        "v": -1
    }, {
        "h": 1,
        "v": -1
    }, {
        "h": 1,
        "v": 0
    }, {
        "h": 1,
        "v": 1
    }, {
        "h": 0,
        "v": 1
    }, {
        "h": -1,
        "v": 1
    }, {
        "h": -1,
        "v": 0
    }]

    function opt(key) {
        var v = frame.opts[key];
        return v !== undefined ? v : Widgets.defaultOptions(frame.wtype)[key];
    }

    function setOpt(key, value) {
        Widgets.setOption(frame.uid, key, value);
    }

    function setOpts(changes) {
        Widgets.setOptions(frame.uid, changes);
    }

    function clampX(v) {
        return frame.board ? Math.max(0, Math.min(frame.board.width - frame.cardW, v)) : v;
    }

    function clampY(v) {
        return frame.board ? Math.max(0, Math.min(frame.board.height - frame.cardH, v)) : v;
    }

    function siblings() {
        var out = [];
        if (!frame.board)
            return out;

        for (var i = 0; i < frame.board.frameCount; i++) {
            var f = frame.board.frameAt(i);
            // a card riding along in the same drag is no edge to snap to
            if (f && f !== frame && f.visible && !f.closing && !f.dragging)
                out.push(f);

        }
        return out;
    }

    function snapTo(nx, ny) {
        if (!Prefs.widgetSnap || !frame.board) {
            frame.guideX = -1;
            frame.guideY = -1;
            return ({
                "x": nx,
                "y": ny
            });
        }
        var s = Widgets.snapBox(frame.board.width, frame.board.height, frame.cardW, frame.cardH, nx, ny, frame.siblings());
        frame.guideX = s.gx;
        frame.guideY = s.gy;
        return ({
            "x": s.x,
            "y": s.y
        });
    }

    function beginDrag(mx, my) {
        // a card outside the selection moves on its own and lets the rest go
        if (!frame.selected)
            Widgets.clearSelection();

        if (frame.locked)
            return ;

        var crew = [];
        if (frame.selected) {
            for (var i = 0; frame.board && i < frame.board.frameCount; i++) {
                var f = frame.board.frameAt(i);
                if (f && f !== frame && f.selected && f.visible && !f.closing)
                    crew.push(f);

            }
            // lifted in their current stacking order, under the one in hand
            crew.sort((a, b) => {
                return a.zOrder - b.zOrder;
            });
        }
        for (var j = 0; j < crew.length; j++) {
            var c = crew[j];
            c.homeX = c.x;
            c.homeY = c.y;
            c.dragX = c.x;
            c.dragY = c.y;
            c.dragging = true;
            Widgets.raise(c.uid);
        }
        frame.crew = crew;
        frame.grabX = mx;
        frame.grabY = my;
        frame.homeX = frame.x;
        frame.homeY = frame.y;
        frame.dragX = frame.x;
        frame.dragY = frame.y;
        frame.dragging = true;
        if (frame.board)
            frame.board.dragFrame = frame;

        Widgets.dragUid = frame.uid;
        Widgets.raise(frame.uid);
    }

    function moveDrag(mx, my) {
        if (!frame.dragging)
            return ;

        if (frame.board) {
            var at = frame.mapToItem(frame.board, mx, my);
            frame.pointerX = at.x;
            frame.pointerY = at.y;
        }
        var snapped = frame.snapTo(frame.dragX + (mx - frame.grabX), frame.dragY + (my - frame.grabY));
        var dx = snapped.x - frame.homeX;
        var dy = snapped.y - frame.homeY;
        if (frame.board) {
            // the group stops at an edge as one, so its shape never changes
            var l = frame.homeX;
            var t = frame.homeY;
            var r = frame.homeX + frame.cardW;
            var b = frame.homeY + frame.cardH;
            for (var i = 0; i < frame.crew.length; i++) {
                var c = frame.crew[i];
                if (!c)
                    continue;

                l = Math.min(l, c.homeX);
                t = Math.min(t, c.homeY);
                r = Math.max(r, c.homeX + c.width);
                b = Math.max(b, c.homeY + c.height);
            }
            dx = Math.max(-l, Math.min(frame.board.width - r, dx));
            dy = Math.max(-t, Math.min(frame.board.height - b, dy));
        }
        frame.dragX = frame.homeX + dx;
        frame.dragY = frame.homeY + dy;
        for (var j = 0; j < frame.crew.length; j++) {
            var m = frame.crew[j];
            if (!m)
                continue;

            m.dragX = m.homeX + dx;
            m.dragY = m.homeY + dy;
        }
        Widgets.setLive(frame.uid, frame.dragX, frame.dragY, frame.width, frame.height);
    }

    function endDrag() {
        if (!frame.dragging)
            return ;

        var binned = frame.overBin;
        var crew = frame.crew;
        frame.crew = [];
        frame.dragging = false;
        frame.guideX = -1;
        frame.guideY = -1;
        if (frame.board && frame.board.dragFrame === frame)
            frame.board.dragFrame = null;

        if (Widgets.dragUid === frame.uid)
            Widgets.dragUid = "";

        frame.pointerX = -1;
        frame.pointerY = -1;
        // dropped on the panel: the card and whatever rode along with it go
        if (binned) {
            for (var b = 0; b < crew.length; b++) {
                if (crew[b]) {
                    crew[b].dragging = false;
                    Widgets.close(crew[b].uid);
                }
            }
            Widgets.clearSelection();
            Widgets.close(frame.uid);
            return ;
        }
        Widgets.setPos(frame.uid, frame.dragX, frame.dragY);
        for (var i = 0; i < crew.length; i++) {
            var c = crew[i];
            if (!c)
                continue;

            Widgets.setPos(c.uid, c.dragX, c.dragY);
            c.dragging = false;
        }
        // a click that went nowhere lets the selection go
        if (frame.dragX === frame.homeX && frame.dragY === frame.homeY)
            Widgets.clearSelection();

        Widgets.liveUid = "";
    }

    function beginResize(hx, vy, px, py) {
        if (frame.locked || !frame.resizable)
            return ;

        frame.gripH = hx;
        frame.gripV = vy;
        frame.pressBX = px;
        frame.pressBY = py;
        frame.startX = frame.x;
        frame.startY = frame.y;
        frame.startW = frame.width;
        frame.startH = frame.height;
        frame.resX = frame.x;
        frame.resY = frame.y;
        frame.resW = frame.width;
        frame.resH = frame.height;
        frame.resizing = true;
        Widgets.raise(frame.uid);
    }

    function moveResize(px, py) {
        if (!frame.resizing)
            return ;

        // the catalogue's limits are body pixels, the pointer moves in board ones
        var lim = Widgets.sizeLimits(frame.wtype, frame.wvariant);
        var z = frame.safeZoom;
        var boardW = frame.board ? frame.board.width : frame.startX + frame.startW;
        var boardH = frame.board ? frame.board.height : frame.startY + frame.startH;
        var dx = px - frame.pressBX;
        var dy = py - frame.pressBY;
        var nx = frame.startX;
        var ny = frame.startY;
        var nw = frame.startW;
        var nh = frame.startH;
        if (frame.gripH > 0) {
            nw = Math.min(lim.maxW * z, Math.min(boardW - nx, frame.startW + dx));
        } else if (frame.gripH < 0) {
            var right = frame.startX + frame.startW;
            nw = Math.min(lim.maxW * z, Math.min(right, frame.startW - dx));
        }
        if (frame.gripV > 0) {
            nh = Math.min(lim.maxH * z, Math.min(boardH - ny, frame.startH + dy));
        } else if (frame.gripV < 0) {
            var bottom = frame.startY + frame.startH;
            nh = Math.min(lim.maxH * z, Math.min(bottom, frame.startH - dy));
        }
        nw = Math.max(lim.minW * z, nw);
        nh = Math.max(lim.minH * z, nh);
        if (frame.gripH < 0)
            nx = frame.startX + frame.startW - nw;

        if (frame.gripV < 0)
            ny = frame.startY + frame.startH - nh;

        frame.resX = nx;
        frame.resY = ny;
        frame.resW = nw;
        frame.resH = nh;
        Widgets.setLive(frame.uid, nx, ny, nw, nh);
    }

    function endResize() {
        if (!frame.resizing)
            return ;

        var z = frame.safeZoom;
        Widgets.setSize(frame.uid, frame.resW / z, frame.resH / z);
        Widgets.setPos(frame.uid, frame.resX, frame.resY);
        frame.resizing = false;
        Widgets.liveUid = "";
    }

    // the menu's shortcut for the look the visualiser is really after
    function fillWidth() {
        if (!frame.board || !frame.resizable)
            return ;

        Widgets.setSize(frame.uid, frame.board.width / frame.safeZoom, frame.bh);
        Widgets.setPos(frame.uid, 0, frame.wy);
    }

    function toggleMenu(px, py) {
        if (frame.menuOpen) {
            frame.menuOpen = false;
            if (Widgets.menuUid === frame.uid)
                Widgets.menuUid = "";

        } else {
            // claim the slot first: the connection below shuts every other menu,
            // and this frame's own guard would close us if we opened before it
            frame.menuAtX = px === undefined ? frame.width / 2 : px;
            frame.menuAtY = py === undefined ? frame.height / 2 : py;
            Widgets.menuUid = frame.uid;
            frame.menuOpen = true;
            Widgets.raise(frame.uid);
        }
    }

    // what WidgetRegion masks and blurs
    readonly property real surfaceX: 0
    readonly property real surfaceY: 0
    readonly property real surfaceWidth: frame.width
    readonly property real surfaceHeight: frame.height
    readonly property int surfaceRadius: frame.radius

    visible: frame.onThisScreen && frame.opacity > 0.01
    width: frame.cardW
    height: frame.cardH
    z: frame.zOrder
    x: frame.resizing ? frame.resX : (frame.dragging ? frame.dragX : frame.clampX(frame.wx))
    y: frame.resizing ? frame.resY : (frame.dragging ? frame.dragY : frame.clampY(frame.wy))
    opacity: (frame.closing || frame.blanked) ? 0 : (frame.appeared ? (frame.overBin ? 0.4 : 1) : 0)
    scale: frame.closing ? 0.9 : (frame.appeared ? (frame.overBin ? 0.94 : (frame.dragging ? 1.025 : 1)) : (frame.landed ? 1 : (frame.born ? 0.86 : 0.97)))

    property bool appeared: false

    Component.onCompleted: appearTimer.start()
    // the box picks cards up and drops them live; letting it go keeps what it held
    onMarkedChanged: {
        if (Widgets.marquee !== null)
            Widgets.select(frame.uid, frame.marked);

    }
    onLockedChanged: {
        if (frame.locked)
            Widgets.select(frame.uid, false);

    }

    Connections {
        function onMenuUidChanged() {
            if (Widgets.menuUid !== frame.uid)
                frame.menuOpen = false;

        }

        target: Widgets
    }

    Timer {
        id: appearTimer

        interval: frame.born ? 20 : 1
        onTriggered: frame.appeared = true
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeStandard
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }

    }

    Behavior on width {
        enabled: frame.appeared && !frame.resizing

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeStandard
        }

    }

    Behavior on height {
        enabled: frame.appeared && !frame.resizing

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeStandard
        }

    }

    Behavior on x {
        enabled: !frame.dragging && !frame.resizing

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeStandard
        }

    }

    Behavior on y {
        enabled: !frame.dragging && !frame.resizing

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeStandard
        }

    }

    HoverHandler {
        id: hoverHandler

        enabled: !frame.closing
        onHoveredChanged: frame.hovered = hoverHandler.hovered
        cursorShape: (frame.locked || frame.resizing) ? Qt.ArrowCursor : (frame.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
    }

    // sits under the body so buttons and fields inside the widget win the click
    MouseArea {
        id: dragArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: (mouse) => {
            Widgets.raise(frame.uid);
            frame.beginDrag(mouse.x, mouse.y);
        }
        onPositionChanged: (mouse) => {
            return frame.moveDrag(mouse.x, mouse.y);
        }
        onReleased: frame.endDrag()
        onCanceled: frame.endDrag()
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: frame.radius
        clip: true
        color: frame.bare ? "transparent" : (body.item && body.item.fill !== undefined ? body.item.fill : Theme.bg)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durSlowEffects
            }

        }

        // the body lays out at its natural size and the whole thing is scaled, so a
        // variant never has to know what zoom it is being drawn at
        Item {
            width: frame.bodyW
            height: frame.bodyH
            scale: frame.zoom
            transformOrigin: Item.TopLeft

            // a preset can resize a card as it moves it, so the content follows the card
            Behavior on scale {
                enabled: frame.appeared && !frame.resizing

                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeStandard
                }

            }

            Loader {
                id: body

                anchors.fill: parent
                asynchronous: false
                // clock -> ClockWidget.qml, and so on for every category
                source: frame.wtype === "" ? "" : frame.wtype.charAt(0).toUpperCase() + frame.wtype.slice(1) + "Widget.qml"

            }

        }

        Binding {
            target: body.item
            property: "host"
            value: frame
            when: body.status === Loader.Ready
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.text
            // a pinned card cannot be moved or resized, so it gets no hover chrome
            // at all - on a bare full-width one this tint was a stray rectangle
            opacity: frame.locked ? 0 : (frame.dragging ? 0.07 : (frame.active ? 0.035 : 0))

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

    // no hover chrome: right-press opens the options menu, and a right-drag moves
    // the widget, since bodies that cover their whole card (notes, palette) eat the
    // left press that dragArea below would have used
    MouseArea {
        id: menuArea

        property real pressX: 0
        property real pressY: 0
        property bool moved: false

        anchors.fill: parent
        z: 6
        // left presses fall straight through to the body and to dragArea
        acceptedButtons: Qt.RightButton
        onPressed: (mouse) => {
            menuArea.pressX = mouse.x;
            menuArea.pressY = mouse.y;
            menuArea.moved = false;
            Widgets.raise(frame.uid);
        }
        onPositionChanged: (mouse) => {
            if (!menuArea.moved) {
                // a pinned widget cannot move, so never swallow its menu click
                if (frame.locked)
                    return ;

                if (Math.abs(mouse.x - menuArea.pressX) < 4 && Math.abs(mouse.y - menuArea.pressY) < 4)
                    return ;

                menuArea.moved = true;
                frame.beginDrag(menuArea.pressX, menuArea.pressY);
            }
            frame.moveDrag(mouse.x, mouse.y);
        }
        onReleased: {
            if (menuArea.moved)
                frame.endDrag();
            else
                frame.toggleMenu(menuArea.pressX, menuArea.pressY);
            menuArea.moved = false;
        }
        onCanceled: {
            if (menuArea.moved)
                frame.endDrag();

            menuArea.moved = false;
        }
    }

    // what the desktop's box caught, shown live while the box is still out, and the
    // card the widget panel's list is pointing at
    Rectangle {
        anchors.fill: parent
        z: 7
        radius: frame.radius
        color: Theme.alpha(Theme.accent, 0.1)
        border.width: 2
        border.color: Theme.accent
        opacity: (frame.selected || frame.spotted) ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    // a resizable card has no other affordance, so outline it while it is under
    // the pointer - the bare variants have no container to hint at an edge
    Item {
        anchors.fill: parent
        z: 7
        visible: frame.resizable && !frame.locked && outline.opacity > 0.01

        Rectangle {
            id: outline

            anchors.fill: parent
            radius: frame.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.accent, 0.55)
            opacity: (frame.active || frame.resizing) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Repeater {
            model: frame.gripSpecs

            Rectangle {
                id: dot

                required property var modelData

                readonly property bool corner: dot.modelData.h !== 0 && dot.modelData.v !== 0

                width: Theme.dp(6)
                height: Theme.dp(6)
                radius: Theme.dp(3)
                color: Theme.accent
                opacity: outline.opacity
                visible: dot.corner
                x: dot.modelData.h < 0 ? -Theme.dp(3) : frame.width - Theme.dp(3)
                y: dot.modelData.v < 0 ? -Theme.dp(3) : frame.height - Theme.dp(3)
            }

        }

    }

    // eight handles over everything else, left button only so a right press still
    // reaches the menu underneath
    Repeater {
        model: (frame.resizable && !frame.locked) ? frame.gripSpecs : []

        MouseArea {
            id: grip

            required property var modelData

            readonly property real t: frame.gripSize

            z: 8
            enabled: !frame.locked
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: {
                if (grip.modelData.h === 0)
                    return Qt.SizeVerCursor;

                if (grip.modelData.v === 0)
                    return Qt.SizeHorCursor;

                return grip.modelData.h === grip.modelData.v ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor;
            }
            x: grip.modelData.h < 0 ? 0 : (grip.modelData.h > 0 ? frame.width - grip.t : grip.t)
            y: grip.modelData.v < 0 ? 0 : (grip.modelData.v > 0 ? frame.height - grip.t : grip.t)
            width: grip.modelData.h === 0 ? Math.max(0, frame.width - grip.t * 2) : grip.t
            height: grip.modelData.v === 0 ? Math.max(0, frame.height - grip.t * 2) : grip.t
            onPressed: (mouse) => {
                var p = grip.mapToItem(frame.board, mouse.x, mouse.y);
                frame.beginResize(grip.modelData.h, grip.modelData.v, p.x, p.y);
            }
            onPositionChanged: (mouse) => {
                var p = grip.mapToItem(frame.board, mouse.x, mouse.y);
                frame.moveResize(p.x, p.y);
            }
            onReleased: frame.endResize()
            onCanceled: frame.endResize()
        }

    }

    // while the widget panel is open every card carries a way off the desktop,
    // pulled inside the screen when the card sits right on its edge
    Item {
        id: removeBadge

        readonly property bool shown: frame.editMode && !frame.closing && !frame.dragging && !frame.resizing

        z: 9
        width: Theme.dp(26)
        height: Theme.dp(26)
        x: Math.max(-Theme.dp(9), Theme.dp(4) - frame.x)
        y: Math.max(-Theme.dp(9), Theme.dp(4) - frame.y)
        opacity: removeBadge.shown ? 1 : 0
        scale: removeBadge.shown ? 1 : 0.5
        visible: opacity > 0.01

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: badgeArea.containsMouse ? Theme.error : Theme.surfaceHighest
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.12)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durFastEffects
                }

            }

        }

        Icon {
            anchors.centerIn: parent
            name: "remove"
            size: Theme.dp(18)
            color: badgeArea.containsMouse ? Theme.fgError : Theme.text
        }

        StateLayer {
            id: badgeArea

            radius: width / 2
            ripple: false
            tint: Theme.fgError
            onClicked: Widgets.close(frame.uid)
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

}
