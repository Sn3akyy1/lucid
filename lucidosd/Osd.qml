import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
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
    // a light that is only on or off is a switch, and reads like the lock keys
    readonly property bool kbdSwitch: osdWindow.kbdMax === 1
    // a handful of steps reads better as blocks than as a bar; a keyboard with
    // a fine-grained level keeps the level track
    readonly property bool kbdSegmented: osdWindow.kbdMax > 1 && osdWindow.kbdMax <= 6
    // notch style: the card sits flush on the bottom edge and rises out of it,
    // with the dock's concave corners at its sides. a dock on that edge steps
    // down while it shows; one held up by a menu, a drag, the pointer or edit
    // mode keeps the edge, and the card floats above it instead. on a bottom bar
    // only the full bar's strip runs under it all; over islands or notches it
    // would stand on nothing past a module's ends, so it floats as a card
    readonly property bool notch: Prefs.osdNotch && !osdWindow.dockStays && !(osdWindow.barBelow && !Prefs.barFull)
    // a fullscreen window covers the bar's layer but not this one, so the osd
    // keeps to the screen edge then, as if there were no bar
    readonly property bool barBelow: {
        const m = Hyprland.monitorFor(osdWindow.screen);
        return Prefs.barHoldsBottom && !(m && m.activeWorkspace && m.activeWorkspace.hasFullscreen);
    }
    // what the dock reads to step aside. held until the card has faded, or the
    // dock comes back up under a card still easing out
    readonly property bool holdsEdge: osdWindow.notch && (osdWindow.cardShown || card.visible)
    // shell.qml hands the dock over
    property var dockWindow: null
    // taken as the card comes up: switching styles while it is shown would
    // make it jump
    property bool dockStays: false
    // with the dock a notch too, the dock itself turns into the card and this
    // window shows nothing. taken as it comes up, like dockStays
    property bool dockHosts: false
    readonly property bool cardShown: osdWindow.cardVisible && !osdWindow.dockHosts
    readonly property int notchFlare: osdWindow.notch ? Theme.dp(Prefs.dockNotchFlare) : 0
    // the card's size for what it shows, which the dock morphs to as well
    readonly property int targetWidth: (osdWindow.isLevelType || osdWindow.isSegmentType) ? Theme.dp(260) : cardFace.toggleWidth
    readonly property int targetHeight: (osdWindow.isLevelType || osdWindow.isSegmentType) ? Theme.dp(50) : Theme.dp(56)
    // the face showing it: the card's own, or the dock's while it stands in
    readonly property var face: osdWindow.dockHosts && osdWindow.dockWindow && osdWindow.dockWindow.osdFace ? osdWindow.dockWindow.osdFace : cardFace

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
    readonly property bool isLevelType: osdWindow.oscType === "volume" || osdWindow.oscType === "brightness" || (osdWindow.oscType === "kbdbacklight" && !osdWindow.kbdSegmented && !osdWindow.kbdSwitch)
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
        case "kbdbacklight":
            return "keyboard";
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
        case "kbdbacklight":
            return "On";
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
        case "kbdbacklight":
            return "Off";
        default:
            return "";
        }
    }
    readonly property color toggleOffColor: osdWindow.oscType === "mic" ? Theme.error : Theme.subtextDim

    // the params have to be set before the flag flips: a Behavior reads the
    // previous value of anything its animation binds to
    function setCardVisible(v) {
        if (v && !osdWindow.cardVisible) {
            const dock = osdWindow.dockWindow;
            const here = !!dock && dock.screen === osdWindow.screen;
            osdWindow.dockHosts = here && Prefs.osdNotch && Prefs.osdDockMorph && dock.canHostOsd;
            osdWindow.dockStays = here && !osdWindow.dockHosts && (dock.dockBusy || dock.heldByPointer || Edit.active);
        }
        // the dock sets up its morph before the card's state changes under it
        if (osdWindow.dockHosts && osdWindow.dockWindow)
            osdWindow.dockWindow.stageOsd(v);

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

    // with no display picked for the shell the card has no home of its own, so
    // it comes up on the one being worked on. it only moves while it is down:
    // moving a shown card would cut its animation off. shell.qml applies it
    property var aimedScreen: null
    // dropped once a display is picked, or once that one is unplugged: a
    // surface sent to a dead display is never drawn
    readonly property var placement: Prefs.monitorShellScreen === "" && osdWindow.aimedScreen && Quickshell.screens.indexOf(osdWindow.aimedScreen) >= 0 ? osdWindow.aimedScreen : null

    function trigger() {
        const fresh = !osdWindow.cardVisible;
        if (!osdWindow.cardVisible && Prefs.monitorShellScreen === "")
            osdWindow.aimedScreen = Monitors.focusedScreen;

        osdWindow.setCardVisible(true);
        // a fresh card lands with a wobble, and every step after jiggles it.
        // the dock lands its own morph
        if (osdWindow.dockHosts) {
            if (!fresh)
                osdWindow.dockWindow.jiggle(0.05);

        } else if (fresh) {
            cardJelly.kickAfter(0.14, Math.round(Theme.durEnter * 0.3));
        } else {
            cardJelly.kick(0.05);
        }
        hideTimer.restart();
        osdWindow.face.pulse();
    }

    // a hand on the level track keeps the card up
    function keepUp() {
        hideTimer.restart();
    }

    function held() {
        return cardFace.dragging || cardFace.hovered || (!!osdWindow.dockWindow && osdWindow.dockWindow.osdFaceHeld);
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
        osdWindow.toggleState = osdWindow.kbdLevel > 0;
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
    // the notch belongs on the edge itself, under the dock's reserved strip;
    // the floating card keeps clear of it
    exclusionMode: osdWindow.notch ? ExclusionMode.Ignore : ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // remapped with the rest of the shell when displays change
    visible: Monitors.surfacesUp
    // a notch's surface keeps even sides: centring rounds an odd parent's middle,
    // which would leave the card's edges half a pixel off
    implicitWidth: osdWindow.notch ? 2 * Math.ceil(Theme.dp(480) / 2) : Theme.dp(480)
    implicitHeight: osdWindow.notch ? 2 * Math.ceil(Theme.dp(64) / 2) : Theme.dp(140)
    // a notch stands on a bottom bar, ignoring its reserved strip; a card keeps
    // clear of it, so only the gap is added, less the room around the card
    margins.bottom: osdWindow.notch ? (osdWindow.barBelow ? Prefs.effectiveBarTopMargin + Theme.dp(Prefs.barHeight) : 0) : (osdWindow.barBelow ? Theme.dp(Prefs.barPopupGap) - Math.round((osdWindow.implicitHeight - card.height) / 2) : Theme.dp(96))
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
    // shrunk rather than dropped: hyprland keeps a dropped region on screen
    BackgroundEffect.blurRegion: Theme.blurAmount > 0 ? osdBlurRegion : null

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
            if (osdWindow.held()) {
                hideTimer.restart();
                return ;
            }
            osdWindow.setCardVisible(false);
        }
    }

    // the launcher or a drag takes the edge back from a notch, or the dock back
    // from the card it turned into
    Connections {
        function onDockBusyChanged() {
            if (osdWindow.dockWindow.dockBusy && (osdWindow.holdsEdge || (osdWindow.dockHosts && osdWindow.cardVisible)) && osdWindow.dockWindow.screen === osdWindow.screen)
                osdWindow.setCardVisible(false);

        }

        target: osdWindow.dockWindow
        ignoreUnknownSignals: true
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
        // the state is followed either way, so switching a card back on never
        // shows a change from while it was off
        if (osdWindow.kbInitialized && osdWindow.ready) {
            if (caps !== osdWindow.capsLock) {
                osdWindow.capsLock = caps;
                if (Prefs.osdCapsLock)
                    osdWindow.showCaps(caps);

                Sounds.feedback(caps ? "caps-on" : "caps-off", Prefs.soundOnCaps);
            }
            if (num !== osdWindow.numLock) {
                osdWindow.numLock = num;
                if (Prefs.osdNumLock)
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

    // the card and the notch's edge blends. clipped to the surface: hyprland
    // frosts the whole layer for a region wholly outside it, and the notch
    // sinks past the edge to hide
    Region {
        id: osdBlurRegion

        // the card as painted: its pop works about its centre, inside the jelly,
        // which a notch holds at its bottom edge
        readonly property real paintedX: card.x + cardJelly.shiftX + cardJelly.xScale * card.width * (1 - card.scale) / 2
        readonly property real paintedY: card.y + cardJelly.shiftY + cardJelly.yScale * card.height * (1 - card.scale) / 2
        readonly property real paintedWidth: card.width * card.scale * cardJelly.xScale
        readonly property real paintedHeight: card.height * card.scale * cardJelly.yScale
        readonly property int blendSize: card.visible ? osdWindow.notchFlare : 0
        // up the side no further than it runs straight: past where the top corner
        // starts to round, the curve's tip would stand off it in a step, so a short
        // card takes its blends as quarter ellipses
        readonly property int blendDepth: Math.max(0, Math.min(osdBlurRegion.blendSize, Math.floor(osdBlurRegion.paintedHeight - card.radius * card.scale)))
        readonly property real blendY: osdBlurRegion.paintedY + osdBlurRegion.paintedHeight - osdBlurRegion.blendDepth

        // the card pulled in a pixel along its curved corners only: kept to the
        // painted curve, the hard-edged region frosts its antialiasing, a ragged
        // rim. two bands put the flat edges back at full extent
        readonly property int cardRadius: Math.round(card.radius * card.scale)
        readonly property int bottomIn: osdWindow.notch ? 0 : osdBlurRegion.cardRadius

        function lo(v) {
            return Math.ceil(v - 0.002);
        }

        function hi(v) {
            return Math.floor(v + 0.002);
        }

        intersection: Intersection.Intersect

        Region {
            x: osdBlurRegion.lo(osdBlurRegion.paintedX + 1)
            y: osdBlurRegion.lo(osdBlurRegion.paintedY + 1)
            width: card.visible ? Math.max(0, osdBlurRegion.hi(osdBlurRegion.paintedX + osdBlurRegion.paintedWidth - 1) - osdBlurRegion.lo(osdBlurRegion.paintedX + 1)) : 0
            height: card.visible ? Math.max(0, osdBlurRegion.hi(osdBlurRegion.paintedY + osdBlurRegion.paintedHeight - 1) - osdBlurRegion.lo(osdBlurRegion.paintedY + 1)) : 0
            radius: Math.max(0, osdBlurRegion.cardRadius - 1)
            bottomLeftRadius: Math.max(0, osdBlurRegion.bottomIn - 1)
            bottomRightRadius: Math.max(0, osdBlurRegion.bottomIn - 1)
        }

        Region {
            x: osdBlurRegion.lo(osdBlurRegion.paintedX + osdBlurRegion.cardRadius)
            y: osdBlurRegion.lo(osdBlurRegion.paintedY)
            width: card.visible ? Math.max(0, osdBlurRegion.hi(osdBlurRegion.paintedX + osdBlurRegion.paintedWidth - osdBlurRegion.cardRadius) - osdBlurRegion.lo(osdBlurRegion.paintedX + osdBlurRegion.cardRadius)) : 0
            height: card.visible ? Math.max(0, osdBlurRegion.hi(osdBlurRegion.paintedY + osdBlurRegion.paintedHeight) - osdBlurRegion.lo(osdBlurRegion.paintedY)) : 0
        }

        Region {
            x: osdBlurRegion.lo(osdBlurRegion.paintedX)
            y: osdBlurRegion.lo(osdBlurRegion.paintedY + osdBlurRegion.cardRadius)
            width: card.visible ? Math.max(0, osdBlurRegion.hi(osdBlurRegion.paintedX + osdBlurRegion.paintedWidth) - osdBlurRegion.lo(osdBlurRegion.paintedX)) : 0
            height: card.visible ? Math.max(0, osdBlurRegion.hi(osdBlurRegion.paintedY + osdBlurRegion.paintedHeight - osdBlurRegion.bottomIn) - osdBlurRegion.lo(osdBlurRegion.paintedY + osdBlurRegion.cardRadius)) : 0
        }

        // an edge blend: its box less the ellipse its curve is drawn from, a
        // pixel wider so the hard edge stays inside the curve's antialiasing
        Region {
            x: Math.round(osdBlurRegion.paintedX) - osdBlurRegion.blendSize
            y: Math.ceil(osdBlurRegion.blendY - 0.002)
            width: osdBlurRegion.blendDepth > 0 ? osdBlurRegion.blendSize : 0
            height: Math.floor(osdBlurRegion.blendY + osdBlurRegion.blendDepth + 0.002) - Math.ceil(osdBlurRegion.blendY - 0.002)

            Region {
                shape: RegionShape.Ellipse
                intersection: Intersection.Subtract
                x: Math.round(osdBlurRegion.paintedX) - 2 * osdBlurRegion.blendSize - 1
                y: Math.round(osdBlurRegion.blendY) - osdBlurRegion.blendDepth - 1
                width: 2 * osdBlurRegion.blendSize + 2
                height: 2 * osdBlurRegion.blendDepth + 2
            }

        }

        Region {
            x: Math.round(osdBlurRegion.paintedX + osdBlurRegion.paintedWidth)
            y: Math.ceil(osdBlurRegion.blendY - 0.002)
            width: osdBlurRegion.blendDepth > 0 ? osdBlurRegion.blendSize : 0
            height: Math.floor(osdBlurRegion.blendY + osdBlurRegion.blendDepth + 0.002) - Math.ceil(osdBlurRegion.blendY - 0.002)

            Region {
                shape: RegionShape.Ellipse
                intersection: Intersection.Subtract
                x: Math.round(osdBlurRegion.paintedX + osdBlurRegion.paintedWidth) - 1
                y: Math.round(osdBlurRegion.blendY) - osdBlurRegion.blendDepth - 1
                width: 2 * osdBlurRegion.blendSize + 2
                height: 2 * osdBlurRegion.blendDepth + 2
            }

        }

    }

    Rectangle {
        id: card


        // how far it has sunk to hide, eased on its own: the rest of the offset
        // keeps a notch's bottom on the edge exactly while its height morphs
        property real sunk: osdWindow.cardShown ? 0 : 1
        // the width it eases through. a notch keeps it even and its left side
        // whole, so both sides land on whole pixels where the flares meet them
        property real easedWidth: osdWindow.targetWidth

        // one vertical anchor whatever the style: swapping anchors would let the
        // anchor engine write the height and drop its binding. the notch sits on
        // the bottom edge through the offset, and sinks past it to hide
        anchors.centerIn: parent
        // centring an odd-height card puts it on a half pixel, which left the
        // notch's top and bottom rows half drawn; its offset is whole already
        anchors.alignWhenCentered: !osdWindow.notch
        anchors.horizontalCenterOffset: osdWindow.notch ? Math.round((parent.width - card.width) / 2) - (parent.width - card.width) / 2 : 0
        anchors.verticalCenterOffset: osdWindow.notch ? (parent.height - card.height) / 2 + card.sunk * card.height : card.sunk * Theme.dp(16)
        height: osdWindow.targetHeight
        width: osdWindow.notch ? 2 * Math.round(card.easedWidth / 2) : card.easedWidth
        // follows Corner rounding like every other pill in the shell
        radius: Theme.pill(height)
        bottomLeftRadius: osdWindow.notch ? 0 : card.radius
        bottomRightRadius: osdWindow.notch ? 0 : card.radius
        color: Theme.bg
        opacity: osdWindow.cardShown ? 1 : 0
        // the notch rises out of the edge rather than popping
        scale: osdWindow.cardShown || osdWindow.notch ? 1 : 0.9
        visible: opacity > 0.15
        readonly property bool jellyWobbling: cardJelly.wobbling
        // a notch is held at the edge it shares with the screen and only bobs,
        // or its sides would pull away from the flares
        transform: Jelly {
            id: cardJelly

            target: card
            frequency: 4.6
            anchorY: osdWindow.notch ? 1 : 0.5
            spread: osdWindow.notch ? 0 : cardJelly.naturalSpread
        }

        OsdFace {
            id: cardFace

            anchors.fill: parent
            osd: osdWindow
            live: card.visible
        }

        Behavior on easedWidth {
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

        Behavior on sunk {
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
            depth: osdBlurRegion.blendDepth
            mirrored: isRight
            x: isRight ? Math.round(osdBlurRegion.paintedX + osdBlurRegion.paintedWidth) : Math.round(osdBlurRegion.paintedX) - width
            y: osdBlurRegion.paintedY + osdBlurRegion.paintedHeight - height
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
        bottomLeftRadius: osdWindow.notch ? 0 : Math.round(card.radius * card.scale)
        bottomRightRadius: osdWindow.notch ? 0 : Math.round(card.radius * card.scale)
    }

}
