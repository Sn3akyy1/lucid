import QtQuick
import qs
import qs.lucidui
import qs.lucidicons

// what a tab shows: its items as a grid or a list, with rubber-band selection,
// the keyboard, drops onto the folder itself, and the empty and busy states
FocusScope {
    id: pane

    required property var app
    required property var win
    property var tab: null
    readonly property bool grid: pane.app.prefs.view === "grid"
    // zooming eases between sizes, the grid reflowing as it grows
    property real iconSize: Theme.dp(pane.app.prefs.iconSize)
    // a folder just opened: its items cascade in, each a beat after the last
    property bool cascading: false
    // when its first cell was made: every arrival keeps to one clock from there
    property real cascadeAt: 0
    // the model was just emptied for a new folder or search: the views apply that
    // a frame later, so leaving items go without animating for a moment after
    property bool quiet: false
    // how much wider (or narrower) the pane is about to be, the sidebar still
    // sliding: the grid's columns are counted for the width it ends at
    property real widthDelta: 0
    readonly property bool legacy: pane.app.legacyIcons
    readonly property bool keyboardFocus: pane.activeFocus
    readonly property real colSize: Theme.dp(92)
    readonly property real colDate: Theme.dp(150)
    readonly property real colType: Math.min(Theme.dp(220), Math.max(Theme.dp(120), pane.width * 0.2))
    readonly property var view: pane.grid ? gridView : listView
    readonly property int columns: Math.max(1, Math.floor(gridView.width / Math.max(1, gridView.cellWidth)))
    // a rubber band, in the view's content coordinates
    property bool banding: false
    property point bandFrom
    property point bandTo
    property bool bandAdd: false
    // a touchpad's pace: hyprland scales its deltas down (scroll_factor), and a
    // file view wants to cover ground. padSpeed is px per ms, smoothed
    readonly property real padGain: 2.4
    property real padSpeed: 0
    property real padAt: 0

    function takeFocus() {
        // every press comes through here, so it also catches a coasting view
        coast.stop();
        pane.forceActiveFocus();
    }

    // fingers off the touchpad: the view glides on at their speed, slowing at a
    // steady rate, like gtk's and chromium's own kinetic scrolling
    function coastOn() {
        var speed = pane.padSpeed;
        if (Theme.motionScale <= 0 || Date.now() - pane.padAt > 90 || Math.abs(speed) < 0.12)
            return ;

        var v = pane.view;
        var maxY = Math.max(0, v.contentHeight - v.height);
        var slow = 0.0025;
        var to = Math.max(0, Math.min(maxY, v.contentY - speed * Math.abs(speed) / (2 * slow)));
        if (Math.abs(to - v.contentY) < 1)
            return ;

        // an ease-out quad starts at twice its mean pace: that is the fingers' speed
        coast.from = v.contentY;
        coast.to = to;
        coast.duration = Math.max(120, 2 * Math.abs(to - v.contentY) / Math.abs(speed));
        coast.restart();
    }

    // how many beats item i waits to arrive in the cascade, counted from its start
    function beatsFor(i) {
        var beat = Math.round(16 * Theme.motionScale);
        if (!pane.cascading || beat <= 0)
            return 0;

        if (pane.cascadeAt === 0)
            pane.cascadeAt = Date.now();

        return Math.max(0, Math.min(i, 24) - Math.floor((Date.now() - pane.cascadeAt) / beat));
    }

    // into a folder the view comes from the right, back out of one from the left
    function pushFrom(dir) {
        pushAnim.stop();
        push.x = dir * Theme.dp(44);
        pushAnim.restart();
        pane.cascading = true;
        pane.cascadeAt = 0;
        settle.restart();
    }

    // how things come and go in either view: a folder's items cascade in, a new
    // file rises into place, a trashed one shrinks away, the rest glide to fill.
    // they animate the delegates' own enter and pop, never opacity or scale,
    // which the delegates bind for hidden and cut files
    component Arrive: Transition {
        id: arrive

        SequentialAnimation {
            PropertyAction {
                property: "enter"
                value: 0
            }

            PropertyAction {
                property: "pop"
                value: 0.86
            }

            PauseAnimation {
                duration: pane.cascading ? Math.min(arrive.ViewTransition.index, 24) * Math.round(16 * Theme.motionScale) : 0
            }

            ParallelAnimation {
                NumberAnimation {
                    property: "enter"
                    to: 1
                    duration: Theme.durShort
                }

                NumberAnimation {
                    property: "pop"
                    to: 1
                    duration: Theme.durFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

        }

    }

    component Leave: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "enter"
                to: 0
                duration: Theme.durShort
            }

            NumberAnimation {
                property: "pop"
                to: 0.8
                duration: Theme.durShort
                easing.type: Easing.InCubic
            }

        }

    }

    component Glide: Transition {
        NumberAnimation {
            properties: "x,y"
            duration: Theme.durDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

        // pushed aside while still arriving, an item's arrival stops where it
        // is and never resets: it stayed invisible, a hole in the grid
        NumberAnimation {
            properties: "enter,pop"
            to: 1
            duration: Theme.durShort
        }

    }

    onGridChanged: {
        // the other view rises into place
        switchAnim.stop();
        shift.y = Theme.dp(14);
        pane.shownFade = 0;
        switchAnim.restart();
    }

    property real shownFade: 1

    Behavior on iconSize {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveStandard
        }

    }

    Translate {
        id: push
    }

    Translate {
        id: shift
    }

    NumberAnimation {
        id: pushAnim

        target: push
        property: "x"
        to: 0
        duration: Theme.durDefaultSpatial
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveDefaultSpatial
    }

    ParallelAnimation {
        id: switchAnim

        NumberAnimation {
            target: shift
            property: "y"
            to: 0
            duration: Theme.durFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveFastSpatial
        }

        NumberAnimation {
            target: pane
            property: "shownFade"
            to: 1
            duration: Theme.durShort
        }

    }

    Timer {
        id: settle

        interval: 900
        onTriggered: pane.cascading = false
    }

    Timer {
        id: quietLater

        interval: 150
        onTriggered: pane.quiet = false
    }

    Connections {
        function onClearingChanged() {
            if (pane.tab.clearing) {
                pane.quiet = true;
                quietLater.restart();
            }
        }

        function onNavigated() {
            pane.pushFrom(pane.tab.lastMove);
        }

        function onSearchingChanged() {
            if (pane.tab.searching)
                pane.pushFrom(1);

        }

        target: pane.tab
    }

    function isCut(uri) {
        return pane.win.cutRev >= 0 && pane.win.cutSet[uri] === true;
    }

    // a drag of files picked out here. it is the pane's, not the cell's it starts
    // from: a folder or a tab sprung open under the pointer swaps the view's cells
    // out, and a drag a cell owned died with it, its drop never landing
    readonly property bool dragging: dragProxy.Drag.active
    readonly property Item dragSource: dragProxy
    property string dragList: ""
    property url dragImage

    function startDrag(uris, image) {
        if (dragProxy.Drag.active)
            return ;

        pane.dragList = uris;
        pane.dragImage = image;
        pane.app.dragImage = image;
        // from the event loop, not inside the cell's own handler: a drag runs a
        // loop of its own until the drop, and the cell may be gone before then
        Qt.callLater(function() {
            dragProxy.Drag.active = true;
        });
    }

    // what leaves lumen, dragged or copied: a share's file by its folder path,
    // which any app can open, rather than its sftp:// or smb:// address
    function outUri(it) {
        return it.path ? pane.app.uriOf(it.path) : it.uri;
    }

    function dragUris(uri) {
        if (!pane.tab || pane.tab.rev < 0)
            return uri;

        if (!pane.tab.isSelected(uri)) {
            var i = pane.tab.index[uri];
            return i !== undefined && i < pane.tab.model.count && pane.tab.model.get(i).uri === uri ? pane.outUri(pane.tab.model.get(i)) : uri;
        }
        return pane.tab.selectedItems().map(pane.outUri).join("\r\n");
    }

    function itemClicked(i, mouse, src) {
        var it = pane.tab.model.get(i);
        if (mouse.button === Qt.RightButton) {
            if (!pane.tab.isSelected(it.uri))
                pane.tab.selectOnly(i);

            var p = src.mapToItem(pane.win.contentRoot, mouse.x, mouse.y);
            pane.win.itemMenu(p.x, p.y);
            return ;
        }
        if (mouse.button === Qt.MiddleButton) {
            if (it.kind === "dir")
                pane.win.openIndex(i, true);

            return ;
        }
        if (mouse.modifiers & Qt.ControlModifier)
            pane.tab.toggle(i);
        else if (mouse.modifiers & Qt.ShiftModifier)
            pane.tab.selectRange(i, false);
        else {
            pane.tab.selectOnly(i);
            if (pane.app.prefs.singleClick)
                pane.itemActivated(i, false);

        }
    }

    function itemActivated(i, newTab) {
        pane.win.openIndex(i, newTab);
    }

    function dropInto(dest, drop) {
        var uris = [];
        for (var k = 0; k < drop.urls.length; k++) uris.push(drop.urls[k].toString())
        if (uris.length === 0 || !dest)
            return ;

        var mode = drop.proposedAction === Qt.CopyAction ? "copy" : drop.proposedAction === Qt.LinkAction ? "link" : "auto";
        drop.acceptProposedAction();
        if (mode === "link")
            pane.app.call("link", {
            "uris": uris,
            "dest": dest
        });
        else
            pane.app.transfer(mode, uris, dest);
    }

    function show(i) {
        if (i < 0)
            return ;

        pane.view.positionViewAtIndex(i, pane.grid ? GridView.Contain : ListView.Contain);
    }

    function moveCurrent(to, event) {
        var n = pane.tab.model.count;
        if (n === 0)
            return ;

        to = Math.max(0, Math.min(n - 1, to));
        if (event.modifiers & Qt.ShiftModifier)
            pane.tab.selectRange(to, false);
        else if (event.modifiers & Qt.ControlModifier)
            pane.tab.current = to;
        else
            pane.tab.selectOnly(to);
        pane.show(to);
    }

    function bandSelect() {
        var x0 = Math.min(pane.bandFrom.x, pane.bandTo.x), x1 = Math.max(pane.bandFrom.x, pane.bandTo.x);
        var y0 = Math.min(pane.bandFrom.y, pane.bandTo.y), y1 = Math.max(pane.bandFrom.y, pane.bandTo.y);
        var hits = [];
        var n = pane.tab.model.count;
        if (pane.grid) {
            var cw = gridView.cellWidth, ch = gridView.cellHeight, cols = pane.columns;
            var r0 = Math.max(0, Math.floor(y0 / ch)), r1 = Math.floor(y1 / ch);
            var c0 = Math.max(0, Math.floor(x0 / cw)), c1 = Math.min(cols - 1, Math.floor(x1 / cw));
            for (var r = r0; r <= r1; r++) {
                for (var c = c0; c <= c1; c++) {
                    var i = r * cols + c;
                    if (i < n)
                        hits.push(i);

                }
            }
        } else {
            var rh = Theme.dp(42);
            var a = Math.max(0, Math.floor(y0 / rh)), b = Math.min(n - 1, Math.floor(y1 / rh));
            for (var k = a; k <= b; k++) hits.push(k)
        }
        pane.tab.selectSet(hits, pane.bandAdd);
    }

    Keys.onPressed: (event) => {
        if (!pane.tab)
            return ;

        var ctrl = event.modifiers & Qt.ControlModifier, shift = event.modifiers & Qt.ShiftModifier;
        var alt = event.modifiers & Qt.AltModifier;
        var cur = pane.tab.current;
        var step = pane.grid ? pane.columns : 1;
        var page = Math.max(1, Math.floor(pane.view.height / (pane.grid ? gridView.cellHeight : Theme.dp(42)))) * step;
        switch (event.key) {
        case Qt.Key_Right:
            if (alt)
                return ;

            if (pane.grid)
                pane.moveCurrent(cur + 1, event);

            break;
        case Qt.Key_Left:
            if (alt)
                return ;

            if (pane.grid)
                pane.moveCurrent(Math.max(0, cur - 1), event);

            break;
        case Qt.Key_Down:
            pane.moveCurrent(cur < 0 ? 0 : cur + step, event);
            break;
        case Qt.Key_Up:
            if (alt) {
                pane.tab.goUp();
                break;
            }
            pane.moveCurrent(cur < 0 ? 0 : cur - step, event);
            break;
        case Qt.Key_Home:
            pane.moveCurrent(0, event);
            break;
        case Qt.Key_End:
            pane.moveCurrent(pane.tab.model.count - 1, event);
            break;
        case Qt.Key_PageDown:
            pane.moveCurrent(cur + page, event);
            break;
        case Qt.Key_PageUp:
            pane.moveCurrent(cur - page, event);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            pane.win.openSelection(ctrl !== 0);
            break;
        case Qt.Key_Backspace:
            pane.tab.goUp();
            break;
        case Qt.Key_Delete:
            if (shift)
                pane.win.deleteSelection();
            else
                pane.win.trashSelection();
            break;
        case Qt.Key_F2:
            pane.win.renameSelection();
            break;
        case Qt.Key_Escape:
            if (pane.tab.searching)
                pane.win.endSearch();
            else if (pane.tab.filter !== "")
                pane.win.clearFilter();
            else if (pane.win.choosing)
                pane.win.cancelChooser();
            else
                pane.tab.clearSelection();
            break;
        case Qt.Key_Menu:
            pane.win.keyMenu();
            break;
        default:
            if (ctrl && event.key === Qt.Key_A)
                pane.tab.selectAll();
            else if (ctrl && event.key === Qt.Key_C)
                pane.win.copySelection(false);
            else if (ctrl && event.key === Qt.Key_X)
                pane.win.copySelection(true);
            else if (ctrl && event.key === Qt.Key_V)
                pane.win.paste(pane.tab.path);
            else if (ctrl && shift && event.key === Qt.Key_N)
                pane.win.newFolder();
            else if (shift && event.key === Qt.Key_F10)
                pane.win.keyMenu();
            else if (event.text.length === 1 && event.text.charCodeAt(0) > 32 && event.text.charCodeAt(0) !== 127 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
                pane.win.startFilter(event.text);
            else
                return ;
            break;
        }
        event.accepted = true;
    }

    Item {
        id: dragProxy

        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.proposedAction: Qt.MoveAction
        Drag.imageSource: pane.dragImage
        Drag.mimeData: ({
            "text/uri-list": pane.dragList
        })
        // over, dropped or not: the drop has had the picture by now
        Drag.onActiveChanged: {
            if (!dragProxy.Drag.active)
                pane.app.dragImage = "";

        }
    }

    // a drop on the folder itself, under everything that takes drops of its own
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        enabled: pane.tab !== null && !pane.tab.isSpecial && pane.tab.writable && !pane.tab.searching
        onDropped: (drop) => {
            return pane.dropInto(pane.tab.path, drop);
        }
    }

    // empty space: clicks clear, a drag draws a band, a right click asks what to do here
    MouseArea {
        id: back

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            pane.takeFocus();
            if (mouse.button === Qt.RightButton)
                return ;

            pane.bandAdd = (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) !== 0;
            if (!pane.bandAdd)
                pane.tab.clearSelection();

            var v = pane.view;
            var p = back.mapToItem(v, mouse.x, mouse.y);
            pane.bandFrom = Qt.point(p.x, p.y + v.contentY);
            pane.bandTo = pane.bandFrom;
            pane.banding = true;
        }
        onPositionChanged: (mouse) => {
            if (!pane.banding)
                return ;

            var v = pane.view;
            var p = back.mapToItem(v, mouse.x, mouse.y);
            pane.bandTo = Qt.point(Math.max(0, Math.min(v.width, p.x)), Math.max(0, p.y + v.contentY));
            pane.bandSelect();
            edge.dy = p.y < Theme.dp(24) ? -1 : p.y > v.height - Theme.dp(24) ? 1 : 0;
        }
        onReleased: {
            pane.banding = false;
            edge.dy = 0;
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                pane.tab.clearSelection();
                var p = back.mapToItem(pane.win.contentRoot, mouse.x, mouse.y);
                pane.win.backgroundMenu(p.x, p.y);
            }
        }

        HeldPointer {
            held: pane.banding
            cursor: Qt.ArrowCursor
        }

    }

    // while a band touches the top or bottom edge, the view scrolls under it
    Timer {
        id: edge

        property int dy: 0

        interval: 16
        repeat: true
        running: edge.dy !== 0 && pane.banding
        onTriggered: {
            var v = pane.view;
            var maxY = Math.max(0, v.contentHeight - v.height);
            v.contentY = Math.max(0, Math.min(maxY, v.contentY + edge.dy * Theme.dp(14)));
            pane.bandTo = Qt.point(pane.bandTo.x, Math.max(0, pane.bandTo.y + edge.dy * Theme.dp(14)));
            pane.bandSelect();
        }
    }

    // a wheel notch moves two and a half rows; a touchpad follows the fingers
    // straight away, then coasts when they lift. only a touchpad's scroll has
    // phases: on wayland a wheel notch carries pixel deltas too (15 a notch)
    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                pane.win.zoom(event.angleDelta.y > 0 ? 1 : -1);
                return ;
            }
            var v = pane.view;
            var maxY = Math.max(0, v.contentHeight - v.height);
            if (event.phase !== Qt.NoScrollPhase) {
                glide.stop();
                coast.stop();
                var d = event.pixelDelta.y * pane.padGain;
                if (d !== 0) {
                    var now = Date.now();
                    var dt = Math.max(1, now - pane.padAt);
                    // a pause since the last event starts the speed afresh
                    pane.padSpeed = dt > 90 ? d / dt : pane.padSpeed * 0.6 + d / dt * 0.4;
                    pane.padAt = now;
                    v.contentY = Math.max(0, Math.min(maxY, v.contentY - d));
                }
                if (event.phase === Qt.ScrollEnd)
                    pane.coastOn();

                return ;
            }
            coast.stop();
            var step = Math.max(Theme.dp(320), pane.grid ? gridView.cellHeight * 2.5 : 0);
            glide.to = Math.max(0, Math.min(maxY, (glide.running ? glide.to : v.contentY) - event.angleDelta.y / 120 * step));
            glide.restart();
        }
    }

    NumberAnimation {
        id: coast

        target: pane.view
        property: "contentY"
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: glide

        target: pane.view
        property: "contentY"
        duration: Theme.durShort
        easing.type: Easing.OutCubic
    }

    GridView {
        id: gridView

        property var pane: pane

        anchors.fill: parent
        anchors.leftMargin: Theme.dp(10)
        anchors.rightMargin: Theme.dp(14)
        anchors.topMargin: Theme.dp(8)
        visible: pane.grid
        opacity: pane.grid ? pane.shownFade : 0
        transform: [push, shift]
        interactive: false
        clip: true
        model: pane.tab ? pane.tab.model : null
        // cells animate themselves: the view drops a resize for any cell mid-transition
        add: gridArrive
        remove: pane.quiet ? null : gridLeave
        cellWidth: {
            var min = Math.max(pane.iconSize + Theme.dp(44), pane.iconSize * 1.55);
            var cols = Math.max(1, Math.floor((width + pane.widthDelta) / min));
            return Math.floor(width / cols);
        }
        cellHeight: pane.iconSize + Theme.dp(62)
        // no reuse: a removed item still leaving would go back to the pool and
        // stay on screen as a ghost
        reuseItems: false
        cacheBuffer: Theme.dp(400)
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: {
            if (pane.tab && pane.grid)
                pane.tab.scrollY = contentY;

        }

        delegate: GridCell {
        }

        Transition {
            id: gridArrive

            ScriptAction {
                script: {
                    var it = gridArrive.ViewTransition.item;
                    if (it && it.arrive)
                        it.arrive(pane.beatsFor(gridArrive.ViewTransition.index));

                }
            }

        }

        Leave {
            id: gridLeave
        }

    }

    Item {
        id: listBox

        anchors.fill: parent
        visible: !pane.grid
        opacity: !pane.grid ? pane.shownFade : 0
        transform: [push, shift]

        // the columns, named and sortable
        Row {
            id: heads

            x: Theme.dp(22)
            width: listBox.width - Theme.dp(44)
            height: Theme.dp(36)
            spacing: Theme.dp(12)

            Repeater {
                model: [{
                    "key": "name",
                    "label": "Name",
                    "w": heads.width - pane.colSize - pane.colDate - pane.colType - 3 * heads.spacing
                }, {
                    "key": "size",
                    "label": "Size",
                    "w": pane.colSize
                }, {
                    "key": pane.tab && pane.tab.isTrash ? "deleted" : "modified",
                    "label": pane.tab && pane.tab.isTrash ? "Deleted" : "Modified",
                    "w": pane.colDate
                }, {
                    "key": "type",
                    "label": pane.tab && pane.tab.isTrash ? "From" : pane.tab && pane.tab.searching ? "Where" : "Type",
                    "w": pane.colType
                }]

                delegate: Item {
                    id: colHead

                    required property var modelData
                    // the folder's own sort, or the default it takes
                    readonly property var sort: pane.tab ? pane.app.sortOf(pane.tab.path) : null
                    readonly property bool on: colHead.sort !== null && colHead.sort.key === modelData.key

                    width: modelData.w
                    height: heads.height

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: modelData.key === "size" ? parent.right : undefined
                        spacing: Theme.dp(4)

                        LText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "labelMedium"
                            text: modelData.label
                            color: colHead.on ? Theme.accent : Theme.subtext
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: colHead.on
                            name: colHead.sort && colHead.sort.desc ? "arrow_downward" : "arrow_upward"
                            size: Theme.dp(14)
                            color: Theme.accent
                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.win.sortBy(modelData.key)
                    }

                }

            }

        }

        ListView {
            id: listView

            property var pane: pane

            anchors.fill: parent
            anchors.topMargin: heads.height
            anchors.rightMargin: Theme.dp(6)
            interactive: false
            clip: true
            model: pane.tab ? pane.tab.model : null
            add: listArrive
            remove: pane.quiet ? null : listLeave
            displaced: listGlide
            move: listGlide
            moveDisplaced: listGlide
            // no reuse, as in the grid: leaving items must leave
            reuseItems: false
            cacheBuffer: Theme.dp(600)
            boundsBehavior: Flickable.StopAtBounds
            onContentYChanged: {
                if (pane.tab && !pane.grid)
                    pane.tab.scrollY = contentY;

            }

            delegate: ListRow {
            }

            Arrive {
                id: listArrive
            }

            Leave {
                id: listLeave
            }

            Glide {
                id: listGlide
            }

        }

    }

    // the band itself
    Rectangle {
        visible: pane.banding && (Math.abs(pane.bandTo.x - pane.bandFrom.x) > 3 || Math.abs(pane.bandTo.y - pane.bandFrom.y) > 3)
        x: pane.view.x + Math.min(pane.bandFrom.x, pane.bandTo.x) + (pane.grid ? 0 : listBox.x)
        y: pane.view.y + Math.min(pane.bandFrom.y, pane.bandTo.y) - pane.view.contentY + (pane.grid ? 0 : heads.height)
        width: Math.abs(pane.bandTo.x - pane.bandFrom.x)
        height: Math.abs(pane.bandTo.y - pane.bandFrom.y)
        radius: Theme.dp(8)
        color: Theme.alpha(Theme.accent, 0.14)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.55)
    }

    // a slim thumb that shows where the view is and can be dragged
    Item {
        id: track

        readonly property var v: pane.view
        readonly property real frac: track.v.contentHeight > 0 ? Math.min(1, track.v.height / track.v.contentHeight) : 1

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: pane.grid ? Theme.dp(8) : heads.height
        anchors.bottomMargin: Theme.dp(6)
        width: Theme.dp(10)
        visible: track.frac < 0.999

        Rectangle {
            id: thumb

            x: Theme.dp(3)
            width: thumbArea.containsMouse || thumbArea.pressed ? Theme.dp(6) : Theme.dp(4)
            radius: width / 2
            height: Math.max(Theme.dp(36), track.height * track.frac)
            y: (track.height - thumb.height) * (track.v.contentHeight > track.v.height ? track.v.contentY / (track.v.contentHeight - track.v.height) : 0)
            color: Theme.alpha(Theme.text, thumbArea.pressed ? 0.5 : 0.28)

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        MouseArea {
            id: thumbArea

            property real grabY: 0

            anchors.fill: parent
            hoverEnabled: true
            onPressed: (mouse) => {
                thumbArea.grabY = mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height ? mouse.y - thumb.y : thumb.height / 2;
            }
            onPositionChanged: (mouse) => {
                if (!pressed)
                    return ;

                var span = Math.max(1, track.height - thumb.height);
                var f = Math.max(0, Math.min(1, (mouse.y - thumbArea.grabY) / span));
                track.v.contentY = f * Math.max(0, track.v.contentHeight - track.v.height);
            }

            HeldPointer {
                held: thumbArea.pressed
                cursor: thumbArea.cursorShape
            }

        }

    }

    // nothing to show, or not yet
    Column {
        anchors.centerIn: parent
        spacing: Theme.dp(14)
        visible: pane.tab !== null && pane.tab.model.count === 0 && !pane.tab.connecting && (!pane.tab.loading || pane.tab.error !== "")
        width: Math.min(parent.width - Theme.dp(40), Theme.dp(360))

        TonalIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            size: Theme.dp(88)
            slot: !pane.tab ? "folder-open" : pane.tab.locked ? "folder" : pane.tab.isTrash ? "trash" : pane.tab.searching ? "file" : pane.tab.connectUri !== "" ? "folder-remote" : pane.tab.isNetwork ? "network" : pane.tab.error !== "" ? "file" : "folder-open"
            opacity: 0.85
        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "titleMedium"
            text: !pane.tab ? "" : pane.tab.locked ? (pane.tab.lockedOwner !== "" ? "This folder belongs to " + pane.tab.lockedOwner : "You can't open this folder") : pane.tab.connectUri !== "" ? "This share isn't connected" : pane.tab.error !== "" ? "This folder can't be opened" : pane.tab.isNetwork ? "No computers found nearby" : pane.tab.searching ? "Nothing matches “" + pane.tab.searchQuery + "”" : pane.tab.filter !== "" ? "Nothing here matches “" + pane.tab.filter + "”" : pane.tab.isTrash ? "Trash is empty" : pane.tab.isRecent ? "No recent files" : "This folder is empty"
            color: Theme.text
            wrapMode: Text.Wrap
        }

        LText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "bodySmall"
            visible: text !== ""
            text: !pane.tab ? "" : pane.tab.error !== "" ? pane.tab.error : pane.tab.isNetwork ? (pane.app.canDiscover ? "Computers sharing folders show up here as they're found." : "Finding them needs gvfs-dnssd with Avahi running, or gvfs-wsdd for Windows computers.") : pane.tab.searching ? "Searched every folder below " + pane.app.titleFor(pane.tab.path) + "." : pane.tab.isSpecial || pane.tab.filter !== "" ? "" : "Drop files here, or right-click to make something."
            color: Theme.subtext
            wrapMode: Text.Wrap
        }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pane.tab !== null && pane.tab.connectUri !== ""
            variant: "tonal"
            icon: pane.tab && pane.tab.locked ? "lock_open" : "login"
            text: pane.tab && pane.tab.locked ? "Unlock" : "Connect"
            onClicked: pane.win.reconnect(pane.tab)
        }

    }

    LoadingIndicator {
        id: waiting

        anchors.centerIn: parent
        visible: pane.tab !== null && pane.tab.model.count === 0 && (pane.tab.connecting || (pane.tab.loading && pane.tab.error === ""))
        running: visible
    }

    LText {
        anchors.top: waiting.bottom
        anchors.topMargin: Theme.dp(16)
        anchors.horizontalCenter: parent.horizontalCenter
        visible: waiting.visible && pane.tab.connecting
        role: "bodyMedium"
        text: !pane.tab ? "" : pane.tab.locked ? "Waiting for the password…" : "Connecting to " + pane.app.hostOf(pane.tab.connectUri || pane.tab.path) + "…"
        color: Theme.subtext
    }

}
