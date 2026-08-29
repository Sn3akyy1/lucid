import QtQml.Models
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Widgets

Scope {
    id: root

    property bool locked: false
    property bool unlocking: false
    property var notifMod: null
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryPresent: battery ? battery.isPresent : false
    readonly property int batteryPercent: batteryPresent ? Math.round(battery.percentage * 100) : 0
    property var _lsblkDisks: []
    property var diskList: []
    readonly property var extraDiskPartitions: ["nvme0n1p3", "nvme0n1p4"]
    property string selectedDisk: "nvme0n1p4"
    property var ramHistory: []
    property var cpuHistory: []
    property real ramPercent: 0
    property real cpuPercent: 0
    property real _prevCpuTotal: -1
    property real _prevCpuIdle: -1
    property real lat: 52.2297
    property real lon: 21.0122
    property real temp: 0
    property int humidity: 0
    property int weatherCode: 0
    property real feelsLike: 0
    property real windSpeed: 0
    property real tempMax: 0
    property real tempMin: 0
    property real uvIndex: 0
    property string sunsetTime: ""
    property int clockTick: 0
    property string sysUsername: ""
    property string sysHostname: ""
    property string avatarPath: ""
    property var fastfetchData: ({})
    readonly property var mprisPlayers: Mpris.players.values
    readonly property var mprisSpotifyPlayer: {
        for (let i = 0; i < root.mprisPlayers.length; i++) {
            const p = root.mprisPlayers[i];
            if (p.identity && p.identity.toLowerCase().indexOf("spotify") !== -1)
                return p;
        }
        return null;
    }
    readonly property var mprisPlayer: root.mprisSpotifyPlayer || (root.mprisPlayers.length > 0 ? root.mprisPlayers[0] : null)
    readonly property bool mprisIsPlaying: mprisPlayer && mprisPlayer.playbackState === MprisPlaybackState.Playing
    readonly property string mprisTitle: mprisPlayer ? (mprisPlayer.trackTitle || "Unknown") : "Nothing playing"
    readonly property string mprisArtist: mprisPlayer ? mprisPlayer.trackArtist : ""
    readonly property string mprisDisplayTitle: (mprisPlayer && mprisArtist) ? mprisArtist + "  -  " + mprisTitle : mprisTitle
    readonly property real mprisPosSec: mprisPlayer ? mprisPlayer.position : 0
    readonly property real mprisLenSec: mprisPlayer ? mprisPlayer.length : 0
    property real mprisLivePosSec: mprisPosSec
    property double mprisPosTimestamp: Date.now()
    readonly property real mprisProgress: mprisLenSec > 0 ? Math.min(1, mprisLivePosSec / mprisLenSec) : 0

    function fmtMprisTime(sec) {
        const s = Math.max(0, Math.floor(sec));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    onMprisPosSecChanged: {
        mprisPosTimestamp = Date.now();
        mprisLivePosSec = mprisPosSec;
    }

    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device;
        }
        return null;
    }
    readonly property var wiredDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wired)
                return device;
        }
        return null;
    }
    property var activeNetwork: null
    readonly property bool ethernetConnected: !!(root.wiredDevice && root.wiredDevice.connected)
    readonly property bool wifiConnected: root.wifiDevice ? root.wifiDevice.connected : false
    readonly property real wifiSignal: {
        if (!root.activeNetwork || root.activeNetwork.signalStrength === undefined)
            return 0;
        const raw = root.activeNetwork.signalStrength;
        return raw <= 1 ? raw * 100 : raw;
    }
    readonly property string wifiLabel: {
        if (root.ethernetConnected)
            return "Ethernet";
        if (root.wifiConnected && root.activeNetwork)
            return root.activeNetwork.name;
        return "Not connected";
    }

    function refreshActiveNetwork() {
        if (!root.wifiDevice) {
            root.activeNetwork = null;
            return;
        }
        let found = null;
        for (const net of root.wifiDevice.networks.values) {
            if (net.connected) {
                found = net;
                break;
            }
        }
        root.activeNetwork = found;
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: root.btAdapter ? root.btAdapter.enabled : false
    readonly property var btConnectedDevices: (root.btAdapter && root.btAdapter.devices) ? root.btAdapter.devices.values.filter((d) => d.connected) : []
    readonly property string btLabel: {
        if (!root.btEnabled)
            return "Off";
        if (root.btConnectedDevices.length === 1)
            return root.btConnectedDevices[0].name;
        if (root.btConnectedDevices.length > 1)
            return root.btConnectedDevices.length + " connected";
        return "Not connected";
    }

    readonly property bool isNight: {
        root.clockTick;
        const h = new Date().getHours();
        return h < 6 || h >= 20;
    }

    function weatherIconCategory(code, night) {
        if (code === 0) return night ? "clear-night" : "sunny";
        if (code <= 3) return night ? "partly-night" : "partly";
        if (code <= 48) return "fog";
        if (code <= 67) return "rain";
        if (code <= 77) return "snow";
        if (code <= 82) return "rain";
        if (code <= 99) return "storm";
        return "cloudy";
    }

    function weatherDesc(code) {
        if (code === 0) return "Clear";
        if (code <= 3) return "Partly Cloudy";
        if (code <= 48) return "Foggy";
        if (code <= 67) return "Rainy";
        if (code <= 77) return "Snowy";
        if (code <= 82) return "Rain Showers";
        if (code <= 99) return "Thunderstorm";
        return "—";
    }

    function pushSample(historyArr, v, max) {
        const next = historyArr.concat([v]);
        if (next.length > max)
            next.shift();
        return next;
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

    onLockedChanged: {
        if (root.locked) {
            root.notifShownIds = ({});
            root.notifShownSeeded = false;
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.locked = true;
        }
        function unlock(): void {
            root.locked = false;
        }
        function isLocked(): bool {
            return root.locked;
        }
    }

    FileView {
        id: wallpaperFile
        path: Quickshell.env("HOME") + "/.cache/current_wallpaper"
        watchChanges: true
        onFileChanged: reload()
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
        interval: 1000
        running: root.locked && root.mprisIsPlaying
        repeat: true
        onTriggered: {
            if (root.mprisPlayer)
                root.mprisPlayer.positionChanged();
        }
    }

    Timer {
        interval: 33
        running: root.locked && root.mprisIsPlaying
        repeat: true
        onTriggered: {
            root.mprisLivePosSec = Math.min(root.mprisLenSec, root.mprisPosSec + (Date.now() - root.mprisPosTimestamp) / 1000);
        }
    }

    Timer {
        id: sysInfoTimer
        interval: 60000
        repeat: true
        running: false
        triggeredOnStart: true
        onTriggered: {
            fastfetchProc.running = true;
            avatarProc.running = true;
        }
    }

    Process {
        id: fastfetchProc
        command: ["fastfetch", "--logo", "none", "--pipe", "--structure", "Title:OS:Kernel:Packages:Shell:Terminal:WM:Cursor:Font:Uptime:Date:Media"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
                const data = {};
                let uname = "", host = "";
                const labels = ["OS", "Kernel", "Packages", "Shell", "Terminal", "WM", "Cursor", "Font", "Uptime", "Date", "Media"];
                for (const line of lines) {
                    if (line.includes("@") && !labels.some((l) => line.startsWith(l + " "))) {
                        const parts = line.split("@");
                        uname = parts[0];
                        host = parts.slice(1).join("@");
                        continue;
                    }
                    const spaceIdx = line.indexOf(" ");
                    if (spaceIdx === -1) continue;
                    const key = line.slice(0, spaceIdx).toLowerCase();
                    const value = line.slice(spaceIdx + 1).trim();
                    data[key] = value;
                }
                if (uname) root.sysUsername = uname;
                if (host) root.sysHostname = host;
                root.fastfetchData = data;
            }
        }
    }

    Process {
        id: avatarProc
        command: ["bash", "-c", "for f in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\" \"$HOME/.local/share/AccountsService/icons/$USER\"; do [ -f \"$f\" ] && echo \"$f\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.avatarPath = this.text.trim();
            }
        }
    }

    Timer {
        id: netStatusTimer
        interval: 5000
        running: root.locked
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshActiveNetwork()
    }

    Connections {
        function onValuesChanged() {
            root.refreshActiveNetwork();
        }

        target: root.wifiDevice ? root.wifiDevice.networks : null
    }

    Timer {
        id: weatherTimer
        interval: 15 * 60 * 1000
        running: false
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Process {
        id: weatherProc
        command: ["curl", "-s", "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon + "&current=temperature_2m,relative_humidity_2m,weather_code,apparent_temperature,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,uv_index_max,sunset&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.temp = Math.round(data.current.temperature_2m);
                    root.humidity = Math.round(data.current.relative_humidity_2m);
                    root.weatherCode = data.current.weather_code;
                    root.feelsLike = Math.round(data.current.apparent_temperature);
                    root.windSpeed = Math.round(data.current.wind_speed_10m);
                    root.tempMax = Math.round(data.daily.temperature_2m_max[0]);
                    root.tempMin = Math.round(data.daily.temperature_2m_min[0]);
                    root.uvIndex = Math.round(data.daily.uv_index_max[0]);
                    root.sunsetTime = new Date(data.daily.sunset[0]).toLocaleTimeString(Qt.locale(), "h:mm AP");
                } catch (e) {
                    console.log("weather parse failed:", e);
                }
            }
        }
    }

    Process {
        id: cpuStatProc
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const firstLine = this.text.split("\n")[0];
                const parts = firstLine.trim().split(/\s+/).slice(1).map(Number);
                if (parts.length < 4) return;
                const idle = parts[3] + (parts[4] || 0);
                const total = parts.reduce((a, b) => a + b, 0);
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
                if (!totalMatch || !availMatch) return;
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
                const lines = this.text.trim().split("\n").filter((l) => l.length > 0);
                const disks = [];
                for (const line of lines) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 3) continue;
                    const name = parts[0].replace(/^[\s│├└─]+/, "");
                    const size = parseInt(parts[1]);
                    const type = parts[2];
                    const isWholeDisk = type === "disk" && !/^(zram|loop)/.test(name);
                    const isExtraPartition = type === "part" && root.extraDiskPartitions.includes(name);
                    if (!isWholeDisk && !isExtraPartition) continue;
                    disks.push({ "name": name, "size": size, "used": 0 });
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
                const disks = root._lsblkDisks.map((d) => ({ "name": d.name, "size": d.size, "used": 0, "mounted": false }));
                for (const line of lines) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 2) continue;
                    const source = parts[0];
                    if (!source.startsWith("/dev/")) continue;
                    const used = parseInt(parts[1]);
                    if (isNaN(used)) continue;
                    const devName = source.slice(5);
                    const exactDisk = disks.find((d) => d.name === devName);
                    if (exactDisk) { exactDisk.used += used; exactDisk.mounted = true; }
                    let base = devName;
                    let m = devName.match(/^(nvme\d+n\d+|mmcblk\d+)p\d+$/);
                    if (m) { base = m[1]; } else {
                        m = devName.match(/^([a-z]+)\d+$/);
                        if (m) base = m[1];
                    }
                    const disk = disks.find((d) => d.name === base);
                    if (disk && disk !== exactDisk) { disk.used += used; disk.mounted = true; }
                }
                root.diskList = disks;
                if (!disks.find((d) => d.name === root.selectedDisk) && disks.length > 0)
                    root.selectedDisk = disks[0].name;
            }
        }
    }

    readonly property string wallpaperPath: {
        const p = wallpaperFile.text().trim();
        return p.length > 0 ? p : (Quickshell.env("HOME") + "/.config/quickshell/luciddocks/fallback.jpg");
    }

    WlSessionLock {
        id: sessionLock

        locked: root.locked

        surface: Component {
        WlSessionLockSurface {
        id: overlay

        color: "black"

        Image {
            id: bgImage
            anchors.fill: parent
            source: "file://" + root.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        MultiEffect {
            id: bgBlur
            anchors.fill: parent
            source: bgImage
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 0
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.shadow, 0.35)
        }

        Rectangle {
            id: box

            readonly property int expandDuration: 650
            readonly property int expandedWidth: 1000
            readonly property real colCBottom: lockPower.y + lockPower.height
            readonly property int expandedHeight: Math.max(600, colCBottom + colMargin)
            readonly property int clickDuration: Theme.durMedium + Theme.durQuick * 2
            readonly property int colMargin: 20
            readonly property int colGap: 16
            readonly property int colWidth: (box.expandedWidth - box.colMargin * 2 - box.colGap * 2) / 3
            property bool fullyExpanded: false
            property real shackleAngle: -38

            width: 80
            height: 80
            radius: Theme.radiusLg
            color: Theme.withBlur(Theme.bgOpaque)
            anchors.centerIn: parent
            scale: 0

            Binding {
                target: box
                property: "height"
                value: box.expandedHeight
                when: box.fullyExpanded
            }

            Behavior on height {
                enabled: box.fullyExpanded
                NumberAnimation {
                    duration: Theme.ms(300)
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: lockIcon
                anchors.centerIn: parent
                width: 32
                height: 32

                Shape {
                    width: 24
                    height: 24
                    scale: 32 / 24
                    anchors.centerIn: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        id: iconPath
                        fillColor: Theme.text
                        strokeWidth: 0
                        PathSvg {
                            path: "M6,10 H18 A1,1 0 0 1 19,11 V21 A1,1 0 0 1 18,22 H6 A1,1 0 0 1 5,21 V11 A1,1 0 0 1 6,10 Z M12,14a1.5 1.5 0 0 1 1 2.63V18a1 1 0 1 1-2 0v-1.37A1.5 1.5 0 0 1 12 14Z"
                        }
                    }
                }

                Shape {
                    width: 24
                    height: 24
                    scale: 32 / 24
                    anchors.centerIn: parent
                    preferredRendererType: Shape.CurveRenderer

                    transform: Rotation {
                        origin.x: 6
                        origin.y: 10
                        angle: box.shackleAngle
                    }

                    ShapePath {
                        id: shacklePath
                        fillColor: "transparent"
                        strokeColor: Theme.text
                        strokeWidth: 2.4
                        capStyle: ShapePath.RoundCap
                        PathSvg {
                            path: "M6,10 V8 A6,6 0 0 1 18,8 V10"
                        }
                    }
                }
            }

            Rectangle {
                id: lockClock

                anchors.top: box.top
                anchors.left: box.left
                anchors.margins: box.colMargin
                width: box.colWidth
                height: 210
                radius: 20
                color: Theme.withBlur(Theme.accentContainer)
                opacity: 0
                visible: opacity > 0.01

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        id: lockClockTimeText
                        width: lockClock.width
                        text: new Date().toLocaleTimeString(Qt.locale(), "h:mm:ss AP")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(42)
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        id: lockClockDateText
                        width: lockClock.width
                        text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.bold: false
                        font.pixelSize: Theme.fs(15)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Timer {
                    interval: 1000
                    running: root.locked
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        lockClockTimeText.text = new Date().toLocaleTimeString(Qt.locale(), "h:mm:ss AP");
                        lockClockDateText.text = new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d");
                        root.clockTick++;
                    }
                }
            }

            Rectangle {
                id: weatherCard

                readonly property var infoFields: [
                    {
                        "label": "WIND",
                        "key": "wind"
                    },
                    {
                        "label": "HUMIDITY",
                        "key": "humidity"
                    },
                    {
                        "label": "HIGH",
                        "key": "high"
                    },
                    {
                        "label": "LOW",
                        "key": "low"
                    },
                    {
                        "label": "UV INDEX",
                        "key": "uv"
                    },
                    {
                        "label": "SUNSET",
                        "key": "sunset"
                    }
                ]

                function infoValue(key) {
                    switch (key) {
                    case "wind":
                        return root.windSpeed + " km/h";
                    case "humidity":
                        return root.humidity + "%";
                    case "high":
                        return root.tempMax + "°C";
                    case "low":
                        return root.tempMin + "°C";
                    case "uv":
                        return String(root.uvIndex);
                    case "sunset":
                        return root.sunsetTime || "—";
                    default:
                        return "—";
                    }
                }

                anchors.top: lockClock.bottom
                anchors.left: lockClock.left
                anchors.topMargin: 10
                width: lockClock.width
                height: weatherColumn.implicitHeight + 28
                radius: Theme.radiusLg
                color: Theme.withBlur(Theme.cContainer)
                opacity: 0
                visible: opacity > 0.01

                Column {
                    id: weatherColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 14
                    spacing: 14

                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 999
                        color: Theme.accentContainer
                        anchors.verticalCenter: parent.verticalCenter

                        Item {
                            id: weatherIconBox

                            readonly property string category: root.weatherIconCategory(root.weatherCode, root.isNight)
                            readonly property bool isPartly: category === "partly" || category === "partly-night"

                            width: 22
                            height: 22
                            anchors.centerIn: parent

                            // sun (day, clear/partly)
                            WeatherGlyph {
                                svgPath: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z M12 6L12 4 M12 18L12 20 M18 12L20 12 M6 12L4 12 M16.24 7.76L17.66 6.34 M7.76 7.76L6.34 6.34 M16.24 16.24L17.66 17.66 M7.76 16.24L6.34 17.66"
                                anchors.horizontalCenterOffset: weatherIconBox.isPartly ? 4 : 0
                                anchors.verticalCenterOffset: weatherIconBox.isPartly ? -4 : 0
                                scale: (weatherIconBox.category === "sunny" ? 22 : 13) / 24
                                opacity: (weatherIconBox.category === "sunny" || weatherIconBox.category === "partly") ? 1 : 0

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: Theme.ms(14000)
                                    loops: Animation.Infinite
                                    running: weatherIconBox.category === "sunny" || weatherIconBox.category === "partly"
                                }
                            }

                            // moon (night, clear/partly)
                            WeatherGlyph {
                                svgPath: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z M17.5 5.5v3M16 7h3 M20.5 10.5v2M19.5 11.5h2 M6 6.5v2M5 7.5h2"
                                anchors.horizontalCenterOffset: weatherIconBox.isPartly ? 4 : 0
                                anchors.verticalCenterOffset: weatherIconBox.isPartly ? -4 : 0
                                scale: (weatherIconBox.category === "clear-night" ? 22 : 13) / 24
                                opacity: (weatherIconBox.category === "clear-night" || weatherIconBox.category === "partly-night") ? 1 : 0

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: Theme.ms(40000)
                                    loops: Animation.Infinite
                                    running: weatherIconBox.category === "clear-night" || weatherIconBox.category === "partly-night"
                                }
                            }

                            // plain cloud (overcast, or paired with sun/moon)
                            WeatherGlyph {
                                svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"
                                anchors.horizontalCenterOffset: weatherIconBox.isPartly ? -3 : 0
                                anchors.verticalCenterOffset: weatherIconBox.isPartly ? 3 : 0
                                scale: (weatherIconBox.category === "cloudy" ? 22 : 15) / 24
                                opacity: (weatherIconBox.category === "cloudy" || weatherIconBox.isPartly) ? 1 : 0
                            }

                            // cloud + rain
                            WeatherGlyph {
                                id: rainGlyph

                                svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z M8 20L6.5 23.5 M12.5 20L11 23.5 M17 20L15.5 23.5"
                                scale: 22 / 24
                                opacity: weatherIconBox.category === "rain" ? 1 : 0

                                transform: Translate {
                                    SequentialAnimation on y {
                                        loops: Animation.Infinite
                                        running: weatherIconBox.category === "rain"

                                        NumberAnimation {
                                            from: 0
                                            to: 1.6
                                            duration: Theme.ms(450)
                                            easing.type: Easing.InQuad
                                        }
                                        NumberAnimation {
                                            from: 1.6
                                            to: 0
                                            duration: Theme.ms(0)
                                        }
                                    }
                                }
                            }

                            // cloud + snow
                            WeatherGlyph {
                                svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z M8 20.4v2.6M6.7 21.7h2.6 M12.5 20.4v2.6M11.2 21.7h2.6 M17 20.4v2.6M15.7 21.7h2.6"
                                scale: 22 / 24
                                opacity: weatherIconBox.category === "snow" ? 1 : 0

                                transform: Translate {
                                    SequentialAnimation on x {
                                        loops: Animation.Infinite
                                        running: weatherIconBox.category === "snow"

                                        NumberAnimation {
                                            from: 0
                                            to: 1.4
                                            duration: Theme.ms(900)
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            from: 1.4
                                            to: -1.4
                                            duration: Theme.ms(1800)
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            from: -1.4
                                            to: 0
                                            duration: Theme.ms(900)
                                            easing.type: Easing.InOutSine
                                        }
                                    }
                                }
                            }

                            // cloud + fog
                            WeatherGlyph {
                                svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z M6 20H11M13 20H19 M5.5 21.7H10.5M12.5 21.7H19 M6 23.4H11M13 23.4H18.5"
                                scale: 22 / 24
                                opacity: weatherIconBox.category === "fog" ? 1 : 0

                                transform: Translate {
                                    SequentialAnimation on x {
                                        loops: Animation.Infinite
                                        running: weatherIconBox.category === "fog"

                                        NumberAnimation {
                                            from: 0
                                            to: 1.8
                                            duration: Theme.ms(1800)
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            from: 1.8
                                            to: -1.8
                                            duration: Theme.ms(3600)
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            from: -1.8
                                            to: 0
                                            duration: Theme.ms(1800)
                                            easing.type: Easing.InOutSine
                                        }
                                    }
                                }
                            }

                            // cloud + storm (rumbles periodically)
                            WeatherGlyph {
                                svgPath: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z M13.5 19L11.2 21.8L13 21.8L10.5 24"
                                scale: 22 / 24
                                opacity: weatherIconBox.category === "storm" ? 1 : 0

                                SequentialAnimation on rotation {
                                    loops: Animation.Infinite
                                    running: weatherIconBox.category === "storm"

                                    NumberAnimation {
                                        from: 0
                                        to: -4
                                        duration: Theme.ms(80)
                                        easing.type: Easing.OutQuad
                                    }
                                    NumberAnimation {
                                        from: -4
                                        to: 4
                                        duration: Theme.ms(120)
                                        easing.type: Easing.InOutQuad
                                    }
                                    NumberAnimation {
                                        from: 4
                                        to: 0
                                        duration: Theme.ms(80)
                                        easing.type: Easing.OutQuad
                                    }
                                    PauseAnimation {
                                        duration: Theme.ms(2200)
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: root.temp + "°C"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fontHeadline
                        }

                        Text {
                            text: root.weatherDesc(root.weatherCode)
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                        }

                        Text {
                            text: "Feels like " + root.feelsLike + "°C"
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                }

                Grid {
                    width: parent.width
                    columns: 2
                    rowSpacing: 14
                    columnSpacing: 14

                    Repeater {
                        model: weatherCard.infoFields

                        Column {
                            required property var modelData

                            width: (parent.width - 14) / 2
                            spacing: 3

                            Text {
                                text: modelData.label
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(10)
                            }

                            Text {
                                width: parent.width
                                text: weatherCard.infoValue(modelData.key)
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(13)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                }
            }

            Rectangle {
                id: sysInfoCard

                readonly property var infoFields: [
                    {
                        "label": "OS",
                        "key": "os"
                    },
                    {
                        "label": "KERNEL",
                        "key": "kernel"
                    },
                    {
                        "label": "SHELL",
                        "key": "shell"
                    },
                    {
                        "label": "WM",
                        "key": "wm"
                    },
                    {
                        "label": "UPTIME",
                        "key": "uptime"
                    },
                    {
                        "label": "HOST",
                        "key": "host"
                    }
                ]

                function infoValue(key) {
                    if (key === "host")
                        return root.sysHostname || "—";
                    return root.fastfetchData[key] || "—";
                }

                anchors.top: box.top
                anchors.left: lockClock.right
                anchors.topMargin: box.colMargin
                anchors.leftMargin: box.colGap
                width: box.colWidth
                height: sysColumn.implicitHeight + 62
                radius: 20
                color: Theme.withBlur(Theme.bgTile)
                opacity: 0
                visible: opacity > 0.01

                Column {
                    id: sysColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 16
                    spacing: 14

                    Row {
                        width: parent.width
                        spacing: 14

                        Rectangle {
                            id: avatarBox

                            width: 56
                            height: 56
                            radius: 28
                            color: Theme.accentContainer
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: avatarImage
                                anchors.fill: parent
                                source: root.avatarPath.length > 0 ? "file://" + root.avatarPath : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                visible: status === Image.Ready
                            }

                            Shape {
                                anchors.centerIn: parent
                                visible: !avatarImage.visible
                                width: 24
                                height: 24
                                scale: 28 / 24
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: Theme.accent
                                    strokeWidth: 0
                                    PathSvg {
                                        path: "M12,4A4,4 0 0,1 16,8A4,4 0 0,1 12,12A4,4 0 0,1 8,8A4,4 0 0,1 12,4M12,14C16.42,14 20,15.79 20,18V20H4V18C4,15.79 7.58,14 12,14Z"
                                    }
                                }
                            }
                        }

                        Column {
                            spacing: 3
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "Welcome back"
                                color: Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(12)
                            }

                            Text {
                                text: root.sysUsername || "—"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(19)
                            }
                        }
                    }

                    Rectangle {
                        id: passwordBar

                        property real shakeOffset: 0
                        property bool wrong: false
                        property bool authenticating: false

                        width: parent.width
                        height: 44
                        radius: 999
                        color: passwordBar.wrong ? Theme.alpha(Theme.error, 0.16) : (passwordInput.activeFocus ? Theme.bgHigh : Theme.withBlur(Theme.bgSunken))
                        border.width: passwordBar.wrong ? 1 : 0
                        border.color: Theme.error
                        scale: 1 + passwordBar.focusLift * 0.015 + passwordBar.typePulse
                        transform: Translate {
                            x: passwordBar.shakeOffset
                        }

                        property real focusLift: passwordInput.activeFocus ? 1 : 0
                        property real typePulse: 0

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.ms(150)
                            }
                        }

                        Behavior on focusLift {
                            NumberAnimation {
                                duration: Theme.ms(240)
                                easing.type: Easing.OutCubic
                            }
                        }

                        SequentialAnimation {
                            id: typeBump

                            NumberAnimation {
                                target: passwordBar
                                property: "typePulse"
                                to: 0.02
                                duration: Theme.ms(70)
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: passwordBar
                                property: "typePulse"
                                to: 0
                                duration: Theme.ms(160)
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: parent.radius + 3
                            color: "transparent"
                            border.width: 1.5
                            border.color: Theme.accent
                            opacity: passwordBar.focusLift * 0.55

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.ms(240)
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        function shake() {
                            shakeAnim.restart();
                        }

                        property int failCount: 0
                        property bool cooldown: false

                        function tryUnlock() {
                            if (authenticating || cooldown || passwordInput.text.length === 0)
                                return;

                            authenticating = true;
                            authTimeoutTimer.restart();
                            authProc.checkPassword(passwordInput.text);
                        }

                        Timer {
                            id: authTimeoutTimer

                            interval: 10000
                            onTriggered: {
                                if (authProc.running)
                                    authProc.running = false;
                            }
                        }

                        Timer {
                            id: cooldownTimer

                            interval: 4000
                            onTriggered: passwordBar.cooldown = false
                        }

                        Process {
                            id: authProc

                            property string pendingPassword: ""

                            function checkPassword(pw) {
                                pendingPassword = pw;
                                running = true;
                            }

                            command: ["sudo", "-S", "-k", "-p", "", "-v"]
                            stdinEnabled: true
                            onStarted: {
                                write(pendingPassword + "\n");
                                pendingPassword = "";
                                closeStdinTimer.start();
                            }
                            onExited: (exitCode) => {
                                authTimeoutTimer.stop();
                                passwordBar.authenticating = false;
                                passwordInput.text = "";
                                stdinEnabled = true;
                                if (exitCode === 0) {
                                    passwordBar.wrong = false;
                                    passwordBar.failCount = 0;
                                    if (!root.unlocking) {
                                        root.unlocking = true;
                                        box.fullyExpanded = false;
                                        collapseAnim.start();
                                    }
                                } else {
                                    passwordBar.wrong = true;
                                    passwordBar.shake();
                                    passwordBar.failCount += 1;
                                    if (passwordBar.failCount >= 2) {
                                        passwordBar.cooldown = true;
                                        cooldownTimer.restart();
                                    }
                                }
                            }
                        }

                        Timer {
                            id: closeStdinTimer

                            interval: 100
                            onTriggered: authProc.stdinEnabled = false
                        }

                        SequentialAnimation {
                            id: shakeAnim

                            NumberAnimation {
                                target: passwordBar
                                property: "shakeOffset"
                                to: -6
                                duration: Theme.ms(45)
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: passwordBar
                                property: "shakeOffset"
                                to: 6
                                duration: Theme.ms(90)
                                easing.type: Easing.InOutCubic
                            }
                            NumberAnimation {
                                target: passwordBar
                                property: "shakeOffset"
                                to: -4
                                duration: Theme.ms(90)
                                easing.type: Easing.InOutCubic
                            }
                            NumberAnimation {
                                target: passwordBar
                                property: "shakeOffset"
                                to: 4
                                duration: Theme.ms(90)
                                easing.type: Easing.InOutCubic
                            }
                            NumberAnimation {
                                target: passwordBar
                                property: "shakeOffset"
                                to: 0
                                duration: Theme.ms(60)
                                easing.type: Easing.OutCubic
                            }
                        }

                        Item {
                            width: 14
                            height: 14
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter

                            Shape {
                                width: 24
                                height: 24
                                scale: 14 / 24
                                anchors.centerIn: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: Theme.subtext
                                    strokeWidth: 0
                                    PathSvg {
                                        path: "M6 10V8a6 6 0 1 1 12 0v2h1a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V11a1 1 0 0 1 1-1h1Zm2 0h8V8a4 4 0 1 0-8 0v2Zm4 4a1.5 1.5 0 0 1 1 2.63V18a1 1 0 1 1-2 0v-1.37A1.5 1.5 0 0 1 12 14Z"
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password"
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            visible: passwordInput.text.length === 0 && !passwordInput.activeFocus
                        }

                        TextInput {
                            id: passwordInput

                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            anchors.right: passwordSubmit.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            enabled: !passwordBar.authenticating && !passwordBar.cooldown
                            color: "transparent"
                            selectionColor: "transparent"
                            selectedTextColor: "transparent"
                            cursorDelegate: Rectangle {
                                width: 2
                                color: Theme.accent
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(15)
                            font.letterSpacing: 2
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            selectByMouse: false
                            clip: true
                            Keys.onReturnPressed: passwordBar.tryUnlock()
                            onTextChanged: {
                                passwordBar.wrong = false;
                                if (text.length > 0)
                                    typeBump.restart();
                            }
                        }

                        Row {
                            id: dotsRow

                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            add: Transition {
                                NumberAnimation {
                                    properties: "scale"
                                    from: 0
                                    to: 1
                                    duration: Theme.ms(220)
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 6
                                }
                            }

                            Repeater {
                                model: passwordInput.text.length

                                Item {
                                    id: dotDelegate

                                    width: 10
                                    height: 10
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                                    readonly property bool selected: index >= passwordInput.selectionStart && index < passwordInput.selectionEnd

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        radius: 999
                                        color: Theme.accent
                                        opacity: dotDelegate.selected ? 0.35 : 0

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.ms(120)
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 999
                                        color: dotDelegate.selected ? Theme.accent : Theme.text
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: passwordSubmit

                            width: 32
                            height: 32
                            radius: 999
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: submitArea.containsMouse ? Theme.accentHover : Theme.accent
                            scale: submitArea.pressed ? 0.9 : 1

                            Shape {
                                width: 24
                                height: 24
                                scale: 14 / 24
                                anchors.centerIn: parent
                                preferredRendererType: Shape.CurveRenderer
                                visible: !passwordBar.authenticating

                                ShapePath {
                                    fillColor: Theme.onAccent
                                    strokeWidth: 0
                                    PathSvg {
                                        path: "M4 11h12.17l-5.59-5.59L12 4l8 8-8 8-1.41-1.41L16.17 13H4v-2Z"
                                    }
                                }
                            }

                            Shape {
                                width: 24
                                height: 24
                                scale: 16 / 24
                                anchors.centerIn: parent
                                visible: passwordBar.authenticating
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    strokeColor: Theme.onAccent
                                    strokeWidth: 2.4
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    PathSvg {
                                        path: "M12 3a9 9 0 0 1 9 9"
                                    }
                                }

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: Theme.ms(700)
                                    loops: Animation.Infinite
                                    running: passwordBar.authenticating
                                }
                            }

                            MouseArea {
                                id: submitArea

                                anchors.fill: parent
                                enabled: !passwordBar.authenticating
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: passwordBar.tryUnlock()
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.ms(100)
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                    Grid {
                        width: parent.width
                        columns: 2
                        rowSpacing: 16
                        columnSpacing: 16

                        Repeater {
                            model: sysInfoCard.infoFields

                            Column {
                                required property var modelData

                                width: (parent.width - 16) / 2
                                spacing: 3

                                Text {
                                    text: modelData.label
                                    color: Theme.subtext
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fs(10)
                                }

                                Text {
                                    width: parent.width
                                    text: sysInfoCard.infoValue(modelData.key)
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fs(13)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: connectivityCard

                anchors.top: sysInfoCard.bottom
                anchors.left: sysInfoCard.left
                anchors.topMargin: box.colGap
                width: sysInfoCard.width
                height: connectivityColumn.implicitHeight + 24
                radius: 20
                color: Theme.withBlur(Theme.bgTile)
                opacity: 0
                visible: opacity > 0.01

                Column {
                    id: connectivityColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 4

                    ConnRow {
                        active: root.wifiConnected || root.ethernetConnected
                        label: root.wifiLabel
                        statusText: root.ethernetConnected ? "Wired" : (root.wifiConnected ? "Connected" : "Off")
                        iconPath: root.ethernetConnected ? "M4,6H20V16H4M20,18A2,2 0 0,0 22,16V6C22,4.89 21.1,4 20,4H4C2.89,4 2,4.89 2,6V16A2,2 0 0,0 4,18H0V20H24V18H20Z" : "M12,21L15.6,16.2C14.6,15.45 13.35,15 12,15C10.65,15 9.4,15.45 8.4,16.2L12,21M12,3C7.95,3 4.21,4.34 1.2,6.6L3,9C5.5,7.12 8.62,6 12,6C15.38,6 18.5,7.12 21,9L22.8,6.6C19.79,4.34 16.05,3 12,3M12,9C9.3,9 6.81,9.89 4.8,11.4L6.6,13.8C8.1,12.67 9.97,12 12,12C14.03,12 15.9,12.67 17.4,13.8L19.2,11.4C17.19,9.89 14.7,9 12,9Z"
                    }

                    ConnRow {
                        active: root.btConnectedDevices.length > 0
                        label: root.btLabel
                        statusText: !root.btEnabled ? "Off" : (root.btConnectedDevices.length > 0 ? "Connected" : "On")
                        iconPath: "M17.71,7.71L12,2H11V9.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L11,14.41V22H12L17.71,16.29L13.41,12L17.71,7.71M13,5.83L15.17,8L13,10.17V5.83M13,13.83L15.17,16L13,18.17V13.83Z"
                    }
                }
            }

            Rectangle {
                id: lockMpris

                anchors.top: connectivityCard.bottom
                anchors.left: connectivityCard.left
                anchors.topMargin: box.colGap
                width: sysInfoCard.width
                height: 150
                radius: 20
                color: Theme.bg
                clip: true
                opacity: 0
                visible: opacity > 0.01

                Item {
                    id: mprisArtLayer
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: mprisMask
                    }

                    Image {
                        id: mprisArtBg
                        anchors.fill: parent
                        source: root.mprisPlayer ? root.mprisPlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: mprisArtBg
                        visible: mprisArtBg.visible
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blurMax: 48
                        blur: 1
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.withBlur(Theme.bgTile)
                        visible: !mprisArtBg.visible
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * 0.5

                        gradient: Gradient {
                            orientation: Gradient.Vertical

                            GradientStop {
                                position: 0
                                color: Theme.alpha(Theme.shadow, 0.7)
                            }

                            GradientStop {
                                position: 1
                                color: Theme.alpha(Theme.shadow, 0)
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * 0.55

                        gradient: Gradient {
                            orientation: Gradient.Vertical

                            GradientStop {
                                position: 0
                                color: Theme.alpha(Theme.shadow, 0)
                            }

                            GradientStop {
                                position: 1
                                color: Theme.alpha(Theme.shadow, 0.75)
                            }
                        }
                    }
                }

                Item {
                    id: mprisMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                    }
                }

                Text {
                    id: mprisNowPlayingLabel

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 14
                    text: "Now playing"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                }

                Text {
                    id: mprisTitleText

                    anchors.top: mprisNowPlayingLabel.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 6
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    horizontalAlignment: Text.AlignHCenter
                    text: root.mprisTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(16)
                    elide: Text.ElideRight
                }

                Text {
                    id: mprisSubtitleText

                    anchors.top: mprisTitleText.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 2
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    horizontalAlignment: Text.AlignHCenter
                    text: root.mprisArtist
                    visible: text.length > 0
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                    elide: Text.ElideRight
                }


                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    spacing: 10

                    Item {
                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 999
                            color: Theme.text
                            opacity: prevMprisArea.containsMouse ? 0.14 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.ms(150); easing.type: Easing.OutCubic }
                            }
                        }

                        Item {
                            width: 17
                            height: 17
                            anchors.centerIn: parent
                            scale: prevMprisArea.pressed ? 0.88 : 1

                            Shape {
                                width: 24
                                height: 24
                                scale: 17 / 24
                                anchors.centerIn: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: Theme.text
                                    strokeWidth: 0
                                    PathSvg { path: "M6 6h2v12H6V6Zm3.5 6 8.5-6v12l-8.5-6Z" }
                                }
                            }

                            Behavior on scale {
                                NumberAnimation { duration: Theme.ms(100); easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: prevMprisArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.mprisPlayer && root.mprisPlayer.canGoPrevious) root.mprisPlayer.previous()
                        }
                    }

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 999
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                        scale: playMprisArea.pressed ? 0.92 : (playMprisArea.containsMouse ? 1.08 : 1)

                        Item {
                            width: 17
                            height: 17
                            anchors.centerIn: parent

                            Shape {
                                width: 24
                                height: 24
                                scale: 17 / 24
                                anchors.centerIn: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: Theme.onAccent
                                    strokeWidth: 0
                                    PathSvg { path: root.mprisIsPlaying ? "M8 6h3v12H8V6Zm5 0h3v12h-3V6Z" : "M8 5v14l11-7L8 5Z" }
                                }
                            }
                        }

                        MouseArea {
                            id: playMprisArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.mprisPlayer && root.mprisPlayer.canTogglePlaying) root.mprisPlayer.togglePlaying()
                        }

                        Behavior on scale {
                            NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic }
                        }
                    }

                    Item {
                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 999
                            color: Theme.text
                            opacity: nextMprisArea.containsMouse ? 0.14 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.ms(150); easing.type: Easing.OutCubic }
                            }
                        }

                        Item {
                            width: 17
                            height: 17
                            anchors.centerIn: parent
                            scale: nextMprisArea.pressed ? 0.88 : 1

                            Shape {
                                width: 24
                                height: 24
                                scale: 17 / 24
                                anchors.centerIn: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: Theme.text
                                    strokeWidth: 0
                                    PathSvg { path: "M18 6h-2v12h2V6Zm-3.5 6L6 6v12l8.5-6Z" }
                                }
                            }

                            Behavior on scale {
                                NumberAnimation { duration: Theme.ms(100); easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: nextMprisArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.mprisPlayer && root.mprisPlayer.canGoNext) root.mprisPlayer.next()
                        }
                    }
                }
            }

            Rectangle {
                id: lockNotifications

                readonly property var notifs: root.notifMod ? root.notifMod.sortedNotifications : []
                readonly property int maxListHeight: 260

                anchors.top: box.top
                anchors.left: connectivityCard.right
                anchors.topMargin: box.colMargin
                anchors.leftMargin: box.colGap
                width: box.colWidth
                height: notifCardColumn.implicitHeight + 32
                radius: 20
                color: Theme.withBlur(Theme.bgTile)
                opacity: 0
                visible: opacity > 0.01

                ScriptModel {
                    id: lockNotifModel

                    values: lockNotifications.notifs
                }

                Column {
                    id: notifCardColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 20

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Notifications"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(13)
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "DND"
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(10)
                            }

                            Rectangle {
                                id: notifDndSwitch

                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                height: 16
                                radius: 999
                                color: (root.notifMod && root.notifMod.dnd) ? Theme.accent : Theme.outlineStrong

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: Theme.bgOpaque
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: (root.notifMod && root.notifMod.dnd) ? parent.width - width - 2 : 2

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Theme.ms(200)
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.notifMod)
                                            root.notifMod.dnd = !root.notifMod.dnd;
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.ms(200)
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: lockNotifications.notifs.length > 0
                            text: lockNotifications.notifs.length === 1 ? "1 notification" : lockNotifications.notifs.length + " notifications"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear all"
                            color: clearArea.containsMouse ? Theme.accentHover : Theme.accent
                            opacity: lockNotifications.notifs.length > 0 ? 1 : 0.35
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(11)

                            MouseArea {
                                id: clearArea

                                anchors.fill: parent
                                anchors.margins: -6
                                enabled: lockNotifications.notifs.length > 0
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

                    Item {
                        width: parent.width
                        height: lockNotifications.maxListHeight

                        Text {
                            anchors.centerIn: parent
                            visible: lockNotifications.notifs.length === 0
                            horizontalAlignment: Text.AlignHCenter
                            text: "No notifications"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                        }

                        ListView {
                            id: notifList

                            property int prevCount: 0

                            anchors.top: parent.top
                            width: parent.width
                            visible: lockNotifications.notifs.length > 0
                            clip: true
                            spacing: 6
                            model: lockNotifModel
                            height: Math.min(lockNotifications.maxListHeight, contentHeight)
                            flickDeceleration: 6000
                            maximumFlickVelocity: 6000
                            delegate: LockNotifCard {
                            }
                            onCountChanged: {
                                if (count > prevCount && contentY > 0)
                                    scrollToNewest.restart();
                                prevCount = count;
                            }

                            NumberAnimation {
                                id: scrollToNewest

                                target: notifList
                                property: "contentY"
                                to: 0
                                duration: Theme.ms(320)
                                easing.type: Easing.OutCubic
                            }

                            removeDisplaced: Transition {
                                NumberAnimation {
                                    properties: "x,y"
                                    duration: Theme.ms(300)
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "opacity"
                                    to: 1
                                    duration: Theme.ms(200)
                                }
                            }

                            remove: Transition {
                                NumberAnimation {
                                    property: "opacity"
                                    to: 0
                                    duration: Theme.ms(200)
                                    easing.type: Easing.InCubic
                                }
                                NumberAnimation {
                                    property: "scale"
                                    to: 0.85
                                    duration: Theme.ms(200)
                                    easing.type: Easing.InCubic
                                }
                                NumberAnimation {
                                    property: "x"
                                    to: 26
                                    duration: Theme.ms(200)
                                    easing.type: Easing.InCubic
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: lockPower

                readonly property var actions: [
                    {
                        "id": "suspend",
                        "label": "Suspend",
                        "iconPath": "M12 3a9 9 0 1 0 8.94 10.06.5.5 0 0 0-.66-.54A7 7 0 1 1 11.48 3.72a.5.5 0 0 0-.54-.66A9.06 9.06 0 0 0 12 3Z"
                    },
                    {
                        "id": "hibernate",
                        "label": "Hibernate",
                        "iconPath": "M9.37 5.51A7.5 7.5 0 0 0 9.1 20.94a7.5 7.5 0 0 0 9.32-5.05.5.5 0 0 0-.58-.65 6 6 0 0 1-7.4-7.4.5.5 0 0 0-.07-.33.5.5 0 0 0-.62-.22 7.53 7.53 0 0 0-.38.22Z"
                    },
                    {
                        "id": "reboot",
                        "label": "Reboot",
                        "iconPath": "M12 4V1L8 5l4 4V6a6 6 0 1 1-6 6H4a8 8 0 1 0 8-8Z"
                    },
                    {
                        "id": "logout",
                        "label": "Log Out",
                        "iconPath": "M10 17v-2H3v-6h7V7l5 5-5 5Zm9 3H12v-2h7V6h-7V4h7a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2Z"
                    },
                    {
                        "id": "shutdown",
                        "label": "Shutdown",
                        "iconPath": "M13 3h-2v10h2V3Zm4.83 2.17-1.42 1.42A6.98 6.98 0 0 1 19 12a7 7 0 1 1-11.66-5.24L5.92 5.34A9 9 0 1 0 21 12a8.97 8.97 0 0 0-3.17-6.83Z"
                    }
                ]

                function runAction(id) {
                    const cmds = {
                        "logout": ["uwsm", "stop"],
                        "suspend": ["systemctl", "suspend"],
                        "shutdown": ["systemctl", "poweroff"],
                        "hibernate": ["systemctl", "hibernate"],
                        "reboot": ["systemctl", "reboot"]
                    };
                    const cmd = cmds[id];
                    if (cmd)
                        Quickshell.execDetached(cmd);
                }

                anchors.top: lockNotifications.bottom
                anchors.left: lockNotifications.left
                anchors.topMargin: box.colGap
                width: lockNotifications.width
                height: powerColumn.implicitHeight + 32
                radius: 20
                color: Theme.withBlur(Theme.bgTile)
                opacity: 0
                visible: opacity > 0.01

                Column {
                    id: powerColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 4

                    Text {
                        text: "Power"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(13)
                        bottomPadding: 6
                    }

                    Repeater {
                        model: lockPower.actions

                        PowerActionRow {
                            required property var modelData

                            iconPath: modelData.iconPath
                            label: modelData.label
                            onTriggered: lockPower.runAction(modelData.id)
                        }
                    }
                }
            }

            Column {
                id: systemStats

                anchors.top: weatherCard.bottom
                anchors.left: lockClock.left
                width: lockClock.width
                anchors.topMargin: 14
                spacing: 8
                opacity: 0
                visible: opacity > 0.01

                Row {
                    width: parent.width
                    spacing: 8

                    StatCard {
                        width: (systemStats.width - 16) / 3
                        label: "BATTERY"
                        valueText: root.batteryPresent ? root.batteryPercent + "%" : "N/A"
                        showBar: root.batteryPresent
                        barPct: root.batteryPercent
                    }

                    StatCard {
                        width: (systemStats.width - 16) / 3
                        label: "RAM"
                        valueText: root.ramHistory.length > 0 ? Math.round(root.ramPercent) + "%" : "—"
                        showChart: true
                        chartHistory: root.ramHistory
                    }

                    StatCard {
                        width: (systemStats.width - 16) / 3
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

                    width: parent.width
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
                                    NumberAnimation { duration: Theme.ms(300) }
                                }
                            }
                        }
                    }
                }
            }

            SequentialAnimation {
                id: appearAnim

                ParallelAnimation {
                    NumberAnimation {
                        target: box
                        property: "scale"
                        to: 1
                        duration: Theme.durMedium
                        easing.type: Theme.easeEmphasized
                    }
                    NumberAnimation {
                        target: bgBlur
                        property: "blur"
                        to: 1
                        duration: Theme.ms(box.clickDuration)
                        easing.type: Theme.easeStandard
                    }
                }

                PauseAnimation {
                    duration: Theme.ms(320)
                }

                ParallelAnimation {
                    SequentialAnimation {
                        NumberAnimation {
                            target: box
                            property: "scale"
                            to: 0.85
                            duration: Theme.durQuick
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: box
                            property: "scale"
                            to: 1
                            duration: Theme.durQuick
                            easing.type: Theme.easeEmphasized
                        }
                    }
                    NumberAnimation {
                        target: box
                        property: "shackleAngle"
                        to: 0
                        duration: Theme.ms(260)
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }
                    SequentialAnimation {
                        ColorAnimation {
                            target: iconPath
                            property: "fillColor"
                            to: Theme.accent
                            duration: Theme.durQuick
                        }
                        ColorAnimation {
                            target: iconPath
                            property: "fillColor"
                            to: Theme.text
                            duration: Theme.durQuick
                        }
                    }
                    SequentialAnimation {
                        ColorAnimation {
                            target: shacklePath
                            property: "strokeColor"
                            to: Theme.accent
                            duration: Theme.durQuick
                        }
                        ColorAnimation {
                            target: shacklePath
                            property: "strokeColor"
                            to: Theme.text
                            duration: Theme.durQuick
                        }
                    }
                }

                PauseAnimation {
                    duration: Theme.ms(200)
                }

                onFinished: expandAnim.start()
            }

            ParallelAnimation {
                id: expandAnim

                onFinished: {
                    box.fullyExpanded = true;
                    passwordInput.forceActiveFocus();
                }

                NumberAnimation {
                    target: box
                    property: "width"
                    to: box.expandedWidth
                    duration: Theme.ms(box.expandDuration)
                    easing.type: Easing.OutExpo
                }
                NumberAnimation {
                    target: box
                    property: "height"
                    to: box.expandedHeight
                    duration: Theme.ms(box.expandDuration)
                    easing.type: Easing.OutExpo
                }
                NumberAnimation {
                    target: lockIcon
                    property: "opacity"
                    to: 0
                    duration: Theme.ms(220)
                    easing.type: Theme.easeStandard
                }

                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(350)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: lockClock
                            property: "opacity"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: lockClock
                            property: "scale"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                    }
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(350)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: sysInfoCard
                            property: "opacity"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: sysInfoCard
                            property: "scale"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                    }
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(350)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: lockNotifications
                            property: "opacity"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: lockNotifications
                            property: "scale"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                    }
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(400)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: weatherCard
                            property: "opacity"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: weatherCard
                            property: "scale"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                    }
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(400)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: connectivityCard
                            property: "opacity"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: connectivityCard
                            property: "scale"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                    }
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(430)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: lockPower
                            property: "opacity"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: lockPower
                            property: "scale"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                    }
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(450)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: systemStats
                            property: "opacity"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: systemStats
                            property: "scale"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                    }
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(450)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: lockMpris
                            property: "opacity"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: lockMpris
                            property: "scale"
                            to: 1
                            duration: Theme.ms(320)
                            easing.type: Theme.easeStandard
                        }
                    }
                }
            }

            SequentialAnimation {
                id: collapseAnim

                ParallelAnimation {
                    NumberAnimation {
                        target: lockClock
                        property: "opacity"
                        to: 0
                        duration: Theme.ms(200)
                        easing.type: Theme.easeStandard
                    }
                    NumberAnimation {
                        target: weatherCard
                        property: "opacity"
                        to: 0
                        duration: Theme.ms(200)
                        easing.type: Theme.easeStandard
                    }
                    NumberAnimation {
                        target: systemStats
                        property: "opacity"
                        to: 0
                        duration: Theme.ms(200)
                        easing.type: Theme.easeStandard
                    }
                    NumberAnimation {
                        target: sysInfoCard
                        property: "opacity"
                        to: 0
                        duration: Theme.ms(200)
                        easing.type: Theme.easeStandard
                    }
                    NumberAnimation {
                        target: connectivityCard
                        property: "opacity"
                        to: 0
                        duration: Theme.ms(200)
                        easing.type: Theme.easeStandard
                    }
                    NumberAnimation {
                        target: lockMpris
                        property: "opacity"
                        to: 0
                        duration: Theme.ms(200)
                        easing.type: Theme.easeStandard
                    }
                    NumberAnimation {
                        target: lockNotifications
                        property: "opacity"
                        to: 0
                        duration: Theme.ms(200)
                        easing.type: Theme.easeStandard
                    }
                    NumberAnimation {
                        target: lockPower
                        property: "opacity"
                        to: 0
                        duration: Theme.ms(200)
                        easing.type: Theme.easeStandard
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: box
                        property: "width"
                        to: 80
                        duration: Theme.ms(500)
                        easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: box
                        property: "height"
                        to: 80
                        duration: Theme.ms(500)
                        easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: lockIcon
                        property: "opacity"
                        to: 1
                        duration: Theme.ms(260)
                        easing.type: Theme.easeStandard
                    }
                }

                PauseAnimation {
                    duration: Theme.ms(180)
                }

                ParallelAnimation {
                    SequentialAnimation {
                        NumberAnimation {
                            target: box
                            property: "scale"
                            to: 0.85
                            duration: Theme.durQuick
                            easing.type: Theme.easeStandard
                        }
                        NumberAnimation {
                            target: box
                            property: "scale"
                            to: 1
                            duration: Theme.durQuick
                            easing.type: Theme.easeEmphasized
                        }
                    }
                    SequentialAnimation {
                        ColorAnimation {
                            target: iconPath
                            property: "fillColor"
                            to: Theme.accent
                            duration: Theme.durQuick
                        }
                        ColorAnimation {
                            target: iconPath
                            property: "fillColor"
                            to: Theme.text
                            duration: Theme.durQuick
                        }
                    }
                    SequentialAnimation {
                        ColorAnimation {
                            target: shacklePath
                            property: "strokeColor"
                            to: Theme.accent
                            duration: Theme.durQuick
                        }
                        ColorAnimation {
                            target: shacklePath
                            property: "strokeColor"
                            to: Theme.text
                            duration: Theme.durQuick
                        }
                    }
                }

                NumberAnimation {
                    target: box
                    property: "shackleAngle"
                    to: -38
                    duration: Theme.ms(240)
                    easing.type: Easing.OutCubic
                }

                PauseAnimation {
                    duration: Theme.ms(260)
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: box
                        property: "scale"
                        to: 0
                        duration: Theme.ms(260)
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: bgBlur
                        property: "blur"
                        to: 0
                        duration: Theme.ms(320)
                        easing.type: Theme.easeStandard
                    }
                }

                onFinished: root.locked = false
            }
        }

        Component.onCompleted: {
            box.fullyExpanded = false;
            box.width = 80;
            box.height = 80;
            box.scale = 0;
            box.shackleAngle = -38;
            iconPath.fillColor = Theme.text;
            shacklePath.strokeColor = Theme.text;
            lockIcon.opacity = 1;
            bgBlur.blur = 0;
            lockClock.opacity = 0;
            weatherCard.opacity = 0;
            systemStats.opacity = 0;
            sysInfoCard.opacity = 0;
            lockMpris.opacity = 0;
            connectivityCard.opacity = 0;
            lockNotifications.opacity = 0;
            lockPower.opacity = 0;
            lockClock.scale = 0.94;
            weatherCard.scale = 0.94;
            systemStats.scale = 0.94;
            sysInfoCard.scale = 0.94;
            lockMpris.scale = 0.94;
            connectivityCard.scale = 0.94;
            lockNotifications.scale = 0.94;
            lockPower.scale = 0.94;
            appearAnim.start();
        }
        }
        }
    }

    Connections {
        target: root
        function onLockedChanged() {
            if (root.locked) {
                statsTimer.restart();
                lsblkProc.running = true;
                weatherTimer.restart();
                sysInfoTimer.restart();
            } else {
                statsTimer.stop();
                weatherTimer.stop();
                sysInfoTimer.stop();
                root.unlocking = false;
            }
        }
    }

    component ConnRow: Item {
        id: connRow

        property bool active: false
        property string iconPath: ""
        property string label: ""
        property string statusText: ""

        width: parent.width
        height: 48

        Rectangle {
            width: 32
            height: 32
            radius: 16
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: connRow.active ? Theme.accentContainer : Theme.bgHigh

            Shape {
                width: 24
                height: 24
                scale: 16 / 24
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: connRow.active ? Theme.accent : Theme.subtext
                    strokeWidth: 0
                    PathSvg {
                        path: connRow.iconPath
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 44
            anchors.right: statusLabel.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: connRow.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(12)
            elide: Text.ElideRight
        }

        Text {
            id: statusLabel

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: connRow.statusText
            color: connRow.active ? Theme.accent : Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
        }
    }

    component PowerActionRow: Item {
        id: actionRow

        property string iconPath: ""
        property string label: ""
        readonly property bool hovered: hoverHandler.hovered
        readonly property bool pressed: tapHandler.pressed

        signal triggered

        width: parent.width
        height: 40

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: actionRow.hovered ? Theme.withBlur(Theme.bgHover) : "transparent"
            scale: actionRow.pressed ? 0.98 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(150)
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(100)
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            width: 32
            height: 32
            radius: 16
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.bgHigh

            Shape {
                width: 24
                height: 24
                scale: 16 / 24
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Theme.accent
                    strokeWidth: 0
                    PathSvg {
                        path: actionRow.iconPath
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 48
            anchors.verticalCenter: parent.verticalCenter
            text: actionRow.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fs(12)
        }

        HoverHandler {
            id: hoverHandler
        }

        TapHandler {
            id: tapHandler

            onTapped: actionRow.triggered()
        }
    }

    component LockNotifCard: Rectangle {
        id: card

        required property var modelData
        readonly property var notification: modelData
        property string notifAppName: ""
        property string notifSummary: ""
        property string notifBody: ""
        property string notifImage: ""
        property string notifAppIcon: ""
        property int notifUrgency: NotificationUrgency.Normal
        property var notifActions: []
        readonly property string themeIconName: card.notifAppIcon || (card.notifImage.indexOf("image://icon/") === 0 ? card.notifImage.slice(13) : "")
        readonly property string directImage: card.notifImage.indexOf("image://icon/") === 0 ? "" : card.notifImage
        readonly property string iconSource: directImage || (themeIconName ? Quickshell.iconPath(themeIconName) : "")
        readonly property color accentColor: card.notifUrgency === NotificationUrgency.Critical ? Theme.error : (card.notifUrgency === NotificationUrgency.Low ? Theme.subtextDim : Theme.accent)
        readonly property bool isHovered: cardHover.hovered
        property real arrivalGlow: 0
        readonly property real fullHeight: cardColumn.implicitHeight + 20
        property real enterProgress: 0

        function syncNotification() {
            const n = card.notification;
            if (!n)
                return;

            card.notifAppName = n.appName;
            card.notifSummary = n.summary;
            card.notifBody = n.body;
            card.notifImage = n.image;
            card.notifAppIcon = n.appIcon;
            card.notifUrgency = n.urgency;
            card.notifActions = n.actions.map((a) => ({
                        "text": a.text,
                        "invoke": () => a.invoke()
                    }));
        }

        onNotificationChanged: card.syncNotification()
        Component.onCompleted: {
            card.syncNotification();
            if (card.notification && root.markNotifShown(card.notification.id))
                cardEnter.start();
            else
                card.enterProgress = 1;
        }
        // deferred — straight from a delegate handler this crashes mid-incubation
        function relayout() {
            if (card.ListView.view)
                card.ListView.view.forceLayout();
        }

        onHeightChanged: Qt.callLater(card.relayout)

        width: ListView.view.width
        height: card.fullHeight * card.enterProgress
        radius: 14
        color: Theme.withBlur(card.arrivalGlow > 0 ? Theme._mix(Theme.bgHover, card.accentColor, card.arrivalGlow * 0.32) : Theme.bgHover)
        clip: true
        transform: Translate {
            x: (1 - card.enterProgress) * 22
        }

        ParallelAnimation {
            id: cardEnter

            NumberAnimation {
                target: card
                property: "enterProgress"
                from: 0
                to: 1
                duration: Theme.ms(400)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: card
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.ms(300)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: card
                property: "arrivalGlow"
                from: 1
                to: 0
                duration: Theme.ms(900)
                easing.type: Easing.InCubic
            }
        }

        Connections {
            function onAppNameChanged() {
                card.syncNotification();
            }

            function onAppIconChanged() {
                card.syncNotification();
            }

            function onSummaryChanged() {
                card.syncNotification();
            }

            function onBodyChanged() {
                card.syncNotification();
            }

            function onImageChanged() {
                card.syncNotification();
            }

            function onUrgencyChanged() {
                card.syncNotification();
            }

            function onActionsChanged() {
                card.syncNotification();
            }

            target: card.notification
        }

        HoverHandler {
            id: cardHover
        }

        Column {
            id: cardColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 10
            spacing: 4

            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: 20
                    height: 20
                    radius: 999
                    color: Theme.bgTrack
                    anchors.top: parent.top

                    IconImage {
                        id: notifIconImage

                        anchors.fill: parent
                        anchors.margins: 1
                        source: card.iconSource
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !notifIconImage.visible
                        text: (card.notifAppName || "?").charAt(0).toUpperCase()
                        color: card.accentColor
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(9)
                    }
                }

                Column {
                    width: parent.width - 20 - 20 - 16
                    spacing: 1

                    Text {
                        width: parent.width
                        visible: card.notifAppName !== ""
                        text: card.notifAppName
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(9)
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: card.notifSummary
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Item {
                    width: 20
                    height: 20
                    anchors.top: parent.top

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: dismissArea.containsMouse ? Theme.text : Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                        opacity: card.isHovered ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.ms(140)
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.ms(120)
                            }
                        }
                    }

                    MouseArea {
                        id: dismissArea

                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.notification)
                                card.notification.dismiss();
                        }
                    }
                }
            }

            Text {
                width: parent.width
                leftPadding: 28
                visible: card.notifBody !== ""
                text: card.notifBody
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Row {
                leftPadding: 28
                visible: card.notifActions.length > 0
                spacing: 6

                Repeater {
                    model: card.notifActions

                    Rectangle {
                        id: actionChip

                        required property var modelData

                        height: 22
                        width: actionLabel.implicitWidth + 16
                        radius: 999
                        color: card.accentColor
                        opacity: actionArea.containsMouse ? 0.85 : 1

                        Text {
                            id: actionLabel

                            anchors.centerIn: parent
                            text: actionChip.modelData.text
                            color: Theme.bgOpaque
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(10)
                        }

                        MouseArea {
                            id: actionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: actionChip.modelData.invoke()
                        }
                    }
                }
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

        height: 88
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
                        NumberAnimation { duration: Theme.ms(300) }
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

    // one weather icon layer, crossfades on change
    component WeatherGlyph: Shape {
        id: glyph

        property string svgPath: ""

        width: 24
        height: 24
        anchors.centerIn: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.accent
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: glyph.svgPath
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeStandard
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }
        }

        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeStandard
            }
        }

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeStandard
            }
        }
    }
}