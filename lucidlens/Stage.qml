import QtQuick
import QtQuick.Window
import qs
import qs.lucidui

// the pictures on show: the current one with a neighbour on either side, ready
// to slide in. zoom and pan belong to the current one; neighbours always fit.
// a picture's place in the strip of three is its role: -1, 0 or 1
Item {
    id: stage

    required property var win
    required property var app
    property var items: []
    property int index: -1
    property var edits: null
    property bool cropping: false
    property bool drawing: false
    // held still: no swiping to a neighbour, no zoom (a trim is being set)
    property bool locked: false
    property bool original: false
    property var draft: null
    property bool playing: true
    // what the wheel does: "zoom" | "browse"
    property string wheelMode: "zoom"
    property bool wrap: true
    property real pad: stage.cropping ? Theme.dp(44) : Theme.dp(14)
    readonly property real gap: Theme.dp(28)
    // the slot holding the current picture; the others are its neighbours
    property int center: 0
    property real trackX: 0
    property real panX: 0
    property real panY: 0
    property bool zoomed: false
    property real zoomValue: 1
    readonly property Item currentSlot: stage.slotFor(0)
    readonly property Item current: stage.currentSlot ? stage.currentSlot.picture : null
    // the video on show, and its player once it has one (Movie.qml)
    readonly property bool videoHere: stage.currentSlot !== null && stage.currentSlot.isVideo
    readonly property Item movie: stage.videoHere && stage.current ? stage.current.overlayItem : null
    readonly property real fitScale: stage.currentSlot ? stage.currentSlot.fit : 1
    readonly property real shownScale: stage.zoomed || zoomAnim.running ? stage.zoomValue : stage.fitScale
    readonly property real maxScale: Math.max(stage.fitScale * 2, 24)
    // the current picture's place on the stage, for whatever is laid over it
    readonly property rect picRect: {
        var p = stage.current;
        if (!p)
            return Qt.rect(stage.width / 2, stage.height / 2, 0, 0);

        var w = p.width * stage.shownScale, h = p.height * stage.shownScale;
        return Qt.rect((stage.width - w) / 2 + stage.panX + stage.trackX, (stage.height - h) / 2 + stage.panY, w, h);
    }
    readonly property bool canPan: stage.current !== null && (stage.current.width * stage.shownScale > stage.width + 1 || stage.current.height * stage.shownScale > stage.height + 1)
    readonly property bool sliding: slide.running || Math.abs(stage.trackX) > 0.5
    property real _zoomFrom: 1
    property real _zoomTo: 1
    property var _anchor: null
    property int _lastIndex: -1
    property bool _jump: false

    signal navigate(int delta)
    signal menuAt(real x, real y)
    signal tapped()

    function slotFor(role) {
        for (var i = 0; i < slotRep.count; i++) {
            var s = slotRep.itemAt(i);
            if (s && s.role === role)
                return s;

        }
        return null;
    }

    // ---- zoom

    function zoomTo(target, px, py, animate) {
        if (!stage.current || stage.cropping)
            return ;

        target = Math.max(stage.fitScale, Math.min(stage.maxScale, target));
        var from = stage.shownScale;
        if (px === undefined) {
            px = stage.width / 2;
            py = stage.height / 2;
        }
        var cx = px - stage.width / 2, cy = py - stage.height / 2;
        stage._anchor = {
            "cx": cx,
            "cy": cy,
            "ix": (cx - stage.panX) / from,
            "iy": (cy - stage.panY) / from,
            "px": stage.panX,
            "py": stage.panY,
            "fit": Math.abs(target - stage.fitScale) < 0.0001
        };
        stage._zoomFrom = from;
        stage._zoomTo = target;
        stage.zoomValue = from;
        stage.zoomed = !stage._anchor.fit;
        if (animate === false || Theme.motionScale <= 0) {
            zoomAnim.stop();
            stage.zoomT = 1;
            stage.applyZoom();
        } else {
            zoomAnim.restart();
        }
    }

    // where an eased zoom is by now: scale goes geometrically, so each frame looks
    // like the same step; the point under the pointer stays under it
    property real zoomT: 1

    onZoomTChanged: stage.applyZoom()

    function applyZoom() {
        var a = stage._anchor;
        if (!a)
            return ;

        var s = stage._zoomFrom * Math.pow(stage._zoomTo / stage._zoomFrom, stage.zoomT);
        stage.zoomValue = s;
        if (a.fit) {
            stage.panX = a.px * (1 - stage.zoomT);
            stage.panY = a.py * (1 - stage.zoomT);
        } else {
            stage.panX = a.cx - a.ix * s;
            stage.panY = a.cy - a.iy * s;
            stage.clampPan();
        }
    }

    function zoomBy(k, px, py) {
        var base = zoomAnim.running ? stage._zoomTo : stage.shownScale;
        var target = base * k;
        // fit and 1:1 catch a zoom passing them
        var marks = [stage.fitScale, 1];
        for (var i = 0; i < marks.length; i++) {
            var m = marks[i];
            if ((base < m * 0.999 && target > m * 1.001) || (base > m * 1.001 && target < m * 0.999))
                target = m;

        }
        stage.zoomTo(target, px, py, true);
    }

    function fit() {
        stage.zoomTo(stage.fitScale, undefined, undefined, true);
    }

    // a double click: in to 1:1 (or twice fit, for a small picture) where it
    // landed, or back out to fit
    function toggleZoom(px, py) {
        if (stage.zoomed) {
            stage.fit();
            return ;
        }
        var target = stage.fitScale < 0.999 ? 1 : Math.min(stage.maxScale, stage.fitScale * 2);
        stage.zoomTo(target, px, py, true);
    }

    function clampPan() {
        var p = stage.current;
        if (!p)
            return ;

        var s = stage.shownScale;
        var mx = Math.max(0, (p.width * s - stage.width) / 2), my = Math.max(0, (p.height * s - stage.height) / 2);
        stage.panX = Math.max(-mx, Math.min(mx, stage.panX));
        stage.panY = Math.max(-my, Math.min(my, stage.panY));
    }

    function resetView() {
        zoomAnim.stop();
        coastX.stop();
        coastY.stop();
        stage._anchor = null;
        stage.zoomed = false;
        stage.panX = 0;
        stage.panY = 0;
    }

    // ---- sliding to a neighbour

    // the strip moves from where it is drawn to rest, so a drag hands over
    // straight into the slide
    function settle() {
        slide.stop();
        if (Math.abs(stage.trackX) < 0.5 || Theme.motionScale <= 0) {
            stage.trackX = 0;
            return ;
        }
        slide.from = stage.trackX;
        slide.to = 0;
        slide.duration = Math.round(Theme.durLong * Math.min(1, 0.45 + Math.abs(stage.trackX) / Math.max(1, stage.width)));
        slide.start();
    }

    function go(delta) {
        if (stage.items.length < 2)
            return ;

        var n = stage.items.length, to = stage.index + delta;
        if (to < 0 || to >= n) {
            if (!stage.wrap) {
                stage.bump(delta);
                return ;
            }
            to = (to + n) % n;
        }
        stage.navigate(to - stage.index);
    }

    // at an end with nowhere to go: a nudge that way and back
    function bump(delta) {
        slide.stop();
        nudge.dir = delta;
        nudge.restart();
    }

    onIndexChanged: {
        var was = stage._lastIndex;
        stage._lastIndex = stage.index;
        stage.resetView();
        if (was < 0 || stage.index < 0) {
            stage.trackX = 0;
            return ;
        }
        var d = stage.index - was;
        var n = stage.items.length;
        // past the end and round to the start counts as the next one
        if (stage.wrap && n > 2 && Math.abs(d) === n - 1)
            d = d > 0 ? -1 : 1;

        if (d === 1 || d === -1) {
            // the neighbour already holds it: the strip turns one slot and slides
            stage.center = (stage.center + d + 3) % 3;
            stage.trackX += d * (stage.width + stage.gap);
        } else if (d !== 0) {
            stage.trackX = (d > 0 ? 1 : -1) * Math.min(stage.width * 0.35, Theme.dp(260));
        }
        stage.settle();
    }

    clip: true

    NumberAnimation {
        id: slide

        target: stage
        property: "trackX"
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedDecel
    }

    SequentialAnimation {
        id: nudge

        property int dir: 1

        NumberAnimation {
            target: stage
            property: "trackX"
            to: -nudge.dir * Theme.dp(36)
            duration: Theme.durShort
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: stage
            property: "trackX"
            to: 0
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    NumberAnimation {
        id: zoomAnim

        target: stage
        property: "zoomT"
        from: 0
        to: 1
        duration: Theme.durMedium
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedDecel
        onFinished: {
            if (stage._anchor && stage._anchor.fit) {
                stage.zoomed = false;
                stage.panX = 0;
                stage.panY = 0;
            }
        }
    }

    // a pan let go keeps going and slows to a stop
    NumberAnimation {
        id: coastX

        target: stage
        property: "panX"
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: coastY

        target: stage
        property: "panY"
        easing.type: Easing.OutQuad
    }

    function coast(vx, vy) {
        var p = stage.current;
        if (!p || Theme.motionScale <= 0)
            return ;

        var decel = 0.0028;
        var s = stage.shownScale;
        var mx = Math.max(0, (p.width * s - stage.width) / 2), my = Math.max(0, (p.height * s - stage.height) / 2);
        var go1 = function(anim, v, now, lim) {
            var speed = Math.abs(v) / 1000;
            if (speed < 0.08)
                return ;

            var dist = speed * speed / (2 * decel) * (v > 0 ? 1 : -1);
            var to = Math.max(-lim, Math.min(lim, now + dist));
            anim.from = now;
            anim.to = to;
            anim.duration = Math.max(120, Math.min(1400, 2 * Math.abs(to - now) / speed));
            anim.restart();
        };
        go1(coastX, vx, stage.panX, mx);
        go1(coastY, vy, stage.panY, my);
    }

    onWidthChanged: Qt.callLater(stage.clampPan)
    onHeightChanged: Qt.callLater(stage.clampPan)

    Repeater {
        id: slotRep

        model: 3

        delegate: Item {
            id: slot

            required property int index
            readonly property int role: ((slot.index - stage.center + 4) % 3) - 1
            readonly property int at: stage.index < 0 ? -1 : stage.wrap && stage.items.length > 2 ? (stage.index + slot.role + stage.items.length) % stage.items.length : stage.index + slot.role
            readonly property var entry: slot.at >= 0 && slot.at < stage.items.length && (slot.role === 0 || stage.items.length > 1) ? stage.items[slot.at] : null
            readonly property bool isCurrent: slot.role === 0
            readonly property alias picture: picture
            readonly property real fit: picture.width > 0 && picture.height > 0 ? Math.min(stage.cropping ? 4 : 1, (stage.width - 2 * stage.pad) / picture.width, (stage.height - 2 * stage.pad) / picture.height) : 1
            readonly property real s: slot.isCurrent ? stage.shownScale : slot.fit
            readonly property string src: !slot.entry ? "" : (slot.entry.display || "")
            readonly property bool isVideo: slot.entry !== null && slot.entry.video === true
            // a video's player comes once a slide to it has settled, and stays while
            // it is the one on show, a drag away and back included
            property bool movieOn: false

            function checkMovie() {
                slot.movieOn = slot.isCurrent && slot.isVideo && slot.src !== "" && (slot.movieOn || !stage.sliding);
            }

            onIsCurrentChanged: slot.checkMovie()
            onIsVideoChanged: slot.checkMovie()
            onSrcChanged: slot.checkMovie()
            Component.onCompleted: slot.checkMovie()

            Connections {
                function onSlidingChanged() {
                    slot.checkMovie();
                }

                target: stage
            }

            x: slot.role * (stage.width + stage.gap) + stage.trackX
            width: stage.width
            height: stage.height
            visible: slot.entry !== null && (slot.isCurrent || stage.sliding)

            // the folder's own thumbnail, until the picture itself is in
            Image {
                anchors.fill: parent
                anchors.margins: stage.pad
                fillMode: Image.PreserveAspectFit
                visible: !picture.ready && slot.entry !== null && (slot.entry.thumb || "") !== ""
                source: visible ? "file://" + slot.entry.thumb : ""
                asynchronous: true
                smooth: true
            }

            Item {
                id: holder

                x: (slot.width - width) / 2 + (slot.isCurrent ? stage.panX : 0)
                y: (slot.height - height) / 2 + (slot.isCurrent ? stage.panY : 0)
                width: picture.width * slot.s
                height: picture.height * slot.s

                // see-through parts on a checkerboard, drawn at the screen's own size
                Image {
                    anchors.fill: parent
                    visible: picture.ready && slot.entry !== null && slot.entry.canAlpha === true && stage.app.prefs.checker
                    source: stage.checker
                    sourceSize: Qt.size(16, 16)
                    fillMode: Image.Tile
                    smooth: false
                }

                Picture {
                    id: picture

                    transformOrigin: Item.TopLeft
                    scale: slot.s
                    source: slot.src
                    animated: slot.entry !== null && slot.entry.animated === true
                    vector: slot.entry !== null && slot.entry.vector === true
                    full: slot.isCurrent
                    limit: Qt.size(Math.max(1920, Screen.width), Math.max(1080, Screen.height))
                    edits: slot.isCurrent ? stage.edits : null
                    showFrame: slot.isCurrent && stage.cropping
                    original: slot.isCurrent && stage.original
                    draft: slot.isCurrent ? stage.draft : null
                    playing: stage.playing && slot.isCurrent
                    overlay: slot.movieOn ? Qt.resolvedUrl("Movie.qml") : ""
                    // a file written again (turned, put back) is opened again
                    overlayKey: slot.movieOn && slot.entry ? slot.entry.path + "@" + slot.entry.mtime : ""
                    overlayProps: ({
                        "win": stage.win,
                        "path": slot.entry ? slot.entry.path : ""
                    })
                }

            }

            LoadingIndicator {
                anchors.centerIn: parent
                width: Theme.dp(48)
                height: Theme.dp(48)
                visible: slot.isCurrent && wait.busy && wait.done
                contained: true

                Timer {
                    id: wait

                    property bool done: false
                    readonly property bool busy: picture.status === Image.Loading || (slot.isCurrent && stage.movie !== null && stage.movie.waiting)

                    interval: 450
                    running: wait.busy
                    onRunningChanged: {
                        if (running)
                            done = false;

                    }
                    onTriggered: done = true
                }

            }

            Column {
                anchors.centerIn: parent
                visible: slot.entry !== null && (picture.status === Image.Error || slot.entry.broken === true)
                spacing: Theme.dp(10)

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "broken_image"
                    size: Theme.dp(48)
                    color: Theme.subtext
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "titleMedium"
                    text: slot.isVideo ? "Can't play this video" : "Can't show this picture"
                    color: Theme.text
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, slot.width - Theme.dp(64))
                    role: "bodyMedium"
                    text: slot.entry ? (slot.entry.why || slot.entry.name) : ""
                    color: Theme.subtext
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }

            }

        }

    }

    // a 16 px checkerboard tile, behind whatever can be see-through
    readonly property string checker: {
        var a = Theme.isLight ? "#e4e4e4" : "#3b3b3b", b = Theme.isLight ? "#ffffff" : "#2b2b2b";
        return "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="' + b + '"/><rect width="8" height="8" fill="' + a + '"/><rect x="8" y="8" width="8" height="8" fill="' + a + '"/></svg>');
    }

    // ---- the pointer

    // a drag pans a picture bigger than the stage, and otherwise pulls the next
    // one in; let go past a fifth of the way (or flicked) and it goes
    HeldPointer {
        held: drag.active
        cursor: Qt.ClosedHandCursor
    }

    DragHandler {
        id: drag

        property real startX: 0
        property real startY: 0
        property real startTrack: 0

        target: null
        enabled: !stage.drawing && !stage.cropping && !stage.locked
        acceptedButtons: Qt.LeftButton
        // a press a control over the stage took stays with it: the time line, the map, a button
        grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByAnything
        cursorShape: active ? Qt.ClosedHandCursor : (stage.canPan ? Qt.OpenHandCursor : Qt.ArrowCursor)
        onActiveChanged: {
            if (active) {
                coastX.stop();
                coastY.stop();
                slide.stop();
                nudge.stop();
                drag.startX = stage.panX;
                drag.startY = stage.panY;
                drag.startTrack = stage.trackX;
                return ;
            }
            var v = drag.centroid.velocity;
            if (stage.canPan) {
                stage.coast(v.x, v.y);
                return ;
            }
            stage.release(v.x);
        }
        onActiveTranslationChanged: {
            if (!active)
                return ;

            if (stage.canPan) {
                stage.panX = drag.startX + activeTranslation.x;
                stage.panY = drag.startY + activeTranslation.y;
                stage.clampPan();
            } else if (stage.items.length > 1) {
                stage.trackX = stage.pull(drag.startTrack + activeTranslation.x);
            }
        }
    }

    // a pull past either end only gives a little
    function pull(x) {
        var n = stage.items.length;
        var atStart = !stage.wrap && stage.index <= 0, atEnd = !stage.wrap && stage.index >= n - 1;
        if ((x > 0 && atStart) || (x < 0 && atEnd))
            return x * 0.3;

        return x;
    }

    function release(vx) {
        var w = stage.width + stage.gap;
        var far = Math.abs(stage.trackX) > stage.width * 0.2 || (Math.abs(vx) > 600 && Math.abs(stage.trackX) > Theme.dp(24));
        var dir = stage.trackX < 0 ? 1 : -1;
        var n = stage.items.length;
        var blocked = !stage.wrap && ((dir > 0 && stage.index >= n - 1) || (dir < 0 && stage.index <= 0));
        if (far && !blocked && n > 1)
            stage.go(dir);
        else
            stage.settle();
    }

    PinchHandler {
        id: pinch

        property real startScale: 1

        target: null
        enabled: !stage.drawing && !stage.cropping && !stage.locked
        onActiveChanged: {
            if (active) {
                zoomAnim.stop();
                pinch.startScale = stage.shownScale;
            } else if (stage.shownScale <= stage.fitScale * 1.02) {
                stage.fit();
            }
        }
        onActiveScaleChanged: {
            if (!active)
                return ;

            var c = pinch.centroid.position;
            stage.zoomTo(Math.max(stage.fitScale * 0.85, pinch.startScale * activeScale), c.x, c.y, false);
        }
    }

    // a mouse wheel zooms where the pointer is (or browses, if set so); a touchpad
    // pans a zoomed picture, and side to side pulls the next one in like a drag
    property real padTrack: 0
    property real padSpeed: 0
    property real padAt: 0

    // not a WheelHandler: that drops whatever has nothing on its own axis, which is
    // a level swipe, and the empty ScrollBegin that starts every swipe
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (event) => {
            if (stage.locked)
                return ;

            var p = Qt.point(event.x, event.y);
            if (event.phase !== Qt.NoScrollPhase && !(event.modifiers & Qt.ControlModifier)) {
                if (stage.cropping)
                    return ;

                if (stage.canPan) {
                    coastX.stop();
                    coastY.stop();
                    stage.panX += event.pixelDelta.x * 2;
                    stage.panY += event.pixelDelta.y * 2;
                    stage.clampPan();
                    return ;
                }
                if (event.phase === Qt.ScrollBegin) {
                    slide.stop();
                    nudge.stop();
                    stage.padTrack = stage.trackX;
                    stage.padSpeed = 0;
                    stage.padAt = Date.now();
                }
                // qt sends each empty begin and end twice: only the first end counts
                if (event.phase === Qt.ScrollEnd) {
                    if (stage.padAt > 0 && Math.abs(stage.trackX) > 0.5)
                        stage.release(Date.now() - stage.padAt < 90 ? stage.padSpeed * 1000 : 0);

                    stage.padAt = 0;
                    return ;
                }
                if (Math.abs(event.pixelDelta.x) >= Math.abs(event.pixelDelta.y) && stage.items.length > 1) {
                    slide.stop();
                    var d = event.pixelDelta.x * 2.4, now = Date.now(), dt = Math.max(1, now - stage.padAt);
                    stage.padSpeed = dt > 90 ? d / dt : stage.padSpeed * 0.6 + d / dt * 0.4;
                    stage.padAt = now;
                    stage.padTrack += d;
                    stage.trackX = stage.pull(stage.padTrack);
                }
                return ;
            }
            if (event.phase !== Qt.NoScrollPhase)
                return ;

            var dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            if (dy === 0)
                return ;

            var browse = stage.wheelMode === "browse" && !(event.modifiers & Qt.ControlModifier);
            if (browse || (event.modifiers & Qt.ShiftModifier)) {
                if (!stage.cropping)
                    stage.go(dy < 0 ? 1 : -1);

                return ;
            }
            if (!stage.cropping)
                stage.zoomBy(Math.pow(1.25, dy / 120), p.x, p.y);
        }
    }

    // a second tap close by in time and place is a double click: counted here,
    // so it works the same for every kind of pointer
    TapHandler {
        property real lastAt: 0
        property point lastPos

        acceptedButtons: Qt.LeftButton
        enabled: !stage.drawing && !stage.cropping
        onTapped: (eventPoint, button) => {
            var now = Date.now(), p = eventPoint.position;
            if (now - lastAt < Qt.styleHints.mouseDoubleClickInterval && Math.abs(p.x - lastPos.x) + Math.abs(p.y - lastPos.y) < Theme.dp(16)) {
                lastAt = 0;
                single.stop();
                // a video: the first click's pause taken back, and full screen
                if (stage.movie) {
                    stage.movie.toggle();
                    stage.win.setImmersive(!stage.win.immersive);
                } else {
                    stage.toggleZoom(p.x, p.y);
                }
            } else {
                lastAt = now;
                lastPos = p;
                // a click on a video plays or pauses it at once, as players do
                if (stage.movie)
                    stage.movie.toggle();
                else
                    single.restart();
            }
        }
    }

    Timer {
        id: single

        interval: Qt.styleHints.mouseDoubleClickInterval
        onTriggered: stage.tapped()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !stage.drawing
        onTapped: (eventPoint, button) => {
            return stage.menuAt(eventPoint.position.x, eventPoint.position.y);
        }
    }

}
