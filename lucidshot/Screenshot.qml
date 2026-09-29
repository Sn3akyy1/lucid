import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: flashWindow

    property string saveDir: Quickshell.env("HOME") + "/Pictures/screenshots"
    signal captured()
    // a capture or recording landed on disk; the preview card shows it
    signal saved(string file, string kind)
    // the card, so a live grab can clear it off the screen first
    property var shotPreview: null
    property var afterClear: null

    // true when the card was up: it is gone now, and fn runs a frame later
    function clearFirst(fn) {
        if (!flashWindow.shotPreview || !flashWindow.shotPreview.onScreen)
            return false;
        flashWindow.shotPreview.hideNow();
        flashWindow.afterClear = fn;
        clearTimer.restart();
        return true;
    }

    Timer {
        id: clearTimer

        interval: 80
        onTriggered: {
            var fn = flashWindow.afterClear;
            flashWindow.afterClear = null;
            if (fn)
                fn();
        }
    }

    // what follows a saved capture, per Prefs.shotPreview: the preview card,
    // the notification it replaces, or nothing (it is on the clipboard already)
    function announce(file, kind) {
        if (Prefs.shotPreview === "preview") {
            flashWindow.saved(file, kind);
        } else if (Prefs.shotPreview === "notify") {
            if (kind === "video")
                Quickshell.execDetached(["notify-send", "Recording saved", "Saved to " + file]);
            else
                Quickshell.execDetached(["sh", "-c", "ACTION=$(notify-send 'Screenshot taken!' \"Saved to $1\" -i \"$1\" -A 'open=Open Screenshot' --wait) && [ \"$ACTION\" = open ] && swappy -f \"$1\"; true", "sh", file]);
        }
    }

    // grim with no -o stitches every display into one image, and the flash
    // belongs on the display that was captured, so both follow the focus
    readonly property string output: flashWindow.screen ? flashWindow.screen.name : ""
    readonly property string grimHere: flashWindow.output !== "" ? "grim -o '" + flashWindow.output + "'" : "grim"

    function aimHere() {
        if (Monitors.focusedScreen)
            flashWindow.screen = Monitors.focusedScreen;

    }

    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {}

    function timestampedPath() {
        var d = new Date();
        function pad(n) {
            return (n < 10 ? "0" : "") + n;
        }
        var name = "screenshot_" + d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "_" + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds()) + ".png";
        return flashWindow.saveDir + "/" + name;
    }

    readonly property string imSetup: "command -v magick >/dev/null 2>&1 && IM=magick || IM=convert; "
    // png compression 3, not the default 6: a full screen saves in about a
    // third of the time (0.6 s rather than 2.9 through the overlay) for
    // files about a tenth bigger, and the preview waits on the file
    readonly property string grimLevel: " -l 3"
    readonly property string imLevel: " -define png:compression-level=3"

    function captureFull(showFlash, source) {
        if (showFlash === undefined)
            showFlash = true;
        if (grimProcess.running)
            return;
        if (!source && flashWindow.clearFirst(() => flashWindow.captureFull(showFlash, source)))
            return;
        flashWindow.aimHere();
        var file = flashWindow.timestampedPath();
        grimProcess.targetFile = file;
        grimProcess.showFlash = showFlash;
        grimProcess.command = ["sh", "-c", "mkdir -p '" + flashWindow.saveDir + "' && " + (source ? flashWindow.imSetup + "$IM '" + source + "'" + flashWindow.imLevel + " '" + file + "'" : flashWindow.grimHere + flashWindow.grimLevel + " '" + file + "'")];
        grimProcess.running = true;
    }
    function captureRegion(x, y, w, h, showFlash, source, scale) {
        if (showFlash === undefined)
            showFlash = true;
        if (grimProcess.running)
            return;
        if (!source && flashWindow.clearFirst(() => flashWindow.captureRegion(x, y, w, h, showFlash, source, scale)))
            return;
        if (!(scale > 0))
            scale = 1;
        flashWindow.aimHere();
        var file = flashWindow.timestampedPath();
        grimProcess.targetFile = file;
        grimProcess.showFlash = showFlash;
        var capture;
        if (source) {
            var crop = Math.round(w * scale) + "x" + Math.round(h * scale) + "+" + Math.round(x * scale) + "+" + Math.round(y * scale);
            capture = flashWindow.imSetup + "$IM '" + source + "' -crop " + crop + " +repage" + flashWindow.imLevel + " '" + file + "'";
        } else {
            capture = "grim" + flashWindow.grimLevel + " -g '" + Math.round(x) + "," + Math.round(y) + " " + Math.round(w) + "x" + Math.round(h) + "' '" + file + "'";
        }
        grimProcess.command = ["sh", "-c", "mkdir -p '" + flashWindow.saveDir + "' && " + capture];
        grimProcess.running = true;
    }
    function captureWindow(x, y, w, h, radius) {
        if (windowProcess.running)
            return;
        var file = flashWindow.timestampedPath();
        var geometry = Math.round(x) + "," + Math.round(y) + " " + Math.round(w) + "x" + Math.round(h);
        var maxX = Math.round(w) - 1;
        var maxY = Math.round(h) - 1;
        var r = Math.round(radius);
        windowProcess.targetFile = file;
        windowProcess.command = ["sh", "-c",
            "mkdir -p '" + flashWindow.saveDir + "' && " +
            "command -v magick >/dev/null 2>&1 && IM=magick || IM=convert; " +
            "grim" + flashWindow.grimLevel + " -g '" + geometry + "' '" + file + "' && " +
            "$IM '" + file + "' \\( +clone -alpha extract -fill black -colorize 100 -fill white -draw \"roundrectangle 0,0 " + maxX + "," + maxY + " " + r + "," + r + "\" \\) -alpha off -compose CopyOpacity -composite" + flashWindow.imLevel + " '" + file + "' && " +
            "wl-copy < '" + file + "'"
        ];
        windowProcess.running = true;
    }

    property string ocrLang: "eng"
    readonly property string ocrDir: Quickshell.env("HOME") + "/.cache/lucidshot-ocr"
    // resolved against this file, so it works from the repo or the install dir
    readonly property string ocrScript: Qt.resolvedUrl("emoji-ocr.py").toString().replace("file://", "")

    // "copied" | "empty" | "notool" -- the shell reports, the shell.qml routes it to a toast
    signal textResult(string status)

    // ocr a region of `source` (or the live screen) onto the clipboard. w/h of 0
    // means the whole screen. tesseract runs twice, once on a negated copy, and the
    // longer result wins so light-on-dark UI text reads as well as dark-on-light
    function copyText(x, y, w, h, source, scale) {
        if (ocrProcess.running)
            return;
        if (!source && flashWindow.clearFirst(() => flashWindow.copyText(x, y, w, h, source, scale)))
            return;
        if (!(scale > 0))
            scale = 1;
        flashWindow.aimHere();
        var dir = flashWindow.ocrDir;
        var shot = dir + "/shot.png";
        var up = dir + "/up.png";
        var inv = dir + "/inv.png";
        var region = w > 0 && h > 0;
        var pw = region ? Math.round(w * scale) : 0;
        var capture;
        if (source)
            capture = region ? "$IM '" + source + "' -crop " + pw + "x" + Math.round(h * scale) + "+" + Math.round(x * scale) + "+" + Math.round(y * scale) + " +repage '" + shot + "'" : "$IM '" + source + "' '" + shot + "'";
        else
            capture = region ? "grim -g '" + Math.round(x) + "," + Math.round(y) + " " + Math.round(w) + "x" + Math.round(h) + "' '" + shot + "'" : flashWindow.grimHere + " '" + shot + "'";
        // tesseract wants roughly 300dpi text, so blow up anything narrower than a wide crop
        var upscale = (!region || pw >= 1200) ? "" : " -resize 300%";
        ocrProcess.command = ["sh", "-c",
            "command -v tesseract >/dev/null 2>&1 || { echo notool; exit 0; }; " +
            "mkdir -p '" + dir + "' && rm -f '" + dir + "/a.txt' '" + dir + "/b.txt' '" + dir + "/emoji.txt'; " +
            flashWindow.imSetup +
            capture + " && " +
            "$IM '" + shot + "' -alpha remove -colorspace gray" + upscale + " -sharpen 0x1 -normalize '" + up + "' && " +
            "$IM '" + up + "' -negate '" + inv + "'; " +
            "tesseract '" + up + "' '" + dir + "/a' -l " + flashWindow.ocrLang + " --dpi 300 >/dev/null 2>&1; " +
            "tesseract '" + inv + "' '" + dir + "/b' -l " + flashWindow.ocrLang + " --dpi 300 >/dev/null 2>&1; " +
            "size() { [ -s \"$1\" ] && wc -c < \"$1\" || echo 0; }; " +
            "if [ \"$(size '" + dir + "/b.txt')\" -gt \"$(size '" + dir + "/a.txt')\" ]; then BEST='" + dir + "/b.txt'; else BEST='" + dir + "/a.txt'; fi; " +
            // the emoji-aware reader works off the colour crop; plain tesseract drops
            // emoji or reads them as junk letters. falls back to BEST if it cannot run
            "python3 '" + flashWindow.ocrScript + "' '" + shot + "' > '" + dir + "/emoji.txt' 2>/dev/null; " +
            "[ -s '" + dir + "/emoji.txt' ] && BEST='" + dir + "/emoji.txt'; " +
            "TXT=$(sed -e 's/[[:space:]]*$//' -e '/./,$!d' \"$BEST\" 2>/dev/null); " +
            "if [ -z \"$TXT\" ]; then echo empty; exit 0; fi; " +
            "printf '%s' \"$TXT\" | wl-copy; " +
            "echo copied"
        ];
        ocrProcess.running = true;
    }

    // status is "ok" | "cancel" | "notool"
    signal colorResult(string value, string hex, string status)

    function hex2(n) {
        var h = Math.max(0, Math.min(255, Math.round(n))).toString(16);
        return h.length < 2 ? "0" + h : h;
    }

    function hslToHex(h, sat, l) {
        h = ((h % 360) + 360) % 360 / 360;
        sat = Math.max(0, Math.min(100, sat)) / 100;
        l = Math.max(0, Math.min(100, l)) / 100;
        function comp(p, q, t) {
            if (t < 0)
                t += 1;
            if (t > 1)
                t -= 1;
            if (t < 1 / 6)
                return p + (q - p) * 6 * t;
            if (t < 1 / 2)
                return q;
            if (t < 2 / 3)
                return p + (q - p) * (2 / 3 - t) * 6;
            return p;
        }
        if (sat === 0)
            return "#" + flashWindow.hex2(l * 255) + flashWindow.hex2(l * 255) + flashWindow.hex2(l * 255);
        var q = l < 0.5 ? l * (1 + sat) : l + sat - l * sat;
        var pp = 2 * l - q;
        return "#" + flashWindow.hex2(comp(pp, q, h + 1 / 3) * 255) + flashWindow.hex2(comp(pp, q, h) * 255) + flashWindow.hex2(comp(pp, q, h - 1 / 3) * 255);
    }

    // the swatch colour, read back out of whatever string hyprpicker produced
    function swatchFor(out, format) {
        var t = out.trim();
        if (format === "hex") {
            var h = t.replace("#", "");
            return /^[0-9a-fA-F]{6}$/.test(h) ? "#" + h : "";
        }
        var n = t.match(/-?\d+(\.\d+)?/g);
        if (!n || n.length < 3)
            return "";
        if (format === "hsl")
            return flashWindow.hslToHex(parseFloat(n[0]), parseFloat(n[1]), parseFloat(n[2]));
        return "#" + flashWindow.hex2(parseFloat(n[0])) + flashWindow.hex2(parseFloat(n[1])) + flashWindow.hex2(parseFloat(n[2]));
    }

    // hyprpicker formats in the mode the user chose, so its zoom lens, the
    // clipboard and the toast all show the same string. -a is deliberately not
    // used: the wl-copy it forks would inherit stdout and hold the pipe open
    function pickColor(format) {
        if (colorProcess.running)
            return;
        var fmt = (format === "rgb" || format === "hsl") ? format : "hex";
        var tmpl = "";
        if (fmt === "rgb")
            tmpl = " -o 'rgb({0}, {1}, {2})'";
        else if (fmt === "hsl")
            tmpl = " -o 'hsl({0}, {1}%, {2}%)'";
        colorProcess.format = fmt;
        colorProcess.command = ["sh", "-c",
            "command -v hyprpicker >/dev/null 2>&1 || { echo NOTOOL; exit 0; }; " +
            // -q is deliberately absent: it suppresses the picked colour itself,
            // not just the logs. -b stops the ansi-wrapped "fancy" output. the -o
            // templates are needed because hyprpicker's own defaults are unusable
            // here: rgb gives a bare "15 15 15" and hsl drops a component ("0 0%").
            // they drive the zoom lens too, so it reads the same as the clipboard
            "hyprpicker -f " + fmt + " -b" + tmpl
        ];
        colorProcess.running = true;
    }

    Process {
        id: colorProcess

        property string format: "hex"

        stdout: StdioCollector {
            onStreamFinished: {
                // belt and braces: strip ansi even though -b should prevent it, and
                // take the last real line so a stray log cannot poison the parse
                var clean = text.replace(/\u001b\[[0-9;]*m/g, "").replace(/\u001b/g, "");
                var lines = clean.split("\n").filter(l => l.trim() !== "");
                var out = lines.length ? lines[lines.length - 1].trim() : "";
                if (out === "NOTOOL") {
                    flashWindow.colorResult("", "", "notool");
                    return;
                }
                if (out === "") {
                    flashWindow.colorResult("", "", "cancel");
                    return;
                }
                // something was picked, so always copy and say so, even if the
                // swatch colour could not be worked out from the string
                Quickshell.execDetached(["wl-copy", "--", out]);
                flashWindow.colorResult(out, flashWindow.swatchFor(out, colorProcess.format), "ok");
            }
        }
    }

    Process {
        id: ocrProcess

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                flashWindow.textResult(lines[lines.length - 1]);
            }
        }
    }

    Process {
        id: grimProcess

        property string targetFile: ""
        property bool showFlash: true

        onExited: (code) => {
            if (code !== 0)
                return;
            if (grimProcess.showFlash)
                flashAnim.restart();
            flashWindow.captured();
            Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"", "sh", grimProcess.targetFile]);
            flashWindow.announce(grimProcess.targetFile, "image");
        }
    }

    Process {
        id: windowProcess

        property string targetFile: ""

        onExited: (code) => {
            if (code === 0)
                flashWindow.announce(windowProcess.targetFile, "image");
        }
    }

    Rectangle {
        id: flashOverlay

        anchors.fill: parent
        color: "black"
        opacity: 0
    }

    SequentialAnimation {
        id: flashAnim

    NumberAnimation {
        target: flashOverlay
        property: "opacity"
        to: 0.3
        duration: Theme.ms(60)
    }

    PauseAnimation {
        duration: Theme.ms(800)
    }

    NumberAnimation {
        target: flashOverlay
        property: "opacity"
        to: 0
        duration: Theme.ms(180)
        easing.type: Easing.OutCubic
    }
}

    IpcHandler {
        target: "screenshot"

        function full(): void {
            flashWindow.captureFull();
        }

        function text(): void {
            flashWindow.copyText(0, 0, 0, 0, "", 1);
        }
    }
}