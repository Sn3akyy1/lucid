import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// lucid's own sounds, synthesised by support/sounds/build-sounds.py into
// assets/sounds. every play is a paplay of its own so two can overlap, but the
// same sound twice in a moment plays once: a burst of notifications or a hub
// full of devices is one sound rather than a pile-up
Singleton {
    id: root

    readonly property string dir: Quickshell.shellPath("assets/sounds")
    // the notification picker's choices, in its order
    readonly property var notifSounds: [
        { "key": "glint", "label": "Glint" },
        { "key": "pulse", "label": "Pulse" },
        { "key": "chime", "label": "Chime" },
        { "key": "tap", "label": "Tap" },
        { "key": "orbit", "label": "Orbit" },
        { "key": "halo", "label": "Halo" },
        { "key": "beacon", "label": "Beacon" },
        { "key": "alert", "label": "Alert" }
    ]
    readonly property var systemSounds: ["usb-in", "usb-out", "bt-in", "bt-out", "power-in", "power-out", "charged", "battery-low", "battery-critical", "camera-on", "camera-off", "capture", "alarm", "reminder", "volume", "brightness", "caps-on", "caps-off", "mic-on", "mic-off"]
    // the freedesktop names a saved setting can still hold, carried across
    readonly property var legacy: ({
        "message": "pulse",
        "bell": "glint",
        "complete": "chime",
        "suspend-error": "alert"
    })
    property var lastPlayed: ({})
    property var pending: []
    property real pendingVolume: 1

    function notifKey(name) {
        const k = root.legacy[name] || name;
        return root.notifSounds.some((s) => {
            return s.key === k;
        }) ? k : root.notifSounds[0].key;
    }

    // paplay's --volume rides PulseAudio's cubic scale, so a bare 0.6 is a 13 dB
    // cut rather than six tenths of the loudness; cube-root it back
    function paVolume(v) {
        return Math.round(65536 * Math.cbrt(Math.max(0, Math.min(1, v))));
    }

    // gap: how long after the last play of the same sound another is dropped
    function play(key, volume, gap) {
        const now = Date.now();
        if (now - (root.lastPlayed[key] || 0) < (gap || 150))
            return ;

        root.lastPlayed[key] = now;
        Quickshell.execDetached(["paplay", "--client-name=Lucid", "--stream-name=" + key, "--property=media.role=event", "--volume=" + root.paVolume(volume === undefined ? 1 : volume), root.dir + "/" + key + ".oga"]);
    }

    // a system event: the master switch, the event's own, and their volume.
    // silenced means silenced, warnings aside
    function event(key, on, warning) {
        if (!Prefs.sysSounds || !on)
            return ;

        if (Notifs.silenced && warning !== true)
            return ;

        root.play(key, Prefs.sysSoundVolume);
    }

    // the answer to a key or a slider you just moved: silenced or not, it plays
    function feedback(key, on) {
        if (Prefs.sysSounds && on)
            root.play(key, Prefs.sysSoundVolume, 60);

    }

    // a few a beat apart, so a preview can play the plug-in and the pull-out
    function sequence(keys, volume) {
        root.pending = keys.slice(1);
        root.pendingVolume = volume;
        root.play(keys[0], volume);
        if (root.pending.length > 0)
            sequenceTimer.restart();
        else
            sequenceTimer.stop();
    }

    Timer {
        id: sequenceTimer

        interval: 900
        onTriggered: {
            const key = root.pending[0];
            root.pending = root.pending.slice(1);
            root.play(key, root.pendingVolume);
            if (root.pending.length > 0)
                sequenceTimer.restart();

        }
    }

    IpcHandler {
        // qs ipc call sounds play usb-in
        function play(key: string): void {
            root.play(key, Prefs.sysSoundVolume);
        }

        function list(): string {
            return root.notifSounds.map((s) => {
                return s.key;
            }).concat(root.systemSounds).join(" ");
        }

        target: "sounds"
    }

}
