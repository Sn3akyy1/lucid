import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.lucidlock

// the lock screen, live and scaled down to a card: the real LockSurface in
// preview mode, so what is shown is what locking would show
Item {
    id: lp

    property bool greeterLook: false
    property bool previewFocus: false
    // a layout to show instead of the applied one: the style editor's draft
    property var layout: null
    property bool editing: false
    property string selected: ""
    // the main screen's size, which every layout is drawn for
    readonly property var screen: Monitors.mainScreen || Quickshell.screens[0] || null
    readonly property real screenW: lp.screen ? lp.screen.width : 1920
    readonly property real screenH: lp.screen ? lp.screen.height : 1080
    readonly property real aspect: lp.screenW / Math.max(1, lp.screenH)
    readonly property alias surface: surface
    property int radius: Theme.shapeXl

    signal opened()
    signal picked(string type)
    signal slotPicked(string slot)
    signal dropped(string type, string slot, int index)
    signal dragMoved(string type, point at)

    // play the lock's own arrival again, as the page comes on screen
    function replay() {
        surface.replay();
    }

    implicitHeight: Math.round(lp.width / lp.aspect)
    Component.onCompleted: Lockscreen.holdPreview()
    Component.onDestruction: Lockscreen.releasePreview()

    ClippingRectangle {
        id: box

        width: lp.width
        height: lp.height
        radius: lp.radius
        color: "black"

        // drawn at the screen's own size and scaled, so every layout lands
        // where it would on the screen itself
        Item {
            width: lp.screenW
            height: lp.screenH
            transformOrigin: Item.TopLeft
            scale: box.width / lp.screenW

            LockSurface {
                id: surface

                anchors.fill: parent
                preview: true
                layoutOverride: lp.layout
                previewFocus: lp.previewFocus
                greeterLook: lp.greeterLook
                editing: lp.editing
                selected: lp.selected
                chromeScale: box.width / lp.screenW
                onPicked: (type) => {
                    return lp.picked(type);
                }
                onSlotPicked: (slot) => {
                    return lp.slotPicked(slot);
                }
                onDropped: (type, slot, index) => {
                    return lp.dropped(type, slot, index);
                }
                onDragMoved: (type, at) => {
                    return lp.dragMoved(type, at);
                }
            }

        }

        // on the page, the whole card is the way into the editor
        MouseArea {
            anchors.fill: parent
            visible: !lp.editing
            cursorShape: Qt.PointingHandCursor
            onClicked: lp.opened()
        }

    }

}
