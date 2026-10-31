import QtQuick
import qs
import qs.lucidui

// a small label on the frame: a size, a window's name, what a click will do
Rectangle {
    id: chip

    property string text: ""
    property string icon: ""
    // primary container for the one that matters; the rest sit on the shell's
    // own surface, so they are dark in dark mode
    property bool strong: false
    property bool tabular: true

    width: row.implicitWidth + Theme.dp(chip.icon !== "" ? 22 : 24)
    height: Theme.dp(28)
    radius: height / 2
    color: chip.strong ? Theme.primaryContainer : Theme.surfaceContainer
    border.width: chip.strong ? 0 : 1
    border.color: Theme.alpha(Theme.text, 0.1)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.dp(6)

        Icon {
            visible: chip.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: chip.icon
            size: Theme.dp(16)
            fill: 1
            color: chip.strong ? Theme.fgPrimaryContainer : Theme.primary
        }

        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: "labelMedium"
            tabular: chip.tabular
            color: chip.strong ? Theme.fgPrimaryContainer : Theme.text
            text: chip.text
            elide: Text.ElideRight
            width: Math.min(implicitWidth, Theme.dp(360))
        }

    }

}
