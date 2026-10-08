import QtQuick
import Quickshell
import qs

Column {
    id: page

    readonly property var components: [{
        "name": "lucidbar",
        "desc": "Status bar - workspaces, media, tray, clock, bluetooth, network, notifications, system"
    }, {
        "name": "luciddocks",
        "desc": "Dock, application launcher, wallpaper and theme strips, power menu"
    }, {
        "name": "lucidprefs",
        "desc": "This settings app"
    }, {
        "name": "lucidlock",
        "desc": "Lock screen"
    }, {
        "name": "lucidosd",
        "desc": "Volume and brightness on-screen display"
    }, {
        "name": "lucidshot",
        "desc": "Screenshot overlay and region capture"
    }, {
        "name": "lucidmoji",
        "desc": "Emoji and GIF picker"
    }, {
        "name": "lucidnews",
        "desc": "What's new: the sheet a new version opens with"
    }]
    readonly property var commands: [{
        "cmd": "qs ipc call settings open",
        "desc": "Open this app - also >settings in the launcher"
    }, {
        "cmd": "qs ipc call settings toggle",
        "desc": "Open or close it"
    }, {
        "cmd": "qs ipc call settings bar",
        "desc": "Open straight to a page - also general, dock"
    }, {
        "cmd": "qs ipc call -- settings show about",
        "desc": "Any page by name. The separator before the target is required whenever a function takes an argument."
    }, {
        "cmd": "qs ipc call launcher toggle",
        "desc": "Application launcher"
    }, {
        "cmd": "qs ipc call launcher wallpaper",
        "desc": "Wallpaper strip"
    }, {
        "cmd": "qs ipc call launcher theme",
        "desc": "Theme strip"
    }, {
        "cmd": "qs ipc call launcher power",
        "desc": "Power menu"
    }]

    // set by Settings while the page is on screen
    property bool pageShown: false

    spacing: Theme.dp(26)
    onPageShownChanged: {
        if (page.pageShown)
            hero.enter();

    }

    AboutHero {
        id: hero

        width: parent.width
        live: page.pageShown
    }

    SettingCard {
        title: "UPDATES"

        SettingRow {
            title: Updates.available ? "Lucid v" + Updates.latest + " is out" : "Version " + Updates.currentLabel
            description: Updates.status

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    text: Updates.busy ? "Checking…" : "Check now"
                    variant: "tonal"
                    enabled: !Updates.busy && Updates.current !== ""
                    onClicked: Updates.check()
                }

                // what this version brought, in the shell's own sheet
                M3Button {
                    text: "What's new"
                    variant: "outlined"
                    onClicked: Updates.showWhatsNew()
                }

                // a newer one's notes live on GitHub until it is installed
                M3Button {
                    visible: Updates.available
                    text: "Release notes"
                    variant: "filled"
                    onClicked: Updates.openLatest()
                }

            }

        }

        SettingRow {
            title: "Check for updates"
            resetKey: "updateCheck"
            description: "Once a day Lucid asks GitHub for the newest release, and tells you once when there is one. The request carries nothing about you or this machine."
            showDivider: false

            M3Switch {
                checked: Prefs.updateCheck
                onToggled: (v) => {
                    return Prefs.updateCheck = v;
                }
            }

        }

    }

    SettingCard {
        title: "COMMAND LINE"

        Repeater {
            model: page.commands

            SettingRow {
                id: cmdRow

                required property var modelData
                required property int index

                title: cmdRow.modelData.cmd
                monoTitle: true
                description: cmdRow.modelData.desc
                showDivider: cmdRow.index < page.commands.length - 1
            }

        }

    }

    SettingCard {
        title: "COMPONENTS"

        Repeater {
            model: page.components

            SettingRow {
                id: compRow

                required property var modelData
                required property int index

                title: compRow.modelData.name
                description: compRow.modelData.desc
                showDivider: compRow.index < page.components.length - 1
            }

        }

    }

    SettingCard {
        title: "CONFIGURATION"

        SettingRow {
            title: "Settings file"
            description: "~/.config/quickshell/lucidprefs/prefs.json"
            showDivider: false

            M3Button {
                text: "Open folder"
                onClicked: Quickshell.execDetached(["sh", "-c", "xdg-open ~/.config/quickshell/lucidprefs"])
            }

        }

    }

}
