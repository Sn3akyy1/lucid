import QtQuick
import qs

// Dock settings. Everything here maps onto something the dock already does -
// the magnification ripple, the running-app dot, the hover tooltip and the
// unpinned-but-running icons all exist; this just exposes them.
Column {
    id: page

    spacing: 26

    DockPreview {
        width: parent.width
    }

    // ---------------- size ----------------
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

    // ---------------- behaviour ----------------
    SettingCard {
        title: "BEHAVIOUR"

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
            showDivider: false

            M3Switch {
                checked: Prefs.dockShowRunning
                onToggled: (v) => {
                    return Prefs.dockShowRunning = v;
                }
            }

        }

    }

    // ---------------- indicators ----------------
    SettingCard {
        title: "INDICATORS"

        SettingRow {
            title: "Running indicator"
            description: "A dot beneath any icon whose application is actually running."

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

    // ---------------- pinned apps ----------------
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
