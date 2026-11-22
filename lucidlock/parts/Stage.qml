import QtQuick
import QtQuick.Window
import "Catalog.js" as Catalog

// everything on a lock screen that is not the backdrop: the preset's slots
// filled with the user's widgets, and the sign-in wherever that preset keeps
// it. the lock, the login screen and the settings' preview all draw this one
// file, each handing it their own theme, data and sign-in
Item {
    id: st

    property var theme: null
    property var lock: null
    // Catalog.build()'s output
    property var layout: Catalog.build("", "", "", ({}))
    // widgets only the host can draw, by type: media, notifications, agenda
    property var extra: ({})
    // the sign-in, from the host
    property Component auth: null
    property bool greeter: false
    property bool preview: false
    property bool editing: false
    // what the editor has picked: a widget type, or "auth"
    property string selected: ""
    // only the main screen carries the sign-in; the rest get the time
    property bool primary: true
    // the arrival, linear in time so each block eases a slice of its own
    property real t: 1
    // the share of the arrival the blocks wait out first
    property real lead: 0
    // 0 resting .. 1 a password being typed
    property real focusK: 0
    property bool glanceLive: true
    // the preview's scale, so the editor's lines stay a pixel or two wide
    property real chromeScale: 1

    signal picked(string type)
    signal slotPicked(string slot)
    // the editor's drag and drop: a widget let go over a slot, at an index
    // counted without it, and the pointer wherever a drag is
    signal dropped(string type, string slot, int index)
    signal dragMoved(string type, point at)
    // after a layout change: every Flip measures where its thing landed
    signal measured(bool animate)

    // ── motion ─────────────────────────────────────────────────────────────
    // where each thing on the stage was last laid out, by key. a change that
    // moves one makes it glide from here (Flip.qml)
    property var memo: ({})
    property int settling: 0
    property bool settleAnimate: false
    property bool arrived: false
    readonly property bool flipOk: st.arrived && (!st.theme || st.theme.motionScale > 0)
    // 0..1, the editor's chrome fading in and out
    property real editK: st.editing ? 1 : 0

    // measure on the next few frames, after layout and before drawing, so a
    // glide starts from the old place on the very first frame of the new one
    function relayout(animate) {
        if (animate)
            st.settleAnimate = true;

        st.settling = 4;
        var w = st.Window.window;
        if (w)
            w.requestUpdate();

    }

    // ── drag and drop, in the editor ───────────────────────────────────────
    property string dragType: ""
    // the slot it came from, "" from outside the stage
    property string dragFrom: ""
    // {slot, index} where it would land now, or null
    property var dragTarget: null
    property point dragPoint: Qt.point(0, 0)
    // where the pointer holds it, from its top left
    property point dragGrab: Qt.point(0, 0)
    property size dragSize: Qt.size(0, 0)
    // the ghost under the pointer draws the widget itself; a drag from outside
    // the stage brings its own
    property string ghostType: ""
    property var ghostSlot: null
    property real ghostLift: 0
    // it swings round the point it is held by, as fast as it is carried, and
    // a spring brings it level once the pointer rests
    property real ghostTilt: 0
    property point dragLast: Qt.point(0, 0)
    property real dragLastAt: 0
    // for a drop on no slot: the host decides (true when it took the widget)
    property var dropOutside: null
    // slots on screen, for finding the one under the pointer
    property var slotItems: []

    function registerSlot(s) {
        if (st.slotItems.indexOf(s) === -1)
            st.slotItems.push(s);

    }

    function unregisterSlot(s) {
        var i = st.slotItems.indexOf(s);
        if (i !== -1)
            st.slotItems.splice(i, 1);

    }

    function slotFor(id) {
        for (var i = 0; i < st.slotItems.length; i++) {
            if (st.slotItems[i].slotId === id)
                return st.slotItems[i];

        }
        return null;
    }

    // the slot under a point, and the place in it, counted without the dragged one
    function targetAt(p) {
        var best = null, bestArea = 1e+12;
        for (var i = 0; i < st.slotItems.length; i++) {
            var s = st.slotItems[i];
            if (!s.visible || s.width <= 0)
                continue;

            var o = s.mapToItem(st, 0, 0);
            var pad = s.ring + st.dp(14) / st.chromeScale;
            if (p.x < o.x - pad || p.x > o.x + s.width + pad || p.y < o.y - pad || p.y > o.y + s.height + pad)
                continue;

            var area = (s.width + pad * 2) * (s.height + pad * 2);
            if (area < bestArea) {
                best = s;
                bestArea = area;
            }
        }
        return best ? ({
            "slot": best.slotId,
            "index": best.indexAt(p)
        }) : null;
    }

    function beginDrag(type, from, grab, size, external) {
        var s = st.slotFor(from);
        st.dragType = type;
        st.dragFrom = from;
        st.dragGrab = grab;
        st.dragSize = size;
        st.dragTarget = from !== "" ? ({
            "slot": from,
            "index": s ? s.indexOf(type) : 0
        }) : null;
        st.ghostSlot = s ? ({
            "stage": st,
            "slotId": "",
            "align": s.align,
            "maxWidth": s.maxWidth,
            "maxHeight": s.maxHeight,
            "cards": s.cards,
            "shrinkTo": 1
        }) : null;
        st.ghostType = external ? "" : type;
        st.ghostTilt = 0;
        st.dragLastAt = 0;
        ghostIn.restart();
        st.relayout(true);
    }

    function moveDrag(p) {
        if (st.dragType === "")
            return ;

        var now = Date.now();
        var dt = Math.max(8, now - st.dragLastAt);
        if (st.dragLastAt > 0 && p.x > -10000) {
            var vx = (p.x - st.dragLast.x) / dt;
            st.ghostTilt = Math.max(-9, Math.min(9, vx * 3.2));
            levelOut.restart();
        }
        st.dragLast = p;
        st.dragLastAt = now;
        st.dragPoint = p;
        var t = st.targetAt(p);
        var same = (!t && !st.dragTarget) || (t && st.dragTarget && t.slot === st.dragTarget.slot && t.index === st.dragTarget.index);
        if (!same) {
            st.dragTarget = t;
            st.relayout(true);
        }
        st.dragMoved(st.dragType, p);
    }

    function endDrag(p) {
        if (st.dragType === "")
            return ;

        var type = st.dragType, t = st.dragTarget;
        st.dragPoint = p;
        // the widget lands from where the ghost is drawn
        st.memo[type] = {
            "x": p.x - st.dragGrab.x,
            "y": p.y - st.dragGrab.y,
            "w": st.dragSize.width,
            "h": st.dragSize.height,
            "land": true
        };
        var taken = !t && st.dropOutside ? st.dropOutside(type, p) : false;
        if (taken) {
            ghostOut.restart();
        } else {
            ghostIn.stop();
            st.ghostLift = 0;
            st.ghostType = "";
        }
        st.dragType = "";
        st.dragFrom = "";
        st.dragTarget = null;
        if (t)
            st.dropped(type, t.slot, t.index);

        st.relayout(true);
    }

    function cancelDrag() {
        if (st.dragType === "")
            return ;

        st.endDrag(Qt.point(st.dragPoint.x, st.dragPoint.y));
    }

    readonly property string preset: st.layout ? st.layout.preset : Catalog.defaultPreset
    readonly property int pad: Math.round(Math.max(st.dp(36), Math.min(st.dp(76), st.height * 0.062)))
    // every widget's options, resolved once per layout
    readonly property var resolved: {
        var out = {};
        for (var i = 0; i < Catalog.widgets.length; i++) {
            var w = Catalog.widgets[i];
            var o = {
                "style": Catalog.opt(st.layout, w.id, "style"),
                "size": Catalog.opt(st.layout, w.id, "size")
            };
            var list = w.options || [];
            for (var j = 0; j < list.length; j++)
                o[list[j].key] = Catalog.opt(st.layout, w.id, list[j].key);
            out[w.id] = o;
        }
        return out;
    }
    readonly property var builtins: ({
        "clock": clockC,
        "date": dateC,
        "greeting": greetingC,
        "weather": weatherC,
        "status": statusC,
        "power": powerC,
        "message": messageC
    })

    function dp(px) {
        return st.theme ? st.theme.dp(px) : px;
    }

    // a long tail, so a block lands rather than stops
    function ease(x) {
        var c = Math.max(0, Math.min(1, x));
        return 1 - Math.pow(1 - c, 5);
    }

    function rv(delay) {
        var d = st.lead + delay * (1 - st.lead);
        return st.ease((st.t - d) / Math.max(0.05, 1 - d));
    }

    function componentFor(type) {
        return st.builtins[type] || (st.extra ? st.extra[type] : null) || null;
    }

    // the editor keeps what this screen cannot show, as stand-ins. while a
    // widget is dragged, the slot under it opens a space where it would land
    // and the others move aside; the one it left keeps it, folded, so the
    // pointer's grab survives the move
    function typesOf(slot) {
        var list = st.layout && st.layout.slots ? (st.layout.slots[slot] || []) : [];
        if (!st.editing)
            return list.filter((x) => {
                return Catalog.shownOn(x, st.greeter) && st.componentFor(x) !== null;
            });

        var t = st.dragTarget;
        if (st.dragType === "" || !t || t.slot !== slot)
            return list;

        var others = list.filter((x) => {
            return x !== st.dragType;
        });
        others.splice(Math.max(0, Math.min(t.index, others.length)), 0, slot === st.dragFrom ? st.dragType : "__drop__");
        return others;
    }

    function optsOf(type) {
        return st.resolved[type] || ({});
    }

    function presetOpt(key) {
        return Catalog.presetOpt(st.layout, key);
    }

    // a catalogue word in the lock's language: the shell's lock translates,
    // the login screen's gives it back as it is
    function tr(text) {
        return st.lock && st.lock.tr ? st.lock.tr(text) : text; // i18n-dynamic
    }

    // the sign-in, wherever the preset keeps it
    function focusInput() {
        if (face.item && face.item.authHost)
            face.item.authHost.focusInput();

    }

    function discard() {
        if (face.item && face.item.authHost)
            face.item.authHost.discard();

    }

    // where the sign-in sits, for the on-screen keyboard to keep it in sight
    function authRect() {
        var a = face.item ? face.item.authHost : null;
        return a ? a.mapToItem(st, 0, 0, a.width, a.height) : null;
    }

    Component {
        id: clockC

        Clock {
        }

    }

    Component {
        id: dateC

        DateLine {
        }

    }

    Component {
        id: greetingC

        Greeting {
        }

    }

    Component {
        id: weatherC

        Weather {
        }

    }

    Component {
        id: statusC

        Status {
        }

    }

    Component {
        id: powerC

        Power {
        }

    }

    Component {
        id: messageC

        Message {
        }

    }

    onLayoutChanged: st.relayout(true)
    onGreeterChanged: st.relayout(true)
    onEditingChanged: st.relayout(true)
    onWidthChanged: st.relayout(false)
    onHeightChanged: st.relayout(false)
    // once the arrival is over, and whenever a face settles, the memo is
    // brought up to date without moving anything
    onTChanged: {
        if (!st.arrived && st.t >= 0.999) {
            st.arrived = true;
            st.relayout(false);
        }
    }
    onFocusKChanged: {
        if (st.focusK <= 0 || st.focusK >= 1)
            st.relayout(false);

    }

    Behavior on editK {
        NumberAnimation {
            duration: st.theme ? st.theme.ms(260) : 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: st.theme ? st.theme.curveEffects : [0.31, 0.94, 0.34, 1, 1, 1]
        }

    }

    Connections {
        function onAfterAnimating() {
            var animate = st.settleAnimate;
            st.measured(animate);
            st.settling -= 1;
            if (st.settling <= 0)
                st.settleAnimate = false;

        }

        target: st.settling > 0 ? st.Window.window : null
        ignoreUnknownSignals: true
    }

    Loader {
        id: face

        anchors.fill: parent
        sourceComponent: {
            if (!st.primary)
                return otherC;

            switch (st.preset) {
            case "split":
                return splitC;
            case "panel":
                return panelC;
            case "minimal":
                return minimalC;
            case "bento":
                return bentoC;
            case "deck":
                return deckC;
            }
            return centreC;
        }
    }

    // ── the ghost: the dragged widget itself, lifted, under the pointer ─────
    Item {
        id: ghostBox

        x: st.dragPoint.x - st.dragGrab.x
        y: st.dragPoint.y - st.dragGrab.y
        width: st.dragSize.width
        height: st.dragSize.height
        z: 1000
        visible: st.ghostType !== "" && st.ghostSlot !== null
        // lifted on the way up (0..1); below zero it is being taken away
        opacity: st.ghostLift >= 0 ? 0.94 * Math.min(1, 0.4 + st.ghostLift * 0.6) : Math.max(0, 0.94 * (1 + st.ghostLift / 2))
        scale: st.ghostLift >= 0 ? 1 + 0.04 * st.ghostLift : 1 + 0.2 * st.ghostLift
        transformOrigin: Item.Center

        transform: Rotation {
            origin.x: st.dragGrab.x
            origin.y: st.dragGrab.y
            angle: st.ghostTilt
        }

        // a tonal plate under it, so a widget lifted off the wallpaper reads
        // as carried
        Rectangle {
            readonly property real m: st.dp(12) / st.chromeScale

            x: -m
            y: -m
            width: ghostBox.width + m * 2
            height: ghostBox.height + m * 2
            radius: (st.theme ? st.theme.shapeXl : 24) + m
            color: st.theme ? st.theme.alpha(st.theme.cardHigh, 0.82) : "black"
            border.width: 1.5 / st.chromeScale
            border.color: st.theme ? st.theme.alpha(st.theme.accent, 0.55) : "white"
            opacity: Math.max(0, Math.min(1, st.ghostLift))
        }

        Loader {
            active: ghostBox.visible
            sourceComponent: WidgetHost {
                type: st.ghostType
                slot: st.ghostSlot
                ghost: true
            }
        }

    }

    // the pointer at rest: the ghost hangs level again
    Timer {
        id: levelOut

        interval: 90
        onTriggered: st.ghostTilt = 0
    }

    Behavior on ghostTilt {
        SpringAnimation {
            spring: 7
            damping: 0.38
            epsilon: 0.05
        }

    }

    NumberAnimation {
        id: ghostIn

        target: st
        property: "ghostLift"
        to: 1
        duration: st.theme ? st.theme.ms(300) : 300
        easing.type: Easing.BezierSpline
        easing.bezierCurve: st.theme ? st.theme.curveFastSpatial : [0.42, 1.67, 0.21, 0.9, 1, 1]
    }

    // taken away by the host: it shrinks into the drop and is gone
    SequentialAnimation {
        id: ghostOut

        NumberAnimation {
            target: st
            property: "ghostLift"
            to: -2
            duration: st.theme ? st.theme.ms(220) : 220
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: {
                st.ghostType = "";
                st.ghostLift = 0;
            }
        }

    }

    Component {
        id: centreC

        PresetCentre {
            stage: st
        }

    }

    Component {
        id: splitC

        PresetSplit {
            stage: st
        }

    }

    Component {
        id: panelC

        PresetPanel {
            stage: st
        }

    }

    Component {
        id: minimalC

        PresetMinimal {
            stage: st
        }

    }

    Component {
        id: bentoC

        PresetBento {
            stage: st
        }

    }

    Component {
        id: deckC

        PresetDeck {
            stage: st
        }

    }

    Component {
        id: otherC

        OtherScreen {
            stage: st
        }

    }

}
