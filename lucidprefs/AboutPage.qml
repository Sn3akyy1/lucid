import QtQuick
import Quickshell
import qs

Column {
    id: page

    readonly property var components: [{
        "name": "lucidbar",
        "desc": I18n.tr("Status bar - workspaces, media, tray, clock, bluetooth, network, notifications, system")
    }, {
        "name": "luciddocks",
        "desc": I18n.tr("Dock, application launcher, wallpaper and theme strips, power menu")
    }, {
        "name": "lucidprefs",
        "desc": I18n.tr("This settings app")
    }, {
        "name": "lucidlock",
        "desc": I18n.tr("Lock screen")
    }, {
        "name": "lucidosd",
        "desc": I18n.tr("Volume and brightness on-screen display")
    }, {
        "name": "lucidshot",
        "desc": I18n.tr("Captures, markup, pins and the screen recorder")
    }, {
        "name": "lucidmoji",
        "desc": I18n.tr("Emoji and GIF picker")
    }, {
        "name": "lucidnews",
        "desc": I18n.tr("What's new: the sheet a new version opens with")
    }]
    readonly property var commands: [{
        "cmd": "qs ipc call settings open",
        "desc": I18n.tr("Open this app - also >settings in the launcher")
    }, {
        "cmd": "qs ipc call settings toggle",
        "desc": I18n.tr("Open or close it")
    }, {
        "cmd": "qs ipc call settings bar",
        "desc": I18n.tr("Open straight to a page - also general, dock")
    }, {
        "cmd": "qs ipc call -- settings show about",
        "desc": I18n.tr("Any page by name. The separator before the target is required whenever a function takes an argument.")
    }, {
        "cmd": "qs ipc call launcher toggle",
        "desc": I18n.tr("Application launcher")
    }, {
        "cmd": "qs ipc call launcher wallpaper",
        "desc": I18n.tr("Wallpaper strip")
    }, {
        "cmd": "qs ipc call launcher theme",
        "desc": I18n.tr("Theme strip")
    }, {
        "cmd": "qs ipc call launcher power",
        "desc": I18n.tr("Power menu")
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
        title: I18n.tr("UPDATES")

        SettingRow {
            title: {
                if (Updates.installing)
                    return I18n.tr("Updating to %1", Updates.flowLabel);

                if (Updates.restartPending)
                    return I18n.tr("Restart to finish");

                return Updates.available ? I18n.tr("Lucid v%1 is out", Updates.latest) : I18n.tr("Version %1", Updates.currentLabel);
            }
            description: Updates.status
            stacked: true

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    visible: !Updates.installing
                    text: Updates.busy ? I18n.tr("Checking…") : I18n.tr("Check now")
                    variant: "tonal"
                    enabled: !Updates.busy && Updates.current !== ""
                    onClicked: Updates.check()
                }

                // what this version brought, in the shell's own sheet
                M3Button {
                    text: I18n.tr("What's new")
                    variant: "outlined"
                    onClicked: Updates.showWhatsNew()
                }

                // a newer one's notes live on GitHub until it is installed
                M3Button {
                    visible: Updates.available && !Updates.restartPending
                    text: I18n.tr("Release notes")
                    variant: "outlined"
                    onClicked: Updates.openLatest()
                }

                // installs it from the release, warning and password first
                M3Button {
                    visible: Updates.available && !Updates.installing && !Updates.restartPending
                    text: I18n.tr("Update")
                    variant: "filled"
                    iconPath: "download"
                    onClicked: Updates.startUpdate("release")
                }

                M3Button {
                    visible: Updates.installing
                    text: I18n.tr("Show progress")
                    variant: "filled"
                    onClicked: Updates.show()
                }

                M3Button {
                    visible: Updates.restartPending
                    text: I18n.tr("Restart now")
                    variant: "filled"
                    iconPath: "restart_alt"
                    onClicked: Updates.restartNow()
                }

            }

        }

        SettingRow {
            title: I18n.tr("Check for updates")
            resetKey: "updateCheck"
            description: I18n.tr("Once a day Lucid asks GitHub for the newest release, and tells you once when there is one. The request carries nothing about you or this machine.")

            M3Switch {
                checked: Prefs.updateCheck
                onToggled: (v) => {
                    return Prefs.updateCheck = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Beta updates")
            resetKey: "updateBeta"
            description: I18n.tr("Offers the newest commit on main, before it becomes a release. Installing one needs your password, like an update. Turning this off does not roll anything back; the next release replaces the beta.")
            warning: I18n.tr("Critical: beta builds are untested and things may break. The bar, the lock screen or the whole shell can fail to start, and getting back may take a terminal.")
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
            title: Updates.betaAvailable ? I18n.tr("Beta %1 is available", Updates.betaShort) : I18n.tr("Beta build")
            description: Updates.betaStatus
            showDivider: false

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    text: Updates.betaBusy ? I18n.tr("Checking…") : I18n.tr("Check")
                    variant: "tonal"
                    enabled: !Updates.betaBusy
                    onClicked: Updates.checkBeta()
                }

                // grey once the newest commit on main is the one installed
                M3Button {
                    text: I18n.tr("Install beta")
                    variant: "filled"
                    destructive: true
                    enabled: Updates.betaAvailable && !Updates.installing
                    onClicked: Updates.startUpdate("beta")
                }

            }

        }

    }

    SettingCard {
        title: I18n.tr("COMMAND LINE")

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
        title: I18n.tr("COMPONENTS")

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
        title: I18n.tr("CONFIGURATION")

        SettingRow {
            title: I18n.tr("Settings file")
            description: I18n.tr("~/.config/quickshell/lucidprefs/prefs.json")
            showDivider: false

            M3Button {
                text: I18n.tr("Open folder")
                onClicked: Quickshell.execDetached(["sh", "-c", "xdg-open ~/.config/quickshell/lucidprefs"])
            }

        }

    }

}
