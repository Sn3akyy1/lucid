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
    // emoji.json is ~150KB and most sessions never open this panel, so the
    // parse is deferred until the first open instead of being paid on every
    // shell start. FileView with an empty path simply doesn't load.
    property bool dataRequested: false
    property var emojiGroups: []
    property var emojiData: []
    property var kaomojiGroups: []
    property var kaomojiData: []
    // "emoji" | "kaomoji" | "gif"
    property string tab: "emoji"
    // last thing sent, for the footer's confirmation line
    property string lastCopied: ""
    property string lastAction: "Copied"
    // typing needs wtype (virtual-keyboard protocol). Detected at startup so
    // the panel silently falls back to the clipboard when it isn't installed
    // rather than looking broken.
    property bool wtypeAvailable: false
    // true only during the focus hand-off: the panel drops keyboard focus so
    // the compositor restores it to the window underneath, wtype types into
    // *that*, then focus comes back here. Without this the synthetic keys
    // would land in this panel's own search box.
    property bool handingOff: false
    property var typeQueue: []
    readonly property string clipDir: "/tmp/lucidmoji-clip"
    // the two halves of a paste, raced against each other
    property bool clipReady: false
    property bool focusReady: false
    // the window that was focused when the panel opened. Captured up front:
    // once this layer takes keyboard focus the compositor deactivates that
    // toplevel, so ToplevelManager.activeToplevel is no longer usable by the
    // time an insert happens.
    property var targetToplevel: null

    readonly property var recentEmoji: st.recentEmoji || []
    readonly property var recentKaomoji: st.recentKaomoji || []
    readonly property var recentGifs: st.recentGifs || []
    // What the Recent views actually render. Snapshotted when the panel opens
    // and deliberately NOT live: using something from Recent bumps it to the
    // front of the stored list, and if the grid tracked that, tiles would
    // reshuffle under the cursor mid-click. The stored lists above stay
    // accurate; the reorder just becomes visible on the next open.
    property var recentEmojiView: []
    property var recentKaomojiView: []
    property var recentGifsView: []
    readonly property var favEmoji: st.favEmoji || []
    readonly property var favKaomoji: st.favKaomoji || []
    readonly property var favGifs: st.favGifs || []
    // 0 = default yellow, 1..5 = light -> dark Fitzpatrick modifiers
    readonly property int skinTone: st.skinTone || 0
    readonly property string tenorKey: cfg.tenorKey || ""
    // Giphy hands out keys with just an email; Tenor needs a Google Cloud
    // billing account. Whichever key is present wins, Giphy first.
    readonly property string giphyKey: cfg.giphyKey || ""
    // Chromium ignores the Unicode keysyms wtype synthesizes: ASCII arrives,
    // anything else (emoji, é, →) is silently dropped, and no wtype delay flag
    // changes that. Every Electron/Chromium app is affected, so those get
    // clipboard+Ctrl+V instead, with the clipboard put back afterwards.
    readonly property var defaultPasteApps: ["vesktop", "discord", "webcord", "armcord", "slack", "element", "signal", "spotify", "code", "codium", "vscode", "obsidian", "notion", "teams", "chrome", "chromium", "brave", "edge"]
    readonly property var pasteApps: (cfg.pasteApps && cfg.pasteApps.length > 0) ? cfg.pasteApps : mojiWindow.defaultPasteApps
    readonly property string gifDir: cfg.gifDir !== "" ? cfg.gifDir : (Quickshell.env("HOME") + "/Pictures/GIFs")

    // panel position: -1 means "never dragged", i.e. centred on screen
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

        // must be read before `open` flips - see targetToplevel above
        if (ToplevelManager.activeToplevel)
            mojiWindow.targetToplevel = ToplevelManager.activeToplevel;


        mojiWindow.open = true;
    }

    // applies the current skin tone to an emoji entry, falling back to the
    // toneless form for anything that has no variants
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

    // JsonAdapter only writes when the property itself is reassigned, so every
    // mutation here goes through a fresh array rather than an in-place splice
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
        // clearing is an explicit request to empty the list, so unlike a
        // reorder it should show up immediately rather than next open
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

    // argv form, never a shell string: emoji and kaomoji are full of quotes,
    // backslashes and parens that no amount of shell escaping survives cleanly
    function copyText(t) {
        if (t === "")
            return ;

        Quickshell.execDetached(["wl-copy", "--", t]);
        mojiWindow.lastCopied = t;
        mojiWindow.lastAction = "Copied";
        copiedTimer.restart();
    }

    // the primary action: type straight into whatever had focus before the
    // panel opened, falling back to the clipboard when wtype isn't installed
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
        // already handed off - pumpQueue() will pick this up when the current
        // wtype exits, so a fast second click isn't dropped
        if (mojiWindow.handingOff)
            return ;

        mojiWindow.handingOff = true;
        mojiWindow.focusReady = false;
        // clipboard work needs no focus, so start it now rather than after
        // the hand-off - the two run concurrently and the slower one wins
        if (mojiWindow.needsPaste())
            mojiWindow.pumpQueue();

        refocusTimer.restart();
    }

    // stage 2: with this layer's keyboard focus released, explicitly re-activate
    // the window that was focused when the panel opened. Relying on the
    // compositor to implicitly restore focus is what failed - dropping
    // keyboard_interactivity alone left focus nowhere, so wtype's keys went
    // into the void.
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
            // loading the clipboard needs no focus, so it runs *concurrently*
            // with the focus hand-off rather than after it - waiting on the
            // two in series was most of the visible lag. Whichever finishes
            // last fires the paste, via tryPaste().
            mojiWindow.clipReady = false;
            clipProc.command = ["sh", "-c", "d=\"$2\"; rm -rf \"$d\"; mkdir -p \"$d\"; t=$(wl-paste --list-types 2>/dev/null | head -1); if [ -n \"$t\" ]; then printf '%s' \"$t\" > \"$d/type\"; wl-paste --type \"$t\" > \"$d/data\" 2>/dev/null; fi; printf '%s' \"$1\" | wl-copy", "sh", next, mojiWindow.clipDir];
            clipProc.running = true;
            return ;
        }
        typeProc.command = ["wtype", "--", next];
        typeProc.running = true;
    }

    // fires only once both halves are done: the clipboard holds our text and
    // the target window has keyboard focus back
    function tryPaste() {
        if (!mojiWindow.clipReady || !mojiWindow.focusReady)
            return ;

        mojiWindow.clipReady = false;
        mojiWindow.focusReady = false;
        Hyprland.dispatch("hl.dsp.send_shortcut{ mods = \"CTRL\", key = \"v\" }");
        restoreTimer.restart();
    }

    // local .gif files go on the clipboard as image data rather than as a
    // path, so pasting into a chat window inserts the actual gif
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

    // stage 1 -> 2: let the layer's keyboard_interactivity change reach the
    // compositor before asking it to focus the target window
    Timer {
        id: refocusTimer

        interval: 16
        onTriggered: mojiWindow.refocusTarget()
    }

    // stage 2 -> 3: and let that focus change land before any keys are sent.
    // Electron apps take far longer than wtype targets: the window regains
    // focus quickly but the webview only restores focus to its text field a
    // few frames later, and a Ctrl+V that lands before that goes nowhere.
    Timer {
        id: typeTimer

        interval: 45
        onTriggered: mojiWindow.onFocusSettled()
    }

    // and a moment for the last keystroke to be delivered before this panel
    // asks for focus again
    Timer {
        id: regrabTimer

        interval: 60
        onTriggered: mojiWindow.handingOff = false
    }

    Process {
        id: typeProc

        onExited: mojiWindow.pumpQueue()
    }

    // clipboard is loaded -> send the paste keystroke. This goes through
    // Hyprland rather than `wtype -M ctrl -k v`: wtype's synthetic keymap
    // produces a Ctrl+V that VS Code ignores outright (Ctrl+A from the same
    // source works, so the keys do arrive - it's the scancode the keybinding
    // layer sees that's wrong). Hyprland's own dispatch is accepted.
    Process {
        id: clipProc

        onExited: {
            mojiWindow.clipReady = true;
            mojiWindow.tryPaste();
        }
    }

    // give the app time to actually read the clipboard before handing the
    // original contents back - the read happens asynchronously after the
    // keystroke, so restoring too early pastes the wrong thing
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
                // still focused on the target, so only the clipboard half
                // needs redoing for the next queued item
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
            // one lowercase haystack per entry, built once here rather than
            // re-joined for all 1900 entries on every keystroke
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
            // free key but needs a Google Cloud billing account:
            // https://developers.google.com/tenor/guides/quickstart
            property string tenorKey: ""
            // empty -> ~/Pictures/GIFs
            property string gifDir: ""
            // apps that need clipboard+paste instead of wtype (substring match
            // on the window's app id). Empty -> the built-in Electron/Chromium
            // list; set it to override.
            property var pasteApps: []
        }

    }

    // click anywhere outside the panel to dismiss, same as the dock's
    // click-catcher window
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

    // same real-compositor-blur treatment the bar pills get, scoped to just
    // the panel rect instead of this window's full-screen canvas
    BackgroundEffect.blurRegion: Theme.blurAmount > 0 && mojiWindow.open ? panelBlurRegion : null

    Region {
        id: panelBlurRegion

        item: face
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

        // drag it somewhere unreachable (or off a monitor you no longer have)
        // and this puts it back in the middle
        function center(): void {
            st.panelX = -1;
            st.panelY = -1;
        }

    }

}
