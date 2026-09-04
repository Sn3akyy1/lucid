pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// qt reads the icon theme once at process start and never again, so
// Quickshell.iconPath() keeps handing back whatever theme was active when the
// shell launched. this resolves names against the theme directories itself,
// which is what lets the dock follow an icon theme change without a restart.
QtObject {
    id: iconTheme

    readonly property string script: Qt.resolvedUrl("./resolve-icons.sh").toString().replace("file://", "")

    property string themeName: ""
    // every icon binding reads this, so bumping it re-runs the lookups
    property int generation: 0

    // name -> path, "" meaning "the theme has nothing for this"
    property var resolved: ({})
    property var queued: ({})

    // "" means unresolved: callers fall back to Quickshell.iconPath themselves
    function pathFor(name) {
        if (!name || name === "")
            return "";

        if (name.charAt(0) === "/")
            return "file://" + name;

        var hit = iconTheme.resolved[name];
        if (hit !== undefined)
            return hit === "" ? "" : "file://" + hit;

        if (!iconTheme.queued[name]) {
            iconTheme.queued[name] = true;
            iconTheme.batch.restart();
        }
        return "";
    }

    function runBatch() {
        // one batch at a time, or a rename storm spawns a process per icon
        if (iconTheme.resolver.running) {
            iconTheme.batch.restart();
            return;
        }
        var names = Object.keys(iconTheme.queued);
        if (names.length === 0 || iconTheme.themeName === "")
            return;

        iconTheme.pendingNames = names;
        iconTheme.queued = ({});
        iconTheme.resolver.command = ["sh", iconTheme.script, iconTheme.themeName].concat(names);
        iconTheme.resolver.running = true;
    }

    property var pendingNames: []

    // a theme change invalidates every path, so drop the cache and let the
    // bindings ask again - they re-queue themselves through pathFor
    function setTheme(name) {
        var clean = name.trim().replace(/^icon-theme:\s*/, "").replace(/^'|'$/g, "").trim();
        if (clean === "" || clean === iconTheme.themeName)
            return;

        iconTheme.themeName = clean;
        iconTheme.resolved = ({});
        iconTheme.queued = ({});
        iconTheme.generation++;
    }

    // prints the current theme, then one line per change, for as long as the
    // shell runs
    property Process watcher: Process {
        running: true
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface icon-theme; gsettings monitor org.gnome.desktop.interface icon-theme"]

        stdout: SplitParser {
            onRead: line => iconTheme.setTheme(line)
        }
    }

    property Timer batch: Timer {
        interval: 40
        onTriggered: iconTheme.runBatch()
    }

    property Process resolver: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                var out = iconTheme.resolved;
                // seed every name asked for, so a miss is remembered as a miss
                // and never re-queued on each repaint
                for (var i = 0; i < iconTheme.pendingNames.length; i++)
                    out[iconTheme.pendingNames[i]] = "";

                var lines = text.split("\n");
                for (var j = 0; j < lines.length; j++) {
                    if (lines[j] === "")
                        continue;

                    var tab = lines[j].indexOf("\t");
                    if (tab <= 0)
                        continue;

                    out[lines[j].substring(0, tab)] = lines[j].substring(tab + 1);
                }
                iconTheme.resolved = out;
                iconTheme.generation++;
            }
        }
    }
}
