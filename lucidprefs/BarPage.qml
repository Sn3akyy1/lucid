import QtQuick
import qs

// Bar settings. The two that matter most - pop-up mode and the inline mode it
// unlocks - are also the two hardest to picture, so they sit directly under a
// live miniature of the result.
Column {
    id: page

    readonly property var moduleList: [
        { "key": "showWorkspaces", "name": "Workspaces", "desc": "Workspace pills and the expanded overview" },
        { "key": "showMedia", "name": "Media", "desc": "Now-playing pill and player controls" },
        { "key": "showTray", "name": "System tray", "desc": "Status icons from running applications" },
        { "key": "showClock", "name": "Clock", "desc": "Time, date and the calendar panel" },
        { "key": "showBluetooth", "name": "Bluetooth", "desc": "Adapter state and paired devices" },
        { "key": "showNetwork", "name": "Network", "desc": "Wi-Fi, ethernet and throughput" },
        { "key": "showNotifications", "name": "Notifications", "desc": "Toasts and the notification list" },
        { "key": "showSystem", "name": "System", "desc": "Battery, volume, brightness and quick settings" }
    ]

    spacing: 26

    BarPreview {
        width: parent.width
    }

    // ---------------- how modules open ----------------
    SettingCard {
        title: "OPENING BEHAVIOUR"

        SettingRow {
            title: "Pop-up mode"
            description: "Modules stop morphing their own pill into a panel. The pill stays put in the bar and the panel appears below it as a detached pop-up."

            M3Switch {
                checked: Prefs.barPopupMode
                onToggled: (v) => {
                    return Prefs.barPopupMode = v;
                }
            }

        }

        SettingRow {
            title: "Pop-up distance"
            resetKey: "barPopupGap"
            description: "The gap between a module's pill and the panel it opens."
            enabled: Prefs.barPopupMode
            disabledReason: "Only applies in pop-up mode."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.barPopupMode
                from: 0
                to: 24
                stepSize: 1
                suffix: " px"
                value: Prefs.barPopupGap
                onMoved: (v) => {
                    return Prefs.barPopupGap = v;
                }
            }

        }

    }

    // ---------------- layout ----------------
    SettingCard {
        title: "LAYOUT"

        SettingRow {
            title: "Bar height"
            resetKey: "barHeight"
            description: "How tall each module's resting pill is."
            stacked: true

            M3Slider {
                width: parent.width
                from: 26
                to: 52
                stepSize: 1
                suffix: " px"
                value: Prefs.barHeight
                onMoved: (v) => {
                    return Prefs.barHeight = v;
                }
            }

        }

        SettingRow {
            title: "Distance from top"
            resetKey: "barTopMargin"
            description: "How far the bar floats below the top edge of the screen."
            enabled: !Prefs.barNotch
            disabledReason: "Notches sit flush against the screen edge by definition - switch back to islands on the General page to float the bar."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: !Prefs.barNotch
                from: 0
                to: 48
                stepSize: 1
                suffix: " px"
                value: Prefs.barTopMargin
                onMoved: (v) => {
                    return Prefs.barTopMargin = v;
                }
            }

        }

        SettingRow {
            title: "Side margin"
            resetKey: "barSideMargin"
            description: "Inset from the left and right screen edges."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 60
                stepSize: 1
                suffix: " px"
                value: Prefs.barSideMargin
                onMoved: (v) => {
                    return Prefs.barSideMargin = v;
                }
            }

        }

        SettingRow {
            title: "Module spacing"
            resetKey: "barSpacing"
            description: "The gap between neighbouring pills."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 24
                stepSize: 1
                suffix: " px"
                value: Prefs.barSpacing
                onMoved: (v) => {
                    return Prefs.barSpacing = v;
                }
            }

        }

    }

    // ---------------- modules ----------------
    SettingCard {
        title: "MODULES"

        Repeater {
            model: page.moduleList

            SettingRow {
                id: modRow

                required property var modelData
                required property int index

                title: modRow.modelData.name
                description: modRow.modelData.desc
                showDivider: modRow.index < page.moduleList.length - 1

                M3Switch {
                    checked: Prefs[modRow.modelData.key]
                    onToggled: (v) => {
                        return Prefs[modRow.modelData.key] = v;
                    }
                }

            }

        }

    }

    // ---------------- per-module options ----------------
    SettingCard {
        title: "CLOCK"

        SettingRow {
            title: "24-hour time"
            description: "Show 14:30 instead of 02:30 PM."

            M3Switch {
                checked: Prefs.clock24h
                onToggled: (v) => {
                    return Prefs.clock24h = v;
                }
            }

        }

        SettingRow {
            title: "Show date"
            description: "Keep the weekday and day-of-month beside the time."
            showDivider: false

            M3Switch {
                checked: Prefs.clockShowDate
                onToggled: (v) => {
                    return Prefs.clockShowDate = v;
                }
            }

        }

    }

    SettingCard {
        title: "NOTIFICATIONS"

        SettingRow {
            title: "Do not disturb"
            description: "Notifications are still collected in the list, but no toast is shown."

            M3Switch {
                checked: Prefs.doNotDisturb
                onToggled: (v) => {
                    return Prefs.doNotDisturb = v;
                }
            }

        }

        SettingRow {
            title: "Toast duration"
            resetKey: "toastTimeout"
            description: "How long a toast stays on screen when the notification does not ask for something else."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 15
                stepSize: 1
                suffix: " s"
                value: Prefs.toastTimeout
                onMoved: (v) => {
                    return Prefs.toastTimeout = v;
                }
            }

        }

    }

}
