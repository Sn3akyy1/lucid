import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs

WidgetBody {
    id: w

    readonly property var players: {
        var out = [];
        var list = Mpris.players.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].dbusName && list[i].dbusName.indexOf("playerctld") !== -1)
                continue;

            out.push(list[i]);
        }
        return out;
    }
    readonly property var player: {
        var list = w.players;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i];

        }
        return list.length > 0 ? list[0] : null;
    }
    readonly property bool has: w.player !== null
    readonly property bool playing: w.has ? w.player.isPlaying : false
    readonly property string title: w.has ? (w.player.trackTitle || "Unknown track") : "Nothing playing"
    readonly property string artist: w.has ? (w.player.trackArtist || w.player.identity || "") : "Start something and it lands here"
    readonly property string artUrl: w.has ? (w.player.trackArtUrl || "") : ""
    readonly property real length: w.has ? w.player.length : 0
    readonly property real position: w.has ? w.player.position : 0
    // mpris reports position in 1s steps, so interpolate between them or the wave stutters
    property real livePos: w.position
    property real posBase: w.position
    property double posStamp: Date.now()
    property int jumpDuration: 0
    property bool snapNext: false
    readonly property bool canSeek: w.has && w.player.canSeek
    readonly property real progress: w.length > 0 ? Math.max(0, Math.min(1, w.livePos / w.length)) : 0
    readonly property bool showProgress: w.opt("showProgress") !== false
    // set by whichever seek control is being dragged: the interpolator below
    // must stop, or it fights the scrub
    property bool scrubbing: false
    readonly property bool scroll: w.opt("scroll") !== false

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

    function clock(secs) {
        if (!secs || secs < 0)
            return "0:00";

        var m = Math.floor(secs / 60);
        var s = Math.floor(secs % 60);
        return m + ":" + String(s).padStart(2, "0");
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

    FrameAnimation {
        running: w.playing && w.showProgress && !w.preview && !w.scrubbing
        onTriggered: w.livePos = Math.min(w.length, w.posBase + (Date.now() - w.posStamp) / 1000)
    }

    // mpris never ticks position on its own
    Timer {
        interval: 1000
        repeat: true
        running: w.playing && w.showProgress && !w.preview && !w.scrubbing
        onTriggered: {
            if (w.player)
                w.player.positionChanged();

        }
    }

    Item {
        id: cardView

        visible: w.variant === "card"
        anchors.fill: parent
        anchors.margins: 16

        // a cover is square, so give it the card's full width in both directions
        Artwork {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: width
            corner: 16
        }

        Column {
            id: cardText

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: cardSeek.top
            anchors.bottomMargin: 10
            spacing: 1

            Text {
                width: parent.width
                text: w.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: w.artist
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

        }

        WaveSeek {
            id: cardSeek

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: cardControls.top
            anchors.bottomMargin: 8
            position: w.livePos
            length: w.length
            jumpDuration: w.jumpDuration
            interactive: w.canSeek && !w.preview
            onDraggingChanged: w.scrubbing = cardSeek.dragging
            visible: w.showProgress
            height: w.showProgress ? implicitHeight : 0
            onSeekRequested: (sec) => {
                return w.seekTo(sec);
            }
        }

        Controls {
            id: cardControls

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
        }

    }

    Item {
        id: rowView

        visible: w.variant === "row"
        anchors.fill: parent
        anchors.margins: 16

        Artwork {
            id: rowArt

            width: parent.height - (w.showProgress ? 10 : 0)
            height: width
            anchors.left: parent.left
            anchors.top: parent.top
            corner: 13
        }

        Column {
            anchors.left: rowArt.right
            anchors.leftMargin: 14
            anchors.right: rowControls.left
            anchors.rightMargin: 10
            anchors.verticalCenter: rowArt.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: w.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: w.artist
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

        }

        Controls {
            id: rowControls

            anchors.right: parent.right
            anchors.verticalCenter: rowArt.verticalCenter
            k: 0.86
        }

        Meter {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            thickness: 3
            value: w.progress
            fillColor: Theme.accent
            visible: w.showProgress
        }

    }

    Item {
        id: artView

        readonly property real corner: w.host ? w.host.bodyRadius : Theme.radiusXl

        visible: w.variant === "art"
        anchors.fill: parent

        // every overlay lives inside the cover: the frame's card clips to its
        // bounding box only, so a square-cornered child pokes out of the rounding
        Artwork {
            anchors.fill: parent
            corner: artView.corner

            // lifts the centred transport off a bright cover
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.3)
                opacity: w.hovered ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.5
                opacity: w.hovered ? 1 : 0
                visible: opacity > 0.01

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, 0.8)
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 28
                spacing: 1
                opacity: w.hovered ? 1 : 0
                visible: opacity > 0.01

                Text {
                    width: parent.width
                    text: w.title
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: w.artist
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            // sits on the idle badge, so the play button grows in place instead of
            // darting to the bottom of the card the moment the pointer arrives
            Controls {
                anchors.centerIn: parent
                k: 0.9
                overArt: true
                opacity: w.hovered && w.has ? 1 : 0
                visible: opacity > 0.01
                scale: w.hovered ? 1 : 0.9

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

            }

            // paused indicator only: the transport above replaces it on hover
            Rectangle {
                anchors.centerIn: parent
                width: 46
                height: 46
                radius: Theme.rad(23)
                color: Theme.alpha(Theme.bgOpaque, 0.8)
                opacity: (w.has && !w.playing && !w.hovered) ? 1 : 0
                visible: opacity > 0.01
                scale: w.hovered ? 1.12 : 1

                WidgetGlyph {
                    anchors.centerIn: parent
                    name: "play"
                    size: 22
                    color: Theme.text
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

            }

            ArtSeek {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 6
            }

        }

    }

    component Artwork: ClippingRectangle {
        id: art

        property real corner: 14

        radius: art.corner
        color: Theme.alpha(Theme.text, 0.07)

        Image {
            anchors.fill: parent
            source: w.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 320
            sourceSize.height: 320
            visible: w.artUrl !== "" && status === Image.Ready
        }

        WidgetGlyph {
            anchors.centerIn: parent
            name: "media"
            size: Math.min(parent.width, parent.height) * 0.3
            color: Theme.alpha(Theme.text, 0.22)
            visible: w.artUrl === ""
        }

    }

    component Controls: Row {
        id: ctl

        // Item already owns "scale", so the control size multiplier needs its own name
        property real k: 1
        // white-on-scrim, for the transport that sits over the cover
        property bool overArt: false
        readonly property color glyph: ctl.overArt ? "#ffffff" : Theme.text
        readonly property color chip: ctl.overArt ? Theme.alpha("#ffffff", 0.18) : Theme.withBlur(Theme.bgHigh)

        // same spec as the bar's Mpris transport row
        spacing: 10 * ctl.k

        WidgetButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "prev"
            diameter: 30 * ctl.k
            iconSize: 15 * ctl.k
            surface: true
            surfaceColor: ctl.chip
            stateColor: ctl.glyph
            hoverGrow: true
            iconColor: ctl.glyph
            enabled: w.has && w.player.canGoPrevious
            onClicked: w.skip(-1)
        }

        WidgetButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: w.playing ? "pause" : "play"
            diameter: 40 * ctl.k
            iconSize: 19 * ctl.k
            filled: true
            hoverGrow: true
            enabled: w.has
            onClicked: w.toggle()
        }

        WidgetButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "next"
            diameter: 30 * ctl.k
            iconSize: 15 * ctl.k
            surface: true
            surfaceColor: ctl.chip
            stateColor: ctl.glyph
            hoverGrow: true
            iconColor: ctl.glyph
            enabled: w.has && w.player.canGoNext
            onClicked: w.skip(1)
        }

    }

    // the artwork variant's seek strip: a pill over the cover that thickens under
    // the pointer. inset from the edges, or the card's corner radius would clip
    // its ends off and the track would lose its first and last few percent
    component ArtSeek: Item {
        id: strip

        property bool dragging: false
        property real dragProgress: 0
        readonly property bool active: strip.dragging || hit.containsMouse
        readonly property real shown: strip.dragging ? strip.dragProgress : w.progress
        readonly property real thickness: strip.active ? 6 : 3

        function fractionAt(px) {
            return Math.max(0, Math.min(1, px / Math.max(1, strip.width)));
        }

        // taller than it paints: a 3px line is not a hit target
        implicitHeight: 22
        // dragging keeps it up if the pointer wanders off the card mid-scrub
        opacity: (w.hovered || strip.dragging) ? 1 : 0
        visible: w.showProgress && w.has && strip.opacity > 0.01
        onDraggingChanged: w.scrubbing = strip.dragging

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: strip.thickness
            radius: height / 2
            color: Theme.alpha("#ffffff", strip.active ? 0.34 : 0.24)

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(parent.height, parent.width * strip.shown)
                height: parent.height
                radius: height / 2
                color: Theme.accent

                Behavior on width {
                    enabled: !strip.dragging

                    NumberAnimation {
                        duration: Theme.ms(w.jumpDuration)
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Theme.easeStandard
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

        MouseArea {
            id: hit

            anchors.fill: parent
            enabled: w.canSeek && !w.preview
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // otherwise the frame's drag handler steals the gesture mid-scrub
            preventStealing: true
            onPressed: (mouse) => {
                strip.dragging = true;
                strip.dragProgress = strip.fractionAt(mouse.x);
            }
            onPositionChanged: (mouse) => {
                if (strip.dragging)
                    strip.dragProgress = strip.fractionAt(mouse.x);

            }
            onReleased: {
                w.seekTo(strip.dragProgress * w.length);
                strip.dragging = false;
            }
            onCanceled: strip.dragging = false
            onWheel: (wheel) => {
                return w.seekTo(w.livePos + (wheel.angleDelta.y > 0 ? 5 : -5));
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

}
