import QtQuick
import qs
import qs.lucidicons

Column {
    id: page

    readonly property var schemeOptions: [{
        "key": "dark",
        "label": I18n.tr("Dark")
    }, {
        "key": "light",
        "label": I18n.tr("Light")
    }, {
        "key": "auto",
        "label": I18n.tr("Auto")
    }]

    readonly property var responseOptions: [{
        "key": "negative_quadratic",
        "label": I18n.tr("Eager")
    }, {
        "key": "linear",
        "label": I18n.tr("Even")
    }, {
        "key": "quadratic",
        "label": I18n.tr("Lazy")
    }]
    // unset is modules/plugins.lua's own, which tilts
    readonly property bool tiltOn: HyprConfig.mine["lucid.cursor_tilt"] !== false
    readonly property bool shakeOn: HyprConfig.bool("plugin.dynamic_cursors.shake.enabled", true)
    readonly property bool motionReady: HyprConfig.moduleInstalled && HyprConfig.cursorPlugin
    readonly property string motionReason: {
        if (!HyprConfig.liveRead)
            return "";

        if (HyprConfig.moduleProbed && !HyprConfig.moduleInstalled)
            return I18n.tr("Your Hyprland config does not read ~/.config/hypr/lucid-settings.lua, where these go. Run the installer with --with-hypr, or add Lucid's modules/settings.lua and require it in hyprland.lua.");

        if (!HyprConfig.cursorPlugin)
            return I18n.tr("The pointer moves through hypr-dynamic-cursors, a Hyprland plugin that is not loaded right now.");

        return "";
    }

    function orUnset(v) {
        return v === "" ? I18n.tr("Not set") : v;
    }

    spacing: Theme.dp(26)
    Component.onCompleted: HyprConfig.refresh()

    SettingCard {
        title: I18n.tr("POINTER")
        subtitle: Env.probed ? "" : I18n.tr("Reading what this machine has installed…")

        SettingRow {
            title: I18n.tr("Use legacy cursor theme")
            resetKey: "envLegacyCursor"
            description: I18n.tr("Turns off Lucid's own pointer, Bibata Modern drawn in your palette's colours, and uses a cursor theme installed on this machine instead.")

            M3Switch {
                checked: Prefs.envLegacyCursor
                onToggled: (v) => {
                    return Prefs.envLegacyCursor = v;
                }
            }

        }

        // lucid's own pointer: how it takes the palette, and what that looks like
        SettingRow {
            visible: !Prefs.envLegacyCursor
            title: I18n.tr("Pointer colour")
            resetKey: "envCursorStyle"
            description: I18n.tr("Dark is Bibata's classic look, a dark pointer with a light outline, and Light turns it over; both keep one look in light and dark mode. Accent is your palette's own colour and turns deep in light mode, the way a filled button does. When the palette changes, the pointer fades across to its new colours along with the rest of the shell.")
            warning: Pointer.error
            stacked: true

            Column {
                width: parent.width
                spacing: Theme.dp(16)

                M3Segmented {
                    width: Math.min(parent.width, Theme.dp(320))
                    current: Prefs.envCursorStyle
                    options: Pointer.styles
                    onChosen: (key) => {
                        return Prefs.envCursorStyle = key;
                    }
                }

                // a few of the shapes, as the theme on disk draws them right now
                Row {
                    visible: Pointer.drawn
                    spacing: Theme.dp(20)

                    Repeater {
                        model: ["left_ptr", "hand2", "xterm", "wait", "crossed_circle", "bd_double_arrow"]

                        Image {
                            required property string modelData

                            width: Theme.dp(40)
                            height: Theme.dp(40)
                            source: Pointer.drawn ? "file://" + Pointer.themeDir + "/preview/" + modelData + ".png?" + Pointer.revision : ""
                            sourceSize: Qt.size(96, 96)
                            cache: false
                            smooth: true
                            mipmap: true
                        }

                    }

                }

            }

        }

        SettingRow {
            visible: Prefs.envLegacyCursor
            title: I18n.tr("Cursor theme")
            description: I18n.tr("Applied to GTK, Qt, XWayland and Hyprland at once. The pointer on screen changes as soon as you pick one; applications you open later pick it up from the environment.")
            warning: Env.cursorMissing ? I18n.tr("“%1” is not installed on this machine any more.", Prefs.envCursorTheme) : ""

            M3Button {
                text: page.orUnset(Prefs.envCursorTheme)
                variant: "tonal"
                enabled: Env.cursorThemes.length > 0
                onClicked: Prefs.envPickerRequested("cursor")
            }

        }

        SettingRow {
            title: I18n.tr("Pointer shadow")
            resetKey: "envCursorShadow"
            enabled: !Prefs.envLegacyCursor || (Env.shadowCapable && !Env.shadowBuilding)
            disabledReason: Env.shadowBuilding ? I18n.tr("Rendering the pointer without its shadow\u2026 this takes a few seconds.") : (Env.shadowReason !== "" ? "\u201c" + Prefs.envCursorTheme + "\u201d " + Env.shadowReason + "." : I18n.tr("Reading the theme\u2019s sources\u2026"))
            description: Prefs.envLegacyCursor ? I18n.tr("The soft shade behind the pointer. Hyprland has no switch for it \u2014 it is painted into the theme itself \u2014 so turning it off renders the theme again from its vector sources and points everything at that copy. The pointer keeps its exact shape, sizes and hotspots.") : I18n.tr("A soft shade under the pointer, which lifts it off whatever it passes over. Bibata draws none of its own.")
            warning: Prefs.envLegacyCursor ? Env.shadowError : ""

            M3Switch {
                checked: Prefs.envCursorShadow
                onToggled: (v) => {
                    return Prefs.envCursorShadow = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Cursor size")
            resetKey: "envCursorSize"
            description: I18n.tr("In pixels. GTK, Qt and Hyprland are all told the same number, which is what stops the pointer changing size as you move between applications.")
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

    // hypr-dynamic-cursors does the moving; modules/plugins.lua names the
    // pointers that lean, and modules/settings.lua applies what is set here
    SettingCard {
        title: I18n.tr("POINTER MOTION")
        subtitle: page.motionReason

        HyprRow {
            id: tiltRow

            title: I18n.tr("Tilt as it moves")
            option: "lucid.cursor_tilt"
            description: I18n.tr("The arrow, the busy and help pointers drawn on it, and the pointing hand lean into the way you move, as if they had a little weight. Text, resizing, moving, the crosshair and every other pointer stay upright.")
            available: page.motionReady
            unavailableReason: page.motionReason

            M3Switch {
                enabled: tiltRow.enabled
                checked: page.tiltOn
                onToggled: (v) => {
                    return HyprConfig.set("lucid.cursor_tilt", v);
                }
            }

        }

        HyprRow {
            id: appsRow

            title: I18n.tr("Also in apps that draw their own pointer")
            option: "lucid.cursor_tilt_apps"
            description: I18n.tr("Zen and Firefox, GTK 3 and X11 applications draw their pointer themselves and never tell Hyprland which one it is, so in them every pointer leans, the text one included, or none does.")
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? I18n.tr("Turn tilting on to choose this.") : page.motionReason

            M3Switch {
                enabled: appsRow.enabled
                checked: HyprConfig.mine["lucid.cursor_tilt_apps"] !== false
                onToggled: (v) => {
                    return HyprConfig.set("lucid.cursor_tilt_apps", v);
                }
            }

        }

        HyprRow {
            id: leanRow

            title: I18n.tr("How far it leans")
            option: "plugin.dynamic_cursors.tilt.full"
            description: I18n.tr("The furthest it tips to either side, when you move fast.")
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? I18n.tr("Turn tilting on to set how it leans.") : page.motionReason
            stacked: true

            M3Slider {
                width: parent.width
                enabled: leanRow.enabled
                from: 10
                to: 180
                stepSize: 5
                suffix: "°"
                value: HyprConfig.num("plugin.dynamic_cursors.tilt.full", 60)
                onMoved: (v) => {
                    return HyprConfig.set("plugin.dynamic_cursors.tilt.full", Math.round(v));
                }
            }

        }

        HyprRow {
            id: speedRow

            title: I18n.tr("Speed for a full lean")
            option: "plugin.dynamic_cursors.tilt.limit"
            description: I18n.tr("How fast the pointer has to travel to lean all the way, in pixels a second. Lower leans sooner.")
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? I18n.tr("Turn tilting on to set how it leans.") : page.motionReason
            stacked: true

            M3Slider {
                width: parent.width
                enabled: speedRow.enabled
                from: 1000
                to: 10000
                stepSize: 250
                suffix: " px/s"
                value: HyprConfig.num("plugin.dynamic_cursors.tilt.limit", 5000)
                onMoved: (v) => {
                    return HyprConfig.set("plugin.dynamic_cursors.tilt.limit", Math.round(v));
                }
            }

        }

        HyprRow {
            id: responseRow

            title: I18n.tr("How it picks up")
            option: "plugin.dynamic_cursors.tilt.activation"
            description: I18n.tr("Eager leans early and eases into the rest, Even keeps step with your speed, and Lazy waits for a quick flick.")
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? I18n.tr("Turn tilting on to set how it leans.") : page.motionReason
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(320))
                enabled: responseRow.enabled
                current: HyprConfig.value("plugin.dynamic_cursors.tilt.activation") || "negative_quadratic"
                options: page.responseOptions
                onChosen: (key) => {
                    return HyprConfig.set("plugin.dynamic_cursors.tilt.activation", key);
                }
            }

        }

        HyprRow {
            id: smoothRow

            title: I18n.tr("Smoothing")
            option: "plugin.dynamic_cursors.tilt.window"
            description: I18n.tr("How much of your last movement it weighs. Higher is steadier, but trails your hand a little.")
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? I18n.tr("Turn tilting on to set how it leans.") : page.motionReason
            stacked: true

            M3Slider {
                width: parent.width
                enabled: smoothRow.enabled
                from: 20
                to: 300
                stepSize: 10
                suffix: " ms"
                value: HyprConfig.num("plugin.dynamic_cursors.tilt.window", 100)
                onMoved: (v) => {
                    return HyprConfig.set("plugin.dynamic_cursors.tilt.window", Math.round(v));
                }
            }

        }

        // the plugin is a compile away on a machine that skipped it at install
        SettingRow {
            visible: HyprConfig.liveRead && !HyprConfig.cursorPlugin && HyprConfig.pluginScriptFound
            title: I18n.tr("Cursor plugin")
            description: HyprConfig.pluginBuilding ? I18n.tr("Building it for the Hyprland on this machine\u2026 this takes about a minute.") : I18n.tr("Tilting and shake to find come from hypr-dynamic-cursors, a Hyprland plugin Lucid builds here for the exact Hyprland you have. It needs git and base-devel, and no password.")
            warning: HyprConfig.pluginError
            showDivider: false

            M3Button {
                text: HyprConfig.pluginBuilding ? I18n.tr("Building\u2026") : I18n.tr("Build and load")
                variant: "tonal"
                enabled: !HyprConfig.pluginBuilding
                onClicked: HyprConfig.buildCursorPlugin()
            }

        }

    // the same plugin grows the pointer when it is shaken, drawn sharp from a
    // large copy of the theme it keeps
    SettingCard {
        title: I18n.tr("SHAKE TO FIND")
        subtitle: page.motionReason

        HyprRow {
            id: shakeRow

            title: I18n.tr("Grow the pointer when you shake it")
            option: "plugin.dynamic_cursors.shake.enabled"
            description: I18n.tr("Shake the pointer and it grows for a moment, so it is easy to find on a busy screen. It stays sharp however large it gets.")
            available: page.motionReady
            unavailableReason: page.motionReason

            M3Switch {
                enabled: shakeRow.enabled
                checked: page.shakeOn
                onToggled: (v) => {
                    return HyprConfig.set("plugin.dynamic_cursors.shake.enabled", v);
                }
            }

        }

        HyprRow {
            id: shakeSize

            title: I18n.tr("How big it grows")
            option: "plugin.dynamic_cursors.shake.base"
            description: I18n.tr("Its size the moment a shake is noticed, as a multiple of the pointer's own. Keep shaking and it grows a little more.")
            available: page.motionReady && page.shakeOn
            unavailableReason: page.motionReady ? I18n.tr("Turn growing on to set how it grows.") : page.motionReason
            stacked: true

            M3Slider {
                width: parent.width
                enabled: shakeSize.enabled
                from: 1.5
                to: 6
                stepSize: 0.5
                decimals: 1
                suffix: "×"
                value: HyprConfig.num("plugin.dynamic_cursors.shake.base", 4)
                onMoved: (v) => {
                    return HyprConfig.set("plugin.dynamic_cursors.shake.base", Math.round(v * 2) / 2);
                }
            }

        }

        HyprRow {
            id: shakeHard

            title: I18n.tr("How hard to shake")
            option: "plugin.dynamic_cursors.shake.threshold"
            description: I18n.tr("Lower grows on a small shake, higher waits for a big one, so it never grows by accident.")
            available: page.motionReady && page.shakeOn
            unavailableReason: page.motionReady ? I18n.tr("Turn growing on to set how it grows.") : page.motionReason
            stacked: true

            M3Slider {
                width: parent.width
                enabled: shakeHard.enabled
                from: 2
                to: 12
                stepSize: 0.5
                decimals: 1
                value: HyprConfig.num("plugin.dynamic_cursors.shake.threshold", 6)
                onMoved: (v) => {
                    return HyprConfig.set("plugin.dynamic_cursors.shake.threshold", Math.round(v * 2) / 2);
                }
            }

        }

        HyprRow {
            id: shakeLong

            title: I18n.tr("Stays big for")
            option: "plugin.dynamic_cursors.shake.timeout"
            description: I18n.tr("How long it stays grown once you stop shaking.")
            available: page.motionReady && page.shakeOn
            unavailableReason: page.motionReady ? I18n.tr("Turn growing on to set how it grows.") : page.motionReason
            showDivider: false
            stacked: true

            M3Slider {
                width: parent.width
                enabled: shakeLong.enabled
                from: 250
                to: 5000
                stepSize: 250
                suffix: " ms"
                value: HyprConfig.num("plugin.dynamic_cursors.shake.timeout", 2000)
                onMoved: (v) => {
                    return HyprConfig.set("plugin.dynamic_cursors.shake.timeout", Math.round(v));
                }
            }

        }

    }

    }

    SettingCard {
        title: I18n.tr("THEMES")

        SettingRow {
            title: I18n.tr("Use legacy icons")
            resetKey: "envLegacyIcons"
            description: I18n.tr("Turns off Lucid's own icons, coloured by Matugen from your wallpaper, and uses your GTK icon theme instead: on the desktop, the dock, the launcher, the tray and in Lumen.")

            M3Switch {
                checked: Prefs.envLegacyIcons
                onToggled: (v) => {
                    return Prefs.envLegacyIcons = v;
                }
            }

        }

        // lucid's sets while its own icons are on, the gtk themes once they are off
        SettingRow {
            title: I18n.tr("Icon theme")
            resetKey: Prefs.envLegacyIcons ? "" : "envIconSet"
            description: Prefs.envLegacyIcons ? I18n.tr("Used by application menus, file managers and the shell's own dock. The dock follows a change straight away; open applications repaint when they next redraw.") : I18n.tr("How Lucid draws files, folders and apps, in your wallpaper's colours. Gravity is lit softly from above; Gravity (Simplified) is the same set in flat tones.")
            warning: Prefs.envLegacyIcons && Env.iconMissing ? I18n.tr("“%1” is not installed on this machine any more.", Prefs.envIconTheme) : ""

            M3Button {
                text: Prefs.envLegacyIcons ? page.orUnset(Prefs.envIconTheme) : LucidIcons.nameOf(Prefs.envIconSet)
                variant: "tonal"
                enabled: !Prefs.envLegacyIcons || Env.iconThemes.length > 0
                onClicked: Prefs.envPickerRequested(Prefs.envLegacyIcons ? "icon" : "iconSet")
            }

        }

        SettingRow {
            title: I18n.tr("Application theme")
            description: I18n.tr("The GTK theme applications draw their own windows with. It has no effect on the shell, which follows the palette on the Theme page.")
            warning: Env.gtkMissing ? I18n.tr("“%1” is not installed on this machine any more.", Prefs.envGtkTheme) : ""

            M3Button {
                text: page.orUnset(Prefs.envGtkTheme)
                variant: "tonal"
                enabled: Env.gtkThemes.length > 0
                onClicked: Prefs.envPickerRequested("gtk")
            }

        }

        SettingRow {
            title: I18n.tr("Light or dark")
            resetKey: "envColorScheme"
            description: I18n.tr("What applications are asked to prefer. Auto leaves the choice to each application.")
            showDivider: false

            M3Segmented {
                width: Theme.dp(260)
                current: Prefs.envColorScheme
                options: page.schemeOptions
                onChosen: (key) => {
                    return Prefs.envColorScheme = key;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("TYPE")
        subtitle: I18n.tr("The shell's own font, and the one applications draw with.")

        SettingRow {
            title: I18n.tr("Interface font")
            resetKey: "fontFamily"
            description: I18n.tr("Applied everywhere the shell draws text. Chosen from the fonts installed on this machine.")

            M3Button {
                text: Prefs.fontFamily
                variant: "tonal"
                onClicked: Prefs.fontPickerRequested()
            }

        }

        SettingRow {
            title: I18n.tr("Text size")
            resetKey: "fontScale"
            description: I18n.tr("Scales the shell's whole type ramp at once. Applications are not affected.")
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
            title: I18n.tr("Applications use the same font")
            resetKey: "envFontSync"
            description: I18n.tr("GTK and Qt are given the shell's interface font. Turn this off to set a separate one for them.")

            M3Switch {
                checked: Prefs.envFontSync
                onToggled: (v) => {
                    return Prefs.envFontSync = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Application font")
            enabled: !Prefs.envFontSync
            disabledReason: I18n.tr("Following the interface font above.")
            description: I18n.tr("What GTK and Qt applications draw their menus and labels with.")

            M3Button {
                text: page.orUnset(Prefs.envAppFont)
                variant: "tonal"
                onClicked: Prefs.envPickerRequested("appFont")
            }

        }

        SettingRow {
            title: I18n.tr("Application text size")
            resetKey: "envAppFontSize"
            description: I18n.tr("In points, the unit GTK and Qt both measure type in.")
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
            title: I18n.tr("Document font")
            description: I18n.tr("Used by applications that lay out pages rather than interfaces.")

            M3Button {
                text: page.orUnset(Prefs.envDocumentFont)
                variant: "tonal"
                onClicked: Prefs.envPickerRequested("docFont")
            }

        }

        SettingRow {
            title: I18n.tr("Monospace font")
            description: I18n.tr("Terminals, editors and anything else asking for a fixed-width face.")
            showDivider: false

            M3Button {
                text: page.orUnset(Prefs.envMonoFont)
                variant: "tonal"
                onClicked: Prefs.envPickerRequested("monoFont")
            }

        }

    }

    SettingCard {
        title: I18n.tr("TOOLKITS")
        subtitle: Env.summary

        SettingRow {
            title: I18n.tr("GTK applications")
            resetKey: "envApplyGtk"
            description: I18n.tr("Writes the settings above into GTK 2, 3 and 4, and into gsettings, which is what makes running applications follow along.")
            enabled: Env.targets.gsettings !== false

            M3Switch {
                checked: Prefs.envApplyGtk
                onToggled: (v) => {
                    return Prefs.envApplyGtk = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Qt applications")
            resetKey: "envApplyQt"
            description: Env.targets.qt6ct === false && Env.targets.qt5ct === false ? I18n.tr("Neither qt5ct nor qt6ct is configured on this machine, so there is nothing to write.") : I18n.tr("Writes into the qt5ct and qt6ct configurations this machine already has.")
            enabled: Env.targets.qt6ct === true || Env.targets.qt5ct === true

            M3Switch {
                checked: Prefs.envApplyQt
                onToggled: (v) => {
                    return Prefs.envApplyQt = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Qt style")
            enabled: Prefs.envApplyQt && (Env.targets.qt6ct === true || Env.targets.qt5ct === true)
            disabledReason: I18n.tr("Turn Qt applications on to choose a style.")
            description: I18n.tr("How Qt draws its own widgets. Fusion is the one every machine has.")

            M3Button {
                text: page.orUnset(Prefs.envQtStyle)
                variant: "tonal"
                onClicked: Prefs.envPickerRequested("qtStyle")
            }

        }

        SettingRow {
            title: I18n.tr("Hyprland environment")
            resetKey: "envApplyHypr"
            description: I18n.tr("Keeps XCURSOR_THEME, XCURSOR_SIZE and the icon theme in Hyprland's env module, so applications started later inherit them.")
            enabled: Env.targets.hyprland !== false
            disabledReason: I18n.tr("No Hyprland env module on this machine to write to.")
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
        title: I18n.tr("THIS MACHINE")

        SettingRow {
            title: I18n.tr("Re-read from the system")
            description: Env.lastError !== "" ? Env.lastError : I18n.tr("Loads whatever the machine's own configuration files currently say, discarding what is set here. Useful after changing appearance with another tool.")
            showDivider: false

            M3Button {
                text: Env.busy ? I18n.tr("Working…") : I18n.tr("Re-read")
                variant: "tonal"
                enabled: !Env.busy
                onClicked: Prefs.askConfirm(I18n.tr("Re-read appearance from this machine?"), I18n.tr("Every setting on this page is replaced by what the machine's GTK, Qt and Hyprland configuration currently says. Nothing else is touched."), "Re-read", Prefs.resetEnvToken)
            }

        }

    }

}
