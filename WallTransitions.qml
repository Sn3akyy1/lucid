import "lucidprefs/WallTransitions.js" as WT
import QtQuick
import Quickshell
pragma Singleton

// how the wallpaper changes: the named presets, the ones the user saved, and the
// transition.conf that set-wallpaper.sh reads on every change. The data and the
// conf text live in lucidprefs/WallTransitions.js; this is the part that talks to
// Prefs and writes the file.
Singleton {
    id: root

    readonly property string confPath: Quickshell.env("HOME") + "/.config/lucid/wallpaper-transition.conf"
    // only here so shell.qml has something to read to bring the singleton up
    readonly property bool active: true
    readonly property var all: WT.presets(Prefs.wallTransCustomPresets)

    function values() {
        return {
            "type": Prefs.wallTransType,
            "duration": Prefs.wallTransDuration,
            "angle": Prefs.wallTransAngle,
            "origin": Prefs.wallTransOrigin,
            "bezier": Prefs.wallTransBezier,
            "wave": Prefs.wallTransWave
        };
    }

    function presetName(p) {
        return p.name;
    }

    function apply(id) {
        var p = WT.presetById(id, Prefs.wallTransCustomPresets);
        if (!p)
            return ;

        Prefs.wallTransType = p.type;
        Prefs.wallTransDuration = Number(p.duration);
        Prefs.wallTransAngle = Number(p.angle);
        Prefs.wallTransOrigin = p.origin;
        Prefs.wallTransBezier = p.bezier;
        Prefs.wallTransWave = p.wave;
        Prefs.wallTransPreset = p.id;
    }

    // a single value edited by hand: the preset only stays selected if the values
    // still match it
    function set(key, value) {
        Prefs["wallTrans" + key.charAt(0).toUpperCase() + key.slice(1)] = value;
        Prefs.wallTransPreset = WT.matchingId(root.values(), Prefs.wallTransCustomPresets);
    }

    function saveCurrent(name) {
        var n = name.trim();
        if (n === "")
            return ;

        Prefs.wallTransCustomPresets = WT.addCustom(Prefs.wallTransCustomPresets, n, root.values());
        var all = WT.presets(Prefs.wallTransCustomPresets);
        Prefs.wallTransPreset = all[all.length - 1].id;
    }

    function deleteCustom(id) {
        Prefs.wallTransCustomPresets = WT.removeCustom(Prefs.wallTransCustomPresets, id);
        if (Prefs.wallTransPreset === id)
            Prefs.wallTransPreset = WT.matchingId(root.values(), Prefs.wallTransCustomPresets);

    }

    function writeConf() {
        // temp file then mv, so the script never reads half of it
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"", "sh", root.confPath, WT.confText(root.values())]);
    }

    Timer {
        id: settle

        interval: 150
        onTriggered: root.writeConf()
    }

    Connections {
        function onWallTransTypeChanged() {
            settle.restart();
        }

        function onWallTransDurationChanged() {
            settle.restart();
        }

        function onWallTransAngleChanged() {
            settle.restart();
        }

        function onWallTransOriginChanged() {
            settle.restart();
        }

        function onWallTransBezierChanged() {
            settle.restart();
        }

        function onWallTransWaveChanged() {
            settle.restart();
        }

        target: Prefs
    }

    Component.onCompleted: settle.restart()
}
