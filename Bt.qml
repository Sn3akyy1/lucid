import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: !!root.adapter
    readonly property bool on: root.present && root.adapter.enabled

    // things bluez exposes that the Quickshell adapter does not
    property string address: ""
    property string alias: ""
    property bool softBlocked: false
    property bool hardBlocked: false
    property string aliasError: ""
    property bool aliasBusy: false
    // a power-on waiting for bluez to hear that rfkill let go
    property bool powerPending: false

    // bluez_card.* entries from pipewire, one per connected audio device
    property var audioCards: []

    // pairings started while pairable was off, see pair()
    property var pairQueue: []
    property bool pairableHeld: false

    readonly property string blockReason: {
        if (root.hardBlocked)
            return "A hardware switch or an Fn key has Bluetooth blocked. The radio cannot come on until that is released.";

        if (root.softBlocked && !root.on)
            return "Bluetooth is blocked in software. Turning it on here releases the block.";

        return "";
    }

    // the confirm dialog only carries a token, so it comes back here by address
    function deviceAt(address) {
        if (!root.adapter || !root.adapter.devices)
            return null;

        return root.adapter.devices.values.find((d) => {
            return d.address === address;
        }) || null;
    }

    function forgetAddress(address) {
        const d = root.deviceAt(address);
        if (d)
            d.forget();

    }

    // bluez only keeps the key from a pairing the adapter was bondable for. With pairable off
    // the pairing goes through, lives as long as the link and is thrown away, so the device
    // drops about two seconds after connecting. Hold pairable on around it, then put it back
    function pair(device) {
        if (!device || !root.adapter)
            return ;

        if (root.adapter.pairable && !root.pairableHeld) {
            device.pair();
            return ;
        }
        root.pairQueue = root.pairQueue.concat([{
            "address": device.address,
            "since": 0
        }]);
        if (!root.pairableHeld) {
            root.pairableHeld = true;
            pairableOn.running = true;
        } else if (!pairableOn.running) {
            root.startQueuedPairs();
        }
    }

    function startQueuedPairs() {
        const now = Date.now();
        root.pairQueue = root.pairQueue.map((p) => {
            if (p.since !== 0)
                return p;

            const d = root.deviceAt(p.address);
            if (d)
                d.pair();

            return {
                "address": p.address,
                "since": now
            };
        });
    }

    function cardFor(address) {
        if (!address)
            return null;

        const key = "bluez_card." + address.replace(/:/g, "_").toUpperCase();
        return root.audioCards.find((c) => {
            return c.name.toUpperCase() === key;
        }) || null;
    }

    // bluez icon names and kde connect device types both land here
    function glyphKind(name) {
        const n = (name || "").toLowerCase();
        if (n.indexOf("headphone") >= 0 || n.indexOf("headset") >= 0)
            return "headphones";

        if (n.indexOf("watch") >= 0)
            return "watch";

        if (n.indexOf("tablet") >= 0)
            return "tablet";

        if (n.indexOf("phone") >= 0)
            return "phone";

        if (n.indexOf("laptop") >= 0)
            return "laptop";

        if (n.indexOf("computer") >= 0 || n.indexOf("desktop") >= 0 || n.indexOf("pc") >= 0)
            return "desktop";

        if (n.indexOf("keyboard") >= 0)
            return "keyboard";

        if (n.indexOf("mouse") >= 0 || n.indexOf("pointing") >= 0)
            return "mouse";

        if (n.indexOf("gaming") >= 0 || n.indexOf("joypad") >= 0 || n.indexOf("gamepad") >= 0)
            return "gamepad";

        if (n.indexOf("printer") >= 0)
            return "printer";

        if (n.indexOf("car") >= 0 || n.indexOf("hifi") >= 0)
            return "car";

        if (n.indexOf("tv") >= 0 || n.indexOf("display") >= 0 || n.indexOf("video") >= 0)
            return "tv";

        if (n.indexOf("speaker") >= 0 || n.indexOf("audio") >= 0 || n.indexOf("multimedia") >= 0)
            return "speaker";

        return "";
    }

    function profileLabel(name) {
        const map = {
            "a2dp-sink": "High quality audio",
            "a2dp-sink-sbc": "High quality audio (SBC)",
            "a2dp-sink-sbc_xq": "High quality audio (SBC-XQ)",
            "a2dp-sink-aac": "High quality audio (AAC)",
            "a2dp-sink-aptx": "High quality audio (aptX)",
            "a2dp-sink-aptx_hd": "High quality audio (aptX HD)",
            "a2dp-sink-ldac": "High quality audio (LDAC)",
            "headset-head-unit": "Headset — mic works, lower quality",
            "headset-head-unit-cvsd": "Headset (CVSD)",
            "headset-head-unit-msbc": "Headset — wideband mic",
            "off": "Audio off"
        };
        return map[name] || name;
    }

    function setProfile(card, profile) {
        profileProc.running = false;
        profileProc.command = ["pactl", "set-card-profile", card, profile];
        profileProc.running = true;
    }

    // bluez refuses to power a radio rfkill holds, so release the block first
    function setEnabled(on) {
        if (!root.adapter)
            return ;

        root.powerPending = on;
        if (!on) {
            root.adapter.enabled = false;
            return ;
        }
        unblockProc.running = false;
        unblockProc.running = true;
    }

    function finishPowerOn() {
        if (!root.powerPending || !root.adapter || root.adapter.state === BluetoothAdapterState.Blocked)
            return ;

        root.powerPending = false;
        root.adapter.enabled = true;
    }

    function setAlias(name) {
        const clean = (name || "").trim();
        if (clean === "" || clean === root.alias)
            return ;

        root.aliasBusy = true;
        root.aliasError = "";
        aliasProc.running = false;
        aliasProc.command = ["bluetoothctl", "system-alias", clean];
        aliasProc.running = true;
    }

    function refresh() {
        infoProc.running = false;
        infoProc.running = true;
        cardProc.running = false;
        cardProc.running = true;
    }

    // adapter address, alias and the rfkill state, in one shot
    Process {
        id: infoProc

        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | sed -n 's/^Controller \\([0-9A-F:]*\\).*/A=\\1/p;s/^\\s*Alias: /B=/p'; rfkill -J 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text;
                const a = /A=([0-9A-F:]+)/.exec(text);
                if (a)
                    root.address = a[1];

                const b = /B=(.*)/.exec(text);
                if (b)
                    root.alias = b[1].trim();

                const brace = text.indexOf("{");
                if (brace < 0)
                    return ;

                try {
                    const list = JSON.parse(text.substring(brace)).rfkilldevices || [];
                    const bt = list.filter((d) => {
                        return d.type === "bluetooth";
                    });
                    root.softBlocked = bt.some((d) => {
                        return d.soft === "blocked";
                    });
                    root.hardBlocked = bt.some((d) => {
                        return d.hard === "blocked";
                    });
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: cardProc

        command: ["pactl", "-f", "json", "list", "cards"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(this.text.trim() || "[]");
                    root.audioCards = all.filter((c) => {
                        return c.name.indexOf("bluez_card.") === 0;
                    }).map((c) => {
                        return {
                            "name": c.name,
                            "active": c.active_profile || "",
                            "profiles": Object.keys(c.profiles || {}).filter((p) => {
                                return p !== "off" && c.profiles[p].available !== false;
                            }).sort((x, y) => {
                                return (c.profiles[y].priority || 0) - (c.profiles[x].priority || 0);
                            })
                        };
                    });
                } catch (e) {
                    root.audioCards = [];
                }
            }
        }

    }

    Process {
        id: profileProc

        onExited: root.refresh()
    }

    Process {
        id: unblockProc

        command: ["rfkill", "unblock", "bluetooth"]
        onExited: {
            root.finishPowerOn();
            pendingExpiry.restart();
            root.refresh();
        }
    }

    // bluez often reports the unblock after rfkill has already exited
    Connections {
        function onStateChanged() {
            root.finishPowerOn();
        }

        target: root.adapter
    }

    // a failed unblock mustn't power the radio on hours later
    Timer {
        id: pendingExpiry

        interval: 3000
        onTriggered: root.powerPending = false
    }

    Process {
        id: aliasProc

        onExited: (code) => {
            root.aliasBusy = false;
            root.aliasError = code === 0 ? "" : "bluetoothctl would not take that name";
            root.refresh();
        }
    }

    // a connect or disconnect moves the audio card, so re-read on any change
    Connections {
        function onValuesChanged() {
            settle.restart();
        }

        target: (root.adapter && root.adapter.devices) ? root.adapter.devices : null
    }

    Timer {
        id: settle

        interval: 900
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 20000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // exits once bluez has applied it, so a pairing never starts ahead of the bondable flag
    Process {
        id: pairableOn

        command: ["bluetoothctl", "pairable", "on"]
        onExited: root.startQueuedPairs()
    }

    Process {
        id: pairableOff

        command: ["bluetoothctl", "pairable", "off"]
    }

    // a queued pairing is over once its device stops pairing; the grace covers the moment
    // before pair() raises the flag
    Timer {
        interval: 1000
        repeat: true
        running: root.pairableHeld && !pairableOn.running
        onTriggered: {
            const now = Date.now();
            root.pairQueue = root.pairQueue.filter((p) => {
                const d = root.deviceAt(p.address);
                return !!d && (d.pairing || now - p.since < 3000);
            });
            if (root.pairQueue.length > 0)
                return ;

            root.pairableHeld = false;
            pairableOff.running = true;
        }
    }

}
