import QtQuick
import qs

Column {
    id: page

    // every option this page sets, for its reset
    readonly property var lookKeys: ["general.gaps_in", "general.gaps_out", "general.border_size", "general.col.active_border", "lucid.border", "general.col.inactive_border", "lucid.inactive_border", "decoration.rounding", "decoration.rounding_power", "decoration.shadow.enabled", "decoration.shadow.range", "decoration.shadow.render_power", "decoration.dim_inactive", "decoration.dim_strength"]
    readonly property var tilingKeys: ["general.layout", "dwindle.split_width_multiplier", "dwindle.force_split", "dwindle.default_split_ratio", "dwindle.preserve_split", "master.orientation", "master.mfact", "master.new_status", "master.new_on_top", "scrolling.column_width", "scrolling.fullscreen_on_one_column", "lucid.solo"]
    readonly property var pageKeys: page.lookKeys.concat(page.tilingKeys)
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
