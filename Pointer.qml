import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// lucid's own pointer: Bibata Modern, which cursortheme.py draws in the
// palette's colours. this works the colours out, has the theme drawn again
// whenever they change, and walks the pointer across to them over the
// palette's fade
Singleton {
    id: root

    readonly property string themeName: "lucid-cursors"
    readonly property string helper: Qt.resolvedUrl("lucidprefs/cursortheme.py").toString().replace("file://", "")
    readonly property string themeDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/icons/" + root.themeName
    readonly property var styles: [{
        "key": "dark",
        "label": "Dark"
    }, {
        "key": "light",
        "label": "Light"
    }, {
        "key": "accent",
        "label": "Accent"
    }]
    // legacy cursors hand the pointer back to a theme installed on the machine
    readonly property bool active: !Prefs.envLegacyCursor
    property bool probed: false
    // what the theme on disk was drawn with, null while there is none
    property var stamp: null
    // the script's own drawing, so a theme an older one drew is drawn again
    property int design: 0
    // hyprcursor can find it; retired while legacy cursors are on
    property bool live: false
    readonly property bool ready: root.stamp !== null && root.live
    // drawn by this version's design, so what it wrote matches what is asked for
    readonly property bool drawn: root.ready && root.stamp.design === root.design
    property bool busy: false
    property string error: ""
    // the colours on screen, part of the way through a fade or not
    property var shown: null
    // bumped after every drawing, so previews of the theme load again
    property int revision: 0
    property bool _again: false
    property bool _retiring: false

    // Hyprland keeps drawing the image it has when the theme changes, until
    // the shape asked for changes: each window with a PointerPoke asks again
    signal poked()

    function poke() {
        root.poked();
    }

    // a colour at a tone, at a saturation of its own
    function toned(c, tone, sat) {
        if (c.hslHue < 0)
            return Theme.atTone(c, tone);

        return Theme.atTone(Qt.hsla(c.hslHue, sat, 0.5, 1), tone);
    }

    function hex(c) {
        const h = (x) => {
            return ("0" + Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16)).slice(-2);
        };
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    // the body and the outline around it, then the colours bibata draws its
    // badges and busy ring in, taken from the palette. accent turns over with
    // light and dark the way a filled button does; dark and light stay put.
    // the keys are in the order cursortheme.py writes them back in
    readonly property var colours: {
        const p = Theme.cPrimary;
        const style = Prefs.envCursorStyle;
        let body, ink;
        // dark ends are kept to a tint, as the ramp would run them at full
        // colour; light ends stay off white, where no colour is left to show
        if (style === "light") {
            body = Theme.tonal(p, 90);
            ink = root.toned(p, 14, 0.5);
        } else if (style === "accent") {
            body = Theme.isLight ? Theme.tonal(p, 40) : Theme.tonal(p, 82);
            ink = Theme.isLight ? root.toned(p, 99, 0.25) : Theme.tonal(p, 13);
        } else {
            body = root.toned(p, 11, 0.4);
            ink = Theme.tonal(p, 82);
        }
        // marks on a dark body are light, and the other way round
        const dark = style === "dark" || (style === "accent" && Theme.isLight);
        const mark = dark ? 72 : 45;
        const e = Theme.cError;
        return {
            "body": root.hex(body),
            "ink": root.hex(ink),
            // a sign that says no has to read as one, so the error hue at full colour
            "error": root.hex(root.toned(e, 55, Math.max(0.65, e.hslSaturation))),
            "a1": root.hex(Theme.tonal(p, mark)),
            "a2": root.hex(Theme.tonal(Theme.cTertiary, mark)),
            "a3": root.hex(Theme.tonal(Theme.cSecondary, mark)),
            "a4": root.hex(Theme.tonal(p, dark ? 88 : 30)),
            "raised": root.hex(dark ? root.toned(p, 26, 0.45) : root.toned(p, 86, 0.25)),
            "muted": root.hex(root.toned(p, dark ? 58 : 50, 0.12)),
            "shadow": "#000000"
        };
    }
    readonly property var spec: ({
        "colours": root.colours,
        "shadow": Prefs.envCursorShadow,
        "size": Prefs.envCursorSize
    })
    readonly property string want: JSON.stringify(root.spec)
    readonly property string have: root.stamp ? JSON.stringify({
        "colours": root.stamp.colours,
        "shadow": root.stamp.shadow,
        "size": root.stamp.size
    }) : ""

    function sync() {
        // before prefs load, legacy reads as off and would retire a theme in use
        if (!root.probed || !Prefs.loaded || !Theme.paletteLoaded || root._retiring)
            return ;

        if (!root.active) {
            if (root.live)
                root.retire();

            return ;
        }
        if (root.ready && root.want === root.have && root.stamp.design === root.design)
            return ;

        // a newer palette: stop where the last one got to and start from there
        if (proc.running) {
            root._again = true;
            proc.running = false;
            return ;
        }
        const s = Object.assign({
        }, root.spec);
        // only the colours moved, on a theme that is up: that fades
        const fades = root.ready && root.stamp.design === root.design && root.stamp.shadow === s.shadow && root.stamp.size === s.size && Theme.recolourMs > 0;
        if (fades)
            s.from = root.shown || root.stamp.colours;

        s.duration = Theme.recolourMs;
        root.error = "";
        root.busy = true;
        proc.command = ["python3", root.helper, fades ? "fade" : "build", JSON.stringify(s)];
        proc.running = true;
    }

    function retire() {
        if (proc.running) {
            root._again = true;
            proc.running = false;
            return ;
        }
        root._retiring = true;
        root.busy = true;
        proc.command = ["python3", root.helper, "retire"];
        proc.running = true;
    }

    // the palette arrives a property at a time; draw once it has all landed
    onWantChanged: syncLater.restart()
    onActiveChanged: syncLater.restart()

    Connections {
        function onLoadedChanged() {
            syncLater.restart();
        }

        target: Prefs
    }

    Timer {
        id: syncLater

        interval: 60
        onTriggered: root.sync()
    }

    Process {
        id: probeProc

        running: true
        command: ["python3", root.helper, "probe"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(this.text.trim() || "{}");
                    root.stamp = r.stamp || null;
                    root.design = r.design || 0;
                    root.live = r.live === true;
                    root.shown = root.stamp ? root.stamp.colours : null;
                } catch (e) {
                    root.stamp = null;
                }
                root.probed = true;
                root.sync();
            }
        }

    }

    Process {
        id: proc

        onExited: {
            root.busy = false;
            if (root._retiring) {
                root._retiring = false;
                root.live = false;
            }
            if (root._again) {
                root._again = false;
                Qt.callLater(root.sync);
            }
        }

        stdout: SplitParser {
            onRead: (line) => {
                let r = null;
                try {
                    r = JSON.parse(line);
                } catch (e) {
                    return ;
                }
                if (r.step !== undefined) {
                    root.shown = r.colours;
                    root.poke();
                } else if (r.swap || r.hires) {
                    // hires: the plugin's copy for shake to find has loaded again
                    root.poke();
                } else if (r.ok === true && r.stamp) {
                    // the script that drew it says which design is current, even
                    // when it has been updated since the shell started
                    root.design = r.stamp.design;
                    root.stamp = r.stamp;
                    root.live = true;
                    root.shown = r.stamp.colours;
                    root.revision++;
                } else if (r.ok === false) {
                    root.error = r.error || "could not draw the pointer";
                }
            }
        }

    }

}
