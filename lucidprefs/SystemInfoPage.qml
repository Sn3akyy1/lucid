import QtQuick
import Quickshell
import qs
import qs.lucidui

Column {
    id: page

    property bool pageShown: false
    readonly property var info: Sys.info || ({})
    readonly property string fallback: page.info.ready ? I18n.tr("Not reported") : I18n.tr("Reading…")
    readonly property string hardwareModel: [page.info.vendor || "", page.info.model || ""].filter((v) => {
        return v !== "";
    }).join(" · ")
    readonly property string machineName: page.info.model || page.info.host || I18n.tr("This computer")
    readonly property string machineDetail: [page.info.vendor || "", page.info.os || ""].filter((v) => {
        return v !== "";
    }).join(" · ")
    readonly property var deviceRows: [{
        "title": I18n.tr("Device name"),
        "value": page.info.host || ""
    }, {
        "title": I18n.tr("Hardware model"),
        "value": page.hardwareModel
    }, {
        "title": I18n.tr("Uptime"),
        "value": Number(page.info.uptimeSeconds) >= 0 ? Sys.duration(Number(page.info.uptimeSeconds)) : ""
    }]
    readonly property var hardwareRows: [{
        "title": I18n.tr("Processor"),
        "value": [page.info.cpuModel || "", page.info.cores ? I18n.trn("%1 logical processor", "%1 logical processors", Number(page.info.cores)) : ""].filter((v) => {
            return v !== "";
        }).join(" · ")
    }, {
        "title": I18n.tr("Graphics"),
        "value": String(page.info.gpuModels || page.info.gpuModel || "").split("|").filter((v) => {
            return v !== "";
        }).join(" · ")
    }, {
        "title": I18n.tr("Memory"),
        "value": page.sizeOf(page.info.memoryBytes)
    }, {
        "title": I18n.tr("Storage"),
        "value": Number(page.info.storageBytes) > 0 ? I18n.tr("%1 total · %2 free", page.sizeOf(page.info.storageBytes), page.sizeOf(page.info.storageFreeBytes)) : ""
    }]
    readonly property var softwareRows: [{
        "title": I18n.tr("Operating system"),
        "value": page.info.os || ""
    }, {
        "title": I18n.tr("Kernel"),
        "value": page.info.kernel || ""
    }, {
        "title": I18n.tr("Architecture"),
        "value": page.info.architecture || ""
    }, {
        "title": I18n.tr("Desktop environment"),
        "value": page.info.desktop || ""
    }, {
        "title": I18n.tr("Session type"),
        "value": page.info.sessionType || ""
    }, {
        "title": I18n.tr("Compositor"),
        "value": [page.info.desktop || "", page.info.compositor || ""].filter((v) => {
            return v !== "";
        }).join(" ")
    }, {
        "title": I18n.tr("Quickshell"),
        "value": page.info.quickshell || ""
    }, {
        "title": I18n.tr("Shell"),
        "value": page.info.shell || ""
    }, {
        "title": I18n.tr("Packages"),
        "value": page.info.packages || ""
    }]

    function sizeOf(bytes) {
        const n = Number(bytes);
        return n > 0 ? Storage.size(n) : "";
    }

    function shown(value) {
        return String(value || "").trim() || page.fallback;
    }

    function refresh() {
        Sys.refreshInfo();
    }

    spacing: Theme.dp(26)
    Component.onCompleted: page.refresh()
    onPageShownChanged: {
        if (page.pageShown)
            page.refresh();

    }

    Rectangle {
        width: parent.width
        implicitHeight: Theme.dp(144)
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.bgTile)

        Rectangle {
            id: iconPlate

            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(26)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(82)
            height: width
            radius: Theme.shapeLg
            color: Theme.accentContainer

            Icon {
                anchors.centerIn: parent
                name: "computer"
                size: Theme.dp(42)
                fill: 1
                color: Theme.fgAccentContainer
            }

        }

        Column {
            anchors.left: iconPlate.right
            anchors.leftMargin: Theme.dp(22)
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(26)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(3)

            Text {
                width: parent.width
                text: page.machineName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.variableAxes: Theme.axes(Theme.fontHeadlineSm, 640, 0)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: page.machineDetail || page.fallback
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                font.variableAxes: Theme.axes(Theme.fontBodyLg, 430, 0)
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: [page.info.user || "", page.info.host || ""].filter((v) => {
                    return v !== "";
                }).join("@")
                visible: text !== ""
                color: Theme.subtextDim
                font.family: "monospace"
                font.pixelSize: Theme.fontBodyMd
                elide: Text.ElideRight
            }

        }

    }

    SettingCard {
        title: I18n.tr("This computer")

        Repeater {
            model: page.deviceRows

            SettingRow {
                required property var modelData
                required property int index

                title: modelData.title
                description: page.shown(modelData.value)
                showDivider: index < page.deviceRows.length - 1
            }

        }

    }

    SettingCard {
        title: I18n.tr("Hardware")

        Repeater {
            model: page.hardwareRows

            SettingRow {
                required property var modelData
                required property int index

                title: modelData.title
                description: page.shown(modelData.value)
                showDivider: index < page.hardwareRows.length - 1
            }

        }

    }

    SettingCard {
        title: I18n.tr("Software")

        Repeater {
            model: page.softwareRows

            SettingRow {
                required property var modelData
                required property int index

                title: modelData.title
                description: page.shown(modelData.value)
                showDivider: index < page.softwareRows.length - 1
            }

        }

    }

}
