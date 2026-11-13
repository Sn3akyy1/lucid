import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.lucidui

// everything the capture overlay draws and does: the frozen frame, the
// selection, the editor, the toolbar and the way out. the window around it
// only freezes the screen and holds the keyboard, so a rig can drive this whole
Item {
    id: stage

    // wired by the overlay
    property var engine: null
    property var cards: null
    property var pins: null
    property string screenName: ""
    // the display's place in the layout, for a capture taken live
    property real screenX: 0
    property real screenY: 0
    // the picture: the frozen screen, or a saved capture being marked up
    property url baseUrl: ""
    property string basePath: ""
    property size baseSize: Qt.size(0, 0)
    property bool editing: false
    // windows on the frozen screen, topmost first, in stage coordinates
    property var windows: []
    property real rounding: 0
    // "shot" | "record" | "text" | "colour"
    property string mode: "shot"
    // "region" | "window"; the whole screen is the shutter's, with nothing selected
    property string target: "region"
    // "idle" | "select" | "drag" | "adjust" | "mark" | "read" | "timer" | "fly"
    property string phase: "idle"
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    readonly property bool hasSel: stage.selW >= 2 && stage.selH >= 2
    // how the selection came about, and the window it is, if it is one
    property string selKind: "region"
    property var selWindow: null
    property real selRound: 0
    property int hoverWin: -1
    property real px: -1
    property real py: -1
    property bool pointerIn: false
    // the stage draws the pointer while the guides or a dragged corner follow
    // it: the compositor shows its own a frame or two before a window catches up
    readonly property bool aiming: input.containsMouse && !stage.editing && stage.mode !== "colour" && stage.target === "region" && (stage.phase === "select" || stage.phase === "drag")
    property bool spaceHeld: false
    property bool busy: false
    // options, kept between opens by the overlay
    property bool markup: false
    property int timer: 0
    property int countdown: 3
    property bool mic: false
    property bool system: true
    property string format: "hex"
    property var palette: []
    property string tool: "arrow"
    property int inkIndex: 0
    property int sizeIndex: 1
    readonly property var inks: [Theme.primary, "#ff5449", "#ffb300", "#2ecc71", "#4c8dff", "#ffffff", "#202124"]
    readonly property color ink: stage.inks[Math.max(0, Math.min(stage.inks.length - 1, stage.inkIndex))]
    readonly property bool canUndo: marks.canUndo
    readonly property bool canRedo: marks.canRedo
    readonly property bool cardsOn: stage.cards !== null && Prefs.shotPreview === "preview"
    // what the frame looks like where the picture sits, and how many of its
    // pixels go to one of ours
    readonly property rect baseRect: {
        if (!stage.editing)
            return Qt.rect(0, 0, stage.width, stage.height);

        const iw = stage.baseSize.width, ih = stage.baseSize.height;
        if (iw <= 0 || ih <= 0)
            return Qt.rect(stage.width / 2, stage.height / 2, 0, 0);

        const k = Math.min(1, (stage.width - Theme.dp(96)) / iw, (stage.height - Theme.dp(232)) / ih);
        const w = Math.round(iw * k), h = Math.round(ih * k);
        return Qt.rect(Math.round((stage.width - w) / 2), Math.round((stage.height - Theme.dp(88) - h) / 2), w, h);
    }
    // the dock's band along the bottom, or a bottom bar's, which the toolbar keeps well clear of
    readonly property real dockBand: Prefs.dockOn ? Theme.dp(Prefs.dockIconSize) + Theme.dp(20) + Prefs.effectiveDockBottomMargin : (Prefs.barEnabled && Prefs.barBottom ? Prefs.effectiveBarTopMargin + Theme.dp(Prefs.barHeight) : 0)
    readonly property real ratio: stage.baseRect.width > 0 && stage.baseSize.width > 0 ? stage.baseSize.width / stage.baseRect.width : 1
    readonly property size naturalSize: Qt.size(base.implicitWidth, base.implicitHeight)
    // the pixel under the pointer, read off the frame
    property color sample: "transparent"
    property int ticks: 0
    // the capture on its way out
    property var job: null
    property real flyX: 0
    property real flyY: 0
    property real flyW: 0
    property real flyH: 0
    property real flyR: 0
    // the phase a text read was started from, to go back to if it finds nothing
    property string readFrom: "select"
    property string readId: ""
    property bool hintFresh: false
    // the overlay is fading out
    property bool leaving: false
    // false until the window has a size to place the toolbar against. the first
    // open after a reload sizes it only as it maps, and the toolbar, placed
    // against no height at all, would come gliding down from above the screen.
    // a display of another height starts it over (ShotOverlay.prepare)
    property bool sized: false
    // drags
    property real anchorX: 0
    property real anchorY: 0
    property real lastX: 0
    property real lastY: 0
    property bool moving: false
    property real grabDX: 0
    property real grabDY: 0
    property string edge: ""
    property var edgeFrom: null
    readonly property var frameBounds: stage.editing ? stage.baseRect : Qt.rect(0, 0, stage.width, stage.height)
    readonly property bool passThrough: stage.phase === "timer" || stage.phase === "shooting"
    // what still takes a click while the rest lets the pointer through
    readonly property Item countdownItem: timerBadge
    readonly property string hint: {
        if (stage.editing)
            return "";

        switch (stage.phase) {
        case "select":
            if (stage.mode === "colour")
                return "Click to copy a colour  ·  Shift-click to collect a few";

            if (stage.target === "window")
                return "Click a window";

            return stage.mode === "record" ? "Drag over what to record, or click a window" : (stage.mode === "text" ? "Drag over the text, or click a window" : "Drag to select, or click a window");
        case "adjust":
            return "Drag the handles to adjust  ·  Enter starts recording";
        case "read":
            return "Reading the text…";
        }
        return "";
    }
    readonly property string fabTip: {
        if (stage.phase === "mark")
            return stage.editing ? "Save an edited copy (Enter)" : "Save and copy (Enter)";

        switch (stage.mode) {
        case "record":
            return stage.hasSel ? "Record the selection (Enter)" : "Record the whole screen (Enter)";
        case "text":
            return stage.hasSel ? "Copy the text in the selection" : "Copy all the text on the screen";
        case "colour":
            return "Copy every colour collected";
        }
        return (stage.timer > 0 ? "Take it in " + stage.timer + " s" : "Take it") + (stage.hasSel ? ", just the selection" : ", the whole screen") + " (Enter)";
    }

    signal closeRequested()
    // the capture has flown to its card, or been handed on: unmap now
    signal finished()
    signal notify(string icon, string text, bool warn)
    signal swatch(string hex, string text)
    signal settingsRequested()

    // a fresh start, every time the overlay opens
    function reset(mode, target) {
        stage.leaving = false;
        flyAnim.stop();
        cutTimer.stop();
        tickTimer.stop();
        stage.job = null;
        stage.busy = false;
        stage.moving = false;
        stage.edge = "";
        stage.spaceHeld = false;
        stage.palette = [];
        stage.sample = "transparent";
        stage.timer = 0;
        stage.readId = "";
        marks.clear();
        cut.visible = false;
        scene.opacity = 1;
        stage.mode = mode || "shot";
        if (target === "region" || target === "window")
            stage.target = target;

        stage.clearSel();
        stage.phase = stage.editing ? "mark" : "select";
        if (stage.editing) {
            const r = stage.baseRect;
            stage.setSel(r.x, r.y, r.width, r.height);
            stage.mode = "shot";
        }
        stage.hintFresh = true;
        hintTimer.restart();
        barIn.restart();
        if (stage.mode === "colour")
            sampler.prime();

        stage.forceActiveFocus();
    }

    function markSized() {
        stage.sized = stage.height > 0;
    }

    // dismissed: the overlay fades as a whole, the toolbar as one piece in it
    function leave() {
        stage.leaving = true;
    }

    // the overlay is gone: nothing waiting may act on it any more
    function park() {
        flyAnim.stop();
        cutTimer.stop();
        tickTimer.stop();
        shootTimer.stop();
        stage.phase = "idle";
        stage.busy = false;
        stage.moving = false;
        stage.readId = "";
        cut.visible = false;
    }

    function clearSel() {
        stage.selX = 0;
        stage.selY = 0;
        stage.selW = 0;
        stage.selH = 0;
        stage.selKind = "region";
        stage.selWindow = null;
        stage.selRound = 0;
        stage.hoverWin = -1;
    }

    function setSel(x, y, w, h) {
        const b = stage.frameBounds;
        const x0 = Math.max(b.x, Math.min(b.x + b.width, x));
        const y0 = Math.max(b.y, Math.min(b.y + b.height, y));
        stage.selX = Math.round(x0);
        stage.selY = Math.round(y0);
        stage.selW = Math.round(Math.max(0, Math.min(b.x + b.width, x + w) - x0));
        stage.selH = Math.round(Math.max(0, Math.min(b.y + b.height, y + h) - y0));
    }

    function setMode(m) {
        if (stage.phase !== "select" && stage.phase !== "adjust")
            return ;

        if (m === "record" && Capture.active)
            return ;

        if (stage.mode === m)
            return ;

        stage.mode = m;
        // a selection made for a recording is no use to the others, and the
        // others never leave one behind
        stage.clearSel();
        stage.phase = "select";
        stage.hintFresh = true;
        hintTimer.restart();
        if (m === "colour")
            sampler.prime();

    }

    function setTarget(t) {
        if ((stage.phase !== "select" && stage.phase !== "adjust") || (t !== "region" && t !== "window"))
            return ;

        stage.target = t;
        stage.clearSel();
        stage.phase = "select";
        if (stage.pointerIn)
            stage.hoverWin = stage.windowAt(stage.px, stage.py);

        stage.hintFresh = true;
        hintTimer.restart();
    }

    function cycleTimer() {
        const steps = [0, 3, 5, 10];
        if (stage.mode === "record") {
            stage.countdown = steps[(steps.indexOf(stage.countdown) + 1) % steps.length];
            return ;
        }
        stage.timer = steps[(steps.indexOf(stage.timer) + 1) % steps.length];
    }

    function openSettings() {
        stage.settingsRequested();
    }

    function close() {
        if (stage.phase === "fly" || stage.phase === "shooting")
            return ;

        if (stage.phase === "timer") {
            stage.cancelTimer();
            return ;
        }
        stage.closeRequested();
    }

    // right click: one step back, then out
    function back() {
        if (stage.phase === "mark") {
            stage.leaveMarkup();
            return ;
        }
        if (stage.phase === "adjust" || stage.hasSel) {
            stage.clearSel();
            stage.phase = "select";
            return ;
        }
        stage.close();
    }

    function windowAt(x, y) {
        if (stage.editing || stage.mode === "colour")
            return -1;

        for (let i = 0; i < stage.windows.length; i++) {
            const w = stage.windows[i];
            if (x >= w.x && x < w.x + w.w && y >= w.y && y < w.y + w.h)
                return i;

        }
        return -1;
    }

    function inside(x, y) {
        return stage.hasSel && x >= stage.selX && x < stage.selX + stage.selW && y >= stage.selY && y < stage.selY + stage.selH;
    }

    // edges pull the pointer in from a few pixels away: the screen's and the
    // windows', so a window's content is easy to take exactly
    function snap(v, horizontal) {
        const reach = Theme.dp(6);
        const lines = horizontal ? [0, stage.width] : [0, stage.height];
        for (const w of stage.windows) {
            if (horizontal)
                lines.push(w.x, w.x + w.w);
            else
                lines.push(w.y, w.y + w.h);
        }
        let best = v, gap = reach + 1;
        for (const l of lines) {
            const d = Math.abs(l - v);
            if (d < gap) {
                gap = d;
                best = l;
            }
        }
        return best;
    }

    function pointerPress(x, y, button, mods) {
        if (stage.busy || stage.phase === "fly" || stage.phase === "read" || stage.passThrough)
            return ;

        if (button === Qt.RightButton) {
            stage.back();
            return ;
        }
        stage.lastX = x;
        stage.lastY = y;
        if (stage.mode === "colour")
            return ;

        if (stage.phase === "mark") {
            if (stage.tool === "move" && stage.inside(x, y))
                stage.startMove(x, y);

            return ;
        }
        if (stage.phase === "adjust" && stage.inside(x, y)) {
            stage.startMove(x, y);
            return ;
        }
        if (stage.target === "region") {
            const free = mods & Qt.ControlModifier;
            stage.anchorX = free ? x : stage.snap(x, true);
            stage.anchorY = free ? y : stage.snap(y, false);
            stage.selKind = "region";
            stage.selWindow = null;
            stage.selRound = 0;
            stage.setSel(stage.anchorX, stage.anchorY, 0, 0);
            stage.phase = "drag";
        }
    }

    function pointerMove(x, y, mods) {
        stage.px = x;
        stage.py = y;
        stage.pointerIn = true;
        if (stage.moving) {
            stage.setSel(Math.max(stage.frameBounds.x, Math.min(stage.frameBounds.x + stage.frameBounds.width - stage.selW, x - stage.grabDX)), Math.max(stage.frameBounds.y, Math.min(stage.frameBounds.y + stage.frameBounds.height - stage.selH, y - stage.grabDY)), stage.selW, stage.selH);
            return ;
        }
        if (stage.phase === "drag") {
            stage.dragTo(x, y, mods);
            return ;
        }
        if (stage.phase === "select" || (stage.phase === "adjust" && stage.target === "window"))
            stage.hoverWin = stage.windowAt(x, y);

        if (stage.mode === "colour")
            sampler.request();

    }

    function dragTo(x, y, mods) {
        // space held moves the whole selection instead of its far corner
        if (stage.spaceHeld) {
            stage.anchorX += x - stage.lastX;
            stage.anchorY += y - stage.lastY;
        }
        stage.lastX = x;
        stage.lastY = y;
        const free = mods & Qt.ControlModifier;
        let dx = (free ? x : stage.snap(x, true)) - stage.anchorX;
        let dy = (free ? y : stage.snap(y, false)) - stage.anchorY;
        if (mods & Qt.ShiftModifier) {
            const s = Math.max(Math.abs(dx), Math.abs(dy));
            dx = dx < 0 ? -s : s;
            dy = dy < 0 ? -s : s;
        }
        if (mods & Qt.AltModifier)
            stage.setSel(stage.anchorX - Math.abs(dx), stage.anchorY - Math.abs(dy), Math.abs(dx) * 2, Math.abs(dy) * 2);
        else
            stage.setSel(Math.min(stage.anchorX, stage.anchorX + dx), Math.min(stage.anchorY, stage.anchorY + dy), Math.abs(dx), Math.abs(dy));
    }

    function pointerRelease(x, y, button, mods) {
        if (button === Qt.RightButton)
            return ;

        if (stage.moving) {
            stage.moving = false;
            return ;
        }
        if (stage.phase === "drag") {
            // a click rather than a drag takes the window under it
            if (stage.selW < 4 || stage.selH < 4) {
                stage.clearSel();
                stage.phase = "select";
                const w = stage.windowAt(x, y);
                if (w >= 0)
                    stage.takeWindow(w);
                else
                    stage.hoverWin = -1;
                return ;
            }
            stage.commit({
                "x": stage.selX,
                "y": stage.selY,
                "w": stage.selW,
                "h": stage.selH,
                "kind": "region"
            });
            return ;
        }
        if (stage.mode === "colour" && stage.phase === "select") {
            stage.pick(mods & Qt.ShiftModifier);
            return ;
        }
        if ((stage.phase === "select" || stage.phase === "adjust") && stage.target === "window") {
            const w = stage.windowAt(x, y);
            if (w >= 0)
                stage.takeWindow(w);

        }
    }

    function startMove(x, y) {
        stage.moving = true;
        stage.grabDX = x - stage.selX;
        stage.grabDY = y - stage.selY;
    }

    function takeWindow(i) {
        const w = stage.windows[i];
        if (!w)
            return ;

        const whole = w.x >= 0 && w.y >= 0 && w.x + w.w <= stage.width && w.y + w.h <= stage.height;
        stage.commit({
            "x": w.x,
            "y": w.y,
            "w": w.w,
            "h": w.h,
            "kind": "window",
            "win": w,
            "round": whole && !w.fullscreen && Prefs.shotRoundWindows ? stage.rounding : 0
        });
    }

    function takeScreen() {
        stage.commit({
            "x": 0,
            "y": 0,
            "w": stage.width,
            "h": stage.height,
            "kind": "screen"
        });
    }

    // a selection is made: what happens next is the mode's business
    function commit(c) {
        stage.setSel(c.x, c.y, c.w, c.h);
        if (!stage.hasSel)
            return ;

        stage.selKind = c.kind || "region";
        stage.selWindow = c.win || null;
        stage.selRound = c.round || 0;
        stage.hoverWin = -1;
        if (stage.mode === "record") {
            stage.phase = "adjust";
            return ;
        }
        if (stage.mode === "text") {
            stage.readSelection();
            return ;
        }
        if (stage.markup) {
            stage.phase = "mark";
            return ;
        }
        if (stage.timer > 0) {
            stage.startTimer();
            return ;
        }
        stage.cutOut({
            "after": "card"
        });
    }

    function fabAction() {
        if (stage.busy || stage.phase === "fly" || stage.phase === "read" || stage.passThrough)
            return ;

        if (stage.phase === "mark") {
            stage.finishMarkup("card");
            return ;
        }
        if (stage.mode === "colour") {
            if (stage.palette.length > 0)
                stage.copyPalette();

            return ;
        }
        if (stage.mode === "record") {
            stage.record();
            return ;
        }
        if (stage.hasSel)
            stage.commit({
            "x": stage.selX,
            "y": stage.selY,
            "w": stage.selW,
            "h": stage.selH,
            "kind": stage.selKind,
            "win": stage.selWindow,
            "round": stage.selRound
        });
        else
            stage.takeScreen();
    }

    // handles: an edge or a corner follows the pointer, the rest stays put
    function reshapeStart(edge, x, y) {
        stage.edge = edge;
        stage.lastX = x;
        stage.lastY = y;
        stage.edgeFrom = {
            "l": stage.selX,
            "t": stage.selY,
            "r": stage.selX + stage.selW,
            "b": stage.selY + stage.selH
        };
    }

    function reshapeMove(x, y, mods) {
        if (stage.edge === "" || !stage.edgeFrom)
            return ;

        const f = stage.edgeFrom, b = stage.frameBounds, min = 8;
        const free = mods & Qt.ControlModifier;
        let l = f.l, t = f.t, r = f.r, bt = f.b;
        if (stage.edge.indexOf("l") !== -1)
            l = Math.max(b.x, Math.min(r - min, free ? f.l + x - stage.lastX : stage.snap(f.l + x - stage.lastX, true)));

        if (stage.edge.indexOf("r") !== -1)
            r = Math.min(b.x + b.width, Math.max(l + min, free ? f.r + x - stage.lastX : stage.snap(f.r + x - stage.lastX, true)));

        if (stage.edge.indexOf("t") !== -1)
            t = Math.max(b.y, Math.min(bt - min, free ? f.t + y - stage.lastY : stage.snap(f.t + y - stage.lastY, false)));

        if (stage.edge.indexOf("b") !== -1)
            bt = Math.min(b.y + b.height, Math.max(t + min, free ? f.b + y - stage.lastY : stage.snap(f.b + y - stage.lastY, false)));

        stage.setSel(l, t, r - l, bt - t);
        stage.selKind = "region";
        stage.selWindow = null;
        stage.selRound = 0;
    }

    function reshapeEnd() {
        stage.edge = "";
        stage.edgeFrom = null;
    }

    function nudge(dx, dy, grow) {
        if (!stage.hasSel || (stage.phase !== "adjust" && stage.phase !== "mark"))
            return ;

        const b = stage.frameBounds;
        if (grow)
            stage.setSel(stage.selX, stage.selY, Math.max(8, Math.min(b.x + b.width - stage.selX, stage.selW + dx)), Math.max(8, Math.min(b.y + b.height - stage.selY, stage.selH + dy)));
        else
            stage.setSel(Math.max(b.x, Math.min(b.x + b.width - stage.selW, stage.selX + dx)), Math.max(b.y, Math.min(b.y + b.height - stage.selH, stage.selY + dy)), stage.selW, stage.selH);
        stage.selKind = "region";
        stage.selWindow = null;
        stage.selRound = 0;
    }

    function leaveMarkup() {
        if (stage.editing) {
            stage.closeRequested();
            return ;
        }
        marks.clear();
        stage.clearSel();
        stage.phase = "select";
    }

    function undo() {
        marks.undo();
    }

    function redo() {
        marks.redo();
    }

    function finishMarkup(after) {
        if (stage.phase !== "mark" || stage.busy || !stage.hasSel)
            return ;

        if (marks.typing)
            marks.commitText();

        stage.cutOut({
            "after": after,
            "marked": stage.editing || marks.count > 0
        });
    }

    // the text in the selection, as it is on the frame: marks left out
    function readSelection() {
        if (!stage.hasSel || !stage.engine)
            return ;

        stage.readFrom = stage.phase === "mark" ? "mark" : "select";
        stage.phase = "read";
        stage.readId = stage.engine.readText(stage.basePath, {
            "x": stage.selX,
            "y": stage.selY,
            "w": stage.selW,
            "h": stage.selH
        }, stage.ratio, {
        });
    }

    function textDone(r) {
        stage.readId = "";
        if (r.status === "ok") {
            if (stage.cardsOn) {
                stage.cutOut({
                    "after": "card",
                    "kind": "text",
                    "id": r.id,
                    "text": r.text,
                    "codes": r.codes
                });
            } else {
                stage.notify("content_copy", r.text !== "" ? "Text copied" : "Code copied", false);
                stage.closeRequested();
            }
            return ;
        }
        if (r.status === "notool") {
            stage.notify("warning", "Install tesseract to copy text", true);
            stage.closeRequested();
            return ;
        }
        stage.notify(r.status === "empty" ? "search_off" : "warning", r.status === "empty" ? "No text found there" : "The text could not be read", r.status !== "empty");
        if (stage.readFrom === "mark") {
            stage.phase = "mark";
        } else {
            stage.clearSel();
            stage.phase = "select";
        }
    }

    function record() {
        if (Capture.active || !stage.engine)
            return ;

        const whole = !stage.hasSel || (stage.selW >= stage.width - 1 && stage.selH >= stage.height - 1);
        Capture.arm({
            "output": stage.screenName,
            "region": whole ? null : {
                "x": stage.selX,
                "y": stage.selY,
                "w": stage.selW,
                "h": stage.selH
            },
            "mic": stage.mic,
            "system": stage.system,
            "countdown": stage.countdown
        });
        stage.phase = "fly";
        stage.finished();
    }

    // the self-timer: the frozen frame goes, the pointer goes through, and the
    // capture is taken live once the count runs out
    function startTimer() {
        stage.ticks = stage.timer;
        stage.phase = "timer";
        tickTimer.restart();
    }

    function cancelTimer() {
        tickTimer.stop();
        stage.phase = "select";
        stage.clearSel();
    }

    function fireTimer() {
        stage.phase = "shooting";
        shootTimer.restart();
    }

    function liveShot() {
        const whole = stage.selW >= stage.width - 1 && stage.selH >= stage.height - 1;
        const geom = whole ? "" : Math.round(stage.screenX + stage.selX) + "," + Math.round(stage.screenY + stage.selY) + " " + Math.round(stage.selW) + "x" + Math.round(stage.selH);
        const scr = Quickshell.screens.find((s) => {
            return s.name === stage.screenName;
        }) || null;
        stage.engine.live(scr, geom, {
            "round": stage.selRound,
            "address": stage.selWindow ? stage.selWindow.address : ""
        });
        stage.finished();
    }

    function formatColour(c, fmt) {
        const r = Math.round(c.r * 255), g = Math.round(c.g * 255), b = Math.round(c.b * 255);
        if (fmt === "rgb")
            return "rgb(" + r + ", " + g + ", " + b + ")";

        if (fmt === "hsl") {
            const max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b);
            const l = (max + min) / 2;
            let h = 0, s = 0;
            if (max !== min) {
                const d = max - min;
                s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
                if (max === c.r)
                    h = (c.g - c.b) / d + (c.g < c.b ? 6 : 0);
                else if (max === c.g)
                    h = (c.b - c.r) / d + 2;
                else
                    h = (c.r - c.g) / d + 4;
                h *= 60;
            }
            return "hsl(" + Math.round(h) + ", " + Math.round(s * 100) + "%, " + Math.round(l * 100) + "%)";
        }
        return Theme.toHex(c);
    }

    function pick(keep) {
        if (stage.sample.a <= 0 || !stage.engine)
            return ;

        const hex = Theme.toHex(stage.sample);
        const value = stage.formatColour(stage.sample, stage.format);
        stage.engine.copyText(value);
        if (keep) {
            stage.palette = stage.palette.filter((e) => {
                return e.hex !== hex;
            }).concat([{
                "hex": hex,
                "value": value
            }]).slice(-10);
            return ;
        }
        stage.swatch(hex, value);
        stage.closeRequested();
    }

    function copyColour(e) {
        stage.engine.copyText(e.value);
        stage.swatch(e.hex, e.value);
    }

    function copyPalette() {
        stage.engine.copyText(stage.palette.map((e) => {
            return e.value;
        }).join("\n"));
        stage.notify("palette", stage.palette.length === 1 ? "Colour copied" : stage.palette.length + " colours copied", false);
        stage.closeRequested();
    }

    // who announces the capture once it is on disk: a card made here, a pin,
    // or (no cards) the shell
    function ownerFor(after) {
        if (after === "pin")
            return "pin";

        return stage.cardsOn ? "overlay" : "";
    }

    // the selection, frozen into a picture of its own: the card's thumbnail,
    // the editor's export, and the thing that flies away
    function cutOut(o) {
        if (!stage.engine || !stage.hasSel)
            return ;

        const r = {
            "x": stage.selX,
            "y": stage.selY,
            "w": stage.selW,
            "h": stage.selH
        };
        const kind = o.kind || "image";
        const save = o.after === "copy" ? false : (stage.editing ? true : Prefs.shotSaveFile);
        const id = o.id || stage.engine.nextId();
        stage.job = {
            "id": id,
            "after": o.after,
            "rect": r,
            "pw": Math.max(1, Math.round(r.w * stage.ratio)),
            "ph": Math.max(1, Math.round(r.h * stage.ratio)),
            "save": save,
            "marked": o.marked === true,
            "kind": kind,
            "text": o.text || "",
            "codes": o.codes || [],
            "thumb": ""
        };
        stage.flyX = r.x;
        stage.flyY = r.y;
        stage.flyW = r.w;
        stage.flyH = r.h;
        stage.flyR = 0;
        stage.phase = "fly";
        stage.busy = true;
        // a plain capture is cut from the frame on disk, which is exact and
        // leaves this process free to animate
        if (kind === "image" && !stage.job.marked)
            stage.engine.crop(stage.basePath, r, stage.ratio, {
            "id": id,
            "round": stage.selRound,
            "save": save,
            "screen": stage.screenName,
            "owner": stage.ownerFor(o.after)
        });

        cut.opacity = 1;
        cutSource.live = true;
        cut.visible = true;
        cutTimer.restart();
    }

    // two frames on, the cut has drawn: grab what is needed, then let go
    function grabCut() {
        const j = stage.job;
        if (!j)
            return ;

        let waiting = 1;
        const done = () => {
            waiting--;
            if (waiting === 0)
                stage.launch();

        };
        if (j.marked) {
            waiting++;
            const out = stage.engine.runDir + "/grab-" + j.id + ".bmp";
            const asked = cut.grabToImage((res) => {
                if (res.saveToFile(out)) {
                    const src = stage.basePath;
                    const dot = src.lastIndexOf(".");
                    const slash = src.lastIndexOf("/");
                    stage.engine.adopt(out, j.pw, j.ph, {
                        "id": j.id,
                        "save": j.save,
                        "screen": stage.screenName,
                        "owner": stage.ownerFor(j.after),
                        "dir": stage.editing ? src.substring(0, slash) : "",
                        "base": stage.editing ? src.substring(slash + 1, dot > slash ? dot : src.length) + "-edited" : ""
                    });
                } else {
                    stage.notify("warning", "The capture could not be saved", true);
                }
                done();
            }, Qt.size(j.pw, j.ph));
            if (!asked)
                done();

        }
        if (j.after !== "pin" && stage.cardsOn) {
            waiting++;
            const tw = Math.min(j.pw, Math.round(stage.cards.thumbWidth * 2));
            const th = Math.max(1, Math.round(tw * j.ph / j.pw));
            const thumb = stage.engine.runDir + "/thumb-" + j.id + ".png";
            const asked = cut.grabToImage((res) => {
                if (res.saveToFile(thumb))
                    j.thumb = thumb;

                done();
            }, Qt.size(Math.max(1, tw), th));
            if (!asked)
                done();

        }
        done();
    }

    function launch() {
        const j = stage.job;
        cutSource.live = false;
        if (!j)
            return ;

        if (j.after === "pin") {
            // the pin takes this one's place once the file is there
            return ;
        }
        let to = null;
        if (stage.cardsOn)
            to = stage.cards.prepare({
            "id": j.id,
            "kind": j.kind,
            "thumb": j.thumb,
            "w": j.pw,
            "h": j.ph,
            "temp": !j.save,
            "text": j.text,
            "codes": j.codes,
            "screen": stage.screenName,
            "edited": stage.editing
        });

        if (to) {
            flyAnim.toCard = true;
            flyAnim.tx = to.x;
            flyAnim.ty = to.y;
            flyAnim.tw = to.w;
            flyAnim.th = to.h;
            flyAnim.tr = to.radius;
        } else {
            // no card: into the corner, the way it went
            flyAnim.toCard = false;
            const s = Math.max(Theme.dp(24), Math.min(Theme.dp(120), stage.flyW * 0.15));
            flyAnim.tw = s;
            flyAnim.th = Math.max(1, s * stage.flyH / Math.max(1, stage.flyW));
            flyAnim.tx = stage.width - Theme.dp(24) - flyAnim.tw;
            flyAnim.ty = stage.height - Theme.dp(24) - flyAnim.th;
            flyAnim.tr = Theme.rad(12);
        }
        flyAnim.restart();
    }

    function key(e) {
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
        const shift = (e.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (e.modifiers & Qt.AltModifier) !== 0;
        e.accepted = true;
        if (stage.phase === "fly" || stage.phase === "shooting")
            return ;

        if (e.key === Qt.Key_Escape) {
            stage.close();
            return ;
        }
        if (stage.passThrough || stage.phase === "read")
            return ;

        switch (e.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            stage.fabAction();
            return ;
        case Qt.Key_Space:
            if (!e.isAutoRepeat)
                stage.spaceHeld = true;

            return ;
        case Qt.Key_Tab:
            if (stage.phase === "select" && stage.mode !== "colour") {
                stage.setTarget(stage.target === "region" ? "window" : "region");
            }
            return ;
        case Qt.Key_Left:
            stage.nudge(shift ? -10 : -1, 0, alt);
            return ;
        case Qt.Key_Right:
            stage.nudge(shift ? 10 : 1, 0, alt);
            return ;
        case Qt.Key_Up:
            stage.nudge(0, shift ? -10 : -1, alt);
            return ;
        case Qt.Key_Down:
            stage.nudge(0, shift ? 10 : 1, alt);
            return ;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            if (stage.phase === "mark")
                stage.undo();

            return ;
        }
        if (ctrl) {
            if (e.key === Qt.Key_Z && stage.phase === "mark")
                shift ? stage.redo() : stage.undo();
            else if (e.key === Qt.Key_Y && stage.phase === "mark")
                stage.redo();
            else if (e.key === Qt.Key_C && stage.phase === "mark")
                stage.finishMarkup("copy");
            else if (e.key === Qt.Key_S && stage.phase === "mark")
                stage.finishMarkup("card");
            return ;
        }
        if (stage.phase === "mark") {
            const tools = {
                "M": "move",
                "P": "pen",
                "H": "hl",
                "A": "arrow",
                "B": "rect",
                "O": "oval",
                "T": "text",
                "N": "step",
                "X": "redact"
            };
            const t = tools[e.text.toUpperCase()];
            if (t)
                stage.tool = t;

            return ;
        }
        if (stage.phase !== "select")
            return ;

        switch (e.text.toUpperCase()) {
        case "S":
            stage.setMode("shot");
            break;
        case "R":
            stage.setMode("record");
            break;
        case "T":
            stage.setMode("text");
            break;
        case "C":
            stage.setMode("colour");
            break;
        case "W":
            if (stage.mode !== "colour")
                stage.setTarget("window");
            break;
        case "E":
            if (stage.mode === "shot")
                stage.markup = !stage.markup;
            break;
        }
    }

    focus: true
    // after the size has reached every binding, so the jump to it is not animated
    onHeightChanged: {
        if (stage.height > 0 && !stage.sized)
            Qt.callLater(stage.markSized);

    }
    Keys.onPressed: (e) => {
        return stage.key(e);
    }
    Keys.onReleased: (e) => {
        if (e.key === Qt.Key_Space && !e.isAutoRepeat)
            stage.spaceHeld = false;

    }

    Timer {
        id: hintTimer

        interval: 3600
        onTriggered: stage.hintFresh = false
    }

    Timer {
        id: cutTimer

        interval: 48
        onTriggered: stage.grabCut()
    }

    Timer {
        id: tickTimer

        interval: 1000
        repeat: true
        onTriggered: {
            stage.ticks--;
            if (stage.ticks <= 0) {
                tickTimer.stop();
                stage.fireTimer();
            }
        }
    }

    // the countdown is off the screen, and the frame with it, before grim looks
    Timer {
        id: shootTimer

        interval: 64
        onTriggered: stage.liveShot()
    }

    Connections {
        function onTextRead(r) {
            if (r.id === stage.readId && stage.phase === "read")
                stage.textDone(r);

        }

        function onReady(entry) {
            const j = stage.job;
            if (j && j.after === "pin" && entry.id === j.id) {
                if (stage.pins)
                    stage.pins.add(entry.file, stage.screenName, j.rect.x, j.rect.y, j.rect.w, j.rect.h);

                stage.job = null;
                stage.busy = false;
                stage.finished();
            }
        }

        function onFailed(id, why) {
            const j = stage.job;
            if (j && id === j.id && j.after === "pin") {
                stage.notify("warning", why, true);
                stage.job = null;
                stage.busy = false;
                stage.closeRequested();
            }
        }

        target: stage.engine
    }

    // reads the frame's own pixels: the colour picker, and nothing else
    Canvas {
        id: sampler

        property string loaded: ""
        property real fx: 0
        property real fy: 0

        function prime() {
            const u = String(stage.baseUrl);
            if (u === "" || sampler.loaded === u)
                return ;

            if (sampler.loaded !== "")
                sampler.unloadImage(sampler.loaded);

            sampler.loaded = u;
            sampler.loadImage(u);
        }

        function request() {
            sampler.fx = Math.max(0, Math.min(stage.baseSize.width - 1, Math.floor((stage.px - stage.baseRect.x) * stage.ratio)));
            sampler.fy = Math.max(0, Math.min(stage.baseSize.height - 1, Math.floor((stage.py - stage.baseRect.y) * stage.ratio)));
            sampler.requestPaint();
        }

        z: -1
        width: 4
        height: 4
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        onImageLoaded: sampler.request()
        onPaint: {
            if (sampler.loaded === "" || !sampler.isImageLoaded(sampler.loaded))
                return ;

            const ctx = sampler.getContext("2d");
            ctx.clearRect(0, 0, 4, 4);
            ctx.drawImage(sampler.loaded, sampler.fx, sampler.fy, 1, 1, 0, 0, 1, 1);
            const d = ctx.getImageData(0, 0, 1, 1).data;
            stage.sample = Qt.rgba(d[0] / 255, d[1] / 255, d[2] / 255, 1);
        }
    }

    // the picture, and the marks on it: what a capture is cut from
    Item {
        id: scene

        anchors.fill: parent
        // the self-timer looks at the live screen
        visible: !stage.passThrough

        Rectangle {
            anchors.fill: parent
            visible: stage.editing
            color: Theme.alpha(Theme.cScrim, Theme.isLight ? 0.45 : 0.62)
        }

        Image {
            id: base

            x: stage.baseRect.x
            y: stage.baseRect.y
            width: stage.baseRect.width
            height: stage.baseRect.height
            source: stage.baseUrl
            cache: false
            // a frozen screen has to be there the moment the window maps
            asynchronous: stage.editing
            smooth: true
            mipmap: stage.editing && stage.ratio > 1.5
        }

        ShotMarks {
            id: marks

            stage: stage
            base: base
            tool: stage.tool
            ink: stage.ink
            sizeIndex: stage.sizeIndex
            visible: marks.count > 0 || stage.phase === "mark" || marks.drawing !== null
        }

    }

    // the shade round the selection, or round the window under the pointer
    Item {
        id: shade

        readonly property bool glide: stage.phase === "select"
        readonly property bool on: !stage.editing && stage.mode !== "colour" && !stage.passThrough && stage.phase !== "fly"
        readonly property var win: stage.hoverWin >= 0 && stage.phase === "select" ? stage.windows[stage.hoverWin] : null
        readonly property bool showWin: shade.win !== null && stage.target === "window"
        property real hx: shade.showWin ? shade.win.x : (stage.hasSel ? stage.selX : 0)
        property real hy: shade.showWin ? shade.win.y : (stage.hasSel ? stage.selY : 0)
        property real hw: shade.showWin ? shade.win.w : (stage.hasSel ? stage.selW : 0)
        property real hh: shade.showWin ? shade.win.h : (stage.hasSel ? stage.selH : 0)
        readonly property color tone: Theme.alpha("#000000", Theme.isLight ? 0.36 : 0.5)

        anchors.fill: parent
        opacity: shade.on ? 1 : 0
        visible: opacity > 0.01

        Rectangle {
            x: 0
            y: 0
            width: stage.width
            height: Math.max(0, shade.hy)
            color: shade.tone
        }

        Rectangle {
            x: 0
            y: shade.hy + shade.hh
            width: stage.width
            height: Math.max(0, stage.height - shade.hy - shade.hh)
            color: shade.tone
        }

        Rectangle {
            x: 0
            y: shade.hy
            width: Math.max(0, shade.hx)
            height: shade.hh
            color: shade.tone
        }

        Rectangle {
            x: shade.hx + shade.hw
            y: shade.hy
            width: Math.max(0, stage.width - shade.hx - shade.hw)
            height: shade.hh
            color: shade.tone
        }

        Behavior on hx {
            enabled: shade.glide

            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on hy {
            enabled: shade.glide

            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on hw {
            enabled: shade.glide

            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on hh {
            enabled: shade.glide

            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durDefaultEffects
            }

        }

    }

    // crosshair guides through the pointer, before a drag starts
    Item {
        anchors.fill: parent
        visible: stage.aiming && stage.phase === "select"

        Rectangle {
            x: Math.round(stage.px)
            width: 1
            height: stage.height
            color: Theme.alpha(Theme.primary, 0.55)
        }

        Rectangle {
            y: Math.round(stage.py)
            width: stage.width
            height: 1
            color: Theme.alpha(Theme.primary, 0.55)
        }

    }

    // the pointer while the stage draws it: the theme's own crosshair, or a
    // plain one in its colours when a theme of the machine's is in use
    DrawnPointer {
        id: aim

        cursor: Qt.CrossCursor
        px: stage.px
        py: stage.py
        visible: stage.aiming
        z: 11

        Item {
            id: plain

            readonly property int core: 2 * Math.max(1, Math.round(aim.width / 24))
            readonly property int rim: plain.core + 2 * Math.max(2, Math.round(aim.width / 12))

            anchors.fill: parent
            visible: !aim.ready

            Rectangle {
                x: (aim.width - plain.rim) / 2
                y: 1
                width: plain.rim
                height: aim.height - 2
                radius: width / 2
                color: Pointer.colours.ink
            }

            Rectangle {
                x: 1
                y: (aim.height - plain.rim) / 2
                width: aim.width - 2
                height: plain.rim
                radius: height / 2
                color: Pointer.colours.ink
            }

            Rectangle {
                x: (aim.width - plain.core) / 2
                y: 1 + (plain.rim - plain.core) / 2
                width: plain.core
                height: aim.height - 2 - (plain.rim - plain.core)
                radius: width / 2
                color: Pointer.colours.body
            }

            Rectangle {
                x: 1 + (plain.rim - plain.core) / 2
                y: (aim.height - plain.core) / 2
                width: aim.width - 2 - (plain.rim - plain.core)
                height: plain.core
                radius: height / 2
                color: Pointer.colours.body
            }

        }

    }

    MouseArea {
        id: input

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: !stage.passThrough && stage.phase !== "fly"
        cursorShape: {
            if (stage.aiming)
                return aim.onScreen ? Qt.BlankCursor : Qt.CrossCursor;

            if (stage.moving)
                return Qt.ClosedHandCursor;

            if (stage.phase === "mark")
                return stage.tool === "move" && stage.inside(stage.px, stage.py) ? Qt.OpenHandCursor : Qt.ArrowCursor;

            if (stage.phase === "adjust" && stage.inside(stage.px, stage.py))
                return Qt.OpenHandCursor;

            if (stage.mode === "colour")
                return loupe.want ? Qt.BlankCursor : Qt.CrossCursor;

            if (stage.target === "region" || stage.phase === "drag")
                return Qt.CrossCursor;

            return Qt.PointingHandCursor;
        }
        onPressed: (mouse) => {
            return stage.pointerPress(mouse.x, mouse.y, mouse.button, mouse.modifiers);
        }
        onPositionChanged: (mouse) => {
            return stage.pointerMove(mouse.x, mouse.y, mouse.modifiers);
        }
        onReleased: (mouse) => {
            return stage.pointerRelease(mouse.x, mouse.y, mouse.button, mouse.modifiers);
        }
        // a window that maps under a still pointer hears of it only here
        onEntered: {
            stage.px = input.mouseX;
            stage.py = input.mouseY;
            stage.pointerIn = true;
        }
        onExited: stage.pointerIn = false

        HeldPointer {
            held: stage.moving
            cursor: Qt.ClosedHandCursor
        }

    }

    // the editor's pen, over the selection while marking up
    MouseArea {
        id: pen

        x: stage.selX
        y: stage.selY
        width: stage.selW
        height: stage.selH
        enabled: stage.phase === "mark" && stage.tool !== "move" && !stage.busy
        visible: pen.enabled
        preventStealing: true
        cursorShape: stage.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
        onPressed: (mouse) => {
            return marks.press(mouse.x + pen.x, mouse.y + pen.y);
        }
        onPositionChanged: (mouse) => {
            if (pen.pressed)
                marks.move(mouse.x + pen.x, mouse.y + pen.y, mouse.modifiers);

        }
        onReleased: marks.release()
        onCanceled: marks.release()

        HeldPointer {
            held: pen.pressed
            cursor: pen.cursorShape
        }

    }

    // a window under the pointer that a click would take
    Rectangle {
        readonly property var win: shade.win

        visible: win !== null && stage.target === "region" && stage.mode !== "colour"
        x: win ? win.x - 1 : 0
        y: win ? win.y - 1 : 0
        width: win ? win.w + 2 : 0
        height: win ? win.h + 2 : 0
        radius: stage.rounding + 1
        color: "transparent"
        border.width: Theme.dp(2)
        border.color: Theme.alpha(Theme.primary, 0.6)
    }

    ShotFrame {
        readonly property var win: shade.win

        stage: stage
        visible: shade.showWin && stage.mode !== "colour"
        x: shade.hx
        y: shade.hy
        width: shade.hw
        height: shade.hh
        sizeText: win ? Math.round(win.w * stage.ratio) + " × " + Math.round(win.h * stage.ratio) : ""
        caption: win ? (win.title || win.cls || "") : ""
        radius: win && !win.fullscreen ? stage.rounding : 0
        roomBelow: stage.height - shade.hy - shade.hh
    }

    ShotFrame {
        id: frame

        stage: stage
        visible: stage.hasSel && (stage.phase === "drag" || stage.phase === "adjust" || stage.phase === "mark" || stage.phase === "read" || stage.phase === "timer")
        x: stage.selX
        y: stage.selY
        width: stage.selW
        height: stage.selH
        ink: stage.phase === "timer" ? Theme.alpha(Theme.primary, 0.8) : (stage.mode === "record" ? Theme.error : Theme.primary)
        handles: (stage.phase === "adjust" || stage.phase === "mark") && !marks.drawing && !marks.typing
        sizeText: stage.phase === "timer" ? "" : Math.round(stage.selW * stage.ratio) + " × " + Math.round(stage.selH * stage.ratio)
        caption: stage.selWindow ? (stage.selWindow.title || stage.selWindow.cls || "") : ""
        radius: stage.selRound
        roomBelow: stage.height - stage.selY - stage.selH
    }

    // reading: the selection stays lit and a light sweeps it until the copy lands
    Item {
        id: scan

        visible: stage.phase === "read"
        x: stage.selX
        y: stage.selY
        width: stage.selW
        height: stage.selH
        clip: true

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.primary, 0.08)
        }

        Rectangle {
            id: beam

            width: parent.width
            height: Math.max(Theme.dp(24), parent.height * 0.18)

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.primary, 0)
                }

                GradientStop {
                    position: 0.85
                    color: Theme.alpha(Theme.primary, 0.26)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.primary, 0.75)
                }

            }

        }

        SequentialAnimation {
            running: scan.visible
            loops: Animation.Infinite

            NumberAnimation {
                target: beam
                property: "y"
                from: -beam.height
                to: scan.height
                duration: Theme.ms(950)
                easing.type: Easing.InOutSine
            }

            PauseAnimation {
                duration: Theme.ms(120)
            }

        }

        LoadingIndicator {
            anchors.centerIn: parent
            width: Theme.dp(52)
            height: Theme.dp(52)
            contained: true
            running: scan.visible
            visible: scan.width > Theme.dp(64) && scan.height > Theme.dp(64)
        }

    }

    ShotCountdown {
        id: timerBadge

        visible: stage.phase === "timer"
        value: stage.ticks
        caption: "Click to cancel"
        x: Math.round(stage.selX + stage.selW / 2 - width / 2)
        y: Math.round(stage.selY + stage.selH / 2 - Theme.dp(88))
        onTapped: stage.cancelTimer()
    }

    ShotLoupe {
        id: loupe

        readonly property bool want: stage.pointerIn && !stage.editing && !stage.moving && stage.edge === "" && ((stage.mode === "colour" && stage.phase === "select") || (stage.phase === "drag" && Prefs.shotLoupe))
        // beside the pointer, on whichever side has room
        readonly property real gap: Theme.dp(28)

        visible: loupe.want
        source: stage.baseUrl
        frameSize: stage.baseSize
        ratio: stage.ratio
        px: stage.px
        py: stage.py
        picked: stage.mode === "colour" ? stage.sample : "transparent"
        label: stage.mode === "colour" ? (stage.sample.a > 0 ? stage.formatColour(stage.sample, stage.format) : "") : Math.round(stage.px * stage.ratio) + ", " + Math.round(stage.py * stage.ratio)
        // picking a colour, the lens is the pointer; selecting, it keeps beside it
        readonly property bool centred: stage.mode === "colour"

        x: Math.round(loupe.centred ? stage.px - loupe.box / 2 : (stage.px + loupe.gap + loupe.width > stage.width ? stage.px - loupe.gap - loupe.width : stage.px + loupe.gap))
        y: Math.round(loupe.centred ? stage.py - loupe.box / 2 : (stage.py + loupe.gap + loupe.height > stage.height ? stage.py - loupe.gap - loupe.height : stage.py + loupe.gap))
        z: 5
    }

    ShotChip {
        id: hintChip

        readonly property bool want: stage.hint !== "" && (stage.hintFresh || stage.phase === "read") && stage.phase !== "fly"

        x: Math.round((stage.width - width) / 2)
        y: toolbar.high ? stage.height - stage.dockBand - height - Theme.dp(40) : Theme.dp(28)
        text: stage.hint
        tabular: false
        icon: stage.phase === "read" ? "document_scanner" : "info"
        opacity: hintChip.want ? 1 : 0
        visible: opacity > 0.01
        layer.enabled: opacity < 0.999
        z: 6

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durDefaultEffects
            }

        }

    }

    ShotToolbar {
        id: toolbar

        // where the item goes for the bar itself to rest there: the item has
        // room for its shadow on every side
        readonly property real lowY: stage.height - stage.dockBand - Theme.dp(40) - toolbar.bodyHeight - toolbar.pad
        readonly property real highY: Theme.dp(24) - toolbar.pad
        // off the bottom when the selection reaches into it, if the top is clear
        readonly property bool high: {
            if (!stage.hasSel || stage.phase === "select")
                return false;

            const reachesLow = stage.selY + stage.selH > toolbar.lowY + toolbar.pad - Theme.dp(16);
            const clearHigh = stage.selY > toolbar.highY + toolbar.pad + toolbar.bodyHeight + Theme.dp(16);
            return reachesLow && clearHigh;
        }
        property real lift: 0

        stage: stage
        tipAbove: !toolbar.high
        x: Math.round((stage.width - toolbar.width) / 2)
        y: (toolbar.high ? toolbar.highY : toolbar.lowY) + toolbar.lift
        // faded out as one picture: item by item, the pill's shadow would show
        // through the pill, and the pill through every button on it
        layer.enabled: stage.leaving || flyAnim.running
        z: 8
        visible: opacity > 0.01 && !stage.passThrough
        // a drag passing over it keeps the stage's pointer, not a button's
        enabled: stage.phase !== "drag"
        width: implicitWidth
        height: implicitHeight

        Behavior on y {
            enabled: stage.sized

            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    RectangularShadow {
        anchors.fill: cut
        radius: cut.radius
        blur: Theme.dp(22)
        offset.y: Theme.dp(6)
        color: Theme.alpha(Theme.shadow, 0.45)
        visible: cut.visible && stage.phase === "fly"
        opacity: cut.opacity
        z: 9
    }

    // the selection as a picture of its own, which is what flies to the card
    ClippingRectangle {
        id: cut

        visible: false
        x: stage.flyX
        y: stage.flyY
        width: stage.flyW
        height: stage.flyH
        radius: stage.flyR
        color: "transparent"
        z: 10

        ShaderEffectSource {
            id: cutSource

            anchors.fill: parent
            sourceItem: scene
            sourceRect: stage.job ? Qt.rect(stage.job.rect.x, stage.job.rect.y, stage.job.rect.w, stage.job.rect.h) : Qt.rect(0, 0, 1, 1)
            textureSize: stage.job ? Qt.size(stage.job.pw, stage.job.ph) : Qt.size(1, 1)
            hideSource: false
            smooth: true
        }

    }

    ParallelAnimation {
        id: barIn

        NumberAnimation {
            target: toolbar
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.durEnter
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        // nothing to come in from before the window has its size: the first
        // open only fades, as every later one appears to
        NumberAnimation {
            target: toolbar
            property: "lift"
            from: !stage.sized ? 0 : (toolbar.high ? -Theme.dp(28) : Theme.dp(28))
            to: 0
            duration: Theme.durEnter
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    ParallelAnimation {
        id: flyAnim

        property bool toCard: true
        property real tx: 0
        property real ty: 0
        property real tw: 0
        property real th: 0
        property real tr: 0

        onFinished: {
            const j = stage.job;
            stage.job = null;
            stage.busy = false;
            if (flyAnim.toCard && j && stage.cards)
                stage.cards.reveal(j.id);

            stage.finished();
        }

        NumberAnimation {
            target: stage
            property: "flyX"
            to: flyAnim.tx
            duration: Theme.durDefaultSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

        NumberAnimation {
            target: stage
            property: "flyY"
            to: flyAnim.ty
            duration: Theme.durDefaultSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

        NumberAnimation {
            target: stage
            property: "flyW"
            to: flyAnim.tw
            duration: Theme.durDefaultSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

        NumberAnimation {
            target: stage
            property: "flyH"
            to: flyAnim.th
            duration: Theme.durDefaultSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

        NumberAnimation {
            target: stage
            property: "flyR"
            to: flyAnim.tr
            duration: Theme.durDefaultSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

        NumberAnimation {
            target: scene
            property: "opacity"
            to: 0
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
        }

        NumberAnimation {
            target: toolbar
            property: "opacity"
            to: 0
            duration: Theme.durExit
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
        }

        NumberAnimation {
            target: cut
            property: "opacity"
            from: 1
            to: flyAnim.toCard ? 1 : 0
            duration: Theme.durDefaultSpatial
            easing.type: Easing.InCubic
        }

    }

}
