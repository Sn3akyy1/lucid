import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs
import qs.lucidui

// a magnifier over the frozen frame: the pixels round the pointer blown up,
// a hairline grid between them and the one under the pointer ringed. under it,
// what that pixel is: its colour, or where it sits
Item {
    id: lp

    property url source: ""
    // the frame's own pixels, and how many of them to a logical pixel
    property size frameSize: Qt.size(0, 0)
    property real ratio: 1
    // the pointer, in logical pixels on the frame
    property real px: 0
    property real py: 0
    property int cells: 15
    property int zoom: Theme.dp(11)
    property color picked: "transparent"
    property string label: ""
    readonly property int box: lp.cells * lp.zoom
    readonly property int half: Math.floor(lp.cells / 2)
    readonly property int fx: Math.max(0, Math.min(lp.frameSize.width - 1, Math.floor(lp.px * lp.ratio)))
    readonly property int fy: Math.max(0, Math.min(lp.frameSize.height - 1, Math.floor(lp.py * lp.ratio)))
    readonly property bool lightPick: lp.picked.a > 0 && (0.299 * lp.picked.r + 0.587 * lp.picked.g + 0.114 * lp.picked.b) > 0.6

    width: lp.box
    height: lp.box + Theme.dp(8) + readout.height

    RectangularShadow {
        anchors.fill: lens
        radius: lens.radius
        blur: Theme.dp(18)
        offset.y: Theme.dp(4)
        color: Theme.alpha(Theme.shadow, Theme.isLight ? 0.22 : 0.45)
    }

    ClippingRectangle {
        id: lens

        width: lp.box
        height: lp.box
        radius: Theme.rad(28)
        color: Theme.surfaceContainer

        Image {
            source: lp.source
            smooth: false
            mipmap: false
            cache: false
            asynchronous: true
            width: lp.frameSize.width * lp.zoom
            height: lp.frameSize.height * lp.zoom
            x: (lp.half - lp.fx) * lp.zoom
            y: (lp.half - lp.fy) * lp.zoom
        }

        Repeater {
            model: lp.cells - 1

            Rectangle {
                required property int index

                x: (index + 1) * lp.zoom
                width: 1
                height: lp.box
                color: Theme.alpha("#000000", 0.14)
            }

        }

        Repeater {
            model: lp.cells - 1

            Rectangle {
                required property int index

                y: (index + 1) * lp.zoom
                width: lp.box
                height: 1
                color: Theme.alpha("#000000", 0.14)
            }

        }

        // the pixel itself, ringed twice so it shows on light and dark alike
        Rectangle {
            x: lp.half * lp.zoom - 2
            y: lp.half * lp.zoom - 2
            width: lp.zoom + 4
            height: lp.zoom + 4
            radius: Theme.dp(3)
            color: "transparent"
            border.width: 2
            border.color: lp.lightPick ? "#000000" : "#ffffff"

            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: parent.radius + 1
                color: "transparent"
                border.width: 1
                border.color: lp.lightPick ? Theme.alpha("#ffffff", 0.7) : Theme.alpha("#000000", 0.55)
            }

        }

    }

    Rectangle {
        anchors.fill: lens
        radius: lens.radius
        color: "transparent"
        border.width: Theme.dp(3)
        border.color: Theme.surfaceContainer
    }

    Rectangle {
        id: readout

        y: lp.box + Theme.dp(8)
        anchors.horizontalCenter: lens.horizontalCenter
        width: readRow.implicitWidth + Theme.dp(lp.picked.a > 0 ? 14 : 22)
        height: Theme.dp(32)
        radius: height / 2
        color: Theme.surfaceContainer
        visible: lp.label !== ""

        Row {
            id: readRow

            anchors.centerIn: parent
            spacing: Theme.dp(8)

            Rectangle {
                visible: lp.picked.a > 0
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(20)
                height: Theme.dp(20)
                radius: width / 2
                color: lp.picked
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.25)
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelLarge"
                tabular: true
                color: Theme.text
                text: lp.label
            }

        }

    }

}
