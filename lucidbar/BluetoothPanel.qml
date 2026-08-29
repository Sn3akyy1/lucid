import QtQuick
import QtQuick.Shapes
import Quickshell.Bluetooth
import qs

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
            height: 28

            Timer {
                interval: 400
                running: root.discovering
                repeat: true
                onTriggered: scanButton.dotCount = (scanButton.dotCount + 1) % 4
            }

            Timer {
                interval: 20000
                running: root.discovering
                onTriggered: {
                    if (root.adapter)
                        root.adapter.discovering = false;

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
                    color: root.discovering ? Theme.accent : (scanArea.containsMouse ? Theme.text : Theme.subtext)
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
                    text: root.discovering ? "Searching" + ".".repeat(scanButton.dotCount) : "Search for devices"
                    color: root.discovering ? Theme.accent : (scanArea.containsMouse ? Theme.text : Theme.subtext)
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
                visible: root.discovering
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
                    if (root.adapter)
                        root.adapter.discovering = !root.adapter.discovering;

                }
            }

        }

        Item {
            visible: root.btEnabled
            width: parent.width
            height: 22

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "Visible to other devices"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 16
                radius: 999
                color: (root.adapter && root.adapter.discoverable) ? Theme.accent : Theme.outlineStrong

                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.bg
                    anchors.verticalCenter: parent.verticalCenter
                    x: (root.adapter && root.adapter.discoverable) ? parent.width - width - 2 : 2

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.barMs(200)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.adapter)
                            root.adapter.discoverable = !root.adapter.discoverable;

                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.barMs(200)
                    }

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
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Turn it on to see nearby devices"
                color: Theme.outlineStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
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
                    text: "PAIRED"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(10)
                    font.letterSpacing: 1.2
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
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.discovering
                    text: "Tap “Search for devices” to scan"
                    color: Theme.outlineStrong
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                }

            }

        }

    }

    component BluetoothGlyph: Shape {
        id: glyph

        property color glyphColor: Theme.subtext

        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: glyph.glyphColor
            strokeWidth: 0

            PathSvg {
                path: "M17.71,7.71L12,2H11V9.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L11,14.41V22H12L17.71,16.29L13.41,12L17.71,7.71M13,5.83L15.17,8L13,10.17V5.83M13,13.83L15.17,16L13,18.17V13.83Z"
            }

        }

    }

    component HeadphonesGlyph: Shape {
        id: hpGlyph

        property color glyphColor: Theme.subtext

        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: hpGlyph.glyphColor
            strokeWidth: 0

            PathSvg {
                path: "M12,3A9,9 0 0,0 3,12V19A3,3 0 0,0 6,22H8V13H5V12A7,7 0 0,1 12,5A7,7 0 0,1 19,12V13H16V22H18A3,3 0 0,0 21,19V12A9,9 0 0,0 12,3Z"
            }

        }

    }

    component PhoneGlyph: Shape {
        id: phGlyph

        property color glyphColor: Theme.subtext

        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: phGlyph.glyphColor
            strokeWidth: 0

            PathSvg {
                path: "M17,19H7V5H17M17,1H7C5.89,1 5,1.89 5,3V21A2,2 0 0,0 7,23H17A2,2 0 0,0 19,21V3C19,1.89 18.1,1 17,1Z"
            }

        }

    }

    component LaptopGlyph: Shape {
        id: lpGlyph

        property color glyphColor: Theme.subtext

        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: lpGlyph.glyphColor
            strokeWidth: 0

            PathSvg {
                path: "M4,6H20V16H4M20,18A2,2 0 0,0 22,16V6C22,4.89 21.1,4 20,4H4C2.89,4 2,4.89 2,6V16A2,2 0 0,0 4,18H0V20H24V18H20Z"
            }

        }

    }

    component SpeakerGlyph: Shape {
        id: spGlyph

        property color glyphColor: Theme.subtext

        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: spGlyph.glyphColor
            strokeWidth: 0

            PathSvg {
                path: "M17,2H7C5.9,2 5,2.9 5,4V20C5,21.1 5.9,22 7,22H17C18.1,22 19,21.1 19,20V4C19,2.9 18.1,2 17,2M12,20C10.34,20 9,18.66 9,17C9,15.34 10.34,14 12,14C13.66,14 15,15.34 15,17C15,18.66 13.66,20 12,20M12,10C10.34,10 9,8.66 9,7C9,5.34 10.34,4 12,4C13.66,4 15,5.34 15,7C15,8.66 13.66,10 12,10Z"
            }

        }

    }

    component KeyboardGlyph: Item {
        id: kbGlyph

        property color glyphColor: Theme.subtext

        width: 16
        height: 16

        Rectangle {
            anchors.centerIn: parent
            width: 15
            height: 10
            radius: 2
            color: "transparent"
            border.width: 1.4
            border.color: kbGlyph.glyphColor
        }

        Grid {
            anchors.centerIn: parent
            columns: 4
            rows: 2
            spacing: 1.6

            Repeater {
                model: 8

                Rectangle {
                    width: 1.6
                    height: 1.6
                    radius: 0.4
                    color: kbGlyph.glyphColor
                }

            }

        }

    }

    component MouseGlyph: Item {
        id: msGlyph

        property color glyphColor: Theme.subtext

        width: 16
        height: 16

        Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 14
            radius: 5
            color: "transparent"
            border.width: 1.4
            border.color: msGlyph.glyphColor
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 2
            width: 1.4
            height: 5
            radius: 0.7
            color: msGlyph.glyphColor
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
            height: 42
            radius: 12
            color: devItem.isExpanded ? Theme.withBlur(Theme.bgActive) : (rowArea.containsMouse ? Theme.withBlur(Theme.bgHover) : "transparent")

            Row {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 10

                Item {
                    width: 26
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: Theme.alpha(Theme.accent, devItem.isConnected ? 0.22 : 0.12)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(150)
                            }

                        }

                    }

                    HeadphonesGlyph {
                        anchors.centerIn: parent
                        scale: 15 / 24
                        visible: devItem.iconKind === "headphones"
                        glyphColor: Theme.accent
                    }

                    PhoneGlyph {
                        anchors.centerIn: parent
                        scale: 13 / 24
                        visible: devItem.iconKind === "phone"
                        glyphColor: Theme.accent
                    }

                    LaptopGlyph {
                        anchors.centerIn: parent
                        scale: 15 / 24
                        visible: devItem.iconKind === "laptop"
                        glyphColor: Theme.accent
                    }

                    SpeakerGlyph {
                        anchors.centerIn: parent
                        scale: 14 / 24
                        visible: devItem.iconKind === "speaker"
                        glyphColor: Theme.accent
                    }

                    KeyboardGlyph {
                        anchors.centerIn: parent
                        visible: devItem.iconKind === "keyboard"
                        glyphColor: Theme.accent
                    }

                    MouseGlyph {
                        anchors.centerIn: parent
                        visible: devItem.iconKind === "mouse"
                        glyphColor: Theme.accent
                    }

                    BluetoothGlyph {
                        anchors.centerIn: parent
                        scale: 12 / 24
                        visible: devItem.iconKind === ""
                        glyphColor: Theme.accent
                    }

                    Rectangle {
                        visible: devItem.isConnected
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.success
                        border.width: 1.5
                        border.color: Theme.bg
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -2

                        SequentialAnimation on opacity {
                            running: devItem.isConnected
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
                    width: parent.width - 26 - 12 - 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: devItem.modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
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

                Text {
                    text: "▾"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
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
