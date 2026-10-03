import QtQuick
import qs

// one matugen template in Settings -> Theme: the app it colours, the file it
// writes, how the last change went, and a switch. a failure shows matugen's
// own reason as the row's warning
SettingRow {
    id: row

    required property var modelData
    readonly property var t: row.modelData
    readonly property bool working: Templates.busy === row.t.name || Templates.busy === "*"
    // removing takes a second click within a few seconds
    property bool armed: false

    function short(path) {
        return path.indexOf(Templates.home + "/") === 0 ? "~" + path.slice(Templates.home.length) : path;
    }

    readonly property string stateText: {
        if (row.working)
            return "Rendering...";

        switch (row.t.state) {
        case "ok":
            return "Coloured on the last change";
        case "skipped":
            return "Written by Lucid itself under this palette";
        case "failed":
            return "Did not render on the last change";
        case "off":
            return "Off, its file keeps the colours it last had";
        default:
            return "Not rendered yet";
        }
    }

    title: row.t.app !== "" ? row.t.app : row.t.name
    // the template's own name only where the app's reads differently
    description: (row.t.app !== "" && row.t.app.toLowerCase() !== row.t.name.toLowerCase() ? row.t.name + " · " : "") + row.short(row.t.outputPath || row.t.output) + "\n" + row.stateText
    warning: row.t.state === "failed" ? row.t.error : ""

    Row {
        spacing: 6

        M3IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 36
            enabled: row.t.inputPath !== ""
            // pencil
            iconPath: "edit"
            onClicked: Templates.openFile(row.t.inputPath)
        }

        M3IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 36
            visible: !row.t.required
            enabled: !row.working
            destructive: row.armed
            variant: row.armed ? "filled" : "standard"
            // bin
            iconPath: "delete"
            onClicked: {
                if (row.armed) {
                    row.armed = false;
                    Templates.remove(row.t.name);
                } else {
                    row.armed = true;
                    disarm.restart();
                }
            }
        }

        M3Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: row.t.enabled
            enabled: !row.t.required && !row.working
            onToggled: (value) => {
                return Templates.setEnabled(row.t.name, value);
            }
        }

        Timer {
            id: disarm

            interval: 3000
            onTriggered: row.armed = false
        }

    }

}
