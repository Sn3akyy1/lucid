import QtQuick
import Quickshell
import Quickshell.Io
import "Lyrics.js" as Lyrics

// the words of whatever a player is on, from lrclib.net, and where the song is
// in them. nothing is asked of the network until something showing them is
// active; every answer is kept on disk, so a track is only looked up once
Item {
    id: src

    property var player: null
    // false while nothing on screen reads the lyrics: no lookup, no frame clock
    property bool active: false

    readonly property string title: src.player ? (src.player.trackTitle || "") : ""
    readonly property string artist: src.player ? (src.player.trackArtist || "") : ""
    readonly property string album: src.player ? (src.player.trackAlbum || "") : ""
    readonly property real length: src.player ? src.player.length : 0
    readonly property bool playing: src.player ? src.player.isPlaying : false
    readonly property string key: src.title === "" ? "" : src.title + "\u0001" + src.artist + "\u0001" + src.album + "\u0001" + Math.round(src.length)
    // "idle" (no track), "loading", "found", "instrumental", "none", "offline"
    property string status: "idle"
    property bool synced: false
    property var lines: []
    property string loadedKey: ""
    // the song's position, moved on every frame between the player's reports
    property real pos: 0
    property real posBase: 0
    property double posStamp: Date.now()
    // the line being sung, -1 before the first; set rather than bound, since it is its own search hint
    property int index: -1
    readonly property var line: src.index >= 0 ? src.lines[src.index] : null
    // 0..1 through the current line
    readonly property real lineProgress: src.line && src.line.end > src.line.t ? Math.max(0, Math.min(1, (src.pos - src.line.t) / (src.line.end - src.line.t))) : 0

    function follow() {
        const i = src.synced ? Lyrics.lineAt(src.lines, src.pos, src.index) : -1;
        if (i !== src.index)
            src.index = i;

    }

    onPosChanged: src.follow()
    onLinesChanged: src.follow()
    onSyncedChanged: src.follow()

    // how far the word at w of the current line has been sung, 0..1
    function wordProgress(l, w) {
        if (!l || w < 0 || w >= l.words.length)
            return 0;

        const wd = l.words[w];
        return wd.end > wd.t ? Math.max(0, Math.min(1, (src.pos - wd.t) / (wd.end - wd.t))) : (src.pos >= wd.t ? 1 : 0);
    }

    function seekLine(i) {
        if (!src.player || !src.player.canSeek || !src.synced || i < 0 || i >= src.lines.length)
            return ;

        src.player.position = src.lines[i].t;
        src.resync(src.lines[i].t);
    }

    function resync(at) {
        src.posBase = at;
        src.posStamp = Date.now();
        src.pos = at;
    }

    function lookup() {
        // a failed lookup is tried again the next time something shows the lyrics
        if (!src.active || (src.key === src.loadedKey && src.status !== "offline"))
            return ;

        src.loadedKey = src.key;
        src.lines = [];
        src.synced = false;
        src.index = -1;
        if (src.key === "") {
            src.status = "idle";
            return ;
        }
        src.status = "loading";
        var h = 5381;
        for (var i = 0; i < src.key.length; i++) h = ((h * 33) ^ src.key.charCodeAt(i)) >>> 0
        fetch.wanted = src.key;
        fetch.file = Quickshell.env("HOME") + "/.cache/lucid/lyrics/" + h.toString(16) + ".json";
        fetch.running = false;
        fetch.command = ["sh", "-c", fetch.script, "sh", fetch.file, src.title, src.artist, src.album, src.length > 0 ? String(Math.round(src.length)) : ""];
        fetch.running = true;
    }

    onKeyChanged: src.lookup()
    onActiveChanged: {
        src.lookup();
        if (src.active && src.player)
            src.resync(src.player.position);

    }
    onPlayerChanged: {
        if (src.player)
            src.resync(src.player.position);

    }
    onPlayingChanged: src.resync(src.pos)

    Connections {
        function onPositionChanged() {
            src.resync(src.player.position);
        }

        target: src.active ? src.player : null
    }

    // mpris doesn't tick the position by itself
    Timer {
        interval: 1000
        repeat: true
        running: src.active && src.playing
        onTriggered: {
            if (src.player)
                src.player.positionChanged();

        }
    }

    FrameAnimation {
        running: src.active && src.playing && src.synced
        onTriggered: src.pos = Math.min(src.length > 0 ? src.length : 1e9, src.posBase + (Date.now() - src.posStamp) / 1000)
    }

    Process {
        id: fetch

        property string wanted: ""
        property string file: ""
        // the exact record first; a search by title and artist if lrclib has none
        // under that album and length. a failed request is not kept, so it is
        // asked again next time the track comes up
        readonly property string script: "f=\"$1\"; d=\"$(dirname \"$f\")\"; mkdir -p \"$d\"; find \"$d\" \\( -name '*.json' -mtime +60 -o -name '*.json.*' -mmin +5 \\) -delete 2>/dev/null; [ -s \"$f\" ] && { cat \"$f\"; exit 0; }; "
            + "ua='lucid (https://github.com/Sn3akyy1/lucid)'; api=https://lrclib.net/api; t=\"$f.$$\"; "
            + "c=$(curl -s --max-time 10 -A \"$ua\" -o \"$t\" -w '%{http_code}' -G \"$api/get\" --data-urlencode \"track_name=$2\" --data-urlencode \"artist_name=$3\" --data-urlencode \"album_name=$4\" ${5:+--data-urlencode \"duration=$5\"}); "
            + "[ \"$c\" = 404 ] && c=$(curl -s --max-time 10 -A \"$ua\" -o \"$t\" -w '%{http_code}' -G \"$api/search\" --data-urlencode \"track_name=$2\" ${3:+--data-urlencode \"artist_name=$3\"}); "
            + "[ \"$c\" = 200 ] && mv \"$t\" \"$f\" && cat \"$f\" && exit 0; rm -f \"$t\"; exit 1"

        // nothing on stdout: the request failed
        stdout: StdioCollector {
            id: answer

            onStreamFinished: fetch.settle(answer.text)
        }

        function settle(text) {
            if (fetch.wanted !== src.loadedKey)
                return ;

            if (text.trim() === "") {
                src.status = "offline";
                return ;
            }
            var r;
            try {
                r = Lyrics.read(JSON.parse(text), src.artist, src.length);
            } catch (e) {
                r = { "status": "none", "synced": false, "lines": [] };
            }
            src.lines = r.lines;
            src.synced = r.synced;
            src.status = r.status;
            // a search answers with every version lrclib has: only the one chosen is kept
            if (r.record && text.trim().charAt(0) === "[") {
                trim.command = ["sh", "-c", "printf '%s' \"$2\" > \"$1\"", "sh", fetch.file, JSON.stringify(r.record)];
                trim.running = true;
            }
        }
    }

    Process {
        id: trim
    }

}
