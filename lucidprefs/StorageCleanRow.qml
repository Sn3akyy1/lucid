import QtQuick
import qs
import qs.lucidui

// one thing Storage could clear: what it is, how big, and the button that does it
SettingRow {
    id: cleanRow

    property var pal: null

    required property var modelData
    readonly property var info: cleanRow.pal ? cleanRow.pal.about(cleanRow.modelData) : ({})
    readonly property bool needsRoot: cleanRow.modelData.root === true

    title: cleanRow.info.title || ""
    description: cleanRow.info.body || ""
    enabled: !cleanRow.needsRoot || !!(Storage.cleanup && Storage.cleanup.pkexec)
    disabledReason: "pkexec is not installed, so nothing here can run as root."

    Row {
        spacing: Theme.dp(14)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Storage.size(cleanRow.modelData.size)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyLg
            font.weight: Font.Medium
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(verbBtn.implicitWidth, Theme.dp(40))
            height: Theme.dp(40)

            M3Button {
                id: verbBtn

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: cleanRow.info.show ? "text" : "tonal"
                text: cleanRow.info.verb || ""
                iconPath: cleanRow.info.show ? "open_in_new" : ""
                visible: Storage.cleaning !== cleanRow.modelData.id
                enabled: cleanRow.enabled && (cleanRow.info.show ? cleanRow.pal.scan !== null || Storage.volumes.length > 0 : Storage.cleaning === "")
                onClicked: cleanRow.pal.act(cleanRow.modelData)
            }

            LoadingIndicator {
                anchors.centerIn: parent
                width: Theme.dp(36)
                height: Theme.dp(36)
                visible: Storage.cleaning === cleanRow.modelData.id
                running: visible
            }

        }

    }

}
