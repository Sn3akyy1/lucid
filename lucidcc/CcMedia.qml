import "../lucidwidgets" as LW
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs
import qs.lucidui

// what is playing: the cover, the title and artist, the controls and how far
// along it is. a tap anywhere else opens the media panel. on a taller card it
// keeps to the middle. its looks: the cover as a square (card), as a disc
// that turns while it plays with how far along round it (disc), or blurred
// across the whole card under the rest (backdrop); one line with play (mini);
// the card over a wave to seek along, with the times (wave); or the cover
// filling the card, the rest over its foot (cover)
Item {
    id: mc

    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property real progress: 0
    property bool playing: false
    property real radius: Theme.shapeLgInc
    property bool easeValue: true
    // where it is and how long it runs, in seconds, for the wave
    property real position: 0
    property real length: 0
    // card, disc, backdrop, mini, wave or cover
    property string look: "card"
    readonly property bool disc: mc.look === "disc"
    readonly property bool classic: ["mini", "wave", "cover"].indexOf(mc.look) === -1

    signal previous()
    signal toggle()
    signal next()
    signal opened()
    signal seek(real seconds)

    implicitHeight: ({
        "mini": Theme.dp(56),
        "wave": waveCol.implicitHeight + Theme.dp(20),
        "cover": Theme.dp(200)
    })[mc.look] || Theme.dp(84)

    // the cover blurred over the whole card, under a scrim the text reads on;
    // with no cover, a wash of the accent in its place
    ClippingRectangle {
        anchors.fill: parent
        radius: mc.radius
        color: "transparent"
        visible: mc.look === "backdrop"

        Rectangle {
            visible: backdropArt.status !== Image.Ready
            anchors.fill: parent

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.primary, 0.32)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.tertiary, 0.14)
                }

            }

        }

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
            visible: backdropArt.status === Image.Ready
            anchors.fill: parent
            source: backdropArt
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.2
        }

        Rectangle {
            visible: backdropArt.status === Image.Ready
            anchors.fill: parent
            color: Theme.alpha(Theme.bgOpaque, 0.55)
        }

    }

    // cover: the cover over the whole card, the rest on a shade at its foot
    ClippingRectangle {
        visible: mc.look === "cover"
        anchors.fill: parent
        radius: mc.radius
        color: Theme.withBlur(Theme.surfaceHighest)

        Image {
            id: coverArt

            anchors.fill: parent
            source: mc.look === "cover" ? mc.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 512
            sourceSize.height: 512
            visible: coverArt.status === Image.Ready
        }

        // with no cover, the accent and a note in its place
        Rectangle {
            visible: coverArt.status !== Image.Ready
            anchors.fill: parent

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.primary, 0.35)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.tertiary, 0.12)
                }

            }

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - Theme.dp(64)) / 2 - size / 2
                name: "music_note"
                size: Theme.dp(40)
                color: Theme.alpha(Theme.text, 0.5)
            }

        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(parent.height, Theme.dp(110))

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }

                GradientStop {
                    position: 0.55
                    color: Theme.alpha(Theme.bgOpaque, 0.82)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.bgOpaque, 0.94)
                }

            }

        }

    }

    StateLayer {
        radius: mc.radius
        onClicked: mc.opened()
    }

    Item {
        visible: mc.look === "cover"
        anchors.fill: parent

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(16)
            anchors.right: coverControls.left
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: coverControls.verticalCenter
            spacing: 0

            LText {
                width: parent.width
                role: "titleMedium"
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

        Row {
            id: coverControls

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(16)
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

        LinearProgress {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.dp(16)
            anchors.rightMargin: Theme.dp(16)
            anchors.bottomMargin: Theme.dp(6)
            value: mc.progress
            thickness: Theme.dp(3)
            valueAnimated: false
            trackColor: Theme.alpha(Theme.text, 0.16)
        }

    }

    // mini: one line, a small cover, the name and play
    Item {
        visible: mc.look === "mini"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.dp(56)

        ClippingRectangle {
            id: miniArt

            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(38)
            height: Theme.dp(38)
            radius: Theme.shapeMd
            color: Theme.withBlur(Theme.surfaceHighest)

            Image {
                id: miniImg

                anchors.fill: parent
                source: mc.look === "mini" ? mc.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Theme.dp(76)
                sourceSize.height: Theme.dp(76)
                visible: miniImg.status === Image.Ready
            }

            Icon {
                anchors.centerIn: parent
                visible: !miniImg.visible
                name: "music_note"
                size: Theme.dp(20)
                color: Theme.subtext
            }

        }

        Column {
            anchors.left: miniArt.right
            anchors.leftMargin: Theme.dp(10)
            anchors.right: miniControls.left
            anchors.rightMargin: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: -Theme.dp(2)

            LText {
                width: parent.width
                role: "labelLarge"
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

        Row {
            id: miniControls

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: mc.playing ? "pause" : "play_arrow"
                iconFill: 1
                size: "xs"
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

        // how far along, a hairline at the foot
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.dp(12)
            anchors.bottomMargin: Theme.dp(3)
            width: (parent.width - Theme.dp(24)) * Math.max(0, Math.min(1, mc.progress))
            height: Theme.dp(2)
            radius: height / 2
            color: Theme.primary
        }

    }

    // wave: the card's line over a wave to seek along, with the times under it
    Column {
        id: waveCol

        visible: mc.look === "wave"
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.dp(10)
        width: parent.width - Theme.dp(20)
        spacing: Theme.dp(4)

        Item {
            width: parent.width
            height: Theme.dp(56)

            ClippingRectangle {
                id: waveArt

                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(52)
                height: Theme.dp(52)
                radius: Theme.shapeLg
                color: Theme.withBlur(Theme.surfaceHighest)

                Image {
                    id: waveImg

                    anchors.fill: parent
                    source: mc.look === "wave" ? mc.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: Theme.dp(104)
                    sourceSize.height: Theme.dp(104)
                    visible: waveImg.status === Image.Ready
                }

                Icon {
                    anchors.centerIn: parent
                    visible: !waveImg.visible
                    name: "music_note"
                    size: Theme.dp(24)
                    color: Theme.subtext
                }

            }

            Column {
                anchors.left: waveArt.right
                anchors.leftMargin: Theme.dp(12)
                anchors.right: waveControls.left
                anchors.rightMargin: Theme.dp(8)
                anchors.verticalCenter: parent.verticalCenter
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

            Row {
                id: waveControls

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
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

        }

        LW.WaveSeek {
            width: parent.width
            position: mc.position
            length: mc.length
            interactive: mc.length > 0
            playing: mc.playing
            flowing: mc.easeValue
            accent: Theme.primary
            trackColor: Theme.withBlur(Theme.surfaceHighest)
            labelColor: Theme.subtext
            onSeekRequested: (s) => {
                return mc.seek(s);
            }
        }

    }

    Item {
        visible: mc.classic
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
