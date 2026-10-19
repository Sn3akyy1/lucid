import QtQuick
import qs
import qs.lucidui

// a ring gauge with its reading in the middle
Item {
    id: g

    property real value: 0
    property string center: ""
    property string centerIcon: ""
    property string label: ""
    property string detail: ""
    property color tone: Theme.accent
    property bool clickable: false

    signal clicked()

    // as big as its share of the card allows, from the old 54 up to 84
    readonly property real ring: Math.round(Math.max(Theme.dp(54), Math.min(Theme.dp(84), g.width - Theme.dp(20))))

    implicitHeight: gcol.implicitHeight

    Column {
        id: gcol

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.dp(6)

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: g.ring
            height: g.ring

            CircularProgress {
                anchors.fill: parent
                value: g.value
                thickness: Math.round(g.ring * 0.1)
                // past 72 the ring would turn wavy on its own; a gauge reads better plain
                wavy: false
                color: g.tone
                trackColor: Theme.withBlur(Theme.surfaceHighest)
            }

            Row {
                anchors.centerIn: parent
                spacing: 0

                Icon {
                    visible: g.centerIcon !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    name: g.centerIcon
                    size: Math.round(g.ring * 0.24)
                    fill: 1
                    color: g.tone
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    size: Math.round(g.ring * 0.27)
                    weight: 680
                    rounded: 100
                    text: g.center
                }

            }

            StateLayer {
                visible: g.clickable
                radius: g.ring / 2
                onClicked: g.clicked()
            }

        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "labelMedium"
                text: g.label
                width: Math.min(implicitWidth, g.width - Theme.dp(4))
                elide: Text.ElideRight
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                role: "bodySmall"
                size: Theme.fs(11)
                color: Theme.subtext
                text: g.detail
                width: Math.min(implicitWidth, g.width - Theme.dp(4))
                elide: Text.ElideRight
            }

        }

    }

}
