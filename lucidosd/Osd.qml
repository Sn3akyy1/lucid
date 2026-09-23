import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs

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

    // m3 shape, spacing and slider metrics, shared with lucidbar/System.qml
    readonly property int cardPadX: 16
    readonly property int badgeSize: 44
    readonly property int cardGap: 14
    readonly property int trackWidth: 200
    readonly property int readoutWidth: 50
    readonly property int glyphSize: 22

    // level 0 is the slash-free glyph: the badge draws its own slash
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
        "path": "M20 15.31L23.31 12 20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69zM12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6 6 2.69 6 6-2.69 6-6 6z"
    }, {
        "max": 66,
        "path": "M20 15.31L23.31 12 20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69zM12 18V6c3.31 0 6 2.69 6 6s-2.69 6-6 6z"
    }, {
        "max": 100,
        "path": "M20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69L23.31 12 20 8.69zM12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6 6 2.69 6 6-2.69 6-6 6zm0-10c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4z"
    }]
    readonly property string micIconPath: "M12 14c1.66 0 2.99-1.34 2.99-3L15 5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7z"
    readonly property string capsLockIconPath: "M12 8.41 16.59 13 18 11.59l-6-6-6 6L7.41 13 12 8.41ZM6 18h12v-2H6Z"
    readonly property string numLockIconPath: "M4.9 6.6a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0M10.3 6.6a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0M15.7 6.6a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0M4.9 12a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0M10.3 12a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0M15.7 12a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0M4.9 17.4a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0M10.3 17.4a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0M15.7 17.4a1.7 1.7 0 1 0 3.4 0a1.7 1.7 0 1 0 -3.4 0"
    readonly property bool isLevelType: osdWindow.oscType === "volume" || osdWindow.oscType === "brightness"
    readonly property bool badgeActive: osdWindow.toggleState
    readonly property bool showMuteSlash: (osdWindow.oscType === "mic" && !osdWindow.toggleState) || (osdWindow.oscType === "volume" && osdWindow.levelMuted)
    readonly property string toggleIconPath: {
        switch (osdWindow.oscType) {
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
        if (osdWindow.isLevelType)
            levelPulseAnim.restart();
        else if (osdWindow.oscType === "mic")
            pulseAnim.restart();
        else
            nudgeAnim.restart();
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
        onTriggered: osdWindow.setCardVisible(false)
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

        readonly property int levelWidth: osdWindow.cardPadX * 2 + osdWindow.badgeSize + osdWindow.cardGap * 2 + osdWindow.trackWidth + osdWindow.readoutWidth
        readonly property int toggleWidth: osdWindow.cardPadX * 2 + osdWindow.badgeSize + osdWindow.cardGap + Math.ceil(Math.max(labelMetrics.advanceWidth, stateFlip.width))

        anchors.centerIn: parent
        anchors.verticalCenterOffset: osdWindow.cardVisible ? 0 : 16
        height: 76
        width: osdWindow.isLevelType ? card.levelWidth : card.toggleWidth
        radius: Theme.shapeXlInc
        color: Theme.bg
        opacity: osdWindow.cardVisible ? 1 : 0
        scale: osdWindow.cardVisible ? 1 : 0.9
        visible: opacity > 0.15

        TextMetrics {
            id: labelMetrics

            text: osdWindow.currentLabel.toUpperCase()
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fontLabelSm
            font.letterSpacing: 1.2
        }

        Rectangle {
            id: iconBadge

            anchors.left: parent.left
            anchors.leftMargin: osdWindow.cardPadX
            anchors.verticalCenter: parent.verticalCenter
            width: osdWindow.badgeSize
            height: osdWindow.badgeSize
            radius: Theme.pill(width)
            color: osdWindow.badgeActive ? Theme.accent : Theme.withBlur(Theme.bgHigh)

            MorphIcon {
                anchors.centerIn: parent
                visible: osdWindow.isLevelType
                levels: osdWindow.oscType === "brightness" ? osdWindow.brightnessIconLevels : osdWindow.volumeIconLevels
                value: osdWindow.levelMuted ? 0 : osdWindow.levelValue
                tint: osdWindow.badgeActive ? "black" : (osdWindow.levelMuted ? Theme.error : Theme.text)
                iconSize: osdWindow.glyphSize
            }

            SvgIcon {
                id: toggleGlyph

                anchors.centerIn: parent
                visible: !osdWindow.isLevelType
                path: osdWindow.toggleIconPath
                tint: osdWindow.badgeActive ? "black" : Theme.text
                iconSize: osdWindow.glyphSize
            }

            // a cut in the badge colour, so the slash reads as a gap
            // through the glyph rather than a line laid over it
            Rectangle {
                visible: osdWindow.showMuteSlash
                anchors.centerIn: parent
                width: osdWindow.glyphSize * 1.3 + 4
                height: 5
                rotation: 45
                color: iconBadge.color
            }

            Rectangle {
                visible: osdWindow.showMuteSlash
                anchors.centerIn: parent
                width: osdWindow.glyphSize * 1.3
                height: 1.6
                radius: 1
                rotation: 45
                color: Theme.error
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

        // overline + slider, the m3 list-item anatomy System.qml's SliderRow uses
        Column {
            visible: osdWindow.isLevelType
            anchors.left: iconBadge.right
            anchors.leftMargin: osdWindow.cardGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Text {
                text: osdWindow.currentLabel.toUpperCase()
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fontLabelSm
                font.letterSpacing: 1.2
            }

            LevelTrack {
                id: levelTrack

                width: osdWindow.trackWidth
                value: osdWindow.levelValue
                muted: osdWindow.levelMuted
                animated: card.visible
            }

        }

        Item {
            id: readout

            visible: osdWindow.isLevelType
            width: osdWindow.readoutWidth
            height: 28
            anchors.right: parent.right
            anchors.rightMargin: osdWindow.cardPadX
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: pctSign

                anchors.right: parent.right
                anchors.baseline: pctNum.baseline
                text: "%"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fontLabelSm
            }

            Text {
                id: pctNum

                anchors.right: pctSign.left
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(levelTrack.value)
                color: osdWindow.levelMuted ? Theme.subtextDim : Theme.text
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fontTitleLg
            }

        }

        Column {
            visible: !osdWindow.isLevelType
            anchors.left: iconBadge.right
            anchors.leftMargin: osdWindow.cardGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                text: osdWindow.currentLabel.toUpperCase()
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fontLabelSm
                font.letterSpacing: 1.2
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
                    font.bold: true
                    font.pixelSize: Theme.fontTitleSm
                }

                TextMetrics {
                    id: offMetrics

                    text: osdWindow.toggleOffText
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fontTitleSm
                }

                Column {
                    width: parent.width
                    y: osdWindow.toggleState ? -stateFlip.lineHeight : 0

                    Text {
                        width: parent.width
                        height: stateFlip.lineHeight
                        text: osdWindow.toggleOffText
                        color: osdWindow.toggleOffColor
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontTitleSm
                    }

                    Text {
                        width: parent.width
                        height: stateFlip.lineHeight
                        text: osdWindow.toggleOnText
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontTitleSm
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
            from: osdWindow.toggleState ? 7 : -7
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

        // the handle answers the keypress, the way an m3 slider answers a press
        SequentialAnimation {
            id: levelPulseAnim

            NumberAnimation {
                target: levelTrack
                property: "handleStretch"
                to: 8
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

            NumberAnimation {
                target: levelTrack
                property: "handleStretch"
                to: 0
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
    }

    component SvgIcon: Item {
        id: iconRoot

        property string path: ""
        property color tint: Theme.text
        property int iconSize: 16

        width: iconSize
        height: iconSize

        Shape {
            width: 24
            height: 24
            scale: iconRoot.iconSize / 24
            anchors.centerIn: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: iconRoot.tint
                strokeWidth: 0

                PathSvg {
                    path: iconRoot.path
                }

            }

        }

    }

    // the glyph crossfades between levels instead of snapping
    component MorphIcon: Item {
        id: morphIcon

        property var levels: []
        property real value: 0
        property color tint: Theme.text
        property int iconSize: 16
        readonly property int activeIndex: {
            for (let i = 0; i < morphIcon.levels.length; i++) {
                if (morphIcon.value <= morphIcon.levels[i].max)
                    return i;

            }
            return morphIcon.levels.length - 1;
        }

        width: iconSize
        height: iconSize

        Repeater {
            model: morphIcon.levels

            Shape {
                id: levelShape

                required property int index
                required property var modelData

                width: 24
                height: 24
                scale: morphIcon.iconSize / 24
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: morphIcon.activeIndex === levelShape.index ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

                ShapePath {
                    fillColor: morphIcon.tint
                    strokeWidth: 0

                    PathSvg {
                        path: levelShape.modelData.path
                    }

                }

            }

        }

    }

    // m3 slider anatomy: 16dp tracks notched 6dp either side of a 4dp handle,
    // squared off where they meet it, stop indicator on the inactive end
    component LevelTrack: Item {
        id: lt

        property real value: 0
        property bool muted: false
        property bool animated: false
        property real handleStretch: 0
        readonly property int handleW: 4
        readonly property int trackH: 16
        readonly property int notch: 6
        readonly property real pos: Math.max(0, Math.min(1, lt.value / 100))
        readonly property real handleX: lt.pos * Math.max(0, lt.width - lt.handleW)
        readonly property color liveColor: lt.muted ? Theme.outlineStrong : Theme.accent

        height: 28

        Behavior on value {
            enabled: lt.animated

            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Rectangle {
            id: activeTrack

            x: 0
            anchors.verticalCenter: parent.verticalCenter
            // below a couple of px the rounded stub reads as an artifact
            visible: activeTrack.width > 2
            width: Math.max(0, lt.handleX - lt.notch)
            height: lt.trackH
            radius: Theme.pill(lt.trackH)
            topRightRadius: 2
            bottomRightRadius: 2
            color: lt.liveColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Rectangle {
            id: inactiveTrack

            x: Math.min(lt.width, lt.handleX + lt.handleW + lt.notch)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, lt.width - inactiveTrack.x)
            height: lt.trackH
            radius: Theme.pill(lt.trackH)
            topLeftRadius: 2
            bottomLeftRadius: 2
            color: Theme.withBlur(Theme.bgHigh)

            Rectangle {
                visible: inactiveTrack.width > 16
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 4
                radius: 2
                color: Theme.outlineStrong
            }

        }

        Rectangle {
            x: lt.handleX
            anchors.verticalCenter: parent.verticalCenter
            width: lt.handleW
            height: lt.trackH + 12 + lt.handleStretch
            radius: lt.handleW / 2
            color: lt.liveColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

}
