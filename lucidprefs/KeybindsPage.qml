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
    // the desktop icons' own keys, the one being recorded, and those the search keeps
    property string deskRecording: ""
    readonly property var shownDeskKeys: {
        var q = page.query.trim().toLowerCase();
        return DesktopIcons.keyActions.filter((a) => {
            return q === "" || "desktop".indexOf(q) >= 0 || a.label.toLowerCase().indexOf(q) >= 0 || DesktopIcons.keysFor(a.id).toLowerCase().indexOf(q) >= 0;
        });
    }
    readonly property string problems: {
        var out = [];
        if (Keybinds.parseError !== "")
            out.push(I18n.tr("keybinds.json does not parse (%1). Nothing is saved from here until the file is fixed.", Keybinds.parseError));

        if (Keybinds.emergency)
            out.push(I18n.tr("Hyprland could not use the file and fell back to the emergency binds: ") + (Keybinds.status.error || I18n.tr("unknown error")) + ".");
        else if (page.failedCount > 0)
            out.push(page.failedCount + (page.failedCount === 1 ? I18n.tr(" keybind did not") : I18n.tr(" keybinds did not")) + I18n.tr(" apply — marked in red below."));
        return out.join("\n");
    }

    spacing: Theme.dp(26)

    SettingCard {
        title: I18n.tr("KEYBINDS")

        SettingRow {
            title: Keybinds.missing ? I18n.tr("No keybinds file yet") : I18n.tr("%1 keybinds", Keybinds.binds.length)
            description: Keybinds.missing ? I18n.tr("~/.config/lucid/keybinds.json does not exist, so Hyprland is running a small emergency set. Add a keybind to start the file, or re-run the Lucid installer for the full default list.") : I18n.tr("Kept in ~/.config/lucid/keybinds.json. Every change is saved as you make it and Hyprland reloads straight away, so a new key works the moment you save it.") + (Keybinds.sheetKeys !== "" ? I18n.tr(" %1 shows them all, over whatever you are doing.", Keybinds.sheetKeys) : "")
            warning: page.problems
            showDivider: Keybinds.extraCount > 0
            stacked: true

            Flow {
                width: parent.width
                spacing: Theme.dp(8)

                M3Button {
                    text: I18n.tr("Add keybind")
                    variant: "filled"
                    enabled: Keybinds.parseError === ""
                    iconPath: "add"
                    onClicked: Keybinds.editRequested("")
                }

                M3Button {
                    text: I18n.tr("Show cheatsheet")
                    variant: "tonal"
                    onClicked: Keybinds.sheetRequested()
                }

                M3Button {
                    text: I18n.tr("Edit file")
                    variant: "outlined"
                    onClicked: Keybinds.openFile()
                }

                M3Button {
                    text: I18n.tr("Reload Hyprland")
                    variant: "text"
                    onClicked: Keybinds.reloadHyprland()
                }

            }

        }

        SettingRow {
            visible: Keybinds.extraCount > 0
            title: I18n.tr("Binds from elsewhere")
            description: Keybinds.extraCount + (Keybinds.extraCount === 1 ? I18n.tr(" more bind is") : I18n.tr(" more binds are")) + I18n.tr(" active in Hyprland than this list holds. They come from hypr-user.lua or another module, so they cannot be changed here — and one on the same keys as a bind below fires alongside it.")
            showDivider: false
        }

    }

    Item {
        width: parent.width
        height: Theme.dp(46)
        visible: Keybinds.binds.length > 0

        M3TextField {
            anchors.left: parent.left
            anchors.right: found.left
            anchors.rightMargin: found.text === "" ? 0 : Theme.dp(16)
            anchors.verticalCenter: parent.verticalCenter
            placeholder: I18n.tr("Search by key, action or category")
            text: page.query
            onEdited: (v) => {
                page.query = v;
            }
        }

        Text {
            id: found

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter
            text: page.query.trim() === "" ? "" : I18n.tr("%1 found", page.shownBinds.length)
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
        }

    }

    Text {
        width: parent.width
        visible: page.query.trim() !== "" && page.shownCategories.length === 0
        text: I18n.tr("No keybind matches “%1”.", page.query.trim())
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        horizontalAlignment: Text.AlignHCenter
        topPadding: Theme.dp(12)
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

    // a capture that timed out ends the recording too
    Connections {
        function onCapturingChanged() {
            if (!Keybinds.capturing && page.deskRecording !== "")
                page.deskRecording = "";

        }

        target: Keybinds
    }

    SettingCard {
        title: I18n.tr("DESKTOP ICONS")
        visible: page.shownDeskKeys.length > 0

        SettingRow {
            title: I18n.tr("Desktop shortcuts")
            description: I18n.tr("The keys the desktop icons answer to while the desktop has the keyboard: click an empty spot or an icon first. Apps never see them, and they never fire inside an app, so the usual Ctrl+C and Ctrl+V are safe here.") + (Prefs.desktopIcons ? "" : I18n.tr(" Desktop icons are off in General."))

            M3Button {
                text: I18n.tr("Reset all")
                variant: "text"
                enabled: Object.keys(DesktopIcons.keyOverrides).length > 0
                onClicked: Prefs.desktopKeys = "{}"
            }

        }

        Repeater {
            model: page.shownDeskKeys

            DesktopKeyRow {
                required property var modelData

                action: modelData
                recordingId: page.deskRecording
                onStartRecording: (id) => {
                    page.deskRecording = id;
                    Keybinds.startCapture();
                }
                onStopRecording: {
                    page.deskRecording = "";
                    Keybinds.stopCapture();
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("HOW A KEYBIND IS WRITTEN")

        SettingRow {
            title: I18n.tr("Keys")
            description: I18n.tr("Modifiers and one key joined with +, as in SUPER + SHIFT + T. Key names are Hyprland's: left, Return, Print, comma, F5, XF86AudioRaiseVolume, mouse:272 for a left click, mouse_down for the wheel. Record fills this in by pressing the keys.")
        }

        SettingRow {
            title: I18n.tr("Actions")
            description: I18n.tr("A command runs through the shell, the same as typing it in a terminal. Lua is for Hyprland's own actions — hl.dsp.window.close(), hl.dsp.focus({ workspace = 3 }) — or function() … end for anything longer, with fn (utils/functions.lua) and seq(a, b) to hand. A Lua mistake only costs that one key: it is marked here and everything else still binds.")
            showDivider: false
        }

    }

}
