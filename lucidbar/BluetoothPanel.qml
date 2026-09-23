import QtQuick
import QtQuick.Shapes
import Quickshell.Bluetooth
import qs
import qs.lucidui

Item {
    id: root

    property bool active: false
    property string expandedKey: ""

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: adapter ? adapter.enabled : false
    readonly property var deviceGroups: root.computeGroups()
    readonly property var connectedDevices: root.deviceGroups.connected
    readonly property var pairedDevices: root.deviceGroups.paired
    readonly property var nearbyDevices: root.deviceGroups.nearby
    readonly property bool anyConnecting: (adapter && adapter.devices) ? adapter.devices.values.some((d) => {
        return d.state === BluetoothDeviceState.Connecting;
    }) : false
    readonly property bool discovering: !!(root.adapter && root.adapter.discovering)
    // only a scan this panel started is ours to stop; bluez refuses the rest
    property bool ownScan: false

    onDiscoveringChanged: {
        if (!root.discovering)
            root.ownScan = false;

    }

    readonly property string label: {
        if (!root.btEnabled)
            return "Off";

        if (root.connectedDevices.length === 1) {
            let d = root.connectedDevices[0];
            let batt = root.getBatteryText(d);
            return d.name + (batt !== "" ? " (" + batt + ")" : "");
        }
        if (root.connectedDevices.length > 1)
            return root.connectedDevices.length + " devices connected";

        if (root.anyConnecting)
            return "Connecting...";

        if (root.discovering)
            return "Scanning...";

        return "Not connected";
    }

    function getBatteryText(dev) {
        if (!dev || !dev.batteryAvailable)
            return "";

        let b = dev.battery;
        if (b === undefined || b === null || b < 0)
            return "";

        let pct = (b <= 1 && b > 0) ? Math.round(b * 100) : Math.round(b);
        return pct + '%';
    }

    function isMacLike(name) {
        return /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(name || "");
    }

    function deviceIconKind(iconName) {
        const n = (iconName || "").toLowerCase();
        if (n.includes("headphone") || n.includes("headset"))
            return "headphones";

        if (n.includes("phone") || n.includes("tablet"))
            return "phone";

        if (n.includes("computer") || n.includes("laptop") || n.includes("pc"))
            return "laptop";

        if (n.includes("keyboard"))
            return "keyboard";

        if (n.includes("mouse"))
            return "mouse";

        if (n.includes("speaker") || n.includes("audio") || n.includes("multimedia"))
            return "speaker";

        return "";
    }

    function computeGroups() {
        if (!root.adapter || !root.adapter.devices)
            return {
            "connected": [],
            "paired": [],
            "nearby": []
        };

        const named = root.adapter.devices.values.filter((d) => {
            return d.name && d.name.length > 0 && !root.isMacLike(d.name);
        });
        const byName = (arr) => {
            return arr.slice().sort((a, b) => {
                return a.name.localeCompare(b.name);
            });
        };
        return {
            "connected": byName(named.filter((d) => {
                return d.connected;
            })),
            "paired": byName(named.filter((d) => {
                return !d.connected && d.paired;
            })),
            "nearby": byName(named.filter((d) => {
                return !d.connected && !d.paired;
            }))
        };
    }


    implicitHeight: col.implicitHeight

    onActiveChanged: {
        if (!root.active)
            root.expandedKey = "";

    }

    Column {
        id: col

        width: root.width
        spacing: 10

        Item {
            id: scanButton

            property int dotCount: 0

            visible: root.btEnabled
            width: parent.width
            height: 44

            Timer {
                interval: 400
                running: root.discovering
                repeat: true
                onTriggered: scanButton.dotCount = (scanButton.dotCount + 1) % 4
            }

            Timer {
                interval: 20000
                running: root.discovering && root.ownScan
                onTriggered: {
                    if (root.adapter)
                        root.adapter.discovering = false;

                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.discovering ? Theme.withBlur(Theme.secondaryContainer) : Theme.withBlur(Theme.surfaceHigh)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }

                }

                StateLayer {
                    radius: parent.radius
                    tint: root.discovering ? Theme.fgSecondaryContainer : Theme.text
                    onClicked: {
                        if (!root.adapter)
                            return ;

                        root.ownScan = !root.discovering;
                        root.adapter.discovering = !root.discovering;
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Item {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        LoadingIndicator {
                            anchors.fill: parent
                            visible: root.discovering
                            color: Theme.fgSecondaryContainer
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !root.discovering
                            name: "bluetooth_searching"
                            size: 20
                            color: Theme.subtext
                        }

                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        text: root.discovering ? "Looking for devices" : "Search for devices"
                        color: root.discovering ? Theme.fgSecondaryContainer : Theme.text
                    }

                }

                LText {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.discovering
                    role: "labelMedium"
                    text: "Stop"
                    color: Theme.fgSecondaryContainer
                }

            }

        }

        Item {
            visible: root.btEnabled
            width: parent.width
            height: 34

            LText {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                role: "bodyMedium"
                color: Theme.subtext
                text: "Visible to other devices"
            }

            Switch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: !!(root.adapter && root.adapter.discoverable)
                onToggled: {
                    if (root.adapter)
                        root.adapter.discoverable = !root.adapter.discoverable;

                }
            }

        }

        Column {
            visible: !root.btEnabled
            width: parent.width
            topPadding: 20
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Bluetooth is off"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(12)
                font.variableAxes: Theme.axes(Theme.fs(12), 420, 0)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Turn it on to see nearby devices"
                color: Theme.outlineStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
            }

        }

        Column {
            id: listCol

            visible: root.btEnabled
            width: parent.width
            spacing: 14

            Column {
                width: parent.width
                spacing: 3
                visible: root.connectedDevices.length > 0

                Text {
                    text: "Connected"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 600, 0)
                    leftPadding: 4
                    bottomPadding: 3
                }

                Repeater {
                    model: root.connectedDevices

                    BtDeviceRow {
                        group: "connected"
                    }

                }

            }

            Column {
                width: parent.width
                spacing: 3
                visible: root.pairedDevices.length > 0

                Text {
                    text: "Paired"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 600, 0)
                    leftPadding: 4
                    bottomPadding: 3
                }

                Repeater {
                    model: root.pairedDevices

                    BtDeviceRow {
                        group: "paired"
                    }

                }

            }

            Column {
                width: parent.width
                spacing: 3
                visible: root.nearbyDevices.length > 0

                Text {
                    text: "Nearby"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 600, 0)
                    leftPadding: 4
                    bottomPadding: 3
                }

                Repeater {
                    model: root.nearbyDevices

                    BtDeviceRow {
                        group: "nearby"
                    }

                }

            }

            Column {
                width: parent.width
                visible: root.connectedDevices.length === 0 && root.pairedDevices.length === 0 && root.nearbyDevices.length === 0
                topPadding: 18
                bottomPadding: 6
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.discovering ? "Looking for devices…" : "No devices found"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                    font.variableAxes: Theme.axes(Theme.fs(12), 420, 0)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.discovering
                    text: "Tap “Search for devices” to scan"
                    color: Theme.outlineStrong
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
                }

            }

        }

    }

    component BtDeviceRow: Column {
        id: devItem

        required property var modelData
        required property string group
        readonly property bool isExpanded: root.expandedKey === modelData.address
        readonly property bool isConnected: modelData.connected
        readonly property string iconKind: root.deviceIconKind(modelData.icon)
        readonly property bool isConnecting: modelData.state === BluetoothDeviceState.Connecting
        readonly property bool isPairing: modelData.pairing
        readonly property bool isPaired: modelData.paired
        property bool actionFailed: false
        property bool wasBusy: false
        property bool renaming: false
        property string renameText: ""

        width: parent.width

        Connections {
            function onStateChanged() {
                if (devItem.modelData.state === BluetoothDeviceState.Connecting) {
                    devItem.wasBusy = true;
                    devItem.actionFailed = false;
                } else if (devItem.wasBusy && devItem.group !== "nearby") {
                    devItem.actionFailed = !devItem.modelData.connected;
                    devItem.wasBusy = false;
                }
            }

            function onPairingChanged() {
                if (devItem.modelData.pairing) {
                    devItem.wasBusy = true;
                    devItem.actionFailed = false;
                } else if (devItem.wasBusy && devItem.group === "nearby") {
                    devItem.wasBusy = false;
                    if (devItem.modelData.paired) {
                        devItem.actionFailed = false;
                        devItem.modelData.connect();
                    } else {
                        devItem.actionFailed = true;
                    }
                }
            }

            target: devItem.modelData
        }

        Rectangle {
            width: parent.width
            height: 56
            radius: devItem.isExpanded ? 20 : 14
            color: devItem.isExpanded ? Theme.withBlur(Theme.surfaceHighest) : (rowArea.containsMouse ? Theme.withBlur(Theme.layer(Theme.surfaceHigh, Theme.text, Theme.stateHover)) : Theme.withBlur(Theme.surfaceHigh))

            Behavior on radius {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 14
                spacing: 12

                Item {
                    width: 36
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: devItem.isConnected ? Theme.primary : Theme.alpha(Theme.text, 0.08)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(150)
                            }

                        }

                    }

                    Icon {
                        anchors.centerIn: parent
                        name: ({"headphones": "headphones", "phone": "smartphone", "laptop": "computer", "speaker": "speaker", "keyboard": "keyboard", "mouse": "mouse"})[devItem.iconKind] || "bluetooth"
                        size: 20
                        fill: devItem.isConnected ? 1 : 0
                        color: devItem.isConnected ? Theme.fgPrimary : Theme.text
                    }

                    Rectangle {
                        id: btDot

                        visible: devItem.isConnected
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.success
                        border.width: 2
                        border.color: Theme.surfaceHigh
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -2

                        // visible is the effective one, so a closed panel stops the pulse
                        // instead of driving a repaint every frame for nobody
                        SequentialAnimation on opacity {
                            running: btDot.visible
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
                    width: parent.width - 36 - 20 - 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: devItem.modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(13)
                        font.variableAxes: Theme.axes(Theme.fs(13), 560, 0)
                        elide: Text.ElideRight
                    }

                    Row {
                        width: parent.width
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (devItem.isPairing)
                                    return "Pairing…";

                                if (devItem.isConnecting)
                                    return "Connecting…";

                                if (devItem.isConnected) {
                                    let batt = root.getBatteryText(devItem.modelData);
                                    return "Connected" + (batt !== "" ? " · " + batt : "");
                                }
                                if (devItem.isPaired)
                                    return devItem.modelData.trusted ? "Paired · Trusted" : "Paired";

                                return "Available";
                            }
                            color: devItem.isConnected ? Theme.accent : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(10)
                            font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
                        }

                        Rectangle {
                            visible: devItem.isConnected && devItem.modelData.batteryAvailable
                            width: 22
                            height: 5
                            radius: 2
                            color: Theme.bgTrack
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                readonly property real pct: devItem.modelData.battery <= 1 ? devItem.modelData.battery : devItem.modelData.battery / 100

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(2, parent.width * Math.max(0, Math.min(1, pct)))
                                height: parent.height
                                radius: 2
                                color: pct < 0.2 ? Theme.error : Theme.success
                            }

                        }

                    }

                }

                Icon {
                    name: "expand_more"
                    size: 20
                    color: Theme.subtext
                    anchors.verticalCenter: parent.verticalCenter
                    rotation: devItem.isExpanded ? 180 : 0

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
                onClicked: {
                    devItem.renaming = false;
                    root.expandedKey = devItem.isExpanded ? "" : devItem.modelData.address;
                }
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
            height: devItem.isExpanded ? expandContent.implicitHeight : 0
            clip: true

            Column {
                id: expandContent

                width: parent.width
                leftPadding: 36
                rightPadding: 14
                topPadding: 6
                bottomPadding: 14
                spacing: 9
                y: devItem.isExpanded ? 0 : -8
                opacity: devItem.isExpanded ? 1 : 0

                Row {
                    width: parent.width - 46
                    height: 30
                    spacing: 8

                    Rectangle {
                        id: primaryBtn

                        readonly property bool busy: devItem.isPairing || devItem.isConnecting

                        width: devItem.group === "nearby" ? parent.width : (parent.width - 8) / 2
                        height: parent.height
                        radius: 999
                        color: busy ? Theme.withBlur(Theme.outlineStrong) : (devItem.isConnected ? Theme.accentContainer : (primaryArea.containsMouse ? Theme.accentHover : Theme.accent))
                        opacity: busy ? 0.7 : 1
                        scale: primaryArea.pressed ? 0.96 : 1

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (devItem.isPairing)
                                    return "Pairing…";

                                if (devItem.isConnecting)
                                    return "Connecting…";

                                if (devItem.group === "nearby")
                                    return "Pair";

                                return devItem.isConnected ? "Disconnect" : "Connect";
                            }
                            color: primaryBtn.busy ? Theme.subtext : (devItem.isConnected ? Theme.accent : Theme.bgOpaque)
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(12)
                            font.variableAxes: Theme.axes(Theme.fs(12), 640, 0)
                        }

                        MouseArea {
                            id: primaryArea

                            anchors.fill: parent
                            enabled: !primaryBtn.busy
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                devItem.actionFailed = false;
                                if (devItem.group === "nearby")
                                    devItem.modelData.pair();
                                else if (devItem.isConnected)
                                    devItem.modelData.disconnect();
                                else
                                    devItem.modelData.connect();
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

                        visible: devItem.group !== "nearby"
                        width: (parent.width - 8) / 2
                        height: parent.height
                        radius: 999
                        color: forgetArea.containsMouse ? Theme.withBlur(Theme.outlineStrong) : "transparent"
                        border.width: 1
                        border.color: Theme.outlineStrong
                        scale: forgetArea.pressed ? 0.96 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "Forget"
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
                                root.expandedKey = "";
                                devItem.modelData.forget();
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
                    visible: devItem.isPairing
                    text: "Cancel pairing"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    font.variableAxes: Theme.axes(Theme.fs(11), 420, 0)
                    font.underline: cancelPairArea.containsMouse

                    MouseArea {
                        id: cancelPairArea

                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: devItem.modelData.cancelPair()
                    }

                }

                Text {
                    visible: devItem.actionFailed && !devItem.isConnected && !devItem.isPairing && !devItem.isConnecting
                    width: parent.width - 46
                    text: devItem.group === "nearby" ? "Pairing failed. Please try again." : "Failed to connect. The device may be out of range."
                    color: Theme.error
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
                    wrapMode: Text.WordWrap
                }

                Flow {
                    width: parent.width - 46
                    visible: devItem.group !== "nearby"
                    spacing: 12

                    Row {
                        spacing: 8

                        Rectangle {
                            width: 15
                            height: 15
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: devItem.modelData.trusted ? Theme.accent : "transparent"
                            border.width: 1.5
                            border.color: devItem.modelData.trusted ? Theme.accent : Theme.outlineStrong

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.trusted = !devItem.modelData.trusted
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(120)
                                }

                            }

                        }

                        Text {
                            text: "Auto-reconnect"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(11)
                            font.variableAxes: Theme.axes(Theme.fs(11), 640, 0)
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.trusted = !devItem.modelData.trusted
                            }

                        }

                    }

                    Row {
                        visible: devItem.isConnected
                        spacing: 8

                        Rectangle {
                            width: 15
                            height: 15
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: devItem.modelData.wakeAllowed ? Theme.accent : "transparent"
                            border.width: 1.5
                            border.color: devItem.modelData.wakeAllowed ? Theme.accent : Theme.outlineStrong

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.wakeAllowed = !devItem.modelData.wakeAllowed
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(120)
                                }

                            }

                        }

                        Text {
                            text: "Allow wake"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(11)
                            font.variableAxes: Theme.axes(Theme.fs(11), 640, 0)
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.wakeAllowed = !devItem.modelData.wakeAllowed
                            }

                        }

                    }

                    Row {
                        spacing: 8

                        Rectangle {
                            width: 15
                            height: 15
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: devItem.modelData.blocked ? Theme.withBlur(Theme.error) : "transparent"
                            border.width: 1.5
                            border.color: devItem.modelData.blocked ? Theme.error : Theme.outlineStrong

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.blocked = !devItem.modelData.blocked
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(120)
                                }

                            }

                        }

                        Text {
                            text: "Block"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(11)
                            font.variableAxes: Theme.axes(Theme.fs(11), 640, 0)
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.blocked = !devItem.modelData.blocked
                            }

                        }

                    }

                }

                Text {
                    visible: devItem.group !== "nearby" && !devItem.renaming
                    text: "Rename"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    font.variableAxes: Theme.axes(Theme.fs(11), 420, 0)
                    font.underline: renameArea.containsMouse

                    MouseArea {
                        id: renameArea

                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            devItem.renameText = devItem.modelData.name;
                            devItem.renaming = true;
                        }
                    }

                }

                Rectangle {
                    id: renameBox

                    visible: devItem.renaming
                    width: parent.width - 46
                    height: 30
                    radius: 8
                    color: Theme.withBlur(Theme.bgSunken)
                    border.width: 1
                    border.color: renameInput.activeFocus ? Theme.accent : Theme.bgHigh

                    Connections {
                        function onRenamingChanged() {
                            if (devItem.renaming)
                                renameInput.forceActiveFocus();

                        }

                        target: devItem
                    }

                    TextInput {
                        id: renameInput

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(12)
                        font.variableAxes: Theme.axes(Theme.fs(12), 420, 0)
                        selectByMouse: true
                        text: devItem.renameText
                        Keys.onReturnPressed: {
                            if (text.trim().length > 0)
                                devItem.modelData.name = text.trim();

                            devItem.renaming = false;
                        }
                        Keys.onEscapePressed: devItem.renaming = false
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.barMs(150)
                        }

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


}
