import QtQuick
import qs
import qs.lucidui

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

    width: parent ? parent.width : Theme.dp(400)

    Rectangle {
        id: head

        width: parent.width
        height: Theme.dp(62)
        radius: Theme.radiusMd
        color: dev.expanded ? Theme.bgHover : (headArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

        Item {
            id: iconTile

            width: Theme.dp(40)
            height: Theme.dp(40)
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(11)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.dp(13)
                color: Theme.alpha(Theme.accent, dev.isDefault ? 0.24 : 0.11)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            DeviceGlyph {
                anchors.centerIn: parent
                size: Theme.dp(21)
                kind: Audio.glyphKind(dev.modelData)
                color: Theme.accent
            }

            // the tick the rest of the app uses for "this is the one in use"
            Rectangle {
                width: Theme.dp(14)
                height: Theme.dp(14)
                radius: Theme.dp(7)
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -Theme.dp(3)
                visible: dev.isDefault
                color: Theme.success
                border.width: 2
                border.color: Theme.bgTile

                Icon {
                    anchors.centerIn: parent
                    name: "check"
                    size: Theme.dp(10)
                    color: Theme.fgSuccess
                }

            }

        }

        Column {
            anchors.left: iconTile.right
            anchors.leftMargin: Theme.dp(14)
            anchors.right: trailing.left
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            Text {
                width: parent.width
                text: Audio.label(dev.modelData)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.variableAxes: Theme.axes(Theme.fontTitle, 640, 0)
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: dev.status
                color: dev.isDefault ? Theme.accent : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                elide: Text.ElideRight
            }

        }

        Row {
            id: trailing

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(8)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dev.muted ? "Muted" : dev.volume + "%"
                color: dev.muted ? Theme.subtextDim : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
            }

            M3IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.dp(32)
                iconSize: Theme.dp(18)
                rotation: dev.expanded ? 180 : 0
                iconPath: "expand_more"
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
            anchors.rightMargin: trailing.width + Theme.dp(12)
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
            leftPadding: Theme.dp(65)
            rightPadding: Theme.dp(14)
            topPadding: Theme.dp(4)
            bottomPadding: Theme.dp(16)
            spacing: Theme.dp(14)
            opacity: dev.expanded ? 1 : 0

            Row {
                width: parent.width - Theme.dp(79)
                spacing: Theme.dp(12)

                M3IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(36)
                    iconSize: Theme.dp(19)
                    variant: dev.muted ? "tonal" : "standard"
                    iconPath: dev.muted ? "volume_off" : "volume_up"
                    onClicked: Audio.toggleMute(dev.modelData)
                }

                M3Slider {
                    width: parent.width - Theme.dp(48)
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
                width: parent.width - Theme.dp(79)
                visible: dev.ports && dev.ports.list.length > 1
                spacing: Theme.dp(7)

                Text {
                    text: dev.modelData.isSink ? "Socket" : "Connector"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
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
                width: parent.width - Theme.dp(79)
                visible: dev.card && dev.card.profiles.length > 1
                spacing: Theme.dp(7)

                Text {
                    text: "Mode"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
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
                width: parent.width - Theme.dp(79)
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
