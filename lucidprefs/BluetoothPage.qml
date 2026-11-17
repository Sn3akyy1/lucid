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
            return I18n.tr("No Bluetooth adapter is plugged into this machine.");

        if (Bt.hardBlocked)
            return Bt.blockReason;

        if (!page.on)
            return I18n.tr("The radio is off, so nothing can connect.");

        if (page.connectedList.length === 1)
            return I18n.tr("%1 is connected.", page.connectedList[0].name);

        if (page.connectedList.length > 1)
            return I18n.tr("%1 devices are connected.", page.connectedList.length);

        return I18n.tr("On, with nothing connected.");
    }

    spacing: Theme.dp(26)

    function ago(ms) {
        page.agoTick;
        const s = Math.max(0, Math.round((Date.now() - ms) / 1000));
        if (s < 60)
            return I18n.tr("just now");

        if (s < 3600)
            return I18n.tr("%1 min ago", Math.round(s / 60));

        return new Date(ms).toLocaleTimeString(I18n.locale, Locale.ShortFormat);
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
        title: I18n.tr("ADAPTER")

        SettingRow {
            title: I18n.tr("Bluetooth")
            description: page.adapterSummary
            enabled: !!page.adapter && !Bt.hardBlocked
            disabledReason: page.adapter ? Bt.blockReason : I18n.tr("No Bluetooth adapter is plugged into this machine.")

            M3Switch {
                enabled: !!page.adapter && !Bt.hardBlocked
                checked: page.on
                onToggled: (v) => {
                    Bt.setEnabled(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Let other devices find this one")
            enabled: page.on
            disabledReason: I18n.tr("Turn Bluetooth on first.")
            description: page.on && page.adapter && page.adapter.discoverable ? I18n.tr("Anything nearby can see this machine as “") + (Bt.alias !== "" ? Bt.alias : I18n.tr("this computer")) + I18n.tr("” and ask to pair.") : I18n.tr("Turn this on while you pair something that has to start the pairing itself, then turn it back off.")

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
            title: I18n.tr("Accept pairing requests")
            enabled: page.on
            disabledReason: I18n.tr("Turn Bluetooth on first.")
            description: I18n.tr("With this off, a device can see this machine but cannot pair with it.")

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
            title: I18n.tr("Answer pairing questions")
            enabled: !!page.adapter
            disabledReason: I18n.tr("No Bluetooth adapter is plugged into this machine.")
            description: {
                if (!Prefs.btAgent)
                    return I18n.tr("Off: another app, Blueman say, has to answer bluez, or codes to confirm go unanswered.");

                if (BtAgent.status === "missing")
                    return "bluetoothd isn't running.";

                if (BtAgent.status === "error")
                    return BtAgent.detail !== "" ? BtAgent.detail : I18n.tr("Something went wrong starting the agent.");

                return I18n.tr("Codes to confirm come up as notifications, and paired devices may open their audio and input profiles. Turn it off to leave this to another app.");
            }

            M3Switch {
                enabled: !!page.adapter
                checked: Prefs.btAgent
                onToggled: (v) => {
                    Prefs.btAgent = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Name other devices see")
            enabled: !!page.adapter
            description: Bt.address !== "" ? I18n.tr("The adapter's address is %1.", Bt.address) : I18n.tr("Reading the adapter…")
            warning: Bt.aliasError
            showDivider: false

            M3TextField {
                width: Theme.dp(260)
                enabled: !!page.adapter && !Bt.aliasBusy
                placeholder: I18n.tr("this computer")
                text: Bt.alias
                onAccepted: (v) => {
                    return Bt.setAlias(v);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("RECEIVING FILES")

        SettingRow {
            title: I18n.tr("Receive files")
            enabled: !!page.adapter
            disabledReason: I18n.tr("No Bluetooth adapter is plugged into this machine.")
            description: {
                if (!Prefs.btReceive)
                    return I18n.tr("Files sent to this machine are turned away.");

                if (BtReceive.status === "missing")
                    return I18n.tr("Needs obexd, which comes in the bluez-obex package.");

                if (BtReceive.status === "taken")
                    return I18n.tr("Another app is already answering incoming files, so it handles them instead.");

                if (BtReceive.status === "error")
                    return BtReceive.detail !== "" ? BtReceive.detail : I18n.tr("Something went wrong starting the receiver.");

                if (BtReceive.status === "starting")
                    return "Starting…";

                return I18n.tr("Each file asks first, in a notification. Devices that haven't paired can only find this machine while “Let other devices find this one” is on.");
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
            title: I18n.tr("Save to")
            enabled: Prefs.btReceive
            description: BtReceive.folder !== "" ? BtReceive.pretty(BtReceive.folder) : I18n.tr("Your Downloads folder")
            resetKey: "btReceiveFolder"

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    text: I18n.tr("Open")
                    variant: "text"
                    enabled: Prefs.btReceive && BtReceive.folder !== ""
                    onClicked: BtReceive.openFolder()
                }

                M3Button {
                    text: folderPicker.running ? I18n.tr("Choosing…") : I18n.tr("Change…")
                    enabled: Prefs.btReceive && !folderPicker.running
                    onClicked: {
                        folderPicker.command = ["python3", Qt.resolvedUrl("pickfile.py").toString().replace("file://", ""), "--directory", "--title", "Save received files to", "--file", BtReceive.folder];
                        folderPicker.running = true;
                    }
                }

            }

        }

        SettingRow {
            title: I18n.tr("Accept from paired devices without asking")
            enabled: Prefs.btReceive
            description: I18n.tr("Your own phone or laptop sends straight to the folder. Anything else still asks.")

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
                description: I18n.tr("From %1 · %2", modelData.device, page.ago(modelData.time))

                Row {
                    spacing: Theme.dp(8)

                    M3Button {
                        text: I18n.tr("Show in folder")
                        variant: "text"
                        onClicked: BtReceive.showInFolder(modelData.file)
                    }

                    M3Button {
                        text: I18n.tr("Open")
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
        title: I18n.tr("DEVICES")

        SettingRow {
            title: page.discovering ? I18n.tr("Searching%1", ".".repeat(dots.n)) : I18n.tr("Nearby devices")
            enabled: page.on
            disabledReason: I18n.tr("Turn Bluetooth on to see what is around.")
            description: page.discovering ? I18n.tr("Leave the device you want in pairing mode. Searching stops on its own after a minute.") : I18n.tr("Put the device into pairing mode first, then search.")
            stacked: true
            showDivider: page.on

            Row {
                width: parent.width
                spacing: Theme.dp(10)

                M3TextField {
                    width: parent.width - scanBtn.implicitWidth - unnamedBox.implicitWidth - autoScanBox.implicitWidth - Theme.dp(30)
                    enabled: page.on
                    placeholder: I18n.tr("Filter by name or address")
                    onEdited: (v) => {
                        return page.filter = v;
                    }
                }

                M3Button {
                    id: scanBtn

                    anchors.verticalCenter: parent.verticalCenter
                    variant: page.discovering ? "filled" : "tonal"
                    enabled: page.on
                    text: page.discovering ? I18n.tr("Stop") : I18n.tr("Search")
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
                    label: I18n.tr("Unnamed")
                    checked: Prefs.btShowUnnamed
                    onToggled: Prefs.btShowUnnamed = !Prefs.btShowUnnamed
                }

                CheckLine {
                    id: autoScanBox

                    anchors.verticalCenter: parent.verticalCenter
                    enabled: page.on
                    label: I18n.tr("Search when this page opens")
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
                text: I18n.tr("Connected")
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
                text: I18n.tr("Paired")
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
                text: I18n.tr("Available")
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
                text: page.filter.trim() !== "" ? I18n.tr("Nothing matches “%1”.", page.filter.trim()) : (page.discovering ? I18n.tr("Looking for devices…") : I18n.tr("No devices yet. Press Search to look for some."))
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
