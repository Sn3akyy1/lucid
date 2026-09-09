import QtQuick
import Quickshell.Networking
import qs

Column {
    id: page

    property string filter: ""
    property string expanded: ""
    property bool hiddenForm: false
    property string hiddenSsid: ""
    property string hiddenPsk: ""
    property string hotspotSsid: "Lucid Hotspot"
    property string hotspotPsk: ""
    readonly property var wifi: Net.wifiDevice
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool scanning: !!(page.wifi && page.wifi.scannerEnabled)
    readonly property var groups: {
        if (!page.wifi || !page.wifi.networks)
            return {
            "connected": [],
            "saved": [],
            "nearby": []
        };

        const q = page.filter.trim().toLowerCase();
        const best = new Map();
        for (const n of page.wifi.networks.values) {
            if (!n.name || n.name.length === 0)
                continue;

            if (q !== "" && n.name.toLowerCase().indexOf(q) < 0)
                continue;

            const seen = best.get(n.name);
            if (!seen || n.connected || Net.strengthPct(n) > Net.strengthPct(seen))
                best.set(n.name, n);

        }
        const all = Array.from(best.values());
        const bySignal = (a) => {
            return a.slice().sort((x, y) => {
                return Net.strengthPct(y) - Net.strengthPct(x);
            });
        };
        return {
            "connected": all.filter((n) => {
                return n.connected;
            }),
            "saved": bySignal(all.filter((n) => {
                return !n.connected && n.known;
            })),
            "nearby": bySignal(all.filter((n) => {
                return !n.connected && !n.known;
            }))
        };
    }
    readonly property int visibleCount: page.groups.connected.length + page.groups.saved.length + page.groups.nearby.length

    spacing: 26
    Component.onCompleted: {
        Net.refresh();
        if (page.wifi && Networking.wifiEnabled)
            page.wifi.scannerEnabled = true;

    }

    SettingCard {
        title: "STATUS"

        SettingRow {
            title: Net.connectivityLabel
            description: {
                const active = Net.devices.filter((d) => {
                    return d.connection !== "";
                });
                if (active.length === 0)
                    return "Nothing is connected.";

                return active.map((d) => {
                    return d.connection + " on " + d.name + (d.ip4.length > 0 ? " (" + d.ip4[0].split("/")[0] + ")" : "");
                }).join("  ·  ");
            }
            warning: Net.lastError

            M3Button {
                variant: "tonal"
                enabled: Networking.canCheckConnectivity
                text: "Check now"
                onClicked: Networking.checkConnectivity()
            }

        }

        SettingRow {
            title: "Keep checking for a sign-in page"
            visible: Networking.canCheckConnectivity
            description: "NetworkManager pings a known address now and then, which is how it can tell a hotel sign-in page from a real connection."
            showDivider: false

            M3Switch {
                checked: Networking.connectivityCheckEnabled
                onToggled: (v) => {
                    return Networking.connectivityCheckEnabled = v;
                }
            }

        }

    }

    SettingCard {
        title: "WI-FI"

        SettingRow {
            title: "Wi-Fi"
            enabled: Networking.wifiHardwareEnabled
            disabledReason: "A hardware switch or an Fn key has the Wi-Fi radio blocked."
            description: page.wifiOn ? (page.groups.connected.length > 0 ? "On, joined to " + page.groups.connected[0].name + "." : "On, not joined to anything.") : "The radio is off, so nothing can connect."

            M3Switch {
                enabled: Networking.wifiHardwareEnabled
                checked: page.wifiOn
                onToggled: (v) => {
                    return Networking.wifiEnabled = v;
                }
            }

        }

        SettingRow {
            title: page.scanning ? "Looking for networks" : "Networks"
            visible: page.wifiOn
            description: "Scanning keeps the list fresh. Turn it off and the list stops moving under your cursor."
            stacked: true

            Row {
                width: parent.width
                spacing: 10

                M3TextField {
                    width: parent.width - scanBox.implicitWidth - hiddenBtn.implicitWidth - 20
                    placeholder: "Filter by name"
                    onEdited: (v) => {
                        return page.filter = v;
                    }
                }

                CheckLine {
                    id: scanBox

                    anchors.verticalCenter: parent.verticalCenter
                    label: "Keep scanning"
                    checked: page.scanning
                    onToggled: {
                        if (page.wifi)
                            page.wifi.scannerEnabled = !page.wifi.scannerEnabled;

                    }
                }

                M3Button {
                    id: hiddenBtn

                    anchors.verticalCenter: parent.verticalCenter
                    variant: "text"
                    text: "Hidden network"
                    onClicked: page.hiddenForm = !page.hiddenForm
                }

            }

        }

        SettingRow {
            title: "Join a hidden network"
            visible: page.wifiOn && page.hiddenForm
            enabled: !Net.busy
            description: "A network that does not broadcast its name. Type it exactly, capitals and all."
            stacked: true

            Row {
                width: parent.width
                spacing: 10

                M3TextField {
                    width: 220
                    placeholder: "Network name"
                    onEdited: (v) => {
                        return page.hiddenSsid = v;
                    }
                }

                M3TextField {
                    width: 220
                    placeholder: "Password, if any"
                    onEdited: (v) => {
                        return page.hiddenPsk = v;
                    }
                }

                M3Button {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "filled"
                    text: Net.busy ? "Joining" : "Join"
                    enabled: !Net.busy && page.hiddenSsid.trim() !== ""
                    onClicked: Net.connectHidden(page.hiddenSsid.trim(), page.hiddenPsk)
                }

            }

        }

        Column {
            width: parent.width
            visible: page.wifiOn
            topPadding: 4
            bottomPadding: 8
            spacing: 2

            GroupLabel {
                text: "Connected"
                visible: page.groups.connected.length > 0
            }

            Repeater {
                model: page.groups.connected

                WifiRow {
                    expanded: page.expanded === modelData.name
                    onExpandRequested: page.expanded = expanded ? "" : modelData.name
                }

            }

            GroupLabel {
                text: "Saved"
                visible: page.groups.saved.length > 0
            }

            Repeater {
                model: page.groups.saved

                WifiRow {
                    expanded: page.expanded === modelData.name
                    onExpandRequested: page.expanded = expanded ? "" : modelData.name
                }

            }

            GroupLabel {
                text: "Nearby"
                visible: page.groups.nearby.length > 0
            }

            Repeater {
                model: page.groups.nearby

                WifiRow {
                    expanded: page.expanded === modelData.name
                    onExpandRequested: page.expanded = expanded ? "" : modelData.name
                }

            }

            Text {
                width: parent.width
                visible: page.visibleCount === 0
                horizontalAlignment: Text.AlignHCenter
                topPadding: 18
                bottomPadding: 18
                text: page.filter.trim() !== "" ? "Nothing matches that." : "No networks in range."
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
            }

        }

    }

    SettingCard {
        title: "SHARE THIS CONNECTION"
        visible: page.wifiOn && !!page.wifi

        SettingRow {
            title: "Wi-Fi hotspot"
            enabled: !Net.busy
            description: "Turns the Wi-Fi radio into an access point so other devices can borrow this machine's connection. It drops whatever Wi-Fi network you are on, so it only helps when the internet arrives some other way."
            stacked: true
            showDivider: false

            Row {
                width: parent.width
                spacing: 10

                M3TextField {
                    width: 220
                    placeholder: "Hotspot name"
                    text: page.hotspotSsid
                    onEdited: (v) => {
                        return page.hotspotSsid = v;
                    }
                }

                M3TextField {
                    width: 220
                    placeholder: "Password, 8 characters or more"
                    onEdited: (v) => {
                        return page.hotspotPsk = v;
                    }
                }

                M3Button {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    text: "Start hotspot"
                    enabled: !Net.busy && page.hotspotSsid.trim() !== "" && page.hotspotPsk.length >= 8
                    onClicked: Prefs.askConfirm("Start a hotspot?", "This drops the Wi-Fi network you are on and turns the radio into an access point named " + page.hotspotSsid.trim() + ".", "Start", "net-hotspot:" + page.hotspotSsid.trim() + "\n" + page.hotspotPsk)
                }

            }

        }

    }

    SettingCard {
        title: "WIRED"
        visible: Net.wiredDevices.length > 0

        Repeater {
            model: Net.wiredDevices

            SettingRow {
                id: wiredRow

                required property var modelData
                required property int index
                readonly property var info: Net.deviceInfo(wiredRow.modelData.name)

                title: wiredRow.modelData.name
                description: {
                    if (!wiredRow.modelData.connected)
                        return wiredRow.info && wiredRow.info.state === "unavailable" ? "No cable plugged in." : "Cable plugged in, not connected.";

                    const ip = wiredRow.info && wiredRow.info.ip4.length > 0 ? wiredRow.info.ip4[0].split("/")[0] : "";
                    const speed = wiredRow.info && wiredRow.info.speed > 0 ? wiredRow.info.speed + " Mbit/s" : "";
                    return ["Connected", ip, speed].filter((x) => {
                        return x !== "";
                    }).join("  ·  ");
                }
                showDivider: wiredRow.index < Net.wiredDevices.length - 1

                Row {
                    spacing: 14

                    CheckLine {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Connect automatically"
                        checked: wiredRow.modelData.autoconnect
                        onToggled: wiredRow.modelData.autoconnect = !wiredRow.modelData.autoconnect
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "tonal"
                        visible: wiredRow.modelData.connected
                        text: "Disconnect"
                        onClicked: wiredRow.modelData.disconnect()
                    }

                }

            }

        }

    }

    SettingCard {
        title: "VPN"

        SettingRow {
            title: Net.vpns.length === 0 ? "No VPN set up" : (Net.activeVpn ? "Connected to " + Net.activeVpn.name : "Not connected")
            description: Net.vpns.length === 0 ? "Lucid lists whatever NetworkManager already knows. Import a config with nmcli or nm-connection-editor and it turns up here." : "One at a time, the way NetworkManager handles it."
            showDivider: Net.vpns.length > 0
        }

        Repeater {
            model: Net.vpns

            SettingRow {
                id: vpnRow

                required property var modelData
                required property int index

                title: vpnRow.modelData.name
                description: (vpnRow.modelData.type === "wireguard" ? "WireGuard" : "VPN") + (vpnRow.modelData.active ? "  ·  connected" : "")
                enabled: !Net.busy
                showDivider: vpnRow.index < Net.vpns.length - 1

                Row {
                    spacing: 14

                    CheckLine {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Connect automatically"
                        checked: vpnRow.modelData.autoconnect
                        onToggled: Net.setAutoconnect(vpnRow.modelData.uuid, !vpnRow.modelData.autoconnect)
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: vpnRow.modelData.active ? "tonal" : "filled"
                        text: vpnRow.modelData.active ? "Disconnect" : "Connect"
                        onClicked: {
                            if (vpnRow.modelData.active)
                                Net.down(vpnRow.modelData.uuid);
                            else
                                Net.up(vpnRow.modelData.uuid);
                        }
                    }

                }

            }

        }

    }

    Repeater {
        model: Net.devices.filter((d) => {
            return d.type === "wifi" || d.type === "ethernet";
        })

        NetDetailsCard {
            required property var modelData

            width: parent.width
            info: modelData
        }

    }

    SettingCard {
        title: "SAVED CONNECTIONS"

        SettingRow {
            title: "Everything NetworkManager has kept"
            description: "A saved connection is a set of settings, not a network. Deleting one only forgets the settings."
            showDivider: Net.profiles.length > 0
        }

        Repeater {
            model: Net.profiles

            SettingRow {
                id: profRow

                required property var modelData
                required property int index

                title: profRow.modelData.name
                description: {
                    const kind = profRow.modelData.type === "802-11-wireless" ? "Wi-Fi" : (profRow.modelData.type === "802-3-ethernet" ? "Wired" : profRow.modelData.type);
                    return kind + (profRow.modelData.active ? "  ·  in use on " + profRow.modelData.device : "");
                }
                enabled: !Net.busy
                showDivider: profRow.index < Net.profiles.length - 1

                Row {
                    spacing: 14

                    CheckLine {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Automatic"
                        checked: profRow.modelData.autoconnect
                        onToggled: Net.setAutoconnect(profRow.modelData.uuid, !profRow.modelData.autoconnect)
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "text"
                        destructive: true
                        text: "Delete"
                        onClicked: Prefs.askConfirm("Delete this saved connection?", "The settings for " + profRow.modelData.name + " and any password go with it. Nothing else on the machine is touched.", "Delete", "net-delete:" + profRow.modelData.uuid)
                    }

                }

            }

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
