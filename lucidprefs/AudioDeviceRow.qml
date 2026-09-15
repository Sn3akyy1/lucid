import QtQuick
import qs

// one output or input: the whole row picks it, the chevron opens what the
// device itself can be told to do — its profile, its socket and its own volume
Column {
    id: dev

    required property var modelData
    property bool expanded: false
    readonly property bool isDefault: Audio.isDefault(dev.modelData)
    readonly property var card: Audio.cardFor(dev.modelData)
    readonly property var ports: Audio.portsFor(dev.modelData)
    readonly property string detail: Audio.detailOf(dev.modelData)
    readonly property int volume: Audio.volumeOf(dev.modelData)
    readonly property bool muted: Audio.mutedOf(dev.modelData)
    readonly property string status: {
        const what = dev.modelData.isSink ? "output" : "input";
        if (dev.isDefault)
            return dev.detail !== "" ? "Default " + what + " · " + dev.detail : "Default " + what;

        return dev.detail !== "" ? dev.detail : "Available";
    }

    signal expandRequested()

    width: parent ? parent.width : 400

    Rectangle {
        id: head

        width: parent.width
        height: 62
        radius: Theme.radiusMd
        color: dev.expanded ? Theme.bgHover : (headArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

        Item {
            id: iconTile

            width: 40
            height: 40
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 13
                color: Theme.alpha(Theme.accent, dev.isDefault ? 0.24 : 0.11)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            DeviceGlyph {
                anchors.centerIn: parent
                size: 21
                kind: Audio.glyphKind(dev.modelData)
                color: Theme.accent
            }

            // the tick the rest of the app uses for "this is the one in use"
            Rectangle {
                width: 14
                height: 14
                radius: 7
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -3
                visible: dev.isDefault
                color: Theme.success
                border.width: 2
                border.color: Theme.bgTile

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: Theme.fgSuccess
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.Bold
                }

            }

        }

        Column {
            anchors.left: iconTile.right
            anchors.leftMargin: 14
            anchors.right: trailing.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: Audio.label(dev.modelData)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: dev.status
                color: dev.isDefault ? Theme.accent : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                elide: Text.ElideRight
            }

        }

        Row {
            id: trailing

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dev.muted ? "Muted" : dev.volume + "%"
                color: dev.muted ? Theme.subtextDim : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
            }

            M3IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                iconSize: 18
                rotation: dev.expanded ? 180 : 0
                iconPath: "M7.41 8.59 12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41Z"
                onClicked: dev.expandRequested()

                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

            }

        }

        MouseArea {
            id: headArea

            anchors.fill: parent
            anchors.rightMargin: trailing.width + 12
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Audio.setDefault(dev.modelData)
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

    }

    Item {
        id: drawer

        width: parent.width
        height: dev.expanded ? body.implicitHeight : 0
        clip: true

        Column {
            id: body

            width: parent.width
            leftPadding: 65
            rightPadding: 14
            topPadding: 4
            bottomPadding: 16
            spacing: 14
            opacity: dev.expanded ? 1 : 0

            Row {
                width: parent.width - 79
                spacing: 12

                M3IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 36
                    iconSize: 19
                    variant: dev.muted ? "tonal" : "standard"
                    iconPath: dev.muted ? "M12 4 9.91 6.09 12 8.18V4ZM4.27 3 3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06a8.94 8.94 0 0 0 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3ZM19 12c0 .82-.15 1.61-.41 2.34l1.53 1.53A8.9 8.9 0 0 0 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71Zm-2.5 0c0-1.77-1.02-3.29-2.5-4.03v1.79l2.48 2.48c.01-.08.02-.16.02-.24Z" : "M3 9v6h4l5 5V4L7 9H3Zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02ZM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77Z"
                    onClicked: Audio.toggleMute(dev.modelData)
                }

                M3Slider {
                    width: parent.width - 48
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: 100
                    stepSize: 1
                    decimals: 0
                    suffix: "%"
                    enabled: !dev.muted
                    value: dev.volume
                    onMoved: (v) => {
                        return Audio.setVolume(dev.modelData, v);
                    }
                }

            }

            // where the sound physically comes out: the headphone socket, the
            // speakers, the digital output
            Column {
                width: parent.width - 79
                visible: dev.ports && dev.ports.list.length > 1
                spacing: 7

                Text {
                    text: dev.modelData.isSink ? "Socket" : "Connector"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: Font.Medium
                }

                M3Chips {
                    width: parent.width
                    current: dev.ports ? dev.ports.active : ""
                    options: (dev.ports ? dev.ports.list : []).map((p) => {
                        return {
                            "key": p.key,
                            "label": p.available ? p.label : p.label + " — unplugged"
                        };
                    })
                    onChosen: (key) => {
                        return Audio.setPort(dev.modelData, key);
                    }
                }

            }

            // the card's own mode, which decides what devices it offers at all
            Column {
                width: parent.width - 79
                visible: dev.card && dev.card.profiles.length > 1
                spacing: 7

                Text {
                    text: "Mode"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: Font.Medium
                }

                M3Chips {
                    width: parent.width
                    current: dev.card ? dev.card.active : ""
                    options: dev.card ? dev.card.profiles : []
                    onChosen: (key) => {
                        return Audio.setProfile(dev.card.name, key);
                    }
                }

            }

            Text {
                width: parent.width - 79
                text: dev.modelData.name
                color: Theme.subtextDim
                font.family: "monospace"
                font.features: ({
                    "liga": 0,
                    "calt": 0
                })
                font.pixelSize: Theme.fontLabel
                elide: Text.ElideRight
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeStandard
            }

        }

    }

}
