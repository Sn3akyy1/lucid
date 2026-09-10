import QtQuick
import Quickshell.Bluetooth
import qs

Column {
    id: page

    property string filter: ""
    property string expandedBt: ""
    readonly property var adapter: Bt.adapter
    readonly property bool on: Bt.on
    readonly property bool discovering: !!(page.adapter && page.adapter.discovering)
    readonly property var visibleDevices: {
        if (!page.adapter || !page.adapter.devices)
            return [];

        const macish = /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/;
        const q = page.filter.trim().toLowerCase();
        return page.adapter.devices.values.filter((d) => {
            if (!d.name || d.name.length === 0)
                return false;

            if (!Prefs.btShowUnnamed && macish.test(d.name) && !d.paired)
                return false;

            if (q !== "" && d.name.toLowerCase().indexOf(q) < 0 && d.address.toLowerCase().indexOf(q) < 0)
                return false;

            return true;
        }).sort((a, b) => {
            return a.name.localeCompare(b.name);
        });
    }
    readonly property var connectedList: page.visibleDevices.filter((d) => {
        return d.connected;
    })
    readonly property var pairedList: page.visibleDevices.filter((d) => {
        return !d.connected && d.paired;
    })
    readonly property var nearbyList: page.visibleDevices.filter((d) => {
        return !d.connected && !d.paired;
    })
    readonly property string adapterSummary: {
        if (!page.adapter)
            return "No Bluetooth adapter is plugged into this machine.";

        if (Bt.hardBlocked)
            return Bt.blockReason;

        if (!page.on)
            return "The radio is off, so nothing can connect.";

        if (page.connectedList.length === 1)
            return page.connectedList[0].name + " is connected.";

        if (page.connectedList.length > 1)
            return page.connectedList.length + " devices are connected.";

        return "On, with nothing connected.";
    }

    spacing: 26
    Component.onCompleted: {
        Bt.refresh();
        if (Prefs.btScanOnOpen && page.on && page.adapter)
            page.adapter.discovering = true;

    }

    // scanning burns radio and battery, so it stops itself
    Timer {
        interval: 45000
        running: page.discovering
        onTriggered: {
            if (page.adapter)
                page.adapter.discovering = false;

        }
    }

    Timer {
        id: dots

        property int n: 0

        interval: 420
        repeat: true
        running: page.discovering
        onTriggered: dots.n = (dots.n + 1) % 4
    }

    SettingCard {
        title: "ADAPTER"

        SettingRow {
            title: "Bluetooth"
            description: page.adapterSummary
            enabled: !!page.adapter && !Bt.hardBlocked
            disabledReason: page.adapter ? Bt.blockReason : "No Bluetooth adapter is plugged into this machine."

            M3Switch {
                enabled: !!page.adapter && !Bt.hardBlocked
                checked: page.on
                onToggled: (v) => {
                    Bt.setEnabled(v);
                }
            }

        }

        SettingRow {
            title: "Let other devices find this one"
            enabled: page.on
            disabledReason: "Turn Bluetooth on first."
            description: page.on && page.adapter && page.adapter.discoverable ? "Anything nearby can see this machine as “" + (Bt.alias !== "" ? Bt.alias : "this computer") + "” and ask to pair." : "Turn this on while you pair something that has to start the pairing itself, then turn it back off."

            M3Switch {
                enabled: page.on
                checked: !!(page.adapter && page.adapter.discoverable)
                onToggled: (v) => {
                    if (page.adapter)
                        page.adapter.discoverable = v;

                }
            }

        }

        SettingRow {
            title: "Accept pairing requests"
            enabled: page.on
            disabledReason: "Turn Bluetooth on first."
            description: "With this off, a device can see this machine but cannot pair with it."

            M3Switch {
                enabled: page.on
                checked: !!(page.adapter && page.adapter.pairable)
                onToggled: (v) => {
                    if (page.adapter)
                        page.adapter.pairable = v;

                }
            }

        }

        SettingRow {
            title: "Name other devices see"
            enabled: !!page.adapter
            description: Bt.address !== "" ? "The adapter's address is " + Bt.address + "." : "Reading the adapter…"
            warning: Bt.aliasError
            showDivider: false

            M3TextField {
                width: 260
                enabled: !!page.adapter && !Bt.aliasBusy
                placeholder: "this computer"
                text: Bt.alias
                onAccepted: (v) => {
                    return Bt.setAlias(v);
                }
            }

        }

    }

    SettingCard {
        title: "DEVICES"

        SettingRow {
            title: page.discovering ? "Searching" + ".".repeat(dots.n) : "Nearby devices"
            enabled: page.on
            disabledReason: "Turn Bluetooth on to see what is around."
            description: page.discovering ? "Leave the device you want in pairing mode. Searching stops on its own after a minute." : "Put the device into pairing mode first, then search."
            stacked: true
            showDivider: page.on

            Row {
                width: parent.width
                spacing: 10

                M3TextField {
                    width: parent.width - scanBtn.implicitWidth - unnamedBox.implicitWidth - autoScanBox.implicitWidth - 30
                    enabled: page.on
                    placeholder: "Filter by name or address"
                    onEdited: (v) => {
                        return page.filter = v;
                    }
                }

                M3Button {
                    id: scanBtn

                    anchors.verticalCenter: parent.verticalCenter
                    variant: page.discovering ? "filled" : "tonal"
                    enabled: page.on
                    text: page.discovering ? "Stop" : "Search"
                    onClicked: {
                        if (page.adapter)
                            page.adapter.discovering = !page.adapter.discovering;

                    }
                }

                CheckLine {
                    id: unnamedBox

                    anchors.verticalCenter: parent.verticalCenter
                    enabled: page.on
                    label: "Unnamed"
                    checked: Prefs.btShowUnnamed
                    onToggled: Prefs.btShowUnnamed = !Prefs.btShowUnnamed
                }

                CheckLine {
                    id: autoScanBox

                    anchors.verticalCenter: parent.verticalCenter
                    enabled: page.on
                    label: "Search when this page opens"
                    checked: Prefs.btScanOnOpen
                    onToggled: Prefs.btScanOnOpen = !Prefs.btScanOnOpen
                }

            }

        }

        Column {
            width: parent.width
            visible: page.on
            topPadding: 4
            bottomPadding: 8
            spacing: 2

            GroupLabel {
                text: "Connected"
                visible: page.connectedList.length > 0
            }

            Repeater {
                model: page.connectedList

                BtDeviceRow {
                    group: "connected"
                    expanded: page.expandedBt === modelData.address
                    onExpandRequested: page.expandedBt = expanded ? "" : modelData.address
                }

            }

            GroupLabel {
                text: "Paired"
                visible: page.pairedList.length > 0
            }

            Repeater {
                model: page.pairedList

                BtDeviceRow {
                    group: "paired"
                    expanded: page.expandedBt === modelData.address
                    onExpandRequested: page.expandedBt = expanded ? "" : modelData.address
                }

            }

            GroupLabel {
                text: "Available"
                visible: page.nearbyList.length > 0
            }

            Repeater {
                model: page.nearbyList

                BtDeviceRow {
                    group: "nearby"
                    expanded: page.expandedBt === modelData.address
                    onExpandRequested: page.expandedBt = expanded ? "" : modelData.address
                }

            }

            Text {
                width: parent.width
                visible: page.visibleDevices.length === 0
                horizontalAlignment: Text.AlignHCenter
                topPadding: 18
                bottomPadding: 18
                text: page.filter.trim() !== "" ? "Nothing matches “" + page.filter.trim() + "”." : (page.discovering ? "Looking for devices…" : "No devices yet. Press Search to look for some.")
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
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
