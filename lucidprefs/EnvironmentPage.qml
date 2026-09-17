import QtQuick
import qs

Column {
    id: page

    readonly property var schemeOptions: [{
        "key": "dark",
        "label": "Dark"
    }, {
        "key": "light",
        "label": "Light"
    }, {
        "key": "auto",
        "label": "Auto"
    }]

    function orUnset(v) {
        return v === "" ? "Not set" : v;
    }

    spacing: 26

    SettingCard {
        title: "POINTER"
        subtitle: Env.probed ? "" : "Reading what this machine has installed…"

        SettingRow {
            title: "Cursor theme"
            description: "Applied to GTK, Qt, XWayland and Hyprland at once. The pointer on screen changes as soon as you pick one; applications you open later pick it up from the environment."
            warning: Env.cursorMissing ? "“" + Prefs.envCursorTheme + "” is not installed on this machine any more." : ""

            M3Button {
                text: page.orUnset(Prefs.envCursorTheme)
                variant: "tonal"
                enabled: Env.cursorThemes.length > 0
                onClicked: Prefs.envPickerRequested("cursor")
            }

        }

        SettingRow {
            title: "Pointer shadow"
            resetKey: "envCursorShadow"
            enabled: Env.shadowCapable && !Env.shadowBuilding
            disabledReason: Env.shadowBuilding ? "Rendering the pointer without its shadow\u2026 this takes a few seconds." : (Env.shadowReason !== "" ? "\u201c" + Prefs.envCursorTheme + "\u201d " + Env.shadowReason + "." : "Reading the theme\u2019s sources\u2026")
            description: "The soft shade behind the pointer. Hyprland has no switch for it \u2014 it is painted into the theme itself \u2014 so turning it off renders the theme again from its vector sources and points everything at that copy. The pointer keeps its exact shape, sizes and hotspots."
            warning: Env.shadowError

            M3Switch {
                checked: Prefs.envCursorShadow
                onToggled: (v) => {
                    return Prefs.envCursorShadow = v;
                }
            }

        }

        SettingRow {
            title: "Cursor size"
            resetKey: "envCursorSize"
            description: "In pixels. GTK, Qt and Hyprland are all told the same number, which is what stops the pointer changing size as you move between applications."
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: Env.cursorSizes.length - 1
                stepSize: 1
                stepLabels: Env.cursorSizeLabels
                value: Env.sizeIndex(Prefs.envCursorSize)
                onMoved: (v) => {
                    return Prefs.envCursorSize = Env.sizeAt(v);
                }
            }

        }

    }

    SettingCard {
        title: "THEMES"

        SettingRow {
            title: "Icon theme"
            description: "Used by application menus, file managers and the shell's own dock. The dock follows a change straight away; open applications repaint when they next redraw."
            warning: Env.iconMissing ? "“" + Prefs.envIconTheme + "” is not installed on this machine any more." : ""

            M3Button {
                text: page.orUnset(Prefs.envIconTheme)
                variant: "tonal"
                enabled: Env.iconThemes.length > 0
                onClicked: Prefs.envPickerRequested("icon")
            }

        }

        SettingRow {
            title: "Application theme"
            description: "The GTK theme applications draw their own windows with. It has no effect on the shell, which follows the palette on the Theme page."
            warning: Env.gtkMissing ? "“" + Prefs.envGtkTheme + "” is not installed on this machine any more." : ""

            M3Button {
                text: page.orUnset(Prefs.envGtkTheme)
                variant: "tonal"
                enabled: Env.gtkThemes.length > 0
                onClicked: Prefs.envPickerRequested("gtk")
            }

        }

        SettingRow {
            title: "Light or dark"
            resetKey: "envColorScheme"
            description: "What applications are asked to prefer. Auto leaves the choice to each application."
            showDivider: false

            M3Segmented {
                width: 260
                current: Prefs.envColorScheme
                options: page.schemeOptions
                onChosen: (key) => {
                    return Prefs.envColorScheme = key;
                }
            }

        }

    }

    SettingCard {
        title: "TYPE"
        subtitle: "The shell's own font, and the one applications draw with."

        SettingRow {
            title: "Interface font"
            resetKey: "fontFamily"
            description: "Applied everywhere the shell draws text. Chosen from the fonts installed on this machine."

            M3Button {
                text: Prefs.fontFamily
                variant: "tonal"
                onClicked: Prefs.fontPickerRequested()
            }

        }

        SettingRow {
            title: "Text size"
            resetKey: "fontScale"
            description: "Scales the shell's whole type ramp at once. Applications are not affected."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0.9
                to: 1.5
                stepSize: 0.05
                decimals: 2
                suffix: "x"
                value: Prefs.fontScale
                onMoved: (v) => {
                    return Prefs.fontScale = v;
                }
            }

        }

        SettingRow {
            title: "Applications use the same font"
            resetKey: "envFontSync"
            description: "GTK and Qt are given the shell's interface font. Turn this off to set a separate one for them."

            M3Switch {
                checked: Prefs.envFontSync
                onToggled: (v) => {
                    return Prefs.envFontSync = v;
                }
            }

        }

        SettingRow {
            title: "Application font"
            enabled: !Prefs.envFontSync
            disabledReason: "Following the interface font above."
            description: "What GTK and Qt applications draw their menus and labels with."

            M3Button {
                text: page.orUnset(Prefs.envAppFont)
                variant: "tonal"
                onClicked: Prefs.envPickerRequested("appFont")
            }

        }

        SettingRow {
            title: "Application text size"
            resetKey: "envAppFontSize"
            description: "In points, the unit GTK and Qt both measure type in."
            stacked: true

            M3Slider {
                width: parent.width
                from: 7
                to: 18
                stepSize: 1
                suffix: " pt"
                value: Prefs.envAppFontSize
                onMoved: (v) => {
                    return Prefs.envAppFontSize = Math.round(v);
                }
            }

        }

        SettingRow {
            title: "Document font"
            description: "Used by applications that lay out pages rather than interfaces."

            M3Button {
                text: page.orUnset(Prefs.envDocumentFont)
                variant: "tonal"
                onClicked: Prefs.envPickerRequested("docFont")
            }

        }

        SettingRow {
            title: "Monospace font"
            description: "Terminals, editors and anything else asking for a fixed-width face."
            showDivider: false

            M3Button {
                text: page.orUnset(Prefs.envMonoFont)
                variant: "tonal"
                onClicked: Prefs.envPickerRequested("monoFont")
            }

        }

    }

    SettingCard {
        title: "TOOLKITS"
        subtitle: Env.summary

        SettingRow {
            title: "GTK applications"
            resetKey: "envApplyGtk"
            description: "Writes the settings above into GTK 2, 3 and 4, and into gsettings, which is what makes running applications follow along."
            enabled: Env.targets.gsettings !== false

            M3Switch {
                checked: Prefs.envApplyGtk
                onToggled: (v) => {
                    return Prefs.envApplyGtk = v;
                }
            }

        }

        SettingRow {
            title: "Qt applications"
            resetKey: "envApplyQt"
            description: Env.targets.qt6ct === false && Env.targets.qt5ct === false ? "Neither qt5ct nor qt6ct is configured on this machine, so there is nothing to write." : "Writes into the qt5ct and qt6ct configurations this machine already has."
            enabled: Env.targets.qt6ct === true || Env.targets.qt5ct === true

            M3Switch {
                checked: Prefs.envApplyQt
                onToggled: (v) => {
                    return Prefs.envApplyQt = v;
                }
            }

        }

        SettingRow {
            title: "Qt style"
            enabled: Prefs.envApplyQt && (Env.targets.qt6ct === true || Env.targets.qt5ct === true)
            disabledReason: "Turn Qt applications on to choose a style."
            description: "How Qt draws its own widgets. Fusion is the one every machine has."

            M3Button {
                text: page.orUnset(Prefs.envQtStyle)
                variant: "tonal"
                onClicked: Prefs.envPickerRequested("qtStyle")
            }

        }

        SettingRow {
            title: "Hyprland environment"
            resetKey: "envApplyHypr"
            description: "Keeps XCURSOR_THEME, XCURSOR_SIZE and the icon theme in Hyprland's env module, so applications started later inherit them."
            enabled: Env.targets.hyprland !== false
            disabledReason: "No Hyprland env module on this machine to write to."
            showDivider: false

            M3Switch {
                checked: Prefs.envApplyHypr
                onToggled: (v) => {
                    return Prefs.envApplyHypr = v;
                }
            }

        }

    }

    SettingCard {
        title: "THIS MACHINE"

        SettingRow {
            title: "Re-read from the system"
            description: Env.lastError !== "" ? Env.lastError : "Loads whatever the machine's own configuration files currently say, discarding what is set here. Useful after changing appearance with another tool."
            showDivider: false

            M3Button {
                text: Env.busy ? "Working…" : "Re-read"
                variant: "tonal"
                enabled: !Env.busy
                onClicked: Prefs.askConfirm("Re-read appearance from this machine?", "Every setting on this page is replaced by what the machine's GTK, Qt and Hyprland configuration currently says. Nothing else is touched.", "Re-read", Prefs.resetEnvToken)
            }

        }

    }

}
