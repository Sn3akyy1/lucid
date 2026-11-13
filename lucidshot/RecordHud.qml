import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.lucidui

// what shows while LucidShot records: the countdown, a line round the part
// being recorded (just outside it, so it never ends up in the video) and the
// controls, set down beside that part where there is room
PanelWindow {
    id: hud

    readonly property bool counting: Capture.state === "countdown"
    readonly property bool running: Capture.live || Capture.state === "saving"
    readonly property var area: Capture.region
    // where the controls were dragged to, for the rest of this recording
    property real dragX: -1
    property real dragY: -1
    readonly property real gap: Theme.dp(14)
    readonly property real restX: {
        const w = pill.width;
        if (!hud.area)
            return Math.round((hud.width - w) / 2);

        return Math.round(Math.max(hud.gap, Math.min(hud.width - w - hud.gap, hud.area.x + hud.area.w / 2 - w / 2)));
    }
    readonly property real restY: {
        const h = pill.height;
        // clear of the dock along the bottom, or of a bottom bar
        const low = hud.height - (Prefs.dockOn ? Theme.dp(Prefs.dockIconSize) + Theme.dp(20) + Prefs.effectiveDockBottomMargin : (Prefs.barEnabled && Prefs.barBottom ? Prefs.effectiveBarTopMargin + Theme.dp(Prefs.barHeight) : 0)) - Theme.dp(40) - h;
        if (!hud.area)
            return low;

        const below = hud.area.y + hud.area.h + hud.gap;
        if (below + h <= hud.height - hud.gap)
            return below;

        const above = hud.area.y - hud.gap - h;
        if (above >= hud.gap)
            return above;

        return hud.area.y + hud.area.h - h - hud.gap;
    }

    screen: Capture.screen || Monitors.focusedScreen || Monitors.mainScreen
    visible: (hud.counting || (hud.running && !Capture.hidden)) && Monitors.surfacesUp
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucid-shot-rec"
    mask: hud.counting ? countRegion : pillRegion
    BackgroundEffect.blurRegion: Theme.blurAmount > 0 && hud.running && !Capture.hidden ? pillBlur : null
    onRunningChanged: {
        if (!hud.running) {
            hud.dragX = -1;
            hud.dragY = -1;
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Region {
        id: countRegion

        item: countdown
    }

    Region {
        id: pillRegion

        item: pill
    }

    Region {
        id: pillBlur

        x: pill.x
        y: pill.y
        width: pill.width
        height: pill.height
        radius: pill.height / 2
    }

    Connections {
        function onShowRequested() {
            pill.kick();
        }

        target: Capture
    }

    // the outline, three pixels clear of what is recorded
    Item {
        visible: hud.area !== null
        x: hud.area ? hud.area.x - 4 : 0
        y: hud.area ? hud.area.y - 4 : 0
        width: hud.area ? hud.area.w + 8 : 0
        height: hud.area ? hud.area.h + 8 : 0

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: 3
            border.width: 2
            border.color: Theme.alpha(Theme.error, hud.counting ? 0.6 : 0.9)
        }

    }

    ShotCountdown {
        id: countdown

        visible: hud.counting
        value: Capture.countdown
        fill: Theme.primary
        ink: Theme.fgPrimary
        caption: "Recording starts  ·  click to cancel"
        x: Math.round((hud.area ? hud.area.x + hud.area.w / 2 : hud.width / 2) - width / 2)
        y: Math.round((hud.area ? hud.area.y + hud.area.h / 2 : hud.height / 2) - Theme.dp(88))
        onTapped: Capture.cancel()
    }

    RecordPill {
        id: pill

        visible: hud.running
        tipAbove: pill.y > hud.height / 2
        x: hud.dragX >= 0 ? hud.dragX : hud.restX
        y: hud.dragY >= 0 ? hud.dragY : hud.restY
        width: implicitWidth
        height: implicitHeight

        HeldPointer {
            held: pillDrag.active
            cursor: Qt.ArrowCursor
        }

        DragHandler {
            id: pillDrag

            target: null
            xAxis.enabled: true
            yAxis.enabled: true
            onActiveChanged: {
                if (active) {
                    dragFrom.x = pill.x;
                    dragFrom.y = pill.y;
                }
            }
            onTranslationChanged: {
                if (!active)
                    return ;

                hud.dragX = Math.max(0, Math.min(hud.width - pill.width, dragFrom.x + translation.x));
                hud.dragY = Math.max(0, Math.min(hud.height - pill.height, dragFrom.y + translation.y));
            }

            property point dragFrom: Qt.point(0, 0)
        }

    }

}
