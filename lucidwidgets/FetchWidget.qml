import QtQuick
import Quickshell
import qs
import qs.lucidui
import qs.lucidprefs as LP

// the machine at a glance, the way a fetch script prints it
WidgetBody {
    id: w

    readonly property var sample: ({
        "os": "Arch Linux",
        "kernel": "6.12.1-arch1-1",
        "host": "lucid",
        "user": "you",
        "shell": "fish",
        "cpuModel": "Intel Core i5-1135G7",
        "cores": "8",
        "gpuModel": "Intel Iris Xe Graphics",
        "packages": "1042",
        "model": "Laptop"
    })
    readonly property var info: w.preview ? w.sample : Sys.info
    readonly property real up: w.preview ? 186000 : Sys.uptime
    readonly property string memText: w.preview ? "9.8 / 15.5 GB" : (Sys.ramTotalGb > 0 ? Sys.ramUsedGb.toFixed(1) + " / " + Sys.ramTotalGb.toFixed(1) + " GB" : "")
    readonly property var rows: {
        var i = w.info || {};
        var out = [];
        function add(icon, key, value) {
            if (value)
                out.push({
                "icon": icon,
                "key": key,
                "value": value
            });

        }
        add("computer", "OS", i.os);
        add("deployed_code", "Kernel", i.kernel);
        add("schedule", "Uptime", Sys.duration(w.up));
        add("inventory_2", "Packages", i.packages ? i.packages + " (pacman)" : "");
        add("terminal", "Shell", i.shell);
        add("dashboard", "WM", "Hyprland");
        add("memory", "CPU", i.cpuModel ? i.cpuModel + (i.cores ? " ×" + i.cores : "") : "");
        add("developer_board", "GPU", i.gpuModel);
        add("memory_alt", "Memory", w.memText);
        return out;
    }
    readonly property var swatches: [Theme.primary, Theme.secondary, Theme.tertiary, Theme.error, Theme.primaryContainer, Theme.secondaryContainer, Theme.tertiaryContainer, Theme.surfaceHighest]

    defaultTone: "surface"
    Component.onCompleted: {
        if (!w.preview)
            Sys.hold("fetch-" + w.uid, true, 5000);

    }
    Component.onDestruction: Sys.hold("fetch-" + w.uid, false)

    // card: the mark and who you are, then a labelled list
    Item {
        visible: w.variant === "card"
        anchors.fill: parent
        anchors.margins: 18

        Row {
            id: cardHead

            spacing: 14

            LP.LucidaMark {
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                height: 46
                strokeWidth: 2
                ringColor: w.inkAccent
                starColor: w.ink
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -3

                LText {
                    role: "titleMedium"
                    weight: 640
                    color: w.ink
                    text: (w.info.user || "") + "@" + (w.info.host || "")
                }

                LText {
                    role: "labelMedium"
                    color: w.inkDim
                    text: "Lucid on " + (w.info.os || "Linux")
                }

            }

        }

        Column {
            anchors.top: cardHead.bottom
            anchors.topMargin: 14
            width: parent.width
            spacing: 5

            Repeater {
                model: w.rows.slice(1)

                Item {
                    id: fr

                    required property var modelData

                    width: parent.width
                    height: 20

                    Icon {
                        id: frIcon

                        anchors.verticalCenter: parent.verticalCenter
                        name: fr.modelData.icon
                        size: 16
                        fill: 1
                        color: w.inkAccent
                    }

                    LText {
                        id: frKey

                        anchors.left: frIcon.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70
                        role: "labelLarge"
                        color: w.inkDim
                        text: fr.modelData.key
                    }

                    LText {
                        anchors.left: frKey.right
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        role: "bodyMedium"
                        color: w.ink
                        text: fr.modelData.value
                        elide: Text.ElideRight
                    }

                }

            }

        }

        Row {
            anchors.bottom: parent.bottom
            spacing: 4

            Repeater {
                model: w.swatches

                Rectangle {
                    required property color modelData
                    required property int index

                    width: 22
                    height: 14
                    topLeftRadius: index === 0 ? 7 : 3
                    bottomLeftRadius: index === 0 ? 7 : 3
                    topRightRadius: index === w.swatches.length - 1 ? 7 : 3
                    bottomRightRadius: index === w.swatches.length - 1 ? 7 : 3
                    color: modelData
                }

            }

        }

    }

    // terminal: a prompt and the fetch printed under it in mono
    Item {
        visible: w.variant === "terminal"
        anchors.fill: parent
        anchors.margins: 16

        Column {
            width: parent.width
            spacing: 2

            Text {
                font.family: "monospace"
                font.pixelSize: 13
                color: w.inkDim
                textFormat: Text.StyledText
                text: "<font color='" + Theme.toHex(w.inkAccent) + "'>❯</font> lucidfetch"
            }

            Item {
                width: 1
                height: 6
            }

            Text {
                font.family: "monospace"
                font.pixelSize: 13
                font.bold: true
                color: w.inkAccent
                text: (w.info.user || "") + "@" + (w.info.host || "")
            }

            Text {
                font.family: "monospace"
                font.pixelSize: 13
                color: w.inkFaint
                text: "─".repeat(Math.max(4, ((w.info.user || "") + "@" + (w.info.host || "")).length))
            }

            Repeater {
                model: w.rows

                Text {
                    required property var modelData

                    width: parent.width
                    font.family: "monospace"
                    font.pixelSize: 13
                    color: w.ink
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    text: "<font color='" + Theme.toHex(w.inkAccent) + "'><b>" + modelData.key + "</b></font>: " + String(modelData.value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                }

            }

        }

        Row {
            anchors.bottom: parent.bottom
            spacing: 0

            Repeater {
                model: w.swatches

                Rectangle {
                    required property color modelData

                    width: 20
                    height: 12
                    color: modelData
                }

            }

        }

    }

}
