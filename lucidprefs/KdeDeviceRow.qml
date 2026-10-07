import QtQuick
import qs
import qs.lucidui

Column {
    id: dev

    required property var modelData
    property bool expanded: false

    readonly property string devId: dev.modelData.id
    readonly property bool reachable: dev.modelData.reachable
    readonly property bool paired: dev.modelData.paired
    readonly property bool asking: dev.modelData.pairRequestedByPeer
    readonly property bool waiting: dev.modelData.pairRequested
    readonly property bool opens: dev.paired && dev.reachable
    readonly property var battery: dev.modelData.battery
    readonly property var sig: dev.modelData.signal

    readonly property string status: {
        if (dev.asking)
            return "Wants to pair with this machine";

        if (dev.waiting)
            return "Waiting for the other device to accept…";

        if (!dev.paired)
            return "Nearby, not paired";

        if (!dev.reachable)
            return "Paired · offline";

        const via = dev.modelData.links.length > 0 ? dev.modelData.links.join(", ") : "";
        return via !== "" ? "Connected over " + via : "Connected";
    }

    signal opened()
    signal expandRequested()

    width: parent ? parent.width : Theme.dp(400)

    Rectangle {
        id: head

        width: parent.width
        height: Theme.dp(62)
        radius: Theme.radiusMd
        color: dev.expanded ? Theme.bgHover : (headArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

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
                color: Theme.alpha(dev.asking ? Theme.warning : Theme.accent, dev.reachable || dev.asking ? 0.24 : 0.11)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            DeviceGlyph {
                anchors.centerIn: parent
                size: Theme.dp(21)
                kind: Bt.glyphKind(dev.modelData.type)
                color: dev.asking ? Theme.warning : Theme.accent
            }

            Rectangle {
                width: Theme.dp(11)
                height: Theme.dp(11)
                radius: 5.5
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -Theme.dp(2)
                visible: dev.opens
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
                color: dev.asking ? Theme.warning : (dev.opens ? Theme.accent : Theme.subtext)
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
            spacing: Theme.dp(12)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: dev.sig !== undefined && dev.sig.strength >= 0
                spacing: Theme.dp(6)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dev.sig ? dev.sig.type : ""
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                }

                SignalBars {
                    anchors.verticalCenter: parent.verticalCenter
                    strength: dev.sig ? dev.sig.strength * 25 : 0
                }

            }

            BatteryPip {
                anchors.verticalCenter: parent.verticalCenter
                charge: dev.battery ? dev.battery.charge : -1
                charging: !!(dev.battery && dev.battery.charging)
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: dev.opens ? "chevron_right" : "expand_more"
                size: Theme.dp(18)
                color: Theme.subtext
                rotation: !dev.opens && dev.expanded ? 180 : 0

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
                if (dev.opens)
                    dev.opened();
                else
                    dev.expandRequested();
            }
        }

    }

    // everything a device that is not ready to open can still do
    Item {
        id: drawer

        width: parent.width
        height: !dev.opens && dev.expanded ? body.implicitHeight : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeStandard
            }

        }

        Column {
            id: body

            width: parent.width
            leftPadding: Theme.dp(65)
            rightPadding: Theme.dp(14)
            topPadding: Theme.dp(4)
            bottomPadding: Theme.dp(16)
            spacing: Theme.dp(12)
            opacity: dev.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

            Text {
                width: parent.width - Theme.dp(79)
                text: {
                    if (dev.asking)
                        return "Check that " + dev.modelData.name + " is showing key " + dev.modelData.key + ", then accept.";

                    if (dev.waiting)
                        return "Accept the request on " + dev.modelData.name + ". Both should be showing key " + dev.modelData.key + ".";

                    if (!dev.paired)
                        return "Pairing asks the other device to confirm. Both will show the same key, and they must match.";

                    return "This device is paired but not on the network right now. Open KDE Connect on it and make sure you are both on the same Wi-Fi.";
                }
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                wrapMode: Text.WordWrap
            }

            Row {
                spacing: Theme.dp(10)

                M3Button {
                    variant: "filled"
                    visible: dev.asking
                    text: "Accept"
                    onClicked: KdeConnect.accept(dev.devId)
                }

                M3Button {
                    variant: "filled"
                    visible: !dev.paired && !dev.asking && !dev.waiting
                    text: "Pair"
                    onClicked: KdeConnect.pair(dev.devId)
                }

                M3Button {
                    variant: "text"
                    destructive: true
                    visible: dev.asking || dev.waiting
                    text: dev.asking ? "Reject" : "Cancel"
                    onClicked: KdeConnect.cancel(dev.devId)
                }

                M3Button {
                    variant: "text"
                    destructive: true
                    visible: dev.paired && !dev.asking && !dev.waiting
                    text: "Unpair"
                    onClicked: Prefs.askConfirm("Unpair " + dev.modelData.name + "?", "This machine and that device stop trusting each other. Nothing on either is deleted, and you can pair them again whenever you like.", "Unpair", "kde-unpair:" + dev.devId)
                }

            }

            Text {
                text: dev.devId
                color: Theme.subtextDim
                font.family: "monospace"
                font.features: ({
                    "liga": 0,
                    "calt": 0
                })
                font.pixelSize: Theme.fontLabel
            }

        }

    }

}
