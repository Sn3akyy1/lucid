import QtQuick
import qs

// one key. entry fields: l label, s shifted label, g glyph, r role, w width units
Item {
    id: cap

    property var entry: null
    property real unit: 46
    property real gap: 5
    property bool shifted: false
    // 0 off, 1 one-shot, 2 locked
    property int modState: 0
    property bool pressedDown: false

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
        if (cap.lit)
            return Theme.accent;

        return cap.role === "key" ? Theme.withBlur(Theme.surfaceHigh) : Theme.withBlur(Theme.surfaceContainer);
    }
    readonly property color capInk: {
        if (cap.lit)
            return Theme.fgAccent;

        return cap.role === "key" ? Theme.text : Theme.subtext;
    }
    readonly property real restRadius: Math.max(Theme.shapeSm, Theme.rad(cap.unit * 0.26))

    signal fired()

    implicitWidth: cap.unit * cap.units + cap.gap * (cap.units - 1)
    implicitHeight: cap.unit

    Rectangle {
        id: plate

        anchors.fill: parent
        color: cap.capFace
        radius: cap.pressedDown ? Theme.rad(cap.unit * 0.44) : cap.restRadius
        scale: cap.pressedDown ? 0.94 : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
                easing.type: Theme.easeStandard
            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Theme.easeStandard
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Theme.easeStandard
            }

        }

        // m3 state layer, over the face and under the legend
        Rectangle {
            anchors.fill: parent
            radius: plate.radius
            color: Theme.alpha(cap.capInk, cap.pressedDown ? Theme.statePressed : (hover.hovered ? Theme.stateHover : 0))

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                    easing.type: Theme.easeStandard
                }

            }

        }

        KeyGlyph {
            anchors.centerIn: parent
            visible: cap.entry && cap.entry.g !== undefined
            name: cap.entry && cap.entry.g !== undefined ? cap.entry.g : ""
            glyphColor: cap.capInk
            width: Math.round(cap.unit * 0.46)
            height: width
        }

        Text {
            anchors.centerIn: parent
            visible: !(cap.entry && cap.entry.g !== undefined)
            text: cap.label
            color: cap.capInk
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(cap.unit * (cap.wordy ? 0.25 : 0.38))
            font.weight: cap.wordy ? Font.Medium : Font.Normal
        }

        // a locked modifier keeps the fill and adds the bar; one-shot is fill alone
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(cap.unit * 0.12)
            width: Math.round(cap.unit * 0.3)
            height: 2
            radius: 1
            color: cap.capInk
            opacity: cap.modState === 2 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                    easing.type: Theme.easeStandard
                }

            }

        }

    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        onPressed: {
            cap.pressedDown = true;
            cap.fired();
            repeatDelay.restart();
        }
        onReleased: {
            cap.pressedDown = false;
            repeatDelay.stop();
            repeatRun.stop();
        }
        onCanceled: {
            cap.pressedDown = false;
            repeatDelay.stop();
            repeatRun.stop();
        }
    }

    // hold to repeat, at the usual xkb rate. modifiers and layer keys opt out
    Timer {
        id: repeatDelay

        interval: 420
        onTriggered: {
            if (cap.role === "mod" || cap.role === "layer")
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
