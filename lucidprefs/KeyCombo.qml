import QtQuick
import qs
import qs.lucidui

// a key combination as a row of keycaps: "SUPER + SHIFT + left" -> [Super][Shift][←]
Row {
    id: combo

    property string keys: ""
    property int capHeight: Theme.dp(26)
    property int fontSize: Theme.fontLabelLg
    property color capColor: Theme.bgHigh
    property color textColor: Theme.text
    property bool dim: false

    spacing: Theme.dp(4)
    opacity: combo.dim ? 0.45 : 1

    Repeater {
        model: Keybinds.tokens(combo.keys)

        Rectangle {
            required property string modelData
            // an arrow key draws as its symbol; the hidden text still sizes the cap
            readonly property bool arrow: /^[←→↑↓]$/.test(modelData)

            anchors.verticalCenter: parent.verticalCenter
            height: combo.capHeight
            width: Math.max(combo.capHeight, cap.implicitWidth + Theme.dp(16))
            radius: Theme.dp(7)
            color: combo.capColor
            border.width: 1
            border.color: Theme.alpha(Theme.outline, 0.6)

            // the keycap's lip, so it reads as a key and not a tag
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.dp(3)
                anchors.rightMargin: Theme.dp(3)
                anchors.bottomMargin: Theme.dp(2)
                height: 1
                color: Theme.alpha(Theme.shadow, 0.35)
            }

            Text {
                id: cap

                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                visible: !parent.arrow
                text: parent.modelData
                color: combo.textColor
                font.family: Theme.fontFamily
                font.pixelSize: parent.arrow ? Math.round(combo.fontSize * 1.45) : combo.fontSize
                font.weight: parent.arrow ? Font.Bold : Font.DemiBold
            }

            Icon {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                visible: parent.arrow
                name: ({
                    "←": "arrow_back",
                    "→": "arrow_forward",
                    "↑": "arrow_upward",
                    "↓": "arrow_downward"
                })[parent.modelData] || ""
                size: Math.round(combo.fontSize * 1.3)
                color: combo.textColor
            }

        }

    }

}
