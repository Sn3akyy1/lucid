import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: mojiWindow

    readonly property real panelW: 520
    readonly property real panelH: 600
    property bool open: false
    property bool dataRequested: false
    property var emojiGroups: []
    property var emojiData: []
    property var kaomojiGroups: []
    property var kaomojiData: []
    // "emoji" | "kaomoji" | "gif"
    property string tab: "emoji"
    property string lastCopied: ""
    property string lastAction: "Copied"
    property bool wtypeAvailable: false
    property bool handingOff: false
    property var typeQueue: []
    readonly property string clipDir: "/tmp/lucidmoji-clip"
    property bool clipReady: false
    property bool focusReady: false
    property var targetToplevel: null

    readonly property var recentEmoji: st.recentEmoji || []
    readonly property var recentKaomoji: st.recentKaomoji || []
    readonly property var recentGifs: st.recentGifs || []
    property var recentEmojiView: []
    property var recentKaomojiView: []
    property var recentGifsView: []
    readonly property var favEmoji: st.favEmoji || []
    readonly property var favKaomoji: st.favKaomoji || []
    readonly property var favGifs: st.favGifs || []
    // 0 = default yellow, 1..5 = fitzpatrick modifiers
    readonly property int skinTone: st.skinTone || 0
    readonly property string tenorKey: cfg.tenorKey || ""
    readonly property string giphyKey: cfg.giphyKey || ""
    readonly property var defaultPasteApps: ["vesktop", "discord", "webcord", "armcord", "slack", "element", "signal", "spotify", "code", "codium", "vscode", "obsidian", "notion", "teams", "chrome", "chromium", "brave", "edge"]
    readonly property var pasteApps: (cfg.pasteApps && cfg.pasteApps.length > 0) ? cfg.pasteApps : mojiWindow.defaultPasteApps
    readonly property string gifDir: cfg.gifDir !== "" ? cfg.gifDir : (Quickshell.env("HOME") + "/Pictures/GIFs")

    // -1 means never dragged, i.e. centred
    readonly property real panelX: st.panelX >= 0 ? Math.max(0, Math.min(width - panelW, st.panelX)) : (width - panelW) / 2
    readonly property real panelY: st.panelY >= 0 ? Math.max(0, Math.min(height - panelH, st.panelY)) : (height - panelH) / 2

    function snapshotRecents() {
        mojiWindow.recentEmojiView = mojiWindow.recentEmoji.slice();
        mojiWindow.recentKaomojiView = mojiWindow.recentKaomoji.slice();
        mojiWindow.recentGifsView = mojiWindow.recentGifs.slice();
    }

    function show(which) {
        mojiWindow.dataRequested = true;
        mojiWindow.snapshotRecents();
        if (which !== "")
            mojiWindow.tab = which;

        // must be read before open flips
        if (ToplevelManager.activeToplevel)
            mojiWindow.targetToplevel = ToplevelManager.activeToplevel;


        mojiWindow.open = true;
    }

    function toned(entry) {
        if (!entry)
            return "";

        if (mojiWindow.skinTone > 0 && entry.t && entry.t[mojiWindow.skinTone - 1])
            return entry.t[mojiWindow.skinTone - 1];

        return entry.e;
    }

    function setSkinTone(t) {
        st.skinTone = t;
    }

    function _pushCapped(list, value, cap, keyOf) {
        var out = [value];
        for (var i = 0; i < list.length && out.length < cap; i++) {
            if (keyOf(list[i]) !== keyOf(value))
                out.push(list[i]);

        }
        return out;
    }

    function _keyStr(v) {
        return v;
    }

    function _keyGif(v) {
        return v && v.url ? v.url : "";
    }

    function pushRecentEmoji(e) {
        st.recentEmoji = mojiWindow._pushCapped(mojiWindow.recentEmoji, e, 64, mojiWindow._keyStr);
    }

    function pushRecentKaomoji(e) {
        st.recentKaomoji = mojiWindow._pushCapped(mojiWindow.recentKaomoji, e, 64, mojiWindow._keyStr);
    }

    function pushRecentGif(gif) {
        st.recentGifs = mojiWindow._pushCapped(mojiWindow.recentGifs, gif, 48, mojiWindow._keyGif);
    }

    function _toggle(list, value, keyOf) {
        var out = [];
        var found = false;
        for (var i = 0; i < list.length; i++) {
            if (keyOf(list[i]) === keyOf(value))
                found = true;
            else
                out.push(list[i]);
        }
        if (!found)
            out.unshift(value);

        return out;
    }

    function clearRecents() {
        if (mojiWindow.tab === "kaomoji")
            st.recentKaomoji = [];
        else if (mojiWindow.tab === "gif")
            st.recentGifs = [];
        else
            st.recentEmoji = [];
        mojiWindow.snapshotRecents();
    }

    function isFavEmoji(e) {
        return mojiWindow.favEmoji.indexOf(e) !== -1;
    }

    function isFavKaomoji(e) {
        return mojiWindow.favKaomoji.indexOf(e) !== -1;
    }

    function isFavGif(url) {
        for (var i = 0; i < mojiWindow.favGifs.length; i++) {
            if (mojiWindow.favGifs[i].url === url)
                return true;

        }
        return false;
    }

    function toggleFavEmoji(e) {
        st.favEmoji = mojiWindow._toggle(mojiWindow.favEmoji, e, mojiWindow._keyStr);
    }

    function toggleFavKaomoji(e) {
        st.favKaomoji = mojiWindow._toggle(mojiWindow.favKaomoji, e, mojiWindow._keyStr);
    }

    function toggleFavGif(gif) {
        st.favGifs = mojiWindow._toggle(mojiWindow.favGifs, gif, mojiWindow._keyGif);
    }

    function copyText(t) {
        if (t === "")
            return ;

        Quickshell.execDetached(["wl-copy", "--", t]);
        mojiWindow.lastCopied = t;
        mojiWindow.lastAction = "Copied";
        copiedTimer.restart();
    }

    function insert(t) {
        if (t === "")
            return ;

        if (!mojiWindow.wtypeAvailable) {
            mojiWindow.copyText(t);
            return ;
        }
        var q = mojiWindow.typeQueue.slice();
        q.push(t);
        mojiWindow.typeQueue = q;
        mojiWindow.lastCopied = t;
        mojiWindow.lastAction = "Inserted";
        copiedTimer.restart();
        if (mojiWindow.handingOff)
            return ;

        mojiWindow.handingOff = true;
        mojiWindow.focusReady = false;
        if (mojiWindow.needsPaste())
            mojiWindow.pumpQueue();

        refocusTimer.restart();
    }

    function refocusTarget() {
        if (mojiWindow.targetToplevel)
            mojiWindow.targetToplevel.activate();

        typeTimer.restart();
    }

    function onFocusSettled() {
        if (mojiWindow.needsPaste()) {
            mojiWindow.focusReady = true;
            mojiWindow.tryPaste();
            return ;
        }
        mojiWindow.pumpQueue();
    }

    function needsPaste() {
        var id = (mojiWindow.targetToplevel && mojiWindow.targetToplevel.appId ? mojiWindow.targetToplevel.appId : "").toLowerCase();
        if (id === "")
            return false;

        for (var i = 0; i < mojiWindow.pasteApps.length; i++) {
            if (id.indexOf(String(mojiWindow.pasteApps[i]).toLowerCase()) !== -1)
                return true;

        }
        return false;
    }

    function pumpQueue() {
        if (mojiWindow.typeQueue.length === 0) {
            regrabTimer.restart();
            return ;
        }
        var q = mojiWindow.typeQueue.slice();
        var next = q.shift();
        mojiWindow.typeQueue = q;
        if (mojiWindow.needsPaste()) {
            mojiWindow.clipReady = false;
            clipProc.command = ["sh", "-c", "d=\"$2\"; rm -rf \"$d\"; mkdir -p \"$d\"; t=$(wl-paste --list-types 2>/dev/null | head -1); if [ -n \"$t\" ]; then printf '%s' \"$t\" > \"$d/type\"; wl-paste --type \"$t\" > \"$d/data\" 2>/dev/null; fi; printf '%s' \"$1\" | wl-copy", "sh", next, mojiWindow.clipDir];
            clipProc.running = true;
            return ;
        }
        typeProc.command = ["wtype", "--", next];
        typeProc.running = true;
    }

    function tryPaste() {
        if (!mojiWindow.clipReady || !mojiWindow.focusReady)
            return ;

        mojiWindow.clipReady = false;
        mojiWindow.focusReady = false;
        Hyprland.dispatch("hl.dsp.send_shortcut{ mods = \"CTRL\", key = \"v\" }");
        restoreTimer.restart();
    }

    function copyGifFile(path) {
        Quickshell.execDetached(["sh", "-c", "wl-copy --type image/gif < \"$1\"", "sh", path]);
        mojiWindow.lastCopied = path;
        copiedTimer.restart();
    }

    color: "transparent"
    visible: open
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && !handingOff ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucidmoji"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onOpenChanged: {
        if (mojiWindow.open)
            mojiWindow.dataRequested = true;

    }

    Timer {
        id: copiedTimer

        interval: 1400
        onTriggered: mojiWindow.lastCopied = ""
    }

    Timer {
        id: refocusTimer

        interval: 16
        onTriggered: mojiWindow.refocusTarget()
    }

    Timer {
        id: typeTimer

        interval: 45
        onTriggered: mojiWindow.onFocusSettled()
    }

    Timer {
        id: regrabTimer

        interval: 60
        onTriggered: mojiWindow.handingOff = false
    }

    Process {
        id: typeProc

        onExited: mojiWindow.pumpQueue()
    }

    Process {
        id: clipProc

        onExited: {
            mojiWindow.clipReady = true;
            mojiWindow.tryPaste();
        }
    }

    Timer {
        id: restoreTimer

        interval: 450
        onTriggered: {
            restoreProc.command = ["sh", "-c", "d=\"$1\"; t=$(cat \"$d/type\" 2>/dev/null); if [ -n \"$t\" ] && [ -s \"$d/data\" ]; then wl-copy --type \"$t\" < \"$d/data\"; fi; rm -rf \"$d\"", "sh", mojiWindow.clipDir];
            restoreProc.running = true;
        }
    }

    Process {
        id: restoreProc

        onExited: {
            if (mojiWindow.typeQueue.length > 0) {
                mojiWindow.focusReady = true;
                mojiWindow.pumpQueue();
                return ;
            }
            regrabTimer.restart();
        }
    }

    Process {
        id: wtypeCheck

        running: true
        command: ["sh", "-c", "command -v wtype >/dev/null 2>&1"]
        onExited: (code) => {
            mojiWindow.wtypeAvailable = code === 0;
        }
    }

    FileView {
        id: emojiFile

        path: mojiWindow.dataRequested ? Qt.resolvedUrl("./emoji.json") : ""
        onLoaded: {
            var d = JSON.parse(emojiFile.text());
            for (var i = 0; i < d.emoji.length; i++) {
                var it = d.emoji[i];
                it.s = it.n + " " + (it.k || "");
            }
            mojiWindow.emojiGroups = d.groups;
            mojiWindow.emojiData = d.emoji;
        }
    }

    FileView {
        id: kaomojiFile

        path: mojiWindow.dataRequested ? Qt.resolvedUrl("./kaomoji.json") : ""
        onLoaded: {
            var d = JSON.parse(kaomojiFile.text());
            for (var i = 0; i < d.kaomoji.length; i++) {
                var it = d.kaomoji[i];
                it.s = it.n + " " + (it.k || "");
            }
            mojiWindow.kaomojiGroups = d.groups;
            mojiWindow.kaomojiData = d.kaomoji;
        }
    }

    FileView {
        id: stateFile

        path: Qt.resolvedUrl("./state.json")
        blockLoading: true
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: st

            property var recentEmoji: []
            property var recentKaomoji: []
            property var recentGifs: []
            property var favEmoji: []
            property var favKaomoji: []
            property var favGifs: []
            property int skinTone: 0
            property real panelX: -1
            property real panelY: -1
        }

    }

    FileView {
        id: configFile

        path: Qt.resolvedUrl("./config.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: cfg

            // free key, email only: https://developers.giphy.com/dashboard/
            property string giphyKey: ""
            property string tenorKey: ""
            // empty -> ~/Pictures/GIFs
            property string gifDir: ""
            property var pasteApps: []
        }

    }

    MouseArea {
        anchors.fill: parent
        onClicked: mojiWindow.open = false
    }

    MojiFace {
        id: face

        host: mojiWindow
        x: mojiWindow.panelX
        y: mojiWindow.panelY
        width: mojiWindow.panelW
        height: mojiWindow.panelH
        onCloseRequested: mojiWindow.open = false
        onDragged: (dx, dy) => {
            st.panelX = Math.max(0, Math.min(mojiWindow.width - mojiWindow.panelW, mojiWindow.panelX + dx));
            st.panelY = Math.max(0, Math.min(mojiWindow.height - mojiWindow.panelH, mojiWindow.panelY + dy));
        }
    }

    BackgroundEffect.blurRegion: Theme.blurAmount > 0 && mojiWindow.open ? panelBlurRegion : null

    Region {
        id: panelBlurRegion

        x: Math.ceil(face.x - 0.002)
        y: Math.ceil(face.y - 0.002)
        width: Math.max(0, Math.floor(face.x + face.width + 0.002) - Math.ceil(face.x - 0.002))
        height: Math.max(0, Math.floor(face.y + face.height + 0.002) - Math.ceil(face.y - 0.002))
        radius: Theme.radiusXl
    }

    IpcHandler {
        target: "moji"

        function toggle(): void {
            if (mojiWindow.open)
                mojiWindow.open = false;
            else
                mojiWindow.show("");
        }

        function open(): void {
            mojiWindow.show("");
        }

        function close(): void {
            mojiWindow.open = false;
        }

        function emoji(): void {
            mojiWindow.show("emoji");
        }

        function kaomoji(): void {
            mojiWindow.show("kaomoji");
        }

        function gif(): void {
            mojiWindow.show("gif");
        }

        function center(): void {
            st.panelX = -1;
            st.panelY = -1;
        }

    }

}
