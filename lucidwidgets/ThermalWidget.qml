import QtQuick
import Quickshell
import Quickshell.Io
import qs

WidgetBody {
    id: w

    // "" when no graphics card could be read, "asleep" or "on"
    property string gpuState: ""
    property string gpuName: ""
    property real gpuTemp: -1
    property real gpuLoad: 0
    property real vramUsed: 0
    property real vramTotal: 0
    property real gpuPower: -1
    property real cpuTemp: -1
    property var fans: []
    property var fanPeaks: ({})
    property real lastGpuRead: 0
    property int polls: 0
    property bool gameModeOn: false
    property bool gameModeBusy: false

    readonly property int pollMs: (parseInt(w.opt("interval")) || 2) * 1000
    readonly property bool hasGpu: w.gpuState !== ""
    readonly property bool gpuAwake: w.gpuState === "on"
    readonly property bool showFans: w.opt("showFans") !== false && w.fans.length > 0
    readonly property bool gameModeConfigured: Prefs.gameModeOnCmd.trim() !== "" && Prefs.gameModeOffCmd.trim() !== ""
    readonly property string gpuShort: w.gpuName.replace(/^NVIDIA\s+(GeForce\s+)?/, "").replace(/\s+Laptop GPU$/, " Laptop")
    readonly property real fanRpm: w.fans.length > 0 ? w.fans.reduce((a, f) => {
        return a + f.rpm;
    }, 0) / w.fans.length : 0
    readonly property real fanLevel: w.fans.length > 0 ? w.fans.reduce((a, f) => {
        return a + f.level;
    }, 0) / w.fans.length : 0
    readonly property color fanTint: Theme.hasTonalContainers ? Theme.cSecondary : Theme.subtext
    readonly property string headText: {
        if (w.hasGpu)
            return (w.gpuAwake && w.gpuTemp >= 0) ? Math.round(w.gpuTemp) + "°" : "—";

        return w.cpuTemp >= 0 ? Math.round(w.cpuTemp) + "°" : "—";
    }
    readonly property var gpuStats: {
        var out = [{
            "label": "LOAD",
            "value": Math.round(w.gpuLoad * 100) + "%",
            "level": w.gpuLoad,
            "tint": Theme.accent
        }];
        if (w.vramTotal > 0)
            out.push({
                "label": "MEMORY",
                "value": (w.vramUsed / 1024).toFixed(1) + " / " + (w.vramTotal / 1024).toFixed(1) + " GB",
                "level": w.vramUsed / w.vramTotal,
                "tint": Theme.accentMuted
            });

        if (w.cpuTemp >= 0)
            out.push({
                "label": "CPU",
                "value": Math.round(w.cpuTemp) + "°",
                "level": w.cpuTemp / 100,
                "tint": w.tempTint(w.cpuTemp)
            });

        return out;
    }
    readonly property var fanStats: w.fans.slice(0, 3).map((f) => {
        return ({
            "label": f.label.toUpperCase(),
            "value": f.rpm + " rpm",
            "level": f.level,
            "tint": w.fanTint
        });
    })
    readonly property var rings: {
        var out = [];
        if (w.hasGpu) {
            out.push({
                "short": "GPU",
                "value": w.gpuTemp >= 0 ? w.gpuTemp / 100 : 0,
                "text": w.gpuAwake && w.gpuTemp >= 0 ? Math.round(w.gpuTemp) + "°" : "—",
                "tint": w.tempTint(w.gpuTemp)
            });
            out.push({
                "short": "LOAD",
                "value": w.gpuAwake ? w.gpuLoad : 0,
                "text": w.gpuAwake ? Math.round(w.gpuLoad * 100) + "%" : "—",
                "tint": Theme.accentMuted
            });
        }
        if (w.cpuTemp >= 0)
            out.push({
                "short": "CPU",
                "value": w.cpuTemp / 100,
                "text": Math.round(w.cpuTemp) + "°",
                "tint": w.tempTint(w.cpuTemp)
            });

        if (w.showFans)
            out.push({
                "short": "FANS",
                "value": w.fanLevel,
                "text": w.rpmShort(w.fanRpm),
                "tint": w.fanTint
            });

        return out;
    }
    readonly property var compactCells: {
        var out = [];
        if (w.hasGpu)
            out.push({
                "short": "GPU",
                "text": w.gpuAwake && w.gpuTemp >= 0 ? Math.round(w.gpuTemp) + "°" : "—",
                "tint": w.tempTint(w.gpuTemp)
            });

        if (w.cpuTemp >= 0)
            out.push({
                "short": "CPU",
                "text": Math.round(w.cpuTemp) + "°",
                "tint": w.tempTint(w.cpuTemp)
            });

        if (w.showFans)
            out.push({
                "short": "FANS",
                "text": w.rpmShort(w.fanRpm),
                "tint": w.fanTint
            });

        return out;
    }

    function tempTint(t) {
        return t >= 85 ? Theme.error : (t >= 72 ? Theme.warning : Theme.accent);
    }

    function rpmShort(rpm) {
        return rpm >= 1000 ? (rpm / 1000).toFixed(1) + "k" : Math.round(rpm) + "";
    }

    function poll() {
        // a card that drives no screen can sleep, and every nvidia-smi call wakes
        // it up again. read that one at most every ten seconds, which leaves it
        // room to drop off between reads; asleep, the script leaves it alone
        var mayRead = Date.now() - w.lastGpuRead >= Math.max(w.pollMs, 10000);
        probe.command = ["sh", "-c", probe.script, "thermal", mayRead ? "1" : "0"];
        probe.running = true;
        w.polls++;
        if (Prefs.gameModeStateFile === "" && w.polls % 5 === 1)
            w.checkGameMode();

    }

    function take(text) {
        var section = "";
        var fanRows = [];
        var sawGpu = false;
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.charAt(0) === "@") {
                section = line.substring(1);
                continue;
            }
            if (line === "")
                continue;

            var p = line.split("|");
            if (section === "gpu") {
                sawGpu = true;
                if (p[0] === "pm") {
                    if (p[2] === "suspended")
                        w.gpuState = "asleep";
                    else if (w.gpuState !== "on" && w.gpuName !== "")
                        w.gpuState = "on";
                } else if (p[0] === "nvidia") {
                    var f = p[1].split(",").map((s) => {
                        return s.trim();
                    });
                    if (f.length < 6)
                        continue;

                    w.gpuName = f[0];
                    w.gpuTemp = w.num(f[1], -1);
                    w.gpuLoad = Math.max(0, Math.min(1, w.num(f[2], 0) / 100));
                    w.vramUsed = w.num(f[3], 0);
                    w.vramTotal = w.num(f[4], 0);
                    w.gpuPower = w.num(f[5], -1);
                    w.gpuState = "on";
                    w.lastGpuRead = Date.now();
                } else if (p[0] === "amd") {
                    w.gpuName = "Radeon";
                    var milli = w.num(p[1], -1);
                    w.gpuTemp = milli >= 0 ? milli / 1000 : -1;
                    w.gpuLoad = Math.max(0, Math.min(1, w.num(p[2], 0) / 100));
                    w.vramUsed = w.num(p[3], 0) / 1048576;
                    w.vramTotal = w.num(p[4], 0) / 1048576;
                    var micro = w.num(p[5], -1);
                    w.gpuPower = micro >= 0 ? micro / 1000000 : -1;
                    w.gpuState = "on";
                    w.lastGpuRead = Date.now();
                }
            } else if (section === "cpu") {
                var t = parseInt(line);
                w.cpuTemp = isNaN(t) ? -1 : (t > 1000 ? t / 1000 : t);
            } else if (section === "fans") {
                if (p.length >= 5 && !isNaN(parseInt(p[2])))
                    fanRows.push({
                        "chip": p[0],
                        "key": p[1],
                        "rpm": parseInt(p[2]),
                        "label": p[3],
                        "max": parseInt(p[4]) || 0
                    });

            }
        }
        if (!sawGpu)
            w.gpuState = "";

        w.fans = w.pickFans(fanRows);
    }

    function num(s, fallback) {
        var v = parseFloat(s);
        return isNaN(v) ? fallback : v;
    }

    // several drivers can report the same fans (dell_smm, dell_ddv and
    // alienware_wmi all do on a G15); keep the one chip that names them best
    function pickFans(rows) {
        var groups = {};
        var order = [];
        for (var i = 0; i < rows.length; i++) {
            if (!groups[rows[i].chip]) {
                groups[rows[i].chip] = [];
                order.push(rows[i].chip);
            }
            groups[rows[i].chip].push(rows[i]);
        }
        var best = null, bestScore = -1;
        for (var k = 0; k < order.length; k++) {
            var g = groups[order[k]];
            var score = g.filter((r) => {
                return r.label !== "";
            }).length * 10 + g.length;
            if (score > bestScore) {
                best = g;
                bestScore = score;
            }
        }
        if (!best)
            return [];

        var peaks = Object.assign({}, w.fanPeaks);
        var out = best.map((r, n) => {
            var id = r.chip + "/" + r.key;
            // a reported maximum is trusted; without one the scale is the fastest seen
            var top = r.max > 0 ? Math.max(r.max, r.rpm) : Math.max(peaks[id] || 0, r.rpm, 4000);
            peaks[id] = top;
            return ({
                "label": r.label !== "" ? r.label : "Fan " + (n + 1),
                "rpm": r.rpm,
                "level": top > 0 ? r.rpm / top : 0
            });
        });
        w.fanPeaks = peaks;
        return out;
    }

    function setGameMode(on) {
        if (w.preview || !w.gameModeConfigured || w.gameModeBusy)
            return ;

        w.gameModeBusy = true;
        w.gameModeOn = on;
        gameModeRun.command = ["bash", "-c", on ? Prefs.gameModeOnCmd : Prefs.gameModeOffCmd];
        gameModeRun.running = true;
    }

    function checkGameMode() {
        if (w.preview || Prefs.gameModeStatusCmd.trim() === "" || gameModeStatus.running)
            return ;

        gameModeStatus.command = ["bash", "-c", Prefs.gameModeStatusCmd];
        gameModeStatus.running = true;
    }

    // the gallery hands over its host after onCompleted, so seed on either
    onPreviewChanged: w.seedPreview()
    Component.onCompleted: w.seedPreview()

    function seedPreview() {
        if (!w.preview)
            return ;

        w.gpuState = "on";
        w.gpuName = "NVIDIA GeForce RTX 4060 Laptop GPU";
        w.gpuTemp = 58;
        w.gpuLoad = 0.41;
        w.vramUsed = 2310;
        w.vramTotal = 8188;
        w.gpuPower = 32.4;
        w.cpuTemp = 64;
        w.fans = [{
            "label": "CPU Fan",
            "rpm": 3120,
            "level": 0.62
        }, {
            "label": "GPU Fan",
            "rpm": 3380,
            "level": 0.68
        }];
    }

    Timer {
        interval: w.pollMs
        repeat: true
        running: w.live
        triggeredOnStart: true
        onTriggered: w.poll()
    }

    Process {
        id: probe

        readonly property string script: "g=''\n" + "for d in /sys/bus/pci/devices/*; do\n" + "  [ \"$(cat \"$d/vendor\" 2>/dev/null)\" = 0x10de ] || continue\n" + "  case \"$(cat \"$d/class\" 2>/dev/null)\" in 0x03*) g=$d; break ;; esac\n" + "done\n" + "echo @gpu\n" + "if [ -n \"$g\" ] && command -v nvidia-smi >/dev/null 2>&1; then\n" + "  shown=0\n" + "  for c in \"$g\"/drm/card*/card*-*/status; do [ \"$(cat \"$c\" 2>/dev/null)\" = connected ] && shown=1 && break; done\n" + "  st=$(cat \"$g/power/runtime_status\" 2>/dev/null)\n" + "  echo \"pm|$shown|$st\"\n" + "  if [ \"$st\" != suspended ] && { [ \"$shown\" = 1 ] || [ \"$1\" = 1 ]; }; then\n" + "    echo \"nvidia|$(nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>/dev/null | head -1)\"\n" + "  fi\n" + "else\n" + "  for c in /sys/class/drm/card[0-9]*/device; do\n" + "    [ \"$(cat \"$c/vendor\" 2>/dev/null)\" = 0x1002 ] && [ -r \"$c/gpu_busy_percent\" ] || continue\n" + "    st=$(cat \"$c/power/runtime_status\" 2>/dev/null)\n" + "    echo \"pm|1|$st\"\n" + "    [ \"$st\" = suspended ] && break\n" + "    h=$(ls -d \"$c\"/hwmon/hwmon* 2>/dev/null | head -1)\n" + "    echo \"amd|$(cat \"$h/temp1_input\" 2>/dev/null)|$(cat \"$c/gpu_busy_percent\" 2>/dev/null)|$(cat \"$c/mem_info_vram_used\" 2>/dev/null)|$(cat \"$c/mem_info_vram_total\" 2>/dev/null)|$(cat \"$h/power1_average\" 2>/dev/null || cat \"$h/power1_input\" 2>/dev/null)\"\n" + "    break\n" + "  done\n" + "fi\n" + "echo @cpu\n" + "t=''\n" + "for h in /sys/class/hwmon/hwmon*; do\n" + "  case \"$(cat \"$h/name\" 2>/dev/null)\" in coretemp|k10temp|zenpower|cpu_thermal|acpitz) [ -r \"$h/temp1_input\" ] && t=$(cat \"$h/temp1_input\") && break ;; esac\n" + "done\n" + "echo \"$t\"\n" + "echo @fans\n" + "for h in /sys/class/hwmon/hwmon*; do\n" + "  n=$(cat \"$h/name\" 2>/dev/null)\n" + "  for f in \"$h\"/fan*_input; do\n" + "    [ -r \"$f\" ] || continue\n" + "    b=${f%_input}\n" + "    echo \"$n|${b##*/}|$(cat \"$f\" 2>/dev/null)|$(cat \"${b}_label\" 2>/dev/null)|$(cat \"${b}_max\" 2>/dev/null)\"\n" + "  done\n" + "done\n"

        stdout: StdioCollector {
            onStreamFinished: w.take(this.text)
        }

    }

    Process {
        id: gameModeRun

        onExited: (code) => {
            w.gameModeBusy = false;
            if (code !== 0)
                w.gameModeOn = !w.gameModeOn;

            w.checkGameMode();
        }
    }

    Process {
        id: gameModeStatus

        onExited: (code) => {
            if (!w.gameModeBusy)
                w.gameModeOn = code === 0;

        }
    }

    // the same "test -f <file>" the toasts watch, so no status command needs polling
    FileView {
        path: (w.live && Prefs.gameModeStateFile !== "") ? Prefs.gameModeStateFile : ""
        watchChanges: path !== ""
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (!w.gameModeBusy)
                w.gameModeOn = true;

        }
        onLoadFailed: {
            if (!w.gameModeBusy && path !== "")
                w.gameModeOn = false;

        }
    }

    Column {
        id: detail

        visible: w.variant === "detail"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 13

        Item {
            width: parent.width
            height: 44

            Text {
                id: headTemp

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: w.headText
                color: w.hasGpu ? (w.gpuAwake ? w.tempTint(w.gpuTemp) : Theme.subtextDim) : w.tempTint(w.cpuTemp)
                font.family: Theme.fontFamily
                font.pixelSize: 38
                font.bold: true
                font.letterSpacing: -1.5
            }

            Column {
                anchors.left: headTemp.right
                anchors.leftMargin: 12
                anchors.right: headDraw.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: w.hasGpu ? "GRAPHICS" : "PROCESSOR"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.4
                }

                Text {
                    width: parent.width
                    text: w.hasGpu ? (w.gpuAwake ? w.gpuShort : "Asleep, left undisturbed") : "Temperature"
                    color: w.gpuAwake || !w.hasGpu ? Theme.text : Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

            }

            Column {
                id: headDraw

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: w.gpuAwake && w.gpuPower >= 0
                spacing: 1

                Text {
                    anchors.right: parent.right
                    text: "DRAW"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 0.9
                }

                Text {
                    anchors.right: parent.right
                    text: w.gpuPower.toFixed(w.gpuPower < 10 ? 1 : 0) + " W"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

            }

        }

        StatRow {
            width: parent.width
            visible: w.gpuAwake
            model: w.gpuStats
        }

        StatRow {
            width: parent.width
            visible: w.showFans
            model: w.fanStats
        }

        Row {
            visible: w.opt("showControls") !== false
            spacing: 8

            Chip {
                path: Power.icon(Power.profile)
                label: Power.name(Power.profile)
                onClicked: {
                    if (!w.preview)
                        Power.cycle();

                }
            }

            Chip {
                visible: w.gameModeConfigured || w.preview
                icon: "games"
                label: "Game mode"
                on: w.gameModeOn
                busy: w.gameModeBusy
                onClicked: w.setGameMode(!w.gameModeOn)
            }

        }

    }

    Row {
        id: ringRow

        visible: w.variant === "rings"
        anchors.centerIn: parent
        width: parent.width - 20

        Repeater {
            model: w.rings

            Column {
                id: ringCell

                required property var modelData

                width: w.rings.length > 0 ? ringRow.width / w.rings.length : 0
                spacing: 8

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 70
                    height: 70

                    Gauge {
                        anchors.fill: parent
                        thickness: 7
                        value: ringCell.modelData.value
                        fillColor: ringCell.modelData.tint
                        startAngle: -215
                        sweep: 250
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -3
                        text: ringCell.modelData.text
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
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

    Row {
        id: compactRow

        visible: w.variant === "compact"
        anchors.centerIn: parent
        width: parent.width - 32

        Repeater {
            model: w.compactCells

            Column {
                id: compactCell

                required property var modelData

                width: w.compactCells.length > 0 ? compactRow.width / w.compactCells.length : 0
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
                    color: compactCell.modelData.tint
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    font.letterSpacing: -0.5
                }

            }

        }

    }

    component StatRow: Row {
        id: statRow

        property var model: []

        Repeater {
            model: statRow.model

            Column {
                id: stat

                required property var modelData

                width: statRow.model.length > 0 ? statRow.width / statRow.model.length : 0
                spacing: 3

                Text {
                    text: stat.modelData.label
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 0.9
                }

                Text {
                    width: stat.width - 8
                    text: stat.modelData.value
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }

                Meter {
                    width: stat.width - 12
                    thickness: 4
                    value: stat.modelData.level
                    fillColor: stat.modelData.tint
                }

            }

        }

    }

    component Chip: Rectangle {
        id: chip

        property string icon: ""
        property string path: ""
        property string label: ""
        property bool on: false
        property bool busy: false

        signal clicked()

        implicitWidth: chipRow.implicitWidth + 24
        implicitHeight: 30
        radius: Theme.pill(height)
        opacity: chip.busy ? 0.6 : 1
        color: chip.on ? Theme.accent : Theme.alpha(Theme.text, chipArea.containsMouse ? 0.13 : 0.07)

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 6

            WidgetGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                path: chip.path
                size: 15
                color: chip.on ? Theme.fgAccent : Theme.text
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.on ? Theme.fgAccent : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }

        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

    }

}
