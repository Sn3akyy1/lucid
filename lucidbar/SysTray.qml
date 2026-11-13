import QtQuick
import Quickshell
import Quickshell.Hyprland._FocusGrab
import Quickshell.Services.SystemTray
import qs
import qs.lucidui

// the system tray. its two looks share one line of apps: each app in a slot of
// its own as the apps module has them, or the first few stacked with a count.
// a click on either opens the panel, grouped rows whose menus open in place,
// and a right click on a slot hangs the app's menu off the bar in the desktop
// menu's card
BarPill {
    id: root

    // the look picked on the module's card: every app in a slot, or the stack
    lookPref: Prefs.trayStyle
    readonly property bool iconFace: root.look === "icons"

    // the apps shown, in order: asking for attention, at work, idle; then by name
    readonly property var ordered: Tray.ordered(SystemTray.items ? SystemTray.items.values : [])
    readonly property int trayCount: root.ordered.length
    readonly property int attentionCount: root.ordered.filter((i) => {
        return Tray.wantsYou(i);
    }).length
    // the ones running that the module's card switched off
    readonly property int hiddenCount: (SystemTray.items ? SystemTray.items.values : []).filter((i) => {
        return !Tray.isBuiltin(i) && Tray.isHidden(i);
    }).length

    // each app keeps a number for as long as it stays. the slots, the stack and
    // the panel's rows all draw from one list of those numbers, brought into line
    // by moves, so a title or a status changing rebuilds nothing, and an app that
    // quits shrinks away where it was before its neighbours close up
    property var registry: ({})
    property var serials: []
    property int nextSerial: 1
    // what came with the module is already there; what comes later grows in
    property bool slotsReady: false

    function itemOf(serial) {
        return root.registry[serial] || null;
    }

    // its place among the apps staying, -1 for one on its way out
    function rankOf(serial) {
        return root.serials.indexOf(serial);
    }

    function sync() {
        const want = root.ordered;
        const leavingNow = [];
        for (let i = 0; i < slots.count; i++) {
            if (slots.get(i).leaving)
                leavingNow.push(slots.get(i).serial);

        }
        const reg = Object.assign({}, root.registry);
        let regChanged = false;
        const wanted = [];
        for (const it of want) {
            let s = -1;
            for (const k in reg) {
                const n = Number(k);
                if (reg[k] === it && leavingNow.indexOf(n) === -1) {
                    s = n;
                    break;
                }
            }
            if (s < 0) {
                // back while its old slot still shrinks: that one keeps the face it
                // had, and the app comes in anew
                for (const k in reg) {
                    if (reg[k] === it)
                        delete reg[k];

                }
                s = root.nextSerial++;
                reg[s] = it;
                regChanged = true;
            }
            wanted.push(s);
        }
        // the rest shrink away where they are, with nothing left pointing at an
        // app that may be gone: they keep the face they had
        let leavingAny = false;
        for (let i = 0; i < slots.count; i++) {
            const r = slots.get(i);
            if (!r.leaving && wanted.indexOf(r.serial) === -1) {
                delete reg[r.serial];
                regChanged = true;
                slots.setProperty(i, "leaving", true);
                leavingAny = true;
            }
        }
        if (regChanged)
            root.registry = reg;

        // the rest into line, among the ones still leaving
        for (let k = 0; k < wanted.length; k++) {
            let target = 0;
            let seen = 0;
            for (; target < slots.count; target++) {
                if (slots.get(target).leaving)
                    continue;

                if (seen === k)
                    break;

                seen++;
            }
            let cur = -1;
            for (let i = 0; i < slots.count; i++) {
                if (slots.get(i).serial === wanted[k] && !slots.get(i).leaving) {
                    cur = i;
                    break;
                }
            }
            if (cur === -1)
                slots.insert(target, {
                "serial": wanted[k],
                "leaving": false
            });
            else if (cur !== target)
                slots.move(cur, target, 1);
        }
        root.serials = wanted;
        if (leavingAny)
            retire.restart();

    }

    onOrderedChanged: root.sync()
    Component.onCompleted: {
        root.sync();
        readyLater.start();
    }

    ListModel {
        id: slots
    }

    // the ones that left have shrunk away by now: a slot goes quicker than a row
    // in the open panel, and only what is on screen is waited for
    Timer {
        id: retire

        interval: (root.expanded ? Theme.durMedium : Theme.durShort) + 40
        onTriggered: {
            for (let i = slots.count - 1; i >= 0; i--) {
                if (slots.get(i).leaving)
                    slots.remove(i);

            }
        }
    }

    Timer {
        id: readyLater

        interval: 600
        onTriggered: root.slotsReady = true
    }

    // sizes: a slot and a glyph as the apps module has them
    readonly property int slot: root.compactHeight - Theme.dp(4)
    readonly property int glyph: Math.min(root.compactHeight - Theme.dp(12), Math.max(Theme.barDp(12), Math.round(Math.min(root.compactHeight * 0.55, root.compactHeight - Theme.dp(16)) * Theme.barContent)))
    readonly property int horizontalPadding: root.iconFace ? Theme.dp(6) : Theme.barDp(10)
    readonly property int pileMax: 3
    // each one behind shows about two thirds of itself
    readonly property int pileStep: Math.round(root.glyph * 0.78)
    readonly property int pileShown: Math.min(root.trayCount, root.pileMax)
    readonly property int pileWidth: root.pileShown > 0 ? root.glyph + (root.pileShown - 1) * root.pileStep : 0
    readonly property int moreCount: Math.max(0, root.trayCount - root.pileMax)
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    // tall enough that an app's menu opened in its row rarely has to scroll
    readonly property int maxPanelHeight: Math.min(Theme.dp(760), Math.max(Theme.dp(200), root.screenH - Theme.dp(90)))
    readonly property int rowGap: Theme.dp(3)
    // a panel taller than it may be scrolls under the wheel, rows and all
    readonly property bool panelScrolls: panelFlick.contentHeight > panelFlick.height + 0.5

    shown: Prefs.barHas("tray") && root.trayCount > 0
    compactWidth: root.iconFace ? slots.count * root.slot + root.horizontalPadding * 2 : root.pileWidth + (root.moreCount > 0 ? Theme.barDp(5) + moreText.implicitWidth : 0) + root.horizontalPadding * 2
    panelWidth: Math.min(Theme.dp(340), root.screenW - Theme.dp(34))
    // the flickable's own margins, each rounded as it is: dp(24) is a pixel short of two dp(12)s
    panelHeight: Math.min(root.maxPanelHeight, panelCol.implicitHeight + 2 * Theme.dp(12))
    expandedRadius: Theme.shapeXl
    compactCollapseScale: 0.94
    // in the icons look each slot lights on its own, so the pill does not light
    // as a whole; a click on it still opens the panel, as on any pill
    compactInteractive: !root.iconFace

    onTrayCountChanged: {
        if (root.trayCount === 0) {
            root.expanded = false;
            root.closeMenu();
        }
    }
    onExpandedChanged: {
        root.closeMenu();
        root.hover(null);
        // a row left open is put away once the panel has gone, not while it goes
        if (root.expanded)
            rowReset.stop();
        else
            rowReset.restart();
    }

    // ---- the panel: which row has its menu out
    property int openSerial: -1

    function toggleRow(serial) {
        root.openSerial = root.openSerial === serial ? -1 : serial;
        if (root.openSerial !== -1)
            rowReveal.restart();

    }

    // a menu row was picked: everything the tray had open goes
    function chosen() {
        root.closeMenu();
        root.expanded = false;
    }

    function openSheet() {
        root.closeMenu();
        root.expanded = false;
        if (root.hostWindow && root.hostWindow.editModule)
            root.hostWindow.editModule("tray");
        else
            Prefs.openBarModule("tray");
    }

    // a click on the icons look, on an icon or between them: the panel, as a
    // click on any pill. a right click between them, the module's sheet
    function barClicked(button) {
        if (button === Qt.RightButton) {
            root.openSheet();
            return ;
        }
        if (root.popupMode && root.expanded && !root.hoverOpen) {
            root.expanded = false;
            return ;
        }
        root.hoverOpen = false;
        root.compactClicked();
        root.expanded = true;
    }

    Timer {
        id: rowReset

        interval: Theme.barDurEnter + 120
        onTriggered: root.openSerial = -1
    }

    // a row that opened below the fold scrolls up into view once it has grown
    Timer {
        id: rowReveal

        interval: Theme.durMedium + 30
        onTriggered: {
            for (let i = 0; i < rowsRep.count; i++) {
                const r = rowsRep.itemAt(i);
                if (!r || r.serial !== root.openSerial)
                    continue;

                const top = rowsCol.y + r.y;
                const bottom = top + r.height;
                const maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height);
                let y = panelFlick.contentY;
                if (bottom > y + panelFlick.height)
                    y = bottom - panelFlick.height;

                if (top < y)
                    y = top;

                scrollTo.to = Math.max(0, Math.min(maxY, y));
                scrollTo.restart();
                return ;
            }
        }
    }

    NumberAnimation {
        id: scrollTo

        target: panelFlick
        property: "contentY"
        duration: Theme.durMedium
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedDecel
    }

    // ---- the menu off a slot
    property int menuSerial: -1
    property bool menuShown: false
    property real menuAtX: 0
    // where the menu hangs from, in the pill's own coordinates: the slot's far
    // side. it goes away from the bar, so up from there on the bottom edge
    property real menuFromY: 0
    readonly property var menuItem: root.menuSerial >= 0 ? root.itemOf(root.menuSerial) : null
    readonly property real menuY: root.overlayY(root.menuFromY, 0, card.height)
    readonly property bool menuVisible: root.menuShown || card.opacity > 0.01

    function toggleMenu(cell) {
        if (!cell)
            return ;

        if (root.menuShown && root.menuSerial === cell.serial) {
            root.closeMenu();
            return ;
        }
        root.hover(null);
        const a = root.mapFromItem(cell, 0, 0).y;
        const b = root.mapFromItem(cell, 0, cell.height).y;
        root.menuFromY = Math.max(a, b) + Theme.dp(6);
        root.menuAtX = menuLayer.mapFromItem(cell, 0, 0).x - Theme.dp(2);
        const swapped = root.menuShown;
        root.menuSerial = cell.serial;
        menu.reset();
        if (swapped)
            card.popIn();
        else
            root.menuShown = true;
    }

    function closeMenu() {
        root.menuShown = false;
    }

    // the app quit with its menu open
    onMenuItemChanged: {
        if (!root.menuItem)
            root.closeMenu();

    }
    onMenuShownChanged: {
        if (root.menuShown)
            card.appear();
        else
            card.vanish();
    }

    // a menu off the bar has no panel's grab behind it, so it keeps its own
    HyprlandFocusGrab {
        active: root.menuShown && !root.expanded
        windows: root.hostWindow ? [root.hostWindow] : []
        onCleared: root.closeMenu()
    }

    // ---- the name under a slot, after a beat
    property Item tipCell: null
    property bool tipShown: false
    property bool tipAbove: false
    readonly property bool tipOpen: Prefs.dockShowTooltips && root.iconFace && root.tipShown && !!root.tipCell && !root.menuShown && !root.expanded
    readonly property var tipItem: root.tipCell ? root.tipCell.item : null
    // what the tip says and where, held while it fades: the slot it named is
    // already gone from under the pointer by then
    readonly property bool tipLive: !!root.tipCell && root.tipShown && !!root.tipItem
    property point tipAt: Qt.point(0, 0)
    property string tipName: ""
    property string tipDetail: ""
    property bool tipWants: false
    // mapped again once the overlay has grown to take it, since on the bottom
    // edge the overlay counts from its far end
    readonly property point tipLiveAt: root.tipLive ? (menuLayer.width, menuLayer.height, menuLayer.mapFromItem(root.tipCell, root.tipCell.width / 2, root.tipAbove ? -Theme.dp(8) : root.tipCell.height + Theme.dp(8))) : Qt.point(0, 0)
    readonly property string tipLiveName: root.tipLive ? Tray.nameOf(root.tipItem) : ""
    readonly property bool tipLiveWants: root.tipLive && Tray.wantsYou(root.tipItem)
    readonly property string tipLiveDetail: root.tipLive ? (Tray.detailOf(root.tipItem) || (root.tipLiveWants ? "Wants your attention" : "")) : ""

    onTipLiveAtChanged: {
        if (root.tipLive)
            root.tipAt = root.tipLiveAt;

    }
    onTipLiveNameChanged: {
        if (root.tipLive)
            root.tipName = root.tipLiveName;

    }
    onTipLiveDetailChanged: {
        if (root.tipLive)
            root.tipDetail = root.tipLiveDetail;

    }
    onTipLiveWantsChanged: {
        if (root.tipLive)
            root.tipWants = root.tipLiveWants;

    }
    onTipLiveChanged: {
        if (!root.tipLive)
            return ;

        root.tipAt = root.tipLiveAt;
        root.tipName = root.tipLiveName;
        root.tipDetail = root.tipLiveDetail;
        root.tipWants = root.tipLiveWants;
    }

    function hover(cell) {
        root.tipCell = cell;
        root.tipShown = false;
        if (cell)
            tipDelay.restart();
        else
            tipDelay.stop();
    }

    function unhover(cell) {
        if (root.tipCell === cell)
            root.hover(null);

    }

    Timer {
        id: tipDelay

        interval: 500
        onTriggered: {
            if (!root.tipCell)
                return ;

            const g = root.tipCell.mapToGlobal(0, 0);
            root.tipAbove = g.y > root.screenH / 2;
            root.tipShown = true;
        }
    }

    // the menu card takes the pointer and the blur; the tip takes neither
    overlayOpen: root.menuVisible || root.tipOpen || tip.opacity > 0.01
    overlayItem: card
    readonly property bool overlayBlurReady: card.opacity > 0.95
    readonly property var overlayRects: root.menuShown ? [{
        "x": card.x + cardJelly.shiftX,
        "y": card.y + cardJelly.shiftY,
        "w": card.width * cardJelly.xScale,
        "h": card.height * cardJelly.yScale,
        "r": card.radius
    }] : []

    compactContent: [
        // the icons look: a click between the icons opens the panel, a right
        // click there the module's sheet; the slots above pass their clicks on
        MouseArea {
            anchors.fill: parent
            enabled: root.iconFace
            visible: root.iconFace
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                return root.barClicked(mouse.button);
            }
        },
        Item {
            id: strip

            visible: root.iconFace
            x: root.horizontalPadding
            width: slots.count * root.slot
            height: root.compactHeight

            Repeater {
                model: root.iconFace ? slots : null

                TraySlot {
                    tray: root
                }

            }

        },
        // the stack: the first apps overlapped, then how many more
        Item {
            id: pile

            visible: !root.iconFace
            x: root.horizontalPadding
            anchors.verticalCenter: parent.verticalCenter
            width: root.pileWidth
            height: root.glyph

            Repeater {
                model: root.iconFace ? null : slots

                TrayPileIcon {
                    tray: root
                }

            }

            Behavior on width {
                enabled: root.slotsReady

                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

        },
        Text {
            id: moreText

            visible: !root.iconFace && root.moreCount > 0
            anchors.left: pile.right
            anchors.leftMargin: Theme.barDp(5)
            anchors.verticalCenter: parent.verticalCenter
            text: "+" + root.moreCount
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFs(12)
            font.variableAxes: Theme.axes(Theme.barFs(12), 600, 0)
            font.weight: Font.DemiBold
        },
        // the one in front asking for attention: the slots' red mark, under it
        Rectangle {
            id: pileMark

            property real pulse: 1
            readonly property bool wants: !root.iconFace && root.attentionCount > 0

            x: pile.x + Math.round((root.glyph - width) / 2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(3)
            width: Theme.barDp(4)
            height: Theme.barDp(3)
            radius: height / 2
            color: Theme.error
            opacity: pileMark.wants ? pileMark.pulse : 0
            visible: opacity > 0.01

            SequentialAnimation on pulse {
                running: pileMark.wants && root.shown
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running)
                        pileMark.pulse = 1;

                }

                NumberAnimation {
                    to: 0.3
                    duration: Theme.ms(500)
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    to: 1
                    duration: Theme.ms(500)
                    easing.type: Easing.InOutSine
                }

            }

        }
    ]

    panelContent: [
        Flickable {
            id: panelFlick

            anchors.fill: parent
            anchors.margins: Theme.dp(12)
            contentWidth: width
            contentHeight: panelCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height + 0.5
            flickDeceleration: 6000
            maximumFlickVelocity: 6000

            Column {
                id: panelCol

                width: panelFlick.width

                Item {
                    width: parent.width
                    height: Theme.dp(44)

                    // on the rows' icon column
                    LText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.dp(14)
                        anchors.verticalCenter: parent.verticalCenter
                        role: "titleMedium"
                        weight: 600
                        text: "Tray"
                        color: Theme.text
                    }

                    LText {
                        anchors.right: sheetButton.left
                        anchors.rightMargin: Theme.dp(4)
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelMedium"
                        text: root.attentionCount > 0 ? (root.attentionCount === 1 ? "1 wants attention" : root.attentionCount + " want attention") : (root.trayCount === 1 ? "1 app" : root.trayCount + " apps")
                        color: root.attentionCount > 0 ? Theme.error : Theme.subtext
                    }

                    IconButton {
                        id: sheetButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "settings"
                        size: "s"
                        onClicked: root.openSheet()
                    }

                }

                Item {
                    width: 1
                    height: Theme.dp(4)
                }

                Column {
                    id: rowsCol

                    width: parent.width

                    Repeater {
                        id: rowsRep

                        model: slots

                        TrayRow {
                            tray: root
                        }

                    }

                }

                // apps switched off on the card still run; say so, and where to bring them back
                Item {
                    visible: root.hiddenCount > 0
                    width: parent.width
                    height: visible ? Theme.dp(44) : 0

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: Theme.dp(6)
                        radius: height / 2
                        color: Theme.text
                        opacity: hiddenArea.pressed ? Theme.statePressed : (hiddenHover.hovered && root.expanded ? Theme.stateHover : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.dp(14)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: Theme.dp(3)
                        spacing: Theme.dp(10)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "visibility_off"
                            size: Theme.dp(18)
                            color: Theme.subtext
                        }

                        LText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "bodyMedium"
                            text: root.hiddenCount === 1 ? "1 app hidden" : root.hiddenCount + " apps hidden"
                            color: Theme.subtext
                        }

                    }

                    LText {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(14)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: Theme.dp(3)
                        role: "labelLarge"
                        text: "Manage"
                        color: Theme.primary
                    }

                    HoverHandler {
                        id: hiddenHover
                    }

                    MouseArea {
                        id: hiddenArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSheet()
                    }

                }

            }

        }
    ]

    overlayContent: [
        Item {
            id: menuLayer

            anchors.fill: parent

            // the app's menu, the desktop menu's card: its name on top, then the
            // rows, a submenu sliding in over them
            Rectangle {
                id: card

                readonly property real headH: Theme.dp(52)
                readonly property real headWant: Theme.dp(13) + Theme.dp(26) + Theme.dp(12) + Math.max(cardName.implicitWidth, cardDetail.visible ? cardDetail.implicitWidth : 0) + Theme.dp(18)
                readonly property bool jellyWobbling: cardJelly.wobbling

                function appear() {
                    vanishAnim.stop();
                    cardJelly.rest();
                    if (card.opacity < 0.05)
                        card.scale = 0.8;

                    appearAnim.restart();
                    cardJelly.kickAfter(Math.min(0.09, Theme.dp(20) / Math.max(1, card.height)), Math.round(Theme.barDurEnter * 0.3));
                }

                function vanish() {
                    appearAnim.stop();
                    vanishAnim.restart();
                }

                // another app's menu while one is up: it comes in again from where it hangs
                function popIn() {
                    vanishAnim.stop();
                    card.scale = 0.92;
                    appearAnim.restart();
                    cardJelly.kickAfter(0.05, Math.round(Theme.barDurEnter * 0.3));
                }

                width: Math.round(Math.max(Theme.dp(220), Math.min(Theme.dp(320), Math.max(card.headWant, menu.implicitWidth))))
                height: Math.round(card.headH + Theme.dp(1) + menu.implicitHeight)
                // kept on screen, whichever side of the bar the tray sits on
                x: Math.round(Math.max(Theme.dp(10) - root.x, Math.min(root.menuAtX, menuLayer.width - card.width - Theme.dp(10))))
                y: Math.round(root.menuY)
                // m3 expressive: the card rounds out further while a submenu is in
                radius: menu.shown > 0 ? Theme.radiusLg : Theme.radiusMd
                color: Theme.bg
                border.width: Theme.blurAmount > 0 ? 0 : 1
                border.color: Theme.alpha(Theme.text, 0.06)
                clip: true
                opacity: 0
                visible: card.opacity > 0.01
                transformOrigin: Prefs.barBottom ? Item.BottomLeft : Item.TopLeft

                // who the menu is for
                Item {
                    id: cardHead

                    width: card.width
                    height: card.headH

                    // centred on the rows' icon column
                    TrayIcon {
                        id: cardIcon

                        x: Theme.dp(13)
                        anchors.verticalCenter: parent.verticalCenter
                        item: root.menuItem
                        size: Theme.dp(26)
                    }

                    Column {
                        anchors.left: cardIcon.right
                        anchors.leftMargin: Theme.dp(12)
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        LText {
                            id: cardName

                            width: parent.width
                            role: "titleSmall"
                            weight: 600
                            text: root.menuItem ? Tray.nameOf(root.menuItem) : ""
                            color: Theme.text
                            elide: Text.ElideRight
                        }

                        LText {
                            id: cardDetail

                            readonly property bool wants: Tray.wantsYou(root.menuItem)

                            width: parent.width
                            visible: text !== ""
                            role: "bodySmall"
                            text: root.menuItem ? (Tray.detailOf(root.menuItem) || (cardDetail.wants ? "Wants your attention" : "")) : ""
                            color: cardDetail.wants ? Theme.error : Theme.subtext
                            elide: Text.ElideRight
                        }

                    }

                }

                Rectangle {
                    y: card.headH
                    x: Theme.dp(12)
                    width: card.width - Theme.dp(24)
                    height: 1
                    color: Theme.alpha(Theme.text, 0.1)
                }

                // an app with no menu, or an empty one, still gets one row: open it
                TrayMenu {
                    id: menu

                    y: card.headH + Theme.dp(1)
                    width: card.width
                    handle: root.menuItem && root.menuItem.hasMenu ? root.menuItem.menu : null
                    onChosen: root.closeMenu()
                    onOpenRequested: {
                        if (root.menuItem)
                            root.menuItem.activate();

                        root.closeMenu();
                    }
                }

                // wheel over the menu stays in it
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                    }
                }

                ParallelAnimation {
                    id: appearAnim

                    NumberAnimation {
                        target: card
                        property: "opacity"
                        to: 1
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                    NumberAnimation {
                        target: card
                        property: "scale"
                        to: 1
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                // out: m3's quick fade in place, never shrinking away
                NumberAnimation {
                    id: vanishAnim

                    target: card
                    property: "opacity"
                    to: 0
                    duration: Theme.barDurQuick
                }

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                transform: Jelly {
                    id: cardJelly

                    target: card
                    anchorX: 0
                    anchorY: Prefs.barBottom ? 1 : 0
                    frequency: 4.4
                }

            }

            // the app's name, as the apps module names its icons
            Rectangle {
                id: tip

                x: Math.round(Math.max(Theme.dp(6) - root.x, Math.min(root.tipAt.x - width / 2, (root.hostWindow ? root.hostWindow.width : menuLayer.width) - root.x - width - Theme.dp(6))))
                y: Math.round(root.tipAbove ? root.tipAt.y - height : root.tipAt.y)
                width: Math.min(Theme.dp(260), Math.max(tipNameMetrics.width, tipDetail.visible ? tipDetailMetrics.width : 0) + Theme.dp(22))
                height: tipColumn.implicitHeight + Theme.dp(12)
                radius: Theme.radiusXs
                color: Theme.bgHigh
                opacity: root.tipOpen ? 1 : 0
                visible: opacity > 0.01

                // measured, not read off the texts: an eliding text's own width is
                // the width it was given
                TextMetrics {
                    id: tipNameMetrics

                    font: tipName.font
                    text: tipName.text
                }

                TextMetrics {
                    id: tipDetailMetrics

                    font: tipDetail.font
                    text: tipDetail.text
                }

                Column {
                    id: tipColumn

                    anchors.centerIn: parent
                    width: tip.width - Theme.dp(20)
                    spacing: 1

                    Text {
                        id: tipName

                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.tipName
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.variableAxes: Theme.axes(Theme.fontBody, 520, 0)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        id: tipDetail

                        width: parent.width
                        visible: text !== ""
                        horizontalAlignment: Text.AlignHCenter
                        text: root.tipDetail
                        color: root.tipWants ? Theme.error : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                        elide: Text.ElideRight
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

                transform: Translate {
                    y: (1 - tip.opacity) * (root.tipAbove ? Theme.dp(4) : -Theme.dp(4))
                }

            }

        }
    ]
}
