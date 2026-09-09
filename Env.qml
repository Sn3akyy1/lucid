import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// the appearance outside the shell; envtool.py owns the files it lands in
Singleton {
    id: root

    readonly property string helper: Qt.resolvedUrl("lucidprefs/envtool.py").toString().replace("file://", "")
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
        "cursorTheme": Prefs.envCursorTheme,
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

    function apply() {
        if (!Prefs.loaded || !root.probed || !Prefs.envAdopted || root.adopting)
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
    }

    function loadPreviews() {
        if (root.previewsLoaded || previewProc.running)
            return ;

        previewProc.running = true;
    }

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
