import QtQuick
import qs

Column {
    id: page

    // every option this page sets, for its reset
    readonly property var lookKeys: ["general.gaps_in", "general.gaps_out", "general.border_size", "general.col.active_border", "lucid.border", "general.col.inactive_border", "lucid.inactive_border", "decoration.rounding", "decoration.rounding_power", "decoration.shadow.enabled", "decoration.shadow.range", "decoration.shadow.render_power", "decoration.dim_inactive", "decoration.dim_strength"]
    readonly property var tilingKeys: ["general.layout", "dwindle.split_width_multiplier", "dwindle.force_split", "dwindle.default_split_ratio", "dwindle.preserve_split", "master.orientation", "master.mfact", "master.new_status", "master.new_on_top", "scrolling.column_width", "scrolling.fullscreen_on_one_column", "lucid.solo"]
    readonly property var behaviourKeys: ["input.follow_mouse", "misc.focus_on_activate", "cursor.no_warps", "cursor.warp_on_change_workspace", "general.resize_on_border", "general.extend_border_grab_area", "general.snap.enabled", "general.snap.window_gap", "general.snap.monitor_gap", "cursor.hide_on_key_press", "cursor.inactive_timeout", "animations.enabled"]
    readonly property var pageKeys: page.lookKeys.concat(page.tilingKeys, page.behaviourKeys)
    readonly property string layout: String(HyprConfig.value("general.layout") || "dwindle")
    // how many windows the layout preview lays out; the preview's own, not a setting
    property int previewCount: 3
    // the inactive border counts as on while your config draws one
    readonly property bool inactiveBorderOn: {
        const c = HyprConfig.choice("lucid.inactive_border");
        if (c !== "")
            return c === "faint";

        return HyprConfig.coloursOf(HyprConfig.live["general.col.inactive_border"]).some((x) => {
            return x.a > 0;
        });
    }

    spacing: Theme.dp(26)
    Component.onCompleted: HyprConfig.refresh()

    SettingCard {
        visible: HyprConfig.moduleProbed && !HyprConfig.moduleInstalled

        SettingRow {
            title: I18n.tr("Not set up")
            warning: I18n.tr("This page writes ~/.config/hypr/lucid-settings.lua, and your Hyprland config does not read it. Run the installer with --with-hypr, or copy Lucid's modules/settings.lua into ~/.config/hypr/modules/ and add require(\"modules.settings\") to hyprland.lua, before anything of your own.")
            showDivider: false
        }

    }

    WindowsPreview {
        width: parent.width
    }

    SettingCard {
        title: I18n.tr("GAPS")
        subtitle: I18n.tr("Changes apply as you make them. Anything you leave alone stays as your Hyprland config has it.")

        HyprRow {
            id: gapsIn

            title: I18n.tr("Between windows")
            option: "general.gaps_in"
            description: I18n.tr("Each window keeps this much room on every side, so two neighbours sit twice this far apart.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: gapsIn.enabled
                from: 0
                to: 40
                stepSize: 1
                suffix: " px"
                value: HyprConfig.num("general.gaps_in", 5)
                onMoved: (v) => {
                    return HyprConfig.set("general.gaps_in", Math.round(v));
                }
            }

        }

        HyprRow {
            id: gapsOut

            title: I18n.tr("Around the edges")
            option: "general.gaps_out"
            description: I18n.tr("Room between the windows and the edges of the screen.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: gapsOut.enabled
                from: 0
                to: 80
                stepSize: 1
                suffix: " px"
                value: HyprConfig.num("general.gaps_out", 20)
                onMoved: (v) => {
                    return HyprConfig.set("general.gaps_out", Math.round(v));
                }
            }

        }

        SettingRow {
            title: I18n.tr("From the bar and dock")
            resetKey: "shellGap"
            description: I18n.tr("Extra room the bar and dock keep clear of windows, on top of the gap around the edges.")
            stacked: true
            showDivider: false

            M3Slider {
                width: parent.width
                from: 0
                to: 60
                stepSize: 1
                suffix: " px"
                value: Prefs.shellGap
                onMoved: (v) => {
                    return Prefs.shellGap = Math.round(v);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("BORDERS")

        HyprRow {
            id: borderSize

            title: I18n.tr("Border width")
            option: "general.border_size"
            description: I18n.tr("The line around each window. At 0 there is none.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: borderSize.enabled
                from: 0
                to: 10
                stepSize: 1
                suffix: " px"
                value: HyprConfig.num("general.border_size", 2)
                onMoved: (v) => {
                    return HyprConfig.set("general.border_size", Math.round(v));
                }
            }

        }

        HyprRow {
            id: borderColour

            title: I18n.tr("Border colour")
            option: "general.col.active_border"
            extraKeys: ["lucid.border"]
            description: HyprConfig.borderMode() === "" ? I18n.tr("The window you are in. Right now your Hyprland config picks the colour; these follow your palette and change with it.") : I18n.tr("The window you are in. Accent is your palette's main colour, and the gradient runs through three of its colours.")
            available: HyprConfig.num("general.border_size", 2) > 0
            unavailableReason: I18n.tr("There is no border to colour at 0 px.")
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(360))
                enabled: borderColour.enabled
                current: HyprConfig.borderMode()
                options: HyprConfig.borderModes
                onChosen: (key) => {
                    return HyprConfig.set("lucid.border", key);
                }
            }

        }

        HyprRow {
            id: inactiveBorder

            title: I18n.tr("Border on other windows")
            option: "general.col.inactive_border"
            extraKeys: ["lucid.inactive_border"]
            description: I18n.tr("A faint line, in your palette's outline colour, around the windows you are not in.")
            available: HyprConfig.num("general.border_size", 2) > 0
            unavailableReason: I18n.tr("There is no border to colour at 0 px.")
            showDivider: false

            M3Switch {
                enabled: inactiveBorder.enabled
                checked: page.inactiveBorderOn
                onToggled: (v) => {
                    return HyprConfig.set("lucid.inactive_border", v ? "faint" : "none");
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("PINNED WINDOWS")
        subtitle: I18n.tr("A pinned window floats over the rest and follows you to every workspace. These make it easy to tell which one it is.")

        SettingRow {
            title: I18n.tr("Border")
            description: Prefs.pinBorder === "off" ? I18n.tr("A pinned window wears the same border as any other.") : I18n.tr("A border of its own, from your palette, so it reads as pinned even when you are in another window.")
            resetKey: "pinBorder"
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(420))
                current: Prefs.pinBorder
                options: HyprConfig.pinModes
                onChosen: (key) => {
                    Prefs.pinBorder = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Pin badge")
            description: Prefs.pinBadge === "off" ? I18n.tr("No badge.") : I18n.tr("A small tab with a pin, tucked into that corner of the window in the border's colour. Click it to unpin. It steps away while the window moves and comes back once it stops.")
            resetKey: "pinBadge"
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(520))
                current: Prefs.pinBadge
                options: [{
                    "key": "off",
                    "label": I18n.tr("Off")
                }, {
                    "key": "top-left",
                    "label": I18n.tr("Top left")
                }, {
                    "key": "top-right",
                    "label": I18n.tr("Top right")
                }, {
                    "key": "bottom-left",
                    "label": I18n.tr("Bottom left")
                }, {
                    "key": "bottom-right",
                    "label": I18n.tr("Bottom right")
                }]
                onChosen: (key) => {
                    Prefs.pinBadge = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Ripple when pinned")
            description: I18n.tr("A ring spreads out from the window the moment you pin it.")
            resetKey: "pinPulse"
            showDivider: false

            M3Switch {
                checked: Prefs.pinPulse
                onToggled: (v) => {
                    Prefs.pinPulse = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("WINDOWS ASKING FOR ATTENTION")
        subtitle: I18n.tr("A window that wants you (a message come in, a download done, a terminal's bell) lights its workspace up in the bar. These mark the window itself once you are there.")

        SettingRow {
            title: I18n.tr("Attention tab")
            description: Prefs.urgentBadge === "off" ? I18n.tr("No tab.") : I18n.tr("A tab with a bell in that corner of the window, in the colour the bar gives it. Click it to go to the window; it goes away once you do.")
            resetKey: "urgentBadge"
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(520))
                current: Prefs.urgentBadge
                options: [{
                    "key": "off",
                    "label": I18n.tr("Off")
                }, {
                    "key": "top-left",
                    "label": I18n.tr("Top left")
                }, {
                    "key": "top-right",
                    "label": I18n.tr("Top right")
                }, {
                    "key": "bottom-left",
                    "label": I18n.tr("Bottom left")
                }, {
                    "key": "bottom-right",
                    "label": I18n.tr("Bottom right")
                }]
                onChosen: (key) => {
                    Prefs.urgentBadge = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Ripple when it asks")
            description: I18n.tr("Rings spread out from the window the first time you see it asking.")
            resetKey: "urgentPulse"
            showDivider: false

            M3Switch {
                checked: Prefs.urgentPulse
                onToggled: (v) => {
                    Prefs.urgentPulse = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("CORNERS")

        HyprRow {
            id: rounding

            title: I18n.tr("Window corners")
            option: "decoration.rounding"
            description: I18n.tr("How round each window's corners are. This is the windows only; the shell has its own on the General page.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: rounding.enabled
                from: 0
                to: 30
                stepSize: 1
                suffix: " px"
                value: HyprConfig.num("decoration.rounding", 10)
                onMoved: (v) => {
                    return HyprConfig.set("decoration.rounding", Math.round(v));
                }
            }

        }

        HyprRow {
            id: roundingPower

            title: I18n.tr("Corner shape")
            option: "decoration.rounding_power"
            description: I18n.tr("2 is a plain round corner. Higher flattens it into the smoother curve of a squircle.")
            available: HyprConfig.num("decoration.rounding", 10) > 0
            unavailableReason: I18n.tr("The corners are square at 0 px.")
            stacked: true
            showDivider: false

            M3Slider {
                width: parent.width
                enabled: roundingPower.enabled
                from: 1
                to: 10
                stepSize: 0.5
                decimals: 1
                value: HyprConfig.num("decoration.rounding_power", 2)
                onMoved: (v) => {
                    return HyprConfig.set("decoration.rounding_power", Math.round(v * 2) / 2);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("SHADOW")

        HyprRow {
            id: shadowOn

            title: I18n.tr("Shadow")
            option: "decoration.shadow.enabled"
            description: I18n.tr("A soft shadow under each window.")

            M3Switch {
                enabled: shadowOn.enabled
                checked: HyprConfig.bool("decoration.shadow.enabled", false)
                onToggled: (v) => {
                    return HyprConfig.set("decoration.shadow.enabled", v);
                }
            }

        }

        HyprRow {
            id: shadowRange

            title: I18n.tr("Shadow size")
            option: "decoration.shadow.range"
            description: I18n.tr("How far it spreads from the window.")
            available: HyprConfig.bool("decoration.shadow.enabled", false)
            unavailableReason: I18n.tr("The shadow is off.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: shadowRange.enabled
                from: 1
                to: 60
                stepSize: 1
                suffix: " px"
                value: HyprConfig.num("decoration.shadow.range", 20)
                onMoved: (v) => {
                    return HyprConfig.set("decoration.shadow.range", Math.round(v));
                }
            }

        }

        HyprRow {
            id: shadowPower

            title: I18n.tr("Shadow falloff")
            option: "decoration.shadow.render_power"
            description: I18n.tr("1 fades out slowly and reads soft; 4 stays dark close to the window and ends sharply.")
            available: HyprConfig.bool("decoration.shadow.enabled", false)
            unavailableReason: I18n.tr("The shadow is off.")
            stacked: true
            showDivider: false

            M3Slider {
                width: parent.width
                enabled: shadowPower.enabled
                from: 1
                to: 4
                stepSize: 1
                value: HyprConfig.num("decoration.shadow.render_power", 3)
                onMoved: (v) => {
                    return HyprConfig.set("decoration.shadow.render_power", Math.round(v));
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("DIMMING")

        HyprRow {
            id: dimOn

            title: I18n.tr("Dim other windows")
            option: "decoration.dim_inactive"
            description: I18n.tr("Darken every window but the one you are in, so it stands out.")

            M3Switch {
                enabled: dimOn.enabled
                checked: HyprConfig.bool("decoration.dim_inactive", false)
                onToggled: (v) => {
                    return HyprConfig.set("decoration.dim_inactive", v);
                }
            }

        }

        HyprRow {
            id: dimStrength

            title: I18n.tr("How much")
            option: "decoration.dim_strength"
            description: I18n.tr("How dark the other windows get.")
            available: HyprConfig.bool("decoration.dim_inactive", false)
            unavailableReason: I18n.tr("Dimming is off.")
            stacked: true
            showDivider: false

            M3Slider {
                width: parent.width
                enabled: dimStrength.enabled
                from: 5
                to: 80
                stepSize: 5
                suffix: "%"
                value: Math.round(HyprConfig.num("decoration.dim_strength", 0.5) * 100)
                onMoved: (v) => {
                    return HyprConfig.set("decoration.dim_strength", Math.round(v) / 100);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("TILING")
        subtitle: I18n.tr("Where a new window goes and how the space is shared out.")

        SettingRow {
            title: I18n.tr("Preview")
            description: I18n.tr("Your layout with this many windows open, each new one opened from the one before.")
            stacked: true

            Column {
                width: parent.width
                spacing: Theme.dp(14)

                M3Segmented {
                    width: Math.min(parent.width, Theme.dp(300))
                    current: page.previewCount
                    options: [1, 2, 3, 4, 5].map((n) => {
                        return {
                            "key": n,
                            "label": String(n)
                        };
                    })
                    onChosen: (key) => {
                        return page.previewCount = key;
                    }
                }

                WindowsPreview {
                    width: parent.width
                    count: page.previewCount
                    viewFraction: 1
                    newestActive: true
                }

            }

        }

        HyprRow {
            id: layoutRow

            title: I18n.tr("Layout")
            option: "general.layout"
            description: page.layout === "master" ? I18n.tr("Master: one main window, and the rest in a stack beside it.") : (page.layout === "scrolling" ? I18n.tr("Scrolling: windows as columns on a strip that scrolls sideways, so opening one never squeezes the rest.") : I18n.tr("Dwindle: every new window splits the one you are in, in half."))
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(360))
                enabled: layoutRow.enabled
                current: page.layout
                options: [{
                    "key": "dwindle",
                    "label": I18n.tr("Dwindle")
                }, {
                    "key": "master",
                    "label": I18n.tr("Master")
                }, {
                    "key": "scrolling",
                    "label": I18n.tr("Scrolling")
                }]
                onChosen: (key) => {
                    return HyprConfig.set("general.layout", key);
                }
            }

        }

        HyprRow {
            id: splitWidth

            visible: page.layout === "dwindle"
            title: I18n.tr("Split direction")
            option: "dwindle.split_width_multiplier"
            description: I18n.tr("A space is split side by side while it is wider than its height times this, and top to bottom otherwise. At 1 a wide screen splits into halves and each half into landscape quarters; lower keeps splitting side by side, higher stacks sooner.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: splitWidth.enabled
                from: 0.5
                to: 2
                stepSize: 0.1
                decimals: 1
                value: HyprConfig.num("dwindle.split_width_multiplier", 1)
                onMoved: (v) => {
                    return HyprConfig.set("dwindle.split_width_multiplier", Math.round(v * 10) / 10);
                }
            }

        }

        HyprRow {
            id: forceSplit

            visible: page.layout === "dwindle"
            title: I18n.tr("New windows go")
            option: "dwindle.force_split"
            description: I18n.tr("Which side of the split a new window takes.")
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(420))
                enabled: forceSplit.enabled
                current: HyprConfig.num("dwindle.force_split", 0)
                options: [{
                    "key": 0,
                    "label": I18n.tr("By the cursor")
                }, {
                    "key": 1,
                    "label": I18n.tr("Left or top")
                }, {
                    "key": 2,
                    "label": I18n.tr("Right or bottom")
                }]
                onChosen: (key) => {
                    return HyprConfig.set("dwindle.force_split", key);
                }
            }

        }

        HyprRow {
            id: splitRatio

            visible: page.layout === "dwindle"
            title: I18n.tr("Split size")
            option: "dwindle.default_split_ratio"
            description: I18n.tr("How much of a split the first window keeps. At 50% both halves are even.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: splitRatio.enabled
                from: 20
                to: 80
                stepSize: 5
                suffix: "%"
                value: Math.round(HyprConfig.num("dwindle.default_split_ratio", 1) * 50)
                onMoved: (v) => {
                    return HyprConfig.set("dwindle.default_split_ratio", Math.round(v) / 50);
                }
            }

        }

        HyprRow {
            id: preserveSplit

            visible: page.layout === "dwindle"
            title: I18n.tr("Keep splits")
            option: "dwindle.preserve_split"
            description: I18n.tr("A split keeps its direction when the windows around it change, instead of being worked out again from its shape.")

            M3Switch {
                enabled: preserveSplit.enabled
                checked: HyprConfig.bool("dwindle.preserve_split", false)
                onToggled: (v) => {
                    return HyprConfig.set("dwindle.preserve_split", v);
                }
            }

        }

        HyprRow {
            id: masterSide

            visible: page.layout === "master"
            title: I18n.tr("Master side")
            option: "master.orientation"
            description: I18n.tr("Where the main window sits. In the centre the stack is shared out to both sides.")
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(460))
                enabled: masterSide.enabled
                current: String(HyprConfig.value("master.orientation") || "left")
                options: [{
                    "key": "left",
                    "label": I18n.tr("Left")
                }, {
                    "key": "right",
                    "label": I18n.tr("Right")
                }, {
                    "key": "top",
                    "label": I18n.tr("Top")
                }, {
                    "key": "bottom",
                    "label": I18n.tr("Bottom")
                }, {
                    "key": "center",
                    "label": I18n.tr("Centre")
                }]
                onChosen: (key) => {
                    return HyprConfig.set("master.orientation", key);
                }
            }

        }

        HyprRow {
            id: masterSize

            visible: page.layout === "master"
            title: I18n.tr("Master size")
            option: "master.mfact"
            description: I18n.tr("How much of the screen the main window takes.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: masterSize.enabled
                from: 20
                to: 80
                stepSize: 5
                suffix: "%"
                value: Math.round(HyprConfig.num("master.mfact", 0.55) * 100)
                onMoved: (v) => {
                    return HyprConfig.set("master.mfact", Math.round(v) / 100);
                }
            }

        }

        HyprRow {
            id: newStatus

            visible: page.layout === "master"
            title: I18n.tr("A new window")
            option: "master.new_status"
            description: I18n.tr("Takes over as the main window, joins the stack, or does what the window you are in does.")
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(420))
                enabled: newStatus.enabled
                current: String(HyprConfig.value("master.new_status") || "slave")
                options: [{
                    "key": "master",
                    "label": I18n.tr("Becomes main")
                }, {
                    "key": "slave",
                    "label": I18n.tr("Joins the stack")
                }, {
                    "key": "inherit",
                    "label": I18n.tr("Like this one")
                }]
                onChosen: (key) => {
                    return HyprConfig.set("master.new_status", key);
                }
            }

        }

        HyprRow {
            id: newOnTop

            visible: page.layout === "master"
            title: I18n.tr("New at the top of the stack")
            option: "master.new_on_top"
            description: I18n.tr("A window joining the stack goes first instead of last.")

            M3Switch {
                enabled: newOnTop.enabled
                checked: HyprConfig.bool("master.new_on_top", false)
                onToggled: (v) => {
                    return HyprConfig.set("master.new_on_top", v);
                }
            }

        }

        HyprRow {
            id: columnWidth

            visible: page.layout === "scrolling"
            title: I18n.tr("Column width")
            option: "scrolling.column_width"
            description: I18n.tr("How much of the screen a new column takes.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: columnWidth.enabled
                from: 20
                to: 100
                stepSize: 5
                suffix: "%"
                value: Math.round(HyprConfig.num("scrolling.column_width", 0.5) * 100)
                onMoved: (v) => {
                    return HyprConfig.set("scrolling.column_width", Math.round(v) / 100);
                }
            }

        }

        HyprRow {
            id: oneColumn

            visible: page.layout === "scrolling"
            title: I18n.tr("A single column fills the screen")
            option: "scrolling.fullscreen_on_one_column"
            description: I18n.tr("With only one window open, it takes the whole width.")

            M3Switch {
                enabled: oneColumn.enabled
                checked: HyprConfig.bool("scrolling.fullscreen_on_one_column", true)
                onToggled: (v) => {
                    return HyprConfig.set("scrolling.fullscreen_on_one_column", v);
                }
            }

        }

        HyprRow {
            id: solo

            title: I18n.tr("A lone window goes edge to edge")
            option: "lucid.solo"
            description: I18n.tr("When a window is the only one on its workspace, or maximised, it drops the gaps, the border and the rounded corners.")
            showDivider: false

            M3Switch {
                enabled: solo.enabled
                checked: HyprConfig.choice("lucid.solo") === true
                onToggled: (v) => {
                    if (v)
                        HyprConfig.set("lucid.solo", true);
                    else
                        HyprConfig.resetKeys(["lucid.solo"]);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("FOCUS")

        HyprRow {
            id: followMouse

            title: I18n.tr("A window takes the focus")
            option: "input.follow_mouse"
            description: HyprConfig.num("input.follow_mouse", 1) === 2 ? I18n.tr("The window under the cursor scrolls and takes clicks, but your typing stays where you clicked last.") : (HyprConfig.num("input.follow_mouse", 1) === 0 ? I18n.tr("Moving the cursor changes nothing; a window takes the focus when you click it.") : I18n.tr("Moving the cursor onto a window gives it the focus."))
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, Theme.dp(480))
                enabled: followMouse.enabled
                current: HyprConfig.num("input.follow_mouse", 1)
                options: [{
                    "key": 0,
                    "label": I18n.tr("On click")
                }, {
                    "key": 1,
                    "label": I18n.tr("On hover")
                }, {
                    "key": 2,
                    "label": I18n.tr("Hover, typing on click")
                }]
                onChosen: (key) => {
                    return HyprConfig.set("input.follow_mouse", key);
                }
            }

        }

        HyprRow {
            id: focusOnActivate

            title: I18n.tr("Apps can take the focus")
            option: "misc.focus_on_activate"
            description: I18n.tr("When an app asks to be brought forward — a link opened in the browser, say — it gets the focus. Off, it only asks for your attention.")

            M3Switch {
                enabled: focusOnActivate.enabled
                checked: HyprConfig.bool("misc.focus_on_activate", false)
                onToggled: (v) => {
                    return HyprConfig.set("misc.focus_on_activate", v);
                }
            }

        }

        HyprRow {
            id: warps

            title: I18n.tr("The cursor follows the focus")
            option: "cursor.no_warps"
            description: I18n.tr("When a key moves the focus to another window, the cursor jumps into it.")

            M3Switch {
                enabled: warps.enabled
                checked: !HyprConfig.bool("cursor.no_warps", false)
                onToggled: (v) => {
                    return HyprConfig.set("cursor.no_warps", !v);
                }
            }

        }

        HyprRow {
            id: warpWorkspace

            title: I18n.tr("Also when switching workspace")
            option: "cursor.warp_on_change_workspace"
            description: I18n.tr("Switching workspace puts the cursor back on the window you were last in there.")
            available: !HyprConfig.bool("cursor.no_warps", false)
            unavailableReason: I18n.tr("The cursor stays put while it does not follow the focus.")
            showDivider: false

            M3Switch {
                enabled: warpWorkspace.enabled
                checked: HyprConfig.num("cursor.warp_on_change_workspace", 0) > 0
                onToggled: (v) => {
                    return HyprConfig.set("cursor.warp_on_change_workspace", v ? 1 : 0);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("MOVING AND RESIZING")

        HyprRow {
            id: resizeBorder

            title: I18n.tr("Resize by the edges")
            option: "general.resize_on_border"
            description: I18n.tr("Drag a window's edge or corner to resize it, with no key held.")

            M3Switch {
                enabled: resizeBorder.enabled
                checked: HyprConfig.bool("general.resize_on_border", false)
                onToggled: (v) => {
                    return HyprConfig.set("general.resize_on_border", v);
                }
            }

        }

        HyprRow {
            id: grabArea

            title: I18n.tr("Grab area")
            option: "general.extend_border_grab_area"
            description: I18n.tr("How far outside the window an edge can still be caught.")
            available: HyprConfig.bool("general.resize_on_border", false)
            unavailableReason: I18n.tr("Resizing by the edges is off.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: grabArea.enabled
                from: 0
                to: 40
                stepSize: 1
                suffix: " px"
                value: HyprConfig.num("general.extend_border_grab_area", 15)
                onMoved: (v) => {
                    return HyprConfig.set("general.extend_border_grab_area", Math.round(v));
                }
            }

        }

        HyprRow {
            id: snapOn

            title: I18n.tr("Snap floating windows")
            option: "general.snap.enabled"
            description: I18n.tr("A floating window you drag clicks into place against the other windows and the edges of the screen.")

            M3Switch {
                enabled: snapOn.enabled
                checked: HyprConfig.bool("general.snap.enabled", false)
                onToggled: (v) => {
                    return HyprConfig.set("general.snap.enabled", v);
                }
            }

        }

        HyprRow {
            id: snapWindows

            title: I18n.tr("Snap to windows from")
            option: "general.snap.window_gap"
            available: HyprConfig.bool("general.snap.enabled", false)
            unavailableReason: I18n.tr("Snapping is off.")
            description: I18n.tr("How close to another window it has to come.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: snapWindows.enabled
                from: 0
                to: 50
                stepSize: 1
                suffix: " px"
                value: HyprConfig.num("general.snap.window_gap", 10)
                onMoved: (v) => {
                    return HyprConfig.set("general.snap.window_gap", Math.round(v));
                }
            }

        }

        HyprRow {
            id: snapScreen

            title: I18n.tr("Snap to the screen from")
            option: "general.snap.monitor_gap"
            available: HyprConfig.bool("general.snap.enabled", false)
            unavailableReason: I18n.tr("Snapping is off.")
            description: I18n.tr("How close to an edge of the screen it has to come.")
            stacked: true
            showDivider: false

            M3Slider {
                width: parent.width
                enabled: snapScreen.enabled
                from: 0
                to: 50
                stepSize: 1
                suffix: " px"
                value: HyprConfig.num("general.snap.monitor_gap", 10)
                onMoved: (v) => {
                    return HyprConfig.set("general.snap.monitor_gap", Math.round(v));
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("CURSOR AND MOTION")

        HyprRow {
            id: hideTyping

            title: I18n.tr("Hide the cursor while typing")
            option: "cursor.hide_on_key_press"
            description: I18n.tr("It comes back as soon as the mouse moves.")

            M3Switch {
                enabled: hideTyping.enabled
                checked: HyprConfig.bool("cursor.hide_on_key_press", false)
                onToggled: (v) => {
                    return HyprConfig.set("cursor.hide_on_key_press", v);
                }
            }

        }

        HyprRow {
            id: idleCursor

            title: I18n.tr("Hide an idle cursor after")
            option: "cursor.inactive_timeout"
            description: I18n.tr("A cursor left still disappears after this long. At 0 it never does.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: idleCursor.enabled
                from: 0
                to: 30
                stepSize: 1
                suffix: " s"
                value: HyprConfig.num("cursor.inactive_timeout", 0)
                onMoved: (v) => {
                    return HyprConfig.set("cursor.inactive_timeout", Math.round(v));
                }
            }

        }

        HyprRow {
            id: animationsOn

            title: I18n.tr("Window animations")
            option: "animations.enabled"
            description: I18n.tr("Windows and workspaces slide and fade as they open, close and change. Off, everything is instant. The shell's own motion is on the General page.")
            showDivider: false

            M3Switch {
                enabled: animationsOn.enabled
                checked: HyprConfig.bool("animations.enabled", true)
                onToggled: (v) => {
                    return HyprConfig.set("animations.enabled", v);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("RESET")

        SettingRow {
            title: I18n.tr("Hand it all back to your config")
            description: I18n.tr("Everything on this page goes back to whatever your Hyprland config sets, as if Settings had never touched it.")
            showDivider: false

            M3Button {
                text: I18n.tr("Reset")
                variant: "text"
                destructive: true
                enabled: page.pageKeys.some((k) => {
                    return HyprConfig.isMine(k);
                })
                onClicked: Prefs.askReset("Reset windows?", "Everything on this page goes back to whatever your Hyprland config sets.", "hypr:" + page.pageKeys.join(","))
            }

        }

    }

}
