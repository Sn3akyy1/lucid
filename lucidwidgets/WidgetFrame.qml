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
    readonly property real cardW: Math.round(frame.bw * frame.zoom)
    readonly property real cardH: Math.round(frame.bh * frame.zoom)
    readonly property int radius: Math.round(Math.min(Theme.radiusXl * frame.zoom, frame.cardH / 2, frame.cardW / 2))
    // the same corner expressed in the body's own unscaled coordinates
    readonly property real bodyRadius: frame.zoom > 0 ? frame.radius / frame.zoom : frame.radius
    readonly property bool active: frame.hovered || frame.dragging || frame.menuOpen
    // a variant can ask for no container at all and draw straight onto the wallpaper
    readonly property bool bare: body.item !== null && body.item.bare === true

    property bool dragging: false
    property bool hovered: false
    property bool menuOpen: false
    property real dragX: 0
    property real dragY: 0
    property real grabX: 0
    property real grabY: 0
    property real guideX: -1
    property real guideY: -1

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

    function toggleMenu() {
        if (frame.menuOpen) {
            frame.menuOpen = false;
            if (Widgets.menuUid === frame.uid)
                Widgets.menuUid = "";

        } else {
            // claim the slot first: the connection below shuts every other menu,
            // and this frame's own guard would close us if we opened before it
            Widgets.menuUid = frame.uid;
            frame.menuOpen = true;
            Widgets.raise(frame.uid);
        }
    }

    // what WidgetRegion masks and blurs
    readonly property real surfaceX: 0
    readonly property real surfaceY: 0
    readonly property real surfaceWidth: frame.cardW
    readonly property real surfaceHeight: frame.cardH
    readonly property int surfaceRadius: frame.radius
    // the options panel is a child of this frame, so its board position is just an offset
    readonly property bool menuVisible: menu.visible
    readonly property real menuX: frame.x + menu.x
    readonly property real menuY: frame.y + menu.y
    readonly property real menuW: menu.width
    readonly property real menuH: menu.height
    readonly property int menuRadius: Theme.radiusLg

    visible: frame.onThisScreen && frame.opacity > 0.01
    width: frame.cardW
    height: frame.cardH
    z: frame.zOrder
    x: frame.dragging ? frame.dragX : frame.clampX(frame.wx)
    y: frame.dragging ? frame.dragY : frame.clampY(frame.wy)
    opacity: frame.closing ? 0 : (frame.appeared ? 1 : 0)
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
        enabled: frame.appeared

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeStandard
        }

    }

    Behavior on height {
        enabled: frame.appeared

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeStandard
        }

    }

    Behavior on x {
        enabled: !frame.dragging

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeStandard
        }

    }

    Behavior on y {
        enabled: !frame.dragging

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeStandard
        }

    }

    HoverHandler {
        id: hoverHandler

        enabled: !frame.closing
        onHoveredChanged: frame.hovered = hoverHandler.hovered
        cursorShape: frame.locked ? Qt.ArrowCursor : (frame.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
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
            width: frame.bw
            height: frame.bh
            scale: frame.zoom
            transformOrigin: Item.TopLeft

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
            opacity: frame.dragging ? 0.07 : (frame.active ? 0.035 : 0)

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
                frame.toggleMenu();
            menuArea.moved = false;
        }
        onCanceled: {
            if (menuArea.moved)
                frame.endDrag();

            menuArea.moved = false;
        }
    }

    WidgetMenu {
        id: menu

        frame: frame
        z: 30
    }

}
