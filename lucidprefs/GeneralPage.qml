import QtQuick
import Quickshell
import qs

Column {
    id: page

    readonly property string home: Quickshell.env("HOME")
    spacing: 26

    SettingCard {
        title: "SHAPE"

        SettingRow {
            title: "Bar style"
            description: "Islands float free of the screen edge. Notches sit flush against it, squaring off the corners that meet it."

            M3Segmented {
                width: 260
                current: Prefs.barStyle
                options: [{
                    "key": "island",
                    "label": "Islands"
                }, {
                    "key": "notch",
                    "label": "Notches"
                }]
                onChosen: (key) => {
                    return Prefs.barStyle = key;
                }
            }

        }

        SettingRow {
            title: "Dock style"
            description: "The same choice for the dock, against the bottom edge."
            showDivider: false

            M3Segmented {
                width: 260
                current: Prefs.dockStyle
                options: [{
                    "key": "island",
                    "label": "Islands"
                }, {
                    "key": "notch",
                    "label": "Notches"
                }]
                onChosen: (key) => {
                    return Prefs.dockStyle = key;
                }
            }

        }

    }

    SettingCard {
        title: "SURFACES"

        SettingRow {
            title: "Glass"
            description: "How far the desktop shows through the shell, the terminal and your windows now has a page of its own."

            M3Button {
                text: "Glass…"
                variant: "tonal"
                onClicked: Prefs.settingsRequested("glass")
            }

        }

        SettingRow {
            title: "Accent intensity"
            resetKey: "accentPunch"
            description: "Lifts the accent colour away from the wallpaper-derived original. 1.0 uses it exactly as generated."
            stacked: true

            M3Slider {
                width: parent.width
                from: 1
                to: 2
                stepSize: 0.05
                decimals: 2
                value: Prefs.accentPunch
                onMoved: (v) => {
                    return Prefs.accentPunch = v;
                }
            }

        }

        SettingRow {
            title: "Corner rounding"
            resetKey: "radiusScale"
            description: "Scales every rounded corner in the shell at once — pills, panels, the dock, cards and buttons. 100% is the shipped shape; 0% squares everything off. Pill-shaped controls stay pill-shaped until you reach 0."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 150
                stepSize: 5
                decimals: 0
                suffix: " %"
                value: Math.round(Prefs.radiusScale * 100)
                onMoved: (v) => {
                    return Prefs.radiusScale = v / 100;
                }
            }

        }

        SettingRow {
            title: "Surface darkness"
            resetKey: "surfaceDarkness"
            description: "How far every panel is darkened beneath the theme's own surface colour. Auto follows the theme."
            stacked: true

            Row {
                spacing: 16
                width: parent.width

                M3Slider {
                    width: parent.width - resetDark.width - 16
                    enabled: Prefs.surfaceDarkness >= 0
                    from: 0
                    to: 0.8
                    stepSize: 0.05
                    decimals: 2
                    value: Prefs.surfaceDarkness >= 0 ? Prefs.surfaceDarkness : 0.45
                    onMoved: (v) => {
                        return Prefs.surfaceDarkness = v;
                    }
                }

                M3Button {
                    id: resetDark

                    anchors.verticalCenter: parent.verticalCenter
                    text: Prefs.surfaceDarkness >= 0 ? "Auto" : "Manual"
                    variant: Prefs.surfaceDarkness >= 0 ? "tonal" : "filled"
                    onClicked: Prefs.surfaceDarkness = Prefs.surfaceDarkness >= 0 ? -1 : 0.45
                }

            }

        }

        SettingRow {
            title: "Accent tint"
            resetKey: "surfaceTint"
            description: "How much of the accent colour is mixed into every panel. A light palette comes out of the generator almost white, so Auto tints it and leaves dark panels flat."
            showDivider: false
            stacked: true

            Row {
                spacing: 16
                width: parent.width

                M3Slider {
                    width: parent.width - resetTint.width - 16
                    enabled: Prefs.surfaceTint >= 0
                    from: 0
                    to: 1
                    stepSize: 0.05
                    decimals: 2
                    value: Prefs.surfaceTint >= 0 ? Prefs.surfaceTint : (Theme.isLight ? 0.7 : 0)
                    onMoved: (v) => {
                        return Prefs.surfaceTint = v;
                    }
                }

                M3Button {
                    id: resetTint

                    anchors.verticalCenter: parent.verticalCenter
                    text: Prefs.surfaceTint >= 0 ? "Auto" : "Manual"
                    variant: Prefs.surfaceTint >= 0 ? "tonal" : "filled"
                    onClicked: Prefs.surfaceTint = Prefs.surfaceTint >= 0 ? -1 : (Theme.isLight ? 0.7 : 0.2)
                }

            }

        }

    }

    SettingCard {
        title: "MOTION"

        SettingRow {
            title: "Animation speed"
            resetKey: "motionScale"
            description: "Scales every transition in the shell. 1.00x is the shipped speed; drag to 0 for no animation at all."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 2
                stepSize: 0.25
                decimals: 2
                suffix: "x"
                value: Prefs.motionScale
                onMoved: (v) => {
                    return Prefs.motionScale = v;
                }
            }

        }

    }

    SettingCard {
        title: "DESKTOP"

        SettingRow {
            title: "Selection box"
            resetKey: "desktopSelection"
            description: "Drag across empty desktop and a translucent box follows the cursor, the way it does on Windows and macOS. It is decoration only \u2014 nothing gets selected, and dragging inside a window or on a widget is untouched."

            M3Switch {
                checked: Prefs.desktopSelection
                onToggled: (v) => {
                    return Prefs.desktopSelection = v;
                }
            }

        }

        SettingRow {
            title: "Right-click menu"
            resetKey: "desktopMenu"
            description: "Right-click empty desktop for wallpaper and theme, the widgets you have placed, a screenshot and settings."
            showDivider: false

            M3Switch {
                checked: Prefs.desktopMenu
                onToggled: (v) => {
                    return Prefs.desktopMenu = v;
                }
            }

        }

    }

}
