import QtQuick
import QtQuick.Shapes
import qs
import qs.lucidui

// a bar in edit mode: an outline round every module, a stand-in for one switched
// on with nothing to show right now, a clasp between neighbours that joins or
// parts them, and the grips that carry a module along the bar or pull it off.
// a press that does not move still reaches the module, so it opens as usual
Item {
    id: edit

    property var host: null

    readonly property real t: edit.host ? edit.host.editT : 0
    readonly property int stripH: Theme.dp(Prefs.barHeight)
    // how far below the bar a module has to be pulled before letting go takes it off
    readonly property real pullOff: edit.stripH * 1.2
    readonly property string screenName: edit.host && edit.host.screen ? edit.host.screen.name : ""
    readonly property bool live: edit.t > 0.001 || edit.held !== "" || edit.leaving !== "" || (!!edit.host && edit.host.dragKey !== "")

    // the module in hand: where on it the pointer took it, and the arrangement it came from
    property string held: ""
    property real grabDx: 0
    property real grabY: 0
    property real heldWidth: 0
    property var startGroups: null
    // every place it could land, {groups, x}, and the one it is over
    property var landings: []
    property int landing: -1
    // pulled off the bar: let go, it leaves
    property bool pulling: false
    // a stand-in on its way out, and how much of it is left
    property string leaving: ""
    property real leave: 0

    // a stand-in's width: its glyph, its name and the pill's padding
    readonly property var ghostWidths: {
        void ghostMetrics.font;
        const out = ({});
        for (const m of Prefs.barModules)
            out[m.id] = Math.ceil(ghostMetrics.advanceWidth(m.name)) + Theme.dp(16) + Theme.dp(6) + Theme.dp(14) * 2;
        return out;
    }
    // neighbours whose meeting a clasp joins, both in the bar with something to show
    readonly property var pairs: {
        const b = edit.host;
        if (!b || Prefs.barFull || edit.t <= 0.001)
            return [];

        const out = [];
        for (const zone of Prefs.barZones) {
            const keys = b.zoneKeys(zone);
            for (let i = 0; i + 1 < keys.length; i++) {
                if (b.realWidthOf(keys[i]) > 0.5 && b.realWidthOf(keys[i + 1]) > 0.5)
                    out.push({
                    "a": keys[i],
                    "b": keys[i + 1]
                });

            }
        }
        return out;
    }

    function ghostWidthOf(key) {
        const b = edit.host;
        const mod = b ? b.pillFor[key] : null;
        if (!mod)
            return 0;

        const w = edit.ghostWidths[key] || 0;
        if (key === edit.leaving)
            return w * edit.leave;

        if (edit.t <= 0.001 || mod.shown || !Prefs.barHas(key))
            return 0;

        return w * edit.t;
    }

    function copyGroups(g) {
        return {
            "left": g.left.slice(),
            "center": g.center.slice(),
            "right": g.right.slice()
        };
    }

    function sameGroups(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    // where key's pill would start with the bar arranged as g, worked out the way
    // the bar places its three groups
    function slotIn(g, key) {
        const b = edit.host;
        const keysOf = (side) => {
            return g[side].filter((id) => {
                return Prefs.barShown(id);
            });
        };
        const widthsOf = (keys) => {
            return keys.map((id) => {
                return id === key ? edit.heldWidth : b.widthOf(id);
            });
        };
        const lk = keysOf("left");
        const ck = keysOf("center");
        const rk = keysOf("right");
        const lw = widthsOf(lk);
        const cw = widthsOf(ck);
        const rw = widthsOf(rk);
        const lp = b.placeGroup(lw, b.leftOriginX, lk);
        const lW = lp[lw.length] - b.leftOriginX;
        const cW = b.placeGroup(cw, 0, ck)[cw.length];
        const rW = b.placeGroup(rw, 0, rk)[rw.length];
        const rightX = b.width - rW - b.sideMargin;
        const centreX = Math.min(Math.max((b.width - cW) / 2, b.leftOriginX + lW + b.zoneGap), rightX - cW - b.zoneGap);
        if (lk.indexOf(key) >= 0)
            return lp[lk.indexOf(key)];

        if (ck.indexOf(key) >= 0)
            return b.placeGroup(cw, centreX, ck)[ck.indexOf(key)];

        return b.placeGroup(rw, rightX, rk)[rk.indexOf(key)];
    }

    // every slot the module could be put in, each with where it would sit there
    function plan(key) {
        const base = edit.copyGroups(edit.startGroups);
        for (const side of ["left", "center", "right"]) base[side] = base[side].filter((id) => {
            return id !== key;
        })
        const out = [];
        for (const side of ["left", "center", "right"]) {
            const shown = base[side].filter((id) => {
                return Prefs.barShown(id) && edit.host.widthOf(id) > 0.5;
            });
            for (let i = 0; i <= shown.length; i++) {
                const g = edit.copyGroups(base);
                const list = g[side];
                // in front of the shown module it lands before, so the ones switched
                // off keep their own places
                let at = list.length;
                if (i < shown.length)
                    at = list.indexOf(shown[i]);
                else if (shown.length > 0)
                    at = list.indexOf(shown[shown.length - 1]) + 1;
                list.splice(at, 0, key);
                out.push({
                    "groups": g,
                    "x": edit.slotIn(g, key)
                });
            }
        }
        return out;
    }

    function arrange(g) {
        // before the write, so the others ease across to make room
        Prefs.barReorderTick++;
        edit.host.dragGroups = g;
    }

    function begin(key, px, py) {
        const b = edit.host;
        if (!b || !Edit.active)
            return ;

        drop.stop();
        settle.stop();
        edit.held = key;
        edit.pulling = false;
        edit.grabDx = px - b.xOf(key);
        edit.grabY = py;
        edit.heldWidth = b.widthOf(key);
        edit.startGroups = edit.copyGroups(Prefs.barLayoutGroups);
        b.dragShift = 0;
        b.dragLift = 0;
        b.dragGroups = edit.copyGroups(edit.startGroups);
        b.dragKey = key;
        b.dragHeld = true;
        Edit.dragging = true;
        edit.landings = edit.plan(key);
        edit.landing = -1;
    }

    function move(px, py) {
        const key = edit.held;
        const b = edit.host;
        if (key === "" || !b)
            return ;

        const want = px - edit.grabDx;
        // scene y runs down the screen, and a bottom bar's modules come off upward
        const dy = Prefs.barBottom ? edit.grabY - py : py - edit.grabY;
        const pulling = dy > edit.pullOff;
        if (pulling !== edit.pulling) {
            edit.pulling = pulling;
            edit.landing = -1;
            // off the bar it would leave, so the slot it came from opens again
            if (pulling)
                edit.arrange(edit.copyGroups(edit.startGroups));

        }
        if (!pulling) {
            let best = -1;
            let bestD = Infinity;
            for (let i = 0; i < edit.landings.length; i++) {
                const d = Math.abs(edit.landings[i].x - want);
                if (d < bestD) {
                    bestD = d;
                    best = i;
                }
            }
            // a little stickiness, so it does not flick between two slots
            const cur = edit.landing >= 0 ? Math.abs(edit.landings[edit.landing].x - want) : Infinity;
            if (best >= 0 && best !== edit.landing && (edit.landing < 0 || cur - bestD > Theme.dp(10))) {
                edit.landing = best;
                if (!edit.sameGroups(edit.landings[best].groups, b.dragGroups))
                    edit.arrange(edit.landings[best].groups);

            }
        }
        b.dragShift = want - b.placeFor(key);
        // short of coming off, it gives a little, so it reads as loose
        b.dragLift = pulling ? dy : Math.max(0, Math.min(dy, edit.pullOff)) * 0.25;
    }

    function end() {
        const key = edit.held;
        const b = edit.host;
        if (key === "" || !b)
            return ;

        edit.held = "";
        b.dragHeld = false;
        Edit.dragging = false;
        if (edit.pulling) {
            edit.pulling = false;
            const mod = b.pillFor[key];
            // a stand-in has no pill of its own to empty, so it empties itself
            if (mod && !mod.shown) {
                edit.leave = 1;
                edit.leaving = key;
                leaveAnim.restart();
            }
            b.dragGroups = null;
            Prefs.setBarModuleShown(key, false);
            settle.restart();
            return ;
        }
        const g = b.dragGroups;
        const at = b.xOf(key);
        if (g && !edit.sameGroups(g, edit.startGroups))
            Prefs.setBarLayout(g);

        b.dragGroups = null;
        // from where it was let go into its slot
        b.dragShift = at - b.placeFor(key);
        drop.restart();
    }

    function cancel() {
        const key = edit.held;
        const b = edit.host;
        if (key === "" || !b)
            return ;

        edit.held = "";
        edit.pulling = false;
        b.dragHeld = false;
        Edit.dragging = false;
        const at = b.xOf(key);
        Prefs.barReorderTick++;
        b.dragGroups = null;
        b.dragShift = at - b.placeFor(key);
        drop.restart();
    }

    function inspect(key) {
        const b = edit.host;
        if (!b)
            return ;

        const mod = b.pillFor[key];
        const cx = b.xOf(key) + (mod && mod.width > 0.5 ? mod.width : edit.ghostWidthOf(key)) / 2;
        Edit.openSheet("module", key, Edit.sideFor(cx, b.width), edit.screenName);
    }

    anchors.fill: parent
    z: 150
    visible: edit.live

    FontMetrics {
        id: ghostMetrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabelLg
        font.weight: Font.Medium
    }

    ParallelAnimation {
        id: drop

        onRunningChanged: {
            if (!drop.running && edit.held === "" && edit.host)
                edit.host.dragKey = "";

        }

        NumberAnimation {
            target: edit.host
            property: "dragShift"
            to: 0
            duration: Theme.barMs(420)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: edit.host
            property: "dragLift"
            to: 0
            duration: Theme.barMs(420)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    // a module let go off the bar shrinks where it was dropped, then lets go of its place
    Timer {
        id: settle

        interval: Theme.barMs(600)
        onTriggered: {
            if (edit.held !== "" || !edit.host)
                return ;

            edit.host.dragKey = "";
            edit.host.dragShift = 0;
            edit.host.dragLift = 0;
        }
    }

    NumberAnimation {
        id: leaveAnim

        target: edit
        property: "leave"
        to: 0
        duration: Theme.barMs(360)
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveStandard
        onRunningChanged: {
            if (!leaveAnim.running)
                edit.leaving = "";

        }
    }

    // the marks exist only while edit mode is up, or while a module it let go of settles
    Loader {
        anchors.fill: parent
        active: edit.live

        sourceComponent: Item {
            Repeater {
                model: Prefs.barModules

                Item {
                    id: mark

                    required property var modelData
                    readonly property string key: mark.modelData.id
                    readonly property var mod: edit.host ? (edit.host.pillFor[mark.key] || null) : null
                    // its own width, not its slot's: the overview keeps its outline as it flies off
                    readonly property bool real: !!mark.mod && mark.mod.visible && mark.mod.width > 0.5
                    readonly property real ghostW: edit.ghostWidthOf(mark.key)
                    readonly property bool ghost: !mark.real && mark.ghostW > 0.5
                    readonly property bool open: !!mark.mod && (mark.mod.expanded === true || mark.mod.anyOpen === true)
                    // the overview, out in the middle of the screen: nothing to carry along the bar
                    readonly property bool flown: mark.key === "workspaces" && mark.open && !Prefs.barPopupMode
                    // opened in place, it is carried by the band where its pill was, as a window
                    // by its title bar; the rest of the panel keeps its own drags
                    readonly property bool inBand: hover.hovered && hover.point.position.y < edit.stripH
                    readonly property bool grabbable: mark.ghost || !mark.open || Prefs.barPopupMode || (!mark.flown && mark.inBand)
                    readonly property bool held: edit.held === mark.key
                    readonly property bool hot: hover.hovered || popHover.hovered || mark.held
                    readonly property real topL: mark.real && mark.mod.barTopLeftRadius !== undefined ? mark.mod.barTopLeftRadius : (Prefs.barFlush ? 0 : Prefs.barPillRadius)
                    readonly property real topR: mark.real && mark.mod.barTopRightRadius !== undefined ? mark.mod.barTopRightRadius : (Prefs.barFlush ? 0 : Prefs.barPillRadius)
                    readonly property real botL: mark.real && mark.mod.barBottomLeftRadius !== undefined ? mark.mod.barBottomLeftRadius : Prefs.barPillRadius
                    readonly property real botR: mark.real && mark.mod.barBottomRightRadius !== undefined ? mark.mod.barBottomRightRadius : Prefs.barPillRadius
                    // a notch's outline runs out along its edge blends and is left open
                    // along the screen's edges, as the dock's is. not once it is lifted off
                    readonly property bool notched: Prefs.barNotch && mark.real && !mark.flown && !!edit.host && !(edit.host.dragKey === mark.key && edit.host.dragLift > 0.5)
                    readonly property real line: mark.hot ? 2 : 1
                    readonly property var notchPaths: mark.notched ? mark.notchOutline() : ({
                        "open": "",
                        "closed": ""
                    })

                    // the outline half a line inside the edge, in the mark's own frame: down
                    // a side from its top blend (or the screen side's curve), along the
                    // bottom, and up the other side. closed along the screen's edges for the fill
                    function notchOutline() {
                        const d = mark.line / 2;
                        const w = mark.width;
                        const h = mark.height;
                        const fl = edit.host.notchFlareOf(mark.mod, true);
                        const fr = edit.host.notchFlareOf(mark.mod, false);
                        // a blend can sweep out further than it reaches down: a quarter ellipse
                        const dl = edit.host.notchDepthOf(mark.mod, true);
                        const dr = edit.host.notchDepthOf(mark.mod, false);
                        const meets = edit.host.hangPlan.meets[mark.key] || ({});
                        const bl = Math.max(mark.botL, d);
                        const br = Math.max(mark.botR, d);
                        const arc = (rx, ry, sweep, x, y) => {
                            return " A" + rx + "," + ry + " 0 0 " + sweep + " " + x + "," + y;
                        };
                        // how far across from its centre an ellipse reaches at the height y
                        const across = (rx, ry, cy, y) => {
                            return rx * Math.sqrt(Math.max(0, 1 - Math.pow((cy - y) / ry, 2)));
                        };
                        let p = "";
                        let sx = d;
                        let ex = w - d;
                        if (meets.left) {
                            const r = meets.left.size + d;
                            const cx = meets.left.size - mark.x;
                            const cy = meets.left.y - mark.y + meets.left.size;
                            sx = cx - r;
                            p += "M" + sx + "," + cy + arc(r, r, 1, cx, cy - r);
                        } else {
                            if (fl > 0 && dl > 0) {
                                // a blend deeper than the straight side is met where the corner starts
                                const rx = fl + d;
                                const ry = dl + d;
                                const yj = Math.min(dl, h - bl);
                                sx = -fl;
                                p += "M" + sx + "," + (-d) + arc(rx, ry, 1, -fl + across(rx, ry, dl, yj), yj);
                            } else {
                                p += "M" + d + "," + (-d);
                            }
                            p += " L" + d + "," + (h - bl) + (bl > d ? arc(bl - d, bl - d, 0, bl, h - d) : "");
                        }
                        if (meets.right) {
                            const r = meets.right.size + d;
                            const cx = edit.host.width - meets.right.size - mark.x;
                            const cy = meets.right.y - mark.y + meets.right.size;
                            ex = cx + r;
                            p += " L" + cx + "," + (cy - r) + arc(r, r, 1, ex, cy);
                        } else {
                            p += " L" + (w - br) + "," + (h - d) + (br > d ? arc(br - d, br - d, 0, w - d, h - br) : "");
                            if (fr > 0 && dr > 0) {
                                const rx = fr + d;
                                const ry = dr + d;
                                const yj = Math.min(dr, h - br);
                                ex = w + fr;
                                p += " L" + (w - d) + "," + yj + " L" + (w + fr - across(rx, ry, dr, yj)) + "," + yj + arc(rx, ry, 1, ex, -d);
                            } else {
                                p += " L" + (w - d) + "," + (-d);
                            }
                        }
                        return {
                            "open": p,
                            "closed": p + " L" + ex + "," + (-d) + " L" + sx + "," + (-d) + " Z"
                        };
                    }

                    // the surface as drawn, so the outline morphs with a module opening in place
                    x: mark.real ? mark.mod.x + (mark.mod.surfaceX !== undefined ? mark.mod.surfaceX : 0) : (edit.host ? edit.host.xOf(mark.key) : 0)
                    y: mark.real ? mark.mod.y + (mark.mod.surfaceY !== undefined ? mark.mod.surfaceY : 0) : (edit.host ? edit.host.rowY + edit.host.liftOf(mark.key) : 0)
                    width: mark.real ? (mark.mod.surfaceWidth !== undefined ? mark.mod.surfaceWidth : mark.mod.width) : mark.ghostW
                    height: mark.real ? (mark.mod.surfaceHeight !== undefined ? mark.mod.surfaceHeight : mark.mod.height) : edit.stripH
                    visible: mark.real || mark.ghost
                    z: mark.held ? 2 : 1

                    // a stand-in: the module's glyph and name in a dashed slot of its own
                    Item {
                        anchors.fill: parent
                        visible: mark.ghost
                        opacity: edit.t

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.min(height / 2, Prefs.barPillRadius)
                            topLeftRadius: Prefs.barFlush ? 0 : radius
                            topRightRadius: Prefs.barFlush ? 0 : radius
                            color: Theme.alpha(Theme.bg, Theme.bg.a * (mark.hot ? 0.9 : 0.55))

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durShort
                                }

                            }

                        }

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: edit.pulling && mark.held ? Theme.error : Theme.alpha(mark.hot ? Theme.accent : Theme.text, mark.hot ? 0.9 : 0.38)
                                strokeWidth: 1
                                strokeStyle: ShapePath.DashLine
                                dashPattern: [3, 3]

                                PathRectangle {
                                    x: 0.5
                                    y: 0.5
                                    width: mark.width - 1
                                    height: mark.height - 1
                                    radius: Math.min(mark.height / 2, Prefs.barPillRadius)
                                    topLeftRadius: Prefs.barFlush ? 0 : Math.min(mark.height / 2, Prefs.barPillRadius)
                                    topRightRadius: Prefs.barFlush ? 0 : Math.min(mark.height / 2, Prefs.barPillRadius)
                                }

                            }

                        }

                        Row {
                            id: ghostRow

                            anchors.centerIn: parent
                            spacing: Theme.dp(6)
                            visible: mark.width > ghostName.implicitWidth + Theme.dp(26)

                            // the bar is mirrored on the bottom edge; the words stand upright
                            transform: Scale {
                                origin.y: ghostRow.height / 2
                                yScale: Prefs.barBottom ? -1 : 1
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: mark.modelData.icon || "widgets"
                                size: Theme.dp(16)
                                color: mark.hot ? Theme.accent : Theme.subtext
                            }

                            Text {
                                id: ghostName

                                anchors.verticalCenter: parent.verticalCenter
                                text: mark.modelData.name
                                color: mark.hot ? Theme.text : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabelLg
                                font.weight: Font.Medium
                            }

                        }

                    }

                    // an outline along the pill's own edge, inside it: outside, the bar's
                    // window edge cut its top off and it ran into the neighbours
                    Rectangle {
                        visible: mark.real && !mark.notched
                        anchors.fill: parent
                        topLeftRadius: mark.topL
                        topRightRadius: mark.topR
                        bottomLeftRadius: mark.botL
                        bottomRightRadius: mark.botR
                        color: edit.pulling && mark.held ? Theme.alpha(Theme.error, 0.14) : (mark.hot && !mark.open ? Theme.alpha(Theme.accent, 0.08) : "transparent")
                        border.width: mark.line
                        border.color: edit.pulling && mark.held ? Theme.error : Theme.alpha(Theme.accent, mark.hot ? 1 : 0.55)
                        opacity: edit.t

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    Shape {
                        visible: mark.notched
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        opacity: edit.t

                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: mark.hot && !mark.open ? Theme.alpha(Theme.accent, 0.08) : "transparent"

                            Behavior on fillColor {
                                ColorAnimation {
                                    duration: Theme.durShort
                                }

                            }

                            PathSvg {
                                path: mark.notchPaths.closed
                            }

                        }

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Theme.alpha(Theme.accent, mark.hot ? 1 : 0.55)
                            strokeWidth: mark.line
                            capStyle: ShapePath.FlatCap
                            joinStyle: ShapePath.RoundJoin

                            PathSvg {
                                path: mark.notchPaths.open
                            }

                        }

                    }

                    // a pop-up gets its own outline, which grows and goes with it
                    Item {
                        id: popMark

                        readonly property var pop: mark.real && mark.mod.popupOpen === true ? (mark.mod.popupItem || null) : null
                        // a pop-up bent by jelly reports where it is painted
                        readonly property bool painted: popMark.pop !== null && mark.mod.popupPaintX !== undefined

                        x: popMark.pop ? mark.mod.x + (popMark.painted ? mark.mod.popupPaintX : popMark.pop.x) - mark.x : 0
                        y: popMark.pop ? mark.mod.y + (popMark.painted ? mark.mod.popupPaintY : popMark.pop.y) - mark.y : 0
                        width: popMark.pop ? (popMark.painted ? mark.mod.popupPaintWidth : popMark.pop.width) : 0
                        height: popMark.pop ? (popMark.painted ? mark.mod.popupPaintHeight : popMark.pop.height) : 0
                        visible: popMark.pop !== null

                        Rectangle {
                            anchors.fill: parent
                            topLeftRadius: popMark.pop ? popMark.pop.topLeftRadius : 0
                            topRightRadius: popMark.pop ? popMark.pop.topRightRadius : 0
                            bottomLeftRadius: popMark.pop ? popMark.pop.bottomLeftRadius : 0
                            bottomRightRadius: popMark.pop ? popMark.pop.bottomRightRadius : 0
                            color: "transparent"
                            border.width: mark.hot ? 2 : 1
                            border.color: Theme.alpha(Theme.accent, mark.hot ? 1 : 0.55)
                            opacity: edit.t
                        }

                        HoverHandler {
                            id: popHover

                            enabled: Edit.active
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: Edit.active && edit.held === ""
                            acceptedButtons: Qt.RightButton
                            onClicked: edit.inspect(mark.key)
                        }

                    }

                    // pulled far enough down to come off
                    Rectangle {
                        id: offChip

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + Theme.dp(10)
                        width: offRow.implicitWidth + Theme.dp(24)
                        height: Theme.dp(30)
                        radius: height / 2
                        color: Theme.errorContainer
                        opacity: edit.pulling && mark.held ? 1 : 0
                        scale: edit.pulling && mark.held ? 1 : 0.85
                        visible: opacity > 0.01

                        Row {
                            id: offRow

                            anchors.centerIn: parent
                            spacing: Theme.dp(6)

                            // the bar is mirrored on the bottom edge; the words stand upright
                            transform: Scale {
                                origin.y: offRow.height / 2
                                yScale: Prefs.barBottom ? -1 : 1
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "delete"
                                size: Theme.dp(16)
                                color: Theme.fgErrorContainer
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Let go to take it off the bar"
                                color: Theme.fgErrorContainer
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabelLg
                                font.weight: Font.Medium
                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.OutBack
                            }

                        }

                    }

                    // over an open panel's content the cursor is left to the content
                    HoverHandler {
                        id: hover

                        enabled: Edit.active
                        cursorShape: mark.held ? Qt.ClosedHandCursor : (mark.grabbable ? Qt.OpenHandCursor : undefined)
                    }

                    // the right button opens the module's sheet, and only here: the module
                    // underneath never hears it
                    MouseArea {
                        anchors.fill: parent
                        enabled: Edit.active && edit.held === ""
                        acceptedButtons: Qt.RightButton
                        onClicked: edit.inspect(mark.key)
                    }

                    // a stand-in has nothing to open, so a click asks for its sheet instead
                    TapHandler {
                        enabled: Edit.active && mark.ghost
                        acceptedButtons: Qt.LeftButton
                        onTapped: edit.inspect(mark.key)
                    }

                    // lent to the module itself: a handler on an item above it would swallow
                    // every press, so a click never opened it. as its own, a press that never
                    // moves still reaches the module, and once it moves the drag is ours
                    HeldPointer {
                        held: dragger.active
                        cursor: Qt.ClosedHandCursor
                    }

                    DragHandler {
                        id: dragger

                        parent: mark.real ? mark.mod : mark
                        target: null
                        enabled: Edit.active && (edit.held === "" || mark.held) && (dragger.active || mark.grabbable)
                        acceptedButtons: Qt.LeftButton
                        onActiveChanged: {
                            if (dragger.active)
                                edit.begin(mark.key, dragger.centroid.scenePressPosition.x, dragger.centroid.scenePressPosition.y);
                            else
                                edit.end();
                        }
                        onCentroidChanged: {
                            if (dragger.active)
                                edit.move(dragger.centroid.scenePosition.x, dragger.centroid.scenePosition.y);

                        }
                        onCanceled: edit.cancel()
                    }

                    Behavior on x {
                        enabled: mark.ghost && !mark.held && !!edit.host && edit.host.shuffling

                        NumberAnimation {
                            duration: Theme.barDurEnter
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                }

            }

            // a clasp where two neighbours meet: it joins them into one island, or parts them
            Repeater {
                model: edit.pairs

                Item {
                    id: clasp

                    required property var modelData
                    readonly property var ma: edit.host ? edit.host.pillFor[clasp.modelData.a] : null
                    readonly property var mb: edit.host ? edit.host.pillFor[clasp.modelData.b] : null
                    readonly property bool joined: Prefs.barJoined(clasp.modelData.a, clasp.modelData.b)

                    x: clasp.ma && clasp.mb ? Math.round((clasp.ma.x + clasp.ma.width + clasp.mb.x) / 2 - width / 2) : 0
                    y: clasp.ma ? Math.round(clasp.ma.y + (edit.stripH - height) / 2) : 0
                    width: Theme.dp(20)
                    height: Theme.dp(20)
                    z: 3
                    visible: !!clasp.ma && !!clasp.mb
                    opacity: edit.t * (edit.held === "" && edit.host && edit.host.dragKey === "" ? 1 : 0)

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: clasp.joined ? Theme.accent : Theme.alpha(Theme.bg, Math.max(Theme.bg.a, 0.85))
                        border.width: clasp.joined ? 0 : 1
                        border.color: Theme.alpha(Theme.accent, claspArea.containsMouse ? 1 : 0.55)
                        scale: claspArea.pressed ? 0.92 : (claspArea.containsMouse ? 1.12 : 1)

                        Icon {
                            anchors.centerIn: parent
                            name: "link"
                            size: Theme.dp(14)
                            color: clasp.joined ? Theme.fgAccent : (claspArea.containsMouse ? Theme.accent : Theme.subtext)
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.OutBack
                            }

                        }

                    }

                    // takes the press outright: the two modules under its edges never hear it
                    MouseArea {
                        id: claspArea

                        anchors.fill: parent
                        enabled: Edit.active
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: Prefs.setBarJoined(clasp.modelData.a, clasp.modelData.b, !clasp.joined)
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

            }

        }

    }

}
