import QtQuick
import qs
import qs.lucidui
import "parts"

// LockMedia's seek line: the played part rides a wave while the track plays
Column {
    id: part

    property var media: null

    spacing: Theme.dp(4)
    visible: media.length > 0

    // m3 expressive: the played part rides a wave while the track plays
    LinearProgress {
        width: parent.width
        value: media.progress
        wavy: true
        animated: media.playing
        // livePos already arrives every 50 ms; easing it again only lags
        valueAnimated: false
        trackColor: Theme.alpha(Theme.subtext, 0.22)
    }

    Item {
        width: parent.width
        height: times.implicitHeight

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
