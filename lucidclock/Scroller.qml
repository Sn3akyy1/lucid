import QtQuick
import QtQuick.Controls
import qs

// a flickable for the clock's pages: a notch of the wheel glides a good step,
// a touchpad moves it under the fingers, and a thin bar shows where you are
Flickable {
    id: sc

    property real step: Theme.dp(180)
    readonly property bool scrollable: sc.contentHeight > sc.height + 1
    readonly property real maxY: Math.max(0, sc.contentHeight - sc.height)

    // bring a child into view, with a little room round it
    function reveal(item) {
        if (!item)
            return ;

        const p = item.mapToItem(sc.contentItem, 0, 0);
        const pad = Theme.dp(16);
        let to = sc.contentY;
        if (p.y - pad < sc.contentY)
            to = p.y - pad;
        else if (p.y + item.height + pad > sc.contentY + sc.height)
            to = p.y + item.height + pad - sc.height;
        sc.glideTo(to);
    }

    function glideTo(y) {
        const to = Math.max(0, Math.min(sc.maxY, y));
        glide.stop();
        glide.from = sc.contentY;
        glide.to = to;
        glide.start();
    }

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 6000
    maximumFlickVelocity: 9000

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse
        onWheel: (e) => {
            e.accepted = true;
            const base = glide.running ? glide.to : sc.contentY;
            const to = Math.max(0, Math.min(sc.maxY, base - (e.angleDelta.y / 120) * sc.step));
            if (to !== base)
                sc.glideTo(to);

        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.TouchPad
        onWheel: (e) => {
            e.accepted = true;
            glide.stop();
            const dy = e.pixelDelta.y !== 0 ? e.pixelDelta.y : e.angleDelta.y / 4;
            sc.contentY = Math.max(0, Math.min(sc.maxY, sc.contentY - dy));
        }
    }

    NumberAnimation {
        id: glide

        target: sc
        property: "contentY"
        duration: Theme.ms(220)
        easing.type: Easing.OutCubic
    }

    ScrollBar.vertical: ScrollBar {
        policy: sc.scrollable ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        contentItem: Rectangle {
            implicitWidth: Theme.dp(4)
            radius: width / 2
            color: Theme.alpha(Theme.text, 0.35)
        }

        background: Item {
        }

    }

}
