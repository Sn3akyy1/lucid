import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// one poller for every live system reading in the shell. nothing runs until a
// card or panel holds it, and it stops again once the last one lets go
Singleton {
    id: root

    // tag -> the refresh it asked for, in ms; the quickest one wins
    property var holders: ({})
    readonly property bool active: Object.keys(root.holders).length > 0
    readonly property int intervalMs: {
        var ms = 5000;
        for (var k in root.holders) ms = Math.min(ms, root.holders[k])
        return Math.max(1000, ms);
    }
    readonly property int historyLength: 60

    property real cpu: 0
    property real cpuMhz: 0
    property var cpuHistory: []
    property real load1: 0
    property real ram: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property var ramHistory: []
    property real swap: 0
    property real swapUsedGb: 0
    property real swapTotalGb: 0
    property real disk: 0
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    property real diskFreeGb: 0
    property real temp: -1
    property real uptime: -1
    // bytes per second, summed over every real interface
    property real netDown: 0
    property real netUp: 0
    property var downHistory: []
    property var upHistory: []
    // -1 when the card exposes no load
    property real gpu: -1
    property real gpuTemp: -1
    property var info: ({})

    property real _prevTotal: -1
    property real _prevIdle: -1
    property real _prevRx: -1
    property real _prevTx: -1
    property double _prevAt: 0

    function hold(tag, on, ms) {
        var next = Object.assign({}, root.holders);
        if (on)
            next[tag] = ms || 2000;
        else
            delete next[tag];
        root.holders = next;
    }

    function push(arr, v) {
        var next = arr.concat([v]);
        while (next.length > root.historyLength) next.shift()
        return next;
    }

    // 1.2 MB/s, 340 KB/s
    function rate(bps) {
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(bps >= 10485760 ? 0 : 1) + " MB/s";

        if (bps >= 1024)
            return Math.round(bps / 1024) + " KB/s";

        return Math.round(bps) + " B/s";
    }

    function duration(sec) {
        if (sec < 0)
            return "";

        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        return d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m");
    }

    function parse(text) {
        var section = "";
        var lines = text.split("\n");
        var mem = {};
        var rx = 0, tx = 0;
        var mhz = [];
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
                if (root._prevTotal >= 0 && total > root._prevTotal) {
                    root.cpu = Math.max(0, Math.min(1, 1 - (idle - root._prevIdle) / (total - root._prevTotal)));
                    root.cpuHistory = root.push(root.cpuHistory, root.cpu);
                }
                root._prevTotal = total;
                root._prevIdle = idle;
            } else if (section === "mhz") {
                var f = parseFloat(line);
                if (!isNaN(f))
                    mhz.push(f);

            } else if (section === "mem") {
                var m = /^(\w+):\s+(\d+)/.exec(line);
                if (m)
                    mem[m[1]] = parseInt(m[2]);

            } else if (section === "disk") {
                var d = line.trim().split(/\s+/).map(Number);
                // the root reserve is neither used nor free, so the share is of used + avail, as df reports it
                if (d.length >= 3 && d[1] + d[2] > 0) {
                    root.diskTotalGb = d[0] / 1073741824;
                    root.diskUsedGb = d[1] / 1073741824;
                    root.diskFreeGb = d[2] / 1073741824;
                    root.disk = d[1] / (d[1] + d[2]);
                }
            } else if (section === "temp") {
                var t = parseInt(line);
                root.temp = isNaN(t) ? -1 : (t > 1000 ? t / 1000 : t);
            } else if (section === "up") {
                var u = line.split(/\s+/);
                root.uptime = parseFloat(u[0]);
            } else if (section === "load") {
                root.load1 = parseFloat(line.split(/\s+/)[0]) || 0;
            } else if (section === "net") {
                var n = /^([^:]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/.exec(line);
                if (n && !/^(lo|virbr|docker|veth|br-)/.test(n[1])) {
                    rx += parseInt(n[2]);
                    tx += parseInt(n[3]);
                }
            } else if (section === "gpu") {
                var g = line.split(",").map((s) => {
                    return parseFloat(s);
                });
                if (!isNaN(g[0]))
                    root.gpu = Math.max(0, Math.min(1, g[0] / 100));

                if (g.length > 1 && !isNaN(g[1]))
                    root.gpuTemp = g[1];

            }
        }
        if (mhz.length)
            root.cpuMhz = mhz.reduce((a, b) => {
            return a + b;
        }, 0) / mhz.length;

        if (mem.MemTotal > 0) {
            root.ramTotalGb = mem.MemTotal / 1048576;
            root.ramUsedGb = (mem.MemTotal - mem.MemAvailable) / 1048576;
            root.ram = Math.max(0, Math.min(1, 1 - mem.MemAvailable / mem.MemTotal));
            root.ramHistory = root.push(root.ramHistory, root.ram);
        }
        if (mem.SwapTotal > 0) {
            root.swapTotalGb = mem.SwapTotal / 1048576;
            root.swapUsedGb = (mem.SwapTotal - mem.SwapFree) / 1048576;
            root.swap = root.swapUsedGb / root.swapTotalGb;
        }
        var now = Date.now();
        if (root._prevRx >= 0 && now > root._prevAt) {
            var dt = (now - root._prevAt) / 1000;
            root.netDown = Math.max(0, (rx - root._prevRx) / dt);
            root.netUp = Math.max(0, (tx - root._prevTx) / dt);
            root.downHistory = root.push(root.downHistory, root.netDown);
            root.upHistory = root.push(root.upHistory, root.netUp);
        }
        root._prevRx = rx;
        root._prevTx = tx;
        root._prevAt = now;
    }

    onActiveChanged: {
        if (root.active && !root.info.os)
            infoProc.running = true;

    }

    Timer {
        interval: root.intervalMs
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Process {
        id: poll

        command: ["sh", "-c", "echo @cpu; head -1 /proc/stat; echo @mhz; grep -m8 '^cpu MHz' /proc/cpuinfo | cut -d: -f2; echo @mem; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo; echo @disk; df -B1 --output=size,used,avail / | tail -1; echo @up; cat /proc/uptime; echo @load; cat /proc/loadavg; echo @net; tail -n +3 /proc/net/dev; echo @temp; t=''; for h in /sys/class/hwmon/hwmon*; do n=$(cat \"$h/name\" 2>/dev/null); case \"$n\" in coretemp|k10temp|zenpower|cpu_thermal|acpitz) [ -r \"$h/temp1_input\" ] && t=$(cat \"$h/temp1_input\") && break;; esac; done; [ -z \"$t\" ] && [ -r /sys/class/thermal/thermal_zone0/temp ] && t=$(cat /sys/class/thermal/thermal_zone0/temp); echo \"$t\"; echo @gpu; for c in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$c\" ] && cat \"$c\" && exit 0; done; " + (root.info.nvidia ? "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1" : "true")]

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }

    }

    // the things that never change while the session runs, read once
    Process {
        id: infoProc

        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; echo \"os=${PRETTY_NAME:-Linux}\"; echo \"logo=${LOGO:-}\"; echo \"kernel=$(uname -r)\"; echo \"host=$(cat /proc/sys/kernel/hostname)\"; echo \"user=$USER\"; echo \"shell=$(basename \"${SHELL:-sh}\")\"; echo \"cpuModel=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/(R)//g; s/(TM)//g; s/ CPU//; s/ @.*//; s/^ *//')\"; echo \"cores=$(nproc)\"; g=$(lspci 2>/dev/null | grep -iE 'vga|3d controller' | head -1 | sed 's/.*: //; s/Corporation //; s/ (rev.*//'); echo \"gpuModel=$g\"; command -v pacman >/dev/null && echo \"packages=$(pacman -Qq 2>/dev/null | wc -l)\"; nvidia-smi -L >/dev/null 2>&1 && echo nvidia=1; echo \"model=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)\""]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var k = lines[i].indexOf("=");
                    if (k > 0)
                        out[lines[i].slice(0, k)] = lines[i].slice(k + 1).trim();

                }
                out.nvidia = out.nvidia === "1";
                root.info = out;
            }
        }

    }

}
