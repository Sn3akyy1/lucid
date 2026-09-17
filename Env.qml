import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// the appearance outside the shell; envtool.py owns the files it lands in
Singleton {
    id: root

    readonly property string helper: Qt.resolvedUrl("lucidprefs/envtool.py").toString().replace("file://", "")
    readonly property string shadowHelper: Qt.resolvedUrl("lucidprefs/cursorshadow.py").toString().replace("file://", "")
    property bool probed: false
    property var cursorThemes: []
    property var iconThemes: []
    property var gtkThemes: []
    property var qtStyles: []
    // which of the eight targets this machine actually has
    property var targets: ({
    })
    property var lastTouched: []
    property string lastError: ""
    property bool busy: false
    readonly property var cursorSizes: [16, 20, 24, 28, 32, 40, 48, 64]
    readonly property var cursorSizeLabels: ["16 px", "20 px", "24 px", "28 px", "32 px", "40 px", "48 px", "64 px"]
    readonly property var platformThemes: ["qt6ct", "qt5ct", "gtk3", "gnome", "kde", ""]
    // the app font follows the shell's own unless it has been set apart
    readonly property string appFont: Prefs.envFontSync ? Prefs.fontFamily : Prefs.envAppFont
    readonly property bool cursorMissing: root.probed && !root.has(root.cursorThemes, Prefs.envCursorTheme)
    // hyprland has no cursor-shadow option; the shade is painted into the theme
    // itself, so turning it off means rebuilding the theme from its svg sources
    property var shadowThemes: ({
    })
    readonly property var shadowInfo: root.shadowThemes[Prefs.envCursorTheme] || ({
    })
    readonly property bool shadowCapable: root.shadowInfo.capable === true
    readonly property bool shadowBuilt: root.shadowInfo.built === true
    readonly property string shadowReason: root.shadowInfo.reason || ""
    readonly property bool shadowOff: root.shadowCapable && !Prefs.envCursorShadow
    readonly property bool shadowNeedsBuild: root.shadowOff && !root.shadowBuilt
    property bool shadowProbed: false
    property bool shadowBuilding: false
    property string shadowError: ""
    // what the eight files are actually told, which is the variant when it exists
    readonly property string cursorTheme: root.shadowOff && root.shadowBuilt ? root.shadowInfo.variant : Prefs.envCursorTheme
    readonly property bool iconMissing: root.probed && !root.has(root.iconThemes, Prefs.envIconTheme)
    readonly property bool gtkMissing: root.probed && !root.has(root.gtkThemes, Prefs.envGtkTheme)
    readonly property int scopeCount: (Prefs.envApplyGtk ? 1 : 0) + (Prefs.envApplyQt ? 1 : 0) + (Prefs.envApplyHypr ? 1 : 0)
    readonly property string summary: {
        if (!root.probed)
            return "Looking at what this machine has installed…";

        if (root.scopeCount === 0)
            return "Nothing is being written — every toolkit below is turned off";

        var parts = [];
        if (Prefs.envApplyGtk)
            parts.push("GTK");

        if (Prefs.envApplyQt)
            parts.push("Qt");

        if (Prefs.envApplyHypr)
            parts.push("Hyprland");

        return "Applied to " + parts.join(", ");
    }
    // everything envtool.py needs, in the shape it reads
    readonly property string payload: JSON.stringify({
        "cursorTheme": root.cursorTheme,
        "cursorSize": Prefs.envCursorSize,
        "iconTheme": Prefs.envIconTheme,
        "gtkTheme": Prefs.envGtkTheme,
        "qtStyle": Prefs.envQtStyle,
        "qtPlatformTheme": Prefs.envQtPlatformTheme,
        "colorScheme": Prefs.envColorScheme,
        "appFont": root.appFont,
        "appFontSize": Prefs.envAppFontSize,
        "documentFont": Prefs.envDocumentFont,
        "documentFontSize": Prefs.envDocumentFontSize,
        "monoFont": Prefs.envMonoFont,
        "monoFontSize": Prefs.envMonoFontSize,
        "applyGtk": Prefs.envApplyGtk,
        "applyQt": Prefs.envApplyQt,
        "applyHypr": Prefs.envApplyHypr
    })
    // what was written last, so a reload does not rewrite the same eight files
    property string applied: ""
    // prefs writes are debounced, so payload keeps moving after adopt() returns
    property bool adopting: false
    // theme name -> its folder icon, resolved once on first open
    property var iconPreviews: ({
    })
    property bool previewsLoaded: false

    function sizeIndex(px) {
        var best = 0, dist = 9999;
        for (var i = 0; i < root.cursorSizes.length; i++) {
            var d = Math.abs(root.cursorSizes[i] - px);
            if (d < dist) {
                dist = d;
                best = i;
            }
        }
        return best;
    }

    function sizeAt(i) {
        return root.cursorSizes[Math.max(0, Math.min(root.cursorSizes.length - 1, Math.round(i)))];
    }

    function has(list, name) {
        return name === "" || list.indexOf(name) !== -1;
    }

    // the light/dark counterpart of a theme name, "" when nothing installed
    // matches. naming is not standardised, so this tries the conventions that
    // are actually out there rather than assuming one: FairyWren_Dark pairs
    // with FairyWren_Light, but adw-gtk3-dark's light build is plain adw-gtk3,
    // which is why the bare stem is a candidate too. checking the installed
    // list is the whole point - the old wallpaper hook assumed adw-gtk3-light
    // and set a theme this machine has never had.
    function variantOf(name, list, light) {
        if (!name || !list || list.length === 0)
            return "";

        var from = light ? "dark" : "light";
        var to = light ? "light" : "dark";
        var re = new RegExp("([-_ ]?)(" + from + ")$", "i");
        var m = name.match(re);
        var cands = [];
        if (m) {
            var w = m[2];
            var word = w === w.toUpperCase() ? to.toUpperCase() : (w[0] === w[0].toUpperCase() ? to[0].toUpperCase() + to.substring(1) : to);
            cands.push(name.replace(re, m[1] + word));
            cands.push(name.replace(re, ""));
        } else {
            cands.push(name + "-" + to, name + "_" + to[0].toUpperCase() + to.substring(1), name + "-" + to[0].toUpperCase() + to.substring(1));
        }
        for (var i = 0; i < cands.length; i++) {
            if (cands[i] !== name && cands[i] !== "" && list.indexOf(cands[i]) !== -1)
                return cands[i];
        }
        return "";
    }

    Connections {
        // only fires from Prefs.setColorMode, so loading the cache file at
        // startup never rewrites the user's theme choices behind their back
        function onColorModeApplied(mode) {
            // only rewrite theme names Lucid is actually managing; un-adopted,
            // these prefs describe the machine rather than drive it
            if (!Prefs.envAdopted || !root.probed)
                return ;

            var light = mode === "light";
            var gtk = root.variantOf(Prefs.envGtkTheme, root.gtkThemes, light);
            if (gtk !== "")
                Prefs.envGtkTheme = gtk;

            var icons = root.variantOf(Prefs.envIconTheme, root.iconThemes, light);
            if (icons !== "")
                Prefs.envIconTheme = icons;
        }

        target: Prefs
    }

    function apply() {
        if (!Prefs.loaded || !root.probed || !root.shadowProbed || !Prefs.envAdopted || root.adopting || root.shadowBuilding)
            return ;

        var want = root.payload;
        if (want === root.applied)
            return ;

        root.applied = want;
        root.busy = true;
        applyProc.running = false;
        applyProc.command = ["python3", root.helper, "apply", want];
        applyProc.running = true;
    }

    // read the machine's own settings in; must never write them back out
    function adopt(cur) {
        Prefs.set("envCursorTheme", cur.cursorTheme || "");
        Prefs.set("envCursorSize", cur.cursorSize || 24);
        Prefs.set("envCursorShadow", cur.cursorShadow !== false);
        Prefs.set("envIconTheme", cur.iconTheme || "");
        Prefs.set("envGtkTheme", cur.gtkTheme || "");
        Prefs.set("envQtStyle", cur.qtStyle || "Fusion");
        Prefs.set("envQtPlatformTheme", cur.qtPlatformTheme || "");
        Prefs.set("envColorScheme", cur.colorScheme || "auto");
        Prefs.set("envAppFont", cur.appFont || Prefs.fontFamily);
        Prefs.set("envAppFontSize", cur.appFontSize || 11);
        Prefs.set("envDocumentFont", cur.documentFont || cur.appFont || Prefs.fontFamily);
        Prefs.set("envDocumentFontSize", cur.documentFontSize || 11);
        Prefs.set("envMonoFont", cur.monoFont || "monospace");
        Prefs.set("envMonoFontSize", cur.monoFontSize || 10);
        Prefs.set("envAdopted", true);
    }

    function rescan() {
        probeProc.running = false;
        probeProc.running = true;
        shadowProc.running = false;
        shadowProc.running = true;
    }

    // rendering a whole theme takes a few seconds, so it is built once and kept
    function buildShadowless() {
        if (root.shadowBuilding || !root.shadowNeedsBuild)
            return ;

        root.shadowError = "";
        root.shadowBuilding = true;
        buildProc.command = ["python3", root.shadowHelper, "build", Prefs.envCursorTheme];
        buildProc.running = true;
    }

    // the probe names each theme's variant; note one as built without re-probing
    function markBuilt(variant) {
        var base = variant.replace(/-noshadow$/, "");
        var m = Object.assign({
        }, root.shadowThemes);
        m[base] = Object.assign({
        }, m[base] || ({
        }), {
            "built": true
        });
        root.shadowThemes = m;
    }

    function loadPreviews() {
        if (root.previewsLoaded || previewProc.running)
            return ;

        previewProc.running = true;
    }

    onShadowNeedsBuildChanged: root.buildShadowless()
    onPayloadChanged: {
        if (root.adopting) {
            root.applied = root.payload;
            adoptSettle.restart();
        } else if (root.probed && Prefs.envAdopted) {
            applyDebounce.restart();
        }
    }

    Timer {
        id: applyDebounce

        interval: 500
        repeat: false
        onTriggered: root.apply()
    }

    Timer {
        id: adoptSettle

        interval: 900
        repeat: false
        onTriggered: {
            root.adopting = false;
            root.applied = root.payload;
        }
    }

    Process {
        id: probeProc

        running: true
        command: ["python3", root.helper, "probe"]

        stdout: StdioCollector {
            onStreamFinished: {
                var d = {
                };
                try {
                    d = JSON.parse(this.text.trim() || "{}");
                } catch (e) {
                    root.lastError = "could not read the machine's appearance settings";
                    root.probed = true;
                    return ;
                }
                root.cursorThemes = d.cursorThemes || [];
                root.iconThemes = d.iconThemes || [];
                root.gtkThemes = d.gtkThemes || [];
                root.qtStyles = d.qtStyles || [];
                root.targets = d.targets || ({
                });
                root.probed = true;
                if (!Prefs.envAdopted && d.current) {
                    root.adopting = true;
                    root.adopt(d.current);
                    root.applied = root.payload;
                    adoptSettle.restart();
                } else {
                    root.apply();
                }
            }
        }

    }

    Process {
        id: shadowProc

        running: true
        command: ["python3", root.shadowHelper, "probe"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.shadowThemes = JSON.parse(this.text.trim() || "{}").themes || ({
                    });
                } catch (e) {
                    root.shadowThemes = ({
                    });
                }
                root.shadowProbed = true;
                root.buildShadowless();
                root.apply();
            }
        }

    }

    Process {
        id: buildProc

        onExited: {
            root.shadowBuilding = false;
            // the theme may have changed while this one was rendering
            Qt.callLater(root.buildShadowless);
            Qt.callLater(root.apply);
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var r = {
                };
                try {
                    r = JSON.parse(this.text.trim() || "{}");
                } catch (e) {
                }
                if (r.ok && r.theme)
                    root.markBuilt(r.theme);
                else
                    root.shadowError = r.error || "could not rebuild the theme without its shadow";
            }
        }

    }

    Process {
        id: previewProc

        command: ["python3", root.helper, "icons"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.iconPreviews = JSON.parse(this.text.trim() || "{}");
                    root.previewsLoaded = true;
                } catch (e) {
                    root.iconPreviews = ({
                    });
                }
            }
        }

    }

    Process {
        id: applyProc

        onExited: {
            root.busy = false;
            // the pickers list what is installed; a theme may have arrived since
            root.rescan();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var r = JSON.parse(this.text.trim() || "{}");
                    root.lastTouched = r.touched || [];
                    root.lastError = r.ok === false ? (r.error || "could not apply") : "";
                } catch (e) {
                    root.lastError = "could not apply";
                }
            }
        }

    }

    // a reset clears envAdopted, which re-reads the machine instead of blanking
    Connections {
        function onLoadedChanged() {
            if (Prefs.loaded)
                root.rescan();

        }

        function onEnvAdoptedChanged() {
            if (Prefs.loaded && !Prefs.envAdopted)
                root.rescan();

        }

        target: Prefs
    }

}
