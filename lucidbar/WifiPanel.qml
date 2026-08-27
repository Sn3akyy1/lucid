import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs

// The Wi-Fi / Ethernet control surface, as plain content with no pill of its
// own. It used to be a bar module in its own right (Network.qml, ~2000 lines,
// of which the outer ~400 were a copy of everybody else's pill shell); it is
// now one of the views the System panel morphs into, so the bar carries one
// fewer pill and the network state lives next to the rest of the system state
// it belongs with.
//
// The host sets `width` and `active` and reads `implicitHeight`. Everything
// below the component/function block is the same logic and the same layout
// Network.qml had - nothing about how this looks was changed in the move.
Item {
    id: root

    // true while this view is the one the System panel is showing. Drives the
    // per-row reset that used to hang off the module's own `expanded`.
    property bool active: false
    // which row in the list is opened out into its detail form
    property string expandedKey: ""

    component EthernetGlyph: Item {
        id: glyph

        property color glyphColor: Theme.subtext

        Rectangle {
            width: 10
            height: 7
            radius: 2
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 2
            color: glyph.glyphColor
        }

        Row {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Rectangle {
                width: 2
                height: 5
                color: glyph.glyphColor
            }

            Rectangle {
                width: 2
                height: 5
                color: glyph.glyphColor
            }

        }

    }

    // shared so the compact pill and the expanded list can never drift apart
    component WifiStrengthGlyph: Text {
        id: wsg

        property real strength: 0
        property bool showOff: false
        readonly property var icons: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
        readonly property real normalizedStrength: wsg.strength <= 1 ? wsg.strength * 100 : wsg.strength
        readonly property int level: Math.max(0, Math.min(4, Math.floor(wsg.normalizedStrength / 20)))

        text: wsg.showOff ? "󰤮" : wsg.icons[wsg.level]
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(15)
    }

    component NetRow: Column {
        id: netItem

        required property var modelData
        readonly property bool isExpanded: root.expandedKey === modelData.name
        readonly property bool isConnected: modelData.connected
        readonly property bool isSecured: modelData.security !== undefined && modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Owe
        readonly property var uiState: root.uiStateFor(modelData.name)
        readonly property bool isTrusted: modelData.known === true && !uiState.isUntrustedAttempt
        readonly property bool connectFailed: uiState.connectFailed
        readonly property bool attemptedWithNewPassword: uiState.attemptedWithNewPassword
        readonly property bool showPasswordInput: uiState.showPasswordInput
        readonly property string failReason: uiState.failReason
        readonly property bool isConnecting: modelData.state === ConnectionState.Connecting || (root.pendingNetworkName === modelData.name)

        width: parent.width
        onIsExpandedChanged: {
            if (isExpanded && netItem.isTrusted)
                root.fetchAutoConnect(modelData.name);
            else if (!isExpanded && !netItem.isConnected && !netItem.isConnecting)
                root.setUiState(modelData.name, {
                    "showPasswordInput": false,
                    "connectFailed": false,
                    "attemptedWithNewPassword": false,
                    "passwordText": "",
                    "failReason": ""
                });

        }

        Connections {
            function onConnectionFailed(reason) {
                if (connectTimeoutTimer.targetNetwork === netItem.modelData)
                    connectTimeoutTimer.stop();

                root.pendingNetworkName = "";
                root.setUiState(netItem.modelData.name, {
                    "connectFailed": true,
                    "failReason": root.failReasonText(reason),
                    "showPasswordInput": netItem.isSecured,
                    "isUntrustedAttempt": netItem.isSecured
                });
            }

            function onConnectedChanged() {
                if (!netItem.modelData.connected)
                    return ;

                if (connectTimeoutTimer.targetNetwork === netItem.modelData)
                    connectTimeoutTimer.stop();

                root.pendingNetworkName = "";
                root.setUiState(netItem.modelData.name, {
                    "connectFailed": false,
                    "showPasswordInput": false,
                    "attemptedWithNewPassword": false,
                    "isUntrustedAttempt": false,
                    "passwordText": "",
                    "failReason": ""
                });
                root.fetchAutoConnect(netItem.modelData.name);
            }

            target: netItem.modelData
        }

        Rectangle {
            width: parent.width
            height: 42
            radius: 12
            color: netItem.isExpanded ? Theme.withBlur(Theme.bgActive) : (rowArea.containsMouse ? Theme.withBlur(Theme.bgHover) : "transparent")

            Row {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 10

                Item {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1

                    WifiStrengthGlyph {
                        anchors.centerIn: parent
                        strength: netItem.modelData.signalStrength || 0
                        color: netItem.isConnected ? Theme.accent : Theme.subtext
                    }

                    Rectangle {
                        visible: netItem.isConnected
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.success
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -1

                        SequentialAnimation on opacity {
                            running: netItem.isConnected
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.35
                                duration: Theme.barMs(700)
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                to: 1
                                duration: Theme.barMs(700)
                                easing.type: Easing.InOutQuad
                            }

                        }

                    }

                }

                Column {
                    width: parent.width - 16 - 12 - 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: netItem.modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        elide: Text.ElideRight
                    }

                    Text {
                        text: netItem.isConnected ? "Connected · " + root.strengthLabel(netItem.modelData.signalStrength || 0) : root.strengthLabel(netItem.modelData.signalStrength || 0)
                        color: netItem.isConnected ? Theme.accent : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(10)
                    }

                }

                Text {
                    text: "▾"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    anchors.verticalCenter: parent.verticalCenter
                    rotation: netItem.isExpanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.barMs(200)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            MouseArea {
                id: rowArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expandedKey = netItem.isExpanded ? "" : netItem.modelData.name
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.barMs(150)
                }

            }

        }

        Item {
            id: expandArea

            width: parent.width
            height: netItem.isExpanded ? expandContent.implicitHeight : 0
            clip: true

            Column {
                id: expandContent

                width: parent.width
                leftPadding: 36
                rightPadding: 14
                topPadding: 6
                bottomPadding: 14
                spacing: 10
                y: netItem.isExpanded ? 0 : -8
                opacity: netItem.isExpanded ? 1 : 0

                Rectangle {
                    id: passwordBox

                    visible: netItem.showPasswordInput && !netItem.isConnected
                    width: parent.width - 46
                    height: 32
                    radius: 8
                    color: Theme.withBlur(Theme.bgSunken)
                    border.width: 1
                    border.color: netItem.connectFailed ? Theme.error : (passwordInput.activeFocus ? Theme.accent : Theme.bgHigh)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enter password..."
                        color: Theme.outlineStrong
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                        visible: !passwordInput.text && !passwordInput.activeFocus
                    }

                    TextInput {
                        id: passwordInput

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(12)
                        selectByMouse: true
                        onAccepted: {
                            if (text.length > 0)
                                root.submitPassword(netItem.modelData, text);

                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.barMs(150)
                        }

                    }

                }

                Row {
                    width: parent.width - 46
                    height: 30
                    spacing: 8

                    Rectangle {
                        id: connectBtn

                        width: (netItem.isTrusted && !netItem.showPasswordInput) ? (parent.width - 8) / 2 : parent.width
                        height: parent.height
                        radius: 999
                        color: netItem.isConnecting ? Theme.withBlur(Theme.outlineStrong) : (netItem.isConnected ? Theme.accentContainer : (connectArea.containsMouse ? Theme.accentHover : Theme.accent))
                        scale: connectArea.pressed ? 0.96 : 1

                        Text {
                            anchors.centerIn: parent
                            text: netItem.isConnecting ? "Connecting..." : (netItem.isConnected ? "Disconnect" : "Connect")
                            color: netItem.isConnecting ? Theme.subtext : (netItem.isConnected ? Theme.accent : Theme.bgOpaque)
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(12)
                        }

                        MouseArea {
                            id: connectArea

                            anchors.fill: parent
                            enabled: !netItem.isConnecting
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (netItem.isConnected) {
                                    netItem.modelData.disconnect();
                                } else if (netItem.showPasswordInput) {
                                    if (passwordInput.text.length > 0)
                                        root.submitPassword(netItem.modelData, passwordInput.text);

                                } else if (!netItem.isTrusted && netItem.isSecured) {
                                    root.setUiState(netItem.modelData.name, {
                                        "showPasswordInput": true,
                                        "connectFailed": false
                                    });
                                } else {
                                    root.attemptConnect(netItem.modelData);
                                }
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(120)
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.barMs(90)
                                easing.type: Easing.OutQuad
                            }

                        }

                    }

                    Rectangle {
                        id: forgetBtn

                        visible: netItem.isTrusted && !netItem.showPasswordInput
                        width: (parent.width - 8) / 2
                        height: parent.height
                        radius: 999
                        color: forgetArea.containsMouse ? Theme.withBlur(Theme.outlineStrong) : "transparent"
                        border.width: 1
                        border.color: Theme.outlineStrong
                        scale: forgetArea.pressed ? 0.96 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "Forget Network"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(11)
                        }

                        MouseArea {
                            id: forgetArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (netItem.isConnected)
                                    netItem.modelData.disconnect();

                                netItem.modelData.forget();
                                root.setUiState(netItem.modelData.name, {
                                    "showPasswordInput": false,
                                    "connectFailed": false,
                                    "attemptedWithNewPassword": false,
                                    "isUntrustedAttempt": false,
                                    "passwordText": "",
                                    "failReason": ""
                                });
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(120)
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.barMs(90)
                                easing.type: Easing.OutQuad
                            }

                        }

                    }

                }

                Text {
                    id: errorText

                    visible: netItem.connectFailed && !netItem.isConnected && !netItem.isConnecting
                    width: parent.width - 46
                    text: netItem.failReason || (netItem.attemptedWithNewPassword ? "Incorrect password." : "Connection failed.")
                    color: Theme.error
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    wrapMode: Text.WordWrap
                }

                Row {
                    visible: netItem.isTrusted
                    spacing: 8

                    Rectangle {
                        id: autoBox

                        readonly property bool checked: root.isAutoConnectEnabled(netItem.modelData.name)

                        width: 15
                        height: 15
                        radius: 4
                        color: checked ? Theme.accent : "transparent"
                        border.width: 1.5
                        border.color: checked ? Theme.accent : Theme.outlineStrong

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleAutoConnect(netItem.modelData.name, !autoBox.checked)
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(120)
                            }

                        }

                    }

                    Text {
                        text: "Connect automatically"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(11)
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleAutoConnect(netItem.modelData.name, !root.isAutoConnectEnabled(netItem.modelData.name))
                        }

                    }

                }

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.barMs(220)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barMs(180)
                    }

                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.barMs(240)
                    easing.type: Easing.OutCubic
                }

            }

        }

    }


    property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device;

        }
        return null;
    }
    property var wiredDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wired)
                return device;

        }
        return null;
    }
    property var activeNetwork: null
    property string pendingNetworkName: ""
    property var netUiState: ({
    })
    property var netAutoConnectState: ({
    })
    property bool hiddenFormOpen: false
    property string hiddenSsid: ""
    property string hiddenPsk: ""
    property bool hiddenFailed: false
    readonly property string hiddenErrorDetail: root.hiddenFailed ? (hiddenStderr.text.trim().length > 0 ? hiddenStderr.text.trim() : "nmcli failed to connect (no further detail available).") : ""
    readonly property bool ethernetConnected: !!(root.wiredDevice && root.wiredDevice.connected)
    readonly property bool connecting: wifiDevice && wifiDevice.state === ConnectionState.Connecting
    readonly property bool wifiConnected: wifiDevice ? wifiDevice.connected : false
    readonly property bool primaryIsEthernet: root.ethernetConnected
    readonly property var primaryDevice: root.primaryIsEthernet ? root.wiredDevice : root.wifiDevice
    readonly property int tier: root.wifiConnected ? Math.min(2, Math.floor(root.signalStrength / 25)) : -1
    readonly property real signalStrength: {
        if (!activeNetwork || activeNetwork.signalStrength === undefined)
            return 0;

        const raw = activeNetwork.signalStrength;
        return raw <= 1 ? raw * 100 : raw;
    }
    // what the System pill and its Wi-Fi tile read for a one-line summary
    readonly property string statusText: {
        if (root.primaryIsEthernet)
            return "Ethernet";

        if (root.connecting)
            return "Connecting...";

        if (root.wifiConnected && root.activeNetwork)
            return root.activeNetwork.name;

        return "Disconnected";
    }
    property real lastRx: -1
    property real lastTx: -1
    property real rxRate: 0
    property real txRate: 0
    readonly property var networkGroups: root.computeNetworkGroups()
    readonly property var connectedNetworks: root.networkGroups.connected
    readonly property var savedNetworks: root.networkGroups.saved
    readonly property var nearbyNetworks: root.networkGroups.nearby

    implicitHeight: col.implicitHeight

    onActiveChanged: {
        if (!root.active) {
            root.expandedKey = "";
            root.hiddenFormOpen = false;
            root.hiddenFailed = false;
        }
    }

    function uiStateFor(name) {
        return root.netUiState[name] || {
            "showPasswordInput": false,
            "connectFailed": false,
            "attemptedWithNewPassword": false,
            "isUntrustedAttempt": false,
            "passwordText": "",
            "failReason": ""
        };
    }

    function failReasonText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "No password saved for this network.";
        case ConnectionFailReason.WifiAuthTimeout:
            return "Authentication timed out.";
        case ConnectionFailReason.WifiClientFailed:
            return "The Wi-Fi client failed to connect.";
        case ConnectionFailReason.WifiClientDisconnected:
            return "Disconnected during the connection attempt.";
        case ConnectionFailReason.WifiNetworkLost:
            return "The network went out of range.";
        default:
            return ConnectionFailReason.toString(reason);
        }
    }

    function setUiState(name, patch) {
        const next = Object.assign({
        }, root.netUiState);
        next[name] = Object.assign({
        }, root.uiStateFor(name), patch);
        root.netUiState = next;
    }

    function isAutoConnectEnabled(name) {
        if (root.netAutoConnectState[name] !== undefined)
            return root.netAutoConnectState[name];

        return true;
    }

    function setAutoConnectState(name, enabled) {
        const next = Object.assign({
        }, root.netAutoConnectState);
        next[name] = enabled;
        root.netAutoConnectState = next;
    }

    function fetchAutoConnect(ssid) {
        getAutoconnectProc.running = false;
        getAutoconnectProc.targetSsid = ssid;
        getAutoconnectProc.command = ["nmcli", "-g", "connection.autoconnect", "connection", "show", ssid];
        getAutoconnectProc.running = true;
    }

    function toggleAutoConnect(ssid, enabled) {
        root.setAutoConnectState(ssid, enabled);
        modifyAutoconnectProc.running = false;
        modifyAutoconnectProc.targetSsid = ssid;
        modifyAutoconnectProc.command = ["nmcli", "connection", "modify", ssid, "connection.autoconnect", enabled ? "yes" : "no"];
        modifyAutoconnectProc.running = true;
    }

    function isNetworkSecured(network) {
        return network.security !== undefined && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    function attemptConnect(network) {
        root.pendingNetworkName = network.name;
        root.setUiState(network.name, {
            "connectFailed": false,
            "attemptedWithNewPassword": false,
            "failReason": ""
        });
        if (root.activeNetwork && root.activeNetwork.name !== network.name)
            root.activeNetwork.disconnect();

        connectTimeoutTimer.targetNetwork = network;
        connectTimeoutTimer.restart();
        network.connect();
    }

    function submitPassword(network, password) {
        root.pendingNetworkName = network.name;
        root.setUiState(network.name, {
            "connectFailed": false,
            "attemptedWithNewPassword": true,
            "isUntrustedAttempt": true,
            "passwordText": password,
            "failReason": ""
        });
        if (root.activeNetwork && root.activeNetwork.name !== network.name)
            root.activeNetwork.disconnect();

        connectTimeoutTimer.targetNetwork = network;
        connectTimeoutTimer.restart();
        network.connectWithPsk(password);
    }

    function strengthLabel(s) {
        if (s >= 66)
            return "Strong";

        if (s >= 33)
            return "Good";

        return "Weak";
    }

    function refreshActiveNetwork() {
        if (!root.wifiDevice)
            return ;

        let found = null;
        for (const net of root.wifiDevice.networks.values) {
            if (net.connected) {
                found = net;
                break;
            }
        }
        root.activeNetwork = found;
    }

    function computeNetworkGroups() {
        if (!root.wifiDevice || !root.wifiDevice.networks)
            return {
                "connected": [],
                "saved": [],
                "nearby": []
            };

        const byName = new Map();
        for (const n of root.wifiDevice.networks.values) {
            if (!n.name || n.name.length === 0)
                continue;

            const existing = byName.get(n.name);
            if (!existing || n.connected || (n.signalStrength || 0) > (existing.signalStrength || 0))
                byName.set(n.name, n);

        }
        const all = Array.from(byName.values());
        const bySignal = (arr) => arr.slice().sort((a, b) => (b.signalStrength || 0) - (a.signalStrength || 0));
        return {
            "connected": all.filter((n) => n.connected),
            "saved": bySignal(all.filter((n) => !n.connected && n.known)),
            "nearby": bySignal(all.filter((n) => !n.connected && !n.known))
        };
    }

    function connectivityLabel() {
        switch (Networking.connectivity) {
        case NetworkConnectivity.None:
            return "No internet access";
        case NetworkConnectivity.Portal:
            return "Sign-in required";
        case NetworkConnectivity.Limited:
            return "Limited connectivity";
        default:
            return "";
        }
    }

    function connectHidden() {
        const ssid = root.hiddenSsid.trim();
        if (ssid.length === 0)
            return ;

        root.hiddenFailed = false;
        let cmd = ["nmcli", "device", "wifi", "connect", ssid];
        if (root.hiddenPsk.length > 0)
            cmd = cmd.concat(["password", root.hiddenPsk]);

        cmd = cmd.concat(["hidden", "yes"]);
        hiddenConnectProc.running = false;
        hiddenConnectProc.command = cmd;
        hiddenConnectProc.running = true;
    }

    function formatRate(bytesPerSec) {
        const kb = bytesPerSec / 1024.0;
        return kb < 1000 ? kb.toFixed(0) + "K" : (kb / 1024).toFixed(1) + "M";
    }


    Timer {
        id: connectTimeoutTimer

        property var targetNetwork: null

        interval: 15000
        repeat: false
        onTriggered: {
            if (!targetNetwork || root.pendingNetworkName !== targetNetwork.name)
                return ;

            const secured = root.isNetworkSecured(targetNetwork);
            root.pendingNetworkName = "";
            root.setUiState(targetNetwork.name, {
                "connectFailed": true,
                "failReason": "Timed out waiting for a response from the network.",
                "showPasswordInput": secured,
                "isUntrustedAttempt": secured
            });
        }
    }

    // Trigger auto-connect on interface when Wi-Fi is re-enabled
    Process {
        id: triggerDeviceAutoconnectProc

        command: root.wifiDevice ? ["nmcli", "device", "connect", root.wifiDevice.name] : []
    }

    Timer {
        id: autoconnectTriggerTimer

        interval: 1200
        repeat: false
        onTriggered: {
            if (Networking.wifiEnabled && root.wifiDevice)
                triggerDeviceAutoconnectProc.running = true;

        }
    }

    Connections {
        function onWifiEnabledChanged() {
            if (Networking.wifiEnabled)
                autoconnectTriggerTimer.restart();

        }

        target: Networking
    }

    Process {
        id: modifyAutoconnectProc

        property string targetSsid: ""
    }

    Process {
        id: getAutoconnectProc

        property string targetSsid: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const val = this.text.trim();
                root.setAutoConnectState(getAutoconnectProc.targetSsid, val === "yes");
            }
        }

    }

    Process {
        id: hiddenConnectProc

        stderr: StdioCollector {
            id: hiddenStderr
        }

        onExited: (code) => {
            root.hiddenFailed = code !== 0;
            if (code === 0) {
                root.hiddenFormOpen = false;
                root.hiddenSsid = "";
                root.hiddenPsk = "";
            }
        }
    }

    Connections {
        function onValuesChanged() {
            root.refreshActiveNetwork();
        }

        target: root.wifiDevice ? root.wifiDevice.networks : null
    }


    Process {
        id: statsProc

        command: root.primaryDevice ? ["cat", "/sys/class/net/" + root.primaryDevice.name + "/statistics/rx_bytes", "/sys/class/net/" + root.primaryDevice.name + "/statistics/tx_bytes"] : []

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const rx = parseInt(lines[0]);
                const tx = parseInt(lines[1]);
                if (root.lastRx >= 0) {
                    root.rxRate = rx - root.lastRx;
                    root.txRate = tx - root.lastTx;
                }
                root.lastRx = rx;
                root.lastTx = tx;
            }
        }

    }

    Timer {
        interval: 1000
        running: root.primaryDevice !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refreshActiveNetwork();
            if (root.wifiConnected || root.ethernetConnected)
                statsProc.running = true;

        }
    }


    Column {
        id: col

        width: root.width
        spacing: 10

        // connectivity banner
        Item {
            visible: Networking.connectivity === NetworkConnectivity.None || Networking.connectivity === NetworkConnectivity.Portal || Networking.connectivity === NetworkConnectivity.Limited
            width: parent.width
            height: 20

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.connectivityLabel()
                color: Networking.connectivity === NetworkConnectivity.None ? Theme.error : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Networking.canCheckConnectivity
                text: "Recheck"
                color: Theme.accentMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                font.underline: recheckArea.containsMouse

                MouseArea {
                    id: recheckArea

                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Networking.checkConnectivity()
                }

            }

        }

        // ethernet
        Item {
            visible: root.wiredDevice !== null
            width: parent.width
            height: 40

            EthernetGlyph {
                id: ethIcon

                width: 16
                height: 16
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                glyphColor: root.ethernetConnected ? Theme.accent : Theme.subtext
            }

            Column {
                anchors.left: ethIcon.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "Ethernet"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                }

                Text {
                    text: {
                        if (!root.wiredDevice)
                            return "No cable connected";

                        if (root.ethernetConnected)
                            return "Connected" + (root.wiredDevice.linkSpeed > 0 ? " · " + root.wiredDevice.linkSpeed + " Mbps" : "");

                        if (root.wiredDevice.hasLink)
                            return "Cable connected · not configured";

                        return "No cable connected";
                    }
                    color: root.ethernetConnected ? Theme.accent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                }

            }

            Rectangle {
                visible: root.ethernetConnected
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 78
                height: 26
                radius: 999
                color: ethDisconnectArea.containsMouse ? Theme.outlineStrong : "transparent"
                border.width: 1
                border.color: Theme.outlineStrong

                Text {
                    anchors.centerIn: parent
                    text: "Disconnect"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(10)
                }

                MouseArea {
                    id: ethDisconnectArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.wiredDevice && root.wiredDevice.network)
                            root.wiredDevice.network.disconnect();

                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.barMs(120)
                    }

                }

            }

        }

        // wi-fi subheader
        Item {
            width: parent.width
            height: 24

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Wi-Fi"
                color: Theme.text
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fs(12)
            }

            Rectangle {
                id: wifiSwitch

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 18
                radius: 999
                color: Networking.wifiEnabled ? Theme.accent : Theme.outlineStrong

                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.bg
                    anchors.verticalCenter: parent.verticalCenter
                    x: Networking.wifiEnabled ? parent.width - width - 2 : 2

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.barMs(200)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                MouseArea {
                    anchors.fill: parent
                    enabled: Networking.wifiHardwareEnabled
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.barMs(200)
                    }

                }

            }

        }

        Text {
            visible: !Networking.wifiHardwareEnabled
            width: parent.width
            text: "Wi-Fi is disabled by a hardware switch"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(11)
            wrapMode: Text.WordWrap
        }

        Item {
            id: scanButton

            property int dotCount: 0
            readonly property bool scanning: root.wifiDevice ? root.wifiDevice.scannerEnabled : false

            visible: Networking.wifiEnabled && Networking.wifiHardwareEnabled
            width: parent.width
            height: 28

            Timer {
                interval: 400
                running: scanButton.scanning
                repeat: true
                onTriggered: scanButton.dotCount = (scanButton.dotCount + 1) % 4
            }

            Timer {
                interval: 20000
                running: scanButton.scanning
                onTriggered: {
                    if (root.wifiDevice)
                        root.wifiDevice.scannerEnabled = false;

                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: ""
                    anchors.verticalCenter: parent.verticalCenter
                    color: scanButton.scanning ? Theme.accent : (scanArea.containsMouse ? Theme.text : Theme.subtext)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.barMs(150)
                        }

                    }

                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: scanButton.scanning ? "Scanning" + ".".repeat(scanButton.dotCount) : "Search for networks"
                    color: scanButton.scanning ? Theme.accent : (scanArea.containsMouse ? Theme.text : Theme.subtext)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.barMs(150)
                        }

                    }

                }

            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                visible: scanButton.scanning
                text: "tap to stop"
                color: Theme.accentMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
            }

            MouseArea {
                id: scanArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.wifiDevice)
                        root.wifiDevice.scannerEnabled = !root.wifiDevice.scannerEnabled;

                }
            }

        }

        // network list
        Column {
            id: listCol

            visible: Networking.wifiEnabled && Networking.wifiHardwareEnabled
            width: parent.width
            spacing: 14

            Column {
                width: parent.width
                spacing: 3
                visible: root.connectedNetworks.length > 0

                Text {
                    text: "CONNECTED"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(10)
                    font.letterSpacing: 1.2
                    leftPadding: 4
                    bottomPadding: 3
                }

                Repeater {
                    model: root.connectedNetworks

                    NetRow {
                    }

                }

            }

            Column {
                width: parent.width
                spacing: 3
                visible: root.savedNetworks.length > 0

                Text {
                    text: "SAVED"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(10)
                    font.letterSpacing: 1.2
                    leftPadding: 4
                    bottomPadding: 3
                }

                Repeater {
                    model: root.savedNetworks

                    NetRow {
                    }

                }

            }

            Column {
                width: parent.width
                spacing: 3
                visible: root.nearbyNetworks.length > 0

                Text {
                    text: "NEARBY"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(10)
                    font.letterSpacing: 1.2
                    leftPadding: 4
                    bottomPadding: 3
                }

                Repeater {
                    model: root.nearbyNetworks

                    NetRow {
                    }

                }

            }

            Column {
                width: parent.width
                visible: root.connectedNetworks.length === 0 && root.savedNetworks.length === 0 && root.nearbyNetworks.length === 0
                topPadding: 18
                bottomPadding: 6
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: scanButton.scanning ? "Looking for networks…" : "No networks found"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                }

            }

            // hidden network
            Column {
                width: parent.width
                spacing: 8
                topPadding: 2

                Text {
                    visible: !root.hiddenFormOpen
                    text: "Connect to hidden network"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    font.underline: hiddenToggleArea.containsMouse
                    leftPadding: 4

                    MouseArea {
                        id: hiddenToggleArea

                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.hiddenFormOpen = true
                    }

                }

                Column {
                    width: parent.width
                    visible: root.hiddenFormOpen
                    spacing: 6
                    leftPadding: 4
                    rightPadding: 4

                    Rectangle {
                        width: parent.width - 8
                        height: 30
                        radius: 8
                        color: Theme.withBlur(Theme.bgSunken)
                        border.width: 1
                        border.color: hiddenSsidInput.activeFocus ? Theme.accent : Theme.bgHigh

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Network name (SSID)"
                            color: Theme.outlineStrong
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                            visible: !hiddenSsidInput.text && !hiddenSsidInput.activeFocus
                        }

                        TextInput {
                            id: hiddenSsidInput

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            selectByMouse: true
                            onTextChanged: root.hiddenSsid = text
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.barMs(150)
                            }

                        }

                    }

                    Rectangle {
                        width: parent.width - 8
                        height: 30
                        radius: 8
                        color: Theme.withBlur(Theme.bgSunken)
                        border.width: 1
                        border.color: root.hiddenFailed ? Theme.error : (hiddenPskInput.activeFocus ? Theme.accent : Theme.bgHigh)

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password (leave blank if open)"
                            color: Theme.outlineStrong
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                            visible: !hiddenPskInput.text && !hiddenPskInput.activeFocus
                        }

                        TextInput {
                            id: hiddenPskInput

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            selectByMouse: true
                            onTextChanged: root.hiddenPsk = text
                            onAccepted: root.connectHidden()
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.barMs(150)
                            }

                        }

                    }

                    Text {
                        visible: root.hiddenFailed
                        width: parent.width - 8
                        text: root.hiddenErrorDetail
                        color: Theme.error
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(10)
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: 8
                        height: 28

                        Rectangle {
                            width: 90
                            height: parent.height
                            radius: 999
                            color: hiddenConnectArea.containsMouse ? Theme.accentHover : Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                color: Theme.bg
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(11)
                            }

                            MouseArea {
                                id: hiddenConnectArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectHidden()
                            }

                        }

                        Rectangle {
                            width: 70
                            height: parent.height
                            radius: 999
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.outlineStrong

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(11)
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.hiddenFormOpen = false;
                                    root.hiddenFailed = false;
                                    hiddenSsidInput.text = "";
                                    hiddenPskInput.text = "";
                                }
                            }

                        }

                    }

                }

            }

        }

    }

}
