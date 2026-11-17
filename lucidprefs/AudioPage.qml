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
    // the pane is showing and the settings window is open, which is when the
    // meters are worth a capture stream
    readonly property bool shown: page.visible && page.Window.window !== null && page.Window.window.visible
    readonly property bool sinkBalance: Audio.hasBalance(page.sink)
    readonly property var balanceLabels: {
        const out = [];
        for (let v = -100; v <= 100; v += 5) out.push(v === 0 ? I18n.tr("Centre") : (v < 0 ? I18n.tr("Left %1%", (-v)) : I18n.tr("Right %1%", v)))
        return out;
    }
    // listening on a Bluetooth headset's microphone flips it into call mode,
    // so there the input meter waits to be asked
    property bool btListen: false
    readonly property var sourceCard: Audio.cardFor(page.source)
    readonly property bool meterWouldSwitch: !!page.source && page.source.name.indexOf("bluez_input.") === 0 && Audio.wp["bluetooth.autoswitch-to-headset-profile"] !== false && !(page.sourceCard && page.sourceCard.active.indexOf("headset") === 0)
    readonly property string outputSummary: {
        if (Audio.outputs.length === 0)
            return I18n.tr("This machine has nothing to play sound through.");

        if (!page.sink)
            return I18n.tr("Nothing is set as the output yet. Pick one below.");

        const detail = Audio.detailOf(page.sink);
        return Audio.label(page.sink) + (detail !== "" ? " · " + detail : "");
    }
    // the devices on offer, plus any ticked one that is unplugged right now,
    // so it can still be unticked
    readonly property var combineChoices: {
        const out = Audio.combinable.map((n) => {
            return {
                "name": n.name,
                "label": Audio.label(n),
                "present": true
            };
        });
        Audio.combineWanted.forEach((name) => {
            if (!out.some((c) => {
                return c.name === name;
            }))
                out.push({
                "name": name,
                "label": name,
                "present": false
            });

        });
        return out;
    }
    readonly property string inputSummary: {
        if (Audio.inputs.length === 0)
            return I18n.tr("No microphone or other input is plugged into this machine.");

        if (!page.source)
            return I18n.tr("Nothing is set as the input yet. Pick one below.");

        const detail = Audio.detailOf(page.source);
        return Audio.label(page.source) + (detail !== "" ? " · " + detail : "");
    }

    spacing: Theme.dp(26)
    onSourceChanged: page.btListen = false
    Component.onCompleted: {
        Audio.refresh();
        Audio.refreshWp();
    }

    SettingCard {
        title: I18n.tr("OUTPUT")

        SettingRow {
            title: I18n.tr("Volume")
            description: page.outputSummary
            enabled: !!page.sink
            disabledReason: page.outputSummary
            warning: Audio.lastError
            stacked: true

            Column {
                width: parent.width
                spacing: Theme.dp(10)

                Row {
                    width: parent.width
                    spacing: Theme.dp(12)

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.dp(40)
                        iconSize: Theme.dp(21)
                        variant: Audio.mutedOf(page.sink) ? "tonal" : "standard"
                        enabled: !!page.sink
                        iconPath: Audio.mutedOf(page.sink) ? "volume_off" : "volume_up"
                        onClicked: Audio.toggleMute(page.sink)
                    }

                    M3Slider {
                        width: parent.width - Theme.dp(52)
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

                LevelMeter {
                    x: Theme.dp(52)
                    width: parent.width - Theme.dp(52)
                    visible: Prefs.audioMeters
                    node: page.sink
                    running: page.shown && Prefs.audioMeters
                }

            }

        }

        SettingRow {
            title: I18n.tr("Balance")
            enabled: page.sinkBalance
            disabledReason: page.sink ? I18n.tr("This output has a single channel.") : I18n.tr("There is no output.")
            description: I18n.tr("Lean the sound towards the left or the right side.")
            stacked: true

            Row {
                width: parent.width
                spacing: Theme.dp(12)

                M3Slider {
                    width: parent.width - centreBtn.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    from: -100
                    to: 100
                    stepSize: 5
                    stepLabels: page.balanceLabels
                    enabled: page.sinkBalance
                    value: Math.round(Audio.balanceOf(page.sink) * 20) * 5
                    onMoved: (v) => {
                        return Audio.setBalance(page.sink, v / 100);
                    }
                }

                // back to the centre; the readout already says where it is
                M3IconButton {
                    id: centreBtn

                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(40)
                    iconSize: Theme.dp(20)
                    enabled: page.sinkBalance && Math.abs(Audio.balanceOf(page.sink)) > 0.001
                    iconPath: "refresh"
                    onClicked: Audio.setBalance(page.sink, 0)
                }

            }

        }

        SettingRow {
            title: I18n.tr("Test")
            enabled: !!page.sink
            disabledReason: I18n.tr("There is no output to test.")
            description: page.sinkBalance ? I18n.tr("A voice names each side, so you can tell they are the right way round.") : I18n.tr("Play a short voice clip on this output.")

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    variant: "tonal"
                    enabled: !!page.sink
                    text: page.sinkBalance ? I18n.tr("Left") : I18n.tr("Play")
                    onClicked: Audio.testSide(page.sink, page.sinkBalance ? "FL" : "")
                }

                M3Button {
                    variant: "tonal"
                    visible: page.sinkBalance
                    text: I18n.tr("Right")
                    onClicked: Audio.testSide(page.sink, "FR")
                }

            }

        }

        SettingRow {
            title: I18n.tr("Level meters")
            resetKey: "audioMeters"
            description: I18n.tr("A live meter under the output and the microphone volume, so a dead microphone reads apart from a quiet one. They only listen while this page is open.")

            M3Switch {
                checked: Prefs.audioMeters
                onToggled: (v) => {
                    return Prefs.audioMeters = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Move playing apps with the output")
            resetKey: "audioMoveStreams"
            description: I18n.tr("Picking a different output carries anything already playing across to it. With this off, only apps that have no device of their own follow the change.")

            M3Switch {
                checked: Prefs.audioMoveStreams
                onToggled: (v) => {
                    return Prefs.audioMoveStreams = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Play through several at once")
            resetKey: "audioCombine"
            enabled: page.combineChoices.length >= 2
            disabledReason: I18n.tr("This needs two or more outputs.")
            description: I18n.tr("Tick two or more and a Combined output joins the list below, playing on all of them together. Its volume leads, and the slider under each ticked device sets how loud that one plays beside the others. Devices that keep time apart, like the built-in card and a USB or Bluetooth one, can drift a few milliseconds from each other.")
            showDivider: false
            stacked: true

            Column {
                width: parent.width
                spacing: Theme.dp(14)
                visible: page.combineChoices.length >= 2

                Repeater {
                    model: page.combineChoices

                    Column {
                        id: choice

                        required property var modelData
                        readonly property bool member: Audio.isCombineMember(choice.modelData.name)
                        readonly property var node: choice.modelData.present ? (Audio.combinable.find((n) => {
                            return n.name === choice.modelData.name;
                        }) || null) : null

                        width: parent.width
                        spacing: Theme.dp(6)

                        CheckLine {
                            label: choice.modelData.present ? choice.modelData.label : I18n.tr("%1 — not connected", choice.modelData.label)
                            checked: choice.member
                            onToggled: Audio.setCombineMember(choice.modelData.name, !checked)
                        }

                        // the device's own level, which is how loud it plays
                        // beside the others under the combined output's volume
                        Row {
                            x: Theme.dp(27)
                            width: parent.width - x
                            visible: choice.member && !!choice.node
                            spacing: Theme.dp(12)

                            M3IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                size: Theme.dp(36)
                                iconSize: Theme.dp(19)
                                variant: Audio.mutedOf(choice.node) ? "tonal" : "standard"
                                iconPath: Audio.mutedOf(choice.node) ? "volume_off" : "volume_up"
                                onClicked: Audio.toggleMute(choice.node)
                            }

                            M3Slider {
                                width: parent.width - Theme.dp(48)
                                anchors.verticalCenter: parent.verticalCenter
                                from: 0
                                to: 100
                                stepSize: 1
                                decimals: 0
                                suffix: "%"
                                enabled: !Audio.mutedOf(choice.node)
                                value: Audio.volumeOf(choice.node)
                                onMoved: (v) => {
                                    return Audio.setVolume(choice.node, v);
                                }
                            }

                        }

                    }

                }

            }

        }

        Column {
            width: parent.width
            topPadding: Theme.dp(4)
            bottomPadding: Theme.dp(8)
            spacing: Theme.dp(2)

            GroupLabel {
                text: I18n.tr("Play sound through")
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
                topPadding: Theme.dp(18)
                bottomPadding: Theme.dp(18)
                text: I18n.tr("No outputs. A card switched off in its mode below offers none, and a Bluetooth speaker has to be connected on the Bluetooth page first.")
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
                wrapMode: Text.WordWrap
            }

        }

    }

    SettingCard {
        title: I18n.tr("INPUT")

        SettingRow {
            title: I18n.tr("Microphone volume")
            description: page.inputSummary
            enabled: !!page.source
            disabledReason: page.inputSummary
            showDivider: false
            stacked: true

            Column {
                width: parent.width
                spacing: Theme.dp(10)

                Row {
                    width: parent.width
                    spacing: Theme.dp(12)

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.dp(40)
                        iconSize: Theme.dp(21)
                        variant: Audio.mutedOf(page.source) ? "tonal" : "standard"
                        enabled: !!page.source
                        iconPath: Audio.mutedOf(page.source) ? "mic_off" : "mic"
                        onClicked: Audio.toggleMute(page.source)
                    }

                    M3Slider {
                        width: parent.width - Theme.dp(52)
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

                LevelMeter {
                    x: Theme.dp(52)
                    width: parent.width - Theme.dp(52)
                    visible: Prefs.audioMeters
                    node: page.source
                    running: page.shown && Prefs.audioMeters && (!page.meterWouldSwitch || page.btListen)
                }

                Item {
                    x: Theme.dp(52)
                    width: parent.width - Theme.dp(52)
                    height: Math.max(listenText.implicitHeight, listenBtn.height)
                    visible: Prefs.audioMeters && page.meterWouldSwitch

                    Text {
                        id: listenText

                        anchors.left: parent.left
                        anchors.right: listenBtn.left
                        anchors.rightMargin: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.btListen ? I18n.tr("Listening. The headset plays at call quality until you stop.") : I18n.tr("The meter waits here: listening to a Bluetooth headset's microphone switches it to call-quality sound.")
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyMd
                        wrapMode: Text.WordWrap
                    }

                    M3Button {
                        id: listenBtn

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        variant: page.btListen ? "filled" : "tonal"
                        text: page.btListen ? I18n.tr("Stop") : I18n.tr("Listen")
                        onClicked: page.btListen = !page.btListen
                    }

                }

            }

        }

        Column {
            width: parent.width
            topPadding: Theme.dp(4)
            bottomPadding: Theme.dp(8)
            spacing: Theme.dp(2)

            GroupLabel {
                text: I18n.tr("Record from")
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
                topPadding: Theme.dp(18)
                bottomPadding: Theme.dp(18)
                text: I18n.tr("Nothing to record from. A headset has to be in a mode that includes its microphone before it shows up here.")
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
                wrapMode: Text.WordWrap
            }

        }

    }

    SettingCard {
        title: I18n.tr("APPLICATIONS")
        subtitle: I18n.tr("Everything making or taking sound right now. Each one keeps its own volume and can be sent to a device of its own.")

        Column {
            width: parent.width
            topPadding: Theme.dp(2)
            bottomPadding: Theme.dp(8)
            spacing: Theme.dp(2)

            GroupLabel {
                text: I18n.tr("Playing")
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
                text: I18n.tr("Recording")
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
                topPadding: Theme.dp(18)
                bottomPadding: Theme.dp(18)
                text: I18n.tr("Nothing is playing or recording.")
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
            }

        }

    }

    SettingCard {
        title: I18n.tr("BEHAVIOUR")
        subtitle: I18n.tr("Kept by WirePlumber, so they hold for every application and survive a restart.")

        WpSwitchRow {
            wpKey: "node.stream.restore-props"
            title: I18n.tr("Remember each application's volume")
            description: I18n.tr("An application starts at the volume and mute it had the last time.")
        }

        WpSwitchRow {
            wpKey: "node.stream.restore-target"
            title: I18n.tr("Remember where each application plays")
            description: I18n.tr("An application you sent to another device goes back there the next time it starts.")
        }

        WpSwitchRow {
            wpKey: "linking.follow-default-target"
            title: I18n.tr("Move sound along with the default device")
            description: I18n.tr("Applications playing on the default device follow it when you choose another one.")
        }

        WpSwitchRow {
            wpKey: "linking.pause-playback"
            title: I18n.tr("Pause media when its device goes away")
            description: I18n.tr("Players pause when headphones are unplugged or a headset disconnects, instead of carrying on through the speakers.")
        }

        WpSwitchRow {
            wpKey: "bluetooth.autoswitch-to-headset-profile"
            title: I18n.tr("Switch headsets to call mode for their microphone")
            description: I18n.tr("When an application records from a Bluetooth headset, it changes to the headset profile: the microphone works, and playback drops to call quality until the recording stops.")
        }

        SettingRow {
            title: I18n.tr("Bluetooth headsets favour")
            enabled: Audio.wp["bluetooth.profile-preference"] !== undefined
            disabledReason: Audio.wpRead ? I18n.tr("This version of WirePlumber does not have this setting.") : I18n.tr("WirePlumber's settings could not be read. They need wpctl from WirePlumber 0.5 or newer.")
            description: I18n.tr("What WirePlumber leans towards when it picks a headset's mode by itself.")

            M3Segmented {
                width: Theme.dp(240)
                enabled: Audio.wp["bluetooth.profile-preference"] !== undefined
                current: Audio.wp["bluetooth.profile-preference"] === "latency" ? "latency" : "quality"
                options: [{
                    "key": "quality",
                    "label": I18n.tr("Quality")
                }, {
                    "key": "latency",
                    "label": I18n.tr("Latency")
                }]
                onChosen: (key) => {
                    return Audio.setWp("bluetooth.profile-preference", key);
                }
            }

        }

        WpSwitchRow {
            wpKey: "node.features.audio.mono"
            title: I18n.tr("Mono audio")
            description: I18n.tr("Play the left and right channels together on every speaker and headphone. Every output restarts for a moment when this changes.")
            showDivider: false
        }

    }

    SettingCard {
        title: I18n.tr("SYSTEM SOUNDS")
        subtitle: I18n.tr("Short tones for what happens to the machine itself. They keep quiet while notifications are silenced, apart from the battery warnings and the ticks answering a key you pressed.")

        SettingRow {
            title: I18n.tr("Play system sounds")
            resetKey: "sysSounds"
            description: I18n.tr("Lucid's own set, made for it. The notification sound and the timer's alarm have switches of their own.")

            M3Switch {
                checked: Prefs.sysSounds
                onToggled: (v) => {
                    return Prefs.sysSounds = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Volume")
            resetKey: "sysSoundVolume"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("Relative to the output's own volume.")
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
            title: I18n.tr("USB devices")
            resetKey: "soundOnUsb"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("A rising pair as something is plugged in, a falling one as it comes out. The machine's built-in parts stay quiet.")

            SoundToggle {
                prefKey: "soundOnUsb"
                sounds: ["usb-in", "usb-out"]
            }

        }

        SettingRow {
            title: I18n.tr("Bluetooth devices")
            resetKey: "soundOnBluetooth"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("A device connecting or dropping away. Switching Bluetooth off stays quiet.")

            SoundToggle {
                prefKey: "soundOnBluetooth"
                sounds: ["bt-in", "bt-out"]
            }

        }

        SettingRow {
            title: I18n.tr("Charger")
            resetKey: "soundOnCharger"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("Plugging in, unplugging, and a full charge.")

            SoundToggle {
                prefKey: "soundOnCharger"
                sounds: ["power-in", "power-out", "charged"]
            }

        }

        SettingRow {
            title: I18n.tr("Battery warnings")
            resetKey: "soundOnBattery"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("At 20 and 10 %, and a more urgent one at 5 %. These play even while you are silenced.")

            SoundToggle {
                prefKey: "soundOnBattery"
                sounds: ["battery-low", "battery-critical"]
            }

        }

        SettingRow {
            title: I18n.tr("Camera")
            resetKey: "soundOnCamera"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("An app starting to use the camera, and letting it go.")

            SoundToggle {
                prefKey: "soundOnCamera"
                sounds: ["camera-on", "camera-off"]
            }

        }

        SettingRow {
            title: I18n.tr("Screenshots")
            resetKey: "soundOnCapture"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("As a capture is saved.")

            SoundToggle {
                prefKey: "soundOnCapture"
                sounds: ["capture"]
            }

        }

        SettingRow {
            title: I18n.tr("Volume")
            resetKey: "soundOnVolume"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("A tiny tick at the level you just set. A drag or a held key ticks where it starts and where it stops, not at every step.")

            SoundToggle {
                prefKey: "soundOnVolume"
                sounds: ["volume"]
            }

        }

        SettingRow {
            title: I18n.tr("Brightness")
            resetKey: "soundOnBrightness"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("The same, a shade brighter. Dimming while you are away stays quiet.")

            SoundToggle {
                prefKey: "soundOnBrightness"
                sounds: ["brightness"]
            }

        }

        SettingRow {
            title: I18n.tr("Caps Lock")
            resetKey: "soundOnCaps"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("Up as it goes on, down as it goes off.")

            SoundToggle {
                prefKey: "soundOnCaps"
                sounds: ["caps-on", "caps-off"]
            }

        }

        SettingRow {
            title: I18n.tr("Microphone")
            resetKey: "soundOnMic"
            enabled: Prefs.sysSounds
            disabledReason: I18n.tr("System sounds are switched off.")
            description: I18n.tr("A blip as it is muted or unmuted, from a key, the bar or anywhere else.")
            showDivider: false

            SoundToggle {
                prefKey: "soundOnMic"
                sounds: ["mic-on", "mic-off"]
            }

        }

    }

    component WpSwitchRow: SettingRow {
        id: wpRow

        property string wpKey: ""
        readonly property bool known: Audio.wp[wpRow.wpKey] !== undefined

        enabled: wpRow.known
        disabledReason: Audio.wpRead ? I18n.tr("This version of WirePlumber does not have this setting.") : I18n.tr("WirePlumber's settings could not be read. They need wpctl from WirePlumber 0.5 or newer.")

        M3Switch {
            enabled: wpRow.known
            checked: Audio.wp[wpRow.wpKey] === true
            onToggled: (v) => {
                return Audio.setWp(wpRow.wpKey, v);
            }
        }

    }

    // an event's own switch, and a button that plays what it sounds like
    component SoundToggle: Row {
        id: soundToggle

        property string prefKey: ""
        property var sounds: []

        spacing: Theme.dp(4)

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
        leftPadding: Theme.dp(22)
        topPadding: Theme.dp(14)
        bottomPadding: Theme.dp(6)
    }

}
