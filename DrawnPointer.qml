import QtQuick
import qs

// the pointer drawn by a window itself, from lucid's theme: the compositor shows
// its own a frame or two before a window catches up, so whatever is drawn at the
// pointer trails it. hide the real one only once `onScreen` (HeldPointer does it
// all); a theme of the machine's has no pictures here, so nothing is drawn
Image {
    id: dp

    // the shape, as for cursorShape
    property int cursor: Qt.ArrowCursor
    // where the hotspot goes, in the parent's coordinates
    property real px: 0
    property real py: 0
    // the picture is only read while this is on
    property bool active: true
    readonly property string picture: dp.active ? PointerPictures.pictureOf(dp.cursor) : ""
    readonly property var hot: dp.picture !== "" ? PointerPictures.stamp.hotspots[dp.picture] : undefined
    readonly property bool ready: dp.hot !== undefined && dp.status === Image.Ready
    // a frame with this in it has gone to the compositor: hidden any sooner, the
    // real pointer would leave no pointer at all for a frame or two
    property bool onScreen: false
    property int swaps: 0
    // as big as shake to find has made the compositor's, about the hotspot
    readonly property real zoom: dp.active ? PointerPictures.zoom : 1

    width: PointerPictures.size * dp.zoom
    height: PointerPictures.size * dp.zoom
    x: Math.round(dp.px - (dp.hot ? dp.hot[0] : 0.5) * dp.width)
    y: Math.round(dp.py - (dp.hot ? dp.hot[1] : 0.5) * dp.height)
    source: dp.hot !== undefined ? "file://" + PointerPictures.dir + "/preview/" + dp.picture + ".png?" + PointerPictures.revision : ""
    // the pictures are 192 px, for a pointer grown up to 8x
    sourceSize: Qt.size(192, 192)
    cache: false
    smooth: true
    mipmap: true
    onVisibleChanged: {
        dp.swaps = 0;
        dp.onScreen = false;
    }

    // two swaps, as the first can be a frame already on its way
    Connections {
        function onFrameSwapped() {
            if (++dp.swaps >= 2)
                dp.onScreen = true;
            else
                dp.Window.window.update();
        }

        target: dp.visible && !dp.onScreen ? dp.Window.window : null
    }

}
