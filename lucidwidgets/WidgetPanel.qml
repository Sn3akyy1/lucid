import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.lucidprefs as LP
import qs.lucidui

// the widget panel: every widget to drag out or click in, the cards already out
// there, and the layouts. drawn on the widget layer, so a drop lands on its board
Item {
    id: wp

    property Item board: null

    readonly property bool open: wp.board !== null && wp.board.panelUp === true
    readonly property bool shown: wp.open || wp.reveal > 0.01
    // eases 0..1 as the sheet slides in
    property real reveal: wp.open ? 1 : 0
    // "add" | "placed" | "layouts"
    property string tab: "add"
    readonly property var tabs: [{
        "key": "add",
        "label": "Add",
        "icon": "add"
    }, {
        "key": "placed",
        "label": "On desktop",
        "icon": "desktop_windows"
    }, {
        "key": "layouts",
        "label": "Layouts",
        "icon": "dashboard"
    }]
    readonly property int tabIndex: Math.max(0, ["add", "placed", "layouts"].indexOf(wp.tab))
    // a catalogue type id, or "all"
    property string category: "all"
    // the search, lowercased and trimmed, a beat behind the field
    property string query: ""
    // the layouts tab draws a thumbnail per preset, so it is only built once visited
    property bool layoutsWanted: false
    // remove-all asks twice
    property bool clearArmed: false
    // bumped on every change to the cards, for anything that reads across the whole list
    property int cardsRev: 0

    readonly property real edge: Theme.dp(12)
    readonly property real pad: Theme.dp(20)
    readonly property int wheelStep: 190
    readonly property real sheetW: Math.min(Theme.dp(452), wp.width - wp.edge * 2)
    readonly property real sheetH: Math.max(0, wp.height - wp.edge * 2)
    readonly property real innerW: wp.sheetW - wp.pad * 2
    readonly property real tileW: Math.floor((wp.innerW - Theme.dp(10)) / 2)
    // a card on another screen than the main one remembers which
    readonly property string spawnScreen: (wp.board && !wp.board.isPrimary) ? wp.board.screenName : ""
    readonly property var shownTypes: {
        var q = wp.query;
        var out = [];
        for (var i = 0; i < Widgets.catalogue.length; i++) {
            var t = Widgets.catalogue[i];
            if (wp.category !== "all" && t.id !== wp.category)
                continue;

            var vs = q === "" ? t.variants : t.variants.filter((v) => {
                return wp.matches(t, v, q);
            });
            if (vs.length > 0)
                out.push({
                "id": t.id,
                "name": t.name,
                "blurb": t.blurb,
                "variants": vs
            });

        }
        return out;
    }
    // the first and last rows the list is showing, for its rounded ends
    readonly property var placedEnds: {
        var _ = wp.cardsRev + wp.query.length;
        var first = "";
        var last = "";
        for (var i = 0; i < Widgets.model.count; i++) {
            var e = Widgets.model.get(i);
            if (e.closing || !wp.cardMatches(e.wtype, e.wvariant))
                continue;

            if (first === "")
                first = e.uid;

            last = e.uid;
        }
        return ({
            "first": first,
            "last": last
        });
    }
    readonly property int liveCards: {
        var _ = wp.cardsRev;
        var n = 0;
        for (var i = 0; i < Widgets.model.count; i++) {
            if (!Widgets.model.get(i).closing)
                n++;

        }
        return n;
    }

    // the words people search for that the catalogue's own names and blurbs never use
    readonly property var keywords: ({
        "clock": "time watch hours",
        "calendar": "date month week day agenda reminders",
        "system": "cpu ram memory disk processor usage performance monitor",
        "thermal": "temperature heat gpu fan cooling",
        "network": "internet wifi ethernet speed download upload bandwidth",
        "battery": "power charge laptop",
        "media": "music song player spotify mpris audio album",
        "visualiser": "visualizer audio music sound cava spectrum bars",
        "games": "steam play gaming library",
        "weather": "forecast temperature rain sun",
        "notes": "sticky memo text note write",
        "todo": "tasks checklist list reminders",
        "palette": "colours colors theme swatches material",
        "kdeconnect": "phone android mobile kde connect",
        "timer": "pomodoro stopwatch countdown alarm focus",
        "glance": "summary date weather next",
        "photo": "pictures images gallery slideshow frame",
        "fetch": "neofetch fastfetch system info terminal"
    })

    // every word has to turn up somewhere in the widget's names, blurbs and keywords
    function matches(t, v, q) {
        if (q === "")
            return true;

        var hay = (t.id + " " + t.name + " " + t.blurb + " " + (wp.keywords[t.id] || "") + (v ? " " + v.id + " " + v.name + " " + v.blurb : "")).toLowerCase();
        var words = q.split(/\s+/);
        for (var i = 0; i < words.length; i++) {
            if (words[i] !== "" && hay.indexOf(words[i]) < 0)
                return false;

        }
        return true;
    }

    function cardMatches(typeId, variantId) {
        var t = Widgets.typeAt(typeId);
        return t !== null && wp.matches(t, Widgets.variantAt(typeId, variantId), wp.query);
    }

    function presetMatches(p) {
        var q = wp.query;
        return q === "" || (p.name + " " + (p.blurb || "")).toLowerCase().indexOf(q) >= 0;
    }

    // the sheet's resting place, so a drop test never sees it mid-slide
    function sheetHit(px, py) {
        return px >= wp.edge && px <= wp.edge + wp.sheetW && py >= wp.edge && py <= wp.edge + wp.sheetH;
    }

    function close() {
        Widgets.closePanel();
    }

    // a click: the first free spot on this screen that the sheet is not covering
    function addCard(typeId, variantId) {
        var v = Widgets.variantAt(typeId, variantId);
        if (!v || Widgets.full || !wp.board)
            return ;

        var size = Widgets.freshSize(typeId, v);
        var k = Widgets.sizeScale(typeId, v.id);
        var spot = Widgets.freeSpot(size.w * k, size.h * k, {
            "screen": wp.board.screenName,
            "w": wp.width,
            "h": wp.height,
            "avoid": {
                "x": 0,
                "y": 0,
                "w": wp.edge + wp.sheetW,
                "h": wp.height
            }
        });
        var uid = Widgets.spawnAt(typeId, v.id, spot.x, spot.y, wp.spawnScreen, false);
        if (uid !== "")
            wp.flash(uid);

    }

    // outlines a card for a moment, so a click shows where it went
    function flash(uid) {
        Widgets.spotUid = uid;
        flashTimer.uid = uid;
        flashTimer.restart();
    }

    function openCardMenu(uid) {
        var f = wp.board ? wp.board.frameFor(uid) : null;
        if (f && f.visible && !f.menuOpen)
            f.toggleMenu();

    }

    function cardsHere() {
        var out = [];
        for (var i = 0; wp.board && i < wp.board.frameCount; i++) {
            var f = wp.board.frameAt(i);
            if (f && f.visible && !f.closing)
                out.push(f);

        }
        return out;
    }

    // at = the press in panel coordinates, from = the tile's preview card as drawn
    function pickUp(typeId, variantId, at, from) {
        var v = Widgets.variantAt(typeId, variantId);
        if (!v || Widgets.full)
            return ;

        settle.stop();
        ghost.wtype = typeId;
        ghost.wvariant = v.id;
        // the size the card will land at
        var size = Widgets.freshSize(typeId, v);
        var k = Widgets.sizeScale(typeId, v.id);
        ghost.natW = Math.round(size.w * k);
        ghost.natH = Math.round(size.h * k);
        // the ghost grows out of the preview around the point that was grabbed
        var fx = from.w > 0 ? Math.max(0, Math.min(1, (at.x - from.x) / from.w)) : 0.5;
        var fy = from.h > 0 ? Math.max(0, Math.min(1, (at.y - from.y) / from.h)) : 0.5;
        ghost.grabX = fx * ghost.natW;
        ghost.grabY = fy * ghost.natH;
        ghost.fromScale = from.w > 0 ? from.w / ghost.natW : 0.5;
        ghost.fade = 1;
        ghost.lift = 0;
        ghost.carried = true;
        ghost.x = at.x - ghost.grabX;
        ghost.y = at.y - ghost.grabY;
        if (wp.board)
            wp.board.dragFrame = ghost;

        liftAnim.restart();
    }

    function carry(px, py) {
        if (!ghost.carried || !wp.board)
            return ;

        ghost.overSheet = wp.sheetHit(px, py);
        var nx = px - ghost.grabX;
        var ny = py - ghost.grabY;
        if (Prefs.widgetSnap && !ghost.overSheet) {
            var s = Widgets.snapBox(wp.width, wp.height, ghost.natW, ghost.natH, nx, ny, wp.cardsHere());
            nx = s.x;
            ny = s.y;
            ghost.guideX = s.gx;
            ghost.guideY = s.gy;
        } else {
            ghost.guideX = -1;
            ghost.guideY = -1;
        }
        ghost.x = Math.max(0, Math.min(wp.width - ghost.natW, nx));
        ghost.y = Math.max(0, Math.min(wp.height - ghost.natH, ny));
    }

    function letGo() {
        ghost.carried = false;
        ghost.guideX = -1;
        ghost.guideY = -1;
        if (wp.board && wp.board.dragFrame === ghost)
            wp.board.dragFrame = null;

    }

    // let go over the desktop: the card takes the ghost's place and the ghost fades off it
    function drop() {
        if (!ghost.carried)
            return ;

        var back = ghost.overSheet || Widgets.full;
        wp.letGo();
        if (back) {
            wp.abandon();
            return ;
        }
        Widgets.spawnAt(ghost.wtype, ghost.wvariant, ghost.x, ghost.y, wp.spawnScreen, true);
        settle.landing = true;
        settle.restart();
    }

    // let go over the sheet, or lost: the ghost shrinks back toward the gallery
    function abandon() {
        wp.letGo();
        if (ghost.wtype === "")
            return ;

        settle.landing = false;
        settle.restart();
    }

    function wheel(view, anim, event) {
        event.accepted = true;
        var lo = view.originY - view.topMargin;
        var hi = Math.max(lo, view.originY + view.contentHeight + view.bottomMargin - view.height);
        var base = anim.running ? anim.to : view.contentY;
        var target = Math.max(lo, Math.min(hi, base - (event.angleDelta.y / 120) * wp.wheelStep));
        if (target === base)
            return ;

        anim.stop();
        anim.from = view.contentY;
        anim.to = target;
        anim.start();
    }

    function stepTab(delta) {
        wp.tab = wp.tabs[(wp.tabIndex + delta + wp.tabs.length) % wp.tabs.length].key;
    }

    visible: wp.shown || ghost.visible
    onOpenChanged: {
        if (wp.open)
            return ;

        wp.abandon();
        if (wp.board)
            wp.board.forceActiveFocus();

    }
    onTabChanged: {
        if (wp.tab === "layouts")
            wp.layoutsWanted = true;

        wp.clearArmed = false;
    }

    Behavior on reveal {
        NumberAnimation {
            duration: wp.open ? Theme.durLong : Theme.durExit
            easing.type: Easing.Bezier
            easing.bezierCurve: wp.open ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
        }

    }

    Connections {
        function onCountChanged() {
            wp.cardsRev++;
        }

        function onDataChanged() {
            wp.cardsRev++;
        }

        target: Widgets.model
    }

    Timer {
        id: flashTimer

        property string uid: ""

        interval: 1100
        onTriggered: {
            if (Widgets.spotUid === flashTimer.uid)
                Widgets.spotUid = "";

        }
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: wp.clearArmed = false
    }

    Rectangle {
        id: sheet

        x: wp.edge - (1 - wp.reveal) * (wp.sheetW + wp.edge + Theme.dp(24))
        y: wp.edge
        width: wp.sheetW
        height: wp.sheetH
        radius: Theme.radiusXl
        color: Theme.withBlur(Theme.surfaceContainer)
        visible: wp.shown
        clip: true

        // the sheet takes its own presses and wheel, so nothing reaches the dim behind
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onWheel: (wheel) => {
                return wheel.accepted = true;
            }
        }

        Loader {
            id: body

            anchors.fill: parent
            active: wp.shown
            sourceComponent: bodyComponent
        }

    }

    // a card carried over the sheet is taken off the desktop when it is let go
    Rectangle {
        id: bin

        readonly property Item carried: (wp.board && wp.board.dragFrame && wp.board.dragFrame !== ghost) ? wp.board.dragFrame : null
        readonly property bool hot: bin.carried !== null && bin.carried.overBin === true
        // only once the card is brought toward the sheet, so an ordinary move is left alone
        readonly property bool near: bin.carried !== null && bin.carried.pointerX >= 0 && bin.carried.pointerX < wp.edge + wp.sheetW + 160

        x: sheet.x
        y: sheet.y
        width: sheet.width
        height: sheet.height
        radius: sheet.radius
        color: bin.hot ? Theme.alpha(Theme.errorContainer, 0.94) : Theme.alpha(Theme.surfaceHighest, 0.9)
        border.width: 2
        border.color: bin.hot ? Theme.error : Theme.alpha(Theme.text, 0.14)
        opacity: wp.open && (bin.hot || bin.near) ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFastEffects
            }

        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.dp(14)

            MaterialShape {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.dp(72)
                height: Theme.dp(72)
                shape: "cookie9"
                color: bin.hot ? Theme.error : Theme.primaryContainer
                scale: bin.hot ? 1.12 : 1

                Icon {
                    anchors.centerIn: parent
                    name: "delete"
                    size: Theme.dp(30)
                    fill: bin.hot ? 1 : 0
                    color: bin.hot ? Theme.fgError : Theme.fgPrimaryContainer
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "titleMedium"
                color: bin.hot ? Theme.fgErrorContainer : Theme.text
                text: bin.hot ? "Let go to remove it" : "Drop here to remove"
            }

        }

    }

    // a card on its way out of the gallery. the board draws its snap guides off it,
    // the same way it does for a card being moved
    Item {
        id: ghost

        property string wtype: ""
        property string wvariant: ""
        property bool carried: false
        property real natW: 1
        property real natH: 1
        property real grabX: 0
        property real grabY: 0
        // the preview's size against the real card's, where the ghost starts from
        property real fromScale: 1
        // 0 on top of the preview, 1 lifted at full size
        property real lift: 0
        property real fade: 1
        property bool overSheet: false
        property real guideX: -1
        property real guideY: -1
        property real dim: ghost.overSheet ? 0.5 : 0.95

        width: ghost.natW
        height: ghost.natH
        z: 2
        visible: ghost.wtype !== ""
        opacity: ghost.fade * ghost.dim

        Behavior on dim {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

        transform: Scale {
            origin.x: ghost.grabX
            origin.y: ghost.grabY
            xScale: ghost.fromScale + (1.03 - ghost.fromScale) * ghost.lift
            yScale: ghost.fromScale + (1.03 - ghost.fromScale) * ghost.lift
        }

        WidgetPreview {
            anchors.fill: parent
            wtype: ghost.wtype
            wvariant: ghost.wvariant
            live: ghost.visible
        }

    }

    NumberAnimation {
        id: liftAnim

        target: ghost
        property: "lift"
        from: 0
        to: 1
        duration: Theme.durFastSpatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveDefaultSpatial
    }

    // landing: settle to the card's own size while it fades in underneath, then go.
    // going back: shrink toward the gallery and fade
    SequentialAnimation {
        id: settle

        property bool landing: false

        ScriptAction {
            script: liftAnim.stop()
        }

        ParallelAnimation {
            NumberAnimation {
                target: ghost
                property: "lift"
                to: settle.landing ? (1 - ghost.fromScale) / Math.max(0.001, 1.03 - ghost.fromScale) : 0
                duration: Theme.durFastEffects
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: settle.landing ? Theme.ms(90) : 0
                }

                NumberAnimation {
                    target: ghost
                    property: "fade"
                    to: 0
                    duration: Theme.durShort
                    easing.type: Easing.InCubic
                }

            }

        }

        ScriptAction {
            script: {
                ghost.wtype = "";
                ghost.overSheet = false;
            }
        }

    }

    Component {
        id: bodyComponent

        Item {
            id: content

            Component.onCompleted: search.input.forceActiveFocus()
            // the next open starts over, once this one has slid away
            Component.onDestruction: {
                wp.tab = "add";
                wp.category = "all";
                wp.query = "";
                wp.clearArmed = false;
                wp.layoutsWanted = false;
            }
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                    wp.stepTab(e.key === Qt.Key_Backtab || (e.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    e.accepted = true;
                } else if (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier)) {
                    search.input.forceActiveFocus();
                    search.input.selectAll();
                    e.accepted = true;
                } else if (e.key === Qt.Key_Escape) {
                    wp.close();
                    e.accepted = true;
                }
            }

            Timer {
                id: typing

                interval: 140
                onTriggered: wp.query = search.text.trim().toLowerCase()
            }

            // header: the mark, what the panel is, what it does here and the way out
            Item {
                id: head

                x: wp.pad
                y: wp.pad
                width: wp.innerW
                height: Theme.dp(48)

                MaterialShape {
                    id: mark

                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(46)
                    height: Theme.dp(46)
                    shape: "cookie9"
                    color: Theme.primaryContainer

                    WidgetGlyph {
                        anchors.centerIn: parent
                        name: "widgets"
                        size: Theme.dp(22)
                        color: Theme.fgPrimaryContainer
                    }

                }

                Column {
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.dp(14)
                    anchors.right: closeBtn.left
                    anchors.rightMargin: Theme.dp(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    LText {
                        width: parent.width
                        role: "titleLarge"
                        text: "Widgets"
                        elide: Text.ElideRight
                    }

                    LText {
                        width: parent.width
                        role: "bodySmall"
                        color: Widgets.full ? Theme.error : Theme.subtext
                        text: {
                            if (Widgets.full)
                                return "The desktop is full. Take one off to make room.";

                            if (wp.tab === "placed")
                                return wp.liveCards + " of " + Widgets.capacity + " on the desktop";

                            if (wp.tab === "layouts")
                                return "Rearrange everything in one go";

                            return "Drag one onto the desktop, or click to add it";
                        }
                        elide: Text.ElideRight
                    }

                }

                IconButton {
                    id: closeBtn

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    onClicked: wp.close()
                }

            }

            TextField {
                id: search

                x: wp.pad
                y: head.y + head.height + Theme.dp(14)
                width: wp.innerW
                variant: "search"
                containerColor: Theme.withBlur(Theme.surfaceHigh)
                placeholder: wp.tab === "placed" ? "Search your desktop" : (wp.tab === "layouts" ? "Search layouts" : "Search widgets")
                onTextEdited: typing.restart()
                onEscaped: {
                    if (search.text !== "") {
                        search.text = "";
                        typing.stop();
                        wp.query = "";
                    } else {
                        wp.close();
                    }
                }
                // return puts out the first widget the search turned up
                onAccepted: {
                    typing.stop();
                    wp.query = search.text.trim().toLowerCase();
                    if (wp.tab === "add" && wp.shownTypes.length > 0)
                        wp.addCard(wp.shownTypes[0].id, wp.shownTypes[0].variants[0].id);

                }
            }

            Tabs {
                id: tabBar

                x: wp.pad
                y: search.y + search.height + Theme.dp(6)
                width: wp.innerW
                inline: true
                options: wp.tabs
                current: wp.tab
                onPicked: (key) => {
                    return wp.tab = key;
                }
            }

            // the three tabs side by side, pushed across as the tab changes
            Item {
                id: panes

                x: 0
                y: tabBar.y + tabBar.height
                width: wp.sheetW
                height: Math.max(0, foot.y - panes.y)
                clip: true

                Item {
                    id: strip

                    // a pane paints only while some of it is in view
                    function inView(i) {
                        return Math.abs(strip.x + i * wp.sheetW) < wp.sheetW - 0.5;
                    }

                    x: -wp.tabIndex * wp.sheetW
                    width: wp.sheetW * 3
                    height: panes.height

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                    // add: the categories as filter chips over a gallery of every face
                    Item {
                        id: addPane

                        x: 0
                        width: wp.sheetW
                        height: strip.height
                        visible: strip.inView(0)

                        Flickable {
                            id: chipScroll

                            x: wp.pad
                            y: Theme.dp(14)
                            width: wp.innerW
                            height: Theme.dp(32)
                            contentWidth: chipRow.width
                            contentHeight: height
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            Row {
                                id: chipRow

                                spacing: Theme.dp(6)

                                Repeater {
                                    model: [{
                                        "id": "all",
                                        "name": "All"
                                    }].concat(Widgets.catalogue)

                                    Chip {
                                        required property var modelData

                                        kind: "filter"
                                        text: modelData.name
                                        selected: wp.category === modelData.id
                                        onClicked: wp.category = (selected && modelData.id !== "all") ? "all" : modelData.id
                                    }

                                }

                            }

                            // a wheel or a sideways swipe runs the chips, at the panes' step
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: (event) => {
                                    event.accepted = true;
                                    var d = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                                    var maxX = Math.max(0, chipScroll.contentWidth - chipScroll.width);
                                    var base = chipAnim.running ? chipAnim.to : chipScroll.contentX;
                                    var target = Math.max(0, Math.min(maxX, base - (d / 120) * wp.wheelStep));
                                    if (target === base)
                                        return ;

                                    chipAnim.stop();
                                    chipAnim.from = chipScroll.contentX;
                                    chipAnim.to = target;
                                    chipAnim.start();
                                }
                            }

                            NumberAnimation {
                                id: chipAnim

                                target: chipScroll
                                property: "contentX"
                                duration: Theme.ms(170)
                                easing.type: Easing.OutCubic
                            }

                        }

                        ListView {
                            id: gallery

                            x: 0
                            y: chipScroll.y + chipScroll.height + Theme.dp(10)
                            width: wp.sheetW
                            height: Math.max(0, addPane.height - gallery.y)
                            clip: true
                            spacing: Theme.dp(22)
                            topMargin: Theme.dp(8)
                            bottomMargin: Theme.dp(20)
                            cacheBuffer: 360
                            boundsBehavior: Flickable.StopAtBounds
                            flickDeceleration: 6000
                            maximumFlickVelocity: 9000
                            model: wp.shownTypes

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: (event) => {
                                    return wp.wheel(gallery, galleryScroll, event);
                                }
                            }

                            NumberAnimation {
                                id: galleryScroll

                                target: gallery
                                property: "contentY"
                                duration: Theme.ms(170)
                                easing.type: Easing.OutCubic
                            }

                            delegate: Item {
                                id: group

                                required property var modelData
                                readonly property int placed: {
                                    var _ = wp.cardsRev;
                                    return Widgets.countOfType(group.modelData.id);
                                }

                                width: gallery.width
                                height: groupCol.implicitHeight

                                Column {
                                    id: groupCol

                                    x: wp.pad
                                    width: wp.innerW
                                    spacing: Theme.dp(10)

                                    Item {
                                        width: parent.width
                                        height: Theme.dp(22)

                                        LText {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.dp(4)
                                            anchors.verticalCenter: parent.verticalCenter
                                            role: "labelLarge"
                                            color: Theme.primary
                                            text: group.modelData.name
                                        }

                                        LText {
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.dp(4)
                                            anchors.verticalCenter: parent.verticalCenter
                                            role: "labelMedium"
                                            color: Theme.subtext
                                            text: group.placed > 0 ? group.placed + " on the desktop" : ""
                                        }

                                    }

                                    Grid {
                                        columns: 2
                                        spacing: Theme.dp(10)

                                        Repeater {
                                            model: group.modelData.variants

                                            PanelTile {
                                                required property var modelData

                                                width: wp.tileW
                                                panel: wp
                                                wtype: group.modelData.id
                                                variant: modelData
                                            }

                                        }

                                    }

                                }

                            }

                        }

                        Column {
                            anchors.centerIn: gallery
                            width: wp.innerW
                            spacing: Theme.dp(10)
                            visible: wp.shownTypes.length === 0

                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "search_off"
                                size: Theme.dp(40)
                                color: Theme.subtext
                            }

                            LText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                role: "titleMedium"
                                text: "No widgets match"
                            }

                            LText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                role: "bodyMedium"
                                color: Theme.subtext
                                wrapMode: Text.WordWrap
                                text: wp.category !== "all" ? "Nothing in this category fits the search. Try All." : "Try another word, such as clock, music or notes."
                            }

                        }

                    }

                    // on the desktop: every card that is out, and how they all behave
                    Flickable {
                        id: placedPane

                        x: wp.sheetW
                        width: wp.sheetW
                        height: strip.height
                        visible: strip.inView(1)
                        contentHeight: placedCol.implicitHeight + Theme.dp(34)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 6000
                        maximumFlickVelocity: 9000

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: (event) => {
                                return wp.wheel(placedPane, placedScroll, event);
                            }
                        }

                        NumberAnimation {
                            id: placedScroll

                            target: placedPane
                            property: "contentY"
                            duration: Theme.ms(170)
                            easing.type: Easing.OutCubic
                        }

                        Column {
                            id: placedCol

                            x: wp.pad
                            y: Theme.dp(14)
                            width: wp.innerW
                            spacing: Theme.dp(18)

                            Item {
                                width: parent.width
                                height: Theme.dp(36)
                                visible: wp.liveCards > 0

                                LText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.dp(4)
                                    anchors.verticalCenter: parent.verticalCenter
                                    role: "labelLarge"
                                    color: Theme.primary
                                    text: "Hover one to find it, click it for its options"
                                    width: parent.width - clearBtn.width - Theme.dp(12)
                                    elide: Text.ElideRight
                                }

                                Button {
                                    id: clearBtn

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    variant: wp.clearArmed ? "filled" : "text"
                                    danger: true
                                    size: "xs"
                                    icon: "delete_sweep"
                                    text: wp.clearArmed ? "Remove all?" : "Remove all"
                                    onClicked: {
                                        if (wp.clearArmed) {
                                            wp.clearArmed = false;
                                            disarm.stop();
                                            Widgets.closeAll();
                                        } else {
                                            wp.clearArmed = true;
                                            disarm.restart();
                                        }
                                    }
                                }

                            }

                            Column {
                                width: parent.width
                                spacing: Theme.dp(2)
                                visible: wp.liveCards > 0

                                Repeater {
                                    model: Widgets.model

                                    PanelRow {
                                        panel: wp
                                        first: wp.placedEnds.first === uid
                                        last: wp.placedEnds.last === uid
                                    }

                                }

                            }

                            LText {
                                width: parent.width
                                visible: wp.liveCards > 0 && wp.placedEnds.first === ""
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: Theme.dp(12)
                                role: "bodyMedium"
                                color: Theme.subtext
                                text: "None of your widgets match the search."
                            }

                            // nothing out yet
                            Column {
                                width: parent.width
                                spacing: Theme.dp(10)
                                visible: wp.liveCards === 0
                                topPadding: Theme.dp(26)
                                bottomPadding: Theme.dp(10)

                                MaterialShape {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Theme.dp(64)
                                    height: Theme.dp(64)
                                    shape: "cookie9"
                                    color: Theme.primaryContainer

                                    WidgetGlyph {
                                        anchors.centerIn: parent
                                        name: "widgets"
                                        size: Theme.dp(26)
                                        color: Theme.fgPrimaryContainer
                                    }

                                }

                                LText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    role: "titleMedium"
                                    text: "Nothing on the desktop yet"
                                }

                                LText {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    role: "bodyMedium"
                                    color: Theme.subtext
                                    wrapMode: Text.WordWrap
                                    text: Widgets.canRestore ? "Drag one out of Add, or bring back the last layout from Layouts." : "Drag one out of Add, or start from a ready-made layout."
                                }

                            }

                            Column {
                                width: parent.width
                                spacing: Theme.dp(8)

                                LText {
                                    leftPadding: Theme.dp(4)
                                    role: "labelLarge"
                                    color: Theme.primary
                                    text: "Behaviour"
                                }

                                Column {
                                    width: parent.width
                                    spacing: Theme.dp(2)

                                    Repeater {
                                        model: [{
                                            "key": "widgetSnap",
                                            "label": "Snap while dragging",
                                            "blurb": "Catch on edges, centres and each other"
                                        }, {
                                            "key": "widgetLockAll",
                                            "label": "Pin everything",
                                            "blurb": "Nothing moves until you turn this off"
                                        }, {
                                            "key": "widgetOnTop",
                                            "label": "Keep above windows",
                                            "blurb": "Float over everything, not just the desktop"
                                        }, {
                                            "key": "widgetHideFullscreen",
                                            "label": "Hide for fullscreen windows",
                                            "blurb": "Step aside while something runs fullscreen"
                                        }]

                                        Rectangle {
                                            id: brow

                                            required property var modelData
                                            required property int index

                                            width: parent.width
                                            height: Theme.dp(60)
                                            topLeftRadius: brow.index === 0 ? Theme.rad(20) : Theme.dp(4)
                                            topRightRadius: brow.index === 0 ? Theme.rad(20) : Theme.dp(4)
                                            bottomLeftRadius: brow.index === 3 ? Theme.rad(20) : Theme.dp(4)
                                            bottomRightRadius: brow.index === 3 ? Theme.rad(20) : Theme.dp(4)
                                            color: Theme.withBlur(Theme.surfaceHigh)

                                            Column {
                                                anchors.left: parent.left
                                                anchors.leftMargin: Theme.dp(16)
                                                anchors.right: bsw.left
                                                anchors.rightMargin: Theme.dp(10)
                                                anchors.verticalCenter: parent.verticalCenter

                                                LText {
                                                    width: parent.width
                                                    role: "bodyMedium"
                                                    text: brow.modelData.label
                                                    elide: Text.ElideRight
                                                }

                                                LText {
                                                    width: parent.width
                                                    role: "bodySmall"
                                                    color: Theme.subtext
                                                    text: brow.modelData.blurb
                                                    elide: Text.ElideRight
                                                }

                                            }

                                            Switch {
                                                id: bsw

                                                anchors.right: parent.right
                                                anchors.rightMargin: Theme.dp(12)
                                                anchors.verticalCenter: parent.verticalCenter
                                                checked: Prefs[brow.modelData.key] === true
                                                onToggled: (v) => {
                                                    return Prefs.set(brow.modelData.key, v);
                                                }
                                            }

                                        }

                                    }

                                }

                            }

                        }

                    }

                    // layouts: the presets, drawn small, built the first time the tab is opened
                    Loader {
                        id: layoutsPane

                        x: wp.sheetW * 2
                        width: wp.sheetW
                        height: strip.height
                        visible: strip.inView(2)
                        active: wp.layoutsWanted
                        sourceComponent: layoutsComponent
                    }

                }

            }

            // the foot: the full settings page, and done
            Item {
                id: foot

                x: 0
                y: wp.sheetH - foot.height
                width: wp.sheetW
                height: Theme.dp(68)

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.divider
                }

                Button {
                    anchors.left: parent.left
                    anchors.leftMargin: wp.pad - Theme.dp(6)
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "text"
                    icon: "settings"
                    text: "Settings"
                    onClicked: {
                        wp.close();
                        Prefs.settingsRequested("widgets");
                    }
                }

                Button {
                    anchors.right: parent.right
                    anchors.rightMargin: wp.pad
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "filled"
                    icon: "check"
                    text: "Done"
                    onClicked: wp.close()
                }

            }

        }

    }

    Component {
        id: layoutsComponent

        Flickable {
            id: layouts

            // a saved layout waiting on its delete to be confirmed, {id, name}
            property var doomed: null
            property string wallpaper: ""

            contentHeight: layoutCol.implicitHeight + Theme.dp(34)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 6000
            maximumFlickVelocity: 9000

            FileView {
                path: Quickshell.env("HOME") + "/.cache/current_wallpaper"
                blockLoading: true
                printErrors: false
                watchChanges: true
                onFileChanged: reload()
                onLoaded: layouts.wallpaper = text().trim()
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    return wp.wheel(layouts, layoutScroll, event);
                }
            }

            NumberAnimation {
                id: layoutScroll

                target: layouts
                property: "contentY"
                duration: Theme.ms(170)
                easing.type: Easing.OutCubic
            }

            Column {
                id: layoutCol

                x: wp.pad
                y: Theme.dp(14)
                width: wp.innerW
                spacing: Theme.dp(12)

                LText {
                    leftPadding: Theme.dp(4)
                    role: "labelLarge"
                    color: Theme.primary
                    text: "Yours"
                }

                Grid {
                    columns: 2
                    spacing: Theme.dp(10)

                    LP.PresetSaveTile {
                        width: wp.tileW
                        visible: wp.query === ""
                        wallpaper: layouts.wallpaper
                    }

                    // an arrangement nobody saved, set aside when a preset replaced it
                    LP.PresetTile {
                        width: wp.tileW
                        visible: Widgets.canRestore && wp.query === ""
                        title: "Last layout"
                        blurb: "Not saved"
                        cards: Widgets.lastLayout
                        wallpaper: layouts.wallpaper
                        mark: "refresh"
                        onChosen: Widgets.restoreLast()
                    }

                    Repeater {
                        model: Widgets.userPresets.filter((p) => {
                            return wp.presetMatches(p);
                        })

                        LP.PresetTile {
                            required property var modelData

                            width: wp.tileW
                            title: modelData.name
                            blurb: "Saved " + Qt.formatDate(new Date(modelData.saved || 0), "d MMM yyyy")
                            cards: Widgets.presetLayout(modelData.id)
                            wallpaper: layouts.wallpaper
                            selected: Widgets.presetId === modelData.id
                            removable: true
                            onChosen: Widgets.applyPreset(modelData.id)
                            onRemoveRequested: layouts.doomed = {
                                "id": modelData.id,
                                "name": modelData.name
                            }
                        }

                    }

                }

                // asks before a saved layout goes
                Rectangle {
                    width: parent.width
                    height: Theme.dp(56)
                    radius: Theme.rad(20)
                    visible: layouts.doomed !== null
                    color: Theme.errorContainer

                    LText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.dp(16)
                        anchors.right: keepBtn.left
                        anchors.rightMargin: Theme.dp(8)
                        anchors.verticalCenter: parent.verticalCenter
                        role: "bodyMedium"
                        color: Theme.fgErrorContainer
                        text: layouts.doomed ? "Delete “" + layouts.doomed.name + "”?" : ""
                        elide: Text.ElideRight
                    }

                    Button {
                        id: keepBtn

                        anchors.right: dropBtn.left
                        anchors.rightMargin: Theme.dp(4)
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "text"
                        size: "xs"
                        text: "Keep"
                        contentOverride: Theme.fgErrorContainer
                        onClicked: layouts.doomed = null
                    }

                    Button {
                        id: dropBtn

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "filled"
                        danger: true
                        size: "xs"
                        text: "Delete"
                        onClicked: {
                            if (layouts.doomed)
                                Widgets.deletePreset(layouts.doomed.id);

                            layouts.doomed = null;
                        }
                    }

                }

                Item {
                    width: 1
                    height: Theme.dp(6)
                }

                LText {
                    leftPadding: Theme.dp(4)
                    role: "labelLarge"
                    color: Theme.primary
                    text: "Ready-made"
                }

                Grid {
                    columns: 2
                    spacing: Theme.dp(10)

                    Repeater {
                        model: Widgets.presets.filter((p) => {
                            return wp.presetMatches(p);
                        })

                        LP.PresetTile {
                            required property var modelData

                            width: wp.tileW
                            title: modelData.name
                            blurb: modelData.blurb
                            cards: Widgets.presetLayout(modelData.id)
                            wallpaper: layouts.wallpaper
                            selected: Widgets.presetId === modelData.id
                            onChosen: Widgets.applyPreset(modelData.id)
                        }

                    }

                }

            }

        }

    }

}
