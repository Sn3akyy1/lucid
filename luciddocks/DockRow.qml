import QtQuick
import qs

Item {
    id: row

    property var model: null
    property string dragMode: "none"
    property var clients: []
    property int activeWorkspaceId: -1
    property string focusedAddress: ""
    property bool ready: false
    property bool pointerInside: true
    property int dropIndex: -1
    property bool dropActive: false
    property bool reserveSlot: false
    property bool pinArmed: false

    property bool dragging: false
    property real pinDragCenter: -1

    signal stackPopupRequested(Item view, string appId, string iconName, string command)
    signal contextMenuRequested(Item view, string appId, string command)
    signal launchRecorded(string name)
    // the model is already mutated in place
    signal orderChanged()
    signal removeRequested(int index)
    signal pinRequested(string appId, int index)

    readonly property int slotSize: Prefs.dockIconSize
    readonly property int slotGap: Prefs.dockSpacing
    readonly property int slotPitch: row.slotSize + row.slotGap
    readonly property int count: repeater.count
    readonly property int previewCount: row.count + ((row.reserveSlot && row.dragMode === "reorder") ? 1 : 0)

    readonly property int hoveredSlot: (rowHover.hovered && row.pointerInside) ? Math.max(0, Math.min(row.count - 1, Math.floor(rowHover.point.position.x / row.slotPitch))) : -1

    function bump(index) {
        var it = repeater.itemAt(index);
        if (it)
            it.bump();

    }

    function boostFor(index) {
        if (!Prefs.dockMagnify || row.dragging || row.hoveredSlot < 0)
            return 0;

        var dist = Math.abs(index - row.hoveredSlot);
        if (dist === 1)
            return 0.06 * Prefs.dockHoverEffect;

        if (dist === 2)
            return 0.025 * Prefs.dockHoverEffect;

        return 0;
    }

    width: row.previewCount > 0 ? row.previewCount * row.slotPitch - row.slotGap : 0
    height: row.slotSize
    visible: row.width > 0.5 || row.dragging

    HoverHandler {
        id: rowHover
    }

    Behavior on width {
        enabled: row.ready

        NumberAnimation {
            duration: Theme.ms(220)
            easing.type: Easing.OutCubic
        }

    }

    Rectangle {
        id: dropPlaceholder

        width: row.slotSize
        height: row.slotSize
        radius: Math.round(14 * row.slotSize / 46)
        color: Theme.alpha(Theme.accent, 0.15)
        visible: row.dragMode === "reorder" && row.dropActive && row.dropIndex >= 0
        x: Math.max(0, Math.min(row.dropIndex, row.count)) * row.slotPitch
        z: 5

        Behavior on x {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.OutCubic
            }

        }

    }

    Repeater {
        id: repeater

        model: row.model

        delegate: Item {
            id: slot

            required property string iconName
            required property string command
            required property string appId
            required property string displayName
            required property bool justAdded
            required property int index

            readonly property real targetX: {
                var base = slot.index;
                if (row.dragMode === "reorder" && row.reserveSlot && row.dropIndex >= 0 && slot.index >= row.dropIndex)
                    base += 1;

                return base * row.slotPitch;
            }
            readonly property real removeThreshold: 40
            property real dragOffsetY: 0

            readonly property bool overRemoveThreshold: row.dragMode === "reorder" && dragHandler.active && -slot.y > slot.removeThreshold
            readonly property bool overPinThreshold: row.dragMode === "pin" && dragHandler.active && row.pinArmed

            property real entranceScale: slot.justAdded ? 0 : 1
            property real entranceOpacity: slot.justAdded ? 0 : 1

            width: row.slotSize
            height: row.slotSize
            scale: slot.entranceScale * (slot.overRemoveThreshold ? 0.7 : (slot.overPinThreshold ? 1.12 : 1))
            opacity: slot.entranceOpacity * (slot.overRemoveThreshold ? 0.35 : 1)
            z: dragHandler.active ? 10 : 1

            Component.onCompleted: {
                if (slot.justAdded)
                    entranceAnim.start();

            }

            function bump() {
                slot.entranceScale = 0.72;
                bumpAnim.restart();
            }

            NumberAnimation {
                id: bumpAnim

                target: slot
                property: "entranceScale"
                to: 1
                duration: Theme.durEnter
                easing.type: Easing.OutBack
                easing.overshoot: Theme.emphasizedOvershoot
            }

            onXChanged: {
                slot.publishCenter();
                if (row.dragMode !== "reorder" || !dragHandler.active)
                    return;

                var myCenter = slot.x + slot.width / 2;
                var candidate = Math.round(myCenter / row.slotPitch);
                candidate = Math.max(0, Math.min(row.count - 1, candidate));
                if (candidate !== slot.index)
                    row.model.move(slot.index, candidate, 1);

            }
            onYChanged: {
                if (dragHandler.active)
                    slot.dragOffsetY = slot.y;

            }

            function publishCenter() {
                if (row.dragMode === "pin" && dragHandler.active)
                    row.pinDragCenter = slot.mapToItem(null, slot.width / 2, 0).x;

            }

            ParallelAnimation {
                id: entranceAnim

                NumberAnimation {
                    target: slot
                    property: "entranceScale"
                    to: 1
                    duration: Theme.durEnter
                    easing.type: Easing.OutBack
                    easing.overshoot: Theme.emphasizedOvershoot
                }

                NumberAnimation {
                    target: slot
                    property: "entranceOpacity"
                    to: 1
                    duration: Theme.ms(220)
                    easing.type: Easing.OutCubic
                }

            }

            ParallelAnimation {
                id: removeAnim

                onFinished: row.removeRequested(slot.index)

                NumberAnimation {
                    target: slot
                    property: "entranceScale"
                    to: 0
                    duration: Theme.durExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedAccel
                }

                NumberAnimation {
                    target: slot
                    property: "entranceOpacity"
                    to: 0
                    duration: Theme.durExit
                    easing.type: Easing.InCubic
                }

            }

            Binding {
                target: slot
                property: "x"
                value: slot.targetX
                when: !dragHandler.active
            }

            Binding {
                target: slot
                property: "y"
                value: 0
                when: !dragHandler.active
            }

            DockItem {
                id: itemView

                iconName: slot.iconName
                command: slot.command
                appId: slot.appId
                displayName: slot.displayName
                clients: row.clients
                activeWorkspaceId: row.activeWorkspaceId
                focusedAddress: row.focusedAddress
                magnifyBoost: row.boostFor(slot.index)
                pointerInside: row.pointerInside
                onRequestStackPopup: row.stackPopupRequested(itemView, slot.appId, slot.iconName, slot.command)
                onRequestContextMenu: row.contextMenuRequested(itemView, slot.appId, slot.command)
                onLaunched: row.launchRecorded(slot.displayName)
            }

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Theme.accent
                anchors.horizontalCenter: parent.horizontalCenter
                y: -14
                opacity: slot.overPinThreshold ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            DragHandler {
                id: dragHandler

                enabled: row.dragMode !== "none"
                target: slot
                yAxis.enabled: row.dragMode === "reorder"
                yAxis.minimum: -200
                yAxis.maximum: 0
                xAxis.minimum: row.dragMode === "pin" ? slot.targetX - row.width - 4000 : 0
                xAxis.maximum: row.dragMode === "pin" ? slot.targetX + 40 : (row.count - 1) * row.slotPitch

                onActiveChanged: {
                    row.dragging = active;
                    if (active) {
                        slot.dragOffsetY = 0;
                        slot.publishCenter();
                        return;
                    }
                    if (row.dragMode === "pin") {
                        if (row.pinArmed)
                            row.pinRequested(slot.appId, row.dropIndex);

                        row.pinDragCenter = -1;
                        return;
                    }
                    if (-slot.dragOffsetY > slot.removeThreshold)
                        removeAnim.start();
                    else
                        row.orderChanged();
                }
            }

            Behavior on x {
                enabled: !dragHandler.active

                NumberAnimation {
                    duration: Theme.ms(220)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on y {
                enabled: !dragHandler.active

                NumberAnimation {
                    duration: Theme.ms(220)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

}
