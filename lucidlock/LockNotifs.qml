import QtQuick
import Quickshell
import qs
import "../lucidnotif"

// the same groups the notification centre draws, read through the one server
// the shell already owns
Rectangle {
    id: panel

    // whatever vertical room the column above it did not want
    property real maxHeight: Theme.dp(340)
    readonly property bool empty: Notifs.count === 0

    radius: Theme.shapeXl
    color: Lockscreen.card
    implicitHeight: Math.min(panel.maxHeight, head.height + (panel.empty ? Theme.dp(96) : list.contentHeight + Theme.dp(24)))

    ScriptModel {
        id: rowModel

        values: Notifs.rows
    }

    Item {
        id: head

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.dp(52)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(22)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(10)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleSm
                font.variableAxes: Theme.axes(Theme.fontTitleSm, 520, 0)
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(Theme.dp(22), countText.implicitWidth + Theme.dp(14))
                height: Theme.dp(22)
                radius: Theme.dp(999)
                color: Theme.accent
                visible: !panel.empty

                Text {
                    id: countText

                    anchors.centerIn: parent
                    text: Notifs.count
                    color: Theme.fgAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelSm
                    font.variableAxes: Theme.axes(Theme.fontLabelSm, 520, 0)
                    font.weight: Font.Medium
                }

            }

        }

        LockIconButton {
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            diameter: Theme.dp(36)
            glyphSize: Theme.dp(18)
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
        anchors.verticalCenterOffset: Theme.dp(14)
        spacing: Theme.dp(10)
        visible: panel.empty

        LockGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "bell"
            size: Theme.dp(26)
            color: Theme.alpha(Theme.subtextDim, 0.7)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Notifs.dnd ? "Notifications are paused" : "You are all caught up"
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodySm
            font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
        }

    }

    Flickable {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.dp(14)
        anchors.rightMargin: Theme.dp(14)
        anchors.bottomMargin: Theme.dp(14)
        clip: true
        visible: !panel.empty
        interactive: false
        contentHeight: rows.implicitHeight
        contentWidth: width

        Column {
            id: rows

            width: list.width
            spacing: Theme.dp(6)

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
                    implicitHeight: rowItem.isHeader ? Theme.dp(24) : group.implicitHeight
                    height: rowItem.implicitHeight

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.dp(6)
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.dp(4)
                        visible: rowItem.isHeader
                        text: rowItem.isHeader ? rowItem.modelData.label : ""
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.weight: Font.DemiBold
                        font.pixelSize: Theme.fontLabelSm
                        font.variableAxes: Theme.axes(Theme.fontLabelSm, 600, 0)
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
