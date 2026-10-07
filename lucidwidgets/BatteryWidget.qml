import QtQuick
import Quickshell.Services.UPower
import qs
import qs.lucidui

WidgetBody {
    id: w

    defaultTone: "secondary"

    readonly property var dev: UPower.displayDevice
    readonly property bool present: w.dev ? w.dev.isPresent : false
    readonly property real level: w.present ? w.dev.percentage : 0
    readonly property int percent: Math.round(w.level * 100)
    readonly property int state: w.dev ? w.dev.state : UPowerDeviceState.Unknown
    readonly property bool charging: w.state === UPowerDeviceState.Charging || w.state === UPowerDeviceState.PendingCharge
    readonly property bool full: w.state === UPowerDeviceState.FullyCharged
    readonly property bool low: w.opt("warnLow") !== false && !w.charging && w.level <= 0.2
    readonly property real rate: w.dev ? Math.abs(w.dev.changeRate) : 0
    readonly property real health: (w.dev && w.dev.healthSupported) ? w.dev.healthPercentage : -1
    readonly property color tint: w.low ? Theme.error : w.inkAccent
    readonly property string stateText: {
        if (!w.present)
            return "No battery";

        if (w.full)
            return "Fully charged";

        if (w.charging)
            return "Charging";

        if (w.state === UPowerDeviceState.Empty)
            return "Empty";

        return "On battery";
    }
    // only the figures this battery actually reports, so no column reads as a dash
    readonly property var stats: {
        var out = [];
        if (w.timeText !== "")
            out.push({
                "label": w.charging ? "UNTIL FULL" : "REMAINING",
                "value": w.timeText.replace(" to full", "").replace(" left", "")
            });

        if (w.rate > 0.05)
            out.push({
                "label": w.charging ? "CHARGING AT" : "DRAWING",
                "value": w.rate.toFixed(1) + " W"
            });

        if (w.capacity > 0)
            out.push({
                "label": "CAPACITY",
                "value": w.capacity.toFixed(1) + " Wh"
            });

        if (w.health >= 0)
            out.push({
                "label": "HEALTH",
                "value": Math.round(w.health) + "%"
            });

        if (out.length === 0)
            out.push({
                "label": "STATE",
                "value": w.stateText
            });

        return out.slice(0, 3);
    }
    readonly property real capacity: w.dev ? w.dev.energyCapacity : 0
    readonly property string timeText: {
        if (!w.present || w.opt("showTime") === false)
            return "";

        var secs = w.charging ? (w.dev ? w.dev.timeToFull : 0) : (w.dev ? w.dev.timeToEmpty : 0);
        if (!secs || secs <= 0)
            return w.full ? "" : "estimating…";

        var h = Math.floor(secs / 3600);
        var m = Math.round((secs % 3600) / 60);
        var body = h > 0 ? h + " h " + m + " m" : m + " m";
        return w.charging ? body + " to full" : body + " left";
    }

    // every other battery upower can see: mice, headsets, a paired phone
    readonly property var others: {
        var out = [];
        var list = UPower.devices.values;
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (!d || !d.isPresent || d.type === UPowerDeviceType.LinePower || d.nativePath === "" && d.model === "")
                continue;

            if (d.type === UPowerDeviceType.Battery && d.powerSupply)
                continue;

            out.push(d);
        }
        return out;
    }

    function glyphFor(d) {
        switch (d.type) {
        case UPowerDeviceType.Mouse:
            return "mouse";
        case UPowerDeviceType.Keyboard:
            return "keyboard";
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones:
            return "headphones";
        case UPowerDeviceType.Phone:
            return "smartphone";
        case UPowerDeviceType.Tablet:
            return "tablet";
        case UPowerDeviceType.GamingInput:
            return "stadia_controller";
        case UPowerDeviceType.Speakers:
            return "speaker";
        }
        return "battery_full";
    }

    // the battery glyph that matches the level, in eighths like the bar's
    readonly property string levelGlyph: {
        if (w.charging)
            return "battery_charging_full";

        if (w.full)
            return "battery_full";

        var steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"];
        return steps[Math.max(0, Math.min(7, Math.floor(w.level * 8)))];
    }

    component DeviceRow: Rectangle {
        id: dr

        property string glyph: ""
        property string label: ""
        property real value: 0
        property bool plugged: false
        property bool first: false
        property bool last: false
        readonly property color hue: dr.value <= 0.2 && !dr.plugged ? Theme.error : w.inkAccent

        width: parent ? parent.width : 0
        height: Theme.dp(48)
        topLeftRadius: dr.first ? Theme.rad(18) : Theme.dp(6)
        topRightRadius: dr.first ? Theme.rad(18) : Theme.dp(6)
        bottomLeftRadius: dr.last ? Theme.rad(18) : Theme.dp(6)
        bottomRightRadius: dr.last ? Theme.rad(18) : Theme.dp(6)
        color: Theme.alpha(w.ink, 0.07)

        Item {
            id: drRing

            x: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(34)
            height: Theme.dp(34)

            CircularProgress {
                anchors.fill: parent
                thickness: 3.5
                value: dr.value
                color: dr.hue
                trackColor: Theme.alpha(w.ink, 0.12)
            }

            Icon {
                anchors.centerIn: parent
                name: dr.glyph
                size: Theme.dp(17)
                fill: 1
                color: w.ink
            }

        }

        LText {
            anchors.left: drRing.right
            anchors.leftMargin: Theme.dp(12)
            anchors.right: drVal.left
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            role: "bodyMedium"
            weight: 520
            color: w.ink
            text: dr.label
            elide: Text.ElideRight
        }

        Row {
            id: drVal

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            Icon {
                visible: dr.plugged
                anchors.verticalCenter: parent.verticalCenter
                name: "bolt"
                size: Theme.dp(15)
                fill: 1
                color: w.inkAccent
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelLarge"
                weight: 660
                tabular: true
                color: w.ink
                text: Math.round(dr.value * 100) + "%"
            }

        }

    }

    // ring: one thick ring, the number inside, a bolt shape turning while it charges
    Item {
        id: ring

        readonly property real d: Math.min(width, height) - Theme.dp(20)

        visible: w.variant === "ring"
        anchors.fill: parent

        MaterialShape {
            anchors.centerIn: parent
            width: ring.d - Theme.dp(34)
            height: width
            shape: w.charging ? "cookie9" : "circle"
            color: Theme.alpha(w.tint, w.charging ? 0.16 : 0.08)

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 16000
                loops: Animation.Infinite
                running: w.charging && w.visible && !w.preview
            }

        }

        CircularProgress {
            anchors.centerIn: parent
            width: ring.d
            height: width
            thickness: Theme.dp(10)
            value: w.level
            color: w.tint
            trackColor: Theme.alpha(w.ink, 0.1)
        }

        Column {
            anchors.centerIn: parent
            spacing: -Theme.dp(4)

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: w.charging ? "bolt" : (w.low ? "battery_alert" : "battery_full")
                size: Theme.dp(20)
                fill: 1
                color: w.tint
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter

                LText {
                    role: "displaySmall"
                    weight: 680
                    rounded: 100
                    tabular: true
                    color: w.ink
                    text: w.present ? w.percent : "—"
                }

                LText {
                    anchors.baseline: parent.children[0].baseline
                    role: "titleSmall"
                    weight: 600
                    color: w.inkDim
                    text: w.present ? "%" : ""
                }

            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "labelSmall"
                color: w.inkDim
                text: w.timeText !== "" && w.timeText !== "estimating…" ? w.timeText : w.stateText
            }

        }

    }

    // bar: the battery itself, drawn as a big stadium that fills
    Item {
        visible: w.variant === "bar"
        anchors.fill: parent
        anchors.margins: Theme.dp(18)

        Item {
            id: cell

            width: parent.width - Theme.dp(8)
            height: Theme.dp(46)

            Rectangle {
                anchors.fill: parent
                radius: Theme.rad(16)
                color: Theme.alpha(w.ink, 0.1)
            }

            Rectangle {
                width: Math.max(Theme.dp(32), parent.width * w.level)
                height: parent.height
                radius: Theme.rad(16)
                color: w.tint

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durDefaultSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.dp(14)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(6)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: w.charging
                    name: "bolt"
                    size: Theme.dp(20)
                    fill: 1
                    color: w.level > 0.25 ? w.fgInkAccent : w.ink
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "titleLarge"
                    weight: 700
                    rounded: 100
                    tabular: true
                    color: w.level > 0.25 ? (w.low ? Theme.fgError : w.fgInkAccent) : w.ink
                    text: w.present ? w.percent + "%" : "No battery"
                }

            }

        }

        // the terminal nub
        Rectangle {
            anchors.left: cell.right
            anchors.leftMargin: Theme.dp(3)
            anchors.verticalCenter: cell.verticalCenter
            width: Theme.dp(5)
            height: Theme.dp(18)
            radius: 2.5
            color: w.level >= 0.999 ? w.tint : Theme.alpha(w.ink, 0.1)
        }

        LText {
            anchors.bottom: parent.bottom
            role: "labelLarge"
            color: w.ink
            text: w.stateText
        }

        LText {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            role: "labelLarge"
            color: w.inkDim
            text: w.timeText
        }

    }

    // detail: the number, a wavy bar that moves while it charges, and the figures
    Item {
        visible: w.variant === "detail"
        anchors.fill: parent
        anchors.margins: Theme.dp(18)

        Row {
            id: dHead

            spacing: Theme.dp(12)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(44)
                height: Theme.dp(44)
                radius: Theme.rad(14)
                color: Theme.alpha(w.tint, 0.16)

                Icon {
                    anchors.centerIn: parent
                    name: w.levelGlyph
                    size: Theme.dp(24)
                    fill: 1
                    color: w.tint
                }

            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -Theme.dp(4)

                LText {
                    role: "headlineMedium"
                    weight: 680
                    rounded: 100
                    tabular: true
                    color: w.ink
                    text: w.present ? w.percent + "%" : "—"
                }

                LText {
                    role: "labelMedium"
                    color: w.inkDim
                    text: w.stateText
                }

            }

        }

        LinearProgress {
            id: dBar

            anchors.top: dHead.bottom
            anchors.topMargin: Theme.dp(14)
            width: parent.width
            value: w.level
            thickness: Theme.dp(6)
            wavy: w.charging && !w.preview
            color: w.tint
            trackColor: Theme.alpha(w.ink, 0.1)
        }

        Row {
            anchors.bottom: parent.bottom
            width: parent.width

            Repeater {
                model: w.stats

                Column {
                    id: stat

                    required property var modelData

                    width: parent.width / Math.max(1, w.stats.length)
                    spacing: 0

                    LText {
                        role: "labelSmall"
                        color: w.inkFaint
                        text: stat.modelData.label
                    }

                    LText {
                        role: "titleSmall"
                        weight: 640
                        tabular: true
                        color: w.ink
                        text: stat.modelData.value
                    }

                }

            }

        }

    }

    // devices: this machine first, then whatever else is reporting a battery
    Column {
        visible: w.variant === "devices"
        anchors.fill: parent
        anchors.margins: Theme.dp(14)
        spacing: Theme.dp(4)

        DeviceRow {
            visible: w.present
            first: true
            last: w.others.length === 0
            glyph: "laptop_chromebook"
            label: "This computer"
            value: w.level
            plugged: w.charging || w.full
        }

        Repeater {
            model: w.others.slice(0, 3)

            DeviceRow {
                required property var modelData
                required property int index

                first: !w.present && index === 0
                last: index === Math.min(3, w.others.length) - 1
                glyph: w.glyphFor(modelData)
                label: modelData.model || "Device"
                value: modelData.percentage
                plugged: modelData.state === UPowerDeviceState.Charging
            }

        }

        LText {
            visible: w.others.length === 0
            width: parent.width
            topPadding: Theme.dp(6)
            horizontalAlignment: Text.AlignHCenter
            role: "labelMedium"
            color: w.inkFaint
            text: "Wireless devices show up here when they report a charge"
            wrapMode: Text.Wrap
        }

    }

}
