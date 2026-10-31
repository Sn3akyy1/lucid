import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.lucidui

// the cards a capture leaves in the corner. the newest is up front, the ones
// before it fan out behind; a click on one brings it forward. they go on their
// own unless the pointer is resting on them. a capture from the overlay flies
// into its card, so the card is made first and only shown once it has landed
PanelWindow {
    id: stack

    property var engine: null
    property var pins: null
    // the overlay, for marking a capture up
    property var overlay: null
    // newest first: { id, kind, file, thumb, w, h, temp, text, codes, screen,
    // duration, bytes, edited, busy, incoming }
    property var entries: []
    // drawn empty for a capture, without unmapping: unmapping sets off the
    // compositor's own fade, which the capture would see
    property bool cleared: false
    property bool leaving: false
    // the slide-in, skipped when the overlay flew the capture here
    property real slide: 0
    readonly property var front: stack.entries.length > 0 ? stack.entries[0] : null
    readonly property bool shownNow: stack.front !== null && stack.front.incoming !== true
    readonly property bool onScreen: stack.visible && !stack.cleared && stack.shownNow
    readonly property bool held: fieldHover.hovered || frontCard.dragging
    // m3 metrics: a 16dp gap to the screen's edges, the thumbnail inset 8dp and
    // concentric with the card
    readonly property int margin: Theme.dp(16)
    readonly property int cardW: Theme.dp(352)
    readonly property int pad: Theme.dp(8)
    readonly property int cardRadius: Theme.rad(24)
    readonly property int thumbRadius: Math.max(Theme.dp(4), stack.cardRadius - stack.pad)
    readonly property int thumbWidth: stack.cardW - stack.pad * 2
    readonly property int peek: Theme.dp(10)
    readonly property int behind: Math.min(2, Math.max(0, stack.entries.length - 1))

    // a card's parts, from what it holds; the landing spot is worked out from
    // the same numbers, so a flown capture lands on the thumbnail exactly
    function layout(e) {
        if (!e)
            return {
            "thumbH": 0,
            "textH": 0,
            "cardH": 0
        };

        const text = e.kind === "text";
        const w = e.w > 0 ? e.w : 16, h = e.h > 0 ? e.h : 9;
        // text read over ipc comes with no picture at all
        const thumbH = text ? (e.thumb ? Theme.dp(72) : 0) : Math.round(Math.max(Theme.dp(110), Math.min(Theme.dp(216), stack.thumbWidth * h / w)));
        const textH = text ? Theme.dp(96) : 0;
        return {
            "thumbH": thumbH,
            "textH": textH,
            "cardH": stack.pad + thumbH + Theme.dp(10) + Theme.dp(44) + (text ? textH + Theme.dp(4) : 0) + Theme.dp(4) + Theme.dp(40) + Theme.dp(10)
        };
    }

    // where the thumbnail of a new front card sits, in the screen's own pixels
    function landing(e) {
        const scr = stack.screenFor(e.screen);
        const sw = scr ? scr.width : 1920, sh = scr ? scr.height : 1080;
        const l = stack.layout(e);
        return {
            "x": sw - stack.margin - stack.cardW + stack.pad,
            "y": sh - stack.margin - l.cardH + stack.pad,
            "w": stack.thumbWidth,
            "h": l.thumbH,
            "radius": stack.thumbRadius
        };
    }

    function screenFor(name) {
        return Quickshell.screens.find((s) => {
            return s.name === name;
        }) || Monitors.focusedScreen || Monitors.mainScreen;
    }

    // the overlay's capture: made now, shown once it lands
    function prepare(e) {
        const done = stack.early[e.id];
        const entry = Object.assign({
            "incoming": true
        }, e, done ? {
            "file": done.file,
            "temp": done.temp === true
        } : {
        });
        if (done) {
            const m = Object.assign({
            }, stack.early);
            delete m[e.id];
            stack.early = m;
        }
        stack.place(entry);
        return stack.landing(entry);
    }

    function reveal(id) {
        stack.patch(id, {
            "incoming": false
        });
        stack.slide = 0;
        stack.restartLife();
    }

    // a capture from anywhere else slides in from the edge
    function show(e) {
        const entry = Object.assign({
            "incoming": false
        }, e);
        stack.place(entry);
        stack.slide = 1;
        slideIn.restart();
        stack.restartLife();
    }

    function place(entry) {
        stack.cleared = false;
        stack.leaving = false;
        exitAnim.stop();
        unclear.stop();
        if (entry.screen)
            stack.screen = stack.screenFor(entry.screen);

        stack.entries = [entry].concat(stack.entries.filter((x) => {
            return x.id !== entry.id;
        })).slice(0, 6);
        stack.probe(entry);
    }

    // files that were done before their card was made
    property var early: ({
    })

    // the engine finished the file a card was made for; one that is not made
    // yet (the capture is still flying) gets it as it is
    function update(e) {
        const had = stack.entries.some((x) => {
            return x.id === e.id;
        });
        if (!had) {
            const m = Object.assign({
            }, stack.early);
            m[e.id] = e;
            stack.early = m;
            return false;
        }

        stack.patch(e.id, {
            "file": e.file,
            "w": e.w || 0,
            "h": e.h || 0,
            "temp": e.temp === true
        });
        stack.probe(e);
        return true;
    }

    function patch(id, change) {
        stack.entries = stack.entries.map((x) => {
            return x.id === id ? Object.assign({
            }, x, change) : x;
        });
    }

    function dismiss(id) {
        const left = stack.entries.filter((x) => {
            return x.id !== id;
        });
        if (left.length === 0) {
            stack.dismissAll();
            return ;
        }
        stack.entries = left;
        swapIn.restart();
        stack.restartLife();
    }

    function dismissAll() {
        if (stack.entries.length === 0)
            return ;

        lifeAnim.stop();
        stack.leaving = true;
        exitAnim.restart();
    }

    function bringForward(i) {
        if (i <= 0 || i >= stack.entries.length)
            return ;

        const e = stack.entries[i];
        stack.entries = [e].concat(stack.entries.filter((x) => {
            return x.id !== e.id;
        }));
        swapIn.restart();
        stack.restartLife();
    }

    // gone this frame, no slide: a live capture is about to be taken
    function hideNow() {
        lifeAnim.stop();
        exitAnim.stop();
        slideIn.stop();
        stack.cleared = true;
        stack.entries = [];
        stack.leaving = false;
        unclear.restart();
    }

    function restartLife() {
        lifeAnim.stop();
        frontCard.life = 1;
        const text = stack.front && stack.front.kind === "text";
        lifeAnim.duration = (Math.max(3, Prefs.shotPreviewSeconds) + (text ? 4 : 0)) * 1000;
        lifeAnim.start();
    }

    function markup(e) {
        if (!stack.overlay || !e.file)
            return ;

        stack.dismiss(e.id);
        stack.overlay.edit(e.file);
    }

    function pin(e, card) {
        if (!stack.pins || !e.file)
            return ;

        const scr = stack.screenFor(e.screen);
        const sw = scr ? scr.width : 1920, sh = scr ? scr.height : 1080;
        // as big as it was, up to half the screen, set down by the card
        const k = Math.min(1, sw * 0.5 / Math.max(1, e.w), sh * 0.5 / Math.max(1, e.h));
        const w = Math.round(e.w * k), h = Math.round(e.h * k);
        stack.pins.add(e.file, scr ? scr.name : "", sw - stack.margin - w - Theme.dp(24), sh - stack.margin - h - frontCard.height - Theme.dp(24), w, h);
        stack.dismiss(e.id);
    }

    function keep(e) {
        stack.engine.keep(e.file, (f) => {
            if (f !== "")
                stack.patch(e.id, {
                "file": f,
                "temp": false
            });

        });
    }

    property var reads: ({
    })

    function readText(e) {
        const id = stack.engine.readText(e.file, null, 1, {
        });
        const r = Object.assign({
        }, stack.reads);
        r[id] = {
            "screen": e.screen,
            "thumb": e.thumb || e.file
        };
        stack.reads = r;
    }

    function makeGif(e) {
        stack.patch(e.id, {
            "busy": true
        });
        stack.engine.toGif(e.file, {
            "id": e.id + "-gif"
        });
    }

    // what ffprobe and stat know that the capture did not say
    function probe(e) {
        if (!e.file || (e.kind !== "video" && e.kind !== "gif" && e.bytes > 0))
            return ;

        probes.queue = probes.queue.concat([{
            "id": e.id,
            "file": e.file,
            "kind": e.kind
        }]);
        if (!probes.running)
            probes.next();

    }

    color: "transparent"
    // mapped from the moment a capture starts to fly here: mapping sets off the
    // compositor's fade-in, which would dim the card just as the capture lands
    visible: (stack.entries.length > 0 || stack.cleared || stack.leaving) && Monitors.surfacesUp
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucid-shot-card"
    implicitWidth: stack.cardW + stack.margin * 2
    implicitHeight: frontCard.height + stack.margin * 2 + stack.peek * 2
    BackgroundEffect.blurRegion: Theme.blurAmount > 0 && stack.onScreen && !stack.leaving ? blurArea : null
    mask: stack.onScreen ? inputArea : emptyArea

    anchors {
        bottom: true
        right: true
    }

    Region {
        id: emptyArea
    }

    Region {
        id: inputArea

        x: frontCard.x
        y: frontCard.y - stack.peek * stack.behind
        width: frontCard.width
        height: frontCard.height + stack.peek * stack.behind
    }

    Region {
        id: blurArea

        x: Math.round(frontCard.x + frontCard.tx)
        y: frontCard.y
        width: frontCard.width
        height: frontCard.height
        radius: stack.cardRadius
    }

    // the time left, run as an animation so resting on the card pauses it in place
    NumberAnimation {
        id: lifeAnim

        target: frontCard
        property: "life"
        from: 1
        to: 0
        paused: running && stack.held
        onFinished: stack.dismissAll()
    }

    // long after any capture that asked for the clear has been taken
    Timer {
        id: unclear

        interval: 1500
        onTriggered: stack.cleared = false
    }

    Item {
        id: field

        anchors.fill: parent
        visible: !stack.cleared

        // the cards behind, as slips of their own above the front one
        Repeater {
            model: stack.behind

            Rectangle {
                id: slip

                required property int index
                readonly property int depth: slip.index + 1

                x: frontCard.x + Theme.dp(12) * slip.depth + frontCard.tx
                y: frontCard.y - stack.peek * slip.depth
                z: -slip.depth
                width: frontCard.width - Theme.dp(24) * slip.depth
                height: Theme.dp(40)
                radius: stack.cardRadius
                color: Theme.alpha(Theme.surfaceHigh, 1 - 0.18 * slip.depth)
                opacity: frontCard.opacity

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: stack.peek
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stack.bringForward(slip.depth)
                }

            }

        }

        HoverHandler {
            id: fieldHover
        }

        ShotCard {
            id: frontCard

            property real tx: stack.slide * (stack.cardW + stack.margin * 2)

            stack: stack
            entry: stack.front
            x: stack.margin
            y: stack.height - stack.margin - frontCard.height
            visible: stack.shownNow || stack.leaving

            transform: Translate {
                x: frontCard.tx
            }

        }

    }

    NumberAnimation {
        id: slideIn

        target: stack
        property: "slide"
        from: 1
        to: 0
        duration: Theme.durEnter
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedDecel
    }

    SequentialAnimation {
        id: swapIn

        NumberAnimation {
            target: frontCard
            property: "opacity"
            to: 0.4
            duration: Theme.durFastEffects / 2
        }

        NumberAnimation {
            target: frontCard
            property: "opacity"
            to: 1
            duration: Theme.durFastEffects
        }

    }

    SequentialAnimation {
        id: exitAnim

        ParallelAnimation {
            NumberAnimation {
                target: stack
                property: "slide"
                to: 1
                duration: Theme.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedAccel
            }

            NumberAnimation {
                target: frontCard
                property: "opacity"
                to: 0
                duration: Theme.durExit
                easing.type: Easing.InCubic
            }

        }

        ScriptAction {
            script: {
                stack.entries = [];
                stack.leaving = false;
                stack.slide = 0;
                frontCard.opacity = 1;
            }
        }

    }

    Process {
        id: probes

        property var queue: []
        property var current: null

        function next() {
            if (probes.running || probes.queue.length === 0)
                return ;

            probes.current = probes.queue[0];
            probes.queue = probes.queue.slice(1);
            const c = probes.current;
            // a frame from half a second in for a recording's card: the first is often black
            probes.command = ["sh", "-c", "f=\"$1\"; k=\"$2\"; d=\"$3\"; s=$(stat -c %s \"$f\" 2>/dev/null || echo 0); " + "if [ \"$k\" = video ] || [ \"$k\" = gif ]; then " + "set -- $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height:format=duration -of csv=p=0 \"$f\" 2>/dev/null | tr ',\\n' '  '); " + "t=''; if [ \"$k\" = video ]; then mkdir -p \"$d\"; t=\"$d/frame-$(date +%s%N).jpg\"; " + "ffmpeg -v error -y -ss 0.5 -i \"$f\" -frames:v 1 -vf scale=720:-2 \"$t\" </dev/null || ffmpeg -v error -y -i \"$f\" -frames:v 1 -vf scale=720:-2 \"$t\" </dev/null || t=''; fi; " + "printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$s\" \"${1:-0}\" \"${2:-0}\" \"${3:-0}\" \"$t\"; else printf '%s\\n' \"$s\"; fi", "sh", c.file, c.kind, (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-shot"];
            probes.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const c = probes.current;
                if (!c)
                    return ;

                const f = this.text.trim().split("\t");
                const change = {
                    "bytes": parseInt(f[0]) || 0
                };
                if (f.length >= 4) {
                    if (parseInt(f[1]) > 0)
                        change.w = parseInt(f[1]);

                    if (parseInt(f[2]) > 0)
                        change.h = parseInt(f[2]);

                    change.duration = parseFloat(f[3]) || 0;
                    if (f[4])
                        change.thumb = f[4];

                }
                stack.patch(c.id, change);
            }
        }

        onExited: Qt.callLater(probes.next)
    }

    Connections {
        function onTextRead(r) {
            const ask = stack.reads[r.id];
            if (!ask)
                return ;

            const left = Object.assign({
            }, stack.reads);
            delete left[r.id];
            stack.reads = left;
            if (r.status === "ok")
                stack.show({
                "id": r.id,
                "kind": "text",
                "text": r.text,
                "codes": r.codes,
                "thumb": ask.thumb,
                "screen": ask.screen,
                "w": 16,
                "h": 9
            });

        }

        function onGifMade(r) {
            const src = r.id.replace(/-gif$/, "");
            stack.patch(src, {
                "busy": false
            });
            if (r.ok)
                stack.show({
                "id": r.id,
                "kind": "gif",
                "file": r.file,
                "screen": stack.front ? stack.front.screen : ""
            });

        }

        target: stack.engine
    }

}
