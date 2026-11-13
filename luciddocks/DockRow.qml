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
    // the row's x in the window; when it slides under a drag the dragged icon is held still
    property real originX: 0
    property real heldOriginX: 0
    // window x of the icon being pinned, so its new slot glides in from there
    property real landFrom: -1

    property bool dragging: false
    property Item dragSlot: null
    // an icon armed to pin leaves its slot, and the rest close up behind it
    readonly property bool lifting: row.dragMode === "pin" && row.pinArmed && row.dragSlot !== null
    property real pinDragCenter: -1
    // a pin pulled off the dock goes to the desktop as a launcher instead of unpinning;
    // sending is set while that drag is in the air
    property bool desktopDrop: false
    property bool sending: false

    signal stackPopupRequested(Item view, string appId, string iconName, string command)
    signal contextMenuRequested(Item view, string appId, string command)
    signal launchRecorded(string name)
    // the model is already mutated in place
    signal orderChanged()
    signal removeRequested(int index)
    signal pinRequested(string appId, int index, real from)

    readonly property int slotSize: Theme.dp(Prefs.dockIconSize)
    readonly property int slotGap: Theme.dp(Prefs.dockSpacing)
    readonly property int slotPitch: row.slotSize + row.slotGap
    // the gap opening and the icon landing in it share one timing
    readonly property int enterMs: Theme.ms(220)
    readonly property int count: repeater.count
    readonly property int previewCount: row.count + ((row.reserveSlot && row.dragMode === "reorder") ? 1 : 0) - (row.lifting ? 1 : 0)

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
    Component.onCompleted: row.heldOriginX = row.originX
    onOriginXChanged: {
        var dx = row.originX - row.heldOriginX;
        row.heldOriginX = row.originX;
        if (row.dragSlot)
            row.dragSlot.x -= dx;

    }

    HoverHandler {
        id: rowHover
    }

    Behavior on width {
        enabled: row.ready

        NumberAnimation {
            duration: row.enterMs
            easing.type: Easing.OutCubic
        }

    }

    Rectangle {
        id: dropPlaceholder

        width: row.slotSize
        height: row.slotSize
        radius: Prefs.dockItemRadius
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

                if (row.lifting && slot.index > row.dragSlot.index)
                    base -= 1;

                return base * row.slotPitch;
            }
            readonly property real removeThreshold: 40
            property real dragOffsetY: 0

            readonly property bool overRemoveThreshold: row.dragMode === "reorder" && !row.desktopDrop && dragHandler.active && -slot.y > slot.removeThreshold
            // pulled far enough to leave for the desktop
            property bool outward: false

            // hands the pin to a system drag the desktop takes as a launcher; the slot springs back
            function sendOut() {
                slot.outward = true;
                row.sending = true;
                proxy.Drag.mimeData = {
                    "application/x-lucid-desktop-app": JSON.stringify({
                        "appId": slot.appId,
                        "iconName": slot.iconName,
                        "name": slot.displayName,
                        "command": slot.command
                    })
                };
                proxy.Drag.active = true;
            }
            readonly property bool overPinThreshold: row.dragMode === "pin" && dragHandler.active && row.pinArmed

            property real entranceScale: slot.justAdded ? 0.55 : 1
            property real entranceOpacity: slot.justAdded ? 0 : 1
            property real landShift: 0
            // set before anything moves: an animation writes its start value before it reports running
            property bool landing: false

            width: row.slotSize
            height: row.slotSize
            scale: slot.entranceScale * (slot.overRemoveThreshold ? 0.7 : (slot.overPinThreshold ? 1.12 : 1))
            opacity: slot.entranceOpacity * (slot.overRemoveThreshold ? 0.35 : 1)
            z: dragHandler.active ? 10 : 1
            transform: Translate {
                x: slot.landShift
            }

            Component.onCompleted: {
                if (slot.justAdded && row.landFrom >= 0)
                    slot.land();
                else if (slot.justAdded)
                    entranceAnim.start();

            }

            // dropped from the running row: start where it was let go, still lifted, and settle
            function land() {
                slot.landing = true;
                slot.landShift = row.mapFromItem(null, row.landFrom, 0).x - slot.width / 2 - slot.targetX;
                slot.entranceScale = 1.12;
                slot.entranceOpacity = 1;
                landAnim.start();
            }

            // the model keeps justAdded, so clear it or a rebuilt delegate replays the entrance
            function settled() {
                if (slot.index >= 0 && slot.index < row.model.count)
                    row.model.setProperty(slot.index, "justAdded", false);

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
                if (!dragHandler.active)
                    return;

                slot.dragOffsetY = slot.y;
                if (row.desktopDrop && row.dragMode === "reorder" && !slot.outward && -slot.y > slot.removeThreshold)
                    slot.sendOut();

            }

            function publishCenter() {
                if (row.dragMode === "pin" && dragHandler.active)
                    row.pinDragCenter = slot.mapToItem(null, slot.width / 2, 0).x;

            }

            ParallelAnimation {
                id: entranceAnim

                onFinished: slot.settled()

                NumberAnimation {
                    target: slot
                    property: "entranceScale"
                    to: 1
                    duration: row.enterMs
                    easing.type: Easing.OutBack
                    easing.overshoot: Theme.emphasizedOvershoot
                }

                NumberAnimation {
                    target: slot
                    property: "entranceOpacity"
                    to: 1
                    duration: row.enterMs
                    easing.type: Easing.OutCubic
                }

            }

            ParallelAnimation {
                id: landAnim

                onFinished: {
                    slot.landing = false;
                    slot.settled();
                }

                NumberAnimation {
                    target: slot
                    property: "landShift"
                    to: 0
                    duration: row.enterMs
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: slot
                    property: "entranceScale"
                    to: 1
                    duration: row.enterMs
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
                width: Theme.dp(8)
                height: Theme.dp(8)
                radius: Theme.dp(4)
                color: Theme.accent
                anchors.horizontalCenter: parent.horizontalCenter
                y: -Theme.dp(14)
                opacity: slot.overPinThreshold ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            // what the desktop receives: the app, under its own type, with the icon riding the pointer
            Item {
                id: proxy

                width: slot.width
                height: slot.height
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
                Drag.proposedAction: Qt.CopyAction
                Drag.hotSpot.x: slot.width / 2
                Drag.hotSpot.y: slot.height / 2
                Drag.onDragFinished: (action) => {
                    proxy.Drag.active = false;
                    slot.outward = false;
                    row.sending = false;
                }
            }

            HeldPointer {
                held: dragHandler.active && !slot.outward
                cursor: Qt.ArrowCursor
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
                    row.dragSlot = active ? slot : null;
                    if (active) {
                        slot.dragOffsetY = 0;
                        slot.publishCenter();
                        // the drag image, ready by the time the pin is pulled off
                        if (row.desktopDrop && row.dragMode === "reorder")
                            itemView.grabToImage((r) => {
                                proxy.Drag.imageSource = r.url;
                            });

                        return;
                    }
                    // gone to the desktop as a system drag: the pin stays where it was
                    if (slot.outward) {
                        row.orderChanged();
                        return;
                    }
                    if (row.dragMode === "pin") {
                        // pinning takes this running entry out of the model, which destroys this
                        // delegate mid-handler: read and reset everything before asking
                        var armed = row.pinArmed;
                        var at = row.dropIndex;
                        var id = slot.appId;
                        var from = row.pinDragCenter;
                        row.pinDragCenter = -1;
                        if (armed)
                            row.pinRequested(id, at, from);

                        return;
                    }
                    // with the desktop taking pins, a pull never unpins: the menu does that
                    if (-slot.dragOffsetY > slot.removeThreshold && !row.desktopDrop)
                        removeAnim.start();
                    else
                        row.orderChanged();
                }
            }

            Behavior on x {
                enabled: !dragHandler.active

                NumberAnimation {
                    duration: row.enterMs
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on y {
                enabled: !dragHandler.active

                NumberAnimation {
                    duration: row.enterMs
                    easing.type: Easing.OutCubic
                }

            }

            // a behavior here would restart every frame of the animations
            // below and pin scale at its start value until they finish
            Behavior on scale {
                enabled: !entranceAnim.running && !bumpAnim.running && !removeAnim.running && !slot.landing

                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

}
