import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs
import qs.lucidui
import qs.luciddocks

PanelWindow {
    id: osdWindow

    property bool ready: false
    property bool cardVisible: false
    property string oscType: ""
    property real levelValue: 0
    property bool levelMuted: false
    property bool toggleState: false
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property int volumePercent: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool volMuted: (sink && sink.audio) ? sink.audio.muted : false
    readonly property bool micMuted: (source && source.audio) ? source.audio.muted : false
    property string backlightDevice: ""
    property int maxBrightness: 0
    readonly property int brightnessPercent: osdWindow.maxBrightness > 0 ? Math.round((parseInt(brightnessFile.text()) / osdWindow.maxBrightness) * 100) : 0
    property bool capsLock: false
    property bool numLock: false
    property bool kbInitialized: false
    property int pendingBrightness: -1
    // the keyboard backlight is an led, not a backlight device, and steps
    // through a few whole levels
    property string kbdDevice: ""
    property int kbdMax: 0
    readonly property string kbdWatcher: Qt.resolvedUrl("kbd-backlight-watch.py").toString().replace("file://", "")
    // the last level reported, so the watcher and the file watch never show
    // the same change twice
    property int kbdLast: -1
    property int kbdLevel: 0
    property bool kbdFileWritten: false
    // a handful of steps reads better as blocks than as a bar; a keyboard with
    // a fine-grained level keeps the level track
    readonly property bool kbdSegmented: osdWindow.kbdMax > 0 && osdWindow.kbdMax <= 6
    // notch style: the card sits flush on the bottom edge and rises out of it,
    // with the dock's concave corners at its sides
    readonly property bool notch: Prefs.osdNotch
    readonly property int notchFlare: osdWindow.notch ? Theme.dp(Prefs.dockNotchFlare) : 0

    // m3 shape, spacing and slider metrics, shared with lucidbar/System.qml
    readonly property int cardPadX: Theme.dp(12)
    readonly property int badgeSize: Theme.dp(36)
    readonly property int cardGap: Theme.dp(10)
    readonly property int glyphSize: Theme.dp(18)
    // the level card's own, tighter slider metrics
    readonly property int levelTrackH: Theme.dp(30)
    readonly property int levelHandleH: Theme.dp(38)

    readonly property string levelIcon: {
        if (osdWindow.oscType === "kbdbacklight")
            return "keyboard";

        if (osdWindow.oscType === "brightness")
            return osdWindow.levelValue < 34 ? "brightness_low" : (osdWindow.levelValue < 67 ? "brightness_medium" : "brightness_high");

        if (osdWindow.levelMuted || osdWindow.levelValue <= 0)
            return "volume_off";

        return osdWindow.levelValue < 34 ? "volume_mute" : (osdWindow.levelValue < 67 ? "volume_down" : "volume_up");
    }
    readonly property bool isLevelType: osdWindow.oscType === "volume" || osdWindow.oscType === "brightness" || (osdWindow.oscType === "kbdbacklight" && !osdWindow.kbdSegmented)
    readonly property bool isSegmentType: osdWindow.oscType === "kbdbacklight" && osdWindow.kbdSegmented
    // only volume and brightness are set from the card; the keyboard light is news
    readonly property bool isSettable: osdWindow.oscType === "volume" || osdWindow.oscType === "brightness"
    readonly property bool badgeActive: osdWindow.toggleState
    readonly property string toggleIcon: {
        switch (osdWindow.oscType) {
        case "mic":
            return osdWindow.toggleState ? "mic" : "mic_off";
        case "capslock":
            return "keyboard_capslock";
        case "numlock":
            return "dialpad";
        default:
            return "";
        }
    }
    readonly property string currentLabel: {
        switch (osdWindow.oscType) {
        case "volume":
            return "Volume";
        case "brightness":
            return "Brightness";
        case "kbdbacklight":
            return "Keyboard light";
        case "mic":
            return "Microphone";
        case "capslock":
            return "Caps Lock";
        case "numlock":
            return "Num Lock";
        default:
            return "";
        }
    }
    // the lock keys show the letters the next keystroke makes rather than a word
    readonly property string toggleOnText: {
        switch (osdWindow.oscType) {
        case "mic":
            return "Unmuted";
        case "capslock":
            return "ABC";
        case "numlock":
            return "123";
        default:
            return "";
        }
    }
    readonly property string toggleOffText: {
        switch (osdWindow.oscType) {
        case "mic":
            return "Muted";
        case "capslock":
            return "abc";
        case "numlock":
            return "Arrows";
        default:
            return "";
        }
    }
    readonly property color toggleOffColor: osdWindow.oscType === "mic" ? Theme.error : Theme.subtextDim

    // the params have to be set before the flag flips: a Behavior reads the
    // previous value of anything its animation binds to
    function setCardVisible(v) {
        cardFade.duration = v ? Theme.durEnter : Theme.durExit;
        cardFade.easing.bezierCurve = v ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel;
        cardRise.duration = v ? Theme.durEnter : Theme.durExit;
        cardRise.easing.bezierCurve = v ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel;
        cardPop.duration = v ? Theme.durEnter : Theme.durExit;
        if (v) {
            cardPop.easing.type = Easing.OutBack;
            cardPop.easing.overshoot = Theme.emphasizedOvershoot;
        } else {
            cardPop.easing.bezierCurve = Theme.easeEmphasizedAccel;
            cardPop.easing.type = Easing.Bezier;
        }
        osdWindow.cardVisible = v;
    }

    function trigger() {
        osdWindow.setCardVisible(true);
        hideTimer.restart();
        if (osdWindow.isLevelType) {
            if (!levelTrack.dragging)
                levelPulseAnim.restart();

        } else if (osdWindow.isSegmentType) {
            segmentPulseAnim.restart();
        } else if (osdWindow.oscType === "mic") {
            pulseAnim.restart();
        } else {
            nudgeAnim.restart();
        }
    }

    function setBrightness(percent) {
        osdWindow.pendingBrightness = Math.max(0, Math.min(100, Math.round(percent)));
        brightnessDebounce.restart();
    }

    function applyLevel(v) {
        hideTimer.restart();
        if (!osdWindow.isSettable)
            return ;

        osdWindow.levelValue = v;
        if (osdWindow.oscType === "brightness") {
            osdWindow.setBrightness(v);
            return ;
        }
        if (!osdWindow.sink || !osdWindow.sink.audio)
            return ;

        if (osdWindow.sink.audio.muted)
            osdWindow.sink.audio.muted = false;

        osdWindow.levelMuted = false;
        osdWindow.sink.audio.volume = Math.max(0, Math.min(1, v / 100));
    }

    function showVolume() {
        osdWindow.oscType = "volume";
        osdWindow.levelValue = osdWindow.volumePercent;
        osdWindow.levelMuted = osdWindow.volMuted;
        osdWindow.trigger();
    }

    function showBrightness() {
        osdWindow.oscType = "brightness";
        osdWindow.levelValue = osdWindow.brightnessPercent;
        osdWindow.levelMuted = false;
        osdWindow.trigger();
    }

    function showKbdBacklight() {
        osdWindow.oscType = "kbdbacklight";
        osdWindow.levelValue = osdWindow.kbdMax > 0 ? Math.round((osdWindow.kbdLevel / osdWindow.kbdMax) * 100) : 0;
        osdWindow.levelMuted = false;
        osdWindow.trigger();
    }

    // caps lock, num lock and the microphone are on/off news; with toasts chosen
    // for them ToastEvents shows it and the card stays down
    signal toggled(string kind, bool on)

    function showToggle(kind, on) {
        osdWindow.toggled(kind, on);
        if (Prefs.osdTogglesToast)
            return ;

        osdWindow.oscType = kind;
        osdWindow.toggleState = on;
        osdWindow.trigger();
    }

    function showMic() {
        osdWindow.showToggle("mic", !osdWindow.micMuted);
    }

    function showCaps(state) {
        osdWindow.showToggle("capslock", state);
    }

    function showNum(state) {
        osdWindow.showToggle("numlock", state);
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // remapped with the rest of the shell when displays change
    visible: Monitors.surfacesUp
    implicitWidth: Theme.dp(480)
    implicitHeight: osdWindow.notch ? Theme.dp(64) : Theme.dp(140)
    margins.bottom: osdWindow.notch ? 0 : Theme.dp(96)
    Component.onCompleted: {
        findDeviceProc.running = true;
        findKbdProc.running = true;
    }
    onBacklightDeviceChanged: {
        if (backlightDevice !== "")
            readMaxProc.running = true;

    }
    onKbdDeviceChanged: {
        if (kbdDevice === "")
            return ;

        readKbdMaxProc.running = true;
        // the watcher's command is set here rather than bound: the process
        // takes its argument list as it starts, and a binding has not caught
        // up with the device in the same pass that set it - it would be
        // launched on the empty path it had before
        kbdWatchProc.command = ["python3", osdWindow.kbdWatcher, "/sys/class/leds/" + osdWindow.kbdDevice];
        kbdWatchProc.running = true;
    }

    // both sources land here: the watcher for the key, the file for a level
    // set by anything that writes it. `written` marks a level read after a
    // write to the file: news even when it matches the level the card last
    // showed, since the key may have moved the led without the card hearing
    function reportKbdLevel(level, written) {
        if (level < 0 || (level === osdWindow.kbdLast && !written))
            return ;

        const seeding = osdWindow.kbdLast < 0;
        osdWindow.kbdLast = level;
        osdWindow.kbdLevel = level;
        if (seeding || !osdWindow.ready)
            return ;

        osdWindow.showKbdBacklight();
    }
    // muting is its own answer; the tick is heard at the level just set
    onVolumePercentChanged: {
        if (!osdWindow.ready)
            return ;

        osdWindow.showVolume();
        if (!osdWindow.volMuted)
            osdWindow.levelTick("volume");

    }
    onVolMutedChanged: {
        if (!osdWindow.ready)
            return ;

        osdWindow.showVolume();
        if (!osdWindow.volMuted)
            osdWindow.levelTick("volume");

    }
    // idle dimming moves the backlight too: nothing ticks while you are away,
    // or as it comes back up when you return
    onBrightnessPercentChanged: {
        if (!osdWindow.ready)
            return ;

        osdWindow.showBrightness();
        if (!idleWatch.isIdle && Date.now() - osdWindow.activeSince > 1500)
            osdWindow.levelTick("brightness");

    }
    onMicMutedChanged: {
        if (!osdWindow.ready)
            return ;

        osdWindow.showMic();
        Sounds.feedback(osdWindow.micMuted ? "mic-off" : "mic-on", Prefs.soundOnMic);
    }
    BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && card.visible) ? osdBlurRegion : null

    anchors {
        bottom: true
    }

    PwObjectTracker {
        objects: [osdWindow.sink, osdWindow.source]
    }

    Timer {
        interval: 800
        running: true
        onTriggered: osdWindow.ready = true
    }

    // a level ticks at its first change, then once more where a drag or a held
    // key comes to rest, rather than at every step on the way
    property string tickPending: ""
    property real activeSince: 0

    function levelTick(key) {
        if (tickSettle.running)
            osdWindow.tickPending = key;
        else
            osdWindow.tick(key);
        tickSettle.restart();
    }

    function tick(key) {
        Sounds.feedback(key, key === "volume" ? Prefs.soundOnVolume : Prefs.soundOnBrightness);
    }

    Timer {
        id: tickSettle

        interval: 220
        onTriggered: {
            if (osdWindow.tickPending !== "")
                osdWindow.tick(osdWindow.tickPending);

            osdWindow.tickPending = "";
        }
    }

    // idle a little short of the dim, so the dim and its undo both find it idle
    IdleMonitor {
        id: idleWatch

        timeout: Prefs.idleEnabled && Prefs.idleDim ? Math.max(5, Prefs.idleDimAfter - 3) : 60
        respectInhibitors: false
        onIsIdleChanged: {
            if (!idleWatch.isIdle)
                osdWindow.activeSince = Date.now();

        }
    }

    Timer {
        id: hideTimer

        interval: 1600
        onTriggered: {
            if (levelTrack.dragging || levelTrack.hovered) {
                hideTimer.restart();
                return ;
            }
            osdWindow.setCardVisible(false);
        }
    }

    Process {
        id: findDeviceProc

        command: ["bash", "-c", "ls /sys/class/backlight | head -1"]

        stdout: StdioCollector {
            onStreamFinished: osdWindow.backlightDevice = this.text.trim().replace(/[@/*=|]$/, "")
        }

    }

    Timer {
        id: brightnessDebounce

        interval: 60
        onTriggered: {
            if (osdWindow.pendingBrightness >= 0)
                setBrightnessProc.running = true;

        }
    }

    Process {
        id: setBrightnessProc

        command: osdWindow.pendingBrightness >= 0 ? ["brightnessctl", "set", osdWindow.pendingBrightness + "%"] : []
    }

    Process {
        id: readMaxProc

        command: osdWindow.backlightDevice ? ["cat", "/sys/class/backlight/" + osdWindow.backlightDevice + "/max_brightness"] : []

        stdout: StdioCollector {
            onStreamFinished: osdWindow.maxBrightness = parseInt(this.text.trim())
        }

    }

    FileView {
        id: brightnessFile

        path: osdWindow.backlightDevice ? "/sys/class/backlight/" + osdWindow.backlightDevice + "/brightness" : ""
        watchChanges: true
        onFileChanged: reload()
    }

    // vendor-prefixed: dell::kbd_backlight, tpacpi::kbd_backlight, asus::kbd_backlight
    Process {
        id: findKbdProc

        command: ["sh", "-c", "ls /sys/class/leds 2>/dev/null | grep -m1 'kbd_backlight$' || true"]

        stdout: StdioCollector {
            onStreamFinished: osdWindow.kbdDevice = this.text.trim()
        }

    }

    Process {
        id: readKbdMaxProc

        command: osdWindow.kbdDevice ? ["cat", "/sys/class/leds/" + osdWindow.kbdDevice + "/max_brightness"] : []

        stdout: StdioCollector {
            onStreamFinished: osdWindow.kbdMax = parseInt(this.text.trim()) || 0
        }

    }

    FileView {
        id: kbdFile

        path: osdWindow.kbdDevice ? "/sys/class/leds/" + osdWindow.kbdDevice + "/brightness" : ""
        watchChanges: true
        printErrors: false
        // the driver sets the led out of line with the write, so the file
        // still reads the old level right after the change lands; the reread
        // waits for it to settle
        onFileChanged: {
            osdWindow.kbdFileWritten = true;
            kbdSettleTimer.restart();
        }
        onLoaded: {
            osdWindow.reportKbdLevel(parseInt(text()) || 0, osdWindow.kbdFileWritten);
            osdWindow.kbdFileWritten = false;
        }
    }

    Timer {
        id: kbdSettleTimer

        interval: 200
        onTriggered: kbdFile.reload()
    }

    // the key is handled in firmware: the kernel moves the led and raises a
    // sysfs notification without anything writing the file, so watching the
    // file cannot see it. the helper sits on that notification and reports
    Process {
        id: kbdWatchProc

        stdout: SplitParser {
            onRead: (line) => {
                const level = parseInt(line.trim());
                if (!isNaN(level))
                    osdWindow.reportKbdLevel(level, false);

            }
        }

    }

    // lock keys have no hyprland event, but the kernel's keyboard leds carry the
    // same state and reading them never touches hyprland. polling its request
    // socket instead deadlocked it against a resizing window for 5 s at a time
    function readLocks() {
        var caps = false;
        var num = false;
        var files = ledFiles.instances;
        for (var i = 0; i < files.length; i++) {
            files[i].reload();
            var on = parseInt(files[i].text()) > 0;
            if (files[i].isCaps)
                caps = caps || on;
            else
                num = num || on;
        }
        if (osdWindow.kbInitialized && osdWindow.ready) {
            if (caps !== osdWindow.capsLock) {
                osdWindow.capsLock = caps;
                osdWindow.showCaps(caps);
                Sounds.feedback(caps ? "caps-on" : "caps-off", Prefs.soundOnCaps);
            }
            if (num !== osdWindow.numLock) {
                osdWindow.numLock = num;
                osdWindow.showNum(num);
            }
        } else {
            osdWindow.capsLock = caps;
            osdWindow.numLock = num;
        }
        osdWindow.kbInitialized = true;
    }

    // every keyboard that has the leds, so a lock on any of them counts
    Process {
        id: ledScan

        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock /sys/class/leds/*::numlock 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: ledFiles.model = this.text.split("\n").filter((p) => {
                return p !== "";
            })
        }

    }

    Variants {
        id: ledFiles

        model: []

        FileView {
            required property string modelData
            readonly property bool isCaps: modelData.endsWith("::capslock")

            path: modelData + "/brightness"
            blockLoading: true
            printErrors: false
        }

    }

    Timer {
        interval: 400
        running: osdWindow.ready && ledFiles.instances.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: osdWindow.readLocks()
    }

    Region {
        id: osdBlurRegion

        readonly property real paintedX: card.x + card.width * (1 - card.scale) / 2
        readonly property real paintedY: card.y + card.height * (1 - card.scale) / 2
        readonly property real paintedWidth: card.width * card.scale
        readonly property real paintedHeight: card.height * card.scale

        x: Math.ceil(osdBlurRegion.paintedX - 0.002)
        y: Math.ceil(osdBlurRegion.paintedY - 0.002)
        width: Math.max(0, Math.floor(osdBlurRegion.paintedX + osdBlurRegion.paintedWidth + 0.002) - Math.ceil(osdBlurRegion.paintedX - 0.002))
        height: Math.max(0, Math.floor(osdBlurRegion.paintedY + osdBlurRegion.paintedHeight + 0.002) - Math.ceil(osdBlurRegion.paintedY - 0.002))
        radius: Math.round(card.radius * card.scale)
        bottomLeftRadius: osdWindow.notch ? 0 : Math.round(card.radius * card.scale)
        bottomRightRadius: osdWindow.notch ? 0 : Math.round(card.radius * card.scale)
    }

    Rectangle {
        id: card

        readonly property int levelWidth: Theme.dp(260)
        readonly property int toggleWidth: osdWindow.cardPadX * 2 + osdWindow.badgeSize + osdWindow.cardGap + Math.ceil(Math.max(labelMetrics.advanceWidth, stateFlip.width)) + Theme.dp(6)

        // one vertical anchor whatever the style: swapping anchors would let the
        // anchor engine write the height and drop its binding. the notch sits on
        // the bottom edge through the offset, and sinks past it to hide
        anchors.centerIn: parent
        anchors.verticalCenterOffset: osdWindow.notch ? (parent.height - card.height) / 2 + (osdWindow.cardVisible ? 0 : card.height) : (osdWindow.cardVisible ? 0 : Theme.dp(16))
        height: (osdWindow.isLevelType || osdWindow.isSegmentType) ? Theme.dp(50) : Theme.dp(56)
        width: (osdWindow.isLevelType || osdWindow.isSegmentType) ? card.levelWidth : card.toggleWidth
        radius: height / 2
        bottomLeftRadius: osdWindow.notch ? 0 : card.radius
        bottomRightRadius: osdWindow.notch ? 0 : card.radius
        color: Theme.bg
        opacity: osdWindow.cardVisible ? 1 : 0
        // the notch rises out of the edge rather than popping
        scale: osdWindow.cardVisible || osdWindow.notch ? 1 : 0.9
        visible: opacity > 0.15

        TextMetrics {
            id: labelMetrics

            text: osdWindow.currentLabel
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeSize("labelSmall")
            font.variableAxes: Theme.axes(Theme.typeSize("labelSmall"), 560, 0)
        }

        Slider {
            id: levelTrack

            visible: osdWindow.isLevelType
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(10)
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            size: "m"
            trackH: osdWindow.levelTrackH
            handleH: osdWindow.levelHandleH
            // a full stadium cap, as round as the card behind it
            outerR: osdWindow.levelTrackH / 2
            iconSize: Theme.dp(18)
            from: 0
            to: 100
            value: osdWindow.levelMuted ? 0 : osdWindow.levelValue
            icon: osdWindow.levelIcon
            showValue: false
            inlineValue: true
            valueText: (v) => {
                return osdWindow.levelMuted ? "Off" : Math.round(v) + "%";
            }
            activeColor: osdWindow.levelMuted ? Theme.outlineStrong : Theme.primary
            inactiveColor: Theme.withBlur(Theme.surfaceHighest)
            easeValue: card.visible
            onMoved: (v) => {
                return osdWindow.applyLevel(v);
            }
            onReleased: hideTimer.restart()
            onHoveredChanged: {
                if (!levelTrack.hovered)
                    hideTimer.restart();

            }

        }

        // a keyboard light with a few whole steps: one block per step. only the
        // steps that are on have a full body, the rest are a thin rail, since
        // blocks of one thickness side by side read as a bar cut in pieces
        Item {
            id: segmentRow

            readonly property int steps: Math.max(1, osdWindow.kbdMax)
            readonly property int gap: Theme.dp(4)

            visible: osdWindow.isSegmentType
            anchors.fill: parent
            anchors.leftMargin: Theme.dp(16)
            anchors.rightMargin: Theme.dp(16)

            Icon {
                id: segmentIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "keyboard"
                size: Theme.dp(18)
                fill: osdWindow.kbdLevel > 0 ? 1 : 0
                color: osdWindow.kbdLevel > 0 ? Theme.primary : Theme.subtextDim
            }

            LText {
                id: segmentReadout

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                role: "labelLarge"
                tabular: true
                color: osdWindow.kbdLevel > 0 ? Theme.text : Theme.subtextDim
                text: osdWindow.kbdLevel > 0 ? osdWindow.kbdLevel + "/" + segmentRow.steps : "Off"
            }

            Row {
                id: segmentBlocks

                readonly property real blockW: (segmentBlocks.width - segmentRow.gap * (segmentRow.steps - 1)) / segmentRow.steps

                anchors.left: segmentIcon.right
                anchors.leftMargin: Theme.dp(12)
                anchors.right: segmentReadout.left
                anchors.rightMargin: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                height: osdWindow.levelTrackH / 2
                spacing: segmentRow.gap

                Repeater {
                    model: segmentRow.steps

                    Item {
                        required property int index
                        readonly property bool lit: index < osdWindow.kbdLevel

                        width: segmentBlocks.blockW
                        height: segmentBlocks.height

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: parent.lit ? parent.height : Theme.dp(4)
                            radius: Theme.pill(height)
                            color: parent.lit ? Theme.primary : Theme.withBlur(Theme.surfaceHighest)

                            Behavior on height {
                                enabled: card.visible

                                NumberAnimation {
                                    duration: Theme.durMedium
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeEmphasizedDecel
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durShort
                                }

                            }

                        }

                    }

                }

            }

        }

        Item {
            id: iconBadge

            visible: !osdWindow.isLevelType && !osdWindow.isSegmentType
            anchors.left: parent.left
            anchors.leftMargin: osdWindow.cardPadX
            anchors.verticalCenter: parent.verticalCenter
            width: osdWindow.badgeSize
            height: osdWindow.badgeSize

            readonly property color fillColor: osdWindow.badgeActive ? Theme.accent : Theme.withBlur(Theme.surfaceHighest)

            MaterialShape {
                id: badgeShape

                anchors.fill: parent
                shape: "cookie9"
                color: iconBadge.fillColor
                rotation: osdWindow.badgeActive ? 20 : 0

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.durSlowSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

            }

            Icon {
                id: toggleGlyph

                anchors.centerIn: parent
                name: osdWindow.toggleIcon
                size: osdWindow.glyphSize + Theme.dp(2)
                fill: osdWindow.badgeActive ? 1 : 0
                color: osdWindow.badgeActive ? Theme.fgAccent : Theme.text
            }

        }

        Column {
            visible: !osdWindow.isLevelType && !osdWindow.isSegmentType
            anchors.left: iconBadge.right
            anchors.leftMargin: osdWindow.cardGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            LText {
                role: "labelSmall"
                color: Theme.subtext
                text: osdWindow.currentLabel
            }

            // off sits above on, so flipping rolls the column up one line
            Item {
                id: stateFlip

                readonly property int lineHeight: Math.ceil(offMetrics.height)

                width: Math.ceil(Math.max(onMetrics.advanceWidth, offMetrics.advanceWidth))
                height: stateFlip.lineHeight
                clip: true

                TextMetrics {
                    id: onMetrics

                    text: osdWindow.toggleOnText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeSize("titleMedium")
                    font.variableAxes: Theme.axes(Theme.typeSize("titleMedium"), 640, 60)
                }

                TextMetrics {
                    id: offMetrics

                    text: osdWindow.toggleOffText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeSize("titleMedium")
                    font.variableAxes: Theme.axes(Theme.typeSize("titleMedium"), 640, 60)
                }

                Column {
                    width: parent.width
                    y: osdWindow.toggleState ? -stateFlip.lineHeight : 0

                    LText {
                        width: parent.width
                        height: stateFlip.lineHeight
                        role: "titleMedium"
                        weight: 640
                        rounded: 60
                        text: osdWindow.toggleOffText
                        color: osdWindow.toggleOffColor
                    }

                    LText {
                        width: parent.width
                        height: stateFlip.lineHeight
                        role: "titleMedium"
                        weight: 640
                        rounded: 60
                        text: osdWindow.toggleOnText
                        color: Theme.accent
                    }

                    Behavior on y {
                        enabled: card.visible

                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                }

            }

        }

        NumberAnimation {
            id: nudgeAnim

            target: toggleGlyph
            property: "anchors.verticalCenterOffset"
            from: osdWindow.toggleState ? 6 : -6
            to: 0
            duration: Theme.durLong
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }

        SequentialAnimation {
            id: pulseAnim

            NumberAnimation {
                target: iconBadge
                property: "scale"
                to: 1.12
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

            NumberAnimation {
                target: iconBadge
                property: "scale"
                to: 1
                duration: Theme.durShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        SequentialAnimation {
            id: segmentPulseAnim

            NumberAnimation {
                target: segmentReadout
                property: "scale"
                to: 1.12
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

            NumberAnimation {
                target: segmentReadout
                property: "scale"
                to: 1
                duration: Theme.durMedium
                easing.type: Easing.OutBack
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        // the reading answers the keypress
        SequentialAnimation {
            id: levelPulseAnim

            NumberAnimation {
                target: levelTrack.valueItem
                property: "scale"
                to: 1.12
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

            NumberAnimation {
                target: levelTrack.valueItem
                property: "scale"
                to: 1
                duration: Theme.durMedium
                easing.type: Easing.OutBack
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        Behavior on width {
            enabled: card.visible

            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on height {
            enabled: card.visible

            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on opacity {
            NumberAnimation {
                id: cardFade

                duration: Theme.durEnter
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on scale {
            NumberAnimation {
                id: cardPop

                duration: Theme.durEnter
                easing.type: Easing.OutBack
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                id: cardRise

                duration: Theme.durEnter
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

    // the notch's concave corners where its sides meet the bottom edge
    Repeater {
        model: osdWindow.notch ? 2 : 0

        DockFlare {
            required property int index
            readonly property bool isRight: index === 1

            size: osdWindow.notchFlare
            mirrored: isRight
            x: isRight ? card.x + card.width : card.x - width
            y: card.y + card.height - height
            visible: card.visible
            opacity: card.opacity
        }

    }

    mask: Region {
        // only volume and brightness take the pointer; the toggle toasts and
        // the keyboard light stay click-through
        readonly property bool grabs: card.visible && osdWindow.isSettable

        x: grabs ? Math.round(osdBlurRegion.paintedX) : 0
        y: grabs ? Math.round(osdBlurRegion.paintedY) : 0
        width: grabs ? Math.round(osdBlurRegion.paintedWidth) : 0
        height: grabs ? Math.round(osdBlurRegion.paintedHeight) : 0
        radius: Math.round(card.radius * card.scale)
    }

}
