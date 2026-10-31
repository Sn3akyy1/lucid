import QtQuick
import Quickshell
import Quickshell.Io
import qs

// what LucidShot does with a picture once it has one: cuts it out of the frozen
// frame or takes it live, saves it, copies it and says it is ready. it also
// reads the text in one, and turns a recording into a gif. the overlay, the
// cards, the pins and the ipc all come through here
Scope {
    id: engine

    // the result cards: a live capture clears them off the screen first
    property var cards: null
    readonly property string home: Quickshell.env("HOME")
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-shot"
    // captures that were only copied get a folder of their own: lens shows the
    // folder a file is in, and runDir is full of the overlay's working files
    readonly property string copyDir: engine.runDir + "/copied"
    readonly property string shotDir: Capture.expand(Prefs.shotFolder) || engine.home + "/Pictures/screenshots"
    // resolved against this file, so it works from the repo or the install dir
    readonly property string ocrScript: Qt.resolvedUrl("ocr.py").toString().replace("file://", "")
    property int serial: 0
    property var _jobs: []
    property var _after: null

    // reads asked for over ipc, which nothing on screen is waiting on
    property var loose: ({
    })

    // a capture is saved, or on the clipboard: { id, kind, file, w, h, temp,
    // screen, owner }. owner says who shows it: "overlay" made its card already,
    // "pin" pins it, anything else is for the shell to announce
    signal ready(var entry)
    signal failed(string id, string why)
    // { id, status: "ok" | "empty" | "notool" | "fail", text, codes }
    signal textRead(var result)
    // { id, source, file, ok }
    signal gifMade(var result)

    function nextId() {
        engine.serial++;
        return "shot-" + Date.now() + "-" + engine.serial;
    }

    function baseName() {
        return "screenshot_" + new Date().toLocaleString(Qt.locale("C"), "yyyy-MM-dd_HH-mm-ss");
    }

    function fileUrl(path) {
        return "file://" + String(path).split("/").map((p) => {
            return encodeURIComponent(p);
        }).join("/");
    }

    // the display a live capture takes, read when the command is built: one held
    // in a binding can be a display gone since start-up
    function outputName(scr) {
        const live = Quickshell.screens.map((s) => {
            return s.name;
        });
        for (const s of [scr, Monitors.focusedScreen]) {
            const name = s ? String(s.name || "") : "";
            if (name !== "" && live.indexOf(name) !== -1)
                return name;

        }
        return "";
    }

    // a part of the frozen frame, which is what the user chose it on.
    // rect is in the overlay's logical pixels; the frame is in the display's own
    function crop(src, rect, scale, opts) {
        const o = opts || {
        };
        const id = o.id || engine.nextId();
        const k = scale > 0 ? scale : 1;
        const pw = Math.max(1, Math.round(rect.w * k));
        const ph = Math.max(1, Math.round(rect.h * k));
        const geom = pw + "x" + ph + "+" + Math.max(0, Math.round(rect.x * k)) + "+" + Math.max(0, Math.round(rect.y * k));
        const r = o.round > 0 ? Math.round(o.round * k) : 0;
        const save = o.save !== undefined ? o.save : Prefs.shotSaveFile;
        engine.run(["sh", "-c", engine.cutScript, "sh", src, save ? engine.shotDir : engine.copyDir, o.base || engine.baseName(), geom, String(r), String(pw - 1), String(ph - 1)], (code, out) => {
            const f = out.trim();
            if (code !== 0 || f === "") {
                engine.failed(id, "The capture could not be saved");
                return ;
            }
            engine.landed({
                "id": id,
                "kind": "image",
                "file": f,
                "w": pw,
                "h": ph,
                "temp": !save,
                "screen": o.screen || "",
                "owner": o.owner || ""
            });
        });
        return id;
    }

    // what the editor drew, grabbed to a file of its own; made a png in place
    function adopt(grabbed, w, h, opts) {
        const o = opts || {
        };
        const id = o.id || engine.nextId();
        const save = o.save !== undefined ? o.save : Prefs.shotSaveFile;
        engine.run(["sh", "-c", engine.adoptScript, "sh", grabbed, save ? (o.dir || engine.shotDir) : engine.copyDir, o.base || engine.baseName()], (code, out) => {
            const f = out.trim();
            if (code !== 0 || f === "") {
                engine.failed(id, "The capture could not be saved");
                return ;
            }
            engine.landed({
                "id": id,
                "kind": "image",
                "file": f,
                "w": w,
                "h": h,
                "temp": !save,
                "screen": o.screen || "",
                "edited": true,
                "owner": o.owner || ""
            });
        });
        return id;
    }

    // straight off the screen, for the timer and the shortcuts. geom is in the
    // global layout; address re-reads a window's place, in case it moved
    function live(scr, geom, opts) {
        const o = opts || {
        };
        const id = o.id || engine.nextId();
        const save = o.save !== undefined ? o.save : Prefs.shotSaveFile;
        const out = engine.outputName(scr);
        engine.whenClear(() => {
            engine.run(["sh", "-c", engine.liveScript, "sh", out, save ? engine.shotDir : engine.copyDir, engine.baseName(), geom || "", String(o.round > 0 ? Math.round(o.round) : 0), o.address || ""], (code, text) => {
                const f = text.trim().split("\t");
                if (code !== 0 || f.length < 3) {
                    engine.failed(id, "The screen could not be captured");
                    return ;
                }
                engine.landed({
                    "id": id,
                    "kind": "image",
                    "file": f[0],
                    "w": parseInt(f[1]) || 0,
                    "h": parseInt(f[2]) || 0,
                    "temp": !save,
                    "screen": out,
                    "owner": o.owner || ""
                });
            });
        });
        return id;
    }

    // the focused window, live
    function activeWindow(scr) {
        engine.run(["sh", "-c", "hyprctl -j activewindow 2>/dev/null | jq -r 'if .at then \"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\\t\\(.address)\" else \"\" end'"], (code, out) => {
            const f = out.trim().split("\t");
            if (f[0] === "")
                engine.live(scr, "", {
            });
            else
                engine.live(scr, f[0], {
                "round": HyprConfig.num("decoration.rounding", 0),
                "address": f[1] || ""
            });
        });
    }

    // true once, for a read nothing on screen asked for
    function claim(id) {
        if (!engine.loose[id])
            return false;

        const l = Object.assign({
        }, engine.loose);
        delete l[id];
        engine.loose = l;
        return true;
    }

    function ocrLang() {
        return Prefs.shotOcrLang || "eng";
    }

    // text off a part of the frozen frame, or off the live screen when src is
    // empty. ocr.py reads a copy and a negated copy at once, puts lines that
    // only wrapped on screen back together and keeps the emoji; tesseract's
    // own lines are the fallback when it cannot run
    function readText(src, rect, scale, opts) {
        const o = opts || {
        };
        const id = o.id || engine.nextId();
        let geom = "";
        if (rect && rect.w > 0 && rect.h > 0) {
            if (src !== "") {
                const k = scale > 0 ? scale : 1;
                geom = Math.round(rect.w * k) + "x" + Math.round(rect.h * k) + "+" + Math.round(rect.x * k) + "+" + Math.round(rect.y * k);
            } else {
                geom = rect.geom || "";
            }
        }
        const go = () => {
            ocr.queue = ocr.queue.concat([{
                "id": id,
                "command": ["sh", "-c", engine.readScript, "sh", engine.runDir + "/ocr", src, geom, engine.outputName(o.screenObj || null), engine.ocrScript, engine.ocrLang()]
            }]);
            if (!ocr.running)
                ocr.next();

        };
        if (src === "")
            engine.whenClear(go);
        else
            go();
        return id;
    }

    function toGif(file, opts) {
        const o = opts || {
        };
        gif.queue = gif.queue.concat([{
            "id": o.id || engine.nextId(),
            "source": file
        }]);
        if (!gif.running)
            gif.next();

    }

    function copyImage(file) {
        Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"", "sh", file]);
    }

    function copyFile(file) {
        Quickshell.execDetached(["wl-copy", "--type", "text/uri-list", engine.fileUrl(file)]);
    }

    function copyText(text) {
        Quickshell.execDetached(["wl-copy", "--", text]);
    }

    function open(file) {
        Quickshell.execDetached(["xdg-open", file]);
    }

    // a capture goes to lens by name, whatever opens that kind of file by
    // default. it shows up with the rest of its folder beside it
    function view(file) {
        Quickshell.execDetached([Quickshell.shellPath("lucidlens/lens"), file]);
    }

    // a file manager that speaks FileManager1 opens the folder with the file
    // already picked out; anything else just gets the folder
    function reveal(file) {
        Quickshell.execDetached(["sh", "-c", "gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems \"['$1']\" '' >/dev/null 2>&1 || xdg-open \"$2\"", "sh", engine.fileUrl(file), file.substring(0, file.lastIndexOf("/"))]);
    }

    // the trash first, so a slip can be undone from the file manager
    function trash(file) {
        Quickshell.execDetached(["sh", "-c", "gio trash \"$1\" 2>/dev/null || rm -f \"$1\"", "sh", file]);
    }

    // a capture that was only copied goes to the screenshots folder after all
    function keep(file, done) {
        engine.run(["sh", "-c", "dir=\"$1\"; src=\"$2\"; b=$(basename \"$src\" .png); mkdir -p \"$dir\" || exit 1; f=\"$dir/$b.png\"; n=2; while [ -e \"$f\" ]; do f=\"$dir/$b-$n.png\"; n=$((n+1)); done; mv \"$src\" \"$f\" && echo \"$f\"", "sh", engine.shotDir, file], (code, out) => {
            if (done)
                done(code === 0 ? out.trim() : "");

        });
    }

    function search(text) {
        Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(String(text).substring(0, 400))]);
    }

    // a live capture must not have the card in it: the card is drawn empty for
    // a frame first, without unmapping (that would set off the compositor's fade)
    function whenClear(fn) {
        if (engine.cards && engine.cards.onScreen) {
            engine.cards.hideNow();
            engine._after = fn;
            clearTimer.restart();
            return ;
        }
        fn();
    }

    function landed(entry) {
        if (entry.kind === "image")
            Sounds.event("capture", Prefs.soundOnCapture);

        engine.ready(entry);
    }

    // jobs that write a capture run one after another, so two never take the same name
    function run(command, done) {
        engine._jobs = engine._jobs.concat([{
            "command": command,
            "done": done
        }]);
        if (!job.running)
            engine._next();

    }

    function _next() {
        if (engine._jobs.length === 0)
            return ;

        job.current = engine._jobs[0];
        engine._jobs = engine._jobs.slice(1);
        job.command = job.current.command;
        job.running = true;
    }

    // names never clash: a second capture in the same second gets -2, -3...
    readonly property string pickName: "mkdir -p \"$dir\" || exit 1; f=\"$dir/$base.png\"; n=2; while [ -e \"$f\" ]; do f=\"$dir/$base-$n.png\"; n=$((n+1)); done; "
    readonly property string imSetup: "if command -v magick >/dev/null 2>&1; then IM=magick; ID='magick identify'; else IM=convert; ID=identify; fi; "
    // png compression 3, not the default 6: a full screen saves in about a third
    // of the time for files about a tenth bigger, and the card waits on the file
    readonly property string level: " -define png:compression-level=3 "
    readonly property string roundCut: "\\( +clone -alpha extract -fill black -colorize 100 -fill white -draw \"roundrectangle 0,0 $mx,$my $r,$r\" \\) -alpha off -compose CopyOpacity -composite"
    readonly property string cutScript: "src=\"$1\"; dir=\"$2\"; base=\"$3\"; geom=\"$4\"; r=\"$5\"; mx=\"$6\"; my=\"$7\"; " + engine.imSetup + engine.pickName + "if [ \"$r\" -gt 0 ]; then $IM \"$src\" -crop \"$geom\" +repage " + engine.roundCut + engine.level + "\"$f\" || exit 1; " + "else $IM \"$src\" -crop \"$geom\" +repage" + engine.level + "\"$f\" || exit 1; fi; " + "wl-copy --type image/png < \"$f\" >/dev/null 2>&1; echo \"$f\""
    readonly property string adoptScript: "src=\"$1\"; dir=\"$2\"; base=\"$3\"; " + engine.imSetup + engine.pickName + "$IM \"$src\"" + engine.level + "\"$f\" || exit 1; rm -f \"$src\"; " + "wl-copy --type image/png < \"$f\" >/dev/null 2>&1; echo \"$f\""
    readonly property string liveScript: "out=\"$1\"; dir=\"$2\"; base=\"$3\"; geom=\"$4\"; r=\"$5\"; addr=\"$6\"; " + engine.imSetup + engine.pickName + "if [ -n \"$addr\" ]; then g=$(hyprctl -j clients 2>/dev/null | jq -r --arg a \"$addr\" '.[] | select(.address == $a) | \"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"' | head -1); [ -n \"$g\" ] && geom=\"$g\"; fi; " + "if [ -n \"$geom\" ]; then grim -l 3 -g \"$geom\" \"$f\" || exit 1; elif [ -n \"$out\" ]; then grim -l 3 -o \"$out\" \"$f\" || exit 1; else grim -l 3 \"$f\" || exit 1; fi; " + "set -- $($ID -format '%w %h' \"$f\"); w=$1; h=$2; " + "if [ \"$r\" -gt 0 ] && [ -n \"$w\" ]; then mx=$((w - 1)); my=$((h - 1)); $IM \"$f\" " + engine.roundCut + engine.level + "\"$f\"; fi; " + "wl-copy --type image/png < \"$f\" >/dev/null 2>&1; printf '%s\\t%s\\t%s\\n' \"$f\" \"$w\" \"$h\""
    readonly property string readScript: "dir=\"$1\"; src=\"$2\"; geom=\"$3\"; out=\"$4\"; reader=\"$5\"; lang=\"$6\"; " + "command -v tesseract >/dev/null 2>&1 || { echo notool; exit 0; }; " + engine.imSetup + "mkdir -p \"$dir\" && rm -f \"$dir\"/a.txt \"$dir\"/b.txt; shot=\"$dir/shot.png\"; up=\"$dir/up.png\"; inv=\"$dir/inv.png\"; " + "if [ -n \"$src\" ]; then if [ -n \"$geom\" ]; then $IM \"$src\" -crop \"$geom\" +repage \"$shot\"; else $IM \"$src\" \"$shot\"; fi; " + "elif [ -n \"$geom\" ]; then grim -g \"$geom\" \"$shot\"; elif [ -n \"$out\" ]; then grim -o \"$out\" \"$shot\"; else grim \"$shot\"; fi || { echo fail; exit 0; }; " + "w=$($ID -format %w \"$shot\" 2>/dev/null); grow=''; [ \"${w:-0}\" -lt 1200 ] && grow='-resize 300%'; " + "$IM \"$shot\" -alpha remove -colorspace gray $grow -sharpen 0x1 -normalize \"$up\" && $IM \"$up\" -negate \"$inv\"; " + "codes=''; command -v zbarimg >/dev/null 2>&1 && codes=$(zbarimg -q --raw \"$shot\" 2>/dev/null); " + "txt=$(python3 \"$reader\" \"$shot\" \"$up\" \"$inv\" \"$lang\" 2>/dev/null | sed -e 's/[[:space:]]*$//' -e '/./,$!d'); " + "if [ -z \"$txt\" ]; then " + "tesseract \"$up\" \"$dir/a\" -l \"$lang\" --dpi 300 >/dev/null 2>&1; tesseract \"$inv\" \"$dir/b\" -l \"$lang\" --dpi 300 >/dev/null 2>&1; " + "size() { [ -s \"$1\" ] && wc -c < \"$1\" || echo 0; }; " + "if [ \"$(size \"$dir/b.txt\")\" -gt \"$(size \"$dir/a.txt\")\" ]; then best=\"$dir/b.txt\"; else best=\"$dir/a.txt\"; fi; " + "txt=$(sed -e 's/[[:space:]]*$//' -e '/./,$!d' \"$best\" 2>/dev/null); fi; " + "if [ -z \"$txt\" ] && [ -z \"$codes\" ]; then echo empty; exit 0; fi; " + "echo ok; printf '%s\\n' \"$codes\" | sed 's/^/@code /'; printf '%s' \"$txt\""

    Timer {
        id: clearTimer

        interval: 80
        onTriggered: {
            const fn = engine._after;
            engine._after = null;
            if (fn)
                fn();

        }
    }

    Process {
        id: job

        property var current: null
        // the output closing and the exit can come in either order; a job is
        // done once both are in
        property int code: -1
        property bool drained: false
        property bool ended: false

        function settle() {
            if (!job.drained || !job.ended)
                return ;

            const j = job.current;
            job.current = null;
            job.drained = false;
            job.ended = false;
            if (j && j.done)
                j.done(job.code, jobOut.text);

            Qt.callLater(engine._next);
        }

        onStarted: {
            job.drained = false;
            job.ended = false;
        }
        onExited: (code) => {
            job.code = code;
            job.ended = true;
            job.settle();
        }

        stdout: StdioCollector {
            id: jobOut

            onStreamFinished: {
                job.drained = true;
                job.settle();
            }
        }

    }

    Process {
        id: ocr

        property var queue: []
        property string current: ""
        property bool drained: false
        property bool ended: false

        function next() {
            if (ocr.running || ocr.queue.length === 0)
                return ;

            const j = ocr.queue[0];
            ocr.queue = ocr.queue.slice(1);
            ocr.current = j.id;
            ocr.command = j.command;
            ocr.running = true;
        }

        function settle() {
            if (!ocr.drained || !ocr.ended)
                return ;

            ocr.drained = false;
            ocr.ended = false;
            const t = ocrOut.text;
            const nl = t.indexOf("\n");
            const status = (nl < 0 ? t : t.substring(0, nl)).trim();
            const lines = (nl < 0 ? "" : t.substring(nl + 1)).split("\n");
            const codes = [];
            while (lines.length > 0 && lines[0].indexOf("@code") === 0) {
                const c = lines.shift().substring(5).trim();
                if (c !== "")
                    codes.push(c);

            }
            const text = lines.join("\n");
            if (status === "ok" && text !== "")
                engine.copyText(text);
            else if (status === "ok" && codes.length > 0)
                engine.copyText(codes[0]);
            engine.textRead({
                "id": ocr.current,
                "status": status === "" ? "fail" : status,
                "text": text,
                "codes": codes
            });
            Qt.callLater(ocr.next);
        }

        onStarted: {
            ocr.drained = false;
            ocr.ended = false;
        }
        onExited: {
            ocr.ended = true;
            ocr.settle();
        }

        stdout: StdioCollector {
            id: ocrOut

            onStreamFinished: {
                ocr.drained = true;
                ocr.settle();
            }
        }

    }

    Process {
        id: gif

        property var queue: []
        property var current: null

        function next() {
            if (gif.queue.length === 0)
                return ;

            gif.current = gif.queue[0];
            gif.queue = gif.queue.slice(1);
            // 15 fps and at most 960 wide, a palette made for this clip, and
            // only the changed rectangle redrawn per frame: small enough to send
            gif.command = ["sh", "-c", "src=\"$1\"; b=\"${src%.*}\"; f=\"$b.gif\"; n=2; while [ -e \"$f\" ]; do f=\"$b-$n.gif\"; n=$((n+1)); done; " + "ffmpeg -v error -y -i \"$src\" -vf \"fps=15,scale='min(960,iw)':-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle\" -loop 0 \"$f\" </dev/null && echo \"$f\"", "sh", gif.current.source];
            gif.running = true;
        }

        property int code: -1
        property bool drained: false
        property bool ended: false

        function settle() {
            if (!gif.drained || !gif.ended)
                return ;

            const j = gif.current;
            gif.current = null;
            gif.drained = false;
            gif.ended = false;
            const f = gifOut.text.trim();
            if (j)
                engine.gifMade({
                "id": j.id,
                "source": j.source,
                "file": gif.code === 0 ? f : "",
                "ok": gif.code === 0 && f !== ""
            });

            Qt.callLater(gif.next);
        }

        onStarted: {
            gif.drained = false;
            gif.ended = false;
        }
        onExited: (code) => {
            gif.code = code;
            gif.ended = true;
            gif.settle();
        }

        stdout: StdioCollector {
            id: gifOut

            onStreamFinished: {
                gif.drained = true;
                gif.settle();
            }
        }
    }

    IpcHandler {
        // qs ipc call screenshot full
        function full(): void {
            engine.live(Monitors.focusedScreen, "", {
            });
        }

        function window(): void {
            engine.activeWindow(Monitors.focusedScreen);
        }

        function text(): void {
            const id = engine.readText("", null, 1, {
                "screenObj": Monitors.focusedScreen
            });
            const l = Object.assign({
            }, engine.loose);
            l[id] = true;
            engine.loose = l;
        }

        target: "screenshot"
    }

}
