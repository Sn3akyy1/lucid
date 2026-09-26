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

    spacing: 26
    Component.onCompleted: HyprConfig.refresh()

    SettingCard {
        visible: HyprConfig.moduleProbed && !HyprConfig.moduleInstalled

        SettingRow {
            title: "Not set up"
            warning: "This page writes ~/.config/hypr/lucid-settings.lua, and your Hyprland config does not read it. Run the installer with --with-hypr, or copy Lucid's modules/settings.lua into ~/.config/hypr/modules/ and add require(\"modules.settings\") to hyprland.lua, before anything of your own."
            showDivider: false
        }

    }

    WindowsPreview {
        width: parent.width
    }

    SettingCard {
        title: "GAPS"
        subtitle: "Changes apply as you make them. Anything you leave alone stays as your Hyprland config has it."

        HyprRow {
            id: gapsIn

            title: "Between windows"
            option: "general.gaps_in"
            description: "Each window keeps this much room on every side, so two neighbours sit twice this far apart."
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

            title: "Around the edges"
            option: "general.gaps_out"
            description: "Room between the windows and the edges of the screen."
            stacked: true
            showDivider: false

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

    }

    SettingCard {
        title: "BORDERS"

        HyprRow {
            id: borderSize

            title: "Border width"
            option: "general.border_size"
            description: "The line around each window. At 0 there is none."
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

            title: "Border colour"
            option: "general.col.active_border"
            extraKeys: ["lucid.border"]
            description: HyprConfig.choice("lucid.border") === "" ? "The window you are in. Right now your Hyprland config picks the colour; these follow your palette and change with it." : "The window you are in. Accent is your palette's main colour, and the gradient runs through three of its colours."
            available: HyprConfig.num("general.border_size", 2) > 0
            unavailableReason: "There is no border to colour at 0 px."
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, 360)
                enabled: borderColour.enabled
                current: HyprConfig.choice("lucid.border")
                options: HyprConfig.borderModes
                onChosen: (key) => {
                    return HyprConfig.set("lucid.border", key);
                }
            }

        }

        HyprRow {
            id: inactiveBorder

            title: "Border on other windows"
            option: "general.col.inactive_border"
            extraKeys: ["lucid.inactive_border"]
            description: "A faint line, in your palette's outline colour, around the windows you are not in."
            available: HyprConfig.num("general.border_size", 2) > 0
            unavailableReason: "There is no border to colour at 0 px."
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
        title: "CORNERS"

        HyprRow {
            id: rounding

            title: "Window corners"
            option: "decoration.rounding"
            description: "How round each window's corners are. This is the windows only; the shell has its own on the General page."
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

            title: "Corner shape"
            option: "decoration.rounding_power"
            description: "2 is a plain round corner. Higher flattens it into the smoother curve of a squircle."
            available: HyprConfig.num("decoration.rounding", 10) > 0
            unavailableReason: "The corners are square at 0 px."
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
        title: "SHADOW"

        HyprRow {
            id: shadowOn

            title: "Shadow"
            option: "decoration.shadow.enabled"
            description: "A soft shadow under each window."

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

            title: "Shadow size"
            option: "decoration.shadow.range"
            description: "How far it spreads from the window."
            available: HyprConfig.bool("decoration.shadow.enabled", false)
            unavailableReason: "The shadow is off."
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

            title: "Shadow falloff"
            option: "decoration.shadow.render_power"
            description: "1 fades out slowly and reads soft; 4 stays dark close to the window and ends sharply."
            available: HyprConfig.bool("decoration.shadow.enabled", false)
            unavailableReason: "The shadow is off."
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
        title: "DIMMING"

        HyprRow {
            id: dimOn

            title: "Dim other windows"
            option: "decoration.dim_inactive"
            description: "Darken every window but the one you are in, so it stands out."

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

            title: "How much"
            option: "decoration.dim_strength"
            description: "How dark the other windows get."
            available: HyprConfig.bool("decoration.dim_inactive", false)
            unavailableReason: "Dimming is off."
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
        title: "TILING"
        subtitle: "Where a new window goes and how the space is shared out."

        SettingRow {
            title: "Preview"
            description: "Your layout with this many windows open, each new one opened from the one before."
            stacked: true

            Column {
                width: parent.width
                spacing: 14

                M3Segmented {
                    width: Math.min(parent.width, 300)
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

            title: "Layout"
            option: "general.layout"
            description: page.layout === "master" ? "Master: one main window, and the rest in a stack beside it." : (page.layout === "scrolling" ? "Scrolling: windows as columns on a strip that scrolls sideways, so opening one never squeezes the rest." : "Dwindle: every new window splits the one you are in, in half.")
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, 360)
                enabled: layoutRow.enabled
                current: page.layout
                options: [{
                    "key": "dwindle",
                    "label": "Dwindle"
                }, {
                    "key": "master",
                    "label": "Master"
                }, {
                    "key": "scrolling",
                    "label": "Scrolling"
                }]
                onChosen: (key) => {
                    return HyprConfig.set("general.layout", key);
                }
            }

        }

        HyprRow {
            id: splitWidth

            visible: page.layout === "dwindle"
            title: "Split direction"
            option: "dwindle.split_width_multiplier"
            description: "A space is split side by side while it is wider than its height times this, and top to bottom otherwise. At 1 a wide screen splits into halves and each half into landscape quarters; lower keeps splitting side by side, higher stacks sooner."
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
            title: "New windows go"
            option: "dwindle.force_split"
            description: "Which side of the split a new window takes."
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, 420)
                enabled: forceSplit.enabled
                current: HyprConfig.num("dwindle.force_split", 0)
                options: [{
                    "key": 0,
                    "label": "By the cursor"
                }, {
                    "key": 1,
                    "label": "Left or top"
                }, {
                    "key": 2,
                    "label": "Right or bottom"
                }]
                onChosen: (key) => {
                    return HyprConfig.set("dwindle.force_split", key);
                }
            }

        }

        HyprRow {
            id: splitRatio

            visible: page.layout === "dwindle"
            title: "Split size"
            option: "dwindle.default_split_ratio"
            description: "How much of a split the first window keeps. At 50% both halves are even."
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
            title: "Keep splits"
            option: "dwindle.preserve_split"
            description: "A split keeps its direction when the windows around it change, instead of being worked out again from its shape."

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
            title: "Master side"
            option: "master.orientation"
            description: "Where the main window sits. In the centre the stack is shared out to both sides."
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, 460)
                enabled: masterSide.enabled
                current: String(HyprConfig.value("master.orientation") || "left")
                options: [{
                    "key": "left",
                    "label": "Left"
                }, {
                    "key": "right",
                    "label": "Right"
                }, {
                    "key": "top",
                    "label": "Top"
                }, {
                    "key": "bottom",
                    "label": "Bottom"
                }, {
                    "key": "center",
                    "label": "Centre"
                }]
                onChosen: (key) => {
                    return HyprConfig.set("master.orientation", key);
                }
            }

        }

        HyprRow {
            id: masterSize

            visible: page.layout === "master"
            title: "Master size"
            option: "master.mfact"
            description: "How much of the screen the main window takes."
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
            title: "A new window"
            option: "master.new_status"
            description: "Takes over as the main window, joins the stack, or does what the window you are in does."
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, 420)
                enabled: newStatus.enabled
                current: String(HyprConfig.value("master.new_status") || "slave")
                options: [{
                    "key": "master",
                    "label": "Becomes main"
                }, {
                    "key": "slave",
                    "label": "Joins the stack"
                }, {
                    "key": "inherit",
                    "label": "Like this one"
                }]
                onChosen: (key) => {
                    return HyprConfig.set("master.new_status", key);
                }
            }

        }

        HyprRow {
            id: newOnTop

            visible: page.layout === "master"
            title: "New at the top of the stack"
            option: "master.new_on_top"
            description: "A window joining the stack goes first instead of last."

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
            title: "Column width"
            option: "scrolling.column_width"
            description: "How much of the screen a new column takes."
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
            title: "A single column fills the screen"
            option: "scrolling.fullscreen_on_one_column"
            description: "With only one window open, it takes the whole width."

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

            title: "A lone window goes edge to edge"
            option: "lucid.solo"
            description: "When a window is the only one on its workspace, or maximised, it drops the gaps, the border and the rounded corners."
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
        title: "FOCUS"

        HyprRow {
            id: followMouse

            title: "A window takes the focus"
            option: "input.follow_mouse"
            description: HyprConfig.num("input.follow_mouse", 1) === 2 ? "The window under the cursor scrolls and takes clicks, but your typing stays where you clicked last." : (HyprConfig.num("input.follow_mouse", 1) === 0 ? "Moving the cursor changes nothing; a window takes the focus when you click it." : "Moving the cursor onto a window gives it the focus.")
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, 480)
                enabled: followMouse.enabled
                current: HyprConfig.num("input.follow_mouse", 1)
                options: [{
                    "key": 0,
                    "label": "On click"
                }, {
                    "key": 1,
                    "label": "On hover"
                }, {
                    "key": 2,
                    "label": "Hover, typing on click"
                }]
                onChosen: (key) => {
                    return HyprConfig.set("input.follow_mouse", key);
                }
            }

        }

        HyprRow {
            id: focusOnActivate

            title: "Apps can take the focus"
            option: "misc.focus_on_activate"
            description: "When an app asks to be brought forward — a link opened in the browser, say — it gets the focus. Off, it only asks for your attention."

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

            title: "The cursor follows the focus"
            option: "cursor.no_warps"
            description: "When a key moves the focus to another window, the cursor jumps into it."

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

            title: "Also when switching workspace"
            option: "cursor.warp_on_change_workspace"
            description: "Switching workspace puts the cursor back on the window you were last in there."
            available: !HyprConfig.bool("cursor.no_warps", false)
            unavailableReason: "The cursor stays put while it does not follow the focus."
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
        title: "MOVING AND RESIZING"

        HyprRow {
            id: resizeBorder

            title: "Resize by the edges"
            option: "general.resize_on_border"
            description: "Drag a window's edge or corner to resize it, with no key held."

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

            title: "Grab area"
            option: "general.extend_border_grab_area"
            description: "How far outside the window an edge can still be caught."
            available: HyprConfig.bool("general.resize_on_border", false)
            unavailableReason: "Resizing by the edges is off."
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

            title: "Snap floating windows"
            option: "general.snap.enabled"
            description: "A floating window you drag clicks into place against the other windows and the edges of the screen."

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

            title: "Snap to windows from"
            option: "general.snap.window_gap"
            available: HyprConfig.bool("general.snap.enabled", false)
            unavailableReason: "Snapping is off."
            description: "How close to another window it has to come."
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

            title: "Snap to the screen from"
            option: "general.snap.monitor_gap"
            available: HyprConfig.bool("general.snap.enabled", false)
            unavailableReason: "Snapping is off."
            description: "How close to an edge of the screen it has to come."
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
        title: "CURSOR AND MOTION"

        HyprRow {
            id: hideTyping

            title: "Hide the cursor while typing"
            option: "cursor.hide_on_key_press"
            description: "It comes back as soon as the mouse moves."

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

            title: "Hide an idle cursor after"
            option: "cursor.inactive_timeout"
            description: "A cursor left still disappears after this long. At 0 it never does."
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

            title: "Window animations"
            option: "animations.enabled"
            description: "Windows and workspaces slide and fade as they open, close and change. Off, everything is instant. The shell's own motion is on the General page."
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
        title: "RESET"

        SettingRow {
            title: "Hand it all back to your config"
            description: "Everything on this page goes back to whatever your Hyprland config sets, as if Settings had never touched it."
            showDivider: false

            M3Button {
                text: "Reset"
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
