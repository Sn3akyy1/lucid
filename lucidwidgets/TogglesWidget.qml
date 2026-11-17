import QtQuick
import Quickshell.Networking
import qs
import qs.lucidui

// quick settings on the desktop; each one changes shape as it comes on
WidgetBody {
    id: w

    readonly property var sets: ({
        "connect": ["wifi", "bluetooth", "dnd", "awake"],
        "evening": ["dark", "nightlight", "dnd", "awake"],
        "sound": ["sound", "mic", "bluetooth", "dnd"]
    })
    readonly property var keys: w.sets[w.opt("set")] || w.sets["connect"]
    readonly property var litShapes: ["cookie9", "clover4", "sunny", "flower"]
    readonly property string ssid: {
        const d = Net.wifiDevice;
        if (!d || !d.networks)
            return "";

        const n = d.networks.values.find((x) => {
            return x.connected;
        });
        return n ? n.name : "";
    }
    readonly property string btDevice: {
        if (!Bt.on || !Bt.adapter.devices)
            return "";

        const d = Bt.adapter.devices.values.find((x) => {
            return x.connected;
        });
        return d ? d.name : "";
    }
    // the shapes sit on the wallpaper, so their off colour is the card's, opaque
    readonly property color offFill: w.bare ? Theme.alpha(w.fill, 1) : Theme.alpha(w.ink, 0.1)

    // icon, label, whether it is on, and the line under the label
    function info(key) {
        switch (key) {
        case "wifi":
            return {
                "icon": Networking.wifiEnabled ? "wifi" : "wifi_off",
                "label": I18n.tr("Wi-Fi"),
                "on": Networking.wifiEnabled,
                "state": !Networking.wifiEnabled ? I18n.tr("Off") : (w.ssid !== "" ? w.ssid : I18n.tr("On"))
            };
        case "bluetooth":
            return {
                "icon": !Bt.on ? "bluetooth_disabled" : (w.btDevice !== "" ? "bluetooth_connected" : "bluetooth"),
                "label": I18n.tr("Bluetooth"),
                "on": Bt.on,
                "state": !Bt.present ? I18n.tr("No adapter") : (!Bt.on ? I18n.tr("Off") : (w.btDevice !== "" ? w.btDevice : I18n.tr("On")))
            };
        case "dnd":
            return {
                "icon": "do_not_disturb_on",
                "label": I18n.tr("Do not disturb"),
                "on": Notifs.dnd,
                "state": Notifs.dnd ? I18n.tr("On") : I18n.tr("Off")
            };
        case "awake":
            return {
                "icon": "coffee",
                "label": I18n.tr("Keep awake"),
                "on": Prefs.idleKeepAwake,
                "state": Prefs.idleKeepAwake ? I18n.tr("On") : I18n.tr("Off")
            };
        case "dark":
            return {
                "icon": Prefs.colorMode === "dark" ? "dark_mode" : "light_mode",
                "label": I18n.tr("Dark theme"),
                "on": Prefs.colorMode === "dark",
                "state": Prefs.colorMode === "dark" ? I18n.tr("On") : I18n.tr("Off")
            };
        case "nightlight":
            return {
                "icon": "nightlight",
                "label": I18n.tr("Night light"),
                "on": NightLight.active,
                "state": NightLight.status
            };
        case "sound":
            return {
                "icon": Audio.mutedOf(Audio.sink) ? "volume_off" : "volume_up",
                "label": I18n.tr("Sound"),
                "on": !Audio.mutedOf(Audio.sink),
                "state": Audio.mutedOf(Audio.sink) ? I18n.tr("Muted") : Audio.volumeOf(Audio.sink) + "%"
            };
        case "mic":
            return {
                "icon": Audio.mutedOf(Audio.source) ? "mic_off" : "mic",
                "label": I18n.tr("Microphone"),
                "on": !Audio.mutedOf(Audio.source),
                "state": Audio.mutedOf(Audio.source) ? I18n.tr("Muted") : I18n.tr("On")
            };
        }
        return {
            "icon": "",
            "label": "",
            "on": false,
            "state": ""
        };
    }

    function toggle(key) {
        if (!w.live)
            return ;

        switch (key) {
        case "wifi":
            Networking.wifiEnabled = !Networking.wifiEnabled;
            break;
        case "bluetooth":
            Bt.setEnabled(!Bt.on);
            break;
        case "dnd":
            Notifs.toggleDnd();
            break;
        case "awake":
            Prefs.idleKeepAwake = !Prefs.idleKeepAwake;
            break;
        case "dark":
            Prefs.setColorMode(Prefs.colorMode === "dark" ? "light" : "dark");
            break;
        case "nightlight":
            NightLight.toggle();
            break;
        case "sound":
            Audio.toggleMute(Audio.sink);
            break;
        case "mic":
            Audio.toggleMute(Audio.source);
            break;
        }
    }

    bare: w.variant === "shapes"
    pill: w.variant === "row"

    // shapes: round while off, an expressive shape spinning in as each comes on
    Grid {
        id: shapeGrid

        readonly property int cell: Math.floor((w.width - shapeGrid.spacing) / 2)

        visible: w.variant === "shapes"
        anchors.centerIn: parent
        columns: 2
        spacing: Theme.dp(10)

        Repeater {
            model: w.variant === "shapes" ? w.keys : []

            Item {
                id: sw

                required property string modelData
                required property int index
                readonly property var st: w.info(sw.modelData)

                width: shapeGrid.cell
                height: shapeGrid.cell

                MaterialShape {
                    anchors.fill: parent
                    shape: "circle"
                    to: w.litShapes[sw.index % w.litShapes.length]
                    morph: sw.st.on ? 1 : 0
                    color: sw.st.on ? w.inkAccent : w.offFill
                    rotation: sw.st.on ? 0 : -60
                    scale: swTap.pressed ? 0.9 : (swTap.containsMouse ? 1.04 : 1)

                    Behavior on morph {
                        NumberAnimation {
                            duration: Theme.durDefaultSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveStandard
                        }

                    }

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.durSlowSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveSlowSpatial
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durDefaultEffects
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                }

                Icon {
                    anchors.centerIn: parent
                    name: sw.st.icon
                    size: Math.round(sw.width * 0.34)
                    fill: sw.st.on ? 1 : 0
                    color: sw.st.on ? w.fgInkAccent : w.ink
                }

                WidgetTap {
                    id: swTap

                    anchors.fill: parent
                    widget: w
                    onTapped: w.toggle(sw.modelData)
                }

            }

        }

    }

    // row: round buttons that square up when on
    Row {
        visible: w.variant === "row"
        anchors.centerIn: parent
        spacing: Theme.dp(10)

        Repeater {
            model: w.variant === "row" ? w.keys : []

            Item {
                id: btn

                required property string modelData
                readonly property var st: w.info(btn.modelData)

                width: Theme.dp(60)
                height: Theme.dp(60)

                MaterialShape {
                    anchors.fill: parent
                    shape: "circle"
                    to: "square"
                    morph: btn.st.on ? 1 : 0
                    color: btn.st.on ? w.inkAccent : w.offFill
                    scale: btnTap.pressed ? 0.9 : (btnTap.containsMouse ? 1.06 : 1)

                    Behavior on morph {
                        NumberAnimation {
                            duration: Theme.durDefaultSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveStandard
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durDefaultEffects
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
                        }

                    }

                }

                Icon {
                    anchors.centerIn: parent
                    name: btn.st.icon
                    size: Theme.dp(24)
                    fill: btn.st.on ? 1 : 0
                    color: btn.st.on ? w.fgInkAccent : w.ink
                }

                WidgetTap {
                    id: btnTap

                    anchors.fill: parent
                    widget: w
                    onTapped: w.toggle(btn.modelData)
                }

            }

        }

    }

    // tiles: quick settings tiles, a pill while off and squarer while on
    Grid {
        id: tileGrid

        visible: w.variant === "tiles"
        anchors.fill: parent
        anchors.margins: Theme.dp(14)
        columns: 2
        spacing: Theme.dp(8)

        Repeater {
            model: w.variant === "tiles" ? w.keys : []

            Rectangle {
                id: tile

                required property string modelData
                readonly property var st: w.info(tile.modelData)

                width: Math.floor((tileGrid.width - tileGrid.spacing) / 2)
                height: Math.floor((tileGrid.height - tileGrid.spacing) / 2)
                radius: tile.st.on ? Theme.rad(18) : tile.height / 2
                color: tile.st.on ? w.inkAccent : Theme.alpha(w.ink, 0.08)

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durDefaultSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }

                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: tile.st.on ? w.fgInkAccent : w.ink
                    opacity: tileTap.pressed ? 0.12 : (tileTap.containsMouse ? 0.07 : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

                Rectangle {
                    id: tileIcon

                    x: Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(40)
                    height: Theme.dp(40)
                    radius: width / 2
                    color: tile.st.on ? Theme.alpha(w.fgInkAccent, 0.16) : Theme.alpha(w.ink, 0.1)

                    Icon {
                        anchors.centerIn: parent
                        name: tile.st.icon
                        size: Theme.dp(20)
                        fill: tile.st.on ? 1 : 0
                        color: tile.st.on ? w.fgInkAccent : w.ink
                    }

                }

                Column {
                    anchors.left: tileIcon.right
                    anchors.leftMargin: Theme.dp(10)
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    LText {
                        width: parent.width
                        elide: Text.ElideRight
                        role: "titleSmall"
                        color: tile.st.on ? w.fgInkAccent : w.ink
                        text: tile.st.label
                    }

                    LText {
                        width: parent.width
                        elide: Text.ElideRight
                        role: "bodySmall"
                        color: tile.st.on ? Theme.alpha(w.fgInkAccent, 0.8) : w.inkDim
                        text: tile.st.state
                    }

                }

                WidgetTap {
                    id: tileTap

                    anchors.fill: parent
                    widget: w
                    onTapped: w.toggle(tile.modelData)
                }

            }

        }

    }

}
