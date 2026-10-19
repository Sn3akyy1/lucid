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
    onArtUrlChanged: w.localArt = ""
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
    // the shapes a cover is cut to; a track always gets the same one
    readonly property var coverShapes: ["cookie9", "clover4", "sunny", "flower", "pentagon", "softBurst", "cookie12", "clover8"]
    readonly property string trackShape: {
        var key = w.title + "\u0001" + w.artist;
        var h = 5381;
        for (var i = 0; i < key.length; i++) h = ((h * 33) ^ key.charCodeAt(i)) >>> 0
        return w.coverShapes[h % w.coverShapes.length];
    }
    readonly property string artFile: {
        if (!w.remoteArt)
            return "";

        var h = 5381;
        for (var i = 0; i < w.artUrl.length; i++) h = ((h * 33) ^ w.artUrl.charCodeAt(i)) >>> 0
        return Quickshell.env("HOME") + "/.cache/lucid/art/" + h.toString(16) + ".img";
    }
    property string localArt: ""
    // what every image on the card shows: the cached copy for a remote cover,
    // the url as it is for a local one
    readonly property string artSource: w.remoteArt ? w.localArt : w.artUrl

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

    // the player's own window, or play and pause when it has none to show
    function raisePlayer() {
        if (w.has && w.player.canRaise)
            w.player.raise();
        else
            w.toggle();
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

    bare: w.variant === "orbit" || w.variant === "shape"
    pill: w.variant === "pill" || w.variant === "capsule"
    ownInk: w.artTint
    fill: w.artTint ? Theme.withBlur(Theme.atTone(w.seedVivid, Theme.isLight ? 90 : 22)) : w.toneFill
    ink: w.artTint ? Theme.atTone(w.seedVivid, Theme.isLight ? 12 : 94) : w.toneInk
    inkAccent: w.artTint ? Theme.atTone(w.seedVivid, Theme.isLight ? 40 : 80) : w.toneInkAccent
    fgInkAccent: w.artTint ? Theme.atTone(w.seedVivid, Theme.isLight ? 98 : 16) : w.toneOnInkAccent
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

    Behavior on fgInkAccent {
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

    // every cover goes through the local copy: a remote one handed straight to
    // an Image makes Qt speak http/2 itself, which is where the shell has
    // crashed. the tint needs it, so it was fetched for the tint alone before
    function fetchCover() {
        w.localArt = "";
        if (w.artFile !== "" && !w.preview) {
            fetchArt.running = false;
            fetchArt.running = true;
        }
    }

    // track changed on the player -> immediately clear cached art and refetch
    Connections {
        function onTrackChanged() {
            w.fetchCover();
        }

        target: w.player
        ignoreUnknownSignals: true
    }

    onArtFileChanged: w.fetchCover()
    Component.onCompleted: w.fetchCover()

    Process {
        id: fetchArt

        command: ["sh", "-c", "f=\"$1\"; d=\"$(dirname \"$f\")\"; mkdir -p \"$d\"; find \"$d\" -name '*.img' -mtime +14 -delete 2>/dev/null; [ -s \"$f\" ] || { t=\"$f.$$\"; curl -sfL --max-time 10 -o \"$t\" \"$2\" && mv \"$t\" \"$f\" && sync || rm -f \"$t\"; }; [ -s \"$f\" ]", "sh", w.artFile, w.artUrl]
        onExited: (code) => {
            if (code === 0)
                w.localArt = "file://" + w.artFile;

        }
    }

    ColorQuantizer {
        id: quant

        source: w.artSource
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

        property real corner: Theme.dp(20)

        radius: cov.corner
        color: Theme.alpha(w.ink, 0.08)

        Image {
            id: covImg

            anchors.fill: parent
            source: w.artSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Theme.dp(512)
            sourceSize.height: Theme.dp(512)
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

        property real big: Theme.dp(56)
        property bool showPrev: true

        spacing: Theme.dp(8)

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
            // the state layer alone barely shows on a saturated fill, so the pill
            // swells under the pointer as well
            scale: playTap.pressed ? 0.96 : (playTap.containsMouse ? 1.05 : 1)

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

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
                color: w.fgInkAccent
            }

            StateLayer {
                id: playTap

                radius: parent.radius
                tint: w.fgInkAccent
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

    // play and pause on a shape: round while it waits, squared off while it plays
    component PlayShape: Item {
        id: ps

        property real size: Theme.dp(56)

        width: ps.size
        height: ps.size
        opacity: w.has ? 1 : 0.4

        MaterialShape {
            anchors.fill: parent
            shape: "circle"
            to: "square"
            morph: w.playing ? 1 : 0
            color: w.inkAccent
            scale: psArea.pressed ? 0.92 : (psArea.containsMouse ? 1.06 : 1)

            Behavior on morph {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveStandard
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

        }

        Icon {
            anchors.centerIn: parent
            name: w.playing ? "pause" : "play_arrow"
            size: Math.round(ps.size * 0.46)
            fill: 1
            color: w.fgInkAccent
        }

        MouseArea {
            id: psArea

            anchors.fill: parent
            enabled: w.has
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: w.toggle()
        }

    }

    // a skip on a small circle that blooms into a cookie under the pointer
    component SkipShape: Item {
        id: sk

        property int dir: 1
        property real size: Theme.dp(40)
        property color fillColor: Theme.alpha(w.inkAccent, 0.16)
        property color inkColor: w.inkAccent
        readonly property bool able: w.has && (sk.dir > 0 ? w.player.canGoNext : w.player.canGoPrevious)

        width: sk.size
        height: sk.size
        opacity: sk.able ? 1 : 0.4

        MaterialShape {
            anchors.fill: parent
            shape: "circle"
            to: "cookie9"
            morph: skArea.containsMouse ? 1 : 0
            color: sk.fillColor
            rotation: skArea.containsMouse ? 20 : 0
            scale: skArea.pressed ? 0.9 : 1

            Behavior on morph {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveStandard
                }

            }

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.durSlowSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveSlowSpatial
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

        }

        Icon {
            anchors.centerIn: parent
            name: sk.dir > 0 ? "skip_next" : "skip_previous"
            size: Math.round(sk.size * 0.5)
            fill: 1
            color: sk.inkColor
        }

        MouseArea {
            id: skArea

            anchors.fill: parent
            enabled: sk.able
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: w.skip(sk.dir)
        }

    }

    // card: the cover, then the track, a wavy seek and the transport
    Item {
        visible: w.variant === "card"
        anchors.fill: parent
        anchors.margins: Theme.dp(18)

        Cover {
            id: cardArt

            width: parent.width
            height: width
            // follows the card's own corner, so the corner dial rounds both
            corner: Math.round(w.corner * 0.85)
        }

        Rectangle {
            visible: w.source !== ""
            x: Theme.dp(10)
            y: Theme.dp(10)
            width: srcLabel.implicitWidth + Theme.dp(18)
            height: Theme.dp(24)
            radius: Theme.dp(12)
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
            anchors.topMargin: Theme.dp(12)
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
            anchors.bottomMargin: Theme.dp(4)
            width: parent.width
            position: w.livePos
            length: w.length
            interactive: w.canSeek
            playing: w.playing
            flowing: !w.preview
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
            big: Theme.dp(52)
        }

    }

    // row: a strip, cover on the left, the track over its controls
    Item {
        visible: w.variant === "row"
        anchors.fill: parent
        anchors.margins: Theme.dp(12)

        Cover {
            id: rowArt

            width: parent.height
            height: parent.height
            corner: Theme.dp(18)
        }

        Column {
            anchors.left: rowArt.right
            anchors.leftMargin: Theme.dp(14)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Theme.dp(2)
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
            anchors.leftMargin: Theme.dp(14)
            anchors.right: rowControls.left
            anchors.rightMargin: Theme.dp(10)
            anchors.verticalCenter: rowControls.verticalCenter
            value: w.progress
            thickness: Theme.dp(4)
            animated: false
            color: w.inkAccent
            trackColor: Theme.alpha(w.ink, 0.14)
        }

        Transport {
            id: rowControls

            anchors.right: parent.right
            anchors.rightMargin: -Theme.dp(6)
            anchors.bottom: parent.bottom
            spacing: 0
            big: Theme.dp(38)
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
            anchors.leftMargin: Theme.dp(16)
            anchors.right: artPlay.left
            anchors.rightMargin: Theme.dp(10)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(18)
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
            anchors.rightMargin: Theme.dp(14)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(14)
            width: Theme.dp(48)
            height: Theme.dp(48)
            radius: artTap.pressed ? Theme.dp(14) : Theme.dp(24)
            color: w.inkAccent
            scale: artTap.pressed ? 0.96 : (artTap.containsMouse ? 1.05 : 1)

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
                size: Theme.dp(26)
                fill: 1
                color: w.fgInkAccent
            }

            StateLayer {
                id: artTap

                radius: parent.radius
                tint: w.fgInkAccent
                onClicked: w.toggle()
            }

        }

        Rectangle {
            visible: w.showProgress && w.has
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: w.corner
            width: (parent.width - w.corner * 2) * w.progress
            height: Theme.dp(3)
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
            width: Math.min(parent.width, parent.height) - Theme.dp(16)
            height: width
            thickness: Theme.dp(6)
            value: w.progress
            animated: false
            color: w.inkAccent
            trackColor: Theme.alpha(w.ink, 0.14)
        }

        ShapedImage {
            id: record

            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - Theme.dp(40)
            height: width
            shape: "cookie12"
            source: w.artSource
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
            width: Theme.dp(56)
            height: Theme.dp(56)
            radius: discTap.pressed ? Theme.dp(16) : Theme.dp(28)
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
                size: Theme.dp(30)
                fill: 1
                color: w.fgInkAccent
            }

            StateLayer {
                id: discTap

                radius: parent.radius
                tint: w.fgInkAccent
                onClicked: w.toggle()
            }

        }

    }

    // pill: a capsule, the cover round at one end with the track's progress circling it
    Item {
        visible: w.variant === "pill"
        anchors.fill: parent

        CircularProgress {
            id: pillRing

            x: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - Theme.dp(16)
            height: width
            visible: w.showProgress && w.has
            thickness: Theme.dp(3)
            value: w.progress
            animated: false
            wavy: false
            color: w.inkAccent
            trackColor: Theme.alpha(w.ink, 0.14)
        }

        ShapedImage {
            id: pillArt

            anchors.centerIn: pillRing
            width: pillRing.width - Theme.dp(12)
            height: width
            shape: "circle"
            source: w.artSource
            fallbackColor: Theme.alpha(w.ink, 0.1)

            Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: Math.round(pillArt.width * 0.4)
                fill: 1
                color: w.inkFaint
            }

        }

        WidgetTap {
            anchors.fill: pillArt
            widget: w
            onTapped: w.raisePlayer()
        }

        Column {
            anchors.left: pillRing.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: pillPlay.left
            anchors.rightMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Marquee {
                width: parent.width
                role: "titleSmall"
                weight: 600
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

        PlayShape {
            id: pillPlay

            anchors.right: pillNext.left
            anchors.rightMargin: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(56)
        }

        SkipShape {
            id: pillNext

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(16)
            anchors.verticalCenter: parent.verticalCenter
            dir: 1
            size: Theme.dp(40)
        }

    }

    // orbit: a round face, the cover at its heart, the track a wavy ring and the controls along its foot
    Item {
        id: orbit

        readonly property real d: Math.min(width, height)

        visible: w.variant === "orbit"
        anchors.fill: parent

        MaterialShape {
            anchors.centerIn: parent
            width: orbit.d
            height: orbit.d
            shape: "circle"
            color: Theme.alpha(w.fill, 1)
        }

        CircularProgress {
            anchors.centerIn: parent
            width: orbit.d - Math.round(orbit.d * 0.05)
            height: width
            visible: w.showProgress && w.has
            thickness: Math.round(orbit.d * 0.034)
            value: w.progress
            animated: false
            color: w.inkAccent
            trackColor: Theme.alpha(w.ink, 0.14)
        }

        Rectangle {
            readonly property real maxW: Math.round(orbit.d * 0.46)

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(orbit.height / 2 - orbit.d * 0.32 - height / 2)
            width: Math.min(Math.ceil(orbitMetrics.advanceWidth) + Theme.dp(20), maxW)
            height: Theme.dp(24)
            radius: height / 2
            color: Theme.alpha(w.inkAccent, 0.16)

            TextMetrics {
                id: orbitMetrics

                font: orbitTitle.font
                text: orbitTitle.text
            }

            LText {
                id: orbitTitle

                anchors.centerIn: parent
                width: parent.width - Theme.dp(20)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                role: "labelMedium"
                weight: 600
                color: w.ink
                text: w.title
            }

        }

        ShapedImage {
            id: orbitArt

            x: Math.round((orbit.width - width) / 2)
            y: Math.round(orbit.height / 2 - orbit.d * 0.233)
            width: Math.round(orbit.d * 0.5)
            height: width
            shape: "circle"
            source: w.artSource
            decode: Theme.dp(256)
            fallbackColor: Theme.alpha(w.ink, 0.1)

            Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: Math.round(orbitArt.width * 0.36)
                fill: 1
                color: w.inkFaint
            }

        }

        WidgetTap {
            anchors.fill: orbitArt
            widget: w
            onTapped: w.raisePlayer()
        }

        PlayShape {
            x: Math.round(orbit.width / 2 - width / 2)
            y: Math.round(orbitArt.y + orbitArt.height - height / 2)
            size: Math.round(orbit.d * 0.22)
        }

        SkipShape {
            x: Math.round(orbit.width / 2 - orbit.d * 0.242 - width / 2)
            y: Math.round(orbit.height / 2 + orbit.d * 0.25 - height / 2)
            dir: -1
            size: Math.round(orbit.d * 0.158)
        }

        SkipShape {
            x: Math.round(orbit.width / 2 + orbit.d * 0.242 - width / 2)
            y: Math.round(orbit.height / 2 + orbit.d * 0.25 - height / 2)
            dir: 1
            size: Math.round(orbit.d * 0.158)
        }

    }

    // shape: the cover cut to a shape of its own, a new one easing in with every track
    Item {
        id: blobFace

        visible: w.variant === "shape"
        anchors.fill: parent

        ShapedImage {
            id: blob

            // the shape on show; the track's own eases in over it, then takes its place
            property string shown: "cookie9"

            x: Theme.dp(8)
            y: Theme.dp(4)
            width: blobFace.width - Theme.dp(16)
            height: width
            shape: blob.shown
            to: w.trackShape
            source: w.artSource
            decode: Theme.dp(384)
            fallbackColor: Theme.alpha(w.fill, 1)
            Component.onCompleted: blob.shown = w.trackShape

            Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: Math.round(blob.width * 0.32)
                fill: 1
                color: w.inkFaint
            }

        }

        NumberAnimation {
            id: blobMorph

            target: blob
            property: "morph"
            from: 0
            to: 1
            duration: Theme.durSlowSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
            onFinished: {
                blob.shown = w.trackShape;
                blob.morph = 0;
            }
        }

        Connections {
            function onTrackShapeChanged() {
                if (blob.shown === w.trackShape)
                    return ;

                if (blobFace.visible)
                    blobMorph.restart();
                else
                    blob.shown = w.trackShape;
            }

            target: w
        }

        WidgetTap {
            anchors.fill: blob
            widget: w
            onTapped: w.raisePlayer()
        }

        PlayShape {
            x: Math.round(blob.x + blob.width * 0.8 - width / 2)
            y: Math.round(blob.y + blob.height * 0.8 - height / 2)
            size: Theme.dp(64)
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(12)
            anchors.right: blobSkips.left
            anchors.rightMargin: Theme.dp(8)
            y: blob.y + blob.height + Theme.dp(10)
            spacing: Theme.dp(2)

            ShadowText {
                width: parent.width
                elide: Text.ElideRight
                shadow: true
                pixelSize: Theme.dp(17)
                weight: 600
                color: "white"
                text: w.title
            }

            ShadowText {
                width: parent.width
                elide: Text.ElideRight
                shadow: true
                pixelSize: Theme.dp(13)
                weight: 480
                color: Qt.rgba(1, 1, 1, 0.82)
                text: w.artist
            }

            LinearProgress {
                visible: w.showProgress && w.has
                width: parent.width
                value: w.progress
                wavy: true
                flowing: w.playing
                valueAnimated: false
                thickness: Theme.dp(3)
                amplitude: Theme.dp(2)
                wavelength: Theme.dp(18)
                color: "white"
                trackColor: Qt.rgba(1, 1, 1, 0.28)
            }

        }

        Row {
            id: blobSkips

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            y: blob.y + blob.height + Theme.dp(10)
            spacing: Theme.dp(6)

            SkipShape {
                dir: -1
                size: Theme.dp(38)
                fillColor: Theme.alpha(w.fill, 1)
                inkColor: w.ink
            }

            SkipShape {
                dir: 1
                size: Theme.dp(38)
                fillColor: Theme.alpha(w.fill, 1)
                inkColor: w.ink
            }

        }

    }

    // capsule: a tall pill, the cover round at the top and the track turned on its side
    Item {
        id: capsule

        visible: w.variant === "capsule"
        anchors.fill: parent

        ShapedImage {
            id: capArt

            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.dp(12)
            width: capsule.width - Theme.dp(24)
            height: width
            shape: "circle"
            source: w.artSource
            fallbackColor: Theme.alpha(w.ink, 0.1)

            Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: Math.round(capArt.width * 0.4)
                fill: 1
                color: w.inkFaint
            }

        }

        WidgetTap {
            anchors.fill: capArt
            widget: w
            onTapped: w.raisePlayer()
        }

        // read upward, the progress running beside the words
        Item {
            readonly property real spanFrom: capArt.y + capArt.height + Theme.dp(14)
            readonly property real spanTo: capNext.y - Theme.dp(14)

            x: Math.round(capsule.width / 2 - width / 2)
            y: Math.round((spanFrom + spanTo) / 2 - height / 2)
            width: Math.max(0, spanTo - spanFrom)
            height: Theme.dp(58)
            rotation: -90

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: Theme.dp(2)

                Marquee {
                    width: parent.width
                    role: "titleSmall"
                    weight: 600
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

                LinearProgress {
                    visible: w.showProgress && w.has
                    width: parent.width
                    value: w.progress
                    wavy: true
                    flowing: w.playing
                    valueAnimated: false
                    thickness: Theme.dp(3)
                    amplitude: Theme.dp(2)
                    wavelength: Theme.dp(18)
                    color: w.inkAccent
                    trackColor: Theme.alpha(w.ink, 0.14)
                }

            }

        }

        SkipShape {
            id: capNext

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: capPlay.top
            anchors.bottomMargin: Theme.dp(8)
            dir: 1
            size: Theme.dp(44)
        }

        PlayShape {
            id: capPlay

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(14)
            size: capsule.width - Theme.dp(28)
        }

    }

}
