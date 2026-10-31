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
        "desc": "Captures, markup, pins and the screen recorder"
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
            title: {
                if (Updates.installing)
                    return "Updating to " + Updates.flowLabel;

                if (Updates.restartPending)
                    return "Restart to finish";

                return Updates.available ? "Lucid v" + Updates.latest + " is out" : "Version " + Updates.currentLabel;
            }
            description: Updates.status
            stacked: true

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    visible: !Updates.installing
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
                    visible: Updates.available && !Updates.restartPending
                    text: "Release notes"
                    variant: "outlined"
                    onClicked: Updates.openLatest()
                }

                // installs it from the release, warning and password first
                M3Button {
                    visible: Updates.available && !Updates.installing && !Updates.restartPending
                    text: "Update"
                    variant: "filled"
                    iconPath: "download"
                    onClicked: Updates.startUpdate("release")
                }

                M3Button {
                    visible: Updates.installing
                    text: "Show progress"
                    variant: "filled"
                    onClicked: Updates.show()
                }

                M3Button {
                    visible: Updates.restartPending
                    text: "Restart now"
                    variant: "filled"
                    iconPath: "restart_alt"
                    onClicked: Updates.restartNow()
                }

            }

        }

        SettingRow {
            title: "Check for updates"
            resetKey: "updateCheck"
            description: "Once a day Lucid asks GitHub for the newest release, and tells you once when there is one. The request carries nothing about you or this machine."

            M3Switch {
                checked: Prefs.updateCheck
                onToggled: (v) => {
                    return Prefs.updateCheck = v;
                }
            }

        }

        SettingRow {
            title: "Beta updates"
            resetKey: "updateBeta"
            description: "Offers the newest commit on main, before it becomes a release. Installing one needs your password, like an update. Turning this off does not roll anything back; the next release replaces the beta."
            warning: "Critical: beta builds are untested and things may break. The bar, the lock screen or the whole shell can fail to start, and getting back may take a terminal."
            showDivider: Prefs.updateBeta

            M3Switch {
                checked: Prefs.updateBeta
                onToggled: (v) => {
                    return Prefs.updateBeta = v;
                }
            }

        }

        SettingRow {
            visible: Prefs.updateBeta
            title: Updates.betaAvailable ? "Beta " + Updates.betaShort + " is available" : "Beta build"
            description: Updates.betaStatus
            showDivider: false

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    text: Updates.betaBusy ? "Checking…" : "Check"
                    variant: "tonal"
                    enabled: !Updates.betaBusy
                    onClicked: Updates.checkBeta()
                }

                // grey once the newest commit on main is the one installed
                M3Button {
                    text: "Install beta"
                    variant: "filled"
                    destructive: true
                    enabled: Updates.betaAvailable && !Updates.installing
                    onClicked: Updates.startUpdate("beta")
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
