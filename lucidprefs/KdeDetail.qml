import QtQuick
import qs

Column {
    id: detail

    required property var dev

    property string draft: ""

    readonly property var battery: detail.dev.battery
    readonly property var sig: detail.dev.signal
    readonly property var sftp: detail.dev.sftp
    readonly property bool sentRecently: KdeConnect.lastSentAt > 0 && Date.now() - KdeConnect.lastSentAt < 8000

    function has(name) {
        return detail.dev.loaded.indexOf(name) >= 0;
    }

    signal back()

    spacing: 26

    Item {
        width: parent.width
        height: 64

        Rectangle {
            id: backBtn

            width: 38
            height: 38
            radius: Theme.rad(19)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: backArea.containsMouse ? Theme.bgHover : Theme.bgTile

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

            Text {
                anchors.centerIn: parent
                text: "‹"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(20)
            }

            MouseArea {
                id: backArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: detail.back()
            }

        }

        DeviceGlyph {
            id: headGlyph

            anchors.left: backBtn.right
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            size: 26
            kind: Bt.glyphKind(detail.dev.type)
            color: Theme.accent
        }

        Column {
            anchors.left: headGlyph.right
            anchors.leftMargin: 14
            anchors.right: headTrailing.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: detail.dev.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(18)
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: detail.dev.links.length > 0 ? "Connected over " + detail.dev.links.join(", ") : "Connected"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                elide: Text.ElideRight
            }

        }

        Row {
            id: headTrailing

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: detail.sig !== undefined && detail.sig.strength >= 0
                text: detail.sig ? detail.sig.type + " " + "▮".repeat(Math.max(0, detail.sig.strength)) : ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
            }

            BatteryPip {
                anchors.verticalCenter: parent.verticalCenter
                charge: detail.battery ? detail.battery.charge : -1
                charging: !!(detail.battery && detail.battery.charging)
            }

        }

    }

    SettingCard {
        title: "SEND TO THIS DEVICE"

        SettingRow {
            title: "Files"
            description: detail.sentRecently ? (KdeConnect.lastSent === 1 ? "Sent 1 file." : "Sent " + KdeConnect.lastSent + " files.") : "Pick anything on this machine and it lands in the phone's downloads."
            enabled: detail.has("kdeconnect_share")
            disabledReason: "This device has file sharing turned off."

            Row {
                spacing: 10

                M3Button {
                    variant: "filled"
                    enabled: detail.has("kdeconnect_share")
                    text: "Choose files…"
                    onClicked: KdeConnect.pickFiles(detail.dev.id, "Send to " + detail.dev.name)
                }

                M3Button {
                    variant: "text"
                    enabled: detail.has("kdeconnect_share")
                    text: "Where files arrive"
                    onClicked: KdeConnect.openDest(detail.dev.id)
                }

            }

        }

        SettingRow {
            title: "Text or a link"
            description: "A link opens on the phone. Anything else is copied to its clipboard."
            enabled: detail.has("kdeconnect_share")
            stacked: true
            showDivider: false

            Row {
                width: parent.width
                spacing: 10

                M3TextField {
                    id: textField

                    width: parent.width - 110
                    enabled: detail.has("kdeconnect_share")
                    placeholder: "Type a message or paste a link…"
                    onEdited: (v) => {
                        return detail.draft = v;
                    }
                    onAccepted: (v) => {
                        return sendText.clicked();
                    }
                }

                M3Button {
                    id: sendText

                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    text: "Send"
                    enabled: detail.draft.trim() !== ""
                    onClicked: {
                        const v = detail.draft.trim();
                        if (v === "")
                            return ;

                        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(v))
                            KdeConnect.shareUrl(detail.dev.id, v);
                        else
                            KdeConnect.shareText(detail.dev.id, v);
                        detail.draft = "";
                        textField.clear();
                    }
                }

            }

        }

    }

    SettingCard {
        title: "THINGS TO DO WITH IT"

        SettingRow {
            title: "Right now"
            description: detail.sftp && detail.sftp.mounted && detail.sftp.point !== "" ? "The phone's storage is mounted at " + detail.sftp.point + "." : "Ring it if you have lost it, or mount its storage to browse the files."
            stacked: true
            showDivider: false

            Flow {
                width: parent.width
                spacing: 8

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_findmyphone")
                    text: "Ring it"
                    onClicked: KdeConnect.ring(detail.dev.id)
                }

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_clipboard")
                    text: "Send my clipboard"
                    onClicked: KdeConnect.sendClipboard(detail.dev.id)
                }

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_lockdevice")
                    text: detail.dev.locked ? "Unlock it" : "Lock it"
                    onClicked: KdeConnect.setLocked(detail.dev.id, !detail.dev.locked)
                }

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_sftp")
                    text: detail.sftp && detail.sftp.mounted ? "Browse its files" : "Mount its storage"
                    onClicked: {
                        if (detail.sftp && detail.sftp.mounted)
                            KdeConnect.browse(detail.dev.id);
                        else
                            KdeConnect.mount(detail.dev.id);
                    }
                }

                M3Button {
                    variant: "text"
                    visible: !!(detail.sftp && detail.sftp.mounted)
                    text: "Unmount"
                    onClicked: KdeConnect.unmount(detail.dev.id)
                }

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_sms")
                    text: "Text messages"
                    onClicked: KdeConnect.openSms(detail.dev.id)
                }

                M3Button {
                    variant: "text"
                    visible: detail.has("kdeconnect_ping")
                    text: "Ping"
                    onClicked: KdeConnect.ping(detail.dev.id, "Hello from Lucid")
                }

            }

        }

    }

    KdeMediaCard {
        width: parent.width
        visible: detail.has("kdeconnect_mprisremote")
        dev: detail.dev
    }

    KdeNotifyCard {
        width: parent.width
        visible: detail.has("kdeconnect_notifications")
        dev: detail.dev
    }

    KdeVolumeCard {
        width: parent.width
        visible: (detail.dev.sinks || []).length > 0
        dev: detail.dev
    }

    KdeInputCard {
        width: parent.width
        visible: detail.has("kdeconnect_remotecontrol")
        dev: detail.dev
    }

    SettingCard {
        title: "COMMANDS ON THE DEVICE"
        visible: (detail.dev.commands || []).length > 0

        SettingRow {
            title: "Run one"
            description: "These are the commands you have set up on the device itself."
            stacked: true
            showDivider: false

            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: detail.dev.commands || []

                    M3Button {
                        required property var modelData

                        variant: "tonal"
                        text: modelData.name
                        onClicked: KdeConnect.runCommand(detail.dev.id, modelData.key)
                    }

                }

            }

        }

    }

    SettingCard {
        title: "FEATURES"

        SettingRow {
            title: "What this device is allowed to do"
            description: "Turn off anything you would rather it did not do. The change reaches the other side straight away."
            stacked: true
            showDivider: false

            Flow {
                width: parent.width
                spacing: 16

                Repeater {
                    model: detail.dev.supported || []

                    CheckLine {
                        required property string modelData

                        label: KdeConnect.pluginLabel(modelData)
                        checked: detail.has(modelData)
                        onToggled: KdeConnect.setPlugin(detail.dev.id, modelData, !detail.has(modelData))
                    }

                }

            }

        }

    }

    SettingCard {
        title: "PAIRING"

        SettingRow {
            title: "Verification key"
            description: "Both devices show the same key while they trust each other."
            monoTitle: false
            showDivider: false

            Row {
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: detail.dev.key
                    color: Theme.subtext
                    font.family: "monospace"
                    font.features: ({
                        "liga": 0,
                        "calt": 0
                    })
                    font.pixelSize: Theme.fontBody
                }

                M3Button {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "text"
                    destructive: true
                    text: "Unpair"
                    onClicked: Prefs.askConfirm("Unpair " + detail.dev.name + "?", "This machine and that device stop trusting each other. Nothing on either is deleted, and you can pair them again whenever you like.", "Unpair", "kde-unpair:" + detail.dev.id)
                }

            }

        }

    }

}
