import QtQuick
import qs

// a saved Wi-Fi network as a QR code a phone camera can join from, with the
// password beside it. the password is read when this appears and dropped
// when it goes, and it stays dotted until asked for
Item {
    id: share

    required property string ssid
    // stacks the code over the password, for the narrow bar panel
    property bool compact: false
    property int qrSize: share.compact ? 148 : 168
    property bool revealed: false
    property bool copied: false

    readonly property var info: Net.sharedSsid === share.ssid ? Net.shared : ({})
    readonly property bool loading: Net.sharedSsid === share.ssid && Net.shareLoading
    readonly property var rows: share.info.qr || []
    readonly property bool open: share.info.security === "nopass"
    readonly property string problem: {
        if (share.loading || share.info.found === undefined)
            return "";

        if (!share.info.found)
            return "There is no saved profile for this network, so there is nothing to share.";

        if (share.info.security === "enterprise")
            return "This network signs in with an account, not a password a phone could scan.";

        if (!share.open && !share.info.psk)
            return share.info.agentOwned ? "The password is kept in your keyring, not by NetworkManager, so it can't be read from here." : "No password is saved for this network.";

        return "";
    }
    readonly property bool ready: share.problem === "" && share.info.found === true
    readonly property color paper: Theme.atTone(Theme.accent, 98)
    readonly property color ink: Theme.atTone(Theme.accent, 10)

    implicitHeight: grid.implicitHeight
    Component.onCompleted: Net.loadShare(share.ssid)
    Component.onDestruction: Net.clearShare(share.ssid)
    onSsidChanged: {
        share.revealed = false;
        Net.loadShare(share.ssid);
    }

    Timer {
        id: copiedTimer

        interval: 1600
        onTriggered: share.copied = false
    }

    component QrTile: Rectangle {
        width: share.qrSize
        height: share.qrSize
        radius: Math.round(share.qrSize * 0.09)
        color: share.paper

        Canvas {
            id: qr

            // a quiet zone of about three modules keeps phones locking on
            anchors.fill: parent
            anchors.margins: Math.round(share.qrSize * 0.08)
            visible: share.rows.length > 0
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const rows = share.rows;
                const n = rows.length;
                if (n === 0)
                    return ;

                // whole pixels per module, or the edges blur and scanners slip
                const m = Math.max(1, Math.floor(Math.min(width, height) / n));
                const ox = Math.floor((width - m * n) / 2);
                const oy = Math.floor((height - m * n) / 2);
                ctx.fillStyle = share.ink;
                for (let y = 0; y < n; y++) {
                    const row = rows[y];
                    for (let x = 0; x < row.length; x++) {
                        if (row.charAt(x) === "1")
                            ctx.fillRect(ox + x * m, oy + y * m, m, m);

                    }
                }
            }

            Connections {
                function onRowsChanged() {
                    qr.requestPaint();
                }

                function onInkChanged() {
                    qr.requestPaint();
                }

                target: share
            }

        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 28
            visible: share.rows.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: share.loading ? "Reading…" : (share.ready ? "Install qrencode to show a code." : "No code")
            color: Theme.alpha(share.ink, 0.6)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
        }

    }

    component Details: Column {
        spacing: 10

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: share.problem !== "" ? share.problem : (share.open ? "Point a phone's camera at the code to join " + share.ssid + ". It's an open network, so there is no password." : "Point a phone's camera at the code to join " + share.ssid + ", or type the password in.")
            color: share.problem !== "" ? Theme.error : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            lineHeight: 1.15
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.radiusSm
            visible: share.ready && !share.open
            color: Theme.alpha(Theme.text, 0.06)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: eye.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                // a fixed row of dots, so hidden it doesn't give the length away
                text: share.revealed ? (share.info.psk || "") : "••••••••••"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.letterSpacing: share.revealed ? 0.5 : 2
                elide: Text.ElideRight
            }

            M3IconButton {
                id: eye

                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                // eye / eye-off, Material Design Icons
                iconPath: share.revealed ? "M11.83,9L15,12.16C15,12.11 15,12.05 15,12A3,3 0 0,0 12,9C11.94,9 11.89,9 11.83,9M7.53,9.8L9.08,11.35C9.03,11.56 9,11.77 9,12A3,3 0 0,0 12,15C12.22,15 12.44,14.97 12.65,14.92L14.2,16.47C13.53,16.8 12.79,17 12,17A5,5 0 0,1 7,12C7,11.21 7.2,10.47 7.53,9.8M2,4.27L4.28,6.55L4.73,7C3.08,8.3 1.78,10 1,12C2.73,16.39 7,19.5 12,19.5C13.55,19.5 15.03,19.2 16.38,18.66L16.81,19.08L19.73,22L21,20.73L3.27,3M12,7A5,5 0 0,1 17,12C17,12.64 16.87,13.26 16.64,13.82L19.57,16.75C21.07,15.5 22.27,13.86 23,12C21.27,7.61 17,4.5 12,4.5C10.6,4.5 9.26,4.75 8,5.2L10.17,7.35C10.74,7.13 11.35,7 12,7Z" : "M12,9A3,3 0 0,0 9,12A3,3 0 0,0 12,15A3,3 0 0,0 15,12A3,3 0 0,0 12,9M12,17A5,5 0 0,1 7,12A5,5 0 0,1 12,7A5,5 0 0,1 17,12A5,5 0 0,1 12,17M12,4.5C7,4.5 2.73,7.61 1,12C2.73,16.39 7,19.5 12,19.5C17,19.5 21.27,16.39 23,12C21.27,7.61 17,4.5 12,4.5Z"
                onClicked: share.revealed = !share.revealed
            }

        }

        M3Button {
            visible: share.ready && !share.open
            // outlined in the bar panel, where the buttons beside it are
            variant: share.compact ? "outlined" : "tonal"
            text: share.copied ? "Copied" : "Copy password"
            onClicked: {
                Net.copyShared();
                share.copied = true;
                copiedTimer.restart();
            }
        }

    }

    Grid {
        id: grid

        width: parent.width
        columns: share.compact ? 1 : 2
        columnSpacing: 20
        rowSpacing: 12
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: share.compact ? Grid.AlignHCenter : Grid.AlignLeft

        QrTile {
        }

        Details {
            width: share.compact ? grid.width : grid.width - share.qrSize - grid.columnSpacing
        }

    }

}
