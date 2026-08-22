import QtQuick
import Quickshell
import qs

// About: what this shell is made of, and the command line that reaches it.
// The IPC list is here rather than in a README because a settings app opened
// from a terminal is exactly where someone goes looking for the next command.
Column {
    id: page

    // one place to bump when the shell is released - the window title stays
    // clean of it on purpose, since that is what the compositor and the dock
    // show, and a version there would just be noise
    readonly property string version: "v0.91"
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
                        text: "LucidShell"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(30)
                        font.bold: true
                    }

                    // outlined rather than filled: this is a status marker
                    // sitting beside the name, not an action, and a solid
                    // accent chip here would read as something to press
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
                        text: "A Quickshell desktop for Hyprland"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }

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
