import QtQuick
import Quickshell
import qs
import qs.lucidui

Column {
    id: page

    property int tick: 0

    readonly property string positionText: {
        page.tick;
        var bits = [];
        if (Loc.place !== "")
            bits.push(Loc.place);

        bits.push(Loc.coordText);
        if (Loc.fixedAt > 0)
            bits.push(I18n.tr("found %1", page.agoText(Date.now() - Loc.fixedAt)));

        return bits.join("  ·  ");
    }

    readonly property var goalLabels: {
        var out = [I18n.tr("Off")];
        for (var i = 1; i <= 16; i++) out.push(i + (i === 1 ? I18n.tr(" session") : I18n.tr(" sessions")))
        return out;
    }

    function agoText(ms) {
        var mins = Math.floor(ms / 60000);
        if (mins < 1)
            return I18n.tr("just now");

        if (mins < 60)
            return mins + (mins === 1 ? I18n.tr(" minute ago") : I18n.tr(" minutes ago"));

        var hrs = Math.round(mins / 60);
        if (hrs < 24)
            return hrs + (hrs === 1 ? I18n.tr(" hour ago") : I18n.tr(" hours ago"));

        var days = Math.round(hrs / 24);
        return days + (days === 1 ? I18n.tr(" day ago") : I18n.tr(" days ago"));
    }

    spacing: Theme.dp(26)

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: page.tick++
    }

    SettingCard {
        title: I18n.tr("LOCATION")

        SettingRow {
            title: I18n.tr("Auto-detect location")
            resetKey: "gpsEnabled"
            description: I18n.tr("Works out roughly where you are from your network connection, and keeps checking every few hours. This is the same switch as the GPS tile in the bar's system panel.")
            warning: Prefs.gpsEnabled ? I18n.tr("Your address is sent to ipapi.co to be turned into a position.") : ""

            M3Switch {
                checked: Prefs.gpsEnabled
                onToggled: (v) => {
                    return Prefs.gpsEnabled = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Place")
            enabled: !Prefs.gpsEnabled
            disabledReason: I18n.tr("Auto-detect is choosing the place for you. Turn it off to name one yourself.")
            description: I18n.tr("A town or city to sit the shell in. Press Enter to look it up.")

            M3TextField {
                width: Theme.dp(260)
                enabled: !Prefs.gpsEnabled
                placeholder: I18n.tr("Poznań")
                text: Prefs.locationName
                onAccepted: (v) => {
                    Prefs.locationName = v;
                    Loc.lookup(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Position")
            description: page.positionText
            warning: Loc.lastError
            showDivider: false

            M3Button {
                text: Loc.busy ? I18n.tr("Looking…") : (Prefs.gpsEnabled ? I18n.tr("Detect now") : I18n.tr("Look up"))
                variant: "tonal"
                enabled: !Loc.busy
                onClicked: Loc.refresh()
            }

        }

    }

    SettingCard {
        title: I18n.tr("TIME ZONE")

        SettingRow {
            title: I18n.tr("Time zone")
            description: I18n.tr("The machine's own zone, shared with every application on it. Changing it here is the same as running timedatectl, so it asks for your password.")
            warning: Loc.zoneError !== "" ? I18n.tr("Unchanged — %1", Loc.zoneError) : ""

            Row {
                spacing: Theme.dp(14)

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(2)

                    Text {
                        text: Loc.zone !== "" ? Loc.zone.replace(/_/g, " ") : I18n.tr("Reading…")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle
                        font.variableAxes: Theme.axes(Theme.fontTitle, 640, 0)
                        font.bold: true
                    }

                    Text {
                        text: Loc.offsetText
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                    }

                }

                M3Button {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Loc.zoneBusy ? I18n.tr("Setting…") : I18n.tr("Change…")
                    variant: "tonal"
                    enabled: !Loc.zoneBusy
                    onClicked: Prefs.timeZonePickerRequested()
                }

            }

        }

        SettingRow {
            title: I18n.tr("Set it from my location")
            resetKey: "timeZoneAuto"
            description: {
                if (Loc.zoneFromLocation === "")
                    return I18n.tr("Your location has not named a zone yet. Find a place above and the machine can follow it.");

                if (Loc.locationAgrees)
                    return I18n.tr("The machine already keeps the time of %1.", Loc.zoneFromLocation.replace(/_/g, " "));

                return I18n.tr("Your location sits in %1, which the machine is not on.", Loc.zoneFromLocation.replace(/_/g, " "));
            }
            showDivider: Loc.stale

            M3Switch {
                checked: Prefs.timeZoneAuto
                onToggled: (v) => {
                    return Prefs.timeZoneAuto = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Applications opened before the change")
            visible: Loc.stale
            description: {
                page.tick;
                return "A program reads the time zone once, when it starts, so anything already running is still on the old one. Lucid corrects for that itself and shows " + Loc.now().toLocaleTimeString(I18n.locale, "HH:mm") + " either way — restart the others, or log out, to bring them across.";
            }
            showDivider: false
        }

    }

    SettingCard {
        title: I18n.tr("CLOCK")

        SettingRow {
            title: I18n.tr("24-hour time")
            resetKey: "clock24h"
            description: I18n.tr("Show 14:30 instead of 02:30 PM.")

            M3Switch {
                checked: Prefs.clock24h
                onToggled: (v) => {
                    return Prefs.clock24h = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Show date")
            resetKey: "clockShowDate"
            description: I18n.tr("Keep the weekday and day-of-month beside the time in the bar.")

            M3Switch {
                checked: Prefs.clockShowDate
                onToggled: (v) => {
                    return Prefs.clockShowDate = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Show seconds")
            resetKey: "clockShowSeconds"
            description: I18n.tr("Tick the seconds in the bar. Off, the colon blinks instead.")

            M3Switch {
                checked: Prefs.clockShowSeconds
                onToggled: (v) => {
                    return Prefs.clockShowSeconds = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Weather beside the time")
            resetKey: "clockShowWeather"
            description: I18n.tr("A small icon and the temperature, taken from the Weather service.")

            M3Switch {
                checked: Prefs.clockShowWeather
                onToggled: (v) => {
                    return Prefs.clockShowWeather = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Running timer in the bar")
            resetKey: "clockShowTimer"
            description: I18n.tr("While a timer, pomodoro or stopwatch is counting, show it as a chip with a ring.")

            M3Switch {
                checked: Prefs.clockShowTimer
                onToggled: (v) => {
                    return Prefs.clockShowTimer = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Week starts on")
            resetKey: "weekStartMonday"
            description: I18n.tr("For the clock's calendar and the calendar widgets.")

            M3Segmented {
                width: Theme.dp(200)
                options: [{
                    "key": "mon",
                    "label": I18n.tr("Monday")
                }, {
                    "key": "sun",
                    "label": I18n.tr("Sunday")
                }]
                current: Prefs.weekStartMonday ? "mon" : "sun"
                onChosen: (k) => {
                    return Prefs.weekStartMonday = k === "mon";
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("UNITS")

        SettingRow {
            title: I18n.tr("Measurement system")
            resetKey: "units"
            description: I18n.tr("°C and km/h, or °F and mph. For the weather in the bar, on the lock screen and in the widgets, and for the heat of the processor, graphics card and drives.")

            M3Segmented {
                width: Theme.dp(200)
                options: [{
                    "key": "metric",
                    "label": I18n.tr("Metric")
                }, {
                    "key": "imperial",
                    "label": I18n.tr("Imperial")
                }]
                current: Prefs.units
                onChosen: (k) => {
                    return Prefs.units = k;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("POMODORO")

        SettingRow {
            title: I18n.tr("Preset")
            description: I18n.tr("Sets the focus, break and long break lengths and the rounds together.")
            stacked: true

            M3Chips {
                width: parent.width
                current: Chrono.pomoPreset
                options: Chrono.pomoPresets.map((p) => {
                    return {
                        "key": p.key,
                        "label": p.name + " · " + p.label
                    };
                })
                onChosen: (k) => {
                    return Chrono.pomoUsePreset(k);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Focus length")
            resetKey: "pomodoroFocus"
            description: I18n.tr("One pomodoro focus session.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 5
                to: 90
                stepSize: 5
                suffix: I18n.tr(" min")
                value: Prefs.pomodoroFocus
                onMoved: (v) => {
                    return Prefs.pomodoroFocus = Math.round(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Short break")
            resetKey: "pomodoroShort"
            description: I18n.tr("The break after each focus session.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 30
                stepSize: 1
                suffix: I18n.tr(" min")
                value: Prefs.pomodoroShort
                onMoved: (v) => {
                    return Prefs.pomodoroShort = Math.round(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Long break")
            resetKey: "pomodoroLong"
            description: I18n.tr("The break after a full set of rounds.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 5
                to: 60
                stepSize: 5
                suffix: I18n.tr(" min")
                value: Prefs.pomodoroLong
                onMoved: (v) => {
                    return Prefs.pomodoroLong = Math.round(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Rounds before a long break")
            resetKey: "pomodoroRounds"
            description: I18n.tr("How many focus sessions make a set.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 2
                to: 8
                stepSize: 1
                suffix: ""
                value: Prefs.pomodoroRounds
                onMoved: (v) => {
                    return Prefs.pomodoroRounds = Math.round(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Start breaks on their own")
            resetKey: "pomodoroAutoStart"
            description: I18n.tr("Off, the break waits for you when a focus session ends.")

            M3Switch {
                checked: Prefs.pomodoroAutoStart
                onToggled: (v) => {
                    return Prefs.pomodoroAutoStart = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Start focus on its own")
            resetKey: "pomodoroAutoFocus"
            description: I18n.tr("Off, the next focus session waits for you when a break ends.")

            M3Switch {
                checked: Prefs.pomodoroAutoFocus
                onToggled: (v) => {
                    return Prefs.pomodoroAutoFocus = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Repeat sets")
            resetKey: "pomodoroRepeat"
            description: I18n.tr("Off, the pomodoro stops after the long break instead of starting over.")

            M3Switch {
                checked: Prefs.pomodoroRepeat
                onToggled: (v) => {
                    return Prefs.pomodoroRepeat = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Do not disturb while focusing")
            resetKey: "pomodoroSilence"
            description: I18n.tr("Holds notifications back during a focus session and lets them through again for the break.")

            M3Switch {
                checked: Prefs.pomodoroSilence
                onToggled: (v) => {
                    return Prefs.pomodoroSilence = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Daily goal")
            resetKey: "pomodoroGoal"
            description: I18n.tr("Focus sessions to aim for each day. The clock counts them and tells you when you get there.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 16
                stepSize: 1
                stepLabels: page.goalLabels
                value: Prefs.pomodoroGoal
                onMoved: (v) => {
                    return Prefs.pomodoroGoal = Math.round(v);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("TIMERS")

        SettingRow {
            title: I18n.tr("Sound when time is up")
            resetKey: "timerSound"
            description: I18n.tr("Plays Lucid's alarm alongside the notification, whatever the system sound settings say.")

            Row {
                spacing: Theme.dp(4)

                M3IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconPath: "play_arrow"
                    onClicked: Sounds.play("alarm", 1)
                }

                M3Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Prefs.timerSound
                    onToggled: (v) => {
                        return Prefs.timerSound = v;
                    }
                }

            }

        }

        SettingRow {
            title: I18n.tr("Sound for reminders")
            resetKey: "reminderSound"
            description: I18n.tr("A chime as a reminder comes due, and again when a snoozed one comes back. Like the alarm, it plays even while you are silenced.")

            Row {
                spacing: Theme.dp(4)

                M3IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconPath: "play_arrow"
                    onClicked: Sounds.play("reminder", 1)
                }

                M3Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Prefs.reminderSound
                    onToggled: (v) => {
                        return Prefs.reminderSound = v;
                    }
                }

            }

        }

        SettingRow {
            title: I18n.tr("World clocks")
            description: I18n.tr("Add and remove cities from the World tab of the clock, opened from the time in the bar.")

            Button {
                variant: "tonal"
                size: "xs"
                icon: "public"
                text: I18n.tr("Open")
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "--", "clock", "open", "world"])
            }

        }

    }

}
