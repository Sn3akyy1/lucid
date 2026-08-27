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
        { "key": "showNotifications", "name": "Notifications", "desc": "Toasts and the notification list" },
        { "key": "showSystem", "name": "System", "desc": "Battery, volume, brightness and quick settings" }
    ]

    spacing: 26

    BarPreview {
        width: parent.width
    }

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
            title: "Edge blend"
            resetKey: "barNotchFlare"
            description: "How far a notched module's upper corners sweep out into the top of the screen. Only drawn where there is room for it - modules packed close together keep their square corners rather than leaving a spike of wallpaper between them."
            enabled: Prefs.barNotch
            disabledReason: "Islands float clear of the screen edge, so there is nothing to blend into - switch the bar to Notches on the General page."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.barNotch
                from: 0
                to: 32
                stepSize: 1
                suffix: " px"
                value: Prefs.barNotchFlare
                onMoved: (v) => {
                    return Prefs.barNotchFlare = v;
                }
            }

        }

        SettingRow {
            title: "Animation speed"
            resetKey: "barMotionScale"
            description: "Scales every transition in the bar - hovers, pills growing and shrinking, modules appearing and leaving - on top of the shell-wide Animation speed on the General page. Above 1.00x the bar moves more slowly than the rest of the shell."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 2.5
                stepSize: 0.05
                decimals: 2
                suffix: "x"
                value: Prefs.barMotionScale
                onMoved: (v) => {
                    return Prefs.barMotionScale = v;
                }
            }

        }

        SettingRow {
            title: "Module spacing"
            resetKey: "barSpacing"
            description: "The gap between neighbouring pills."
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

        SettingRow {
            title: "Hover growth"
            resetKey: "barHoverGrow"
            description: "How far a pill swells under the pointer to show it opens. Capped at half the module spacing."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 6
                stepSize: 1
                suffix: " px"
                value: Prefs.barHoverGrow
                onMoved: (v) => {
                    return Prefs.barHoverGrow = v;
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
                // nothing here can show while the bar itself is off
                enabled: Prefs.barEnabled
                disabledReason: "The bar is switched off, so this module has nothing to appear in."
                showDivider: modRow.index < page.moduleList.length - 1

                M3Switch {
                    checked: Prefs[modRow.modelData.key]
                    enabled: Prefs.barEnabled
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
