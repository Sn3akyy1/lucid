import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// LucidShot's recorder: wf-recorder on one display, all of it or a part of it,
// with the speakers and the microphone mixed into one track. it runs detached
// and keeps its state in the runtime dir, so a shell reload never cuts a
// recording short and the next shell picks it back up. the bar's chip, the
// control centre's tile, the privacy pill and the recording controls read this
Singleton {
    id: root

    // "idle" | "countdown" | "recording" | "paused" | "saving"
    property string state: "idle"
    // whole seconds recorded, the pauses left out
    property int seconds: 0
    // seconds left before it starts
    property int countdown: 0
    // the controls were tucked into the bar's chip
    property bool hidden: false
    readonly property bool active: root.state !== "idle"
    readonly property bool live: root.state === "recording" || root.state === "paused"
    // what is recorded: a display, and a part of it in its own logical pixels,
    // or all of it while region is null
    property string output: ""
    property var region: null
    property bool mic: false
    property bool system: true
    // the finished file, once there is one
    property string file: ""
    property string lastError: ""
    readonly property var screen: Quickshell.screens.find((s) => {
        return s.name === root.output;
    }) || null
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string home: Quickshell.env("HOME")
    readonly property string folder: root.expand(Prefs.recordFolder) || root.home + "/Videos"
    // the parts of a paused recording, joined when it stops
    property var segments: []
    // one recording, and one part of it, so a stale marker never counts
    property string token: ""
    property int part: 0
    property real banked: 0
    property real partStart: 0
    property real now: Date.now()
    // "vaapi" | "software", whichever the running part uses
    property string encoder: ""
    property string device: ""
    property string sinkModule: ""
    property string micModule: ""
    property string systemModule: ""
    // what the next exit of the recorder means
    property string expect: ""
    property bool restored: false

    signal showRequested()
    signal saved(string file, int seconds)
    signal failed(string why)

    function clock(sec) {
        const s = Math.max(0, Math.floor(sec));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const tail = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + tail : m + ":" + tail;
    }

    function expand(p) {
        const v = String(p || "").trim();
        if (v === "")
            return "";

        return v === "~" ? root.home : (v.indexOf("~/") === 0 ? root.home + v.substring(1) : v);
    }

    function stamp() {
        return new Date().toLocaleString(Qt.locale("C"), "yyyy-MM-dd_HH-mm-ss");
    }

    // opts: { output, region, mic, system, countdown }
    function arm(opts) {
        if (root.active)
            return ;

        const o = opts || {
        };
        root.output = o.output || "";
        root.region = o.region && o.region.w >= 2 && o.region.h >= 2 ? o.region : null;
        root.mic = o.mic === true;
        root.system = o.system !== false;
        root.hidden = false;
        root.lastError = "";
        root.file = "";
        root.seconds = 0;
        const n = o.countdown !== undefined ? o.countdown : Prefs.recordCountdown;
        root.countdown = Math.max(0, Math.round(n));
        root.state = "countdown";
        // with no countdown it still waits for the overlay to leave the screen
        if (root.countdown > 0)
            countTimer.restart();
        else
            settle.restart();
    }

    function cancel() {
        if (root.state !== "countdown")
            return ;

        countTimer.stop();
        settle.stop();
        root.state = "idle";
        root.countdown = 0;
    }

    function start() {
        if (root.state !== "countdown")
            return ;

        root.token = String(Date.now());
        root.part = 0;
        root.banked = 0;
        root.segments = [];
        root.expect = "";
        root.file = root.folder + "/recording_" + root.stamp() + ".mp4";
        root.encoder = Prefs.recordEncoder === "software" || root.device === "" ? "software" : "vaapi";
        root.partStart = Date.now();
        root.now = root.partStart;
        root.state = "recording";
        root.persist();
        // the mix comes first: wf-recorder reads its track from the null sink
        root.pulse("start", root.audioScript(true, root.mic, root.system), (out) => {
            const ids = out.trim().split(/\s+/);
            root.sinkModule = ids[0] && ids[0] !== "-" ? ids[0] : "";
            root.micModule = ids[1] && ids[1] !== "-" ? ids[1] : "";
            root.systemModule = ids[2] && ids[2] !== "-" ? ids[2] : "";
            root.launch();
        });
    }

    function pause() {
        if (root.state !== "recording" || root.expect !== "")
            return ;

        root.expect = "pause";
        root.persist();
        root.interrupt();
    }

    function resume() {
        if (root.state !== "paused")
            return ;

        root.part++;
        root.state = "recording";
        root.partStart = Date.now();
        root.now = root.partStart;
        root.persist();
        root.pulse("resume", root.audioScript(false, root.mic, root.system), (out) => {
            const ids = out.trim().split(/\s+/);
            root.micModule = ids[1] && ids[1] !== "-" ? ids[1] : "";
            root.systemModule = ids[2] && ids[2] !== "-" ? ids[2] : "";
            root.launch();
        });
    }

    function togglePause() {
        if (root.state === "recording")
            root.pause();
        else if (root.state === "paused")
            root.resume();
    }

    function stop() {
        if (root.state === "countdown") {
            root.cancel();
            return ;
        }
        if (root.state === "recording") {
            root.expect = "stop";
            root.state = "saving";
            root.persist();
            root.interrupt();
        } else if (root.state === "paused") {
            root.state = "saving";
            root.finish();
        }
    }

    function toggle() {
        if (root.active)
            root.stop();
        else
            root.arm({
            "output": Monitors.focusedScreen ? Monitors.focusedScreen.name : "",
            "mic": root.mic,
            "system": root.system
        });
    }

    // a source can come and go mid-recording; leaving it out unloads its
    // loopback, so the microphone is not held open while it is off
    function setMic(on) {
        root.mic = on;
        root.persist();
        if (root.state === "recording")
            root.pulse("mic", on ? root.loopbackScript("mic") : root.unloadScript([root.micModule]), (out) => {
            root.micModule = on ? out.trim() : "";
            root.persist();
        });

    }

    function setSystem(on) {
        root.system = on;
        root.persist();
        if (root.state === "recording")
            root.pulse("system", on ? root.loopbackScript("system") : root.unloadScript([root.systemModule]), (out) => {
            root.systemModule = on ? out.trim() : "";
            root.persist();
        });

    }

    function partPath(n) {
        const f = root.file;
        const slash = f.lastIndexOf("/");
        return f.substring(0, slash + 1) + "." + f.substring(slash + 1).replace(/\.mp4$/, "") + ".part" + n + ".mp4";
    }

    // wf-recorder takes the global layout, the region comes relative to its display
    function geometry() {
        if (!root.region)
            return "";

        const s = root.screen;
        const ox = s ? s.x : 0;
        const oy = s ? s.y : 0;
        // the encoder wants even sides
        const w = Math.max(2, Math.floor(root.region.w / 2) * 2);
        const h = Math.max(2, Math.floor(root.region.h / 2) * 2);
        return Math.round(ox + root.region.x) + "," + Math.round(oy + root.region.y) + " " + w + "x" + h;
    }

    function launch() {
        const target = root.partPath(root.part);
        root.segments = root.segments.filter((p) => {
            return p !== target;
        }).concat([target]);
        root.partStart = Date.now();
        root.now = root.partStart;
        const args = ["wf-recorder", "-y", "-f", target];
        if (root.output !== "")
            args.push("-o", root.output);

        const g = root.geometry();
        if (g !== "")
            args.push("-g", g);

        if (root.sinkModule !== "")
            args.push("--audio=lucidshot_mix.monitor");

        if (root.encoder === "vaapi")
            args.push("-c", "h264_vaapi", "-d", root.device);
        else
            args.push("-c", "libx264", "-x", "yuv420p", "-p", "preset=veryfast", "-p", "crf=21");
        if (Prefs.recordFps > 0)
            args.push("-r", String(Prefs.recordFps));

        root.persist();
        // detached, so a reload does not take the recorder down with this
        // process; the wrapper leaves the pid and, at the end, the exit code
        Quickshell.execDetached(["sh", "-c", "r=\"$1\"; t=\"$2\"; o=\"$3\"; shift 3; " + "mkdir -p \"$o\" || { printf '%s 127\\n' \"$t\" > \"$r/lucid-shot-rec.exit\"; exit 1; }; " + "\"$@\" </dev/null >\"$r/lucid-shot-rec.log\" 2>&1 & p=$!; " + "printf '%s %s\\n' \"$t\" \"$p\" > \"$r/lucid-shot-rec.pid\"; " + "wait \"$p\"; c=$?; printf '%s %s\\n' \"$t\" \"$c\" > \"$r/lucid-shot-rec.exit\"", "sh", root.runDir, root.token + ":" + root.part, target.substring(0, target.lastIndexOf("/"))].concat(args));
    }

    // SIGINT, which wf-recorder takes as "finish the file"
    function interrupt() {
        Quickshell.execDetached(["sh", "-c", "read t p < \"$1/lucid-shot-rec.pid\" && [ \"$t\" = \"$2\" ] && kill -INT \"$p\"", "sh", root.runDir, root.token + ":" + root.part]);
    }

    function audioScript(withSink, mic, system) {
        let s = "S=-; M=-; Y=-; command -v pactl >/dev/null 2>&1 || { echo '- - -'; exit 0; }; ";
        if (withSink)
            s += "pactl unload-module module-null-sink 2>/dev/null >/dev/null; S=$(pactl load-module module-null-sink sink_name=lucidshot_mix sink_properties=device.description=LucidShot 2>/dev/null) || S=-; ";

        if (mic)
            s += "M=$(" + root.loopbackScript("mic") + ") || M=-; ";

        if (system)
            s += "Y=$(" + root.loopbackScript("system") + ") || Y=-; ";

        return s + "echo \"$S $M $Y\"";
    }

    function loopbackScript(which) {
        const source = which === "mic" ? "$(pactl get-default-source)" : "$(pactl get-default-sink).monitor";
        return "pactl load-module module-loopback source=\"" + source + "\" sink=lucidshot_mix latency_msec=30 source_dont_move=true sink_dont_move=true sink_input_properties=media.name=lucidshot-" + which + " 2>/dev/null";
    }

    function unloadScript(ids) {
        const list = ids.filter((i) => {
            return i !== "" && i !== "-";
        });
        return list.length === 0 ? "true" : list.map((i) => {
            return "pactl unload-module " + i + " 2>/dev/null";
        }).join("; ") + "; true";
    }

    // the parts become one file. one part is remuxed, so it gets the faststart
    // index; several are joined without encoding again
    function finish() {
        root.expect = "";
        root.persist();
        Quickshell.execDetached(["sh", "-c", root.unloadScript([root.micModule, root.systemModule, root.sinkModule])]);
        root.micModule = "";
        root.systemModule = "";
        root.sinkModule = "";
        // the parts sit beside the file under names of our own, so the list
        // names them bare and never has to quote a folder
        const parts = root.segments.map((p) => {
            return p.substring(p.lastIndexOf("/") + 1);
        });
        const fix = root.encoder === "vaapi" ? root.vaapiFix + " " : "";
        Quickshell.execDetached(["sh", "-c", "r=\"$1\"; t=\"$2\"; out=\"$3\"; shift 3; " + "mark() { printf '%s\\t%s\\t%s\\n' \"$t\" \"$1\" \"$out\" > \"$r/lucid-shot-rec.done\"; }; " + "cd \"$(dirname \"$out\")\" || { mark 1; exit 0; }; " + "list=\".lucidshot-$t.txt\"; : > \"$list\"; n=0; " + "for p in \"$@\"; do [ -s \"$p\" ] && { printf \"file '%s'\\n\" \"$p\" >> \"$list\"; n=$((n+1)); }; done; " + "if [ $n -eq 0 ]; then rm -f \"$list\" \"$@\"; mark 2; exit 0; fi; " + "ffmpeg -v error -y -f concat -safe 0 -i \"$list\" -c copy " + fix + "-movflags +faststart \"$out\" </dev/null; c=$?; " + "rm -f \"$list\"; [ $c -eq 0 ] && rm -f \"$@\"; mark $c", "sh", root.runDir, root.token, root.file].concat(parts));
    }

    // what the hardware encoder leaves out of the stream: it encodes the full
    // range of the screen's colours but does not say so, and players read it
    // as limited range, washed out
    readonly property string vaapiFix: "-bsf:v h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1:video_full_range_flag=1"

    function reset() {
        root.state = "idle";
        root.seconds = 0;
        root.countdown = 0;
        root.hidden = false;
        root.expect = "";
        root.segments = [];
        root.token = "";
        root.persist();
    }

    // the recorder left: asked to (a pause or a stop) or not
    function exited(code) {
        // only a running part can end; a paused recording has none
        if (!(root.state === "recording" || (root.state === "saving" && root.expect === "stop")))
            return ;

        const ran = Date.now() - root.partStart;
        if (root.expect === "pause") {
            root.banked += Math.max(0, ran);
            root.expect = "";
            root.state = "paused";
            root.persist();
            // nothing listens while it is paused
            root.pulse("pause", root.unloadScript([root.micModule, root.systemModule]), () => {
                root.micModule = "";
                root.systemModule = "";
                root.persist();
            });
            return ;
        }
        if (root.expect === "stop") {
            root.banked += Math.max(0, ran);
            root.finish();
            return ;
        }
        // it never got going: the hardware encoder is the usual reason
        if (ran < 2500 && root.encoder === "vaapi" && Prefs.recordEncoder !== "hardware") {
            const dud = root.partPath(root.part);
            root.segments = root.segments.filter((p) => {
                return p !== dud;
            });
            Quickshell.execDetached(["rm", "-f", dud]);
            root.encoder = "software";
            root.part++;
            root.launch();
            return ;
        }
        root.banked += Math.max(0, ran);
        root.lastError = ran < 2500 ? "The recorder stopped straight away" : "The recorder stopped on its own";
        root.state = "saving";
        root.finish();
    }

    function persist() {
        stateFile.setText(root.state === "idle" ? "{}" : JSON.stringify({
            "state": root.state,
            "token": root.token,
            "part": root.part,
            "segments": root.segments,
            "file": root.file,
            "output": root.output,
            "region": root.region,
            "mic": root.mic,
            "system": root.system,
            "banked": root.banked,
            "partStart": root.partStart,
            "encoder": root.encoder,
            "expect": root.expect,
            "hidden": root.hidden,
            "modules": [root.sinkModule, root.micModule, root.systemModule]
        }));
    }

    // a recording that was running when the shell went down carries on
    function restore() {
        let s = {
        };
        try {
            s = JSON.parse(stateFile.text() || "{}");
        } catch (e) {
            s = {
            };
        }
        if (s.state === "recording" || s.state === "paused" || s.state === "saving") {
            root.token = s.token || "";
            root.part = s.part || 0;
            root.segments = s.segments || [];
            root.file = s.file || "";
            root.output = s.output || "";
            root.region = s.region || null;
            root.mic = s.mic === true;
            root.system = s.system !== false;
            root.banked = s.banked || 0;
            root.partStart = s.partStart || Date.now();
            root.encoder = s.encoder || "software";
            root.expect = s.expect || "";
            root.hidden = s.hidden === true;
            const m = s.modules || [];
            root.sinkModule = m[0] || "";
            root.micModule = m[1] || "";
            root.systemModule = m[2] || "";
            root.state = s.state;
            if (root.state === "recording")
                alive.running = true;

        }
        root.restored = true;
    }

    // pactl calls, one after another
    property var _queue: []

    function pulse(tag, script, done) {
        root._queue = root._queue.concat([{
            "script": script,
            "done": done
        }]);
        if (!pa.running)
            root._next();

    }

    function _next() {
        if (root._queue.length === 0)
            return ;

        const job = root._queue[0];
        pa.job = job;
        root._queue = root._queue.slice(1);
        pa.command = ["sh", "-c", job.script];
        pa.running = true;
    }

    // the bar's chip asks for the controls back
    onShowRequested: root.hidden = false
    onHiddenChanged: {
        if (root.live)
            root.persist();

    }
    Component.onCompleted: root.restore()

    Process {
        id: pa

        property var job: null

        stdout: StdioCollector {
            onStreamFinished: {
                const j = pa.job;
                pa.job = null;
                if (j && j.done)
                    j.done(this.text);

                root._next();
            }
        }

    }

    // the first render node there is, for the hardware encoder
    Process {
        running: true
        command: ["sh", "-c", "for d in /dev/dri/renderD*; do [ -r \"$d\" ] && { echo \"$d\"; exit 0; }; done"]

        stdout: StdioCollector {
            onStreamFinished: root.device = this.text.trim()
        }

    }

    // a restored recording whose recorder is gone ended while no shell watched
    Process {
        id: alive

        command: ["sh", "-c", "read t p < \"$1/lucid-shot-rec.pid\" && [ \"$t\" = \"$2\" ] && kill -0 \"$p\"", "sh", root.runDir, root.token + ":" + root.part]
        onExited: (code) => {
            if (code !== 0 && root.state === "recording")
                root.exited(-1);

        }
    }

    FileView {
        id: stateFile

        path: root.runDir + "/lucid-shot-rec.json"
        blockLoading: true
        printErrors: false
    }

    // written by the wrapper as the recorder exits: "<token>:<part> <code>"
    FileView {
        id: exitMark

        path: root.restored ? root.runDir + "/lucid-shot-rec.exit" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: exitMark.reload()
        // one write can be read twice
        property string handled: ""

        onLoaded: {
            const line = exitMark.text().trim();
            const f = line.split(" ");
            if (f.length < 2 || f[0] !== root.token + ":" + root.part || line === exitMark.handled)
                return ;

            exitMark.handled = line;
            root.exited(parseInt(f[1]));
        }
    }

    // written once the parts are one file: "<token>\t<code>\t<file>"
    FileView {
        id: doneMark

        path: root.restored ? root.runDir + "/lucid-shot-rec.done" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: doneMark.reload()
        onLoaded: {
            const f = doneMark.text().trim().split("\t");
            if (f.length < 3 || f[0] !== root.token || root.state !== "saving")
                return ;

            const code = parseInt(f[1]);
            const secs = Math.round(root.banked / 1000);
            const out = f[2];
            const why = root.lastError;
            root.reset();
            if (code === 0) {
                root.file = out;
                root.saved(out, secs);
            } else {
                root.failed(code === 2 ? (why || "Nothing was recorded") : "The recording could not be put together");
            }
        }
    }

    Timer {
        id: countTimer

        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0) {
                countTimer.stop();
                root.start();
            }
        }
    }

    Timer {
        id: settle

        interval: 260
        onTriggered: root.start()
    }

    Timer {
        interval: 250
        repeat: true
        running: root.live
        onTriggered: {
            root.now = Date.now();
            const run = root.state === "recording" ? Math.max(0, root.now - root.partStart) : 0;
            root.seconds = Math.floor((root.banked + run) / 1000);
        }
    }

    IpcHandler {
        // qs ipc call recorder toggle
        function toggle(): void {
            root.toggle();
        }

        function start(): void {
            if (!root.active)
                root.toggle();

        }

        function stop(): void {
            root.stop();
        }

        function pause(): void {
            root.togglePause();
        }

        function status(): string {
            return JSON.stringify({
                "state": root.state,
                "seconds": root.seconds,
                "file": root.file,
                "output": root.output,
                "region": root.region,
                "encoder": root.encoder,
                "mic": root.mic,
                "system": root.system,
                "parts": root.segments.length
            });
        }

        target: "recorder"
    }

}
