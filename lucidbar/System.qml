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

BarPill {
    id: root

    // wired from shell.qml
    property var mprisMod: null

    property string view: "main"
    readonly property bool inSubView: root.view !== "main"

    property bool viewSwitching: false

    // m3 easing, as authored in the spec
    readonly property var easeEmphasized: [0.2, 0, 0, 1, 1, 1]
    readonly property var easeEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeEmphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]

    // m3 spacing, on the 4dp grid
    readonly property int sp1: 4
    readonly property int sp2: 8
    readonly property int sp3: 12
    readonly property int sp4: 16
    readonly property int sp5: 20

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

    readonly property int horizontalPadding: 16
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    readonly property int maxPanelHeight: Math.min(820, Math.max(200, root.screenH - 40))
    readonly property int panelPad: root.sp4
    readonly property int contentWidth: root.panelWidth - root.panelPad * 2
    readonly property int headerHeight: 44
    readonly property int subHeaderHeight: 44
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
            return powerPanel.implicitHeight + root.viewChrome;

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

    // material icons, 24dp, official path data
    readonly property var brightnessIconLevels: [
        { "max": 33, "path": "M20 15.31L23.31 12 20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69zM12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6 6 2.69 6 6-2.69 6-6 6z" },
        { "max": 66, "path": "M20 15.31L23.31 12 20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69zM12 18V6c3.31 0 6 2.69 6 6s-2.69 6-6 6z" },
        { "max": 100, "path": "M20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69L23.31 12 20 8.69zM12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6 6 2.69 6 6-2.69 6-6 6zm0-10c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4z" }
    ]
    // level 0 is the slash-free glyph: the mute overlay draws its own slash
    readonly property var volumeIconLevels: [
        { "max": 0, "path": "M7 9v6h4l5 5V4l-5 5H7z" },
        { "max": 49, "path": "M18.5 12c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM5 9v6h4l5 5V4L9 9H5z" },
        { "max": 100, "path": "M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" }
    ]

    readonly property string micIconPath: "M12 14c1.66 0 2.99-1.34 2.99-3L15 5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7z"
    readonly property string btIconPath: "M17.71 7.71L12 2h-1v7.59L6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 11 14.41V22h1l5.71-5.71-4.3-4.29 4.3-4.29zM13 5.83l1.88 1.88L13 9.59V5.83zm1.88 10.46L13 18.17v-3.76l1.88 1.88z"
    readonly property string chevronPath: "M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"
    readonly property string chevronLeftPath: "M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"
    readonly property string checkPath: "M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"
    readonly property string expandPath: "M16.59 8.59L12 13.17 7.41 8.59 6 10l6 6 6-6z"
    readonly property string speakerPath: "M17 2H7c-1.1 0-2 .9-2 2v16c0 1.1.9 1.99 2 1.99L17 22c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 2c1.1 0 2 .9 2 2s-.9 2-2 2c-1.11 0-2-.9-2-2s.89-2 2-2zm0 16c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"
    readonly property string settingsPath: "M19.14,12.94c0.04-0.3,0.06-0.61,0.06-0.94c0-0.32-0.02-0.64-0.07-0.94l2.03-1.58c0.18-0.14,0.23-0.41,0.12-0.61 l-1.92-3.32c-0.12-0.22-0.37-0.29-0.59-0.22l-2.39,0.96c-0.5-0.38-1.03-0.7-1.62-0.94L14.4,2.81c-0.04-0.24-0.24-0.41-0.48-0.41 h-3.84c-0.24,0-0.43,0.17-0.47,0.41L9.25,5.35C8.66,5.59,8.12,5.92,7.63,6.29L5.24,5.33c-0.22-0.08-0.47,0-0.59,0.22L2.74,8.87 C2.62,9.08,2.66,9.34,2.86,9.48l2.03,1.58C4.84,11.36,4.8,11.69,4.8,12s0.02,0.64,0.07,0.94l-2.03,1.58 c-0.18,0.14-0.23,0.41-0.12,0.61l1.92,3.32c0.12,0.22,0.37,0.29,0.59,0.22l2.39-0.96c0.5,0.38,1.03,0.7,1.62,0.94l0.36,2.54 c0.05,0.24,0.24,0.41,0.48,0.41h3.84c0.24,0,0.44-0.17,0.47-0.41l0.36-2.54c0.59-0.24,1.13-0.56,1.62-0.94l2.39,0.96 c0.22,0.08,0.47,0,0.59-0.22l1.92-3.32c0.12-0.22,0.07-0.47-0.12-0.61L19.14,12.94z M12,15.6c-1.98,0-3.6-1.62-3.6-3.6 s1.62-3.6,3.6-3.6s3.6,1.62,3.6,3.6S13.98,15.6,12,15.6z"
    readonly property string prevPath: "M6 6h2v12H6zm3.5 6l8.5 6V6z"
    readonly property string nextPath: "M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"
    readonly property string playPath: "M8 5v14l11-7z"
    readonly property string pausePath: "M6 19h4V5H6v14zm8-14v14h4V5h-4z"
    readonly property string notePath: "M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"

    function volumeIconFor(pct) {
        for (var i = 0; i < root.volumeIconLevels.length; i++) {
            if (pct <= root.volumeIconLevels[i].max)
                return root.volumeIconLevels[i].path;
        }
        return root.volumeIconLevels[root.volumeIconLevels.length - 1].path;
    }

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
    readonly property int tipGap: 6
    // grows each icon's slab a little; the row spacing is 8, so gaps stay dead
    readonly property int tipSlabPad: 2
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

    shown: Prefs.showSystem

    compactWidth: content.implicitWidth + root.horizontalPadding * 2
    panelWidth: Math.min(400, root.screenW - 34)
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
    onCompactClicked: root.view = "main"
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

        command: ["lsblk", "-b", "-J", "-o", "NAME,KNAME,PATH,SIZE,TYPE"]

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
                            "size": parseInt(dev.size),
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

        command: ["df", "-B1", "--output=source,used"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").slice(1);
                const disks = root._lsblkDisks.map((d) => {
                    return ({
                        "name": d.name,
                        "size": d.size,
                        "used": 0,
                        "mounted": false
                    });
                });
                // btrfs subvolumes and bind mounts repeat the same source
                const seen = {};
                for (const line of lines) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 2)
                        continue;

                    const source = parts[0];
                    const used = parseInt(parts[1]);
                    if (!source.startsWith("/dev/") || isNaN(used) || seen[source])
                        continue;

                    seen[source] = true;
                    for (let i = 0; i < disks.length; i++) {
                        if (root._lsblkDisks[i].paths.includes(source)) {
                            disks[i].used += used;
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
    readonly property bool gameModeConfigured: Prefs.gameModeOnCmd.trim() !== "" && Prefs.gameModeOffCmd.trim() !== ""

    function setGameMode(on) {
        if (!root.gameModeConfigured || root.gameModeBusy)
            return ;

        root.gameModeFailed = false;
        root.gameModeBusy = true;
        root.gameModeOn = on;
        gameModeProc.command = ["bash", "-c", on ? Prefs.gameModeOnCmd : Prefs.gameModeOffCmd];
        gameModeProc.running = true;
    }

    function refreshGameMode() {
        if (Prefs.gameModeStatusCmd.trim() === "" || root.gameModeBusy || gameModeStatusProc.running)
            return ;

        gameModeStatusProc.command = ["bash", "-c", Prefs.gameModeStatusCmd];
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

    compactContent: [
        Row {
            id: content

            anchors.centerIn: parent
            spacing: 8

            // click cycles to the next layout; the pill's own click still
            // opens the panel everywhere else
            Rectangle {
                id: kbIndicator

                visible: Prefs.showKbLayout && root.kbLayout !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: kbText.implicitWidth + 10
                height: 18
                radius: 9
                color: kbArea.containsMouse ? Theme.alpha(Theme.text, 0.1) : "transparent"

                Text {
                    id: kbText

                    anchors.centerIn: parent
                    text: root.kbLayout
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(11)
                }

                MouseArea {
                    id: kbArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: kbSwitchProc.running = true
                }

            }

            Item {
                id: wifiIcon

                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    visible: !wifiPanel.primaryIsEthernet
                    text: {
                        const glyphs = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
                        if (!Networking.wifiEnabled)
                            return "󰤮";

                        const s = wifiPanel.signalStrength;
                        return wifiPanel.wifiConnected ? glyphs[Math.max(0, Math.min(4, Math.floor(s / 20)))] : glyphs[0];
                    }
                    color: wifiPanel.wifiConnected ? Theme.accent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(15)
                }

                Item {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    visible: wifiPanel.primaryIsEthernet

                    Rectangle {
                        width: 10
                        height: 7
                        radius: 2
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 2
                        color: Theme.accent
                    }

                    Row {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        Rectangle {
                            width: 2
                            height: 5
                            color: Theme.accent
                        }

                        Rectangle {
                            width: 2
                            height: 5
                            color: Theme.accent
                        }

                    }

                }

            }

            SvgIcon {
                id: btIcon

                visible: root.btEnabled
                anchors.verticalCenter: parent.verticalCenter
                path: root.btIconPath
                tint: btPanel.connectedDevices.length > 0 ? Theme.accent : Theme.subtext
                iconSize: 15
            }

            StatusIndicator {
                id: volIndicator

                svgPath: root.volumeIconFor(root.volumePercent)
                labelText: root.volMuted ? "Muted" : root.volumePercent
                isMuted: root.volMuted
            }

            StatusIndicator {
                id: micIndicator

                svgPath: root.micIconPath
                labelText: root.micMuted ? "Off" : "On"
                isMuted: root.micMuted
            }

            Row {
                id: batteryRow

                readonly property color battColor: root.batteryCharging ? Theme.accent : (root.batteryPercent <= 20 ? Theme.error : Theme.subtext)

                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                visible: root.batteryPresent

                Item {
                    id: batteryIcon

                    width: 24
                    height: 15
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: body

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 15
                        radius: 5
                        color: "transparent"
                        border.width: 1.5
                        border.color: batteryRow.battColor

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 1
                            width: Math.max(0, (parent.width - 2) * (root.batteryPercent / 100))
                            radius: 2
                            color: batteryRow.battColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(200)
                                }

                            }

                        }

                        Shape {
                            visible: root.batteryCharging
                            anchors.centerIn: parent
                            width: 24
                            height: 25
                            scale: 12 / 24
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: Theme.bgOpaque
                                strokeWidth: 0

                                PathSvg {
                                    path: "M11 21h-1l1-7H7.5c-.88 0-.33-.75-.31-.78C8.48 10.94 10.42 7.54 13.01 3h1l-1 7h3.51c.4 0 .62.19.4.66C12.97 17.55 11 21 11 21z"
                                }

                            }

                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.barMs(200)
                            }

                        }

                    }

                    Rectangle {
                        anchors.left: body.right
                        anchors.leftMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 7
                        radius: 1
                        color: batteryRow.battColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(200)
                            }

                        }

                    }

                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryPercent + "%"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fontLabelLg
                }

            }

        },
        MouseArea {
            id: tipHover

            anchors.fill: parent
            enabled: root.shown && !root.anyOpen
            hoverEnabled: true
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
                    anchors.leftMargin: root.panelPad
                    anchors.rightMargin: root.panelPad
                    height: root.headerHeight

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Control Centre"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontTitleSm
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.sp2

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.uptimeText !== ""
                            text: root.uptimeText
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelSm
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            path: root.settingsPath
                            tint: Theme.subtext
                            diameter: 30
                            iconSize: 17
                            onTapped: {
                                root.expanded = false;
                                Prefs.settingsRequested("");
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

                    Column {
                        id: mainColumn

                        width: scrollArea.width
                        spacing: root.sp5

                        Grid {
                            width: root.contentWidth
                            columns: 2
                            columnSpacing: root.sp2
                            rowSpacing: root.sp2

                            ToggleTile {
                                iconGlyph: "󰤯"
                                name: "Wi-Fi"
                                sub: wifiPanel.statusText
                                checked: Networking.wifiEnabled
                                showArrow: true
                                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                                onExpandRequested: root.showView("wifi")
                            }

                            ToggleTile {
                                iconPath: root.btIconPath
                                name: "Bluetooth"
                                sub: btPanel.label
                                checked: root.btEnabled
                                showArrow: true
                                onToggled: Bt.setEnabled(!root.btEnabled)
                                onExpandRequested: root.showView("bluetooth")
                            }

                            ToggleTile {
                                iconPath: "M22,16v-2l-8.5-5V3.5C13.5,2.67,12.83,2,12,2s-1.5,0.67-1.5,1.5V9L2,14v2l8.5-2.5V19L8,20.5L8,22l4-1l4,1l0-1.5L13.5,19 v-5.5L22,16z"
                                name: "Airplane"
                                sub: root.airplaneMode ? "Radios off" : "Off"
                                checked: root.airplaneMode
                                onToggled: root.toggleAirplane()
                            }

                            ToggleTile {
                                iconPath: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 11H7v-2h10v2z"
                                name: "Do Not Disturb"
                                sub: root.dndOn ? "Silenced" : "Off"
                                checked: root.dndOn
                                onToggled: Notifs.toggleDnd()
                            }

                            ToggleTile {
                                iconPath: "M20 3H4v10c0 2.21 1.79 4 4 4h6c2.21 0 4-1.79 4-4v-3h2c1.11 0 2-.9 2-2V5c0-1.11-.89-2-2-2zm0 5h-2V5h2v3zM4 19h16v2H4z"
                                name: "Caffeine"
                                sub: Prefs.idleKeepAwake ? "Staying awake" : "Idle allowed"
                                checked: Prefs.idleKeepAwake
                                onToggled: Prefs.idleKeepAwake = !Prefs.idleKeepAwake
                            }

                            ToggleTile {
                                iconPath: "M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"
                                name: "Location"
                                sub: {
                                    if (!Prefs.gpsEnabled)
                                        return "Off";

                                    if (Loc.busy)
                                        return "Locating…";

                                    return Loc.place !== "" ? Loc.place : "No fix yet";
                                }
                                checked: Prefs.gpsEnabled
                                onToggled: {
                                    Prefs.gpsEnabled = !Prefs.gpsEnabled;
                                    if (Prefs.gpsEnabled)
                                        Loc.detect();

                                }
                            }

                            ToggleTile {
                                iconPath: "M21.58 16.09l-1.09-7.66A3.996 3.996 0 0 0 16.53 5H7.47C5.48 5 3.79 6.46 3.51 8.43l-1.09 7.66A2.545 2.545 0 0 0 4.94 19c.68 0 1.32-.27 1.8-.75L9 16h6l2.25 2.25c.48.48 1.13.75 1.8.75 1.56 0 2.75-1.37 2.53-2.91ZM11 11H9v2H8v-2H6v-1h2V8h1v2h2v1Zm4-1c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1Zm2 3c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1Z"
                                name: "Game Mode"
                                sub: {
                                    if (!root.gameModeConfigured)
                                        return "Set up in Settings";

                                    if (root.gameModeBusy)
                                        return root.gameModeOn ? "Turning on…" : "Turning off…";

                                    if (root.gameModeFailed)
                                        return "Command failed";

                                    return root.gameModeOn ? "On" : "Off";
                                }
                                checked: root.gameModeOn
                                onToggled: {
                                    if (!root.gameModeConfigured) {
                                        root.expanded = false;
                                        Prefs.settingsRequested("bar");
                                    } else {
                                        root.setGameMode(!root.gameModeOn);
                                    }
                                }
                            }

                            // a click steps to the next profile, the arrow lists them all
                            ToggleTile {
                                iconPath: Power.icon(Power.profile)
                                name: "Power"
                                sub: Power.name(Power.profile) + ((Power.degradation !== "" && Power.profile === PowerProfile.Performance) ? " · held back" : "")
                                checked: Power.profile !== PowerProfile.Balanced
                                showArrow: true
                                onToggled: Power.cycle()
                                onExpandRequested: root.showView("power")
                            }

                        }

                        Column {
                            width: root.contentWidth
                            spacing: root.sp2

                            Overline {
                                text: "SOUND & DISPLAY"
                            }

                            GroupCard {
                                width: root.contentWidth

                                SliderRow {
                                    width: parent.width
                                    iconLevels: root.brightnessIconLevels
                                    value: root.brightnessPercent
                                    onMoved: (v) => {
                                        return root.setBrightness(v);
                                    }
                                }

                                SliderRow {
                                    width: parent.width
                                    iconLevels: root.volumeIconLevels
                                    value: root.volumePercent
                                    muted: root.volMuted
                                    showMute: true
                                    showPicker: true
                                    onMoved: (v) => {
                                        return root.setVolume(v);
                                    }
                                    onMuteToggled: root.toggleVolMute()
                                    onPickerRequested: root.showView("output")
                                }

                            }

                        }

                        Column {
                            width: root.contentWidth
                            spacing: root.sp2
                            visible: root.mprisMod && root.mprisMod.player

                            Overline {
                                text: "NOW PLAYING"
                            }

                            Rectangle {
                                id: mediaCard

                                readonly property var mprisPlayer: root.mprisMod ? root.mprisMod.player : null
                                readonly property real progress: (root.mprisMod && root.mprisMod.lenSec > 0) ? Math.max(0, Math.min(1, root.mprisMod.posSec / root.mprisMod.lenSec)) : 0

                                width: root.contentWidth
                                height: 72
                                radius: Theme.shapeLg
                                color: Theme.withBlur(Theme.bgTile)

                                StateLayer {
                                    hovered: mediaArea.containsMouse
                                    pressed: mediaArea.pressed
                                }

                                MouseArea {
                                    id: mediaArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.expanded = false;
                                        if (root.mprisMod)
                                            root.mprisMod.expanded = true;

                                    }
                                }

                                // ClippingRectangle: radius + clip alone leaves
                                // the image corners square
                                ClippingRectangle {
                                    id: mediaArt

                                    anchors.left: parent.left
                                    anchors.leftMargin: root.sp3
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 48
                                    height: 48
                                    radius: Theme.shapeMd
                                    color: Theme.withBlur(Theme.bgActive)

                                    Image {
                                        id: mediaArtImg

                                        anchors.fill: parent
                                        source: root.mprisMod ? root.mprisMod.artUrl : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 128
                                        sourceSize.height: 128
                                        visible: mediaArtImg.status === Image.Ready
                                    }

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        visible: !mediaArtImg.visible
                                        path: root.notePath
                                        tint: Theme.subtext
                                        iconSize: 20
                                    }

                                }

                                Item {
                                    anchors.left: mediaArt.right
                                    anchors.leftMargin: root.sp3
                                    anchors.right: parent.right
                                    anchors.rightMargin: root.sp3
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 48

                                    Row {
                                        id: mediaControls

                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        spacing: 2

                                        IconButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            path: root.prevPath
                                            tint: Theme.text
                                            diameter: 28
                                            iconSize: 17
                                            onTapped: {
                                                if (mediaCard.mprisPlayer && mediaCard.mprisPlayer.canGoPrevious)
                                                    mediaCard.mprisPlayer.previous();

                                            }
                                        }

                                        IconButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            path: (root.mprisMod && root.mprisMod.isPlaying) ? root.pausePath : root.playPath
                                            tint: Theme.fgAccent
                                            bg: Theme.accent
                                            layerTint: Theme.fgAccent
                                            diameter: 30
                                            iconSize: 18
                                            onTapped: {
                                                if (mediaCard.mprisPlayer && mediaCard.mprisPlayer.canTogglePlaying)
                                                    mediaCard.mprisPlayer.togglePlaying();

                                            }
                                        }

                                        IconButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            path: root.nextPath
                                            tint: Theme.text
                                            diameter: 28
                                            iconSize: 17
                                            onTapped: {
                                                if (mediaCard.mprisPlayer && mediaCard.mprisPlayer.canGoNext)
                                                    mediaCard.mprisPlayer.next();

                                            }
                                        }

                                    }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.right: mediaControls.left
                                        anchors.rightMargin: root.sp2
                                        anchors.top: parent.top
                                        anchors.topMargin: 3
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: root.mprisMod ? root.mprisMod.title : ""
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.bold: true
                                            font.pixelSize: Theme.fontLabelLg
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            visible: text !== ""
                                            text: root.mprisMod ? root.mprisMod.artist : ""
                                            color: Theme.subtext
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontLabelSm
                                            elide: Text.ElideRight
                                        }

                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 2
                                        height: 3
                                        radius: Theme.shapeFull
                                        color: Theme.withBlur(Theme.bgHigh)

                                        Rectangle {
                                            width: parent.width * mediaCard.progress
                                            height: parent.height
                                            radius: Theme.shapeFull
                                            color: Theme.accent
                                        }

                                    }

                                }

                            }

                        }

                        Column {
                            width: root.contentWidth
                            spacing: root.sp2

                            Overline {
                                text: "SYSTEM"
                            }

                            Row {
                                width: parent.width
                                spacing: root.sp2

                                StatCard {
                                    width: (root.contentWidth - root.sp2 * 2) / 3
                                    label: "CPU"
                                    valueText: root.cpuHistory.length > 0 ? Math.round(root.cpuPercent) + "%" : "—"
                                    detailText: root.cpuTemp > 0 ? Math.round(root.cpuTemp) + " °C" : ""
                                    showChart: true
                                    chartHistory: root.cpuHistory
                                }

                                StatCard {
                                    width: (root.contentWidth - root.sp2 * 2) / 3
                                    label: "RAM"
                                    valueText: root.ramHistory.length > 0 ? Math.round(root.ramPercent) + "%" : "—"
                                    detailText: root.ramTotalGB > 0 ? root.ramUsedGB.toFixed(1) + " / " + Math.round(root.ramTotalGB) + " GB" : ""
                                    showChart: true
                                    chartHistory: root.ramHistory
                                }

                                StatCard {
                                    width: (root.contentWidth - root.sp2 * 2) / 3
                                    label: "BATTERY"
                                    valueText: root.batteryPresent ? root.batteryPercent + "%" : "N/A"
                                    detailText: root.batteryDetail
                                    showBar: root.batteryPresent
                                    barPct: root.batteryPercent
                                    barColor: root.batteryCharging ? Theme.accent : (root.batteryPercent <= 20 ? Theme.error : Theme.accent)
                                }

                            }

                            Rectangle {
                                id: diskCard

                                readonly property var selectedDiskInfo: {
                                    for (const d of root.diskList) {
                                        if (d.name === root.selectedDisk)
                                            return d;

                                    }
                                    return root.diskList.length > 0 ? root.diskList[0] : null;
                                }
                                readonly property real usedGB: selectedDiskInfo ? selectedDiskInfo.used / 1.07374e+09 : 0
                                readonly property real totalGB: selectedDiskInfo ? selectedDiskInfo.size / 1.07374e+09 : 0
                                readonly property real usedPct: (selectedDiskInfo && selectedDiskInfo.size > 0) ? (selectedDiskInfo.used / selectedDiskInfo.size * 100) : 0
                                readonly property bool unmounted: diskCard.selectedDiskInfo !== null && !diskCard.selectedDiskInfo.mounted

                                width: root.contentWidth
                                height: diskColumn.implicitHeight + root.sp3 * 2
                                radius: Theme.shapeMd
                                color: Theme.withBlur(Theme.bgTile)

                                Column {
                                    id: diskColumn

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: root.sp3
                                    spacing: root.sp1 + 2

                                    Item {
                                        width: parent.width
                                        height: 22

                                        Overline {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "DISK"
                                        }

                                        Rectangle {
                                            id: diskTrigger

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 22
                                            width: diskTriggerRow.implicitWidth + 18
                                            radius: Theme.shapeFull
                                            color: Theme.withBlur(Theme.bgHigh)
                                            visible: root.diskList.length > 0
                                            scale: diskTriggerArea.pressed ? 0.96 : 1

                                            Row {
                                                id: diskTriggerRow

                                                anchors.centerIn: parent
                                                spacing: 4

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.selectedDisk || "—"
                                                    color: Theme.text
                                                    font.family: Theme.fontFamily
                                                    font.bold: true
                                                    font.pixelSize: Theme.fontLabelSm
                                                }

                                                SvgIcon {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    path: root.expandPath
                                                    tint: Theme.subtext
                                                    iconSize: 11
                                                    rotation: root.diskDropdownOpen ? 180 : 0

                                                    Behavior on rotation {
                                                        NumberAnimation {
                                                            duration: Theme.barMs(180)
                                                            easing.type: Easing.Bezier
                                                            easing.bezierCurve: root.easeEmphasized
                                                        }

                                                    }

                                                }

                                            }

                                            StateLayer {
                                                hovered: diskTriggerArea.containsMouse
                                                pressed: diskTriggerArea.pressed
                                            }

                                            MouseArea {
                                                id: diskTriggerArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!root.diskDropdownOpen) {
                                                        const below = diskTrigger.mapToItem(mainView, 0, diskTrigger.height);
                                                        const above = diskTrigger.mapToItem(mainView, 0, 0);
                                                        diskPopup.x = below.x + diskTrigger.width - diskPopup.width;
                                                        // the disk card sits last, so below usually runs past the
                                                        // panel's clipped edge; flip up when it does
                                                        const fitsBelow = below.y + 6 + diskPopup.height <= root.panelHeight - root.sp2;
                                                        diskPopup.dropUp = !fitsBelow;
                                                        diskPopup.y = fitsBelow ? below.y + 6 : Math.max(root.sp2, above.y - diskPopup.height - 6);
                                                    }
                                                    root.diskDropdownOpen = !root.diskDropdownOpen;
                                                }
                                            }

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: Theme.barMs(90)
                                                    easing.type: Easing.OutQuad
                                                }

                                            }

                                        }

                                    }

                                    Text {
                                        width: parent.width
                                        text: {
                                            if (!diskCard.selectedDiskInfo)
                                                return "No disks found";

                                            if (diskCard.unmounted)
                                                return "Not mounted";

                                            return Math.round(diskCard.usedGB) + " / " + Math.round(diskCard.totalGB) + " GB";
                                        }
                                        color: diskCard.unmounted ? Theme.subtext : Theme.text
                                        font.family: Theme.fontFamily
                                        font.bold: true
                                        font.pixelSize: Theme.fontTitleMd
                                    }

                                    Meter {
                                        width: parent.width
                                        visible: diskCard.selectedDiskInfo !== null
                                        opacity: diskCard.unmounted ? 0.4 : 1
                                        pct: diskCard.usedPct
                                    }

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

                MouseArea {
                    anchors.fill: parent
                    visible: root.diskDropdownOpen
                    enabled: root.diskDropdownOpen
                    onClicked: root.diskDropdownOpen = false
                }

                // declared last so it paints on top
                Rectangle {
                    id: diskPopup

                    property bool dropUp: false

                    visible: opacity > 0.01
                    opacity: root.diskDropdownOpen ? 1 : 0
                    scale: root.diskDropdownOpen ? 1 : 0.94
                    transformOrigin: diskPopup.dropUp ? Item.Bottom : Item.Top
                    width: 150
                    height: diskPopupColumn.implicitHeight + root.sp1 * 2
                    radius: Theme.shapeMd
                    color: Theme.withBlur(Theme.bgActive)
                    z: 100

                    Column {
                        id: diskPopupColumn

                        anchors.fill: parent
                        anchors.margins: root.sp1
                        spacing: 2

                        Repeater {
                            model: root.diskList

                            Rectangle {
                                id: optRow

                                required property var modelData
                                readonly property bool isSelected: optRow.modelData.name === root.selectedDisk

                                width: parent.width
                                height: 30
                                radius: Theme.shapeSm
                                color: optRow.isSelected ? Theme.accent : "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: root.sp2 + 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: optRow.modelData.name
                                    color: optRow.isSelected ? Theme.fgAccent : Theme.text
                                    opacity: (!optRow.modelData.mounted && !optRow.isSelected) ? 0.45 : 1
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fontLabelMd
                                }

                                SvgIcon {
                                    visible: optRow.isSelected
                                    anchors.right: parent.right
                                    anchors.rightMargin: root.sp2
                                    anchors.verticalCenter: parent.verticalCenter
                                    path: root.checkPath
                                    tint: Theme.fgAccent
                                    iconSize: 13
                                }

                                StateLayer {
                                    hovered: optArea.containsMouse
                                    pressed: optArea.pressed
                                    tint: optRow.isSelected ? Theme.fgAccent : Theme.text
                                }

                                MouseArea {
                                    id: optArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedDisk = optRow.modelData.name;
                                        root.diskDropdownOpen = false;
                                    }
                                }

                            }

                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(180)
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.barMs(180)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: root.easeEmphasizedDecel
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
                    anchors.leftMargin: root.panelPad - 4
                    anchors.rightMargin: root.panelPad
                    height: root.subHeaderHeight

                    IconButton {
                        id: backChip

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        path: root.chevronLeftPath
                        tint: Theme.text
                        diameter: 32
                        iconSize: 18
                        onTapped: root.showView("main")
                    }

                    Text {
                        anchors.left: backChip.right
                        anchors.leftMargin: root.sp1
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            switch (root.view) {
                            case "wifi":
                                return "Network";
                            case "bluetooth":
                                return "Bluetooth";
                            case "output":
                                return "Output device";
                            case "power":
                                return "Power profile";
                            }
                            return "";
                        }
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontTitleSm
                    }

                    M3Switch {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.view === "bluetooth" || root.view === "wifi"
                        checked: root.view === "wifi" ? Networking.wifiEnabled : root.btEnabled
                        onToggled: {
                            if (root.view === "wifi")
                                Networking.wifiEnabled = !Networking.wifiEnabled;
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
                            return powerPanel.implicitHeight;
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
                    }

                    PowerPanel {
                        id: powerPanel

                        width: subScroll.width
                        visible: root.view === "power"
                        gameModeOn: root.gameModeOn
                    }

                    DeviceList {
                        id: outputList

                        width: subScroll.width
                        visible: root.view === "output"
                        nodes: root.outputNodes
                        current: root.sink
                        emptyText: "No output devices"
                        iconPath: root.speakerPath
                        availability: root.sinkAvailable
                        onPicked: (node) => {
                            Pipewire.preferredDefaultAudioSink = node;
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

            readonly property int pad: 14
            // measured off unconstrained metrics, since an eliding Text reports
            // its elided width and would pin the card at whatever it first got
            readonly property real natural: {
                let w = Math.max(tipOverlineText.implicitWidth, tipTitleMetrics.width + (root.tipViewKind === "volume" ? 32 : 0));
                if (tipSupportText.visible)
                    w = Math.max(w, tipSupportMetrics.width);

                // rounding the card width down by a fraction would elide the text
                return Math.ceil(w) + 2;
            }
            readonly property int floorW: root.tipViewKind === "volume" ? 232 : 128

            width: Math.ceil(Math.min(320, Math.max(tipCard.floorW, tipCard.natural + tipCard.pad * 2)))
            height: Math.round(tipCol.implicitHeight + tipCard.pad * 2 - 6)
            x: root.tipCardX
            y: root.compactHeight + root.tipGap
            radius: Theme.shapeMd
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
                    root.tipSetVolume(tipSlider.valueAt(sp.x));
                }
                onPositionChanged: (mouse) => {
                    if (!root.tipDragging)
                        return ;

                    root.tipSetVolume(tipSlider.valueAt(tipSlider.mapFromItem(tipCardArea, mouse.x, mouse.y).x));
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
                anchors.topMargin: tipCard.pad - 3
                width: tipCard.width - tipCard.pad * 2
                spacing: 3

                Text {
                    id: tipOverlineText

                    text: root.tipOverline
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fontLabelSm
                    font.letterSpacing: 0.8
                }

                Text {
                    id: tipTitleText

                    width: tipCol.width - (root.tipViewKind === "volume" ? 32 : 0)
                    text: root.tipTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fontTitleSm
                    elide: Text.ElideRight
                }

                Text {
                    id: tipSupportText

                    width: tipCol.width
                    visible: tipSupportText.text !== ""
                    text: root.tipSupport
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelSm
                    elide: Text.ElideRight
                    topPadding: 1
                }

                M3Slider {
                    id: tipSlider

                    visible: root.tipViewKind === "volume"
                    width: tipCol.width
                    value: root.volumePercent
                    muted: root.volMuted
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
                anchors.rightMargin: 9
                anchors.topMargin: 9
                width: 28
                height: 28
                radius: Theme.shapeFull
                color: "transparent"

                StateLayer {
                    hovered: tipMute.hovered
                    pressed: false
                }

                SvgIcon {
                    anchors.centerIn: parent
                    path: root.volMuted ? root.volumeIconLevels[0].path : root.volumeIconFor(root.volumePercent)
                    tint: root.volMuted ? Theme.error : Theme.subtext
                    iconSize: 16
                }

                Rectangle {
                    visible: root.volMuted
                    anchors.centerIn: parent
                    width: 18
                    height: 1.5
                    rotation: 45
                    color: Theme.error
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

    // m3 state layer: one hover/press idiom for every interactive surface here
    component StateLayer: Rectangle {
        id: layer

        property bool hovered: false
        property bool pressed: false
        property color tint: Theme.text

        anchors.fill: parent
        radius: parent.radius !== undefined ? parent.radius : 0
        color: layer.tint
        opacity: layer.pressed ? Theme.statePressed : (layer.hovered ? Theme.stateHover : 0)

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.barMs(150)
                easing.type: Easing.Bezier
                easing.bezierCurve: root.easeEmphasized
            }

        }

    }

    component Overline: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.bold: true
        font.pixelSize: Theme.fontLabelSm
        font.letterSpacing: 0.8
    }

    // flat grouped container, the same shape the settings app uses
    component GroupCard: Rectangle {
        id: group

        default property alias rows: groupColumn.data

        implicitHeight: groupColumn.implicitHeight + root.sp3 * 2
        height: implicitHeight
        radius: Theme.shapeLg
        color: Theme.withBlur(Theme.bgTile)

        Column {
            id: groupColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: root.sp3
            anchors.leftMargin: root.sp3
            anchors.rightMargin: root.sp3
            spacing: root.sp1
        }

    }

    component IconButton: Rectangle {
        id: btn

        property string path: ""
        property color tint: Theme.text
        property int diameter: 32
        property int iconSize: 18
        property color bg: "transparent"
        property color layerTint: Theme.text

        signal tapped()

        width: btn.diameter
        height: btn.diameter
        radius: Theme.shapeFull
        color: btn.bg

        StateLayer {
            hovered: btnArea.containsMouse
            pressed: btnArea.pressed
            tint: btn.layerTint
        }

        SvgIcon {
            anchors.centerIn: parent
            path: btn.path
            tint: btn.tint
            iconSize: btn.iconSize
        }

        MouseArea {
            id: btnArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.tapped()
        }

    }

    // m3 switch anatomy: the handle grows from 16 to 22 as it travels
    component M3Switch: Rectangle {
        id: sw

        property bool checked: false

        signal toggled()

        width: 44
        height: 26
        radius: Theme.shapeFull
        color: sw.checked ? Theme.accent : Theme.withBlur(Theme.bgHigh)

        Rectangle {
            id: swHandle

            width: sw.checked ? 22 : 16
            height: width
            radius: Theme.shapeFull
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? sw.width - width - 2 : 5
            color: sw.checked ? Theme.bgOpaque : Theme.outlineStrong

            Behavior on x {
                NumberAnimation {
                    duration: Theme.barMs(250)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.easeEmphasized
                }

            }

            Behavior on width {
                NumberAnimation {
                    duration: Theme.barMs(250)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.easeEmphasized
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.barDurQuick
                }

            }

        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.barMs(200)
            }

        }

    }

    // m3 slider: thick track, detached handle, stop dot at the far end
    component M3Slider: Item {
        id: sl

        property real value: 0
        property bool muted: false
        property bool interactive: false
        property bool dragging: false
        property real dragValue: 0
        readonly property real liveValue: sl.dragging ? sl.dragValue : sl.value

        signal moved(real v)

        readonly property int handleW: 4
        readonly property int trackH: 16
        readonly property int notch: 6
        readonly property real pos: Math.max(0, Math.min(1, sl.liveValue / 100))
        readonly property real handleX: sl.pos * Math.max(0, sl.width - sl.handleW)
        readonly property color liveColor: sl.muted ? Theme.outlineStrong : Theme.accent

        function valueAt(px) {
            const span = Math.max(1, sl.width - sl.handleW);
            return Math.max(0, Math.min(100, ((px - sl.handleW / 2) / span) * 100));
        }

        function applyAt(px) {
            sl.dragging = true;
            sl.dragValue = sl.valueAt(px);
            sl.moved(sl.dragValue);
        }

        height: 32

        Rectangle {
            id: activeTrack

            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, sl.handleX - sl.notch)
            height: sl.trackH
            radius: sl.trackH / 2
            topRightRadius: 2
            bottomRightRadius: 2
            color: sl.liveColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.barDurQuick
                }

            }

        }

        Rectangle {
            id: inactiveTrack

            x: Math.min(sl.width, sl.handleX + sl.handleW + sl.notch)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, sl.width - inactiveTrack.x)
            height: sl.trackH
            radius: sl.trackH / 2
            topLeftRadius: 2
            bottomLeftRadius: 2
            color: Theme.withBlur(Theme.bgHigh)

            Rectangle {
                visible: inactiveTrack.width > 16
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 4
                radius: 2
                color: Theme.outlineStrong
            }

        }

        Rectangle {
            id: handle

            x: sl.handleX
            anchors.verticalCenter: parent.verticalCenter
            width: sl.handleW
            height: sl.trackH + 12
            radius: sl.handleW / 2
            color: sl.liveColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.barDurQuick
                }

            }

        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -4
            anchors.bottomMargin: -4
            enabled: sl.interactive
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => {
                return sl.applyAt(mouse.x);
            }
            onPositionChanged: (mouse) => {
                if (pressed)
                    sl.applyAt(mouse.x);

            }
            onReleased: sl.dragging = false
            onCanceled: sl.dragging = false
            onWheel: (wheel) => {
                sl.moved(Math.max(0, Math.min(100, sl.value + (wheel.angleDelta.y > 0 ? 5 : -5))));
                wheel.accepted = true;
            }
        }

    }

    // leading control, track, trailing readout
    component SliderRow: Item {
        id: sliderRow

        property var iconLevels: []
        property real value: 0
        property bool muted: false
        property bool showMute: false
        property bool showPicker: false
        readonly property real displayValue: sliderTrack.liveValue

        signal moved(real v)
        signal muteToggled()
        signal pickerRequested()

        height: 40

        Rectangle {
            id: sliderLead

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: Theme.shapeFull
            color: "transparent"

            StateLayer {
                hovered: sliderRow.showMute && leadArea.containsMouse
                pressed: sliderRow.showMute && leadArea.pressed
            }

            MorphIcon {
                anchors.centerIn: parent
                levels: sliderRow.iconLevels
                value: sliderRow.displayValue
                tint: sliderRow.muted ? Theme.error : Theme.subtext
                iconSize: 18
            }

            Rectangle {
                visible: sliderRow.muted
                anchors.centerIn: parent
                width: 22
                height: 1.5
                rotation: 45
                color: Theme.error
            }

            MouseArea {
                id: leadArea

                anchors.fill: parent
                enabled: sliderRow.showMute
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sliderRow.muteToggled()
            }

        }

        M3Slider {
            id: sliderTrack

            anchors.left: sliderLead.right
            anchors.leftMargin: root.sp3
            anchors.right: sliderTail.left
            anchors.rightMargin: root.sp3
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            value: sliderRow.value
            muted: sliderRow.muted
            onMoved: (v) => {
                return sliderRow.moved(v);
            }
        }

        // fixed width, so a row without a picker still lines its track up
        Item {
            id: sliderTail

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 74
            height: 28

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                horizontalAlignment: Text.AlignRight
                text: Math.round(sliderRow.displayValue) + "%"
                color: sliderRow.muted ? Theme.subtextDim : Theme.text
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fontLabelMd
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: sliderRow.showPicker
                path: root.chevronPath
                tint: Theme.subtext
                diameter: 28
                iconSize: 13
                onTapped: sliderRow.pickerRequested()
            }

        }

    }

    // the output/input picker body
    component DeviceList: Column {
        id: devList

        property var nodes: []
        property var current: null
        property string emptyText: ""
        property string iconPath: ""
        property var availability: ({})

        signal picked(var node)

        spacing: root.sp2

        Repeater {
            model: devList.nodes

            Rectangle {
                id: devOpt

                required property var modelData
                readonly property bool isCurrent: devList.current === devOpt.modelData
                readonly property bool usable: devList.availability[devOpt.modelData.name] !== false

                width: devList.width
                height: 56
                radius: Theme.shapeMd
                color: devOpt.isCurrent ? Theme.accent : Theme.withBlur(Theme.bgTile)
                opacity: devOpt.usable ? 1 : 0.42

                StateLayer {
                    hovered: devOptArea.containsMouse
                    pressed: devOptArea.pressed
                    tint: devOpt.isCurrent ? Theme.fgAccent : Theme.text
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.barMs(180)
                    }

                }

                SvgIcon {
                    id: devOptIcon

                    anchors.left: parent.left
                    anchors.leftMargin: root.sp3
                    anchors.verticalCenter: parent.verticalCenter
                    path: devList.iconPath
                    tint: devOpt.isCurrent ? Theme.fgAccent : Theme.subtext
                    iconSize: 18
                }

                Column {
                    anchors.left: devOptIcon.right
                    anchors.leftMargin: root.sp3
                    anchors.right: devOptCheck.left
                    anchors.rightMargin: root.sp2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: root.deviceLabel(devOpt.modelData)
                        color: devOpt.isCurrent ? Theme.fgAccent : Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontLabelLg
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: devOpt.isCurrent ? "Default device" : (devOpt.usable ? "" : "Not connected")
                        color: devOpt.isCurrent ? Theme.alpha(Theme.fgAccent, 0.75) : Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelSm
                        elide: Text.ElideRight
                    }

                }

                SvgIcon {
                    id: devOptCheck

                    anchors.right: parent.right
                    anchors.rightMargin: root.sp3
                    anchors.verticalCenter: parent.verticalCenter
                    visible: devOpt.isCurrent
                    path: root.checkPath
                    tint: Theme.fgAccent
                    iconSize: 16
                }

                MouseArea {
                    id: devOptArea

                    anchors.fill: parent
                    enabled: devOpt.usable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: devList.picked(devOpt.modelData)
                }

            }

        }

        Text {
            width: devList.width
            visible: devList.nodes.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: devList.emptyText
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelMd
            topPadding: root.sp5
            bottomPadding: root.sp5
        }

    }

    component Meter: Rectangle {
        id: meter

        property real pct: 0
        property color barColor: Theme.accent

        height: 6
        radius: Theme.shapeFull
        color: Theme.withBlur(Theme.bgHigh)

        Rectangle {
            width: Math.max(0, Math.min(1, meter.pct / 100)) * parent.width
            height: parent.height
            radius: Theme.shapeFull
            color: meter.barColor

            Behavior on width {
                NumberAnimation {
                    duration: Theme.barMs(300)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.easeEmphasized
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.barMs(200)
                }

            }

        }

    }

    // one anatomy for all three: overline, value, detail, then a meter zone
    // whose contents share a baseline whether they are a bar or a sparkline
    component StatCard: Rectangle {
        id: card

        property string label: ""
        property string valueText: "—"
        property string detailText: ""
        property bool showBar: false
        property real barPct: 0
        property color barColor: Theme.accent
        property bool showChart: false
        property var chartHistory: []

        readonly property int meterZone: 22

        // every card carries the same four rows, so all three size alike even
        // when a detail line is empty
        implicitHeight: statColumn.implicitHeight + root.sp3 * 2
        height: implicitHeight
        radius: Theme.shapeMd
        color: Theme.withBlur(Theme.bgTile)

        Column {
            id: statColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.sp3
            spacing: root.sp1

            Overline {
                width: parent.width
                text: card.label
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: card.valueText
                color: Theme.text
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fontTitleMd
            }

            Text {
                width: parent.width
                text: card.detailText
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
                elide: Text.ElideRight
            }

            Item {
                id: meterZone

                width: parent.width
                height: card.meterZone

            Meter {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: card.showBar
                pct: card.barPct
                barColor: card.barColor
            }

            Row {
                id: chartRow

                anchors.fill: parent
                visible: card.showChart
                spacing: 2

                Repeater {
                    model: card.chartHistory

                    Rectangle {
                        required property real modelData

                        anchors.bottom: parent.bottom
                        width: (chartRow.width - Math.max(0, card.chartHistory.length - 1) * chartRow.spacing) / Math.max(1, card.chartHistory.length)
                        height: Math.max(2, (modelData / 100) * chartRow.height)
                        radius: 2
                        color: Theme.accent
                        opacity: 0.85

                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.barMs(220)
                                easing.type: Easing.Bezier
                                easing.bezierCurve: root.easeEmphasized
                            }

                        }

                    }

                    }

                }

            }

        }

    }

    // flat tile; "on" is carried by the icon tint and a growing accent underline
    // checked tiles fill with the accent, the way they did before
    component ToggleTile: Rectangle {
        id: tile

        property string iconPath: ""
        property string iconGlyph: ""
        property string name: ""
        property string sub: ""
        property bool checked: false
        property bool showArrow: false

        signal toggled()
        signal expandRequested()

        width: (root.contentWidth - root.sp2) / 2
        height: 56
        radius: Theme.shapeLg
        color: tile.checked ? Theme.accent : Theme.withBlur(Theme.bgTile)

        StateLayer {
            hovered: tileArea.containsMouse
            pressed: tileArea.pressed
            tint: tile.checked ? Theme.fgAccent : Theme.text
        }

        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: root.sp3
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.sp2
            width: parent.width - root.sp3 - (tile.showArrow ? 38 : root.sp3)

            SvgIcon {
                visible: tile.iconGlyph === ""
                anchors.verticalCenter: parent.verticalCenter
                path: tile.iconPath
                tint: tile.checked ? Theme.fgAccent : Theme.subtext
                iconSize: 18
            }

            Text {
                visible: tile.iconGlyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: tile.iconGlyph
                color: tile.checked ? Theme.fgAccent : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(17)
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                width: parent.width - 18 - root.sp2

                Text {
                    width: parent.width
                    text: tile.name
                    color: tile.checked ? Theme.fgAccent : Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fontLabelLg
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: tile.sub !== ""
                    text: tile.sub
                    color: tile.checked ? Theme.alpha(Theme.fgAccent, 0.75) : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelSm
                    elide: Text.ElideRight
                }

            }

        }

        IconButton {
            visible: tile.showArrow
            anchors.right: parent.right
            anchors.rightMargin: root.sp1
            anchors.verticalCenter: parent.verticalCenter
            path: root.chevronPath
            tint: tile.checked ? Theme.fgAccent : Theme.subtext
            diameter: 30
            iconSize: 14
            onTapped: tile.expandRequested()
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.barMs(180)
            }

        }

    }

    component StatusIndicator: Row {
        property string svgPath: ""
        property string labelText: ""
        property bool isMuted: false

        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Item {
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            Shape {
                width: 24
                height: 24
                scale: 14 / 24
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: isMuted ? Theme.outlineStrong : Theme.text
                    strokeWidth: 0

                    PathSvg {
                        path: svgPath
                    }

                }

            }

            Rectangle {
                visible: isMuted
                anchors.centerIn: parent
                width: parent.width * 1.3
                height: 1.5
                rotation: 45
                color: Theme.error
            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: labelText
            color: Theme.text
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fontLabelLg
        }

    }

    component SvgIcon: Item {
        id: iconRoot

        property string path: ""
        property color tint: Theme.text
        property int iconSize: 16

        width: iconSize
        height: iconSize

        Shape {
            width: 24
            height: 24
            scale: iconRoot.iconSize / 24
            anchors.centerIn: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: iconRoot.tint
                strokeWidth: 0

                PathSvg {
                    path: iconRoot.path
                }

            }

        }

    }

    component MorphIcon: Item {
        id: morphIcon

        property var levels: []
        property real value: 0
        property color tint: Theme.text
        property int iconSize: 16
        readonly property int activeIndex: {
            for (let i = 0; i < morphIcon.levels.length; i++) {
                if (morphIcon.value <= morphIcon.levels[i].max)
                    return i;

            }
            return morphIcon.levels.length - 1;
        }

        width: iconSize
        height: iconSize

        Repeater {
            model: morphIcon.levels

            Shape {
                id: levelShape

                required property int index
                required property var modelData

                width: 24
                height: 24
                scale: morphIcon.iconSize / 24
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: morphIcon.activeIndex === levelShape.index ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barMs(180)
                        easing.type: Easing.OutCubic
                    }

                }

                ShapePath {
                    fillColor: morphIcon.tint
                    strokeWidth: 0

                    PathSvg {
                        path: levelShape.modelData.path
                    }

                }

            }

        }

    }

}
