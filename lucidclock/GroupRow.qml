import QtQuick
import qs

// one row of a grouped list, the way Lucid Settings draws them: the group's
// outer corners round large, the corners meeting a neighbour small, 3dp apart.
// the content goes inside; `raised` is a row opened up, a step lighter
Rectangle {
    id: gr

    property bool first: true
    property bool last: true
    property bool hoverable: true
    property bool raised: false
    readonly property int outer: Theme.rad(26)
    readonly property int inner: Theme.dp(6)
    readonly property bool hovered: hover.hovered
    default property alias content: holder.data

    topLeftRadius: gr.first ? gr.outer : gr.inner
    topRightRadius: gr.first ? gr.outer : gr.inner
    bottomLeftRadius: gr.last ? gr.outer : gr.inner
    bottomRightRadius: gr.last ? gr.outer : gr.inner
    color: Theme.withBlur(gr.raised ? Theme.bgHigh : Theme.bgTile)

    // pointer feedback only, as SettingRow's: it never takes a click
    Rectangle {
        anchors.fill: parent
        topLeftRadius: gr.topLeftRadius
        topRightRadius: gr.topRightRadius
        bottomLeftRadius: gr.bottomLeftRadius
        bottomRightRadius: gr.bottomRightRadius
        color: Theme.text
        opacity: hover.hovered && gr.hoverable ? Theme.stateHover * 0.5 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

    HoverHandler {
        id: hover
    }

    Item {
        id: holder

        anchors.fill: parent
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.durShort
        }

    }

}
