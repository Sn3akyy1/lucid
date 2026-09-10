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

    // ------------------------------------------------ Empty / Disconnected state
    Item {
        id: emptyState
        visible: !w.connected
        anchors.fill: parent

        Column {
            anchors.centerIn: parent
            spacing: 8
            width: parent.width - 24

            WidgetGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "kdeconnect"
                size: 32
                color: Theme.subtext
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: KdeConnect.installed ? "No phone connected" : "KDE Connect unavailable"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: KdeConnect.installed ? "Pair a phone in Settings" : "Install kdeconnect to connect phone"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            WidgetButton {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: "refresh"
                diameter: 32
                iconSize: 16
                surface: true
                tip: "Rescan devices"
                onClicked: KdeConnect.rescan()
            }
        }
    }

    // ------------------------------------------------ Compact Variant
    Item {
        id: compactView
        visible: w.connected && w.variant === "compact"
        anchors.fill: parent

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: Theme.alpha(Theme.accent, 0.15)
                anchors.verticalCenter: parent.verticalCenter

                WidgetGlyph {
                    anchors.centerIn: parent
                    name: "phone"
                    size: 20
                    color: Theme.accent
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 46 - (w.showShare ? 42 : 0) - (w.showRing ? 42 : 0)
                spacing: 2

                Text {
                    text: w.phoneName
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }

                Row {
                    spacing: 6

                    WidgetGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "battery"
                        size: 12
                        color: w.charging ? Theme.accent : Theme.subtext
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: w.chargePct >= 0 ? (w.chargePct + "%" + (w.charging ? "⚡" : "")) : "Connected"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            WidgetButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: w.showShare
                icon: "share"
                diameter: 32
                iconSize: 16
                surface: true
                tip: "Send file"
                onClicked: if (w.dev) KdeConnect.pickFiles(w.dev.id, "Send to " + w.dev.name)
            }

            WidgetButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: w.showRing
                icon: "ring"
                diameter: 32
                iconSize: 16
                surface: true
                tip: "Ring phone"
                onClicked: if (w.dev) KdeConnect.ring(w.dev.id)
            }
        }
    }

    // ------------------------------------------------ Card Variant
    Item {
        id: cardView
        visible: w.connected && (w.variant === "card" || w.variant === "" || !w.variant)
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Header: Icon + Name + Status pill
            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    color: Theme.alpha(Theme.accent, 0.15)

                    WidgetGlyph {
                        anchors.centerIn: parent
                        name: "phone"
                        size: 20
                        color: Theme.accent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 48
                    spacing: 2

                    Text {
                        text: w.phoneName
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Row {
                        spacing: 8

                        Row {
                            spacing: 4
                            visible: w.chargePct >= 0

                            WidgetGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "battery"
                                size: 12
                                color: w.charging ? Theme.accent : Theme.subtext
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: w.chargePct + "%" + (w.charging ? " (Charging)" : "")
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            visible: w.netType !== ""
                            text: "• " + w.netType
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // Stats gauge / status bar
            Rectangle {
                width: parent.width
                height: 40
                radius: Theme.radiusMd
                color: Theme.alpha(Theme.bgHigh, 0.6)

                Row {
                    anchors.fill: parent
                    anchors.margins: 8

                    // Battery bar
                    Item {
                        width: parent.width / 2
                        height: parent.height

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 80
                                height: 8
                                radius: 4
                                color: Theme.alpha(Theme.outline, 0.3)
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: Math.max(4, parent.width * Math.max(0, Math.min(1, w.chargePct / 100)))
                                    height: parent.height
                                    radius: 4
                                    color: w.chargePct <= 20 ? Theme.error : Theme.accent
                                }
                            }

                            Text {
                                text: w.chargePct >= 0 ? (w.chargePct + "%") : "—"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Signal indicator
                    Item {
                        width: parent.width / 2
                        height: parent.height

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            WidgetGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "system"
                                size: 14
                                color: Theme.subtext
                            }

                            Text {
                                text: w.sigStrength >= 0 ? ("Signal " + w.sigStrength + "/5") : "Connected"
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // Action Buttons Row
            Row {
                width: parent.width
                spacing: 8

                WidgetButton {
                    visible: w.showShare
                    icon: "share"
                    diameter: 36
                    iconSize: 18
                    surface: true
                    tip: "Send file"
                    onClicked: if (w.dev) KdeConnect.pickFiles(w.dev.id, "Send to " + w.dev.name)
                }

                WidgetButton {
                    visible: w.showRing
                    icon: "ring"
                    diameter: 36
                    iconSize: 18
                    surface: true
                    tip: "Ring phone"
                    onClicked: if (w.dev) KdeConnect.ring(w.dev.id)
                }

                WidgetButton {
                    visible: w.showClipboard
                    icon: "clipboard"
                    diameter: 36
                    iconSize: 18
                    surface: true
                    tip: "Send clipboard"
                    onClicked: if (w.dev) KdeConnect.sendClipboard(w.dev.id)
                }

                WidgetButton {
                    icon: "refresh"
                    diameter: 36
                    iconSize: 18
                    surface: true
                    tip: "Ping phone"
                    onClicked: if (w.dev) KdeConnect.ping(w.dev.id, "Ping from Lucid")
                }
            }
        }
    }

    // ------------------------------------------------ Remote Variant
    Item {
        id: remoteView
        visible: w.connected && w.variant === "remote"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Header
            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Theme.alpha(Theme.accent, 0.15)
                    anchors.verticalCenter: parent.verticalCenter

                    WidgetGlyph {
                        anchors.centerIn: parent
                        name: "phone"
                        size: 16
                        color: Theme.accent
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: w.phoneName
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - 90
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: w.chargePct >= 0 ? (w.chargePct + "%") : ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            // Media card if active, or status details
            Rectangle {
                width: parent.width
                height: 86
                radius: Theme.radiusLg
                color: Theme.alpha(Theme.bgHigh, 0.6)

                Column {
                    visible: w.hasMedia
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: w.trackTitle
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: w.trackArtist
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        WidgetButton {
                            icon: "prev"
                            diameter: 28
                            iconSize: 14
                            tip: "Previous track"
                            onClicked: if (w.dev) KdeConnect.mpris(w.dev.id, "Previous")
                        }

                        WidgetButton {
                            icon: w.isPlaying ? "pause" : "play"
                            diameter: 28
                            iconSize: 14
                            filled: true
                            tip: w.isPlaying ? "Pause" : "Play"
                            onClicked: if (w.dev) KdeConnect.mpris(w.dev.id, "PlayPause")
                        }

                        WidgetButton {
                            icon: "next"
                            diameter: 28
                            iconSize: 14
                            tip: "Next track"
                            onClicked: if (w.dev) KdeConnect.mpris(w.dev.id, "Next")
                        }
                    }
                }

                // Idle message if no media active
                Column {
                    visible: !w.hasMedia
                    anchors.centerIn: parent
                    spacing: 4

                    WidgetGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "media"
                        size: 20
                        color: Theme.subtext
                    }

                    Text {
                        text: "No active media playing on phone"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            // Quick actions grid
            Row {
                width: parent.width
                spacing: 8

                WidgetButton {
                    visible: w.showShare
                    icon: "share"
                    diameter: 36
                    iconSize: 18
                    surface: true
                    tip: "Send file"
                    onClicked: if (w.dev) KdeConnect.pickFiles(w.dev.id, "Send to " + w.dev.name)
                }

                WidgetButton {
                    visible: w.showRing
                    icon: "ring"
                    diameter: 36
                    iconSize: 18
                    surface: true
                    tip: "Ring phone"
                    onClicked: if (w.dev) KdeConnect.ring(w.dev.id)
                }

                WidgetButton {
                    visible: w.showClipboard
                    icon: "clipboard"
                    diameter: 36
                    iconSize: 18
                    surface: true
                    tip: "Send clipboard"
                    onClicked: if (w.dev) KdeConnect.sendClipboard(w.dev.id)
                }

                WidgetButton {
                    icon: "refresh"
                    diameter: 36
                    iconSize: 18
                    surface: true
                    tip: "Ping phone"
                    onClicked: if (w.dev) KdeConnect.ping(w.dev.id, "Ping from Lucid")
                }
            }
        }
    }
}
