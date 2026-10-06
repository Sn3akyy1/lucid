import QtQuick
import qs

// m3 primary tabs. the indicator is as wide as the label and slides between them
Item {
    id: tabs

    // [{ key, label, icon }]
    property var options: []
    property var current: ""
    property bool secondary: false
    // icon beside the label rather than above it
    property bool inline: false

    signal picked(var key)

    readonly property int currentIndex: {
        for (var i = 0; i < tabs.options.length; i++) {
            if (tabs.options[i].key === tabs.current)
                return i;

        }
        return -1;
    }
    readonly property Item currentItem: tabs.currentIndex >= 0 && rep.count > tabs.currentIndex ? rep.itemAt(tabs.currentIndex) : null

    implicitHeight: tabs.options.length && tabs.options[0].icon && !tabs.secondary && !tabs.inline ? Theme.dp(56) : Theme.dp(46)

    Row {
        id: row

        anchors.fill: parent

        Repeater {
            id: rep

            model: tabs.options

            Item {
                id: tab

                required property var modelData
                required property int index
                readonly property bool on: tab.index === tabs.currentIndex
                readonly property real contentW: col.implicitWidth

                width: row.width / Math.max(1, rep.count)
                height: row.height

                StateLayer {
                    tint: tab.on ? Theme.primary : Theme.text
                    onClicked: tabs.picked(tab.modelData.key)
                }

                Grid {
                    id: col

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    columns: tabs.inline ? 2 : 1
                    spacing: tabs.inline ? Theme.dp(8) : Theme.dp(2)
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter

                    Icon {
                        visible: !!tab.modelData.icon && !tabs.secondary
                        name: tab.modelData.icon || ""
                        size: Theme.dp(22)
                        fill: tab.on ? 1 : 0
                        color: tab.on ? Theme.primary : Theme.subtext
                    }

                    LText {
                        text: tab.modelData.label || ""
                        role: "titleSmall"
                        color: tab.on ? (tabs.secondary ? Theme.text : Theme.primary) : Theme.subtext
                    }

                }

            }

        }

    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.divider
    }

    Rectangle {
        id: indicator

        readonly property real w: tabs.secondary ? (tabs.currentItem ? tabs.currentItem.width : 0) : (tabs.currentItem ? Math.max(24, tabs.currentItem.contentW) : 0)

        visible: tabs.currentItem !== null
        anchors.bottom: parent.bottom
        height: tabs.secondary ? Theme.dp(2) : Theme.dp(3)
        width: indicator.w
        x: tabs.currentItem ? tabs.currentItem.x + (tabs.currentItem.width - indicator.w) / 2 : 0
        topLeftRadius: tabs.secondary ? 0 : Theme.dp(3)
        topRightRadius: tabs.secondary ? 0 : Theme.dp(3)
        color: Theme.primary

        Behavior on x {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

}
