import QtQuick
import Quickshell
import qs
import "../lucidnotif"

// the same groups the notification centre draws, read through the one server
// the shell already owns
Rectangle {
    id: panel

    // whatever vertical room the column above it did not want
    property real maxHeight: 340
    readonly property bool empty: Notifs.count === 0

    radius: Theme.shapeXl
    color: Lockscreen.card
    implicitHeight: Math.min(panel.maxHeight, head.height + (panel.empty ? 96 : list.contentHeight + 24))

    ScriptModel {
        id: rowModel

        values: Notifs.rows
    }

    Item {
        id: head

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 52

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleSm
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(22, countText.implicitWidth + 14)
                height: 22
                radius: 999
                color: Theme.accent
                visible: !panel.empty

                Text {
                    id: countText

                    anchors.centerIn: parent
                    text: Notifs.count
                    color: Theme.fgAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelSm
                    font.weight: Font.Medium
                }

            }

        }

        LockIconButton {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            diameter: 36
            glyphSize: 18
            glyph: "close"
            glyphColor: Theme.subtext
            tooltip: "Clear all"
            visible: !panel.empty
            onClicked: Notifs.clearAll()
        }

    }

    // nothing waiting is worth saying plainly, not leaving a blank card
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 14
        spacing: 10
        visible: panel.empty

        LockGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "bell"
            size: 26
            color: Theme.alpha(Theme.subtextDim, 0.7)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Notifs.dnd ? "Notifications are paused" : "You are all caught up"
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodySm
        }

    }

    Flickable {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        clip: true
        visible: !panel.empty
        interactive: false
        contentHeight: rows.implicitHeight
        contentWidth: width

        Column {
            id: rows

            width: list.width
            spacing: 6

            move: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: Theme.ms(300)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.ms(240)
                    easing.type: Easing.OutCubic
                }

            }

            Repeater {
                model: rowModel

                Item {
                    id: rowItem

                    required property var modelData

                    readonly property bool isHeader: rowItem.modelData && rowItem.modelData.kind === "header"

                    width: rows.width
                    implicitHeight: rowItem.isHeader ? 24 : group.implicitHeight
                    height: rowItem.implicitHeight

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        visible: rowItem.isHeader
                        text: rowItem.isHeader ? rowItem.modelData.label : ""
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.weight: Font.DemiBold
                        font.pixelSize: Theme.fontLabelSm
                        font.letterSpacing: 0.6
                    }

                    NotifGroup {
                        id: group

                        width: parent.width
                        visible: !rowItem.isHeader
                        row: rowItem.isHeader ? null : rowItem.modelData
                        // no action buttons, no inline reply: nothing here may
                        // reach past the lock
                        interactive: false
                    }

                }

            }

        }

    }

    // a stepped wheel, because a flickable inside a locked surface will not
    // take the wheel on its own
    MouseArea {
        anchors.fill: list
        acceptedButtons: Qt.NoButton
        visible: !panel.empty
        onWheel: (wheel) => {
            var max = Math.max(0, list.contentHeight - list.height);
            list.contentY = Math.max(0, Math.min(max, list.contentY - (wheel.angleDelta.y / 120) * 70));
            wheel.accepted = true;
        }
    }

}
