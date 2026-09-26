import QtQuick
import Quickshell.Io
import qs

Column {
    id: page

    readonly property var keyboardKeys: ["input.kb_layout", "input.kb_variant", "input.kb_options", "input.repeat_rate", "input.repeat_delay", "input.numlock_by_default"]
    readonly property var pointerKeys: ["input.sensitivity", "input.accel_profile", "input.natural_scroll", "input.scroll_factor", "input.left_handed", "input.touchpad.tap-to-click", "input.touchpad.natural_scroll", "input.touchpad.scroll_factor", "input.touchpad.disable_while_typing", "input.touchpad.clickfinger_behavior", "input.touchpad.tap-and-drag", "input.touchpad.middle_button_emulation"]
    readonly property var gestureKeys: ["gestures.workspace_swipe_distance", "gestures.workspace_swipe_invert", "gestures.workspace_swipe_cancel_ratio", "gestures.workspace_swipe_min_speed_to_force", "gestures.workspace_swipe_forever", "gestures.workspace_swipe_create_new"]
    readonly property var pageKeys: page.keyboardKeys.concat(page.pointerKeys, page.gestureKeys)
    // the touchpad card only shows when Hyprland has one
    property bool hasTouchpad: false
    readonly property var layouts: HyprConfig.layoutList()
    // the common ways to switch; one your config picked that is not here shows too
    readonly property var switchChoices: {
        const out = [{
            "key": "",
            "label": "No key"
        }, {
            "key": "grp:alt_shift_toggle",
            "label": "Alt + Shift"
        }, {
            "key": "grp:win_space_toggle",
            "label": "Super + Space"
        }, {
            "key": "grp:ctrl_shift_toggle",
            "label": "Ctrl + Shift"
        }, {
            "key": "grp:caps_toggle",
            "label": "Caps Lock"
        }, {
            "key": "grp:toggle",
            "label": "Right Alt"
        }];
        const now = HyprConfig.kbOption("grp");
        if (now !== "" && !out.some((c) => {
            return c.key === now;
        }))
            out.push({
            "key": now,
            "label": Xkb.optionName(now)
        });

        return out;
    }
    readonly property var capsChoices: {
        const out = [{
            "key": "",
            "label": "Caps Lock"
        }, {
            "key": "ctrl:nocaps",
            "label": "Ctrl"
        }, {
            "key": "caps:escape",
            "label": "Escape"
        }, {
            "key": "caps:none",
            "label": "Nothing"
        }];
        const now = HyprConfig.kbOption("caps");
        if (now !== "" && !out.some((c) => {
            return c.key === now;
        }))
            out.push({
            "key": now,
            "label": Xkb.optionName(now)
        });

        return out;
    }

    function move(i, by) {
        const list = page.layouts.slice();
        const j = i + by;
        if (j < 0 || j >= list.length)
            return ;

        const e = list[i];
        list[i] = list[j];
        list[j] = e;
        HyprConfig.setLayouts(list);
    }

    function removeAt(i) {
        const list = page.layouts.slice();
        list.splice(i, 1);
        HyprConfig.setLayouts(list);
    }

    spacing: 26
    Component.onCompleted: {
        HyprConfig.refresh();
        devicesProc.running = true;
    }

    Process {
        id: devicesProc

        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.hasTouchpad = (JSON.parse(this.text).mice || []).some((m) => {
                        return /touchpad|trackpad/i.test(m.name || "");
                    });
                } catch (e) {
                    page.hasTouchpad = false;
                }
            }
        }

    }

    SettingCard {
        visible: HyprConfig.moduleProbed && !HyprConfig.moduleInstalled

        SettingRow {
            title: "Not set up"
            warning: "This page writes ~/.config/hypr/lucid-settings.lua, and your Hyprland config does not read it. Run the installer with --with-hypr, or copy Lucid's modules/settings.lua into ~/.config/hypr/modules/ and add require(\"modules.settings\") to hyprland.lua, before anything of your own."
            showDivider: false
        }

    }

    SettingCard {
        title: "KEYBOARD"
        subtitle: "Changes apply as you make them, to every keyboard. Anything you leave alone stays as your Hyprland config has it."

        HyprRow {
            id: layoutsRow

            title: "Layouts"
            option: "input.kb_layout"
            extraKeys: ["input.kb_variant"]
            description: page.layouts.length > 1 ? "The first one is what every keyboard starts with; the key below moves through the rest in this order." : "Add another to switch between them."
            stacked: true

            Column {
                width: parent.width
                spacing: 6

                Repeater {
                    model: page.layouts

                    Rectangle {
                        id: layoutItem

                        required property var modelData
                        required property int index

                        width: parent.width
                        height: 56
                        radius: Theme.radiusMd
                        color: Theme.bgSunken

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.right: tools.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: Xkb.nameOf(layoutItem.modelData.layout, layoutItem.modelData.variant)
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBodyLg
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: HyprConfig.layoutId(layoutItem.modelData) + (layoutItem.index === 0 ? "  ·  starts with this one" : "")
                                color: Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabelSm
                                elide: Text.ElideRight
                            }

                        }

                        Row {
                            id: tools

                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            M3IconButton {
                                size: 36
                                enabled: layoutsRow.enabled && layoutItem.index > 0
                                iconPath: "M11 20V7.825l-5.6 5.6L4 12l8-8l8 8l-1.4 1.425l-5.6-5.6V20h-2Z"
                                onClicked: page.move(layoutItem.index, -1)
                            }

                            M3IconButton {
                                size: 36
                                enabled: layoutsRow.enabled && layoutItem.index < page.layouts.length - 1
                                iconPath: "M11 4v12.175l-5.6-5.6L4 12l8 8l8-8l-1.4-1.425l-5.6 5.6V4h-2Z"
                                onClicked: page.move(layoutItem.index, 1)
                            }

                            M3IconButton {
                                size: 36
                                enabled: layoutsRow.enabled && page.layouts.length > 1
                                destructive: true
                                iconPath: "M6.4 19L5 17.6l5.6-5.6L5 6.4L6.4 5l5.6 5.6L17.6 5L19 6.4L13.4 12l5.6 5.6l-1.4 1.4l-5.6-5.6L6.4 19Z"
                                onClicked: page.removeAt(layoutItem.index)
                            }

                        }

                    }

                }

                M3Button {
                    text: "Add a layout"
                    variant: "text"
                    iconPath: "M11 13H5v-2h6V5h2v6h6v2h-6v6h-2v-6Z"
                    enabled: layoutsRow.enabled && Xkb.loaded
                    onClicked: HyprConfig.layoutPickerRequested(page.layouts.map(HyprConfig.layoutId))
                }

            }

        }

        HyprRow {
            id: switchRow

            title: "Switch layouts with"
            option: "input.kb_options"
            description: HyprConfig.kbOption("grp") === "grp:win_space_toggle" ? "Super + Space may also be one of your keybinds; both then happen." : "The bar's layout indicator switches them with a click as well."
            available: page.layouts.length > 1
            unavailableReason: "There is only one layout to use."
            stacked: true

            M3Chips {
                width: parent.width
                enabled: switchRow.enabled
                current: HyprConfig.kbOption("grp")
                options: page.switchChoices
                onChosen: (key) => {
                    return HyprConfig.setKbOption("grp", key);
                }
            }

        }

        HyprRow {
            id: capsRow

            title: "Caps Lock key"
            option: "input.kb_options"
            description: "What the Caps Lock key does. The other keyboard options your config sets are kept."
            stacked: true

            M3Chips {
                width: parent.width
                enabled: capsRow.enabled
                current: HyprConfig.kbOption("caps")
                options: page.capsChoices
                onChosen: (key) => {
                    return HyprConfig.setKbOption("caps", key);
                }
            }

        }

        HyprRow {
            id: repeatDelay

            title: "Repeat after"
            option: "input.repeat_delay"
            description: "How long a key is held before it starts repeating."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: repeatDelay.enabled
                from: 150
                to: 1000
                stepSize: 25
                suffix: " ms"
                value: HyprConfig.num("input.repeat_delay", 600)
                onMoved: (v) => {
                    return HyprConfig.set("input.repeat_delay", Math.round(v));
                }
            }

        }

        HyprRow {
            id: repeatRate

            title: "Repeat speed"
            option: "input.repeat_rate"
            description: "How many times a second a held key repeats."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: repeatRate.enabled
                from: 5
                to: 60
                stepSize: 1
                suffix: " /s"
                value: HyprConfig.num("input.repeat_rate", 25)
                onMoved: (v) => {
                    return HyprConfig.set("input.repeat_rate", Math.round(v));
                }
            }

        }

        HyprRow {
            id: numlock

            title: "Num Lock on at start"
            option: "input.numlock_by_default"
            description: "The keypad types numbers from the moment you sign in."

            M3Switch {
                enabled: numlock.enabled
                checked: HyprConfig.bool("input.numlock_by_default", false)
                onToggled: (v) => {
                    return HyprConfig.set("input.numlock_by_default", v);
                }
            }

        }

        SettingRow {
            title: "Try it"
            description: "Type here to feel the repeat and check the layout."
            stacked: true
            showDivider: false

            M3TextField {
                width: Math.min(parent.width, 420)
                placeholder: "Type something"
                commitOnBlur: false
            }

        }

    }

    SettingCard {
        title: "MOUSE"

        HyprRow {
            id: sensitivity

            title: "Pointer speed"
            option: "input.sensitivity"
            description: "Added to the speed of every mouse and touchpad. At 0 they move as the device reports."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: sensitivity.enabled
                from: -100
                to: 100
                stepSize: 5
                suffix: "%"
                value: Math.round(HyprConfig.num("input.sensitivity", 0) * 100)
                onMoved: (v) => {
                    return HyprConfig.set("input.sensitivity", Math.round(v) / 100);
                }
            }

        }

        HyprRow {
            id: accel

            title: "Acceleration"
            option: "input.accel_profile"
            description: String(HyprConfig.value("input.accel_profile") || "") === "flat" ? "Flat: the pointer covers the same distance however fast you move." : "Adaptive: the faster you move, the further the pointer goes. It is what each device does unless told otherwise."
            stacked: true

            M3Segmented {
                width: Math.min(parent.width, 300)
                enabled: accel.enabled
                current: String(HyprConfig.value("input.accel_profile") || "") === "flat" ? "flat" : "adaptive"
                options: [{
                    "key": "adaptive",
                    "label": "Adaptive"
                }, {
                    "key": "flat",
                    "label": "Flat"
                }]
                onChosen: (key) => {
                    return HyprConfig.set("input.accel_profile", key);
                }
            }

        }

        HyprRow {
            id: mouseNatural

            title: "Natural scrolling"
            option: "input.natural_scroll"
            description: "The page follows the wheel, the way content follows a finger on a phone."

            M3Switch {
                enabled: mouseNatural.enabled
                checked: HyprConfig.bool("input.natural_scroll", false)
                onToggled: (v) => {
                    return HyprConfig.set("input.natural_scroll", v);
                }
            }

        }

        HyprRow {
            id: mouseScroll

            title: "Scroll speed"
            option: "input.scroll_factor"
            description: "How far one notch of the wheel scrolls, times the usual."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: mouseScroll.enabled
                from: 0.2
                to: 3
                stepSize: 0.1
                decimals: 1
                suffix: "×"
                value: HyprConfig.num("input.scroll_factor", 1)
                onMoved: (v) => {
                    return HyprConfig.set("input.scroll_factor", Math.round(v * 10) / 10);
                }
            }

        }

        HyprRow {
            id: leftHanded

            title: "Left-handed"
            option: "input.left_handed"
            description: "Swaps the left and right buttons."
            showDivider: false

            M3Switch {
                enabled: leftHanded.enabled
                checked: HyprConfig.bool("input.left_handed", false)
                onToggled: (v) => {
                    return HyprConfig.set("input.left_handed", v);
                }
            }

        }

    }

    SettingCard {
        visible: page.hasTouchpad
        title: "TOUCHPAD"

        HyprRow {
            id: tapClick

            title: "Tap to click"
            option: "input.touchpad.tap-to-click"
            description: "A light tap clicks; two fingers are a right click, three a middle click."

            M3Switch {
                enabled: tapClick.enabled
                checked: HyprConfig.bool("input.touchpad.tap-to-click", true)
                onToggled: (v) => {
                    return HyprConfig.set("input.touchpad.tap-to-click", v);
                }
            }

        }

        HyprRow {
            id: tapDrag

            title: "Tap and drag"
            option: "input.touchpad.tap-and-drag"
            description: "Tap, then keep the finger down to drag."
            available: HyprConfig.bool("input.touchpad.tap-to-click", true)
            unavailableReason: "Tap to click is off."

            M3Switch {
                enabled: tapDrag.enabled
                checked: HyprConfig.bool("input.touchpad.tap-and-drag", true)
                onToggled: (v) => {
                    return HyprConfig.set("input.touchpad.tap-and-drag", v);
                }
            }

        }

        HyprRow {
            id: padNatural

            title: "Natural scrolling"
            option: "input.touchpad.natural_scroll"
            description: "The page moves with your fingers."

            M3Switch {
                enabled: padNatural.enabled
                checked: HyprConfig.bool("input.touchpad.natural_scroll", false)
                onToggled: (v) => {
                    return HyprConfig.set("input.touchpad.natural_scroll", v);
                }
            }

        }

        HyprRow {
            id: padScroll

            title: "Scroll speed"
            option: "input.touchpad.scroll_factor"
            description: "How far a swipe of two fingers scrolls, times the usual."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: padScroll.enabled
                from: 0.1
                to: 3
                stepSize: 0.1
                decimals: 1
                suffix: "×"
                value: HyprConfig.num("input.touchpad.scroll_factor", 1)
                onMoved: (v) => {
                    return HyprConfig.set("input.touchpad.scroll_factor", Math.round(v * 10) / 10);
                }
            }

        }

        HyprRow {
            id: typing

            title: "Off while typing"
            option: "input.touchpad.disable_while_typing"
            description: "A palm on the touchpad does nothing while you type."

            M3Switch {
                enabled: typing.enabled
                checked: HyprConfig.bool("input.touchpad.disable_while_typing", true)
                onToggled: (v) => {
                    return HyprConfig.set("input.touchpad.disable_while_typing", v);
                }
            }

        }

        HyprRow {
            id: clickfinger

            title: "Right click with two fingers"
            option: "input.touchpad.clickfinger_behavior"
            description: "Pressing down with two fingers is a right click and with three a middle click, anywhere on the pad. Off, it depends on where you press: the bottom right corner is the right button."

            M3Switch {
                enabled: clickfinger.enabled
                checked: HyprConfig.bool("input.touchpad.clickfinger_behavior", false)
                onToggled: (v) => {
                    return HyprConfig.set("input.touchpad.clickfinger_behavior", v);
                }
            }

        }

        HyprRow {
            id: middle

            title: "Middle click from both buttons"
            option: "input.touchpad.middle_button_emulation"
            description: "Pressing the left and right buttons together is a middle click."
            showDivider: false

            M3Switch {
                enabled: middle.enabled
                checked: HyprConfig.bool("input.touchpad.middle_button_emulation", false)
                onToggled: (v) => {
                    return HyprConfig.set("input.touchpad.middle_button_emulation", v);
                }
            }

        }

    }

    SettingCard {
        visible: page.hasTouchpad
        title: "SWIPING BETWEEN WORKSPACES"
        subtitle: "How the touchpad swipe to another workspace feels. How many fingers it takes is set by the gestures in your Hyprland config."

        HyprRow {
            id: swipeDistance

            title: "Swipe length"
            option: "gestures.workspace_swipe_distance"
            description: "How far the fingers travel for a whole workspace. Shorter is quicker, longer is more precise."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: swipeDistance.enabled
                from: 100
                to: 800
                stepSize: 25
                suffix: " px"
                value: HyprConfig.num("gestures.workspace_swipe_distance", 300)
                onMoved: (v) => {
                    return HyprConfig.set("gestures.workspace_swipe_distance", Math.round(v));
                }
            }

        }

        HyprRow {
            id: swipeCancel

            title: "Switch once you are past"
            option: "gestures.workspace_swipe_cancel_ratio"
            description: "How much of the way you need to get before letting go switches; short of it, the workspace slides back."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: swipeCancel.enabled
                from: 5
                to: 90
                stepSize: 5
                suffix: "%"
                value: Math.round(HyprConfig.num("gestures.workspace_swipe_cancel_ratio", 0.5) * 100)
                onMoved: (v) => {
                    return HyprConfig.set("gestures.workspace_swipe_cancel_ratio", Math.round(v) / 100);
                }
            }

        }

        HyprRow {
            id: swipeFlick

            title: "A flick switches from"
            option: "gestures.workspace_swipe_min_speed_to_force"
            description: "How fast a short swipe has to be to switch anyway. At 0 only the distance counts."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: swipeFlick.enabled
                from: 0
                to: 60
                stepSize: 1
                value: HyprConfig.num("gestures.workspace_swipe_min_speed_to_force", 30)
                onMoved: (v) => {
                    return HyprConfig.set("gestures.workspace_swipe_min_speed_to_force", Math.round(v));
                }
            }

        }

        HyprRow {
            id: swipeInvert

            title: "Invert the swipe"
            option: "gestures.workspace_swipe_invert"
            description: "Hyprland has this on unless told otherwise. If a swipe takes you the opposite way from the one you expect, flip it."

            M3Switch {
                enabled: swipeInvert.enabled
                checked: HyprConfig.bool("gestures.workspace_swipe_invert", true)
                onToggled: (v) => {
                    return HyprConfig.set("gestures.workspace_swipe_invert", v);
                }
            }

        }

        HyprRow {
            id: swipeForever

            title: "Keep going past the next one"
            option: "gestures.workspace_swipe_forever"
            description: "One long swipe can travel several workspaces instead of stopping at the neighbour."

            M3Switch {
                enabled: swipeForever.enabled
                checked: HyprConfig.bool("gestures.workspace_swipe_forever", false)
                onToggled: (v) => {
                    return HyprConfig.set("gestures.workspace_swipe_forever", v);
                }
            }

        }

        HyprRow {
            id: swipeNew

            title: "A new workspace at the end"
            option: "gestures.workspace_swipe_create_new"
            description: "Swiping past the last workspace makes a new, empty one."
            showDivider: false

            M3Switch {
                enabled: swipeNew.enabled
                checked: HyprConfig.bool("gestures.workspace_swipe_create_new", true)
                onToggled: (v) => {
                    return HyprConfig.set("gestures.workspace_swipe_create_new", v);
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
                onClicked: Prefs.askReset("Reset input?", "Everything on this page goes back to whatever your Hyprland config sets.", "hypr:" + page.pageKeys.join(","))
            }

        }

    }

}
