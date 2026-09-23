import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.lucidui

WidgetBody {
    id: w

    readonly property var players: Mpris.players.values.filter((p) => {
        return !(p.dbusName && p.dbusName.indexOf("playerctld") !== -1);
    })
    readonly property var player: {
        for (var i = 0; i < w.players.length; i++) {
            if (w.players[i].isPlaying)
                return w.players[i];

        }
        return w.players.length > 0 ? w.players[0] : null;
    }
    readonly property bool has: w.player !== null
    readonly property bool playing: w.has ? w.player.isPlaying : false
    readonly property string title: w.has ? (w.player.trackTitle || "Unknown track") : "Nothing playing"
    readonly property string artist: w.has ? (w.player.trackArtist || w.player.identity || "") : "Start something and it lands here"
    readonly property string source: w.has ? (w.player.identity || "") : ""
    readonly property string artUrl: w.has ? (w.player.trackArtUrl || "") : ""
    readonly property real length: w.has ? w.player.length : 0
    readonly property real position: w.has ? w.player.position : 0
    // mpris reports position in whole seconds, so interpolate between them
    property real livePos: w.position
    property real posBase: w.position
    property double posStamp: Date.now()
    property int jumpDuration: 0
    property bool snapNext: false
    property bool scrubbing: false
    readonly property bool canSeek: w.has && w.player.canSeek
    readonly property real progress: w.length > 0 ? Math.max(0, Math.min(1, w.livePos / w.length)) : 0
    readonly property bool showProgress: w.opt("showProgress") !== false
    readonly property bool scroll: w.opt("scroll") !== false && !w.preview
    // the card takes its colours off the cover, the way a phone's player does
    readonly property bool artTint: w.opt("artTint") !== false && w.artUrl !== "" && quant.colors.length > 0
    readonly property color seed: {
        var best = null;
        var score = -1;
        for (var i = 0; i < quant.colors.length; i++) {
            var c = quant.colors[i];
            var t = Theme.toneOf(c);
            // colourful, and not a near-black or near-white corner of the cover
            var sc = Theme.chromaOf(c) * (t > 12 && t < 90 ? 1 : 0.2);
            if (sc > score) {
                score = sc;
                best = c;
            }
        }
        return best !== null ? best : Theme.cPrimary;
    }
    readonly property color seedVivid: Theme.withSat(w.seed, 1.4)
    // the quantizer only reads local files, so a cover served over the web is
    // fetched once into the cache and read from there. every card fetches into
    // its own part file, since two cards on one track race for the same cover
    readonly property bool remoteArt: /^https?:/.test(w.artUrl)
    readonly property string artFile: {
        if (!w.remoteArt)
            return "";

        var h = 5381;
        for (var i = 0; i < w.artUrl.length; i++) h = ((h * 33) ^ w.artUrl.charCodeAt(i)) >>> 0
        return Quickshell.env("HOME") + "/.cache/lucid/art/" + h.toString(16) + ".img";
    }
    property string localArt: ""

    function toggle() {
        if (w.has && w.player.canTogglePlaying)
            w.player.togglePlaying();

    }

    function skip(dir) {
        if (!w.has)
            return ;

        if (dir > 0 && w.player.canGoNext)
            w.player.next();
        else if (dir < 0 && w.player.canGoPrevious)
            w.player.previous();
    }

    function seekTo(sec) {
        if (!w.canSeek)
            return ;

        const target = Math.max(0, Math.min(w.length, sec));
        w.player.position = target;
        w.jumpDuration = 0;
        w.posBase = target;
        w.posStamp = Date.now();
        w.livePos = target;
    }

    ownInk: w.artTint
    fill: w.artTint ? Theme.withBlur(Theme.atTone(w.seedVivid, Theme.isLight ? 90 : 22)) : w.toneFill
    ink: w.artTint ? Theme.atTone(w.seedVivid, Theme.isLight ? 12 : 94) : w.toneInk
    inkAccent: w.artTint ? Theme.atTone(w.seedVivid, Theme.isLight ? 40 : 80) : w.toneInkAccent
    onInkAccent: w.artTint ? Theme.atTone(w.seedVivid, Theme.isLight ? 98 : 16) : w.toneOnInkAccent
    Behavior on fill {
        ColorAnimation {
            duration: Theme.durSlowEffects
        }

    }

    Behavior on ink {
        ColorAnimation {
            duration: Theme.durSlowEffects
        }

    }

    Behavior on inkAccent {
        ColorAnimation {
            duration: Theme.durSlowEffects
        }

    }

    Behavior on onInkAccent {
        ColorAnimation {
            duration: Theme.durSlowEffects
        }

    }

    onPositionChanged: {
        const delta = Math.abs(w.position - w.livePos);
        w.jumpDuration = (w.snapNext || delta < 1.5) ? 0 : 320;
        w.snapNext = false;
        w.posBase = w.position;
        w.posStamp = Date.now();
        w.livePos = w.position;
    }
    onPlayerChanged: w.snapNext = true
    onPlayingChanged: {
        w.posBase = w.livePos;
        w.posStamp = Date.now();
    }

    function fetchCover() {
        w.localArt = "";
        if (w.artFile !== "" && w.opt("artTint") !== false && !w.preview) {
            fetchArt.running = false;
            fetchArt.running = true;
        }
    }

    onArtFileChanged: w.fetchCover()
    Component.onCompleted: w.fetchCover()

    Process {
        id: fetchArt

        command: ["sh", "-c", "f=\"$1\"; d=\"$(dirname \"$f\")\"; mkdir -p \"$d\"; find \"$d\" -name '*.img' -mtime +14 -delete 2>/dev/null; [ -s \"$f\" ] || { t=\"$f.$$\"; curl -sfL --max-time 10 -o \"$t\" \"$2\" && mv \"$t\" \"$f\" || rm -f \"$t\"; }; [ -s \"$f\" ]", "sh", w.artFile, w.artUrl]
        onExited: (code) => {
            if (code === 0)
                w.localArt = "file://" + w.artFile;

        }
    }

    ColorQuantizer {
        id: quant

        source: w.remoteArt ? w.localArt : w.artUrl
        depth: 3
        rescaleSize: 48
    }

    // a blanked or off-screen card has no progress bar to move, so do not run
    // a per-frame handler for it
    FrameAnimation {
        running: w.visible && w.playing && w.showProgress && !w.preview && !w.scrubbing
        onTriggered: w.livePos = Math.min(w.length, w.posBase + (Date.now() - w.posStamp) / 1000)
    }

    // mpris never ticks position on its own
    Timer {
        interval: 1000
        repeat: true
        running: w.visible && w.playing && w.showProgress && !w.preview && !w.scrubbing
        onTriggered: {
            if (w.player)
                w.player.positionChanged();

        }
    }

    // the cover, rounded, or a note on the ink when there is none
    component Cover: ClippingRectangle {
        id: cov

        property real corner: 20

        radius: cov.corner
        color: Theme.alpha(w.ink, 0.08)

        Image {
            id: covImg

            anchors.fill: parent
            source: w.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 512
            sourceSize.height: 512
            visible: covImg.status === Image.Ready
        }

        Icon {
            anchors.centerIn: parent
            visible: covImg.status !== Image.Ready
            name: "music_note"
            size: Math.min(cov.width, cov.height) * 0.36
            fill: 1
            color: w.inkFaint
        }

    }

    component Transport: Row {
        id: tr

        property real big: 56
        property bool showPrev: true

        spacing: 8

        IconButton {
            visible: tr.showPrev
            anchors.verticalCenter: parent.verticalCenter
            icon: "skip_previous"
            iconFill: 1
            tintOverride: w.ink
            disabled: !(w.has && w.player.canGoPrevious)
            onClicked: w.skip(-1)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: tr.big * 1.3
            height: tr.big
            radius: playTap.pressed ? tr.big * 0.28 : tr.big / 2
            color: w.inkAccent
            opacity: w.has ? 1 : 0.4

            Behavior on radius {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

            Icon {
                anchors.centerIn: parent
                name: w.playing ? "pause" : "play_arrow"
                size: tr.big * 0.5
                fill: 1
                color: w.onInkAccent
            }

            StateLayer {
                id: playTap

                radius: parent.radius
                tint: w.onInkAccent
                disabled: !w.has
                onClicked: w.toggle()
            }

        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "skip_next"
            iconFill: 1
            tintOverride: w.ink
            disabled: !(w.has && w.player.canGoNext)
            onClicked: w.skip(1)
        }

    }

    // card: the cover, then the track, a wavy seek and the transport
    Item {
        visible: w.variant === "card"
        anchors.fill: parent
        anchors.margins: 14

        Cover {
            id: cardArt

            width: parent.width
            height: width
            corner: 22
        }

        Rectangle {
            visible: w.source !== ""
            x: 10
            y: 10
            width: srcLabel.implicitWidth + 18
            height: 24
            radius: 12
            color: Theme.alpha(w.fill, 0.85)

            LText {
                id: srcLabel

                anchors.centerIn: parent
                role: "labelSmall"
                color: w.ink
                text: w.source
            }

        }

        Column {
            anchors.top: cardArt.bottom
            anchors.topMargin: 12
            width: parent.width
            spacing: 0

            Marquee {
                width: parent.width
                role: "titleMedium"
                weight: 600
                color: w.ink
                text: w.title
                scrolling: w.scroll
            }

            LText {
                width: parent.width
                role: "bodyMedium"
                color: w.inkDim
                text: w.artist
                elide: Text.ElideRight
            }

        }

        WaveSeek {
            id: cardSeek

            visible: w.showProgress
            opacity: w.has ? 1 : 0.35
            anchors.bottom: cardControls.top
            anchors.bottomMargin: 4
            width: parent.width
            position: w.livePos
            length: w.length
            interactive: w.canSeek
            jumpDuration: w.jumpDuration
            accent: w.inkAccent
            trackColor: Theme.alpha(w.ink, 0.16)
            labelColor: w.inkDim
            onDraggingChanged: w.scrubbing = cardSeek.dragging
            onSeekRequested: (s) => {
                return w.seekTo(s);
            }
        }

        Transport {
            id: cardControls

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            big: 52
        }

    }

    // row: a strip, cover on the left, the track over its controls
    Item {
        visible: w.variant === "row"
        anchors.fill: parent
        anchors.margins: 12

        Cover {
            id: rowArt

            width: parent.height
            height: parent.height
            corner: 18
        }

        Column {
            anchors.left: rowArt.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 2
            spacing: 0

            Marquee {
                width: parent.width
                role: "titleSmall"
                color: w.ink
                text: w.title
                scrolling: w.scroll
            }

            LText {
                width: parent.width
                role: "bodySmall"
                color: w.inkDim
                text: w.artist
                elide: Text.ElideRight
            }

        }

        LinearProgress {
            visible: w.showProgress && w.has
            anchors.left: rowArt.right
            anchors.leftMargin: 14
            anchors.right: rowControls.left
            anchors.rightMargin: 10
            anchors.verticalCenter: rowControls.verticalCenter
            value: w.progress
            thickness: 4
            animated: false
            color: w.inkAccent
            trackColor: Theme.alpha(w.ink, 0.14)
        }

        Transport {
            id: rowControls

            anchors.right: parent.right
            anchors.rightMargin: -6
            anchors.bottom: parent.bottom
            spacing: 0
            big: 38
        }

    }

    // art: the cover edge to edge, the track over a scrim
    Item {
        visible: w.variant === "art"
        anchors.fill: parent

        Cover {
            anchors.fill: parent
            corner: w.corner
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.5
            bottomLeftRadius: w.corner
            bottomRightRadius: w.corner

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(w.fill, 0.94)
                }

            }

        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: artPlay.left
            anchors.rightMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 0

            Marquee {
                width: parent.width
                role: "titleSmall"
                color: w.ink
                text: w.title
                scrolling: w.scroll
            }

            LText {
                width: parent.width
                role: "bodySmall"
                color: w.inkDim
                text: w.artist
                elide: Text.ElideRight
            }

        }

        Rectangle {
            id: artPlay

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: 48
            height: 48
            radius: artTap.pressed ? 14 : 24
            color: w.inkAccent

            Icon {
                anchors.centerIn: parent
                name: w.playing ? "pause" : "play_arrow"
                size: 26
                fill: 1
                color: w.onInkAccent
            }

            StateLayer {
                id: artTap

                radius: parent.radius
                tint: w.onInkAccent
                onClicked: w.toggle()
            }

        }

        Rectangle {
            visible: w.showProgress && w.has
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: w.corner
            width: (parent.width - w.corner * 2) * w.progress
            height: 3
            radius: 1.5
            color: w.inkAccent
        }

    }

    // disc: the cover as a record that turns while it plays, ringed by the track's progress
    Item {
        id: disc

        visible: w.variant === "disc"
        anchors.fill: parent

        CircularProgress {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - 16
            height: width
            thickness: 6
            value: w.progress
            animated: false
            color: w.inkAccent
            trackColor: Theme.alpha(w.ink, 0.14)
        }

        ShapedImage {
            id: record

            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - 40
            height: width
            shape: "cookie12"
            source: w.artUrl
            fallbackColor: Theme.alpha(w.ink, 0.1)

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: w.playing && w.visible && !w.preview
            }

            Icon {
                anchors.centerIn: parent
                name: "album"
                size: record.width * 0.4
                color: w.inkFaint
            }

        }

        Rectangle {
            anchors.centerIn: parent
            width: 56
            height: 56
            radius: discTap.pressed ? 16 : 28
            color: w.inkAccent
            opacity: w.hovered || !w.playing ? 1 : 0
            scale: w.hovered || !w.playing ? 1 : 0.7

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durDefaultEffects
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

            Icon {
                anchors.centerIn: parent
                name: w.playing ? "pause" : "play_arrow"
                size: 30
                fill: 1
                color: w.onInkAccent
            }

            StateLayer {
                id: discTap

                radius: parent.radius
                tint: w.onInkAccent
                onClicked: w.toggle()
            }

        }

    }

}
