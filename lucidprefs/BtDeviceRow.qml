import QtQuick
import Quickshell.Bluetooth
import qs
import qs.lucidui

Column {
    id: dev

    required property var modelData
    property string group: "paired"
    property bool expanded: false
    property bool renaming: false
    property bool actionFailed: false
    property bool wasBusy: false
    readonly property bool isConnected: dev.modelData.connected
    readonly property bool isPaired: dev.modelData.paired
    readonly property bool isPairing: dev.modelData.pairing
    readonly property bool isConnecting: dev.modelData.state === BluetoothDeviceState.Connecting
    readonly property bool busy: dev.isPairing || dev.isConnecting
    readonly property var card: Bt.cardFor(dev.modelData.address)
    readonly property int batteryPct: {
        if (!dev.modelData.batteryAvailable)
            return -1;

        const b = dev.modelData.battery;
        if (b === undefined || b === null || b < 0)
            return -1;

        return Math.round(b <= 1 && b > 0 ? b * 100 : b);
    }
    readonly property string status: {
        if (dev.isPairing)
            return "Pairing…";

        if (dev.isConnecting)
            return "Connecting…";

        if (dev.isConnected)
            return dev.modelData.trusted ? "Connected · reconnects on its own" : "Connected";

        if (dev.isPaired)
            return dev.modelData.blocked ? "Paired · blocked" : (dev.modelData.trusted ? "Paired · reconnects on its own" : "Paired");

        return "Not paired yet";
    }

    signal expandRequested()

    width: parent ? parent.width : Theme.dp(400)

    // bluez reports failure only by going quiet again, so watch the transitions
    Connections {
        function onStateChanged() {
            if (dev.modelData.state === BluetoothDeviceState.Connecting) {
                dev.wasBusy = true;
                dev.actionFailed = false;
            } else if (dev.wasBusy && dev.group !== "nearby") {
                dev.actionFailed = !dev.modelData.connected;
                dev.wasBusy = false;
            }
        }

        function onPairingChanged() {
            if (dev.modelData.pairing) {
                dev.wasBusy = true;
                dev.actionFailed = false;
            } else if (dev.wasBusy && dev.group === "nearby") {
                dev.wasBusy = false;
                dev.actionFailed = !dev.modelData.paired;
                if (dev.modelData.paired)
                    dev.modelData.connect();

            }
        }

        target: dev.modelData
    }

    Rectangle {
        id: head

        width: parent.width
        height: Theme.dp(62)
        radius: Theme.radiusMd
        color: dev.expanded ? Theme.bgHover : (headArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

        Item {
            id: iconTile

            width: Theme.dp(40)
            height: Theme.dp(40)
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(11)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.rad(13)
                color: Theme.alpha(Theme.accent, dev.isConnected ? 0.24 : 0.11)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            DeviceGlyph {
                anchors.centerIn: parent
                size: Theme.dp(21)
                kind: Bt.glyphKind(dev.modelData.icon)
                color: Theme.accent
            }

            Rectangle {
                width: Theme.dp(11)
                height: Theme.dp(11)
                radius: 5.5
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -Theme.dp(2)
                visible: dev.isConnected
                color: Theme.success
                border.width: 2
                border.color: Theme.bgTile
            }

        }

        Column {
            anchors.left: iconTile.right
            anchors.leftMargin: Theme.dp(14)
            anchors.right: trailing.left
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            Text {
                width: parent.width
                text: dev.modelData.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.variableAxes: Theme.axes(Theme.fontTitle, 640, 0)
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: dev.status
                color: dev.isConnected ? Theme.accent : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                elide: Text.ElideRight
            }

        }

        Row {
            id: trailing

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(10)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: dev.batteryPct >= 0
                spacing: Theme.dp(6)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dev.batteryPct + "%"
                    color: dev.batteryPct < 20 ? Theme.error : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(26)
                    height: Theme.dp(6)
                    radius: Theme.dp(3)
                    color: Theme.bgTrack

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(Theme.dp(3), parent.width * Math.max(0, Math.min(1, dev.batteryPct / 100)))
                        height: parent.height
                        radius: Theme.dp(3)
                        color: dev.batteryPct < 20 ? Theme.error : Theme.success
                    }

                }

            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "expand_more"
                size: Theme.dp(18)
                color: Theme.subtext
                rotation: dev.expanded ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

            }

        }

        MouseArea {
            id: headArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                dev.renaming = false;
                dev.expandRequested();
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

    }

    Item {
        id: drawer

        width: parent.width
        height: dev.expanded ? body.implicitHeight : 0
        clip: true

        Column {
            id: body

            width: parent.width
            leftPadding: Theme.dp(65)
            rightPadding: Theme.dp(14)
            topPadding: Theme.dp(4)
            bottomPadding: Theme.dp(16)
            spacing: Theme.dp(12)
            opacity: dev.expanded ? 1 : 0

            // four buttons: they wrap on a narrow window
            Flow {
                width: parent.width - Theme.dp(79)
                spacing: Theme.dp(10)

                M3Button {
                    variant: "filled"
                    enabled: !dev.busy && !dev.modelData.blocked
                    text: {
                        if (dev.isPairing)
                            return "Pairing…";

                        if (dev.isConnecting)
                            return "Connecting…";

                        if (dev.group === "nearby")
                            return "Pair";

                        return dev.isConnected ? "Disconnect" : "Connect";
                    }
                    onClicked: {
                        dev.actionFailed = false;
                        if (dev.group === "nearby")
                            Bt.pair(dev.modelData);
                        else if (dev.isConnected)
                            dev.modelData.disconnect();
                        else
                            dev.modelData.connect();
                    }
                }

                M3Button {
                    variant: "text"
                    visible: dev.isPairing
                    text: "Cancel"
                    onClicked: dev.modelData.cancelPair()
                }

                M3Button {
                    variant: "tonal"
                    visible: dev.isPaired && Bt.canReceiveFiles(dev.modelData.address)
                    text: "Send files"
                    onClicked: Bt.sendFiles(dev.modelData.address, dev.modelData.name, [])
                }

                M3Button {
                    variant: "tonal"
                    visible: dev.isPaired && !dev.renaming
                    text: "Rename"
                    onClicked: dev.renaming = true
                }

                M3Button {
                    variant: "text"
                    destructive: true
                    visible: dev.isPaired
                    text: "Forget"
                    onClicked: Prefs.askConfirm("Forget " + dev.modelData.name + "?", "The pairing is removed from this machine. You will have to pair the device again to use it.", "Forget", "bt-forget:" + dev.modelData.address)
                }

            }

            M3TextField {
                width: Theme.dp(300)
                visible: dev.renaming
                placeholder: dev.modelData.name
                text: dev.modelData.name
                onAccepted: (v) => {
                    if (v.trim() !== "")
                        dev.modelData.name = v.trim();

                    dev.renaming = false;
                }
            }

            Text {
                width: parent.width - Theme.dp(79)
                visible: dev.actionFailed && !dev.busy && !dev.isConnected
                text: dev.group === "nearby" ? "Pairing failed. Bring the device closer, make sure it is in pairing mode, and try again." : "Could not connect. The device may be off or out of range."
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width - Theme.dp(79)
                visible: dev.isConnected && dev.card && dev.card.profiles.length > 1
                spacing: Theme.dp(7)

                Text {
                    text: "Audio mode"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                    font.weight: Font.Medium
                }

                Flow {
                    width: parent.width
                    spacing: Theme.dp(6)

                    Repeater {
                        model: dev.card ? dev.card.profiles : []

                        Rectangle {
                            id: prof

                            required property string modelData
                            readonly property bool selected: dev.card && dev.card.active === prof.modelData

                            width: profLabel.implicitWidth + Theme.dp(24)
                            height: Theme.dp(30)
                            radius: Theme.dp(15)
                            color: prof.selected ? Theme.accentContainer : (profArea.containsMouse ? Theme.bgHover : Theme.bgSunken)

                            Text {
                                id: profLabel

                                anchors.centerIn: parent
                                text: Bt.profileLabel(prof.modelData)
                                color: prof.selected ? Theme.fgAccentContainer : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.variableAxes: Theme.axes(Theme.fontLabel, (prof.selected) ? 640 : 420, 0)
                                font.bold: prof.selected
                            }

                            MouseArea {
                                id: profArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Bt.setProfile(dev.card.name, prof.modelData)
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                    }

                }

            }

            Flow {
                width: parent.width - Theme.dp(79)
                visible: dev.isPaired
                spacing: Theme.dp(18)

                CheckLine {
                    label: "Reconnect on its own"
                    checked: dev.modelData.trusted
                    onToggled: dev.modelData.trusted = !dev.modelData.trusted
                }

                CheckLine {
                    label: "Allow it to wake this machine"
                    visible: dev.isConnected
                    checked: dev.modelData.wakeAllowed
                    onToggled: dev.modelData.wakeAllowed = !dev.modelData.wakeAllowed
                }

                CheckLine {
                    label: "Block"
                    danger: true
                    checked: dev.modelData.blocked
                    onToggled: dev.modelData.blocked = !dev.modelData.blocked
                }

            }

            Text {
                text: dev.modelData.address + (dev.modelData.icon !== "" ? "   ·   " + dev.modelData.icon : "")
                color: Theme.subtextDim
                font.family: "monospace"
                font.features: ({
                    "liga": 0,
                    "calt": 0
                })
                font.pixelSize: Theme.fontLabel
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeStandard
            }

        }

    }

}
