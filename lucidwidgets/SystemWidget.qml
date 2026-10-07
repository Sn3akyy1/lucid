import QtQuick
import qs
import qs.lucidui

WidgetBody {
    id: w

    // a gallery tile draws fixed sample numbers and never wakes the poller
    readonly property var sample: ({
        "cpu": 0.34,
        "ram": 0.62,
        "disk": 0.48,
        "temp": 51,
        "gpu": -1,
        "ramUsedGb": 9.8,
        "ramTotalGb": 15.5,
        "diskUsedGb": 220,
        "diskTotalGb": 460,
        "diskFreeGb": 240,
        "down": 2.4e+06,
        "up": 310000
    })
    readonly property var sampleCpu: {
        var a = [];
        for (var i = 0; i < 60; i++) a.push(0.3 + 0.24 * Math.sin(i / 3.1) + 0.1 * Math.sin(i / 1.3))
        return a;
    }
    readonly property var sampleNet: {
        var a = [];
        for (var i = 0; i < 60; i++) a.push(Math.max(0, 1.2e+06 + 1e+06 * Math.sin(i / 4) + 6e+05 * Math.sin(i / 1.7)))
        return a;
    }
    readonly property real cpu: w.preview ? w.sample.cpu : Sys.cpu
    readonly property real ram: w.preview ? w.sample.ram : Sys.ram
    readonly property real disk: w.preview ? w.sample.disk : Sys.disk
    readonly property real temp: w.preview ? w.sample.temp : Sys.temp
    readonly property real gpu: w.preview ? w.sample.gpu : Sys.gpu
    readonly property var cpuHistory: w.preview ? w.sampleCpu : Sys.cpuHistory
    readonly property var downHistory: w.preview ? w.sampleNet : Sys.downHistory
    readonly property var upHistory: w.preview ? w.sampleNet.map((v) => {
        return v * 0.18;
    }) : Sys.upHistory
    readonly property real down: w.preview ? w.sample.down : Sys.netDown
    readonly property real up: w.preview ? w.sample.up : Sys.netUp
    readonly property int pollMs: {
        var v = parseInt(w.opt("interval"));
        return (v > 0 ? v : 2) * 1000;
    }
    readonly property var metrics: {
        var out = [];
        if (w.opt("showCpu") !== false)
            out.push({
            "key": "cpu",
            "label": "Processor",
            "short": "CPU",
            "icon": "memory",
            "value": w.cpu,
            "text": Math.round(w.cpu * 100) + "%",
            "detail": w.preview ? "3.1 GHz" : (Sys.cpuMhz > 0 ? (Sys.cpuMhz / 1000).toFixed(1) + " GHz" : "")
        });

        if (w.opt("showRam") !== false)
            out.push({
            "key": "ram",
            "label": "Memory",
            "short": "RAM",
            "icon": "memory_alt",
            "value": w.ram,
            "text": Math.round(w.ram * 100) + "%",
            "detail": w.gbOf(w.preview ? w.sample.ramUsedGb : Sys.ramUsedGb, w.preview ? w.sample.ramTotalGb : Sys.ramTotalGb)
        });

        if (w.opt("showDisk") !== false)
            out.push({
            "key": "disk",
            "label": "Disk",
            "short": "Disk",
            "icon": "hard_drive",
            "value": w.disk,
            "text": Math.round(w.disk * 100) + "%",
            "detail": (w.preview || Sys.diskTotalGb > 0) ? Math.round(w.preview ? w.sample.diskFreeGb : Sys.diskFreeGb) + " GB free" : ""
        });

        if (w.opt("showTemp") === true && w.temp >= 0)
            out.push({
            "key": "temp",
            "label": "Temperature",
            "short": "Temp",
            "icon": "thermostat",
            "value": Math.min(1, w.temp / 100),
            "text": Math.round(w.temp) + "°",
            "detail": w.temp > 80 ? "Running hot" : "CPU package"
        });

        if (w.opt("showGpu") === true && w.gpu >= 0)
            out.push({
            "key": "gpu",
            "label": "Graphics",
            "short": "GPU",
            "icon": "developer_board",
            "value": w.gpu,
            "text": Math.round(w.gpu * 100) + "%",
            "detail": Sys.gpuTemp >= 0 ? Math.round(Sys.gpuTemp) + "°" : ""
        });

        return out;
    }

    function gbOf(used, total) {
        return total > 0 ? used.toFixed(1) + " of " + Math.round(total) + " GB" : "";
    }

    // each reading keeps to the palette, and only goes red when it means it
    function tint(key, value) {
        if (value > 0.9 || (key === "temp" && value > 0.85))
            return Theme.error;

        if (key === "temp" && value > 0.7)
            return Theme.warning;

        if (key === "ram" || key === "gpu")
            return w.tonal ? w.inkAccent : Theme.secondary;

        if (key === "disk" || key === "temp")
            return w.tonal ? w.inkAccent : Theme.tertiary;

        return w.inkAccent;
    }

    Component.onCompleted: {
        if (!w.preview)
            Sys.hold(w.uid || "w", true, w.pollMs);

    }
    Component.onDestruction: Sys.hold(w.uid || "w", false)
    onPollMsChanged: {
        if (!w.preview)
            Sys.hold(w.uid || "w", true, w.pollMs);

    }

    // rings: one thick m3 ring per reading, the icon inside, the number under it
    Row {
        visible: w.variant === "rings"
        anchors.centerIn: parent

        Repeater {
            model: w.metrics

            Item {
                id: ring

                required property var modelData
                readonly property real d: Math.min(Theme.dp(84), (w.width - Theme.dp(28)) / Math.max(1, w.metrics.length) - Theme.dp(10))

                width: ring.d + Theme.dp(10)
                height: ring.d + Theme.dp(42)

                CircularProgress {
                    id: arc

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ring.d
                    height: ring.d
                    thickness: Theme.dp(8)
                    value: ring.modelData.value
                    color: w.tint(ring.modelData.key, ring.modelData.value)
                    trackColor: Theme.alpha(w.ink, 0.1)
                }

                Icon {
                    anchors.centerIn: arc
                    name: ring.modelData.icon
                    size: ring.d * 0.34
                    fill: 1
                    color: w.tint(ring.modelData.key, ring.modelData.value)
                }

                Column {
                    anchors.top: arc.bottom
                    anchors.topMargin: Theme.dp(6)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: -Theme.dp(2)

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "titleSmall"
                        weight: 680
                        rounded: 100
                        tabular: true
                        color: w.ink
                        text: ring.modelData.text
                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "labelSmall"
                        color: w.inkDim
                        text: ring.modelData.short
                    }

                }

            }

        }

    }

    // meters: a labelled row per reading over a thick bar with a stop dot
    Column {
        visible: w.variant === "bars"
        anchors.fill: parent
        anchors.margins: Theme.dp(18)
        spacing: Theme.dp(12)

        Repeater {
            model: w.metrics

            Column {
                id: meter

                required property var modelData

                width: parent.width
                spacing: Theme.dp(6)

                Item {
                    width: parent.width
                    height: Theme.dp(20)

                    Icon {
                        id: mIcon

                        anchors.verticalCenter: parent.verticalCenter
                        name: meter.modelData.icon
                        size: Theme.dp(18)
                        fill: 1
                        color: w.tint(meter.modelData.key, meter.modelData.value)
                    }

                    LText {
                        anchors.left: mIcon.right
                        anchors.leftMargin: Theme.dp(8)
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        color: w.ink
                        text: meter.modelData.label
                    }

                    LText {
                        anchors.right: mVal.left
                        anchors.rightMargin: Theme.dp(8)
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelMedium"
                        color: w.inkFaint
                        text: meter.modelData.detail
                    }

                    LText {
                        id: mVal

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        weight: 680
                        tabular: true
                        color: w.ink
                        text: meter.modelData.text
                    }

                }

                LinearProgress {
                    width: parent.width
                    value: meter.modelData.value
                    thickness: Theme.dp(8)
                    color: w.tint(meter.modelData.key, meter.modelData.value)
                    trackColor: Theme.alpha(w.ink, 0.1)
                }

            }

        }

    }

    // graph: the processor's last two minutes, the rest as chips underneath
    Item {
        visible: w.variant === "graph"
        anchors.fill: parent
        anchors.margins: Theme.dp(18)

        Column {
            id: gHead

            spacing: -Theme.dp(4)

            LText {
                role: "labelLarge"
                color: w.inkDim
                text: "Processor"
            }

            LText {
                role: "displaySmall"
                weight: 640
                rounded: 100
                tabular: true
                color: w.ink
                text: Math.round(w.cpu * 100) + "%"
            }

        }

        LText {
            anchors.right: parent.right
            anchors.top: parent.top
            role: "labelMedium"
            color: w.inkFaint
            text: w.preview ? "load 1.2" : "load " + Sys.load1.toFixed(1)
        }

        Spark {
            anchors.top: gHead.bottom
            anchors.topMargin: Theme.dp(4)
            anchors.bottom: gChips.top
            anchors.bottomMargin: Theme.dp(10)
            width: parent.width
            samples: w.cpuHistory
            lineColor: w.tint("cpu", w.cpu)
            lineWidth: 2.5
        }

        Row {
            id: gChips

            anchors.bottom: parent.bottom
            spacing: Theme.dp(6)

            Repeater {
                model: w.metrics.filter((m) => {
                    return m.key !== "cpu";
                })

                Rectangle {
                    id: chip

                    required property var modelData

                    width: chipRow.implicitWidth + Theme.dp(20)
                    height: Theme.dp(28)
                    radius: Theme.dp(14)
                    color: Theme.alpha(w.ink, 0.08)

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: Theme.dp(6)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: chip.modelData.icon
                            size: Theme.dp(15)
                            fill: 1
                            color: w.tint(chip.modelData.key, chip.modelData.value)
                        }

                        LText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "labelMedium"
                            weight: 640
                            tabular: true
                            color: w.ink
                            text: chip.modelData.text
                        }

                    }

                }

            }

        }

    }

    // tiles: a quick-settings grid, each reading in its own tonal tile
    Flow {
        id: tiles

        readonly property int cols: w.metrics.length > 2 ? 2 : w.metrics.length
        readonly property int rows: Math.ceil(w.metrics.length / Math.max(1, tiles.cols))

        visible: w.variant === "tiles"
        anchors.fill: parent
        anchors.margins: Theme.dp(10)
        spacing: Theme.dp(6)

        Repeater {
            model: w.metrics

            Rectangle {
                id: tile

                required property var modelData
                required property int index
                readonly property color hue: w.tint(tile.modelData.key, tile.modelData.value)

                // an odd one out takes the whole last row
                readonly property bool spans: tiles.cols === 2 && tile.index === w.metrics.length - 1 && w.metrics.length % 2 === 1

                width: tile.spans ? tiles.width : (tiles.width - tiles.spacing * (tiles.cols - 1)) / Math.max(1, tiles.cols)
                height: (tiles.height - tiles.spacing * (tiles.rows - 1)) / Math.max(1, tiles.rows)
                radius: Theme.dp(18)
                color: Theme.alpha(tile.hue, 0.14)

                // the fill rises with the reading
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * tile.modelData.value
                    radius: parent.radius
                    color: Theme.alpha(tile.hue, 0.22)

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.durDefaultSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                }

                Icon {
                    x: Theme.dp(14)
                    y: Theme.dp(12)
                    name: tile.modelData.icon
                    size: Theme.dp(20)
                    fill: 1
                    color: tile.hue
                }

                Column {
                    x: Theme.dp(14)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.dp(10)
                    spacing: -Theme.dp(3)

                    LText {
                        role: "headlineSmall"
                        weight: 680
                        rounded: 100
                        tabular: true
                        color: w.ink
                        text: tile.modelData.text
                    }

                    LText {
                        role: "labelMedium"
                        color: w.inkDim
                        text: tile.modelData.label
                    }

                }

            }

        }

    }

    // network: what is coming in and going out, drawn over each other
    Item {
        visible: w.variant === "network"
        anchors.fill: parent
        anchors.margins: Theme.dp(18)

        Row {
            id: nHead

            spacing: Theme.dp(18)

            Repeater {
                model: [{
                    "icon": "arrow_downward",
                    "label": "Down",
                    "v": w.down,
                    "c": w.inkAccent
                }, {
                    "icon": "arrow_upward",
                    "label": "Up",
                    "v": w.up,
                    "c": w.tonal ? w.inkDim : Theme.tertiary
                }]

                Row {
                    id: rateCell

                    required property var modelData

                    spacing: Theme.dp(8)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(30)
                        height: Theme.dp(30)
                        radius: Theme.dp(15)
                        color: Theme.alpha(rateCell.modelData.c, 0.16)

                        Icon {
                            anchors.centerIn: parent
                            name: rateCell.modelData.icon
                            size: Theme.dp(18)
                            color: rateCell.modelData.c
                        }

                    }

                    Column {
                        spacing: -Theme.dp(3)

                        LText {
                            role: "titleMedium"
                            weight: 660
                            tabular: true
                            color: w.ink
                            text: Sys.rate(rateCell.modelData.v)
                        }

                        LText {
                            role: "labelSmall"
                            color: w.inkDim
                            text: rateCell.modelData.label
                        }

                    }

                }

            }

        }

        Item {
            anchors.top: nHead.bottom
            anchors.topMargin: Theme.dp(10)
            anchors.bottom: parent.bottom
            width: parent.width

            Spark {
                id: downSpark

                anchors.fill: parent
                samples: w.downHistory
                autoScale: true
                lineColor: w.inkAccent
                lineWidth: 2.5
            }

            // up shares down's scale, so the two read against each other
            Spark {
                anchors.fill: parent
                samples: w.upHistory.map((v) => {
                    return v / Math.max(1, downSpark.peak);
                })
                lineColor: w.tonal ? w.inkDim : Theme.tertiary
                lineWidth: Theme.dp(2)
                filled: false
            }

        }

    }

    // compact: one strip of numbers
    Row {
        visible: w.variant === "compact"
        anchors.centerIn: parent
        spacing: Theme.dp(16)

        Repeater {
            model: w.metrics.slice(0, 3)

            Row {
                id: cell

                required property var modelData

                spacing: Theme.dp(8)

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(34)
                    height: Theme.dp(34)

                    CircularProgress {
                        anchors.fill: parent
                        thickness: Theme.dp(4)
                        value: cell.modelData.value
                        color: w.tint(cell.modelData.key, cell.modelData.value)
                        trackColor: Theme.alpha(w.ink, 0.1)
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: cell.modelData.icon
                        size: Theme.dp(15)
                        fill: 1
                        color: w.tint(cell.modelData.key, cell.modelData.value)
                    }

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -Theme.dp(3)

                    LText {
                        role: "titleSmall"
                        weight: 680
                        tabular: true
                        color: w.ink
                        text: cell.modelData.text
                    }

                    LText {
                        role: "labelSmall"
                        color: w.inkDim
                        text: cell.modelData.short
                    }

                }

            }

        }

    }

}
