import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.lucidui
import "parts"

// whatever is playing, with just enough control to skip a track without
// unlocking the machine: a card, a compact pill, the cover up big, or the
// deck, the deck preset's hero
WidgetBase {
    id: lm

    readonly property string style: lm.opts.style || "card"
    readonly property bool ownCard: !lm.carded
    readonly property real cardW: lm.carded ? lm.avail : Math.min(lm.avail, Theme.dp(lm.style === "compact" ? 380 : 440))

    readonly property var players: Mpris.players.values
    // the one the user is most likely to mean
    readonly property var player: {
        for (var i = 0; i < lm.players.length; i++) {
            if (lm.players[i].playbackState === MprisPlaybackState.Playing)
                return lm.players[i];

        }
        return lm.players.length > 0 ? lm.players[0] : null;
    }
    readonly property bool playing: !!lm.player && lm.player.playbackState === MprisPlaybackState.Playing
    // the editor shows the card's empty state, so its place can be seen
    readonly property string title: lm.player ? (lm.player.trackTitle || I18n.tr("Unknown track")) : I18n.tr("Nothing playing")
    readonly property string artist: lm.player ? (lm.player.trackArtist || lm.player.identity || "") : I18n.tr("Music shows up here as it plays")
    readonly property real length: lm.player ? lm.player.length : 0
    // a remote cover through the cache, never straight into the Image: Qt's
    // own http/2 client is what has been crashing the shell
    readonly property string artUrl: lm.player ? (lm.player.trackArtUrl || "") : ""
    readonly property bool remoteArt: /^https?:/.test(lm.artUrl)
    readonly property string artFile: {
        if (!lm.remoteArt)
            return "";

        var h = 5381;
        for (var i = 0; i < lm.artUrl.length; i++) h = ((h * 33) ^ lm.artUrl.charCodeAt(i)) >>> 0
        return Quickshell.env("HOME") + "/.cache/lucid/art/" + h.toString(16) + ".img";
    }
    property string localArt: ""
    readonly property string artSource: lm.remoteArt ? lm.localArt : lm.artUrl

    // the last cover stays up until the next one is on disk
    function fetchCover() {
        if (lm.artFile === "") {
            lm.localArt = "";
            return ;
        }
        // handed over here: a command bound to artFile is still the old one in onArtFileChanged
        artFetch.superseded = artFetch.running;
        artFetch.file = lm.artFile;
        artFetch.running = false;
        artFetch.command = ["sh", "-c", artFetch.script, "sh", lm.artFile, lm.artUrl];
        artFetch.running = true;
    }

    onArtFileChanged: lm.fetchCover()
    Component.onCompleted: lm.fetchCover()

    Process {
        id: artFetch

        property string file: ""
        // a run cut short by the next fetch still reports, before that one starts
        property bool superseded: false
        readonly property string script: "f=\"$1\"; d=\"$(dirname \"$f\")\"; mkdir -p \"$d\"; find \"$d\" -name '*.img' -mtime +14 -delete 2>/dev/null; [ -s \"$f\" ] || { t=\"$f.$$\"; curl -sfL --max-time 10 -o \"$t\" \"$2\" && mv \"$t\" \"$f\" || rm -f \"$t\"; }; [ -s \"$f\" ]"

        onExited: (code) => {
            if (artFetch.superseded) {
                artFetch.superseded = false;
                return ;
            }
            lm.localArt = code === 0 ? "file://" + artFetch.file : "";
        }
    }
    property real livePos: 0
    property double posStamp: 0
    readonly property real progress: lm.length > 0 ? Math.min(1, lm.livePos / lm.length) : 0

    function fmt(sec) {
        var s = Math.max(0, Math.floor(sec));
        var m = Math.floor(s / 60);
        var r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    hasContent: lm.player !== null || lm.editing
    implicitWidth: lm.style === "deck" ? deck.width : (lm.style === "cover" ? coverCard.width : (lm.style === "compact" ? pill.width : card.width))
    implicitHeight: lm.style === "deck" ? deck.height : (lm.style === "cover" ? coverCard.height : (lm.style === "compact" ? pill.height : card.height))

    Connections {
        function onPositionChanged() {
            lm.posStamp = Date.now();
            lm.livePos = lm.player.position;
        }

        target: lm.player
        ignoreUnknownSignals: true
    }

    // mpris only volunteers a position when asked, so ask, then coast between
    Timer {
        running: Lockscreen.live && lm.playing
        interval: 1000
        repeat: true
        onTriggered: {
            if (lm.player)
                lm.player.positionChanged();

        }
    }

    Timer {
        running: Lockscreen.live && lm.playing && lm.style !== "compact"
        interval: 50
        repeat: true
        onTriggered: lm.livePos = Math.min(lm.length, lm.player.position + (Date.now() - lm.posStamp) / 1000)
    }

    // ── card ────────────────────────────────────────────────────────────────
    Rectangle {
        id: card

        readonly property real pad: lm.ownCard ? Theme.dp(18) : 0

        x: lm.xFor(width, lm.width)
        visible: lm.style === "card"
        width: lm.cardW
        height: Theme.dp(lm.ownCard ? 124 : 92)
        radius: Theme.shapeXl
        color: lm.ownCard ? (lm.onCard ? Lockscreen.cardHigh : Lockscreen.card) : "transparent"

        LockMediaArt {
            media: lm
            id: cardArt

            x: card.pad
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(84)
            radius: Theme.shapeLg
        }

        LockMediaTransport {
            media: lm
            id: cardTransport

            anchors.right: parent.right
            anchors.rightMargin: card.pad > 0 ? Theme.dp(14) : 0
            anchors.verticalCenter: parent.verticalCenter
            big: Theme.dp(40)
        }

        Column {
            anchors.left: cardArt.right
            anchors.leftMargin: Theme.dp(16)
            anchors.right: cardTransport.left
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(8)

            LockMediaTitles {
                media: lm
                width: parent.width
            }

            LockMediaSeek {
                media: lm
                width: parent.width
            }

        }

    }

    // ── compact: a pill with the cover, the title and play ──────────────────
    Rectangle {
        id: pill

        x: lm.xFor(width, lm.width)
        visible: lm.style === "compact"
        width: lm.cardW
        height: Theme.dp(64)
        radius: height / 2
        color: lm.ownCard ? (lm.onCard ? Lockscreen.cardHigh : Lockscreen.card) : "transparent"

        LockMediaArt {
            media: lm
            id: pillArt

            x: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(44)
            radius: height / 2
        }

        LockMediaTransport {
            media: lm
            id: pillTransport

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            big: Theme.dp(34)
        }

        LockMediaTitles {
            media: lm
            anchors.left: pillArt.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: pillTransport.left
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            titleSize: Theme.fontLabelLg
        }

    }

    // ── cover: the art up big, everything under it ──────────────────────────
    Rectangle {
        id: coverCard

        readonly property real pad: lm.ownCard ? Theme.dp(18) : 0
        readonly property real artSize: Math.min(Theme.dp(300), lm.cardW - coverCard.pad * 2)

        x: lm.xFor(width, lm.width)
        visible: lm.style === "cover"
        width: coverCol.width + coverCard.pad * 2
        height: coverCol.height + coverCard.pad * 2
        radius: Theme.shapeXl
        color: lm.ownCard ? (lm.onCard ? Lockscreen.cardHigh : Lockscreen.card) : "transparent"

        Column {
            id: coverCol

            x: coverCard.pad
            y: coverCard.pad
            width: coverCard.artSize
            spacing: Theme.dp(12)

            LockMediaArt {
                media: lm
                size: coverCard.artSize
                radius: Theme.shapeXl - coverCard.pad / 2
            }

            LockMediaTitles {
                media: lm
                width: parent.width
                titleSize: Theme.fontTitleMd
                align: Text.AlignHCenter
            }

            LockMediaSeek {
                media: lm
                width: parent.width
            }

            LockMediaTransport {
                media: lm
                anchors.horizontalCenter: parent.horizontalCenter
                big: Theme.dp(44)
            }

        }

    }


    // ── deck: the cover cut to a cookie inside a ring of the track's progress,
    // the title in display type beside it, and a play button of the same shape
    Item {
        id: deck

        readonly property real art: Math.round(Math.min(Theme.dp(360), lm.avail * 0.4))
        readonly property real ring: deck.art + Theme.dp(48)
        readonly property real gap: Theme.dp(64)
        readonly property real textW: Math.round(Math.max(Theme.dp(260), Math.min(Theme.dp(620), lm.avail - deck.ring - deck.gap)))
        readonly property int titlePx: Math.round(Theme.fontDisplayLg * 1.75)
        readonly property string source: lm.player ? (lm.player.identity || "") : ""

        x: lm.xFor(width, lm.width)
        visible: lm.style === "deck"
        width: deck.ring + deck.gap + deck.textW
        height: Math.max(deck.ring, deckText.height)

        Item {
            y: (deck.height - height) / 2
            width: deck.ring
            height: deck.ring

            // only the played part waves, and only while it plays
            CircularProgress {
                anchors.fill: parent
                value: lm.progress
                thickness: Theme.dp(8)
                color: Theme.accent
                trackColor: Theme.alpha(Theme.text, 0.14)
                // mpris hands over a fresh position many times a second: easing
                // each one would only drag the ring behind the song
                animated: false
                wavy: lm.playing
            }

            ShapedImage {
                id: deckArt

                anchors.centerIn: parent
                width: deck.art
                height: deck.art
                shape: "cookie9"
                source: lm.artSource
                fallbackColor: Theme.accentContainer
                decode: 600

                Glyph {
                    anchors.centerIn: parent
                    name: "music_note"
                    size: deck.art * 0.34
                    color: Theme.fgAccentContainer
                }

            }

            // the scallops turn while it plays, a record on the platter: one
            // scallop's turn is the whole shape again, so the loop has no seam
            NumberAnimation {
                target: deckArt
                property: "spin"
                from: 0
                to: 40
                duration: 9000
                loops: Animation.Infinite
                running: deck.visible && lm.playing && Lockscreen.live
            }

        }

        Column {
            id: deckText

            x: deck.ring + deck.gap
            y: (deck.height - height) / 2
            width: deck.textW
            spacing: Theme.dp(8)

            Text {
                width: parent.width
                text: lm.player ? I18n.tr("NOW PLAYING") + (deck.source !== "" ? "  ·  " + deck.source.toUpperCase() : "") : I18n.tr("MEDIA")
                color: Theme.accent
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleSm
                font.variableAxes: Theme.axes(Theme.fontTitleSm, 640, 0)
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.dp(2.2)
            }

            Text {
                width: parent.width
                topPadding: Theme.dp(4)
                text: lm.title
                color: Theme.text
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 0.92
                font.family: Theme.fontFamily
                font.pixelSize: deck.titlePx
                font.variableAxes: Theme.axes(deck.titlePx, 580, 0)
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: lm.artist
                color: Theme.subtext
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineMd
                font.variableAxes: Theme.axes(Theme.fontHeadlineMd, 440, 0)
            }

            Text {
                text: lm.fmt(lm.livePos) + "  /  " + lm.fmt(lm.length)
                visible: lm.length > 0
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleMd
                font.variableAxes: Theme.axes(Theme.fontTitleMd, 460, 0)
                font.features: {
                    "tnum": 1
                }
            }

            Item {
                width: 1
                height: Theme.dp(14)
            }

            Row {
                spacing: Theme.dp(16)

                LockIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    diameter: Theme.dp(72)
                    glyphSize: Theme.dp(32)
                    glyph: "prev"
                    glyphColor: Theme.text
                    baseColor: Lockscreen.card
                    actionable: !!lm.player && lm.player.canGoPrevious && !lm.editing
                    onClicked: lm.player.previous()
                }

                // play on the cover's own shape; a pause rounds it to a circle
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(104)
                    height: Theme.dp(104)
                    scale: playTap.pressed ? 0.92 : (playHover.hovered ? 1.04 : 1)

                    MaterialShape {
                        anchors.fill: parent
                        shape: "cookie9"
                        to: "circle"
                        morph: lm.playing ? 0 : 1
                        spin: deckArt.spin
                        color: playHover.hovered ? Theme.accentHover : Theme.accent

                        Behavior on morph {
                            NumberAnimation {
                                duration: Theme.ms(420)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                    }

                    LockGlyph {
                        anchors.centerIn: parent
                        name: lm.playing ? "pause" : "play"
                        size: Theme.dp(44)
                        color: Theme.fgAccent
                    }

                    HoverHandler {
                        id: playHover

                        enabled: !lm.editing
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: playTap

                        enabled: !!lm.player && lm.player.canTogglePlaying && !lm.editing
                        onTapped: lm.player.togglePlaying()
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.ms(160)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                LockIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    diameter: Theme.dp(72)
                    glyphSize: Theme.dp(32)
                    glyph: "next"
                    glyphColor: Theme.text
                    baseColor: Lockscreen.card
                    actionable: !!lm.player && lm.player.canGoNext && !lm.editing
                    onClicked: lm.player.next()
                }

            }

        }

    }

}
