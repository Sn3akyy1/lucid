import QtQuick
import Quickshell
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
                    iconPath: Audio.mutedOf(page.sink) ? "volume_off" : "volume_up"
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
                font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
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
                    iconPath: Audio.mutedOf(page.source) ? "mic_off" : "mic"
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
                font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
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
                font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
            }

        }

    }

    SettingCard {
        title: "SYSTEM SOUNDS"
        subtitle: "Short tones for what happens to the machine itself. They keep quiet while notifications are silenced, apart from the battery warnings and the ticks answering a key you pressed."

        SettingRow {
            title: "Play system sounds"
            resetKey: "sysSounds"
            description: "Lucid's own set, made for it. The notification sound and the timer's alarm have switches of their own."

            M3Switch {
                checked: Prefs.sysSounds
                onToggled: (v) => {
                    return Prefs.sysSounds = v;
                }
            }

        }

        SettingRow {
            title: "Volume"
            resetKey: "sysSoundVolume"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "Relative to the output's own volume."
            stacked: true

            M3Slider {
                width: parent.width
                from: 10
                to: 100
                stepSize: 5
                suffix: " %"
                enabled: Prefs.sysSounds
                value: Math.round(Prefs.sysSoundVolume * 100)
                onMoved: (v) => {
                    return Prefs.sysSoundVolume = v / 100;
                }
            }

        }

        SettingRow {
            title: "USB devices"
            resetKey: "soundOnUsb"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "A rising pair as something is plugged in, a falling one as it comes out. The machine's built-in parts stay quiet."

            SoundToggle {
                prefKey: "soundOnUsb"
                sounds: ["usb-in", "usb-out"]
            }

        }

        SettingRow {
            title: "Bluetooth devices"
            resetKey: "soundOnBluetooth"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "A device connecting or dropping away. Switching Bluetooth off stays quiet."

            SoundToggle {
                prefKey: "soundOnBluetooth"
                sounds: ["bt-in", "bt-out"]
            }

        }

        SettingRow {
            title: "Charger"
            resetKey: "soundOnCharger"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "Plugging in, unplugging, and a full charge."

            SoundToggle {
                prefKey: "soundOnCharger"
                sounds: ["power-in", "power-out", "charged"]
            }

        }

        SettingRow {
            title: "Battery warnings"
            resetKey: "soundOnBattery"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "At 20 and 10 %, and a more urgent one at 5 %. These play even while you are silenced."

            SoundToggle {
                prefKey: "soundOnBattery"
                sounds: ["battery-low", "battery-critical"]
            }

        }

        SettingRow {
            title: "Camera"
            resetKey: "soundOnCamera"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "An app starting to use the camera, and letting it go."

            SoundToggle {
                prefKey: "soundOnCamera"
                sounds: ["camera-on", "camera-off"]
            }

        }

        SettingRow {
            title: "Screenshots"
            resetKey: "soundOnCapture"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "As a capture is saved."

            SoundToggle {
                prefKey: "soundOnCapture"
                sounds: ["capture"]
            }

        }

        SettingRow {
            title: "Volume"
            resetKey: "soundOnVolume"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "A tiny tick at the level you just set. A drag or a held key ticks where it starts and where it stops, not at every step."

            SoundToggle {
                prefKey: "soundOnVolume"
                sounds: ["volume"]
            }

        }

        SettingRow {
            title: "Brightness"
            resetKey: "soundOnBrightness"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "The same, a shade brighter. Dimming while you are away stays quiet."

            SoundToggle {
                prefKey: "soundOnBrightness"
                sounds: ["brightness"]
            }

        }

        SettingRow {
            title: "Caps Lock"
            resetKey: "soundOnCaps"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "Up as it goes on, down as it goes off."

            SoundToggle {
                prefKey: "soundOnCaps"
                sounds: ["caps-on", "caps-off"]
            }

        }

        SettingRow {
            title: "Microphone"
            resetKey: "soundOnMic"
            enabled: Prefs.sysSounds
            disabledReason: "System sounds are switched off."
            description: "A blip as it is muted or unmuted, from a key, the bar or anywhere else."
            showDivider: false

            SoundToggle {
                prefKey: "soundOnMic"
                sounds: ["mic-on", "mic-off"]
            }

        }

    }

    // an event's own switch, and a button that plays what it sounds like
    component SoundToggle: Row {
        id: soundToggle

        property string prefKey: ""
        property var sounds: []

        spacing: 4

        M3IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconPath: "play_arrow"
            enabled: Prefs.sysSounds
            onClicked: Sounds.sequence(soundToggle.sounds, Prefs.sysSoundVolume)
        }

        M3Switch {
            anchors.verticalCenter: parent.verticalCenter
            enabled: Prefs.sysSounds
            checked: Prefs[soundToggle.prefKey] === true
            onToggled: (v) => {
                return Prefs.set(soundToggle.prefKey, v);
            }
        }

    }

    component GroupLabel: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitleSm
        font.variableAxes: Theme.axes(Theme.fontTitleSm, 600, 0)
        font.weight: Font.DemiBold
        font.letterSpacing: 0.1
        leftPadding: 22
        topPadding: 14
        bottomPadding: 6
    }

}
