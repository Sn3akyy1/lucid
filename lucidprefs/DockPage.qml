import QtQuick
import qs

Column {
    id: page

    // shown in edit mode's sheet beside the dock itself, which needs no preview
    property bool inSheet: false

    spacing: Theme.dp(26)

    // with the bar on the bottom edge the dock is off, and a page of its
    // settings changing nothing on screen says nothing of why
    SettingCard {
        visible: Prefs.barBottom && Prefs.barEnabled
        title: "DOCK OFF"

        SettingRow {
            title: "The bar is on the bottom edge"
            description: "The dock gives the edge to the bar, and the launcher rises out of the bar instead. Its apps can come along: the bar's Apps module shows your pinned apps and the open ones, and keeps to the settings below for running applications, icon tiles, the running indicator and tooltips. The rest wait here for the bar to go back to the top."
            showDivider: false
            stacked: true

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    text: Prefs.showApps ? "Apps settings" : "Turn on Apps"
                    variant: "filled"
                    onClicked: {
                        if (Prefs.showApps)
                            Prefs.openBarModule("apps");
                        else
                            Prefs.showApps = true;
                    }
                }

                M3Button {
                    text: "Move the bar to the top"
                    variant: "tonal"
                    onClicked: Prefs.barPosition = "top"
                }

            }

        }

    }

    DockPreview {
        width: parent.width
        visible: !page.inSheet
    }

    SettingCard {
        title: "ON THE DESKTOP"
        visible: !page.inSheet

        SettingRow {
            title: "Edit the dock where it is"
            description: "In edit mode the desktop shades over and the dock gets a handle: drag it up to float the dock higher, or down into the bottom edge to make it a notch. Right-click the dock for these settings, right beside it."
            enabled: Prefs.dockEnabled
            disabledReason: "The dock is switched off."
            showDivider: false

            M3Button {
                text: "Edit the dock"
                variant: "filled"
                iconPath: "edit"
                enabled: Prefs.dockEnabled
                onClicked: Edit.enterFromSettings("dock", "dock")
            }

        }

    }

    SettingCard {
        title: "STYLE"

        SettingRow {
            title: "Dock style"
            resetKey: "dockStyle"
            description: Prefs.dockSplit ? "The launcher, your pinned apps and the running ones each float on an island of their own, the way the bar's modules do. They close up into one as the launcher opens out of them, and part again when it closes." : (Prefs.dockNotch ? "The dock sits flush against the bottom edge, its lower corners sweeping out into it." : "The dock floats above the bottom edge as one rounded island.")

            M3Segmented {
                width: Math.max(Theme.dp(300), fitWidth)
                current: Prefs.dockStyle
                options: [{
                    "key": "island",
                    "label": "Island"
                }, {
                    "key": "notch",
                    "label": "Notch"
                }, {
                    "key": "split",
                    "label": "Split"
                }]
                onChosen: (key) => {
                    return Prefs.dockStyle = key;
                }
            }

        }

        SettingRow {
            title: "Edge blend"
            resetKey: "dockNotchFlare"
            description: "How far the dock's lower corners sweep out into the bottom of the screen, so it reads as carved out of the edge rather than resting on it. A notched OSD sweeps out the same way."
            enabled: Prefs.dockNotch || Prefs.osdNotch
            disabledReason: "Only a notch meets the screen edge, so there is nothing to blend into - set Dock style to Notch above, or OSD style to Notch on the General page."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.dockNotch || Prefs.osdNotch
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
            title: "Island gap"
            resetKey: "dockSplitGap"
            description: "How far apart the launcher's island, the pinned apps' and the running apps' sit."
            enabled: Prefs.dockSplit
            disabledReason: "Only a split dock has islands to space out - set Dock style to Split above."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.dockSplit
                from: 4
                to: 24
                stepSize: 1
                suffix: " px"
                value: Prefs.dockSplitGap
                onMoved: (v) => {
                    return Prefs.dockSplitGap = v;
                }
            }

        }

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
            title: "Icon padding"
            resetKey: "dockIconPadding"
            description: "How far each icon is inset inside its own slot. More padding shrinks the icon without moving the dock."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 16
                stepSize: 1
                suffix: " px"
                value: Prefs.dockIconPadding
                onMoved: (v) => {
                    return Prefs.dockIconPadding = v;
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
            title: "Dock radius"
            resetKey: "dockRadius"
            description: "How round the dock's corners are. Each icon's own corners follow it, up to a full circle."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 40
                stepSize: 1
                suffix: " px"
                value: Prefs.dockRadius
                onMoved: (v) => {
                    return Prefs.dockRadius = v;
                }
            }

        }

        SettingRow {
            title: "Distance from bottom"
            resetKey: "dockBottomMargin"
            description: "How far the dock floats above the bottom edge of the screen."
            enabled: !Prefs.dockNotch
            disabledReason: "A notch sits flush against the screen edge by definition - set Dock style to Island or Split above to float the dock."
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
            description: "Always slides the dock off the bottom of the screen until the pointer reaches the edge. Dynamic only does it while a tiled window is open on the workspace, or a floating one overlaps the dock, so it is back whenever the desktop is clear."
            stacked: true

            M3Segmented {
                width: parent.width
                current: !Prefs.dockAutoHide ? "off" : (Prefs.dockDynamicHide ? "dynamic" : "always")
                options: [{
                    "key": "off",
                    "label": "Off"
                }, {
                    "key": "always",
                    "label": "Always"
                }, {
                    "key": "dynamic",
                    "label": "Dynamic"
                }]
                onChosen: (k) => {
                    Prefs.dockAutoHide = k !== "off";
                    Prefs.dockDynamicHide = k === "dynamic";
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
        title: "LAUNCHER"

        SettingRow {
            title: "Launcher"
            description: "The search panel the dock opens into, its modes, prefixes and the clipboard behind them now has a page of its own."
            showDivider: false

            M3Button {
                text: "Launcher\u2026"
                variant: "tonal"
                onClicked: Prefs.settingsRequested("launcher")
            }

        }

    }

    SettingCard {
        title: "PINNED APPLICATIONS"
        visible: !page.inSheet

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
