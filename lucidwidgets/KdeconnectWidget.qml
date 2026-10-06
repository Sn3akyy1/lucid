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

    // every phone this machine is paired with, reachable or not
    readonly property var paired: w.preview ? [w.sampleDev] : KdeConnect.reachable.concat(KdeConnect.offline)
    // the one this card was pinned to, when there is more than one
    readonly property string pinnedId: String(w.opt("deviceId") || "")
    readonly property var dev: {
        if (w.preview)
            return w.sampleDev;
        if (w.pinnedId !== "") {
            const pinned = KdeConnect.device(w.pinnedId);
            if (pinned)
                return pinned;

        }
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
    readonly property bool showBrowse: w.opt("showBrowse") !== false
    readonly property bool manyPhones: !w.preview && w.paired.length > 1
    // what an action just did, in the status line for a moment
    property string flash: ""

    readonly property string glyph: w.dev && w.dev.type === "tablet" ? "tablet_android" : "smartphone"
    readonly property string statusLine: {
        if (!w.connected)
            return "";

        if (w.flash !== "")
            return w.flash;

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
            "run": "share",
            "plugin": "kdeconnect_share",
            "off": "Sharing is off on the phone"
        });

        if (w.showRing)
            out.push({
            "icon": "ring_volume",
            "tip": "Ring it",
            "run": "ring",
            "plugin": "kdeconnect_findmyphone",
            "off": "Find my phone is off on the phone"
        });

        if (w.showClipboard)
            out.push({
            "icon": "content_paste_go",
            "tip": "Send the clipboard",
            "run": "clip",
            "plugin": "kdeconnect_clipboard",
            "off": "Clipboard sharing is off on the phone"
        });

        if (w.showBrowse && w.variant !== "compact")
            out.push({
            "icon": "folder_open",
            "tip": "Browse its files",
            "run": "browse",
            "plugin": "kdeconnect_sftp",
            "off": "File browsing is off on the phone"
        });

        out.push({
            "icon": "notifications_active",
            "tip": "Ping",
            "run": "ping",
            "plugin": "kdeconnect_ping",
            "off": "Ping is off on the phone"
        });
        // only worth a button when there is somewhere else to go
        if (w.manyPhones)
            out.push({
            "icon": "swap_horiz",
            "tip": "Another phone",
            "run": "next",
            "plugin": ""
        });

        return out;
    }

    // a phone answers an action only while its own plugin is on
    function can(plugin) {
        return w.preview || plugin === "" || (w.connected && KdeConnect.pluginOn(w.dev, plugin));
    }

    function say(text) {
        w.flash = text;
        flashTimer.restart();
    }

    function nextDevice() {
        if (!w.manyPhones || !w.dev)
            return ;

        const at = w.paired.findIndex((d) => {
            return d.id === w.dev.id;
        });
        w.setOpts({
            "deviceId": w.paired[(at + 1) % w.paired.length].id
        });
    }

    function run(what) {
        if (!w.dev || w.preview)
            return ;

        if (what === "share") {
            KdeConnect.pickFiles(w.dev.id, "Send to " + w.dev.name);
        } else if (what === "ring") {
            KdeConnect.ring(w.dev.id);
            w.say("Ringing " + w.dev.name);
        } else if (what === "clip") {
            KdeConnect.sendClipboard(w.dev.id);
            w.say("Clipboard sent");
        } else if (what === "browse") {
            KdeConnect.browse(w.dev.id);
            w.say("Opening its files");
        } else if (what === "ping") {
            KdeConnect.ping(w.dev.id, "Ping from Lucid");
            w.say("Pinged");
        } else if (what === "next") {
            w.nextDevice();
        }
    }

    Timer {
        id: flashTimer

        interval: 2200
        onTriggered: w.flash = ""
    }

    // the phone's mark: its glyph inside a scalloped shape
    component Mark: MaterialShape {
        id: mk

        property real d: Theme.dp(48)

        width: mk.d
        height: mk.d
        shape: "cookie9"
        color: w.connected ? w.inkAccent : Theme.alpha(w.ink, 0.1)

        Icon {
            anchors.centerIn: parent
            name: w.connected ? w.glyph : "phonelink_off"
            size: mk.d * 0.48
            fill: 1
            color: w.connected ? w.fgInkAccent : w.inkDim
        }

    }

    // the phone's reception, as the cellular symbol that matches it
    component Bars: Icon {
        name: ["signal_cellular_0_bar", "signal_cellular_1_bar", "signal_cellular_2_bar", "signal_cellular_3_bar", "signal_cellular_4_bar"][Math.max(0, Math.min(4, w.sigStrength))]
        size: Theme.dp(18)
        fill: 1
        color: w.ink
    }

    component BatteryRing: Item {
        width: Theme.dp(34)
        height: Theme.dp(34)

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

        property real btn: Theme.dp(44)

        spacing: Theme.dp(3)

        Repeater {
            model: w.actions

            Rectangle {
                id: act

                required property var modelData
                required property int index
                readonly property bool firstOne: act.index === 0
                readonly property bool lastOne: act.index === w.actions.length - 1
                // greyed while the phone has the plugin off; a tap says why
                readonly property bool usable: w.can(act.modelData.plugin)

                width: ag.btn
                height: ag.btn
                topLeftRadius: act.firstOne || actTap.pressed ? ag.btn / 2 : Theme.dp(10)
                bottomLeftRadius: act.firstOne || actTap.pressed ? ag.btn / 2 : Theme.dp(10)
                topRightRadius: act.lastOne || actTap.pressed ? ag.btn / 2 : Theme.dp(10)
                bottomRightRadius: act.lastOne || actTap.pressed ? ag.btn / 2 : Theme.dp(10)
                color: Theme.alpha(w.ink, 0.09)

                Icon {
                    anchors.centerIn: parent
                    name: act.modelData.icon
                    size: Theme.dp(20)
                    color: w.ink
                    opacity: act.usable ? 1 : 0.38
                }

                StateLayer {
                    id: actTap

                    radius: Theme.dp(10)
                    tint: w.ink
                    onClicked: act.usable ? w.run(act.modelData.run) : w.say(act.modelData.off)
                }

            }

        }

    }

    // nothing paired or nothing reachable
    Column {
        visible: !w.connected
        anchors.centerIn: parent
        width: parent.width - Theme.dp(32)
        spacing: Theme.dp(8)

        Mark {
            anchors.horizontalCenter: parent.horizontalCenter
            d: Math.min(Theme.dp(56), w.height * 0.34)
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
        x: Theme.dp(16)
        y: Theme.dp(14)
        width: parent.width - Theme.dp(32)
        height: Theme.dp(48)

        Mark {
            id: headMark

            anchors.verticalCenter: parent.verticalCenter
            d: Theme.dp(46)
        }

        Column {
            anchors.left: headMark.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: headBatt.left
            anchors.rightMargin: Theme.dp(8)
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
                spacing: Theme.dp(6)

                Bars {
                    id: headBars

                    visible: w.sigStrength >= 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                LText {
                    width: parent.width - (headBars.visible ? headBars.width + Theme.dp(6) : 0)
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
        anchors.bottomMargin: Theme.dp(16)
        btn: Math.min(Theme.dp(52), (w.width - Theme.dp(32) - 3 * (w.actions.length - 1)) / Math.max(1, w.actions.length))
    }

    // remote: the header, what the phone is playing, and the actions
    Item {
        visible: w.connected && w.variant === "remote"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Theme.dp(14)
        anchors.topMargin: Theme.dp(12)

        Rectangle {
            id: nowPlaying

            width: parent.width
            height: Theme.dp(60)
            radius: Theme.dp(18)
            color: Theme.alpha(w.ink, 0.07)

            Icon {
                id: npIcon

                x: Theme.dp(14)
                anchors.verticalCenter: parent.verticalCenter
                name: "music_note"
                size: Theme.dp(20)
                color: w.inkAccent
            }

            Column {
                anchors.left: npIcon.right
                anchors.leftMargin: Theme.dp(10)
                anchors.right: npCtl.left
                anchors.rightMargin: Theme.dp(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: -Theme.dp(2)

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
                anchors.rightMargin: Theme.dp(6)
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
                    width: Theme.dp(40)
                    height: Theme.dp(40)
                    radius: npTap.pressed ? Theme.dp(12) : Theme.dp(20)
                    color: w.inkAccent
                    opacity: w.hasMedia ? 1 : 0.4

                    Icon {
                        anchors.centerIn: parent
                        name: w.isPlaying ? "pause" : "play_arrow"
                        size: Theme.dp(22)
                        fill: 1
                        color: w.fgInkAccent
                    }

                    StateLayer {
                        id: npTap

                        radius: parent.radius
                        tint: w.fgInkAccent
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
            btn: Math.min(Theme.dp(52), (parent.width - 3 * (w.actions.length - 1)) / Math.max(1, w.actions.length))
        }

    }

    // compact: one row, the mark, name, battery and ring
    Item {
        visible: w.connected && w.variant === "compact"
        anchors.fill: parent
        anchors.margins: Theme.dp(14)

        Mark {
            id: cMark

            anchors.verticalCenter: parent.verticalCenter
            d: Theme.dp(44)
        }

        Column {
            anchors.left: cMark.right
            anchors.leftMargin: Theme.dp(10)
            anchors.right: cRing.left
            anchors.rightMargin: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: -Theme.dp(2)

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
            disabled: !w.can("kdeconnect_findmyphone")
            tooltip: cRing.disabled ? "Find my phone is off on the phone" : "Ring it"
            onClicked: w.run("ring")
        }

    }

}
