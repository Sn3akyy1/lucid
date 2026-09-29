import QtQuick
import qs
import qs.lucidui

// one module in the layout editor. the root is the slot the card's column lays
// out and leaves behind as a gap; the surface inside it is what lifts and
// follows the pointer, so the list never reflows mid-drag
Item {
    id: row

    property var host: null
    property string moduleKey: ""
    // the zone this row belongs to, or "spare" for the list of modules that
    // are not in the bar
    property string zone: ""
    property int slot: 0
    property bool placed: true
    property bool first: true
    property bool last: true

    readonly property var spec: Prefs.barModuleAt(row.moduleKey)
    readonly property bool dragging: row.host !== null && row.host.dragKey === row.moduleKey
    readonly property bool aiming: row.host !== null && row.host.dragKey !== "" && row.host.dropZone === row.zone
    readonly property bool markBefore: row.aiming && row.host.dropIndex === row.slot
    readonly property bool markAfter: row.aiming && row.last && row.host.dropIndex === row.slot + 1

    readonly property int outerRadius: 22
    readonly property int innerRadius: 6

    width: parent ? parent.width : 0
    height: 58
    z: row.dragging ? 20 : 0

    component Marker: Rectangle {
        width: row.width - 12
        height: 3
        radius: 1.5
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.accent
        z: 10
    }

    Marker {
        visible: row.markBefore
        anchors.verticalCenter: parent.top
    }

    Marker {
        visible: row.markAfter
        anchors.verticalCenter: parent.bottom
    }

    Rectangle {
        id: surface

        width: row.width
        height: row.height
        color: row.dragging ? Theme.bgHover : Theme.bgTile
        scale: row.dragging ? 1.015 : 1
        topLeftRadius: row.first ? row.outerRadius : row.innerRadius
        topRightRadius: row.first ? row.outerRadius : row.innerRadius
        bottomLeftRadius: row.last ? row.outerRadius : row.innerRadius
        bottomRightRadius: row.last ? row.outerRadius : row.innerRadius

        Drag.active: grip.drag.active
        Drag.source: row
        Drag.keys: ["lucid-bar-module"]
        Drag.hotSpot.x: surface.width / 2
        Drag.hotSpot.y: surface.height / 2

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFastEffects
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastEffects
                easing.type: Easing.OutCubic
            }

        }

        // the drag writes y directly, so the snap back has to be written too
        Behavior on y {
            enabled: !grip.drag.active

            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveStandard
            }

        }

        // declared first so the buttons above it keep their own presses, and
        // preventStealing so the settings page does not flick instead
        MouseArea {
            id: grip

            anchors.fill: parent
            preventStealing: true
            cursorShape: row.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: surface
            drag.axis: Drag.YAxis
            drag.smoothed: false
            onReleased: {
                surface.y = 0;
                if (row.host)
                    row.host.endDrag();

            }
            onCanceled: {
                surface.y = 0;
                if (row.host)
                    row.host.endDrag();

            }

            drag.onActiveChanged: {
                if (grip.drag.active && row.host)
                    row.host.beginDrag(row.moduleKey, row.zone);

            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: controls.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "drag_indicator"
                size: 18
                color: row.dragging ? Theme.accent : Theme.subtextDim
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 26
                radius: 9
                color: row.placed ? Theme.alpha(Theme.accent, 0.16) : Theme.alpha(Theme.text, 0.07)

                Icon {
                    anchors.centerIn: parent
                    name: row.spec ? row.spec.icon : ""
                    size: 17
                    color: row.placed ? Theme.accent : Theme.subtextDim
                }

            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 76
                spacing: 1

                LText {
                    width: parent.width
                    elide: Text.ElideRight
                    role: "titleSmall"
                    weight: 620
                    color: row.placed ? Theme.text : Theme.subtext
                    text: row.spec ? row.spec.name : row.moduleKey
                }

                LText {
                    width: parent.width
                    elide: Text.ElideRight
                    role: "bodySmall"
                    color: Theme.subtextDim
                    text: row.spec ? row.spec.desc : ""
                }

            }

        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            M3IconButton {
                visible: row.placed
                anchors.verticalCenter: parent.verticalCenter
                size: 34
                iconSize: 18
                iconPath: "arrow_upward"
                enabled: Prefs.barCanStep(row.moduleKey, -1)
                onClicked: Prefs.barStep(row.moduleKey, -1)
            }

            M3IconButton {
                visible: row.placed
                anchors.verticalCenter: parent.verticalCenter
                size: 34
                iconSize: 18
                iconPath: "arrow_downward"
                enabled: Prefs.barCanStep(row.moduleKey, 1)
                onClicked: Prefs.barStep(row.moduleKey, 1)
            }

            M3IconButton {
                visible: row.placed
                anchors.verticalCenter: parent.verticalCenter
                size: 34
                iconSize: 17
                iconPath: "close"
                destructive: true
                onClicked: Prefs.barRemove(row.moduleKey)
            }

            M3IconButton {
                visible: !row.placed
                anchors.verticalCenter: parent.verticalCenter
                size: 34
                iconSize: 19
                variant: "tonal"
                iconPath: "add"
                onClicked: Prefs.barMove(row.moduleKey, "right", -1)
            }

        }

    }

    // the spare list has no order of its own, so only placed rows are aimed at
    DropArea {
        anchors.fill: parent
        keys: ["lucid-bar-module"]
        enabled: row.placed && !row.dragging

        onPositionChanged: (drop) => {
            if (row.host)
                row.host.aimDrop(row.zone, drop.y < row.height / 2 ? row.slot : row.slot + 1);

        }
        onEntered: (drop) => {
            if (row.host)
                row.host.aimDrop(row.zone, drop.y < row.height / 2 ? row.slot : row.slot + 1);

        }
    }

}
