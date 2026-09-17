import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: kbWindow

    property bool open: false
    // kept up for the exit animation, which outlives open
    property bool rendered: false
    // "letters" | "function". shadowing Item.layer is a silent killer, hence the name
    readonly property string keyLayer: st.keyLayer === "function" ? "function" : "letters"
    // every modifier: 0 off, 1 one-shot, 2 locked
    property int shiftState: 0
    property int ctrlState: 0
    property int altState: 0
    property int superState: 0
    property var targetToplevel: null
    property var queue: []

    readonly property real minKeySize: 32
    readonly property real maxKeySize: 80
    readonly property real keySize: Math.max(kbWindow.minKeySize, Math.min(kbWindow.maxKeySize, st.keySize))
    // -1 on either axis means never placed, i.e. centred above the dock
    readonly property real panelX: kbWindow.clampX(kbWindow.liveX >= 0 ? kbWindow.liveX : (st.panelX >= 0 ? st.panelX : (kbWindow.width - face.width) / 2))
    readonly property real panelY: kbWindow.clampY(kbWindow.liveY >= 0 ? kbWindow.liveY : (st.panelY >= 0 ? st.panelY : kbWindow.height - face.height - 116))
    // held while a drag is in flight; state.json is written once, on release
    property real liveX: -1
    property real liveY: -1

    function clampX(v) {
        return Math.max(0, Math.min(Math.max(0, kbWindow.width - face.width), v));
    }

    function clampY(v) {
        return Math.max(0, Math.min(Math.max(0, kbWindow.height - face.height), v));
    }

    function moveTo(px, py) {
        kbWindow.liveX = kbWindow.clampX(px);
        kbWindow.liveY = kbWindow.clampY(py);
    }

    function dragEnd() {
        if (kbWindow.liveX >= 0)
            st.panelX = kbWindow.liveX;

        if (kbWindow.liveY >= 0)
            st.panelY = kbWindow.liveY;

    }

    function recentre() {
        kbWindow.liveX = -1;
        kbWindow.liveY = -1;
        st.panelX = -1;
        st.panelY = -1;
    }

    function show() {
        if (ToplevelManager.activeToplevel)
            kbWindow.targetToplevel = ToplevelManager.activeToplevel;

        kbWindow.open = true;
    }

    function modState(name) {
        switch (name) {
        case "shift":
            return kbWindow.shiftState;
        case "caps":
            return kbWindow.shiftState === 2 ? 2 : 0;
        case "ctrl":
            return kbWindow.ctrlState;
        case "alt":
            return kbWindow.altState;
        case "super":
            return kbWindow.superState;
        }
        return 0;
    }

    // off -> one-shot -> locked -> off. caps is the lock half of shift
    function cycleMod(name) {
        if (name === "caps") {
            kbWindow.shiftState = kbWindow.shiftState === 2 ? 0 : 2;
            return ;
        }
        var next = (kbWindow.modState(name) + 1) % 3;
        switch (name) {
        case "shift":
            kbWindow.shiftState = next;
            break;
        case "ctrl":
            kbWindow.ctrlState = next;
            break;
        case "alt":
            kbWindow.altState = next;
            break;
        case "super":
            kbWindow.superState = next;
            break;
        }
    }

    function consumeOneShots() {
        if (kbWindow.shiftState === 1)
            kbWindow.shiftState = 0;

        if (kbWindow.ctrlState === 1)
            kbWindow.ctrlState = 0;

        if (kbWindow.altState === 1)
            kbWindow.altState = 0;

        if (kbWindow.superState === 1)
            kbWindow.superState = 0;

    }

    function clearMods() {
        kbWindow.shiftState = 0;
        kbWindow.ctrlState = 0;
        kbWindow.altState = 0;
        kbWindow.superState = 0;
    }

    // the layer never takes keyboard focus, so the target normally keeps it.
    // if something dropped it anyway, hand it back before typing
    function reclaimFocus() {
        if (!ToplevelManager.activeToplevel && kbWindow.targetToplevel)
            kbWindow.targetToplevel.activate();

    }

    function fire(entry) {
        if (entry.t === "mod") {
            kbWindow.cycleMod(entry.k);
            return ;
        }
        var mods = [];
        if (kbWindow.ctrlState > 0)
            mods.push("CTRL");

        if (kbWindow.altState > 0)
            mods.push("ALT");

        if (kbWindow.superState > 0)
            mods.push("SUPER");

        var shift = kbWindow.shiftState > 0;
        kbWindow.reclaimFocus();
        if (mods.length > 0) {
            // a real chord. hyprland's own dispatcher is the one path every app
            // honours - wtype's ctrl combos are ignored by vscode and friends
            if (shift)
                mods.push("SHIFT");

            Hyprland.dispatch("hl.dsp.send_shortcut{ mods = \"" + mods.join(" ") + "\", key = \"" + entry.k + "\" }");
        } else if (entry.t === "named") {
            kbWindow.run(shift ? ["wtype", "-M", "shift", "-k", entry.k, "-m", "shift"] : ["wtype", "-k", entry.k]);
        } else {
            kbWindow.run(["wtype", "--", shift ? entry.s : entry.l]);
        }
        kbWindow.consumeOneShots();
    }

    // one process at a time, so held keys arrive in the order they were pressed
    function run(cmd) {
        if (kbWindow.queue.length > 24)
            return ;

        var q = kbWindow.queue.slice();
        q.push(cmd);
        kbWindow.queue = q;
        kbWindow.pump();
    }

    function pump() {
        if (typeProc.running || kbWindow.queue.length === 0)
            return ;

        var q = kbWindow.queue.slice();
        var next = q.shift();
        kbWindow.queue = q;
        typeProc.command = next;
        typeProc.running = true;
    }

    function setLayer(l) {
        st.keyLayer = l;
    }

    function resize(step) {
        st.keySize = Math.max(kbWindow.minKeySize, Math.min(kbWindow.maxKeySize, kbWindow.keySize + step));
    }

    color: "transparent"
    visible: kbWindow.rendered && Monitors.surfacesUp
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    // never. the window under the keyboard has to keep typing focus
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucidkeys"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onOpenChanged: {
        if (kbWindow.open) {
            kbWindow.rendered = true;
            hideTimer.stop();
        } else {
            kbWindow.clearMods();
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer

        interval: Theme.durExit + 60
        onTriggered: kbWindow.rendered = false
    }

    Process {
        id: typeProc

        onExited: kbWindow.pump()
    }

    Connections {
        function onActiveToplevelChanged() {
            if (ToplevelManager.activeToplevel)
                kbWindow.targetToplevel = ToplevelManager.activeToplevel;

        }

        target: ToplevelManager
    }

    FileView {
        id: stateFile

        path: Qt.resolvedUrl("./state.json")
        blockLoading: true
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: st

            property real panelX: -1
            property real panelY: -1
            property real keySize: 46
            property string keyLayer: "letters"
        }

    }

    KeyboardFace {
        id: face

        host: kbWindow
        x: kbWindow.panelX
        y: kbWindow.panelY + (kbWindow.open ? 0 : 22)
        width: implicitWidth
        height: implicitHeight
        opacity: kbWindow.open ? 1 : 0
        onCloseRequested: kbWindow.open = false
        onMovedTo: (px, py) => {
            return kbWindow.moveTo(px, py);
        }
        onDragFinished: kbWindow.dragEnd()

        // the entrance slide must not sit between the pointer and the panel
        Behavior on y {
            enabled: !face.dragging

            NumberAnimation {
                duration: kbWindow.open ? Theme.durEnter : Theme.durExit
                easing.type: Easing.BezierSpline
                easing.bezierCurve: kbWindow.open ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: kbWindow.open ? Theme.durEnter : Theme.durExit
                easing.type: Theme.easeStandard
            }

        }

    }

    // only the panel takes clicks. everywhere else has to reach the app, or you
    // could never put the caret in the field you are typing into
    mask: Region {
        x: Math.floor(face.x)
        y: Math.floor(face.y)
        width: Math.ceil(face.width)
        height: Math.ceil(face.height)
        radius: Theme.radiusXl
    }

    // the blur cannot fade with the panel, so it is tied to open, not rendered
    BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && kbWindow.open) ? panelBlurRegion : null

    Region {
        id: panelBlurRegion

        x: Math.ceil(face.x - 0.002)
        y: Math.ceil(face.y - 0.002)
        width: Math.max(0, Math.floor(face.x + face.width + 0.002) - Math.ceil(face.x - 0.002))
        height: Math.max(0, Math.floor(face.y + face.height + 0.002) - Math.ceil(face.y - 0.002))
        radius: Theme.radiusXl
    }

    IpcHandler {
        target: "keyboard"

        function toggle(): void {
            if (kbWindow.open)
                kbWindow.open = false;
            else
                kbWindow.show();
        }

        function open(): void {
            kbWindow.show();
        }

        function close(): void {
            kbWindow.open = false;
        }

        function letters(): void {
            kbWindow.setLayer("letters");
            kbWindow.show();
        }

        function fnkeys(): void {
            kbWindow.setLayer("function");
            kbWindow.show();
        }

        function center(): void {
            kbWindow.recentre();
        }

        function bigger(): void {
            kbWindow.resize(4);
        }

        function smaller(): void {
            kbWindow.resize(-4);
        }

    }

}
