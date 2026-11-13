import QtQuick
import qs
import qs.lucidlumen
import qs.lucidui

// what floats over the stage: the way to the neighbours while the pointer is
// about, the zoom as it changes, a map of a picture zoomed past the stage, a
// moving picture's controls, a video's, and the slideshow's
Item {
    id: ctl

    required property var win
    required property var stage
    readonly property bool viewing: ctl.win.mode === "view" && !ctl.win.overview
    // the pointer moved lately: the controls show, and go again when it rests
    property bool awake: false
    readonly property color glass: Theme.alpha(Theme.surfaceHigh, 0.86)

    function wake() {
        ctl.awake = true;
        rest.restart();
    }

    HoverHandler {
        id: hover

        onPointChanged: ctl.wake()
        onHoveredChanged: {
            if (!hovered)
                ctl.awake = false;

        }
    }

    Timer {
        id: rest

        interval: ctl.win.slideshow ? 1800 : 2600
        onTriggered: ctl.awake = false
    }

    component GlassButton: IconButton {
        variant: "tonal"
        size: "m"
        containerOverride: Theme.alpha(Theme.surfaceHigh, 0.86)
        tintOverride: Theme.text
    }

    GlassButton {
        id: prev

        anchors.verticalCenter: parent.verticalCenter
        x: ctl.shown ? Theme.dp(16) : -Theme.dp(12)
        icon: "chevron_left"
        tooltip: "Previous (←)"
        opacity: ctl.shown ? 1 : 0
        visible: opacity > 0.01 && ctl.win.items.length > 1

        Tip {
        }

        onClicked: ctl.win.go(-1)

        Behavior on x {
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

    readonly property bool shown: ctl.viewing && !ctl.win.slideshow && !ctl.win.trimming && ctl.awake && !ctl.stage.zoomed

    GlassButton {
        anchors.verticalCenter: parent.verticalCenter
        x: ctl.shown ? ctl.width - width - Theme.dp(16) : ctl.width - width + Theme.dp(12)
        icon: "chevron_right"
        tooltip: "Next (→)"
        opacity: ctl.shown ? 1 : 0
        visible: opacity > 0.01 && ctl.win.items.length > 1

        Tip {
        }

        onClicked: ctl.win.go(1)

        Behavior on x {
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

    // the zoom, for a moment after it changes
    Rectangle {
        id: toast

        property bool on: false

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.dp(18) + videoBar.lift
        width: toastLabel.implicitWidth + Theme.dp(28)
        height: Theme.dp(36)
        radius: height / 2
        color: ctl.glass
        opacity: toast.on && !anim.visible ? 1 : 0
        scale: toast.on ? 1 : 0.9
        visible: opacity > 0.01

        LText {
            id: toastLabel

            anchors.centerIn: parent
            role: "labelLarge"
            tabular: true
            text: Math.round(ctl.stage.shownScale * 100) + "%"
        }

        Connections {
            // only a zoom someone made: not the fit following the window
            function onShownScaleChanged() {
                if (!ctl.stage.current || !ctl.stage.current.ready || ctl.stage.sliding || !ctl.stage.zoomed || ctl.win.slideshow)
                    return ;

                toast.on = true;
                toastLife.restart();
            }

            target: ctl.stage
        }

        Timer {
            id: toastLife

            interval: 900
            onTriggered: toast.on = false
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

    // where the stage looks into a picture zoomed past it
    Rectangle {
        id: map

        readonly property var pic: ctl.stage.current
        readonly property real k: !map.pic || map.pic.width <= 0 ? 0 : Math.min(Theme.dp(150) / map.pic.width, Theme.dp(110) / map.pic.height)

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.dp(16)
        anchors.bottomMargin: Theme.dp(16) + videoBar.lift
        width: map.pic ? map.pic.width * map.k + Theme.dp(8) : 0
        height: map.pic ? map.pic.height * map.k + Theme.dp(8) : 0
        radius: Theme.radiusSm
        color: ctl.glass
        opacity: ctl.stage.canPan && ctl.viewing && !ctl.stage.sliding ? 1 : 0
        visible: opacity > 0.01

        Image {
            id: mapPic

            x: Theme.dp(4)
            y: Theme.dp(4)
            width: parent.width - Theme.dp(8)
            height: parent.height - Theme.dp(8)
            source: ctl.win.current && ctl.win.current.thumb ? "file://" + ctl.win.current.thumb : ""
            fillMode: Image.Stretch
            smooth: true
            visible: ctl.win.edits === ctl.win.blank
        }

        // the part on show, and a drag moves it
        Rectangle {
            readonly property real s: ctl.stage.shownScale
            readonly property real pw: map.pic ? map.pic.width * s : 1
            readonly property real ph: map.pic ? map.pic.height * s : 1
            readonly property real fw: Math.min(1, ctl.stage.width / pw)
            readonly property real fh: Math.min(1, ctl.stage.height / ph)

            x: mapPic.x + mapPic.width * (0.5 - fw / 2 - ctl.stage.panX / pw)
            y: mapPic.y + mapPic.height * (0.5 - fh / 2 - ctl.stage.panY / ph)
            width: mapPic.width * fw
            height: mapPic.height * fh
            color: Theme.alpha(Theme.accent, 0.18)
            border.width: Theme.dp(2)
            border.color: Theme.accent
            radius: Theme.dp(4)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function seek(mx, my) {
                var s = ctl.stage.shownScale, p = map.pic;
                var fx = (mx - mapPic.x) / mapPic.width, fy = (my - mapPic.y) / mapPic.height;
                ctl.stage.panX = (0.5 - fx) * p.width * s;
                ctl.stage.panY = (0.5 - fy) * p.height * s;
                ctl.stage.clampPan();
            }
            onPressed: (mouse) => {
                return seek(mouse.x, mouse.y);
            }
            onPositionChanged: (mouse) => {
                if (pressed)
                    seek(mouse.x, mouse.y);

            }

            HeldPointer {
                held: parent.pressed
                cursor: Qt.PointingHandCursor
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    // a moving picture: play, pause, and a frame at a time
    Rectangle {
        id: anim

        readonly property var img: ctl.stage.current ? ctl.stage.current.image : null
        readonly property int frames: anim.img && anim.img.frameCount !== undefined ? anim.img.frameCount : 0

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.dp(16)
        width: animRow.implicitWidth + Theme.dp(16)
        height: Theme.dp(48)
        radius: height / 2
        color: ctl.glass
        visible: ctl.viewing && ctl.win.current !== null && ctl.win.current.animated && anim.frames > 1 && (ctl.awake || !ctl.stage.playing)

        Row {
            id: animRow

            anchors.centerIn: parent
            spacing: Theme.dp(4)

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_previous"
                tooltip: "Previous frame"

                Tip {
                }

                onClicked: {
                    ctl.stage.playing = false;
                    anim.img.currentFrame = (anim.img.currentFrame - 1 + anim.frames) % anim.frames;
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: ctl.stage.playing ? "pause" : "play_arrow"
                tooltip: ctl.stage.playing ? "Pause" : "Play"

                Tip {
                }

                onClicked: ctl.stage.playing = !ctl.stage.playing
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_next"
                tooltip: "Next frame"

                Tip {
                }

                onClicked: {
                    ctl.stage.playing = false;
                    anim.img.currentFrame = (anim.img.currentFrame + 1) % anim.frames;
                }
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: Theme.dp(10)
                role: "labelLarge"
                tabular: true
                color: Theme.subtext
                text: anim.img ? (anim.img.currentFrame + 1) + " / " + anim.frames : ""
            }

        }

    }

    VideoBar {
        id: videoBar

        anchors.fill: parent
        win: ctl.win
        stage: ctl.stage
        awake: ctl.awake
    }

    // the slideshow: how far into this picture (or video), and its controls when the pointer moves
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: Theme.dp(3)
        width: parent.width * (ctl.stage.movie && ctl.stage.movie.duration > 0 ? ctl.stage.movie.position / ctl.stage.movie.duration : progress.t)
        color: Theme.accent
        visible: ctl.win.slideshow

        NumberAnimation {
            id: progress

            property real t: 0

            target: progress
            property: "t"
            from: 0
            to: 1
            duration: Math.max(2, ctl.win.app.prefs.slideSecs) * 1000
            running: ctl.win.slideshow && !ctl.win.slidePaused
        }

        Connections {
            function onIndexChanged() {
                if (ctl.win.slideshow)
                    progress.restart();

            }

            target: ctl.win
        }

    }

    Rectangle {
        id: slideCtl

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: ctl.awake ? Theme.dp(24) : -height
        width: slideRow.implicitWidth + Theme.dp(16)
        height: Theme.dp(56)
        radius: height / 2
        color: ctl.glass
        visible: ctl.win.slideshow

        Row {
            id: slideRow

            anchors.centerIn: parent
            spacing: Theme.dp(4)

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_previous"
                size: "m"
                onClicked: ctl.win.go(-1)
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: ctl.win.slidePaused ? "play_arrow" : "pause"
                size: "m"
                variant: "filled"
                onClicked: ctl.win.pauseSlideshow(!ctl.win.slidePaused)
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_next"
                size: "m"
                onClicked: ctl.win.go(1)
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "shuffle"
                checkable: true
                checked: ctl.win.app.prefs.shuffle
                onClicked: ctl.win.app.prefs.shuffle = !ctl.win.app.prefs.shuffle
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                onClicked: ctl.win.stopSlideshow()
            }

        }

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

    // nothing to show
    Column {
        anchors.centerIn: parent
        visible: ctl.win.items.length === 0 && ctl.win.folder !== ""
        spacing: Theme.dp(12)

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "photo_library"
            size: Theme.dp(56)
            color: Theme.subtext
        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "titleMedium"
            text: ctl.win.app.prefs.videos && (ctl.win.app.caps.videos || []).length > 0 ? "No pictures or videos here" : "No pictures here"
        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "bodyMedium"
            color: Theme.subtext
            text: "Drop one on the window, or open one with Ctrl+O"
        }

    }

}
