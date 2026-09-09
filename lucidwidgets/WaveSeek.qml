import QtQuick
import qs

// the bar's Mpris seek bar, rebuilt for a widget card: a sine wave over the
// played part, a flat rail over the rest, and start/end times under it
Item {
    id: seek

    property real position: 0
    property real length: 0
    property bool interactive: true
    property bool showTimes: true
    // set while the owner is animating a jump so the handle glides instead of snapping
    property int jumpDuration: 0
    property color accent: Theme.accent
    property color trackColor: Theme.alpha(Theme.text, 0.14)
    property color labelColor: Theme.subtext

    property bool dragging: false
    property bool hovering: false
    property real dragProgress: 0
    property bool showRemaining: false

    readonly property real trackInset: 8
    readonly property real waveHeight: 22
    readonly property real progress: seek.length > 0 ? Math.max(0, Math.min(1, seek.position / seek.length)) : 0
    readonly property real shownProgress: seek.dragging ? seek.dragProgress : seek.progress

    signal seekRequested(real seconds)

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    function fractionAt(px, w) {
        return Math.max(0, Math.min(1, (px - seek.trackInset) / Math.max(1, w - seek.trackInset * 2)));
    }

    implicitHeight: seek.waveHeight + (seek.showTimes ? 4 + posLabel.implicitHeight : 0)
    onAccentChanged: waveCanvas.requestPaint()
    onTrackColorChanged: waveCanvas.requestPaint()

    Canvas {
        id: waveCanvas

        property real animatedProgress: seek.shownProgress
        property real handleHeight: (seek.hovering || seek.dragging) ? 18 : 14
        property real amplitude: (seek.hovering || seek.dragging) ? 4.5 : 3.5

        readonly property real trackThickness: 4
        readonly property real handleWidth: 4
        readonly property real trackGap: 6
        readonly property real stopIndicator: 4
        readonly property real wavelength: 26

        function smoothstep(t) {
            t = Math.max(0, Math.min(1, t));
            return t * t * (3 - 2 * t);
        }

        // the wave has to die out at both ends or it collides with the cap and the handle
        function envelope(x, inset, rampLen, endX) {
            const fromStart = waveCanvas.smoothstep((x - inset) / rampLen);
            const fromEnd = waveCanvas.smoothstep((endX - x) / rampLen);
            return Math.min(fromStart, fromEnd);
        }

        function roundedBar(ctx, x, y, w, h, color) {
            ctx.fillStyle = color;
            ctx.beginPath();
            ctx.roundedRect(x, y, w, h, w / 2, w / 2);
            ctx.fill();
        }

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: seek.waveHeight
        antialiasing: true
        onAnimatedProgressChanged: requestPaint()
        onHandleHeightChanged: requestPaint()
        onAmplitudeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const midY = height / 2;
            const inset = seek.trackInset;
            const usableWidth = width - inset * 2;
            const handleX = inset + Math.max(0, Math.min(usableWidth, usableWidth * animatedProgress));
            const activeEnd = handleX - trackGap - handleWidth / 2;
            const inactiveStart = handleX + trackGap + handleWidth / 2;
            const rampLen = wavelength * 1.4;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            if (activeEnd - inset > trackThickness) {
                ctx.strokeStyle = seek.accent;
                ctx.lineWidth = trackThickness;
                ctx.beginPath();
                for (let x = inset; x <= activeEnd; x++) {
                    const y = midY + Math.sin((x / wavelength) * Math.PI * 2) * amplitude * envelope(x, inset, rampLen, activeEnd);
                    if (x === inset)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
            const trackEnd = width - inset - stopIndicator * 2;
            if (trackEnd - inactiveStart > trackThickness) {
                ctx.strokeStyle = seek.trackColor;
                ctx.lineWidth = trackThickness;
                ctx.beginPath();
                ctx.moveTo(inactiveStart, midY);
                ctx.lineTo(trackEnd, midY);
                ctx.stroke();
            }
            ctx.fillStyle = seek.accent;
            ctx.globalAlpha = animatedProgress > 0.97 ? 0 : 0.55;
            ctx.beginPath();
            ctx.arc(width - inset - stopIndicator / 2, midY, stopIndicator / 2, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalAlpha = 1;
            roundedBar(ctx, handleX - handleWidth / 2, midY - handleHeight / 2, handleWidth, handleHeight, seek.accent);
        }

        Behavior on animatedProgress {
            enabled: !seek.dragging

            NumberAnimation {
                duration: Theme.ms(seek.jumpDuration)
                easing.type: Easing.OutCubic
            }

        }

        Behavior on handleHeight {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutCubic
            }

        }

        Behavior on amplitude {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeStandard
            }

        }

    }

    MouseArea {
        anchors.fill: waveCanvas
        anchors.margins: -4
        enabled: seek.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // otherwise the frame's drag handler steals the gesture mid-scrub
        preventStealing: true
        onEntered: seek.hovering = true
        onExited: seek.hovering = false
        onPressed: (mouse) => {
            seek.dragging = true;
            seek.dragProgress = seek.fractionAt(mouse.x, width);
        }
        onPositionChanged: (mouse) => {
            if (seek.dragging)
                seek.dragProgress = seek.fractionAt(mouse.x, width);

        }
        onReleased: {
            seek.seekRequested(seek.dragProgress * seek.length);
            seek.dragging = false;
        }
        onCanceled: seek.dragging = false
        onWheel: (wheel) => {
            return seek.seekRequested(seek.position + (wheel.angleDelta.y > 0 ? 5 : -5));
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: posLabel.implicitHeight
        visible: seek.showTimes

        Text {
            id: posLabel

            anchors.left: parent.left
            anchors.leftMargin: seek.trackInset
            text: seek.fmt(seek.dragging ? seek.dragProgress * seek.length : seek.position)
            color: seek.labelColor
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Text {
            id: lenLabel

            anchors.right: parent.right
            anchors.rightMargin: seek.trackInset
            text: seek.showRemaining ? "-" + seek.fmt(seek.length - seek.position) : seek.fmt(seek.length)
            color: lenArea.containsMouse ? Theme.text : seek.labelColor
            font.family: Theme.fontFamily
            font.pixelSize: 11

            MouseArea {
                id: lenArea

                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: seek.showRemaining = !seek.showRemaining
            }

        }

    }

}
