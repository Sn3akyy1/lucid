import QtQuick
import qs

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
    // while a grip is held the card runs off the live drag, not off the store
    readonly property real bodyW: frame.resizing ? frame.resW / frame.safeZoom : frame.bw
    readonly property real bodyH: frame.resizing ? frame.resH / frame.safeZoom : frame.bh
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
    readonly property bool blanked: body.item !== null && body.item.hidden === true && !frame.dragging && !frame.resizing && !frame.menuOpen

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

    readonly property real gripSize: 12
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

    readonly property real snapPad: 20
    readonly property real snapGap: 16
    readonly property real snapDist: 9

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
            if (f && f !== frame && f.visible && !f.closing)
                out.push(f);

        }
        return out;
    }

    // v is where the edge would land, g is the line to draw when it does
    function bestSnap(pos, cands) {
        var best = null;
        var bd = frame.snapDist;
        for (var i = 0; i < cands.length; i++) {
            var d = Math.abs(pos - cands[i].v);
            if (d < bd) {
                bd = d;
                best = cands[i];
            }
        }
        return best;
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
        var W = frame.board.width;
        var H = frame.board.height;
        var xs = [{
            "v": frame.snapPad,
            "g": frame.snapPad
        }, {
            "v": W - frame.snapPad - frame.cardW,
            "g": W - frame.snapPad
        }, {
            "v": (W - frame.cardW) / 2,
            "g": W / 2
        }];
        var ys = [{
            "v": frame.snapPad,
            "g": frame.snapPad
        }, {
            "v": H - frame.snapPad - frame.cardH,
            "g": H - frame.snapPad
        }, {
            "v": (H - frame.cardH) / 2,
            "g": H / 2
        }];
        var sib = frame.siblings();
        for (var i = 0; i < sib.length; i++) {
            var f = sib[i];
            xs.push({
                "v": f.x,
                "g": f.x
            }, {
                "v": f.x + f.width - frame.cardW,
                "g": f.x + f.width
            }, {
                "v": f.x + (f.width - frame.cardW) / 2,
                "g": f.x + f.width / 2
            }, {
                "v": f.x + f.width + frame.snapGap,
                "g": -1
            }, {
                "v": f.x - frame.snapGap - frame.cardW,
                "g": -1
            });
            ys.push({
                "v": f.y,
                "g": f.y
            }, {
                "v": f.y + f.height - frame.cardH,
                "g": f.y + f.height
            }, {
                "v": f.y + (f.height - frame.cardH) / 2,
                "g": f.y + f.height / 2
            }, {
                "v": f.y + f.height + frame.snapGap,
                "g": -1
            }, {
                "v": f.y - frame.snapGap - frame.cardH,
                "g": -1
            });
        }
        var sx = frame.bestSnap(nx, xs);
        var sy = frame.bestSnap(ny, ys);
        frame.guideX = sx ? sx.g : -1;
        frame.guideY = sy ? sy.g : -1;
        return ({
            "x": sx ? sx.v : nx,
            "y": sy ? sy.v : ny
        });
    }

    function beginDrag(mx, my) {
        if (frame.locked)
            return ;

        frame.grabX = mx;
        frame.grabY = my;
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

        var snapped = frame.snapTo(frame.dragX + (mx - frame.grabX), frame.dragY + (my - frame.grabY));
        frame.dragX = frame.clampX(snapped.x);
        frame.dragY = frame.clampY(snapped.y);
    }

    function endDrag() {
        if (!frame.dragging)
            return ;

        frame.dragging = false;
        frame.guideX = -1;
        frame.guideY = -1;
        if (frame.board && frame.board.dragFrame === frame)
            frame.board.dragFrame = null;

        if (Widgets.dragUid === frame.uid)
            Widgets.dragUid = "";

        Widgets.setPos(frame.uid, frame.dragX, frame.dragY);
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
    }

    function endResize() {
        if (!frame.resizing)
            return ;

        var z = frame.safeZoom;
        Widgets.setSize(frame.uid, frame.resW / z, frame.resH / z);
        Widgets.setPos(frame.uid, frame.resX, frame.resY);
        frame.resizing = false;
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
    opacity: (frame.closing || frame.blanked) ? 0 : (frame.appeared ? 1 : 0)
    scale: frame.closing ? 0.9 : (frame.appeared ? (frame.dragging ? 1.025 : 1) : (frame.born ? 0.86 : 0.97))

    property bool appeared: false

    Component.onCompleted: appearTimer.start()
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
        color: frame.bare ? "transparent" : Theme.bg

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

                width: 6
                height: 6
                radius: 3
                color: Theme.accent
                opacity: outline.opacity
                visible: dot.corner
                x: dot.modelData.h < 0 ? -3 : frame.width - 3
                y: dot.modelData.v < 0 ? -3 : frame.height - 3
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

}
