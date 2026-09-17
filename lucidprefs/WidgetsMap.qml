import "../lucidwidgets"
import QtQuick
import Quickshell
import qs

Item {
    id: map

    // the preview is drawn over this, the same as the preset tiles
    property string wallpaper: ""

    readonly property var screenSize: Monitors.mainScreen
    readonly property real screenW: map.screenSize ? map.screenSize.width : 1920
    readonly property real screenH: map.screenSize ? map.screenSize.height : 1080
    readonly property real fit: Math.min((frame.width - 24) / map.screenW, (frame.height - 24) / map.screenH)

    implicitHeight: 300

    Text {
        id: caption

        anchors.left: parent.left
        anchors.top: parent.top
        leftPadding: 22
        text: "Your desktop"
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitleSm
        font.weight: Font.DemiBold
        font.letterSpacing: 0.1
        bottomPadding: 12
    }

    Text {
        anchors.right: parent.right
        anchors.baseline: caption.baseline
        rightPadding: 22
        text: "Click a widget to pin it in place"
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        visible: Widgets.count > 0
    }

    Rectangle {
        id: frame

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: caption.bottom
        anchors.bottom: parent.bottom
        radius: Theme.radiusXl
        color: Theme.withBlur(Theme.bgTile)
        clip: true

        // the real widgets on your wallpaper, drawn the way the presets are
        PresetThumb {
            id: canvas

            anchors.centerIn: parent
            width: map.screenW * map.fit
            height: map.screenH * map.fit
            cards: Widgets.desktopLayout
            wallpaper: map.wallpaper
        }

        // a hit area over each card, off the live model so a pin shows at once
        Item {
            x: canvas.x
            y: canvas.y
            width: canvas.width
            height: canvas.height

            Repeater {
                model: Widgets.model

                Item {
                    id: spot

                    required property string uid
                    required property real wx
                    required property real wy
                    required property real bw
                    required property real bh
                    required property real zoom
                    required property bool pinned
                    required property bool closing
                    required property string screenName
                    readonly property real cw: spot.bw * spot.zoom * map.fit
                    readonly property real ch: spot.bh * spot.zoom * map.fit

                    x: Math.max(0, Math.min(parent.width - spot.cw, spot.wx * map.fit))
                    y: Math.max(0, Math.min(parent.height - spot.ch, spot.wy * map.fit))
                    width: spot.cw
                    height: spot.ch
                    visible: !spot.closing && Widgets.onPrimary({
                        "screenName": spot.screenName
                    })

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.min(Theme.radiusXl * spot.zoom * map.fit, spot.ch / 2)
                        color: Theme.text
                        opacity: area.containsMouse ? 0.14 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    // pinned for good, or offered on hover
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        width: 18
                        height: 18
                        radius: Theme.rad(9)
                        color: Theme.accent
                        opacity: spot.pinned ? 1 : (area.containsMouse ? 0.55 : 0)
                        visible: opacity > 0.01

                        WidgetGlyph {
                            anchors.centerIn: parent
                            name: "pin"
                            size: 11
                            color: Theme.fgAccent
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Widgets.togglePinned(spot.uid)
                    }

                }

            }

        }

        Rectangle {
            anchors.centerIn: canvas
            width: empty.implicitWidth + 36
            height: empty.implicitHeight + 24
            radius: Theme.radiusLg
            color: Theme.bgOpaque
            visible: Widgets.count === 0

            Column {
                id: empty

                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing placed yet"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Pick a preset or a widget below."
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                }

            }

        }

    }

}
