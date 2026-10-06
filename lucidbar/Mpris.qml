import QtQuick
import Quickshell
import Quickshell.Hyprland._FocusGrab
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.lucidui


BarPill {
    id: root

    property string page: "player"
    readonly property var easeStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var easeEmphasized: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property int contentWidth: root.panelWidth - Theme.dp(28)
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
    readonly property string displayTitle: (root.player && root.artist) ? root.artist + "  -  " + root.title : root.title
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
    property var bars: []
    // a single value means cava is not emitting raw ascii frames; fall back
    // rather than stretch one bar across the whole strip
    readonly property int barCount: root.bars.length > 1 ? root.bars.length : 24
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

    function barColor(level) {
        const floor = 0.62;
        const k = floor + (1 - floor) * Math.min(1, level * 1.25);
        return Qt.rgba(Theme.accent.r * k, Theme.accent.g * k, Theme.accent.b * k, 1);
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

    shown: Prefs.barHas("media")
    compactWidth: compactRow.implicitWidth + Theme.dp(20)
    panelWidth: Math.min(Theme.dp(400), root.screenW - Theme.dp(34))
    panelHeight: Theme.dp(28) + (root.page === "player" ? playerColumn.implicitHeight : shazamColumn.implicitHeight)
    expandedRadius: Theme.radiusXl
    compactCollapseScale: 0.94
    compactInteractive: false
    surfaceLayered: true

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

        // silence costs the same as sound to capture and parse, so only listen
        // while something is actually playing or the panel is open on the strip
        running: root.isPlaying || root.expanded
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
            spacing: Theme.dp(8)

            Item {
                width: Theme.dp(26)
                height: Theme.dp(26)
                anchors.verticalCenter: parent.verticalCenter

                CircularProgress {
                    anchors.fill: parent
                    visible: root.player !== null
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
                    visible: root.player !== null && compactArtImg.status === Image.Ready

                    Image {
                        id: compactArtImg

                        anchors.fill: parent
                        source: root.artUrl
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

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.dp(2)
                    visible: root.player !== null && !compactArt.visible

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

                width: root.volumeFlash ? volumeFlashRow.implicitWidth : Math.min(Theme.dp(170), Math.max(Theme.dp(60), compactTitle.naturalWidth))
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
                width: Theme.dp(24)
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

            x: Theme.dp(14)
            y: Theme.dp(14)
            width: root.contentWidth
            spacing: Theme.dp(10)

            Row {
                width: root.contentWidth
                height: Theme.dp(84)
                spacing: Theme.dp(12)

                Item {
                    id: artwork

                    width: Theme.dp(84)
                    height: Theme.dp(84)

                    RoundedArt {
                        anchors.fill: parent
                        source: root.artUrl
                        shapeRadius: Theme.radiusLg
                        fallbackGlyph: Theme.dp(30)
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
                        glyphSize: Theme.dp(32)

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
                    width: root.contentWidth - Theme.dp(84) - Theme.dp(12)
                    height: Theme.dp(84)

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

                    }

                    Row {
                        id: volumeRow

                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: parent.width
                        height: Theme.dp(22)
                        spacing: Theme.dp(8)
                        visible: root.volumeSupported

                        SvgIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            path: root.volumeGlyphFor(root.playerVolume)
                            tint: Theme.subtext
                            glyphSize: Theme.dp(14)
                        }

                        Slider {
                            id: volTrack

                            width: parent.width - Theme.dp(22)
                            anchors.verticalCenter: parent.verticalCenter
                            value: root.playerVolume
                            showValue: false
                            inactiveColor: Theme.withBlur(Theme.surfaceHighest)
                            onMoved: (v) => {
                                if (root.player)
                                    root.player.volume = v;

                            }
                        }

                    }

                }

            }

            Item {
                id: vizStrip

                width: root.contentWidth
                height: Theme.dp(20)
                opacity: root.isPlaying ? 1 : 0.75

                Row {
                    anchors.fill: parent
                    spacing: Theme.dp(3)

                    Repeater {
                        model: root.barCount

                        Rectangle {
                            required property int index

                            readonly property real level: root.barLevel(index)

                            width: (vizStrip.width - (root.barCount - 1) * 3) / root.barCount
                            // width is only the dot-minimum for a thin bar, so cap it:
                            // a wide bar must not drag the height up with it
                            height: Math.min(vizStrip.height, Math.max(width, level * vizStrip.height))
                            anchors.bottom: parent.bottom
                            radius: Theme.dp(999)
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
                height: Theme.dp(40)

                Column {
                    width: parent.width
                    spacing: Theme.dp(4)
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

                        Canvas {
                            id: waveCanvas

                            property real animatedProgress: trackHitArea.displayProgress
                            readonly property real trackThickness: Theme.dp(4)
                            readonly property real handleWidth: Theme.dp(4)
                            property real handleHeight: trackHitArea.hovering || trackHitArea.dragging ? Theme.dp(18) : Theme.dp(14)
                            property real amplitude: trackHitArea.hovering || trackHitArea.dragging ? 4.5 : 3.5
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
                            font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                        }

                        Text {
                            id: lenLabel

                            anchors.right: parent.right
                            anchors.rightMargin: trackHitArea.trackInset
                            text: root.showRemaining ? "-" + root.fmt(root.lenSec - root.livePosSec) : root.fmt(root.lenSec)
                            color: lenArea.containsMouse ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)

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
                    spacing: Theme.dp(7)
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

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.player ? "LIVE  ·  " + root.fmt(root.livePosSec) : "NOTHING QUEUED"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontLabel
                        font.variableAxes: Theme.axes(Theme.fontLabel, 640, 0)
                        font.letterSpacing: 0.5
                    }

                }

            }

            Item {
                width: root.contentWidth
                height: Theme.dp(40)

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(2)

                    IconBtn {
                        ghost: true
                        diameter: Theme.dp(28)
                        glyphSize: Theme.dp(15)
                        visible: root.mprisPlayers.length > 1
                        path: root.swapGlyph
                        tint: Theme.subtextDim
                        onActivated: root.cyclePlayer()
                    }

                    IconBtn {
                        ghost: true
                        diameter: Theme.dp(28)
                        glyphSize: Theme.dp(16)
                        path: root.identifyGlyph
                        tint: Theme.subtextDim
                        onActivated: root.openPanel("shazam")
                    }

                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(2)

                    IconBtn {
                        ghost: true
                        diameter: Theme.dp(28)
                        glyphSize: Theme.dp(14)
                        visible: root.player !== null && root.player.canRaise
                        path: root.openGlyph
                        tint: Theme.subtextDim
                        onActivated: {
                            if (root.player)
                                root.player.raise();

                        }
                    }

                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(10)
                    visible: root.player !== null

                    IconBtn {
                        ghost: true
                        diameter: Theme.dp(26)
                        glyphSize: Theme.dp(14)
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
                        diameter: Theme.dp(30)
                        glyphSize: Theme.dp(15)
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.prevGlyph
                        enabledAction: root.player !== null && root.player.canGoPrevious
                        onActivated: root.skip(-1)
                    }

                    IconBtn {
                        diameter: Theme.dp(40)
                        glyphSize: Theme.dp(19)
                        filled: true
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.isPlaying ? root.pauseGlyph : root.playGlyph
                        tint: Theme.fgAccent
                        enabledAction: root.player !== null && root.player.canTogglePlaying
                        onActivated: root.togglePlay()
                    }

                    IconBtn {
                        diameter: Theme.dp(30)
                        glyphSize: Theme.dp(15)
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.nextGlyph
                        enabledAction: root.player !== null && root.player.canGoNext
                        onActivated: root.skip(1)
                    }

                    IconBtn {
                        ghost: true
                        diameter: Theme.dp(26)
                        glyphSize: Theme.dp(14)
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

            x: Theme.dp(14)
            y: Theme.dp(14)
            width: root.contentWidth
            spacing: Theme.dp(12)

            Item {
                width: root.contentWidth
                height: Theme.dp(30)

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(4)

                    IconBtn {
                        ghost: true
                        diameter: Theme.dp(26)
                        glyphSize: Theme.dp(15)
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.backGlyph
                        tint: Theme.subtext
                        onActivated: root.setPage("player")
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "IDENTIFY"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontLabel
                        font.variableAxes: Theme.axes(Theme.fontLabel, 640, 0)
                        font.letterSpacing: 0.5
                    }

                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(2)

                    IconBtn {
                        ghost: true
                        diameter: Theme.dp(28)
                        glyphSize: Theme.dp(16)
                        path: root.volumeGlyphs[root.volumeGlyphs.length - 1].path
                        tint: root.listenSource === "system" ? Theme.accent : Theme.subtextDim
                        onActivated: {
                            root.listenSource = "system";
                            root.cancelListening();
                        }
                    }

                    IconBtn {
                        ghost: true
                        diameter: Theme.dp(28)
                        glyphSize: Theme.dp(16)
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
                height: root.shazamState === "match" ? Theme.dp(84) : Theme.dp(136)

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.dp(14)
                    visible: root.shazamState !== "match"

                    Item {
                        width: Theme.dp(116)
                        height: Theme.dp(74)
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: 3

                            Rectangle {
                                id: ring

                                required property int index

                                anchors.centerIn: parent
                                width: Theme.dp(64)
                                height: Theme.dp(64)
                                radius: Theme.dp(999)
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
                            width: Theme.dp(64)
                            height: Theme.dp(64)
                            radius: Theme.dp(999)
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
                                spacing: Theme.dp(3)
                                visible: root.shazamState === "listening"

                                Repeater {
                                    model: 5

                                    Rectangle {
                                        required property int index

                                        width: Theme.dp(3)
                                        radius: Theme.dp(999)
                                        color: Theme.fgAccent
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: Math.max(Theme.dp(4), root.bandLevel(1 + index * 7, 7 + index * 7) * 26)

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
                                tint: Theme.fgAccent
                                glyphSize: Theme.dp(26)
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
                        spacing: Theme.dp(3)

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
                            font.variableAxes: Theme.axes(Theme.fontTitle, 640, 0)
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
                            font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                            elide: Text.ElideRight
                        }

                    }

                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.contentWidth
                    spacing: Theme.dp(14)
                    visible: root.shazamState === "match"

                    RoundedArt {
                        width: Theme.dp(76)
                        height: Theme.dp(76)
                        source: root.shazamResult ? root.shazamResult.art : ""
                        shapeRadius: Theme.radiusMd
                        fallbackGlyph: Theme.dp(28)
                    }

                    Item {
                        width: root.contentWidth - Theme.dp(76) - Theme.dp(14)
                        height: Theme.dp(76)

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
                                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                                elide: Text.ElideRight
                            }

                        }

                        Row {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            spacing: Theme.dp(6)

                            PillBtn {
                                label: "Shazam"
                                path: root.openGlyph
                                onActivated: root.openUrl(root.shazamResult ? root.shazamResult.url : "")
                            }

                            IconBtn {
                                diameter: Theme.dp(28)
                                glyphSize: Theme.dp(14)
                                anchors.verticalCenter: parent.verticalCenter
                                path: root.searchGlyph
                                onActivated: root.searchOnline(root.shazamResult)
                            }

                            IconBtn {
                                diameter: Theme.dp(28)
                                glyphSize: Theme.dp(14)
                                anchors.verticalCenter: parent.verticalCenter
                                path: root.copyGlyph
                                onActivated: root.copyText(root.shazamResult ? root.shazamResult.title + " — " + root.shazamResult.artist : "")
                            }

                            IconBtn {
                                diameter: Theme.dp(28)
                                glyphSize: Theme.dp(14)
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
                spacing: Theme.dp(6)
                visible: historyAdapter.items.length > 0

                Item {
                    width: parent.width
                    height: Theme.dp(14)

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RECENT"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontLabel
                        font.variableAxes: Theme.axes(Theme.fontLabel, 640, 0)
                        font.letterSpacing: 0.5
                    }

                    IconBtn {
                        ghost: true
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        diameter: Theme.dp(22)
                        glyphSize: Theme.dp(13)
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
                        height: Theme.dp(38)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -Theme.dp(4)
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
                            width: Theme.dp(32)
                            height: Theme.dp(32)
                            source: histRow.modelData.art
                            shapeRadius: Theme.radiusXs
                            fallbackGlyph: Theme.dp(16)
                        }

                        Column {
                            anchors.left: histArt.right
                            anchors.leftMargin: Theme.dp(10)
                            anchors.right: histAgo.left
                            anchors.rightMargin: Theme.dp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                text: histRow.modelData.title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fontBody
                                font.variableAxes: Theme.axes(Theme.fontBody, 640, 0)
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: histRow.modelData.artist
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
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
                            font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
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

    // clipped, not shader-masked: a mask renders blank or as one huge blob
    // on machines without a real gpu
    component RoundedArt: Item {
        id: art

        property string source: ""
        property int shapeRadius: Theme.radiusMd
        property int fallbackGlyph: Theme.dp(28)
        readonly property bool ready: artSource.status === Image.Ready

        ClippingRectangle {
            anchors.fill: parent
            radius: art.shapeRadius
            color: Theme.withBlur(Theme.bgActive)

            Image {
                id: artSource

                anchors.fill: parent
                source: art.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Theme.dp(256)
                sourceSize.height: Theme.dp(256)
                visible: art.ready
            }

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
        property int glyphSize: Theme.dp(16)

        width: icon.glyphSize
        height: icon.glyphSize

        property real fill: 1

        Icon {
            anchors.centerIn: parent
            name: icon.path
            size: Math.round(icon.glyphSize * 1.15)
            fill: icon.fill
            color: icon.tint
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
            font.variableAxes: Theme.axes(mq.pixelSize, (mq.bold) ? 640 : 420, 0)
        }

        Text {
            id: bare

            visible: false
            text: mq.content
            font.family: Theme.fontFamily
            font.bold: mq.bold
            font.pixelSize: mq.pixelSize
            font.variableAxes: Theme.axes(mq.pixelSize, (mq.bold) ? 640 : 420, 0)
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
                        font.variableAxes: Theme.axes(mq.pixelSize, (mq.bold) ? 640 : 420, 0)
                    }

                    Text {
                        text: measure.text
                        color: mq.textColor
                        font.family: Theme.fontFamily
                        font.bold: mq.bold
                        font.pixelSize: mq.pixelSize
                        font.variableAxes: Theme.axes(mq.pixelSize, (mq.bold) ? 640 : 420, 0)
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
        property int diameter: Theme.dp(28)
        property int glyphSize: Theme.dp(14)
        property color tint: Theme.text
        property bool filled: false
        property bool ghost: false
        property bool enabledAction: true

        signal activated()

        width: btn.diameter
        height: btn.diameter
        radius: Theme.dp(999)
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
            color: btn.filled ? Theme.fgAccent : Theme.text
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
        readonly property color onColor: pill.accented ? Theme.fgAccent : Theme.text

        signal activated()

        implicitWidth: pillRow.implicitWidth + Theme.dp(26)
        height: Theme.dp(30)
        radius: Theme.dp(999)
        color: pill.accented ? Theme.accent : Theme.withBlur(Theme.bgHigh)
        scale: pillArea.pressed ? 0.94 : (pillArea.containsMouse ? 1.04 : 1)

        Row {
            id: pillRow

            anchors.centerIn: parent
            spacing: Theme.dp(7)

            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.path !== ""
                path: pill.path
                tint: pill.onColor
                glyphSize: Theme.dp(14)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                color: pill.onColor
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fontLabel
                font.variableAxes: Theme.axes(Theme.fontLabel, 640, 0)
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
