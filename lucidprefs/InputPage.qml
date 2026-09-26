import QtQuick
import qs

Column {
    id: page

    readonly property var keyboardKeys: ["input.kb_layout", "input.kb_variant", "input.kb_options", "input.repeat_rate", "input.repeat_delay", "input.numlock_by_default"]
    readonly property var pageKeys: page.keyboardKeys
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
    Component.onCompleted: HyprConfig.refresh()

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
