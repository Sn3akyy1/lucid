import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.lucidui

// whatever is playing, with just enough control to skip a track without
// unlocking the machine
Rectangle {
    id: media

    readonly property var players: Mpris.players.values
    // the one the user is most likely to mean
    readonly property var player: {
        for (var i = 0; i < media.players.length; i++) {
            if (media.players[i].playbackState === MprisPlaybackState.Playing)
                return media.players[i];

        }
        return media.players.length > 0 ? media.players[0] : null;
    }
    readonly property bool playing: !!media.player && media.player.playbackState === MprisPlaybackState.Playing
    readonly property string title: media.player ? (media.player.trackTitle || "Unknown track") : ""
    readonly property string artist: media.player ? (media.player.trackArtist || media.player.identity || "") : ""
    readonly property real length: media.player ? media.player.length : 0
    property real livePos: 0
    property double posStamp: 0
    readonly property real progress: media.length > 0 ? Math.min(1, media.livePos / media.length) : 0

    function fmt(sec) {
        var s = Math.max(0, Math.floor(sec));
        var m = Math.floor(s / 60);
        var r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    visible: media.player !== null
    radius: Theme.shapeXl
    color: Lockscreen.card
    implicitHeight: Theme.dp(124)

    Connections {
        function onPositionChanged() {
            media.posStamp = Date.now();
            media.livePos = media.player.position;
        }

        target: media.player
        ignoreUnknownSignals: true
    }

    // mpris only volunteers a position when asked, so ask, then coast between
    Timer {
        running: Lockscreen.locked && media.playing
        interval: 1000
        repeat: true
        onTriggered: {
            if (media.player)
                media.player.positionChanged();

        }
    }

    Timer {
        running: Lockscreen.locked && media.playing
        interval: 50
        repeat: true
        onTriggered: media.livePos = Math.min(media.length, media.player.position + (Date.now() - media.posStamp) / 1000)
    }

    ClippingRectangle {
        id: art

        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(18)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.dp(80)
        height: Theme.dp(80)
        radius: Theme.shapeLg
        color: Theme.accentContainer

        LockGlyph {
            anchors.centerIn: parent
            name: "music"
            size: Theme.dp(30)
            color: Theme.fgAccentContainer
            visible: cover.status !== Image.Ready
        }

        Image {
            id: cover

            anchors.fill: parent
            source: media.player && media.player.trackArtUrl ? media.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Theme.dp(160)
            sourceSize.height: Theme.dp(160)
            asynchronous: true
        }

    }

    Row {
        id: transport

        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        LockIconButton {
            diameter: Theme.dp(36)
            glyphSize: Theme.dp(19)
            glyph: "prev"
            glyphColor: Theme.subtext
            actionable: !!media.player && media.player.canGoPrevious
            onClicked: media.player.previous()
        }

        LockIconButton {
            diameter: Theme.dp(40)
            glyphSize: Theme.dp(22)
            glyph: media.playing ? "pause" : "play"
            glyphColor: Theme.accent
            actionable: !!media.player && media.player.canTogglePlaying
            onClicked: media.player.togglePlaying()
        }

        LockIconButton {
            diameter: Theme.dp(36)
            glyphSize: Theme.dp(19)
            glyph: "next"
            glyphColor: Theme.subtext
            actionable: !!media.player && media.player.canGoNext
            onClicked: media.player.next()
        }

    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: Theme.dp(16)
        anchors.right: transport.left
        anchors.rightMargin: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(3)

        Text {
            width: parent.width
            text: media.title
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitleSm
            font.variableAxes: Theme.axes(Theme.fontTitleSm, 520, 0)
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            text: media.artist
            color: Theme.subtextDim
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodySm
            font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
        }

        Item {
            width: parent.width
            height: Theme.dp(6)
            visible: media.length > 0
        }

        // m3 expressive: the played part rides a wave while the track plays
        LinearProgress {
            width: parent.width
            value: media.progress
            wavy: true
            animated: media.playing
            // livePos already arrives every 50 ms; easing it again only lags
            valueAnimated: false
            trackColor: Theme.alpha(Theme.subtext, 0.22)
            visible: media.length > 0
        }

        Item {
            width: parent.width
            height: times.implicitHeight
            visible: media.length > 0

            Text {
                id: times

                text: media.fmt(media.livePos)
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
                font.variableAxes: Theme.axes(Theme.fontLabelSm, 480, 0)
                font.features: ({
                    "tnum": 1
                })
            }

            Text {
                anchors.right: parent.right
                text: media.fmt(media.length)
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
                font.variableAxes: Theme.axes(Theme.fontLabelSm, 480, 0)
                font.features: ({
                    "tnum": 1
                })
            }

        }

    }

}
