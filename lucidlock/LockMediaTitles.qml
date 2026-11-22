import QtQuick
import qs
import qs.lucidui
import "parts"

// the track and the artist, for LockMedia
Column {
    id: part

    property var media: null

    property int titleSize: Theme.fontTitleSm
    property int align: Text.AlignLeft

    spacing: Theme.dp(3)

    Text {
        width: parent.width
        horizontalAlignment: parent.align
        text: media.title
        color: media.tonal ? Theme.fgAccentContainer : Theme.text
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: parent.titleSize
        font.variableAxes: Theme.axes(parent.titleSize, 540, 0)
        font.weight: Font.Medium
    }

    Text {
        width: parent.width
        horizontalAlignment: parent.align
        text: media.artist
        color: Theme.subtextDim
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodySm
        font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
    }

}
