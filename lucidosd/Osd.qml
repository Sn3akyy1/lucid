import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs

// Transient on-screen-display popup for volume, brightness, mic mute,
// caps lock and num lock. Floats above the dock, auto-hides after a beat,
// and never takes keyboard/pointer focus.
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
    // Material Design "volume_mute"/"volume_down"/"volume_up" - sourced
    // from google/material-design-icons, matching the icons used in
    // System.qml's bar pill and control-center slider
    readonly property var volumeIconLevels: [{
        "max": 0,
        "path": "M7 9v6h4l5 5V4l-5 5H7z"
    }, {
        "max": 49,
        "path": "M18.5 12c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM5 9v6h4l5 5V4L9 9H5z"
    }, {
        "max": 100,
        "path": "M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"
    }]
    readonly property var brightnessIconLevels: [{
        "max": 33,
        "path": "M12 6.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11Z"
    }, {
        "max": 66,
        "path": "M12 6.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11ZM12 1a1 1 0 0 1 1 1v1.5a1 1 0 1 1-2 0V2a1 1 0 0 1 1-1Zm0 18.5a1 1 0 0 1 1 1V22a1 1 0 1 1-2 0v-1.5a1 1 0 0 1 1-1ZM1 12a1 1 0 0 1 1-1h1.5a1 1 0 1 1 0 2H2a1 1 0 0 1-1-1Zm18.5 0a1 1 0 0 1 1-1H22a1 1 0 1 1 0 2h-1.5a1 1 0 0 1-1-1Z"
    }, {
        "max": 100,
        "path": "M12 6.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11ZM12 1a1 1 0 0 1 1 1v1.5a1 1 0 1 1-2 0V2a1 1 0 0 1 1-1Zm0 18.5a1 1 0 0 1 1 1V22a1 1 0 1 1-2 0v-1.5a1 1 0 0 1 1-1ZM4.22 4.22a1 1 0 0 1 1.41 0l1.06 1.06a1 1 0 1 1-1.41 1.41L4.22 5.63a1 1 0 0 1 0-1.41Zm12.6 12.6a1 1 0 0 1 1.41 0l1.06 1.06a1 1 0 0 1-1.41 1.41l-1.06-1.06a1 1 0 0 1 0-1.41ZM1 12a1 1 0 0 1 1-1h1.5a1 1 0 1 1 0 2H2a1 1 0 0 1-1-1Zm18.5 0a1 1 0 0 1 1-1H22a1 1 0 1 1 0 2h-1.5a1 1 0 0 1-1-1ZM4.22 19.78a1 1 0 0 1 0-1.41l1.06-1.06a1 1 0 1 1 1.41 1.41l-1.06 1.06a1 1 0 0 1-1.41 0Zm12.6-12.6a1 1 0 0 1 0-1.41l1.06-1.06a1 1 0 1 1 1.41 1.41l-1.06 1.06a1 1 0 0 1-1.41 0Z"
    }]
    readonly property string micIconPath: "M12 14a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3Zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.92V21h2v-3.08A7 7 0 0 0 19 11h-2Z"
    readonly property string capsLockIconPath: "M12 4 6 11 18 11Z M6 15h12v2H6Z"
    readonly property string numLockIconPath: "M7 4h4v4H7Z M13 4h4v4h-4Z M7 10h4v4H7Z M13 10h4v4h-4Z M7 16h4v4H7Z M13 16h4v4h-4Z"
    readonly property bool isLevelType: osdWindow.oscType === "volume" || osdWindow.oscType === "brightness"
    // both only ever apply within innerRow, which is toggle-type-only now
    // that volume/brightness render through levelSlider instead
    readonly property bool badgeActive: osdWindow.toggleState
    readonly property bool showMuteSlash: osdWindow.oscType === "mic" && !osdWindow.toggleState
    readonly property string currentIconPath: {
        switch (osdWindow.oscType) {
        case "volume":
            return osdWindow.levelMuted ? osdWindow.volumeIconLevels[0].path : osdWindow.volumeIconFor(osdWindow.levelValue);
        case "brightness":
            return osdWindow.brightnessIconFor(osdWindow.levelValue);
        case "mic":
            return osdWindow.micIconPath;
        case "capslock":
            return osdWindow.capsLockIconPath;
        case "numlock":
            return osdWindow.numLockIconPath;
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
    readonly property string currentStateText: {
        switch (osdWindow.oscType) {
        case "mic":
            return osdWindow.toggleState ? "Unmuted" : "Muted";
        case "capslock":
        case "numlock":
            return osdWindow.toggleState ? "On" : "Off";
        default:
            return "";
        }
    }

    function volumeIconFor(pct) {
        for (var i = 0; i < osdWindow.volumeIconLevels.length; i++) {
            if (pct <= osdWindow.volumeIconLevels[i].max)
                return osdWindow.volumeIconLevels[i].path;

        }
        return osdWindow.volumeIconLevels[osdWindow.volumeIconLevels.length - 1].path;
    }

    function brightnessIconFor(pct) {
        for (var i = 0; i < osdWindow.brightnessIconLevels.length; i++) {
            if (pct <= osdWindow.brightnessIconLevels[i].max)
                return osdWindow.brightnessIconLevels[i].path;

        }
        return osdWindow.brightnessIconLevels[osdWindow.brightnessIconLevels.length - 1].path;
    }

    function trigger() {
        osdWindow.cardVisible = true;
        hideTimer.restart();
        pulseAnim.restart();
        levelPulseAnim.restart();
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
    // Overlay, not Top - Hyprland hides Top-layer surfaces behind fullscreen
    // clients, and an OSD needs to stay visible over a fullscreen video same
    // as it would on any other desktop
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    implicitWidth: 420
    implicitHeight: 110
    margins.bottom: 110
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
    // real compositor blur, scoped to just the OSD card - see the matching
    // note on bar in shell.qml.
    // card.visible (not osdWindow.cardVisible) so the blur region tracks
    // the card's actual fade-out, not just the moment its hide was
    // requested - Region.item only follows geometry, not opacity/visible,
    // so without this the blur kept reporting the card's last position
    // forever after it faded out, showing as a permanent blurred blob.
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
        onTriggered: osdWindow.cardVisible = false
    }

    Process {
        id: findDeviceProc

        command: ["bash", "-c", "ls /sys/class/backlight | head -1"]

        stdout: StdioCollector {
            onStreamFinished: osdWindow.backlightDevice = this.text.trim().replace(/[@/*=|]$/, "")
        }

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

    Process {
        id: kbStateProc

        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    var kbs = data.keyboards || [];
                    var main = null;
                    for (var i = 0; i < kbs.length; i++) {
                        if (kbs[i].main) {
                            main = kbs[i];
                            break;
                        }
                    }
                    if (!main && kbs.length > 0)
                        main = kbs[0];

                    if (!main)
                        return ;

                    var newCaps = !!main.capsLock;
                    var newNum = !!main.numLock;
                    if (osdWindow.kbInitialized && osdWindow.ready) {
                        if (newCaps !== osdWindow.capsLock) {
                            osdWindow.capsLock = newCaps;
                            osdWindow.showCaps(newCaps);
                        }
                        if (newNum !== osdWindow.numLock) {
                            osdWindow.numLock = newNum;
                            osdWindow.showNum(newNum);
                        }
                    } else {
                        osdWindow.capsLock = newCaps;
                        osdWindow.numLock = newNum;
                    }
                    osdWindow.kbInitialized = true;
                } catch (e) {
                    console.warn("hyprctl devices parse failed:", e);
                }
            }
        }

    }

    Timer {
        interval: 400
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: kbStateProc.running = true
    }

    Region {
        id: osdBlurRegion

        item: card
        radius: card.radius
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        height: 64
        width: osdWindow.isLevelType ? (levelSlider.width + 30) : (innerRow.implicitWidth + 30)
        radius: 32
        color: Theme.bg
        opacity: osdWindow.cardVisible ? 1 : 0
        // no scale-pop here (was 0.9 -> 1) - the real compositor blur
        // region below tracks card's layout bounds, not its rendered
        // (scaled) bounds, so animating scale made the blur snap to full
        // size immediately while the pill was still visually scaling up,
        // showing as a briefly oversized/mismatched blur on every show.
        visible: opacity > 0.01

        Row {
            id: innerRow

            visible: !osdWindow.isLevelType
            anchors.centerIn: parent
            spacing: 14

            Rectangle {
                id: iconBadge

                width: 40
                height: 40
                radius: 20
                anchors.verticalCenter: parent.verticalCenter
                // bgHigh instead of bgTile - bgTile sits right next to the
                // card's own Theme.bg on the tonal ladder, so the inactive
                // badge all but disappeared against the card
                color: osdWindow.badgeActive ? Theme.accent : Theme.withBlur(Theme.bgHigh)

                Item {
                    id: iconWrap

                    anchors.centerIn: parent
                    width: 20
                    height: 20

                    Shape {
                        width: 24
                        height: 24
                        scale: 20 / 24
                        anchors.centerIn: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: osdWindow.badgeActive ? Theme.onAccent : Theme.text
                            strokeWidth: 0

                            PathSvg {
                                path: osdWindow.currentIconPath
                            }

                        }

                    }

                    Rectangle {
                        visible: osdWindow.showMuteSlash
                        anchors.centerIn: parent
                        width: parent.width * 1.3
                        height: 1.6
                        radius: 1
                        rotation: 45
                        color: Theme.error
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(200)
                    }

                }

            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    text: osdWindow.currentLabel
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)
                }

                Text {
                    text: osdWindow.currentStateText
                    color: osdWindow.toggleState ? Theme.accent : Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(11)
                }

            }

        }

        // pill-style slider for volume/brightness - a growing accent fill
        // carries the percentage and morphing icon at its own edge, matching
        // the shape of System.qml's control-center SliderRow rather than the
        // badge layout used by the toggle OSD types
        Item {
            id: levelSlider

            visible: osdWindow.isLevelType
            width: 220
            height: 40
            anchors.centerIn: parent

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 2
                radius: 1
                color: Theme.withBlur(Theme.outline)
            }

            Rectangle {
                id: levelFill

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: height / 2
                // same bgHigh swap as iconBadge - bgTile was nearly
                // indistinguishable from the card's own background, making
                // the muted fill look like it wasn't rendering at all
                color: osdWindow.levelMuted ? Theme.withBlur(Theme.bgHigh) : Theme.accent
                clip: true
                // collapses to the bare circular minimum instead of
                // tracking the pre-mute level - muting reads as "volume is
                // now zero", not "volume is still wherever it was, just
                // grayed out"
                width: osdWindow.levelMuted ? height : Math.max(height, parent.width * (osdWindow.levelValue / 100))

                Text {
                    id: levelPercentLabel

                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: osdWindow.levelMuted ? "" : Math.round(osdWindow.levelValue) + "%"
                    color: osdWindow.levelMuted ? Theme.text : Theme.onAccent
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(14)
                    opacity: (levelFill.width - 12 - width - levelIconWrap.width - 8) > 0 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(120)
                        }

                    }

                }

                Item {
                    id: levelIconWrap

                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10

                    Shape {
                        width: 24
                        height: 24
                        scale: 20 / 24
                        anchors.centerIn: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: osdWindow.levelMuted ? Theme.text : Theme.onAccent
                            strokeWidth: 0

                            PathSvg {
                                path: osdWindow.currentIconPath
                            }

                        }

                    }

                    Rectangle {
                        visible: osdWindow.levelMuted
                        anchors.centerIn: parent
                        width: parent.width * 1.3
                        height: 1.6
                        radius: 1
                        rotation: 45
                        color: Theme.error
                    }

                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.ms(200)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(200)
                    }

                }

            }

        }

        SequentialAnimation {
            id: pulseAnim

            NumberAnimation {
                target: iconBadge
                property: "scale"
                to: 1.12
                duration: Theme.ms(90)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: iconBadge
                property: "scale"
                to: 1
                duration: Theme.ms(180)
                easing.type: Easing.OutCubic
            }

        }

        SequentialAnimation {
            id: levelPulseAnim

            NumberAnimation {
                target: levelIconWrap
                property: "scale"
                to: 1.18
                duration: Theme.ms(90)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: levelIconWrap
                property: "scale"
                to: 1
                duration: Theme.ms(180)
                easing.type: Easing.OutCubic
            }

        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.ms(220)
                easing.type: Easing.OutCubic
            }

        }

        // Directional on purpose. A blur region is a hard on/off - it cannot
        // fade with the surface - and it is dropped when card.visible goes
        // false at opacity 0.01. Decelerating out (OutCubic) crawls through
        // the last few percent of opacity, so the card was already invisible
        // for ~34ms while the blur was still at full strength: the ghost of
        // frosted glass left hanging after the OSD had gone. Accelerating out
        // holds the card visible and then drops it, so the card and its blur
        // end together. Theme's own note says as much - decelerate for
        // something entering, accelerate for something leaving.
        Behavior on opacity {
            NumberAnimation {
                duration: osdWindow.cardVisible ? Theme.ms(200) : Theme.ms(160)
                easing.type: osdWindow.cardVisible ? Easing.OutCubic : Easing.InCubic
            }

        }

    }

    mask: Region {
        item: card
    }

}
