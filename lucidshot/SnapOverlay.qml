import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.lucidui

PanelWindow {
    id: snapWindow

    property bool open: false
    property bool contentVisible: true
    property bool animateContent: true
    property string activeTool: ""
    property string pendingAction: ""
    property string captureMode: "camera"
    property string openMode: "camera"
    property string colorFormat: "hex"
    property string freezePath: Quickshell.env("HOME") + "/.cache/quickshell-snap-freeze.png"

    property string recordingState: "idle"
    property int recordSeconds: 0
    property bool micOn: true
    property bool headphoneOn: true
    property string recordSaveDir: Quickshell.env("HOME") + "/Videos"
    property string recordPidFile: "/tmp/quickshell-wfrecorder.pid"
    property string lastRecordingFile: ""
    property var segmentFiles: []
    property string currentCrop: ""
    property bool toolbarHidden: false
    property bool hiddenRecording: false


    property real selStartX: 0
    property real selStartY: 0
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0

    // the ocr reads the frozen image, so the overlay can stay up while it works
    property bool ocrBusy: false
    property real busyX: 0
    property real busyY: 0
    property real busyW: 0
    property real busyH: 0

    readonly property real freezeScale: (freezeImg.implicitWidth > 0 && snapWindow.width > 0) ? (freezeImg.implicitWidth / snapWindow.width) : 1

    readonly property color shadeColor: Theme.alpha(Theme.shadow, 0.55)
    readonly property bool shadeVisible: contentVisible && activeTool !== "fullscreen" && captureMode !== "color"

    readonly property bool desktopExposed: captureMode === "color" || (captureMode === "video" && (activeTool === "fullscreen" || recordingState !== "idle"))

    signal fullscreenRequested()
    signal regionRequested(real x, real y, real w, real h)
    signal textRequested(real x, real y, real w, real h)
    signal colorPickRequested(string format)

    color: "transparent"
    exclusiveZone: -1
    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Region {
        id: toolbarOnlyMask

        Region {
            item: toolbar
        }
    }

    Region {
        id: emptyMask
    }

    onDesktopExposedChanged: {
        snapWindow.mask = null;
        if (snapWindow.desktopExposed)
            maskApplyTimer.restart();
    }

    onRecordingStateChanged: {
        if (snapWindow.recordingState !== "idle")
            return;
        snapWindow.hiddenRecording = false;
        if (snapWindow.toolbarHidden) {
            snapWindow.toolbarHidden = false;
            snapWindow.mask = null;
        }
    }

    Timer {
        id: maskApplyTimer

        interval: 16
        onTriggered: {
            if (snapWindow.desktopExposed)
                snapWindow.mask = toolbarOnlyMask;
        }
    }

    function resetSelection() {
        snapWindow.selStartX = 0;
        snapWindow.selStartY = 0;
        snapWindow.selX = 0;
        snapWindow.selY = 0;
        snapWindow.selW = 0;
        snapWindow.selH = 0;
    }

    function formatTimer(total) {
        var h = Math.floor(total / 3600);
        var m = Math.floor((total % 3600) / 60);
        var s = total % 60;
        function pad(n) {
            return (n < 10 ? "0" : "") + n;
        }
        return pad(h) + ":" + pad(m) + ":" + pad(s);
    }

    function timestampSuffix() {
        var d = new Date();
        function pad(n) {
            return (n < 10 ? "0" : "") + n;
        }
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "_" + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds());
    }

function stopRecordingBackend() {
        var file = snapWindow.lastRecordingFile;
        var segs = snapWindow.segmentFiles;
        var crop = snapWindow.currentCrop;
        var listFile = file.replace(/\.mp4$/, "") + ".concat.txt";
        var mergedFile;
        var mergeCmd;
        if (segs.length > 1) {
            mergedFile = file.replace(/\.mp4$/, "") + ".full.mp4";
            var listCmds = "rm -f '" + listFile + "'; ";
            for (var i = 0; i < segs.length; i++) {
                listCmds += "echo \"file '" + segs[i] + "'\" >> '" + listFile + "'; ";
            }
            mergeCmd = listCmds + "ffmpeg -y -f concat -safe 0 -i '" + listFile + "' -c copy '" + mergedFile + "'; ";
        } else {
            mergedFile = segs[0];
            mergeCmd = "";
        }
        var finalCmd;
        if (crop) {
            finalCmd = "ffmpeg -y -i '" + mergedFile + "' -vf crop=" + crop + " -color_range pc -colorspace bt709 -color_primaries bt709 -color_trc bt709 -pix_fmt yuv420p -c:v libx264 -crf 18 -preset veryfast -c:a copy '" + file + "'";
        } else {
            finalCmd = "ffmpeg -y -i '" + mergedFile + "' -c:v copy -bsf:v h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1:video_full_range_flag=1 -c:a copy '" + file + "'";
        }
        var cleanupSegs = segs.map(function (s) {
            return "'" + s + "'";
        }).join(" ");
        var cleanupMerged = segs.length > 1 ? "'" + mergedFile + "'" : "";
        Quickshell.execDetached(["sh", "-c",
            "[ -f " + snapWindow.recordPidFile + " ] && kill -INT \"$(cat " + snapWindow.recordPidFile + ")\" 2>/dev/null; " +
            "sleep 0.6; " +
            "for f in /tmp/quickshell-wfrec-nullsink.pid /tmp/quickshell-wfrec-loop-mic.pid /tmp/quickshell-wfrec-loop-sys.pid; do " +
            "if [ -f \"$f\" ]; then pactl unload-module \"$(cat \"$f\")\" 2>/dev/null; rm -f \"$f\"; fi; " +
            "done; " +
            "rm -f " + snapWindow.recordPidFile + "; " +
            mergeCmd +
            finalCmd + "; " +
            "rm -f '" + listFile + "' " + cleanupSegs + " " + cleanupMerged + "; " +
            "notify-send 'Recording saved' 'Saved to " + file + "'"
        ]);
    }

    function recorderLaunchCmd(segFile) {
        return "DRI=$(ls /dev/dri/renderD* 2>/dev/null | head -1); " +
            "if [ -n \"$DRI\" ]; then " +
            "wf-recorder -c h264_vaapi -d \"$DRI\" --audio=wfrec_combined.monitor -f '" + segFile + "' & " +
            "else " +
            "wf-recorder --audio=wfrec_combined.monitor -x yuv420p -f '" + segFile + "' & " +
            "fi; " +
            "echo $! > " + snapWindow.recordPidFile + "; " +
            "wait";
    }

    function startRecordingBackend() {
        var crop = "";
        if (snapWindow.activeTool === "select" && snapWindow.selW > 1 && snapWindow.selH > 1) {
            crop = Math.round(snapWindow.selW) + ":" + Math.round(snapWindow.selH) + ":" + Math.round(snapWindow.selX) + ":" + Math.round(snapWindow.selY);
        }
        snapWindow.currentCrop = crop;
        var sysMute = snapWindow.headphoneOn ? "0" : "1";
        var baseName = snapWindow.recordSaveDir + "/recording_" + snapWindow.timestampSuffix();
        snapWindow.lastRecordingFile = baseName + ".mp4";
        var segFile = baseName + ".part0.mp4";
        snapWindow.segmentFiles = [segFile];
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p '" + snapWindow.recordSaveDir + "'; " +
            "SINK_MON=\"$(pactl get-default-sink).monitor\"; SRC=\"$(pactl get-default-source)\"; " +
            "pactl load-module module-null-sink sink_name=wfrec_combined > /tmp/quickshell-wfrec-nullsink.pid; " +
            "pactl load-module module-loopback source=\"$SRC\" sink=wfrec_combined sink_input_properties=media.name=lucidshot-mic latency_msec=1 > /tmp/quickshell-wfrec-loop-mic.pid; " +
            "pactl load-module module-loopback source=\"$SINK_MON\" sink=wfrec_combined sink_input_properties=media.name=lucidshot-sys latency_msec=1 > /tmp/quickshell-wfrec-loop-sys.pid; " +
            "sleep 0.2; " +
            "SYSID=$(pactl list sink-inputs | awk '/^Sink Input #/{id=$3} /media.name = \"lucidshot-sys\"/{gsub(\"#\",\"\",id); print id}' | tail -1); " +
            "[ -n \"$SYSID\" ] && pactl set-sink-input-mute \"$SYSID\" " + sysMute + "; " +
            snapWindow.recorderLaunchCmd(segFile)
        ]);
    }

    function setSysAudioMuted(muted) {
        Quickshell.execDetached(["sh", "-c",
            "ID=$(pactl list sink-inputs | awk '/^Sink Input #/{id=$3} /media.name = \"lucidshot-sys\"/{gsub(\"#\",\"\",id); print id}' | tail -1); " +
            "[ -n \"$ID\" ] && pactl set-sink-input-mute \"$ID\" " + (muted ? "1" : "0")
        ]);
    }

    function pauseRecordingBackend() {
        Quickshell.execDetached(["sh", "-c", "[ -f " + snapWindow.recordPidFile + " ] && kill -INT \"$(cat " + snapWindow.recordPidFile + ")\" 2>/dev/null; true"]);
    }

    function resumeRecordingBackend() {
        var segFile = snapWindow.lastRecordingFile.replace(/\.mp4$/, "") + ".part" + snapWindow.segmentFiles.length + ".mp4";
        snapWindow.segmentFiles.push(segFile);
        Quickshell.execDetached(["sh", "-c", snapWindow.recorderLaunchCmd(segFile)]);
    }

    function setCaptureMode(id) {
        if (id !== "camera" && id !== "video" && id !== "text" && id !== "color")
            return;
        if (snapWindow.captureMode === id)
            return;
        if (id !== "video" && snapWindow.recordingState !== "idle")
            return;
        var leavingColor = snapWindow.captureMode === "color";
        snapWindow.captureMode = id;
        snapWindow.activeTool = id === "video" ? "fullscreen" : "select";
        if (leavingColor && (id === "camera" || id === "text"))
            snapWindow.refreeze();
        snapWindow.resetSelection();
        if (id === "video") {
            snapWindow.recordingState = "idle";
            snapWindow.recordSeconds = 0;
            snapWindow.refreshMicStatus();
        }
    }

    function togglePlayPause() {
        if (snapWindow.recordingState === "idle") {
            snapWindow.recordingState = "recording";
            snapWindow.recordSeconds = 0;
            snapWindow.startRecordingBackend();
        } else if (snapWindow.recordingState === "recording") {
            snapWindow.recordingState = "paused";
            snapWindow.pauseRecordingBackend();
        } else if (snapWindow.recordingState === "paused") {
            snapWindow.recordingState = "recording";
            snapWindow.resumeRecordingBackend();
        }
    }

    function stopRecording() {
        if (snapWindow.recordingState === "idle")
            return;
        snapWindow.recordingState = "idle";
        snapWindow.recordSeconds = 0;
        snapWindow.resetSelection();
        snapWindow.activeTool = "fullscreen";
        snapWindow.stopRecordingBackend();
    }

    function hideToolbar() {
        if (snapWindow.recordingState === "idle" || snapWindow.toolbarHidden)
            return;
        snapWindow.toolbarHidden = true;
        snapWindow.hiddenRecording = true;
        snapWindow.mask = emptyMask;
    }

    function showToolbar() {
        if (!snapWindow.hiddenRecording)
            return;
        snapWindow.open = true;
        snapWindow.hiddenRecording = false;
        snapWindow.toolbarHidden = false;
        snapWindow.captureMode = "video";
        snapWindow.activeTool = snapWindow.currentCrop ? "select" : "fullscreen";
        snapWindow.resetSelection();
        snapWindow.mask = snapWindow.desktopExposed ? toolbarOnlyMask : null;
    }

    Timer {
        id: recordTick

        interval: 1000
        repeat: true
        running: snapWindow.recordingState === "recording"
        onTriggered: snapWindow.recordSeconds++
    }

    Process {
        id: micStatusProc

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]

        stdout: StdioCollector {
            onStreamFinished: {
                snapWindow.micOn = text.indexOf("MUTED") === -1;
            }
        }
    }

    function refreshMicStatus() {
        if (!micStatusProc.running)
            micStatusProc.running = true;
    }

    Timer {
        id: micPollTimer

        interval: 500
        repeat: true
        running: snapWindow.open && snapWindow.captureMode === "video"
        onTriggered: snapWindow.refreshMicStatus()
    }
    Timer {
        id: micRefreshDelay

        interval: 150
        onTriggered: snapWindow.refreshMicStatus()
    }

    function beginOpen() {
        if (freezeProcess.running)
            return;
        if (snapWindow.open && !snapWindow.toolbarHidden)
            return;
        // pinned to the display in use, so the freeze grim takes and the one
        // the overlay is drawn on are the same display
        if (Monitors.focusedScreen)
            snapWindow.screen = Monitors.focusedScreen;

        freezeProcess.running = true;
    }

    function resetToFreshSession() {
        // a hidden recording is still running, so reopening has to land back on it
        var mode = snapWindow.hiddenRecording ? "video" : snapWindow.openMode;
        snapWindow.contentVisible = true;
        snapWindow.animateContent = true;
        snapWindow.activeTool = mode === "video" ? "fullscreen" : "select";
        snapWindow.pendingAction = "";
        snapWindow.captureMode = mode;
        snapWindow.toolbarHidden = false;
        snapWindow.ocrBusy = false;
        ocrTimeout.stop();
        snapWindow.resetSelection();
        if (!snapWindow.hiddenRecording) {
            snapWindow.recordingState = "idle";
            snapWindow.recordSeconds = 0;
            snapWindow.micOn = true;
            snapWindow.headphoneOn = true;
        }
        snapWindow.mask = snapWindow.desktopExposed ? toolbarOnlyMask : null;
        toolbar.x = Qt.binding(function () {
            return (snapWindow.width - toolbar.width) / 2;
        });
        toolbar.y = toolbar.restY;
    }

    // hide the toolbar for a frame, re-grab, then come back. without the hide the
    // toolbar itself lands in the freeze
    function refreeze() {
        if (freezeProcess.running)
            return;
        snapWindow.animateContent = false;
        snapWindow.contentVisible = false;
        refreezeDelay.restart();
    }

    Timer {
        id: refreezeDelay

        interval: 50
        onTriggered: {
            freezeProcess.quiet = true;
            freezeProcess.running = true;
        }
    }

    Process {
        id: freezeProcess

        property bool quiet: false

        // -o, or a second display would be stitched into the freeze and every
        // crop taken off it would be read at the wrong scale
        command: ["sh", "-c", (snapWindow.screen ? "grim -o '" + snapWindow.screen.name + "'" : "grim") + " -l 0 '" + snapWindow.freezePath + "'"]

        onExited: (code) => {
            if (freezeProcess.quiet) {
                freezeProcess.quiet = false;
                if (code === 0) {
                    freezeImg.source = "";
                    freezeImg.source = "file://" + snapWindow.freezePath;
                }
                snapWindow.contentVisible = true;
                snapWindow.animateContent = true;
                return;
            }
            if (code !== 0)
                return;
            freezeImg.source = "";
            freezeImg.source = "file://" + snapWindow.freezePath;
            snapWindow.open = true;
            snapWindow.resetToFreshSession();
        }
    }

    function startColorPick() {
        snapWindow.colorPickRequested(snapWindow.colorFormat);
    }

    // hold the overlay open and scan the region until the copy comes back
    function beginTextRead(x, y, w, h, whole) {
        if (snapWindow.ocrBusy)
            return;
        snapWindow.busyX = x;
        snapWindow.busyY = y;
        snapWindow.busyW = w;
        snapWindow.busyH = h;
        snapWindow.ocrBusy = true;
        ocrTimeout.restart();
        if (whole)
            snapWindow.textRequested(0, 0, 0, 0);
        else
            snapWindow.textRequested(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
    }

    function finishTextRead() {
        ocrTimeout.stop();
        snapWindow.ocrBusy = false;
        snapWindow.open = false;
    }

    // nothing should be able to wedge the overlay open if the reader never answers
    Timer {
        id: ocrTimeout

        interval: 30000
        onTriggered: snapWindow.finishTextRead()
    }

    function runTool(id) {
        if (snapWindow.captureMode === "color")
            return;
        if (snapWindow.captureMode === "text") {
            if (id === "select") {
                snapWindow.activeTool = "select";
                snapWindow.resetSelection();
            } else if (id === "fullscreen") {
                snapWindow.beginTextRead(0, 0, snapWindow.width, snapWindow.height, true);
            }
            return;
        }
        if (snapWindow.captureMode === "video") {
            if (id === "select" || id === "fullscreen") {
                snapWindow.activeTool = id;
                snapWindow.resetSelection();
            }
            return;
        }
        if (id === "select") {
            snapWindow.activeTool = "select";
            snapWindow.resetSelection();
        } else if (id === "fullscreen") {
            snapWindow.pendingAction = "fullscreen";
            snapWindow.animateContent = false;
            snapWindow.contentVisible = false;
            hideForCaptureTimer.start();
        }
    }

    Timer {
        id: hideForCaptureTimer

        interval: 50
        onTriggered: {
            if (snapWindow.pendingAction === "fullscreen") {
                snapWindow.fullscreenRequested();
            } else if (snapWindow.pendingAction === "region") {
                snapWindow.regionRequested(Math.round(snapWindow.selX), Math.round(snapWindow.selY), Math.round(snapWindow.selW), Math.round(snapWindow.selH));
            }
            snapWindow.open = false;
        }
    }

    Image {
        id: freezeImg

        anchors.fill: parent
        source: ""
        cache: false
        asynchronous: false
        fillMode: Image.PreserveAspectCrop
        visible: !snapWindow.desktopExposed
    }

    Rectangle {
        id: shadeTop

        color: snapWindow.shadeColor
        opacity: snapWindow.shadeVisible ? 1 : 0
        visible: opacity > 0
        x: 0
        y: 0
        width: snapWindow.width
        height: snapWindow.selY

        Behavior on opacity {
            enabled: snapWindow.animateContent
            NumberAnimation {
                duration: Theme.ms(120)
            }
        }
    }

    Rectangle {
        id: shadeBottom

        color: snapWindow.shadeColor
        opacity: snapWindow.shadeVisible ? 1 : 0
        visible: opacity > 0
        x: 0
        y: snapWindow.selY + snapWindow.selH
        width: snapWindow.width
        height: snapWindow.height - (snapWindow.selY + snapWindow.selH)

        Behavior on opacity {
            enabled: snapWindow.animateContent
            NumberAnimation {
                duration: Theme.ms(120)
            }
        }
    }

    Rectangle {
        id: shadeLeft

        color: snapWindow.shadeColor
        opacity: snapWindow.shadeVisible ? 1 : 0
        visible: opacity > 0
        x: 0
        y: snapWindow.selY
        width: snapWindow.selX
        height: snapWindow.selH

        Behavior on opacity {
            enabled: snapWindow.animateContent
            NumberAnimation {
                duration: Theme.ms(120)
            }
        }
    }

    Rectangle {
        id: shadeRight

        color: snapWindow.shadeColor
        opacity: snapWindow.shadeVisible ? 1 : 0
        visible: opacity > 0
        x: snapWindow.selX + snapWindow.selW
        y: snapWindow.selY
        width: snapWindow.width - (snapWindow.selX + snapWindow.selW)
        height: snapWindow.selH

        Behavior on opacity {
            enabled: snapWindow.animateContent
            NumberAnimation {
                duration: Theme.ms(120)
            }
        }
    }

    Rectangle {
        color: "transparent"
        border.color: Theme.accent
        border.width: 1
        visible: snapWindow.contentVisible && !snapWindow.ocrBusy && snapWindow.activeTool === "select" && snapWindow.selW > 0 && snapWindow.selH > 0 && !(snapWindow.captureMode === "video" && snapWindow.recordingState !== "idle")
        x: snapWindow.selX
        y: snapWindow.selY
        width: snapWindow.selW
        height: snapWindow.selH
    }

    // reading feedback: the box stays put and a beam sweeps it until the copy lands
    Item {
        id: scanner

        visible: snapWindow.ocrBusy
        x: snapWindow.busyX
        y: snapWindow.busyY
        width: snapWindow.busyW
        height: snapWindow.busyH
        clip: true

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.accent, 0.06)
            border.color: Theme.accent
            border.width: 1
        }

        Rectangle {
            id: beam

            width: parent.width
            height: 26
            y: -height

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.accent, 0)
                }

                GradientStop {
                    position: 0.82
                    color: Theme.alpha(Theme.accent, 0.28)
                }

                GradientStop {
                    position: 1
                    color: Theme.accent
                }

            }

        }

        SequentialAnimation {
            running: snapWindow.ocrBusy
            loops: Animation.Infinite

            NumberAnimation {
                target: beam
                property: "y"
                from: -beam.height
                to: scanner.height
                duration: Theme.ms(850)
                easing.type: Easing.InOutSine
            }

            PauseAnimation {
                duration: Theme.ms(120)
            }

        }

        // corner ticks, so a tall thin selection still reads as "being worked on"
        Repeater {
            model: 4

            Rectangle {
                readonly property bool rightSide: index % 2 === 1
                readonly property bool bottomSide: index > 1

                width: 9
                height: 2
                color: Theme.accent
                x: rightSide ? scanner.width - width : 0
                y: bottomSide ? scanner.height - height : 0
            }

        }

    }

    MouseArea {
        id: selectArea

        anchors.fill: parent
        enabled: snapWindow.contentVisible && !snapWindow.desktopExposed && !snapWindow.ocrBusy
        hoverEnabled: true
        cursorShape: snapWindow.activeTool === "select" ? Qt.CrossCursor : Qt.ArrowCursor

        onPressed: mouse => {
            if (snapWindow.activeTool === "select") {
                snapWindow.selStartX = mouse.x;
                snapWindow.selStartY = mouse.y;
                snapWindow.selX = mouse.x;
                snapWindow.selY = mouse.y;
                snapWindow.selW = 0;
                snapWindow.selH = 0;
            }
        }

        onPositionChanged: mouse => {
            if (snapWindow.activeTool === "select" && pressed) {
                var x1 = Math.min(snapWindow.selStartX, mouse.x);
                var y1 = Math.min(snapWindow.selStartY, mouse.y);
                var x2 = Math.max(snapWindow.selStartX, mouse.x);
                var y2 = Math.max(snapWindow.selStartY, mouse.y);
                snapWindow.selX = x1;
                snapWindow.selY = y1;
                snapWindow.selW = x2 - x1;
                snapWindow.selH = y2 - y1;
            }
        }

        onReleased: mouse => {
            if (snapWindow.activeTool !== "select") {
                if (snapWindow.captureMode !== "video")
                    snapWindow.open = false;
                return;
            }
            if (snapWindow.selW < 2 || snapWindow.selH < 2) {
                snapWindow.selW = 0;
                snapWindow.selH = 0;
                return;
            }
            if (snapWindow.captureMode === "video")
                return;
            if (snapWindow.captureMode === "text") {
                snapWindow.beginTextRead(snapWindow.selX, snapWindow.selY, snapWindow.selW, snapWindow.selH, false);
                return;
            }
            snapWindow.pendingAction = "region";
            snapWindow.animateContent = false;
            snapWindow.contentVisible = false;
            hideForCaptureTimer.start();
        }
    }

    Item {
        id: toolbarHost

        anchors.fill: parent

        Rectangle {
            id: toolbar

            readonly property real restY: 96

            x: (snapWindow.width - width) / 2
            y: toolbar.restY

            radius: height / 2
            color: Theme.bgOpaque
            border.color: Theme.alpha(Theme.text, toolbarHover.hovered ? 0.12 : 0.07)
            border.width: 1
            width: toolRow.implicitWidth + 24
            height: 60
            opacity: (snapWindow.contentVisible && !snapWindow.toolbarHidden) ? 1 : 0
            visible: opacity > 0

            HoverHandler {
                id: toolbarHover

                cursorShape: Qt.ArrowCursor
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.ms(150)
                }
            }

            Behavior on opacity {
                enabled: snapWindow.animateContent
                NumberAnimation {
                    duration: Theme.ms(120)
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Theme.ms(220)
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                id: toolRow

                anchors.centerIn: parent
                spacing: 10

                ModeSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                }

                SnapDivider {}

                Row {
                    visible: snapWindow.captureMode !== "color"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    IconAction {
                        iconPath: "crop_free"
                        label: snapWindow.captureMode === "text" ? "Copy Text in Region" : "Snap Select"
                        active: snapWindow.activeTool === "select"
                        disabled: snapWindow.ocrBusy || (snapWindow.captureMode === "video" && snapWindow.recordingState !== "idle")
                        onTapped: snapWindow.runTool("select")
                    }

                    IconAction {
                        iconPath: "desktop_windows"
                        label: snapWindow.captureMode === "text" ? "Copy All Text on Screen" : "Fullscreen"
                        active: snapWindow.activeTool === "fullscreen"
                        disabled: snapWindow.ocrBusy || (snapWindow.captureMode === "video" && snapWindow.recordingState !== "idle")
                        onTapped: snapWindow.runTool("fullscreen")
                    }
                }

                Row {
                    id: colorControls

                    visible: snapWindow.captureMode === "color"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    IconAction {
                        anchors.verticalCenter: parent.verticalCenter
                        iconPath: "colorize"
                        label: "Pick a Colour"
                        activeColor: Theme.accent
                        onTapped: snapWindow.startColorPick()
                    }

                    SnapDivider {}

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        FormatChip {
                            fmt: "hex"
                        }

                        FormatChip {
                            fmt: "rgb"
                        }

                        FormatChip {
                            fmt: "hsl"
                        }
                    }
                }

                Row {
                    id: videoControls

                    visible: snapWindow.captureMode === "video"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    SnapDivider {}

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        IconAction {
                            iconPath: {
                                if (snapWindow.recordingState === "recording")
                                    return "pause";
                                if (snapWindow.recordingState === "paused")
                                    return "play_arrow";
                                return "fiber_manual_record";
                            }
                            label: {
                                if (snapWindow.recordingState === "recording")
                                    return "Pause";
                                if (snapWindow.recordingState === "paused")
                                    return "Resume";
                                return "Start Recording";
                            }
                            active: snapWindow.recordingState !== "idle"
                            activeColor: snapWindow.recordingState === "recording" ? Theme.error : Theme.accent
                            disabled: snapWindow.recordingState === "idle" && snapWindow.activeTool === "select" && (snapWindow.selW <= 0 || snapWindow.selH <= 0)
                            onTapped: snapWindow.togglePlayPause()
                        }

                        IconAction {
                            iconPath: "stop"
                            label: "Stop"
                            disabled: snapWindow.recordingState === "idle"
                            onTapped: snapWindow.stopRecording()
                        }

                        IconAction {
                            iconPath: "visibility_off"
                            label: "Hide (switch to Video to bring back)"
                            disabled: snapWindow.recordingState === "idle"
                            onTapped: snapWindow.hideToolbar()
                        }

                        TimerChip {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    SnapDivider {}

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        ToggleChip {
                            anchors.verticalCenter: parent.verticalCenter
                            iconPath: snapWindow.micOn ? "mic" : "mic_off"
                            labelOn: "Mic"
                            labelOff: "Mic Off"
                            on: snapWindow.micOn
                            onTapped: {
                                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
                                snapWindow.micOn = !snapWindow.micOn;
                                micRefreshDelay.restart();
                            }
                        }

                        ToggleChip {
                            anchors.verticalCenter: parent.verticalCenter
                            iconPath: snapWindow.headphoneOn ? "headphones" : "headset_off"
                            labelOn: "Audio"
                            labelOff: "Audio Off"
                            on: snapWindow.headphoneOn
                            onTapped: {
                                snapWindow.headphoneOn = !snapWindow.headphoneOn;
                                if (snapWindow.recordingState !== "idle")
                                    snapWindow.setSysAudioMuted(!snapWindow.headphoneOn);
                            }
                        }
                    }
                }

                SnapDivider {}

                DragHandle {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        component FormatChip: Item {
            id: fchip

            property string fmt: ""

            readonly property bool active: snapWindow.colorFormat === fchip.fmt

            width: fchipText.implicitWidth + 18
            height: 28

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusXs
                color: fchip.active ? Theme.accent : (fchipHover.hovered ? Theme.alpha(Theme.text, 0.09) : Theme.alpha(Theme.text, 0.05))

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(150)
                    }
                }

            }

            Text {
                id: fchipText

                anchors.centerIn: parent
                text: fchip.fmt.toUpperCase()
                color: fchip.active ? Theme.fgAccent : Theme.subtext
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fs(11)
                font.variableAxes: Theme.axes(Theme.fs(11), 640, 0)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(120)
                    }
                }

            }

            HoverHandler {
                id: fchipHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: snapWindow.colorFormat = fchip.fmt
            }
        }

        component SnapDivider: Rectangle {
            width: 1
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.alpha(Theme.outline, 0.6)
        }

        component IconAction: Item {
            id: action

            property string iconPath: ""
            property string label: ""
            property bool active: false
            property bool disabled: false
            property color activeColor: Theme.accent

            signal tapped()

            width: 44
            height: 44

            Item {
                id: visual

                anchors.fill: parent
                scale: tap.pressed ? 0.88 : (hover.hovered && !action.disabled ? 1.05 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.ms(110)
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: stateLayer

                    anchors.centerIn: parent
                    width: 42
                    height: 42
                    radius: action.active ? 14 : 21
                    color: action.activeColor

                    Behavior on radius {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }
                    }
                    opacity: action.disabled ? 0 : (action.active ? 1 : (tap.pressed ? Theme.statePressed : (hover.hovered ? Theme.stateHover : 0)))

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(120)
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(150)
                        }
                    }
                }

                Icon {
                    visible: /^[a-z0-9_]+$/.test(action.iconPath)
                    anchors.centerIn: parent
                    name: visible ? action.iconPath : ""
                    size: 22
                    fill: action.active ? 1 : 0
                    opacity: action.disabled ? 0.35 : 1
                    color: action.active ? Theme.fgAccent : (hover.hovered ? Theme.text : Theme.subtext)
                }

                Shape {
                    visible: !/^[a-z0-9_]+$/.test(action.iconPath)
                    width: 20
                    height: 20
                    anchors.centerIn: parent
                    opacity: action.disabled ? 0.35 : 1
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: action.active ? Theme.fgAccent : (hover.hovered ? Theme.accent : Theme.subtext)
                        strokeWidth: 0

                        PathSvg {
                            path: action.iconPath
                        }

                        Behavior on fillColor {
                            ColorAnimation {
                                duration: Theme.ms(120)
                            }
                        }
                    }

                    transform: Scale {
                        xScale: 20 / 24
                        yScale: 20 / 24
                    }
                }
            }

            Rectangle {
                id: tip

                visible: opacity > 0
                opacity: tipReady ? 1 : 0
                radius: 6
                color: Theme.inverseSurface
                width: tipText.implicitWidth + 16
                height: tipText.implicitHeight + 10
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height + 10
                z: 10

                property bool tipReady: false

                Text {
                    id: tipText

                    anchors.centerIn: parent
                    text: action.label
                    color: Theme.fgInverseSurface
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 420, 0)
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(150)
                    }
                }
            }

            Timer {
                id: tipDelay

                interval: 400
                onTriggered: tip.tipReady = true
            }

            HoverHandler {
                id: hover

                enabled: !action.disabled
                cursorShape: Qt.PointingHandCursor

                onHoveredChanged: {
                    if (hover.hovered) {
                        tipDelay.restart();
                    } else {
                        tipDelay.stop();
                        tip.tipReady = false;
                    }
                }
            }

            TapHandler {
                id: tap

                enabled: !action.disabled
                onTapped: action.tapped()
            }
        }

        component ModeSegment: Item {
            id: seg

            property string label: ""
            property string iconPath: ""
            property bool active: false
            property bool disabled: false

            signal tapped()

            width: 84
            height: parent.height

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.text
                opacity: seg.active || seg.disabled ? 0 : (segTap.pressed ? Theme.statePressed : (segHover.hovered ? Theme.stateHover : 0))

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(120)
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 6
                opacity: seg.disabled ? 0.35 : 1
                scale: segTap.pressed ? 0.92 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.ms(110)
                        easing.type: Easing.OutCubic
                    }
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: seg.iconPath
                    size: 18
                    fill: seg.active ? 1 : 0
                    color: seg.active ? Theme.fgAccent : Theme.subtext
                }

                Shape {
                    visible: false
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: seg.active ? Theme.fgAccent : Theme.subtext
                        strokeWidth: 0

                        PathSvg {
                            path: seg.iconPath
                        }

                        Behavior on fillColor {
                            ColorAnimation {
                                duration: Theme.ms(120)
                            }
                        }
                    }

                    transform: Scale {
                        xScale: 14 / 24
                        yScale: 14 / 24
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.label
                    color: seg.active ? Theme.fgAccent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), (seg.active) ? 640 : 420, 0)
                    font.bold: seg.active

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(120)
                        }
                    }
                }
            }

            HoverHandler {
                id: segHover

                enabled: !seg.disabled
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: segTap

                enabled: !seg.disabled
                onTapped: seg.tapped()
            }
        }

        component ModeSwitch: Rectangle {
            id: modeSwitch

            readonly property bool videoMode: snapWindow.captureMode === "video"
            readonly property bool recording: snapWindow.recordingState !== "idle"
            readonly property int modeIndex: snapWindow.captureMode === "video" ? 1 : (snapWindow.captureMode === "text" ? 2 : (snapWindow.captureMode === "color" ? 3 : 0))

            width: 342
            height: 44
            radius: height / 2
            color: Theme.alpha(Theme.text, switchHover.hovered ? 0.07 : 0.045)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(150)
                }
            }

            HoverHandler {
                id: switchHover
            }

            Rectangle {
                x: 3 + modeSwitch.modeIndex * 84
                y: 3
                width: 84
                height: parent.height - 6
                radius: height / 2
                color: Theme.accent

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.durDefaultSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveFastSpatial
                    }
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 3

                ModeSegment {
                    label: "Photo"
                    iconPath: "photo_camera"
                    active: snapWindow.captureMode === "camera"
                    disabled: modeSwitch.recording || snapWindow.ocrBusy
                    onTapped: snapWindow.setCaptureMode("camera")
                }

                ModeSegment {
                    label: "Video"
                    iconPath: "videocam"
                    active: modeSwitch.videoMode
                    onTapped: {
                        if (snapWindow.hiddenRecording)
                            snapWindow.showToolbar();
                        else
                            snapWindow.setCaptureMode("video");
                    }
                }

                ModeSegment {
                    label: "Text"
                    iconPath: "text_fields"
                    active: snapWindow.captureMode === "text"
                    disabled: modeSwitch.recording || snapWindow.ocrBusy
                    onTapped: snapWindow.setCaptureMode("text")
                }

                ModeSegment {
                    label: "Colour"
                    iconPath: "colorize"
                    active: snapWindow.captureMode === "color"
                    disabled: modeSwitch.recording || snapWindow.ocrBusy
                    onTapped: snapWindow.setCaptureMode("color")
                }
            }
        }

        component TimerChip: Rectangle {
            id: chip

            readonly property bool recording: snapWindow.recordingState === "recording"
            readonly property bool paused: snapWindow.recordingState === "paused"

            width: chipRow.implicitWidth + 16
            height: 30
            radius: Theme.radiusSm
            color: Theme.alpha(Theme.text, 0.05)

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    id: recDot

                    width: 8
                    height: 8
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.recording || chip.paused
                    color: chip.paused ? Theme.subtext : Theme.error

                    SequentialAnimation {
                        running: chip.recording
                        loops: Animation.Infinite

                        onRunningChanged: if (!running)
                            recDot.opacity = 1

                        NumberAnimation {
                            target: recDot
                            property: "opacity"
                            from: 1
                            to: 0.25
                            duration: Theme.ms(650)
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            target: recDot
                            property: "opacity"
                            from: 0.25
                            to: 1
                            duration: Theme.ms(650)
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: snapWindow.formatTimer(snapWindow.recordSeconds)
                    color: Theme.text
                    font.family: "monospace"
                    font.pixelSize: Theme.fs(12)
                }
            }
        }

        component ToggleChip: Item {
            id: chip

            property string iconPath: ""
            property string labelOn: ""
            property string labelOff: ""
            property bool on: false

            signal tapped()

            width: chipRow.implicitWidth + 20
            height: 34
            scale: tap.pressed ? 0.94 : (chipHover.hovered ? 1.03 : 1)

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(110)
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: chip.on ? (chipHover.hovered ? Theme.accentHover : Theme.accent) : (chipHover.hovered ? Theme.alpha(Theme.text, 0.09) : Theme.alpha(Theme.text, 0.05))

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(150)
                    }
                }
            }

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: chip.iconPath
                    size: 17
                    fill: chip.on ? 1 : 0
                    color: chip.on ? Theme.fgAccent : Theme.subtext
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.on ? chip.labelOn : chip.labelOff
                    color: chip.on ? Theme.fgAccent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    font.variableAxes: Theme.axes(Theme.fs(11), 640, 0)
                    font.bold: true

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(120)
                        }
                    }
                }
            }

            HoverHandler {
                id: chipHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: tap

                onTapped: chip.tapped()
            }
        }

        component DragHandle: Item {
            width: 32
            height: 38

            Item {
                id: dragVisual

                anchors.fill: parent
                scale: dragH.active ? 0.9 : (hoverH.hovered ? 1.08 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.ms(110)
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 34
                    radius: Theme.radiusSm
                    color: Theme.accent
                    opacity: dragH.active ? Theme.statePressed : (hoverH.hovered ? Theme.stateHover : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(120)
                        }
                    }
                }

                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    rows: 2
                    spacing: 4

                    Repeater {
                        model: 4

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: hoverH.hovered ? Theme.accent : Theme.subtext

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.ms(120)
                                }
                            }
                        }
                    }
                }
            }

            HoverHandler {
                id: hoverH

                cursorShape: Qt.SizeAllCursor
            }

            DragHandler {
                id: dragH

                target: toolbar
                xAxis.minimum: 8
                xAxis.maximum: snapWindow.width - toolbar.width - 8
                yAxis.minimum: 8
                yAxis.maximum: snapWindow.height - toolbar.height - 8
            }
        }
    }

    Item {
        focus: snapWindow.open

        Keys.onEscapePressed: snapWindow.open = false
    }

    // the recorder's state, for the bar chip and the control centre tile
    Binding {
        target: Capture
        property: "state"
        value: snapWindow.recordingState
    }

    Binding {
        target: Capture
        property: "seconds"
        value: snapWindow.recordSeconds
    }

    Binding {
        target: Capture
        property: "hidden"
        value: snapWindow.hiddenRecording
    }

    Connections {
        function onShowRequested() {
            if (snapWindow.hiddenRecording)
                snapWindow.showToolbar();

        }

        target: Capture
    }

    IpcHandler {
        target: "snap"

        function toggle(): void {
            if (snapWindow.open && !snapWindow.toolbarHidden) {
                snapWindow.open = false;
            } else {
                snapWindow.openMode = "camera";
                snapWindow.beginOpen();
            }
        }

        function open(): void {
            snapWindow.openMode = "camera";
            snapWindow.beginOpen();
        }

        function text(): void {
            if (snapWindow.open && !snapWindow.toolbarHidden) {
                snapWindow.setCaptureMode("text");
                return;
            }
            snapWindow.openMode = "text";
            snapWindow.beginOpen();
        }

        function color(): void {
            if (snapWindow.open && !snapWindow.toolbarHidden) {
                snapWindow.setCaptureMode("color");
                return;
            }
            snapWindow.openMode = "color";
            snapWindow.beginOpen();
        }

        // straight into the recorder
        function video(): void {
            if (snapWindow.hiddenRecording) {
                snapWindow.showToolbar();
                return;
            }
            if (snapWindow.open && !snapWindow.toolbarHidden) {
                snapWindow.setCaptureMode("video");
                return;
            }
            snapWindow.openMode = "video";
            snapWindow.beginOpen();
        }

        function close(): void {
            snapWindow.open = false;
        }
    }
}