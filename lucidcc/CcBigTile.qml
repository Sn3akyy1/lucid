import QtQuick
import qs
import qs.lucidui

// a big tile: the icon side toggles, the label side opens the detail view.
// the pill squares off once the tile is on
Rectangle {
    id: tile

    property string icon: ""
    property string name: ""
    property string sub: ""
    property bool checked: false
    // off for a tile with no page of its own: no chevron, and it all switches
    property bool hasPage: true
    // the pill stays a pill and its icon turns into this shape as it comes on
    property string shape: ""
    // on, and drawn as a filled pill
    readonly property bool filled: tile.checked && tile.shape === ""

    signal toggled()
    signal expandRequested()

    height: Theme.dp(64)
    radius: tile.filled ? Theme.shapeLgInc : height / 2
    color: tile.filled ? Theme.primary : Theme.withBlur(Theme.surfaceHighest)

    Behavior on radius {
        NumberAnimation {
            duration: Theme.durDefaultSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.durDefaultEffects
        }

    }

    StateLayer {
        radius: tile.radius
        tint: tile.filled ? Theme.fgPrimary : Theme.text
        onClicked: tile.expandRequested()
    }

    Rectangle {
        id: bubble

        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.dp(44)
        height: Theme.dp(44)
        radius: Theme.dp(22)
        color: tile.shape !== "" ? "transparent" : (tile.filled ? Theme.alpha(Theme.fgPrimary, 0.14) : Theme.alpha(Theme.text, 0.08))

        MaterialShape {
            visible: tile.shape !== ""
            anchors.fill: parent
            shape: "circle"
            to: tile.shape
            morph: tile.checked ? 1 : 0
            rotation: tile.checked ? 0 : -60
            color: tile.checked ? Theme.primary : Theme.alpha(Theme.text, 0.08)

            Behavior on morph {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveStandard
                }

            }

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.durSlowSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveSlowSpatial
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }

            }

        }

        StateLayer {
            radius: Theme.dp(22)
            tint: tile.checked ? Theme.fgPrimary : Theme.text
            onClicked: tile.toggled()
        }

        Icon {
            anchors.centerIn: parent
            name: tile.icon
            size: Theme.dp(22)
            fill: tile.checked ? 1 : 0
            color: tile.checked ? Theme.fgPrimary : Theme.text
        }

    }

    Column {
        anchors.left: bubble.right
        anchors.leftMargin: Theme.dp(10)
        anchors.right: tile.hasPage ? chevron.left : parent.right
        anchors.rightMargin: tile.hasPage ? Theme.dp(2) : Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        LText {
            width: parent.width
            role: "titleSmall"
            weight: 600
            text: tile.name
            color: tile.filled ? Theme.fgPrimary : Theme.text
            elide: Text.ElideRight
        }

        LText {
            width: parent.width
            visible: text !== ""
            role: "bodySmall"
            text: tile.sub
            color: tile.filled ? Theme.alpha(Theme.fgPrimary, 0.78) : Theme.subtext
            elide: Text.ElideRight
        }

    }

    Icon {
        id: chevron

        visible: tile.hasPage
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron_right"
        size: Theme.dp(20)
        color: tile.filled ? Theme.fgPrimary : Theme.subtext
    }

}
