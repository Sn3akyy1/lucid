import QtQuick
import qs

Column {
    id: page

    property string query: ""
    readonly property var shownBinds: {
        var q = page.query.trim().toLowerCase();
        return Keybinds.binds.filter((b) => {
            return Keybinds.matches(b, q);
        });
    }
    readonly property var shownCategories: Keybinds.categories.filter((c) => {
        return page.shownBinds.some((b) => {
            return Keybinds.categoryOf(b) === c;
        });
    })
    readonly property int failedCount: Object.keys(Keybinds.failed).length
    readonly property string problems: {
        var out = [];
        if (Keybinds.parseError !== "")
            out.push("keybinds.json does not parse (" + Keybinds.parseError + "). Nothing is saved from here until the file is fixed.");

        if (Keybinds.emergency)
            out.push("Hyprland could not use the file and fell back to the emergency binds: " + (Keybinds.status.error || "unknown error") + ".");
        else if (page.failedCount > 0)
            out.push(page.failedCount + (page.failedCount === 1 ? " keybind did not" : " keybinds did not") + " apply — marked in red below.");
        return out.join("\n");
    }

    spacing: 26

    SettingCard {
        title: "KEYBINDS"

        SettingRow {
            title: Keybinds.missing ? "No keybinds file yet" : Keybinds.binds.length + " keybinds"
            description: Keybinds.missing ? "~/.config/lucid/keybinds.json does not exist, so Hyprland is running a small emergency set. Add a keybind to start the file, or re-run the Lucid installer for the full default list." : "Kept in ~/.config/lucid/keybinds.json. Every change is saved as you make it and Hyprland reloads straight away, so a new key works the moment you save it." + (Keybinds.sheetKeys !== "" ? " " + Keybinds.sheetKeys + " shows them all, over whatever you are doing." : "")
            warning: page.problems
            showDivider: Keybinds.extraCount > 0
            stacked: true

            Flow {
                width: parent.width
                spacing: 8

                M3Button {
                    text: "Add keybind"
                    variant: "filled"
                    enabled: Keybinds.parseError === ""
                    iconPath: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2Z"
                    onClicked: Keybinds.editRequested("")
                }

                M3Button {
                    text: "Show cheatsheet"
                    variant: "tonal"
                    onClicked: Keybinds.sheetRequested()
                }

                M3Button {
                    text: "Edit file"
                    variant: "outlined"
                    onClicked: Keybinds.openFile()
                }

                M3Button {
                    text: "Reload Hyprland"
                    variant: "text"
                    onClicked: Keybinds.reloadHyprland()
                }

            }

        }

        SettingRow {
            visible: Keybinds.extraCount > 0
            title: "Binds from elsewhere"
            description: Keybinds.extraCount + (Keybinds.extraCount === 1 ? " more bind is" : " more binds are") + " active in Hyprland than this list holds. They come from hypr-user.lua or another module, so they cannot be changed here — and one on the same keys as a bind below fires alongside it."
            showDivider: false
        }

    }

    Item {
        width: parent.width
        height: 46
        visible: Keybinds.binds.length > 0

        M3TextField {
            anchors.left: parent.left
            anchors.right: found.left
            anchors.rightMargin: found.text === "" ? 0 : 16
            anchors.verticalCenter: parent.verticalCenter
            placeholder: "Search by key, action or category"
            text: page.query
            onEdited: (v) => {
                page.query = v;
            }
        }

        Text {
            id: found

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: page.query.trim() === "" ? "" : page.shownBinds.length + " found"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
        }

    }

    Text {
        width: parent.width
        visible: page.query.trim() !== "" && page.shownCategories.length === 0
        text: "No keybind matches “" + page.query.trim() + "”."
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        horizontalAlignment: Text.AlignHCenter
        topPadding: 12
    }

    Repeater {
        model: page.shownCategories

        SettingCard {
            id: group

            required property string modelData

            title: group.modelData

            Repeater {
                model: page.shownBinds.filter((b) => {
                    return Keybinds.categoryOf(b) === group.modelData;
                })

                KeybindRow {
                    required property var modelData

                    bind: modelData
                }

            }

        }

    }

    SettingCard {
        title: "HOW A KEYBIND IS WRITTEN"

        SettingRow {
            title: "Keys"
            description: "Modifiers and one key joined with +, as in SUPER + SHIFT + T. Key names are Hyprland's: left, Return, Print, comma, F5, XF86AudioRaiseVolume, mouse:272 for a left click, mouse_down for the wheel. Record fills this in by pressing the keys."
        }

        SettingRow {
            title: "Actions"
            description: "A command runs through the shell, the same as typing it in a terminal. Lua is for Hyprland's own actions — hl.dsp.window.close(), hl.dsp.focus({ workspace = 3 }) — or function() … end for anything longer, with fn (utils/functions.lua) and seq(a, b) to hand. A Lua mistake only costs that one key: it is marked here and everything else still binds."
            showDivider: false
        }

    }

}
