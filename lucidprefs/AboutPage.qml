import QtQuick
import Quickshell
import qs

Column {
    id: page

    readonly property string version: Updates.currentLabel
    readonly property bool beta: true
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

    spacing: 26

    Rectangle {
        width: parent.width
        height: 164
        radius: Theme.radiusXl
        color: Theme.bgTile

        Row {
            anchors.centerIn: parent
            spacing: 22

            LucidaMark {
                width: 68
                height: 68
                strokeWidth: 2.6
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Row {
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Lucid"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(30)
                        font.bold: true
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: page.beta
                        width: betaLabel.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.accent

                        Text {
                            id: betaLabel

                            anchors.centerIn: parent
                            text: "BETA"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(10)
                            font.bold: true
                            font.letterSpacing: 1
                        }

                    }

                }

                Row {
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.version
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "·"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "The brightest thing in your setup."
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }

                }

            }

        }

    }

    SettingCard {
        title: "UPDATES"

        SettingRow {
            title: Updates.available ? "Lucid v" + Updates.latest + " is out" : "Version " + Updates.currentLabel
            description: Updates.status

            Row {
                spacing: 8

                M3Button {
                    text: Updates.busy ? "Checking…" : "Check now"
                    variant: "tonal"
                    enabled: !Updates.busy && Updates.current !== ""
                    onClicked: Updates.check()
                }

                M3Button {
                    text: "What's new"
                    variant: Updates.available ? "filled" : "outlined"
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
