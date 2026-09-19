import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
pragma Singleton

Singleton {
    id: root

    // what the machine plays through and listens on right now
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

    readonly property var outputs: root.nodes.filter((n) => {
        return root.isAudio(n) && n.isSink && !n.isStream;
    }).sort(root.byLabel)
    readonly property var inputs: root.nodes.filter((n) => {
        return root.isAudio(n) && !n.isSink && !n.isStream;
    }).sort(root.byLabel)
    readonly property var playbackStreams: root.nodes.filter((n) => {
        return root.isAudio(n) && n.isStream && n.isSink;
    })
    // the page's own level meters record through streams named "quickshell";
    // the name never changes, so a stream is never dropped once it is tracked
    readonly property var recordStreams: root.nodes.filter((n) => {
        return root.isAudio(n) && n.isStream && !n.isSink && n.name !== "quickshell";
    })
    // unbound nodes report no properties and a volume of zero, so everything a
    // page draws has to be held open for as long as it is on screen
    readonly property var tracked: root.outputs.concat(root.inputs, root.playbackStreams, root.recordStreams)

    // pipewire's registry carries no card profiles, no ports and no pulse ids
    // to move a stream by, so pactl fills those in beside it
    property var cards: []
    property var devicePorts: ({})
    property var streamRoutes: ({})
    property string lastError: ""
    // stream node id -> true for one sent to a device of its own rather than
    // following the default
    property var pinned: ({})
    // WirePlumber setting id -> value, as wpctl reports it
    property var wp: ({})
    property bool wpRead: false
    readonly property string soundDir: "/usr/share/sounds/freedesktop/stereo/"
    // pactl calls are serialised: two at once on the same card race
    property var actionQueue: []

    function isAudio(node) {
        return !!node && (node.type & PwNodeType.Audio) !== 0;
    }

    function label(node) {
        if (!node)
            return "";

        if (node.description && node.description !== "")
            return node.description;

        if (node.nickname && node.nickname !== "")
            return node.nickname;

        return node.name || "";
    }

    function byLabel(a, b) {
        return root.label(a).localeCompare(root.label(b));
    }

    // a stream is named for the program behind it, not for the node
    function appLabel(node) {
        if (!node)
            return "";

        const p = node.properties || {};
        return p["application.name"] || node.description || node.name || "";
    }

    // and subtitled with whatever it is playing, when that says something new
    function mediaLabel(node) {
        if (!node)
            return "";

        const p = node.properties || {};
        const m = p["media.name"] || "";
        return m === root.appLabel(node) ? "" : m;
    }

    // the loudest channel, so a balance set off centre still reads as the level
    function levelOf(node) {
        if (!node || !node.audio)
            return 0;

        const v = node.audio.volumes;
        if (!v || v.length === 0)
            return node.audio.volume;

        let top = 0;
        for (let i = 0; i < v.length; i++) top = Math.max(top, v[i])
        return top;
    }

    function volumeOf(node) {
        return Math.round(root.levelOf(node) * 100);
    }

    function mutedOf(node) {
        return !!(node && node.audio && node.audio.muted);
    }

    // dragging a muted slider unmutes, the way the bar's volume pill does
    // every channel scales together, so the balance survives
    function setVolume(node, pct) {
        if (!node || !node.audio)
            return ;

        node.audio.muted = false;
        const target = Math.max(0, Math.min(1, pct / 100));
        const v = node.audio.volumes;
        const top = root.levelOf(node);
        if (!v || v.length === 0 || top < 0.0001) {
            node.audio.volume = target;
            return ;
        }
        const out = [];
        for (let i = 0; i < v.length; i++) out.push(v[i] * target / top)
        node.audio.volumes = out;
    }

    function sideOf(channel) {
        const s = PwAudioChannel.toString(channel);
        return /Left/.test(s) ? -1 : (/Right/.test(s) ? 1 : 0);
    }

    function hasBalance(node) {
        if (!node || !node.audio || !node.audio.channels)
            return false;

        let l = false, r = false;
        const ch = node.audio.channels;
        for (let i = 0; i < ch.length; i++) {
            const side = root.sideOf(ch[i]);
            l = l || side < 0;
            r = r || side > 0;
        }
        return l && r;
    }

    // -1 all left .. 0 centre .. 1 all right
    function balanceOf(node) {
        if (!root.hasBalance(node))
            return 0;

        const ch = node.audio.channels;
        const v = node.audio.volumes;
        let l = 0, r = 0;
        for (let i = 0; i < ch.length && i < v.length; i++) {
            const side = root.sideOf(ch[i]);
            if (side < 0)
                l = Math.max(l, v[i]);
            else if (side > 0)
                r = Math.max(r, v[i]);
        }
        if (l < 0.0001 && r < 0.0001)
            return 0;

        return l >= r ? -(1 - r / l) : 1 - l / r;
    }

    function setBalance(node, b) {
        if (!root.hasBalance(node))
            return ;

        const top = root.levelOf(node);
        const ch = node.audio.channels;
        const out = [];
        for (let i = 0; i < ch.length; i++) {
            const side = root.sideOf(ch[i]);
            if (side < 0)
                out.push(top * (b > 0 ? 1 - b : 1));
            else if (side > 0)
                out.push(top * (b < 0 ? 1 + b : 1));
            else
                out.push(top);
        }
        node.audio.volumes = out;
    }

    // "FL" or "FR" speaks on that side alone; "" plays on every channel
    function testSide(node, side) {
        if (!node)
            return ;

        const file = side === "FL" ? "audio-channel-front-left" : (side === "FR" ? "audio-channel-front-right" : "audio-channel-front-center");
        const cmd = ["pw-play", "--target", node.name];
        if (side !== "")
            cmd.push("--channel-map", side);

        cmd.push(root.soundDir + file + ".oga");
        Quickshell.execDetached(cmd);
    }

    function toggleMute(node) {
        if (node && node.audio)
            node.audio.muted = !node.audio.muted;

    }

    function isDefault(node) {
        return !!node && ((node.isSink && node === root.sink) || (!node.isSink && node === root.source));
    }

    // pipewire only moves the streams that never asked for a device of their
    // own, so anything already playing can be carried across as well
    function setDefault(node) {
        if (!node)
            return ;

        if (node.isSink) {
            Pipewire.preferredDefaultAudioSink = node;
            if (Prefs.audioMoveStreams)
                root.moveAll(root.playbackStreams, node);

        } else {
            Pipewire.preferredDefaultAudioSource = node;
            if (Prefs.audioMoveStreams)
                root.moveAll(root.recordStreams, node);

        }
    }

    function shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function routeOf(node) {
        return node ? (root.streamRoutes[node.id] || null) : null;
    }

    // the device a stream is playing on, as a node the page can offer to change
    function targetOf(node) {
        const r = root.routeOf(node);
        if (!r)
            return null;

        const list = node && node.isSink ? root.outputs : root.inputs;
        return list.find((d) => {
            return d.name === r.target;
        }) || null;
    }

    // its name, which a monitor has even though it is nothing this page lists
    function targetLabel(node) {
        const r = root.routeOf(node);
        return r ? r.label : "";
    }

    function moveCommand(stream, device) {
        const r = root.routeOf(stream);
        if (!r || !device || r.target === device.name)
            return "";

        const verb = stream.isSink ? "move-sink-input" : "move-source-output";
        return "pactl " + verb + " " + r.id + " " + root.shq(device.name);
    }

    // a stream recording a device's own output — a visualiser, a screen
    // recorder — asked for that device, and is not listening for a microphone
    function onMonitor(stream) {
        const r = root.routeOf(stream);
        return !!r && /\.monitor$/.test(r.target);
    }

    function isPinned(stream) {
        return !!stream && root.pinned[stream.id] === true;
    }

    // a move writes target.node and target.object into the default metadata;
    // with both gone WirePlumber hands the stream back to the default device
    function followDefault(stream) {
        // a missing id reads as 0 to pw-metadata, and deleting on 0 wipes the
        // default devices themselves
        if (!stream || !(stream.id > 0))
            return ;

        root.run("pw-metadata -n default -d " + stream.id + " target.node >/dev/null; pw-metadata -n default -d " + stream.id + " target.object >/dev/null");
    }

    function move(stream, device) {
        const cmd = root.moveCommand(stream, device);
        if (cmd !== "")
            root.run(cmd);

    }

    function moveAll(streams, device) {
        const parts = [];
        for (var i = 0; i < streams.length; i++) {
            if (root.onMonitor(streams[i]))
                continue;

            const cmd = root.moveCommand(streams[i], device);
            if (cmd !== "")
                parts.push(cmd);

        }
        if (parts.length > 0)
            root.run(parts.join("; "));

    }

    function cardFor(node) {
        if (!node || !node.properties)
            return null;

        const id = parseInt(node.properties["device.id"]);
        if (isNaN(id))
            return null;

        return root.cards.find((c) => {
            return c.index === id;
        }) || null;
    }

    function portsFor(node) {
        return (node && root.devicePorts[node.name]) || null;
    }

    // what the device is doing now: its profile, and the socket it comes out of
    function detailOf(node) {
        if (!node)
            return "";

        const bits = [];
        const p = node.properties || {};
        const profile = p["device.profile.description"] || "";
        if (profile !== "")
            bits.push(profile);

        const ports = root.portsFor(node);
        if (ports && ports.active !== "") {
            const active = ports.list.find((x) => {
                return x.key === ports.active;
            });
            if (active && active.label !== "" && bits.indexOf(active.label) < 0)
                bits.push(active.label);

        }
        return bits.join(" · ");
    }

    function setProfile(cardName, profile) {
        root.run("pactl set-card-profile " + root.shq(cardName) + " " + root.shq(profile));
    }

    function setPort(node, port) {
        if (!node)
            return ;

        const verb = node.isSink ? "set-sink-port" : "set-source-port";
        root.run("pactl " + verb + " " + root.shq(node.name) + " " + root.shq(port));
    }

    function glyphKind(node) {
        if (!node)
            return "speaker";

        const p = node.properties || {};
        const card = root.cardFor(node);
        const hay = [p["device.icon_name"], p["device.form_factor"], p["media.icon_name"], card ? card.icon : "", node.name].join(" ").toLowerCase();
        if (hay.indexOf("headphone") >= 0 || hay.indexOf("headset") >= 0)
            return "headphones";

        if (hay.indexOf("hdmi") >= 0 || hay.indexOf("display") >= 0 || hay.indexOf("tv") >= 0)
            return "tv";

        // a microphone that also has a socket to listen on is drawn for what
        // this particular half of it does, not for what the box mostly is
        if (node.isSink) {
            if (hay.indexOf("bluez") >= 0)
                return "headphones";

            return "speaker";
        }
        if (hay.indexOf("webcam") >= 0 || hay.indexOf("camera") >= 0)
            return "webcam";

        if (hay.indexOf("phone") >= 0 && hay.indexOf("microphone") < 0 && hay.indexOf("headphone") < 0)
            return "phone";

        return "microphone";
    }

    function run(script) {
        root.actionQueue = root.actionQueue.concat([script]);
        root.drain();
    }

    function drain() {
        if (actionProc.running || root.actionQueue.length === 0)
            return ;

        const next = root.actionQueue[0];
        root.actionQueue = root.actionQueue.slice(1);
        actionProc.command = ["sh", "-c", next];
        actionProc.running = true;
    }

    function refresh() {
        infoProc.running = false;
        infoProc.running = true;
    }

    function refreshWp() {
        wpProc.running = false;
        wpProc.running = true;
    }

    function parseWp(s) {
        if (s === "true")
            return true;

        if (s === "false")
            return false;

        if (/^".*"$/.test(s))
            return s.slice(1, -1);

        const n = Number(s);
        return s === "" || isNaN(n) ? s : n;
    }

    // saved, so it outlives a WirePlumber restart like the rest of its state
    function setWp(key, value) {
        const next = {};
        for (const k in root.wp) next[k] = root.wp[k]
        next[key] = value;
        root.wp = next;
        root.run("wpctl settings --save " + root.shq(key) + " " + root.shq(typeof value === "string" ? "\"" + value + "\"" : String(value)));
    }

    Process {
        id: wpProc

        command: ["wpctl", "settings"]
        environment: ({
            "LC_ALL": "C"
        })

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                let key = "";
                const lines = this.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const id = /^\s*-\s*Id:\s*(\S+)/.exec(lines[i]);
                    if (id) {
                        key = id[1];
                        continue;
                    }
                    // a saved value carries "[Saved: true]" in the listing, "(Saved: true)" alone
                    const val = /^\s*Value:\s*(.*?)(?:\s+[\[(]Saved:[^\])]*[\])])?\s*$/.exec(lines[i]);
                    if (val && key !== "") {
                        out[key] = root.parseWp(val[1]);
                        key = "";
                    }
                }
                root.wp = out;
                root.wpRead = Object.keys(out).length > 0;
            }
        }

    }

    // one pass for everything pactl knows, so a change costs a single process
    Process {
        id: infoProc

        command: ["sh", "-c", "for k in cards sinks sources sink-inputs source-outputs; do printf '\\n@%s@\\n' \"$k\"; pactl -f json list $k 2>/dev/null; done; printf '\\n@metadata@\\n'; pw-metadata -n default 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root.absorb(this.text)
        }

    }

    function section(text, name) {
        const start = text.indexOf("@" + name + "@");
        if (start < 0)
            return [];

        var end = text.indexOf("\n@", start + 1);
        if (end < 0)
            end = text.length;

        try {
            return JSON.parse(text.substring(start + name.length + 2, end).trim() || "[]");
        } catch (e) {
            return [];
        }
    }

    function absorb(text) {
        const cards = root.section(text, "cards");
        root.cards = cards.map((c) => {
            const profiles = c.profiles || {};
            return {
                "index": c.index,
                "name": c.name,
                "description": (c.properties || {})["device.description"] || c.name,
                "icon": (c.properties || {})["device.icon_name"] || "",
                "active": c.active_profile || "",
                // "off" is left out on purpose: a card switched off keeps no
                // devices, and a row that is gone cannot be switched back
                "profiles": Object.keys(profiles).filter((p) => {
                    return p !== "off" && (profiles[p].available !== false || p === c.active_profile);
                }).sort((x, y) => {
                    return (profiles[y].priority || 0) - (profiles[x].priority || 0);
                }).map((p) => {
                    return {
                        "key": p,
                        "label": profiles[p].description || p
                    };
                })
            };
        });
        const ports = {
        };
        // pulse numbers sinks and sources apart, so a sink index and a source
        // index of the same number are two different devices
        const sinkIds = {
        };
        const sourceIds = {
        };
        const readDevices = (list, ids) => {
            for (var i = 0; i < list.length; i++) {
                const d = list[i];
                ids[d.index] = {
                    "name": d.name,
                    "label": d.description || d.name
                };
                ports[d.name] = {
                    "active": d.active_port || "",
                    "list": (d.ports || []).map((p) => {
                        return {
                            "key": p.name,
                            "label": p.description || p.name,
                            "available": p.availability !== "not available"
                        };
                    })
                };
            }
        };
        readDevices(root.section(text, "sinks"), sinkIds);
        readDevices(root.section(text, "sources"), sourceIds);
        root.devicePorts = ports;
        const routes = {
        };
        const readStreams = (list, key, ids) => {
            for (var i = 0; i < list.length; i++) {
                const s = list[i];
                const node = parseInt((s.properties || {})["object.id"]);
                if (isNaN(node))
                    continue;

                // a recording stream may be sitting on a monitor, which pipewire
                // keeps no node for, so the name it went to is carried along
                const on = ids[s[key]];
                routes[node] = {
                    "id": s.index,
                    "target": on ? on.name : "",
                    "label": on ? on.label : ""
                };
            }
        };
        readStreams(root.section(text, "sink-inputs"), "sink", sinkIds);
        readStreams(root.section(text, "source-outputs"), "source", sourceIds);
        root.streamRoutes = routes;
        // which streams were sent somewhere by hand
        const meta = text.indexOf("@metadata@");
        const pins = {};
        if (meta >= 0) {
            const re = /id:(\d+) key:'target\.(?:object|node)' value:'([^']*)'/g;
            const body = text.substring(meta);
            let m;
            while ((m = re.exec(body)) !== null) {
                if (m[2] !== "" && m[2] !== "-1")
                    pins[m[1]] = true;

            }
        }
        root.pinned = pins;
    }

    Process {
        id: actionProc

        onExited: (code) => {
            root.lastError = code === 0 ? "" : "pactl would not make that change";
            root.refresh();
            if (String(actionProc.command[2] || "").indexOf("wpctl settings") === 0)
                root.refreshWp();

            root.drain();
        }
    }

    // pipewire says the moment anything moves, so there is nothing to poll
    Process {
        id: monitor

        running: true
        command: ["pactl", "subscribe"]
        // pipewire-pulse going down takes the subscription with it; come back
        // on a delay so a machine without pactl does not spin
        onExited: respawn.restart()

        stdout: SplitParser {
            onRead: (line) => {
                // volume moves arrive as a change on the device itself and say
                // nothing about profiles, ports or routing
                if (line.indexOf("'change' on sink #") >= 0 || line.indexOf("'change' on source #") >= 0)
                    return ;

                settle.restart();
            }
        }

    }

    Timer {
        id: respawn

        interval: 5000
        onTriggered: {
            monitor.running = true;
            root.refresh();
        }
    }

    Timer {
        id: settle

        interval: 600
        onTriggered: root.refresh()
    }

    // a device that has just appeared has no pactl entry here yet
    Connections {
        function onValuesChanged() {
            settle.restart();
        }

        target: Pipewire.nodes
    }

    PwObjectTracker {
        objects: root.tracked
    }

    Component.onCompleted: {
        root.refresh();
        root.refreshWp();
    }
}
