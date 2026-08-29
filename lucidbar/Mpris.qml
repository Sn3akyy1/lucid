import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland._FocusGrab
import Quickshell.Io
import Quickshell.Services.Mpris
import qs


BarPill {
    id: root

    property string page: "player"
    readonly property var easeStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var easeEmphasized: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property int contentWidth: root.panelWidth - 28
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
    readonly property string album: root.player ? root.player.trackAlbum : ""
    readonly property string artUrl: root.player ? root.player.trackArtUrl : ""
    readonly property string displayTitle: (root.player && root.artist) ? root.artist + "  -  " + root.title : root.title
    readonly property string sourceName: root.player ? (root.player.identity || "Media") : ""
    readonly property string metaLine: {
        if (!root.player)
            return "";

        const showAlbum = root.album !== "" && root.album !== root.title;
        return showAlbum ? root.album + "  ·  " + root.sourceName : root.sourceName;
    }
    readonly property real posSec: root.player ? root.player.position : 0
    readonly property real lenSec: root.player ? root.player.length : 0
    readonly property bool hasDuration: root.lenSec > 0
    property real livePosSec: root.posSec
    property real posBase: root.posSec
    property double posTimestamp: Date.now()
    property int jumpDuration: 0
    property bool snapNext: false
    readonly property real progress: root.hasDuration ? Math.min(1, root.livePosSec / root.lenSec) : 0
    property bool showRemaining: false
    readonly property bool volumeSupported: root.player ? root.player.volumeSupported : false
    readonly property real playerVolume: root.player ? root.player.volume : 0
    property bool volumeFlash: false
    property var bars: []
    readonly property int barCount: root.bars.length > 0 ? root.bars.length : 24
    property string shazamState: "idle"
    property var shazamResult: null
    property string shazamError: ""
    property int listenElapsed: 0
    readonly property int listenLimit: 30
    property string listenSource: "system"
    property string monitorDevice: ""
    property string micDevice: ""
    readonly property string listenDevice: root.listenSource === "mic" ? root.micDevice : root.monitorDevice
    property double nowMs: Date.now()
    readonly property string noteGlyph: "M12 3v10.55A4 4 0 1 0 14 17V7h4V3h-6Z"
    readonly property string playGlyph: "M8 5v14l11-7L8 5Z"
    readonly property string pauseGlyph: "M8 6h3v12H8V6Zm5 0h3v12h-3V6Z"
    readonly property string prevGlyph: "M6 6h2v12H6V6Zm3.5 6 8.5-6v12l-8.5-6Z"
    readonly property string nextGlyph: "M18 6h-2v12h2V6Zm-3.5 6L6 6v12l8.5-6Z"
    readonly property string shuffleGlyph: "M10.59 9.17 5.41 4 4 5.41l5.17 5.17 1.42-1.41ZM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5Zm.33 9.41-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13Z"
    readonly property string repeatGlyph: "M7 7h10v3l4-4-4-4v3H5v6h2V7Zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4Z"
    readonly property string repeatOneGlyph: "M7 7h10v3l4-4-4-4v3H5v6h2V7Zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4Zm-4-2V9h-1l-2 1v1h1.5v4H13Z"
    readonly property string identifyGlyph: "M3 10h2v4H3v-4Zm4-3h2v10H7V7Zm4-4h2v18h-2V3Zm4 4h2v10h-2V7Zm4 3h2v4h-2v-4Z"
    readonly property string backGlyph: "M15.41 7.41 14 6l-6 6 6 6 1.41-1.41L10.83 12l4.58-4.59Z"
    readonly property string collapseGlyph: "M12 8l-6 6 1.41 1.41L12 10.83l4.59 4.58L18 14l-6-6Z"
    readonly property string openGlyph: "M14 3v2h3.59l-9.83 9.83 1.41 1.41L19 6.41V10h2V3h-7ZM19 19H5V5h7V3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7h-2v7Z"
    readonly property string copyGlyph: "M16 1H4a2 2 0 0 0-2 2v14h2V3h12V1Zm3 4H8a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2Zm0 16H8V7h11v14Z"
    readonly property string searchGlyph: "M15.5 14h-.79l-.28-.27a6.47 6.47 0 0 0 1.48-5.34c-.47-2.78-2.79-5-5.59-5.34a6.5 6.5 0 0 0-7.27 7.27c.34 2.8 2.56 5.12 5.34 5.59a6.47 6.47 0 0 0 5.34-1.48l.27.28v.79L18.25 20l1.49-1.49L15.5 14Zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14Z"
    readonly property string retryGlyph: "M17.65 6.35A7.96 7.96 0 0 0 12 4a8 8 0 1 0 7.73 10h-2.08A6 6 0 1 1 12 6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35Z"
    readonly property string trashGlyph: "M6 19a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V7H6v12ZM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4Z"
    readonly property string micGlyph: "M12 14a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3Zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.92V21h2v-3.08A7 7 0 0 0 19 11h-2Z"
    readonly property string checkGlyph: "M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17Z"
    readonly property string swapGlyph: "M6.99 11 3 15l3.99 4v-3H14v-2H6.99v-3ZM21 9l-3.99-4v3H10v2h7.01v3L21 9Z"
    readonly property var volumeGlyphs: [
        {
            "max": 0,
            "path": "M7 9v6h4l5 5V4l-5 5H7z"
        },
        {
            "max": 49,
            "path": "M18.5 12c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM5 9v6h4l5 5V4L9 9H5z"
        },
        {
            "max": 100,
            "path": "M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"
        }
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

    function barColor(level) {
        const floor = 0.62;
        const k = floor + (1 - floor) * Math.min(1, level * 1.25);
        return Qt.rgba(Theme.accent.r * k, Theme.accent.g * k, Theme.accent.b * k, 1);
    }

    function openPanel(target) {
        root.page = target;
        root.expanded = true;
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

    function startListening() {
        root.shazamError = "";
        root.shazamResult = null;
        root.listenElapsed = 0;
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
    property int pageFadePause: 0

    onExpandedChanged: {
        root.pageFadePause = Theme.barMs(root.expanded ? 140 : 0);
        if (root.expanded)
            return ;

        root.page = "player";
        root.cancelListening();
    }

    shown: Prefs.showMedia
    compactWidth: compactRow.implicitWidth + 20
    panelWidth: Math.min(400, root.screenW - 34)
    panelHeight: 28 + (root.page === "player" ? playerColumn.implicitHeight : shazamColumn.implicitHeight)
    expandedRadius: Theme.radiusXl
    compactCollapseScale: 0.94
    compactInteractive: false
    panelFades: false

    IpcHandler {
        target: "media"

        function toggle(): void {
            if (root.expanded)
                root.expanded = false;
            else
                root.openPanel("player");
        }

        function open(): void {
            root.openPanel("player");
        }

        function close(): void {
            root.expanded = false;
        }

        function identify(): void {
            root.openPanel("shazam");
            root.startListening();
        }

        function playPause(): void {
            root.togglePlay();
        }

        function next(): void {
            root.skip(1);
        }

        function previous(): void {
            root.skip(-1);
        }

    }

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

    FrameAnimation {
        running: root.isPlaying && !trackHitArea.dragging
        onTriggered: root.livePosSec = Math.min(root.lenSec, root.posBase + (Date.now() - root.posTimestamp) / 1000)
    }

    Connections {
        function onTrackChanged() {
            root.snapNext = true;
        }

        target: root.player
    }

    Timer {
        id: volumeFlashTimer

        interval: 1100
        onTriggered: root.volumeFlash = false
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

        running: true
        command: ["cava", "-p", Quickshell.env('HOME') + "/.config/cava/quickshell.conf"]

        stdout: SplitParser {
            onRead: (line) => {
                const raw = line.trim().split(" ");
                const prev = root.bars;
                const out = [];
                for (let i = 0; i < raw.length; i++) {
                    const v = parseInt(raw[i]) || 0;
                    const p = prev[i];
                    out.push((p === undefined || v >= p) ? v : p * 0.82 + v * 0.18);
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
                else
                    root.openPanel("player");
            }
            onWheel: (wheel) => {
                return root.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
            }
        },

        Row {
            id: compactRow

            anchors.centerIn: parent
            spacing: 8

            Item {
                width: 14
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    anchors.centerIn: parent
                    spacing: 2.5
                    visible: root.player !== null

                    Repeater {
                        model: 3

                        Rectangle {
                            required property int index

                            width: 2.5
                            radius: 999
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                            height: root.isPlaying ? Math.max(3, root.bandLevel(1 + index * 11, 10 + index * 11) * 16) : 3

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.barMs(90)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

                SvgIcon {
                    anchors.centerIn: parent
                    visible: root.player === null
                    path: root.noteGlyph
                    tint: Theme.accent
                    glyphSize: 14
                }

            }

            Item {
                id: compactTitleSlot

                width: root.volumeFlash ? volumeFlashRow.implicitWidth : Math.min(160, Math.max(60, compactTitle.naturalWidth))
                height: 18
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
                    spacing: 5
                    opacity: root.volumeFlash ? 1 : 0

                    SvgIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.volumeGlyphFor(root.playerVolume)
                        tint: Theme.accent
                        glyphSize: 13
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.playerVolume * 100) + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(13)
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(140)
                        }

                    }

                }

            }

            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                diameter: 22
                glyphSize: 13
                filled: true
                path: root.isPlaying ? root.pauseGlyph : root.playGlyph
                tint: Theme.onAccent
                enabledAction: root.player !== null && root.player.canTogglePlaying
                onActivated: root.togglePlay()
            }

        }
    ]

    panelContent: [
    Item {
        id: playerPage

        anchors.fill: parent
        anchors.margins: 14
        opacity: (root.expanded && root.page === "player") ? 1 : 0
        visible: opacity > 0.01

        transform: Translate {
            x: root.page === "player" ? 0 : -26

            Behavior on x {
                NumberAnimation {
                    duration: Theme.barDurLong
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.easeEmphasized
                }

            }

        }

        Column {
            id: playerColumn

            width: root.contentWidth
            spacing: 12

            Row {
                width: root.contentWidth
                height: 96
                spacing: 14

                Item {
                    id: artwork

                    width: 96
                    height: 96

                    RoundedArt {
                        anchors.fill: parent
                        source: root.artUrl
                        shapeRadius: Theme.radiusLg
                        fallbackGlyph: 34
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusLg
                        color: "black"
                        opacity: artArea.containsMouse ? 0.4 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barMs(150)
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        opacity: artArea.containsMouse ? 1 : 0
                        path: root.isPlaying ? root.pauseGlyph : root.playGlyph
                        tint: "white"
                        glyphSize: 32

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barMs(150)
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    MouseArea {
                        id: artArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePlay()
                    }

                }

                Item {
                    width: root.contentWidth - 96 - 14
                    height: 96

                    Column {
                        anchors.top: parent.top
                        width: parent.width
                        spacing: 1

                        Marquee {
                            width: parent.width
                            content: root.title
                            scrolling: root.isPlaying
                            bold: true
                            pixelSize: Theme.fontHeadline
                        }

                        Marquee {
                            width: parent.width
                            visible: root.artist !== ""
                            content: root.artist
                            scrolling: root.isPlaying
                            textColor: Theme.subtext
                            pixelSize: Theme.fontBody
                        }

                        Text {
                            width: parent.width
                            visible: root.metaLine !== ""
                            text: root.metaLine
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            elide: Text.ElideRight
                        }

                    }

                    Row {
                        id: volumeRow

                        readonly property real fraction: Math.max(0, Math.min(1, root.playerVolume))
                        readonly property int handleWidth: 4
                        readonly property int handleGap: 6

                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: parent.width
                        height: 22
                        spacing: 8
                        visible: root.volumeSupported

                        SvgIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            path: root.volumeGlyphFor(root.playerVolume)
                            tint: volArea.containsMouse ? Theme.accent : Theme.subtext
                            glyphSize: 14
                        }

                        Item {
                            id: volTrack

                            readonly property real handleX: volumeRow.fraction * (volTrack.width - volumeRow.handleWidth)

                            width: parent.width - 14 - volPct.width - 16
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: volInactive

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                x: volTrack.handleX + volumeRow.handleWidth + volumeRow.handleGap
                                height: 10
                                radius: height / 2
                                color: Theme.withBlur(Theme.bgHigh)
                            }

                            Rectangle {
                                id: volActive

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, volTrack.handleX - volumeRow.handleGap)
                                height: 10
                                radius: height / 2
                                color: Theme.accent
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4
                                height: 4
                                radius: 999
                                color: Theme.accent
                                opacity: volumeRow.fraction > 0.94 ? 0 : 0.55
                            }

                            Rectangle {
                                id: volHandle

                                x: volTrack.handleX
                                anchors.verticalCenter: parent.verticalCenter
                                width: volumeRow.handleWidth
                                height: volArea.pressed ? 14 : 20
                                radius: 999
                                color: Theme.accent

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.barDurQuick
                                        easing.type: Theme.easeStandard
                                    }

                                }

                            }

                            MouseArea {
                                id: volArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onPressed: (mouse) => {
                                    if (root.player)
                                        root.player.volume = Math.max(0, Math.min(1, mouse.x / volTrack.width));

                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed && root.player)
                                        root.player.volume = Math.max(0, Math.min(1, mouse.x / volTrack.width));

                                }
                                onWheel: (wheel) => {
                                    return root.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                                }
                            }

                        }

                        Text {
                            id: volPct

                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(root.playerVolume * 100) + "%"
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                        }

                    }

                }

            }

            Item {
                id: vizStrip

                width: root.contentWidth
                height: 28
                opacity: root.isPlaying ? 1 : 0.75

                Row {
                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        model: root.barCount

                        Rectangle {
                            required property int index

                            readonly property real level: root.barLevel(index)

                            width: (vizStrip.width - (root.barCount - 1) * 3) / root.barCount
                            height: Math.max(width, level * vizStrip.height)
                            anchors.bottom: parent.bottom
                            radius: 999
                            color: root.barColor(level)

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.barMs(70)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barMs(220)
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Item {
                width: root.contentWidth
                height: 40

                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.hasDuration

                    Item {
                        id: trackHitArea

                        property bool hovering: false
                        property bool dragging: false
                        property real dragProgress: root.progress
                        readonly property real displayProgress: dragging ? dragProgress : root.progress
                        readonly property real trackInset: 8

                        width: parent.width
                        height: 22

                        Canvas {
                            id: waveCanvas

                            property real animatedProgress: trackHitArea.displayProgress
                            readonly property real trackThickness: 4
                            readonly property real handleWidth: 4
                            property real handleHeight: trackHitArea.hovering || trackHitArea.dragging ? 18 : 14
                            property real amplitude: trackHitArea.hovering || trackHitArea.dragging ? 4.5 : 3.5
                            readonly property real trackGap: 6
                            readonly property real stopIndicator: 4
                            readonly property real wavelength: 26

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
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                if (activeEnd - inset > trackThickness) {
                                    ctx.strokeStyle = Theme.accent;
                                    ctx.lineWidth = trackThickness;
                                    ctx.beginPath();
                                    for (let x = inset; x <= activeEnd; x++) {
                                        const y = midY + Math.sin((x / wavelength) * Math.PI * 2) * amplitude * envelope(x, inset, rampLen, activeEnd);
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

                        Text {
                            id: posLabel

                            anchors.left: parent.left
                            anchors.leftMargin: trackHitArea.trackInset
                            text: root.fmt(root.livePosSec)
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                        }

                        Text {
                            id: lenLabel

                            anchors.right: parent.right
                            anchors.rightMargin: trackHitArea.trackInset
                            text: root.showRemaining ? "-" + root.fmt(root.lenSec - root.livePosSec) : root.fmt(root.lenSec)
                            color: lenArea.containsMouse ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel

                            MouseArea {
                                id: lenArea

                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showRemaining = !root.showRemaining
                            }

                        }

                    }

                }

                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    visible: !root.hasDuration

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 999
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: root.isPlaying
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

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.player ? "LIVE  ·  " + root.fmt(root.livePosSec) : "NOTHING QUEUED"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontLabel
                        font.letterSpacing: 0.5
                    }

                }

            }

            Item {
                width: root.contentWidth
                height: 40

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    IconBtn {
                        ghost: true
                        diameter: 28
                        glyphSize: 15
                        visible: root.mprisPlayers.length > 1
                        path: root.swapGlyph
                        tint: Theme.subtextDim
                        onActivated: root.cyclePlayer()
                    }

                    IconBtn {
                        ghost: true
                        diameter: 28
                        glyphSize: 16
                        path: root.identifyGlyph
                        tint: Theme.subtextDim
                        onActivated: root.openPanel("shazam")
                    }

                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    IconBtn {
                        ghost: true
                        diameter: 28
                        glyphSize: 14
                        visible: root.player !== null && root.player.canRaise
                        path: root.openGlyph
                        tint: Theme.subtextDim
                        onActivated: {
                            if (root.player)
                                root.player.raise();

                        }
                    }

                    IconBtn {
                        ghost: true
                        diameter: 28
                        glyphSize: 16
                        path: root.collapseGlyph
                        tint: Theme.subtextDim
                        onActivated: root.expanded = false
                    }

                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    visible: root.player !== null

                    IconBtn {
                        ghost: true
                        diameter: 26
                        glyphSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.player !== null && root.player.shuffleSupported
                        path: root.shuffleGlyph
                        tint: (root.player && root.player.shuffle) ? Theme.accent : Theme.subtextDim
                        onActivated: {
                            if (root.player)
                                root.player.shuffle = !root.player.shuffle;

                        }
                    }

                    IconBtn {
                        diameter: 30
                        glyphSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.prevGlyph
                        enabledAction: root.player !== null && root.player.canGoPrevious
                        onActivated: root.skip(-1)
                    }

                    IconBtn {
                        diameter: 40
                        glyphSize: 19
                        filled: true
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.isPlaying ? root.pauseGlyph : root.playGlyph
                        tint: Theme.onAccent
                        enabledAction: root.player !== null && root.player.canTogglePlaying
                        onActivated: root.togglePlay()
                    }

                    IconBtn {
                        diameter: 30
                        glyphSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.nextGlyph
                        enabledAction: root.player !== null && root.player.canGoNext
                        onActivated: root.skip(1)
                    }

                    IconBtn {
                        ghost: true
                        diameter: 26
                        glyphSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.player !== null && root.player.loopSupported
                        path: (root.player && root.player.loopState === MprisLoopState.Track) ? root.repeatOneGlyph : root.repeatGlyph
                        tint: (root.player && root.player.loopState !== MprisLoopState.None) ? Theme.accent : Theme.subtextDim
                        onActivated: root.cycleLoop()
                    }

                }

                PillBtn {
                    anchors.centerIn: parent
                    visible: root.player === null
                    label: "Identify what's playing"
                    path: root.identifyGlyph
                    accented: true
                    onActivated: root.openPanel("shazam")
                }

            }

        }

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.pageFadePause
                }

                NumberAnimation {
                    duration: Theme.barMs(220)
                    easing.type: Easing.OutCubic
                }

            }

        }

    }
,
    Item {
        id: shazamPage

        anchors.fill: parent
        anchors.margins: 14
        opacity: (root.expanded && root.page === "shazam") ? 1 : 0
        visible: opacity > 0.01

        transform: Translate {
            x: root.page === "shazam" ? 0 : 26

            Behavior on x {
                NumberAnimation {
                    duration: Theme.barDurLong
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.easeEmphasized
                }

            }

        }

        Column {
            id: shazamColumn

            width: root.contentWidth
            spacing: 12

            Item {
                width: root.contentWidth
                height: 30

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    IconBtn {
                        ghost: true
                        diameter: 26
                        glyphSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.backGlyph
                        tint: Theme.subtext
                        onActivated: root.page = "player"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "IDENTIFY"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontLabel
                        font.letterSpacing: 0.5
                    }

                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    IconBtn {
                        ghost: true
                        diameter: 28
                        glyphSize: 16
                        path: root.volumeGlyphs[root.volumeGlyphs.length - 1].path
                        tint: root.listenSource === "system" ? Theme.accent : Theme.subtextDim
                        onActivated: {
                            root.listenSource = "system";
                            root.cancelListening();
                        }
                    }

                    IconBtn {
                        ghost: true
                        diameter: 28
                        glyphSize: 16
                        path: root.micGlyph
                        tint: root.listenSource === "mic" ? Theme.accent : Theme.subtextDim
                        onActivated: {
                            root.listenSource = "mic";
                            root.cancelListening();
                        }
                    }

                }

            }

            Item {
                id: shazamHero

                width: root.contentWidth
                height: root.shazamState === "match" ? 84 : 136

                Column {
                    anchors.centerIn: parent
                    spacing: 14
                    visible: root.shazamState !== "match"

                    Item {
                        width: 116
                        height: 74
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: 3

                            Rectangle {
                                id: ring

                                required property int index

                                anchors.centerIn: parent
                                width: 64
                                height: 64
                                radius: 999
                                color: "transparent"
                                border.width: 2
                                border.color: Theme.accent
                                opacity: 0
                                visible: root.shazamState === "listening"

                                SequentialAnimation {
                                    running: root.shazamState === "listening"

                                    PauseAnimation {
                                        duration: Theme.barMs(ring.index * 620)
                                    }

                                    SequentialAnimation {
                                        loops: Animation.Infinite

                                        ParallelAnimation {
                                            NumberAnimation {
                                                target: ring
                                                property: "scale"
                                                from: 0.75
                                                to: 1.9
                                                duration: Theme.barMs(1860)
                                                easing.type: Easing.OutCubic
                                            }

                                            NumberAnimation {
                                                target: ring
                                                property: "opacity"
                                                from: 0.5
                                                to: 0
                                                duration: Theme.barMs(1860)
                                                easing.type: Easing.OutCubic
                                            }

                                        }

                                    }

                                }

                            }

                        }

                        Rectangle {
                            id: listenBtn

                            anchors.centerIn: parent
                            width: 64
                            height: 64
                            radius: 999
                            color: Theme.accent
                            scale: listenArea.pressed ? 0.94 : (listenArea.containsMouse ? 1.05 : 1)

                            SequentialAnimation on opacity {
                                running: root.shazamState === "listening"
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 0.75
                                    duration: Theme.barMs(780)
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 1
                                    duration: Theme.barMs(780)
                                    easing.type: Easing.InOutSine
                                }

                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 3
                                visible: root.shazamState === "listening"

                                Repeater {
                                    model: 5

                                    Rectangle {
                                        required property int index

                                        width: 3
                                        radius: 999
                                        color: Theme.onAccent
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: Math.max(4, root.bandLevel(1 + index * 7, 7 + index * 7) * 26)

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: Theme.barMs(90)
                                                easing.type: Easing.OutCubic
                                            }

                                        }

                                    }

                                }

                            }

                            SvgIcon {
                                anchors.centerIn: parent
                                visible: root.shazamState !== "listening"
                                path: root.shazamState === "idle" ? root.identifyGlyph : root.retryGlyph
                                tint: Theme.onAccent
                                glyphSize: 26
                            }

                            MouseArea {
                                id: listenArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.shazamState === "listening")
                                        root.cancelListening();
                                    else
                                        root.startListening();
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.barMs(140)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                    Column {
                        width: root.contentWidth
                        spacing: 3

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
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
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fontTitle
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                switch (root.shazamState) {
                                case "listening":
                                    return root.listenElapsed + "s  ·  tap to stop";
                                case "nomatch":
                                    return "Nothing recognisable in the last " + root.listenLimit + "s — tap to try again";
                                case "error":
                                    return "songrec couldn't reach the mic, the device or Shazam";
                                default:
                                    return "via songrec  ·  " + (root.listenDevice === "" ? "default device" : "takes about 10s");
                                }
                            }
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            elide: Text.ElideRight
                        }

                    }

                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.contentWidth
                    spacing: 14
                    visible: root.shazamState === "match"

                    RoundedArt {
                        width: 76
                        height: 76
                        source: root.shazamResult ? root.shazamResult.art : ""
                        shapeRadius: Theme.radiusMd
                        fallbackGlyph: 28
                    }

                    Item {
                        width: root.contentWidth - 76 - 14
                        height: 76

                        Column {
                            anchors.top: parent.top
                            width: parent.width
                            spacing: 1

                            Marquee {
                                width: parent.width
                                content: root.shazamResult ? root.shazamResult.title : ""
                                bold: true
                                pixelSize: Theme.fontHeadline
                            }

                            Marquee {
                                width: parent.width
                                content: root.shazamResult ? root.shazamResult.artist : ""
                                textColor: Theme.subtext
                                pixelSize: Theme.fontBody
                            }

                            Text {
                                width: parent.width
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
                                color: Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                elide: Text.ElideRight
                            }

                        }

                        Row {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            spacing: 6

                            PillBtn {
                                label: "Shazam"
                                path: root.openGlyph
                                onActivated: root.openUrl(root.shazamResult ? root.shazamResult.url : "")
                            }

                            IconBtn {
                                diameter: 28
                                glyphSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                                path: root.searchGlyph
                                onActivated: root.searchOnline(root.shazamResult)
                            }

                            IconBtn {
                                diameter: 28
                                glyphSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                                path: root.copyGlyph
                                onActivated: root.copyText(root.shazamResult ? root.shazamResult.title + " — " + root.shazamResult.artist : "")
                            }

                            IconBtn {
                                diameter: 28
                                glyphSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                                path: root.retryGlyph
                                onActivated: root.startListening()
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
                spacing: 6
                visible: historyAdapter.items.length > 0

                Item {
                    width: parent.width
                    height: 14

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RECENT"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontLabel
                        font.letterSpacing: 0.5
                    }

                    IconBtn {
                        ghost: true
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        diameter: 22
                        glyphSize: 13
                        path: root.trashGlyph
                        tint: Theme.subtextDim
                        onActivated: root.clearHistory()
                    }

                }

                Repeater {
                    model: historyAdapter.items.slice(0, 3)

                    Item {
                        id: histRow

                        required property var modelData

                        width: root.contentWidth
                        height: 38

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: Theme.radiusSm
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
                            width: 32
                            height: 32
                            source: histRow.modelData.art
                            shapeRadius: Theme.radiusXs
                            fallbackGlyph: 16
                        }

                        Column {
                            anchors.left: histArt.right
                            anchors.leftMargin: 10
                            anchors.right: histAgo.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                text: histRow.modelData.title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fontBody
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: histRow.modelData.artist
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                elide: Text.ElideRight
                            }

                        }

                        Text {
                            id: histAgo

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.agoText(histRow.modelData.at, root.nowMs)
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
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

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.pageFadePause
                }

                NumberAnimation {
                    duration: Theme.barMs(220)
                    easing.type: Easing.OutCubic
                }

            }

        }

    }
    ]

    component RoundedArt: Item {
        id: art

        property string source: ""
        property int shapeRadius: Theme.radiusMd
        property int fallbackGlyph: 28
        readonly property bool ready: artSource.status === Image.Ready

        Rectangle {
            anchors.fill: parent
            radius: art.shapeRadius
            color: Theme.withBlur(Theme.bgActive)
        }

        Image {
            id: artSource

            anchors.fill: parent
            source: art.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
            sourceSize.height: 256
            visible: false
        }

        Rectangle {
            id: artMask

            anchors.fill: parent
            radius: art.shapeRadius
            visible: false
            layer.enabled: true
        }

        OpacityMask {
            anchors.fill: parent
            source: artSource
            maskSource: artMask
            visible: art.ready
        }

        SvgIcon {
            anchors.centerIn: parent
            visible: !art.ready
            path: root.noteGlyph
            tint: Theme.bgHigh
            glyphSize: art.fallbackGlyph
        }

    }

    component SvgIcon: Item {
        id: icon

        property string path: ""
        property color tint: Theme.text
        property int glyphSize: 16

        width: icon.glyphSize
        height: icon.glyphSize

        Shape {
            width: 24
            height: 24
            scale: icon.glyphSize / 24
            anchors.centerIn: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: icon.tint
                strokeWidth: 0

                PathSvg {
                    path: icon.path
                }

            }

        }

    }

    component Marquee: Item {
        id: mq

        property string content: ""
        property color textColor: Theme.text
        property bool bold: false
        property int pixelSize: Theme.fs(13)
        property bool scrolling: true
        readonly property int sliceCount: 7
        readonly property int sliceWidth: 2
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
        }

        Text {
            id: bare

            visible: false
            text: mq.content
            font.family: Theme.fontFamily
            font.bold: mq.bold
            font.pixelSize: mq.pixelSize
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
                    }

                    Text {
                        text: measure.text
                        color: mq.textColor
                        font.family: Theme.fontFamily
                        font.bold: mq.bold
                        font.pixelSize: mq.pixelSize
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

    component IconBtn: Rectangle {
        id: btn

        property string path: ""
        property int diameter: 28
        property int glyphSize: 14
        property color tint: Theme.text
        property bool filled: false
        property bool ghost: false
        property bool enabledAction: true

        signal activated()

        width: btn.diameter
        height: btn.diameter
        radius: 999
        color: btn.filled ? Theme.accent : (btn.ghost ? "transparent" : Theme.withBlur(Theme.bgHigh))
        opacity: btn.enabledAction ? 1 : 0.3
        scale: btnArea.pressed ? 0.9 : (btnArea.containsMouse ? 1.07 : 1)

        SvgIcon {
            anchors.centerIn: parent
            path: btn.path
            tint: btn.tint
            glyphSize: btn.glyphSize
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: btn.filled ? Theme.onAccent : Theme.text
            opacity: !btn.enabledAction ? 0 : (btnArea.pressed ? Theme.statePressed : (btnArea.containsMouse ? Theme.stateHover : 0))

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.barDurQuick
                    easing.type: Theme.easeStandard
                }

            }

        }

        MouseArea {
            id: btnArea

            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabledAction
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.barDurQuick
                easing.type: Theme.easeStandard
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.barDurShort
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.barDurQuick
            }

        }

    }

    component PillBtn: Rectangle {
        id: pill

        property string label: ""
        property string path: ""
        property bool accented: false
        readonly property color onColor: pill.accented ? Theme.onAccent : Theme.text

        signal activated()

        implicitWidth: pillRow.implicitWidth + 26
        height: 30
        radius: 999
        color: pill.accented ? Theme.accent : Theme.withBlur(Theme.bgHigh)
        scale: pillArea.pressed ? 0.94 : (pillArea.containsMouse ? 1.04 : 1)

        Row {
            id: pillRow

            anchors.centerIn: parent
            spacing: 7

            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.path !== ""
                path: pill.path
                tint: pill.onColor
                glyphSize: 14
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                color: pill.onColor
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fontLabel
                font.letterSpacing: 0.1
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: pill.onColor
            opacity: pillArea.pressed ? Theme.statePressed : (pillArea.containsMouse ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.barDurQuick
                    easing.type: Theme.easeStandard
                }

            }

        }

        MouseArea {
            id: pillArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.activated()
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.barDurQuick
                easing.type: Theme.easeStandard
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
