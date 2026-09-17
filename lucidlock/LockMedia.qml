import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs

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
    implicitHeight: 116

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
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: 64
        radius: Theme.shapeMd
        color: Theme.accentContainer

        LockGlyph {
            anchors.centerIn: parent
            name: "music"
            size: 26
            color: Theme.fgAccentContainer
            visible: cover.status !== Image.Ready
        }

        Image {
            id: cover

            anchors.fill: parent
            source: media.player && media.player.trackArtUrl ? media.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 128
            sourceSize.height: 128
            asynchronous: true
        }

    }

    Row {
        id: transport

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        LockIconButton {
            diameter: 36
            glyphSize: 19
            glyph: "prev"
            glyphColor: Theme.subtext
            enabled: !!media.player && media.player.canGoPrevious
            onClicked: media.player.previous()
        }

        LockIconButton {
            diameter: 40
            glyphSize: 22
            glyph: media.playing ? "pause" : "play"
            glyphColor: Theme.accent
            enabled: !!media.player && media.player.canTogglePlaying
            onClicked: media.player.togglePlaying()
        }

        LockIconButton {
            diameter: 36
            glyphSize: 19
            glyph: "next"
            glyphColor: Theme.subtext
            enabled: !!media.player && media.player.canGoNext
            onClicked: media.player.next()
        }

    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 16
        anchors.right: transport.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: media.title
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitleSm
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            text: media.artist
            color: Theme.subtextDim
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodySm
        }

        Item {
            width: parent.width
            height: 9
            visible: media.length > 0
        }

        // m3 linear progress: two tracks with a gap, and a stop at the end
        Item {
            id: track

            width: parent.width
            height: 4
            visible: media.length > 0

            Rectangle {
                width: Math.max(0, track.width * media.progress - 3)
                height: parent.height
                radius: 2
                color: Theme.accent
            }

            Rectangle {
                x: track.width * media.progress + 3
                width: Math.max(0, track.width - x - 6)
                height: parent.height
                radius: 2
                color: Theme.alpha(Theme.outlineStrong, 0.6)
            }

            Rectangle {
                anchors.right: parent.right
                width: 4
                height: 4
                radius: 2
                color: Theme.accent
            }

        }

        Item {
            width: parent.width
            height: 4
            visible: media.length > 0
        }

        Text {
            text: media.length > 0 ? media.fmt(media.livePos) + " / " + media.fmt(media.length) : ""
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelSm
            visible: media.length > 0
        }

    }


}
