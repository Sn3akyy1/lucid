import QtQuick
import qs

Item {
    id: page

    property string openId: ""
    property string expanded: ""
    readonly property var current: page.openId !== "" ? KdeConnect.device(page.openId) : null
    readonly property bool detailed: page.current !== null && page.current.reachable && page.current.paired
    readonly property var asking: KdeConnect.devices.filter((d) => {
        return d.pairRequestedByPeer;
    })
    readonly property var nearby: KdeConnect.nearby.filter((d) => {
        return !d.pairRequestedByPeer;
    })

    // a device dropping off the network takes its panel with it. deferred,
    // because `detailed` is derived from `openId` and writing it back inside
    // the handler is a binding loop
    function closeDetail() {
        if (!page.detailed)
            page.openId = "";

    }

    implicitWidth: parent ? parent.width : 700
    implicitHeight: page.detailed ? detailView.implicitHeight : listView.implicitHeight
    enabled: Prefs.kdeConnectEnabled
    opacity: page.enabled ? 1 : 0.38
    onDetailedChanged: {
        if (!page.detailed)
            Qt.callLater(page.closeDetail);

    }

    Column {
        id: listView

        width: parent.width
        spacing: 26
        visible: !page.detailed
        opacity: page.detailed ? 0 : 1

        SettingCard {
            title: "THIS MACHINE"

            SettingRow {
                title: "Status"
                description: KdeConnect.installed ? "Links this machine to a phone or tablet on the same network: files both ways, a shared clipboard, its notifications here, and a remote for whatever it is playing. " + KdeConnect.summary + "." : "KDE Connect is not installed. Install the kdeconnect package and this page comes to life."
                enabled: KdeConnect.installed
                disabledReason: "KDE Connect is not installed. Install the kdeconnect package and this page comes to life."
                warning: KdeConnect.lastError
            }

            SettingRow {
                title: "Name your phone sees"
                visible: KdeConnect.active
                enabled: KdeConnect.running
                description: KdeConnect.selfId !== "" ? "This machine's KDE Connect ID is " + KdeConnect.selfId + "." : "Waiting for the KDE Connect daemon…"

                M3TextField {
                    width: 260
                    enabled: KdeConnect.running
                    placeholder: "archlinux"
                    text: KdeConnect.selfName
                    onAccepted: (v) => {
                        if (v.trim() !== "")
                            KdeConnect.setName(v.trim());

                    }
                }

            }

            SettingRow {
                title: "Connect over"
                visible: KdeConnect.active && KdeConnect.backends.length > 0
                enabled: KdeConnect.running
                description: "The network is the fast path. Bluetooth is a fallback for when the two are not on the same Wi-Fi."
                stacked: true
                showDivider: false

                Flow {
                    width: parent.width
                    spacing: 16

                    Repeater {
                        model: KdeConnect.backends

                        CheckLine {
                            required property var modelData

                            label: modelData.name === "LAN" ? "This network" : modelData.name
                            checked: modelData.enabled
                            onToggled: KdeConnect.setBackend(modelData.name, !modelData.enabled)
                        }

                    }

                }

            }

        }

        SettingCard {
            title: "DEVICES"
            visible: KdeConnect.active

            SettingRow {
                title: "Your devices"
                enabled: KdeConnect.running
                description: KdeConnect.running ? "Open KDE Connect on the phone and it turns up here. Pick a connected one to open it." : "The KDE Connect daemon is not answering. It normally starts itself the moment something asks for it."
                stacked: true
                showDivider: KdeConnect.devices.length > 0

                M3Button {
                    variant: "tonal"
                    enabled: KdeConnect.running
                    text: "Look again"
                    onClicked: KdeConnect.rescan()
                }

            }

            Column {
                width: parent.width
                topPadding: 4
                bottomPadding: 8
                spacing: 2

                GroupLabel {
                    text: "Wants to pair"
                    visible: page.asking.length > 0
                }

                Repeater {
                    model: page.asking

                    KdeDeviceRow {
                        expanded: true
                    }

                }

                GroupLabel {
                    text: "Connected"
                    visible: KdeConnect.reachable.length > 0
                }

                Repeater {
                    model: KdeConnect.reachable

                    KdeDeviceRow {
                        expanded: page.expanded === modelData.id
                        onOpened: page.openId = modelData.id
                        onExpandRequested: page.expanded = expanded ? "" : modelData.id
                    }

                }

                GroupLabel {
                    text: "Paired, offline"
                    visible: KdeConnect.offline.length > 0
                }

                Repeater {
                    model: KdeConnect.offline

                    KdeDeviceRow {
                        expanded: page.expanded === modelData.id
                        onExpandRequested: page.expanded = expanded ? "" : modelData.id
                    }

                }

                GroupLabel {
                    text: "Nearby"
                    visible: page.nearby.length > 0
                }

                Repeater {
                    model: page.nearby

                    KdeDeviceRow {
                        expanded: page.expanded === modelData.id
                        onExpandRequested: page.expanded = expanded ? "" : modelData.id
                    }

                }

                Text {
                    width: parent.width
                    visible: KdeConnect.running && KdeConnect.devices.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 18
                    bottomPadding: 18
                    text: "No devices yet. Install KDE Connect on your phone, open it, and it will appear here."
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    KdeDetail {
        id: detailView

        width: parent.width
        visible: page.detailed
        opacity: page.detailed ? 1 : 0
        dev: page.current !== null ? page.current : ({
            "id": "",
            "name": "",
            "type": "",
            "links": [],
            "loaded": [],
            "supported": [],
            "key": ""
        })
        onBack: page.openId = ""

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    component GroupLabel: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitleSm
        font.weight: Font.DemiBold
        font.letterSpacing: 0.1
        leftPadding: 22
        topPadding: 14
        bottomPadding: 6
    }

}
