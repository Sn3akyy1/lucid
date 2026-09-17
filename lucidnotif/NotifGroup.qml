import QtQuick
import qs

// one app's notifications. collapsed it is a stack you can see the depth of,
// expanded it is that app's own little list.
Item {
    id: group

    property var row: null
    property bool interactive: true

    readonly property var items: group.row ? group.row.items : []
    readonly property int count: group.row ? group.row.count : 0
    readonly property string groupKey: group.row ? group.row.key : ""
    readonly property string appName: group.row ? group.row.appName : ""
    readonly property bool expanded: group.row ? group.row.expanded === true : false
    readonly property bool stacked: group.count > 1 && !group.expanded
    readonly property int peekDepth: group.stacked ? (group.count > 2 ? 11 : 6) : 0
    readonly property real headHeight: content.implicitHeight
    readonly property int cardRadius: Theme.shapeLg

    implicitHeight: content.implicitHeight + group.peekDepth

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.ms(300)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    // the plates behind the top card are the whole point of the collapsed state
    Rectangle {
        id: peekBack

        anchors.top: parent.top
        x: 14
        width: Math.max(0, parent.width - 28)
        height: group.headHeight + 11
        radius: group.cardRadius
        color: Theme.shade(Theme.bgHover, 6)
        opacity: group.stacked && group.count > 2 ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(200)
            }

        }

    }

    Rectangle {
        id: peekFront

        anchors.top: parent.top
        x: 7
        width: Math.max(0, parent.width - 14)
        height: group.headHeight + 6
        radius: group.cardRadius
        color: Theme.shade(Theme.bgHover, 3)
        opacity: group.stacked ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(200)
            }

        }

    }

    Column {
        id: content

        width: parent.width
        spacing: 6

        // expanded: the app gets a heading with its own clear
        Item {
            width: parent.width
            height: group.expanded ? 28 : 0
            opacity: group.expanded ? 1 : 0
            visible: opacity > 0.01
            clip: true

            NotifAvatar {
                id: groupAvatar

                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                size: 20
                notification: group.items.length > 0 ? group.items[0] : null
            }

            Text {
                anchors.left: groupAvatar.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: group.appName
                color: Theme.text
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: Theme.fs(11)
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                NotifTextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Clear"
                    onClicked: Notifs.clearGroup(group.groupKey)
                }

                NotifGhostButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconPath: Notifs.icons.expand_less
                    onClicked: Notifs.toggleGroup(group.groupKey)
                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(200)
                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.ms(260)
                    easing.type: Easing.OutCubic
                }

            }

        }

        Repeater {
            id: cardRepeater

            model: group.expanded ? group.items : group.items.slice(0, 1)

            NotifSurface {
                required property var modelData
                required property int index

                width: content.width
                notification: modelData
                radius: group.cardRadius
                // only the collapsed head carries the group's controls
                groupCount: (group.stacked && index === 0) ? group.count : 0
                groupKey: group.groupKey
                inGroup: group.expanded
                interactive: group.interactive
            }

        }

    }

}
