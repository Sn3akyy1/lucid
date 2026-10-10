import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// files sent to this machine over bluetooth. lucidprefs/bt-receive.py answers
// obexd's push requests with notifications; this keeps it running, hands it
// the settings and remembers what came in for the settings page.
Singleton {
    id: root

    readonly property bool active: Prefs.loaded && Prefs.btReceive && Bt.present
    // "starting" | "ready" | "missing" (no obexd) | "taken" (another agent) | "error" | "off"
    property string status: "off"
    property string detail: ""
    property string defaultFolder: ""
    readonly property string folder: Prefs.btReceiveFolder !== "" ? Prefs.btReceiveFolder : root.defaultFolder
    // newest first, this session only: {file, name, device, time}
    property var recent: []
    property int restarts: 0

    function pretty(path) {
        const home = Quickshell.env("HOME") || "";
        if (home !== "" && (path === home || path.indexOf(home + "/") === 0))
            return "~" + path.slice(home.length);

        return path;
    }

    function send(obj) {
        if (helper.running)
            helper.write(JSON.stringify(obj) + "\n");

    }

    function sendConfig() {
        root.send({
            "cmd": "config",
            "folder": Prefs.btReceiveFolder,
            "autoPaired": Prefs.btReceiveAutoPaired
        });
    }

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }

    // the helper asks FileManager1 to select the file and falls back to
    // opening the folder
    function showInFolder(path) {
        if (helper.running)
            root.send({
            "cmd": "show",
            "file": path
        });
        else
            Quickshell.execDetached(["xdg-open", path.replace(/\/[^\/]*$/, "") || "/"]);
    }

    function openFolder() {
        if (root.folder !== "")
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "sh", root.folder]);

    }

    function forget(file) {
        root.recent = root.recent.filter((r) => {
            return r.file !== file;
        });
    }

    onActiveChanged: {
        root.restarts = 0;
        if (root.active)
            root.status = "starting";
        else
            root.status = "off";
        helper.running = root.active;
    }
    Component.onCompleted: {
        root.status = root.active ? "starting" : "off";
        helper.running = root.active;
    }

    Connections {
        function onBtReceiveFolderChanged() {
            root.sendConfig();
        }

        function onBtReceiveAutoPairedChanged() {
            root.sendConfig();
        }

        target: Prefs
    }

    // `running` is driven by hand, as with the kde connect bridge: quickshell
    // clears it when the process exits, which would kill a binding
    Timer {
        id: restart

        interval: 3000
        onTriggered: {
            if (root.active && !helper.running)
                helper.running = true;

        }
    }

    Process {
        id: helper

        stdinEnabled: true
        command: ["python3", Qt.resolvedUrl("lucidprefs/bt-receive.py").toString().replace("file://", "")]
        onStarted: root.sendConfig()
        onExited: (code) => {
            if (!root.active) {
                root.status = "off";
                return ;
            }
            root.status = "error";
            if (root.detail === "")
                root.detail = "The helper stopped (code " + code + ").";

            // a helper that keeps dying is left down rather than spun forever
            if (root.restarts < 5) {
                root.restarts++;
                restart.restart();
            }
        }

        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "")
                    return ;

                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return ;
                }
                if (d.type === "state") {
                    root.status = d.state || "error";
                    root.detail = d.detail || "";
                    if (d.defaultFolder)
                        root.defaultFolder = d.defaultFolder;

                    if (root.status === "ready")
                        root.restarts = 0;

                } else if (d.type === "received") {
                    const next = [{
                        "file": d.file,
                        "name": d.name,
                        "device": d.device,
                        "time": d.time
                    }].concat(root.recent.filter((r) => {
                        return r.file !== d.file;
                    }));
                    root.recent = next.slice(0, 8);
                }
            }
        }

        stderr: SplitParser {
            onRead: (line) => {
                if (line.indexOf("No module named") >= 0)
                    root.detail = "python-gobject is missing, so obexd cannot be reached.";

            }
        }

    }

}
