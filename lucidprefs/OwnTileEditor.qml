import QtQuick
import qs
import qs.lucidcc
import qs.lucidui

// one of the user's own control centre tiles on the system module's card: how
// it looks, drawn as the panel draws it, and the commands behind it
Rectangle {
    id: ed

    // an entry of Prefs.systemOwnTileList
    property var tile: null
    readonly property string key: ed.tile ? ed.tile.key : ""
    readonly property bool isSwitch: !!ed.tile && ed.tile.off.trim() !== ""
    // the icons Lucid carries are only the ones it names somewhere, so the
    // choice is these
    readonly property var icons: ["star", "bolt", "terminal", "code", "build", "deployed_code", "cloud", "lan", "hub", "public", "vpn_key", "shield", "security", "key", "screen_share", "tv", "monitor", "computer", "laptop_chromebook", "smartphone", "sports_esports", "stadia_controller", "headphones", "music_note", "movie", "videocam", "photo_camera", "light", "mode_fan", "thermostat", "eco", "water_drop", "power", "sync", "download", "upload_file", "folder", "home", "favorite", "orbit", "target", "flag", "notifications", "schedule", "speed", "memory", "hard_drive", "usb"]

    function set(fields) {
        Prefs.setSystemOwnTile(ed.key, fields);
    }

    width: parent ? parent.width : 0
    height: body.implicitHeight + Theme.dp(32)
    radius: Theme.radiusMd
    color: "transparent"
    border.width: 1
    border.color: Theme.outline

    Column {
        id: body

        x: Theme.dp(16)
        y: Theme.dp(16)
        width: parent.width - Theme.dp(32)
        spacing: Theme.dp(12)

        Item {
            width: parent.width
            height: Math.max(preview.height, fields.implicitHeight)

            // as it shows in the panel; a switch shows on
            CcSmallTile {
                id: preview

                width: Theme.dp(64)
                enabled: false
                icon: ed.tile ? ed.tile.icon : ""
                label: ed.tile ? ed.tile.name : ""
                checked: ed.isSwitch
            }

            Column {
                id: fields

                anchors.left: preview.right
                anchors.leftMargin: Theme.dp(16)
                anchors.right: remove.left
                anchors.rightMargin: Theme.dp(8)
                spacing: Theme.dp(8)

                M3TextField {
                    width: parent.width
                    placeholder: "Name"
                    text: ed.tile ? ed.tile.name : ""
                    onAccepted: (v) => {
                        return ed.set({
                            "name": v.trim()
                        });
                    }
                }

            }

            M3IconButton {
                id: remove

                anchors.right: parent.right
                anchors.top: parent.top
                size: Theme.dp(36)
                iconPath: "delete"
                destructive: true
                onClicked: Prefs.removeSystemOwnTile(ed.key)
            }

        }

        Flow {
            width: parent.width
            spacing: Theme.dp(4)

            Repeater {
                model: ed.icons

                Rectangle {
                    id: pick

                    required property string modelData
                    readonly property bool chosen: !!ed.tile && ed.tile.icon === pick.modelData

                    width: Theme.dp(36)
                    height: Theme.dp(36)
                    radius: pick.chosen ? Theme.rad(10) : width / 2
                    color: pick.chosen ? Theme.primary : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        name: pick.modelData
                        size: Theme.dp(20)
                        color: pick.chosen ? Theme.fgPrimary : Theme.subtext
                    }

                    StateLayer {
                        radius: parent.radius
                        onClicked: ed.set({
                            "icon": pick.modelData
                        })
                    }

                }

            }

        }

        Repeater {
            model: [{
                "field": "on",
                "label": ed.isSwitch ? "Turn on" : "On a tap",
                "hint": "e.g. tailscale up, or sunshine-ctl start"
            }, {
                "field": "off",
                "label": "Turn off, to make it a switch",
                "hint": "Optional, e.g. tailscale down"
            }, {
                "field": "status",
                "label": "Is it on? Exits 0 while it is",
                "hint": "Optional, e.g. pgrep -x sunshine"
            }]

            Column {
                id: cmd

                required property var modelData

                visible: cmd.modelData.field !== "status" || ed.isSwitch
                width: body.width
                spacing: Theme.dp(4)

                Text {
                    text: cmd.modelData.label
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelMd
                }

                M3TextField {
                    width: parent.width
                    placeholder: cmd.modelData.hint
                    text: ed.tile ? ed.tile[cmd.modelData.field] : ""
                    onAccepted: (v) => {
                        const f = {};
                        f[cmd.modelData.field] = v;
                        ed.set(f);
                    }
                }

            }

        }

    }

}
