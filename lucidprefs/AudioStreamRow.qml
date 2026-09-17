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
    // sent to a device of its own, rather than following the default
    readonly property bool pinned: Audio.isPinned(stream.modelData)
    // recording what an output plays (a visualiser): the default input is a
    // microphone, so there is no default to hand it back to
    readonly property bool canFollow: !(!stream.playback && Audio.onMonitor(stream.modelData))
    // a stream that records is muted with a microphone, not with a speaker
    readonly property string icon: {
        if (stream.playback)
            return stream.muted ? "M12 4 9.91 6.09 12 8.18V4ZM4.27 3 3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06a8.94 8.94 0 0 0 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3ZM19 12c0 .82-.15 1.61-.41 2.34l1.53 1.53A8.9 8.9 0 0 0 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71Zm-2.5 0c0-1.77-1.02-3.29-2.5-4.03v1.79l2.48 2.48c.01-.08.02-.16.02-.24Z" : "M3 9v6h4l5 5V4L7 9H3Zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02ZM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77Z";

        return stream.muted ? "M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28Zm-4.02.17c0-.06.02-.11.02-.17V5a3 3 0 0 0-6 0v.18l5.98 5.99ZM4.27 3 3 4.27l6.01 6.01V11a3 3 0 0 0 3 3c.22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52a5 5 0 0 1-5-5H5c0 3.03 2.39 5.53 5.4 5.94V21h2v-3.06c.82-.11 1.59-.38 2.29-.77L19.73 21 21 19.73 4.27 3Z" : "M12 14a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3Zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.42 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7Z";
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
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: stream.subtitle
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
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
            enabled: stream.devices.length > 1 || (stream.pinned && stream.canFollow)
            rotation: stream.expanded ? 180 : 0
            iconPath: "M7.41 8.59 12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41Z"
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
                font.weight: Font.Medium
            }

            M3Chips {
                width: parent.width - 75
                current: (stream.pinned || !stream.canFollow) && stream.target ? stream.target.name : ""
                options: (stream.canFollow ? [{
                    "key": "",
                    "label": "Default device"
                }] : []).concat(stream.devices.map((d) => {
                    return {
                        "key": d.name,
                        "label": Audio.label(d)
                    };
                }))
                onChosen: (key) => {
                    if (key === "") {
                        Audio.followDefault(stream.modelData);
                        return ;
                    }
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
