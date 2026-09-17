import QtQuick
import Quickshell.Io
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
            return "Hold popups back between two times every day. They still collect in the list.";

        var span = Prefs.minutesText(Prefs.quietFrom) + " to " + Prefs.minutesText(Prefs.quietTo);
        return page.quietNow ? "Quiet now — " + span + " every day." : "Quiet from " + span + " every day.";
    }
    readonly property string clearLabel: Prefs.liveNotifCount === 0 ? "Nothing to clear" : (Prefs.liveNotifCount === 1 ? "Clear 1 notification" : "Clear " + Prefs.liveNotifCount + " notifications")
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

    spacing: 26

    // only for the quiet-hours readout, so it can idle when there is none
    Timer {
        interval: 20000
        repeat: true
        running: Prefs.quietHours
        triggeredOnStart: true
        onTriggered: page.tick++
    }

    Process {
        id: soundTest

        command: ["paplay", "--volume=" + Prefs.notifSoundPaVolume, Prefs.notifSoundPath]
    }

    SettingCard {
        title: "POPUPS"

        SettingRow {
            title: "Show popups"
            resetKey: "toastEnabled"
            enabled: Prefs.showNotifications
            disabledReason: "Notifications are switched off, so nothing is shown or collected."
            description: "Slide a notification out of the bar as it arrives. With this off they go straight to the list."

            M3Switch {
                checked: Prefs.toastEnabled
                enabled: Prefs.showNotifications
                onToggled: (v) => {
                    return Prefs.toastEnabled = v;
                }
            }

        }

        SettingRow {
            title: "How many at once"
            resetKey: "toastMaxVisible"
            enabled: Prefs.showNotifications && Prefs.toastEnabled
            disabledReason: "Popups are switched off."
            description: "A burst of notifications stacks under the bar. Anything past this waits in the list instead."
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 6
                stepSize: 1
                enabled: Prefs.showNotifications && Prefs.toastEnabled
                value: Prefs.toastMaxVisible
                onMoved: (v) => {
                    return Prefs.toastMaxVisible = v;
                }
            }

        }

        SettingRow {
            title: "How long one stays"
            resetKey: "toastTimeout"
            enabled: Prefs.showNotifications && Prefs.toastEnabled
            disabledReason: "Popups are switched off."
            description: "The time a popup is left on screen when the application does not ask for something else."
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 30
                stepSize: 1
                suffix: " s"
                enabled: Prefs.showNotifications && Prefs.toastEnabled
                value: Prefs.toastTimeout
                onMoved: (v) => {
                    return Prefs.toastTimeout = v;
                }
            }

        }

        SettingRow {
            title: "Let applications set their own"
            resetKey: "toastUseAppTimeout"
            enabled: Prefs.showNotifications && Prefs.toastEnabled
            disabledReason: "Popups are switched off."
            description: "Most applications name a duration when they send a notification. Turn this off to give every popup the same time above."

            M3Switch {
                checked: Prefs.toastUseAppTimeout
                enabled: Prefs.showNotifications && Prefs.toastEnabled
                onToggled: (v) => {
                    return Prefs.toastUseAppTimeout = v;
                }
            }

        }

        SettingRow {
            title: "Keep urgent ones up"
            resetKey: "toastCriticalSticky"
            enabled: Prefs.showNotifications && Prefs.toastEnabled
            disabledReason: "Popups are switched off."
            description: "A notification marked urgent — a low battery, a failed backup — waits for you instead of timing out."

            M3Switch {
                checked: Prefs.toastCriticalSticky
                enabled: Prefs.showNotifications && Prefs.toastEnabled
                onToggled: (v) => {
                    return Prefs.toastCriticalSticky = v;
                }
            }

        }

        SettingRow {
            title: "Show the message"
            resetKey: "toastShowBody"
            enabled: Prefs.showNotifications && Prefs.toastEnabled
            disabledReason: "Popups are switched off."
            description: "With this off a popup carries the title alone, and the body waits in the list."

            M3Switch {
                checked: Prefs.toastShowBody
                enabled: Prefs.showNotifications && Prefs.toastEnabled
                onToggled: (v) => {
                    return Prefs.toastShowBody = v;
                }
            }

        }

        SettingRow {
            title: "Lines of message"
            resetKey: "toastBodyLines"
            enabled: Prefs.showNotifications && Prefs.toastEnabled && Prefs.toastShowBody
            disabledReason: "The message body is hidden."
            description: "How far a long message is allowed to run before it is cut short."
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 10
                stepSize: 1
                enabled: Prefs.showNotifications && Prefs.toastEnabled && Prefs.toastShowBody
                value: Prefs.toastBodyLines
                onMoved: (v) => {
                    return Prefs.toastBodyLines = v;
                }
            }

        }

        SettingRow {
            title: "Show buttons"
            resetKey: "toastShowActions"
            enabled: Prefs.showNotifications && Prefs.toastEnabled
            disabledReason: "Popups are switched off."
            description: "Reply, Open, Snooze — whatever the application offers, on the popup itself. They are always in the list."

            M3Switch {
                checked: Prefs.toastShowActions
                enabled: Prefs.showNotifications && Prefs.toastEnabled
                onToggled: (v) => {
                    return Prefs.toastShowActions = v;
                }
            }

        }

        SettingRow {
            title: "Reply without switching"
            resetKey: "notifInlineReply"
            enabled: Prefs.showNotifications
            disabledReason: "Notifications are switched off, so nothing is shown or collected."
            description: "Chat applications that support it get a message box on the notification itself, so you can answer without leaving what you are doing."
            showDivider: false

            M3Switch {
                checked: Prefs.notifInlineReply
                enabled: Prefs.showNotifications
                onToggled: (v) => {
                    return Prefs.notifInlineReply = v;
                }
            }

        }

    }

    SettingCard {
        title: "DO NOT DISTURB"

        SettingRow {
            title: "Do not disturb"
            resetKey: "doNotDisturb"
            description: "No popups and no sound. Everything is still collected in the list, and the bell in the bar turns to a moon."

            M3Switch {
                checked: Prefs.doNotDisturb
                onToggled: (v) => {
                    return Prefs.doNotDisturb = v;
                }
            }

        }

        SettingRow {
            title: "Let urgent ones through"
            resetKey: "dndAllowCritical"
            description: "Notifications marked urgent still appear while you are silenced, however you were silenced."

            M3Switch {
                checked: Prefs.dndAllowCritical
                onToggled: (v) => {
                    return Prefs.dndAllowCritical = v;
                }
            }

        }

        SettingRow {
            title: "Silence over a fullscreen window"
            resetKey: "dndFullscreen"
            description: "Films and games are left alone. The notifications wait in the list for you."

            M3Switch {
                checked: Prefs.dndFullscreen
                onToggled: (v) => {
                    return Prefs.dndFullscreen = v;
                }
            }

        }

        SettingRow {
            title: "Quiet hours"
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
            title: "Between"
            enabled: Prefs.quietHours
            disabledReason: "Quiet hours are switched off."
            description: "Written as 22:00. An end earlier than the start runs through midnight."
            showDivider: false

            Row {
                spacing: 10

                M3TextField {
                    id: fromField

                    width: 96
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
                    text: "to"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    opacity: Prefs.quietHours ? 1 : 0.38
                }

                M3TextField {
                    id: toField

                    width: 96
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
        title: "SOUND"

        SettingRow {
            title: "Play a sound"
            resetKey: "notifSound"
            description: "A short chime as a notification arrives. Nothing plays while you are silenced."

            M3Switch {
                checked: Prefs.notifSound
                onToggled: (v) => {
                    return Prefs.notifSound = v;
                }
            }

        }

        SettingRow {
            title: "Which sound"
            resetKey: "notifSoundName"
            enabled: Prefs.notifSound
            disabledReason: "Sound is switched off."
            description: "From the sounds your desktop theme ships."
            stacked: true

            Row {
                spacing: 12

                M3Segmented {
                    width: 360
                    enabled: Prefs.notifSound
                    current: Prefs.notifSoundEntry(Prefs.notifSoundName).key
                    options: Prefs.notifSounds
                    onChosen: (key) => {
                        Prefs.notifSoundName = key;
                        soundTest.running = true;
                    }
                }

                M3Button {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Play"
                    variant: "tonal"
                    enabled: Prefs.notifSound
                    onClicked: soundTest.running = true
                }

            }

        }

        SettingRow {
            title: "Volume"
            resetKey: "notifSoundVolume"
            enabled: Prefs.notifSound
            disabledReason: "Sound is switched off."
            description: "Relative to whatever the notification sink is set to."
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
            title: "Only for urgent ones"
            resetKey: "notifSoundUrgentOnly"
            enabled: Prefs.notifSound
            disabledReason: "Sound is switched off."
            description: "Stay quiet for the ordinary traffic and speak up only for what is marked urgent."
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
        title: "THE LIST"

        SettingRow {
            title: "Show application icons"
            resetKey: "notifShowIcons"
            description: "The sending application's icon beside each notification, in the list and on the popup."

            M3Switch {
                checked: Prefs.notifShowIcons
                onToggled: (v) => {
                    return Prefs.notifShowIcons = v;
                }
            }

        }

        SettingRow {
            title: "Group by application"
            resetKey: "notifGrouping"
            description: "One application's notifications collapse into a single stack you can open, instead of filling the list one by one."

            M3Switch {
                checked: Prefs.notifGrouping
                onToggled: (v) => {
                    return Prefs.notifGrouping = v;
                }
            }

        }

        SettingRow {
            title: "Show times"
            resetKey: "notifTimestamps"
            description: "How long ago each one arrived, beside the application's name, and a heading splitting new ones from the rest."

            M3Switch {
                checked: Prefs.notifTimestamps
                onToggled: (v) => {
                    return Prefs.notifTimestamps = v;
                }
            }

        }

        SettingRow {
            title: "Show progress"
            resetKey: "notifProgress"
            description: "File copies, downloads and transfers report how far along they are. This draws it as a bar that fills in place."

            M3Switch {
                checked: Prefs.notifProgress
                onToggled: (v) => {
                    return Prefs.notifProgress = v;
                }
            }

        }

        SettingRow {
            title: "Keep at most"
            resetKey: "notifMaxHistory"
            description: "Once the list is this long the oldest notification drops off the end as a new one arrives."
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
            title: "Clear the list"
            description: "Dismisses everything the shell is holding right now. The applications are not told anything else."
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
        title: "APPLICATIONS"

        SettingRow {
            title: "Muted applications"
            description: page.appList.length === 0 ? "Nothing has sent a notification yet. Once something does it is listed here to mute." : "A muted application's notifications are turned away as they arrive — no popup, no sound, nothing in the list."
            stacked: true
            showDivider: page.appList.length > 0

            Column {
                width: parent.width
                spacing: 14
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
            title: "Mute one by name"
            description: "Use the name the application gives itself, spelled the same way. Press Enter to add it."
            showDivider: Prefs.notifSeenApps !== ""

            M3TextField {
                id: muteField

                width: 260
                placeholder: "Spotify"
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
            title: "Forget the list"
            visible: Prefs.notifSeenApps !== ""
            description: "Empties the roll of applications seen above. Whatever you muted stays muted, and anything that sends a notification is listed again."
            showDivider: false

            M3Button {
                text: "Forget"
                variant: "text"
                onClicked: Prefs.notifSeenApps = ""
            }

        }

    }

    SettingCard {
        title: "SYSTEM EVENTS"

        SettingRow {
            title: "Keyboard layout"
            resetKey: "toastOnLayout"
            description: "A small toast at the top of the screen with the layout you switched to."

            M3Switch {
                checked: Prefs.toastOnLayout
                onToggled: (v) => {
                    return Prefs.toastOnLayout = v;
                }
            }

        }

        SettingRow {
            title: "Lock keys and microphone"
            resetKey: "osdToggles"
            description: "Where Caps Lock, Num Lock and muting the microphone show up: on the OSD at the bottom, with volume and brightness, or as a toast at the top like the rest of these events."

            M3Segmented {
                width: 220
                current: Prefs.osdToggles
                options: [{
                    "key": "osd",
                    "label": "OSD"
                }, {
                    "key": "toast",
                    "label": "Toast"
                }]
                onChosen: (key) => {
                    return Prefs.osdToggles = key;
                }
            }

        }

        SettingRow {
            title: "Game mode"
            resetKey: "toastOnGameMode"
            enabled: Prefs.gameModeStateFile !== ""
            disabledReason: "Game mode is noticed by watching the file its status command checks. Set the status command under Bar → System module to something like test -f /run/gamemode.state."
            description: "When game mode turns on or off - from the tile, a keybind or anywhere else."

            M3Switch {
                checked: Prefs.toastOnGameMode
                enabled: Prefs.gameModeStateFile !== ""
                onToggled: (v) => {
                    return Prefs.toastOnGameMode = v;
                }
            }

        }

        SettingRow {
            title: "Battery and charger"
            resetKey: "toastOnBattery"
            description: "Plugging in or out, a full charge, and warnings at 20, 10 and 5 %."

            M3Switch {
                checked: Prefs.toastOnBattery
                onToggled: (v) => {
                    return Prefs.toastOnBattery = v;
                }
            }

        }

        SettingRow {
            title: "Bluetooth devices"
            resetKey: "toastOnBluetooth"
            description: "A device connecting, with its battery when it reports one, or disconnecting. Switching Bluetooth off stays quiet."

            M3Switch {
                checked: Prefs.toastOnBluetooth
                onToggled: (v) => {
                    return Prefs.toastOnBluetooth = v;
                }
            }

        }

        SettingRow {
            title: "Wi-Fi"
            resetKey: "toastOnWifi"
            description: "Joining or losing a network. A quick drop and rejoin, like waking from sleep, stays quiet."

            M3Switch {
                checked: Prefs.toastOnWifi
                onToggled: (v) => {
                    return Prefs.toastOnWifi = v;
                }
            }

        }

        SettingRow {
            title: "Sound output"
            resetKey: "toastOnAudio"
            description: "The default output changing - speakers to headphones and back."

            M3Switch {
                checked: Prefs.toastOnAudio
                onToggled: (v) => {
                    return Prefs.toastOnAudio = v;
                }
            }

        }

        SettingRow {
            title: "Displays"
            resetKey: "toastOnDisplays"
            description: "A monitor being plugged in or unplugged."

            M3Switch {
                checked: Prefs.toastOnDisplays
                onToggled: (v) => {
                    return Prefs.toastOnDisplays = v;
                }
            }

        }

        SettingRow {
            title: "Power profile"
            resetKey: "toastOnPower"
            description: "Balanced, performance or power saver. A switch made by game mode is left to its own toast."

            M3Switch {
                checked: Prefs.toastOnPower
                onToggled: (v) => {
                    return Prefs.toastOnPower = v;
                }
            }

        }

        SettingRow {
            title: "Preview"
            description: "Plays one of each, one after another, with made-up details."
            showDivider: false

            M3Button {
                text: "Preview"
                variant: "text"
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "toastevents", "preview"])
            }

        }

    }

}
