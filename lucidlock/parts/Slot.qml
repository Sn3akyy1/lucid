import QtQuick
import "Catalog.js" as Catalog

// one of a preset's places for widgets: a column, or a row, in the order the
// user put them. it arrives on its own beat, and steps back while a password
// is typed unless it is the thing being typed into
Item {
    id: sl

    property var stage: null
    property string slotId: ""
    property bool row: false
    property int align: Qt.AlignLeft
    // the room its widgets may take across, and down
    property real maxWidth: 480
    property real maxHeight: 2000
    property real gap: sl.stage ? sl.stage.dp(16) : 16
    property bool cards: false
    // laid on a surface of the preset's own, rather than on the wallpaper
    property bool onCard: false
    // its turn in the arrival, 0..1
    property real delay: 0
    // how far it rises into place, in px; negative falls from above. riseX
    // slides it in from the side instead
    property real rise: 24
    property real riseX: 0
    // how much it fades while a password is typed. 0 stays, and stays live
    property real dim: 0.6
    // what a clock in here shrinks to while a password is typed
    property real shrinkTo: 1
    // the widgets, in order, as one string: it changes only when this slot's
    // own list does, and the rows below are edited to match rather than
    // rebuilt, so a widget moved within the slot is the same widget, still
    // holding the pointer if it is the one being dragged
    readonly property string typesKey: sl.stage ? sl.stage.typesOf(sl.slotId).join(",") : ""
    readonly property var types: sl.typesKey === "" ? [] : sl.typesKey.split(",")
    readonly property var info: sl.stage ? Catalog.slotOf(sl.stage.layout.preset, sl.slotId) : null
    readonly property bool editing: !!sl.stage && sl.stage.editing
    readonly property real editK: sl.stage ? sl.stage.editK : 0
    readonly property real cs: sl.stage ? sl.stage.chromeScale : 1
    readonly property real arrive: sl.stage ? sl.stage.rv(sl.delay) : 1
    readonly property bool empty: grid.implicitWidth <= 0 || grid.implicitHeight <= 0
    // anything is being dragged, anywhere
    readonly property bool carrying: !!sl.stage && sl.stage.dragType !== ""
    // how present the outline is: faint at rest, nearer under the pointer or
    // while something is carried, full where it would land
    readonly property real presence: sl.target ? 1 : (sl.carrying ? 0.7 : (slotHover.hovered || sl.empty ? 0.55 : 0.28))
    // a drag is over this slot
    readonly property bool target: !!sl.stage && sl.stage.dragType !== "" && !!sl.stage.dragTarget && sl.stage.dragTarget.slot === sl.slotId
    // the editor's chrome is drawn a constant size on screen and laid over the
    // slot, so editing never moves a widget; only an empty slot takes room
    readonly property real addSize: sl.dp(28) / sl.cs
    readonly property real ring: sl.dp(12) / sl.cs
    readonly property real holeW: Math.max(sl.dp(220), sl.dp(150) / sl.cs)
    readonly property real holeH: Math.max(sl.dp(72), sl.dp(36) / sl.cs)

    function dp(px) {
        return sl.stage ? sl.stage.dp(px) : px;
    }

    function xFor(w, boxW) {
        if (sl.align === Qt.AlignHCenter)
            return Math.round((boxW - w) / 2);

        if (sl.align === Qt.AlignRight)
            return Math.round(boxW - w);

        return 0;
    }

    // the rows brought in line with the list: moves where a widget is already
    // here, inserts where it is not, and the leftovers taken off the end
    function sync() {
        // off the key itself: in its own change handler, `types` can still
        // hold the list from before
        var want = sl.typesKey === "" ? [] : sl.typesKey.split(",");
        for (var i = 0; i < want.length; i++) {
            if (i < rows.count && rows.get(i).type === want[i])
                continue;

            var found = -1;
            for (var j = i + 1; j < rows.count; j++) {
                if (rows.get(j).type === want[i]) {
                    found = j;
                    break;
                }
            }
            if (found !== -1)
                rows.move(found, i, 1);
            else
                rows.insert(i, {
                "type": want[i]
            });
        }
        while (rows.count > want.length)
            rows.remove(rows.count - 1)
    }

    function indexOf(type) {
        return sl.types.indexOf(type);
    }

    // the widgets as laid out, in order
    function hosts() {
        var out = [];
        for (var i = 0; i < repeater.count; i++) {
            var h = repeater.itemAt(i);
            if (h)
                out.push(h);

        }
        return out;
    }

    // where a point would put a widget: how many of the others it is past,
    // across a row or down a column, the dragged one and its gap not counted
    function indexAt(p) {
        var n = 0;
        var list = sl.hosts();
        for (var i = 0; i < list.length; i++) {
            var h = list[i];
            if (!h.visible || h.width <= 0 || h.type === "__drop__" || h.type === sl.stage.dragType)
                continue;

            var c = h.mapToItem(sl.stage, h.width / 2, h.height / 2);
            if (sl.row ? p.x > c.x : p.y > c.y)
                n += 1;

        }
        return n;
    }

    implicitWidth: sl.editing && sl.empty ? sl.holeW : grid.implicitWidth
    implicitHeight: sl.editing && sl.empty ? sl.holeH : grid.implicitHeight
    opacity: sl.arrive * (1 - (sl.stage ? sl.stage.focusK : 0) * sl.dim)
    // a slot that steps back takes no clicks: one out there only buys the
    // resting face back, so nothing is pressed by accident mid-password
    enabled: sl.dim === 0 || !sl.stage || sl.stage.glanceLive || sl.editing
    onTypesKeyChanged: sl.sync()
    Component.onCompleted: {
        sl.sync();
        if (sl.stage)
            sl.stage.registerSlot(sl);

    }
    Component.onDestruction: {
        if (sl.stage)
            sl.stage.unregisterSlot(sl);

    }

    ListModel {
        id: rows
    }

    // passive: it only tells the outline the pointer is near
    HoverHandler {
        id: slotHover

        enabled: sl.editing
        margin: sl.ring
    }

    transform: Translate {
        x: (1 - sl.arrive) * sl.riseX
        y: (1 - sl.arrive) * sl.rise
    }

    // ── the editor's view of the slot, under its widgets ────────────────────
    // tonal: a faint wash where nothing is yet, a stronger one where a drag
    // would land
    Rectangle {
        anchors.fill: parent
        anchors.margins: -sl.ring
        visible: opacity > 0.01
        radius: (sl.stage ? sl.stage.theme.shapeXl : 24) + sl.ring
        color: sl.stage ? sl.stage.theme.accent : "white"
        opacity: sl.editK * (sl.target ? 0.14 : (sl.empty ? 0.05 : 0))

        Behavior on opacity {
            NumberAnimation {
                duration: sl.stage ? sl.stage.theme.ms(180) : 180
                easing.type: Easing.OutCubic
            }

        }

    }

    DashedBox {
        id: outline

        property real shown: sl.presence

        anchors.fill: parent
        anchors.margins: -sl.ring
        visible: sl.editK > 0.01
        opacity: sl.editK * outline.shown
        radius: (sl.stage ? sl.stage.theme.shapeXl : 24) + sl.ring
        line: (sl.target ? 2.5 : 1.5) / sl.cs
        dash: (sl.target ? 9 : 6) / sl.cs
        color: sl.stage ? sl.stage.theme.accent : "white"

        Behavior on shown {
            NumberAnimation {
                duration: sl.stage ? sl.stage.theme.ms(200) : 200
                easing.type: Easing.OutCubic
            }

        }

    }

    Grid {
        id: grid

        x: sl.xFor(grid.width, sl.width)
        columns: sl.row ? Math.max(1, rows.count) : 1
        columnSpacing: sl.gap
        rowSpacing: sl.gap
        horizontalItemAlignment: sl.align === Qt.AlignHCenter ? Grid.AlignHCenter : (sl.align === Qt.AlignRight ? Grid.AlignRight : Grid.AlignLeft)
        verticalItemAlignment: Grid.AlignVCenter

        Repeater {
            id: repeater

            model: rows

            WidgetHost {
                slot: sl
            }

        }

    }

    // the slot's name, so an empty one says what it is
    Text {
        id: label

        visible: sl.editK > 0.01 && sl.empty
        opacity: sl.editK
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: sl.addSize * 0.7
        text: sl.info ? sl.stage.tr(sl.info.name) : sl.slotId // i18n-dynamic
        color: sl.stage ? sl.stage.theme.subtext : "white"
        font.family: sl.stage ? sl.stage.theme.fontFamily : ""
        font.pixelSize: Math.round((sl.stage ? sl.stage.theme.fontLabelLg : 13) / sl.cs)
        font.weight: Font.Medium
    }

    // add a widget here
    Rectangle {
        id: add

        readonly property real addLabelShift: sl.empty ? Math.min(sl.holeW * 0.3, label.implicitWidth / 2 + sl.addSize * 0.2) : 0

        visible: opacity > 0.01
        opacity: sl.editK * (sl.carrying ? 0 : 1)
        scale: (0.6 + 0.4 * sl.editK) * (addArea.pressed ? 0.9 : (addArea.containsMouse ? 1.12 : 1))
        width: sl.addSize
        height: sl.addSize
        // m3 expressive: square-ish at rest, round under the pointer
        radius: addArea.containsMouse ? width / 2 : width * 0.32

        Behavior on radius {
            NumberAnimation {
                duration: sl.stage ? sl.stage.theme.ms(220) : 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: sl.stage ? sl.stage.theme.curveFastSpatial : [0.42, 1.67, 0.21, 0.9, 1, 1]
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: sl.stage ? sl.stage.theme.ms(150) : 150
            }

        }

        // on the outline: inside an empty slot, else on its trailing edge
        x: sl.empty ? (sl.width / 2 - width / 2 - addLabelShift) : (sl.row ? sl.width + sl.ring - width / 2 : sl.xFor(width, sl.width))
        y: sl.empty ? (sl.height - height) / 2 : (sl.row ? (sl.height - height) / 2 : sl.height + sl.ring - height / 2)
        color: sl.stage ? (addArea.containsMouse ? sl.stage.theme.accent : sl.stage.theme.accentContainer) : "grey"

        Behavior on color {
            ColorAnimation {
                duration: sl.stage ? sl.stage.theme.ms(140) : 140
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: sl.stage ? sl.stage.theme.ms(220) : 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: sl.stage ? sl.stage.theme.curveFastSpatial : [0.42, 1.67, 0.21, 0.9, 1, 1]
            }

        }

        Glyph {
            anchors.centerIn: parent
            name: "add"
            size: sl.addSize * 0.55
            color: sl.stage ? (addArea.containsMouse ? sl.stage.theme.fgAccent : sl.stage.theme.fgAccentContainer) : "white"
        }

        MouseArea {
            id: addArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sl.stage.slotPicked(sl.slotId)
        }

    }

}
