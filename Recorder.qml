import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// screen recording through wf-recorder: the whole focused output, optionally
// with what the speakers are playing. stopping sends SIGINT so the file closes cleanly
Singleton {
    id: root

    property bool available: false
    property bool recording: false
    property real startedAt: 0
    property real now: Date.now()
    property string file: ""
    readonly property real elapsed: root.recording ? root.now - root.startedAt : 0
    readonly property string dir: Quickshell.env("HOME") + "/Videos/Recordings"

    function clock(ms) {
        var s = Math.floor(ms / 1000);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    function start() {
        if (root.recording || !root.available)
            return ;

        var scr = Monitors.focusedScreen || Monitors.mainScreen;
        var stamp = new Date().toLocaleString(Qt.locale("C"), "yyyy-MM-dd_HH-mm-ss");
        root.file = root.dir + "/lucid-" + stamp + ".mp4";
        var args = ["wf-recorder", "-y", "-f", root.file];
        if (scr && scr.name)
            args.push("-o", scr.name);

        if (Prefs.recordAudio)
            args.push("--audio");

        rec.command = ["sh", "-c", "mkdir -p \"$1\" && shift && exec \"$@\"", "sh", root.dir].concat(args);
        rec.running = true;
        root.startedAt = Date.now();
        root.now = root.startedAt;
        root.recording = true;
    }

    function stop() {
        if (!root.recording)
            return ;

        rec.signal(2);
    }

    function toggle() {
        if (root.recording)
            root.stop();
        else
            root.start();
    }

    Timer {
        interval: 500
        repeat: true
        running: root.recording
        onTriggered: root.now = Date.now()
    }

    Process {
        id: probe

        running: true
        command: ["sh", "-c", "command -v wf-recorder >/dev/null"]
        onExited: (code) => {
            return root.available = code === 0;
        }
    }

    Process {
        id: rec

        onExited: (code) => {
            var took = Date.now() - root.startedAt;
            root.recording = false;
            // under a second means it never really started
            if (took < 1000)
                Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "-i", "media-record", "Recording failed", "wf-recorder stopped straight away"]);
            else if (Prefs.shotPreview === "preview")
                // the same hand-off the overlay's recordings use, so the preview card shows it
                Quickshell.execDetached(["sh", "-c", "printf '%s\\t%s\\n' \"$(date +%s%N)\" \"$1\" > \"$2\"", "sh", root.file, (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-recording-saved"]);
            else if (Prefs.shotPreview === "notify")
                Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "-i", "media-record", "Recording saved", root.file.replace(Quickshell.env("HOME"), "~") + "  ·  " + root.clock(took)]);
        }
    }

    IpcHandler {
        // qs ipc call recorder toggle
        function toggle(): void {
            root.toggle();
        }

        function start(): void {
            root.start();
        }

        function stop(): void {
            root.stop();
        }

        target: "recorder"
    }

}
