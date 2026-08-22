import QtQuick
import qs

// Material 3 slider: a 16dp track split around a 4x44dp bar handle with a 6dp
// gap either side, outer ends fully rounded and inner ends squared back to
// 2dp. These are the metrics the launcher's old >blur strip (luciddocks/
// BlurRow.qml) used before that strip was removed in favour of the Glass
// slider on this app's General page, so the control kept its feel.
//
// Handles both continuous and stepped values. Stop indicators only render for
// stepped sliders with few enough steps to stay legible - a 1..100 slider
// dotted every step is noise, not information.
Item {
    id: slider

    property real from: 0
    property real to: 1
    property real stepSize: 0
    // driven by its binding, never self-assigned - see the note in M3Switch.
    // `moved` fires continuously during a drag, so whatever this is bound to
    // has already caught up by the time the drag ends.
    property real value: 0
    property bool enabled: true
    // optional per-step names, e.g. ["Off", "Light", "Heavy"] - when set,
    // these replace the numeric readout entirely
    property var stepLabels: null
    property string suffix: ""
    // how many decimals the numeric readout keeps; steps of 1 or more never
    // want any
    property int decimals: slider.stepSize >= 1 ? 0 : 2
    property bool dragging: false
    property real dragValue: 0
    property bool showReadout: true

    readonly property real displayValue: slider.dragging ? slider.dragValue : slider.value
    readonly property real span: slider.to - slider.from
    readonly property real fraction: slider.span > 0 ? Math.max(0, Math.min(1, (slider.displayValue - slider.from) / slider.span)) : 0
    readonly property int stepCount: slider.stepSize > 0 ? Math.round(slider.span / slider.stepSize) + 1 : 0
    readonly property bool showStops: slider.stepCount > 1 && slider.stepCount <= 11
    readonly property string readout: {
        if (slider.stepLabels && slider.stepCount > 1) {
            var i = Math.round((slider.displayValue - slider.from) / slider.stepSize);
            if (i >= 0 && i < slider.stepLabels.length)
                return slider.stepLabels[i];
        }
        return slider.displayValue.toFixed(slider.decimals) + slider.suffix;
    }

    // emitted continuously while dragging, not just on release - a shell
    // setting with no live preview is guesswork
    signal moved(real v)

    function snap(v) {
        var clamped = Math.max(slider.from, Math.min(slider.to, v));
        if (slider.stepSize <= 0)
            return clamped;

        var steps = Math.round((clamped - slider.from) / slider.stepSize);
        return Math.max(slider.from, Math.min(slider.to, slider.from + steps * slider.stepSize));
    }

    function updateFromX(px) {
        // the handle travels inside the track's bounds rather than over its
        // full width, so the click has to be mapped through the same inset
        // or the top value is unreachable
        var travel = track.width - track.handleWidth;
        var pct = travel > 0 ? Math.max(0, Math.min(1, (px - track.handleWidth / 2) / travel)) : 0;
        var next = slider.snap(slider.from + pct * slider.span);
        if (next !== slider.dragValue) {
            slider.dragValue = next;
            slider.moved(next);
        }
    }

    implicitHeight: 44 + (slider.showReadout ? 22 : 0)
    implicitWidth: 200
    opacity: slider.enabled ? 1 : 0.38

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }


    // M3's value indicator, kept visible at rest rather than only while
    // dragging - in a settings list the current value is the whole point, and
    // a slider you have to grab to read is a slider you have to guess at
    Item {
        id: indicator

        readonly property real wanted: track.x + track.handleX - indicator.width / 2

        width: readoutText.implicitWidth + 16
        height: 20
        visible: slider.showReadout
        anchors.top: parent.top
        x: Math.max(0, Math.min(slider.width - indicator.width, indicator.wanted))

        Behavior on x {
            NumberAnimation {
                duration: Theme.ms(150)
                easing.type: Easing.OutCubic
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: slider.dragging ? Theme.accent : Theme.bgHigh

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        Text {
            id: readoutText

            anchors.centerIn: parent
            text: slider.readout
            color: slider.dragging ? Theme.onAccent : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.bold: true

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

        }

    }

    Item {
        id: track

        readonly property real trackHeight: 16
        readonly property real handleWidth: 4
        readonly property real handleGap: 6
        readonly property real stopSize: 4
        readonly property real stopInset: 6
        readonly property bool hovering: dragArea.containsMouse || slider.dragging
        readonly property real handleX: track.centerOf(slider.fraction)
        readonly property real activeEnd: Math.max(0, track.handleX - track.handleWidth / 2 - track.handleGap)
        readonly property real inactiveStart: Math.min(track.width, track.handleX + track.handleWidth / 2 + track.handleGap)

        function centerOf(f) {
            return track.handleWidth / 2 + f * (track.width - track.handleWidth);
        }

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 44

        Rectangle {
            width: track.activeEnd
            height: track.trackHeight
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
            topLeftRadius: track.trackHeight / 2
            bottomLeftRadius: track.trackHeight / 2
            topRightRadius: 2
            bottomRightRadius: 2

            Behavior on width {
                NumberAnimation {
                    duration: Theme.ms(150)
                    easing.type: Easing.OutCubic
                }

            }

        }

        Rectangle {
            x: track.inactiveStart
            width: Math.max(0, track.width - track.inactiveStart)
            height: track.trackHeight
            anchors.verticalCenter: parent.verticalCenter
            color: track.hovering ? Theme.bgActive : Theme.bgHigh
            topLeftRadius: 2
            bottomLeftRadius: 2
            topRightRadius: track.trackHeight / 2
            bottomRightRadius: track.trackHeight / 2

            Behavior on x {
                NumberAnimation {
                    duration: Theme.ms(150)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on width {
                NumberAnimation {
                    duration: Theme.ms(150)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        // one dot per step, contrast flipping as the active track sweeps past
        // it, and the one currently under the handle dropping out rather than
        // showing through the gap
        Repeater {
            model: slider.showStops ? slider.stepCount : 0

            Rectangle {
                id: stop

                required property int index

                readonly property real centerX: Math.max(track.stopInset, Math.min(track.width - track.stopInset, track.centerOf(slider.stepCount > 1 ? stop.index / (slider.stepCount - 1) : 0)))
                readonly property bool covered: stop.centerX <= track.activeEnd
                readonly property bool masked: Math.abs(stop.centerX - track.handleX) < track.handleWidth / 2 + track.handleGap + track.stopSize / 2

                width: track.stopSize
                height: track.stopSize
                radius: track.stopSize / 2
                x: stop.centerX - track.stopSize / 2
                anchors.verticalCenter: parent.verticalCenter
                color: stop.covered ? Theme.onAccent : Theme.outlineStrong
                opacity: stop.masked ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

        }

        Rectangle {
            id: handle

            width: track.handleWidth
            height: parent.height
            radius: track.handleWidth / 2
            x: track.handleX - track.handleWidth / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
            scale: track.hovering ? 1.12 : 1

            Behavior on x {
                NumberAnimation {
                    duration: Theme.ms(150)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        MouseArea {
            id: dragArea

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            enabled: slider.enabled
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: (mouse) => {
                slider.dragValue = slider.value;
                slider.dragging = true;
                slider.updateFromX(mouse.x + dragArea.anchors.margins);
            }
            onPositionChanged: (mouse) => {
                if (slider.dragging)
                    slider.updateFromX(mouse.x + dragArea.anchors.margins);

            }
            onReleased: slider.dragging = false
            onCanceled: slider.dragging = false
        }

    }

}
