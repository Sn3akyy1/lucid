import QtQuick
import qs
import qs.lucidui

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

    spacing: Theme.dp(26)

    Item {
        width: parent.width
        height: Theme.dp(64)

        Rectangle {
            id: backBtn

            width: Theme.dp(38)
            height: Theme.dp(38)
            radius: Theme.dp(19)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: backArea.containsMouse ? Theme.bgHover : Theme.bgTile

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durQuick
                }

            }

            Icon {
                anchors.centerIn: parent
                name: "arrow_back"
                size: Theme.dp(20)
                color: Theme.text
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
            anchors.leftMargin: Theme.dp(18)
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(26)
            kind: Bt.glyphKind(detail.dev.type)
            color: Theme.accent
        }

        Column {
            anchors.left: headGlyph.right
            anchors.leftMargin: Theme.dp(14)
            anchors.right: headTrailing.left
            anchors.rightMargin: Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: detail.dev.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(18)
                font.variableAxes: Theme.axes(Theme.fs(18), 640, 0)
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: detail.dev.links.length > 0 ? I18n.tr("Connected over %1", detail.dev.links.join(", ")) : I18n.tr("Connected")
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                elide: Text.ElideRight
            }

        }

        Row {
            id: headTrailing

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(14)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: detail.sig !== undefined && detail.sig.strength >= 0
                spacing: Theme.dp(6)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: detail.sig ? detail.sig.type : ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                }

                SignalBars {
                    anchors.verticalCenter: parent.verticalCenter
                    strength: detail.sig ? detail.sig.strength * 25 : 0
                }

            }

            BatteryPip {
                anchors.verticalCenter: parent.verticalCenter
                charge: detail.battery ? detail.battery.charge : -1
                charging: !!(detail.battery && detail.battery.charging)
            }

        }

    }

    SettingCard {
        title: I18n.tr("SEND TO THIS DEVICE")

        SettingRow {
            title: I18n.tr("Files")
            description: detail.sentRecently ? (KdeConnect.lastSent === 1 ? I18n.tr("Sent 1 file.") : I18n.tr("Sent %1 files.", KdeConnect.lastSent)) : I18n.tr("Pick anything on this machine and it lands in the phone's downloads.")
            enabled: detail.has("kdeconnect_share")
            disabledReason: I18n.tr("This device has file sharing turned off.")

            Row {
                spacing: Theme.dp(10)

                M3Button {
                    variant: "filled"
                    enabled: detail.has("kdeconnect_share")
                    text: I18n.tr("Choose files…")
                    onClicked: KdeConnect.pickFiles(detail.dev.id, I18n.tr("Send to %1", detail.dev.name))
                }

                M3Button {
                    variant: "text"
                    enabled: detail.has("kdeconnect_share")
                    text: I18n.tr("Where files arrive")
                    onClicked: KdeConnect.openDest(detail.dev.id)
                }

            }

        }

        SettingRow {
            title: I18n.tr("Text or a link")
            description: I18n.tr("A link opens on the phone. Anything else is copied to its clipboard.")
            enabled: detail.has("kdeconnect_share")
            stacked: true
            showDivider: false

            Row {
                width: parent.width
                spacing: Theme.dp(10)

                M3TextField {
                    id: textField

                    width: parent.width - Theme.dp(110)
                    enabled: detail.has("kdeconnect_share")
                    placeholder: I18n.tr("Type a message or paste a link…")
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
                    text: I18n.tr("Send")
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
        title: I18n.tr("THINGS TO DO WITH IT")

        SettingRow {
            title: I18n.tr("Right now")
            description: detail.sftp && detail.sftp.mounted && detail.sftp.point !== "" ? I18n.tr("The phone's storage is mounted at %1.", detail.sftp.point) : I18n.tr("Ring it if you have lost it, or mount its storage to browse the files.")
            stacked: true
            showDivider: false

            Flow {
                width: parent.width
                spacing: Theme.dp(8)

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_findmyphone")
                    text: I18n.tr("Ring it")
                    onClicked: KdeConnect.ring(detail.dev.id)
                }

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_clipboard")
                    text: I18n.tr("Send my clipboard")
                    onClicked: KdeConnect.sendClipboard(detail.dev.id)
                }

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_lockdevice")
                    text: detail.dev.locked ? I18n.tr("Unlock it") : I18n.tr("Lock it")
                    onClicked: KdeConnect.setLocked(detail.dev.id, !detail.dev.locked)
                }

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_sftp")
                    text: detail.sftp && detail.sftp.mounted ? I18n.tr("Browse its files") : I18n.tr("Mount its storage")
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
                    text: I18n.tr("Unmount")
                    onClicked: KdeConnect.unmount(detail.dev.id)
                }

                M3Button {
                    variant: "tonal"
                    visible: detail.has("kdeconnect_sms")
                    text: I18n.tr("Text messages")
                    onClicked: KdeConnect.openSms(detail.dev.id)
                }

                M3Button {
                    variant: "text"
                    visible: detail.has("kdeconnect_ping")
                    text: I18n.tr("Ping")
                    onClicked: KdeConnect.ping(detail.dev.id, I18n.tr("Hello from Lucid"))
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
        title: I18n.tr("COMMANDS ON THE DEVICE")
        visible: (detail.dev.commands || []).length > 0

        SettingRow {
            title: I18n.tr("Run one")
            description: I18n.tr("These are the commands you have set up on the device itself.")
            stacked: true
            showDivider: false

            Flow {
                width: parent.width
                spacing: Theme.dp(8)

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
        title: I18n.tr("FEATURES")

        SettingRow {
            title: I18n.tr("What this device is allowed to do")
            description: I18n.tr("Turn off anything you would rather it did not do. The change reaches the other side straight away.")
            stacked: true
            showDivider: false

            Flow {
                width: parent.width
                spacing: Theme.dp(16)

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
        title: I18n.tr("PAIRING")

        SettingRow {
            title: I18n.tr("Verification key")
            description: I18n.tr("Both devices show the same key while they trust each other.")
            monoTitle: false
            showDivider: false

            Row {
                spacing: Theme.dp(14)

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
                    text: I18n.tr("Unpair")
                    onClicked: Prefs.askConfirm(I18n.tr("Unpair %1?", detail.dev.name), I18n.tr("This machine and that device stop trusting each other. Nothing on either is deleted, and you can pair them again whenever you like."), I18n.tr("Unpair"), "kde-unpair:" + detail.dev.id)
                }

            }

        }

    }

}
