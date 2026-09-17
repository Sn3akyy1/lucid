import QtQuick
import qs

// the glanceable half of a status bar, for a screen that has no bar
Row {
    id: chips

    spacing: 10

    component Chip: Rectangle {
        id: chip

        property string glyph: ""
        property string label: ""
        property color tone: Theme.subtext
        default property alias extra: slot.data

        height: 36
        radius: Theme.radiusPill
        color: Lockscreen.card
        width: content.implicitWidth + 30

        Row {
            id: content

            anchors.centerIn: parent
            spacing: 9

            Item {
                id: slot

                anchors.verticalCenter: parent.verticalCenter
                width: childrenRect.width
                height: 18
                visible: chip.glyph === ""
            }

            LockGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.glyph
                size: 17
                color: chip.tone
                visible: chip.glyph !== ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.Medium
            }

        }

    }

    Chip {
        visible: Lockscreen.hasBattery
        label: Lockscreen.batteryPercent + "%"
        tone: Lockscreen.batteryLow ? Theme.error : Theme.subtext

        // a real gauge reads faster than a glyph that never changes
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 14

            Rectangle {
                id: shell

                width: 22
                height: 13
                radius: 4
                color: "transparent"
                border.width: 1.5
                border.color: Lockscreen.batteryLow ? Theme.error : Theme.subtext

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 2.5
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(2, (parent.width - 5) * Lockscreen.batteryPercent / 100)
                    height: parent.height - 5
                    radius: 2
                    color: Lockscreen.batteryLow ? Theme.error : (Lockscreen.charging ? Theme.success : Theme.text)

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.ms(400)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            Rectangle {
                anchors.left: shell.right
                anchors.verticalCenter: shell.verticalCenter
                width: 2
                height: 5
                radius: 1
                color: Lockscreen.batteryLow ? Theme.error : Theme.subtext
            }

            LockGlyph {
                anchors.centerIn: shell
                name: "batteryCharge"
                size: 13
                color: Theme.fgSuccess
                visible: Lockscreen.charging
            }

        }

    }

    Chip {
        glyph: Lockscreen.netGlyph
        label: Lockscreen.netLabel
        tone: (Lockscreen.ethernet || Lockscreen.wifiUp) ? Theme.accent : Theme.subtextDim
    }

    Chip {
        glyph: Lockscreen.btOn ? "bluetooth" : "bluetoothOff"
        label: Lockscreen.btLabel
        tone: Lockscreen.btDevices.length > 0 ? Theme.accent : Theme.subtextDim
        visible: !!Lockscreen.btAdapter
    }

    Chip {
        glyph: "bellOff"
        label: "Do not disturb"
        tone: Theme.warning
        visible: Notifs.dnd
    }

}
