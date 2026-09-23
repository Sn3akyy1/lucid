import QtQuick
import qs
import qs.lucidui

WidgetBody {
    id: w

    readonly property var sampleDev: ({
        "id": "sample-phone-001",
        "name": "Pixel 8 Pro",
        "type": "phone",
        "paired": true,
        "reachable": true,
        "battery": { "charge": 85, "charging": true },
        "signal": { "type": "5G", "strength": 4 },
        "locked": false,
        "mpris": {
            "title": "Blinding Lights",
            "artist": "The Weeknd",
            "playing": true
        }
    })

    readonly property var dev: {
        if (w.preview)
            return w.sampleDev;
        if (KdeConnect.reachable && KdeConnect.reachable.length > 0)
            return KdeConnect.reachable[0];
        if (KdeConnect.devices && KdeConnect.devices.length > 0)
            return KdeConnect.devices[0];
        return null;
    }

    readonly property bool connected: w.dev ? (w.dev.reachable === true) : false
    readonly property string phoneName: w.dev ? (w.dev.name || "Phone") : "No phone"
    readonly property var batt: w.dev ? w.dev.battery : null
    readonly property int chargePct: w.batt ? (w.batt.charge !== undefined ? w.batt.charge : -1) : -1
    readonly property bool charging: w.batt ? !!w.batt.charging : false
    readonly property var sig: w.dev ? w.dev.signal : null
    readonly property string netType: w.sig ? (w.sig.type || "") : ""
    readonly property int sigStrength: w.sig ? (w.sig.strength !== undefined ? w.sig.strength : -1) : -1

    readonly property var mprisData: w.dev ? w.dev.mpris : null
    readonly property bool hasMedia: w.mprisData && w.mprisData.title ? true : false
    readonly property string trackTitle: w.hasMedia ? w.mprisData.title : ""
    readonly property string trackArtist: w.hasMedia ? (w.mprisData.artist || "") : ""
    readonly property bool isPlaying: w.hasMedia ? !!w.mprisData.playing : false

    readonly property bool showShare: w.opt("showShare") !== false
    readonly property bool showRing: w.opt("showRing") !== false
    readonly property bool showClipboard: w.opt("showClipboard") !== false

    readonly property string glyph: w.dev && w.dev.type === "tablet" ? "tablet_android" : "smartphone"
    readonly property string statusLine: {
        if (!w.connected)
            return "";

        var bits = ["Connected"];
        if (w.netType !== "")
            bits.push(w.netType);

        if (w.charging)
            bits.push("charging");

        return bits.join(" · ");
    }
    readonly property var actions: {
        var out = [];
        if (w.showShare)
            out.push({
            "icon": "upload_file",
            "tip": "Send a file",
            "run": "share"
        });

        if (w.showRing)
            out.push({
            "icon": "ring_volume",
            "tip": "Ring it",
            "run": "ring"
        });

        if (w.showClipboard)
            out.push({
            "icon": "content_paste_go",
            "tip": "Send the clipboard",
            "run": "clip"
        });

        out.push({
            "icon": "notifications_active",
            "tip": "Ping",
            "run": "ping"
        });
        return out;
    }

    function run(what) {
        if (!w.dev || w.preview)
            return ;

        if (what === "share")
            KdeConnect.pickFiles(w.dev.id, "Send to " + w.dev.name);
        else if (what === "ring")
            KdeConnect.ring(w.dev.id);
        else if (what === "clip")
            KdeConnect.sendClipboard(w.dev.id);
        else if (what === "ping")
            KdeConnect.ping(w.dev.id, "Ping from Lucid");
    }

    // the phone's mark: its glyph inside a scalloped shape
    component Mark: MaterialShape {
        id: mk

        property real d: 48

        width: mk.d
        height: mk.d
        shape: "cookie9"
        color: w.connected ? w.inkAccent : Theme.alpha(w.ink, 0.1)

        Icon {
            anchors.centerIn: parent
            name: w.connected ? w.glyph : "phonelink_off"
            size: mk.d * 0.48
            fill: 1
            color: w.connected ? w.onInkAccent : w.inkDim
        }

    }

    // four bars, lit up to the phone's reported strength
    component Bars: Row {
        spacing: 2

        Repeater {
            model: 4

            Rectangle {
                required property int index

                anchors.bottom: parent.bottom
                width: 4
                height: 5 + index * 3
                radius: 2
                color: index < w.sigStrength ? w.ink : Theme.alpha(w.ink, 0.2)
            }

        }

    }

    component BatteryRing: Item {
        width: 34
        height: 34

        CircularProgress {
            anchors.fill: parent
            thickness: 3.5
            value: Math.max(0, w.chargePct) / 100
            color: w.chargePct >= 0 && w.chargePct <= 15 && !w.charging ? Theme.error : w.inkAccent
            trackColor: Theme.alpha(w.ink, 0.12)
        }

        LText {
            anchors.centerIn: parent
            role: "labelSmall"
            weight: 680
            tabular: true
            color: w.ink
            text: w.chargePct >= 0 ? w.chargePct : "?"
        }

    }

    // a connected button group: round at the ends, tight where they meet
    component ActionGroup: Row {
        id: ag

        property real btn: 44

        spacing: 3

        Repeater {
            model: w.actions

            Rectangle {
                id: act

                required property var modelData
                required property int index
                readonly property bool firstOne: act.index === 0
                readonly property bool lastOne: act.index === w.actions.length - 1

                width: ag.btn
                height: ag.btn
                topLeftRadius: act.firstOne || actTap.pressed ? ag.btn / 2 : 10
                bottomLeftRadius: act.firstOne || actTap.pressed ? ag.btn / 2 : 10
                topRightRadius: act.lastOne || actTap.pressed ? ag.btn / 2 : 10
                bottomRightRadius: act.lastOne || actTap.pressed ? ag.btn / 2 : 10
                color: Theme.alpha(w.ink, 0.09)

                Icon {
                    anchors.centerIn: parent
                    name: act.modelData.icon
                    size: 20
                    color: w.ink
                }

                StateLayer {
                    id: actTap

                    radius: 10
                    tint: w.ink
                    onClicked: w.run(act.modelData.run)
                }

            }

        }

    }

    // nothing paired or nothing reachable
    Column {
        visible: !w.connected
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 8

        Mark {
            anchors.horizontalCenter: parent.horizontalCenter
            d: Math.min(56, w.height * 0.34)
        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "titleSmall"
            color: w.ink
            text: KdeConnect.installed ? "No phone nearby" : "KDE Connect isn't installed"
        }

        LText {
            visible: w.height > 130
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "bodySmall"
            color: w.inkDim
            wrapMode: Text.Wrap
            text: KdeConnect.installed ? "Open KDE Connect on your phone, or pair one in Settings" : "Install kdeconnect to link a phone"
        }

        Button {
            visible: KdeConnect.installed && w.height > 150
            anchors.horizontalCenter: parent.horizontalCenter
            variant: "tonal"
            size: "xs"
            icon: "refresh"
            text: "Look again"
            onClicked: KdeConnect.rescan()
        }

    }

    // shared header: mark, name, status, battery
    Item {
        id: head

        visible: w.connected && w.variant !== "compact"
        x: 16
        y: 14
        width: parent.width - 32
        height: 48

        Mark {
            id: headMark

            anchors.verticalCenter: parent.verticalCenter
            d: 46
        }

        Column {
            anchors.left: headMark.right
            anchors.leftMargin: 12
            anchors.right: headBatt.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            LText {
                width: parent.width
                role: "titleMedium"
                weight: 600
                color: w.ink
                text: w.phoneName
                elide: Text.ElideRight
            }

            Row {
                width: parent.width
                spacing: 6

                Bars {
                    id: headBars

                    visible: w.sigStrength >= 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                LText {
                    width: parent.width - (headBars.visible ? headBars.width + 6 : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelMedium"
                    color: w.inkDim
                    text: w.statusLine
                    elide: Text.ElideRight
                }

            }

        }

        BatteryRing {
            id: headBatt

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }

    }

    // card: the header, then the actions as one group
    ActionGroup {
        visible: w.connected && w.variant === "card"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        btn: Math.min(52, (w.width - 32 - 3 * (w.actions.length - 1)) / Math.max(1, w.actions.length))
    }

    // remote: the header, what the phone is playing, and the actions
    Item {
        visible: w.connected && w.variant === "remote"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 14
        anchors.topMargin: 12

        Rectangle {
            id: nowPlaying

            width: parent.width
            height: 60
            radius: 18
            color: Theme.alpha(w.ink, 0.07)

            Icon {
                id: npIcon

                x: 14
                anchors.verticalCenter: parent.verticalCenter
                name: "music_note"
                size: 20
                color: w.inkAccent
            }

            Column {
                anchors.left: npIcon.right
                anchors.leftMargin: 10
                anchors.right: npCtl.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2

                LText {
                    width: parent.width
                    role: "titleSmall"
                    color: w.ink
                    text: w.hasMedia ? w.trackTitle : "Nothing playing"
                    elide: Text.ElideRight
                }

                LText {
                    visible: w.trackArtist !== ""
                    width: parent.width
                    role: "bodySmall"
                    color: w.inkDim
                    text: w.trackArtist
                    elide: Text.ElideRight
                }

            }

            Row {
                id: npCtl

                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: "xs"
                    icon: "skip_previous"
                    iconFill: 1
                    tintOverride: w.ink
                    disabled: !w.hasMedia
                    onClicked: KdeConnect.mpris(w.dev.id, "Previous")
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: npTap.pressed ? 12 : 20
                    color: w.inkAccent
                    opacity: w.hasMedia ? 1 : 0.4

                    Icon {
                        anchors.centerIn: parent
                        name: w.isPlaying ? "pause" : "play_arrow"
                        size: 22
                        fill: 1
                        color: w.onInkAccent
                    }

                    StateLayer {
                        id: npTap

                        radius: parent.radius
                        tint: w.onInkAccent
                        disabled: !w.hasMedia
                        onClicked: KdeConnect.mpris(w.dev.id, "PlayPause")
                    }

                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: "xs"
                    icon: "skip_next"
                    iconFill: 1
                    tintOverride: w.ink
                    disabled: !w.hasMedia
                    onClicked: KdeConnect.mpris(w.dev.id, "Next")
                }

            }

        }

        ActionGroup {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            btn: Math.min(52, (parent.width - 3 * (w.actions.length - 1)) / Math.max(1, w.actions.length))
        }

    }

    // compact: one row, the mark, name, battery and ring
    Item {
        visible: w.connected && w.variant === "compact"
        anchors.fill: parent
        anchors.margins: 14

        Mark {
            id: cMark

            anchors.verticalCenter: parent.verticalCenter
            d: 44
        }

        Column {
            anchors.left: cMark.right
            anchors.leftMargin: 10
            anchors.right: cRing.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            LText {
                width: parent.width
                role: "titleSmall"
                color: w.ink
                text: w.phoneName
                elide: Text.ElideRight
            }

            LText {
                role: "labelMedium"
                tabular: true
                color: w.inkDim
                text: (w.chargePct >= 0 ? w.chargePct + "%" : "") + (w.charging ? " · charging" : "")
            }

        }

        IconButton {
            id: cRing

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            variant: "tonal"
            size: "s"
            icon: "ring_volume"
            containerOverride: Theme.alpha(w.ink, 0.1)
            tintOverride: w.ink
            onClicked: w.run("ring")
        }

    }

}
