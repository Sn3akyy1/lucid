import QtQuick
import QtQuick.Shapes
import qs

SettingCard {
    id: card

    required property var dev
    property real drift: 0
    property real driftAt: 0

    readonly property var mpris: card.dev.mpris
    readonly property bool playing: !!(card.mpris && card.mpris.playing)
    readonly property int length: card.mpris ? card.mpris.length : 0
    readonly property int position: Math.max(0, Math.min(card.length, (card.mpris ? card.mpris.position : 0) + card.drift))
    readonly property string nowPlaying: {
        if (!card.mpris || card.mpris.title === "")
            return "Nothing playing";

        return card.mpris.title;
    }

    function clock(ms) {
        if (ms <= 0)
            return "0:00";

        const total = Math.round(ms / 1000);
        const m = Math.floor(total / 60);
        return m + ":" + String(total % 60).padStart(2, "0");
    }

    title: "PLAYING ON THE PHONE"

    // the phone only reports position when something moves it, so run the clock here
    Timer {
        interval: 1000
        repeat: true
        running: card.playing && card.length > 0
        onTriggered: card.drift += 1000
    }

    Connections {
        function onDevChanged() {
            card.drift = 0;
        }

        target: card
    }

    SettingRow {
        title: card.nowPlaying
        description: {
            if (!card.mpris)
                return "";

            const bits = [];
            if (card.mpris.artist !== "")
                bits.push(card.mpris.artist);

            if (card.mpris.album !== "" && card.mpris.album !== card.mpris.artist)
                bits.push(card.mpris.album);

            return bits.join("  ·  ");
        }
        stacked: true
        showDivider: false

        Column {
            width: parent.width
            spacing: 14

            Row {
                width: parent.width
                spacing: 12
                visible: card.length > 0

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.clock(card.position)
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                }

                M3Slider {
                    width: parent.width - 130
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !!(card.mpris && card.mpris.canSeek)
                    showReadout: false
                    from: 0
                    to: Math.max(1, card.length)
                    value: card.position
                    onMoved: (v) => {
                        card.drift = 0;
                        KdeConnect.mpris(card.dev.id, "position", "", Math.round(v));
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.clock(card.length)
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                }

            }

            Row {
                spacing: 10

                TransportButton {
                    kind: "prev"
                    onPressed: KdeConnect.mpris(card.dev.id, "Previous")
                }

                TransportButton {
                    kind: card.playing ? "pause" : "play"
                    primary: true
                    onPressed: KdeConnect.mpris(card.dev.id, "PlayPause")
                }

                TransportButton {
                    kind: "next"
                    onPressed: KdeConnect.mpris(card.dev.id, "Next")
                }

                Item {
                    width: 10
                    height: 1
                }

                M3Slider {
                    width: 190
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!(card.mpris && card.mpris.volume >= 0)
                    from: 0
                    to: 100
                    stepSize: 1
                    suffix: "%"
                    value: card.mpris ? card.mpris.volume : 0
                    onMoved: (v) => {
                        return KdeConnect.mpris(card.dev.id, "volume", "", Math.round(v));
                    }
                }

            }

            Row {
                spacing: 8
                visible: !!(card.mpris && card.mpris.players.length > 1)

                Repeater {
                    model: card.mpris ? card.mpris.players : []

                    Rectangle {
                        id: chip

                        required property string modelData

                        readonly property bool selected: card.mpris && card.mpris.player === chip.modelData

                        width: chipText.implicitWidth + 24
                        height: 30
                        radius: 15
                        color: chip.selected ? Theme.accentContainer : (chipArea.containsMouse ? Theme.bgHover : Theme.bgSunken)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                            }

                        }

                        Text {
                            id: chipText

                            anchors.centerIn: parent
                            text: chip.modelData
                            color: chip.selected ? Theme.fgAccentContainer : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.bold: chip.selected
                        }

                        MouseArea {
                            id: chipArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: KdeConnect.mpris(card.dev.id, "player", chip.modelData)
                        }

                    }

                }

            }

        }

    }

    component TransportButton: Rectangle {
        id: btn

        property string kind: "play"
        property bool primary: false

        signal pressed()

        width: btn.primary ? 48 : 40
        height: btn.primary ? 48 : 40
        radius: width / 2
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: btn.primary ? (btnArea.containsMouse ? Theme.accentHover : Theme.accent) : (btnArea.containsMouse ? Theme.bgHover : Theme.bgSunken)
        scale: btnArea.pressed ? 0.94 : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Theme.easeStandard
            }

        }

        Shape {
            anchors.centerIn: parent
            width: 20
            height: 20
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillColor: btn.primary ? Theme.fgAccent : Theme.text

                PathSvg {
                    path: {
                        switch (btn.kind) {
                        case "play":
                            return "M8,5.14V19.14L19,12.14L8,5.14Z";
                        case "pause":
                            return "M14,19H18V5H14M6,19H10V5H6V19Z";
                        case "next":
                            return "M16,18H18V6H16M6,18L14.5,12L6,6V18Z";
                        default:
                            return "M6,18V6H8V18H6M9.5,12L18,6V18L9.5,12Z";
                        }
                    }
                }

            }

            transform: Scale {
                xScale: 20 / 24
                yScale: 20 / 24
            }

        }

        MouseArea {
            id: btnArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.pressed()
        }

    }

}
