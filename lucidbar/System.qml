import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs

BarPill {
    id: root

    // wired from shell.qml, for handing off to the real panels
    property var notifMod: null
    property var mprisMod: null

    property string view: "main"
    readonly property bool inSubView: root.view !== "main"

    property bool viewSwitching: false

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

        root.beginTransition();
        root.view = v;
    }

    readonly property int horizontalPadding: 16
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    readonly property int maxPanelHeight: Math.min(820, Math.max(200, root.screenH - 40))
    readonly property int contentWidth: root.panelWidth - 28
    readonly property int subHeaderHeight: 38
    readonly property real viewContentHeight: {
        if (root.view === "wifi")
            return wifiPanel.implicitHeight + root.subHeaderHeight + 10;

        if (root.view === "bluetooth")
            return btPanel.implicitHeight + root.subHeaderHeight + 10;

        return expandedColumn.implicitHeight;
    }

    property string backlightDevice: ""
    property int maxBrightness: 0
    readonly property int brightnessPercent: root.maxBrightness > 0 ? Math.round((parseInt(brightnessFile.text()) / root.maxBrightness) * 100) : 0
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: (source && source.audio) ? source.audio.muted : true
    readonly property bool volMuted: (sink && sink.audio) ? sink.audio.muted : true
    readonly property int volumePercent: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0

    readonly property var brightnessIconLevels: [
        { "max": 33, "path": "M12 6.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11Z" },
        { "max": 66, "path": "M12 6.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11ZM12 1a1 1 0 0 1 1 1v1.5a1 1 0 1 1-2 0V2a1 1 0 0 1 1-1Zm0 18.5a1 1 0 0 1 1 1V22a1 1 0 1 1-2 0v-1.5a1 1 0 0 1 1-1ZM1 12a1 1 0 0 1 1-1h1.5a1 1 0 1 1 0 2H2a1 1 0 0 1-1-1Zm18.5 0a1 1 0 0 1 1-1H22a1 1 0 1 1 0 2h-1.5a1 1 0 0 1-1-1Z" },
        { "max": 100, "path": "M12 6.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11ZM12 1a1 1 0 0 1 1 1v1.5a1 1 0 1 1-2 0V2a1 1 0 0 1 1-1Zm0 18.5a1 1 0 0 1 1 1V22a1 1 0 1 1-2 0v-1.5a1 1 0 0 1 1-1ZM4.22 4.22a1 1 0 0 1 1.41 0l1.06 1.06a1 1 0 1 1-1.41 1.41L4.22 5.63a1 1 0 0 1 0-1.41Zm12.6 12.6a1 1 0 0 1 1.41 0l1.06 1.06a1 1 0 0 1-1.41 1.41l-1.06-1.06a1 1 0 0 1 0-1.41ZM1 12a1 1 0 0 1 1-1h1.5a1 1 0 1 1 0 2H2a1 1 0 0 1-1-1Zm18.5 0a1 1 0 0 1 1-1H22a1 1 0 1 1 0 2h-1.5a1 1 0 0 1-1-1ZM4.22 19.78a1 1 0 0 1 0-1.41l1.06-1.06a1 1 0 1 1 1.41 1.41l-1.06 1.06a1 1 0 0 1-1.41 0Zm12.6-12.6a1 1 0 0 1 0-1.41l1.06-1.06a1 1 0 1 1 1.41 1.41l-1.06 1.06a1 1 0 0 1-1.41 0Z" }
    ]
    readonly property var volumeIconLevels: [
        { "max": 0, "path": "M7 9v6h4l5 5V4l-5 5H7z" },
        { "max": 49, "path": "M18.5 12c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM5 9v6h4l5 5V4L9 9H5z" },
        { "max": 100, "path": "M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" }
    ]

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
    readonly property bool dndOn: root.notifMod ? root.notifMod.dnd : false
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter ? btAdapter.enabled : false
    property bool airplaneMode: false
    property bool nightLight: false
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
    property real _prevCpuTotal: -1
    property real _prevCpuIdle: -1

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

    property var notifShownIds: ({})
    property bool notifShownSeeded: false

    function markNotifShown(id) {
        if (!root.notifShownSeeded) {
            const pending = root.notifMod ? root.notifMod.sortedNotifications : [];
            for (const n of pending) root.notifShownIds[n.id] = true
            root.notifShownSeeded = true;
        }
        if (root.notifShownIds[id])
            return false;

        root.notifShownIds[id] = true;
        return true;
    }

    shown: Prefs.showSystem

    compactWidth: content.implicitWidth + root.horizontalPadding * 2
    panelWidth: Math.min(400, root.screenW - 34)
    panelHeight: Math.min(root.maxPanelHeight, root.viewContentHeight + 28)
    expandedRadius: 20
    compactCollapseScale: 0.94
    surfaceLayered: true

    Component.onCompleted: findDeviceProc.running = true
    onBacklightDeviceChanged: {
        if (backlightDevice !== "")
            readMaxProc.running = true;

    }
    onCompactClicked: root.view = "main"
    onExpandedChanged: {
        if (expanded) {
            statsTimer.restart();
            lsblkProc.running = true;
        } else {
            statsTimer.stop();
            diskDropdownOpen = false;
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
            onStreamFinished: root.maxBrightness = parseInt(this.text.trim())
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
                root.ramHistory = root.pushSample(root.ramHistory, usage, 16);
            }
        }

    }

    Process {
        id: lsblkProc

        command: ["lsblk", "-b", "-n", "-o", "NAME,SIZE,TYPE"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter((l) => {
                    return l.length > 0;
                });
                const disks = [];
                for (const line of lines) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 3)
                        continue;

                    const name = parts[0].replace(/^[\s│├└─]+/, "");
                    const size = parseInt(parts[1]);
                    const type = parts[2];
                    const isWholeDisk = type === "disk" && !/^(zram|loop)/.test(name);
                    const isExtraPartition = type === "part" && root.extraDiskPartitions.includes(name);
                    if (!isWholeDisk && !isExtraPartition)
                        continue;

                    disks.push({
                        "name": name,
                        "size": size,
                        "used": 0
                    });
                }
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
                for (const line of lines) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 2)
                        continue;

                    const source = parts[0];
                    if (!source.startsWith("/dev/"))
                        continue;

                    const used = parseInt(parts[1]);
                    if (isNaN(used))
                        continue;

                    const devName = source.slice(5);
                    const exactDisk = disks.find((d) => {
                        return d.name === devName;
                    });
                    if (exactDisk) {
                        exactDisk.used += used;
                        exactDisk.mounted = true;
                    }
                    let base = devName;
                    let m = devName.match(/^(nvme\d+n\d+|mmcblk\d+)p\d+$/);
                    if (m) {
                        base = m[1];
                    } else {
                        m = devName.match(/^([a-z]+)\d+$/);
                        if (m)
                            base = m[1];

                    }
                    const disk = disks.find((d) => {
                        return d.name === base;
                    });
                    if (disk && disk !== exactDisk) {
                        disk.used += used;
                        disk.mounted = true;
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

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    ScriptModel {
        id: miniNotifModel

        values: root.notifMod ? root.notifMod.sortedNotifications.slice(0, 2) : []
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

            Item {
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
                visible: root.btEnabled
                anchors.verticalCenter: parent.verticalCenter
                path: "M17.71,7.71L12,2H11V9.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L11,14.41V22H12L17.71,16.29L13.41,12L17.71,7.71M13,5.83L15.17,8L13,10.17V5.83M13,13.83L15.17,16L13,18.17V13.83Z"
                tint: btPanel.connectedDevices.length > 0 ? Theme.accent : Theme.subtext
                iconSize: 15
            }

            StatusIndicator {
                svgPath: root.volumeIconFor(root.volumePercent)
                labelText: root.volMuted ? "Muted" : root.volumePercent
                isMuted: root.volMuted
            }

            StatusIndicator {
                svgPath: "M12 14a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3Zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.92V21h2v-3.08A7 7 0 0 0 19 11h-2Z"
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
                    font.pixelSize: Theme.fs(13)
                }

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

                Behavior on x {
                    enabled: root.viewSwitching

                    NumberAnimation {
                        duration: root.morphDuration
                        easing.type: Easing.Bezier
                        easing.bezierCurve: root.morphEasing
                    }

                }

                Flickable {
                    id: scrollArea

                    anchors.fill: parent
                    anchors.margins: 14
                    contentWidth: width
                    contentHeight: expandedColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: expandedColumn

                        width: scrollArea.width
                        spacing: 14

                        Grid {
                            width: root.contentWidth
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 8

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
                                iconPath: "M17.71,7.71L12,2H11V9.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L11,14.41V22H12L17.71,16.29L13.41,12L17.71,7.71M13,5.83L15.17,8L13,10.17V5.83M13,13.83L15.17,16L13,18.17V13.83Z"
                                name: "Bluetooth"
                                sub: btPanel.label
                                checked: root.btEnabled
                                showArrow: true
                                onToggled: {
                                    if (root.btAdapter)
                                        root.btAdapter.enabled = !root.btAdapter.enabled;

                                }
                                onExpandRequested: root.showView("bluetooth")
                            }

                            ToggleTile {
                                iconPath: "M12 14a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3Zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.92V21h2v-3.08A7 7 0 0 0 19 11h-2Z"
                                name: "Microphone"
                                sub: root.micMuted ? "Disabled" : "Active"
                                checked: !root.micMuted
                                onToggled: {
                                    if (root.source && root.source.audio)
                                        root.source.audio.muted = !root.source.audio.muted;

                                }
                            }

                            ToggleTile {
                                iconPath: "M21 16v-2l-8-5V3.5a1.5 1.5 0 0 0-3 0V9l-8 5v2l8-2.5V19l-2.5 1.5V22l4-1 4 1v-1.5L11 19v-5.5L21 16Z"
                                name: "Airplane Mode"
                                checked: root.airplaneMode
                                onToggled: {
                                    root.airplaneMode = !root.airplaneMode;
                                    if (root.airplaneMode) {
                                        Networking.wifiEnabled = false;
                                        if (root.btAdapter)
                                            root.btAdapter.enabled = false;

                                    }
                                }
                            }

                            ToggleTile {
                                iconPath: "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm5 11H7v-2h10v2Z"
                                name: "Do Not Disturb"
                                checked: root.dndOn
                                onToggled: {
                                    if (root.notifMod)
                                        root.notifMod.dnd = !root.notifMod.dnd;

                                }
                            }

                            ToggleTile {
                                iconPath: "M12 3a9 9 0 1 0 8.94 10.06.5.5 0 0 0-.66-.54A7 7 0 1 1 11.48 3.72a.5.5 0 0 0-.54-.66A9.06 9.06 0 0 0 12 3Z"
                                name: "Night Light"
                                checked: root.nightLight
                                onToggled: root.nightLight = !root.nightLight
                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                        }

                        Column {
                            width: root.contentWidth
                            spacing: 12

                            SliderRow {
                                iconLevels: root.brightnessIconLevels
                                value: root.brightnessPercent
                                onCommitted: (v) => {
                                    return root.setBrightness(v);
                                }
                            }

                            SliderRow {
                                iconLevels: root.volumeIconLevels
                                value: root.volumePercent
                                onCommitted: (v) => {
                                    if (root.sink && root.sink.audio)
                                        root.sink.audio.volume = v / 100;

                                }
                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                        }

                        Rectangle {
                            id: mprisSection

                            readonly property var mprisPlayer: root.mprisMod ? root.mprisMod.player : null

                            width: root.contentWidth
                            height: 62
                            radius: 12
                            color: mprisArea.containsMouse ? Theme.withBlur(Theme.bgHover) : Theme.withBlur(Theme.bgTile)

                            MouseArea {
                                id: mprisArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.expanded = false;
                                    if (root.mprisMod)
                                        root.mprisMod.expanded = true;

                                }
                            }

                            Rectangle {
                                id: mprisArt

                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 42
                                height: 42
                                radius: 10
                                color: Theme.withBlur(Theme.bgActive)
                                clip: true

                                Image {
                                    id: mprisArtImg

                                    anchors.fill: parent
                                    source: mprisSection.mprisPlayer ? mprisSection.mprisPlayer.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    visible: !mprisArtImg.visible
                                    path: "M12 3v10.55A4 4 0 1 0 14 17V7h4V3h-6Z"
                                    tint: Theme.subtext
                                    iconSize: 18
                                }

                            }

                            Column {
                                anchors.left: mprisArt.right
                                anchors.leftMargin: 10
                                anchors.right: mprisControls.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: root.mprisMod ? root.mprisMod.title : "Nothing playing"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fs(12)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: root.mprisMod ? root.mprisMod.artist : ""
                                    color: Theme.subtext
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(10)
                                    elide: Text.ElideRight
                                }

                            }

                            Row {
                                id: mprisControls

                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Item {
                                    width: 15
                                    height: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: mprisPrevArea.containsMouse ? 0.7 : 1

                                    SvgIcon {
                                        anchors.fill: parent
                                        path: "M6 6h2v12H6V6Zm3.5 6 8.5-6v12l-8.5-6Z"
                                        tint: Theme.text
                                        iconSize: 15
                                    }

                                    MouseArea {
                                        id: mprisPrevArea

                                        anchors.fill: parent
                                        anchors.margins: -5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (mprisSection.mprisPlayer && mprisSection.mprisPlayer.canGoPrevious)
                                                mprisSection.mprisPlayer.previous();

                                        }
                                    }

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.barMs(120)
                                        }

                                    }

                                }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 999
                                    color: Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        path: (root.mprisMod && root.mprisMod.isPlaying) ? "M8 6h3v12H8V6Zm5 0h3v12h-3V6Z" : "M8 5v14l11-7L8 5Z"
                                        tint: Theme.onAccent
                                        iconSize: 14
                                    }

                                    MouseArea {
                                        id: mprisPlayArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (mprisSection.mprisPlayer && mprisSection.mprisPlayer.canTogglePlaying)
                                                mprisSection.mprisPlayer.togglePlaying();

                                        }
                                    }

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.barMs(120)
                                        }

                                    }

                                }

                                Item {
                                    width: 15
                                    height: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: mprisNextArea.containsMouse ? 0.7 : 1

                                    SvgIcon {
                                        anchors.fill: parent
                                        path: "M18 6h-2v12h2V6Zm-3.5 6L6 6v12l8.5-6Z"
                                        tint: Theme.text
                                        iconSize: 15
                                    }

                                    MouseArea {
                                        id: mprisNextArea

                                        anchors.fill: parent
                                        anchors.margins: -5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (mprisSection.mprisPlayer && mprisSection.mprisPlayer.canGoNext)
                                                mprisSection.mprisPlayer.next();

                                        }
                                    }

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.barMs(120)
                                        }

                                    }

                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(120)
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                        }

                        Column {
                            width: root.contentWidth
                            spacing: 8

                            Row {
                                width: parent.width
                                spacing: 8

                                StatCard {
                                    width: (root.contentWidth - 16) / 3
                                    label: "BATTERY"
                                    valueText: root.batteryPresent ? root.batteryPercent + "%" : "N/A"
                                    showBar: root.batteryPresent
                                    barPct: root.batteryPercent
                                }

                                StatCard {
                                    width: (root.contentWidth - 16) / 3
                                    label: "RAM"
                                    valueText: root.ramHistory.length > 0 ? Math.round(root.ramPercent) + "%" : "—"
                                    showChart: true
                                    chartHistory: root.ramHistory
                                }

                                StatCard {
                                    width: (root.contentWidth - 16) / 3
                                    label: "CPU"
                                    valueText: root.cpuHistory.length > 0 ? Math.round(root.cpuPercent) + "%" : "—"
                                    showChart: true
                                    chartHistory: root.cpuHistory
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

                                width: root.contentWidth
                                height: diskColumn.implicitHeight + 20
                                radius: 12
                                color: Theme.withBlur(Theme.bgTile)

                                Column {
                                    id: diskColumn

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    spacing: 6

                                    Item {
                                        width: parent.width
                                        height: 22

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "DISK"
                                            color: Theme.subtext
                                            font.family: Theme.fontFamily
                                            font.bold: true
                                            font.pixelSize: Theme.fs(10)
                                        }

                                        Rectangle {
                                            id: diskTrigger

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 22
                                            width: diskTriggerRow.implicitWidth + 18
                                            radius: 999
                                            color: diskTriggerArea.containsMouse ? Theme.accentHover : Theme.accent
                                            visible: root.diskList.length > 0
                                            scale: diskTriggerArea.pressed ? 0.96 : 1

                                            Row {
                                                id: diskTriggerRow

                                                anchors.centerIn: parent
                                                spacing: 4

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.selectedDisk || "—"
                                                    color: Theme.onAccent
                                                    font.family: Theme.fontFamily
                                                    font.bold: true
                                                    font.pixelSize: Theme.fs(10)
                                                }

                                                SvgIcon {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    path: "M7.41 8.59 12 13.17l4.59-4.58L18 10l-6 6-6-6Z"
                                                    tint: Theme.onAccent
                                                    iconSize: 10
                                                    rotation: root.diskDropdownOpen ? 180 : 0

                                                    Behavior on rotation {
                                                        NumberAnimation {
                                                            duration: Theme.barMs(180)
                                                        }

                                                    }

                                                }

                                            }

                                            MouseArea {
                                                id: diskTriggerArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!root.diskDropdownOpen) {
                                                        const pos = diskTrigger.mapToItem(expandedFace, 0, diskTrigger.height);
                                                        diskPopup.x = pos.x + diskTrigger.width - diskPopup.width;
                                                        diskPopup.y = pos.y + 6;
                                                    }
                                                    root.diskDropdownOpen = !root.diskDropdownOpen;
                                                }
                                            }

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Theme.barMs(120)
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

                                            if (!diskCard.selectedDiskInfo.mounted)
                                                return "Not mounted · " + Math.round(diskCard.totalGB) + " GB";

                                            return Math.round(diskCard.usedGB) + " GB / " + Math.round(diskCard.totalGB) + " GB";
                                        }
                                        color: (diskCard.selectedDiskInfo && !diskCard.selectedDiskInfo.mounted) ? Theme.subtext : Theme.text
                                        font.family: Theme.fontFamily
                                        font.bold: true
                                        font.pixelSize: Theme.fs(15)
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 5
                                        radius: 999
                                        color: Theme.withBlur(Theme.bgHigh)
                                        opacity: (diskCard.selectedDiskInfo && !diskCard.selectedDiskInfo.mounted) ? 0.4 : 1
                                        visible: diskCard.selectedDiskInfo !== null

                                        Rectangle {
                                            width: parent.width * (diskCard.usedPct / 100)
                                            height: parent.height
                                            radius: 999
                                            color: Theme.accent

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: Theme.barMs(300)
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                        }

                        Rectangle {
                            id: notifSection

                            width: root.contentWidth
                            height: notifCol.implicitHeight + 25
                            radius: 12
                            color: notifSectionArea.containsMouse ? Theme.withBlur(Theme.bgHover) : "transparent"

                            MouseArea {
                                id: notifSectionArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.expanded = false;
                                    if (root.notifMod)
                                        root.notifMod.expanded = true;

                                }
                            }

                            Column {
                                id: notifCol

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 15
                                spacing: 8

                                Item {
                                    width: parent.width
                                    height: 18

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Notifications"
                                        color: Theme.subtext
                                        font.family: Theme.fontFamily
                                        font.bold: true
                                        font.pixelSize: Theme.fs(10)
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Clear"
                                        color: clearArea.containsMouse ? Theme.accentHover : Theme.accent
                                        opacity: (root.notifMod && root.notifMod.notifCount > 0) ? 1 : 0.35
                                        font.family: Theme.fontFamily
                                        font.bold: true
                                        font.pixelSize: Theme.fs(10)

                                        MouseArea {
                                            id: clearArea

                                            anchors.fill: parent
                                            anchors.margins: -6
                                            enabled: root.notifMod && root.notifMod.notifCount > 0
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                mouse.accepted = true;
                                                if (root.notifMod)
                                                    root.notifMod.clearAll();

                                            }
                                        }

                                    }

                                }

                                ListView {
                                    id: miniList

                                    width: parent.width
                                    height: contentHeight
                                    visible: root.notifMod && root.notifMod.notifCount > 0
                                    spacing: 8
                                    interactive: false
                                    model: miniNotifModel

                                    delegate: Rectangle {
                                        id: miniCard

                                        required property var modelData
                                        readonly property var notification: modelData
                                        property string notifAppName: ""
                                        property string notifSummary: ""
                                        property string notifImage: ""
                                        property string notifAppIcon: ""
                                        readonly property string themeIconName: miniCard.notifAppIcon || (miniCard.notifImage.indexOf("image://icon/") === 0 ? miniCard.notifImage.slice(13) : "")
                                        readonly property string directImage: miniCard.notifImage.indexOf("image://icon/") === 0 ? "" : miniCard.notifImage
                                        readonly property string iconSrc: directImage || (themeIconName ? Quickshell.iconPath(themeIconName) : "")
                                        property real arrivalGlow: 0

                                        function syncNotification() {
                                            const n = miniCard.notification;
                                            if (!n)
                                                return ;

                                            miniCard.notifAppName = n.appName;
                                            miniCard.notifSummary = n.summary;
                                            miniCard.notifImage = n.image;
                                            miniCard.notifAppIcon = n.appIcon;
                                        }

                                        onNotificationChanged: miniCard.syncNotification()
                                        Component.onCompleted: {
                                            miniCard.syncNotification();
                                            if (!miniCard.notification || !root.markNotifShown(miniCard.notification.id)) {
                                                miniCard.opacity = 1;
                                                miniCard.scale = 1;
                                            }
                                        }
                                        width: parent ? parent.width : 0
                                        height: 44
                                        radius: 10
                                        color: Theme.withBlur(miniCard.arrivalGlow > 0 ? Theme._mix(Theme.bgSunken, Theme.accent, miniCard.arrivalGlow * 0.32) : Theme.bgSunken)

                                        Connections {
                                            function onAppNameChanged() {
                                                miniCard.syncNotification();
                                            }

                                            function onAppIconChanged() {
                                                miniCard.syncNotification();
                                            }

                                            function onSummaryChanged() {
                                                miniCard.syncNotification();
                                            }

                                            function onImageChanged() {
                                                miniCard.syncNotification();
                                            }

                                            target: miniCard.notification
                                        }

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8

                                            Rectangle {
                                                width: 24
                                                height: 24
                                                radius: 7
                                                color: Theme.bgTrack
                                                anchors.verticalCenter: parent.verticalCenter

                                                IconImage {
                                                    anchors.fill: parent
                                                    anchors.margins: 1
                                                    source: miniCard.iconSrc
                                                    asynchronous: true
                                                    visible: status === Image.Ready
                                                }

                                            }

                                            Column {
                                                width: parent.width - 24 - 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1

                                                Text {
                                                    width: parent.width
                                                    visible: miniCard.notifAppName !== ""
                                                    text: miniCard.notifAppName
                                                    color: Theme.subtextDim
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(9)
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: miniCard.notifSummary
                                                    color: Theme.text
                                                    font.family: Theme.fontFamily
                                                    font.bold: true
                                                    font.pixelSize: Theme.fs(11)
                                                    elide: Text.ElideRight
                                                }

                                            }

                                        }

                                    }

                                    add: Transition {
                                        id: miniAdd

                                        SequentialAnimation {
                                            PropertyAction {
                                                property: "opacity"
                                                value: 0
                                            }

                                            PauseAnimation {
                                                duration: Theme.barMs(70)
                                            }

                                            NumberAnimation {
                                                property: "opacity"
                                                to: 1
                                                duration: Theme.barMs(220)
                                                easing.type: Easing.OutCubic
                                            }

                                        }

                                        SequentialAnimation {
                                            PropertyAction {
                                                property: "y"
                                                value: miniAdd.ViewTransition.destination.y - 14
                                            }

                                            PauseAnimation {
                                                duration: Theme.barMs(70)
                                            }

                                            NumberAnimation {
                                                property: "y"
                                                to: miniAdd.ViewTransition.destination.y
                                                duration: Theme.barMs(340)
                                                easing.type: Easing.OutCubic
                                            }

                                        }

                                        SequentialAnimation {
                                            PropertyAction {
                                                property: "scale"
                                                value: 0.92
                                            }

                                            PauseAnimation {
                                                duration: Theme.barMs(70)
                                            }

                                            NumberAnimation {
                                                property: "scale"
                                                to: 1
                                                duration: Theme.barMs(360)
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.6
                                            }

                                        }

                                        SequentialAnimation {
                                            PropertyAction {
                                                property: "arrivalGlow"
                                                value: 1
                                            }

                                            PauseAnimation {
                                                duration: Theme.barMs(70)
                                            }

                                            NumberAnimation {
                                                property: "arrivalGlow"
                                                to: 0
                                                duration: Theme.barMs(850)
                                                easing.type: Easing.InCubic
                                            }

                                        }

                                    }

                                    displaced: Transition {
                                        NumberAnimation {
                                            properties: "x,y"
                                            duration: Theme.barMs(300)
                                            easing.type: Easing.OutCubic
                                        }

                                        NumberAnimation {
                                            property: "opacity"
                                            to: 1
                                            duration: Theme.barMs(200)
                                        }

                                        NumberAnimation {
                                            property: "scale"
                                            to: 1
                                            duration: Theme.barMs(200)
                                        }

                                    }

                                    remove: Transition {
                                        NumberAnimation {
                                            property: "opacity"
                                            to: 0
                                            duration: Theme.barMs(200)
                                            easing.type: Easing.InCubic
                                        }

                                        NumberAnimation {
                                            property: "scale"
                                            to: 0.9
                                            duration: Theme.barMs(200)
                                            easing.type: Easing.InCubic
                                        }

                                    }

                                }

                                Text {
                                    width: parent.width
                                    visible: !root.notifMod || root.notifMod.notifCount === 0
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "No notifications"
                                    color: Theme.subtext
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(11)
                                    topPadding: 4
                                    bottomPadding: 4
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

                    visible: opacity > 0.01
                    opacity: root.diskDropdownOpen ? 1 : 0
                    scale: root.diskDropdownOpen ? 1 : 0.94
                    transformOrigin: Item.Top
                    width: 140
                    height: diskPopupColumn.implicitHeight + 8
                    radius: 12
                    color: Theme.withBlur(Theme.bgTile)
                    border.width: 0
                    z: 100

                    Column {
                        id: diskPopupColumn

                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2

                        Repeater {
                            model: root.diskList

                            Rectangle {
                                id: optRow

                                required property var modelData
                                readonly property bool isSelected: optRow.modelData.name === root.selectedDisk

                                width: parent.width
                                height: 26
                                radius: 8
                                color: optRow.isSelected ? Theme.accent : "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: optRow.modelData.name
                                    color: optRow.isSelected ? Theme.onAccent : Theme.text
                                    opacity: (!optRow.modelData.mounted && !optRow.isSelected) ? 0.45 : 1
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fs(11)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: Theme.text
                                    opacity: (optArea.containsMouse && !optRow.isSelected) ? 0.08 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.barMs(150)
                                            easing.type: Easing.OutCubic
                                        }

                                    }

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

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.barMs(120)
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
                            easing.type: Easing.OutCubic
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
                    anchors.topMargin: 14
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    height: root.subHeaderHeight

                    Rectangle {
                        id: backChip

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        radius: 999
                        color: backArea.containsMouse ? Theme.withBlur(Theme.bgHover) : "transparent"

                        SvgIcon {
                            anchors.centerIn: parent
                            path: "M15.41 7.41 14 6l-6 6 6 6 1.41-1.41L10.83 12l4.58-4.59Z"
                            tint: Theme.text
                            iconSize: 16
                        }

                        MouseArea {
                            id: backArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showView("main")
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(120)
                            }

                        }

                    }

                    Text {
                        anchors.left: backChip.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.view === "wifi" ? "Network" : "Bluetooth"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(13)
                    }

                    Rectangle {
                        visible: root.view === "bluetooth"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 18
                        radius: 999
                        color: root.btEnabled ? Theme.accent : Theme.outlineStrong

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.bg
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.btEnabled ? parent.width - width - 2 : 2

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.barMs(200)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.btAdapter)
                                    root.btAdapter.enabled = !root.btAdapter.enabled;

                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(200)
                            }

                        }

                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                }

                Flickable {
                    id: subScroll

                    anchors.top: subHeader.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.bottomMargin: 14
                    contentWidth: width
                    contentHeight: root.view === "bluetooth" ? btPanel.implicitHeight : wifiPanel.implicitHeight
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
            font.pixelSize: Theme.fs(13)
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

        width: (root.contentWidth - 8) / 2
        height: 58
        radius: 14
        color: tile.checked ? Theme.accent : Theme.withBlur(Theme.bgTile)
        border.width: 0

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            width: parent.width - (tile.showArrow ? 40 : 20)

            SvgIcon {
                visible: tile.iconGlyph === ""
                anchors.verticalCenter: parent.verticalCenter
                path: tile.iconPath
                tint: tile.checked ? Theme.onAccent : Theme.subtext
                iconSize: 17
            }

            Text {
                visible: tile.iconGlyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: tile.iconGlyph
                color: tile.checked ? Theme.onAccent : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(16)
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                width: parent.width - 17 - 8

                Text {
                    width: parent.width
                    text: tile.name
                    color: tile.checked ? Theme.onAccent : Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: tile.sub !== ""
                    text: tile.sub
                    color: tile.checked ? Theme.alpha(Theme.onAccent, 0.75) : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    elide: Text.ElideRight
                }

            }

        }

        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }

        Rectangle {
            id: arrowBtn

            visible: tile.showArrow
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 999
            color: arrowArea.containsMouse ? (tile.checked ? Theme.alpha(Theme.onAccent, 0.2) : Theme.accentContainer) : "transparent"

            SvgIcon {
                anchors.centerIn: parent
                path: "M8.59 16.59 13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41Z"
                tint: tile.checked ? Theme.onAccent : (arrowArea.containsMouse ? Theme.accent : Theme.subtext)
                iconSize: 13
            }

            MouseArea {
                id: arrowArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.expandRequested()
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.text
            opacity: (tileArea.containsMouse && !tile.checked) ? 0.08 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.barMs(150)
                    easing.type: Easing.OutCubic
                }

            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.barMs(150)
            }

        }

    }

    component SliderRow: Item {
        id: sliderRow

        property var iconLevels: []
        property real value: 0
        property bool dragging: false
        property real dragValue: 0
        readonly property real displayValue: dragging ? dragValue : value
        readonly property int trackHeight: 32
        readonly property int iconMargin: 9

        signal committed(real v)

        function updateFromX(x) {
            sliderRow.dragging = true;
            const pct = Math.max(0, Math.min(1, x / trackWrap.width));
            sliderRow.dragValue = pct * 100;
            sliderRow.committed(sliderRow.dragValue);
        }

        width: root.contentWidth
        height: trackHeight

        Item {
            id: trackWrap

            anchors.fill: parent

            Rectangle {
                id: rail

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 2
                radius: 1
                color: Theme.withBlur(Theme.outline)
            }

            Rectangle {
                id: fill

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: sliderRow.trackHeight
                radius: height / 2
                color: Theme.accent
                clip: true
                width: Math.max(height, trackWrap.width * (sliderRow.displayValue / 100))

                Behavior on width {
                    enabled: !sliderRow.dragging

                    NumberAnimation {
                        duration: Theme.barMs(220)
                        easing.type: Easing.OutCubic
                    }

                }

                Text {
                    id: percentLabel

                    anchors.left: parent.left
                    anchors.leftMargin: sliderRow.iconMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(sliderRow.displayValue) + "%"
                    color: Theme.onAccent
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)
                    opacity: (fill.width - sliderRow.iconMargin * 2 - width - sliderIcon.width - 6) > 0 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(120)
                        }

                    }

                }

                MorphIcon {
                    id: sliderIcon

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: sliderRow.iconMargin
                    levels: sliderRow.iconLevels
                    value: sliderRow.displayValue
                    tint: Theme.onAccent
                    iconSize: sliderRow.trackHeight - sliderRow.iconMargin * 2
                    transformOrigin: Item.Center
                    scale: 0.75 + 0.35 * (sliderRow.displayValue / 100)

                    Behavior on scale {
                        enabled: !sliderRow.dragging

                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: (mouse) => {
                    return sliderRow.updateFromX(mouse.x);
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        sliderRow.updateFromX(mouse.x);

                }
                onReleased: sliderRow.dragging = false
            }

        }

    }

    component StatCard: Rectangle {
        id: card

        property string label: ""
        property string valueText: "—"
        property bool showBar: false
        property real barPct: 0
        property bool showChart: false
        property var chartHistory: []

        height: 82
        radius: 12
        color: Theme.withBlur(Theme.bgTile)

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Text {
                text: card.label
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fs(10)
            }

            Text {
                text: card.valueText
                color: Theme.text
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fs(15)
            }

            Rectangle {
                visible: card.showBar
                width: parent.width
                height: 5
                radius: 999
                color: Theme.withBlur(Theme.bgHigh)

                Rectangle {
                    width: parent.width * (card.barPct / 100)
                    height: parent.height
                    radius: 999
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.barMs(300)
                        }

                    }

                }

            }

            Row {
                id: chartRow

                visible: card.showChart
                width: parent.width
                height: 26
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
                    }

                }

            }

        }

    }

}
