import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs

Column {
    id: page

    property string filter: ""
    property string expandedBt: ""
    // re-read so "just now" moves on while the page is open
    property int agoTick: 0
    readonly property var adapter: Bt.adapter
    readonly property bool on: Bt.on
    readonly property bool discovering: !!(page.adapter && page.adapter.discovering)
    // only a scan this page started is ours to stop; bluez refuses the rest
    property bool ownScan: false

    onDiscoveringChanged: {
        if (!page.discovering)
            page.ownScan = false;

    }
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

    spacing: Theme.dp(26)

    function ago(ms) {
        page.agoTick;
        const s = Math.max(0, Math.round((Date.now() - ms) / 1000));
        if (s < 60)
            return "just now";

        if (s < 3600)
            return Math.round(s / 60) + " min ago";

        return new Date(ms).toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
    }

    Component.onCompleted: {
        Bt.refresh();
        if (Prefs.btScanOnOpen && page.on && page.adapter && !page.discovering) {
            page.ownScan = true;
            page.adapter.discovering = true;
        }

    }

    // scanning burns radio and battery, so it stops itself
    Timer {
        interval: 45000
        running: page.discovering && page.ownScan
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
                width: Theme.dp(260)
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
        title: "RECEIVING FILES"

        SettingRow {
            title: "Receive files"
            enabled: !!page.adapter
            disabledReason: "No Bluetooth adapter is plugged into this machine."
            description: {
                if (!Prefs.btReceive)
                    return "Files sent to this machine are turned away.";

                if (BtReceive.status === "missing")
                    return "Needs obexd, which comes in the bluez-obex package.";

                if (BtReceive.status === "taken")
                    return "Another app is already answering incoming files, so it handles them instead.";

                if (BtReceive.status === "error")
                    return BtReceive.detail !== "" ? BtReceive.detail : "Something went wrong starting the receiver.";

                if (BtReceive.status === "starting")
                    return "Starting…";

                return "Each file asks first, in a notification. Devices that haven't paired can only find this machine while “Let other devices find this one” is on.";
            }

            M3Switch {
                enabled: !!page.adapter
                checked: Prefs.btReceive
                onToggled: (v) => {
                    Prefs.btReceive = v;
                }
            }

        }

        SettingRow {
            title: "Save to"
            enabled: Prefs.btReceive
            description: BtReceive.folder !== "" ? BtReceive.pretty(BtReceive.folder) : "Your Downloads folder"
            resetKey: "btReceiveFolder"

            Row {
                spacing: 8

                M3Button {
                    text: "Open"
                    variant: "text"
                    enabled: Prefs.btReceive && BtReceive.folder !== ""
                    onClicked: BtReceive.openFolder()
                }

                M3Button {
                    text: folderPicker.running ? "Choosing…" : "Change…"
                    enabled: Prefs.btReceive && !folderPicker.running
                    onClicked: {
                        folderPicker.command = ["sh", "-c", "zenity --file-selection --directory --title='Save received files to' --filename=\"$1/\" 2>/dev/null || true", "sh", BtReceive.folder];
                        folderPicker.running = true;
                    }
                }

            }

        }

        SettingRow {
            title: "Accept from paired devices without asking"
            enabled: Prefs.btReceive
            description: "Your own phone or laptop sends straight to the folder. Anything else still asks."

            M3Switch {
                enabled: Prefs.btReceive
                checked: Prefs.btReceiveAutoPaired
                onToggled: (v) => {
                    Prefs.btReceiveAutoPaired = v;
                }
            }

        }

        Repeater {
            model: Prefs.btReceive ? BtReceive.recent : []

            delegate: SettingRow {
                required property var modelData

                title: modelData.name
                description: "From " + modelData.device + " · " + page.ago(modelData.time)

                Row {
                    spacing: 8

                    M3Button {
                        text: "Show in folder"
                        variant: "text"
                        onClicked: BtReceive.showInFolder(modelData.file)
                    }

                    M3Button {
                        text: "Open"
                        onClicked: BtReceive.openFile(modelData.file)
                    }

                }

            }

        }

    }

    Process {
        id: folderPicker

        stdout: StdioCollector {
            onStreamFinished: {
                const dir = this.text.trim();
                if (dir === "")
                    return ;

                // the default stays unset, so it follows the Downloads folder
                Prefs.btReceiveFolder = dir === BtReceive.defaultFolder ? "" : dir;
            }
        }

    }

    Timer {
        interval: 30000
        repeat: true
        running: BtReceive.recent.length > 0
        onTriggered: page.agoTick++
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
                spacing: Theme.dp(10)

                M3TextField {
                    width: parent.width - scanBtn.implicitWidth - unnamedBox.implicitWidth - autoScanBox.implicitWidth - Theme.dp(30)
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
                        if (!page.adapter)
                            return ;

                        page.ownScan = !page.discovering;
                        page.adapter.discovering = !page.discovering;

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
            topPadding: Theme.dp(4)
            bottomPadding: Theme.dp(8)
            spacing: Theme.dp(2)

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
                topPadding: Theme.dp(18)
                bottomPadding: Theme.dp(18)
                text: page.filter.trim() !== "" ? "Nothing matches “" + page.filter.trim() + "”." : (page.discovering ? "Looking for devices…" : "No devices yet. Press Search to look for some.")
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                font.variableAxes: Theme.axes(Theme.fontBody, 420, 0)
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
