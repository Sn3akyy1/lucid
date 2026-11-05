import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs

// the dock's apps, on the bar: the pinned ones and then whatever else is open.
// a click opens an app or brings its window up; with several windows, or on a
// right click, the panel lists them and what can be done to the app
BarPill {
    id: root

    property var dockMod: null
    // the app the panel is about
    property string chosen: ""
    // from the toplevels themselves, as the active window module reads them: a
    // window's ipc record is only filled in on a refresh, so it can be missing
    readonly property var windows: Hyprland.toplevels.values.filter((t) => {
        return !!t && root.classOf(t) !== "";
    })
    // about half the bar's height, leaving room under it for the running dot
    readonly property int glyph: Math.max(Theme.dp(12), Math.min(Math.round(root.compactHeight * 0.55), root.compactHeight - Theme.dp(16)))
    readonly property int slot: root.compactHeight - Theme.dp(4)
    readonly property int horizontalPadding: Theme.dp(4)
    // pins first, in the dock's order, then the open apps not pinned, in the
    // order their first window came
    readonly property var items: {
        const out = [];
        const seen = {};
        const pins = root.dockMod ? (root.dockMod.pinnedList || []) : [];
        for (const p of pins) {
            const id = String(p.appId || p.appKey || "");
            if (id === "" || seen[id.toLowerCase()])
                continue;

            seen[id.toLowerCase()] = true;
            out.push({
                "appId": id,
                "name": p.name || id,
                "icon": p.iconName || id,
                "command": p.command || "",
                "pinned": true
            });
        }
        for (const t of (Prefs.dockShowRunning ? root.windows : [])) {
            const id = root.classOf(t);
            if (id === "" || seen[id.toLowerCase()])
                continue;

            seen[id.toLowerCase()] = true;
            const entry = root.dockMod.entryForClass(id);
            out.push({
                "appId": id,
                "name": entry && entry.name ? entry.name : id,
                "icon": entry && entry.iconName ? entry.iconName : id,
                "command": entry && entry.command ? entry.command : "",
                "pinned": false
            });
        }
        return out;
    }
    // a third of the bar at most; past that the last slot is a "+N" that opens the
    // rest. the open apps keep their place on the bar, the pins give way
    readonly property int maxSlots: Math.max(2, Math.floor(((root.hostWindow ? root.hostWindow.width : Theme.dp(1920)) / 3 - root.horizontalPadding * 2) / root.slot))
    readonly property var placed: {
        if (root.items.length <= root.maxSlots)
            return {
                "shown": root.items,
                "rest": []
            };

        const keep = {};
        let room = root.maxSlots - 1;
        for (const open of [true, false]) {
            for (const i of root.items) {
                if (room > 0 && !keep[i.appId] && (root.windowsOf(i.appId).length > 0) === open) {
                    keep[i.appId] = true;
                    room--;
                }
            }
        }
        return {
            "shown": root.items.filter((i) => {
                return keep[i.appId];
            }),
            "rest": root.items.filter((i) => {
                return !keep[i.appId];
            })
        };
    }
    // the panel shows the apps that did not fit, rather than one app
    property bool overflowOpen: false
    readonly property var chosenItem: root.items.find((i) => {
        return i.appId === root.chosen;
    }) || null
    readonly property var chosenWindows: root.windowsOf(root.chosen)
    // the window previews in the panel, as the dock's are, up to three to a row
    readonly property int cardW: Theme.dp(172)
    readonly property int cardH: Theme.dp(106)
    readonly property int cardColumns: Math.max(1, Math.min(3, root.chosenWindows.length))

    // an icon dragged along the bar, as on the dock: a pin to another pin's
    // place, an open app in among the pins to pin it, a pin pulled off to unpin
    property string dragApp: ""
    property bool settling: false
    readonly property var noApp: ({
        "appId": "",
        "name": "",
        "icon": "",
        "command": "",
        "pinned": false
    })
    property Item dragCell: null
    property real dragDx: 0
    property real dragDy: 0
    readonly property int dragFrom: root.dragApp === "" ? -1 : root.placed.shown.findIndex((i) => {
        return i.appId === root.dragApp;
    })
    readonly property var dragItem: root.dragFrom >= 0 ? root.placed.shown[root.dragFrom] : null
    readonly property int pinsShown: root.placed.shown.filter((i) => {
        return i.pinned;
    }).length
    readonly property bool pulling: !!root.dragItem && root.dragItem.pinned && Math.abs(root.dragDy) > root.compactHeight
    readonly property int dragTo: {
        if (!root.dragItem || root.pulling)
            return root.dragFrom;

        const t = Math.max(0, Math.min(root.placed.shown.length - 1, Math.round(root.dragFrom + root.dragDx / root.slot)));
        if (root.dragItem.pinned)
            return Math.min(t, root.pinsShown - 1);

        return t < root.dragFrom && t <= root.pinsShown ? t : root.dragFrom;
    }
    // where the dragged icon is, in the overlay, through whatever the bar does to its items
    readonly property point dragAt: root.dragCell && root.dragFrom >= 0 ? (root.dragDx, root.dragDy, tipLayer.width, tipLayer.height, tipLayer.mapFromItem(root.dragCell, root.dragCell.width / 2 + root.dragDx, root.dragCell.height / 2 + root.dragDy)) : Qt.point(0, 0)

    // how far a cell slides to open the dragged icon's new place, or close its old one
    function shiftOf(index) {
        const from = root.dragFrom;
        const to = root.dragTo;
        if (from < 0 || index === from)
            return 0;

        if (root.pulling)
            return index > from ? -root.slot : 0;

        if (from < to && index > from && index <= to)
            return -root.slot;

        if (to < from && index >= to && index < from)
            return root.slot;

        return 0;
    }

    function pinIndex(appId) {
        const pins = root.dockMod ? (root.dockMod.pinnedList || []) : [];
        const id = String(appId).toLowerCase();
        return pins.findIndex((p) => {
            return String(p.appId || p.appKey || "").toLowerCase() === id;
        });
    }

    function drop() {
        const shown = root.placed.shown;
        const from = root.dragFrom;
        const to = root.dragTo;
        const item = root.dragItem;
        const pulled = root.pulling;
        root.settling = true;
        root.dragApp = "";
        root.dragCell = null;
        Qt.callLater(() => {
            root.settling = false;
        });
        if (!item || !root.dockMod)
            return ;

        if (pulled)
            root.dockMod.unpinApp(item.appId);
        else if (to === from)
            return ;
        else if (item.pinned)
            root.dockMod.movePinned(item.appId, root.pinIndex(shown[to].appId));
        else
            root.dockMod.pinRunningApp(item.appId, to < root.pinsShown ? root.pinIndex(shown[to].appId) : (root.pinsShown > 0 ? root.pinIndex(shown[root.pinsShown - 1].appId) + 1 : 0));
    }

    // the wheel on an icon goes through that app's windows, as on the dock. the
    // place is kept, as a focus that goes through hyprctl lands after the next notch
    property string cycleApp: ""
    property int cycleAt: -1

    function cycle(appId, delta) {
        const wins = root.windowsOf(appId);
        if (wins.length < 2)
            return ;

        let from = root.cycleApp === appId ? root.cycleAt : -1;
        if (from < 0 || from >= wins.length)
            from = wins.indexOf(Hyprland.activeToplevel);

        const next = ((from + delta) % wins.length + wins.length) % wins.length;
        root.cycleApp = appId;
        root.cycleAt = next;
        root.cycleTarget = wins[next];
        root.focusNow(root.addressOf(wins[next]));
    }

    property var cycleTarget: null

    Connections {
        function onActiveToplevelChanged() {
            if (Hyprland.activeToplevel !== root.cycleTarget)
                root.cycleApp = "";

        }

        target: Hyprland
    }

    function workspaceLabel(t) {
        const ws = t && t.workspace;
        if (!ws)
            return "";

        const name = String(ws.name || "");
        if (name.indexOf("special:") !== 0)
            return "Workspace " + ws.id;

        const s = name.slice(8);
        return s === "" || s === "special" ? "Scratchpad" : "Scratchpad · " + s;
    }

    // the dock's icon for the app, or a plain one for an app with none
    function iconOf(name) {
        const found = root.dockMod ? root.dockMod.iconFor(name) : "";
        return found !== "" ? found : Quickshell.iconPath("application-x-executable", true);
    }

    function classOf(t) {
        const o = t.lastIpcObject || {};
        return String((t.wayland && t.wayland.appId) || o.class || "");
    }

    function addressOf(t) {
        const a = String(t.address || "");
        return a === "" || a.indexOf("0x") === 0 ? a : "0x" + a;
    }

    function windowsOf(appId) {
        const id = String(appId).toLowerCase();
        return root.windows.filter((t) => {
            return root.classOf(t).toLowerCase() === id;
        });
    }

    function closeAll(appId) {
        for (const t of root.windowsOf(appId))
            Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + root.addressOf(t) + "\" })");

    }

    function launch(item) {
        if (item && item.command !== "")
            Quickshell.execDetached(["sh", "-c", item.command]);

    }

    // a focus warps the pointer onto the window when warps are on; from the bar
    // the pointer stays where it is, warps going off for that one dispatch
    function focusNow(address) {
        const focus = "hl.dsp.focus({ window = \"address:" + address + "\" })";
        if (HyprConfig.bool("cursor.no_warps", false))
            Hyprland.dispatch(focus);
        else
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ cursor = { no_warps = true } }) hl.dispatch(" + focus + ") hl.config({ cursor = { no_warps = false } })"]);
    }

    // with no window it opens, with one here it comes up; with more, or one on
    // another workspace, the panel shows them, as the dock does
    function activate(item) {
        const wins = root.windowsOf(item.appId);
        const here = Hyprland.focusedWorkspace;
        if (wins.length === 0)
            root.launch(item);
        else if (wins.length === 1 && (!wins[0].workspace || !here || wins[0].workspace.id === here.id))
            root.focusNow(root.addressOf(wins[0]));
        else
            root.openFor(item);
    }

    function openFor(item) {
        root.overflowOpen = false;
        root.chosen = item.appId;
        root.expanded = true;
    }

    function openOverflow() {
        root.overflowOpen = true;
        root.expanded = true;
    }

    // an app picked from the ones that did not fit: as a click on its icon would,
    // through the panel's grab
    function choose(item) {
        const wins = root.windowsOf(item.appId);
        if (wins.length > 1) {
            root.openFor(item);
        } else if (wins.length === 1) {
            root.pick(root.addressOf(wins[0]));
        } else {
            root.launch(item);
            root.expanded = false;
        }
    }

    // the panel's focus grab hands the focus back as it lets go, so a pick
    // waits for that to be over, as the active window module's does
    function pick(address) {
        root.expanded = false;
        focusLater.address = address;
        focusLater.restart();
    }

    // the icon the pointer rests on, for its tooltip; it shows after a beat
    property Item tipCell: null
    property bool tipShown: false
    property bool tipAbove: false
    // where the tip goes in the overlay: off the side of the icon away from the
    // screen edge the bar is on, mapped through whatever the bar does to its
    // items, and again once the overlay has grown to take it
    readonly property point tipAt: root.tipCell && root.tipShown ? (tipLayer.width, tipLayer.height, tipLayer.mapFromItem(root.tipCell, root.tipCell.width / 2, root.tipAbove ? -Theme.dp(8) : root.tipCell.height + Theme.dp(8))) : Qt.point(0, 0)

    function hover(cell) {
        root.tipCell = cell;
        root.tipShown = false;
        if (cell)
            tipDelay.restart();
        else
            tipDelay.stop();
    }

    Timer {
        id: tipDelay

        interval: 500
        onTriggered: {
            if (!root.tipCell)
                return ;

            const g = root.tipCell.mapToGlobal(0, 0);
            const screenH = root.hostWindow && root.hostWindow.screen ? root.hostWindow.screen.height : 0;
            root.tipAbove = g.y > screenH / 2;
            root.tipShown = true;
        }
    }

    Timer {
        id: focusLater

        property string address: ""

        interval: 80
        onTriggered: root.focusNow(focusLater.address)
    }

    opensOnHover: false
    compactInteractive: false
    readonly property bool tipOpen: Prefs.dockShowTooltips && root.tipShown && !!root.tipCell && !root.expanded
    overlayOpen: root.tipOpen || root.dragFrom >= 0
    // the tooltip takes no input, so it adds no region
    readonly property var overlayRects: []
    compactHovered: faceArea.containsMouse
    shown: Prefs.showApps && root.dockMod !== null && root.items.length > 0
    compactWidth: (root.placed.shown.length + (root.placed.rest.length > 0 ? 1 : 0)) * root.slot + root.horizontalPadding * 2
    panelWidth: root.overflowOpen ? Theme.dp(360) : Math.max(Theme.dp(360), root.cardColumns * root.cardW + (root.cardColumns - 1) * Theme.dp(12) + Theme.dp(36))
    panelHeight: (root.overflowOpen ? overflowGrid.implicitHeight : panelColumn.implicitHeight) + Theme.dp(36)
    expandedRadius: Theme.shapeXl
    onExpandedChanged: {
        if (root.expanded)
            Hyprland.refreshToplevels();

    }

    component ActionButton: Rectangle {
        id: button

        property string label: ""
        property bool danger: false

        signal clicked()

        width: buttonLabel.implicitWidth + Theme.dp(28)
        height: Theme.dp(36)
        radius: Theme.dp(18)
        color: {
            if (button.danger)
                return buttonArea.containsMouse ? Theme.error : Theme.errorContainer;

            return buttonArea.containsMouse ? Theme.alpha(Theme.secondaryContainer, 0.8) : Theme.secondaryContainer;
        }

        Text {
            id: buttonLabel

            anchors.centerIn: parent
            text: button.label
            color: button.danger ? (buttonArea.containsMouse ? Theme.fgError : Theme.fgErrorContainer) : Theme.fgSecondaryContainer
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.weight: Font.Medium
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

    }

    compactContent: [
        // a right click off the icons opens the module's card, as on every module
        MouseArea {
            id: faceArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.RightButton
            onClicked: Prefs.openBarModule("apps")
        },
        Row {
            anchors.centerIn: parent

            // by count, the app read from the list: the list is rebuilt on every
            // focus change, and a list for a model would rebuild the icons with
            // it, the one held in a drag too
            Repeater {
                model: root.placed.shown.length

                Item {
                    id: cell

                    required property int index
                    readonly property var app: root.placed.shown[cell.index] || root.noApp
                    readonly property var wins: root.windowsOf(cell.app.appId)
                    readonly property bool focused: cell.wins.indexOf(Hyprland.activeToplevel) >= 0
                    readonly property bool held: root.dragFrom === cell.index

                    width: root.slot
                    height: root.compactHeight
                    // the held icon is drawn in the overlay, where it can leave the bar
                    opacity: cell.held ? 0 : 1

                    transform: Translate {
                        x: root.shiftOf(cell.index)

                        // a drop puts each app in its cell at once, so the slide stops there
                        Behavior on x {
                            enabled: !root.settling

                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Rectangle {
                        visible: Prefs.dockIconTiles
                        anchors.centerIn: parent
                        width: root.slot - Theme.dp(4)
                        height: root.compactHeight - Theme.dp(8)
                        radius: Theme.radiusMd
                        color: Theme.withBlur(Theme.bgTile)
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.slot - Theme.dp(4)
                        height: root.compactHeight - Theme.dp(8)
                        radius: Theme.radiusMd
                        color: Theme.alpha(Theme.text, cellArea.containsMouse ? 0.1 : (cell.focused ? 0.06 : 0))

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    Image {
                        anchors.centerIn: parent
                        width: root.glyph
                        height: root.glyph
                        sourceSize.width: root.glyph * 2
                        sourceSize.height: root.glyph * 2
                        source: root.iconOf(cell.app.icon)
                        asynchronous: true
                        smooth: true
                    }

                    // open windows: a dot, stretched into a bar for the focused one
                    Rectangle {
                        visible: Prefs.dockShowIndicators && cell.wins.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.dp(3)
                        width: cell.focused ? Theme.dp(12) : Theme.dp(4)
                        height: Theme.dp(3)
                        radius: height / 2
                        color: cell.focused ? Theme.accent : Theme.alpha(Theme.text, 0.6)

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    MouseArea {
                        id: cellArea

                        property real pressX: 0
                        property real pressY: 0
                        // a drag ends on a release, and the click that comes with it is no click
                        property bool dragged: false

                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: cell.held ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        onEntered: root.hover(cell)
                        onExited: {
                            if (root.tipCell === cell)
                                root.hover(null);

                        }
                        onPressed: (mouse) => {
                            cellArea.pressX = mouse.x;
                            cellArea.pressY = mouse.y;
                            cellArea.dragged = false;
                        }
                        onPositionChanged: (mouse) => {
                            if (!(cellArea.pressedButtons & Qt.LeftButton))
                                return ;

                            const dx = mouse.x - cellArea.pressX;
                            const dy = mouse.y - cellArea.pressY;
                            if (!cell.held && Math.hypot(dx, dy) > Theme.dp(6)) {
                                root.hover(null);
                                root.dragCell = cell;
                                root.dragApp = cell.app.appId;
                                cellArea.dragged = true;
                            }
                            if (cell.held) {
                                root.dragDx = dx;
                                root.dragDy = dy;
                            }
                        }
                        onReleased: {
                            if (cellArea.dragged)
                                root.drop();

                        }
                        onCanceled: {
                            if (cellArea.dragged) {
                                root.dragApp = "";
                                root.dragCell = null;
                            }
                        }
                        onWheel: (wheel) => {
                            if (cell.wins.length < 2) {
                                wheel.accepted = false;
                                return ;
                            }
                            root.hover(null);
                            root.cycle(cell.app.appId, wheel.angleDelta.y > 0 ? -1 : 1);
                        }
                        onClicked: (mouse) => {
                            if (cellArea.dragged)
                                return ;

                            root.hover(null);
                            if (mouse.button === Qt.RightButton)
                                root.openFor(cell.app);
                            else if (mouse.button === Qt.MiddleButton)
                                root.launch(cell.app);
                            else
                                root.activate(cell.app);
                        }
                    }

                }

            }

            Item {
                visible: root.placed.rest.length > 0
                width: root.slot
                height: root.compactHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: root.slot - Theme.dp(4)
                    height: root.compactHeight - Theme.dp(8)
                    radius: Theme.radiusMd
                    color: Theme.alpha(Theme.text, moreArea.containsMouse ? 0.1 : 0)
                }

                Text {
                    anchors.centerIn: parent
                    text: "+" + root.placed.rest.length
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: moreArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.hover(null);
                        root.openOverflow();
                    }
                }

            }

        }
    ]

    overlayContent: [
        Item {
            id: tipLayer

            anchors.fill: parent

            // the held icon, following the pointer; pulled off the bar it shrinks
            // and fades, as a pin pulled off the dock does
            Image {
                visible: root.dragFrom >= 0
                x: Math.round(root.dragAt.x - width / 2)
                y: Math.round(root.dragAt.y - height / 2)
                width: root.glyph
                height: root.glyph
                sourceSize.width: root.glyph * 2
                sourceSize.height: root.glyph * 2
                source: root.dragItem ? root.iconOf(root.dragItem.icon) : ""
                smooth: true
                scale: root.pulling ? 0.7 : 1.12
                opacity: root.pulling ? 0.35 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            Rectangle {
                id: tip

                readonly property var item: root.tipCell ? root.tipCell.app : null
                readonly property int count: root.tipCell ? root.tipCell.wins.length : 0

                // kept on screen, as the tray's menu is
                x: Math.round(Math.max(Theme.dp(6) - root.x, Math.min(root.tipAt.x - width / 2, (root.hostWindow ? root.hostWindow.width : tipLayer.width) - root.x - width - Theme.dp(6))))
                y: Math.round(root.tipAbove ? root.tipAt.y - height : root.tipAt.y)
                width: Math.max(tipName.implicitWidth, tipDetail.implicitWidth) + Theme.dp(20)
                height: tipColumn.implicitHeight + Theme.dp(12)
                radius: Theme.radiusXs
                color: Theme.bgHigh
                opacity: root.tipOpen ? 1 : 0
                visible: opacity > 0.01

                Column {
                    id: tipColumn

                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        id: tipName

                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tip.item ? tip.item.name : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.variableAxes: Theme.axes(Theme.fontBody, 520, 0)
                        font.weight: Font.Medium
                    }

                    Text {
                        id: tipDetail

                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: text !== ""
                        text: tip.count > 1 ? tip.count + " windows" : (tip.count === 1 ? "1 window" : "")
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }
    ]

    panelContent: [
        // the apps that did not fit, to a grid
        Flow {
            id: overflowGrid

            visible: root.overflowOpen
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(18)
            spacing: Theme.dp(4)

            Repeater {
                model: root.overflowOpen ? root.placed.rest : []

                Rectangle {
                    id: gridCell

                    required property var modelData
                    readonly property int wins: root.windowsOf(gridCell.modelData.appId).length

                    width: Theme.dp(77)
                    height: Theme.dp(80)
                    radius: Theme.radiusMd
                    color: Theme.alpha(Theme.text, gridArea.containsMouse ? 0.08 : 0)

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Theme.dp(10)
                        width: Theme.dp(32)
                        height: Theme.dp(32)
                        sourceSize.width: Theme.dp(64)
                        sourceSize.height: Theme.dp(64)
                        source: root.iconOf(gridCell.modelData.icon)
                        asynchronous: true
                        smooth: true
                    }

                    Rectangle {
                        visible: Prefs.dockShowIndicators && gridCell.wins > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Theme.dp(46)
                        width: Theme.dp(4)
                        height: Theme.dp(3)
                        radius: height / 2
                        color: Theme.alpha(Theme.text, 0.6)
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Theme.dp(4)
                        y: Theme.dp(54)
                        horizontalAlignment: Text.AlignHCenter
                        text: gridCell.modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: gridArea

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton)
                                root.openFor(gridCell.modelData);
                            else if (mouse.button === Qt.MiddleButton)
                                root.launch(gridCell.modelData);
                            else
                                root.choose(gridCell.modelData);
                        }
                    }

                }

            }

        },
        Column {
            id: panelColumn

            visible: !root.overflowOpen
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(18)
            spacing: Theme.dp(12)

            Row {
                width: parent.width
                spacing: Theme.dp(14)

                Rectangle {
                    width: Theme.dp(48)
                    height: Theme.dp(48)
                    radius: Theme.radiusMd
                    color: Theme.accentContainer

                    Image {
                        anchors.centerIn: parent
                        width: Theme.dp(30)
                        height: Theme.dp(30)
                        sourceSize.width: Theme.dp(60)
                        sourceSize.height: Theme.dp(60)
                        source: root.chosenItem ? root.iconOf(root.chosenItem.icon) : ""
                        asynchronous: true
                        smooth: true
                    }

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.dp(62)
                    spacing: Theme.dp(2)

                    Text {
                        width: parent.width
                        text: root.chosenItem ? root.chosenItem.name : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitleMd
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.chosenWindows.length === 0 ? "Not open" : (root.chosenWindows.length === 1 ? "1 window" : root.chosenWindows.length + " windows")
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                    }

                }

            }

            // a live preview to a window, as on the dock, with its title and
            // workspace under it; a click brings it up
            Flow {
                visible: root.chosenWindows.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.cardColumns * root.cardW + (root.cardColumns - 1) * spacing
                spacing: Theme.dp(12)

                Repeater {
                    model: root.expanded ? root.chosenWindows.length : 0

                    Item {
                        id: card

                        required property int index
                        readonly property var win: root.chosenWindows[card.index] || null
                        readonly property bool focused: !!card.win && card.win === Hyprland.activeToplevel
                        readonly property bool hovered: cardArea.containsMouse

                        width: root.cardW
                        height: root.cardH + Theme.dp(40)

                        ClippingRectangle {
                            id: shot

                            width: root.cardW
                            height: root.cardH
                            radius: Theme.radiusLg
                            color: Theme.bgTile
                            scale: card.hovered ? 1.03 : 1

                            ScreencopyView {
                                id: preview

                                anchors.centerIn: parent
                                constraintSize.width: shot.width
                                constraintSize.height: shot.height
                                captureSource: card.win ? card.win.wayland : null
                                live: root.expanded
                                visible: preview.hasContent

                                transform: Scale {
                                    id: cover

                                    origin.x: preview.width / 2
                                    origin.y: preview.height / 2
                                    xScale: preview.width > 0 && preview.height > 0 ? Math.max(shot.width / preview.width, shot.height / preview.height) : 1
                                    yScale: cover.xScale
                                }

                            }

                            Image {
                                visible: !preview.hasContent
                                anchors.centerIn: parent
                                width: Theme.dp(40)
                                height: Theme.dp(40)
                                sourceSize.width: Theme.dp(80)
                                sourceSize.height: Theme.dp(80)
                                source: root.chosenItem ? root.iconOf(root.chosenItem.icon) : ""
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.text
                                opacity: card.hovered ? Theme.stateHover : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.durQuick
                                    }

                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.durShort
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        // the accent ring on the hovered one, a faint one on the focused one
                        Rectangle {
                            anchors.fill: shot
                            radius: shot.radius
                            scale: shot.scale
                            color: "transparent"
                            border.color: Theme.accent
                            border.width: 2
                            opacity: card.hovered ? 1 : (card.focused ? 0.45 : 0)
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        Column {
                            anchors.top: shot.bottom
                            anchors.topMargin: Theme.dp(7)
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 1

                            Text {
                                width: parent.width
                                text: (card.win && card.win.title) || root.chosen
                                color: card.hovered || card.focused ? Theme.text : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.variableAxes: Theme.axes(Theme.fontLabel, 520, 0)
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                width: parent.width
                                text: root.workspaceLabel(card.win)
                                color: Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                                horizontalAlignment: Text.AlignHCenter
                            }

                        }

                        MouseArea {
                            id: cardArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (card.win)
                                    root.pick(root.addressOf(card.win));

                            }
                        }

                    }

                }

            }

            Flow {
                width: parent.width
                spacing: Theme.dp(8)

                ActionButton {
                    visible: !!root.chosenItem && root.chosenItem.command !== ""
                    label: root.chosenWindows.length === 0 ? "Open" : "New window"
                    onClicked: {
                        root.launch(root.chosenItem);
                        root.expanded = false;
                    }
                }

                ActionButton {
                    visible: !!root.chosenItem
                    label: root.chosenItem && root.chosenItem.pinned ? "Unpin" : "Pin"
                    onClicked: {
                        if (root.chosenItem.pinned)
                            root.dockMod.unpinApp(root.chosen);
                        else
                            root.dockMod.pinRunningApp(root.chosen);
                        root.expanded = false;
                    }
                }

                ActionButton {
                    visible: root.chosenWindows.length > 0
                    danger: true
                    label: root.chosenWindows.length > 1 ? "Close all" : "Close"
                    onClicked: {
                        root.closeAll(root.chosen);
                        root.expanded = false;
                    }
                }

            }

        }
    ]
}
