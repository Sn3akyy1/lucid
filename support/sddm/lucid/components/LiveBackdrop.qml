import QtMultimedia
import QtQuick

// a live wallpaper behind the greeter. sync-sddm.sh hands over a small,
// blurred, silent copy whose first frame is background.jpg, so the still under
// this is already the picture the video starts on; it only has to fade over it
Item {
    id: live

    property url source
    readonly property bool showing: player.playbackState === MediaPlayer.PlayingState && (player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia)

    MediaPlayer {
        id: player

        source: live.source
        // play() from here would run before the player has the source
        autoPlay: true
        loops: MediaPlayer.Infinite
        videoOutput: out
        onErrorOccurred: (error, errorString) => {
            return console.warn("lucid greeter:", errorString);
        }
    }

    VideoOutput {
        id: out

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: live.showing ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }

        }

    }

}
