import QtQuick
import Quickshell
import qs
import "../lucidnotif"
import "parts"

// what came in while away: the same groups the notification centre draws,
// as a list, as a shelf of app icons, or as a single count
WidgetBase {
    id: panel

    readonly property string style: panel.opts.style || "list"
    readonly property bool empty: Notifs.count === 0
    readonly property bool ownCard: !panel.carded
    readonly property real boxW: panel.carded ? panel.avail : Math.min(panel.avail, Theme.dp(440))
    // groups only, newest first, for the shelf
    readonly property var groups: (Notifs.rows || []).filter((r) => {
        return r && r.kind === "group";
    })
    readonly property int shelfMax: 6

    hasContent: panel.style === "list" || !panel.empty || panel.editing
    implicitWidth: panel.style === "list" ? panel.boxW : (panel.style === "icons" ? shelf.width : countPill.width)
    implicitHeight: panel.style === "list" ? list.height : (panel.style === "icons" ? shelf.height : countPill.height)

    // ── list ────────────────────────────────────────────────────────────────
    Rectangle {
        id: list

        readonly property real maxH: Math.max(Theme.dp(140), Math.min(panel.availH, Theme.dp(440)))

        x: panel.xFor(width, panel.width)
        visible: panel.style === "list"
        width: panel.boxW
        height: Math.min(list.maxH, head.height + (panel.empty ? Theme.dp(96) : flick.contentHeight + Theme.dp(panel.ownCard ? 24 : 4)))
        radius: Theme.shapeXl
        color: panel.ownCard ? (panel.onCard ? Lockscreen.cardHigh : Lockscreen.card) : "transparent"

        ScriptModel {
            id: rowModel

            values: panel.style === "list" ? Notifs.rows : []
        }

        Item {
            id: head

            width: parent.width
            height: Theme.dp(panel.ownCard ? 52 : 36)

            Row {
                x: panel.ownCard ? Theme.dp(22) : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(10)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Notifications")
                    color: panel.tonal ? Theme.fgAccentContainer : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleSm
                    font.variableAxes: Theme.axes(Theme.fontTitleSm, 520, 0)
                    font.weight: Font.Medium
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(Theme.dp(22), countText.implicitWidth + Theme.dp(14))
                    height: Theme.dp(22)
                    radius: height / 2
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
                anchors.rightMargin: panel.ownCard ? Theme.dp(12) : 0
                anchors.verticalCenter: parent.verticalCenter
                diameter: Theme.dp(36)
                glyphSize: Theme.dp(18)
                glyph: "close"
                glyphColor: Theme.subtext
                tooltip: I18n.tr("Clear all")
                visible: !panel.empty && !panel.preview
                onClicked: Notifs.clearAll()
            }

        }

        // nothing waiting is worth saying plainly, not leaving a blank card
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: head.height + Theme.dp(14)
            spacing: Theme.dp(10)
            visible: panel.empty

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "notifications"
                size: Theme.dp(26)
                color: Theme.alpha(Theme.subtextDim, 0.7)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Notifs.dnd ? I18n.tr("Notifications are paused") : I18n.tr("You are all caught up")
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
            }

        }

        Flickable {
            id: flick

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: head.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: panel.ownCard ? Theme.dp(14) : 0
            anchors.rightMargin: panel.ownCard ? Theme.dp(14) : 0
            anchors.bottomMargin: panel.ownCard ? Theme.dp(14) : 0
            clip: true
            visible: !panel.empty
            interactive: false
            contentHeight: rows.implicitHeight
            contentWidth: width

            Column {
                id: rows

                width: flick.width
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
                            redacted: panel.opts.private === true
                        }

                    }

                }

            }

        }

        // a stepped wheel, because a flickable inside a locked surface will not
        // take the wheel on its own
        MouseArea {
            anchors.fill: flick
            acceptedButtons: Qt.NoButton
            visible: !panel.empty
            onWheel: (wheel) => {
                var max = Math.max(0, flick.contentHeight - flick.height);
                flick.contentY = Math.max(0, Math.min(max, flick.contentY - (wheel.angleDelta.y / 120) * 70));
                wheel.accepted = true;
            }
        }

    }

    // ── icons: a shelf of who wrote, the way a phone's lock screen shows it ──
    Rectangle {
        id: shelf

        readonly property int extra: Math.max(0, panel.groups.length - panel.shelfMax)

        x: panel.xFor(width, panel.width)
        visible: panel.style === "icons"
        width: shelfRow.implicitWidth + Theme.dp(28)
        height: Theme.dp(52)
        radius: height / 2
        color: panel.ownCard ? (panel.onCard ? Lockscreen.cardHigh : Lockscreen.card) : "transparent"

        Row {
            id: shelfRow

            anchors.centerIn: parent
            spacing: Theme.dp(8)

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: Notifs.dnd ? "notifications_off" : "notifications"
                size: Theme.dp(18)
                color: Theme.accent
            }

            Repeater {
                model: panel.style === "icons" ? panel.groups.slice(0, panel.shelfMax) : []

                Item {
                    id: face

                    required property var modelData

                    width: Theme.dp(30)
                    height: Theme.dp(30)
                    anchors.verticalCenter: parent.verticalCenter

                    NotifAvatar {
                        anchors.fill: parent
                        size: Theme.dp(30)
                        notification: face.modelData.items && face.modelData.items.length > 0 ? face.modelData.items[0] : null
                        iconOnly: true
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: -Theme.dp(4)
                        anchors.bottomMargin: -Theme.dp(3)
                        width: Math.max(Theme.dp(16), badge.implicitWidth + Theme.dp(8))
                        height: Theme.dp(16)
                        radius: height / 2
                        color: Theme.accent
                        visible: face.modelData.count > 1

                        Text {
                            id: badge

                            anchors.centerIn: parent
                            text: face.modelData.count
                            color: Theme.fgAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(9)
                            font.variableAxes: Theme.axes(Theme.fs(9), 600, 0)
                            font.weight: Font.DemiBold
                        }

                    }

                }

            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: panel.empty
                text: I18n.tr("No notifications")
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                font.weight: Font.Medium
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: shelf.extra > 0
                text: "+" + shelf.extra
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 560, 0)
                font.weight: Font.Medium
            }

        }

    }

    // ── count ───────────────────────────────────────────────────────────────
    Rectangle {
        id: countPill

        x: panel.xFor(width, panel.width)
        visible: panel.style === "count"
        width: countRow.implicitWidth + Theme.dp(36)
        height: Theme.dp(44)
        radius: height / 2
        color: panel.ownCard ? (panel.onCard ? Lockscreen.cardHigh : Lockscreen.card) : "transparent"

        Row {
            id: countRow

            anchors.centerIn: parent
            spacing: Theme.dp(10)

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "notifications"
                size: Theme.dp(18)
                color: Theme.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.count === 0 ? I18n.tr("No new notifications") : I18n.trn("%1 new notification", "%1 new notifications", Notifs.count)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                font.weight: Font.Medium
            }

        }

    }

}
