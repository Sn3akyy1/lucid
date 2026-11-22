import QtQuick

// one key of OnScreenKeys, drawn as the shell's own keyboard draws its keys
// (lucidkeys/KeyCap.qml). entry fields: l label, s shifted label, g glyph,
// r role, w width units
Item {
    id: cap

    property var theme: null
    property var entry: null
    property real unit: 46
    property real gap: 5
    property bool shifted: false
    // 0 off, 1 one-shot, 2 locked
    property int modState: 0

    readonly property bool pressedDown: tap.pressed
    readonly property string role: cap.entry && cap.entry.r ? cap.entry.r : "key"
    readonly property real units: cap.entry && cap.entry.w ? cap.entry.w : 1
    readonly property bool lit: cap.role === "go" || cap.modState > 0
    readonly property string label: {
        if (!cap.entry)
            return "";

        if (cap.shifted && cap.entry.s !== undefined)
            return cap.entry.s;

        return cap.entry.l !== undefined ? cap.entry.l : "";
    }
    readonly property bool wordy: cap.label.length > 1
    readonly property color capFace: {
        if (!cap.theme)
            return "transparent";

        if (cap.lit)
            return cap.theme.accent;

        return cap.role === "key" ? cap.theme.cardMid : cap.theme.card;
    }
    readonly property color capInk: {
        if (!cap.theme)
            return "white";

        if (cap.lit)
            return cap.theme.fgAccent;

        return cap.role === "key" ? cap.theme.text : cap.theme.subtext;
    }
    readonly property real restRadius: Math.max(cap.theme ? cap.theme.shapeSm : 8, Math.round(cap.unit * 0.26))
    // the layout tables' glyph names, as material symbols
    readonly property var glyphs: ({
        "backspace": "backspace",
        "enter": "keyboard_return",
        "tab": "keyboard_tab",
        "shift": "shift",
        "caps": "keyboard_capslock",
        "left": "chevron_left",
        "right": "chevron_right",
        "up": "keyboard_arrow_up",
        "down": "keyboard_arrow_down",
        "prev": "skip_previous",
        "play": "play_pause",
        "next": "skip_next",
        "mute": "volume_off",
        "voldown": "volume_down",
        "volup": "volume_up",
        "dim": "brightness_low",
        "bright": "brightness_high"
    })

    signal fired()

    function ms(d) {
        return cap.theme ? cap.theme.ms(d) : d;
    }

    implicitWidth: cap.unit * cap.units + cap.gap * (cap.units - 1)
    implicitHeight: cap.unit

    Rectangle {
        id: plate

        anchors.fill: parent
        color: cap.capFace
        radius: cap.pressedDown ? Math.round(cap.unit * 0.44) : cap.restRadius
        scale: cap.pressedDown ? 0.94 : 1

        Behavior on color {
            ColorAnimation {
                duration: cap.ms(120)
                easing.type: Easing.OutCubic
            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: cap.ms(120)
                easing.type: Easing.OutCubic
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: cap.ms(120)
                easing.type: Easing.OutCubic
            }

        }

        // m3 state layer, over the face and under the legend
        Rectangle {
            anchors.fill: parent
            radius: plate.radius
            color: cap.theme ? cap.theme.alpha(cap.capInk, cap.pressedDown ? cap.theme.statePressed : (hover.hovered ? cap.theme.stateHover : 0)) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: cap.ms(120)
                    easing.type: Easing.OutCubic
                }

            }

        }

        Glyph {
            anchors.centerIn: parent
            visible: cap.entry && cap.entry.g !== undefined
            name: cap.entry && cap.entry.g !== undefined ? (cap.glyphs[cap.entry.g] || "") : ""
            size: Math.round(cap.unit * 0.46)
            color: cap.capInk
        }

        Text {
            anchors.centerIn: parent
            visible: !(cap.entry && cap.entry.g !== undefined)
            text: cap.label
            color: cap.capInk
            font.family: cap.theme ? cap.theme.fontFamily : ""
            font.pixelSize: Math.round(cap.unit * (cap.wordy ? 0.25 : 0.38))
            font.variableAxes: cap.theme ? cap.theme.axes(Math.round(cap.unit * (cap.wordy ? 0.25 : 0.38)), 420, 0) : ({})
            font.weight: cap.wordy ? Font.Medium : Font.Normal
        }

        // a locked modifier keeps the fill and adds the bar; one-shot is fill alone
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(cap.unit * 0.12)
            width: Math.round(cap.unit * 0.3)
            height: cap.theme ? cap.theme.dp(2) : 2
            radius: 1
            color: cap.capInk
            opacity: cap.modState === 2 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: cap.ms(120)
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    HoverHandler {
        id: hover
    }

    // a handler per key, so two fingers on two keys are two presses
    TapHandler {
        id: tap

        gesturePolicy: TapHandler.WithinBounds
        onPressedChanged: {
            if (tap.pressed) {
                cap.fired();
                repeatDelay.restart();
            } else {
                repeatDelay.stop();
                repeatRun.stop();
            }
        }
    }

    // hold to repeat, at the usual xkb rate. modifiers opt out
    Timer {
        id: repeatDelay

        interval: 420
        onTriggered: {
            if (cap.role === "mod")
                return ;

            repeatRun.start();
        }
    }

    Timer {
        id: repeatRun

        interval: 40
        repeat: true
        onTriggered: cap.fired()
    }

}
