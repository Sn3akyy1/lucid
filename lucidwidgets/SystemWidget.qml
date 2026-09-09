import QtQuick
import Quickshell.Io
import qs

WidgetBody {
    id: w

    property real cpu: 0
    property real ram: 0
    property real disk: 0
    property real temp: -1
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    property var cpuHistory: []
    property var ramHistory: []
    property real prevTotal: -1
    property real prevIdle: -1

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
                "value": w.cpu,
                "text": Math.round(w.cpu * 100) + "%",
                "detail": ""
            });

        if (w.opt("showRam") !== false)
            out.push({
                "key": "ram",
                "label": "Memory",
                "short": "RAM",
                "value": w.ram,
                "text": Math.round(w.ram * 100) + "%",
                "detail": w.ramTotalGb > 0 ? w.ramUsedGb.toFixed(1) + " / " + w.ramTotalGb.toFixed(1) + " GB" : ""
            });

        if (w.opt("showDisk") !== false)
            out.push({
                "key": "disk",
                "label": "Disk",
                "short": "SSD",
                "value": w.disk,
                "text": Math.round(w.disk * 100) + "%",
                "detail": w.diskTotalGb > 0 ? Math.round(w.diskTotalGb - w.diskUsedGb) + " GB free" : ""
            });

        if (w.opt("showTemp") === true && w.temp >= 0)
            out.push({
                "key": "temp",
                "label": "Temperature",
                "short": "TEMP",
                "value": Math.min(1, w.temp / 100),
                "text": Math.round(w.temp) + "°",
                "detail": ""
            });

        return out;
    }

    // every metric stays inside the wallpaper's own palette; tertiary is dropped
    // because matugen resolves it green on a lot of wallpapers
    function tint(key, value) {
        if (key === "temp")
            return value > 0.8 ? Theme.error : (value > 0.65 ? Theme.warning : Theme.accent);

        if (value > 0.9)
            return Theme.error;

        if (key === "cpu")
            return Theme.accent;

        if (key === "ram")
            return Theme.accentMuted;

        return Theme.hasTonalContainers ? Theme.cSecondary : Theme.subtext;
    }

    function push(arr, v) {
        var next = arr.concat([v]);
        while (next.length > 44) next.shift()
        return next;
    }

    Component.onCompleted: {
        if (w.preview) {
            w.cpu = 0.34;
            w.ram = 0.62;
            w.disk = 0.48;
            w.temp = 51;
            w.ramUsedGb = 9.8;
            w.ramTotalGb = 15.5;
            w.diskUsedGb = 220;
            w.diskTotalGb = 460;
            var a = [], b = [];
            for (var i = 0; i < 44; i++) {
                a.push(0.3 + 0.24 * Math.sin(i / 3.1) + 0.1 * Math.sin(i / 1.3));
                b.push(0.58 + 0.06 * Math.sin(i / 5.5));
            }
            w.cpuHistory = a;
            w.ramHistory = b;
        }
    }

    Timer {
        interval: w.pollMs
        repeat: true
        running: !w.preview
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Process {
        id: poll

        command: ["sh", "-c", "echo @cpu; head -1 /proc/stat; echo @mem; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; echo @disk; df -B1 --output=size,used / | tail -1; echo @temp; t=''; for h in /sys/class/hwmon/hwmon*; do n=$(cat \"$h/name\" 2>/dev/null); case \"$n\" in coretemp|k10temp|zenpower|cpu_thermal|acpitz) [ -r \"$h/temp1_input\" ] && t=$(cat \"$h/temp1_input\") && break;; esac; done; [ -z \"$t\" ] && [ -r /sys/class/thermal/thermal_zone0/temp ] && t=$(cat /sys/class/thermal/thermal_zone0/temp); echo \"$t\""]

        stdout: StdioCollector {
            onStreamFinished: {
                var section = "";
                var lines = this.text.split("\n");
                var memTotal = 0, memAvail = 0;
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.charAt(0) === "@") {
                        section = line.substring(1);
                        continue;
                    }
                    if (line === "")
                        continue;

                    if (section === "cpu") {
                        var parts = line.split(/\s+/).slice(1).map(Number);
                        if (parts.length < 5)
                            continue;

                        var idle = parts[3] + parts[4];
                        var total = parts.reduce((a, b) => {
                            return a + b;
                        }, 0);
                        if (w.prevTotal >= 0 && total > w.prevTotal) {
                            var use = 1 - (idle - w.prevIdle) / (total - w.prevTotal);
                            w.cpu = Math.max(0, Math.min(1, use));
                            w.cpuHistory = w.push(w.cpuHistory, w.cpu);
                        }
                        w.prevTotal = total;
                        w.prevIdle = idle;
                    } else if (section === "mem") {
                        var m = /^(\w+):\s+(\d+)/.exec(line);
                        if (!m)
                            continue;

                        if (m[1] === "MemTotal")
                            memTotal = parseInt(m[2]);
                        else
                            memAvail = parseInt(m[2]);
                    } else if (section === "disk") {
                        var d = line.split(/\s+/).map(Number);
                        if (d.length >= 2 && d[0] > 0) {
                            w.diskTotalGb = d[0] / 1073741824;
                            w.diskUsedGb = d[1] / 1073741824;
                            w.disk = d[1] / d[0];
                        }
                    } else if (section === "temp") {
                        var t = parseInt(line);
                        w.temp = isNaN(t) ? -1 : (t > 1000 ? t / 1000 : t);
                    }
                }
                if (memTotal > 0) {
                    w.ramTotalGb = memTotal / 1048576;
                    w.ramUsedGb = (memTotal - memAvail) / 1048576;
                    w.ram = Math.max(0, Math.min(1, 1 - memAvail / memTotal));
                    w.ramHistory = w.push(w.ramHistory, w.ram);
                }
            }
        }

    }

    Row {
        id: rings

        visible: w.variant === "rings"
        anchors.centerIn: parent
        width: parent.width - 24
        spacing: 0

        Repeater {
            model: w.metrics

            Column {
                id: ringCell

                required property var modelData

                width: w.metrics.length > 0 ? rings.width / w.metrics.length : 0
                spacing: 8

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72
                    height: 72

                    Gauge {
                        anchors.fill: parent
                        thickness: 7
                        value: ringCell.modelData.value
                        fillColor: w.tint(ringCell.modelData.key, ringCell.modelData.value)
                        startAngle: -215
                        sweep: 250
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -3
                        text: ringCell.modelData.text
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.bold: true
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ringCell.modelData.short
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                }

            }

        }

    }

    Column {
        id: bars

        visible: w.variant === "bars"
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0

        Repeater {
            model: w.metrics

            Item {
                id: barRow

                required property var modelData

                // the detail line is the first thing to go when a fourth metric appears
                readonly property bool showDetail: barRow.modelData.detail !== "" && w.metrics.length < 4

                width: bars.width
                height: w.metrics.length > 0 ? bars.height / w.metrics.length : 0

                Text {
                    id: barLabel

                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: barRow.modelData.label
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    anchors.right: parent.right
                    anchors.baseline: barLabel.baseline
                    text: barRow.modelData.text
                    color: w.tint(barRow.modelData.key, barRow.modelData.value)
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

                Meter {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 19
                    thickness: 6
                    value: barRow.modelData.value
                    fillColor: w.tint(barRow.modelData.key, barRow.modelData.value)
                }

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: 29
                    text: barRow.modelData.detail
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    visible: barRow.showDetail
                }

            }

        }

    }

    Item {
        id: graph

        visible: w.variant === "graph"
        anchors.fill: parent
        anchors.margins: 18

        Row {
            id: graphHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 18

            Repeater {
                model: [{
                    "key": "cpu",
                    "short": "CPU",
                    "value": w.cpu
                }, {
                    "key": "ram",
                    "short": "RAM",
                    "value": w.ram
                }]

                Column {
                    id: headCell

                    required property var modelData

                    spacing: 0

                    Text {
                        text: headCell.modelData.short
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Text {
                        text: Math.round(headCell.modelData.value * 100) + "%"
                        color: w.tint(headCell.modelData.key, headCell.modelData.value)
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                        font.bold: true
                        font.letterSpacing: -0.5
                    }

                }

            }

        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 2
            text: w.ramTotalGb > 0 ? w.ramUsedGb.toFixed(1) + " GB used" : ""
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Spark {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: graphHead.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            samples: w.cpuHistory
            lineColor: w.tint("cpu", w.cpu)
            lineWidth: 2.2
        }

        Spark {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: graphHead.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            samples: w.ramHistory
            lineColor: w.tint("ram", w.ram)
            filled: false
            lineWidth: 1.8
            opacity: 0.9
        }

    }

    Row {
        id: compact

        visible: w.variant === "compact"
        anchors.centerIn: parent
        width: parent.width - 28
        spacing: 0

        Repeater {
            model: w.metrics

            Column {
                id: compactCell

                required property var modelData

                width: w.metrics.length > 0 ? compact.width / w.metrics.length : 0
                spacing: 1

                Text {
                    text: compactCell.modelData.short
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                Text {
                    text: compactCell.modelData.text
                    color: w.tint(compactCell.modelData.key, compactCell.modelData.value)
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    font.letterSpacing: -0.5
                }

            }

        }

    }

}
