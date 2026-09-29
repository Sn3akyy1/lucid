import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs
import qs.lucidui

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

    // m3 shape, spacing and slider metrics, shared with lucidbar/System.qml
    readonly property int cardPadX: 12
    readonly property int badgeSize: 36
    readonly property int cardGap: 10
    readonly property int glyphSize: 18
    // the level card's own, tighter slider metrics
    readonly property int levelTrackH: 30
    readonly property int levelHandleH: 38

    readonly property string levelIcon: {
        if (osdWindow.oscType === "brightness")
            return osdWindow.levelValue < 34 ? "brightness_low" : (osdWindow.levelValue < 67 ? "brightness_medium" : "brightness_high");

        if (osdWindow.levelMuted || osdWindow.levelValue <= 0)
            return "volume_off";

        return osdWindow.levelValue < 34 ? "volume_mute" : (osdWindow.levelValue < 67 ? "volume_down" : "volume_up");
    }
    readonly property bool isLevelType: osdWindow.oscType === "volume" || osdWindow.oscType === "brightness"
    readonly property bool badgeActive: osdWindow.toggleState
    readonly property bool showMuteSlash: (osdWindow.oscType === "mic" && !osdWindow.toggleState) || (osdWindow.oscType === "volume" && osdWindow.levelMuted)
    readonly property string toggleIcon: {
        switch (osdWindow.oscType) {
        case "mic":
            return "mic";
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

    function showMic() {
        osdWindow.oscType = "mic";
        osdWindow.toggleState = !osdWindow.micMuted;
        osdWindow.trigger();
    }

    function showCaps(state) {
        osdWindow.oscType = "capslock";
        osdWindow.toggleState = state;
        osdWindow.trigger();
    }

    function showNum(state) {
        osdWindow.oscType = "numlock";
        osdWindow.toggleState = state;
        osdWindow.trigger();
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // remapped with the rest of the shell when displays change
    visible: Monitors.surfacesUp
    implicitWidth: 480
    implicitHeight: 140
    margins.bottom: 96
    Component.onCompleted: findDeviceProc.running = true
    onBacklightDeviceChanged: {
        if (backlightDevice !== "")
            readMaxProc.running = true;

    }
    onVolumePercentChanged: {
        if (!osdWindow.ready)
            return ;

        osdWindow.showVolume();
    }
    onVolMutedChanged: {
        if (!osdWindow.ready)
            return ;

        osdWindow.showVolume();
    }
    onBrightnessPercentChanged: {
        if (!osdWindow.ready)
            return ;

        osdWindow.showBrightness();
    }
    onMicMutedChanged: {
        if (!osdWindow.ready)
            return ;

        osdWindow.showMic();
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
    }

    Rectangle {
        id: card

        readonly property int levelWidth: 260
        readonly property int toggleWidth: osdWindow.cardPadX * 2 + osdWindow.badgeSize + osdWindow.cardGap + Math.ceil(Math.max(labelMetrics.advanceWidth, stateFlip.width)) + 6

        anchors.centerIn: parent
        anchors.verticalCenterOffset: osdWindow.cardVisible ? 0 : 16
        height: osdWindow.isLevelType ? 50 : 56
        width: osdWindow.isLevelType ? card.levelWidth : card.toggleWidth
        radius: height / 2
        color: Theme.bg
        opacity: osdWindow.cardVisible ? 1 : 0
        scale: osdWindow.cardVisible ? 1 : 0.9
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
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            size: "m"
            trackH: osdWindow.levelTrackH
            handleH: osdWindow.levelHandleH
            // a full stadium cap, as round as the card behind it
            outerR: osdWindow.levelTrackH / 2
            iconSize: 18
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

        Item {
            id: iconBadge

            visible: !osdWindow.isLevelType
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
                size: osdWindow.glyphSize + 2
                fill: osdWindow.badgeActive ? 1 : 0
                color: osdWindow.badgeActive ? Theme.fgAccent : Theme.text
            }

            // a cut in the badge colour, so the slash reads as a gap
            // through the glyph rather than a line laid over it
            Rectangle {
                visible: osdWindow.showMuteSlash
                anchors.centerIn: parent
                width: osdWindow.glyphSize * 1.3 + 4
                height: Math.round(osdWindow.glyphSize * 0.22)
                rotation: 45
                color: iconBadge.fillColor
            }

            Rectangle {
                visible: osdWindow.showMuteSlash
                anchors.centerIn: parent
                width: osdWindow.glyphSize * 1.3
                height: osdWindow.glyphSize * 0.082
                radius: 1
                rotation: 45
                color: Theme.error
            }

        }

        Column {
            visible: !osdWindow.isLevelType
            anchors.left: iconBadge.right
            anchors.leftMargin: osdWindow.cardGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

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

    mask: Region {
        // only the level card takes the pointer; the toggle toasts stay click-through
        readonly property bool grabs: card.visible && osdWindow.isLevelType

        x: grabs ? Math.round(osdBlurRegion.paintedX) : 0
        y: grabs ? Math.round(osdBlurRegion.paintedY) : 0
        width: grabs ? Math.round(osdBlurRegion.paintedWidth) : 0
        height: grabs ? Math.round(osdBlurRegion.paintedHeight) : 0
        radius: Math.round(card.radius * card.scale)
    }

}
