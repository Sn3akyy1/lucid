import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs
import qs.lucidui

// what is playing: the cover, the title and artist, the controls and how far
// along it is. a tap anywhere else opens the media panel. on a taller card it
// keeps to the middle. three looks: the cover as a square (card), as a disc
// that turns while it plays with how far along round it (disc), or blurred
// across the whole card under the rest (backdrop)
Item {
    id: mc

    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property real progress: 0
    property bool playing: false
    property real radius: Theme.shapeLgInc
    property bool easeValue: true
    // card, disc or backdrop
    property string look: "card"
    readonly property bool disc: mc.look === "disc"

    signal previous()
    signal toggle()
    signal next()
    signal opened()

    implicitHeight: Theme.dp(84)

    // the cover blurred over the whole card, under a scrim the text reads on
    ClippingRectangle {
        anchors.fill: parent
        radius: mc.radius
        color: "transparent"
        visible: mc.look === "backdrop" && backdropArt.status === Image.Ready

        Image {
            id: backdropArt

            anchors.fill: parent
            source: mc.look === "backdrop" ? mc.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
            sourceSize.height: 256
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: backdropArt
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.2
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bgOpaque, 0.55)
        }

    }

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

            visible: !mc.disc
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

        // the disc: the cover cut round, turning while it plays, and how far
        // along drawn round it
        Item {
            id: disc

            visible: mc.disc
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(68)
            height: Theme.dp(68)

            CircularProgress {
                anchors.fill: parent
                value: mc.progress
                thickness: Theme.dp(3)
                wavy: false
                animated: false
                color: Theme.primary
                trackColor: Theme.withBlur(Theme.surfaceHighest)
            }

            ShapedImage {
                id: discArt

                anchors.centerIn: parent
                width: Theme.dp(56)
                height: Theme.dp(56)
                shape: "cookie12"
                source: mc.disc ? mc.artUrl : ""
                fallbackColor: Theme.withBlur(Theme.surfaceHighest)

                Icon {
                    anchors.centerIn: parent
                    name: "music_note"
                    size: Theme.dp(24)
                    color: Theme.subtext
                }

                // a turn every 16 seconds while it plays, stopping where it is
                FrameAnimation {
                    running: mc.disc && mc.playing
                    onTriggered: discArt.rotation = (discArt.rotation + frameTime * 22.5) % 360
                }

            }

        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            anchors.top: parent.top
            anchors.topMargin: mc.disc ? (parent.height - height) / 2 : Theme.dp(12)
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
            anchors.left: mc.disc ? disc.right : art.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: controls.left
            anchors.rightMargin: Theme.dp(8)
            anchors.top: parent.top
            anchors.topMargin: mc.disc ? (parent.height - height) / 2 : Theme.dp(14)
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
            visible: !mc.disc
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
