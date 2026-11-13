import QtQuick
import qs
import qs.lucidui

// one adjustment: its name and value over an m3 slider whose fill runs from
// the middle (or wherever `origin` is) to the handle. a double click puts it
// back to the origin
Item {
    id: s

    property string label: ""
    property real from: -100
    property real to: 100
    property real origin: 0
    property real value: 0
    property real stepSize: 1
    property string unit: ""
    property int decimals: 0
    property bool disabled: false
    // what the value reads as, if not the number itself
    property var valueText: null
    property real live: s.value
    readonly property bool dragging: area.pressed
    readonly property real trackH: Theme.dp(12)
    readonly property real handleW: area.pressed ? Theme.dp(3) : Theme.dp(4)
    readonly property real gap: Theme.dp(4)
    readonly property real span: Math.max(1, track.width - s.handleW)
    readonly property real frac: Math.max(0, Math.min(1, (s.live - s.from) / (s.to - s.from)))
    readonly property real ofrac: Math.max(0, Math.min(1, (s.origin - s.from) / (s.to - s.from)))
    readonly property real hx: s.handleW / 2 + s.frac * s.span
    readonly property real ox: s.handleW / 2 + s.ofrac * s.span
    readonly property bool moved: Math.abs(s.live - s.origin) > 0.0001

    signal changing(real value)
    signal changed(real value)

    function snap(v) {
        v = Math.max(s.from, Math.min(s.to, v));
        if (s.stepSize > 0)
            v = Math.round(v / s.stepSize) * s.stepSize;

        return v;
    }

    function at(px) {
        return s.snap(s.from + (px - s.handleW / 2) / s.span * (s.to - s.from));
    }

    onValueChanged: {
        if (!area.pressed)
            s.live = s.value;

    }
    implicitWidth: Theme.dp(260)
    implicitHeight: Theme.dp(56)
    opacity: s.disabled ? Theme.disabledContent : 1

    LText {
        anchors.left: parent.left
        anchors.top: parent.top
        role: "labelLarge"
        text: s.label
        color: Theme.text
    }

    LText {
        anchors.right: parent.right
        anchors.top: parent.top
        role: "labelLarge"
        tabular: true
        text: s.valueText ? s.valueText(s.live) : ((s.live > 0 && s.from < 0 ? "+" : "") + s.live.toFixed(s.decimals) + s.unit)
        color: s.moved ? Theme.accent : Theme.subtext
    }

    Item {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.dp(28)

        // the track left of the handle, and right of it, each stopping short
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: Math.max(0, s.hx - s.handleW / 2 - s.gap)
            height: s.trackH
            color: Theme.secondaryContainer
            topLeftRadius: s.trackH / 2
            bottomLeftRadius: s.trackH / 2
            topRightRadius: Theme.dp(2)
            bottomRightRadius: Theme.dp(2)
            visible: width > 0.5
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: s.hx + s.handleW / 2 + s.gap
            width: Math.max(0, track.width - x)
            height: s.trackH
            color: Theme.secondaryContainer
            topRightRadius: s.trackH / 2
            bottomRightRadius: s.trackH / 2
            topLeftRadius: Theme.dp(2)
            bottomLeftRadius: Theme.dp(2)
            visible: width > 0.5
        }

        // the fill, from the origin to the handle
        Rectangle {
            readonly property bool ahead: s.hx >= s.ox
            readonly property real a: ahead ? s.ox : s.hx + s.handleW / 2 + s.gap
            readonly property real b: ahead ? s.hx - s.handleW / 2 - s.gap : s.ox

            anchors.verticalCenter: parent.verticalCenter
            x: a
            width: Math.max(0, b - a)
            height: s.trackH
            color: Theme.primary
            radius: Theme.dp(2)
            topLeftRadius: s.ofrac <= 0.001 && ahead ? s.trackH / 2 : Theme.dp(2)
            bottomLeftRadius: s.ofrac <= 0.001 && ahead ? s.trackH / 2 : Theme.dp(2)
            visible: width > 0.5
        }

        // where nothing is changed
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: s.ox - width / 2
            width: Theme.dp(2)
            height: Theme.dp(4)
            radius: 1
            color: Theme.fgSecondaryContainer
            opacity: s.ofrac > 0.001 && s.ofrac < 0.999 && Math.abs(s.hx - s.ox) > Theme.dp(8) ? 0.6 : 0
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: s.hx - width / 2
            width: s.handleW
            height: area.containsMouse || area.pressed ? Theme.dp(30) : Theme.dp(26)
            radius: width / 2
            color: Theme.primary

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        MouseArea {
            id: area

            anchors.fill: parent
            anchors.topMargin: -Theme.dp(6)
            enabled: !s.disabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: (mouse) => {
                s.live = s.at(mouse.x);
                s.changing(s.live);
            }
            onPositionChanged: (mouse) => {
                if (!pressed)
                    return ;

                var v = s.at(mouse.x);
                if (v !== s.live) {
                    s.live = v;
                    s.changing(v);
                }
            }
            onReleased: s.changed(s.live)
            onDoubleClicked: {
                s.live = s.origin;
                s.changed(s.origin);
            }
            // the wheel scrolls the panel, never a slider under the pointer
            onWheel: (wheel) => {
                wheel.accepted = false;
            }

            HeldPointer {
                held: area.pressed
                cursor: Qt.PointingHandCursor
            }

        }

    }

}
