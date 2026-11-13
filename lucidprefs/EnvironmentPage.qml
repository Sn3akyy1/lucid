import QtQuick
import qs
import qs.lucidicons

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

    readonly property var responseOptions: [{
        "key": "negative_quadratic",
        "label": "Eager"
    }, {
        "key": "linear",
        "label": "Even"
    }, {
        "key": "quadratic",
        "label": "Lazy"
    }]
    // unset is modules/plugins.lua's own, which tilts
    readonly property bool tiltOn: HyprConfig.mine["lucid.cursor_tilt"] !== false
    readonly property bool shakeOn: HyprConfig.bool("plugin.dynamic_cursors.shake.enabled", true)
    readonly property bool motionReady: HyprConfig.moduleInstalled && HyprConfig.cursorPlugin
    readonly property string motionReason: {
        if (!HyprConfig.liveRead)
            return "";

        if (HyprConfig.moduleProbed && !HyprConfig.moduleInstalled)
            return "Your Hyprland config does not read ~/.config/hypr/lucid-settings.lua, where these go. Run the installer with --with-hypr, or add Lucid's modules/settings.lua and require it in hyprland.lua.";

        if (!HyprConfig.cursorPlugin)
            return "The pointer moves through hypr-dynamic-cursors, a Hyprland plugin that is not loaded right now.";

        return "";
    }

    function orUnset(v) {
        return v === "" ? "Not set" : v;
    }

    spacing: Theme.dp(26)
    Component.onCompleted: HyprConfig.refresh()

    SettingCard {
        title: "POINTER"
        subtitle: Env.probed ? "" : "Reading what this machine has installed…"

        SettingRow {
            title: "Use legacy cursor theme"
            resetKey: "envLegacyCursor"
            description: "Turns off Lucid's own pointer, Bibata Modern drawn in your palette's colours, and uses a cursor theme installed on this machine instead."

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
            title: "Pointer colour"
            resetKey: "envCursorStyle"
            description: "Dark is Bibata's classic look, a dark pointer with a light outline, and Light turns it over; both keep one look in light and dark mode. Accent is your palette's own colour and turns deep in light mode, the way a filled button does. When the palette changes, the pointer fades across to its new colours along with the rest of the shell."
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
            enabled: !Prefs.envLegacyCursor || (Env.shadowCapable && !Env.shadowBuilding)
            disabledReason: Env.shadowBuilding ? "Rendering the pointer without its shadow\u2026 this takes a few seconds." : (Env.shadowReason !== "" ? "\u201c" + Prefs.envCursorTheme + "\u201d " + Env.shadowReason + "." : "Reading the theme\u2019s sources\u2026")
            description: Prefs.envLegacyCursor ? "The soft shade behind the pointer. Hyprland has no switch for it \u2014 it is painted into the theme itself \u2014 so turning it off renders the theme again from its vector sources and points everything at that copy. The pointer keeps its exact shape, sizes and hotspots." : "A soft shade under the pointer, which lifts it off whatever it passes over. Bibata draws none of its own."
            warning: Prefs.envLegacyCursor ? Env.shadowError : ""

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

    // hypr-dynamic-cursors does the moving; modules/plugins.lua names the
    // pointers that lean, and modules/settings.lua applies what is set here
    SettingCard {
        title: "POINTER MOTION"
        subtitle: page.motionReason

        HyprRow {
            id: tiltRow

            title: "Tilt as it moves"
            option: "lucid.cursor_tilt"
            description: "The arrow, the busy and help pointers drawn on it, and the pointing hand lean into the way you move, as if they had a little weight. Text, resizing, moving, the crosshair and every other pointer stay upright."
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

            title: "Also in apps that draw their own pointer"
            option: "lucid.cursor_tilt_apps"
            description: "Zen and Firefox, GTK 3 and X11 applications draw their pointer themselves and never tell Hyprland which one it is, so in them every pointer leans, the text one included, or none does."
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? "Turn tilting on to choose this." : page.motionReason

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

            title: "How far it leans"
            option: "plugin.dynamic_cursors.tilt.full"
            description: "The furthest it tips to either side, when you move fast."
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? "Turn tilting on to set how it leans." : page.motionReason
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

            title: "Speed for a full lean"
            option: "plugin.dynamic_cursors.tilt.limit"
            description: "How fast the pointer has to travel to lean all the way, in pixels a second. Lower leans sooner."
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? "Turn tilting on to set how it leans." : page.motionReason
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

            title: "How it picks up"
            option: "plugin.dynamic_cursors.tilt.activation"
            description: "Eager leans early and eases into the rest, Even keeps step with your speed, and Lazy waits for a quick flick."
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? "Turn tilting on to set how it leans." : page.motionReason
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

            title: "Smoothing"
            option: "plugin.dynamic_cursors.tilt.window"
            description: "How much of your last movement it weighs. Higher is steadier, but trails your hand a little."
            available: page.motionReady && page.tiltOn
            unavailableReason: page.motionReady ? "Turn tilting on to set how it leans." : page.motionReason
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
            title: "Cursor plugin"
            description: HyprConfig.pluginBuilding ? "Building it for the Hyprland on this machine\u2026 this takes about a minute." : "Tilting and shake to find come from hypr-dynamic-cursors, a Hyprland plugin Lucid builds here for the exact Hyprland you have. It needs git and base-devel, and no password."
            warning: HyprConfig.pluginError
            showDivider: false

            M3Button {
                text: HyprConfig.pluginBuilding ? "Building\u2026" : "Build and load"
                variant: "tonal"
                enabled: !HyprConfig.pluginBuilding
                onClicked: HyprConfig.buildCursorPlugin()
            }

        }

    // the same plugin grows the pointer when it is shaken, drawn sharp from a
    // large copy of the theme it keeps
    SettingCard {
        title: "SHAKE TO FIND"
        subtitle: page.motionReason

        HyprRow {
            id: shakeRow

            title: "Grow the pointer when you shake it"
            option: "plugin.dynamic_cursors.shake.enabled"
            description: "Shake the pointer and it grows for a moment, so it is easy to find on a busy screen. It stays sharp however large it gets."
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

            title: "How big it grows"
            option: "plugin.dynamic_cursors.shake.base"
            description: "Its size the moment a shake is noticed, as a multiple of the pointer's own. Keep shaking and it grows a little more."
            available: page.motionReady && page.shakeOn
            unavailableReason: page.motionReady ? "Turn growing on to set how it grows." : page.motionReason
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

            title: "How hard to shake"
            option: "plugin.dynamic_cursors.shake.threshold"
            description: "Lower grows on a small shake, higher waits for a big one, so it never grows by accident."
            available: page.motionReady && page.shakeOn
            unavailableReason: page.motionReady ? "Turn growing on to set how it grows." : page.motionReason
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

            title: "Stays big for"
            option: "plugin.dynamic_cursors.shake.timeout"
            description: "How long it stays grown once you stop shaking."
            available: page.motionReady && page.shakeOn
            unavailableReason: page.motionReady ? "Turn growing on to set how it grows." : page.motionReason
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
        title: "THEMES"

        SettingRow {
            title: "Use legacy icons"
            resetKey: "envLegacyIcons"
            description: "Turns off Lucid's own icons, coloured by Matugen from your wallpaper, and uses your GTK icon theme instead: on the desktop, the dock, the launcher, the tray and in Lumen."

            M3Switch {
                checked: Prefs.envLegacyIcons
                onToggled: (v) => {
                    return Prefs.envLegacyIcons = v;
                }
            }

        }

        // lucid's sets while its own icons are on, the gtk themes once they are off
        SettingRow {
            title: "Icon theme"
            resetKey: Prefs.envLegacyIcons ? "" : "envIconSet"
            description: Prefs.envLegacyIcons ? "Used by application menus, file managers and the shell's own dock. The dock follows a change straight away; open applications repaint when they next redraw." : "How Lucid draws files, folders and apps, in your wallpaper's colours. Gravity is lit softly from above; Gravity (Simplified) is the same set in flat tones."
            warning: Prefs.envLegacyIcons && Env.iconMissing ? "“" + Prefs.envIconTheme + "” is not installed on this machine any more." : ""

            M3Button {
                text: Prefs.envLegacyIcons ? page.orUnset(Prefs.envIconTheme) : LucidIcons.nameOf(Prefs.envIconSet)
                variant: "tonal"
                enabled: !Prefs.envLegacyIcons || Env.iconThemes.length > 0
                onClicked: Prefs.envPickerRequested(Prefs.envLegacyIcons ? "icon" : "iconSet")
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
