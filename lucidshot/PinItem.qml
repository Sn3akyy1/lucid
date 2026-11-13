import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs
import qs.lucidui

// a capture pinned over everything: drag it about, scroll to size it, ctrl
// and scroll to see through it, double-click (or the cross) to let it go
Item {
    id: pin

    required property int index
    required property int pid
    required property string file
    required property string screen
    required property real px
    required property real py
    required property real pw
    required property real ph
    // the board: not named board, which a delegate would bind to itself
    property var host: null
    property bool shown: true
    property real zoom: 1
    property real see: 1
    property real lastTap: 0
    readonly property bool hovered: hover.hovered
    readonly property bool jellyWobbling: squish.wobbling

    function zoomAt(k, cx, cy) {
        const z = Math.max(0.15, Math.min(4, pin.zoom * k));
        const real = z / pin.zoom;
        // the point under the pointer stays under it
        pin.x = Math.round(pin.x + cx * (1 - real));
        pin.y = Math.round(pin.y + cy * (1 - real));
        pin.zoom = z;
        sizeChip.flash();
    }

    visible: pin.shown
    x: pin.px
    y: pin.py
    width: Math.round(pin.pw * pin.zoom)
    height: Math.round(pin.ph * pin.zoom)
    Component.onCompleted: squish.kickAfter(0.12, 0)

    RectangularShadow {
        anchors.fill: pic
        radius: pic.radius
        blur: Theme.dp(20)
        offset.y: Theme.dp(5)
        color: Theme.alpha(Theme.shadow, 0.42 * pin.see)
    }

    ClippingRectangle {
        id: pic

        anchors.fill: parent
        radius: Theme.rad(12)
        color: "transparent"
        opacity: pin.see

        Image {
            anchors.fill: parent
            source: pin.host ? pin.host.fileUrl(pin.file) : ""
            fillMode: Image.Stretch
            smooth: true
            mipmap: pin.zoom < 0.9
            asynchronous: true
            cache: false
        }

    }

    Rectangle {
        anchors.fill: parent
        radius: pic.radius
        color: "transparent"
        border.width: pin.hovered ? 2 : 1
        border.color: pin.hovered ? Theme.primary : Theme.alpha(Theme.text, 0.18)
    }

    HoverHandler {
        id: hover

        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    HeldPointer {
        held: drag.active
        cursor: Qt.ClosedHandCursor
    }

    DragHandler {
        id: drag

        target: pin
        onActiveChanged: {
            if (active)
                squish.rest();
            else
                squish.kick(0.08);
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 2;
            if (event.modifiers & Qt.ControlModifier) {
                pin.see = Math.max(0.2, Math.min(1, pin.see + d / 1200));
                sizeChip.flash();
                return ;
            }
            pin.zoomAt(1 + d / 900, event.x, event.y);
        }
    }

    // double taps counted by hand: TapHandler's own count has been unreliable here
    TapHandler {
        onTapped: (point) => {
            const now = Date.now();
            if (now - pin.lastTap < Qt.styleHints.mouseDoubleClickInterval)
                pin.host.remove(pin.pid);
            else
                pin.lastTap = now;
        }
    }

    Rectangle {
        id: tools

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.dp(8)
        width: toolRow.implicitWidth + Theme.dp(8)
        height: Theme.dp(40)
        radius: height / 2
        color: Theme.bgOpaque
        opacity: pin.hovered && pin.width > Theme.dp(120) ? 1 : 0
        visible: opacity > 0.01

        Row {
            id: toolRow

            anchors.centerIn: parent
            spacing: Theme.dp(2)

            ShotButton {
                size: Theme.dp(32)
                icon: "content_copy"
                tip: "Copy it"
                tipAbove: false
                onClicked: pin.host.copy(pin.file)
            }

            ShotButton {
                size: Theme.dp(32)
                icon: "close"
                tip: "Unpin"
                tipAbove: false
                onClicked: pin.host.remove(pin.pid)
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

    }

    ShotChip {
        id: sizeChip

        property bool on: false

        function flash() {
            sizeChip.on = true;
            chipTimer.restart();
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.dp(10)
        text: Math.round(pin.zoom * 100) + "%" + (pin.see < 1 ? "  ·  " + Math.round(pin.see * 100) + "% opaque" : "")
        opacity: sizeChip.on ? 1 : 0
        visible: opacity > 0.01

        Timer {
            id: chipTimer

            interval: 900
            onTriggered: sizeChip.on = false
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

    }

    transform: Jelly {
        id: squish

        target: pin
    }

}
