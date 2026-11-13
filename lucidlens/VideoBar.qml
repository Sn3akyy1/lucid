import QtQuick
import qs
import qs.lucidlumen
import qs.lucidui

// a video's controls, over the foot of the stage: play, the time line, how loud,
// how fast, round and round, a frame kept as a picture, and full screen. they
// go while it plays and the pointer rests, and are always there while paused
Item {
    id: vb

    required property var win
    required property var stage
    // the pointer moved lately (StageControls)
    property bool awake: false
    readonly property var movie: vb.stage.movie
    readonly property var prefs: vb.win.app.prefs
    readonly property bool on: vb.stage.videoHere && vb.win.mode === "view" && !vb.win.overview && !vb.win.slideshow && !vb.win.trimming && vb.movie !== null
    readonly property bool shown: vb.on && (vb.awake || !vb.movie.playing || barHover.hovered || scrub.held)
    readonly property real dur: vb.movie ? vb.movie.duration : 0
    // the bar's height while it shows, for what floats above it
    readonly property real lift: vb.shown ? bar.height + Theme.dp(16) : 0

    // paused: the way back in
    Rectangle {
        anchors.centerIn: parent
        width: Theme.dp(72)
        height: width
        radius: width / 2
        color: Theme.alpha(Theme.surfaceHigh, 0.86)
        opacity: vb.on && !vb.movie.playing && !vb.movie.waiting && !scrub.held && !vb.movie.failed ? 1 : 0
        scale: bigArea.pressed ? 0.92 : (opacity > 0.5 ? 1 : 0.8)
        visible: opacity > 0.01

        Icon {
            anchors.centerIn: parent
            size: Theme.dp(38)
            name: "play_arrow"
            fill: 1
            color: Theme.text
        }

        MouseArea {
            id: bigArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: vb.movie.play()
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

    Rectangle {
        id: bar

        readonly property bool roomy: bar.width >= Theme.dp(640)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: vb.shown ? Theme.dp(16) : -bar.height
        width: Math.min(parent.width - Theme.dp(32), Theme.dp(880))
        height: Theme.dp(56)
        radius: height / 2
        color: Theme.alpha(Theme.surfaceHigh, 0.86)
        opacity: vb.shown ? 1 : 0
        visible: vb.on && opacity > 0.01

        HoverHandler {
            id: barHover
        }

        // the bar takes its own clicks and wheel, so none reach the stage beneath
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => {
                wheel.accepted = true;
            }
        }

        IconButton {
            id: playBtn

            x: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            icon: vb.movie && vb.movie.playing ? "pause" : "play_arrow"
            tooltip: vb.movie && vb.movie.playing ? "Pause (Space)" : "Play (Space)"

            Tip {
            }

            onClicked: vb.movie.toggle()
        }

        LText {
            id: clock

            anchors.left: playBtn.right
            anchors.leftMargin: Theme.dp(4)
            anchors.verticalCenter: parent.verticalCenter
            role: "labelLarge"
            tabular: true
            text: vb.movie ? vb.win.app.timeText(scrub.held ? scrub.at * vb.dur : vb.movie.position) + "  /  " + vb.win.app.timeText(vb.dur) : ""
        }

        // the time line: a click or a drag goes there, and the pointer's time rides above it
        Item {
            id: scrub

            property bool held: false
            property bool wasPlaying: false
            // where a drag has got, 0 to 1
            property real at: 0
            readonly property real frac: scrub.held ? scrub.at : (vb.movie && vb.dur > 0 ? vb.movie.position / vb.dur : 0)
            readonly property bool hot: scrubArea.containsMouse || scrub.held

            function to(mx) {
                scrub.at = Math.max(0, Math.min(1, mx / scrub.width));
                vb.movie.seek(scrub.at * vb.dur);
            }

            anchors.left: clock.right
            anchors.leftMargin: Theme.dp(16)
            anchors.right: tools.left
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.dp(32)
            visible: vb.movie !== null && !vb.movie.failed

            // the part played rides a wave while it plays, and lies flat paused or in hand
            LinearProgress {
                id: track

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                value: scrub.frac
                wavy: true
                animated: vb.movie !== null && vb.movie.playing && !scrub.held
                // the position already arrives frame by frame, and a seek lands at once
                valueAnimated: false
                thickness: scrub.hot ? Theme.dp(6) : Theme.dp(4)
                color: Theme.accent
                trackColor: Theme.alpha(Theme.text, 0.18)

                Behavior on thickness {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            Rectangle {
                x: track.width * scrub.frac - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(14)
                height: width
                radius: width / 2
                color: Theme.accent
                scale: scrub.hot ? 1 : 0
                visible: scale > 0.01

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            MouseArea {
                id: scrubArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: (mouse) => {
                    scrub.wasPlaying = vb.movie.playing;
                    scrub.held = true;
                    vb.movie.scrubbing = true;
                    vb.movie.player.pause();
                    scrub.to(mouse.x);
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        scrub.to(mouse.x);

                }
                onReleased: {
                    scrub.held = false;
                    vb.movie.scrubbing = false;
                    if (scrub.wasPlaying)
                        vb.movie.play();

                }
                onCanceled: {
                    scrub.held = false;
                    vb.movie.scrubbing = false;
                }

                HeldPointer {
                    held: scrubArea.pressed
                    cursor: Qt.PointingHandCursor
                }

            }

            // the time under the pointer
            Rectangle {
                readonly property real mx: scrub.held ? scrub.at * scrub.width : scrubArea.mouseX

                x: Math.max(-scrub.x + Theme.dp(4), Math.min(scrub.width - width, mx - width / 2))
                y: -height - Theme.dp(14)
                width: tipLabel.implicitWidth + Theme.dp(16)
                height: Theme.dp(28)
                radius: height / 2
                color: Theme.alpha(Theme.surfaceHighest, 0.95)
                visible: scrub.hot && vb.dur > 0

                LText {
                    id: tipLabel

                    anchors.centerIn: parent
                    role: "labelMedium"
                    tabular: true
                    text: vb.win.app.timeText(Math.max(0, Math.min(1, parent.mx / Math.max(1, scrub.width))) * vb.dur)
                }

            }

        }

        // it can't be played: why, where the time line would be
        LText {
            anchors.left: clock.right
            anchors.leftMargin: Theme.dp(16)
            anchors.right: tools.left
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            visible: vb.movie !== null && vb.movie.failed
            role: "bodyMedium"
            color: Theme.subtext
            text: vb.movie ? "Can't play it here" + (vb.movie.why ? ": " + vb.movie.why : "") : ""
            elide: Text.ElideRight
        }

        Row {
            id: tools

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            IconButton {
                id: volBtn

                anchors.verticalCenter: parent.verticalCenter
                icon: vb.prefs.muted || vb.prefs.volume <= 0 ? "volume_off" : (vb.prefs.volume < 0.5 ? "volume_down" : "volume_up")
                tooltip: vb.prefs.muted ? "Unmute (M)" : "Mute (M)"
                disabled: vb.movie !== null && !vb.movie.hasAudio && vb.movie.duration > 0

                Tip {
                }

                onClicked: vb.prefs.muted = !vb.prefs.muted

                // the wheel over it turns it up and down
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 8;
                        vb.win.setVolume(vb.prefs.volume + d / 120 * 0.05);
                    }
                }

            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(96)
                visible: bar.roomy && !volBtn.disabled
                size: "xs"
                showValue: false
                from: 0
                to: 1
                value: vb.prefs.muted ? 0 : vb.prefs.volume
                onMoved: (v) => {
                    return vb.win.setVolume(v);
                }
            }

            Item {
                width: Theme.dp(6)
                height: 1
                visible: bar.roomy
            }

            // how fast, a click away from the usual steps
            Rectangle {
                id: rateChip

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(Theme.dp(48), rateLabel.implicitWidth + Theme.dp(18))
                height: Theme.dp(32)
                radius: height / 2
                color: vb.win.rate !== 1 ? Theme.accentContainer : "transparent"
                visible: bar.width >= Theme.dp(560)

                LText {
                    id: rateLabel

                    anchors.centerIn: parent
                    role: "labelLarge"
                    tabular: true
                    color: vb.win.rate !== 1 ? Theme.fgAccentContainer : Theme.text
                    text: vb.win.rateText(vb.win.rate)
                }

                MouseArea {
                    id: rateArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var p = rateChip.mapToItem(vb.win.contentItem, 0, 0);
                        vb.win.rateMenu(p.x - Theme.dp(60), p.y - Theme.dp(300));
                    }
                }

                HoverLayer {
                    area: rateArea
                }

            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.width >= Theme.dp(520)
                icon: "repeat"
                tooltip: vb.prefs.loopVideos ? "Stop playing it round" : "Play it round and round"
                checkable: true
                checked: vb.prefs.loopVideos

                Tip {
                }

                onClicked: vb.prefs.loopVideos = !vb.prefs.loopVideos
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.width >= Theme.dp(480)
                icon: "photo_camera"
                tooltip: "Save this frame as a picture"

                Tip {
                }

                onClicked: vb.win.saveFrame()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: vb.win.immersive ? "fullscreen_exit" : "fullscreen"
                tooltip: vb.win.immersive ? "Leave full screen (F)" : "Full screen (F)"

                Tip {
                }

                onClicked: vb.win.setImmersive(!vb.win.immersive)
            }

        }

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

}
