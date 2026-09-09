import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
pragma Singleton

Singleton {
    id: root

    readonly property string helper: Qt.resolvedUrl("lucidprefs/netinfo.py").toString().replace("file://", "")

    // what NetworkManager knows and the Quickshell module does not
    property string connectivity: ""
    property var devices: []
    property var connections: []
    property var detail: ({})
    property string detailUuid: ""
    property string lastError: ""
    property bool busy: false

    readonly property var wifiDevice: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi)
                return d;

        }
        return null;
    }
    readonly property var wiredDevices: Networking.devices.values.filter((d) => {
        return d.type === DeviceType.Wired;
    })
    readonly property var vpns: root.connections.filter((c) => {
        return c.vpn;
    })
    readonly property var profiles: root.connections.filter((c) => {
        return !c.vpn && c.type !== "bridge";
    })
    readonly property var activeVpn: root.vpns.find((v) => {
        return v.active;
    }) || null

    readonly property string connectivityLabel: {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full:
            return "Connected to the internet";
        case NetworkConnectivity.Portal:
            return "Behind a sign-in page";
        case NetworkConnectivity.Limited:
            return "Connected, but no internet";
        case NetworkConnectivity.None:
            return "No internet";
        default:
            return "Not checked";
        }
    }

    function deviceInfo(name) {
        return root.devices.find((d) => {
            return d.name === name;
        }) || null;
    }

    function securityLabel(sec) {
        switch (sec) {
        case WifiSecurityType.Open:
            return "Open";
        case WifiSecurityType.Owe:
            return "Open (encrypted)";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3 Enterprise";
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Wpa2Eap:
            return "Enterprise";
        case WifiSecurityType.Leap:
            return "LEAP";
        default:
            return "";
        }
    }

    function isSecured(net) {
        return !!net && net.security !== undefined && net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Owe;
    }

    // quickshell reports signal as a 0-1 double; everything here talks percent.
    // the guard keeps it right if that ever changes under us
    function strengthPct(net) {
        if (!net || net.signalStrength === undefined || net.signalStrength === null)
            return 0;

        const raw = net.signalStrength;
        return Math.round(raw <= 1 ? raw * 100 : raw);
    }

    function strengthLabel(s) {
        if (s >= 75)
            return "Excellent";

        if (s >= 50)
            return "Good";

        if (s >= 25)
            return "Fair";

        return "Weak";
    }

    // the confirm dialog carries only a token, so these come back by name
    function forgetSsid(name) {
        if (!root.wifiDevice || !root.wifiDevice.networks)
            return ;

        const n = root.wifiDevice.networks.values.find((x) => {
            return x.name === name && x.known;
        });
        if (n)
            n.forget();

    }

    function hotspotFromToken(token) {
        const nl = token.indexOf("\n");
        if (nl < 0)
            return ;

        root.startHotspot(token.substring(0, nl), token.substring(nl + 1));
    }

    function refresh() {
        infoProc.running = false;
        infoProc.running = true;
    }

    function loadDetail(uuid) {
        root.detailUuid = uuid;
        root.detail = ({});
        detailProc.running = false;
        detailProc.command = ["python3", root.helper, "--conn", uuid];
        detailProc.running = true;
    }

    // every write goes through nmcli; the module cannot express any of these
    function run(args) {
        root.busy = true;
        root.lastError = "";
        actionProc.running = false;
        actionProc.command = ["nmcli"].concat(args);
        actionProc.running = true;
    }

    function up(uuid) {
        root.run(["connection", "up", uuid]);
    }

    function down(uuid) {
        root.run(["connection", "down", uuid]);
    }

    function forget(uuid) {
        root.run(["connection", "delete", uuid]);
    }

    function setAutoconnect(uuid, v) {
        root.run(["connection", "modify", uuid, "connection.autoconnect", v ? "yes" : "no"]);
    }

    function setMetered(uuid, v) {
        root.run(["connection", "modify", uuid, "connection.metered", v ? "yes" : "no"]);
    }

    function setPriority(uuid, n) {
        root.run(["connection", "modify", uuid, "connection.autoconnect-priority", String(Math.round(n))]);
    }

    function setDhcp(uuid) {
        root.run(["connection", "modify", uuid, "ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", "", "ipv4.dns", "", "ipv4.ignore-auto-dns", "no"]);
    }

    function setManual(uuid, address, gateway, dns) {
        root.run(["connection", "modify", uuid, "ipv4.method", "manual", "ipv4.addresses", address, "ipv4.gateway", gateway, "ipv4.dns", dns, "ipv4.ignore-auto-dns", dns === "" ? "no" : "yes"]);
    }

    function setDns(uuid, dns) {
        root.run(["connection", "modify", uuid, "ipv4.dns", dns, "ipv4.ignore-auto-dns", dns === "" ? "no" : "yes"]);
    }

    function connectHidden(ssid, psk) {
        const args = ["device", "wifi", "connect", ssid, "hidden", "yes"];
        root.run(psk === "" ? args : args.concat(["password", psk]));
    }

    function startHotspot(ssid, psk) {
        if (!root.wifiDevice)
            return ;

        root.run(["device", "wifi", "hotspot", "ifname", root.wifiDevice.name, "ssid", ssid, "password", psk]);
    }

    // qs ipc call network status | list | rescan
    IpcHandler {
        target: "network"

        function status(): string {
            const active = root.devices.filter((d) => {
                return d.connection !== "";
            });
            const where = active.map((d) => {
                return d.connection + " on " + d.name + (d.ip4.length > 0 ? " " + d.ip4[0] : "");
            }).join("; ");
            return root.connectivityLabel + (where !== "" ? " — " + where : "");
        }

        function list(): string {
            if (!root.wifiDevice || !root.wifiDevice.networks)
                return "no wifi device";

            const seen = [];
            for (const n of root.wifiDevice.networks.values) {
                if (!n.name)
                    continue;

                seen.push((n.connected ? "* " : "  ") + n.name + "  " + root.strengthPct(n) + "%  " + (n.known ? "saved" : "new") + "  " + root.securityLabel(n.security));
            }
            return seen.length > 0 ? seen.join("\n") : "no networks";
        }

        function rescan(): void {
            if (root.wifiDevice)
                root.wifiDevice.scannerEnabled = true;

            root.refresh();
        }

    }

    Process {
        id: infoProc

        command: ["python3", root.helper]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text.trim() || "{}");
                    root.connectivity = d.connectivity || "";
                    root.devices = d.devices || [];
                    root.connections = d.connections || [];
                } catch (e) {
                    root.devices = [];
                    root.connections = [];
                }
            }
        }

    }

    Process {
        id: detailProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.detail = JSON.parse(this.text.trim() || "{}");
                } catch (e) {
                    root.detail = ({});
                }
            }
        }

    }

    Process {
        id: actionProc

        onExited: (code) => {
            root.busy = false;
            if (code !== 0) {
                const err = actionErr.text.trim();
                root.lastError = err.split("\n").pop() || "NetworkManager refused that change";
            }
            settle.restart();
        }

        stderr: StdioCollector {
            id: actionErr
        }

    }

    // NetworkManager tells us the moment anything moves, so no fast polling
    Process {
        id: monitor

        running: true
        command: ["nmcli", "monitor"]

        stdout: SplitParser {
            onRead: settle.restart()
        }

    }

    Timer {
        id: settle

        interval: 700
        repeat: false
        onTriggered: {
            root.refresh();
            if (root.detailUuid !== "")
                root.loadDetail(root.detailUuid);

        }
    }

    Timer {
        interval: 20000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

}
