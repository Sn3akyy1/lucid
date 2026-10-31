import QtQuick
import qs

// edit mode's handle over the dock: carry it up to float it higher, or down into the
// bottom edge to notch it, and up out of the edge to float it again. while it is
// carried a chip says where it would settle
Item {
    id: handle

    property var dock: null
    property Item shellItem: null

    readonly property bool shown: Edit.active && Prefs.dockEnabled && !!handle.dock && !handle.dock.menuOpen && !handle.dock.morphing
    readonly property bool hot: hover.hovered || drag.active

    // over the dock as painted, so it rides a wobble with the top edge
    readonly property bool painted: !!handle.dock && handle.dock.paintW !== undefined
    readonly property real topX: handle.painted ? handle.dock.paintX : (handle.shellItem ? handle.shellItem.x : 0)
    readonly property real topY: handle.painted ? handle.dock.paintY : (handle.shellItem ? handle.shellItem.y : 0)
    readonly property real topW: handle.painted ? handle.dock.paintW : (handle.shellItem ? handle.shellItem.width : 0)

    x: Math.round(handle.topX + (handle.topW - handle.width) / 2)
    y: Math.round(handle.topY - handle.height - Theme.dp(6))
    width: Theme.dp(72)
    height: Theme.dp(18)
    opacity: handle.shown || drag.active ? 1 : 0
    visible: handle.opacity > 0.01

    Rectangle {
        id: grabber

        anchors.centerIn: parent
        width: handle.hot ? Theme.dp(44) : Theme.dp(32)
        height: Theme.dp(5)
        radius: height / 2
        color: drag.active ? Theme.accent : Theme.alpha(Theme.text, handle.hot ? 0.8 : 0.45)

        Behavior on width {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutCubic
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: grabber.top
        anchors.bottomMargin: Theme.dp(10)
        width: readout.implicitWidth + Theme.dp(22)
        height: Theme.dp(28)
        radius: height / 2
        color: Theme.inverseSurface
        opacity: drag.active ? 1 : 0
        scale: drag.active ? 1 : 0.85
        visible: opacity > 0.01

        Text {
            id: readout

            anchors.centerIn: parent
            text: !handle.dock ? "" : (handle.dock.editNotch ? "Notch" : Math.round(handle.dock.editMargin / Theme.uiScale) + " px from the edge")
            color: Theme.fgInverseSurface
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.weight: Font.Medium
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutBack
            }

        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.OutCubic
        }

    }

    HoverHandler {
        id: hover

        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.SizeVerCursor
    }

    DragHandler {
        id: drag

        target: null
        enabled: handle.shown || drag.active
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            const d = handle.dock;
            if (!d)
                return ;

            if (drag.active) {
                d.editStart = d.renderAsNotch ? 0 : Prefs.effectiveDockBottomMargin;
                d.editMargin = d.editStart;
                d.editDragging = true;
                Edit.dragging = true;
            } else if (d.editDragging) {
                d.commitEditPlacement();
            }
        }
        onTranslationChanged: {
            if (drag.active && handle.dock)
                handle.dock.editMargin = Math.max(0, Math.min(Theme.dp(60), handle.dock.editStart - drag.translation.y));

        }
    }

}
