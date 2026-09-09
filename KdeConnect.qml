import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    // set once the daemon binary is actually on the box
    property bool installed: false
    property bool probed: false
    property bool running: false
    property bool everAnswered: false

    property string selfId: ""
    property string selfName: ""
    property var backends: []
    property var devices: []
    property var requests: []
    property string lastError: ""
    property int lastSent: 0
    property real lastSentAt: 0

    readonly property bool active: Prefs.loaded && Prefs.kdeConnectEnabled && root.installed
    readonly property var reachable: root.devices.filter((d) => {
        return d.paired && d.reachable;
    })
    readonly property var offline: root.devices.filter((d) => {
        return d.paired && !d.reachable;
    })
    readonly property var nearby: root.devices.filter((d) => {
        return !d.paired;
    })
    readonly property int pairedCount: root.reachable.length + root.offline.length

    readonly property string summary: {
        if (!root.installed)
            return "Not installed";

        if (!Prefs.kdeConnectEnabled)
            return "Turned off";

        if (!root.running)
            return root.everAnswered ? "Daemon not running" : "Starting…";

        if (root.reachable.length === 1)
            return root.reachable[0].name;

        if (root.reachable.length > 1)
            return root.reachable.length + " devices connected";

        if (root.pairedCount > 0)
            return root.pairedCount === 1 ? "1 paired device, offline" : root.pairedCount + " paired devices, offline";

        return "No devices paired";
    }

    function device(id) {
        return root.devices.find((d) => {
            return d.id === id;
        }) || null;
    }

    function pluginOn(dev, name) {
        return dev && dev.loaded.indexOf(name) >= 0;
    }

    function send(obj) {
        if (bridge.running)
            bridge.write(JSON.stringify(obj) + "\n");
    }

    function refresh() {
        root.send({
            "c": "refresh"
        });
    }

    function rescan() {
        root.send({
            "c": "rescan"
        });
    }

    function pair(id) {
        root.send({
            "c": "pair",
            "id": id
        });
    }

    function unpair(id) {
        root.send({
            "c": "unpair",
            "id": id
        });
    }

    function accept(id) {
        root.send({
            "c": "accept",
            "id": id
        });
    }

    function cancel(id) {
        root.send({
            "c": "cancel",
            "id": id
        });
    }

    function ring(id) {
        root.send({
            "c": "ring",
            "id": id
        });
    }

    function ping(id, text) {
        root.send({
            "c": "ping",
            "id": id,
            "text": text || ""
        });
    }

    function sendClipboard(id) {
        root.send({
            "c": "clipboard",
            "id": id
        });
    }

    function shareText(id, text) {
        root.send({
            "c": "sharetext",
            "id": id,
            "text": text
        });
    }

    function shareUrl(id, url) {
        root.send({
            "c": "shareurl",
            "id": id,
            "url": url
        });
    }

    function setLocked(id, v) {
        root.send({
            "c": "lock",
            "id": id,
            "v": v
        });
    }

    function mount(id) {
        root.send({
            "c": "mount",
            "id": id
        });
    }

    function unmount(id) {
        root.send({
            "c": "unmount",
            "id": id
        });
    }

    function browse(id) {
        root.send({
            "c": "browse",
            "id": id
        });
    }

    function setPlugin(id, name, v) {
        root.send({
            "c": "plugin",
            "id": id,
            "name": name,
            "v": v
        });
    }

    function runCommand(id, key) {
        root.send({
            "c": "runcmd",
            "id": id,
            "key": key
        });
    }

    function openSms(id) {
        root.send({
            "c": "sms",
            "id": id
        });
    }

    function setName(name) {
        root.send({
            "c": "setname",
            "name": name
        });
    }

    function setBackend(name, v) {
        root.send({
            "c": "backend",
            "name": name,
            "v": v
        });
    }

    function pickFiles(id, title) {
        root.send({
            "c": "pickfiles",
            "id": id,
            "title": title
        });
    }

    function shareFiles(id, uris) {
        root.send({
            "c": "sharefiles",
            "id": id,
            "uris": uris
        });
    }

    function openDest(id) {
        root.send({
            "c": "opendest",
            "id": id
        });
    }

    function mpris(id, action, name, v) {
        root.send({
            "c": "mpris",
            "id": id,
            "action": action,
            "name": name || "",
            "v": v === undefined ? 0 : v
        });
    }

    function sinkVolume(id, name, v) {
        root.send({
            "c": "sinkvolume",
            "id": id,
            "name": name,
            "v": v
        });
    }

    function sinkMute(id, name, v) {
        root.send({
            "c": "sinkmute",
            "id": id,
            "name": name,
            "v": v
        });
    }

    function dismiss(id, nid) {
        root.send({
            "c": "dismiss",
            "id": id,
            "nid": nid
        });
    }

    function notifyReply(id, nid, text) {
        root.send({
            "c": "notifreply",
            "id": id,
            "nid": nid,
            "text": text
        });
    }

    function cursor(id, dx, dy) {
        root.send({
            "c": "cursor",
            "id": id,
            "dx": Math.round(dx),
            "dy": Math.round(dy)
        });
    }

    function click(id, name) {
        root.send({
            "c": "click",
            "id": id,
            "name": name
        });
    }

    function key(id, text, special, shift, ctrl, alt) {
        root.send({
            "c": "key",
            "id": id,
            "text": text || "",
            "special": special || 0,
            "shift": !!shift,
            "ctrl": !!ctrl,
            "alt": !!alt
        });
    }

    // the remote keyboard's own numbering for the keys that carry no character
    readonly property var specialKeys: ({
        "backspace": 1,
        "tab": 2,
        "left": 4,
        "up": 5,
        "right": 6,
        "down": 7,
        "pageup": 8,
        "pagedown": 9,
        "home": 10,
        "end": 11,
        "return": 12,
        "enter": 13,
        "delete": 14,
        "escape": 15
    })

    // a friendlier name than the raw kdeconnect_* plugin id
    function pluginLabel(name) {
        const map = {
            "kdeconnect_battery": "Battery report",
            "kdeconnect_clipboard": "Shared clipboard",
            "kdeconnect_connectivity_report": "Signal strength",
            "kdeconnect_contacts": "Contacts",
            "kdeconnect_findmyphone": "Ring my phone",
            "kdeconnect_findthisdevice": "Ring this machine",
            "kdeconnect_lockdevice": "Lock the phone remotely",
            "kdeconnect_mousepad": "Use the phone as a touchpad",
            "kdeconnect_mpriscontrol": "Control this machine's media",
            "kdeconnect_mprisremote": "Control the phone's media",
            "kdeconnect_notifications": "Receive phone notifications",
            "kdeconnect_pausemusic": "Pause music on a call",
            "kdeconnect_ping": "Ping",
            "kdeconnect_presenter": "Slide remote",
            "kdeconnect_remotecommands": "Run commands here from the phone",
            "kdeconnect_remotecontrol": "Remote input",
            "kdeconnect_remotekeyboard": "Type from the phone",
            "kdeconnect_remotesystemvolume": "Control the phone's volume",
            "kdeconnect_runcommand": "Run commands on the phone",
            "kdeconnect_screensaver_inhibit": "Keep the screen awake",
            "kdeconnect_sendnotifications": "Send my notifications to the phone",
            "kdeconnect_sftp": "Browse the phone's files",
            "kdeconnect_share": "Share files and links",
            "kdeconnect_sms": "Send text messages",
            "kdeconnect_systemvolume": "Control this machine's volume",
            "kdeconnect_telephony": "Call notifications",
            "kdeconnect_virtualmonitor": "Use the phone as a second screen"
        };
        return map[name] || name.replace("kdeconnect_", "").replace(/_/g, " ");
    }

    // qs ipc call kdeconnect status | list | rescan
    // qs ipc call -- kdeconnect ring <device id>
    IpcHandler {
        target: "kdeconnect"

        function status(): string {
            if (!root.installed)
                return "kdeconnect is not installed";

            if (!Prefs.kdeConnectEnabled)
                return "turned off in settings";

            return (root.running ? "daemon up" : "daemon down") + ", as \"" + root.selfName + "\" (" + root.selfId + ") — " + root.summary;
        }

        function list(): string {
            if (root.devices.length === 0)
                return "no devices";

            return root.devices.map((d) => {
                const state = d.pairRequestedByPeer ? "wants to pair" : (!d.paired ? "unpaired" : (d.reachable ? "connected" : "offline"));
                const batt = d.battery && d.battery.charge >= 0 ? "  " + d.battery.charge + "%" : "";
                return d.id + "  " + d.name + "  [" + state + "]" + batt;
            }).join("\n");
        }

        function rescan(): void {
            root.rescan();
        }

        function ring(id: string): void {
            root.ring(id);
        }

        function ping(id: string): void {
            root.ping(id, "Ping from Lucid");
        }

        function clipboard(id: string): void {
            root.sendClipboard(id);
        }

        function files(id: string): void {
            root.pickFiles(id, "Send files");
        }

        function send(id: string, path: string): void {
            root.shareUrl(id, path.indexOf("/") === 0 ? "file://" + path : path);
        }

    }

    Process {
        id: probe

        running: true
        command: ["sh", "-c", "command -v kdeconnectd >/dev/null 2>&1 && echo yes || echo no"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.installed = this.text.trim() === "yes";
                root.probed = true;
            }
        }

    }

    // `running` is driven by hand: quickshell clears it itself when a process
    // exits, which would kill a binding and leave the bridge down for good
    onActiveChanged: bridge.running = root.active

    Component.onCompleted: bridge.running = root.active

    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: {
            if (bridge.running !== root.active)
                bridge.running = root.active;

        }
    }

    Process {
        id: bridge

        stdinEnabled: true
        command: ["python3", Qt.resolvedUrl("lucidprefs/kdeconnect-bridge.py").toString().replace("file://", "")]
        onExited: (code) => {
            root.running = false;
            if (root.active && code !== 0)
                root.lastError = "the KDE Connect bridge stopped (code " + code + ")";

        }

        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "")
                    return ;

                try {
                    const d = JSON.parse(line);
                    if (d.t === "error") {
                        root.lastError = d.msg || "";
                        return ;
                    }
                    if (d.t === "sent") {
                        root.lastSent = d.count;
                        root.lastSentAt = Date.now();
                        return ;
                    }
                    if (d.t !== "state")
                        return ;

                    root.everAnswered = true;
                    root.running = !!d.running;
                    root.selfId = d.selfId || "";
                    root.selfName = d.selfName || "";
                    root.backends = d.backends || [];
                    root.requests = d.requests || [];
                    root.devices = d.devices || [];
                    root.lastError = "";
                } catch (e) {
                    root.lastError = "could not read the bridge reply";
                }
            }
        }

        stderr: SplitParser {
            onRead: (line) => {
                if (line.indexOf("ModuleNotFoundError") >= 0 || line.indexOf("No module named") >= 0)
                    root.lastError = "python-gobject is missing, so KDE Connect cannot be reached";

            }
        }

    }

    // the daemon can appear late; a slow heartbeat keeps the list honest
    Timer {
        interval: 30000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

}
