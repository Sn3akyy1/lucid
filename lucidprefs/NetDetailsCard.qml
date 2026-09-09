import QtQuick
import qs

SettingCard {
    id: card

    required property var info

    property bool editing: false
    property string address: ""
    property string gateway: ""
    property string dns: ""

    readonly property var profile: Net.connections.find((c) => {
        return c.device === card.info.name && c.active;
    }) || null
    readonly property string uuid: card.profile ? card.profile.uuid : ""
    readonly property bool loaded: card.uuid !== "" && Net.detail["uuid"] === card.uuid
    readonly property bool manual: card.loaded && Net.detail["ipv4.method"] === "manual"

    function label(v) {
        return v !== "" && v !== undefined ? v : "—";
    }

    function beginEdit() {
        card.address = Net.detail["ipv4.addresses"] || (card.info.ip4.length > 0 ? card.info.ip4[0] : "");
        card.gateway = Net.detail["ipv4.gateway"] || card.info.gw4;
        card.dns = Net.detail["ipv4.dns"] || card.info.dns4.join(",");
        card.editing = true;
    }

    title: (card.info.type === "wifi" ? "WI-FI" : (card.info.type === "ethernet" ? "WIRED" : card.info.type.toUpperCase())) + "  ·  " + card.info.name

    onUuidChanged: {
        if (card.uuid !== "")
            Net.loadDetail(card.uuid);

    }

    Component.onCompleted: {
        if (card.uuid !== "")
            Net.loadDetail(card.uuid);

    }

    SettingRow {
        title: "Addresses"
        description: card.info.connection !== "" ? "On “" + card.info.connection + "”, " + card.info.state + "." : "Not carrying a connection."
        stacked: true

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 40
            rowSpacing: 9

            InfoPair {
                name: "IPv4"
                value: card.info.ip4.length > 0 ? card.info.ip4.join(", ") : "—"
            }

            InfoPair {
                name: "Gateway"
                value: card.label(card.info.gw4)
            }

            InfoPair {
                name: "DNS"
                value: card.info.dns4.length > 0 ? card.info.dns4.join(", ") : "—"
            }

            InfoPair {
                name: "Hardware address"
                value: card.label(card.info.mac)
            }

            InfoPair {
                name: "IPv6"
                value: card.info.ip6.length > 0 ? card.info.ip6.join("\n") : "—"
            }

            InfoPair {
                name: card.info.type === "wifi" ? "Link rate" : "Link speed"
                value: card.info.type === "wifi" ? card.label(card.info.rate) : (card.info.speed > 0 ? card.info.speed + " Mbit/s" : "—")
            }

            InfoPair {
                name: "MTU"
                value: card.info.mtu > 0 ? String(card.info.mtu) : "—"
            }

        }

    }

    SettingRow {
        title: "How this connection gets its address"
        visible: card.uuid !== ""
        enabled: !Net.busy
        description: card.manual ? "Set by hand. The values below are what NetworkManager will use next time it connects." : "From the router, over DHCP. Switch to By hand to pin an address."
        warning: Net.lastError
        stacked: true
        showDivider: false

        Column {
            width: parent.width
            spacing: 14

            M3Segmented {
                width: 300
                enabled: !Net.busy
                current: card.manual ? "manual" : "auto"
                options: [{
                    "key": "auto",
                    "label": "Automatic"
                }, {
                    "key": "manual",
                    "label": "By hand"
                }]
                onChosen: (k) => {
                    if (k === "auto") {
                        card.editing = false;
                        Net.setDhcp(card.uuid);
                    } else {
                        card.beginEdit();
                    }
                }
            }

            Column {
                width: parent.width
                visible: card.manual || card.editing
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 12

                    FieldPair {
                        name: "Address and prefix"
                        hint: "192.168.1.50/24"
                        value: card.address
                        onEdited: (v) => {
                            return card.address = v;
                        }
                    }

                    FieldPair {
                        name: "Gateway"
                        hint: "192.168.1.1"
                        value: card.gateway
                        onEdited: (v) => {
                            return card.gateway = v;
                        }
                    }

                }

                FieldPair {
                    width: parent.width
                    name: "DNS servers, comma separated"
                    hint: "1.1.1.1,9.9.9.9"
                    value: card.dns
                    onEdited: (v) => {
                        return card.dns = v;
                    }
                }

                Row {
                    spacing: 10

                    M3Button {
                        variant: "filled"
                        text: Net.busy ? "Applying…" : "Apply and reconnect"
                        enabled: !Net.busy && card.address.trim() !== ""
                        onClicked: {
                            Net.setManual(card.uuid, card.address.trim(), card.gateway.trim(), card.dns.trim());
                            card.editing = false;
                            reconnect.restart();
                        }
                    }

                    M3Button {
                        variant: "text"
                        text: "Cancel"
                        visible: card.editing && !card.manual
                        onClicked: card.editing = false
                    }

                }

            }

            Row {
                spacing: 10
                visible: !card.manual && !card.editing

                FieldPair {
                    width: 340
                    name: "Use these DNS servers instead of the router's"
                    hint: "leave empty to use the router's"
                    value: Net.detail["ipv4.dns"] || ""
                    onAccepted: (v) => {
                        return Net.setDns(card.uuid, v.trim());
                    }
                }

            }

        }

    }

    // a changed address only takes effect on the next activation
    Timer {
        id: reconnect

        interval: 400
        repeat: false
        onTriggered: Net.up(card.uuid)
    }

    component InfoPair: Column {
        id: pairItem

        property string name: ""
        property string value: ""

        spacing: 1

        Text {
            text: pairItem.name
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
        }

        Text {
            text: pairItem.value
            color: Theme.text
            font.family: "monospace"
            font.features: ({
                "liga": 0,
                "calt": 0
            })
            font.pixelSize: Theme.fontLabel
        }

    }

    component FieldPair: Column {
        id: pair

        property string name: ""
        property string hint: ""
        property string value: ""

        signal edited(string v)
        signal accepted(string v)

        width: 240
        spacing: 5

        Text {
            text: pair.name
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
        }

        M3TextField {
            width: pair.width
            enabled: !Net.busy
            placeholder: pair.hint
            text: pair.value
            onEdited: (v) => {
                return pair.edited(v);
            }
            onAccepted: (v) => {
                return pair.accepted(v);
            }
        }

    }

}
