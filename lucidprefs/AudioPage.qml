import QtQuick
import qs

Column {
    id: page

    property string expandedOut: ""
    property string expandedIn: ""
    property string expandedStream: ""
    readonly property var sink: Audio.sink
    readonly property var source: Audio.source
    readonly property string outputSummary: {
        if (Audio.outputs.length === 0)
            return "This machine has nothing to play sound through.";

        if (!page.sink)
            return "Nothing is set as the output yet. Pick one below.";

        const detail = Audio.detailOf(page.sink);
        return Audio.label(page.sink) + (detail !== "" ? " · " + detail : "");
    }
    readonly property string inputSummary: {
        if (Audio.inputs.length === 0)
            return "No microphone or other input is plugged into this machine.";

        if (!page.source)
            return "Nothing is set as the input yet. Pick one below.";

        const detail = Audio.detailOf(page.source);
        return Audio.label(page.source) + (detail !== "" ? " · " + detail : "");
    }

    spacing: 26
    Component.onCompleted: Audio.refresh()

    SettingCard {
        title: "OUTPUT"

        SettingRow {
            title: "Volume"
            description: page.outputSummary
            enabled: !!page.sink
            disabledReason: page.outputSummary
            warning: Audio.lastError
            stacked: true

            Row {
                width: parent.width
                spacing: 12

                M3IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    iconSize: 21
                    variant: Audio.mutedOf(page.sink) ? "tonal" : "standard"
                    enabled: !!page.sink
                    iconPath: Audio.mutedOf(page.sink) ? "M12 4 9.91 6.09 12 8.18V4ZM4.27 3 3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06a8.94 8.94 0 0 0 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3ZM19 12c0 .82-.15 1.61-.41 2.34l1.53 1.53A8.9 8.9 0 0 0 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71Zm-2.5 0c0-1.77-1.02-3.29-2.5-4.03v1.79l2.48 2.48c.01-.08.02-.16.02-.24Z" : "M3 9v6h4l5 5V4L7 9H3Zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02ZM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77Z"
                    onClicked: Audio.toggleMute(page.sink)
                }

                M3Slider {
                    width: parent.width - 52
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: 100
                    stepSize: 1
                    decimals: 0
                    suffix: "%"
                    enabled: !!page.sink && !Audio.mutedOf(page.sink)
                    value: Audio.volumeOf(page.sink)
                    onMoved: (v) => {
                        return Audio.setVolume(page.sink, v);
                    }
                }

            }

        }

        SettingRow {
            title: "Move playing apps with the output"
            resetKey: "audioMoveStreams"
            description: "Picking a different output carries anything already playing across to it. With this off, only apps that have no device of their own follow the change."
            showDivider: false

            M3Switch {
                checked: Prefs.audioMoveStreams
                onToggled: (v) => {
                    return Prefs.audioMoveStreams = v;
                }
            }

        }

        Column {
            width: parent.width
            topPadding: 4
            bottomPadding: 8
            spacing: 2

            GroupLabel {
                text: "Play sound through"
                visible: Audio.outputs.length > 0
            }

            Repeater {
                model: Audio.outputs

                AudioDeviceRow {
                    expanded: page.expandedOut === modelData.name
                    onExpandRequested: page.expandedOut = expanded ? "" : modelData.name
                }

            }

            Text {
                width: parent.width
                visible: Audio.outputs.length === 0
                horizontalAlignment: Text.AlignHCenter
                topPadding: 18
                bottomPadding: 18
                text: "No outputs. A card switched off in its mode below offers none, and a Bluetooth speaker has to be connected on the Bluetooth page first."
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
            }

        }

    }

    SettingCard {
        title: "INPUT"

        SettingRow {
            title: "Microphone volume"
            description: page.inputSummary
            enabled: !!page.source
            disabledReason: page.inputSummary
            showDivider: false
            stacked: true

            Row {
                width: parent.width
                spacing: 12

                M3IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    iconSize: 21
                    variant: Audio.mutedOf(page.source) ? "tonal" : "standard"
                    enabled: !!page.source
                    iconPath: Audio.mutedOf(page.source) ? "M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28Zm-4.02.17c0-.06.02-.11.02-.17V5a3 3 0 0 0-6 0v.18l5.98 5.99ZM4.27 3 3 4.27l6.01 6.01V11a3 3 0 0 0 3 3c.22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52a5 5 0 0 1-5-5H5c0 3.03 2.39 5.53 5.4 5.94V21h2v-3.06c.82-.11 1.59-.38 2.29-.77L19.73 21 21 19.73 4.27 3Z" : "M12 14a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3Zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.42 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7Z"
                    onClicked: Audio.toggleMute(page.source)
                }

                M3Slider {
                    width: parent.width - 52
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: 100
                    stepSize: 1
                    decimals: 0
                    suffix: "%"
                    enabled: !!page.source && !Audio.mutedOf(page.source)
                    value: Audio.volumeOf(page.source)
                    onMoved: (v) => {
                        return Audio.setVolume(page.source, v);
                    }
                }

            }

        }

        Column {
            width: parent.width
            topPadding: 4
            bottomPadding: 8
            spacing: 2

            GroupLabel {
                text: "Record from"
                visible: Audio.inputs.length > 0
            }

            Repeater {
                model: Audio.inputs

                AudioDeviceRow {
                    expanded: page.expandedIn === modelData.name
                    onExpandRequested: page.expandedIn = expanded ? "" : modelData.name
                }

            }

            Text {
                width: parent.width
                visible: Audio.inputs.length === 0
                horizontalAlignment: Text.AlignHCenter
                topPadding: 18
                bottomPadding: 18
                text: "Nothing to record from. A headset has to be in a mode that includes its microphone before it shows up here."
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
            }

        }

    }

    SettingCard {
        title: "APPLICATIONS"
        subtitle: "Everything making or taking sound right now. Each one keeps its own volume and can be sent to a device of its own."

        Column {
            width: parent.width
            topPadding: 2
            bottomPadding: 8
            spacing: 2

            GroupLabel {
                text: "Playing"
                visible: Audio.playbackStreams.length > 0
            }

            Repeater {
                model: Audio.playbackStreams

                AudioStreamRow {
                    expanded: page.expandedStream === "out:" + modelData.id
                    onExpandRequested: page.expandedStream = expanded ? "" : "out:" + modelData.id
                }

            }

            GroupLabel {
                text: "Recording"
                visible: Audio.recordStreams.length > 0
            }

            Repeater {
                model: Audio.recordStreams

                AudioStreamRow {
                    expanded: page.expandedStream === "in:" + modelData.id
                    onExpandRequested: page.expandedStream = expanded ? "" : "in:" + modelData.id
                }

            }

            Text {
                width: parent.width
                visible: Audio.playbackStreams.length === 0 && Audio.recordStreams.length === 0
                horizontalAlignment: Text.AlignHCenter
                topPadding: 18
                bottomPadding: 18
                text: "Nothing is playing or recording."
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
            }

        }

    }

    component GroupLabel: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitleSm
        font.weight: Font.DemiBold
        font.letterSpacing: 0.1
        leftPadding: 22
        topPadding: 14
        bottomPadding: 6
    }

}
