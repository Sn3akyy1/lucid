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
    property string hotspotSsid: I18n.tr("Lucid Hotspot")
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

    spacing: Theme.dp(26)
    Component.onCompleted: {
        Net.refresh();
        if (page.wifi && Networking.wifiEnabled)
            page.wifi.scannerEnabled = true;

    }

    SettingCard {
        title: I18n.tr("STATUS")

        SettingRow {
            title: Net.connectivityLabel
            description: {
                const active = Net.devices.filter((d) => {
                    return d.connection !== "";
                });
                if (active.length === 0)
                    return I18n.tr("Nothing is connected.");

                return active.map((d) => {
                    return d.connection + " on " + d.name + (d.ip4.length > 0 ? " (" + d.ip4[0].split("/")[0] + ")" : "");
                }).join("  ·  ");
            }
            warning: Net.lastError

            M3Button {
                variant: "tonal"
                enabled: Networking.canCheckConnectivity
                text: I18n.tr("Check now")
                onClicked: Networking.checkConnectivity()
            }

        }

        SettingRow {
            title: I18n.tr("Keep checking for a sign-in page")
            visible: Networking.canCheckConnectivity
            description: I18n.tr("NetworkManager pings a known address now and then, which is how it can tell a hotel sign-in page from a real connection.")
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
        title: I18n.tr("WI-FI")

        SettingRow {
            title: I18n.tr("Wi-Fi")
            enabled: Networking.wifiHardwareEnabled
            disabledReason: I18n.tr("A hardware switch or an Fn key has the Wi-Fi radio blocked.")
            description: page.wifiOn ? (page.groups.connected.length > 0 ? I18n.tr("On, joined to %1.", page.groups.connected[0].name) : I18n.tr("On, not joined to anything.")) : I18n.tr("The radio is off, so nothing can connect.")

            M3Switch {
                enabled: Networking.wifiHardwareEnabled
                checked: page.wifiOn
                onToggled: (v) => {
                    return Networking.wifiEnabled = v;
                }
            }

        }

        SettingRow {
            title: page.scanning ? I18n.tr("Looking for networks") : I18n.tr("Networks")
            visible: page.wifiOn
            description: I18n.tr("Scanning keeps the list fresh. Turn it off and the list stops moving under your cursor.")
            stacked: true

            Row {
                width: parent.width
                spacing: Theme.dp(10)

                M3TextField {
                    width: parent.width - scanBox.implicitWidth - hiddenBtn.implicitWidth - Theme.dp(20)
                    placeholder: I18n.tr("Filter by name")
                    onEdited: (v) => {
                        return page.filter = v;
                    }
                }

                CheckLine {
                    id: scanBox

                    anchors.verticalCenter: parent.verticalCenter
                    label: I18n.tr("Keep scanning")
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
                    text: I18n.tr("Hidden network")
                    onClicked: page.hiddenForm = !page.hiddenForm
                }

            }

        }

        SettingRow {
            title: I18n.tr("Join a hidden network")
            visible: page.wifiOn && page.hiddenForm
            enabled: !Net.busy
            description: I18n.tr("A network that does not broadcast its name. Type it exactly, capitals and all.")
            stacked: true

            Row {
                width: parent.width
                spacing: Theme.dp(10)

                M3TextField {
                    width: Theme.dp(220)
                    placeholder: I18n.tr("Network name")
                    onEdited: (v) => {
                        return page.hiddenSsid = v;
                    }
                }

                M3TextField {
                    width: Theme.dp(220)
                    placeholder: I18n.tr("Password, if any")
                    onEdited: (v) => {
                        return page.hiddenPsk = v;
                    }
                }

                M3Button {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "filled"
                    text: Net.busy ? I18n.tr("Joining") : I18n.tr("Join")
                    enabled: !Net.busy && page.hiddenSsid.trim() !== ""
                    onClicked: Net.connectHidden(page.hiddenSsid.trim(), page.hiddenPsk)
                }

            }

        }

        Column {
            width: parent.width
            visible: page.wifiOn
            topPadding: Theme.dp(4)
            bottomPadding: Theme.dp(8)
            spacing: Theme.dp(2)

            GroupLabel {
                text: I18n.tr("Connected")
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
                text: I18n.tr("Saved")
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
                text: I18n.tr("Nearby")
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
                topPadding: Theme.dp(18)
                bottomPadding: Theme.dp(18)
                text: page.filter.trim() !== "" ? I18n.tr("Nothing matches that.") : I18n.tr("No networks in range.")
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
            }

        }

    }

    SettingCard {
        title: I18n.tr("SHARE THIS CONNECTION")
        visible: page.wifiOn && !!page.wifi

        SettingRow {
            title: I18n.tr("Wi-Fi hotspot")
            enabled: !Net.busy
            description: I18n.tr("Turns the Wi-Fi radio into an access point so other devices can borrow this machine's connection. It drops whatever Wi-Fi network you are on, so it only helps when the internet arrives some other way.")
            stacked: true
            showDivider: false

            Row {
                width: parent.width
                spacing: Theme.dp(10)

                M3TextField {
                    width: Theme.dp(220)
                    placeholder: I18n.tr("Hotspot name")
                    text: page.hotspotSsid
                    onEdited: (v) => {
                        return page.hotspotSsid = v;
                    }
                }

                M3TextField {
                    width: Theme.dp(220)
                    placeholder: I18n.tr("Password, 8 characters or more")
                    onEdited: (v) => {
                        return page.hotspotPsk = v;
                    }
                }

                M3Button {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    text: I18n.tr("Start hotspot")
                    enabled: !Net.busy && page.hotspotSsid.trim() !== "" && page.hotspotPsk.length >= 8
                    onClicked: Prefs.askConfirm(I18n.tr("Start a hotspot?"), I18n.tr("This drops the Wi-Fi network you are on and turns the radio into an access point named %1.", page.hotspotSsid.trim()), I18n.trc("verb", "Start"), "net-hotspot:" + page.hotspotSsid.trim() + "\n" + page.hotspotPsk)
                }

            }

        }

    }

    SettingCard {
        title: I18n.tr("WIRED")
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
                        return wiredRow.info && wiredRow.info.state === "unavailable" ? I18n.tr("No cable plugged in.") : I18n.tr("Cable plugged in, not connected.");

                    const ip = wiredRow.info && wiredRow.info.ip4.length > 0 ? wiredRow.info.ip4[0].split("/")[0] : "";
                    const speed = wiredRow.info && wiredRow.info.speed > 0 ? wiredRow.info.speed + " Mbit/s" : "";
                    return [I18n.tr("Connected"), ip, speed].filter((x) => {
                        return x !== "";
                    }).join("  ·  ");
                }
                showDivider: wiredRow.index < Net.wiredDevices.length - 1

                Row {
                    spacing: Theme.dp(14)

                    CheckLine {
                        anchors.verticalCenter: parent.verticalCenter
                        label: I18n.tr("Connect automatically")
                        checked: wiredRow.modelData.autoconnect
                        onToggled: wiredRow.modelData.autoconnect = !wiredRow.modelData.autoconnect
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "tonal"
                        visible: wiredRow.modelData.connected
                        text: I18n.tr("Disconnect")
                        onClicked: wiredRow.modelData.disconnect()
                    }

                }

            }

        }

    }

    SettingCard {
        title: I18n.tr("VPN")

        SettingRow {
            title: Net.vpns.length === 0 ? I18n.tr("No VPN set up") : (Net.activeVpn ? I18n.tr("Connected to %1", Net.activeVpn.name) : I18n.tr("Not connected"))
            description: Net.vpns.length === 0 ? I18n.tr("Lucid lists whatever NetworkManager already knows. Import a config with nmcli or nm-connection-editor and it turns up here.") : I18n.tr("One at a time, the way NetworkManager handles it.")
            showDivider: Net.vpns.length > 0
        }

        Repeater {
            model: Net.vpns

            SettingRow {
                id: vpnRow

                required property var modelData
                required property int index

                title: vpnRow.modelData.name
                description: (vpnRow.modelData.type === "wireguard" ? I18n.tr("WireGuard") : I18n.tr("VPN")) + (vpnRow.modelData.active ? I18n.tr("  ·  connected") : "")
                enabled: !Net.busy
                showDivider: vpnRow.index < Net.vpns.length - 1

                Row {
                    spacing: Theme.dp(14)

                    CheckLine {
                        anchors.verticalCenter: parent.verticalCenter
                        label: I18n.tr("Connect automatically")
                        checked: vpnRow.modelData.autoconnect
                        onToggled: Net.setAutoconnect(vpnRow.modelData.uuid, !vpnRow.modelData.autoconnect)
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: vpnRow.modelData.active ? "tonal" : "filled"
                        text: vpnRow.modelData.active ? I18n.tr("Disconnect") : I18n.tr("Connect")
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
        title: I18n.tr("SAVED CONNECTIONS")

        SettingRow {
            title: I18n.tr("Everything NetworkManager has kept")
            description: I18n.tr("A saved connection is a set of settings, not a network. Deleting one only forgets the settings.")
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
                    const kind = profRow.modelData.type === "802-11-wireless" ? "Wi-Fi" : (profRow.modelData.type === "802-3-ethernet" ? I18n.tr("Wired") : profRow.modelData.type);
                    return kind + (profRow.modelData.active ? I18n.tr("  ·  in use on %1", profRow.modelData.device) : "");
                }
                enabled: !Net.busy
                showDivider: profRow.index < Net.profiles.length - 1

                Row {
                    spacing: Theme.dp(14)

                    CheckLine {
                        anchors.verticalCenter: parent.verticalCenter
                        label: I18n.tr("Automatic")
                        checked: profRow.modelData.autoconnect
                        onToggled: Net.setAutoconnect(profRow.modelData.uuid, !profRow.modelData.autoconnect)
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "text"
                        destructive: true
                        text: I18n.tr("Delete")
                        onClicked: Prefs.askConfirm(I18n.tr("Delete this saved connection?"), I18n.tr("The settings for %1 and any password go with it. Nothing else on the machine is touched.", profRow.modelData.name), I18n.tr("Delete"), "net-delete:" + profRow.modelData.uuid)
                    }

                }

            }

        }

    }

    component GroupLabel: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitleSm
        font.variableAxes: Theme.axes(Theme.fontTitleSm, 600, 0)
        font.weight: Font.DemiBold
        font.letterSpacing: 0.1
        leftPadding: Theme.dp(22)
        topPadding: Theme.dp(14)
        bottomPadding: Theme.dp(6)
    }

}
