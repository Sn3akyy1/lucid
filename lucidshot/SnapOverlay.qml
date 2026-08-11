import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: snapWindow

    property bool open: false
    property bool contentVisible: true
    property bool animateContent: true
    property string activeTool: ""
    property string pendingAction: ""
    property string captureMode: "camera"
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
    // true whenever a recording is running that the currently-visible toolbar
    // (if any) isn't showing - either fully hidden, or a fresh Photo session
    // was opened on top of it. Only the notification's "show" action, or the
    // recording actually stopping, can clear it.
    property bool hiddenRecording: false


    property real selStartX: 0
    property real selStartY: 0
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0

    readonly property color shadeColor: Theme.alpha(Theme.shadow, 0.55)
    readonly property bool shadeVisible: contentVisible && activeTool !== "fullscreen"

    // single source of truth: true whenever the real desktop should be
    // both visible (through the punched hole / everywhere the shade isn't)
    // AND clickable. Freeze-visibility and input-mask both derive from
    // this ONE property so they can never drift out of sync again.
    readonly property bool desktopExposed: captureMode === "video" && (activeTool === "fullscreen" || recordingState !== "idle")

    signal fullscreenRequested()
    signal regionRequested(real x, real y, real w, real h)

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
        id: recordingMask

        Region {
            item: toolbar
        }
    }

    // no item at all: every click passes straight through to the desktop
    Region {
        id: emptyMask
    }

    onDesktopExposedChanged: {
        snapWindow.mask = null;
        if (snapWindow.desktopExposed)
            maskApplyTimer.restart();
    }

    // safety net: if a hidden recording ever stops through some path other
    // than showToolbar() -> Stop, don't leave the toolbar stuck unreachable
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
                snapWindow.mask = recordingMask;
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
        // cropping needs actual pixel work, so it still has to re-encode - but
        // the common case (no crop) only needs its color tags fixed, which a
        // bitstream filter can do as a stream copy instead of a full re-encode
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

    // hardware-encodes via VAAPI when a GPU render node is available (near-zero
    // CPU cost, since the compositor's buffers go straight to the encoder) and
    // only falls back to software libx264 if no such device is found
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
        if (id !== "camera" && id !== "video")
            return;
        if (snapWindow.captureMode === id)
            return;
        if (id === "camera" && snapWindow.recordingState !== "idle")
            return;
        snapWindow.captureMode = id;
        snapWindow.activeTool = id === "video" ? "fullscreen" : "select";
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

    // brings the toolbar back showing the actual recording controls, even if
    // a fresh Photo session had been opened on top of the hidden recording.
    // Reached by switching to Video mode - there is no other way back in
    function showToolbar() {
        if (!snapWindow.hiddenRecording)
            return;
        // Esc or "snap close" may have set open=false while it was hidden
        // (or after a fresh session was opened on top of it) - the window
        // itself has to be remapped, or nothing below will ever be seen
        snapWindow.open = true;
        snapWindow.hiddenRecording = false;
        snapWindow.toolbarHidden = false;
        snapWindow.captureMode = "video";
        snapWindow.activeTool = snapWindow.currentCrop ? "select" : "fullscreen";
        snapWindow.resetSelection();
        snapWindow.mask = snapWindow.desktopExposed ? recordingMask : null;
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
        // already open and visible: nothing to do. But if it's open and
        // hidden (a backgrounded recording), fall through and open a fresh
        // session on top of it instead of no-op'ing
        if (snapWindow.open && !snapWindow.toolbarHidden)
            return;
        freezeProcess.running = true;
    }

    // resets everything needed for a fresh Photo-mode session. If a recording
    // is currently hidden in the background, its bookkeeping (recordingState,
    // segmentFiles, mic/headphone, etc.) is left completely untouched so it
    // keeps recording correctly and can still be stopped later via showToolbar()
    function resetToFreshSession() {
        snapWindow.contentVisible = true;
        snapWindow.animateContent = true;
        snapWindow.activeTool = "select";
        snapWindow.pendingAction = "";
        snapWindow.captureMode = "camera";
        snapWindow.toolbarHidden = false;
        snapWindow.resetSelection();
        if (!snapWindow.hiddenRecording) {
            snapWindow.recordingState = "idle";
            snapWindow.recordSeconds = 0;
            snapWindow.micOn = true;
            snapWindow.headphoneOn = true;
        }
        snapWindow.mask = snapWindow.desktopExposed ? recordingMask : null;
        toolbar.x = Qt.binding(function () {
            return (snapWindow.width - toolbar.width) / 2;
        });
        toolbar.y = toolbar.restY;
    }

    Process {
        id: freezeProcess

        // -l 0: skip PNG compression entirely. It's a throwaway cache file
        // overwritten every capture, and compression (not disk I/O) was most
        // of the delay between pressing the key and the screen freezing -
        // level 6 (grim's default) took ~220ms here, level 0 takes ~40ms
        command: ["sh", "-c", "grim -l 0 '" + snapWindow.freezePath + "'"]

        onExited: (code) => {
            if (code !== 0)
                return;
            freezeImg.source = "";
            freezeImg.source = "file://" + snapWindow.freezePath;
            snapWindow.open = true;
            snapWindow.resetToFreshSession();
        }
    }

    function runTool(id) {
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
                duration: 120
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
                duration: 120
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
                duration: 120
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
                duration: 120
            }
        }
    }

    Rectangle {
        color: "transparent"
        border.color: Theme.accent
        border.width: 1
        // hidden while a video crop is actually locked in and recording - but
        // that only applies to the video session itself, not a fresh Photo
        // session opened on top of some other, unrelated hidden recording
        visible: snapWindow.contentVisible && snapWindow.activeTool === "select" && snapWindow.selW > 0 && snapWindow.selH > 0 && !(snapWindow.captureMode === "video" && snapWindow.recordingState !== "idle")
        x: snapWindow.selX
        y: snapWindow.selY
        width: snapWindow.selW
        height: snapWindow.selH
    }

    MouseArea {
        id: selectArea

        anchors.fill: parent
        enabled: snapWindow.contentVisible && !snapWindow.desktopExposed
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
                if (snapWindow.captureMode === "camera")
                    snapWindow.open = false;
                return;
            }
            if (snapWindow.selW < 2 || snapWindow.selH < 2) {
                snapWindow.selW = 0;
                snapWindow.selH = 0;
                return;
            }
            if (snapWindow.captureMode !== "camera")
                return;
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

            radius: Theme.radiusLg
            color: Theme.bgOpaque
            border.color: toolbarHover.hovered ? Theme.alpha(Theme.text, 0.14) : Theme.alpha(Theme.text, 0.06)
            border.width: 1
            width: toolRow.implicitWidth + 20
            height: 56
            opacity: (snapWindow.contentVisible && !snapWindow.toolbarHidden) ? 1 : 0
            visible: opacity > 0

            HoverHandler {
                id: toolbarHover

                cursorShape: Qt.ArrowCursor
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }

            Behavior on opacity {
                enabled: snapWindow.animateContent
                NumberAnimation {
                    duration: 120
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 220
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
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    IconAction {
                        iconPath: "M3,3H9V5H5V9H3V3M15,3H21V9H19V5H15V3M19,15H21V21H15V19H19V15M3,15H5V19H9V21H3V15Z"
                        label: "Snap Select"
                        active: snapWindow.activeTool === "select"
                        disabled: snapWindow.captureMode === "video" && snapWindow.recordingState !== "idle"
                        onTapped: snapWindow.runTool("select")
                    }

                    IconAction {
                        iconPath: "M21,16H3V4H21M21,2H3C1.89,2 1,2.89 1,4V16A2,2 0 0,0 3,18H10V20H8V22H16V20H14V18H21A2,2 0 0,0 23,16V4C23,2.89 22.1,2 21,2Z"
                        label: "Fullscreen"
                        active: snapWindow.activeTool === "fullscreen"
                        disabled: snapWindow.captureMode === "video" && snapWindow.recordingState !== "idle"
                        onTapped: snapWindow.runTool("fullscreen")
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
                                    return "M8 5H10V19H8V5Z M14 5H16V19H14V5Z";
                                if (snapWindow.recordingState === "paused")
                                    return "M9 5L19 12L9 19Z";
                                return "M4 12A8 8 0 1 1 20 12A8 8 0 1 1 4 12Z";
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
                            iconPath: "M6 6H18V18H6V6Z"
                            label: "Stop"
                            disabled: snapWindow.recordingState === "idle"
                            onTapped: snapWindow.stopRecording()
                        }

                        IconAction {
                            iconPath: "M11.83,9L15,12.16C15,12.11 15,12.05 15,12A3,3 0 0,0 12,9C11.94,9 11.89,9 11.83,9M7.53,9.8L9.08,11.35C9.03,11.56 9,11.77 9,12A3,3 0 0,0 12,15C12.22,15 12.44,14.97 12.65,14.92L14.2,16.47C13.53,16.8 12.79,17 12,17A5,5 0 0,1 7,12C7,11.21 7.2,10.47 7.53,9.8M2,4.27L4.28,6.55L4.73,7C3.08,8.3 1.78,10 1,12C2.73,16.39 7,19.5 12,19.5C13.55,19.5 15.03,19.2 16.38,18.66L16.81,19.08L19.73,22L21,20.73L3.27,3M12,7A5,5 0 0,1 17,12C17,12.64 16.87,13.26 16.64,13.82L19.57,16.75C21.07,15.5 22.27,13.86 23,12C21.27,7.61 17,4.5 12,4.5C10.6,4.5 9.26,4.75 8,5.2L10.17,7.35C10.74,7.13 11.35,7 12,7Z"
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
                            iconPath: "M12.06 15c1.66 0 2.99-1.34 2.99-3V6c.01-1.66-1.33-3-2.99-3s-3 1.34-3 3v6c0 1.66 1.34 3 3 3m6.93-2.03a.857.857 0 0 0-.85-.97c-.42 0-.77.3-.83.71-.37 2.61-2.72 4.39-5.25 4.39s-4.88-1.77-5.25-4.39a.84.84 0 0 0-.83-.71c-.52 0-.92.46-.85.97.46 2.97 2.96 5.3 5.93 5.75V20H9c-.55 0-1 .45-1 1s.45 1 1 1h6c.55 0 1-.45 1-1s-.45-1-1-1h-1.94v-1.28c2.96-.43 5.47-2.78 5.93-5.75" + (snapWindow.micOn ? "" : " M4 5L6 3L20 17L18 19Z")
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
                            iconPath: "M12 1c-4.97 0-9 4.03-9 9v7c0 1.66 1.34 3 3 3h3v-8H5v-2c0-3.87 3.13-7 7-7s7 3.13 7 7v2h-4v8h3c1.66 0 3-1.34 3-3v-7c0-4.97-4.03-9-9-9z" + (snapWindow.headphoneOn ? "" : " M4 5L6 3L20 17L18 19Z")
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

        // thin vertical separator used to group toolbar sections
        component SnapDivider: Rectangle {
            width: 1
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.alpha(Theme.outline, 0.6)
        }

        // single icon button: state-layer highlight, disabled dimming, hover tooltip
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
                        duration: 110
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: stateLayer

                    anchors.centerIn: parent
                    width: 38
                    height: 38
                    radius: Theme.radiusSm
                    color: action.activeColor
                    opacity: action.disabled ? 0 : (action.active ? 1 : (tap.pressed ? Theme.statePressed : (hover.hovered ? Theme.stateHover : 0)))

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                Shape {
                    width: 20
                    height: 20
                    anchors.centerIn: parent
                    opacity: action.disabled ? 0.35 : 1
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: action.active ? Theme.onAccent : (hover.hovered ? Theme.accent : Theme.subtext)
                        strokeWidth: 0

                        PathSvg {
                            path: action.iconPath
                        }

                        Behavior on fillColor {
                            ColorAnimation {
                                duration: 120
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
                color: Theme.bgOpaque
                border.color: Theme.alpha(Theme.text, 0.15)
                border.width: 1
                width: tipText.implicitWidth + 16
                height: tipText.implicitHeight + 8
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height + 10
                z: 10

                property bool tipReady: false

                Text {
                    id: tipText

                    anchors.centerIn: parent
                    text: action.label
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
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

        // one half of the Photo/Video segmented switch
        component ModeSegment: Item {
            id: seg

            property string label: ""
            property string iconPath: ""
            property bool active: false
            property bool disabled: false

            signal tapped()

            width: 76
            height: parent.height

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusXs
                color: Theme.text
                opacity: seg.active || seg.disabled ? 0 : (segTap.pressed ? Theme.statePressed : (segHover.hovered ? Theme.stateHover : 0))

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
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
                        duration: 110
                        easing.type: Easing.OutCubic
                    }
                }

                Shape {
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: seg.active ? Theme.onAccent : Theme.subtext
                        strokeWidth: 0

                        PathSvg {
                            path: seg.iconPath
                        }

                        Behavior on fillColor {
                            ColorAnimation {
                                duration: 120
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
                    color: seg.active ? Theme.onAccent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: seg.active

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
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

        // Photo/Video segmented switch with a sliding solid-accent thumb
        component ModeSwitch: Rectangle {
            id: modeSwitch

            readonly property bool videoMode: snapWindow.captureMode === "video"
            readonly property bool recording: snapWindow.recordingState !== "idle"

            width: 158
            height: 38
            radius: Theme.radiusSm
            color: switchHover.hovered ? Theme.alpha(Theme.text, 0.08) : Theme.alpha(Theme.text, 0.05)

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            HoverHandler {
                id: switchHover
            }

            Rectangle {
                x: modeSwitch.videoMode ? 79 : 3
                y: 3
                width: 76
                height: parent.height - 6
                radius: Theme.radiusXs
                color: Theme.accent

                Behavior on x {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 3

                ModeSegment {
                    label: "Photo"
                    iconPath: "M9,2L7.17,4H4A2,2 0 0,0 2,6V18A2,2 0 0,0 4,20H20A2,2 0 0,0 22,18V6A2,2 0 0,0 20,4H16.83L15,2H9M12,7A5,5 0 0,1 17,12A5,5 0 0,1 12,17A5,5 0 0,1 7,12A5,5 0 0,1 12,7M12,9A3,3 0 0,0 9,12A3,3 0 0,0 12,15A3,3 0 0,0 15,12A3,3 0 0,0 12,9Z"
                    active: !modeSwitch.videoMode
                    disabled: modeSwitch.recording && modeSwitch.videoMode
                    onTapped: snapWindow.setCaptureMode("camera")
                }

                ModeSegment {
                    label: "Video"
                    iconPath: "M17,10.5V7A1,1 0 0,0 16,6H4A1,1 0 0,0 3,7V17A1,1 0 0,0 4,18H16A1,1 0 0,0 17,17V13.5L21,17.5V6.5L17,10.5Z"
                    active: modeSwitch.videoMode
                    onTapped: {
                        if (snapWindow.hiddenRecording)
                            snapWindow.showToolbar();
                        else
                            snapWindow.setCaptureMode("video");
                    }
                }
            }
        }

        // elapsed-time chip with a pulsing dot while actively recording
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
                            duration: 650
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            target: recDot
                            property: "opacity"
                            from: 0.25
                            to: 1
                            duration: 650
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: snapWindow.formatTimer(snapWindow.recordSeconds)
                    color: Theme.text
                    font.family: "monospace"
                    font.pixelSize: 12
                }
            }
        }

        // labeled audio toggle pill (mic / system audio) - solid accent when on
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
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: chip.on ? (chipHover.hovered ? Theme.accentHover : Theme.accent) : (chipHover.hovered ? Theme.alpha(Theme.text, 0.09) : Theme.alpha(Theme.text, 0.05))

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: 6

                Shape {
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: chip.on ? Theme.onAccent : Theme.subtext
                        strokeWidth: 0

                        PathSvg {
                            path: chip.iconPath
                        }

                        Behavior on fillColor {
                            ColorAnimation {
                                duration: 120
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
                    text: chip.on ? chip.labelOn : chip.labelOff
                    color: chip.on ? Theme.onAccent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
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

        // drag affordance that repositions the toolbar
        component DragHandle: Item {
            width: 32
            height: 38

            Item {
                id: dragVisual

                anchors.fill: parent
                scale: dragH.active ? 0.9 : (hoverH.hovered ? 1.08 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
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
                            duration: 120
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
                                    duration: 120
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

    IpcHandler {
        target: "snap"

        function toggle(): void {
            // open-but-hidden isn't "open" from the user's perspective -
            // route through beginOpen() so it starts a fresh session instead
            // of just flipping straight back to closed
            if (snapWindow.open && !snapWindow.toolbarHidden) {
                snapWindow.open = false;
            } else {
                snapWindow.beginOpen();
            }
        }

        function open(): void {
            snapWindow.beginOpen();
        }

        function close(): void {
            snapWindow.open = false;
        }
    }
}