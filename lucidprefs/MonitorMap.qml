import QtQuick
import qs
import "MonitorLayout.js" as Layout

// the outputs laid out the way hyprland sees them, drag one to move it. the
// box follows the pointer while an outline shows where it will land: always
// against a neighbour, never on top of one, so there are no gaps to leave the
// pointer stranded in. nothing is applied until it is let go. a click picks a
// box, and the arrow keys then move it the same way, Enter to put it there
Item {
    id: map

    // how close an edge has to come to line up with another, in map pixels
    readonly property int snapPx: 14
    // how far a press has to travel before it is a drag rather than a click
    readonly property int dragPx: 4
    // a lone display has nothing to line up with, and the view re-centres on it
    // under the pointer, so a drag would only run away with its position
    readonly property bool movable: map.placed.length > 1
    property string held: ""
    property bool dragging: false
    // moved with the arrow keys rather than the pointer
    property bool byKeys: false
    // where the held box is under the pointer, and where it would land
    property point dragPos: Qt.point(0, 0)
    property point landPos: Qt.point(0, 0)
    property bool canLand: false
    // what had the keyboard before the map took it
    property Item keysBefore: null
    // the display the page is pointed at
    property string selected: ""
    // the box under the pointer, "" for none
    property string hovered: ""

    // a click picks a box, a double click goes to its settings
    signal picked(string key)
    signal opened(string key)

    // the outputs that take a place in the layout; one switched off has none,
    // and a mirror sits wherever its source does
    readonly property var placed: Monitors.keys.filter((k) => {
        return Monitors.output(k) !== null && Monitors.isOn(k) && Monitors.mirrorOf(k) === "";
    })

    function rectOf(key) {
        const p = Monitors.posOf(key);
        const s = Monitors.layoutSize(key);
        return {
            "x": p.x,
            "y": p.y,
            "w": s.w,
            "h": s.h
        };
    }

    // the whole layout in hyprland's own coordinates, with room around it for
    // a display to be put on any side of the others. nothing is written while
    // a box is held, so this holds still under the pointer until it is let go
    readonly property var bounds: {
        let x0 = 0;
        let y0 = 0;
        let x1 = 0;
        let y1 = 0;
        let bigW = 0;
        let bigH = 0;
        let first = true;
        for (const key of map.placed) {
            const r = map.rectOf(key);
            bigW = Math.max(bigW, r.w);
            bigH = Math.max(bigH, r.h);
            if (first) {
                x0 = r.x;
                y0 = r.y;
                x1 = r.x + r.w;
                y1 = r.y + r.h;
                first = false;
            } else {
                x0 = Math.min(x0, r.x);
                y0 = Math.min(y0, r.y);
                x1 = Math.max(x1, r.x + r.w);
                y1 = Math.max(y1, r.y + r.h);
            }
        }
        if (first)
            return {
                "x": 0,
                "y": 0,
                "w": 1920,
                "h": 1080
            };

        const padX = Math.max(160, map.movable ? bigW * 0.6 : (x1 - x0) * 0.1);
        const padY = Math.max(160, map.movable ? bigH * 0.6 : (y1 - y0) * 0.1);
        return {
            "x": x0 - padX,
            "y": y0 - padY,
            "w": (x1 - x0) + padX * 2,
            "h": (y1 - y0) + padY * 2
        };
    }
    readonly property real fit: Math.min((frame.width - 20) / map.bounds.w, (frame.height - 20) / map.bounds.h)
    readonly property real offX: frame.width / 2 - (map.bounds.x + map.bounds.w / 2) * map.fit
    readonly property real offY: frame.height / 2 - (map.bounds.y + map.bounds.h / 2) * map.fit

    // the page can be closed with the pointer still on a box, which would
    // leave its number up on the real display
    readonly property bool onScreen: map.visible && map.Window.window !== null && map.Window.window.visible
    // the box whose number is on its real display: the one held, or the one
    // under the pointer once it has rested there a moment
    readonly property string pointing: !map.onScreen || !map.movable ? "" : (map.dragging ? map.held : map.hovered)

    onPointingChanged: {
        if (map.pointing === "") {
            pointRest.stop();
            if (Monitors.pointedAt !== "")
                Monitors.pointedAt = "";

        } else if (map.dragging) {
            Monitors.pointedAt = map.pointing;
        } else {
            pointRest.restart();
        }
    }
    Component.onDestruction: {
        if (Monitors.pointedAt !== "")
            Monitors.pointedAt = "";

    }

    Timer {
        id: pointRest

        interval: 300
        onTriggered: Monitors.pointedAt = map.pointing
    }

    // the keyboard comes to the map when a box is picked, and goes back to
    // whatever had it once the map is done with it
    function takeKeys() {
        if (map.activeFocus)
            return ;

        map.keysBefore = map.Window.activeFocusItem;
        map.forceActiveFocus();
    }

    function giveKeysBack() {
        const to = map.keysBefore;
        map.keysBefore = null;
        if (to)
            to.forceActiveFocus();
        else
            map.focus = false;
    }

    function begin(key, byKeys) {
        map.held = key;
        map.byKeys = byKeys;
        map.dragging = true;
        const r = map.rectOf(key);
        map.dragPos = Qt.point(r.x, r.y);
        map.landPos = Qt.point(r.x, r.y);
        map.canLand = true;
        map.takeKeys();
    }

    // the held box under the pointer (at least half of it kept in view), and
    // where it would land. the arrows step exactly, so they skip the snapping,
    // which would pull a small step straight back
    function follow(key, wantX, wantY) {
        const s = Monitors.layoutSize(key);
        const x = Math.max(map.bounds.x - s.w / 2, Math.min(map.bounds.x + map.bounds.w - s.w / 2, wantX));
        const y = Math.max(map.bounds.y - s.h / 2, Math.min(map.bounds.y + map.bounds.h - s.h / 2, wantY));
        map.dragPos = Qt.point(x, y);
        const others = map.placed.filter((k) => {
            return k !== key;
        }).map((k) => {
            return map.rectOf(k);
        });
        const spot = Layout.land(s, {
            "x": x,
            "y": y
        }, others, map.byKeys ? 0 : map.snapPx / map.fit);
        map.canLand = spot !== null;
        if (spot)
            map.landPos = Qt.point(spot.x, spot.y);

    }

    // an arrow nudges the held box by half its size, or a twentieth with
    // Shift, so a few presses take it round to another side of its neighbour
    // and Shift slides it along the edge it is on
    function nudge(dx, dy, fine) {
        const key = map.selected;
        if (!map.movable || map.placed.indexOf(key) < 0)
            return ;

        if (!map.dragging)
            map.begin(key, true);

        const s = Monitors.layoutSize(key);
        const step = fine ? 20 : 2;
        map.follow(key, map.dragPos.x + dx * s.w / step, map.dragPos.y + dy * s.h / step);
    }

    function finish() {
        const byKeys = map.byKeys;
        map.dragging = false;
        map.byKeys = false;
        map.held = "";
        // the arrows keep the keyboard for another move; a drag hands it back
        if (!byKeys)
            map.giveKeysBack();

    }

    // the whole layout written at once, its corner at 0,0, so the drop is one
    // apply; a box let go where it started changes nothing
    function commit(key) {
        const from = map.rectOf(key);
        if (map.canLand && (map.landPos.x !== from.x || map.landPos.y !== from.y)) {
            const positions = {};
            for (const k of map.placed) {
                const r = map.rectOf(k);
                positions[k] = k === key ? {
                    "x": map.landPos.x,
                    "y": map.landPos.y
                } : {
                    "x": r.x,
                    "y": r.y
                };
            }
            Monitors.place(Layout.normalise(positions));
        }
        map.finish();
    }

    implicitHeight: Math.max(Theme.dp(180), Math.min(Theme.dp(420), map.width * map.bounds.h / map.bounds.w))
    // keys the map does not use (typing to search, Escape to close) still
    // reach whatever had them, except mid-move, where Escape is the map's
    Keys.forwardTo: !map.dragging && map.keysBefore ? [map.keysBefore] : []
    Keys.onPressed: (event) => {
        const fine = (event.modifiers & Qt.ShiftModifier) !== 0;
        if (event.key === Qt.Key_Left)
            map.nudge(-1, 0, fine);
        else if (event.key === Qt.Key_Right)
            map.nudge(1, 0, fine);
        else if (event.key === Qt.Key_Up)
            map.nudge(0, -1, fine);
        else if (event.key === Qt.Key_Down)
            map.nudge(0, 1, fine);
        else if (map.dragging && map.byKeys && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space))
            map.commit(map.held);
        else if (map.dragging && event.key === Qt.Key_Escape)
            map.finish();
        else
            return ;
        event.accepted = true;
    }
    onActiveFocusChanged: {
        if (map.activeFocus)
            return ;

        // something else took the keyboard: a move by keys is dropped
        map.keysBefore = null;
        if (map.dragging && map.byKeys)
            map.finish();

    }

    Rectangle {
        id: frame

        anchors.fill: parent
        radius: Theme.radiusXl
        color: Theme.bgSunken
        clip: true

        // where the held display will go when it is let go
        Rectangle {
            readonly property var size: map.held !== "" ? Monitors.layoutSize(map.held) : ({
                "w": 0,
                "h": 0
            })

            visible: map.dragging && !map.byKeys && map.canLand
            x: map.offX + map.landPos.x * map.fit
            y: map.offY + map.landPos.y * map.fit
            width: Math.max(Theme.dp(34), size.w * map.fit)
            height: Math.max(Theme.dp(26), size.h * map.fit)
            radius: Theme.shapeSm
            color: Theme.alpha(Theme.accent, 0.14)
            border.width: 2
            border.color: Theme.accent
            z: 1.5
        }

        Repeater {
            model: Monitors.keys

            Rectangle {
                id: plate

                required property string modelData
                readonly property var out: Monitors.output(plate.modelData)
                readonly property var size: Monitors.layoutSize(plate.modelData)
                readonly property var pos: Monitors.posOf(plate.modelData)
                readonly property bool lifted: map.dragging && map.held === plate.modelData
                // moved by the arrows, the box itself shows where it lands
                readonly property point at: !plate.lifted ? Qt.point(plate.pos.x, plate.pos.y) : (map.byKeys ? map.landPos : map.dragPos)
                readonly property bool lit: drag.containsMouse || map.held === plate.modelData
                readonly property bool chosen: map.selected === plate.modelData
                readonly property bool hasBar: Monitors.barKeys.indexOf(plate.modelData) >= 0
                readonly property color ink: plate.lit ? Theme.fgAccent : Theme.text
                readonly property color inkDim: plate.lit ? Theme.fgAccent : Theme.subtextDim

                visible: plate.out !== null && map.placed.indexOf(plate.modelData) >= 0
                width: Math.max(Theme.dp(34), plate.size.w * map.fit)
                height: Math.max(Theme.dp(26), plate.size.h * map.fit)
                x: map.offX + plate.at.x * map.fit
                y: map.offY + plate.at.y * map.fit
                radius: Theme.shapeSm
                color: plate.lit ? Theme.accent : Theme.bgActive
                opacity: plate.lifted && !map.byKeys ? 0.85 : 1
                border.width: plate.chosen && !plate.lit ? (map.activeFocus ? 3 : 2) : 0
                border.color: Theme.accent
                z: plate.lit ? 2 : 1

                // the bar, along the top
                Rectangle {
                    visible: plate.hasBar && plate.height > 30
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.dp(5)
                    y: Theme.dp(4)
                    height: Theme.dp(3)
                    radius: 1.5
                    color: plate.inkDim
                    opacity: 0.7
                }

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: Theme.dp(6)
                    anchors.topMargin: plate.hasBar ? Theme.dp(10) : Theme.dp(6)
                    visible: plate.height > 44
                    text: Monitors.numberFor(plate.modelData)
                    color: plate.inkDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    font.weight: Font.DemiBold
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.dp(12)
                    spacing: 1

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: Monitors.shortLabel(plate.modelData)
                        color: plate.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                        font.variableAxes: Theme.axes(Theme.fontLabelLg, 600, 0)
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: plate.out ? plate.out.name + "  ·  " + plate.size.w + " × " + plate.size.h : ""
                        color: plate.inkDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
                        visible: plate.height > 44
                    }

                }

                MouseArea {
                    id: drag

                    // the press point in the box, so the box does not jump to
                    // the pointer as the drag starts
                    property real pressX: 0
                    property real pressY: 0

                    anchors.fill: parent
                    hoverEnabled: true
                    // the settings pane scrolls, and would take a vertical drag
                    preventStealing: true
                    cursorShape: !map.movable ? Qt.PointingHandCursor : (plate.lifted ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                    onContainsMouseChanged: {
                        if (drag.containsMouse)
                            map.hovered = plate.modelData;
                        else if (map.hovered === plate.modelData)
                            map.hovered = "";
                    }
                    onPressed: (mouse) => {
                        // a move by keys still going is put down first
                        if (map.dragging)
                            map.finish();

                        map.held = plate.modelData;
                        drag.pressX = mouse.x;
                        drag.pressY = mouse.y;
                    }
                    onPositionChanged: (mouse) => {
                        if (map.held !== plate.modelData || !map.movable)
                            return ;

                        if (!map.dragging) {
                            if (Math.hypot(mouse.x - drag.pressX, mouse.y - drag.pressY) < map.dragPx)
                                return ;

                            map.begin(plate.modelData, false);
                        }
                        // the pointer in the frame, back into the layout
                        const fx = plate.x + mouse.x - drag.pressX;
                        const fy = plate.y + mouse.y - drag.pressY;
                        map.follow(plate.modelData, (fx - map.offX) / map.fit, (fy - map.offY) / map.fit);
                    }
                    // Escape already let go of it, so this release is no pick
                    onReleased: {
                        if (map.held !== plate.modelData)
                            return ;

                        if (map.dragging) {
                            map.commit(plate.modelData);
                        } else {
                            map.held = "";
                            map.picked(plate.modelData);
                            map.takeKeys();
                        }
                    }
                    onDoubleClicked: map.opened(plate.modelData)
                    onCanceled: {
                        if (map.held === plate.modelData)
                            map.finish();

                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

                Behavior on x {
                    enabled: !plate.lifted || map.byKeys

                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

                Behavior on y {
                    enabled: !plate.lifted || map.byKeys

                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

            }

        }

    }

}
