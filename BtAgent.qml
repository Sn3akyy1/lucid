import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// bluez's pairing agent. lucidprefs/bt-agent.py lets paired devices open
// their audio and input profiles and turns codes to confirm into
// notifications; without it bluez refuses anything not marked trusted.
Singleton {
    id: root

    readonly property bool active: Bt.present && Prefs.btAgent
    // "starting" | "ready" | "missing" (bluetoothd gone) | "error" | "off"
    property string status: "off"
    property string detail: ""
    property int restarts: 0

    onActiveChanged: {
        root.restarts = 0;
        root.status = root.active ? "starting" : "off";
        helper.running = root.active;
    }
    Component.onCompleted: {
        root.status = root.active ? "starting" : "off";
        helper.running = root.active;
    }

    // `running` is driven by hand, as with the receiver: quickshell clears it
    // when the process exits, which would kill a binding
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

        command: ["python3", Qt.resolvedUrl("lucidprefs/bt-agent.py").toString().replace("file://", "")]
        onExited: (code) => {
            if (!root.active) {
                root.status = "off";
                return ;
            }
            root.status = "error";
            if (root.detail === "")
                root.detail = I18n.tr("The helper stopped (code %1).", code);

            // a helper that keeps dying is left down rather than spun forever
            if (root.restarts < 5) {
                root.restarts++;
                restart.restart();
            }
        }

        stdout: SplitParser {
            onRead: (line) => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return ;
                }
                if (d.type !== "state")
                    return ;

                root.status = d.state || "error";
                root.detail = d.detail || "";
                if (root.status === "ready")
                    root.restarts = 0;

            }
        }

        stderr: SplitParser {
            onRead: (line) => {
                if (line.indexOf("No module named") >= 0)
                    root.detail = I18n.tr("python-gobject is missing, so bluez cannot be answered.");

            }
        }

    }

}
