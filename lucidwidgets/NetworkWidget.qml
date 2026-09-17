import QtQuick
import Quickshell.Io
import qs

WidgetBody {
    id: w

    // bytes a second over the interface the default route leaves by
    property real down: 0
    property real up: 0
    property var downHistory: []
    property var upHistory: []
    property string iface: ""
    property real prevRx: -1
    property real prevTx: -1
    property real prevAt: 0

    readonly property int pollMs: (parseInt(w.opt("interval")) || 1) * 1000
    readonly property bool bits: w.opt("units") === "bits"
    readonly property var sampleDev: ({
        "name": "wlan0",
        "type": "wifi",
        "connection": "Home",
        "ip4": ["192.168.1.24/24"],
        "gw4": "192.168.1.1",
        "rate": "866 Mbit/s",
        "speed": 0
    })
    // NetworkManager's view of that interface: name, addresses, link rate
    readonly property var dev: w.preview ? w.sampleDev : Net.deviceInfo(w.iface)
    readonly property bool online: w.dev !== null && (w.dev.connection || "") !== ""
    readonly property bool wifi: w.dev !== null && w.dev.type === "wifi"
    readonly property string title: w.online ? w.dev.connection : "Offline"
    readonly property int signal: {
        if (w.preview)
            return 78;

        if (!w.wifi || !Net.wifiDevice || !Net.wifiDevice.networks)
            return -1;

        var n = Net.wifiDevice.networks.values.find((x) => {
            return x.connected;
        });
        return n ? Net.strengthPct(n) : -1;
    }
    readonly property string address: (w.dev && w.dev.ip4 && w.dev.ip4.length > 0) ? w.dev.ip4[0].split("/")[0] : ""
    readonly property string gateway: w.dev ? (w.dev.gw4 || "") : ""
    readonly property string link: w.dev ? (w.dev.rate || (w.dev.speed > 0 ? w.dev.speed + " Mbit/s" : "")) : ""
    // a NetworkManager VPN, or a tunnel some other daemon brought up (tailscale, wg-quick)
    readonly property string vpn: {
        if (w.preview)
            return "";

        if (Net.activeVpn)
            return Net.activeVpn.name;

        var t = Net.devices.find((d) => {
            return (d.type === "tun" || d.type === "wireguard") && d.stateCode === 100 && d.name !== w.iface;
        });
        if (!t)
            return "";

        return t.name.indexOf("tailscale") === 0 ? "Tailscale" : (t.connection || t.name);
    }
    readonly property string internet: {
        switch (w.preview ? "full" : Net.connectivity) {
        case "full":
            return "Reachable";
        case "portal":
            return "Sign-in page";
        case "limited":
            return "Limited";
        case "none":
            return "Unreachable";
        default:
            return "";
        }
    }
    readonly property var facts: {
        var out = [];
        if (w.opt("showAddress") !== false) {
            if (w.address !== "")
                out.push({
                    "label": "Address",
                    "value": w.address
                });

            if (w.gateway !== "")
                out.push({
                    "label": "Gateway",
                    "value": w.gateway
                });

        }
        if (w.signal >= 0)
            out.push({
                "label": "Signal",
                "value": w.signal + "%" + (w.link !== "" ? " · " + w.link : "")
            });
        else if (w.link !== "")
            out.push({
                "label": "Link",
                "value": w.link
            });
        out.push({
            "label": "VPN",
            "value": w.vpn !== "" ? w.vpn : "Off"
        });
        if (w.internet !== "")
            out.push({
                "label": "Internet",
                "value": w.internet
            });

        return out.slice(0, 5);
    }
    // both lines share one scale, so upload reads as small next to a download
    readonly property real peak: Math.max(24 * 1024, Math.max.apply(null, w.downHistory.concat(w.upHistory, [0])))
    readonly property var downLine: w.downHistory.map((v) => {
        return v / w.peak;
    })
    readonly property var upLine: w.upHistory.map((v) => {
        return v / w.peak;
    })
    readonly property color upTint: Theme.hasTonalContainers ? Theme.cSecondary : Theme.subtext

    function rate(bytes) {
        var base = w.bits ? 1000 : 1024;
        var units = w.bits ? ["b/s", "kb/s", "Mb/s", "Gb/s"] : ["B/s", "KB/s", "MB/s", "GB/s"];
        var v = w.bits ? bytes * 8 : bytes;
        var i = 0;
        while (v >= base && i < units.length - 1) {
            v /= base;
            i++;
        }
        return (i > 0 && v < 10 ? v.toFixed(1) : Math.round(v)) + " " + units[i];
    }

    function push(arr, v) {
        var next = arr.concat([v]);
        while (next.length > 60) next.shift()
        return next;
    }

    function take(text) {
        var lines = text.split("\n");
        var name = "";
        var i = 0;
        if (lines.length > 0 && lines[0] !== "@") {
            name = lines[0].trim();
            i = 1;
        }
        var rx = -1, tx = -1;
        for (; i < lines.length && name !== ""; i++) {
            var colon = lines[i].indexOf(":");
            if (colon < 0 || lines[i].substring(0, colon).trim() !== name)
                continue;

            var f = lines[i].substring(colon + 1).trim().split(/\s+/);
            rx = Number(f[0]);
            tx = Number(f[8]);
        }
        var t = Date.now();
        if (name !== w.iface) {
            w.iface = name;
            w.prevRx = -1;
        }
        if (rx < 0) {
            w.down = 0;
            w.up = 0;
        } else if (w.prevRx >= 0 && t > w.prevAt) {
            var dt = (t - w.prevAt) / 1000;
            // a counter that went backwards was reset; skip that sample
            w.down = Math.max(0, (rx - w.prevRx) / dt);
            w.up = Math.max(0, (tx - w.prevTx) / dt);
            w.downHistory = w.push(w.downHistory, w.down);
            w.upHistory = w.push(w.upHistory, w.up);
        }
        w.prevRx = rx;
        w.prevTx = tx;
        w.prevAt = t;
    }

    // the gallery hands over its host after onCompleted, so seed on either
    onPreviewChanged: w.seedPreview()
    Component.onCompleted: w.seedPreview()

    function seedPreview() {
        if (!w.preview)
            return ;

        var d = [], u = [];
        for (var i = 0; i < 60; i++) {
            d.push(Math.max(0, 900000 + 700000 * Math.sin(i / 4.2) + 300000 * Math.sin(i / 1.4)));
            u.push(Math.max(0, 90000 + 60000 * Math.sin(i / 3.1 + 1)));
        }
        w.downHistory = d;
        w.upHistory = u;
        w.down = 1468006;
        w.up = 88064;
    }

    Timer {
        interval: w.pollMs
        repeat: true
        running: w.live
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Process {
        id: poll

        command: ["sh", "-c", "ip -o route get 1.1.1.1 2>/dev/null | sed -n 's/.* dev \\([^ ]*\\).*/\\1/p'; echo @; cat /proc/net/dev"]

        stdout: StdioCollector {
            onStreamFinished: w.take(this.text)
        }

    }

    Item {
        id: graph

        visible: w.variant === "graph"
        anchors.fill: parent
        anchors.margins: 18

        Head {
            id: graphHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
        }

        Row {
            id: graphRates

            anchors.left: parent.left
            anchors.top: graphHead.bottom
            anchors.topMargin: 10
            spacing: 24

            RateCell {
                icon: "down"
                label: "DOWN"
                value: w.rate(w.down)
                tint: Theme.accent
            }

            RateCell {
                icon: "up"
                label: "UP"
                value: w.rate(w.up)
                tint: w.upTint
            }

        }

        Spark {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: graphRates.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            samples: w.downLine
            lineColor: Theme.accent
            lineWidth: 2.2
        }

        Spark {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: graphRates.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            samples: w.upLine
            lineColor: w.upTint
            filled: false
            lineWidth: 1.8
        }

    }

    Item {
        id: detail

        visible: w.variant === "detail"
        anchors.fill: parent
        anchors.margins: 18

        Head {
            id: detailHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: detailHead.bottom
            anchors.topMargin: 10

            Repeater {
                model: w.facts

                Item {
                    id: fact

                    required property var modelData

                    width: parent.width
                    height: 22

                    Text {
                        id: factLabel

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: fact.modelData.label
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.left: factLabel.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: fact.modelData.value
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideLeft
                    }

                }

            }

        }

        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            spacing: 18

            Repeater {
                model: [{
                    "icon": "down",
                    "value": w.rate(w.down),
                    "tint": Theme.accent
                }, {
                    "icon": "up",
                    "value": w.rate(w.up),
                    "tint": w.upTint
                }]

                Row {
                    id: footCell

                    required property var modelData

                    spacing: 4

                    WidgetGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: footCell.modelData.icon
                        size: 14
                        color: footCell.modelData.tint
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: footCell.modelData.value
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }

                }

            }

        }

    }

    Row {
        id: compact

        visible: w.variant === "compact"
        anchors.centerIn: parent
        width: parent.width - 36
        spacing: 0

        RateCell {
            width: compact.width / 2
            icon: "down"
            label: "DOWN"
            value: w.rate(w.down)
            tint: Theme.accent
            big: 20
        }

        RateCell {
            width: compact.width / 2
            icon: "up"
            label: "UP"
            value: w.rate(w.up)
            tint: w.upTint
            big: 20
        }

    }

    component Head: Item {
        implicitHeight: 20

        WidgetGlyph {
            id: headIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: w.wifi ? "wifi" : (w.online ? "lan" : "network")
            size: 16
            color: w.online ? Theme.accent : Theme.subtextDim
        }

        Text {
            anchors.left: headIcon.right
            anchors.leftMargin: 8
            anchors.right: headBadge.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: w.title
            color: w.online ? Theme.text : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
        }

        Row {
            id: headBadge

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            WidgetGlyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: w.vpn !== ""
                name: "shield"
                size: 12
                color: Theme.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: w.vpn !== "" ? w.vpn : (w.signal >= 0 ? w.signal + "%" : "")
                color: w.vpn !== "" ? Theme.accent : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
            }

        }

    }

    component RateCell: Column {
        id: cell

        property string icon: "down"
        property string label: ""
        property string value: ""
        property color tint: Theme.accent
        property real big: 22

        spacing: 1

        Row {
            spacing: 3

            WidgetGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: cell.icon
                size: 11
                color: cell.tint
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cell.label
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
            }

        }

        Text {
            text: cell.value
            color: cell.tint
            font.family: Theme.fontFamily
            font.pixelSize: cell.big
            font.bold: true
            font.letterSpacing: -0.5
        }

    }

}
