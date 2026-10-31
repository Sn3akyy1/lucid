import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// LucidShot's capture overlay. it freezes the display in use and lays the
// stage over it, after waiting for anything of ours that would be in the frame
// to leave (the last overlay's fade, the result card). it keeps the keyboard
// while it is up and remembers its options between opens
PanelWindow {
    id: overlay

    property var engine: null
    property var cards: null
    property var pins: null
    property bool open: false
    // mapped through the exit fade after open drops
    property bool closing: false
    property double unmappedAt: 0
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-shot"
    property string freezePath: ""
    property int freezes: 0
    property string wantMode: "shot"
    property string wantTarget: ""
    // the target a shortcut asked for is not a preference to keep
    property string savedTarget: "region"
    property string wantEdit: ""
    property bool wantWhole: false
    property var editSize: Qt.size(0, 0)
    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/lucid/shot.json"
    // for the status call and for debugging
    readonly property Item stageItem: stage
    // the window that had the keyboard before the overlay took it, handed
    // back while the self-timer counts: dropping the focus alone leaves it nowhere
    property var previous: null

    signal notify(string icon, string text, bool warn)
    signal swatch(string hex, string text)
    signal freezeFailed(string why)

    // mode: "shot" | "record" | "text" | "colour"; target: "region" | "window",
    // or "screen" to take the whole screen as soon as it is frozen
    function begin(mode, target) {
        if (freeze.running || (overlay.open && !overlay.closing && stage.phase !== "idle"))
            return ;

        overlay.wantMode = mode || "shot";
        overlay.wantWhole = target === "screen";
        overlay.wantTarget = target === "screen" ? "" : (target || "");
        overlay.wantEdit = "";
        overlay.prepare();
    }

    // mark up a saved capture: no freeze, the picture over a dimmed desktop
    function edit(file) {
        if (!file || overlay.open)
            return ;

        overlay.wantEdit = file;
        overlay.wantWhole = false;
        overlay.wantMode = "shot";
        overlay.wantTarget = "";
        overlay.prepare();
    }

    function prepare() {
        // the last overlay, hyprland's fade included, has to be off the screen
        // before grim runs, or the freeze photographs it
        if (overlay.closing) {
            sceneFade.stop();
            overlay.closing = false;
        }
        // the wall clock can step back (ntp fixing the rtc after boot), so never wait past 220 ms
        const since = Date.now() - overlay.unmappedAt;
        const settle = since < 0 ? 220 : 220 - since;
        if (!overlay.open && settle > 0) {
            settleDelay.interval = Math.ceil(settle);
            settleDelay.restart();
            return ;
        }
        if (overlay.wantEdit === "" && overlay.cards && overlay.cards.onScreen) {
            overlay.cards.hideNow();
            clearDelay.restart();
            return ;
        }
        // pinned to the display in use, so the freeze grim takes and the one
        // the overlay is drawn on are the same display. on another one the
        // toolbar is placed afresh rather than gliding over from the last
        if (Monitors.focusedScreen) {
            if (!overlay.screen || overlay.screen.name !== Monitors.focusedScreen.name || overlay.screen.height !== Monitors.focusedScreen.height)
                stage.sized = false;

            overlay.screen = Monitors.focusedScreen;
        }

        overlay.previous = ToplevelManager.activeToplevel;
        overlay.rounding = HyprConfig.num("decoration.rounding", 0);
        if (overlay.wantEdit !== "") {
            probe.command = ["sh", "-c", "mkdir -p \"$1\"; magick identify -format '%w %h' \"$2\" 2>/dev/null || identify -format '%w %h' \"$2\"", "sh", overlay.runDir, overlay.wantEdit];
            probe.running = true;
            return ;
        }
        overlay.freezes++;
        overlay.freezePath = overlay.runDir + "/freeze-" + Date.now() + ".png";
        freeze.command = overlay.freezeCommand();
        freeze.running = true;
        winList.running = true;
    }

    property real rounding: 0

    function show() {
        sceneFade.stop();
        overlay.closing = false;
        overlay.contentItem.opacity = 1;
        overlay.applyOptions();
        stage.screenName = overlay.outputName();
        stage.screenX = overlay.screen ? overlay.screen.x : 0;
        stage.screenY = overlay.screen ? overlay.screen.y : 0;
        stage.rounding = overlay.rounding;
        stage.reset(overlay.wantMode, overlay.wantTarget);
        overlay.open = true;
        stage.forceActiveFocus();
        if (overlay.wantWhole) {
            overlay.wantWhole = false;
            whole.tries = 0;
            whole.restart();
        }
    }

    // dismissed: the scene fades on a window still mapped, then it goes
    function close() {
        if (!overlay.open)
            return ;

        overlay.saveOptions();
        // closing first: dropping open first left the window unwanted for a
        // moment, so it unmapped and mapped again, and the compositor faded
        // the overlay in just as it was meant to fade out
        overlay.closing = true;
        overlay.open = false;
        stage.leave();
        sceneFade.restart();
    }

    // handed on, already out of sight: unmap at once
    function finish() {
        overlay.saveOptions();
        sceneFade.stop();
        overlay.closing = false;
        overlay.open = false;
    }

    // read when a command is built, never kept in a binding: one held on to a
    // display gone since start-up (a laptop panel switched off after boot)
    function outputName() {
        const live = Quickshell.screens.map((s) => {
            return s.name;
        });
        for (const s of [overlay.screen, Monitors.focusedScreen]) {
            const name = s ? String(s.name || "") : "";
            if (name !== "" && live.indexOf(name) !== -1)
                return name;

        }
        return "";
    }

    // -o, or a second display would be stitched into the freeze and every crop
    // read at the wrong scale. -l 0: the freeze is read once and thrown away.
    // the runtime dir is memory, so what earlier captures left there goes too
    function freezeCommand() {
        const name = overlay.outputName();
        return ["sh", "-c", "mkdir -p \"$1\" && chmod 700 \"$1\" && rm -f \"$1\"/freeze-*.png \"$1\"/thumb-*.png \"$1\"/grab-*.bmp; find \"$1\" -maxdepth 2 \\( -name 'screenshot_*' -o -name 'frame-*' \\) -mmin +720 -delete 2>/dev/null; grim " + (name !== "" ? "-o \"$3\" " : "") + "-l 0 \"$2\"", "sh", overlay.runDir, overlay.freezePath, name];
    }

    function applyOptions() {
        const o = opts;
        stage.markup = o.markup;
        overlay.savedTarget = o.target === "window" ? "window" : "region";
        stage.target = overlay.savedTarget;
        stage.mic = o.mic;
        stage.system = o.system;
        stage.format = ["hex", "rgb", "hsl"].indexOf(o.format) !== -1 ? o.format : "hex";
        stage.tool = o.tool || "arrow";
        stage.inkIndex = Math.max(0, o.ink);
        stage.sizeIndex = Math.max(0, Math.min(2, o.size));
        stage.countdown = o.countdown >= 0 ? o.countdown : Prefs.recordCountdown;
    }

    function saveOptions() {
        if (stage.editing)
            return ;

        opts.markup = stage.markup;
        opts.target = overlay.wantTarget !== "" && stage.target === overlay.wantTarget ? overlay.savedTarget : stage.target;
        opts.mic = stage.mic;
        opts.system = stage.system;
        opts.format = stage.format;
        opts.tool = stage.tool;
        opts.ink = stage.inkIndex;
        opts.size = stage.sizeIndex;
        opts.countdown = stage.countdown;
        saveDelay.restart();
    }

    // hyprland's own window list, made relative to this display and ordered
    // the way they are stacked: special workspace, floating, tiled, each by
    // how recently it had the focus
    function adoptWindows(text) {
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            stage.windows = [];
            return ;
        }
        const name = overlay.outputName();
        const mon = (data.monitors || []).find((m) => {
            return m.name === name;
        });
        if (!mon) {
            stage.windows = [];
            return ;
        }
        const scale = mon.scale || 1;
        const ws = mon.activeWorkspace ? mon.activeWorkspace.id : null;
        const special = mon.specialWorkspace ? mon.specialWorkspace.id : 0;
        const list = (data.clients || []).filter((c) => {
            if (!c.mapped || c.hidden || !c.workspace)
                return false;

            return c.workspace.id === ws || (special !== 0 && c.workspace.id === special) || (c.pinned && c.monitor === mon.id);
        }).map((c) => {
            return {
                "x": c.at[0] - mon.x,
                "y": c.at[1] - mon.y,
                "w": c.size[0],
                "h": c.size[1],
                "title": c.title || "",
                "cls": c["class"] || "",
                "address": c.address || "",
                "floating": c.floating === true,
                "fullscreen": c.fullscreen > 0 || c.fullscreen === true,
                "special": special !== 0 && c.workspace.id === special,
                "focus": c.focusHistoryID === undefined ? 999 : c.focusHistoryID
            };
        });
        list.sort((a, b) => {
            if (a.special !== b.special)
                return a.special ? -1 : 1;

            if (a.fullscreen !== b.fullscreen)
                return a.fullscreen ? -1 : 1;

            if (a.floating !== b.floating)
                return a.floating ? -1 : 1;

            return a.focus - b.focus;
        });
        stage.windows = list;
    }

    color: "transparent"
    visible: (overlay.open || overlay.closing) && Monitors.surfacesUp
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucid-shot"
    WlrLayershell.keyboardFocus: overlay.open && !stage.passThrough ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: overlay.closing ? emptyRegion : (stage.passThrough ? countdownRegion : null)
    onVisibleChanged: {
        if (!overlay.visible) {
            overlay.unmappedAt = Date.now();
            stage.park();
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Region {
        id: emptyRegion
    }

    Region {
        id: countdownRegion

        item: stage.countdownItem
    }

    // what the overlay last used, so it opens the way it was left
    JsonAdapter {
        id: opts

        property bool markup: false
        property string target: "region"
        property bool mic: false
        property bool system: true
        property string format: "hex"
        property string tool: "arrow"
        property int ink: 0
        property int size: 1
        property int countdown: -1
    }

    FileView {
        id: optsFile

        path: overlay.statePath
        adapter: opts
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: saveDelay

        interval: 400
        onTriggered: {
            Quickshell.execDetached(["mkdir", "-p", overlay.statePath.substring(0, overlay.statePath.lastIndexOf("/"))]);
            optsFile.writeAdapter();
        }
    }

    ShotStage {
        id: stage

        anchors.fill: parent
        engine: overlay.engine
        cards: overlay.cards
        pins: overlay.pins
        onCloseRequested: overlay.close()
        onFinished: overlay.finish()
        onNotify: (icon, text, warn) => {
            return overlay.notify(icon, text, warn);
        }
        onSwatch: (hex, text) => {
            return overlay.swatch(hex, text);
        }
        onSettingsRequested: {
            overlay.close();
            Quickshell.execDetached(["sh", "-c", "sleep 0.25; qs ipc call settings show capture"]);
        }
    }

    NumberAnimation {
        id: sceneFade

        target: overlay.contentItem
        property: "opacity"
        to: 0
        duration: Theme.durExit
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedAccel
        onFinished: overlay.closing = false
    }

    // the self-timer started: the pointer goes through, and the keyboard goes
    // back to the window that had it
    Connections {
        function onPassThroughChanged() {
            if (stage.passThrough)
                handBack.restart();

        }

        target: stage
    }

    Timer {
        id: handBack

        interval: 60
        onTriggered: {
            if (overlay.previous && stage.passThrough)
                overlay.previous.activate();

        }
    }

    // the whole screen, once the window has been given its size: on the first
    // open after a restart it has none until the compositor answers
    Timer {
        id: whole

        property int tries: 0

        interval: 16
        repeat: true
        onTriggered: {
            whole.tries++;
            if (stage.width > 0 && stage.height > 0) {
                whole.stop();
                stage.takeScreen();
            } else if (whole.tries > 60) {
                whole.stop();
            }
        }
    }

    Timer {
        id: settleDelay

        onTriggered: overlay.prepare()
    }

    Timer {
        id: clearDelay

        interval: 80
        onTriggered: overlay.prepare()
    }

    Process {
        id: freeze

        property int lastExit: -1
        property string lastError: ""

        onExited: (code) => {
            freeze.lastExit = code;
            if (code !== 0) {
                freezeFail.restart();
                return ;
            }
            stage.editing = false;
            stage.basePath = overlay.freezePath;
            stage.baseUrl = "";
            stage.baseUrl = "file://" + overlay.freezePath;
            // the freeze decodes as it is set, so its size is known by now
            const n = stage.naturalSize;
            stage.baseSize = n.width > 0 ? n : Qt.size(overlay.width, overlay.height);
            overlay.show();
        }

        stderr: StdioCollector {
            onStreamFinished: freeze.lastError = this.text.trim()
        }

    }

    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(/\s+/);
                const w = parseInt(f[0]), h = parseInt(f[1]);
                if (!(w > 0 && h > 0)) {
                    overlay.notify("broken_image", "That picture could not be opened", true);
                    return ;
                }
                stage.editing = true;
                stage.windows = [];
                stage.basePath = overlay.wantEdit;
                stage.baseSize = Qt.size(w, h);
                stage.baseUrl = "";
                stage.baseUrl = overlay.engine ? overlay.engine.fileUrl(overlay.wantEdit) : "file://" + overlay.wantEdit;
                overlay.show();
            }
        }

    }

    Process {
        id: winList

        command: ["sh", "-c", "printf '{\"clients\":'; hyprctl -j clients 2>/dev/null || printf '[]'; printf ',\"monitors\":'; hyprctl -j monitors 2>/dev/null || printf '[]'; printf '}'"]

        stdout: StdioCollector {
            onStreamFinished: overlay.adoptWindows(this.text)
        }

    }

    // stderr finishes after the exit, so the reason is read a beat later
    Timer {
        id: freezeFail

        interval: 100
        onTriggered: {
            overlay.wantWhole = false;
            const why = freeze.lastError !== "" ? freeze.lastError : "grim exited with " + freeze.lastExit;
            console.warn("lucidshot: could not freeze the screen: " + why);
            overlay.freezeFailed(why);
        }
    }

    IpcHandler {
        function toggle(): void {
            if (overlay.open)
                overlay.close();
            else
                overlay.begin("shot", "");
        }

        function open(): void {
            overlay.begin("shot", "");
        }

        function region(): void {
            overlay.begin("shot", "region");
        }

        function window(): void {
            overlay.begin("shot", "window");
        }

        function screen(): void {
            overlay.begin("shot", "screen");
        }

        function text(): void {
            if (overlay.open)
                stage.setMode("text");
            else
                overlay.begin("text", "");
        }

        function color(): void {
            if (overlay.open)
                stage.setMode("colour");
            else
                overlay.begin("colour", "");
        }

        // straight into the recorder; while one runs, its controls come back
        function video(): void {
            if (Capture.active) {
                Capture.hidden = false;
                Capture.showRequested();
                return ;
            }
            if (overlay.open)
                stage.setMode("record");
            else
                overlay.begin("record", "");
        }

        function record(): void {
            video();
        }

        function stop(): void {
            Capture.stop();
        }

        function edit(path: string): void {
            overlay.edit(path);
        }

        function unpin(): void {
            if (overlay.pins)
                overlay.pins.clear();

        }

        function close(): void {
            overlay.close();
        }

        // what the overlay thinks it is doing, for a bug report
        function status(): string {
            return JSON.stringify({
                "open": overlay.open,
                "closing": overlay.closing,
                "phase": stage.phase,
                "mode": stage.mode,
                "target": stage.target,
                "selection": [stage.selX, stage.selY, stage.selW, stage.selH],
                "windows": stage.windows.length,
                "frame": [stage.baseSize.width, stage.baseSize.height],
                "freezing": freeze.running,
                "lastFreezeExit": freeze.lastExit,
                "lastFreezeError": freeze.lastError,
                "settling": settleDelay.running,
                "cardOnScreen": overlay.cards ? overlay.cards.onScreen === true : false,
                "screen": overlay.screen ? overlay.screen.name : "",
                "focusedScreen": Monitors.focusedScreen ? Monitors.focusedScreen.name : "",
                "recorder": Capture.state
            });
        }

        target: "snap"
    }

}
