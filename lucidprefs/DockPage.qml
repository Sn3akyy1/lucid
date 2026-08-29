import QtQuick
import qs

Column {
    id: page

    spacing: 26

    DockPreview {
        width: parent.width
    }

    SettingCard {
        title: "SIZE & PLACEMENT"

        SettingRow {
            title: "Icon size"
            resetKey: "dockIconSize"
            description: "The size of each icon's slot in the dock. The dock's own height follows it."
            stacked: true

            M3Slider {
                width: parent.width
                from: 32
                to: 72
                stepSize: 1
                suffix: " px"
                value: Prefs.dockIconSize
                onMoved: (v) => {
                    return Prefs.dockIconSize = v;
                }
            }

        }

        SettingRow {
            title: "Icon spacing"
            resetKey: "dockSpacing"
            description: "The gap between neighbouring icons."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 28
                stepSize: 1
                suffix: " px"
                value: Prefs.dockSpacing
                onMoved: (v) => {
                    return Prefs.dockSpacing = v;
                }
            }

        }

        SettingRow {
            title: "Distance from bottom"
            resetKey: "dockBottomMargin"
            description: "How far the dock floats above the bottom edge of the screen."
            enabled: !Prefs.dockNotch
            disabledReason: "Notches sit flush against the screen edge by definition - switch back to islands on the General page to float the dock."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                enabled: !Prefs.dockNotch
                from: 0
                to: 60
                stepSize: 1
                suffix: " px"
                value: Prefs.dockBottomMargin
                onMoved: (v) => {
                    return Prefs.dockBottomMargin = v;
                }
            }

        }

    }

    SettingCard {
        title: "BEHAVIOUR"

        SettingRow {
            title: "Edge blend"
            resetKey: "dockNotchFlare"
            description: "How far the dock's lower corners sweep out into the bottom of the screen, so it reads as carved out of the edge rather than resting on it."
            enabled: Prefs.dockNotch
            disabledReason: "Islands float clear of the screen edge, so there is nothing to blend into - switch the dock to Notches on the General page."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.dockNotch
                from: 0
                to: 40
                stepSize: 1
                suffix: " px"
                value: Prefs.dockNotchFlare
                onMoved: (v) => {
                    return Prefs.dockNotchFlare = v;
                }
            }

        }

        SettingRow {
            title: "Hover strength"
            resetKey: "dockHoverEffect"
            description: "How far an icon swells and lifts under the pointer. At 0 the icons stay put - hovering still highlights them, it just stops moving them."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 2
                stepSize: 0.1
                suffix: "x"
                value: Prefs.dockHoverEffect
                onMoved: (v) => {
                    return Prefs.dockHoverEffect = v;
                }
            }

        }

        SettingRow {
            title: "Magnify on hover"
            description: "Icons swell as the pointer passes over them, and their neighbours follow in a ripple."

            M3Switch {
                checked: Prefs.dockMagnify
                onToggled: (v) => {
                    return Prefs.dockMagnify = v;
                }
            }

        }

        SettingRow {
            title: "Auto-hide"
            description: "The dock slides off the bottom of the screen and comes back when the pointer reaches the edge."

            M3Switch {
                checked: Prefs.dockAutoHide
                onToggled: (v) => {
                    return Prefs.dockAutoHide = v;
                }
            }

        }

        SettingRow {
            title: "Show running applications"
            description: "Applications that are running but not pinned appear in the dock beside the pinned ones."

            M3Switch {
                checked: Prefs.dockShowRunning
                onToggled: (v) => {
                    return Prefs.dockShowRunning = v;
                }
            }

        }

        SettingRow {
            title: "Icon tiles"
            description: "Draws a filled tile behind every icon. Material 3 leaves the container empty and lets hover and press do the talking, which is how the dock looks with this off."
            showDivider: false

            M3Switch {
                checked: Prefs.dockIconTiles
                onToggled: (v) => {
                    return Prefs.dockIconTiles = v;
                }
            }

        }

    }

    SettingCard {
        title: "INDICATORS"

        SettingRow {
            title: "Running indicator"
            description: "A mark beneath any icon whose application is running - one segment per window, widening into a single bar for the window you are focused on."

            M3Switch {
                checked: Prefs.dockShowIndicators
                onToggled: (v) => {
                    return Prefs.dockShowIndicators = v;
                }
            }

        }

        SettingRow {
            title: "Tooltips"
            description: "The application's name appears above its icon after a short hover."
            showDivider: false

            M3Switch {
                checked: Prefs.dockShowTooltips
                onToggled: (v) => {
                    return Prefs.dockShowTooltips = v;
                }
            }

        }

    }

    SettingCard {
        title: "PINNED APPLICATIONS"

        SettingRow {
            title: "Reset pinned applications"
            description: "Puts the dock back to its default set of pinned applications. Anything pinned or reordered since is discarded."
            showDivider: false

            M3Button {
                text: "Reset dock"
                variant: "text"
                destructive: true
                onClicked: Prefs.askReset("Reset pinned applications?", "The dock goes back to its default set of pinned applications. Anything pinned or reordered since is discarded.", Prefs.resetDockToken)
            }

        }

    }

}
