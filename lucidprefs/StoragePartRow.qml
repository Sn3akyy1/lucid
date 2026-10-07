import QtQuick
import qs
import qs.lucidui

// one partition of a drive: what is on it, where it is mounted, how full it is
Item {
    id: row

    property var part: ({})
    readonly property var mounts: (row.part.mounts || []).filter((m) => {
        return m.indexOf("/") === 0;
    })
    readonly property bool mounted: row.mounts.length > 0
    readonly property bool swap: (row.part.mounts || []).indexOf("[SWAP]") >= 0 || row.part.fstype === "swap"
    // the system lives here, so it is never offered for unmounting
    readonly property bool system: row.swap || row.mounts.some((m) => {
        return ["/", "/home", "/boot", "/efi", "/boot/efi", "/usr", "/var"].indexOf(m) >= 0;
    })
    readonly property bool mountable: !row.mounted && !row.swap && (row.part.fstype || "") !== "" && ["crypto_LUKS", "LVM2_member", "linux_raid_member", "BitLocker"].indexOf(row.part.fstype) < 0
    readonly property real frac: row.mounted && row.part.fssize > 0 ? row.part.used / Math.max(1, row.part.used + row.part.avail) : 0
    readonly property bool busy: Storage.mounting === row.part.path

    implicitHeight: Theme.dp(54)

    Rectangle {
        anchors.fill: parent
        radius: Theme.rad(12)
        color: Theme.bgSunken
    }

    Icon {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        name: row.swap ? "swap_horiz" : (row.mounted ? "folder" : "hard_drive")
        size: Theme.dp(18)
        color: row.mounted ? Theme.accent : Theme.subtext
    }

    Column {
        anchors.left: mark.right
        anchors.leftMargin: Theme.dp(10)
        anchors.right: usage.left
        anchors.rightMargin: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(1)

        Text {
            width: parent.width
            text: row.part.label || row.part.partlabel || row.part.name || ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: [row.part.fstype || "no filesystem", row.swap ? "swap" : (row.mounted ? row.mounts.join(", ") : "not mounted"), Storage.size(row.part.size)].join("  ·  ")
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelMd
            elide: Text.ElideMiddle
        }

    }

    Column {
        id: usage

        anchors.right: btns.left
        anchors.rightMargin: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        width: row.mounted && row.part.fssize > 0 ? Theme.dp(120) : 0
        visible: width > 0
        spacing: Theme.dp(5)

        Text {
            anchors.right: parent.right
            text: Storage.size(row.part.avail) + " free"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelMd
        }

        Rectangle {
            width: parent.width
            height: Theme.dp(6)
            radius: height / 2
            color: Theme.bgHigh

            Rectangle {
                width: parent.width * row.frac
                height: parent.height
                radius: height / 2
                color: row.frac * 100 > 100 - Prefs.storageLowPercent ? Theme.error : Theme.accent
            }

        }

    }

    Row {
        id: btns

        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(4)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(2)

        LoadingIndicator {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(32)
            height: Theme.dp(32)
            visible: row.busy
            running: row.busy
        }

        M3Button {
            anchors.verticalCenter: parent.verticalCenter
            variant: "text"
            text: row.mounted ? "Unmount" : "Mount"
            visible: !row.busy && (row.mountable || (row.mounted && !row.system))
            enabled: Storage.mounting === ""
            onClicked: Storage.udisks(row.mounted ? "unmount" : "mount", row.part.path)
        }

        M3IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(36)
            iconPath: "folder_open"
            visible: row.mounted
            onClicked: Storage.open(row.mounts[0])
        }

    }

}
