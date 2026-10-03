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
// mode, battery, bluetooth and usb devices, wi-fi, sound output, displays and
// power profile. The charger, the battery and devices coming and going also
// get a sound. Nothing is announced until the shell has settled, so a reload
// or a login doesn't replay the current state as news
Scope {
    id: root

    required property var toast

    property bool armed: false

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

    // the event's sound, held back until the shell has settled like its toast
    function sound(key, on, warning) {
        if (root.armed)
            Sounds.event(key, on, warning);

    }

    // the battery symbol that matches the charge, in eighths like the bar's
    function batterySymbol(pct) {
        const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"];
        return steps[Math.max(0, Math.min(7, Math.floor(pct / 100 * 8)))];
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
                root.send("power", Power.symbol(p), Power.name(p), "Power profile");

        }
    }

    // battery: the charger coming and going, a full charge, and warnings on
    // the way down
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!root.battery && root.battery.isPresent
    readonly property int batteryPct: root.hasBattery ? Math.round(root.battery.percentage * 100) : -1
    // not "onBattery": next to the battery property above, QML reads that name
    // as battery's change handler and silently drops the binding, so it stayed
    // false and neither the charger nor the low battery toasts ever fired
    readonly property bool unplugged: UPower.onBattery
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
        if (!root.hasBattery || !root.unplugged)
            return ;

        const t = root.thresholdFor(root.batteryPct);
        if (t >= root.lowWarned)
            return ;

        root.lowWarned = t;
        root.sound(t === 5 ? "battery-critical" : "battery-low", Prefs.soundOnBattery, true);
        if (!Prefs.toastOnBattery)
            return ;

        const title = t === 5 ? "Battery critical" : (t === 10 ? "Battery very low" : "Battery low");
        root.send("battery-low", "battery_alert", title, root.batteryPct + "% left", true, t === 5 ? 6000 : 4000);
    }

    onBatteryPctChanged: root.checkLow()
    onUnpluggedChanged: chargerSettle.restart()
    onBatteryFullChanged: {
        if (!root.batteryFull || root.fullAnnounced || root.unplugged)
            return ;

        root.fullAnnounced = true;
        root.sound("charged", Prefs.soundOnCharger);
        if (Prefs.toastOnBattery)
            root.send("charger", root.batterySymbol(100), "Fully charged", root.batteryPct + "%");

    }

    // a loose plug can flap; only where it ends up counts
    Timer {
        id: chargerSettle

        interval: 800
        onTriggered: {
            const s = root.unplugged ? 0 : 1;
            if (!root.hasBattery || s === root.chargerState)
                return ;

            root.chargerState = s;
            // plugged in with nothing left to charge: say so, and let that stand
            // in for the "Fully charged" toast that would follow a moment later
            const full = s === 1 && (root.batteryFull || root.batteryPct >= 100);
            if (s === 1)
                root.lowWarned = 101;
            else
                root.fullAnnounced = false;
            if (full)
                root.fullAnnounced = true;

            root.sound(s === 1 ? "power-in" : "power-out", Prefs.soundOnCharger);
            if (Prefs.toastOnBattery) {
                if (s === 0)
                    root.send("charger", root.batterySymbol(root.batteryPct), "On battery", root.batteryPct + "%");
                else
                    root.send("charger", "battery_charging_full", full ? "Plugged in" : "Charging", full ? "Fully charged" : root.batteryPct + "%");
            }
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
            const joined = now.filter((a) => {
                return before.indexOf(a) < 0;
            });
            const left = Bt.on ? before.filter((a) => {
                return now.indexOf(a) < 0;
            }) : [];
            if (joined.length > 0)
                root.sound("bt-in", Prefs.soundOnBluetooth);
            else if (left.length > 0)
                root.sound("bt-out", Prefs.soundOnBluetooth);
            if (!Prefs.toastOnBluetooth)
                return ;

            for (const address of joined) root.announceBt(address, true)
            for (const address of left) root.announceBt(address, false)
        }
    }

    // usb: udev's events for whole devices, never their interfaces. Built-in
    // parts - the camera, the fingerprint reader, the bluetooth chip - sit on
    // ports the firmware marks fixed and stay quiet, and usb1, usb2... are the
    // controllers' own hubs. Names and kinds come from sysfs, read when the
    // shell starts and again once a burst of plugging settles: a hub brings
    // its children in one burst, and a burst is one toast
    property var usbKnown: ({})
    property var usbBatch: []
    property bool usbFlushPending: false
    property real usbConnectAt: 0

    // the glyph for what a device says it is: its name first, then its
    // interface classes, :030102: being a mouse
    function usbSymbol(name, ifaces) {
        const names = [[/gamepad|joystick|xbox|dualsense|dualshock|game ?controller|pro controller/i, "gamepad"], [/mouse/i, "mouse"], [/keyboard/i, "keyboard"], [/headset|headphone|earbud/i, "headphones"], [/webcam|camera/i, "webcam"], [/phone/i, "phone"]];
        for (const n of names) {
            if (n[0].test(name))
                return root.glyphPath(n[1]);

        }
        const classes = [["06", "phone"], ["0e", "webcam"], ["07", "printer"], ["01", "headphones"]];
        for (const c of classes) {
            if (ifaces.indexOf(":" + c[0]) >= 0)
                return root.glyphPath(c[1]);

        }
        if (ifaces.indexOf(":e0") >= 0)
            return "bluetooth";

        const mouse = ifaces.indexOf(":030102") >= 0;
        const keyboard = ifaces.indexOf(":030101") >= 0;
        if (mouse !== keyboard)
            return root.glyphPath(mouse ? "mouse" : "keyboard");

        return "usb";
    }

    // grep's "3-1/product:USB Optical Mouse" lines; 3-1:1.0 is an interface of 3-1
    function usbScanned(text) {
        const found = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^([^/]+)\/(\w+):(.*)$/);
            if (!m)
                continue;

            // usb1, usb2... are the controllers' own hubs
            const sys = m[1].split(":")[0];
            if (sys.indexOf("-") < 0)
                continue;

            if (!found[sys])
                found[sys] = {
                "name": "",
                "maker": "",
                "fixed": false,
                "device": false,
                "ifaces": {}
            };

            const d = found[sys];
            if (m[2] === "removable") {
                d.device = true;
                d.fixed = m[3] === "fixed";
            } else if (m[2] === "product") {
                d.name = m[3].trim();
            } else if (m[2] === "manufacturer") {
                d.maker = m[3].trim();
            } else {
                if (!d.ifaces[m[1]])
                    d.ifaces[m[1]] = {};

                d.ifaces[m[1]][m[2]] = m[3].trim();
            }
        }
        for (const sys in found) {
            // a root hub's interfaces, 1-0:1.0, belong to no device of their own
            const d = found[sys];
            if (!d.device)
                continue;

            const ifaces = ":" + Object.values(d.ifaces).map((i) => {
                return (i.bInterfaceClass || "") + (i.bInterfaceSubClass || "") + (i.bInterfaceProtocol || "");
            }).join(":") + ":";
            const name = d.name || d.maker || "USB device";
            root.usbKnown[sys] = {
                "name": name,
                "icon": root.usbSymbol(name, ifaces),
                "fixed": d.fixed,
                "hub": ifaces.indexOf(":09") >= 0
            };
        }
        if (root.usbFlushPending) {
            root.usbFlushPending = false;
            root.usbFlush();
        }
    }

    function usbEventIn(action, sys) {
        if (sys.indexOf("-") < 0 || (action !== "add" && action !== "remove"))
            return ;

        if (action === "add")
            root.usbConnectAt = Date.now();

        // a device gone from sysfs is known only by what was read before
        root.usbBatch = root.usbBatch.concat([{
            "sys": sys,
            "added": action === "add",
            "info": root.usbKnown[sys] || null
        }]);
        usbSettle.restart();
    }

    function usbFlush() {
        // a camera may have come or gone with it, or been replaced by its reset
        if (root.usbBatch.length > 0)
            root.camRewatch();

        // out and straight back in is a reset, not news
        const net = {};
        for (const e of root.usbBatch) {
            if (net[e.sys] && net[e.sys].added !== e.added)
                delete net[e.sys];
            else
                net[e.sys] = e;
        }
        root.usbBatch = [];
        const added = [];
        const removed = [];
        for (const sys in net) {
            const e = net[sys];
            const info = e.added ? root.usbKnown[sys] : (e.info || {
                "name": "USB device",
                "icon": "usb",
                "fixed": false,
                "hub": false
            });
            if (!info || info.fixed)
                continue;

            (e.added ? added : removed).push(Object.assign({
                "sys": sys
            }, info));
        }
        if (added.length > 0)
            root.sound("usb-in", Prefs.soundOnUsb);
        else if (removed.length > 0)
            root.sound("usb-out", Prefs.soundOnUsb);
        if (!Prefs.toastOnUsb)
            return ;

        root.announceUsb(added, true);
        root.announceUsb(removed, false);
    }

    function announceUsb(list, connected) {
        // a hub with things on it is named by what is on it
        const devices = list.filter((d) => {
            return !d.hub;
        });
        const shown = devices.length > 0 ? devices : list;
        if (shown.length === 1)
            root.send("usb-" + shown[0].sys, shown[0].icon, shown[0].name, connected ? "USB connected" : "USB disconnected");
        else if (shown.length > 1)
            root.send("usb", "usb", shown.length + " USB devices", connected ? "Connected" : "Disconnected");
    }

    Timer {
        id: usbSettle

        interval: 1000
        onTriggered: {
            if (!root.usbBatch.some((e) => {
                return e.added;
            })) {
                root.usbFlush();
                return ;
            }
            // a new device is read from sysfs before it is named
            root.usbFlushPending = true;
            if (!usbScan.running)
                usbScan.running = true;

        }
    }

    Process {
        id: usbScan

        command: ["sh", "-c", "cd /sys/bus/usb/devices && grep -H . */removable */product */manufacturer */bInterfaceClass */bInterfaceSubClass */bInterfaceProtocol 2>/dev/null"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.usbScanned(this.text)
        }

    }

    // only the header line of each event is read: "UDEV [t] add /devices/.../3-1 (usb)"
    Process {
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device"]
        running: true

        stdout: SplitParser {
            onRead: (line) => {
                const m = line.match(/UDEV\s+\[[\d.]+\]\s+(\w+)\s+(\S+)/);
                if (m)
                    root.usbEventIn(m[1], m[2].split("/").pop());

            }
        }

    }

    // the camera: inotify sees every open and close of /dev/video*, so nothing
    // runs until one is touched, and only then is whoever holds a camera looked
    // up. A browser opening it just to list devices has closed it again by the
    // time the settle ends, and stays quiet
    property int camState: -1

    // after a usb change, so a webcam plugged in later is watched too
    function camRewatch() {
        camWatch.running = false;
        camWatch.running = true;
        camSettle.restart();
    }

    // process names as people know them. A camera reached through pipewire is
    // held by pipewire itself, so the app is whatever its camera node feeds
    function camApps(comms) {
        const out = [];
        for (const c of comms) {
            if (c !== "pipewire" && c !== "wireplumber") {
                out.push(c.charAt(0).toUpperCase() + c.slice(1));
                continue;
            }
            for (const g of (Pipewire.linkGroups ? Pipewire.linkGroups.values : [])) {
                if (g && g.source && g.target && /^(v4l2|libcamera)_/.test(g.source.name || ""))
                    out.push(Audio.appLabel(g.target));

            }
        }
        return out.filter((a, i) => {
            return a && out.indexOf(a) === i;
        });
    }

    function camScanned(text) {
        const comms = text.split("\n").map((c) => {
            return c.trim();
        }).filter((c) => {
            return c !== "";
        });
        const on = comms.length > 0 ? 1 : 0;
        if (on === root.camState)
            return ;

        const known = root.camState !== -1;
        root.camState = on;
        if (!known)
            return ;

        root.sound(on ? "camera-on" : "camera-off", Prefs.soundOnCamera);
        // the privacy module's "x is using the camera" folds into the same toast
        if (Prefs.toastOnCamera)
            root.send("privacy-camera", on ? "videocam" : "videocam_off", on ? "Camera on" : "Camera off", on ? root.camApps(comms).join(", ") : "");

    }

    Timer {
        id: camSettle

        interval: 400
        onTriggered: {
            if (camScan.running)
                camSettle.restart();
            else
                camScan.running = true;
        }
    }

    Process {
        id: camScan

        command: ["sh", "-c", "for d in $(find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' -printf '%h\\n' 2>/dev/null | sort -u); do cat \"${d%/fd}/comm\" 2>/dev/null; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.camScanned(this.text)
        }

    }

    Process {
        id: camWatch

        command: ["sh", "-c", "exec inotifywait -mq -e open,close --format %e /dev/video*"]
        running: true

        stdout: SplitParser {
            onRead: camSettle.restart()
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
                root.send("wifi", "wifi", name, "Wi-Fi connected");
            else
                root.send("wifi", "wifi_off", Networking.wifiEnabled ? "Wi-Fi disconnected" : "Wi-Fi off", "");
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
            // a bluetooth or usb headset taking over already had its own connected toast
            if (!Prefs.toastOnAudio || Date.now() - Math.max(root.btConnectAt, root.usbConnectAt) < 6000)
                return ;

            const text = s.description || s.nickname || s.name;
            root.send("sink", root.glyphPath(/headphone|headset|bluez/i.test(s.name + " " + text) ? "headphones" : "speaker"), text, "Sound output");
        }
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
            root.send("preview-game", "game", "Game mode on", "");
            root.send("preview-charger", "battery_charging_full", "Charging", pct + "%");
            root.send("preview-low", "battery_alert", "Battery low", "20% left", true);
            root.send("preview-bt", root.glyphPath("headphones"), "Headphones", "Connected · 80%");
            root.send("preview-usb", "usb", "USB drive", "USB connected");
            root.send("preview-camera", "videocam", "Camera on", "Firefox");
            root.send("preview-wifi", "wifi", root.wifiName || "Home network", "Wi-Fi connected");
            root.send("preview-sink", root.glyphPath("speaker"), "Speakers", "Sound output");
            root.send("preview-display", root.glyphPath("desktop"), "HDMI-A-1", "Display connected");
            root.send("preview-power", Power.symbol(PowerProfile.Performance), Power.name(PowerProfile.Performance), "Power profile");
            root.toast.queueCap = cap;
            root.armed = was;
        }
    }
}
