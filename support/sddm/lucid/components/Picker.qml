import QtQuick
import QtQuick.Effects

// the greeter's two choices: whose account, and which session. one menu over
// the whole greeter, opened from whatever asked for it (the face, the name, the
// session chip) and set down beside it, above when it sits low on the screen.
// it never touches the layout under it, so it reads the same on every preset,
// and an account picked here can swap the whole layout without pulling the
// list out from under the pointer.
// drawn to m3 expressive's vertical menu (androidx SegmentedMenuTokens and
// StandardMenuTokens): groups on surface container low, 2dp apart, 4dp inset;
// 44dp items with 16dp sides; the group in use rounds to 24dp, the rest sit at
// 8dp; items 4dp inside, 12dp on the group's outer corners and when selected;
// selected on the tertiary container; supporting text on the right in label small
Item {
    id: pk

    // false on the screens that only show the time
    property bool live: true
    // what is showing; latched, so a closing list keeps its rows
    property string kind: ""
    // the asking item's box, in this item's coordinates, followed while open
    property rect from: Qt.rect(0, 0, 0, 0)
    // above the asking item rather than below it, settled as it opens
    property bool above: true
    // 0 closed .. 1 open: k carries the spring of the scale, f the fade
    property real k: 0
    property real f: 0
    // the row the keyboard or the pointer is on, and whether the keyboard drives
    property int hi: 0
    property bool kbd: false
    readonly property bool users: pk.kind === "users"
    readonly property int accounts: Lock.accounts.length
    readonly property int count: pk.users ? pk.accounts + 1 : Lock.sessions.length
    readonly property int current: pk.users ? (Lock.manual ? pk.accounts : Lock.index) : Lock.sessionIndex
    // ── the spec, in this greeter's units ─────────────────────────────────
    readonly property real rowH: Theme.dp(pk.users ? 56 : 44)
    readonly property real groupPad: Theme.dp(4)
    readonly property real groupGap: Theme.dp(2)
    readonly property real side: Theme.dp(16)
    readonly property real between: Theme.dp(12)
    readonly property real lead: pk.users ? Theme.dp(32) : 0
    readonly property real iconSize: Theme.dp(20)
    readonly property int itemOuter: Theme.rad(12)
    readonly property int itemInner: Theme.rad(4)
    readonly property int groupActive: Theme.rad(24)
    readonly property int groupRest: Theme.rad(8)
    // "other account" is a group of its own, after the listed ones
    readonly property bool twoGroups: pk.users && pk.accounts > 0
    readonly property int firstCount: pk.twoGroups ? pk.accounts : pk.count
    // ── room ───────────────────────────────────────────────────────────────
    readonly property real margin: Theme.dp(24)
    readonly property real gap: Theme.dp(8)
    readonly property real fullH: pk.groupH(pk.firstCount) + (pk.twoGroups ? pk.groupGap + pk.groupH(1) : 0)
    readonly property real room: pk.above ? pk.from.y - pk.gap - pk.margin : pk.height - pk.from.y - pk.from.height - pk.gap - pk.margin
    readonly property real panelH: Math.round(Math.min(pk.fullH, Math.max(pk.rowH * 3, pk.room)))
    // as wide as its widest row asks, within m3's menu widths
    readonly property real panelW: Math.round(Math.min(pk.width - pk.margin * 2, Math.max(Theme.dp(240), Math.min(Theme.dp(360), pk.widest + pk.groupPad * 2))))
    readonly property real widest: {
        void labelSize.font;
        void tagSize.font;
        var w = 0;
        for (var i = 0; i < pk.count; i++) {
            // the supporting text on the right stands well clear of the label
            var t = pk.labelW(i) + (pk.trailOf(i) !== "" ? Theme.dp(32) + Math.ceil(tagSize.advanceWidth(pk.trailOf(i))) : 0);
            w = Math.max(w, t);
        }
        return pk.side * 2 + (pk.lead > 0 ? pk.lead + pk.between : 0) + w + pk.between + pk.iconSize;
    }
    readonly property real panelX: Math.round(Math.max(pk.margin, Math.min(pk.width - pk.margin - pk.panelW, pk.from.x + pk.from.width / 2 - pk.panelW / 2)))
    readonly property real panelY: Math.round(pk.above ? pk.from.y - pk.gap - pk.panelH : pk.from.y + pk.from.height + pk.gap)

    signal closed()

    function groupH(n) {
        return n * pk.rowH + pk.groupPad * 2;
    }

    // a row's top within the menu, across the gap between the groups
    function rowTop(i) {
        if (pk.twoGroups && i >= pk.accounts)
            return pk.groupH(pk.firstCount) + pk.groupGap + pk.groupPad + (i - pk.accounts) * pk.rowH;

        return pk.groupPad + i * pk.rowH;
    }

    // where the asking item is now: it can move while the list is up (a
    // layout settling, the field opening), and the list goes with it
    function track() {
        var it = Lock.sheetFrom;
        if (!it || !it.visible)
            return ;

        var r = it.mapToItem(pk, 0, 0, it.width, it.height);
        if (r.x !== pk.from.x || r.y !== pk.from.y || r.width !== pk.from.width || r.height !== pk.from.height)
            pk.from = r;

    }

    // ── what each row says ─────────────────────────────────────────────────
    // "Plasma (Wayland)": the name, and what its brackets say, for the right
    function split(name) {
        var m = /^(.*\S)\s*\(([^()]+)\)\s*$/.exec(name || "");
        return m ? [m[1], m[2]] : [name || "", ""];
    }

    function titleOf(i) {
        if (pk.users) {
            if (i >= pk.accounts)
                return "Other account";

            var a = Lock.accounts[i];
            return a ? Lock.nameOf(a) : "";
        }
        var s = Lock.sessions[i];
        return s ? pk.split(s.name)[0] : "";
    }

    // the line under an account's name
    function subOf(i) {
        if (!pk.users)
            return "";

        if (i >= pk.accounts)
            return "Sign in with a username";

        var a = Lock.accounts[i];
        if (!a)
            return "";

        var bits = [];
        if (a.name !== Lock.nameOf(a))
            bits.push(a.name);

        if (!a.needsPassword)
            bits.push("No password");

        return bits.join(" · ");
    }

    // the supporting text on the right: what a session's brackets said
    function trailOf(i) {
        if (pk.users)
            return "";

        var s = Lock.sessions[i];
        return s ? pk.split(s.name)[1] : "";
    }

    function labelW(i) {
        return Math.max(Math.ceil(labelSize.advanceWidth(pk.titleOf(i))), Math.ceil(subSize.advanceWidth(pk.subOf(i))));
    }

    // ── choosing ───────────────────────────────────────────────────────────
    function choose(i) {
        if (i < 0 || i >= pk.count)
            return ;

        if (i === pk.current) {
            Lock.closeSheet();
            return ;
        }
        if (!pk.users)
            Lock.pickSession(i);
        else if (i >= pk.accounts)
            Lock.pickOther();
        else
            Lock.pick(i);
    }

    function show(i) {
        var top = pk.rowTop(i);
        if (top < flick.contentY)
            flick.contentY = Math.max(0, top - pk.groupPad);
        else if (top + pk.rowH > flick.contentY + flick.height)
            flick.contentY = Math.min(flick.contentHeight - flick.height, top + pk.rowH + pk.groupPad - flick.height);
    }

    function move(by) {
        pk.kbd = true;
        pk.hi = Math.max(0, Math.min(pk.count - 1, pk.hi + by));
        pk.show(pk.hi);
    }

    // a letter goes to the next row starting with it
    function seek(ch) {
        var c = ch.toLowerCase();
        for (var n = 1; n <= pk.count; n++) {
            var i = (pk.hi + n) % pk.count;
            if (pk.titleOf(i).toLowerCase().indexOf(c) === 0) {
                pk.kbd = true;
                pk.hi = i;
                pk.show(i);
                return ;
            }
        }
    }

    visible: pk.live && (pk.f > 0.001 || pk.k > 0.001)

    FontMetrics {
        id: labelSize

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 500, 0)
        font.weight: Font.Medium
    }

    FontMetrics {
        id: subSize

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyMd
        font.variableAxes: Theme.axes(Theme.fontBodyMd, 400, 0)
    }

    FontMetrics {
        id: tagSize

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabelSm
        font.variableAxes: Theme.axes(Theme.fontLabelSm, 500, 0)
        font.weight: Font.Medium
    }

    Connections {
        function onSheetChanged() {
            if (!pk.live)
                return ;

            if (Lock.sheet === "") {
                opening.stop();
                closing.restart();
                return ;
            }
            // straight from one list to the other: the new one opens afresh
            if (pk.kind !== "" && pk.kind !== Lock.sheet) {
                pk.k = 0;
                pk.f = 0;
            }
            pk.kind = Lock.sheet;
            pk.track();
            pk.above = pk.from.y + pk.from.height / 2 > pk.height * 0.5;
            pk.hi = Math.max(0, pk.current);
            pk.kbd = false;
            closing.stop();
            opening.restart();
            keys.forceActiveFocus();
            Qt.callLater(() => {
                pk.show(pk.hi);
            });
        }

        target: Lock
    }

    ParallelAnimation {
        id: opening

        NumberAnimation {
            target: pk
            property: "k"
            to: 1
            duration: Theme.ms(400)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

        NumberAnimation {
            target: pk
            property: "f"
            to: 1
            duration: Theme.ms(150)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveEffects
        }

    }

    ParallelAnimation {
        id: closing

        NumberAnimation {
            target: pk
            property: "k"
            to: 0
            duration: Theme.ms(200)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeEmphasizedAccel
        }

        NumberAnimation {
            target: pk
            property: "f"
            to: 0
            duration: Theme.ms(160)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeEmphasizedAccel
        }

        onFinished: {
            if (Lock.sheet !== "")
                return ;

            pk.kind = "";
            pk.closed();
        }
    }

    FrameAnimation {
        running: pk.visible && !!Lock.sheetFrom
        onTriggered: pk.track()
    }

    // a click off the menu only closes it, as a menu's would
    MouseArea {
        anchors.fill: parent
        enabled: Lock.sheet !== ""
        acceptedButtons: Qt.AllButtons
        onClicked: Lock.closeSheet()
        onWheel: (wheel) => {
            wheel.accepted = true;
        }
    }

    // the keys are the menu's while it is up: none of them reach the field
    Item {
        id: keys

        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Up:
            case Qt.Key_Backtab:
                pk.move(-1);
                break;
            case Qt.Key_Down:
            case Qt.Key_Tab:
                pk.move(1);
                break;
            case Qt.Key_PageUp:
                pk.move(-5);
                break;
            case Qt.Key_PageDown:
                pk.move(5);
                break;
            case Qt.Key_Home:
                pk.move(-pk.count);
                break;
            case Qt.Key_End:
                pk.move(pk.count);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                pk.choose(pk.hi);
                break;
            case Qt.Key_Escape:
            case Qt.Key_Backspace:
                Lock.closeSheet();
                break;
            default:
                if (event.text !== "" && /\S/.test(event.text))
                    pk.seek(event.text);

            }
            event.accepted = true;
        }
    }

    // ── the menu ───────────────────────────────────────────────────────────
    Item {
        id: holder

        x: pk.panelX
        y: pk.panelY
        width: pk.panelW
        height: pk.panelH
        opacity: pk.f
        // a menu on its way out takes no more clicks: they belong to what is
        // under it again
        enabled: Lock.sheet !== "" && Lock.sheet === pk.kind

        // it grows out of the asking item, as m3's menus scale in from their anchor
        transform: Scale {
            origin.x: Math.max(0, Math.min(pk.panelW, pk.from.x + pk.from.width / 2 - pk.panelX))
            origin.y: pk.above ? pk.panelH : 0
            xScale: 0.8 + 0.2 * pk.k
            yScale: 0.8 + 0.2 * pk.k
        }

        // a press on the menu's own gaps stays on the menu
        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => {
                mouse.accepted = true;
            }
            onWheel: (wheel) => {
                wheel.accepted = false;
            }
        }

        Flickable {
            id: flick

            anchors.fill: parent
            contentWidth: width
            contentHeight: pk.fullH
            interactive: pk.fullH > height + 1
            clip: interactive
            boundsBehavior: Flickable.StopAtBounds

            Column {
                width: flick.width
                spacing: pk.groupGap

                Repeater {
                    model: pk.kind === "" ? 0 : (pk.twoGroups ? 2 : 1)

                    // a group: its own surface, rounder while it holds the row in use
                    Item {
                        id: group

                        required property int index
                        readonly property int first: group.index === 0 ? 0 : pk.accounts
                        readonly property int rows: group.index === 0 ? pk.firstCount : 1
                        readonly property bool active: pk.hi >= group.first && pk.hi < group.first + group.rows
                        property real r: group.active ? pk.groupActive : pk.groupRest

                        width: parent.width
                        height: pk.groupH(group.rows)

                        Behavior on r {
                            NumberAnimation {
                                duration: Theme.ms(320)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveDefaultSpatial
                            }

                        }

                        // m3 level 2
                        RectangularShadow {
                            anchors.fill: parent
                            radius: group.r
                            blur: Theme.dp(10)
                            offset: Qt.vector2d(0, Theme.dp(3))
                            color: Qt.rgba(0, 0, 0, 0.32)
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: group.r
                            color: Theme.cardLow
                        }

                        Repeater {
                            model: group.rows

                            Item {
                                id: row

                                required property int index
                                readonly property int i: group.first + row.index
                                readonly property bool firstChild: row.index === 0
                                readonly property bool lastChild: row.index === group.rows - 1
                                readonly property bool other: pk.users && row.i >= pk.accounts
                                readonly property var acct: pk.users && !row.other ? Lock.accounts[row.i] : null
                                readonly property bool picked: row.i === pk.current
                                readonly property bool lit: row.i === pk.hi
                                readonly property string title: pk.titleOf(row.i)
                                readonly property string sub: pk.subOf(row.i)
                                readonly property string trail: pk.trailOf(row.i)
                                // the item's corners: 12dp where they meet the group's
                                // edge, 4dp between items, 12dp all round once chosen
                                readonly property int topR: row.firstChild || row.picked ? pk.itemOuter : pk.itemInner
                                readonly property int bottomR: row.lastChild || row.picked ? pk.itemOuter : pk.itemInner
                                // its turn in the entrance, counted out from the asking item
                                readonly property int order: pk.above ? pk.count - 1 - row.i : row.i
                                readonly property real appear: Math.max(0, Math.min(1, (pk.k - 0.15 - row.order * 0.04) / 0.5))

                                x: pk.groupPad
                                y: pk.groupPad + row.index * pk.rowH
                                width: group.width - pk.groupPad * 2
                                height: pk.rowH
                                opacity: row.appear

                                transform: Translate {
                                    y: (1 - row.appear) * Theme.dp(6) * (pk.above ? 1 : -1)
                                }

                                // chosen: the tertiary container
                                Rectangle {
                                    anchors.fill: parent
                                    topLeftRadius: row.topR
                                    topRightRadius: row.topR
                                    bottomLeftRadius: row.bottomR
                                    bottomRightRadius: row.bottomR
                                    color: Theme.accentContainer
                                    visible: row.picked
                                }

                                // hover, press, and the keyboard's place
                                Rectangle {
                                    anchors.fill: parent
                                    topLeftRadius: row.topR
                                    topRightRadius: row.topR
                                    bottomLeftRadius: row.bottomR
                                    bottomRightRadius: row.bottomR
                                    color: row.picked ? Theme.fgAccentContainer : Theme.text
                                    opacity: rowArea.pressed ? Theme.statePressed : (row.lit && (rowArea.containsMouse || pk.kbd) ? Theme.stateHover : 0)

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.ms(120)
                                        }

                                    }

                                }

                                Rectangle {
                                    anchors.fill: parent
                                    topLeftRadius: row.topR
                                    topRightRadius: row.topR
                                    bottomLeftRadius: row.bottomR
                                    bottomRightRadius: row.bottomR
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.accent
                                    visible: pk.kbd && row.lit
                                }

                                // an account's face, or a person to add
                                Item {
                                    id: leadBox

                                    x: pk.side
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: pk.lead
                                    height: pk.lead
                                    visible: pk.lead > 0

                                    Avatar {
                                        anchors.fill: parent
                                        source: row.acct ? row.acct.icon : ""
                                        initials: row.acct ? Lock.initialsOf(Lock.nameOf(row.acct)) : ""
                                        visible: !!row.acct
                                    }

                                    Glyph {
                                        anchors.centerIn: parent
                                        name: "personAdd"
                                        size: pk.iconSize
                                        color: row.picked ? Theme.fgAccentContainer : Theme.subtext
                                        visible: row.other
                                    }

                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: pk.side + (pk.lead > 0 ? pk.lead + pk.between : 0)
                                    anchors.right: trailRow.left
                                    anchors.rightMargin: pk.between
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.dp(1)

                                    Text {
                                        width: parent.width
                                        text: row.title
                                        elide: Text.ElideRight
                                        color: row.picked ? Theme.fgAccentContainer : Theme.text
                                        font: labelSize.font
                                    }

                                    Text {
                                        width: parent.width
                                        text: row.sub
                                        elide: Text.ElideRight
                                        color: row.picked ? Theme.fgAccentContainer : Theme.subtext
                                        font: subSize.font
                                        visible: row.sub !== ""
                                    }

                                }

                                // trailing: the supporting text, then the check
                                Row {
                                    id: trailRow

                                    anchors.right: parent.right
                                    anchors.rightMargin: pk.side
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: pk.between

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: row.trail
                                        color: row.picked ? Theme.fgAccentContainer : Theme.subtext
                                        font: tagSize.font
                                        visible: row.trail !== ""
                                    }

                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: pk.iconSize
                                        height: pk.iconSize

                                        Glyph {
                                            anchors.centerIn: parent
                                            name: "check"
                                            size: pk.iconSize
                                            color: Theme.fgAccentContainer
                                            opacity: row.picked ? 1 : 0
                                            scale: row.picked ? 1 : 0.5

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: Theme.ms(300)
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: Theme.curveFastSpatial
                                                }

                                            }

                                        }

                                    }

                                }

                                // a MouseArea, not a TapHandler: it keeps the click, which
                                // would otherwise also reach whatever sits under the menu
                                MouseArea {
                                    id: rowArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: {
                                        if (rowArea.containsMouse) {
                                            pk.kbd = false;
                                            pk.hi = row.i;
                                        }
                                    }
                                    // locals first: picking can rebuild the rows under this one
                                    onClicked: {
                                        var i = row.i;
                                        var p = pk;
                                        p.choose(i);
                                    }
                                }

                            }

                        }

                    }

                }

            }

        }

    }

}
