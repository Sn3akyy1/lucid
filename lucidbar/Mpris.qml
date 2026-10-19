import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland._FocusGrab
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs
import qs.lucidui


BarPill {
    id: root

    property string page: "player"
    readonly property var easeStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var easeEmphasized: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property int pad: Theme.dp(16)
    readonly property int contentWidth: root.panelWidth - root.pad * 2
    readonly property int artSize: Theme.dp(96)
    readonly property var mprisPlayers: {
        const out = [];
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p.dbusName && p.dbusName.indexOf("playerctld") !== -1)
                continue;

            out.push(p);
        }
        return out;
    }
    property string pinnedName: ""
    readonly property var player: {
        const list = root.mprisPlayers;
        if (root.pinnedName !== "") {
            for (let i = 0; i < list.length; i++) {
                if (list[i].dbusName === root.pinnedName)
                    return list[i];

            }
        }
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i];

        }
        for (let i = 0; i < list.length; i++) {
            const id = list[i].identity;
            if (id && id.toLowerCase().indexOf("spotify") !== -1)
                return list[i];

        }
        return list.length > 0 ? list[0] : null;
    }
    readonly property bool isPlaying: root.player ? root.player.isPlaying : false
    readonly property string title: root.player ? (root.player.trackTitle || "Unknown") : "Nothing playing"
    readonly property string artist: root.player ? root.player.trackArtist : ""
    readonly property string artUrl: root.player ? root.player.trackArtUrl : ""
    // clear the cached file:// url immediately when the track changes, so
    // artSource falls back to the remote url (or empty) while the new cover downloads
    onArtUrlChanged: root.localArt = ""
    // a remote cover is fetched into the cache and shown from there: an Image
    // fed the url itself makes Qt run the network stack, and its http/2 client
    // is what has been taking the shell down mid-session
    readonly property bool remoteArt: /^https?:/.test(root.artUrl)
    readonly property string artFile: {
        if (!root.remoteArt)
            return "";

        var h = 5381;
        for (var i = 0; i < root.artUrl.length; i++) h = ((h * 33) ^ root.artUrl.charCodeAt(i)) >>> 0
        return Quickshell.env("HOME") + "/.cache/lucid/art/" + h.toString(16) + ".img";
    }
    property string localArt: ""
    readonly property string artSource: root.remoteArt ? root.localArt : root.artUrl

    function fetchCover() {
        root.localArt = "";
        if (root.artFile !== "") {
            artFetch.running = false;
            artFetch.running = true;
        }
    }

    onArtFileChanged: root.fetchCover()
    Component.onCompleted: root.fetchCover()

    // shazam art follows the same pattern
    readonly property bool shazamRemoteArt: root.shazamResult && /^https?:/.test(root.shazamResult.art)
    readonly property string shazamArtFile: {
        if (!root.shazamRemoteArt || !root.shazamResult)
            return "";
        var h = 5381;
        var u = root.shazamResult.art;
        for (var i = 0; i < u.length; i++) h = ((h * 33) ^ u.charCodeAt(i)) >>> 0
        return Quickshell.env("HOME") + "/.cache/lucid/art/" + h.toString(16) + ".img";
    }
    property string shazamLocalArt: ""
    readonly property string shazamArtSource: root.shazamRemoteArt ? root.shazamLocalArt : (root.shazamResult ? root.shazamResult.art : "")

    function shazamFetch() {
        root.shazamLocalArt = "";
        if (root.shazamArtFile !== "") {
            shazamFetchProc.running = false;
            shazamFetchProc.running = true;
        }
    }

    onShazamArtFileChanged: root.shazamFetch()
    onShazamResultChanged: root.shazamFetch()

    Process {
        id: artFetch

        command: ["sh", "-c", "f=\"$1\"; d=\"$(dirname \"$f\")\"; mkdir -p \"$d\"; find \"$d\" -name '*.img' -mtime +14 -delete 2>/dev/null; [ -s \"$f\" ] || { t=\"$f.$$\"; curl -sfL --max-time 10 -o \"$t\" \"$2\" && mv \"$t\" \"$f\" && sync || rm -f \"$t\"; }; [ -s \"$f\" ]", "sh", root.artFile, root.artUrl]
        onExited: (code) => {
            if (code === 0)
                root.localArt = "file://" + root.artFile;

        }
    }

    Process {
        id: shazamFetchProc

        command: root.shazamResult ? ["sh", "-c", "f=\"$1\"; d=\"$(dirname \"$f\")\"; mkdir -p \"$d\"; find \"$d\" -name '*.img' -mtime +14 -delete 2>/dev/null; [ -s \"$f\" ] || { t=\"$f.$$\"; curl -sfL --max-time 10 -o \"$t\" \"$2\" && mv \"$t\" \"$f\" && sync || rm -f \"$t\"; }; [ -s \"$f\" ]", "sh", root.shazamArtFile, root.shazamResult.art] : []
        onExited: (code) => {
            if (code === 0)
                root.shazamLocalArt = "file://" + root.shazamArtFile;

        }
    }
    readonly property string sourceName: root.player ? (root.player.identity || "Media player") : ""
    // the cover across the top, or the record: either way the track goes under it
    readonly property bool heroLayout: (root.coverPanel || root.vinylPanel) && root.player !== null
    // concentric with the panel's own corner
    readonly property int innerRadius: Math.max(Theme.shapeMd, root.expandedRadius - root.pad)
    readonly property string displayTitle: (root.player && root.artist && Prefs.mediaArtist) ? root.artist + "  -  " + root.title : root.title
    // the looks picked on the module's card
    readonly property bool coverFace: Prefs.mediaStyle === "cover"
    readonly property bool compactFace: Prefs.mediaStyle === "compact"
    // the pill fills as the song goes, behind the turning cover and the track
    readonly property bool progressFace: Prefs.mediaStyle === "progress"
    // previous, play and next, then the track
    readonly property bool controlsFace: Prefs.mediaStyle === "controls"
    readonly property bool discFace: !root.coverFace && !root.compactFace && !root.controlsFace
    readonly property bool coverPanel: Prefs.mediaPanelStyle === "cover"
    // the cover as a record that turns while it plays, as the media widget's disc
    readonly property bool vinylPanel: Prefs.mediaPanelStyle === "vinyl"
    // side by side, over the cover blurred across the whole panel
    readonly property bool backdropPanel: Prefs.mediaPanelStyle === "backdrop"
    // side by side without the cover, narrower
    readonly property bool miniPanel: Prefs.mediaPanelStyle === "mini"
    readonly property real posSec: root.player ? root.player.position : 0
    readonly property real lenSec: root.player ? root.player.length : 0
    readonly property bool hasDuration: root.lenSec > 0
    property real livePosSec: root.posSec
    // set by the system pill while its media card is on screen
    property bool posWanted: false
    property real posBase: root.posSec
    property double posTimestamp: Date.now()
    property int jumpDuration: 0
    property bool snapNext: false
    readonly property real progress: root.hasDuration ? Math.min(1, root.livePosSec / root.lenSec) : 0
    property bool showRemaining: false
    readonly property bool volumeSupported: root.player ? root.player.volumeSupported : false
    readonly property real playerVolume: root.player ? root.player.volume : 0
    property bool volumeFlash: false
    // what a second click on the volume icon brings back
    property real unmuteVolume: 0.5
    property var bars: []
    // a single value means cava is not emitting raw ascii frames; fall back
    // rather than stretch one bar across the whole strip
    readonly property int barCount: root.bars.length > 1 ? root.bars.length : 24
    property string shazamState: "idle"
    property var shazamResult: null
    property string shazamError: ""
    property int listenElapsed: 0
    readonly property int listenLimit: 30
    // what the microphone itself hears while identify listens to it; cava only
    // ever hears the computer's own output, so its bars sat flat in the room
    readonly property bool micMetering: root.expanded && root.listenSource === "mic" && root.shazamState === "listening"
    property real micLevel: 0
    // the loudest it got during this listen, on the same -60..0 dB scale
    property real micHeard: 0
    property real micPhase: 0
    // under about -42 dB a fingerprint has nothing to hold on to
    readonly property bool micQuiet: root.listenSource === "mic" && root.micHeard < 0.3 && ((root.shazamState === "listening" && root.listenElapsed >= 4) || root.shazamState === "nomatch")
    readonly property int micVolume: Audio.source ? Audio.volumeOf(Audio.source) : 0
    property string listenSource: "system"
    property string monitorDevice: ""
    property string micDevice: ""
    readonly property string listenDevice: root.listenSource === "mic" ? root.micDevice : root.monitorDevice
    property double nowMs: Date.now()
    readonly property string noteGlyph: "music_note"
    readonly property string playGlyph: "play_arrow"
    readonly property string pauseGlyph: "pause"
    readonly property string prevGlyph: "skip_previous"
    readonly property string nextGlyph: "skip_next"
    readonly property string shuffleGlyph: "shuffle"
    readonly property string repeatGlyph: "repeat"
    readonly property string repeatOneGlyph: "repeat_one"
    readonly property string identifyGlyph: "graphic_eq"
    readonly property string backGlyph: "arrow_back"
    readonly property string openGlyph: "open_in_new"
    readonly property string copyGlyph: "content_copy"
    readonly property string searchGlyph: "search"
    readonly property string retryGlyph: "refresh"
    readonly property string trashGlyph: "delete"
    readonly property string micGlyph: "mic"
    readonly property string checkGlyph: "check"
    readonly property string swapGlyph: "swap_horiz"
    readonly property var volumeGlyphs: [
        { "max": 0, "path": "volume_mute" },
        { "max": 49, "path": "volume_down" },
        { "max": 100, "path": "volume_up" }
    ]

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    function agoText(ts, now) {
        const diff = Math.max(0, now - ts) / 1000;
        if (diff < 60)
            return "just now";

        if (diff < 3600)
            return Math.floor(diff / 60) + "m ago";

        if (diff < 86400)
            return Math.floor(diff / 3600) + "h ago";

        return Math.floor(diff / 86400) + "d ago";
    }

    function volumeGlyphFor(vol) {
        const pct = vol * 100;
        for (let i = 0; i < root.volumeGlyphs.length; i++) {
            if (pct <= root.volumeGlyphs[i].max)
                return root.volumeGlyphs[i].path;

        }
        return root.volumeGlyphs[root.volumeGlyphs.length - 1].path;
    }

    function barLevel(index) {
        const v = root.bars[index];
        return v === undefined ? 0 : Math.min(1, v / 70);
    }

    function bandLevel(from, to) {
        let peak = 0;
        for (let i = from; i <= to && i < root.bars.length; i++) peak = Math.max(peak, root.bars[i]);
        return Math.min(1, peak / 72);
    }

    function openPanel(target) {
        if (root.expanded)
            root.setPage(target);
        else
            root.page = target;
        root.expanded = true;
    }

    // the two pages push each other sideways, the way the System panel's views do
    function setPage(target) {
        if (root.page === target)
            return ;

        root.pageSwitching = true;
        pageSwitchTimer.restart();
        // must precede the assignment: writing page re-evaluates the height
        // binding synchronously, and the Behavior is consulted on that write
        root.beginTransition();
        root.page = target;
    }

    function togglePlay() {
        if (root.player && root.player.canTogglePlaying)
            root.player.togglePlaying();

    }

    function skip(direction) {
        if (!root.player)
            return ;

        if (direction > 0 && root.player.canGoNext)
            root.player.next();
        else if (direction < 0 && root.player.canGoPrevious)
            root.player.previous();

    }

    function seekTo(sec, glide) {
        if (!root.player || !root.player.canSeek)
            return ;

        const target = Math.max(0, Math.min(root.lenSec, sec));
        root.player.position = target;
        root.jumpDuration = glide ? 320 : 0;
        root.posBase = target;
        root.posTimestamp = Date.now();
        root.livePosSec = target;
    }

    function nudgeVolume(delta) {
        if (!root.player || !root.player.volumeSupported)
            return ;

        root.player.volume = Math.max(0, Math.min(1, root.player.volume + delta));
        root.volumeFlash = true;
        volumeFlashTimer.restart();
    }

    function toggleMute() {
        if (!root.player || !root.player.volumeSupported)
            return ;

        if (root.player.volume > 0) {
            root.unmuteVolume = root.player.volume;
            root.player.volume = 0;
        } else {
            root.player.volume = root.unmuteVolume > 0 ? root.unmuteVolume : 0.5;
        }
        root.volumeFlash = true;
        volumeFlashTimer.restart();
    }

    // the player's own window, or play and pause when it has none to show
    function raisePlayer() {
        if (root.player && root.player.canRaise)
            root.player.raise();
        else
            root.togglePlay();
    }

    function cyclePlayer() {
        const list = root.mprisPlayers;
        if (list.length < 2)
            return ;

        let index = 0;
        for (let i = 0; i < list.length; i++) {
            if (list[i] === root.player) {
                index = i;
                break;
            }
        }
        root.pinnedName = list[(index + 1) % list.length].dbusName;
    }

    function cycleLoop() {
        if (!root.player || !root.player.loopSupported)
            return ;

        const state = root.player.loopState;
        if (state === MprisLoopState.None)
            root.player.loopState = MprisLoopState.Playlist;
        else if (state === MprisLoopState.Playlist)
            root.player.loopState = MprisLoopState.Track;
        else
            root.player.loopState = MprisLoopState.None;
    }

    function openUrl(url) {
        if (!url || url === "")
            return ;

        Quickshell.execDetached(["xdg-open", url]);
    }

    function copyText(text) {
        if (!text || text === "")
            return ;

        Quickshell.execDetached(["wl-copy", "--", text]);
    }

    function searchOnline(result) {
        if (!result)
            return ;

        if (result.spotify && result.spotify !== "") {
            root.openUrl(result.spotify);
            return ;
        }
        root.openUrl("https://open.spotify.com/search/" + encodeURIComponent(result.title + " " + result.artist));
    }

    // album/label/released live in a generic metadata list
    function metaValue(track, key) {
        const sections = (track && track.sections) || [];
        for (let i = 0; i < sections.length; i++) {
            const meta = sections[i].metadata || [];
            for (let j = 0; j < meta.length; j++) {
                if (meta[j].title === key)
                    return meta[j].text || "";

            }
        }
        return "";
    }

    function providerUri(track, kind) {
        const providers = (track && track.hub && track.hub.providers) || [];
        for (let i = 0; i < providers.length; i++) {
            if (providers[i].type !== kind)
                continue;

            const actions = providers[i].actions || [];
            if (actions.length > 0 && actions[0].uri)
                return actions[0].uri;

        }
        return "";
    }

    function handleShazamLine(line) {
        const text = line.trim();
        // songrec prints one json object per match
        if (text === "" || text.charAt(0) !== "{")
            return ;

        let payload = null;
        try {
            payload = JSON.parse(text);
        } catch (e) {
            return ;
        }
        const track = payload.track;
        if (!track)
            return ;

        const images = track.images || {};
        const result = {
            "key": track.key || "",
            "title": track.title || "Unknown",
            "artist": track.subtitle || "",
            "album": root.metaValue(track, "Album"),
            "year": root.metaValue(track, "Released"),
            "label": root.metaValue(track, "Label"),
            "genre": (track.genres && track.genres.primary) || "",
            "art": images.coverarthq || images.coverart || "",
            "url": track.url || (track.share && track.share.href) || "",
            "spotify": root.providerUri(track, "SPOTIFY"),
            "at": Date.now()
        };
        root.stopListening();
        root.shazamResult = result;
        root.shazamState = "match";
        root.rememberMatch(result);
    }

    function handleShazamStderr(line) {
        if (line.indexOf("ERROR") === -1)
            return ;

        root.shazamError = line.trim();
        console.log("[mpris-shazam]", line.trim());
    }

    // five bars from one level, each its own height and sway
    function micBar(index) {
        const shape = [0.55, 0.85, 1, 0.8, 0.5];
        return root.micLevel * shape[index] * (0.8 + 0.2 * Math.sin(root.micPhase + index * 1.7));
    }

    function startListening() {
        root.shazamError = "";
        root.shazamResult = null;
        root.listenElapsed = 0;
        root.micHeard = 0;
        root.shazamState = "listening";
        sinkProc.running = true;
        sourceProc.running = true;
        captureStartTimer.restart();
        listenLimitTimer.restart();
        listenTickTimer.restart();
    }

    function stopListening() {
        captureStartTimer.stop();
        listenLimitTimer.stop();
        listenTickTimer.stop();
        if (songrecProc.running)
            songrecProc.running = false;

    }

    function cancelListening() {
        root.stopListening();
        root.shazamState = "idle";
    }

    function rememberMatch(result) {
        const items = (historyAdapter.items || []).slice();
        if (items.length > 0 && items[0].key === result.key)
            items[0] = result;
        else
            items.unshift(result);
        historyAdapter.items = items.slice(0, 12);
    }

    function clearHistory() {
        historyAdapter.items = [];
    }

    onPosSecChanged: {
        const delta = Math.abs(root.posSec - root.livePosSec);
        root.jumpDuration = (root.snapNext || delta < 1.5) ? 0 : 320;
        root.snapNext = false;
        root.posBase = root.posSec;
        root.posTimestamp = Date.now();
        root.livePosSec = root.posSec;
    }
    onPlayerChanged: root.snapNext = true
    onIsPlayingChanged: {
        root.posBase = root.livePosSec;
        root.posTimestamp = Date.now();
    }
    onPageChanged: {
        if (root.page !== "shazam")
            return ;

        sinkProc.running = true;
        sourceProc.running = true;
    }
    // gates the slide, so the first layout and the reset on close do not animate
    property bool pageSwitching: false

    Timer {
        id: pageSwitchTimer

        interval: Theme.barMs(600)
        onTriggered: root.pageSwitching = false
    }

    onExpandedChanged: {
        if (root.expanded)
            return ;

        root.page = "player";
        root.cancelListening();
    }

    shown: Prefs.barHas("media") && !(Prefs.mediaHideIdle && root.player === null)

    compactWidth: compactRow.implicitWidth + Theme.dp(20)
    panelWidth: Math.min(root.miniPanel ? Theme.dp(320) : Theme.dp(400), root.screenW - Theme.dp(34))
    panelHeight: root.pad * 2 + (root.page === "player" ? playerColumn.implicitHeight : shazamColumn.implicitHeight)
    expandedRadius: Theme.radiusXl
    compactCollapseScale: 0.94
    compactInteractive: false
    surfaceLayered: true

    // the "media" ipc target lives in shell.qml, which can have a bar per display

    FileView {
        id: historyFile

        path: Qt.resolvedUrl("./mpris_shazam.json")
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: historyAdapter

            property var items: []
        }

    }

    // mpris doesn't auto-tick position
    Timer {
        interval: 1000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.player)
                root.player.positionChanged();

        }
    }

    // livePosSec is read only by this pill's own panel and the system pill's
    // media card, both closed most of the time. a per-frame interpolation behind
    // a closed panel measured ~18% of a core, so it waits until something shows it
    FrameAnimation {
        running: root.isPlaying && !trackHitArea.dragging && (root.expanded || root.posWanted)
        onTriggered: root.livePosSec = Math.min(root.lenSec, root.posBase + (Date.now() - root.posTimestamp) / 1000)
    }

    Connections {
        function onTrackChanged() {
            root.snapNext = true;
            root.fetchCover();
        }

        target: root.player
    }

    Timer {
        id: volumeFlashTimer

        interval: 1100
        onTriggered: root.volumeFlash = false
    }

    PwNodePeakMonitor {
        id: micPeak

        node: root.micMetering ? Audio.source : null
        enabled: root.micMetering
    }

    // the settings level meter's scale: linear peaks sit near zero until it is loud
    Timer {
        interval: 33
        repeat: true
        running: root.micMetering
        onTriggered: {
            const p = micPeak.peak;
            const target = p > 0.001 ? Math.max(0, Math.min(1, (20 * Math.log10(p) + 60) / 60)) : 0;
            root.micLevel = target > root.micLevel ? target : Math.max(target, root.micLevel - 0.04);
            root.micHeard = Math.max(root.micHeard, target);
            root.micPhase += 0.35;
        }
    }

    Timer {
        id: listenTickTimer

        interval: 1000
        repeat: true
        onTriggered: root.listenElapsed++
    }

    Timer {
        id: captureStartTimer

        interval: 400
        onTriggered: {
            if (root.shazamState === "listening")
                songrecProc.running = true;

        }
    }

    Timer {
        id: listenLimitTimer

        interval: root.listenLimit * 1000
        onTriggered: {
            root.stopListening();
            root.shazamState = "nomatch";
        }
    }

    Timer {
        interval: 30000
        running: root.expanded && root.page === "shazam"
        repeat: true
        triggeredOnStart: true
        onTriggered: root.nowMs = Date.now()
    }

    Process {
        id: cavaProc

        // silence costs the same as sound to capture and parse, so only listen
        // while the pill's bars can dance or the panel is open on the waveform
        running: (root.isPlaying && compactBars.visible) || root.expanded
        command: ["cava", "-p", Quickshell.env('HOME') + "/.config/cava/quickshell.conf"]
        onRunningChanged: {
            if (!cavaProc.running && root.bars.length > 0)
                root.bars = new Array(root.bars.length).fill(0);

        }

        stdout: SplitParser {
            onRead: (line) => {
                const raw = line.trim().split(" ");
                const prev = root.bars;
                const out = new Array(raw.length);
                for (let i = 0; i < raw.length; i++) {
                    const v = parseInt(raw[i]) || 0;
                    const p = prev[i];
                    out[i] = (p === undefined || v >= p) ? v : p * 0.82 + v * 0.18;
                }
                root.bars = out;
            }
        }

    }

    Process {
        id: sinkProc

        running: true
        command: ["pactl", "get-default-sink"]

        stdout: StdioCollector {
            id: sinkCollector

            onStreamFinished: {
                const name = sinkCollector.text.trim();
                root.monitorDevice = name === "" ? "" : name + ".monitor";
            }
        }

    }

    Process {
        id: sourceProc

        running: true
        command: ["pactl", "get-default-source"]

        stdout: StdioCollector {
            id: sourceCollector

            onStreamFinished: root.micDevice = sourceCollector.text.trim()
        }

    }

    Process {
        id: songrecProc

        command: root.listenDevice !== "" ? ["songrec", "recognize", "-j", "-d", root.listenDevice] : ["songrec", "recognize", "-j"]

        stdout: SplitParser {
            onRead: (line) => {
                return root.handleShazamLine(line);
            }
        }

        stderr: SplitParser {
            onRead: (line) => {
                return root.handleShazamStderr(line);
            }
        }

        onExited: (exitCode, exitStatus) => {
            const wasListening = root.shazamState === "listening";
            root.stopListening();
            if (!wasListening)
                return ;

            root.shazamState = (exitCode === 0 && root.shazamError === "") ? "nomatch" : "error";
        }
    }

    compactContent: [
        // Progress: the pill fills, as a capsule, as the song goes
        Rectangle {
            readonly property real track: parent.width - Theme.dp(8)

            visible: root.progressFace && root.player !== null && width > 0
            x: Theme.dp(4)
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - Theme.dp(8)
            // nothing before the song starts, then never thinner than it is tall
            width: root.hasDuration && root.posSec > 0 ? Math.max(height, track * Math.min(1, root.posSec / root.lenSec)) : 0
            radius: height / 2
            color: Theme.alpha(Theme.accent, 0.28)
        },
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onEntered: root.compactHovered = true
            onExited: root.compactHovered = false
            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton)
                    root.skip(1);
                else if (mouse.button === Qt.RightButton)
                    root.skip(-1);
                else if (root.popupMode && root.expanded)
                    root.expanded = false;
                else
                    root.openPanel("player");
            }
            onWheel: (wheel) => {
                if (!Prefs.mediaWheelVolume) {
                    wheel.accepted = false;
                    return ;
                }
                root.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
            }
        },

        Row {
            id: compactRow

            anchors.centerIn: parent
            spacing: Theme.dp(8)

            // Controls: previous, play and next before the track
            Row {
                visible: root.controlsFace && root.player !== null
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(2)

                BarSkip {
                    glyph: root.prevGlyph
                    enabled: root.player !== null && root.player.canGoPrevious
                    onActivated: root.skip(-1)
                }

                Rectangle {
                    width: Math.round(Theme.dp(24) * 1.3)
                    height: Theme.dp(24)
                    radius: controlsPlay.pressed ? Theme.dp(8) : Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                    opacity: root.player !== null && root.player.canTogglePlaying ? 1 : 0.4

                    Icon {
                        anchors.centerIn: parent
                        name: root.isPlaying ? root.pauseGlyph : root.playGlyph
                        size: Theme.dp(16)
                        fill: 1
                        color: Theme.fgAccent
                    }

                    StateLayer {
                        id: controlsPlay

                        radius: parent.radius
                        tint: Theme.fgAccent
                        disabled: !(root.player !== null && root.player.canTogglePlaying)
                        onClicked: root.togglePlay()
                    }

                }

                BarSkip {
                    glyph: root.nextGlyph
                    enabled: root.player !== null && root.player.canGoNext
                    onActivated: root.skip(1)
                }

            }

            Item {
                visible: !(root.controlsFace && root.player !== null)
                width: root.coverFace ? Theme.dp(22) : Theme.dp(26)
                height: width
                anchors.verticalCenter: parent.verticalCenter

                CircularProgress {
                    anchors.fill: parent
                    // the Progress look shows it in the pill's fill instead
                    visible: root.player !== null && !root.coverFace && !root.progressFace
                    value: root.lenSec > 0 ? root.posSec / root.lenSec : 0
                    thickness: 2.5
                    color: Theme.accent
                    trackColor: Theme.alpha(Theme.subtext, 0.22)
                }

                ClippingRectangle {
                    id: compactArt

                    anchors.centerIn: parent
                    width: Theme.dp(18)
                    height: Theme.dp(18)
                    radius: Theme.dp(9)
                    color: Theme.surfaceHighest
                    visible: root.player !== null && compactArtImg.status === Image.Ready && root.discFace

                    Image {
                        id: compactArtImg

                        anchors.fill: parent
                        source: root.discFace ? root.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Theme.dp(64)
                        sourceSize.height: Theme.dp(64)
                    }

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 14000
                        loops: Animation.Infinite
                        running: root.isPlaying && compactArt.visible
                    }

                }

                // the cover look: the album art standing still, squared off
                ClippingRectangle {
                    id: coverArt

                    anchors.fill: parent
                    radius: Theme.dp(6)
                    color: Theme.surfaceHighest
                    visible: root.player !== null && coverArtImg.status === Image.Ready

                    Image {
                        id: coverArtImg

                        anchors.fill: parent
                        source: root.coverFace ? root.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Theme.dp(64)
                        sourceSize.height: Theme.dp(64)
                    }

                }

                Row {
                    id: compactBars

                    anchors.centerIn: parent
                    spacing: Theme.dp(2)
                    visible: root.player !== null && !compactArt.visible && !coverArt.visible

                    Repeater {
                        model: 3

                        Rectangle {
                            required property int index

                            width: 2.5
                            radius: Theme.dp(999)
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                            height: root.isPlaying ? Math.max(Theme.dp(3), root.bandLevel(1 + index * 11, 10 + index * 11) * 11) : Theme.dp(3)

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.barMs(90)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

                Icon {
                    anchors.centerIn: parent
                    visible: root.player === null
                    name: "music_note"
                    size: Theme.dp(16)
                    fill: 1
                    color: Theme.accent
                }

            }

            Item {
                id: compactTitleSlot

                visible: !root.compactFace || root.volumeFlash
                width: root.volumeFlash ? volumeFlashRow.implicitWidth : Math.min(Theme.dp(Prefs.mediaTitleWidth), Math.max(Theme.dp(60), compactTitle.naturalWidth))
                height: Theme.dp(18)
                anchors.verticalCenter: parent.verticalCenter

                Marquee {
                    id: compactTitle

                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    content: root.displayTitle
                    scrolling: root.isPlaying
                    bold: true
                    pixelSize: Theme.fs(13)
                    opacity: root.volumeFlash ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(140)
                        }

                    }

                }

                Row {
                    id: volumeFlashRow

                    anchors.centerIn: parent
                    spacing: Theme.dp(5)
                    opacity: root.volumeFlash ? 1 : 0

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.playerVolume <= 0 ? "volume_off" : (root.playerVolume < 0.5 ? "volume_down" : "volume_up")
                        size: Theme.dp(16)
                        fill: 1
                        color: Theme.accent
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        size: Theme.fs(13)
                        weight: 640
                        text: Math.round(root.playerVolume * 100) + "%"
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(140)
                        }

                    }

                }

            }

            Rectangle {
                visible: Prefs.mediaPlayButton && !(root.controlsFace && root.player !== null)
                width: Math.round(Theme.dp(24) * 1.3)
                height: Theme.dp(24)
                radius: playArea.pressed ? Theme.dp(8) : Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.accent
                opacity: root.player !== null && root.player.canTogglePlaying ? 1 : 0.4

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

                Icon {
                    anchors.centerIn: parent
                    name: root.isPlaying ? "pause" : "play_arrow"
                    size: Theme.dp(16)
                    fill: 1
                    color: Theme.fgAccent
                }

                StateLayer {
                    id: playArea

                    radius: parent.radius
                    tint: Theme.fgAccent
                    disabled: !(root.player !== null && root.player.canTogglePlaying)
                    onClicked: root.togglePlay()
                }

            }

        }
    ]

    panelContent: [
    // backdrop: the cover blurred across the whole panel, under a scrim the
    // text reads on. clipped to the panel's own corners
    ClippingRectangle {
        anchors.fill: parent
        topLeftRadius: root.popupItem.topLeftRadius
        topRightRadius: root.popupItem.topRightRadius
        bottomLeftRadius: root.popupItem.bottomLeftRadius
        bottomRightRadius: root.popupItem.bottomRightRadius
        color: "transparent"
        visible: root.backdropPanel && root.player !== null && backdropArt.status === Image.Ready

        Image {
            id: backdropArt

            anchors.fill: parent
            source: root.backdropPanel ? root.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
            sourceSize.height: 256
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: backdropArt
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.2
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bgOpaque, 0.6)
        }

    },
    Item {
        id: playerPage

        // anchors would pin x, so the page is placed and sized by hand
        y: 0
        width: parent.width
        height: parent.height
        x: root.page === "player" ? 0 : -root.panelWidth
        visible: playerPage.x > -root.panelWidth + 0.5

        Behavior on x {
            enabled: root.pageSwitching

            NumberAnimation {
                duration: root.morphDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: root.morphEasing
            }

        }

        Column {
            id: playerColumn

            x: root.pad
            y: root.pad
            width: root.contentWidth
            spacing: Theme.dp(12)

            // large cover: the art across the panel, where it plays from on a chip
            Item {
                id: heroCover

                width: root.contentWidth
                height: Math.round(root.contentWidth * 0.56)
                visible: root.heroLayout && root.coverPanel

                // the cover with its hover hint; a click raises the player, or plays and pauses
                Item {
                    anchors.fill: parent

                    RoundedArt {
                        anchors.fill: parent
                        source: root.artSource
                        shapeRadius: root.innerRadius
                        decode: Theme.dp(512)
                        fallbackGlyph: Math.round(Math.min(parent.width, parent.height) * 0.32)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.innerRadius
                        color: "black"
                        opacity: heroArtArea.containsMouse ? 0.35 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barMs(150)
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Icon {
                        anchors.centerIn: parent
                        name: root.player && root.player.canRaise ? root.openGlyph : (root.isPlaying ? root.pauseGlyph : root.playGlyph)
                        size: Theme.dp(24)
                        fill: 1
                        color: "white"
                        opacity: heroArtArea.containsMouse ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barMs(150)
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    MouseArea {
                        id: heroArtArea

                        anchors.fill: parent
                        enabled: root.player !== null
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.raisePlayer()
                    }

                }

                // the wheel over the cover sets the player's volume
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        return root.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                    }
                }

                // with several players a click on it moves to the next
                Rectangle {
                    id: sourceChip

                    readonly property bool many: root.mprisPlayers.length > 1

                    x: Theme.dp(10)
                    y: Theme.dp(10)
                    width: chipRow.implicitWidth + Theme.dp(20)
                    height: Theme.dp(26)
                    radius: height / 2
                    color: Theme.alpha(Theme.bg, 0.88)
                    visible: root.sourceName !== ""

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: Theme.dp(4)

                        LText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "labelMedium"
                            color: Theme.text
                            text: root.sourceName
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: sourceChip.many
                            name: root.swapGlyph
                            size: Theme.dp(14)
                            color: Theme.text
                        }

                    }

                    StateLayer {
                        radius: parent.radius
                        tint: Theme.text
                        disabled: !sourceChip.many
                        onClicked: root.cyclePlayer()
                    }

                }

            }

            // vinyl: the cover as a record that turns while it plays, ringed by the
            // track's progress, as the media widget's disc. a click plays and pauses
            Item {
                id: vinyl

                width: root.contentWidth
                height: Math.round(root.contentWidth * 0.62)
                visible: root.heroLayout && root.vinylPanel

                // the wheel over it sets the player's volume
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        return root.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                    }
                }

                CircularProgress {
                    anchors.centerIn: parent
                    width: vinyl.height
                    height: width
                    thickness: Theme.dp(6)
                    value: root.progress
                    animated: false
                    color: Theme.accent
                    trackColor: Theme.alpha(Theme.text, 0.14)
                }

                ShapedImage {
                    id: record

                    anchors.centerIn: parent
                    width: vinyl.height - Theme.dp(24)
                    height: width
                    shape: "cookie12"
                    source: root.vinylPanel ? root.artUrl : ""
                    decode: Theme.dp(384)
                    fallbackColor: Theme.alpha(Theme.text, 0.1)

                    // only while it can be seen
                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 24000
                        loops: Animation.Infinite
                        running: root.isPlaying && root.expanded && vinyl.visible
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !record.ready
                        name: "album"
                        size: record.width * 0.4
                        color: Theme.subtextDim
                    }

                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.dp(56)
                    height: Theme.dp(56)
                    radius: vinylTap.pressed ? Theme.dp(16) : Theme.dp(28)
                    color: Theme.accent
                    opacity: vinylHover.hovered || !root.isPlaying ? 1 : 0
                    scale: vinylHover.hovered || !root.isPlaying ? 1 : 0.7

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durDefaultEffects
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                    Icon {
                        anchors.centerIn: parent
                        name: root.isPlaying ? root.pauseGlyph : root.playGlyph
                        size: Theme.dp(30)
                        fill: 1
                        color: Theme.fgAccent
                    }

                    StateLayer {
                        id: vinylTap

                        radius: parent.radius
                        tint: Theme.fgAccent
                        disabled: !(root.player !== null && root.player.canTogglePlaying)
                        onClicked: root.togglePlay()
                    }

                }

                HoverHandler {
                    id: vinylHover
                }

                // where it plays from; with several players a click moves to the next
                Rectangle {
                    id: vinylSource

                    readonly property bool many: root.mprisPlayers.length > 1

                    width: vinylSourceRow.implicitWidth + Theme.dp(20)
                    height: Theme.dp(26)
                    radius: height / 2
                    color: Theme.alpha(Theme.bg, 0.88)
                    visible: root.sourceName !== ""

                    Row {
                        id: vinylSourceRow

                        anchors.centerIn: parent
                        spacing: Theme.dp(4)

                        LText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "labelMedium"
                            color: Theme.text
                            text: root.sourceName
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: vinylSource.many
                            name: root.swapGlyph
                            size: Theme.dp(14)
                            color: Theme.text
                        }

                    }

                    StateLayer {
                        radius: parent.radius
                        tint: Theme.text
                        disabled: !vinylSource.many
                        onClicked: root.cyclePlayer()
                    }

                }

            }

            Item {
                id: heroInfo

                width: root.contentWidth
                height: Theme.dp(46)
                visible: root.heroLayout

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.dp(62)
                    spacing: Theme.dp(1)
                    opacity: heroVol.open ? 0 : 1

                    Marquee {
                        width: parent.width
                        content: root.title
                        scrolling: root.isPlaying
                        bold: true
                        weight: 600
                        textColor: Theme.text
                        pixelSize: Theme.typeSize("titleLarge")
                    }

                    Marquee {
                        width: parent.width
                        visible: content !== ""
                        content: root.artist
                        scrolling: root.isPlaying
                        textColor: Theme.subtext
                        pixelSize: Theme.typeSize("bodyMedium")
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barDurShort
                        }

                    }

                }

                IconButton {
                    anchors.right: heroVol.left
                    anchors.verticalCenter: parent.verticalCenter
                    size: "xs"
                    icon: root.identifyGlyph
                    tintOverride: Theme.subtext
                    opacity: heroVol.open ? 0 : 1
                    visible: opacity > 0.01
                    onClicked: root.openPanel("shazam")

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barDurShort
                        }

                    }

                }

                // the slider slides out of its icon over the track while the pointer or the wheel wants it
                Item {
                    id: heroVol

                    readonly property bool open: root.volumeSupported && (heroVolHover.hovered || heroVolSlider.dragging || root.volumeFlash)

                    anchors.right: parent.right
                    anchors.rightMargin: -Theme.dp(6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: heroVolSlot.width + heroVolBtn.width
                    height: Theme.dp(30)
                    visible: root.volumeSupported

                    HoverHandler {
                        id: heroVolHover
                    }

                    Item {
                        id: heroVolSlot

                        anchors.right: heroVolBtn.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: heroVol.open ? heroInfo.width - heroVolBtn.width + Theme.dp(6) : 0
                        height: parent.height
                        clip: true

                        Slider {
                            id: heroVolSlider

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(6)
                            anchors.verticalCenter: parent.verticalCenter
                            width: heroInfo.width - heroVolBtn.width
                            trackH: Theme.dp(8)
                            handleH: Theme.dp(22)
                            value: root.playerVolume
                            showValue: false
                            activeColor: Theme.accent
                            inactiveColor: Theme.withBlur(Theme.bgHigh)
                            opacity: heroVol.open ? 1 : 0
                            onMoved: (v) => {
                                if (root.player)
                                    root.player.volume = v;

                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.barDurShort
                                }

                            }

                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.barDurMedium
                                easing.type: Easing.Bezier
                                easing.bezierCurve: root.easeEmphasized
                            }

                        }

                    }

                    IconButton {
                        id: heroVolBtn

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        size: "xs"
                        icon: root.playerVolume <= 0 ? "volume_off" : root.volumeGlyphFor(root.playerVolume)
                        tintOverride: heroVol.open ? Theme.accent : Theme.subtext
                        onClicked: root.toggleMute()
                    }

                }

            }

            // side by side: the cover beside the track, where it plays from and the volume
            Item {
                id: trackHeader

                // mini leaves the cover out and the track takes its place
                readonly property int infoX: root.miniPanel ? 0 : root.artSize + Theme.dp(14)

                width: root.contentWidth
                height: root.artSize
                visible: !root.heroLayout

                // the wheel anywhere over the track sets the player's volume
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        return root.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                    }
                }

                // the cover with its hover hint; a click raises the player, or plays and pauses
                Item {
                    visible: !root.miniPanel
                    width: root.artSize
                    height: root.artSize

                    RoundedArt {
                        anchors.fill: parent
                        source: root.artSource
                        shapeRadius: Theme.shapeLg
                        fallbackGlyph: Math.round(Math.min(parent.width, parent.height) * 0.32)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shapeLg
                        color: "black"
                        opacity: sideArtArea.containsMouse ? 0.35 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barMs(150)
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Icon {
                        anchors.centerIn: parent
                        name: root.player && root.player.canRaise ? root.openGlyph : (root.isPlaying ? root.pauseGlyph : root.playGlyph)
                        size: Theme.dp(24)
                        fill: 1
                        color: "white"
                        opacity: sideArtArea.containsMouse ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barMs(150)
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    MouseArea {
                        id: sideArtArea

                        anchors.fill: parent
                        enabled: root.player !== null
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.raisePlayer()
                    }

                }

                Column {
                    x: trackHeader.infoX
                    y: root.player !== null ? Theme.dp(2) : Math.round((root.artSize - height) / 2)
                    width: root.contentWidth - trackHeader.infoX - Theme.dp(28)
                    spacing: Theme.dp(1)

                    Marquee {
                        width: parent.width
                        content: root.title
                        scrolling: root.isPlaying
                        bold: true
                        weight: 600
                        textColor: Theme.text
                        pixelSize: Theme.typeSize("titleMedium")
                    }

                    Marquee {
                        width: parent.width
                        visible: content !== ""
                        content: root.player !== null ? root.artist : "Start something and it lands here"
                        scrolling: root.isPlaying
                        textColor: Theme.subtext
                        pixelSize: Theme.typeSize("bodyMedium")
                    }

                    // where it plays from; with several players a click moves to the next
                    Item {
                        id: sourceBtn

                        readonly property bool many: root.mprisPlayers.length > 1

                        x: -Theme.dp(6)
                        width: sourceRow.implicitWidth + Theme.dp(12)
                        height: Theme.dp(22)
                        visible: root.player !== null

                        StateLayer {
                            radius: height / 2
                            tint: Theme.text
                            disabled: !sourceBtn.many
                            onClicked: root.cyclePlayer()
                        }

                        Row {
                            id: sourceRow

                            x: Theme.dp(6)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.dp(4)

                            LText {
                                id: sourceLabel

                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(Math.ceil(sourceMetrics.advanceWidth), root.contentWidth - trackHeader.infoX - Theme.dp(60))
                                role: "labelMedium"
                                color: Theme.subtextDim
                                text: root.sourceName
                                elide: Text.ElideRight
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: sourceBtn.many
                                name: root.swapGlyph
                                size: Theme.dp(14)
                                color: Theme.subtextDim
                            }

                        }

                        TextMetrics {
                            id: sourceMetrics

                            font: sourceLabel.font
                            text: root.sourceName
                        }

                    }

                }

                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: -Theme.dp(6)
                    anchors.top: parent.top
                    size: "xs"
                    visible: root.player !== null
                    icon: root.identifyGlyph
                    tintOverride: Theme.subtext
                    onClicked: root.openPanel("shazam")
                }

                // the player's own volume; its icon mutes and unmutes
                Item {
                    x: trackHeader.infoX - Theme.dp(6)
                    y: trackHeader.height - height
                    width: root.contentWidth - trackHeader.infoX + Theme.dp(6)
                    height: Theme.dp(30)
                    visible: root.player !== null && root.volumeSupported

                    IconButton {
                        id: volBtn

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        size: "xs"
                        icon: root.playerVolume <= 0 ? "volume_off" : root.volumeGlyphFor(root.playerVolume)
                        tintOverride: Theme.subtext
                        onClicked: root.toggleMute()
                    }

                    Slider {
                        anchors.left: volBtn.right
                        anchors.leftMargin: Theme.dp(4)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        trackH: Theme.dp(8)
                        handleH: Theme.dp(22)
                        value: root.playerVolume
                        showValue: false
                        activeColor: Theme.accent
                        inactiveColor: Theme.withBlur(Theme.bgHigh)
                        onMoved: (v) => {
                            if (root.player)
                                root.player.volume = v;

                        }
                    }

                }

            }

            // the cava feed as a waveform: a dotted line at rest, rounded bars once there is sound
            Item {
                id: vizStrip

                readonly property real barW: Theme.dp(5)

                width: root.contentWidth
                height: Theme.dp(24)
                visible: root.player !== null

                Row {
                    anchors.centerIn: parent
                    spacing: root.barCount > 1 ? (vizStrip.width - root.barCount * vizStrip.barW) / (root.barCount - 1) : 0

                    Repeater {
                        model: root.barCount

                        Rectangle {
                            required property int index

                            readonly property real level: root.barLevel(index)

                            anchors.verticalCenter: parent.verticalCenter
                            width: vizStrip.barW
                            height: Math.max(vizStrip.barW, level * vizStrip.height)
                            radius: width / 2
                            color: Theme.accent
                            opacity: 0.3 + 0.7 * Math.min(1, level * 2)

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.barMs(70)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

            }

            // reaches into the padding by the handle's inset, so the wave and its times line up with the cover
            Item {
                x: -Theme.dp(8)
                width: root.contentWidth + Theme.dp(16)
                height: Theme.dp(40)
                visible: root.player !== null

                Column {
                    width: parent.width
                    spacing: Theme.dp(2)
                    visible: root.hasDuration

                    Item {
                        id: trackHitArea

                        property bool hovering: false
                        property bool dragging: false
                        property real dragProgress: root.progress
                        readonly property real displayProgress: dragging ? dragProgress : root.progress
                        readonly property real trackInset: Theme.dp(8)

                        width: parent.width
                        height: Theme.dp(22)

                        // the m3 wavy indicator: it flows while the track plays and lies flat once paused
                        Canvas {
                            id: waveCanvas

                            property real animatedProgress: trackHitArea.displayProgress
                            readonly property real trackThickness: Theme.dp(4)
                            readonly property real handleWidth: Theme.dp(4)
                            property real handleHeight: trackHitArea.hovering || trackHitArea.dragging ? Theme.dp(18) : Theme.dp(14)
                            property real amplitude: !root.isPlaying ? 0 : (trackHitArea.hovering || trackHitArea.dragging ? 4.5 : 3.5)
                            readonly property real trackGap: Theme.dp(6)
                            readonly property real stopIndicator: Theme.dp(4)
                            readonly property real wavelength: Theme.dp(26)

                            function smoothstep(t) {
                                t = Math.max(0, Math.min(1, t));
                                return t * t * (3 - 2 * t);
                            }

                            function envelope(x, inset, rampLen, endX) {
                                const fromStart = smoothstep((x - inset) / rampLen);
                                const fromEnd = smoothstep((endX - x) / rampLen);
                                return Math.min(fromStart, fromEnd);
                            }

                            function roundedBar(ctx, x, y, w, h, color) {
                                ctx.fillStyle = color;
                                ctx.beginPath();
                                ctx.roundedRect(x, y, w, h, w / 2, w / 2);
                                ctx.fill();
                            }

                            anchors.fill: parent
                            antialiasing: true
                            onAnimatedProgressChanged: requestPaint()
                            onHandleHeightChanged: requestPaint()
                            onAmplitudeChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                const midY = height / 2;
                                const inset = trackHitArea.trackInset;
                                const usableWidth = width - inset * 2;
                                const handleX = inset + Math.max(0, Math.min(usableWidth, usableWidth * animatedProgress));
                                const activeEnd = handleX - trackGap - handleWidth / 2;
                                const inactiveStart = handleX + trackGap + handleWidth / 2;
                                const rampLen = wavelength * 1.4;
                                // half a wavelength a second; 600s is a whole number of waves, so the wrap is seamless
                                const shift = (Date.now() % 600000) / 1000 * wavelength * 0.5;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                if (activeEnd - inset > trackThickness) {
                                    ctx.strokeStyle = Theme.accent;
                                    ctx.lineWidth = trackThickness;
                                    ctx.beginPath();
                                    for (let x = inset; x <= activeEnd; x++) {
                                        const y = midY + Math.sin(((x - shift) / wavelength) * Math.PI * 2) * amplitude * envelope(x, inset, rampLen, activeEnd);
                                        if (x === inset)
                                            ctx.moveTo(x, y);
                                        else
                                            ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();
                                }
                                const trackEnd = width - inset - stopIndicator * 2;
                                if (trackEnd - inactiveStart > trackThickness) {
                                    ctx.strokeStyle = Theme.withBlur(Theme.bgHigh);
                                    ctx.lineWidth = trackThickness;
                                    ctx.beginPath();
                                    ctx.moveTo(inactiveStart, midY);
                                    ctx.lineTo(trackEnd, midY);
                                    ctx.stroke();
                                }
                                ctx.fillStyle = Theme.accent;
                                ctx.globalAlpha = animatedProgress > 0.97 ? 0 : 0.55;
                                ctx.beginPath();
                                ctx.arc(width - inset - stopIndicator / 2, midY, stopIndicator / 2, 0, Math.PI * 2);
                                ctx.fill();
                                ctx.globalAlpha = 1;
                                roundedBar(ctx, handleX - handleWidth / 2, midY - handleHeight / 2, handleWidth, handleHeight, Theme.accent);
                            }

                            Connections {
                                function onAccentChanged() {
                                    waveCanvas.requestPaint();
                                }

                                function onBgHighChanged() {
                                    waveCanvas.requestPaint();
                                }

                                target: Theme
                            }

                            Behavior on animatedProgress {
                                enabled: !trackHitArea.dragging

                                NumberAnimation {
                                    duration: Theme.barMs(root.jumpDuration)
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: root.easeEmphasized
                                }

                            }

                            Behavior on handleHeight {
                                NumberAnimation {
                                    duration: Theme.barDurShort
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: root.easeEmphasized
                                }

                            }

                            Behavior on amplitude {
                                NumberAnimation {
                                    duration: Theme.barDurMedium
                                    easing.type: Theme.easeStandard
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: trackHitArea.hovering = true
                            onExited: trackHitArea.hovering = false
                            onPressed: (mouse) => {
                                trackHitArea.dragging = true;
                                trackHitArea.dragProgress = Math.max(0, Math.min(1, (mouse.x - trackHitArea.trackInset) / (width - trackHitArea.trackInset * 2)));
                            }
                            onPositionChanged: (mouse) => {
                                if (trackHitArea.dragging)
                                    trackHitArea.dragProgress = Math.max(0, Math.min(1, (mouse.x - trackHitArea.trackInset) / (width - trackHitArea.trackInset * 2)));

                            }
                            onReleased: (mouse) => {
                                root.seekTo(trackHitArea.dragProgress * root.lenSec, false);
                                trackHitArea.dragging = false;
                            }
                            onWheel: (wheel) => {
                                return root.seekTo(root.livePosSec + (wheel.angleDelta.y > 0 ? 5 : -5), true);
                            }
                        }

                    }

                    Item {
                        width: parent.width
                        height: posLabel.implicitHeight

                        LText {
                            id: posLabel

                            anchors.left: parent.left
                            anchors.leftMargin: trackHitArea.trackInset
                            role: "bodySmall"
                            tabular: true
                            color: Theme.subtext
                            text: root.fmt(trackHitArea.dragging ? trackHitArea.dragProgress * root.lenSec : root.livePosSec)
                        }

                        LText {
                            id: lenLabel

                            anchors.right: parent.right
                            anchors.rightMargin: trackHitArea.trackInset
                            role: "bodySmall"
                            tabular: true
                            color: lenArea.containsMouse ? Theme.text : Theme.subtext
                            text: root.showRemaining ? "-" + root.fmt(root.lenSec - root.livePosSec) : root.fmt(root.lenSec)

                            MouseArea {
                                id: lenArea

                                anchors.fill: parent
                                anchors.margins: -Theme.dp(6)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showRemaining = !root.showRemaining
                            }

                        }

                    }

                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.dp(8)
                    visible: !root.hasDuration

                    Rectangle {
                        id: liveDot

                        width: Theme.dp(6)
                        height: Theme.dp(6)
                        radius: Theme.dp(999)
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter

                        // visible is the effective one: a closed panel stops the pulse
                        SequentialAnimation on opacity {
                            running: root.isPlaying && liveDot.visible
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.25
                                duration: Theme.barMs(900)
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 1
                                duration: Theme.barMs(900)
                                easing.type: Easing.InOutSine
                            }

                        }

                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelMedium"
                        tabular: true
                        color: Theme.subtext
                        text: "Live  ·  " + root.fmt(root.livePosSec)
                    }

                }

            }

            // the transport, as the media widget draws it: bare skips either side of a wide play pill
            Item {
                width: root.contentWidth
                height: Theme.dp(52)
                visible: root.player !== null

                IconButton {
                    anchors.left: parent.left
                    anchors.leftMargin: -Theme.dp(6)
                    anchors.verticalCenter: parent.verticalCenter
                    size: "xs"
                    visible: root.player !== null && root.player.shuffleSupported
                    icon: root.shuffleGlyph
                    checkable: true
                    checked: root.player !== null && root.player.shuffle
                    iconFill: checked ? 1 : 0
                    tintOverride: checked ? Theme.accent : Theme.subtext
                    onClicked: {
                        if (root.player)
                            root.player.shuffle = !root.player.shuffle;

                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.dp(8)

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: root.prevGlyph
                        iconFill: 1
                        tintOverride: Theme.text
                        disabled: !(root.player !== null && root.player.canGoPrevious)
                        opacity: disabled ? Theme.disabledContent : 1
                        onClicked: root.skip(-1)
                    }

                    Rectangle {
                        id: playPill

                        readonly property real big: Theme.dp(52)
                        readonly property bool able: root.player !== null && root.player.canTogglePlaying

                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(playPill.big * 1.3)
                        height: playPill.big
                        radius: playTap.pressed ? playPill.big * 0.28 : playPill.big / 2
                        color: Theme.accent
                        opacity: playPill.able ? 1 : 0.4
                        // the state layer alone barely shows on a saturated fill, so the pill
                        // swells under the pointer as well
                        scale: playTap.pressed ? 0.96 : (playTap.containsMouse ? 1.05 : 1)

                        Icon {
                            anchors.centerIn: parent
                            name: root.isPlaying ? root.pauseGlyph : root.playGlyph
                            size: Math.round(playPill.big * 0.5)
                            fill: 1
                            color: Theme.fgAccent
                        }

                        StateLayer {
                            id: playTap

                            radius: parent.radius
                            tint: Theme.fgAccent
                            disabled: !playPill.able
                            onClicked: root.togglePlay()
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                        Behavior on radius {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveDefaultSpatial
                            }

                        }

                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: root.nextGlyph
                        iconFill: 1
                        tintOverride: Theme.text
                        disabled: !(root.player !== null && root.player.canGoNext)
                        opacity: disabled ? Theme.disabledContent : 1
                        onClicked: root.skip(1)
                    }

                }

                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: -Theme.dp(6)
                    anchors.verticalCenter: parent.verticalCenter
                    size: "xs"
                    visible: root.player !== null && root.player.loopSupported
                    icon: (root.player && root.player.loopState === MprisLoopState.Track) ? root.repeatOneGlyph : root.repeatGlyph
                    checkable: true
                    checked: root.player !== null && root.player.loopState !== MprisLoopState.None
                    iconFill: checked ? 1 : 0
                    tintOverride: checked ? Theme.accent : Theme.subtext
                    onClicked: root.cycleLoop()
                }

            }

            Item {
                width: root.contentWidth
                height: Theme.dp(44)
                visible: root.player === null

                Button {
                    anchors.centerIn: parent
                    text: "Identify what's playing"
                    icon: root.identifyGlyph
                    onClicked: root.openPanel("shazam")
                }

            }

        }

    }
,
    Item {
        id: shazamPage

        y: 0
        width: parent.width
        height: parent.height
        x: root.page === "shazam" ? 0 : root.panelWidth
        visible: shazamPage.x < root.panelWidth - 0.5

        Behavior on x {
            enabled: root.pageSwitching

            NumberAnimation {
                duration: root.morphDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: root.morphEasing
            }

        }

        Column {
            id: shazamColumn

            x: root.pad
            y: root.pad
            width: root.contentWidth
            spacing: Theme.dp(12)

            Item {
                width: root.contentWidth
                height: Theme.dp(36)

                IconButton {
                    id: backBtn

                    anchors.left: parent.left
                    anchors.leftMargin: -Theme.dp(8)
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.backGlyph
                    tintOverride: Theme.text
                    onClicked: root.setPage("player")
                }

                LText {
                    anchors.left: backBtn.right
                    anchors.leftMargin: Theme.dp(4)
                    anchors.verticalCenter: parent.verticalCenter
                    role: "titleMedium"
                    color: Theme.text
                    text: "Identify"
                }

                // what it listens to: this computer's own sound, or the microphone
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: -Theme.dp(6)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(2)

                    IconButton {
                        size: "xs"
                        icon: root.volumeGlyphs[root.volumeGlyphs.length - 1].path
                        checkable: true
                        checked: root.listenSource === "system"
                        iconFill: checked ? 1 : 0
                        tintOverride: checked ? Theme.accent : Theme.subtext
                        onClicked: {
                            root.listenSource = "system";
                            root.cancelListening();
                        }
                    }

                    IconButton {
                        size: "xs"
                        icon: root.micGlyph
                        checkable: true
                        checked: root.listenSource === "mic"
                        iconFill: checked ? 1 : 0
                        tintOverride: checked ? Theme.accent : Theme.subtext
                        onClicked: {
                            root.listenSource = "mic";
                            root.cancelListening();
                        }
                    }

                }

            }

            Item {
                id: shazamHero

                width: root.contentWidth
                height: root.shazamState === "match" ? Theme.dp(88) : Theme.dp(root.micQuiet && root.micVolume < 100 ? 186 : 148)

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.dp(14)
                    visible: root.shazamState !== "match"

                    Item {
                        id: listenBtn

                        readonly property bool listening: root.shazamState === "listening"

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.dp(80)
                        height: Theme.dp(80)
                        scale: listenArea.pressed ? 0.94 : (listenArea.containsMouse ? 1.05 : 1)
                        onListeningChanged: {
                            if (!listenBtn.listening)
                                settleTurn.restart();

                        }

                        // an m3 expressive cookie that turns while it listens
                        MaterialShape {
                            id: listenShape

                            property real turn: 0

                            anchors.fill: parent
                            shape: "cookie9"
                            color: Theme.accent
                            rotation: listenShape.turn

                            NumberAnimation on turn {
                                running: listenBtn.listening && shazamPage.visible
                                from: 0
                                to: 360
                                duration: Theme.barMs(7200)
                                loops: Animation.Infinite
                            }

                        }

                        // nine lobes repeat every 40 degrees, so it rests where the next spin starts
                        NumberAnimation {
                            id: settleTurn

                            target: listenShape
                            property: "turn"
                            to: Math.ceil(listenShape.turn / 40) * 40
                            duration: Theme.barDurMedium
                            easing.type: Easing.OutCubic
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.dp(3)
                            visible: listenBtn.listening

                            Repeater {
                                model: 5

                                Rectangle {
                                    required property int index

                                    width: Theme.dp(4)
                                    radius: width / 2
                                    color: Theme.fgAccent
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: Math.max(Theme.dp(4), (root.listenSource === "mic" ? root.micBar(index) : root.bandLevel(1 + index * 7, 7 + index * 7)) * Theme.dp(28))

                                    Behavior on height {
                                        NumberAnimation {
                                            duration: Theme.barMs(90)
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !listenBtn.listening
                            name: root.shazamState === "idle" ? root.identifyGlyph : root.retryGlyph
                            size: Theme.dp(30)
                            fill: 1
                            color: Theme.fgAccent
                        }

                        MouseArea {
                            id: listenArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (listenBtn.listening)
                                    root.cancelListening();
                                else
                                    root.startListening();
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                    }

                    Column {
                        width: root.contentWidth
                        spacing: Theme.dp(2)

                        LText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            role: "titleMedium"
                            color: Theme.text
                            text: {
                                switch (root.shazamState) {
                                case "listening":
                                    return "Listening…";
                                case "nomatch":
                                    return "No match";
                                case "error":
                                    return "Couldn't listen";
                                default:
                                    return root.listenSource === "mic" ? "Identify what's in the room" : "Identify what's playing here";
                                }
                            }
                        }

                        LText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            role: "bodySmall"
                            color: Theme.subtext
                            elide: Text.ElideRight
                            text: {
                                if (root.micQuiet)
                                    return root.shazamState === "nomatch" ? "The microphone was too quiet to hear it" : root.listenElapsed + "s  ·  the microphone barely hears it";

                                switch (root.shazamState) {
                                case "listening":
                                    return root.listenElapsed + "s  ·  tap to stop";
                                case "nomatch":
                                    return "Nothing recognisable in the last " + root.listenLimit + "s, tap to try again";
                                case "error":
                                    return "songrec couldn't reach the mic, the device or Shazam";
                                default:
                                    if (root.listenSource === "mic")
                                        return "via songrec  ·  microphone at " + root.micVolume + "%";

                                    return "via songrec  ·  " + (root.listenDevice === "" ? "default device" : "takes about 10s");
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: Theme.dp(36)
                            visible: root.micQuiet && root.micVolume < 100

                            Button {
                                anchors.centerIn: parent
                                variant: "text"
                                size: "xs"
                                text: "Turn the mic up"
                                icon: root.micGlyph
                                onClicked: Audio.setVolume(Audio.source, 100)
                            }

                        }

                    }

                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.contentWidth
                    spacing: Theme.dp(14)
                    visible: root.shazamState === "match"

                    RoundedArt {
                        width: Theme.dp(88)
                        height: Theme.dp(88)
                        source: root.shazamArtSource
                        shapeRadius: Theme.shapeLg
                        fallbackGlyph: Theme.dp(30)
                    }

                    Item {
                        width: root.contentWidth - Theme.dp(88) - Theme.dp(14)
                        height: Theme.dp(88)

                        Column {
                            anchors.top: parent.top
                            width: parent.width
                            spacing: Theme.dp(1)

                            Marquee {
                                width: parent.width
                                content: root.shazamResult ? root.shazamResult.title : ""
                                bold: true
                                weight: 600
                                textColor: Theme.text
                                pixelSize: Theme.typeSize("titleMedium")
                            }

                            Marquee {
                                width: parent.width
                                content: root.shazamResult ? root.shazamResult.artist : ""
                                textColor: Theme.subtext
                                pixelSize: Theme.typeSize("bodyMedium")
                            }

                            LText {
                                width: parent.width
                                role: "bodySmall"
                                color: Theme.subtextDim
                                elide: Text.ElideRight
                                text: {
                                    if (!root.shazamResult)
                                        return "";

                                    const parts = [];
                                    if (root.shazamResult.album !== "")
                                        parts.push(root.shazamResult.album);

                                    if (root.shazamResult.year !== "")
                                        parts.push(root.shazamResult.year);

                                    if (root.shazamResult.genre !== "")
                                        parts.push(root.shazamResult.genre);

                                    return parts.join("  ·  ");
                                }
                            }

                        }

                        Row {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            spacing: Theme.dp(2)

                            Button {
                                anchors.verticalCenter: parent.verticalCenter
                                size: "xs"
                                text: "Shazam"
                                icon: root.openGlyph
                                containerOverride: Theme.accent
                                contentOverride: Theme.fgAccent
                                onClicked: root.openUrl(root.shazamResult ? root.shazamResult.url : "")
                            }

                            Item {
                                width: Theme.dp(4)
                                height: 1
                            }

                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                size: "xs"
                                icon: root.searchGlyph
                                tintOverride: Theme.subtext
                                onClicked: root.searchOnline(root.shazamResult)
                            }

                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                size: "xs"
                                icon: root.copyGlyph
                                tintOverride: Theme.subtext
                                onClicked: root.copyText(root.shazamResult ? root.shazamResult.title + " — " + root.shazamResult.artist : "")
                            }

                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                size: "xs"
                                icon: root.retryGlyph
                                tintOverride: Theme.subtext
                                onClicked: root.startListening()
                            }

                        }

                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.barDurLong
                        easing.type: Easing.Bezier
                        easing.bezierCurve: root.easeEmphasized
                    }

                }

            }

            Column {
                width: root.contentWidth
                spacing: 0
                visible: historyAdapter.items.length > 0

                Item {
                    width: parent.width
                    height: Theme.dp(30)

                    LText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        role: "titleSmall"
                        color: Theme.accent
                        text: "Recent"
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.rightMargin: -Theme.dp(6)
                        anchors.verticalCenter: parent.verticalCenter
                        size: "xs"
                        icon: root.trashGlyph
                        tintOverride: Theme.subtext
                        onClicked: root.clearHistory()
                    }

                }

                Repeater {
                    model: historyAdapter.items.slice(0, 3)

                    Item {
                        id: histRow

                        required property var modelData

                        width: root.contentWidth
                        height: Theme.dp(52)

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: -Theme.dp(8)
                            anchors.rightMargin: -Theme.dp(8)
                            radius: Theme.shapeMd
                            color: Theme.text
                            opacity: histArea.pressed ? Theme.statePressed : (histArea.containsMouse ? Theme.stateHover : 0)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.barDurQuick
                                }

                            }

                        }

                        RoundedArt {
                            id: histArt

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.dp(40)
                            height: Theme.dp(40)
                            source: histRow.modelData.art
                            shapeRadius: Theme.shapeSm
                            fallbackGlyph: Theme.dp(18)
                        }

                        Column {
                            anchors.left: histArt.right
                            anchors.leftMargin: Theme.dp(12)
                            anchors.right: histAgo.left
                            anchors.rightMargin: Theme.dp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.dp(1)

                            LText {
                                width: parent.width
                                role: "bodyMedium"
                                weight: 560
                                color: Theme.text
                                elide: Text.ElideRight
                                text: histRow.modelData.title
                            }

                            LText {
                                width: parent.width
                                role: "bodySmall"
                                color: Theme.subtext
                                elide: Text.ElideRight
                                text: histRow.modelData.artist
                            }

                        }

                        LText {
                            id: histAgo

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            role: "labelSmall"
                            weight: 420
                            color: Theme.subtextDim
                            text: root.agoText(histRow.modelData.at, root.nowMs)
                        }

                        MouseArea {
                            id: histArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openUrl(histRow.modelData.url)
                        }

                    }

                }

            }

        }

    }
    ]

    // previous or next on the bar, for the Controls look
    component BarSkip: Item {
        id: skipBtn

        property string glyph: ""

        signal activated()

        width: Theme.dp(24)
        height: Theme.dp(24)
        anchors.verticalCenter: parent.verticalCenter
        opacity: skipBtn.enabled ? 1 : 0.4

        Icon {
            anchors.centerIn: parent
            name: skipBtn.glyph
            size: Theme.dp(18)
            fill: 1
            color: Theme.text
        }

        StateLayer {
            radius: height / 2
            tint: Theme.text
            disabled: !skipBtn.enabled
            onClicked: skipBtn.activated()
        }

    }

    // clipped, not shader-masked: a mask renders blank or as one huge blob
    // on machines without a real gpu
    component RoundedArt: Item {
        id: art

        property string source: ""
        property int shapeRadius: Theme.radiusMd
        property int fallbackGlyph: Theme.dp(28)
        property int decode: Theme.dp(256)
        readonly property bool ready: artSource.status === Image.Ready
        // the last cover that loaded stays up while the next one does, so a player
        // that rewrites its art file every few seconds does not blink
        readonly property bool holding: !art.ready && art.source !== "" && artHeld.status === Image.Ready

        ClippingRectangle {
            anchors.fill: parent
            radius: art.shapeRadius
            color: Theme.withBlur(Theme.surfaceHighest)

            Image {
                id: artHeld

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: art.decode
                sourceSize.height: art.decode
                visible: art.holding
            }

            Image {
                id: artSource

                anchors.fill: parent
                source: art.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: art.decode
                sourceSize.height: art.decode
                visible: art.ready
                onStatusChanged: {
                    if (artSource.status === Image.Ready)
                        artHeld.source = artSource.source;

                }
            }

        }

        Icon {
            anchors.centerIn: parent
            visible: !art.ready && !art.holding
            name: "music_note"
            size: art.fallbackGlyph
            fill: 1
            color: Theme.subtext
        }

    }

    component Marquee: Item {
        id: mq

        property string content: ""
        property color textColor: Theme.text
        property bool bold: false
        property int weight: mq.bold ? 640 : 420
        property int pixelSize: Theme.fs(13)
        property bool scrolling: true
        readonly property int sliceCount: 7
        readonly property int sliceWidth: Theme.dp(2)
        // one loop of text plus the gap before its repeat
        readonly property real segmentWidth: measure.implicitWidth
        readonly property real naturalWidth: bare.implicitWidth
        readonly property bool overflowing: mq.naturalWidth > mq.width
        readonly property bool animating: mq.scrolling && mq.overflowing
        property real currentX: 0

        function updateScroll() {
            if (mq.animating) {
                loopAnim.stop();
                entryAnim.restart();
            } else {
                entryAnim.stop();
                loopAnim.stop();
                mq.currentX = 0;
            }
        }

        implicitHeight: Math.ceil(measure.implicitHeight)
        clip: true
        onAnimatingChanged: mq.updateScroll()
        onContentChanged: mq.updateScroll()
        Component.onCompleted: mq.updateScroll()

        Text {
            id: measure

            visible: false
            text: mq.content + "     •     "
            font.family: Theme.fontFamily
            font.bold: mq.bold
            font.pixelSize: mq.pixelSize
            font.variableAxes: Theme.axes(mq.pixelSize, mq.weight, 0)
        }

        Text {
            id: bare

            visible: false
            text: mq.content
            font.family: Theme.fontFamily
            font.bold: mq.bold
            font.pixelSize: mq.pixelSize
            font.variableAxes: Theme.axes(mq.pixelSize, mq.weight, 0)
        }

        SequentialAnimation {
            id: entryAnim

            ScriptAction {
                script: mq.currentX = 0
            }

            PauseAnimation {
                duration: Theme.barMs(900)
            }

            ScriptAction {
                script: loopAnim.start()
            }

        }

        NumberAnimation {
            id: loopAnim

            target: mq
            property: "currentX"
            from: 0
            to: -mq.segmentWidth
            duration: Theme.barMs(Math.max(4000, mq.segmentWidth * 35))
            loops: Animation.Infinite
            running: false
        }

        Repeater {
            model: mq.sliceCount * 2 + 1

            Item {
                id: slice

                required property int index

                readonly property bool isLeft: slice.index < mq.sliceCount
                readonly property bool isRight: slice.index > mq.sliceCount
                readonly property int rightIndex: slice.index - mq.sliceCount - 1

                x: slice.isLeft ? slice.index * mq.sliceWidth : (slice.isRight ? mq.width - mq.sliceCount * mq.sliceWidth + slice.rightIndex * mq.sliceWidth : mq.sliceCount * mq.sliceWidth)
                width: (slice.isLeft || slice.isRight) ? mq.sliceWidth : Math.max(0, mq.width - mq.sliceCount * mq.sliceWidth * 2)
                height: mq.height
                clip: true
                opacity: slice.isLeft ? (mq.animating ? (slice.index + 1) / (mq.sliceCount + 1) : 1) : (slice.isRight ? (mq.overflowing ? (mq.sliceCount - slice.rightIndex) / (mq.sliceCount + 1) : 1) : 1)

                Row {
                    x: mq.currentX - slice.x
                    spacing: 0
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: mq.overflowing ? measure.text : mq.content
                        color: mq.textColor
                        font.family: Theme.fontFamily
                        font.bold: mq.bold
                        font.pixelSize: mq.pixelSize
                        font.variableAxes: Theme.axes(mq.pixelSize, mq.weight, 0)
                    }

                    Text {
                        text: measure.text
                        color: mq.textColor
                        font.family: Theme.fontFamily
                        font.bold: mq.bold
                        font.pixelSize: mq.pixelSize
                        font.variableAxes: Theme.axes(mq.pixelSize, mq.weight, 0)
                        visible: mq.overflowing
                    }

                }

            }

        }

        Behavior on currentX {
            enabled: !entryAnim.running && !loopAnim.running

            NumberAnimation {
                duration: Theme.barDurLong
                easing.type: Easing.Bezier
                easing.bezierCurve: root.easeStandard
            }

        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.barDurLong
            easing.type: Easing.Bezier
            easing.bezierCurve: root.easeEmphasized
        }

    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.barDurLong
            easing.type: Easing.Bezier
            easing.bezierCurve: root.easeEmphasized
        }

    }

}
