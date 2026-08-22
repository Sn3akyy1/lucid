import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: flashWindow

    property string saveDir: Quickshell.env("HOME") + "/Pictures/screenshots"
    signal captured()

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

    // When `source` is given (the snap overlay's freeze frame) the shot is cut
    // out of that file instead of being re-taken with grim.
    //
    // Re-grimming here raced Hyprland's layersOut fade animation: the overlay
    // is unmapped in the same tick that launches grim, so grim samples the
    // screen while the layer is still fading and its frozen - fully opaque -
    // copy of the desktop lands blended over the live desktop underneath.
    // Wherever the two differ (most visibly a bar popup that closed when the
    // overlay took focus) the result looks semi-transparent, even though the
    // captured module never was. Reading the freeze file has no such race, and
    // it is also what the user actually selected against.
    readonly property string imSetup: "command -v magick >/dev/null 2>&1 && IM=magick || IM=convert; "

    function captureFull(showFlash, source) {
        if (showFlash === undefined)
            showFlash = true;
        if (grimProcess.running)
            return;
        var file = flashWindow.timestampedPath();
        grimProcess.targetFile = file;
        grimProcess.showFlash = showFlash;
        grimProcess.command = ["sh", "-c", "mkdir -p '" + flashWindow.saveDir + "' && " + (source ? flashWindow.imSetup + "$IM '" + source + "' '" + file + "'" : "grim '" + file + "'")];
        grimProcess.running = true;
    }
    // `scale` converts the overlay's logical coordinates into freeze-frame
    // pixels; it is 1 on an unscaled output and only matters when `source` is set
    function captureRegion(x, y, w, h, showFlash, source, scale) {
        if (showFlash === undefined)
            showFlash = true;
        if (grimProcess.running)
            return;
        if (!(scale > 0))
            scale = 1;
        var file = flashWindow.timestampedPath();
        grimProcess.targetFile = file;
        grimProcess.showFlash = showFlash;
        var capture;
        if (source) {
            var crop = Math.round(w * scale) + "x" + Math.round(h * scale) + "+" + Math.round(x * scale) + "+" + Math.round(y * scale);
            capture = flashWindow.imSetup + "$IM '" + source + "' -crop " + crop + " +repage '" + file + "'";
        } else {
            capture = "grim -g '" + Math.round(x) + "," + Math.round(y) + " " + Math.round(w) + "x" + Math.round(h) + "' '" + file + "'";
        }
        grimProcess.command = ["sh", "-c", "mkdir -p '" + flashWindow.saveDir + "' && " + capture];
        grimProcess.running = true;
    }
    function captureWindow(x, y, w, h, radius) {
        var file = flashWindow.timestampedPath();
        var geometry = Math.round(x) + "," + Math.round(y) + " " + Math.round(w) + "x" + Math.round(h);
        var maxX = Math.round(w) - 1;
        var maxY = Math.round(h) - 1;
        var r = Math.round(radius);
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p '" + flashWindow.saveDir + "' && " +
            "command -v magick >/dev/null 2>&1 && IM=magick || IM=convert; " +
            "grim -g '" + geometry + "' '" + file + "' && " +
            "$IM '" + file + "' \\( +clone -alpha extract -fill black -colorize 100 -fill white -draw \"roundrectangle 0,0 " + maxX + "," + maxY + " " + r + "," + r + "\" \\) -alpha off -compose CopyOpacity -composite '" + file + "' && " +
            "wl-copy < '" + file + "' && " +
            "ACTION=$(notify-send 'Screenshot taken!' 'Saved to " + file + "' -i '" + file + "' -A 'open=Open Screenshot' --wait) && " +
            "[ \"$ACTION\" = \"open\" ] && swappy -f '" + file + "'; true"
        ]);
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
            Quickshell.execDetached(["sh", "-c",
                "wl-copy < '" + grimProcess.targetFile + "' && " +
                "ACTION=$(notify-send 'Screenshot taken!' 'Saved to " + grimProcess.targetFile + "' -i '" + grimProcess.targetFile + "' -A 'open=Open Screenshot' --wait) && " +
                "[ \"$ACTION\" = \"open\" ] && swappy -f '" + grimProcess.targetFile + "'; " +
                "true"
            ]);
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
    }
}