import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidlumen
import qs.lucidui

// a video's trim, under the stage where the filmstrip was: frames along it, a
// handle at either end of the part to keep, which plays round and round while it
// is set. kept as a copy beside it, so the video itself is never cut
Item {
    id: tr

    required property var win
    required property var stage
    property bool active: false
    readonly property var movie: tr.stage.movie
    readonly property real dur: tr.movie ? tr.movie.duration : 0
    // the part kept, in ms
    property real from: 0
    property real to: 0
    property var frames: []
    readonly property bool saving: tr.win.trimJob !== ""
    readonly property real minLen: 300
    // a handle in hand: 0 none, -1 the start, 1 the end
    property int holding: 0
    property bool wasPlaying: false
    // the room it takes under the stage
    readonly property real panelH: body.implicitHeight + Theme.dp(32)

    // a time to a tenth: 0:02.4
    function fine(ms) {
        var t = Math.max(0, ms) / 1000, m = Math.floor(t / 60), s = t - m * 60;
        return m + ":" + (s < 10 ? "0" : "") + s.toFixed(1);
    }

    function begin() {
        tr.from = 0;
        tr.to = tr.dur;
        tr.frames = [];
        if (tr.dur <= 0 || !tr.win.current)
            return ;

        var path = tr.win.current.path;
        tr.win.app.call("strip", {
            "path": path,
            "n": 10,
            "h": Math.round(Theme.dp(64) * 1.5),
            "duration": tr.dur / 1000
        }, function(r) {
            if (r.ok && tr.win.current && tr.win.current.path === path)
                tr.frames = r.frames;

        });
    }

    function grab(which, x) {
        var ms = Math.max(0, Math.min(1, x / timeline.width)) * tr.dur;
        if (which < 0)
            tr.from = Math.min(ms, tr.to - tr.minLen);
        else
            tr.to = Math.max(ms, tr.from + tr.minLen);
        tr.movie.seek(which < 0 ? tr.from : tr.to);
    }

    onActiveChanged: {
        if (tr.active)
            tr.begin();

    }
    onDurChanged: {
        if (tr.active && tr.to <= 0)
            tr.begin();

    }
    // while it is set, the part plays round and round
    Binding {
        target: tr.movie
        property: "loopFrom"
        value: tr.from
        when: tr.active && tr.movie !== null
    }

    Binding {
        target: tr.movie
        property: "loopTo"
        value: tr.to >= tr.dur - 50 ? -1 : tr.to
        when: tr.active && tr.movie !== null
    }

    Rectangle {
        id: panel

        anchors.fill: parent
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.bgSunken)
        clip: true

        // the panel takes its own clicks, so none reach the stage beneath
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: body

            x: Theme.dp(16)
            y: Theme.dp(16)
            width: panel.width - Theme.dp(32)
            spacing: Theme.dp(12)

            Row {
                width: parent.width
                spacing: Theme.dp(12)

                IconButton {
                    id: playBtn

                    anchors.verticalCenter: parent.verticalCenter
                    icon: tr.movie && tr.movie.playing ? "pause" : "play_arrow"
                    variant: "tonal"
                    size: "m"
                    tooltip: tr.movie && tr.movie.playing ? "Pause (Space)" : "Play the part kept (Space)"

                    Tip {
                    }

                    onClicked: {
                        if (!tr.movie)
                            return ;

                        if (tr.movie.playing) {
                            tr.movie.player.pause();
                        } else {
                            if (tr.movie.position < tr.from || tr.movie.position >= tr.to - 50)
                                tr.movie.seek(tr.from);

                            tr.movie.play();
                        }
                    }
                }

                // the video's length in frames, the part kept between the handles
                Item {
                    id: timeline

                    readonly property real lx: tr.dur > 0 ? tr.from / tr.dur * timeline.width : 0
                    readonly property real rx: tr.dur > 0 ? tr.to / tr.dur * timeline.width : timeline.width

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - playBtn.width - parent.spacing
                    height: Theme.dp(64)

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSm
                        color: Theme.surfaceHighest

                        Row {
                            anchors.fill: parent

                            Repeater {
                                model: tr.frames

                                delegate: Image {
                                    required property string modelData

                                    width: timeline.width / Math.max(1, tr.frames.length)
                                    height: timeline.height
                                    source: modelData !== "" ? "file://" + modelData : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }

                            }

                        }

                        // what goes, dimmed either side
                        Rectangle {
                            width: timeline.lx
                            height: parent.height
                            color: Theme.alpha("#000000", 0.6)
                        }

                        Rectangle {
                            x: timeline.rx
                            width: timeline.width - timeline.rx
                            height: parent.height
                            color: Theme.alpha("#000000", 0.6)
                        }

                    }

                    // a click on the frames goes there
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => {
                            if (tr.movie)
                                tr.movie.seek(Math.max(0, Math.min(1, mouse.x / timeline.width)) * tr.dur);

                        }
                    }

                    // the part kept, edged in the accent
                    Rectangle {
                        x: timeline.lx
                        width: timeline.rx - timeline.lx
                        height: parent.height
                        color: "transparent"
                        border.width: Theme.dp(3)
                        border.color: Theme.accent
                        radius: Theme.radiusSm
                    }

                    // where it is playing
                    Rectangle {
                        x: tr.dur > 0 && tr.movie ? tr.movie.position / tr.dur * timeline.width - width / 2 : 0
                        y: -Theme.dp(4)
                        width: Theme.dp(3)
                        height: parent.height + Theme.dp(8)
                        radius: width / 2
                        color: Theme.text
                        visible: tr.movie !== null && tr.dur > 0
                    }

                    Repeater {
                        model: [-1, 1]

                        delegate: Rectangle {
                            id: handle

                            required property int modelData

                            x: (modelData < 0 ? timeline.lx : timeline.rx) - width / 2
                            y: -Theme.dp(6)
                            width: Theme.dp(16)
                            height: timeline.height + Theme.dp(12)
                            radius: Theme.dp(6)
                            color: Theme.accent
                            scale: grip.pressed ? 1.08 : 1

                            Rectangle {
                                anchors.centerIn: parent
                                width: Theme.dp(3)
                                height: Theme.dp(22)
                                radius: width / 2
                                color: Theme.fgAccent
                            }

                            MouseArea {
                                id: grip

                                anchors.fill: parent
                                anchors.margins: -Theme.dp(8)
                                cursorShape: Qt.SizeHorCursor
                                preventStealing: true
                                onPressed: {
                                    tr.wasPlaying = tr.movie !== null && tr.movie.playing;
                                    tr.holding = handle.modelData;
                                    if (tr.movie) {
                                        tr.movie.scrubbing = true;
                                        tr.movie.player.pause();
                                    }
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed && tr.movie)
                                        tr.grab(handle.modelData, mapToItem(timeline, mouse.x, 0).x);

                                }
                                onReleased: {
                                    tr.holding = 0;
                                    if (!tr.movie)
                                        return ;

                                    tr.movie.scrubbing = false;
                                    if (tr.wasPlaying) {
                                        tr.movie.seek(tr.from);
                                        tr.movie.play();
                                    }
                                }

                                HeldPointer {
                                    held: grip.pressed
                                    cursor: Qt.SizeHorCursor
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.durShort
                                }

                            }

                        }

                    }

                }

            }

            // the times: where it starts, how long, where it ends
            Item {
                width: parent.width
                height: span.implicitHeight

                LText {
                    x: playBtn.width + Theme.dp(12)
                    role: "labelLarge"
                    tabular: true
                    color: tr.holding < 0 ? Theme.accent : Theme.subtext
                    text: tr.fine(tr.from)
                }

                LText {
                    id: span

                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "labelLarge"
                    tabular: true
                    text: ((tr.to - tr.from) / 1000).toFixed(1) + " s kept"
                }

                LText {
                    anchors.right: parent.right
                    role: "labelLarge"
                    tabular: true
                    color: tr.holding > 0 ? Theme.accent : Theme.subtext
                    text: tr.fine(tr.to)
                }

            }

            Item {
                width: parent.width
                height: Math.max(cancelBtn.height, precise.height)

                Row {
                    id: precise

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(12)
                    visible: !tr.saving

                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: tr.win.app.prefs.exactTrim
                        onToggled: (value) => {
                            return tr.win.app.prefs.exactTrim = value;
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        LText {
                            role: "labelLarge"
                            text: "Precise cut"
                        }

                        LText {
                            role: "bodySmall"
                            color: Theme.subtext
                            text: tr.win.app.prefs.exactTrim ? "Exactly at the handles, encoded again: takes a while" : "Off: quick and lossless, but it starts at the nearest keyframe before"
                        }

                    }

                }

                // a cut under way
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - buttons.width - Theme.dp(24)
                    spacing: Theme.dp(6)
                    visible: tr.saving

                    LText {
                        role: "labelLarge"
                        tabular: true
                        text: "Trimming…  " + Math.round(tr.win.trimDone * 100) + "%"
                    }

                    LinearProgress {
                        width: parent.width
                        value: tr.win.trimDone
                    }

                }

                Row {
                    id: buttons

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(8)

                    Button {
                        id: cancelBtn

                        variant: "text"
                        text: tr.saving ? "Stop" : "Cancel"
                        onClicked: tr.saving ? tr.win.app.call("cancel", {
                            "job": tr.win.trimJob
                        }) : tr.win.closeTrim()
                    }

                    Button {
                        variant: "filled"
                        icon: "content_cut"
                        text: "Save copy"
                        disabled: tr.saving || tr.dur <= 0 || (tr.from < 50 && tr.to > tr.dur - 50)
                        onClicked: tr.win.saveTrim(tr.from, tr.to, tr.win.app.prefs.exactTrim)
                    }

                }

            }

        }

    }

}
