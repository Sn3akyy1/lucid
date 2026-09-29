import QtQuick
import qs

// a key combination as a row of keycaps: "SUPER + SHIFT + left" -> [Super][Shift][←]
Row {
    id: combo

    property string keys: ""
    property int capHeight: 26
    property int fontSize: Theme.fontLabelLg
    property color capColor: Theme.bgHigh
    property color textColor: Theme.text
    property bool dim: false

    spacing: 4
    opacity: combo.dim ? 0.45 : 1

    Repeater {
        model: Keybinds.tokens(combo.keys)

        Rectangle {
            required property string modelData
            // arrows sit tiny in most ui fonts, so they get a size up
            readonly property bool arrow: /^[←→↑↓]$/.test(modelData)

            anchors.verticalCenter: parent.verticalCenter
            height: combo.capHeight
            width: Math.max(combo.capHeight, cap.implicitWidth + 16)
            radius: 7
            color: combo.capColor
            border.width: 1
            border.color: Theme.alpha(Theme.outline, 0.6)

            // the keycap's lip, so it reads as a key and not a tag
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 3
                anchors.rightMargin: 3
                anchors.bottomMargin: 2
                height: 1
                color: Theme.alpha(Theme.shadow, 0.35)
            }

            Text {
                id: cap

                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: parent.modelData
                color: combo.textColor
                font.family: Theme.fontFamily
                font.pixelSize: parent.arrow ? Math.round(combo.fontSize * 1.45) : combo.fontSize
                font.weight: parent.arrow ? Font.Bold : Font.DemiBold
            }

        }

    }

}
