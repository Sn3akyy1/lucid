import QtQuick
import Quickshell
import qs

Column {
    id: page

    property int tick: 0
    readonly property bool quietNow: {
        page.tick;
        return Prefs.inQuietWindow(Loc.now());
    }
    readonly property string quietDescription: {
        if (!Prefs.quietHours)
            return I18n.tr("Hold popups back between two times every day. They still collect in the list.");

        var span = Prefs.minutesText(Prefs.quietFrom) + " to " + Prefs.minutesText(Prefs.quietTo);
        return page.quietNow ? I18n.tr("Quiet now — %1 every day.", span) : I18n.tr("Quiet from %1 every day.", span);
    }
    readonly property string clearLabel: Prefs.liveNotifCount === 0 ? I18n.tr("Nothing to clear") : (Prefs.liveNotifCount === 1 ? I18n.tr("Clear 1 notification") : I18n.tr("Clear %1 notifications", Prefs.liveNotifCount))
    // apps you have muted are always listed, even ones this session has not seen
    readonly property var appList: {
        var seen = Prefs.seenApps.slice();
        for (var i = 0; i < Prefs.mutedApps.length; i++) {
            if (seen.indexOf(Prefs.mutedApps[i]) === -1)
                seen.push(Prefs.mutedApps[i]);

        }
        return seen.sort((a, b) => {
            return a.toLowerCase().localeCompare(b.toLowerCase());
        });
    }

    spacing: Theme.dp(26)

    // only for the quiet-hours readout, so it can idle when there is none
    Timer {
        interval: 20000
        repeat: true
        running: Prefs.quietHours
        triggeredOnStart: true
        onTriggered: page.tick++
    }

    SettingCard {
        title: I18n.tr("POPUPS")

        SettingRow {
            title: I18n.tr("Show popups")
            resetKey: "toastEnabled"
            enabled: Prefs.barNotifications
            disabledReason: I18n.tr("Notifications are switched off, so nothing is shown or collected.")
            description: I18n.tr("Slide a notification out of the bar as it arrives. With this off they go straight to the list.")

            M3Switch {
                checked: Prefs.toastEnabled
                enabled: Prefs.barNotifications
                onToggled: (v) => {
                    return Prefs.toastEnabled = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("How many at once")
            resetKey: "toastMaxVisible"
            enabled: Prefs.barNotifications && Prefs.toastEnabled
            disabledReason: I18n.tr("Popups are switched off.")
            description: I18n.tr("A burst of notifications stacks under the bar. Anything past this waits in the list instead.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 6
                stepSize: 1
                enabled: Prefs.barNotifications && Prefs.toastEnabled
                value: Prefs.toastMaxVisible
                onMoved: (v) => {
                    return Prefs.toastMaxVisible = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("How long one stays")
            resetKey: "toastTimeout"
            enabled: Prefs.barNotifications && Prefs.toastEnabled
            disabledReason: I18n.tr("Popups are switched off.")
            description: I18n.tr("The time a popup is left on screen when the application does not ask for something else.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 30
                stepSize: 1
                suffix: " s"
                enabled: Prefs.barNotifications && Prefs.toastEnabled
                value: Prefs.toastTimeout
                onMoved: (v) => {
                    return Prefs.toastTimeout = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Let applications set their own")
            resetKey: "toastUseAppTimeout"
            enabled: Prefs.barNotifications && Prefs.toastEnabled
            disabledReason: I18n.tr("Popups are switched off.")
            description: I18n.tr("Most applications name a duration when they send a notification. Turn this off to give every popup the same time above.")

            M3Switch {
                checked: Prefs.toastUseAppTimeout
                enabled: Prefs.barNotifications && Prefs.toastEnabled
                onToggled: (v) => {
                    return Prefs.toastUseAppTimeout = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Keep urgent ones up")
            resetKey: "toastCriticalSticky"
            enabled: Prefs.barNotifications && Prefs.toastEnabled
            disabledReason: I18n.tr("Popups are switched off.")
            description: I18n.tr("A notification marked urgent — a low battery, a failed backup — waits for you instead of timing out.")

            M3Switch {
                checked: Prefs.toastCriticalSticky
                enabled: Prefs.barNotifications && Prefs.toastEnabled
                onToggled: (v) => {
                    return Prefs.toastCriticalSticky = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Show the message")
            resetKey: "toastShowBody"
            enabled: Prefs.barNotifications && Prefs.toastEnabled
            disabledReason: I18n.tr("Popups are switched off.")
            description: I18n.tr("With this off a popup carries the title alone, and the body waits in the list.")

            M3Switch {
                checked: Prefs.toastShowBody
                enabled: Prefs.barNotifications && Prefs.toastEnabled
                onToggled: (v) => {
                    return Prefs.toastShowBody = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Lines of message")
            resetKey: "toastBodyLines"
            enabled: Prefs.barNotifications && Prefs.toastEnabled && Prefs.toastShowBody
            disabledReason: I18n.tr("The message body is hidden.")
            description: I18n.tr("How far a long message is allowed to run before it is cut short.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 10
                stepSize: 1
                enabled: Prefs.barNotifications && Prefs.toastEnabled && Prefs.toastShowBody
                value: Prefs.toastBodyLines
                onMoved: (v) => {
                    return Prefs.toastBodyLines = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Show buttons")
            resetKey: "toastShowActions"
            enabled: Prefs.barNotifications && Prefs.toastEnabled
            disabledReason: I18n.tr("Popups are switched off.")
            description: I18n.tr("Reply, Open, Snooze — whatever the application offers, on the popup itself. They are always in the list.")

            M3Switch {
                checked: Prefs.toastShowActions
                enabled: Prefs.barNotifications && Prefs.toastEnabled
                onToggled: (v) => {
                    return Prefs.toastShowActions = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Reply without switching")
            resetKey: "notifInlineReply"
            enabled: Prefs.barNotifications
            disabledReason: I18n.tr("Notifications are switched off, so nothing is shown or collected.")
            description: I18n.tr("Chat applications that support it get a message box on the notification itself, so you can answer without leaving what you are doing.")
            showDivider: false

            M3Switch {
                checked: Prefs.notifInlineReply
                enabled: Prefs.barNotifications
                onToggled: (v) => {
                    return Prefs.notifInlineReply = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("DO NOT DISTURB")

        SettingRow {
            title: I18n.tr("Do not disturb")
            resetKey: "doNotDisturb"
            description: I18n.tr("No popups and no sound. Everything is still collected in the list, and the bell in the bar turns to a moon.")

            M3Switch {
                checked: Prefs.doNotDisturb
                onToggled: (v) => {
                    return Prefs.doNotDisturb = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Let urgent ones through")
            resetKey: "dndAllowCritical"
            description: I18n.tr("Notifications marked urgent still appear while you are silenced, however you were silenced.")

            M3Switch {
                checked: Prefs.dndAllowCritical
                onToggled: (v) => {
                    return Prefs.dndAllowCritical = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Silence over a fullscreen window")
            resetKey: "dndFullscreen"
            description: I18n.tr("Films and games are left alone. The notifications wait in the list for you.")

            M3Switch {
                checked: Prefs.dndFullscreen
                onToggled: (v) => {
                    return Prefs.dndFullscreen = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Quiet hours")
            resetKey: "quietHours"
            description: page.quietDescription

            M3Switch {
                checked: Prefs.quietHours
                onToggled: (v) => {
                    return Prefs.quietHours = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Between")
            enabled: Prefs.quietHours
            disabledReason: I18n.tr("Quiet hours are switched off.")
            description: I18n.tr("Written as 22:00. An end earlier than the start runs through midnight.")
            showDivider: false

            Row {
                spacing: Theme.dp(10)

                M3TextField {
                    id: fromField

                    width: Theme.dp(96)
                    enabled: Prefs.quietHours
                    placeholder: "22:00"
                    text: Prefs.minutesText(Prefs.quietFrom)
                    onAccepted: (v) => {
                        var m = Prefs.parseMinutes(v);
                        if (m >= 0)
                            Prefs.quietFrom = m;

                        fromField.text = Prefs.minutesText(Prefs.quietFrom);
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("to")
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
                    opacity: Prefs.quietHours ? 1 : 0.38
                }

                M3TextField {
                    id: toField

                    width: Theme.dp(96)
                    enabled: Prefs.quietHours
                    placeholder: "07:00"
                    text: Prefs.minutesText(Prefs.quietTo)
                    onAccepted: (v) => {
                        var m = Prefs.parseMinutes(v);
                        if (m >= 0)
                            Prefs.quietTo = m;

                        toField.text = Prefs.minutesText(Prefs.quietTo);
                    }
                }

            }

        }

    }

    SettingCard {
        title: I18n.tr("SOUND")

        SettingRow {
            title: I18n.tr("Play a sound")
            resetKey: "notifSound"
            description: I18n.tr("A short chime as a notification arrives. Nothing plays while you are silenced.")

            M3Switch {
                checked: Prefs.notifSound
                onToggled: (v) => {
                    return Prefs.notifSound = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Which sound")
            resetKey: "notifSoundName"
            enabled: Prefs.notifSound
            disabledReason: I18n.tr("Sound is switched off.")
            description: I18n.tr("Lucid's own set. Picking one plays it.")
            stacked: true

            Row {
                width: parent.width
                spacing: Theme.dp(12)

                M3Chips {
                    width: parent.width - playSound.width - Theme.dp(12)
                    enabled: Prefs.notifSound
                    current: Sounds.notifKey(Prefs.notifSoundName)
                    options: Sounds.notifSounds
                    onChosen: (key) => {
                        Prefs.notifSoundName = key;
                        Sounds.play(key, Prefs.notifSoundVolume);
                    }
                }

                M3Button {
                    id: playSound

                    text: I18n.tr("Play")
                    variant: "tonal"
                    enabled: Prefs.notifSound
                    onClicked: Sounds.play(Sounds.notifKey(Prefs.notifSoundName), Prefs.notifSoundVolume)
                }

            }

        }

        SettingRow {
            title: I18n.tr("Volume")
            resetKey: "notifSoundVolume"
            enabled: Prefs.notifSound
            disabledReason: I18n.tr("Sound is switched off.")
            description: I18n.tr("Relative to whatever the notification sink is set to.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 10
                to: 100
                stepSize: 5
                suffix: " %"
                enabled: Prefs.notifSound
                value: Math.round(Prefs.notifSoundVolume * 100)
                onMoved: (v) => {
                    return Prefs.notifSoundVolume = v / 100;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Only for urgent ones")
            resetKey: "notifSoundUrgentOnly"
            enabled: Prefs.notifSound
            disabledReason: I18n.tr("Sound is switched off.")
            description: I18n.tr("Stay quiet for the ordinary traffic and speak up only for what is marked urgent.")
            showDivider: false

            M3Switch {
                checked: Prefs.notifSoundUrgentOnly
                enabled: Prefs.notifSound
                onToggled: (v) => {
                    return Prefs.notifSoundUrgentOnly = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("THE LIST")

        SettingRow {
            title: I18n.tr("Show application icons")
            resetKey: "notifShowIcons"
            description: I18n.tr("The sending application's icon beside each notification, in the list and on the popup.")

            M3Switch {
                checked: Prefs.notifShowIcons
                onToggled: (v) => {
                    return Prefs.notifShowIcons = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Group by application")
            resetKey: "notifGrouping"
            description: I18n.tr("One application's notifications collapse into a single stack you can open, instead of filling the list one by one.")

            M3Switch {
                checked: Prefs.notifGrouping
                onToggled: (v) => {
                    return Prefs.notifGrouping = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Show times")
            resetKey: "notifTimestamps"
            description: I18n.tr("How long ago each one arrived, beside the application's name, and a heading splitting new ones from the rest.")

            M3Switch {
                checked: Prefs.notifTimestamps
                onToggled: (v) => {
                    return Prefs.notifTimestamps = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Show progress")
            resetKey: "notifProgress"
            description: I18n.tr("File copies, downloads and transfers report how far along they are. This draws it as a bar that fills in place.")

            M3Switch {
                checked: Prefs.notifProgress
                onToggled: (v) => {
                    return Prefs.notifProgress = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Keep at most")
            resetKey: "notifMaxHistory"
            description: I18n.tr("Once the list is this long the oldest notification drops off the end as a new one arrives.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 10
                to: 200
                stepSize: 10
                value: Prefs.notifMaxHistory
                onMoved: (v) => {
                    return Prefs.notifMaxHistory = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Clear the list")
            description: I18n.tr("Dismisses everything the shell is holding right now. The applications are not told anything else.")
            showDivider: false

            M3Button {
                text: page.clearLabel
                variant: "tonal"
                enabled: Prefs.liveNotifCount > 0
                onClicked: Prefs.notificationsClearRequested()
            }

        }

    }

    SettingCard {
        title: I18n.tr("APPLICATIONS")

        SettingRow {
            title: I18n.tr("Muted applications")
            description: page.appList.length === 0 ? I18n.tr("Nothing has sent a notification yet. Once something does it is listed here to mute.") : I18n.tr("A muted application's notifications are turned away as they arrive — no popup, no sound, nothing in the list.")
            stacked: true
            showDivider: page.appList.length > 0

            Column {
                width: parent.width
                spacing: Theme.dp(14)
                visible: page.appList.length > 0

                Repeater {
                    model: page.appList

                    CheckLine {
                        required property var modelData

                        label: modelData
                        checked: Prefs.isMuted(modelData)
                        onToggled: Prefs.setMuted(modelData, !checked)
                    }

                }

            }

        }

        SettingRow {
            title: I18n.tr("Mute one by name")
            description: I18n.tr("Use the name the application gives itself, spelled the same way. Press Enter to add it.")
            showDivider: Prefs.notifSeenApps !== ""

            M3TextField {
                id: muteField

                width: Theme.dp(260)
                placeholder: I18n.tr("Spotify")
                onAccepted: (v) => {
                    var name = v.trim();
                    if (name !== "") {
                        Prefs.noteApp(name);
                        Prefs.setMuted(name, true);
                    }
                    muteField.clear();
                }
            }

        }

        SettingRow {
            title: I18n.tr("Forget the list")
            visible: Prefs.notifSeenApps !== ""
            description: I18n.tr("Empties the roll of applications seen above. Whatever you muted stays muted, and anything that sends a notification is listed again.")
            showDivider: false

            M3Button {
                text: I18n.tr("Forget")
                variant: "text"
                onClicked: Prefs.notifSeenApps = ""
            }

        }

    }

    SettingCard {
        title: I18n.tr("SYSTEM EVENTS")

        SettingRow {
            title: I18n.tr("Keyboard layout")
            resetKey: "toastOnLayout"
            description: I18n.tr("A small toast at the top of the screen with the layout you switched to.")

            M3Switch {
                checked: Prefs.toastOnLayout
                onToggled: (v) => {
                    return Prefs.toastOnLayout = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Lock keys and microphone")
            resetKey: "osdToggles"
            description: I18n.tr("Where Caps Lock, Num Lock and muting the microphone show up: on the OSD at the bottom, with volume and brightness, or as a toast at the top like the rest of these events.")

            M3Segmented {
                width: Theme.dp(220)
                current: Prefs.osdToggles
                options: [{
                    "key": "osd",
                    "label": I18n.tr("OSD")
                }, {
                    "key": "toast",
                    "label": I18n.tr("Toast")
                }]
                onChosen: (key) => {
                    return Prefs.osdToggles = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Game mode")
            resetKey: "toastOnGameMode"
            enabled: Prefs.gameModeStateFile !== ""
            disabledReason: I18n.tr("Game mode is noticed by watching the file its status command checks. Set the status command under Bar → System module to something like test -f /run/gamemode.state.")
            description: I18n.tr("When game mode turns on or off - from the tile, a keybind or anywhere else.")

            M3Switch {
                checked: Prefs.toastOnGameMode
                enabled: Prefs.gameModeStateFile !== ""
                onToggled: (v) => {
                    return Prefs.toastOnGameMode = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Battery and charger")
            resetKey: "toastOnBattery"
            description: I18n.tr("Plugging in or out, a full charge, and warnings at 20, 10 and 5 %.")

            M3Switch {
                checked: Prefs.toastOnBattery
                onToggled: (v) => {
                    return Prefs.toastOnBattery = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Bluetooth devices")
            resetKey: "toastOnBluetooth"
            description: I18n.tr("A device connecting, with its battery when it reports one, or disconnecting. Switching Bluetooth off stays quiet.")

            M3Switch {
                checked: Prefs.toastOnBluetooth
                onToggled: (v) => {
                    return Prefs.toastOnBluetooth = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("USB devices")
            resetKey: "toastOnUsb"
            description: I18n.tr("Something plugged into a USB port, or pulled out. The machine's own built-in parts, like the camera, stay quiet.")

            M3Switch {
                checked: Prefs.toastOnUsb
                onToggled: (v) => {
                    return Prefs.toastOnUsb = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Camera")
            resetKey: "toastOnCamera"
            description: I18n.tr("Camera on, with the app using it, and camera off again once it lets go.")

            M3Switch {
                checked: Prefs.toastOnCamera
                onToggled: (v) => {
                    return Prefs.toastOnCamera = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Wi-Fi")
            resetKey: "toastOnWifi"
            description: I18n.tr("Joining or losing a network. A quick drop and rejoin, like waking from sleep, stays quiet.")

            M3Switch {
                checked: Prefs.toastOnWifi
                onToggled: (v) => {
                    return Prefs.toastOnWifi = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Sound output")
            resetKey: "toastOnAudio"
            description: I18n.tr("The default output changing - speakers to headphones and back.")

            M3Switch {
                checked: Prefs.toastOnAudio
                onToggled: (v) => {
                    return Prefs.toastOnAudio = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Displays")
            resetKey: "toastOnDisplays"
            description: I18n.tr("A monitor being plugged in or unplugged.")

            M3Switch {
                checked: Prefs.toastOnDisplays
                onToggled: (v) => {
                    return Prefs.toastOnDisplays = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Power profile")
            resetKey: "toastOnPower"
            description: I18n.tr("Balanced, performance or power saver. A switch made by game mode is left to its own toast.")

            M3Switch {
                checked: Prefs.toastOnPower
                onToggled: (v) => {
                    return Prefs.toastOnPower = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Preview")
            description: I18n.tr("Plays one of each, one after another, with made-up details.")
            showDivider: false

            M3Button {
                text: I18n.tr("Preview")
                variant: "text"
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "toastevents", "preview"])
            }

        }

    }

}
