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

        // filled before the view flips, so its height is right from the first frame
        if (v === "tiles")
            root.syncTiles();

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

        if (root.view === "tiles")
            return tileEditor.implicitHeight + root.viewChrome;

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
    panelWidth: Math.min(Theme.dp(400), root.screenW - Theme.dp(34))
    panelHeight: Math.min(root.maxPanelHeight, root.viewContentHeight)
    expandedRadius: Theme.shapeXl
    compactCollapseScale: 0.94
    surfaceLayered: true

    Component.onCompleted: {
        findDeviceProc.running = true;
        root.refreshGameMode();
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
        const t = Prefs.systemTileAt(key);
        return t ? t.name : "";
    }

    function tileChecked(key) {
        switch (key) {
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
        return false;
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
        const cmd = root.tileCommands[key];
        if (cmd) {
            root.expanded = false;
            Quickshell.execDetached(["sh", "-c", "sleep 0.3; " + cmd]);
            return ;
        }
        switch (key) {
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

    // the grid both views share
    readonly property int tileCols: 6
    readonly property real tileW: (root.contentWidth - root.sp2 * (root.tileCols - 1)) / root.tileCols
    readonly property real tileH: root.tileW + Theme.dp(20)
    readonly property real tileStepX: root.tileW + root.sp2
    readonly property real tileStepY: root.tileH + root.sp3
    // how far a lifted tile stays off the editor's edges: its 1.1 lift and its
    // label both reach past its box, and the scroll area clips at the edge
    readonly property int tileDragPad: Theme.dp(6)

    function tileGridHeight(n) {
        const rows = Math.max(1, Math.ceil(n / root.tileCols));
        return rows * root.tileH + (rows - 1) * root.sp3;
    }

    // the editor works on its own copy, so a drag can reorder it live without
    // the repeater rebuilding the tile under the pointer
    ListModel {
        id: tileModel
    }

    ListModel {
        id: spareModel
    }

    // pops in whichever tile has just crossed between the two lists
    property string tileArrival: ""
    property string tileDeparture: ""
    property bool tileDragging: false
    property bool tileOverSpare: false

    function modelKeys(m) {
        const out = [];
        for (let i = 0; i < m.count; i++) out.push(m.get(i).key)
        return out;
    }

    function syncTiles() {
        if (root.tileDragging)
            return ;

        const keys = Prefs.systemTileKeys;
        const spare = Prefs.systemTileSpare;
        if (root.modelKeys(tileModel).join(",") === keys.join(",") && root.modelKeys(spareModel).join(",") === spare.join(","))
            return ;

        root.tileArrival = "";
        root.tileDeparture = "";
        tileModel.clear();
        for (const k of keys) tileModel.append({
            "key": k
        })
        spareModel.clear();
        for (const k of spare) spareModel.append({
            "key": k
        })
    }

    Connections {
        function onSystemTilesChanged() {
            root.syncTiles();
        }

        target: Prefs
    }

    function tileCommit() {
        Prefs.setSystemTiles(root.modelKeys(tileModel));
    }

    function tileAdd(key) {
        const i = root.modelKeys(spareModel).indexOf(key);
        if (i < 0)
            return ;

        root.tileArrival = key;
        spareModel.remove(i);
        tileModel.append({
            "key": key
        });
        root.tileCommit();
    }

    function tileRemove(key) {
        const i = root.modelKeys(tileModel).indexOf(key);
        if (i < 0)
            return ;

        root.tileDeparture = key;
        tileModel.remove(i);
        // back to its catalogue place among the spares
        const spare = root.modelKeys(spareModel);
        const order = Prefs.systemTileCatalog.map((t) => {
            return t.key;
        }).filter((k) => {
            return k === key || spare.indexOf(k) >= 0;
        });
        spareModel.insert(order.indexOf(key), {
            "key": key
        });
        root.tileCommit();
    }

    // the dragged tile takes whichever cell its centre is over, so the rest
    // part around it as it goes; below the grid it is on its way out
    function tileAim(slot, face) {
        const p = face.mapToItem(tileBoard, face.width / 2, face.height / 2);
        root.tileOverSpare = p.y > tileBoard.height + root.sp3;
        if (root.tileOverSpare)
            return ;

        const col = Math.max(0, Math.min(root.tileCols - 1, Math.floor(p.x / root.tileStepX)));
        const row = Math.max(0, Math.floor(p.y / root.tileStepY));
        const to = Math.min(tileModel.count - 1, row * root.tileCols + col);
        if (to !== slot.index)
            tileModel.move(slot.index, to, 1);

    }

    function tileDrop(key) {
        const out = root.tileOverSpare;
        root.tileOverSpare = false;
        root.tileDragging = false;
        // removing destroys the very delegate whose release is running
        if (out)
            Qt.callLater(root.tileRemove, key);
        else
            root.tileCommit();
    }

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

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(2)

                        IconButton {
                            icon: "edit"
                            onClicked: root.showView("tiles")
                        }

                        IconButton {
                            icon: "settings"
                            onClicked: {
                                root.expanded = false;
                                Prefs.settingsRequested("");
                            }
                        }

                        IconButton {
                            icon: "lock"
                            onClicked: {
                                root.expanded = false;
                                Power.run("lock");
                            }
                        }

                        IconButton {
                            icon: "power_settings_new"
                            variant: "tonal"
                            onClicked: root.showView("power")
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

                    Column {
                        id: mainColumn

                        width: scrollArea.width
                        spacing: root.sp3

                        Column {
                            width: root.contentWidth
                            spacing: root.sp2

                            Slider {
                                visible: root.maxBrightness > 0
                                width: root.contentWidth
                                size: "m"
                                icon: root.brightnessIcon
                                from: 0
                                to: 100
                                value: root.brightnessPercent
                                inactiveColor: Theme.withBlur(Theme.surfaceHighest)
                                easeValue: root.expanded
                                valueText: (v) => {
                                    return Math.round(v) + "%";
                                }
                                onMoved: (v) => {
                                    return root.setBrightness(v);
                                }
                            }

                            Row {
                                width: root.contentWidth
                                spacing: root.sp2

                                Slider {
                                    width: root.contentWidth - outBtn.width - root.sp2
                                    size: "m"
                                    icon: root.volumeIcon(root.volumePercent, root.volMuted)
                                    iconClickable: true
                                    from: 0
                                    to: 100
                                    value: root.volumePercent
                                    activeColor: root.volMuted ? Theme.outlineStrong : Theme.primary
                                    inactiveColor: Theme.withBlur(Theme.surfaceHighest)
                                    easeValue: root.expanded
                                    valueText: (v) => {
                                        return Math.round(v) + "%";
                                    }
                                    onMoved: (v) => {
                                        if (root.sink && root.sink.audio && root.sink.audio.muted)
                                            root.sink.audio.muted = false;

                                        root.setVolume(v);
                                    }
                                    onIconClicked: root.toggleVolMute()
                                }

                                Rectangle {
                                    id: outBtn

                                    width: Theme.dp(50)
                                    height: Theme.dp(38)
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: Theme.rad(12)
                                    color: Theme.withBlur(Theme.surfaceHighest)

                                    StateLayer {
                                        radius: parent.radius
                                        onClicked: root.showView("output")
                                    }

                                    Icon {
                                        anchors.centerIn: parent
                                        name: "speaker"
                                        size: Theme.dp(20)
                                        color: Theme.subtext
                                    }

                                }

                            }

                        }

                        Row {
                            width: root.contentWidth
                            spacing: root.sp2

                            QuickTile {
                                icon: root.wifiGlyph
                                name: wifiPanel.primaryIsEthernet ? "Ethernet" : "Wi-Fi"
                                sub: wifiPanel.statusText
                                checked: Networking.wifiEnabled || wifiPanel.primaryIsEthernet
                                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                                onExpandRequested: root.showView("wifi")
                            }

                            QuickTile {
                                icon: root.btGlyph
                                name: "Bluetooth"
                                sub: btPanel.label
                                checked: root.btEnabled
                                onToggled: Bt.setEnabled(!root.btEnabled)
                                onExpandRequested: root.showView("bluetooth")
                            }

                        }

                        Grid {
                            visible: Prefs.systemTileKeys.length > 0
                            width: root.contentWidth
                            columns: root.tileCols
                            columnSpacing: root.sp2
                            rowSpacing: root.sp3

                            Repeater {
                                model: Prefs.systemTileKeys

                                SmallTile {
                                    required property string modelData

                                    icon: root.tileIcon(modelData)
                                    label: root.tileLabel(modelData)
                                    checked: root.tileChecked(modelData)
                                    hasMore: modelData === "profile" || modelData === "nightlight"
                                    onToggled: root.tileAct(modelData)
                                    onMore: root.showView(modelData)
                                }

                            }

                        }

                        Rectangle {
                            id: mediaCard

                            readonly property var mprisPlayer: root.mprisMod ? root.mprisMod.player : null
                            readonly property real progress: (root.mprisMod && root.mprisMod.lenSec > 0) ? Math.max(0, Math.min(1, root.mprisMod.livePosSec / root.mprisMod.lenSec)) : 0
                            readonly property bool playing: root.mprisMod ? root.mprisMod.isPlaying : false

                            visible: root.mprisMod && root.mprisMod.player
                            width: root.contentWidth
                            height: Theme.dp(84)
                            radius: Theme.shapeLgInc
                            color: Theme.withBlur(Theme.surfaceHigh)

                            StateLayer {
                                radius: parent.radius
                                onClicked: {
                                    root.expanded = false;
                                    if (root.mprisMod)
                                        root.mprisMod.expanded = true;

                                }
                            }

                            // ClippingRectangle: radius + clip alone leaves the image corners square
                            ClippingRectangle {
                                id: mediaArt

                                anchors.left: parent.left
                                anchors.leftMargin: Theme.dp(10)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.dp(64)
                                height: Theme.dp(64)
                                radius: Theme.shapeLg
                                color: Theme.withBlur(Theme.surfaceHighest)

                                Image {
                                    id: mediaArtImg

                                    anchors.fill: parent
                                    source: root.mprisMod ? root.mprisMod.artUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: Theme.dp(128)
                                    sourceSize.height: Theme.dp(128)
                                    visible: mediaArtImg.status === Image.Ready
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    visible: !mediaArtImg.visible
                                    name: "music_note"
                                    size: Theme.dp(26)
                                    color: Theme.subtext
                                }

                            }

                            Row {
                                id: mediaControls

                                anchors.right: parent.right
                                anchors.rightMargin: Theme.dp(10)
                                anchors.top: parent.top
                                anchors.topMargin: Theme.dp(12)
                                spacing: Theme.dp(2)

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: "skip_previous"
                                    iconFill: 1
                                    size: "xs"
                                    tintOverride: Theme.text
                                    onClicked: {
                                        if (mediaCard.mprisPlayer && mediaCard.mprisPlayer.canGoPrevious)
                                            mediaCard.mprisPlayer.previous();

                                    }
                                }

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: mediaCard.playing ? "pause" : "play_arrow"
                                    iconFill: 1
                                    variant: "filled"
                                    onClicked: {
                                        if (mediaCard.mprisPlayer && mediaCard.mprisPlayer.canTogglePlaying)
                                            mediaCard.mprisPlayer.togglePlaying();

                                    }
                                }

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: "skip_next"
                                    iconFill: 1
                                    size: "xs"
                                    tintOverride: Theme.text
                                    onClicked: {
                                        if (mediaCard.mprisPlayer && mediaCard.mprisPlayer.canGoNext)
                                            mediaCard.mprisPlayer.next();

                                    }
                                }

                            }

                            Column {
                                anchors.left: mediaArt.right
                                anchors.leftMargin: Theme.dp(12)
                                anchors.right: mediaControls.left
                                anchors.rightMargin: Theme.dp(8)
                                anchors.top: parent.top
                                anchors.topMargin: Theme.dp(14)
                                spacing: 1

                                LText {
                                    width: parent.width
                                    role: "titleSmall"
                                    text: root.mprisMod ? root.mprisMod.title : ""
                                    elide: Text.ElideRight
                                }

                                LText {
                                    width: parent.width
                                    visible: text !== ""
                                    role: "bodySmall"
                                    color: Theme.subtext
                                    text: root.mprisMod ? root.mprisMod.artist : ""
                                    elide: Text.ElideRight
                                }

                            }

                            LinearProgress {
                                anchors.left: mediaArt.right
                                anchors.leftMargin: Theme.dp(12)
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.dp(16)
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Theme.dp(14)
                                value: mediaCard.progress
                                wavy: true
                                animated: mediaCard.playing
                                valueAnimated: false
                                amplitude: 2.5
                                wavelength: Theme.dp(24)
                                trackColor: Theme.withBlur(Theme.surfaceHighest)
                            }

                        }

                        Rectangle {
                            id: statsCard

                            readonly property var selectedDiskInfo: {
                                for (const d of root.diskList) {
                                    if (d.name === root.selectedDisk)
                                        return d;

                                }
                                return root.diskList.length > 0 ? root.diskList[0] : null;
                            }
                            // fs overhead and the root reserve are neither used nor free, so measure against what df can hand out
                            readonly property real diskPct: (selectedDiskInfo && selectedDiskInfo.mounted && selectedDiskInfo.used + selectedDiskInfo.avail > 0) ? selectedDiskInfo.used / (selectedDiskInfo.used + selectedDiskInfo.avail) : 0

                            function cycleDisk() {
                                if (root.diskList.length < 2)
                                    return ;

                                var i = 0;
                                for (var k = 0; k < root.diskList.length; k++) {
                                    if (root.diskList[k].name === root.selectedDisk)
                                        i = k;

                                }
                                root.selectedDisk = root.diskList[(i + 1) % root.diskList.length].name;
                            }

                            width: root.contentWidth
                            height: gaugeRow.implicitHeight + Theme.dp(28)
                            radius: Theme.shapeLgInc
                            color: Theme.withBlur(Theme.surfaceHigh)

                            Row {
                                id: gaugeRow

                                anchors.centerIn: parent
                                width: parent.width - Theme.dp(16)

                                Gauge {
                                    width: gaugeRow.width / 4
                                    value: root.cpuPercent / 100
                                    center: root.cpuHistory.length > 0 ? Math.round(root.cpuPercent) + "" : "—"
                                    label: "CPU"
                                    detail: root.cpuTemp > 0 ? Math.round(root.cpuTemp) + " °C" : ""
                                    tone: root.cpuTemp >= 85 ? Theme.error : Theme.accent
                                }

                                Gauge {
                                    width: gaugeRow.width / 4
                                    value: root.ramPercent / 100
                                    center: root.ramHistory.length > 0 ? Math.round(root.ramPercent) + "" : "—"
                                    label: "Memory"
                                    detail: root.ramTotalGB > 0 ? root.ramUsedGB.toFixed(1) + " GB" : ""
                                    tone: Theme.accent
                                }

                                Gauge {
                                    width: gaugeRow.width / 4
                                    value: statsCard.diskPct
                                    center: statsCard.selectedDiskInfo && statsCard.selectedDiskInfo.mounted ? Math.round(statsCard.diskPct * 100) + "" : "—"
                                    label: root.selectedDisk || "Disk"
                                    detail: statsCard.selectedDiskInfo ? (statsCard.selectedDiskInfo.mounted ? Math.round(statsCard.selectedDiskInfo.avail / 1.07374e+09) + " GB free" : "not mounted") : ""
                                    tone: statsCard.diskPct * 100 > 100 - Prefs.storageLowPercent ? Theme.error : Theme.accent
                                    clickable: root.diskList.length > 1
                                    onClicked: statsCard.cycleDisk()
                                }

                                Gauge {
                                    width: gaugeRow.width / 4
                                    value: root.batteryPresent ? root.batteryPercent / 100 : 0
                                    center: root.batteryPresent ? root.batteryPercent + "" : "—"
                                    label: root.batteryCharging ? "Charging" : "Battery"
                                    detail: root.batteryDetail
                                    tone: root.batteryPercent <= 20 && !root.batteryCharging ? Theme.error : Theme.accent
                                    centerIcon: root.batteryCharging ? "bolt" : ""
                                }

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
                            case "tiles":
                                return "Edit tiles";
                            case "profile":
                                return "Power profile";
                            case "nightlight":
                                return "Night light";
                            }
                            return "";
                        }
                    }

                    Button {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.view === "tiles" && Prefs.isModified("systemTiles")
                        variant: "text"
                        size: "xs"
                        text: "Reset"
                        onClicked: Prefs.resetKeys(["systemTiles"])
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
                        case "tiles":
                            return tileEditor.implicitHeight;
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

                    Item {
                        id: tileEditor

                        width: subScroll.width
                        visible: root.view === "tiles"
                        implicitHeight: tileColumn.implicitHeight

                        Column {
                            id: tileColumn

                            width: parent.width
                            spacing: root.sp3

                            LText {
                                width: parent.width
                                role: "bodySmall"
                                color: Theme.subtext
                                text: "Drag to rearrange, or tap − to take a tile out"
                                wrapMode: Text.WordWrap
                            }

                            Item {
                                id: tileBoard

                                width: parent.width
                                height: root.tileGridHeight(tileModel.count)

                                LText {
                                    visible: tileModel.count === 0
                                    anchors.centerIn: parent
                                    role: "bodyMedium"
                                    color: Theme.subtext
                                    text: "The panel has no tiles"
                                }

                                Repeater {
                                    model: tileModel

                                    Item {
                                        id: slot

                                        required property string key
                                        required property int index
                                        readonly property var spec: Prefs.systemTileAt(slot.key)
                                        readonly property bool held: grab.drag.active

                                        x: (slot.index % root.tileCols) * root.tileStepX
                                        y: Math.floor(slot.index / root.tileCols) * root.tileStepY
                                        width: root.tileW
                                        height: root.tileH
                                        onHeldChanged: {
                                            if (slot.held)
                                                root.tileDragging = true;

                                        }
                                        Component.onCompleted: {
                                            if (root.tileArrival === slot.key) {
                                                face.enter = 0;
                                                slotPop.start();
                                            }
                                        }

                                        MouseArea {
                                            id: grab

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            preventStealing: true
                                            cursorShape: slot.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            drag.target: face
                                            // in the drag layer's space, since the face only moves once lifted into it
                                            drag.minimumX: root.tileDragPad
                                            drag.maximumX: tileDragLayer.width - face.width - root.tileDragPad
                                            drag.minimumY: root.tileDragPad
                                            drag.maximumY: tileDragLayer.height - face.height - root.tileDragPad
                                            onPositionChanged: {
                                                if (slot.held)
                                                    root.tileAim(slot, face);

                                            }
                                            onReleased: root.tileDrop(slot.key)
                                            onCanceled: root.tileDrop(slot.key)
                                        }

                                        EditTile {
                                            id: face

                                            icon: slot.spec ? slot.spec.icon : ""
                                            label: slot.spec ? slot.spec.name : ""
                                            held: slot.held
                                            hot: grab.containsMouse
                                            onBadgeClicked: root.tileRemove(slot.key)
                                            states: [
                                                State {
                                                    name: "held"
                                                    when: slot.held

                                                    // lifted out of the slot, so the slot can move on underneath it
                                                    ParentChange {
                                                        target: face
                                                        parent: tileDragLayer
                                                    }

                                                }
                                            ]
                                            transitions: [
                                                Transition {
                                                    from: "held"

                                                    ParentAnimation {
                                                        NumberAnimation {
                                                            properties: "x,y"
                                                            duration: Theme.durFastSpatial
                                                            easing.type: Easing.Bezier
                                                            easing.bezierCurve: Theme.curveStandard
                                                        }

                                                    }

                                                }
                                            ]
                                        }

                                        NumberAnimation {
                                            id: slotPop

                                            target: face
                                            property: "enter"
                                            to: 1
                                            duration: Theme.durFastSpatial
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.curveFastSpatial
                                        }

                                        Behavior on x {
                                            enabled: root.view === "tiles"

                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveStandard
                                            }

                                        }

                                        Behavior on y {
                                            enabled: root.view === "tiles"

                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveStandard
                                            }

                                        }

                                    }

                                }

                                Behavior on height {
                                    enabled: root.view === "tiles"

                                    NumberAnimation {
                                        duration: Theme.durFastSpatial
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.curveStandard
                                    }

                                }

                            }

                            Divider {
                                width: parent.width
                            }

                            LText {
                                role: "titleSmall"
                                color: root.tileOverSpare ? Theme.text : Theme.subtext
                                text: root.tileOverSpare ? "Release to take it out" : "Tap to add"
                            }

                            Item {
                                id: spareBoard

                                width: parent.width
                                height: spareModel.count > 0 ? root.tileGridHeight(spareModel.count) : spareEmpty.implicitHeight

                                // the drop target for a tile on its way out
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -root.sp2
                                    radius: Theme.shapeLg
                                    color: Theme.text
                                    opacity: root.tileOverSpare ? Theme.stateHover : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.durFastEffects
                                        }

                                    }

                                }

                                LText {
                                    id: spareEmpty

                                    visible: spareModel.count === 0
                                    width: parent.width
                                    role: "bodyMedium"
                                    color: Theme.subtext
                                    text: "Every tile is already in the panel"
                                }

                                Repeater {
                                    model: spareModel

                                    EditTile {
                                        id: spare

                                        required property string key
                                        required property int index
                                        readonly property var spec: Prefs.systemTileAt(spare.key)

                                        x: (spare.index % root.tileCols) * root.tileStepX
                                        y: Math.floor(spare.index / root.tileCols) * root.tileStepY
                                        icon: spare.spec ? spare.spec.icon : ""
                                        label: spare.spec ? spare.spec.name : ""
                                        adding: true
                                        onBadgeClicked: root.tileAdd(spare.key)
                                        Component.onCompleted: {
                                            if (root.tileDeparture === spare.key) {
                                                spare.enter = 0;
                                                sparePop.start();
                                            }
                                        }

                                        NumberAnimation {
                                            id: sparePop

                                            target: spare
                                            property: "enter"
                                            to: 1
                                            duration: Theme.durFastSpatial
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.curveFastSpatial
                                        }

                                        Behavior on x {
                                            enabled: root.view === "tiles"

                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveStandard
                                            }

                                        }

                                        Behavior on y {
                                            enabled: root.view === "tiles"

                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveStandard
                                            }

                                        }

                                    }

                                }

                                Behavior on height {
                                    enabled: root.view === "tiles"

                                    NumberAnimation {
                                        duration: Theme.durFastSpatial
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.curveStandard
                                    }

                                }

                            }

                        }

                        // a dragged tile rides above both lists
                        Item {
                            id: tileDragLayer

                            anchors.fill: parent
                            z: 10
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

    // a big tile: the icon side toggles, the label side opens the detail view.
    // the pill squares off once the tile is on
    component QuickTile: Rectangle {
        id: tile

        property string icon: ""
        property string name: ""
        property string sub: ""
        property bool checked: false

        signal toggled()
        signal expandRequested()

        width: (root.contentWidth - root.sp2) / 2
        height: Theme.dp(64)
        radius: tile.checked ? Theme.shapeLgInc : height / 2
        color: tile.checked ? Theme.primary : Theme.withBlur(Theme.surfaceHighest)

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

        StateLayer {
            radius: tile.radius
            tint: tile.checked ? Theme.fgPrimary : Theme.text
            onClicked: tile.expandRequested()
        }

        Rectangle {
            id: bubble

            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(44)
            height: Theme.dp(44)
            radius: Theme.dp(22)
            color: tile.checked ? Theme.alpha(Theme.fgPrimary, 0.14) : Theme.alpha(Theme.text, 0.08)

            StateLayer {
                radius: Theme.dp(22)
                tint: tile.checked ? Theme.fgPrimary : Theme.text
                onClicked: tile.toggled()
            }

            Icon {
                anchors.centerIn: parent
                name: tile.icon
                size: Theme.dp(22)
                fill: tile.checked ? 1 : 0
                color: tile.checked ? Theme.fgPrimary : Theme.text
            }

        }

        Column {
            anchors.left: bubble.right
            anchors.leftMargin: Theme.dp(10)
            anchors.right: chevron.left
            anchors.rightMargin: Theme.dp(2)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            LText {
                width: parent.width
                role: "titleSmall"
                weight: 600
                text: tile.name
                color: tile.checked ? Theme.fgPrimary : Theme.text
                elide: Text.ElideRight
            }

            LText {
                width: parent.width
                visible: text !== ""
                role: "bodySmall"
                text: tile.sub
                color: tile.checked ? Theme.alpha(Theme.fgPrimary, 0.78) : Theme.subtext
                elide: Text.ElideRight
            }

        }

        Icon {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: Theme.dp(20)
            color: tile.checked ? Theme.fgPrimary : Theme.subtext
        }

    }

    // an icon-only tile with its name underneath
    component SmallTile: Item {
        id: st

        property string icon: ""
        property string label: ""
        property bool checked: false
        // a right click asks for more than the tap does
        property bool hasMore: false

        signal toggled()
        signal more()

        width: root.tileW
        height: root.tileH

        Rectangle {
            id: sq

            width: st.width
            height: st.width
            radius: st.checked ? Theme.shapeLg : width / 2
            color: st.checked ? Theme.primary : Theme.withBlur(Theme.surfaceHighest)

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

            StateLayer {
                radius: sq.radius
                tint: st.checked ? Theme.fgPrimary : Theme.text
                acceptedButtons: st.hasMore ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton)
                        st.more();
                    else
                        st.toggled();
                }
            }

            Icon {
                anchors.centerIn: parent
                name: st.icon
                size: Theme.dp(22)
                fill: st.checked ? 1 : 0
                color: st.checked ? Theme.fgPrimary : Theme.text
            }

        }

        LText {
            anchors.top: sq.bottom
            anchors.topMargin: Theme.dp(4)
            anchors.horizontalCenter: parent.horizontalCenter
            // the gutter is the label's too; past that it shrinks a little before it elides
            width: root.tileStepX
            horizontalAlignment: Text.AlignHCenter
            role: "labelSmall"
            color: st.checked ? Theme.text : Theme.subtext
            text: st.label
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Math.max(Theme.dp(8), size - Theme.dp(2))
            elide: Text.ElideRight
        }

    }

    // a tile as the editor shows it: flat, no state, and a badge saying what a
    // tap does. an active one is dragged by its slot, a spare one is tapped
    component EditTile: Item {
        id: et

        property string icon: ""
        property string label: ""
        property bool adding: false
        property bool held: false
        property bool hot: false
        // 0..1, run up when the tile has just arrived from the other list
        property real enter: 1
        property real lift: et.held ? 1.1 : 1

        signal badgeClicked()

        width: root.tileW
        height: root.tileH
        z: et.held ? 1 : 0
        opacity: Math.min(1, et.enter)
        scale: (0.6 + 0.4 * et.enter) * et.lift

        Behavior on lift {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Rectangle {
            id: esq

            width: et.width
            height: et.width
            radius: et.held ? Theme.shapeLg : width / 2
            color: et.held ? Theme.primary : Theme.withBlur(Theme.surfaceHighest)

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
                color: Theme.text
                opacity: et.hot && !et.held ? Theme.stateHover : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durFastEffects
                    }

                }

            }

            // a spare tile is one big add button
            StateLayer {
                visible: et.adding
                radius: esq.radius
                onClicked: et.badgeClicked()
            }

            Icon {
                anchors.centerIn: parent
                name: et.icon
                size: Theme.dp(22)
                fill: et.held ? 1 : 0
                color: et.held ? Theme.fgPrimary : (et.adding ? Theme.subtext : Theme.text)
            }

        }

        LText {
            anchors.top: esq.bottom
            anchors.topMargin: Theme.dp(4)
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.tileStepX
            horizontalAlignment: Text.AlignHCenter
            role: "labelSmall"
            color: et.adding ? Theme.subtext : Theme.text
            text: et.label
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Math.max(Theme.dp(8), size - Theme.dp(2))
            elide: Text.ElideRight
        }

        // sits on the circle's rim inside the cell, since the scroll area clips
        // anything past the last column. the hit area is wider than the badge
        Item {
            x: esq.width - Theme.dp(24)
            y: -Theme.dp(4)
            width: Theme.dp(28)
            height: Theme.dp(28)
            opacity: et.held ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFastEffects
                }

            }

            Rectangle {
                anchors.centerIn: parent
                width: Theme.dp(20)
                height: Theme.dp(20)
                radius: Theme.dp(10)
                color: Theme.inverseSurface

                Icon {
                    anchors.centerIn: parent
                    name: et.adding ? "add" : "remove"
                    size: Theme.dp(14)
                    color: Theme.fgInverseSurface
                }

            }

            StateLayer {
                visible: !et.adding
                radius: Theme.rad(14)
                onClicked: et.badgeClicked()
            }

        }

    }

    // a ring gauge with its reading in the middle
    component Gauge: Item {
        id: g

        property real value: 0
        property string center: ""
        property string centerIcon: ""
        property string label: ""
        property string detail: ""
        property color tone: Theme.accent
        property bool clickable: false

        signal clicked()

        implicitHeight: gcol.implicitHeight

        Column {
            id: gcol

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.dp(6)

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.dp(54)
                height: Theme.dp(54)

                CircularProgress {
                    anchors.fill: parent
                    value: g.value
                    thickness: Theme.dp(5)
                    color: g.tone
                    trackColor: Theme.withBlur(Theme.surfaceHighest)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 0

                    Icon {
                        visible: g.centerIcon !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        name: g.centerIcon
                        size: Theme.dp(13)
                        fill: 1
                        color: g.tone
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        weight: 680
                        rounded: 100
                        text: g.center
                    }

                }

                StateLayer {
                    visible: g.clickable
                    radius: Theme.dp(27)
                    onClicked: g.clicked()
                }

            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "labelMedium"
                    text: g.label
                    width: Math.min(implicitWidth, g.width - Theme.dp(4))
                    elide: Text.ElideRight
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: text !== ""
                    role: "bodySmall"
                    size: Theme.fs(11)
                    color: Theme.subtext
                    text: g.detail
                    width: Math.min(implicitWidth, g.width - Theme.dp(4))
                    elide: Text.ElideRight
                }

            }

        }

    }

}
