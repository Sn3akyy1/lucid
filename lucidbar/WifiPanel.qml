import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.lucidui
import "../lucidprefs"

Item {
    id: root

    property bool active: false
    property string expandedKey: ""

    component EthernetGlyph: Item {
        id: glyph

        property color glyphColor: Theme.subtext

        Icon {
            anchors.centerIn: parent
            name: "lan"
            size: Theme.dp(18)
            fill: 1
            color: glyph.glyphColor
        }

    }

    // shared so the pill and the list can't drift apart
    component WifiStrengthGlyph: Icon {
        id: wsg

        property real strength: 0
        property bool showOff: false
        readonly property real normalizedStrength: wsg.strength <= 1 ? wsg.strength * 100 : wsg.strength
        readonly property int level: wsg.normalizedStrength >= 80 ? 4 : (wsg.normalizedStrength >= 60 ? 3 : (wsg.normalizedStrength >= 40 ? 2 : (wsg.normalizedStrength >= 20 ? 1 : 0)))

        name: wsg.showOff ? "signal_wifi_off" : ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"][wsg.level]
        size: Theme.dp(20)
        fill: 1
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
        readonly property bool canShare: netItem.isTrusted && !netItem.showPasswordInput
        property bool sharing: false

        width: parent.width
        onIsExpandedChanged: {
            if (!isExpanded)
                netItem.sharing = false;

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
            height: Theme.dp(54)
            radius: netItem.isExpanded ? Theme.dp(20) : Theme.dp(14)
            color: netItem.isExpanded ? Theme.withBlur(Theme.surfaceHighest) : (rowArea.containsMouse ? Theme.withBlur(Theme.layer(Theme.surfaceHigh, Theme.text, Theme.stateHover)) : Theme.withBlur(Theme.surfaceHigh))

            Behavior on radius {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(14)
                anchors.rightMargin: Theme.dp(14)
                spacing: Theme.dp(14)

                Item {
                    width: Theme.dp(20)
                    height: Theme.dp(20)
                    anchors.verticalCenter: parent.verticalCenter

                    WifiStrengthGlyph {
                        anchors.centerIn: parent
                        strength: netItem.modelData.signalStrength || 0
                        color: netItem.isConnected ? Theme.accent : Theme.subtext
                    }

                    Rectangle {
                        id: netDot

                        visible: netItem.isConnected
                        width: Theme.dp(6)
                        height: Theme.dp(6)
                        radius: Theme.dp(3)
                        color: Theme.success
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -1

                        // visible is the effective one, so a closed panel stops the pulse
                        // instead of driving a repaint every frame for nobody
                        SequentialAnimation on opacity {
                            running: netDot.visible
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
                    width: parent.width - Theme.dp(20) - Theme.dp(18) - Theme.dp(28)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: netItem.modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(13)
                        font.variableAxes: Theme.axes(Theme.fs(13), 560, 0)
                        elide: Text.ElideRight
                    }

                    Text {
                        text: netItem.isConnected ? "Connected · " + root.strengthLabel(root.pct(netItem.modelData.signalStrength || 0)) : root.strengthLabel(root.pct(netItem.modelData.signalStrength || 0)) + (netItem.isSecured ? "" : " · Open")
                        color: netItem.isConnected ? Theme.accent : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                        font.variableAxes: Theme.axes(Theme.fs(11), 420, 0)
                    }

                }

                Icon {
                    name: "expand_more"
                    size: Theme.dp(20)
                    color: Theme.subtext
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
                leftPadding: Theme.dp(36)
                rightPadding: Theme.dp(14)
                topPadding: Theme.dp(6)
                bottomPadding: Theme.dp(14)
                spacing: Theme.dp(10)
                y: netItem.isExpanded ? 0 : -Theme.dp(8)
                opacity: netItem.isExpanded ? 1 : 0

                Rectangle {
                    id: passwordBox

                    visible: netItem.showPasswordInput && !netItem.isConnected
                    width: parent.width - Theme.dp(46)
                    height: Theme.dp(32)
                    radius: Theme.dp(8)
                    color: Theme.withBlur(Theme.bgSunken)
                    border.width: 1
                    border.color: netItem.connectFailed ? Theme.error : (passwordInput.activeFocus ? Theme.accent : Theme.bgHigh)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enter password..."
                        color: Theme.outlineStrong
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                        font.variableAxes: Theme.axes(Theme.fs(11), 420, 0)
                        visible: !passwordInput.text && !passwordInput.activeFocus
                    }

                    TextInput {
                        id: passwordInput

                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(10)
                        anchors.rightMargin: Theme.dp(10)
                        verticalAlignment: Text.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(12)
                        font.variableAxes: Theme.axes(Theme.fs(12), 420, 0)
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
                    width: parent.width - Theme.dp(46)
                    height: Theme.dp(30)
                    spacing: Theme.dp(8)

                    Rectangle {
                        id: connectBtn

                        width: netItem.canShare ? (parent.width - shareBtn.width - Theme.dp(16)) / 2 : parent.width
                        height: parent.height
                        radius: Theme.dp(999)
                        color: netItem.isConnecting ? Theme.withBlur(Theme.outlineStrong) : (netItem.isConnected ? Theme.accentContainer : (connectArea.containsMouse ? Theme.accentHover : Theme.accent))
                        scale: connectArea.pressed ? 0.96 : 1

                        Text {
                            anchors.centerIn: parent
                            text: netItem.isConnecting ? "Connecting..." : (netItem.isConnected ? "Disconnect" : "Connect")
                            color: netItem.isConnecting ? Theme.subtext : (netItem.isConnected ? Theme.accent : Theme.bgOpaque)
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(12)
                            font.variableAxes: Theme.axes(Theme.fs(12), 640, 0)
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

                        visible: netItem.canShare
                        width: (parent.width - shareBtn.width - Theme.dp(16)) / 2
                        height: parent.height
                        radius: Theme.dp(999)
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
                            font.variableAxes: Theme.axes(Theme.fs(11), 640, 0)
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

                    Rectangle {
                        id: shareBtn

                        visible: netItem.canShare
                        width: Theme.dp(30)
                        height: Theme.dp(30)
                        radius: Theme.dp(999)
                        color: netItem.sharing ? Theme.accentContainer : (shareArea.containsMouse ? Theme.withBlur(Theme.outlineStrong) : "transparent")
                        border.width: netItem.sharing ? 0 : 1
                        border.color: Theme.outlineStrong
                        scale: shareArea.pressed ? 0.94 : 1

                        Icon {
                            anchors.centerIn: parent
                            name: "qr_code"
                            size: Theme.dp(16)
                            fill: netItem.sharing ? 1 : 0
                            color: netItem.sharing ? Theme.accent : Theme.text
                        }

                        MouseArea {
                            id: shareArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: netItem.sharing = !netItem.sharing
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

                Loader {
                    width: parent.width - Theme.dp(46)
                    active: netItem.sharing && netItem.isExpanded && root.active
                    visible: active

                    sourceComponent: WifiShare {
                        ssid: netItem.modelData.name
                        compact: true
                    }

                }

                Text {
                    id: errorText

                    visible: netItem.connectFailed && !netItem.isConnected && !netItem.isConnecting
                    width: parent.width - Theme.dp(46)
                    text: netItem.failReason || (netItem.attemptedWithNewPassword ? "Incorrect password." : "Connection failed.")
                    color: Theme.error
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
                    wrapMode: Text.WordWrap
                }

                Row {
                    visible: netItem.isTrusted
                    spacing: Theme.dp(8)

                    Rectangle {
                        id: autoBox

                        readonly property bool checked: root.isAutoConnectEnabled(netItem.modelData.name)

                        width: Theme.dp(15)
                        height: Theme.dp(15)
                        radius: Theme.dp(4)
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
                        font.variableAxes: Theme.axes(Theme.fs(11), 640, 0)
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

    // networkmanager reports 0..1; some callers already hold a percentage
    function pct(s) {
        return s <= 1 ? s * 100 : s;
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

    // auto-connect when wi-fi is re-enabled
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
        spacing: Theme.dp(10)

        Item {
            visible: Networking.connectivity === NetworkConnectivity.None || Networking.connectivity === NetworkConnectivity.Portal || Networking.connectivity === NetworkConnectivity.Limited
            width: parent.width
            height: Theme.dp(20)

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.connectivityLabel()
                color: Networking.connectivity === NetworkConnectivity.None ? Theme.error : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                font.variableAxes: Theme.axes(Theme.fs(11), 420, 0)
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Networking.canCheckConnectivity
                text: "Recheck"
                color: Theme.accentMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
                font.underline: recheckArea.containsMouse

                MouseArea {
                    id: recheckArea

                    anchors.fill: parent
                    anchors.margins: -Theme.dp(4)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Networking.checkConnectivity()
                }

            }

        }

        Item {
            visible: root.wiredDevice !== null
            width: parent.width
            height: Theme.dp(40)

            EthernetGlyph {
                id: ethIcon

                width: Theme.dp(16)
                height: Theme.dp(16)
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                glyphColor: root.ethernetConnected ? Theme.accent : Theme.subtext
            }

            Column {
                anchors.left: ethIcon.right
                anchors.leftMargin: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "Ethernet"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 640, 0)
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
                    font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
                }

            }

            Rectangle {
                visible: root.ethernetConnected
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(78)
                height: Theme.dp(26)
                radius: Theme.dp(999)
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
                    font.variableAxes: Theme.axes(Theme.fs(10), 640, 0)
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

        Text {
            visible: !Networking.wifiHardwareEnabled
            width: parent.width
            text: "Wi-Fi is disabled by a hardware switch"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(11)
            font.variableAxes: Theme.axes(Theme.fs(11), 420, 0)
            wrapMode: Text.WordWrap
        }

        Item {
            id: scanButton

            property int dotCount: 0
            readonly property bool scanning: root.wifiDevice ? root.wifiDevice.scannerEnabled : false

            visible: Networking.wifiEnabled && Networking.wifiHardwareEnabled
            width: parent.width
            height: Theme.dp(44)

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

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: scanButton.scanning ? Theme.withBlur(Theme.secondaryContainer) : Theme.withBlur(Theme.surfaceHigh)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }

                }

                StateLayer {
                    radius: parent.radius
                    tint: scanButton.scanning ? Theme.fgSecondaryContainer : Theme.text
                    onClicked: {
                        if (root.wifiDevice)
                            root.wifiDevice.scannerEnabled = !root.wifiDevice.scannerEnabled;

                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(10)

                    Item {
                        width: Theme.dp(24)
                        height: Theme.dp(24)
                        anchors.verticalCenter: parent.verticalCenter

                        LoadingIndicator {
                            anchors.fill: parent
                            visible: scanButton.scanning
                            color: Theme.fgSecondaryContainer
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !scanButton.scanning
                            name: "wifi_find"
                            size: Theme.dp(20)
                            color: Theme.subtext
                        }

                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        text: scanButton.scanning ? "Looking for networks" : "Search for networks"
                        color: scanButton.scanning ? Theme.fgSecondaryContainer : Theme.text
                    }

                }

                LText {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(16)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: scanButton.scanning
                    role: "labelMedium"
                    text: "Stop"
                    color: Theme.fgSecondaryContainer
                }

            }

        }

        Column {
            id: listCol

            visible: Networking.wifiEnabled && Networking.wifiHardwareEnabled
            width: parent.width
            spacing: Theme.dp(14)

            Column {
                width: parent.width
                spacing: Theme.dp(3)
                visible: root.connectedNetworks.length > 0

                Text {
                    text: "Connected"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 600, 0)
                    leftPadding: Theme.dp(4)
                    bottomPadding: Theme.dp(3)
                }

                Repeater {
                    model: root.connectedNetworks

                    NetRow {
                    }

                }

            }

            Column {
                width: parent.width
                spacing: Theme.dp(3)
                visible: root.savedNetworks.length > 0

                Text {
                    text: "Saved"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 600, 0)
                    leftPadding: Theme.dp(4)
                    bottomPadding: Theme.dp(3)
                }

                Repeater {
                    model: root.savedNetworks

                    NetRow {
                    }

                }

            }

            Column {
                width: parent.width
                spacing: Theme.dp(3)
                visible: root.nearbyNetworks.length > 0

                Text {
                    text: "Nearby"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 600, 0)
                    leftPadding: Theme.dp(4)
                    bottomPadding: Theme.dp(3)
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
                topPadding: Theme.dp(18)
                bottomPadding: Theme.dp(6)
                spacing: Theme.dp(4)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: scanButton.scanning ? "Looking for networks…" : "No networks found"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 420, 0)
                }

            }

            Column {
                width: parent.width
                spacing: Theme.dp(8)
                topPadding: Theme.dp(2)

                Text {
                    visible: !root.hiddenFormOpen
                    text: "Connect to hidden network"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    font.variableAxes: Theme.axes(Theme.fs(11), 420, 0)
                    font.underline: hiddenToggleArea.containsMouse
                    leftPadding: Theme.dp(4)

                    MouseArea {
                        id: hiddenToggleArea

                        anchors.fill: parent
                        anchors.margins: -Theme.dp(4)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.hiddenFormOpen = true
                    }

                }

                Column {
                    width: parent.width
                    visible: root.hiddenFormOpen
                    spacing: Theme.dp(6)
                    leftPadding: Theme.dp(4)
                    rightPadding: Theme.dp(4)

                    Rectangle {
                        width: parent.width - Theme.dp(8)
                        height: Theme.dp(30)
                        radius: Theme.dp(8)
                        color: Theme.withBlur(Theme.bgSunken)
                        border.width: 1
                        border.color: hiddenSsidInput.activeFocus ? Theme.accent : Theme.bgHigh

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.dp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Network name (SSID)"
                            color: Theme.outlineStrong
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                            font.variableAxes: Theme.axes(Theme.fs(11), 420, 0)
                            visible: !hiddenSsidInput.text && !hiddenSsidInput.activeFocus
                        }

                        TextInput {
                            id: hiddenSsidInput

                            anchors.fill: parent
                            anchors.leftMargin: Theme.dp(10)
                            anchors.rightMargin: Theme.dp(10)
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            font.variableAxes: Theme.axes(Theme.fs(12), 420, 0)
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
                        width: parent.width - Theme.dp(8)
                        height: Theme.dp(30)
                        radius: Theme.dp(8)
                        color: Theme.withBlur(Theme.bgSunken)
                        border.width: 1
                        border.color: root.hiddenFailed ? Theme.error : (hiddenPskInput.activeFocus ? Theme.accent : Theme.bgHigh)

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.dp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password (leave blank if open)"
                            color: Theme.outlineStrong
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                            font.variableAxes: Theme.axes(Theme.fs(11), 420, 0)
                            visible: !hiddenPskInput.text && !hiddenPskInput.activeFocus
                        }

                        TextInput {
                            id: hiddenPskInput

                            anchors.fill: parent
                            anchors.leftMargin: Theme.dp(10)
                            anchors.rightMargin: Theme.dp(10)
                            verticalAlignment: Text.AlignVCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            font.variableAxes: Theme.axes(Theme.fs(12), 420, 0)
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
                        width: parent.width - Theme.dp(8)
                        text: root.hiddenErrorDetail
                        color: Theme.error
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(10)
                        font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: Theme.dp(8)
                        height: Theme.dp(28)

                        Rectangle {
                            width: Theme.dp(90)
                            height: parent.height
                            radius: Theme.dp(999)
                            color: hiddenConnectArea.containsMouse ? Theme.accentHover : Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                color: Theme.bg
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(11)
                                font.variableAxes: Theme.axes(Theme.fs(11), 640, 0)
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
                            width: Theme.dp(70)
                            height: parent.height
                            radius: Theme.dp(999)
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
                                font.variableAxes: Theme.axes(Theme.fs(11), 640, 0)
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
