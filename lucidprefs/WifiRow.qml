import QtQuick
import QtQuick.Shapes
import Quickshell.Networking
import qs

Column {
    id: net

    required property var modelData
    property bool expanded: false
    property string psk: ""
    property bool failed: false
    property bool wasBusy: false

    readonly property bool isConnected: net.modelData.connected
    readonly property bool known: net.modelData.known
    readonly property bool secured: Net.isSecured(net.modelData)
    readonly property real strength: Net.strengthPct(net.modelData)
    readonly property bool working: net.modelData.stateChanging || net.modelData.state === ConnectionState.Connecting
    readonly property bool needsPassword: net.secured && !net.known
    readonly property var profile: Net.connections.find((c) => {
        return c.name === net.modelData.name;
    }) || null

    readonly property string status: {
        if (net.working)
            return "Connecting…";

        if (net.isConnected)
            return "Connected  ·  " + Net.strengthLabel(net.strength) + " signal";

        const bits = [];
        if (net.known)
            bits.push("Saved");

        bits.push(Net.strengthLabel(net.strength));
        const sec = Net.securityLabel(net.modelData.security);
        if (sec !== "")
            bits.push(sec);

        return bits.join("  ·  ");
    }

    signal expandRequested()

    width: parent ? parent.width : 400

    // a refused password shows up only as a bounce back to disconnected
    Connections {
        function onStateChanged() {
            if (net.modelData.state === ConnectionState.Connecting) {
                net.wasBusy = true;
                net.failed = false;
            } else if (net.wasBusy && net.modelData.state !== ConnectionState.Connected) {
                net.wasBusy = false;
                net.failed = true;
            } else if (net.modelData.state === ConnectionState.Connected) {
                net.wasBusy = false;
                net.failed = false;
            }
        }

        target: net.modelData
    }

    Rectangle {
        id: head

        width: parent.width
        height: 58
        radius: Theme.radiusMd
        color: net.expanded ? Theme.bgHover : (headArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

        Item {
            id: iconTile

            width: 36
            height: 36
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.rad(12)
                color: Theme.alpha(Theme.accent, net.isConnected ? 0.24 : 0.11)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            WifiGlyph {
                anchors.centerIn: parent
                size: 19
                strength: net.strength
                color: net.isConnected ? Theme.accent : Theme.subtext
            }

        }

        Column {
            anchors.left: iconTile.right
            anchors.leftMargin: 14
            anchors.right: trailing.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: net.modelData.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: net.status
                color: net.isConnected ? Theme.accent : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                elide: Text.ElideRight
            }

        }

        Row {
            id: trailing

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Shape {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                visible: net.secured
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.subtextDim

                    PathSvg {
                        path: "M12,17A2,2 0 0,0 14,15C14,13.89 13.1,13 12,13A2,2 0 0,0 10,15A2,2 0 0,0 12,17M18,8A2,2 0 0,1 20,10V20A2,2 0 0,1 18,22H6A2,2 0 0,1 4,20V10C4,8.89 4.9,8 6,8H7V6A5,5 0 0,1 12,1A5,5 0 0,1 17,6V8H18M12,3A3,3 0 0,0 9,6V8H15V6A3,3 0 0,0 12,3Z"
                    }

                }

                transform: Scale {
                    xScale: 14 / 24
                    yScale: 14 / 24
                }

            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "▾"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                rotation: net.expanded ? 180 : 0

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
            onClicked: net.expandRequested()
        }

    }

    Item {
        id: drawer

        width: parent.width
        height: net.expanded ? body.implicitHeight : 0
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
            leftPadding: 62
            rightPadding: 14
            topPadding: 4
            bottomPadding: 16
            spacing: 12
            opacity: net.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

            Row {
                width: parent.width - 76
                spacing: 10
                visible: net.needsPassword && !net.isConnected

                M3TextField {
                    id: pskField

                    width: parent.width - joinBtn.implicitWidth - 10
                    placeholder: "Network password"
                    onEdited: (v) => {
                        return net.psk = v;
                    }
                    onAccepted: (v) => {
                        return joinBtn.clicked();
                    }
                }

                M3Button {
                    id: joinBtn

                    anchors.verticalCenter: parent.verticalCenter
                    variant: "filled"
                    text: net.working ? "Joining…" : "Join"
                    enabled: !net.working && net.psk.length >= 8
                    onClicked: {
                        net.failed = false;
                        net.modelData.connectWithPsk(net.psk);
                    }
                }

            }

            Row {
                spacing: 10

                M3Button {
                    variant: "filled"
                    visible: !net.needsPassword || net.isConnected
                    enabled: !net.working
                    text: {
                        if (net.working)
                            return "Connecting…";

                        return net.isConnected ? "Disconnect" : "Connect";
                    }
                    onClicked: {
                        net.failed = false;
                        if (net.isConnected)
                            net.modelData.disconnect();
                        else
                            net.modelData.connect();
                    }
                }

                M3Button {
                    variant: "text"
                    destructive: true
                    visible: net.known
                    text: "Forget"
                    onClicked: Prefs.askConfirm("Forget " + net.modelData.name + "?", "The saved password goes with it, so joining again means typing it in.", "Forget", "wifi-forget:" + net.modelData.name)
                }

            }

            Text {
                width: parent.width - 76
                visible: net.failed
                text: net.secured ? "Could not join. The password may be wrong, or the network out of range." : "Could not join. The network may be out of range."
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                wrapMode: Text.WordWrap
            }

            Flow {
                width: parent.width - 76
                visible: net.profile !== null
                spacing: 18

                CheckLine {
                    label: "Join automatically"
                    checked: !!(net.profile && net.profile.autoconnect)
                    onToggled: Net.setAutoconnect(net.profile.uuid, !net.profile.autoconnect)
                }

            }

            Text {
                text: Math.round(net.strength) + "% signal" + (Net.securityLabel(net.modelData.security) !== "" ? "   ·   " + Net.securityLabel(net.modelData.security) : "")
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
            }

        }

    }

}
