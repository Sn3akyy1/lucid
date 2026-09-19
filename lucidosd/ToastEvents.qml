import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs
import "../lucidprefs"

// system events worth a glance, sent to the quick toast: keyboard layout, game
// mode, battery, bluetooth devices, wi-fi, sound output, displays and power
// profile. Nothing is announced until the shell has settled, so a reload or a
// login doesn't replay the current state as news
Scope {
    id: root

    required property var toast
    // the osd, whose caps lock, num lock and microphone changes can come here instead
    property var osd: null

    property bool armed: false

    readonly property string batteryBody: "M16 4h-2V2h-4v2H8a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2Z"
    // the toast fills odd-even, so these cut their marks out of the solid body
    readonly property string chargingPath: root.batteryBody + "M13 7l-4 6.5h3L11 18l4-6.5h-3Z"
    readonly property string batteryAlertPath: root.batteryBody + "M11 7h2v6h-2ZM11 15h2v2h-2Z"

    function send(key, icon, label, detail, warn, ms) {
        if (!root.armed)
            return ;

        root.toast.enqueue({
            "key": key,
            "icon": icon,
            "label": label,
            "detail": detail || "",
            "warn": warn === true,
            "ms": ms || 0
        });
    }

    // an outlined battery filled to the charge
    function batteryPath(pct) {
        const top = Math.round((19 - 12 * Math.max(0.1, Math.min(1, pct / 100))) * 10) / 10;
        return root.batteryBody + "M8 6h8v14H8ZM9 " + top + "h6V19H9Z";
    }

    function glyphPath(kind) {
        glyphs.kind = kind;
        return glyphs.path;
    }

    DeviceGlyph {
        id: glyphs

        visible: false
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: {
            root.seed();
            root.armed = true;
        }
    }

    // whatever holds when the shell settles is the baseline, not an event
    function seed() {
        root.chargerState = root.hasBattery ? (UPower.onBattery ? 0 : 1) : -1;
        root.lowWarned = (root.hasBattery && UPower.onBattery) ? root.thresholdFor(root.batteryPct) : 101;
        root.fullAnnounced = root.batteryFull;
        root.profile = PowerProfiles.profile;
        root.wifiName = root.liveWifiName;
        root.sinkName = root.liveSink ? root.liveSink.name : "";
        root.btLast = root.liveBtConnected;
    }

    // keyboard layout. One switch reports every keyboard hyprland knows, the
    // virtual ones too, and they need not agree - so it reads the main one once
    // the burst is over, the same keyboard the bar's indicator shows
    property string layoutName: ""

    Timer {
        id: layoutSettle

        interval: 150
        onTriggered: {
            if (layoutProc.running)
                layoutSettle.restart();
            else
                layoutProc.running = true;
        }
    }

    Process {
        id: layoutProc

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

                    const name = kb.active_keymap || "";
                    if (root.layoutName !== "" && name !== root.layoutName && Prefs.toastOnLayout)
                        root.send("layout", root.glyphPath("keyboard"), name, "Keyboard layout");

                    root.layoutName = name;
                } catch (e) {
                }
            }
        }

    }

    // displays: hyprland sends a v1 and a v2 form of each; the key folds them
    // into one toast, and the v2 description is kept for whichever comes last
    property var displayDescriptions: ({})

    function announceDisplay(added, name, description) {
        if (description !== "")
            root.displayDescriptions[name] = description;

        if (!Prefs.toastOnDisplays)
            return ;

        root.send("display-" + name, root.glyphPath("desktop"), root.displayDescriptions[name] || name, added ? "Display connected" : "Display disconnected");
    }

    Connections {
        function onRawEvent(event) {
            switch (event.name) {
            case "activelayout":
                layoutSettle.restart();
                break;
            case "monitoradded":
            case "monitorremoved":
                root.announceDisplay(event.name === "monitoradded", event.data, "");
                break;
            case "monitoraddedv2":
            case "monitorremovedv2":
                const parts = event.data.split(",");
                root.announceDisplay(event.name === "monitoraddedv2", parts[1] || parts[0], parts.slice(2).join(","));
                break;
            }
        }

        target: Hyprland
    }

    // game mode is on while the file its status command tests exists; FileView
    // reports a create or a delete as a change, then loaded or loadFailed
    property int gameModeState: -1
    property real gameModeAt: 0

    function setGameMode(on) {
        if (root.gameModeState === on)
            return ;

        const known = root.gameModeState !== -1;
        root.gameModeState = on;
        if (!known)
            return ;

        root.gameModeAt = Date.now();
        if (Prefs.toastOnGameMode)
            root.send("gamemode", "game", on ? "Game mode on" : "Game mode off", "");

    }

    FileView {
        id: gameModeFile

        path: Prefs.gameModeStateFile
        watchChanges: Prefs.gameModeStateFile !== ""
        printErrors: false
        onPathChanged: root.gameModeState = -1
        onFileChanged: gameModeFile.reload()
        onLoaded: root.setGameMode(1)
        onLoadFailed: root.setGameMode(0)
    }

    // power profile. g15-gamemode switches it a second or so before its state
    // file changes, so wait long enough to see whether it was game mode
    property int profile: -1
    readonly property int liveProfile: PowerProfiles.profile

    onLiveProfileChanged: profileSettle.restart()

    Timer {
        id: profileSettle

        interval: 3000
        onTriggered: {
            const p = PowerProfiles.profile;
            if (p === root.profile)
                return ;

            root.profile = p;
            if (Prefs.toastOnPower && Date.now() - root.gameModeAt > 5000)
                root.send("power", Power.icon(p), Power.name(p), "Power profile");

        }
    }

    // battery: the charger coming and going, a full charge, and warnings on
    // the way down
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!root.battery && root.battery.isPresent
    readonly property int batteryPct: root.hasBattery ? Math.round(root.battery.percentage * 100) : -1
    readonly property bool onBattery: UPower.onBattery
    readonly property bool batteryFull: root.hasBattery && root.battery.state === UPowerDeviceState.FullyCharged
    property int chargerState: -1
    // the lowest threshold already warned about on this discharge
    property int lowWarned: 101
    property bool fullAnnounced: false

    function thresholdFor(pct) {
        if (pct <= 5)
            return 5;

        if (pct <= 10)
            return 10;

        return pct <= 20 ? 20 : 101;
    }

    function checkLow() {
        if (!root.hasBattery || !root.onBattery)
            return ;

        const t = root.thresholdFor(root.batteryPct);
        if (t >= root.lowWarned)
            return ;

        root.lowWarned = t;
        if (!Prefs.toastOnBattery)
            return ;

        const title = t === 5 ? "Battery critical" : (t === 10 ? "Battery very low" : "Battery low");
        root.send("battery-low", root.batteryAlertPath, title, root.batteryPct + "% left", true, t === 5 ? 6000 : 4000);
    }

    onBatteryPctChanged: root.checkLow()
    onOnBatteryChanged: chargerSettle.restart()
    onBatteryFullChanged: {
        if (!root.batteryFull || root.fullAnnounced || root.onBattery)
            return ;

        root.fullAnnounced = true;
        if (Prefs.toastOnBattery)
            root.send("charger", root.batteryPath(100), "Fully charged", root.batteryPct + "%");

    }

    // a loose plug can flap; only where it ends up counts
    Timer {
        id: chargerSettle

        interval: 800
        onTriggered: {
            const s = root.onBattery ? 0 : 1;
            if (!root.hasBattery || s === root.chargerState)
                return ;

            root.chargerState = s;
            if (s === 1)
                root.lowWarned = 101;
            else
                root.fullAnnounced = false;
            if (Prefs.toastOnBattery)
                root.send("charger", s === 1 ? root.chargingPath : root.batteryPath(root.batteryPct), s === 1 ? "Charging" : "On battery", root.batteryPct + "%");

            root.checkLow();
        }
    }

    // bluetooth: which devices are connected, compared once things settle
    readonly property var liveBtConnected: {
        const a = Bt.adapter;
        if (!a || !a.devices)
            return [];

        return a.devices.values.filter((d) => {
            return d.connected;
        }).map((d) => {
            return d.address;
        });
    }
    property var btLast: []
    property real btConnectAt: 0
    // the last name and icon seen per address, for a device gone by announcement time
    property var btInfo: ({})

    onLiveBtConnectedChanged: {
        const a = Bt.adapter;
        if (a && a.devices) {
            for (const d of a.devices.values) root.btInfo[d.address] = {
                "name": d.name || d.deviceName || d.address,
                "icon": d.icon || ""
            }
        }
        if (root.liveBtConnected.length > root.btLast.length)
            root.btConnectAt = Date.now();

        btSettle.restart();
    }

    function announceBt(address, connected) {
        const info = root.btInfo[address] || {
            "name": address,
            "icon": ""
        };
        let detail = connected ? "Connected" : "Disconnected";
        const dev = connected ? Bt.deviceAt(address) : null;
        if (dev && dev.batteryAvailable && dev.battery > 0)
            detail += " · " + (dev.battery <= 1 ? Math.round(dev.battery * 100) : Math.round(dev.battery)) + "%";

        root.send("bt-" + address, root.glyphPath(Bt.glyphKind(info.icon)), info.name, detail);
    }

    // also gives a fresh connection a moment to report its battery. Turning the
    // radio off drops every device at once - that is one action, not news
    Timer {
        id: btSettle

        interval: 1500
        onTriggered: {
            const now = root.liveBtConnected;
            const before = root.btLast;
            root.btLast = now;
            if (!Prefs.toastOnBluetooth)
                return ;

            for (const address of now) {
                if (before.indexOf(address) < 0)
                    root.announceBt(address, true);

            }
            if (!Bt.on)
                return ;

            for (const address of before) {
                if (now.indexOf(address) < 0)
                    root.announceBt(address, false);

            }
        }
    }

    // wi-fi: waking from sleep or roaming drops and rejoins within seconds, so
    // only the network it ends up on counts
    readonly property string liveWifiName: {
        for (const d of Networking.devices.values) {
            if (d.type !== DeviceType.Wifi)
                continue;

            if (!d.connected)
                return "";

            for (const n of d.networks.values) {
                if (n.connected)
                    return n.name;

            }
            return "";
        }
        return "";
    }
    property string wifiName: ""

    onLiveWifiNameChanged: wifiSettle.restart()

    Timer {
        id: wifiSettle

        interval: 4000
        onTriggered: {
            const name = root.liveWifiName;
            if (name === root.wifiName)
                return ;

            root.wifiName = name;
            if (!Prefs.toastOnWifi)
                return ;

            if (name !== "")
                root.send("wifi", "󰤨", name, "Wi-Fi connected");
            else
                root.send("wifi", "󰤮", Networking.wifiEnabled ? "Wi-Fi disconnected" : "Wi-Fi off", "");
        }
    }

    // sound output: the default sink changing
    readonly property var liveSink: Pipewire.defaultAudioSink
    property string sinkName: ""

    onLiveSinkChanged: sinkSettle.restart()

    Timer {
        id: sinkSettle

        interval: 1000
        onTriggered: {
            const s = root.liveSink;
            if (!s || s.name === root.sinkName)
                return ;

            root.sinkName = s.name;
            // a bluetooth headset taking over already had its own connected toast
            if (!Prefs.toastOnAudio || Date.now() - root.btConnectAt < 6000)
                return ;

            const text = s.description || s.nickname || s.name;
            root.send("sink", root.glyphPath(/headphone|headset|bluez/i.test(s.name + " " + text) ? "headphones" : "speaker"), text, "Sound output");
        }
    }

    // caps lock, num lock and the microphone, when they are set to show here
    // rather than on the osd. Something the user just did, so it cuts in at once;
    // the osd only reports real changes, so there is nothing to settle or arm
    readonly property string micOffPath: "M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3z"

    function toggleEntry(kind, on) {
        const o = root.osd;
        switch (kind) {
        case "capslock":
            return {
                "key": "toggle-capslock",
                "icon": o ? o.capsLockIconPath : "info",
                "label": on ? "Caps Lock on" : "Caps Lock off"
            };
        case "numlock":
            return {
                "key": "toggle-numlock",
                "icon": o ? o.numLockIconPath : "info",
                "label": on ? "Num Lock on" : "Num Lock off"
            };
        default:
            return {
                "key": "toggle-mic",
                "icon": on ? (o ? o.micIconPath : "info") : root.micOffPath,
                "label": on ? "Microphone on" : "Microphone muted"
            };
        }
    }

    Connections {
        function onToggled(kind, on) {
            if (Prefs.osdTogglesToast)
                root.toast.present(root.toggleEntry(kind, on));

        }

        target: root.osd
        ignoreUnknownSignals: true
    }

    IpcHandler {
        target: "toastevents"

        // qs ipc call toastevents preview - one of each, through the real queue
        function preview(): void {
            const was = root.armed;
            const cap = root.toast.queueCap;
            const pct = root.batteryPct >= 0 ? root.batteryPct : 64;
            root.armed = true;
            // one of each is more than a real burst may hold
            root.toast.queueCap = 16;
            root.send("preview-layout", root.glyphPath("keyboard"), root.layoutName || "English (US)", "Keyboard layout");
            if (Prefs.osdTogglesToast) {
                const caps = root.toggleEntry("capslock", true);
                const mic = root.toggleEntry("mic", false);
                root.send("preview-caps", caps.icon, caps.label, "");
                root.send("preview-mic", mic.icon, mic.label, "");
            }
            root.send("preview-game", "game", "Game mode on", "");
            root.send("preview-charger", root.chargingPath, "Charging", pct + "%");
            root.send("preview-low", root.batteryAlertPath, "Battery low", "20% left", true);
            root.send("preview-bt", root.glyphPath("headphones"), "Headphones", "Connected · 80%");
            root.send("preview-wifi", "󰤨", root.wifiName || "Home network", "Wi-Fi connected");
            root.send("preview-sink", root.glyphPath("speaker"), "Speakers", "Sound output");
            root.send("preview-display", root.glyphPath("desktop"), "HDMI-A-1", "Display connected");
            root.send("preview-power", Power.icon(PowerProfile.Performance), Power.name(PowerProfile.Performance), "Power profile");
            root.toast.queueCap = cap;
            root.armed = was;
        }
    }
}
