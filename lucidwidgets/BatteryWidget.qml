import QtQuick
import Quickshell.Services.UPower
import qs

WidgetBody {
    id: w

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
    readonly property color tint: w.low ? Theme.error : Theme.accent
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

    Item {
        id: ring

        visible: w.variant === "ring"
        anchors.fill: parent

        Gauge {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - 34
            height: width
            thickness: 9
            value: w.level
            fillColor: w.tint
            startAngle: -215
            sweep: 250
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -4
            spacing: -2

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1

                Text {
                    id: ringNumber

                    anchors.verticalCenter: parent.verticalCenter
                    text: w.present ? w.percent : "—"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 34
                    font.bold: true
                    font.letterSpacing: -1.5
                }

                Text {
                    anchors.baseline: ringNumber.baseline
                    text: w.present ? "%" : ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3

                WidgetGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "bolt"
                    size: 12
                    color: w.tint
                    visible: w.charging
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: w.charging ? "charging" : (w.full ? "full" : w.stateText.toLowerCase())
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

            }

        }

    }

    Item {
        id: bar

        visible: w.variant === "bar"
        anchors.fill: parent
        anchors.margins: 20

        Row {
            id: barHead

            anchors.left: parent.left
            anchors.top: parent.top
            spacing: 6

            Text {
                anchors.bottom: parent.bottom
                text: w.present ? w.percent + "%" : "—"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 30
                font.bold: true
                font.letterSpacing: -1
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                text: w.timeText
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            text: w.stateText
            color: w.tint
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }

        // a cell drawn side on, terminal and all
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 26

            Rectangle {
                id: cell

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 7
                height: parent.height
                radius: 9
                color: Theme.alpha(Theme.text, 0.1)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 3
                    width: Math.max(height, (parent.width - 6) * Math.max(0, Math.min(1, w.level)))
                    radius: 6
                    color: w.tint

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.ms(520)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            Rectangle {
                anchors.left: cell.right
                anchors.leftMargin: 1
                anchors.verticalCenter: cell.verticalCenter
                width: 5
                height: 11
                topRightRadius: 3
                bottomRightRadius: 3
                color: Theme.alpha(Theme.text, 0.1)
            }

        }

    }

    Item {
        id: detail

        visible: w.variant === "detail"
        anchors.fill: parent
        anchors.margins: 20

        Row {
            id: detailHead

            anchors.left: parent.left
            anchors.top: parent.top
            spacing: 10

            WidgetGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "battery"
                size: 26
                color: w.tint
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2

                Text {
                    text: w.present ? w.percent + "%" : "No battery"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 30
                    font.bold: true
                    font.letterSpacing: -1
                }

                Text {
                    text: w.stateText
                    color: w.tint
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    visible: w.present
                }

            }

        }

        Meter {
            id: detailMeter

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: detailHead.bottom
            anchors.topMargin: 14
            thickness: 6
            value: w.level
            fillColor: w.tint
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: detailMeter.bottom
            anchors.topMargin: 12
            spacing: 0

            Repeater {
                model: w.stats

                Column {
                    id: statCell

                    required property var modelData

                    width: w.stats.length > 0 ? detail.width / w.stats.length : 0
                    spacing: 1

                    Text {
                        text: statCell.modelData.label
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 0.9
                    }

                    Text {
                        width: statCell.width - 6
                        text: statCell.modelData.value
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                    }

                }

            }

        }

    }

}
