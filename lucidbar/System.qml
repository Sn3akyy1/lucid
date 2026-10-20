import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs
import qs.lucidcc
import qs.lucidui

BarPill {
    id: root

    // wired from shell.qml
    property var mprisMod: null

    // the media card interpolates the mpris position per frame; tell the media
    // pill to run that only while this panel is actually up
    Binding {
        target: root.mprisMod
        property: "posWanted"
        value: root.expanded
        when: root.mprisMod !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    property string view: "main"
    readonly property bool inSubView: root.view !== "main"

    property bool viewSwitching: false

    // m3 easing, as authored in the spec
    readonly property var easeEmphasized: [0.2, 0, 0, 1, 1, 1]
    readonly property var easeEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeEmphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]

    // m3 spacing, on the 4dp grid
    readonly property int sp1: Theme.dp(4)
    readonly property int sp2: Theme.dp(8)
    readonly property int sp3: Theme.dp(12)
    readonly property int sp4: Theme.dp(16)
    readonly property int sp5: Theme.dp(20)

    Timer {
        id: viewResetTimer

        interval: Theme.barMs(700)
        onTriggered: {
            if (!root.expanded)
                root.view = "main";

        }
    }

    Timer {
        id: viewSwitchTimer

        interval: Theme.barMs(600)
        onTriggered: root.viewSwitching = false
    }

    function showView(v) {
        if (root.view === v)
            return ;

        root.viewSwitching = true;
        viewSwitchTimer.restart();

        // must precede the assignment: writing view re-evaluates the size
        // bindings synchronously, and the Behavior is consulted on that write
        root.beginTransition();
        root.view = v;
        if (v === "output")
            sinkPortsProc.running = true;

    }

    readonly property int horizontalPadding: Theme.dp(16)
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    readonly property int maxPanelHeight: Math.min(Theme.dp(820), Math.max(Theme.dp(200), root.screenH - Theme.dp(40)))
    readonly property int panelPad: root.sp4
    readonly property int contentWidth: root.panelWidth - root.panelPad * 2
    readonly property int headerHeight: Theme.dp(52)
    readonly property int subHeaderHeight: Theme.dp(44)
    // header top margin + header + gap + body + bottom padding
    readonly property int viewChrome: root.sp2 + root.headerHeight + root.sp1 + root.panelPad
    readonly property real viewContentHeight: {
        if (root.view === "wifi")
            return wifiPanel.implicitHeight + root.viewChrome;

        if (root.view === "bluetooth")
            return btPanel.implicitHeight + root.viewChrome;

        if (root.view === "output")
            return outputList.implicitHeight + root.viewChrome;

        if (root.view === "power")
            return powerList.implicitHeight + root.viewChrome;

        if (root.view === "profile")
            return powerPanel.implicitHeight + root.viewChrome;

        if (root.view === "nightlight")
            return nightPanel.implicitHeight + root.viewChrome;

        return mainColumn.implicitHeight + root.viewChrome;
    }

    property string backlightDevice: ""
    property int maxBrightness: 0
    readonly property int brightnessPercent: {
        if (root.maxBrightness <= 0)
            return 0;

        const raw = parseInt(brightnessFile.text());
        return isNaN(raw) ? 0 : Math.round((raw / root.maxBrightness) * 100);
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: (source && source.audio) ? source.audio.muted : true
    readonly property bool volMuted: (sink && sink.audio) ? sink.audio.muted : true
    readonly property int volumePercent: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0

    // real devices only: streams are per-app, not something to switch to
    readonly property var outputNodes: !Pipewire.ready ? [] : Pipewire.nodes.values.filter((n) => {
        return n.audio && n.isSink && !n.isStream;
    })

    function setVolume(v) {
        if (!root.sink || !root.sink.audio)
            return ;

        root.sink.audio.volume = Math.max(0, Math.min(1, v / 100));
    }

    function toggleVolMute() {
        if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;

    }

    function volumeIcon(pct, muted) {
        if (muted || pct <= 0)
            return "volume_off";

        return pct < 34 ? "volume_mute" : (pct < 67 ? "volume_down" : "volume_up");
    }

    readonly property string wifiGlyph: {
        if (wifiPanel.primaryIsEthernet)
            return "lan";

        if (!Networking.wifiEnabled)
            return "signal_wifi_off";

        if (!wifiPanel.wifiConnected)
            return "signal_wifi_0_bar";

        const s = wifiPanel.signalStrength;
        return s >= 75 ? "signal_wifi_4_bar" : (s >= 50 ? "network_wifi_3_bar" : (s >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar"));
    }
    readonly property string btGlyph: !root.btEnabled ? "bluetooth_disabled" : (btPanel.connectedDevices.length > 0 ? "bluetooth_connected" : "bluetooth")

    readonly property var battery: UPower.displayDevice
    readonly property bool batteryPresent: battery ? battery.isPresent : false
    readonly property int batteryPercent: batteryPresent ? Math.round(battery.percentage * 100) : 0
    readonly property bool batteryCharging: root.batteryPresent && !UPower.onBattery
    readonly property bool dndOn: Notifs.dnd
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter ? btAdapter.enabled : false

    property bool airplaneMode: false
    property bool _preAirplaneWifi: false
    property bool _preAirplaneBt: false

    // the old version never put the radios back, so turning it off did nothing
    function toggleAirplane() {
        if (!root.airplaneMode) {
            root._preAirplaneWifi = Networking.wifiEnabled;
            root._preAirplaneBt = root.btEnabled;
            root.airplaneMode = true;
            Networking.wifiEnabled = false;
            Bt.setEnabled(false);
            return ;
        }
        root.airplaneMode = false;
        if (root._preAirplaneWifi)
            Networking.wifiEnabled = true;

        if (root._preAirplaneBt)
            Bt.setEnabled(true);

    }

    property int pendingBrightness: -1
    property var _lsblkDisks: []
    property var diskList: []
    readonly property var extraDiskPartitions: ["nvme0n1p3", "nvme0n1p4"]
    property string selectedDisk: ""
    property bool diskDropdownOpen: false
    property var ramHistory: []
    property var cpuHistory: []
    property real ramPercent: 0
    property real cpuPercent: 0
    property real ramUsedGB: 0
    property real ramTotalGB: 0
    property real cpuTemp: -1
    property real uptimeSecs: -1
    property real _prevCpuTotal: -1
    property real _prevCpuIdle: -1

    readonly property string uptimeText: {
        if (root.uptimeSecs < 0)
            return "";

        const d = Math.floor(root.uptimeSecs / 86400);
        const h = Math.floor((root.uptimeSecs % 86400) / 3600);
        const m = Math.floor((root.uptimeSecs % 3600) / 60);
        if (d > 0)
            return "up " + d + "d " + h + "h";

        return h > 0 ? "up " + h + "h " + m + "m" : "up " + m + "m";
    }

    function pushSample(historyArr, v, max) {
        const next = historyArr.concat([v]);
        if (next.length > max)
            next.shift();

        return next;
    }

    function setBrightness(percent) {
        root.pendingBrightness = Math.max(0, Math.min(100, Math.round(percent)));
        brightnessDebounce.restart();
    }

    // hover tooltips over the compact strip
    property string tipKind: ""
    property Item tipTarget: null
    // what the card actually renders; trails tipKind so the resize lands at opacity 0
    property string tipViewKind: ""
    property Item tipViewTarget: null
    property bool tipShown: false
    property bool tipOverPill: false
    property bool tipOverCard: false
    property int tipAnimMs: Theme.barDurShort
    property int tipAnimEase: Easing.OutCubic
    property bool tipDragging: false
    property bool tipOnIcon: false
    readonly property bool tipWanted: (root.tipOverPill && root.tipOnIcon) || root.tipOverCard || root.tipDragging
    readonly property int tipGap: Theme.dp(6)
    // grows each icon's slab a little; the row spacing is 8, so gaps stay dead
    readonly property int tipSlabPad: Theme.dp(2)
    // a dwell delay, not an animation, so it is deliberately not motion-scaled
    readonly property int tipShowDelay: 1000
    readonly property int tipEnterMs: Theme.barMs(120)
    readonly property int tipExitMs: Theme.barMs(80)

    // each icon owns its own slab, so the pill's end padding and the gaps
    // between icons show nothing at all
    function tipPick(px) {
        const segs = [["wifi", wifiIcon], ["bluetooth", btIcon], ["volume", volIndicator], ["mic", micIndicator], ["battery", batteryRow]];
        for (const s of segs) {
            const t = s[1];
            if (!t || !t.visible || t.width <= 0.5)
                continue;

            const left = t.mapToItem(tipHover, 0, 0).x;
            if (px >= left - root.tipSlabPad && px <= left + t.width + root.tipSlabPad)
                return s;

        }
        return null;
    }

    function tipAim(px) {
        const seg = root.tipPick(px);
        root.tipOnIcon = seg !== null;
        if (!seg || root.tipKind === seg[0])
            return ;

        root.tipTarget = seg[1];
        root.tipKind = seg[0];
    }

    function tipApplyView() {
        root.tipViewKind = root.tipKind;
        root.tipViewTarget = root.tipTarget;
    }

    // the icon the pointer is over already drives the tooltip, so a click can
    // reuse it to open the view that owns that status
    readonly property var viewForKind: ({
        "wifi": "wifi",
        "bluetooth": "bluetooth",
        "volume": "output"
    })

    function aimedView() {
        if (!root.tipOnIcon || root.tipKind === "")
            return "main";

        return root.viewForKind[root.tipKind] || "main";
    }

    function tipClose() {
        tipShowTimer.stop();
        tipHideTimer.stop();
        root.tipOverPill = false;
        root.tipOverCard = false;
        root.tipOnIcon = false;
        root.tipShown = false;
    }

    function tipSetVolume(v) {
        if (!root.sink || !root.sink.audio)
            return ;

        root.sink.audio.muted = false;
        root.setVolume(v);
    }

    // every sink on one card shares node.description, and it differs only in a
    // tail that elides away - node.nick is short and actually distinct
    function deviceLabel(node) {
        if (!node)
            return "";

        const nick = node.nickname;
        if (nick && nick.length > 0)
            return nick;

        const pr = node.properties || {};
        if (pr["device.profile.description"])
            return pr["device.profile.description"];

        return root.nodeName(node);
    }

    function nodeName(node) {
        if (!node)
            return "";

        const d = node.description;
        if (d && d.length > 0)
            return d;

        const n = node.nickname;
        if (n && n.length > 0)
            return n;

        return node.name || "";
    }

    // clamped against compactWidth so a change in the strip width re-runs the map
    readonly property real tipAnchorX: {
        const t = root.tipViewTarget;
        if (!t)
            return root.compactWidth / 2;

        return Math.max(0, Math.min(root.compactWidth, t.mapToItem(root, t.width / 2, 0).x));
    }
    readonly property real tipCardX: {
        const w = tipCard.width;
        const lo = 10 - root.x;
        const hi = root.screenW - 10 - w - root.x;
        return Math.round(Math.max(lo, Math.min(hi, root.tipAnchorX - w / 2)));
    }

    readonly property string tipOverline: {
        switch (root.tipViewKind) {
        case "wifi":
            return wifiPanel.primaryIsEthernet ? "ETHERNET" : "WI-FI";
        case "bluetooth":
            return "BLUETOOTH";
        case "volume":
            return "VOLUME";
        case "mic":
            return "MICROPHONE";
        case "battery":
            return "BATTERY";
        }
        return "";
    }
    readonly property string tipTitle: {
        switch (root.tipViewKind) {
        case "wifi":
            if (wifiPanel.primaryIsEthernet)
                return "Wired connection";

            if (!Networking.wifiEnabled)
                return "Wi-Fi off";

            if (wifiPanel.connecting)
                return "Connecting…";

            if (wifiPanel.wifiConnected && wifiPanel.activeNetwork)
                return wifiPanel.activeNetwork.name;

            return "Not connected";
        case "bluetooth":
            if (!root.btEnabled)
                return "Bluetooth off";

            if (btPanel.connectedDevices.length === 1)
                return btPanel.connectedDevices[0].name;

            if (btPanel.connectedDevices.length > 1)
                return btPanel.connectedDevices.length + " devices";

            if (btPanel.anyConnecting)
                return "Connecting…";

            return "Not connected";
        case "volume":
            return root.volMuted ? "Muted" : root.volumePercent + "%";
        case "mic":
            return root.micMuted ? "Muted" : "Active";
        case "battery":
            return root.batteryPresent ? root.batteryPercent + "%" : "No battery";
        }
        return "";
    }
    readonly property string tipSupport: {
        switch (root.tipViewKind) {
        case "wifi":
            if (wifiPanel.primaryIsEthernet)
                return wifiPanel.wiredDevice ? wifiPanel.wiredDevice.name : "Wired";

            if (!Networking.wifiEnabled)
                return "Radio disabled";

            if (!wifiPanel.wifiConnected)
                return wifiPanel.nearbyNetworks.length + " networks nearby";

            const warn = wifiPanel.connectivityLabel();
            const sig = wifiPanel.strengthLabel(wifiPanel.signalStrength) + " · " + Math.round(wifiPanel.signalStrength) + "%";
            return warn !== "" ? sig + " · " + warn : sig;
        case "bluetooth":
            if (!root.btEnabled)
                return "";

            if (btPanel.connectedDevices.length === 1) {
                const b = btPanel.getBatteryText(btPanel.connectedDevices[0]);
                return b !== "" ? "Connected · " + b + " battery" : "Connected";
            }
            if (btPanel.connectedDevices.length > 1)
                return btPanel.connectedDevices.map((d) => {
                    return d.name;
                }).join(", ");

            if (btPanel.discovering)
                return "Scanning…";

            return btPanel.pairedDevices.length + " paired";
        case "volume":
            return root.deviceLabel(root.sink);
        case "mic":
            return root.deviceLabel(root.source);
        case "battery":
            if (!root.batteryPresent)
                return "";

            return root.tipBatteryTime !== "" ? root.tipBatteryState + " · " + root.tipBatteryTime : root.tipBatteryState;
        }
        return "";
    }
    readonly property string tipBatteryState: {
        if (!root.battery)
            return "";

        if (root.battery.state === UPowerDeviceState.FullyCharged)
            return "Fully charged";

        return root.batteryCharging ? "Charging" : "On battery";
    }
    readonly property string tipBatteryTime: {
        if (!root.battery)
            return "";

        const secs = root.batteryCharging ? root.battery.timeToFull : root.battery.timeToEmpty;
        if (!secs || secs <= 0)
            return "";

        const h = Math.floor(secs / 3600);
        const m = Math.round((secs % 3600) / 60);
        const body = h > 0 ? h + "h " + m + "m" : m + "m";
        return root.batteryCharging ? body + " to full" : body + " left";
    }

    // the stat card's second line: draw while discharging, else time
    readonly property string batteryDetail: {
        if (!root.batteryPresent)
            return "no battery";

        const rate = root.battery ? root.battery.changeRate : 0;
        if (!root.batteryCharging && rate > 0.05)
            return rate.toFixed(1) + " W";

        if (root.tipBatteryTime !== "")
            return root.tipBatteryTime;

        return root.batteryCharging ? "charging" : "on battery";
    }

    onTipWantedChanged: {
        if (root.tipWanted) {
            tipHideTimer.stop();
            if (!root.tipShown)
                tipShowTimer.restart();

        } else {
            tipShowTimer.stop();
            tipHideTimer.restart();
        }
    }
    // a behavior reads the previous flag value, so the timings are set here
    onTipShownChanged: {
        root.tipAnimMs = root.tipShown ? root.tipEnterMs : root.tipExitMs;
        root.tipAnimEase = root.tipShown ? Easing.OutCubic : Easing.InCubic;
    }
    onTipKindChanged: {
        root.tipShown = false;
        if (root.tipKind !== "")
            tipShowTimer.restart();

    }

    Timer {
        id: tipShowTimer

        interval: root.tipShowDelay
        onTriggered: {
            if (!root.tipWanted)
                return ;

            root.tipApplyView();
            root.tipShown = true;
        }
    }

    Timer {
        id: tipHideTimer

        interval: Theme.barMs(90)
        onTriggered: root.tipShown = false
    }

    shown: Prefs.barHas("system")

    compactWidth: content.implicitWidth + root.horizontalPadding * 2
    panelWidth: root.gridMain ? root.gridPanelWidth : Math.min(Theme.dp(400), root.screenW - Theme.dp(34))
    panelHeight: Math.min(root.maxPanelHeight, root.viewContentHeight)
    expandedRadius: Theme.shapeXl
    compactCollapseScale: 0.94
    surfaceLayered: true

    Component.onCompleted: {
        findDeviceProc.running = true;
        root.refreshGameMode();
        root.refreshOwnTiles();
    }
    onBacklightDeviceChanged: {
        if (backlightDevice !== "")
            readMaxProc.running = true;

    }
    // the glyph the pointer is on decides where the panel opens
    onCompactClicked: {
        const want = root.aimedView();
        root.view = want;
        if (want === "output")
            sinkPortsProc.running = true;

    }
    onExpandedChanged: {
        if (expanded) {
            root.tipClose();
            root.refreshGameMode();
            root.refreshOwnTiles();
            statsTimer.restart();
            lsblkProc.running = true;
        } else {
            statsTimer.stop();
            diskDropdownOpen = false;
            // the counters keep running while closed, so the first delta after
            // reopening would average over the whole closed span
            root._prevCpuTotal = -1;
            root._prevCpuIdle = -1;
            viewResetTimer.restart();
        }
    }

    Timer {
        id: statsTimer

        interval: 2000
        repeat: true
        running: false
        triggeredOnStart: true
        onTriggered: {
            cpuStatProc.running = true;
            memProc.running = true;
            hostProc.running = true;
        }
    }

    Timer {
        id: brightnessDebounce

        interval: 60
        onTriggered: {
            if (root.pendingBrightness >= 0)
                setBrightnessProc.running = true;

        }
    }

    Process {
        id: findDeviceProc

        command: ["bash", "-c", "ls /sys/class/backlight | head -1"]

        stdout: StdioCollector {
            onStreamFinished: root.backlightDevice = this.text.trim().replace(/[@/*=|]$/, "")
        }

    }

    Process {
        id: readMaxProc

        command: root.backlightDevice ? ["cat", "/sys/class/backlight/" + root.backlightDevice + "/max_brightness"] : []

        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim());
                root.maxBrightness = isNaN(v) ? 0 : v;
            }
        }

    }

    Process {
        id: setBrightnessProc

        command: root.pendingBrightness >= 0 ? ["brightnessctl", "set", root.pendingBrightness + "%"] : []
    }

    Process {
        id: cpuStatProc

        command: ["cat", "/proc/stat"]

        stdout: StdioCollector {
            onStreamFinished: {
                const firstLine = this.text.split("\n")[0];
                const parts = firstLine.trim().split(/\s+/).slice(1).map(Number);
                if (parts.length < 4)
                    return ;

                const idle = parts[3] + (parts[4] || 0);
                const total = parts.reduce((a, b) => {
                    return a + b;
                }, 0);
                if (root._prevCpuTotal >= 0) {
                    const deltaTotal = total - root._prevCpuTotal;
                    const deltaIdle = idle - root._prevCpuIdle;
                    const usage = deltaTotal > 0 ? Math.max(0, Math.min(100, 100 * (1 - deltaIdle / deltaTotal))) : 0;
                    root.cpuPercent = usage;
                    root.cpuHistory = root.pushSample(root.cpuHistory, usage, 16);
                }
                root._prevCpuTotal = total;
                root._prevCpuIdle = idle;
            }
        }

    }

    Process {
        id: memProc

        command: ["cat", "/proc/meminfo"]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text;
                const totalMatch = /MemTotal:\s+(\d+)/.exec(text);
                const availMatch = /MemAvailable:\s+(\d+)/.exec(text);
                if (!totalMatch || !availMatch)
                    return ;

                const total = parseInt(totalMatch[1]);
                const avail = parseInt(availMatch[1]);
                const usage = total > 0 ? Math.max(0, Math.min(100, 100 * (1 - avail / total))) : 0;
                root.ramPercent = usage;
                root.ramTotalGB = total / 1048576;
                root.ramUsedGB = (total - avail) / 1048576;
                root.ramHistory = root.pushSample(root.ramHistory, usage, 16);
            }
        }

    }

    // uptime plus whichever hwmon actually belongs to the cpu
    Process {
        id: hostProc

        command: ["bash", "-c", "printf 'UP %s\\n' \"$(cut -d' ' -f1 /proc/uptime)\"; t=''; for h in /sys/class/hwmon/hwmon*; do n=$(cat \"$h/name\" 2>/dev/null); case \"$n\" in coretemp|k10temp|zenpower|cpu_thermal) t=$(cat \"$h/temp1_input\" 2>/dev/null); break;; esac; done; [ -z \"$t\" ] && t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null); printf 'T %s\\n' \"${t:-}\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const up = /UP\s+([\d.]+)/.exec(this.text);
                if (up)
                    root.uptimeSecs = parseFloat(up[1]);

                const t = /T\s+(\d+)/.exec(this.text);
                root.cpuTemp = t ? parseInt(t[1]) / 1000 : -1;
            }
        }

    }

    Process {
        id: lsblkProc

        command: ["lsblk", "-J", "-o", "NAME,KNAME,PATH,TYPE"]

        stdout: StdioCollector {
            onStreamFinished: {
                let tree = [];
                try {
                    tree = JSON.parse(this.text).blockdevices || [];
                } catch (e) {
                }
                // lvm, luks and raid volumes sit below a partition, so a disk owns every path under it
                const pathsUnder = (dev) => {
                    let out = [dev.path, "/dev/" + dev.kname];
                    for (const c of dev.children || [])
                        out = out.concat(pathsUnder(c));
                    return out;
                };
                const disks = [];
                const visit = (dev) => {
                    const isWholeDisk = dev.type === "disk" && !/^(zram|loop)/.test(dev.name);
                    const isExtraPartition = dev.type === "part" && root.extraDiskPartitions.includes(dev.name);
                    if (isWholeDisk || isExtraPartition)
                        disks.push({
                            "name": dev.name,
                            "paths": pathsUnder(dev)
                        });

                    for (const c of dev.children || [])
                        visit(c);
                };
                for (const dev of tree)
                    visit(dev);
                root._lsblkDisks = disks;
                dfProc.running = true;
            }
        }

    }

    Process {
        id: dfProc

        command: ["df", "-B1", "--output=source,used,avail"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").slice(1);
                const disks = root._lsblkDisks.map((d) => {
                    return ({
                        "name": d.name,
                        "used": 0,
                        "avail": 0,
                        "mounted": false
                    });
                });
                // btrfs subvolumes and bind mounts repeat the same source
                const seen = {};
                for (const line of lines) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 3)
                        continue;

                    const source = parts[0];
                    const used = parseInt(parts[1]);
                    const avail = parseInt(parts[2]);
                    if (!source.startsWith("/dev/") || isNaN(used) || isNaN(avail) || seen[source])
                        continue;

                    seen[source] = true;
                    for (let i = 0; i < disks.length; i++) {
                        if (root._lsblkDisks[i].paths.includes(source)) {
                            disks[i].used += used;
                            disks[i].avail += avail;
                            disks[i].mounted = true;
                        }
                    }
                }
                root.diskList = disks;
                if (!disks.find((d) => {
                    return d.name === root.selectedDisk;
                }) && disks.length > 0)
                    root.selectedDisk = disks[0].name;

            }
        }

    }

    // a sink whose port is "not available" (nothing plugged in) can be set as
    // preferred but pipewire will refuse to make it the default, so the click
    // looks like it silently did nothing. Gate those out up front.
    property var sinkAvailable: ({})

    onOutputNodesChanged: {
        if (root.view === "output")
            sinkPortsProc.running = true;

    }

    Process {
        id: sinkPortsProc

        command: ["pactl", "list", "sinks"]

        stdout: StdioCollector {
            onStreamFinished: {
                const avail = {};
                let name = "";
                let ports = ({});
                for (const raw of this.text.split("\n")) {
                    const line = raw.trim();
                    let m = /^Name:\s+(\S+)/.exec(line);
                    if (m) {
                        name = m[1];
                        ports = {};
                        continue;
                    }
                    m = /^\[Out\]\s+([^:]+):/.exec(line);
                    if (m) {
                        ports[m[1].trim()] = line.indexOf("not available") === -1;
                        continue;
                    }
                    m = /^Active Port:\s+\[Out\]\s+(.+)$/.exec(line);
                    if (m && name !== "")
                        avail[name] = ports[m[1].trim()] !== false;

                }
                root.sinkAvailable = avail;
            }
        }

    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // keyboard layout: the main keyboard's active xkb layout, re-read whenever
    // hyprland reports a switch (the event only carries the long name)
    property string kbLayout: ""
    property string kbLayoutName: ""

    Process {
        id: kbLayoutProc

        command: ["hyprctl", "devices", "-j"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(this.text).keyboards || [];
                    const kb = kbs.find((k) => {
                        return k.main;
                    }) || kbs[0];
                    if (!kb)
                        return ;

                    const codes = String(kb.layout).split(",");
                    const code = (codes[kb.active_layout_index] || codes[0] || "").trim();
                    root.kbLayout = (code.length <= 3 ? code : code.slice(0, 2)).toUpperCase();
                    root.kbLayoutName = kb.active_keymap || "";
                } catch (e) {
                }
            }
        }

    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "activelayout")
                kbLayoutProc.running = true;

        }

        target: Hyprland
    }

    Process {
        id: kbSwitchProc

        command: ["hyprctl", "switchxkblayout", "all", "next"]
    }

    // game mode: whatever the user put in Settings → Bar → Game mode, run
    // through bash; the optional status command (exit 0 = on) keeps the tile in
    // step with changes made elsewhere, e.g. a keybind
    property bool gameModeOn: false
    property bool gameModeBusy: false
    property bool gameModeFailed: false
    readonly property bool gameModeConfigured: Prefs.gameModeConfigured

    function setGameMode(on) {
        if (!root.gameModeConfigured || root.gameModeBusy)
            return ;

        root.gameModeFailed = false;
        root.gameModeBusy = true;
        root.gameModeOn = on;
        gameModeProc.command = ["bash", "-c", on ? Prefs.gameModeOnRun : Prefs.gameModeOffRun];
        gameModeProc.running = true;
    }

    function refreshGameMode() {
        if (Prefs.gameModeStatusRun === "" || root.gameModeBusy || gameModeStatusProc.running)
            return ;

        gameModeStatusProc.command = ["bash", "-c", Prefs.gameModeStatusRun];
        gameModeStatusProc.running = true;
    }

    Process {
        id: gameModeProc

        onExited: (code) => {
            root.gameModeBusy = false;
            if (code !== 0) {
                root.gameModeFailed = true;
                root.gameModeOn = !root.gameModeOn;
            }
            root.refreshGameMode();
        }
    }

    Process {
        id: gameModeStatusProc

        onExited: (code) => {
            return root.gameModeOn = code === 0;
        }
    }

    // the user's own tiles, from the module's card: a switch runs its on or
    // off command through bash and, like game mode, asks its status command
    // (exit 0 = on) whenever the panel opens; a button only runs its command
    property var ownOn: ({})
    property var ownBusy: ({})
    property var ownFailed: ({})

    function ownSet(map, key, v) {
        const out = Object.assign({}, root[map]);
        out[key] = v;
        root[map] = out;
    }

    function ownRun(key, script, check) {
        const p = ownRunC.createObject(root, {
            "key": key,
            "check": check,
            "command": ["bash", "-c", script]
        });
        p.running = true;
    }

    function ownAct(key) {
        const t = Prefs.systemOwnTile(key);
        if (!t || t.on.trim() === "") {
            // nothing to run yet: its fields are on the module's card
            root.expanded = false;
            Prefs.openBarModule("system", "owntiles");
            return ;
        }
        if (t.off.trim() === "") {
            root.expanded = false;
            Quickshell.execDetached(["bash", "-c", "sleep 0.3; " + t.on]);
            return ;
        }
        if (root.ownBusy[key])
            return ;

        const on = !root.ownOn[key];
        root.ownSet("ownFailed", key, false);
        root.ownSet("ownBusy", key, true);
        root.ownSet("ownOn", key, on);
        root.ownRun(key, on ? t.on : t.off, false);
    }

    function ownDone(key, check, code) {
        if (check) {
            root.ownSet("ownOn", key, code === 0);
            return ;
        }
        root.ownSet("ownBusy", key, false);
        if (code !== 0) {
            root.ownSet("ownFailed", key, true);
            root.ownSet("ownOn", key, !root.ownOn[key]);
        }
        root.refreshOwnTiles();
    }

    function refreshOwnTiles() {
        for (const t of Prefs.systemOwnTileList) {
            if (t.off.trim() !== "" && t.status.trim() !== "" && !root.ownBusy[t.key])
                root.ownRun(t.key, t.status, true);

        }
    }

    Component {
        id: ownRunC

        Process {
            property string key: ""
            property bool check: false

            onExited: (code) => {
                root.ownDone(key, check, code);
                destroy();
            }
        }

    }

    Connections {
        function onSystemOwnTilesChanged() {
            root.refreshOwnTiles();
        }

        target: Prefs
    }

    Connections {
        function onGameModeStatusCmdChanged() {
            root.refreshGameMode();
        }

        target: Prefs
    }

    // only bound while the picker is up, so idle devices stay untracked
    PwObjectTracker {
        objects: root.view === "output" ? root.outputNodes : []
    }

    FileView {
        id: brightnessFile

        path: root.backlightDevice ? "/sys/class/backlight/" + root.backlightDevice + "/brightness" : ""
        watchChanges: true
        onFileChanged: reload()
    }

    property date nowDate: Loc.now()

    Timer {
        interval: 30000
        repeat: true
        running: root.expanded
        triggeredOnStart: true
        onTriggered: root.nowDate = Loc.now()
    }

    // two-step confirm for the actions that end the session
    property string powerArmed: ""

    Timer {
        id: powerDisarm

        interval: 3200
        onTriggered: root.powerArmed = ""
    }

    function powerPick(id) {
        if (id === "lock" || id === "suspend" || root.powerArmed === id) {
            root.powerArmed = "";
            root.expanded = false;
            Power.run(id);
            return ;
        }
        root.powerArmed = id;
        powerDisarm.restart();
    }

    function toggleMicMute() {
        if (root.source && root.source.audio)
            root.source.audio.muted = !root.source.audio.muted;

    }

    // what each key in Prefs.systemTiles shows, and what a tap on it does
    function tileIcon(key) {
        switch (key) {
        case "wifi":
            return root.wifiGlyph;
        case "bluetooth":
            return root.btGlyph;
        case "mic":
            return root.micMuted ? "mic_off" : "mic";
        case "record":
            return Capture.active ? "stop_circle" : "screen_record";
        case "profile":
            return Power.symbol(Power.profile);
        case "nightlight":
            return NightLight.active ? "nightlight" : "bedtime";
        case "sound":
            return root.volMuted ? "volume_off" : "volume_up";
        case "vpn":
            return Net.activeVpn ? "vpn_key" : "vpn_key_off";
        }
        const t = Prefs.systemTileAt(key);
        return t ? t.icon : "";
    }

    function tileLabel(key) {
        switch (key) {
        case "wifi":
            return wifiPanel.primaryIsEthernet ? "Ethernet" : "Wi-Fi";
        case "location":
            return Prefs.gpsEnabled && Loc.busy ? "Locating" : "Location";
        case "record":
            return Capture.active ? Capture.clock(Capture.seconds) : "Record";
        case "timer":
            return Chrono.headline ? Chrono.countdown(Chrono.headline.left) : "Timer";
        case "gamemode":
            if (root.gameModeBusy)
                return root.gameModeOn ? "Starting" : "Stopping";

            return root.gameModeFailed ? "Failed" : "Game";
        }
        if (root.ownFailed[key])
            return "Failed";

        const t = Prefs.systemTileAt(key);
        return t ? t.name : "";
    }

    function tileChecked(key) {
        switch (key) {
        case "wifi":
            return Networking.wifiEnabled || wifiPanel.primaryIsEthernet;
        case "bluetooth":
            return root.btEnabled;
        case "dnd":
            return root.dndOn;
        case "awake":
            return Prefs.idleKeepAwake;
        case "dark":
            return Prefs.colorMode === "dark";
        case "airplane":
            return root.airplaneMode;
        case "location":
            return Prefs.gpsEnabled;
        case "mic":
            return !root.micMuted;
        case "record":
            return Capture.active;
        case "timer":
            return Chrono.headline !== null && Chrono.headline.running;
        case "widgets":
            return Prefs.widgetsEnabled;
        case "gamemode":
            return root.gameModeOn;
        case "profile":
            return Power.profile !== PowerProfile.Balanced;
        case "nightlight":
            return NightLight.active;
        case "sound":
            return !root.volMuted;
        case "vpn":
            return Net.activeVpn !== null;
        case "dock":
            return Prefs.dockEnabled;
        case "stopwatch":
            return Chrono.swRunning;
        }
        return !!root.ownOn[key];
    }

    // tools behind another surface, which only opens once this one is gone
    readonly property var tileCommands: ({
        "capture": "qs ipc call snap open",
        "record": "qs ipc call snap video",
        "picker": "qs ipc call snap color",
        "clipboard": "qs ipc call launcher clipboard",
        "emoji": "qs ipc call moji open",
        "wallpaper": "qs ipc call launcher wallpaper",
        "theme": "qs ipc call launcher theme",
        "screenshot": "qs ipc call screenshot full",
        "ocr": "qs ipc call snap text",
        "overview": "qs ipc call workspaces toggle",
        "scratchpad": "hyprctl eval 'if LucidSpecials then LucidSpecials.scratchpad() end'",
        "stopwatch": "qs ipc call -- clock open stopwatch",
        "keybinds": "qs ipc call keybinds open"
    })

    function tileAct(key) {
        if (Prefs.systemOwnTile(key)) {
            root.ownAct(key);
            return ;
        }
        const cmd = root.tileCommands[key];
        if (cmd) {
            root.expanded = false;
            Quickshell.execDetached(["sh", "-c", "sleep 0.3; " + cmd]);
            return ;
        }
        switch (key) {
        case "wifi":
            Networking.wifiEnabled = !Networking.wifiEnabled;
            break;
        case "bluetooth":
            Bt.setEnabled(!root.btEnabled);
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
        case "airplane":
            root.toggleAirplane();
            break;
        case "location":
            Prefs.gpsEnabled = !Prefs.gpsEnabled;
            if (Prefs.gpsEnabled)
                Loc.detect();

            break;
        case "mic":
            root.toggleMicMute();
            break;
        case "widgets":
            Prefs.widgetsEnabled = !Prefs.widgetsEnabled;
            break;
        case "clear":
            Notifs.clearAll();
            break;
        case "keyboard":
            root.expanded = false;
            Prefs.keyboardRequested();
            break;
        case "timer":
            root.expanded = false;
            Quickshell.execDetached(["qs", "ipc", "call", "--", "clock", "open", "timer"]);
            break;
        case "session":
            root.expanded = false;
            Quickshell.execDetached(["qs", "ipc", "call", "session", "open"]);
            break;
        case "gamemode":
            if (!root.gameModeConfigured) {
                root.expanded = false;
                Prefs.settingsRequested("bar");
            } else {
                root.setGameMode(!root.gameModeOn);
            }
            break;
        case "profile":
            // a tap steps to the next profile; a right click lists them all
            Power.cycle();
            break;
        case "nightlight":
            // a right click opens the warmth and the schedule
            NightLight.toggle();
            break;
        case "sound":
            root.toggleVolMute();
            break;
        case "vpn":
            // one at a time, the way NetworkManager does it; none set up opens its page
            if (Net.activeVpn) {
                Net.down(Net.activeVpn.uuid);
            } else if (Net.vpns.length > 0) {
                Net.up(Net.vpns[0].uuid);
            } else {
                root.expanded = false;
                Prefs.settingsRequested("network");
            }
            break;
        case "dock":
            Prefs.dockEnabled = !Prefs.dockEnabled;
            break;
        case "lock":
            root.expanded = false;
            Lockscreen.lock(Theme.barDurEnter + Theme.ms(60));
            break;
        case "phone":
            // rings the phone that is in reach; with none, the phone page says why
            if (KdeConnect.reachable.length > 0) {
                KdeConnect.ring(KdeConnect.reachable[0].id);
            } else {
                root.expanded = false;
                Prefs.settingsRequested("kdeconnect");
            }
            break;
        case "settings":
            root.expanded = false;
            Prefs.settingsRequested("");
            break;
        }
    }

    // the header buttons picked on the module's card, in that order; anything
    // unknown, or named twice, is left out
    function picked(list, known) {
        return String(list || "").split(",").map((k) => {
            return k.trim();
        }).filter((k, i, all) => {
            return known.indexOf(k) !== -1 && all.indexOf(k) === i;
        });
    }

    readonly property var headerKeys: root.picked(Prefs.systemHeaderButtons, ["edit", "settings", "lock", "power"])
    // the blocks, in the order picked on the module's card, and what the sliders
    // hold; the tile blocks hold the tiles, the gauges the readings picked
    readonly property var blockKeys: Prefs.systemBlockKeys
    // only the sliders with something to move here
    readonly property var sliderKeys: Prefs.systemSliderKeys.filter((k) => {
        return (k !== "brightness" || root.maxBrightness > 0) && (k !== "mic" || !!(root.source && root.source.audio));
    })
    readonly property bool mediaUp: !!(root.mprisMod && root.mprisMod.player)

    // what a block holds here
    function blockPieces(key) {
        switch (key) {
        case "sliders":
            return root.sliderKeys;
        case "bigtiles":
            return Prefs.systemBigTileKeys;
        case "tiles":
            return Prefs.systemSmallTileKeys;
        case "media":
            return root.mediaUp ? ["media"] : [];
        }
        return Prefs.systemInfoKeys;
    }

    function blockShown(key) {
        return root.blockKeys.indexOf(key) !== -1 && root.blockPieces(key).length > 0;
    }

    readonly property var shownBlocks: root.blockKeys.filter((k) => {
        return root.blockShown(k);
    })
    // the panel is the grid kept in Prefs.systemGrid: a column is a tile wide
    // and a row a thin strip, so a block is as tall as it was made, or as its
    // pieces need. the columns and rows nothing shown sits in fold away
    readonly property int gridUnit: Theme.dp(52)
    readonly property int gridRow: Theme.dp(20)
    readonly property int gridGap: root.sp3
    // across, where each block sits does not hang on what it holds
    readonly property var gridSpots: Prefs.systemGridPlace(root.blockKeys)
    // the rows each shown block's pieces need
    readonly property var gridNeeds: {
        const out = {};
        for (const k of root.shownBlocks) {
            const b = root.blockItem(k);
            if (b)
                out[k] = Math.ceil((b.implicitHeight + root.gridGap) / (root.gridRow + root.gridGap));

        }
        return out;
    }
    readonly property var gridPlace: Prefs.systemGridPlace(root.blockKeys, root.gridNeeds)
    readonly property bool slidersStand: !!(root.gridSpots.sliders && !root.gridSpots.sliders.lie)

    function gridSpan(n) {
        return n * root.gridUnit + Math.max(0, n - 1) * root.gridGap;
    }

    function gridRowSpan(n) {
        return n * root.gridRow + Math.max(0, n - 1) * root.gridGap;
    }

    // the cells the shown blocks cover, in order: the rest fold away
    function gridUsed(place, across) {
        const out = [];
        for (const k of root.shownBlocks) {
            const r = place[k];
            if (!r)
                continue;

            const from = across ? r.x : r.y;
            for (let i = 0; i < (across ? r.w : r.h); i++)
                if (out.indexOf(from + i) === -1)
                    out.push(from + i);
        }
        return out.sort((a, b) => {
            return a - b;
        });
    }

    readonly property var gridCols: root.gridUsed(root.gridSpots, true)
    readonly property var gridRows: root.gridUsed(root.gridPlace, false)

    // a shown block's box on the grid, in pixels
    function gridBox(key) {
        const r = root.gridPlace[key];
        const ci = r ? root.gridCols.indexOf(r.x) : -1;
        const ri = r ? root.gridRows.indexOf(r.y) : -1;
        if (ci < 0 || ri < 0)
            return Qt.rect(0, 0, root.gridUnit, 0);

        return Qt.rect(ci * (root.gridUnit + root.gridGap), ri * (root.gridRow + root.gridGap), root.gridSpan(r.w), root.gridRowSpan(r.h));
    }

    readonly property int gridWidth: root.gridSpan(root.gridCols.length)
    readonly property real gridHeight: root.gridRowSpan(root.gridRows.length)
    readonly property int gridPanelWidth: root.gridWidth + root.panelPad * 2
    // only the main view, and only while the grid fits the screen: otherwise,
    // and in the other views, which are lists, the usual single column
    readonly property bool gridMain: root.view === "main" && root.screenW >= root.gridPanelWidth + Theme.dp(34)

    // across, a block's columns are all it takes; down, the rows decide
    function blockWidth(key) {
        return root.gridMain && root.gridSpots[key] ? root.gridSpan(root.gridSpots[key].w) : root.contentWidth;
    }

    function blockItem(key) {
        return blockRepeater.count > 0 ? blockRepeater.itemAt(root.blockKeys.indexOf(key)) : null;
    }

    // the single column: top to bottom as on the grid
    readonly property var columnOrder: root.shownBlocks.slice().sort((a, b) => {
        const p = root.gridSpots[a], q = root.gridSpots[b];
        return p && q ? (p.y - q.y || p.x - q.x) : 0;
    })

    function blockStart(key) {
        let at = 0;
        for (const k of root.columnOrder) {
            if (k === key)
                break;

            const b = root.blockItem(k);
            at += (b ? b.height : 0) + root.sp3;
        }
        return at;
    }

    // what the blocks show and do, as CcBlock asks its host
    function sliderIcon(k) {
        return k === "brightness" ? root.brightnessIcon : (k === "volume" ? root.volumeIcon(root.volumePercent, root.volMuted) : (root.micMuted ? "mic_off" : "mic"));
    }

    function sliderValue(k) {
        return k === "brightness" ? root.brightnessPercent : (k === "volume" ? root.volumePercent : root.micPercent);
    }

    function sliderMuted(k) {
        return (k === "volume" && root.volMuted) || (k === "mic" && root.micMuted);
    }

    function sliderMove(k, v) {
        if (k === "brightness") {
            root.setBrightness(v);
        } else if (k === "volume") {
            if (root.sink && root.sink.audio && root.sink.audio.muted)
                root.sink.audio.muted = false;

            root.setVolume(v);
        } else {
            root.setMicVolume(v);
        }
    }

    function sliderIconClick(k) {
        if (k === "volume")
            root.toggleVolMute();
        else if (k === "mic")
            root.toggleMicMute();
    }

    readonly property var mprisPlayer: root.mprisMod ? root.mprisMod.player : null
    readonly property string mediaTitle: root.mprisMod ? root.mprisMod.title : ""
    readonly property string mediaArtist: root.mprisMod ? root.mprisMod.artist : ""
    readonly property string mediaArt: root.mprisMod ? root.mprisMod.artSource : ""
    readonly property real mediaProgress: (root.mprisMod && root.mprisMod.lenSec > 0) ? Math.max(0, Math.min(1, root.mprisMod.livePosSec / root.mprisMod.lenSec)) : 0
    readonly property bool mediaPlaying: root.mprisMod ? root.mprisMod.isPlaying : false
    readonly property real mediaPosition: root.mprisMod ? root.mprisMod.livePosSec : 0
    readonly property real mediaLength: root.mprisMod ? root.mprisMod.lenSec : 0

    function mediaSeek(sec) {
        if (root.mprisMod)
            root.mprisMod.seekTo(sec, true);

    }

    function mediaPrev() {
        if (root.mprisPlayer && root.mprisPlayer.canGoPrevious)
            root.mprisPlayer.previous();

    }

    function mediaToggle() {
        if (root.mprisPlayer && root.mprisPlayer.canTogglePlaying)
            root.mprisPlayer.togglePlaying();

    }

    function mediaNext() {
        if (root.mprisPlayer && root.mprisPlayer.canGoNext)
            root.mprisPlayer.next();

    }

    function mediaOpen() {
        root.expanded = false;
        if (root.mprisMod)
            root.mprisMod.expanded = true;

    }

    readonly property var selectedDiskInfo: {
        for (const d of root.diskList) {
            if (d.name === root.selectedDisk)
                return d;

        }
        return root.diskList.length > 0 ? root.diskList[0] : null;
    }
    // fs overhead and the root reserve are neither used nor free, so measure against what df can hand out
    readonly property real diskPct: (root.selectedDiskInfo && root.selectedDiskInfo.mounted && root.selectedDiskInfo.used + root.selectedDiskInfo.avail > 0) ? root.selectedDiskInfo.used / (root.selectedDiskInfo.used + root.selectedDiskInfo.avail) : 0

    // each gauge, as CcGauge reads it
    function gauge(k) {
        switch (k) {
        case "cpu":
            return {
                "value": root.cpuPercent / 100,
                "center": root.cpuHistory.length > 0 ? Math.round(root.cpuPercent) + "" : "—",
                "label": "CPU",
                "detail": root.cpuTemp > 0 ? Units.degUnit(root.cpuTemp) : "",
                "tone": root.cpuTemp >= 85 ? Theme.error : Theme.accent,
                "icon": "",
                "history": root.cpuHistory.map((v) => {
                    return v / 100;
                })
            };
        case "ram":
            return {
                "value": root.ramPercent / 100,
                "center": root.ramHistory.length > 0 ? Math.round(root.ramPercent) + "" : "—",
                "label": "Memory",
                "detail": root.ramTotalGB > 0 ? root.ramUsedGB.toFixed(1) + " GB" : "",
                "tone": Theme.accent,
                "icon": "",
                "history": root.ramHistory.map((v) => {
                    return v / 100;
                })
            };
        case "disk":
            return {
                "value": root.diskPct,
                "center": root.selectedDiskInfo && root.selectedDiskInfo.mounted ? Math.round(root.diskPct * 100) + "" : "—",
                "label": root.selectedDisk || "Disk",
                "detail": root.selectedDiskInfo ? (root.selectedDiskInfo.mounted ? Math.round(root.selectedDiskInfo.avail / 1.07374e+09) + " GB free" : "not mounted") : "",
                "tone": root.diskPct * 100 > 100 - Prefs.storageLowPercent ? Theme.error : Theme.accent,
                "icon": "",
                "clickable": root.diskList.length > 1
            };
        }
        return {
            "value": root.batteryPresent ? root.batteryPercent / 100 : 0,
            "center": root.batteryPresent ? root.batteryPercent + "" : "—",
            "label": root.batteryCharging ? "Charging" : "Battery",
            "detail": root.batteryDetail,
            "tone": root.batteryPercent <= 20 && !root.batteryCharging ? Theme.error : Theme.accent,
            "icon": root.batteryCharging ? "bolt" : ""
        };
    }

    // a tap on the disk gauge moves to the next disk
    function gaugeClick(k) {
        if (k !== "disk" || root.diskList.length < 2)
            return ;

        let i = 0;
        for (let j = 0; j < root.diskList.length; j++) {
            if (root.diskList[j].name === root.selectedDisk)
                i = j;

        }
        root.selectedDisk = root.diskList[(i + 1) % root.diskList.length].name;
    }

    readonly property int micPercent: (root.source && root.source.audio) ? Math.round(root.source.audio.volume * 100) : 0

    function setMicVolume(v) {
        if (!root.source || !root.source.audio)
            return ;

        if (root.source.audio.muted)
            root.source.audio.muted = false;

        root.source.audio.volume = v / 100;
    }

    // a big tile's name, and the line under it saying what it is doing
    function bigName(key) {
        switch (key) {
        case "dnd":
            return "Do not disturb";
        case "awake":
            return "Stay awake";
        case "dark":
            return "Dark mode";
        case "mic":
            return "Microphone";
        case "gamemode":
            return "Game mode";
        case "profile":
            return "Power profile";
        }
        return root.tileLabel(key);
    }

    function bigSub(key) {
        const on = root.tileChecked(key);
        switch (key) {
        case "wifi":
            return wifiPanel.statusText;
        case "bluetooth":
            return btPanel.label;
        case "airplane":
            return on ? "Radios off" : "Off";
        case "dnd":
            return on ? "Silenced" : "Off";
        case "awake":
            return on ? "Staying awake" : "Idle allowed";
        case "location":
            return !on ? "Off" : (Loc.busy ? "Locating" : "On");
        case "mic":
            return on ? "On" : "Muted";
        case "gamemode":
            if (root.gameModeBusy)
                return root.gameModeOn ? "Starting" : "Stopping";

            if (root.gameModeFailed)
                return "Failed";

            return !root.gameModeConfigured ? "Set it up" : (on ? "On" : "Off");
        case "profile":
            return Power.name(Power.profile);
        case "vpn":
            return Net.activeVpn ? Net.activeVpn.name : (Net.vpns.length > 0 ? "Off" : "None set up");
        case "record":
        case "timer":
            return root.tileLabel(key);
        }
        const own = Prefs.systemOwnTile(key);
        if (own) {
            if (root.ownBusy[key])
                return on ? "Starting" : "Stopping";

            if (root.ownFailed[key])
                return "Failed";

            if (own.on.trim() === "")
                return "Set it up";

            return own.off.trim() === "" ? "" : (on ? "On" : "Off");
        }
        return root.tileChecked(key) ? "On" : "";
    }

    // the tiles with a page of their own: a right click on a small one, the
    // body of a big one, opens it
    readonly property var tilePages: ["wifi", "bluetooth", "profile", "nightlight"]

    function headerAct(key) {
        switch (key) {
        case "edit":
            // the layout editor on the module's card in Settings
            root.expanded = false;
            Prefs.openBarModule("system", "layout");
            break;
        case "settings":
            root.expanded = false;
            Prefs.settingsRequested("");
            break;
        case "lock":
            root.expanded = false;
            Power.run("lock");
            break;
        case "power":
            root.showView("power");
            break;
        }
    }

    // small tiles to a row, where the panel is one column
    readonly property int tileCols: 6

    readonly property string brightnessIcon: root.brightnessPercent < 34 ? "brightness_low" : (root.brightnessPercent < 67 ? "brightness_medium" : "brightness_high")

    compactContent: [
        Row {
            id: content

            anchors.centerIn: parent
            spacing: Theme.dp(10)

            // the active keyboard layout; a click steps to the next one, the
            // rest of the pill still opens the panel
            Rectangle {
                id: kbIndicator

                visible: Prefs.showKbLayout && root.kbLayout !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: kbText.implicitWidth + Theme.dp(10)
                height: Theme.dp(20)
                radius: height / 2
                color: kbArea.containsMouse ? Theme.alpha(Theme.text, 0.1) : "transparent"

                LText {
                    id: kbText

                    anchors.centerIn: parent
                    role: "labelMedium"
                    weight: 620
                    text: root.kbLayout
                    color: Theme.text
                }

                MouseArea {
                    id: kbArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: kbSwitchProc.running = true
                }

            }

            Icon {
                id: wifiIcon

                anchors.verticalCenter: parent.verticalCenter
                name: root.wifiGlyph
                size: Theme.dp(17)
                fill: 1
                color: (wifiPanel.wifiConnected || wifiPanel.primaryIsEthernet) ? Theme.accent : Theme.subtext
            }

            Icon {
                id: btIcon

                visible: root.btEnabled
                anchors.verticalCenter: parent.verticalCenter
                name: root.btGlyph
                size: Theme.dp(16)
                color: btPanel.connectedDevices.length > 0 ? Theme.accent : Theme.subtext
            }

            Row {
                id: volIndicator

                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(3)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.volumeIcon(root.volumePercent, root.volMuted)
                    size: Theme.dp(17)
                    fill: 1
                    color: root.volMuted ? Theme.error : Theme.text
                }

                LText {
                    visible: !root.volMuted
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelMedium"
                    weight: 620
                    text: root.volumePercent
                    color: Theme.text
                }

            }

            Icon {
                id: micIndicator

                anchors.verticalCenter: parent.verticalCenter
                name: root.micMuted ? "mic_off" : "mic"
                size: Theme.dp(16)
                fill: 1
                color: root.micMuted ? Theme.error : Theme.subtext
            }

            BatteryPill {
                id: batteryRow

                visible: root.batteryPresent
                anchors.verticalCenter: parent.verticalCenter
                percent: root.batteryPercent
                charging: root.batteryCharging
            }

        },
        MouseArea {
            id: tipHover

            anchors.fill: parent
            enabled: root.shown && !root.anyOpen
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // no button is accepted, so the pill's own click still opens the panel
            acceptedButtons: Qt.NoButton
            onEntered: root.tipAim(tipHover.mouseX)
            onPositionChanged: (mouse) => {
                root.tipAim(mouse.x);
            }
            // mirrored rather than set on enter/exit, so disabling clears it too
            onContainsMouseChanged: {
                root.compactHovered = tipHover.containsMouse;
                root.tipOverPill = tipHover.containsMouse;
                if (!tipHover.containsMouse)
                    root.tipOnIcon = false;

            }
        }
    ]

    panelContent: [
        Item {
            id: panelStack

            anchors.fill: parent

            Item {
                id: mainView

                y: 0
                width: panelStack.width
                height: panelStack.height
                x: root.inSubView ? -root.panelWidth : 0
                visible: x > -root.panelWidth + 0.5

                // gated, or the first layout (width 0 -> panelWidth) animates too
                Behavior on x {
                    enabled: root.viewSwitching

                    NumberAnimation {
                        duration: root.morphDuration
                        easing.type: Easing.Bezier
                        easing.bezierCurve: root.morphEasing
                    }

                }

                Item {
                    id: mainHeader

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: root.sp2
                    anchors.leftMargin: root.panelPad + Theme.dp(4)
                    anchors.rightMargin: root.panelPad - Theme.dp(4)
                    height: root.headerHeight

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        LText {
                            role: "titleMedium"
                            weight: 600
                            text: Qt.formatDate(root.nowDate, "dddd, d MMMM")
                        }

                        LText {
                            visible: root.uptimeText !== ""
                            role: "bodySmall"
                            color: Theme.subtext
                            text: root.uptimeText
                        }

                    }

                    // the ones picked on the module's card, in that order
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(2)

                        Repeater {
                            model: root.headerKeys

                            IconButton {
                                required property string modelData

                                icon: ({
                                    "edit": "edit",
                                    "settings": "settings",
                                    "lock": "lock",
                                    "power": "power_settings_new"
                                })[modelData]
                                variant: modelData === "power" ? "tonal" : "standard"
                                onClicked: root.headerAct(modelData)
                            }

                        }

                    }

                }

                Flickable {
                    id: scrollArea

                    anchors.top: mainHeader.bottom
                    anchors.topMargin: root.sp1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: root.panelPad
                    anchors.rightMargin: root.panelPad
                    anchors.bottomMargin: root.panelPad
                    contentWidth: width
                    contentHeight: mainColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // the blocks where the module's card put them on the grid, or one
                    // under another when the grid does not fit the screen
                    Item {
                        id: mainColumn

                        width: root.gridMain ? root.gridWidth : root.contentWidth
                        implicitHeight: {
                            if (root.gridMain)
                                return root.gridHeight;

                            let h = 0;
                            for (const k of root.shownBlocks) {
                                const b = root.blockItem(k);
                                h += b ? b.height : 0;
                            }
                            return h + Math.max(0, root.shownBlocks.length - 1) * root.sp3;
                        }

                        Repeater {
                            id: blockRepeater

                            model: root.blockKeys

                            CcBlock {
                                required property string modelData
                                readonly property var spot: root.gridSpots[modelData] || null

                                visible: root.blockShown(modelData)
                                kind: modelData
                                keys: root.blockPieces(modelData)
                                host: root
                                // on the grid a column is a small tile and three a big one
                                cols: root.gridMain && spot ? spot.w : root.tileCols
                                bigCols: root.gridMain && spot ? Math.max(1, Math.floor(spot.w / 3)) : 2
                                gap: root.gridMain ? root.gridGap : root.sp2
                                standing: root.gridMain && root.slidersStand
                                look: Prefs.systemBlockStyle(modelData)
                                cards: Prefs.systemBlockCards
                                x: root.gridMain ? root.gridBox(modelData).x : 0
                                y: root.gridMain ? root.gridBox(modelData).y : root.blockStart(modelData)
                                width: root.blockWidth(modelData)
                                height: root.gridMain ? root.gridBox(modelData).height : implicitHeight
                            }

                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            const maxY = Math.max(0, scrollArea.contentHeight - scrollArea.height);
                            scrollArea.contentY = Math.max(0, Math.min(maxY, scrollArea.contentY - (wheel.angleDelta.y / 120) * 90));
                            wheel.accepted = true;
                        }
                    }

                }

            }

            Item {
                id: subView

                y: 0
                width: panelStack.width
                height: panelStack.height
                x: root.inSubView ? 0 : root.panelWidth
                visible: x < root.panelWidth - 0.5

                Behavior on x {
                    enabled: root.viewSwitching

                    NumberAnimation {
                        duration: root.morphDuration
                        easing.type: Easing.Bezier
                        easing.bezierCurve: root.morphEasing
                    }

                }

                Item {
                    id: subHeader

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: root.sp2
                    anchors.leftMargin: root.panelPad - Theme.dp(6)
                    anchors.rightMargin: root.panelPad
                    height: root.subHeaderHeight

                    IconButton {
                        id: backChip

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "arrow_back"
                        tintOverride: Theme.text
                        onClicked: root.showView("main")
                    }

                    LText {
                        anchors.left: backChip.right
                        anchors.leftMargin: root.sp1
                        anchors.verticalCenter: parent.verticalCenter
                        role: "titleMedium"
                        weight: 600
                        text: {
                            switch (root.view) {
                            case "wifi":
                                return "Internet";
                            case "bluetooth":
                                return "Bluetooth";
                            case "output":
                                return "Sound output";
                            case "power":
                                return "Power";
                            case "profile":
                                return "Power profile";
                            case "nightlight":
                                return "Night light";
                            }
                            return "";
                        }
                    }

                    Switch {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.view === "bluetooth" || root.view === "wifi" || root.view === "nightlight"
                        checked: root.view === "wifi" ? Networking.wifiEnabled : (root.view === "nightlight" ? NightLight.active : root.btEnabled)
                        onToggled: {
                            if (root.view === "wifi")
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                            else if (root.view === "nightlight")
                                NightLight.toggle();
                            else
                                Bt.setEnabled(!root.btEnabled);
                        }
                    }

                }

                Flickable {
                    id: subScroll

                    anchors.top: subHeader.bottom
                    anchors.topMargin: root.sp1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: root.panelPad
                    anchors.rightMargin: root.panelPad
                    anchors.bottomMargin: root.panelPad
                    contentWidth: width
                    contentHeight: {
                        switch (root.view) {
                        case "bluetooth":
                            return btPanel.implicitHeight;
                        case "output":
                            return outputList.implicitHeight;
                        case "power":
                            return powerList.implicitHeight;
                        case "profile":
                            return powerPanel.implicitHeight;
                        case "nightlight":
                            return nightPanel.implicitHeight;
                        }
                        return wifiPanel.implicitHeight;
                    }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    WifiPanel {
                        id: wifiPanel

                        width: subScroll.width
                        active: root.expanded && root.view === "wifi"
                        visible: root.view === "wifi"
                    }

                    BluetoothPanel {
                        id: btPanel

                        width: subScroll.width
                        active: root.expanded && root.view === "bluetooth"
                        visible: root.view === "bluetooth"
                        onCloseRequested: root.expanded = false
                    }

                    NightLightPanel {
                        id: nightPanel

                        width: subScroll.width
                        visible: root.view === "nightlight"
                        onSettingsRequested: {
                            root.expanded = false;
                            Prefs.settingsRequested("displays");
                        }
                    }

                    PowerPanel {
                        id: powerPanel

                        width: subScroll.width
                        visible: root.view === "profile"
                        gameModeOn: root.gameModeOn
                    }

                    Column {
                        id: outputList

                        width: subScroll.width
                        visible: root.view === "output"
                        spacing: Theme.dp(2)

                        Repeater {
                            model: root.outputNodes

                            ListItem {
                                id: devOpt

                                required property var modelData
                                required property int index
                                readonly property bool isCurrent: root.sink === devOpt.modelData
                                readonly property bool usable: root.sinkAvailable[devOpt.modelData.name] !== false
                                readonly property string lower: (root.deviceLabel(devOpt.modelData) + " " + (devOpt.modelData.name || "")).toLowerCase()

                                width: outputList.width
                                first: devOpt.index === 0
                                last: devOpt.index === root.outputNodes.length - 1
                                containerColor: Theme.withBlur(Theme.surfaceHigh)
                                selected: devOpt.isCurrent
                                disabled: !devOpt.usable
                                icon: devOpt.lower.indexOf("head") >= 0 || devOpt.lower.indexOf("bluez") >= 0 ? "headphones" : (devOpt.lower.indexOf("hdmi") >= 0 ? "tv" : "speaker")
                                headline: root.deviceLabel(devOpt.modelData)
                                supporting: devOpt.isCurrent ? "Playing here" : (devOpt.usable ? "" : "Not connected")
                                onClicked: {
                                    if (devOpt.usable)
                                        Pipewire.preferredDefaultAudioSink = devOpt.modelData;

                                }
                                trailing: [
                                    Icon {
                                        visible: devOpt.isCurrent
                                        name: "check"
                                        color: Theme.fgSecondaryContainer
                                    }
                                ]
                            }

                        }

                        LText {
                            width: outputList.width
                            visible: root.outputNodes.length === 0
                            horizontalAlignment: Text.AlignHCenter
                            role: "bodyMedium"
                            color: Theme.subtext
                            text: "No output devices"
                            topPadding: root.sp5
                            bottomPadding: root.sp5
                        }

                        // each program's own level, so one loud app is turned
                        // down here instead of in settings
                        Column {
                            width: outputList.width
                            visible: Audio.playbackStreams.length > 0
                            topPadding: root.sp3
                            bottomPadding: root.sp2
                            spacing: root.sp3

                            Divider {
                                width: parent.width
                            }

                            LText {
                                leftPadding: Theme.dp(6)
                                role: "titleSmall"
                                color: Theme.primary
                                text: "App volume"
                            }

                        }

                        Repeater {
                            model: Audio.playbackStreams

                            Column {
                                id: appVol

                                required property var modelData
                                readonly property int volume: Audio.volumeOf(appVol.modelData)
                                readonly property bool muted: Audio.mutedOf(appVol.modelData)

                                width: outputList.width
                                spacing: Theme.dp(2)
                                bottomPadding: root.sp1

                                LText {
                                    width: parent.width
                                    leftPadding: Theme.dp(6)
                                    role: "bodyMedium"
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    text: {
                                        const media = Audio.mediaLabel(appVol.modelData);
                                        return Audio.appLabel(appVol.modelData) + (media !== "" ? " · " + media : "");
                                    }
                                }

                                Slider {
                                    width: parent.width
                                    size: "m"
                                    icon: root.volumeIcon(appVol.volume, appVol.muted)
                                    iconClickable: true
                                    from: 0
                                    to: 100
                                    value: appVol.volume
                                    activeColor: appVol.muted ? Theme.outlineStrong : Theme.primary
                                    inactiveColor: Theme.withBlur(Theme.surfaceHighest)
                                    easeValue: root.expanded
                                    // a bubble over the handle runs off the panel's
                                    // edge near 100%, so the reading sits in the track
                                    showValue: false
                                    inlineValue: true
                                    valueText: (v) => {
                                        return Math.round(v) + "%";
                                    }
                                    onMoved: (v) => {
                                        return Audio.setVolume(appVol.modelData, v);
                                    }
                                    onIconClicked: Audio.toggleMute(appVol.modelData)
                                }

                            }

                        }

                    }

                    Column {
                        id: powerList

                        width: subScroll.width
                        visible: root.view === "power"
                        spacing: Theme.dp(2)

                        Repeater {
                            model: Power.actions

                            ListItem {
                                id: pw

                                required property var modelData
                                required property int index
                                readonly property bool armed: root.powerArmed === pw.modelData.id

                                width: powerList.width
                                first: pw.index === 0
                                last: pw.index === Power.actions.length - 1
                                containerColor: pw.armed ? Theme.errorContainer : Theme.withBlur(Theme.surfaceHigh)
                                icon: pw.modelData.icon
                                iconColor: pw.armed ? Theme.fgErrorContainer : Theme.subtext
                                headline: pw.armed ? "Click again to " + pw.modelData.label.toLowerCase() : pw.modelData.label
                                onClicked: root.powerPick(pw.modelData.id)
                            }

                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            const maxY = Math.max(0, subScroll.contentHeight - subScroll.height);
                            subScroll.contentY = Math.max(0, Math.min(maxY, subScroll.contentY - (wheel.angleDelta.y / 120) * 90));
                            wheel.accepted = true;
                        }
                    }

                }

            }

        }
    ]

    overlayOpen: tipCard.visible
    overlayItem: tipCard

    overlayContent: [
        Rectangle {
            id: tipCard

            readonly property int pad: Theme.dp(14)
            // measured off unconstrained metrics, since an eliding Text reports
            // its elided width and would pin the card at whatever it first got
            readonly property real natural: {
                let w = Math.max(tipOverlineText.implicitWidth, tipTitleMetrics.width + (root.tipViewKind === "volume" ? Theme.dp(36) : 0));
                if (tipSupportText.visible)
                    w = Math.max(w, tipSupportMetrics.width);

                return Math.ceil(w) + 2;
            }
            readonly property int floorW: root.tipViewKind === "volume" ? Theme.dp(240) : Theme.dp(132)

            width: Math.ceil(Math.min(Theme.dp(320), Math.max(tipCard.floorW, tipCard.natural + tipCard.pad * 2)))
            height: Math.round(tipCol.implicitHeight + tipCard.pad * 2 - Theme.dp(4))
            x: root.tipCardX
            y: root.compactHeight + root.tipGap
            radius: Theme.shapeLg
            color: Theme.bg
            opacity: root.tipShown ? 1 : 0
            visible: tipCard.opacity > 0.01

            // the only hover-enabled area in the card, so nothing can steal it
            MouseArea {
                id: tipCardArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.tipViewKind === "volume" ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: root.tipOverCard = true
                onExited: root.tipOverCard = false
                onPressed: (mouse) => {
                    if (root.tipViewKind !== "volume")
                        return ;

                    if (tipMute.hitBy(mouse.x, mouse.y)) {
                        root.toggleVolMute();
                        return ;
                    }
                    const sp = tipSlider.mapFromItem(tipCardArea, mouse.x, mouse.y);
                    if (sp.y < -10 || sp.y > tipSlider.height + 10)
                        return ;

                    root.tipDragging = true;
                    tipSlider.live = tipSlider.valueAt(sp.x);
                    root.tipSetVolume(tipSlider.live);
                }
                // the slider shows the pointer, not pipewire's echo of it, which lags
                onPositionChanged: (mouse) => {
                    if (!root.tipDragging)
                        return ;

                    tipSlider.live = tipSlider.valueAt(tipSlider.mapFromItem(tipCardArea, mouse.x, mouse.y).x);
                    root.tipSetVolume(tipSlider.live);
                }
                onReleased: root.tipDragging = false
                onCanceled: root.tipDragging = false
                onWheel: (wheel) => {
                    if (root.tipViewKind === "volume")
                        root.tipSetVolume(root.volumePercent + (wheel.angleDelta.y > 0 ? 5 : -5));

                    wheel.accepted = true;
                }
            }

            TextMetrics {
                id: tipTitleMetrics

                font: tipTitleText.font
                text: root.tipTitle
            }

            TextMetrics {
                id: tipSupportMetrics

                font: tipSupportText.font
                text: root.tipSupport
            }

            Column {
                id: tipCol

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: tipCard.pad
                anchors.topMargin: tipCard.pad - Theme.dp(2)
                width: tipCard.width - tipCard.pad * 2
                spacing: Theme.dp(2)

                LText {
                    id: tipOverlineText

                    role: "labelSmall"
                    color: Theme.primary
                    text: root.tipOverline
                    font.letterSpacing: 0.8
                }

                LText {
                    id: tipTitleText

                    width: tipCol.width - (root.tipViewKind === "volume" ? Theme.dp(36) : 0)
                    role: "titleMedium"
                    weight: 600
                    text: root.tipTitle
                    elide: Text.ElideRight
                }

                LText {
                    id: tipSupportText

                    width: tipCol.width
                    visible: text !== ""
                    role: "bodySmall"
                    color: Theme.subtext
                    text: root.tipSupport
                    elide: Text.ElideRight
                    bottomPadding: Theme.dp(2)
                }

                Slider {
                    id: tipSlider

                    visible: root.tipViewKind === "volume"
                    enabled: false
                    width: tipCol.width
                    height: Theme.dp(30)
                    from: 0
                    to: 100
                    value: root.volumePercent
                    showValue: false
                    activeColor: root.volMuted ? Theme.outlineStrong : Theme.primary
                    inactiveColor: Theme.surfaceHighest
                    // the card's own drag drives it directly, so only the rest is eased
                    easeValue: tipCard.visible && !root.tipDragging
                    held: root.tipDragging
                }

            }

            Rectangle {
                id: tipMute

                function hitBy(px, py) {
                    return px >= tipMute.x && px <= tipMute.x + tipMute.width && py >= tipMute.y && py <= tipMute.y + tipMute.height;
                }

                readonly property bool hovered: tipCardArea.containsMouse && tipMute.hitBy(tipCardArea.mouseX, tipCardArea.mouseY)

                visible: root.tipViewKind === "volume"
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: Theme.dp(10)
                anchors.topMargin: Theme.dp(10)
                width: Theme.dp(32)
                height: Theme.dp(32)
                radius: Theme.dp(16)
                color: root.volMuted ? Theme.errorContainer : (tipMute.hovered ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

                Icon {
                    anchors.centerIn: parent
                    name: root.volumeIcon(root.volumePercent, root.volMuted)
                    size: Theme.dp(18)
                    fill: 1
                    color: root.volMuted ? Theme.fgErrorContainer : Theme.subtext
                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.tipAnimMs
                    easing.type: root.tipAnimEase
                }

            }

        }
    ]

}
