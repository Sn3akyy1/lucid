import QtQuick
import qs

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

    readonly property bool low: !w.charging && w.chargePct >= 0 && w.chargePct <= 20
    readonly property color tint: w.low ? Theme.error : Theme.accent
    readonly property real battLevel: w.chargePct >= 0 ? w.chargePct / 100 : 0
    readonly property string stateText: {
        if (w.chargePct < 0)
            return "Connected";

        if (w.charging)
            return w.chargePct >= 100 ? "Fully charged" : "Charging";

        return w.low ? "Battery low" : "On battery";
    }

    component SignalMark: Row {
        spacing: 6
        visible: w.sigStrength >= 0 || w.netType !== ""

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: w.sigStrength >= 0

            Repeater {
                model: 5

                Rectangle {
                    required property int index

                    anchors.bottom: parent.bottom
                    width: 3
                    height: 4 + index * 3
                    radius: 1.5
                    color: index < w.sigStrength ? Theme.text : Theme.alpha(Theme.text, 0.16)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: w.netType !== ""
            text: w.netType
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
        }

    }

    component Bolt: WidgetGlyph {
        name: "bolt"
        color: w.tint
        visible: w.charging

        SequentialAnimation on opacity {
            running: w.charging
            loops: Animation.Infinite

            NumberAnimation {
                from: 1
                to: 0.4
                duration: Theme.ms(900)
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                from: 0.4
                to: 1
                duration: Theme.ms(900)
                easing.type: Easing.InOutSine
            }

        }

    }

    component ActionBar: Row {
        property real diameter: 36
        property real iconSize: 18
        // the compact card has room for the two headline actions only
        property bool full: true

        spacing: 10

        WidgetButton {
            visible: w.showShare
            icon: "share"
            diameter: parent.diameter
            iconSize: parent.iconSize
            surface: true
            hoverGrow: true
            tip: "Send file"
            onClicked: if (w.dev) KdeConnect.pickFiles(w.dev.id, "Send to " + w.dev.name)
        }

        WidgetButton {
            visible: w.showRing
            icon: "ring"
            diameter: parent.diameter
            iconSize: parent.iconSize
            surface: true
            hoverGrow: true
            tip: "Ring phone"
            onClicked: if (w.dev) KdeConnect.ring(w.dev.id)
        }

        WidgetButton {
            visible: w.showClipboard && parent.full
            icon: "clipboard"
            diameter: parent.diameter
            iconSize: parent.iconSize
            surface: true
            hoverGrow: true
            tip: "Send clipboard"
            onClicked: if (w.dev) KdeConnect.sendClipboard(w.dev.id)
        }

        WidgetButton {
            visible: parent.full
            icon: "refresh"
            diameter: parent.diameter
            iconSize: parent.iconSize
            surface: true
            hoverGrow: true
            tip: "Ping phone"
            onClicked: if (w.dev) KdeConnect.ping(w.dev.id, "Ping from Lucid")
        }

    }

    Item {
        id: emptyState

        // compact has no room to stack, so the same content lies down instead
        readonly property bool tight: w.variant === "compact"

        visible: !w.connected
        anchors.fill: parent

        Item {
            visible: emptyState.tight
            anchors.fill: parent
            anchors.margins: 16

            WidgetGlyph {
                id: tightIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "phone"
                size: 26
                color: Theme.subtextDim
            }

            WidgetButton {
                id: tightBtn

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "refresh"
                diameter: 30
                iconSize: 15
                surface: true
                hoverGrow: true
                tip: "Rescan devices"
                onClicked: KdeConnect.rescan()
            }

            Column {
                anchors.left: tightIcon.right
                anchors.leftMargin: 12
                anchors.right: tightBtn.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: KdeConnect.installed ? "No phone" : "Unavailable"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: KdeConnect.installed ? "Pair in Settings" : "Install kdeconnect"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

            }

        }

        // the roomy variants keep the connected skeleton: mark and title up top,
        // the action sitting where the action row sits
        Item {
            visible: !emptyState.tight
            anchors.fill: parent
            anchors.margins: 20

            WidgetGlyph {
                id: roomyIcon

                anchors.left: parent.left
                anchors.top: parent.top
                name: "phone"
                size: 26
                color: Theme.subtextDim
            }

            Text {
                id: roomyTitle

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: roomyIcon.bottom
                anchors.topMargin: 14
                text: KdeConnect.installed ? "No phone connected" : "KDE Connect unavailable"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: roomyTitle.bottom
                anchors.topMargin: 3
                text: KdeConnect.installed ? "Pair a phone in Settings" : "Install kdeconnect to pair a phone"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            WidgetButton {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                icon: "refresh"
                diameter: 36
                iconSize: 18
                surface: true
                hoverGrow: true
                tip: "Rescan devices"
                onClicked: KdeConnect.rescan()
            }

        }

    }

    Item {
        id: compactView

        visible: w.connected && w.variant === "compact"
        anchors.fill: parent
        anchors.margins: 16

        Item {
            id: compactHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 16

            SignalMark {
                id: compactSig

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.left: parent.left
                anchors.right: compactSig.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: w.phoneName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }

        }

        Row {
            id: compactHero

            anchors.left: parent.left
            anchors.top: compactHead.bottom
            anchors.topMargin: 4
            spacing: 2

            Text {
                id: compactPct

                anchors.verticalCenter: parent.verticalCenter
                text: w.chargePct >= 0 ? w.chargePct : "—"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 26
                font.bold: true
                font.letterSpacing: -1
            }

            Text {
                anchors.baseline: compactPct.baseline
                text: w.chargePct >= 0 ? "%" : ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
            }

            Bolt {
                anchors.verticalCenter: parent.verticalCenter
                size: 13
            }

        }

        ActionBar {
            anchors.right: parent.right
            anchors.verticalCenter: compactHero.verticalCenter
            diameter: 30
            iconSize: 15
            spacing: 8
            full: false
        }

        Meter {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            thickness: 5
            value: w.battLevel
            fillColor: w.tint
            visible: w.chargePct >= 0
        }

    }

    Item {
        id: cardView

        visible: w.connected && (w.variant === "card" || w.variant === "" || !w.variant)
        anchors.fill: parent
        anchors.margins: 20

        Item {
            id: cardHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 20

            WidgetGlyph {
                id: cardIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "phone"
                size: 18
                color: Theme.accent
            }

            SignalMark {
                id: cardSig

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.left: cardIcon.right
                anchors.leftMargin: 9
                anchors.right: cardSig.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: w.phoneName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

        }

        Row {
            id: cardHero

            anchors.left: parent.left
            anchors.top: cardHead.bottom
            anchors.topMargin: 14
            spacing: 2

            Text {
                id: cardPct

                anchors.verticalCenter: parent.verticalCenter
                text: w.chargePct >= 0 ? w.chargePct : "—"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 34
                font.bold: true
                font.letterSpacing: -1.5
            }

            Text {
                anchors.baseline: cardPct.baseline
                text: w.chargePct >= 0 ? "%" : ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.bold: true
            }

            Bolt {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 2
                size: 15
            }

        }

        Text {
            anchors.right: parent.right
            anchors.bottom: cardHero.bottom
            anchors.bottomMargin: 7
            text: w.stateText
            color: w.low ? Theme.error : Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1.2
        }

        Meter {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: cardHero.bottom
            anchors.topMargin: 12
            thickness: 6
            value: w.battLevel
            fillColor: w.tint
            visible: w.chargePct >= 0
        }

        ActionBar {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
        }

    }

    Item {
        id: remoteView

        visible: w.connected && w.variant === "remote"
        anchors.fill: parent
        anchors.margins: 20

        Item {
            id: remoteHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 20

            WidgetGlyph {
                id: remoteIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "phone"
                size: 16
                color: Theme.accent
            }

            Row {
                id: remoteBatt

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Bolt {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 12
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: w.chargePct >= 0 ? w.chargePct + "%" : ""
                    color: w.low ? Theme.error : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

            }

            Text {
                anchors.left: remoteIcon.right
                anchors.leftMargin: 8
                anchors.right: remoteBatt.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: w.phoneName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }

        }

        Meter {
            id: remoteMeter

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: remoteHead.bottom
            anchors.topMargin: 8
            thickness: 4
            value: w.battLevel
            fillColor: w.tint
            visible: w.chargePct >= 0
        }

        Item {
            id: remoteMedia

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: remoteMeter.bottom
            anchors.topMargin: 14
            anchors.bottom: remoteRule.top
            anchors.bottomMargin: 14

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: w.hasMedia
                spacing: 1

                Text {
                    width: parent.width
                    text: w.trackTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: w.trackArtist
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

            }

            // same spec as the media widget's transport row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                visible: w.hasMedia
                spacing: 10

                WidgetButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "prev"
                    diameter: 30
                    iconSize: 15
                    surface: true
                    hoverGrow: true
                    tip: "Previous track"
                    onClicked: if (w.dev) KdeConnect.mpris(w.dev.id, "Previous")
                }

                WidgetButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: w.isPlaying ? "pause" : "play"
                    diameter: 40
                    iconSize: 19
                    filled: true
                    hoverGrow: true
                    tip: w.isPlaying ? "Pause" : "Play"
                    onClicked: if (w.dev) KdeConnect.mpris(w.dev.id, "PlayPause")
                }

                WidgetButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "next"
                    diameter: 30
                    iconSize: 15
                    surface: true
                    hoverGrow: true
                    tip: "Next track"
                    onClicked: if (w.dev) KdeConnect.mpris(w.dev.id, "Next")
                }

            }

            Column {
                anchors.centerIn: parent
                visible: !w.hasMedia
                spacing: 6

                WidgetGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "media"
                    size: 24
                    color: Theme.alpha(Theme.text, 0.22)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing playing"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.2
                }

            }

        }

        Rectangle {
            id: remoteRule

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: remoteActions.top
            anchors.bottomMargin: 14
            height: 1
            color: Theme.alpha(Theme.outline, 0.5)
        }

        ActionBar {
            id: remoteActions

            anchors.left: parent.left
            anchors.bottom: parent.bottom
        }

    }

}
