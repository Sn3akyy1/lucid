import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidui

// what is playing: the cover, the title and artist, the controls and how far
// along it is. a tap anywhere else opens the media panel. on a taller card it
// keeps to the middle
Item {
    id: mc

    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property real progress: 0
    property bool playing: false
    property real radius: Theme.shapeLgInc
    property bool easeValue: true

    signal previous()
    signal toggle()
    signal next()
    signal opened()

    implicitHeight: Theme.dp(84)

    StateLayer {
        radius: mc.radius
        onClicked: mc.opened()
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.dp(84)

        // ClippingRectangle: radius + clip alone leaves the image corners square
        ClippingRectangle {
            id: art

            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(64)
            height: Theme.dp(64)
            radius: Theme.shapeLg
            color: Theme.withBlur(Theme.surfaceHighest)

            Image {
                id: artImg

                anchors.fill: parent
                source: mc.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Theme.dp(128)
                sourceSize.height: Theme.dp(128)
                visible: artImg.status === Image.Ready
            }

            Icon {
                anchors.centerIn: parent
                visible: !artImg.visible
                name: "music_note"
                size: Theme.dp(26)
                color: Theme.subtext
            }

        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            anchors.top: parent.top
            anchors.topMargin: Theme.dp(12)
            spacing: Theme.dp(2)

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_previous"
                iconFill: 1
                size: "xs"
                tintOverride: Theme.text
                onClicked: mc.previous()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: mc.playing ? "pause" : "play_arrow"
                iconFill: 1
                variant: "filled"
                onClicked: mc.toggle()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_next"
                iconFill: 1
                size: "xs"
                tintOverride: Theme.text
                onClicked: mc.next()
            }

        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: controls.left
            anchors.rightMargin: Theme.dp(8)
            anchors.top: parent.top
            anchors.topMargin: Theme.dp(14)
            spacing: 1

            LText {
                width: parent.width
                role: "titleSmall"
                text: mc.title
                elide: Text.ElideRight
            }

            LText {
                width: parent.width
                visible: text !== ""
                role: "bodySmall"
                color: Theme.subtext
                text: mc.artist
                elide: Text.ElideRight
            }

        }

        LinearProgress {
            anchors.left: art.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(16)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(14)
            value: mc.progress
            wavy: true
            animated: mc.playing && mc.easeValue
            valueAnimated: false
            amplitude: 2.5
            wavelength: Theme.dp(24)
            trackColor: Theme.withBlur(Theme.surfaceHighest)
        }

    }

}
