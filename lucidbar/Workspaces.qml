import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._FocusGrab
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root

    // mirrors shell's own radius below - exposed so shell.qml can shape
    // this widget's real compositor blur region to match its rounded
    // pill/card shape instead of a plain rectangle.
    readonly property int cornerRadius: root.expanded ? 20 : 60
    property var hostWindow: null
    property var clients: []
    property var iconByClass: ({
    })
    property bool expanded: false
    property real restX: 0
    property real restY: 0
    property var pendingMoves: ({
    })
    property var pendingSwaps: ({
    })
    property int dragHoverIndex: -1
    property string dragSwapTarget: ""
    property bool anyThumbDragging: false
    readonly property int maxWorkspaces: 6
    readonly property int horizontalPadding: 10
    readonly property int dotGap: 6
    readonly property int dotSize: 10
    readonly property int activeDotWidth: 24
    readonly property int hoverDotSize: 24
    readonly property int hoverActiveDotWidth: 38
    readonly property int highestWorkspaceId: {
        let max = 0;
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > max)
                max = ws.id;

        }
        return max;
    }
    readonly property int slotCount: Math.max(root.maxWorkspaces, root.highestWorkspaceId)
    property int hoveredWsId: -1
    readonly property int compactWidth: dotsRow.implicitWidth + horizontalPadding * 2
    readonly property int compactHeight: 35
    readonly property int basePreviewW: 200
    readonly property int basePreviewH: 125
    readonly property int baseLabelGap: 6
    readonly property int baseLabelHeight: 16
    readonly property int baseTileSpacing: 16
    readonly property int baseCardPadding: 22
    readonly property int gridColumns: Math.max(3, Math.min(6, Math.ceil(Math.sqrt(root.slotCount))))
    readonly property int gridRows: Math.ceil(root.slotCount / root.gridColumns)
    readonly property real maxGridWidth: (root.hostWindow ? root.hostWindow.screen.width : 1280) * 0.85 - root.baseCardPadding * 2
    readonly property real maxGridHeight: (root.hostWindow ? root.hostWindow.screen.height : 800) * 0.75 - root.baseCardPadding * 2
    readonly property real naturalGridWidth: root.gridColumns * root.basePreviewW + (root.gridColumns - 1) * root.baseTileSpacing
    readonly property real naturalGridHeight: root.gridRows * (root.basePreviewH + root.baseLabelGap + root.baseLabelHeight) + (root.gridRows - 1) * root.baseTileSpacing
    readonly property real gridScale: Math.max(0.5, Math.min(1, root.maxGridWidth / root.naturalGridWidth, root.maxGridHeight / root.naturalGridHeight))
    readonly property int previewW: Math.round(root.basePreviewW * root.gridScale)
    readonly property int previewH: Math.round(root.basePreviewH * root.gridScale)
    readonly property int labelGap: Math.round(root.baseLabelGap * root.gridScale)
    readonly property int labelHeight: Math.round(root.baseLabelHeight * root.gridScale)
    readonly property int tileW: root.previewW
    readonly property int tileH: root.previewH + root.labelGap + root.labelHeight
    readonly property int tileSpacing: Math.round(root.baseTileSpacing * root.gridScale)
    readonly property int cardPadding: root.baseCardPadding
    readonly property int gridWidth: root.gridColumns * root.tileW + (root.gridColumns - 1) * root.tileSpacing
    readonly property int gridHeight: root.gridRows * root.tileH + (root.gridRows - 1) * root.tileSpacing
    readonly property int cardWidth: root.gridWidth + root.cardPadding * 2
    readonly property int cardHeight: root.gridHeight + root.cardPadding * 2
    readonly property real labelFontSize: Math.max(9, 12 * root.gridScale)
    readonly property real plusFontSize: Math.max(16, 28 * root.gridScale)

    function syncWindowModel() {
        const wanted = [];
        for (const c of root.clients) {
            if (!c.workspace || !c.address || !c.at || !c.size)
                continue;

            const override = root.pendingMoves[c.address];
            const wsId = override !== undefined ? override : c.workspace.id;
            const slotIndex = wsId - 1;
            if (slotIndex < 0 || slotIndex >= root.slotCount)
                continue;

            const swapOverride = root.pendingSwaps[c.address];
            const atX = swapOverride ? swapOverride.atX : c.at[0];
            const atY = swapOverride ? swapOverride.atY : c.at[1];
            const sizeW = swapOverride ? swapOverride.sizeW : c.size[0];
            const sizeH = swapOverride ? swapOverride.sizeH : c.size[1];
            wanted.push({
                "address": c.address,
                "wsId": wsId,
                "slotIndex": slotIndex,
                "atX": atX,
                "atY": atY,
                "sizeW": sizeW,
                "sizeH": sizeH,
                "monitor": c.monitor,
                "iconClass": c.class || ""
            });
        }
        const wantedAddrs = {
        };
        for (const w of wanted) wantedAddrs[w.address] = true
        for (let i = windowModel.count - 1; i >= 0; i--) {
            if (!wantedAddrs[windowModel.get(i).address])
                windowModel.remove(i, 1);

        }
        for (let k = 0; k < wanted.length; k++) {
            let existing = -1;
            for (let m = k; m < windowModel.count; m++) {
                if (windowModel.get(m).address === wanted[k].address) {
                    existing = m;
                    break;
                }
            }
            if (existing === -1) {
                windowModel.insert(k, wanted[k]);
            } else {
                if (existing !== k)
                    windowModel.move(existing, k, 1);

                windowModel.set(k, wanted[k]);
            }
        }
    }

    function normalizeAddress(addr) {
        addr = (addr || "").toLowerCase();
        return addr.indexOf("0x") === 0 ? addr : "0x" + addr;
    }

    function toplevelFor(address) {
        const want = root.normalizeAddress(address);
        for (const t of Hyprland.toplevels.values) {
            if (root.normalizeAddress(t.address) === want)
                return t;

        }
        return null;
    }

    function wsAt(index) {
        const wantId = index + 1;
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id === wantId)
                return ws;

        }
        return null;
    }

    function monitorAt(monitorId) {
        for (const m of Hyprland.monitors.values) {
            if (m.id === monitorId)
                return m;

        }
        return null;
    }

    function prunePendingMoves() {
        const pm = root.pendingMoves;
        let changed = false;
        for (const c of root.clients) {
            if (c.workspace && pm[c.address] !== undefined && pm[c.address] === c.workspace.id) {
                delete pm[c.address];
                changed = true;
            }
        }
        if (changed)
            root.pendingMoves = pm;

    }

    function prunePendingSwaps() {
        const ps = root.pendingSwaps;
        let changed = false;
        for (const c of root.clients) {
            const ov = ps[c.address];
            if (ov && c.at && c.at[0] === ov.atX && c.at[1] === ov.atY) {
                delete ps[c.address];
                changed = true;
            }
        }
        if (changed)
            root.pendingSwaps = ps;

    }

    function moveWindowToWorkspace(address, workspaceId) {
        var lua = "local w=nil for i,win in pairs(hl.get_windows()) do if win.address=='" + address + "' then w=win end end if w then hl.dispatch(hl.dsp.window.move({workspace=" + workspaceId + ", follow=false, window=w})) end";
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    function swapWindows(addressA, addressB) {
        var lua = "local w=nil for i,win in pairs(hl.get_windows()) do if win.address=='" + addressA + "' then w=win end end if w then hl.dispatch(hl.dsp.window.swap({target='address:" + addressB + "', window=w})) end";
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    function findSwapTarget(excludeAddress, slotIdx, centerX, centerY) {
        for (let i = 0; i < windowModel.count; i++) {
            const row = windowModel.get(i);
            if (row.address === excludeAddress || row.slotIndex !== slotIdx)
                continue;

            const item = thumbRepeater.itemAt(i);
            if (!item)
                continue;

            if (centerX >= item.restX && centerX <= item.restX + item.restW && centerY >= item.restY && centerY <= item.restY + item.restH)
                return row.address;

        }
        return "";
    }

    onClientsChanged: {
        root.prunePendingMoves();
        root.prunePendingSwaps();
        root.syncWindowModel();
    }
    onPendingMovesChanged: root.syncWindowModel()
    onPendingSwapsChanged: root.syncWindowModel()
    implicitWidth: root.compactWidth
    implicitHeight: root.compactHeight
    x: root.restX
    y: root.restY
    z: root.expanded ? 100 : 1

    ListModel {
        id: windowModel
    }

    HyprlandFocusGrab {
        active: root.expanded
        windows: root.hostWindow ? [root.hostWindow] : []
        onCleared: root.expanded = false
    }

    HoverHandler {
        id: rowHover

        enabled: !root.expanded
        onHoveredChanged: {
            if (!hovered)
                root.hoveredWsId = -1;

        }
    }

    Rectangle {
        id: shell

        anchors.fill: parent
        color: Theme.bg
        radius: root.expanded ? 20 : 60
        clip: !root.anyThumbDragging

        Item {
            id: compactFace

            anchors.fill: parent
            opacity: root.expanded ? 0 : 1
            scale: root.expanded ? 0.94 : 1
            visible: opacity > 0.01

            Row {
                id: dotsRow

                anchors.centerIn: parent
                spacing: root.dotGap

                Repeater {
                    model: root.slotCount

                    Rectangle {
                        id: dot

                        required property int index
                        readonly property int wsId: index + 1
                        readonly property var wsObj: root.wsAt(dot.index)
                        readonly property bool isActive: wsObj ? wsObj.active : false
                        readonly property bool isUrgent: wsObj ? wsObj.urgent : false
                        readonly property bool hovered: rowHover.hovered
                        readonly property bool isLit: hovered && (root.hoveredWsId === -1 ? isActive : root.hoveredWsId === wsId)

                        width: hovered ? (isLit ? root.hoverActiveDotWidth : root.hoverDotSize) : ((isActive || isUrgent) ? root.activeDotWidth : root.dotSize)
                        height: hovered ? root.hoverDotSize : root.dotSize
                        radius: 999
                        color: isUrgent ? Theme.error : (hovered ? (isLit ? Theme.accent : "transparent") : (isActive ? Theme.accent : Theme.withBlur(Theme._darken(Theme.subtext, 0.45))))

                        Text {
                            anchors.centerIn: parent
                            text: dot.wsId
                            opacity: dot.hovered ? 1 : 0
                            color: dot.isLit ? Theme.bgOpaque : Theme.subtext
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: 13

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered)
                                    root.hoveredWsId = dot.wsId;

                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (dot.wsObj && dot.isActive)
                                    root.expanded = true;
                                else if (dot.wsObj)
                                    dot.wsObj.activate();
                                else
                                    Hyprland.dispatch('hl.dsp.focus({workspace=' + dot.wsId + '})');
                            }
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

        }

        Item {
            id: expandedFace

            anchors.fill: parent
            opacity: root.expanded ? 1 : 0
            scale: root.expanded ? 1 : 1.04
            visible: opacity > 0.01

            MouseArea {
                anchors.fill: parent
                onClicked: root.expanded = false
            }

            Item {
                id: grid

                width: root.gridWidth
                height: root.gridHeight
                anchors.centerIn: parent

                Repeater {
                    id: tileRepeater

                    model: root.slotCount

                    Item {
                        id: tile

                        required property int index
                        readonly property bool hovered: tileHover.hovered
                        readonly property var wsObj: root.wsAt(tile.index)
                        readonly property bool isActive: tile.wsObj ? tile.wsObj.active : false
                        readonly property bool isUrgent: tile.wsObj ? tile.wsObj.urgent : false
                        readonly property bool isDropTarget: root.dragHoverIndex === tile.index

                        x: (tile.index % root.gridColumns) * (root.tileW + root.tileSpacing)
                        y: Math.floor(tile.index / root.gridColumns) * (root.tileH + root.tileSpacing)
                        width: root.tileW
                        height: root.tileH

                        Rectangle {
                            id: card

                            width: root.previewW
                            height: root.previewH
                            radius: 10
                            color: tile.hovered ? Theme.bgHover : "transparent"
                            border.color: tile.isUrgent ? Theme.error : ((tile.isActive || tile.hovered || tile.isDropTarget) ? Theme.accent : Theme.alpha(Theme.text, 0.25))
                            border.width: (tile.isActive || tile.isUrgent || tile.hovered || tile.isDropTarget) ? 2 : 1
                            opacity: tile.wsObj ? 1 : 0.5
                            scale: tile.hovered ? 1.03 : 1

                            Text {
                                anchors.centerIn: parent
                                visible: !tile.wsObj
                                text: "+"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: root.plusFontSize
                                font.bold: true
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        HoverHandler {
                            id: tileHover
                        }

                        Text {
                            anchors.top: card.bottom
                            anchors.horizontalCenter: card.horizontalCenter
                            anchors.topMargin: root.labelGap
                            text: "Workspace " + (tile.index + 1)
                            color: tile.hovered ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: root.labelFontSize

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Hyprland.dispatch('hl.dsp.focus({workspace=' + (tile.index + 1) + '})');
                                root.expanded = false;
                            }
                        }

                    }

                }

                Repeater {
                    id: thumbRepeater

                    model: windowModel

                    ClippingRectangle {
                        id: thumb

                        required property string address
                        required property int wsId
                        required property int slotIndex
                        required property int atX
                        required property int atY
                        required property int sizeW
                        required property int sizeH
                        required property int monitor
                        required property string iconClass
                        readonly property string resolvedIconName: root.iconByClass[thumb.iconClass.toLowerCase()] || thumb.iconClass
                        readonly property var monitorObj: root.monitorAt(thumb.monitor)
                        readonly property var reserved: (thumb.monitorObj && thumb.monitorObj.lastIpcObject && thumb.monitorObj.lastIpcObject.reserved) || [0, 0, 0, 0]
                        readonly property real usableMonX: thumb.monitorObj ? thumb.monitorObj.x + thumb.reserved[0] : 0
                        readonly property real usableMonY: thumb.monitorObj ? thumb.monitorObj.y + thumb.reserved[1] : 0
                        readonly property real usableMonW: thumb.monitorObj ? Math.max(1, thumb.monitorObj.width - thumb.reserved[0] - thumb.reserved[2]) : 1
                        readonly property real usableMonH: thumb.monitorObj ? Math.max(1, thumb.monitorObj.height - thumb.reserved[1] - thumb.reserved[3]) : 1
                        readonly property real fracX: Math.max(0, Math.min(1, (thumb.atX - thumb.usableMonX) / thumb.usableMonW))
                        readonly property real fracY: Math.max(0, Math.min(1, (thumb.atY - thumb.usableMonY) / thumb.usableMonH))
                        readonly property real fracW: Math.max(0, Math.min(1, thumb.sizeW / thumb.usableMonW))
                        readonly property real fracH: Math.max(0, Math.min(1, thumb.sizeH / thumb.usableMonH))
                        readonly property real tileX: (thumb.slotIndex % root.gridColumns) * (root.tileW + root.tileSpacing)
                        readonly property real tileY: Math.floor(thumb.slotIndex / root.gridColumns) * (root.tileH + root.tileSpacing)
                        readonly property real insetPad: 3
                        readonly property real usableW: root.previewW - thumb.insetPad * 2
                        readonly property real usableH: root.previewH - thumb.insetPad * 2
                        readonly property real thumbGap: 4
                        readonly property real rawX: thumb.tileX + thumb.insetPad + thumb.fracX * thumb.usableW
                        readonly property real rawY: thumb.tileY + thumb.insetPad + thumb.fracY * thumb.usableH
                        readonly property real rawW: thumb.fracW * thumb.usableW
                        readonly property real rawH: thumb.fracH * thumb.usableH
                        readonly property real clampedW: Math.min(thumb.rawW, thumb.usableW)
                        readonly property real clampedH: Math.min(thumb.rawH, thumb.usableH)
                        readonly property real clampedX: Math.min(thumb.rawX, thumb.tileX + thumb.insetPad + thumb.usableW - thumb.clampedW)
                        readonly property real clampedY: Math.min(thumb.rawY, thumb.tileY + thumb.insetPad + thumb.usableH - thumb.clampedH)
                        readonly property real restX: thumb.clampedX + thumb.thumbGap / 2
                        readonly property real restY: thumb.clampedY + thumb.thumbGap / 2
                        readonly property real restW: Math.max(2, thumb.clampedW - thumb.thumbGap)
                        readonly property real restH: Math.max(2, thumb.clampedH - thumb.thumbGap)
                        readonly property var toplevel: root.toplevelFor(thumb.address)
                        property bool everHadContent: false
                        property real dragStartX: 0
                        property real dragStartY: 0
                        property int dragStartWsId: 0
                        property bool settling: false
                        property real settleX: 0
                        property real settleY: 0
                        readonly property bool isSwapTarget: !dragHandler.active && root.dragSwapTarget === thumb.address

                        x: dragHandler.active ? thumb.dragStartX + dragHandler.translation.x : (thumb.settling ? thumb.settleX : thumb.restX)
                        y: dragHandler.active ? thumb.dragStartY + dragHandler.translation.y : (thumb.settling ? thumb.settleY : thumb.restY)
                        width: thumb.restW
                        height: thumb.restH
                        radius: 6
                        color: Theme.withBlur(Theme.bgSunken)
                        border.width: dragHandler.active || thumb.isSwapTarget ? 2 : 1
                        border.color: thumb.isSwapTarget ? Theme.accent : (dragHandler.active ? Theme.accent : Theme.alpha(Theme.text, 0.25))
                        scale: dragHandler.active ? 1.06 : 1
                        z: dragHandler.active ? 10 : 1
                        onSlotIndexChanged: thumb.settling = false
                        onAtXChanged: thumb.settling = false
                        onAtYChanged: thumb.settling = false

                        Timer {
                            id: settleTimer

                            interval: 1300
                            onTriggered: thumb.settling = false
                        }

                        DragHandler {
                            id: dragHandler

                            function hoverIndexFor() {
                                const centerX = thumb.x + thumb.width / 2;
                                const centerY = thumb.y + thumb.height / 2;
                                const col = Math.max(0, Math.min(root.gridColumns - 1, Math.floor(centerX / (root.tileW + root.tileSpacing))));
                                const row = Math.max(0, Math.min(root.gridRows - 1, Math.floor(centerY / (root.tileH + root.tileSpacing))));
                                return Math.max(0, Math.min(root.slotCount - 1, row * root.gridColumns + col));
                            }

                            function updateSettleTarget(idx) {
                                const tx = (idx % root.gridColumns) * (root.tileW + root.tileSpacing);
                                const ty = Math.floor(idx / root.gridColumns) * (root.tileH + root.tileSpacing);
                                thumb.settleX = tx + thumb.insetPad + thumb.fracX * thumb.usableW + thumb.thumbGap / 2;
                                thumb.settleY = ty + thumb.insetPad + thumb.fracY * thumb.usableH + thumb.thumbGap / 2;
                                thumb.settling = true;
                            }

                            onActiveChanged: {
                                if (active) {
                                    root.anyThumbDragging = true;
                                    thumb.settling = false;
                                    thumb.dragStartWsId = thumb.wsId;
                                    thumb.dragStartX = thumb.x;
                                    thumb.dragStartY = thumb.y;
                                    return ;
                                }
                                root.anyThumbDragging = false;
                                root.dragHoverIndex = -1;
                                settleTimer.restart();
                                const swapAddress = root.dragSwapTarget;
                                root.dragSwapTarget = "";
                                const targetWsId = dragHandler.hoverIndexFor() + 1;
                                if (targetWsId === thumb.dragStartWsId) {
                                    if (swapAddress !== "") {
                                        let rowA = null, rowB = null;
                                        for (let i = 0; i < windowModel.count; i++) {
                                            const r = windowModel.get(i);
                                            if (r.address === thumb.address)
                                                rowA = r;
                                            else if (r.address === swapAddress)
                                                rowB = r;
                                        }
                                        if (rowA && rowB) {
                                            const ps = root.pendingSwaps;
                                            ps[thumb.address] = {
                                                "atX": rowB.atX,
                                                "atY": rowB.atY,
                                                "sizeW": rowB.sizeW,
                                                "sizeH": rowB.sizeH
                                            };
                                            ps[swapAddress] = {
                                                "atX": rowA.atX,
                                                "atY": rowA.atY,
                                                "sizeW": rowA.sizeW,
                                                "sizeH": rowA.sizeH
                                            };
                                            root.pendingSwaps = ps;
                                        }
                                        root.swapWindows(thumb.address, swapAddress);
                                    }
                                } else {
                                    const pm = root.pendingMoves;
                                    pm[thumb.address] = targetWsId;
                                    root.pendingMoves = pm;
                                    root.moveWindowToWorkspace(thumb.address, targetWsId);
                                }
                            }
                            onCentroidChanged: {
                                if (!dragHandler.active)
                                    return ;

                                const idx = dragHandler.hoverIndexFor();
                                if (idx !== root.dragHoverIndex) {
                                    root.dragHoverIndex = idx;
                                    dragHandler.updateSettleTarget(idx);
                                }
                                root.dragSwapTarget = root.findSwapTarget(thumb.address, idx, thumb.x + thumb.width / 2, thumb.y + thumb.height / 2);
                            }
                        }

                        ScreencopyView {
                            id: preview

                            anchors.centerIn: parent
                            constraintSize.width: thumb.width
                            constraintSize.height: thumb.height
                            captureSource: thumb.toplevel ? thumb.toplevel.wayland : null
                            live: root.expanded
                            visible: thumb.everHadContent || hasContent
                            onHasContentChanged: {
                                if (hasContent)
                                    thumb.everHadContent = true;

                            }

                            transform: Scale {
                                id: fitScale

                                origin.x: preview.width / 2
                                origin.y: preview.height / 2
                                xScale: preview.width > 0 && preview.height > 0 ? Math.max(thumb.width / preview.width, thumb.height / preview.height) : 1
                                yScale: fitScale.xScale
                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.margins: 4
                            width: parent.width - 8
                            visible: !thumb.everHadContent && !preview.hasContent
                            text: thumb.iconClass
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            id: appBadge

                            readonly property real iconSize: Math.max(10, Math.min(22, Math.min(thumb.restW, thumb.restH) * 0.35))

                            visible: thumb.resolvedIconName !== "" && badgeIcon.status === Image.Ready
                            anchors.centerIn: parent
                            width: appBadge.iconSize
                            height: appBadge.iconSize
                            radius: appBadge.iconSize * 0.28
                            color: Theme.alpha(Theme.bg, 0.85)

                            IconImage {
                                id: badgeIcon

                                anchors.fill: parent
                                anchors.margins: Math.max(1, appBadge.iconSize * 0.1)
                                source: thumb.resolvedIconName !== "" ? Quickshell.iconPath(thumb.resolvedIconName, "") : ""
                                asynchronous: true
                            }

                        }

                        Behavior on x {
                            enabled: !dragHandler.active

                            NumberAnimation {
                                duration: 280
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on y {
                            enabled: !dragHandler.active

                            NumberAnimation {
                                duration: 280
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 150
                            }

                        }

                    }

                }

            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.expanded ? 140 : 0
                    }

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on scale {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.expanded ? 140 : 0
                    }

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutCubic
            }

        }

    }

    states: State {
        name: "expanded"
        when: root.expanded

        PropertyChanges {
            target: root
            implicitWidth: root.cardWidth
            implicitHeight: root.cardHeight
            x: root.hostWindow ? (root.hostWindow.screen.width - root.cardWidth) / 2 - root.hostWindow.margins.left : (parent.width - root.cardWidth) / 2
            y: root.hostWindow ? (root.hostWindow.screen.height - root.cardHeight) / 2 - root.hostWindow.margins.top : (parent.height - root.cardHeight) / 2
        }

    }

    transitions: Transition {
        NumberAnimation {
            properties: "x,y,implicitWidth,implicitHeight"
            duration: 380
            easing.type: Easing.OutCubic
        }

    }

}
