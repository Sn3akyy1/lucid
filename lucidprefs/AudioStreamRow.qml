import QtQuick
import qs

// one program's own audio: its volume, and the device it is playing on
Column {
    id: stream

    required property var modelData
    property bool expanded: false
    readonly property bool playback: stream.modelData.isSink
    readonly property var target: Audio.targetOf(stream.modelData)
    readonly property int volume: Audio.volumeOf(stream.modelData)
    readonly property bool muted: Audio.mutedOf(stream.modelData)
    readonly property var devices: stream.playback ? Audio.outputs : Audio.inputs
    // a stream that records is muted with a microphone, not with a speaker
    readonly property string icon: {
        if (stream.playback)
            return stream.muted ? "volume_off" : "volume_up";

        return stream.muted ? "mic_off" : "mic";
    }
    readonly property string subtitle: {
        const media = Audio.mediaLabel(stream.modelData);
        // a recording stream may be on a monitor, which is a device pipewire
        // keeps no node for and this page therefore cannot offer
        const on = stream.target ? Audio.label(stream.target) : Audio.targetLabel(stream.modelData);
        const where = on !== "" ? (stream.playback ? "on " : "from ") + on : "";
        if (media !== "" && where !== "")
            return media + " · " + where;

        return media !== "" ? media : where;
    }

    signal expandRequested()

    width: parent ? parent.width : 400

    Rectangle {
        id: head

        width: parent.width
        height: 62
        radius: Theme.radiusMd
        color: stream.expanded ? Theme.bgHover : (headArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

        MouseArea {
            id: headArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        M3IconButton {
            id: muteBtn

            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            size: 36
            iconSize: 19
            variant: stream.muted ? "tonal" : "standard"
            iconPath: stream.icon
            onClicked: Audio.toggleMute(stream.modelData)
        }

        Column {
            id: labels

            anchors.left: muteBtn.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round((parent.width - muteBtn.width - 26) * 0.38)
            spacing: 2

            Text {
                width: parent.width
                text: Audio.appLabel(stream.modelData)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.variableAxes: Theme.axes(Theme.fontTitle, 640, 0)
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: stream.subtitle
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                elide: Text.ElideRight
                visible: stream.subtitle !== ""
            }

        }

        M3Slider {
            anchors.left: labels.right
            anchors.leftMargin: 14
            anchors.right: expandBtn.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            from: 0
            to: 100
            stepSize: 1
            decimals: 0
            suffix: "%"
            enabled: !stream.muted
            value: stream.volume
            onMoved: (v) => {
                return Audio.setVolume(stream.modelData, v);
            }
        }

        M3IconButton {
            id: expandBtn

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            size: 32
            iconSize: 18
            enabled: stream.devices.length > 1
            rotation: stream.expanded ? 180 : 0
            iconPath: "expand_more"
            onClicked: stream.expandRequested()

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Theme.easeStandard
                }

            }

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
        height: stream.expanded ? body.implicitHeight : 0
        clip: true

        Column {
            id: body

            width: parent.width
            leftPadding: 61
            rightPadding: 14
            topPadding: 4
            bottomPadding: 16
            spacing: 7
            opacity: stream.expanded ? 1 : 0

            Text {
                text: stream.playback ? "Play this on" : "Listen through"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                font.weight: Font.Medium
            }

            M3Chips {
                width: parent.width - 75
                current: stream.target ? stream.target.name : ""
                options: stream.devices.map((d) => {
                    return {
                        "key": d.name,
                        "label": Audio.label(d)
                    };
                })
                onChosen: (key) => {
                    const device = stream.devices.find((d) => {
                        return d.name === key;
                    });
                    if (device)
                        Audio.move(stream.modelData, device);

                }
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
