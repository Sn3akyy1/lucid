import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

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

    function captureFull(showFlash) {
        if (showFlash === undefined)
            showFlash = true;
        if (grimProcess.running)
            return;
        var file = flashWindow.timestampedPath();
        grimProcess.targetFile = file;
        grimProcess.showFlash = showFlash;
        grimProcess.command = ["sh", "-c", "mkdir -p '" + flashWindow.saveDir + "' && grim '" + file + "'"];
        grimProcess.running = true;
    }
    function captureRegion(x, y, w, h, showFlash) {
        if (showFlash === undefined)
            showFlash = true;
        if (grimProcess.running)
            return;
        var file = flashWindow.timestampedPath();
        var geometry = Math.round(x) + "," + Math.round(y) + " " + Math.round(w) + "x" + Math.round(h);
        grimProcess.targetFile = file;
        grimProcess.showFlash = showFlash;
        grimProcess.command = ["sh", "-c", "mkdir -p '" + flashWindow.saveDir + "' && grim -g '" + geometry + "' '" + file + "'"];
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
        duration: 60
    }

    PauseAnimation {
        duration: 800
    }

    NumberAnimation {
        target: flashOverlay
        property: "opacity"
        to: 0
        duration: 180
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