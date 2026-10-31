import QtMultimedia
import QtQuick
import qs

// a video, playing in its still's place: the first frame lens made of it lies
// underneath until the video's own frames are up. only the one on show gets a
// player, and it goes when that does, leaving where it got to for a return
Item {
    id: movie

    required property var win
    required property string path
    readonly property var prefs: movie.win.app.prefs
    readonly property alias player: player
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property real duration: player.duration
    readonly property real position: player.position
    readonly property bool waiting: player.mediaStatus === MediaPlayer.LoadingMedia || player.mediaStatus === MediaPlayer.StalledMedia
    readonly property bool failed: player.error !== MediaPlayer.NoError
    readonly property string why: player.errorString
    readonly property bool hasAudio: player.hasAudio
    readonly property real fps: {
        var r = player.metaData.value(MediaMetaData.VideoFrameRate);
        return r > 0 ? r : 30;
    }
    // a frame of its own is up, so the still beneath can't show through
    property bool framed: false
    // a drag along the time line is under way: no looping back meanwhile
    property bool scrubbing: false
    // the trim's span, played round and round while it is being set (ms)
    property real loopFrom: -1
    property real loopTo: -1
    property bool _started: false

    signal ended()

    function play() {
        if (player.mediaStatus === MediaPlayer.EndOfMedia || (movie.loopTo > 0 && player.position >= movie.loopTo - 30))
            movie.seek(movie.loopFrom > 0 ? movie.loopFrom : 0);

        player.play();
    }

    function toggle() {
        if (movie.playing)
            player.pause();
        else
            movie.play();
    }

    function seek(ms) {
        player.setPosition(Math.max(0, Math.min(player.duration > 0 ? player.duration : ms, ms)));
        movie.framed = true;
    }

    function skip(ms) {
        movie.seek(player.position + ms);
    }

    // a frame on or back: paused, so it stays put
    function step(frames) {
        player.pause();
        movie.seek(player.position + frames * 1000 / movie.fps);
    }

    Component.onDestruction: {
        var p = player.position, d = player.duration;
        var at = Object.assign({}, movie.win.positions);
        // near either end is a fresh start next time
        if (p > 1500 && d > 0 && p < d - 1500)
            at[movie.path] = p;
        else
            delete at[movie.path];
        movie.win.positions = at;
    }

    MediaPlayer {
        id: player

        source: movie.win.app.uriOf(movie.path)
        videoOutput: out
        playbackRate: movie.win.rate
        // a slideshow moves on at the end, so it never loops one
        loops: movie.prefs.loopVideos && !movie.win.slideshow && movie.loopTo < 0 ? MediaPlayer.Infinite : 1
        onMediaStatusChanged: {
            if (player.mediaStatus === MediaPlayer.LoadedMedia && !movie._started) {
                movie._started = true;
                var at = movie.win.positions[movie.path] || 0;
                if (at > 0)
                    movie.seek(at);

                if (movie.prefs.autoplay || movie.win.slideshow)
                    player.play();

            } else if (player.mediaStatus === MediaPlayer.EndOfMedia) {
                movie.ended();
            }
        }
        onPositionChanged: {
            if (!movie.framed && player.position > 0)
                movie.framed = true;

            // the trim's span, round and round
            if (movie.loopTo > 0 && !movie.scrubbing && movie.playing && player.position >= movie.loopTo)
                player.setPosition(movie.loopFrom);

        }

        audioOutput: AudioOutput {
            // a slider's middle should sound like half as loud, not like nearly all
            volume: movie.prefs.volume * movie.prefs.volume
            muted: movie.prefs.muted
        }

    }

    VideoOutput {
        id: out

        anchors.fill: parent
        fillMode: VideoOutput.Stretch
        visible: movie.framed
    }

}
