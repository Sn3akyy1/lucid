import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidui
import "parts"

// the cover for LockMedia, or a note while there is none
ClippingRectangle {
    id: art

    property var media: null

    property real size: Theme.dp(80)

    width: art.size
    height: art.size
    color: Theme.accentContainer

    Glyph {
        anchors.centerIn: parent
        name: "music_note"
        size: art.size * 0.38
        color: Theme.fgAccentContainer
        visible: cover.status !== Image.Ready
    }

    Image {
        id: cover

        anchors.fill: parent
        source: media.artSource
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.round(art.size * 2)
        sourceSize.height: Math.round(art.size * 2)
        asynchronous: true
    }

}
