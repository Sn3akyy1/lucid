import QtQuick
import qs

// Prefs.barLayout as three lanes, one per group of the bar, each lined up the
// way the bar lines it up: against the left edge, around the middle, against
// the right edge. a chip drags along its lane or into another, and the arrow
// keys move the focused one (left/right along the bar, up/down between lanes)
Item {
    id: editor

    readonly property var sides: ["left", "center", "right"]
    readonly property var sideNames: ({
        "left": "Left",
        "center": "Centre",
        "right": "Right"
    })
    readonly property var modules: ({
        "workspaces": {
            "name": "Workspaces",
            "key": "showWorkspaces"
        },
        "media": {
            "name": "Media",
            "key": "showMedia"
        },
        "tray": {
            "name": "System tray",
            "key": "showTray"
        },
        "clock": {
            "name": "Clock",
            "key": "showClock"
        },
        "notifications": {
            "name": "Notifications",
            "key": "showNotifications"
        },
        "system": {
            "name": "System",
            "key": "showSystem"
        }
    })
    readonly property int labelWidth: 64
    readonly property int laneHeight: 48
    readonly property int laneGap: 8
    readonly property int lanePad: 7
    readonly property int chipHeight: 34
    readonly property int chipGap: 6
    // grip, its gap and the padding either side of it and the name
    readonly property int chipChrome: 14 + 8 + 8 + 16
    readonly property real laneWidth: Math.max(0, editor.width - editor.labelWidth)
    property bool dragging: false
    property string dragSide: ""
    // bumped whenever the model changes, so the slots below are worked out again
    property int revision: 0
    readonly property var slots: editor.layout(editor.revision, editor.width)

    function laneY(i) {
        return i * (editor.laneHeight + editor.laneGap);
    }

    function sideAt(y) {
        const i = Math.floor((y + editor.laneGap / 2) / (editor.laneHeight + editor.laneGap));
        return editor.sides[Math.max(0, Math.min(2, i))];
    }

    function groups() {
        const out = {
            "left": [],
            "center": [],
            "right": []
        };
        for (let i = 0; i < chips.count; i++) {
            const c = chips.get(i);
            out[c.side].push(c.mid);
        }
        return out;
    }

    // x, y and width of every chip, from the model's order and the lane widths
    function layout(revision, width) {
        void metrics.font;
        const out = {};
        const g = editor.groups();
        for (let s = 0; s < 3; s++) {
            const ids = g[editor.sides[s]];
            if (ids.length === 0)
                continue;

            const natural = ids.map((id) => {
                return Math.ceil(metrics.advanceWidth(editor.modules[id].name)) + editor.chipChrome;
            });
            const gaps = editor.chipGap * (ids.length - 1);
            const room = editor.laneWidth - editor.lanePad * 2 - gaps;
            // too many for one lane: the longest names give way first, down to
            // a common width, so the short ones still read in full
            let cap = Infinity;
            const sorted = natural.slice().sort((a, b) => {
                return a - b;
            });
            let spare = Math.max(0, room);
            for (let i = 0; i < sorted.length; i++) {
                const share = spare / (sorted.length - i);
                if (sorted[i] > share) {
                    cap = share;
                    break;
                }
                spare -= sorted[i];
            }
            const widths = natural.map((w) => {
                return Math.floor(Math.min(w, cap));
            });
            const total = widths.reduce((a, b) => {
                return a + b;
            }, 0) + gaps;
            let x = editor.labelWidth + editor.lanePad;
            if (editor.sides[s] === "center")
                x = editor.labelWidth + (editor.laneWidth - total) / 2;
            else if (editor.sides[s] === "right")
                x = editor.labelWidth + editor.laneWidth - editor.lanePad - total;
            for (let i = 0; i < ids.length; i++) {
                out[ids[i]] = {
                    "x": Math.round(x),
                    "y": editor.laneY(s) + (editor.laneHeight - editor.chipHeight) / 2,
                    "w": widths[i]
                };
                x += widths[i] + editor.chipGap;
            }
        }
        return out;
    }

    // brings the model round to Prefs by moves, so the chips glide into place
    function load() {
        const g = Prefs.barLayoutGroups;
        const order = [];
        for (const side of editor.sides) {
            for (const id of g[side]) order.push({
                "mid": id,
                "side": side
            })
        }
        if (chips.count !== order.length) {
            chips.clear();
            for (const o of order) chips.append(o)
        } else {
            for (let i = 0; i < order.length; i++) {
                let from = i;
                while (from < chips.count && chips.get(from).mid !== order[i].mid)
                    from++;
                if (from !== i)
                    chips.move(from, i, 1);

                if (chips.get(i).side !== order[i].side)
                    chips.setProperty(i, "side", order[i].side);

            }
        }
        editor.revision++;
    }

    function indexOf(mid) {
        for (let i = 0; i < chips.count; i++) {
            if (chips.get(i).mid === mid)
                return i;

        }
        return -1;
    }

    // puts the dragged chip in the lane under its centre, in front of the
    // first chip there whose centre it hasn't passed yet
    function reorder(mid, cx, cy) {
        const side = editor.sideAt(cy);
        const from = editor.indexOf(mid);
        const others = [];
        for (let i = 0; i < chips.count; i++) {
            const c = chips.get(i);
            if (c.mid === mid || c.side !== side)
                continue;

            const slot = editor.slots[c.mid];
            others.push({
                "index": i,
                "centre": slot ? slot.x + slot.w / 2 : 0
            });
        }
        let rank = 0;
        while (rank < others.length && others[rank].centre < cx)
            rank++;
        let target = from;
        if (rank < others.length)
            target = others[rank].index;
        else if (others.length > 0)
            target = others[others.length - 1].index + 1;
        const to = from < target ? target - 1 : target;
        let changed = false;
        if (to !== from) {
            chips.move(from, to, 1);
            changed = true;
        }
        if (chips.get(to).side !== side) {
            chips.setProperty(to, "side", side);
            changed = true;
        }
        editor.dragSide = side;
        if (changed)
            editor.revision++;

    }

    // left/right walks the whole bar, crossing into the next group at its end
    function step(mid, delta) {
        const g = editor.groups();
        const s = editor.sides.findIndex((side) => {
            return g[side].indexOf(mid) >= 0;
        });
        const inSide = g[editor.sides[s]];
        const pos = inSide.indexOf(mid);
        if (delta < 0 && pos === 0) {
            if (s === 0)
                return ;

            inSide.splice(pos, 1);
            g[editor.sides[s - 1]].push(mid);
        } else if (delta > 0 && pos === inSide.length - 1) {
            if (s === 2)
                return ;

            inSide.splice(pos, 1);
            g[editor.sides[s + 1]].unshift(mid);
        } else {
            inSide.splice(pos, 1);
            inSide.splice(pos + delta, 0, mid);
        }
        Prefs.setBarLayout(g);
    }

    // up/down moves to the next lane, keeping about the same place in it
    function shift(mid, delta) {
        const g = editor.groups();
        const s = editor.sides.findIndex((side) => {
            return g[side].indexOf(mid) >= 0;
        });
        const t = s + delta;
        if (t < 0 || t > 2)
            return ;

        const pos = g[editor.sides[s]].indexOf(mid);
        g[editor.sides[s]].splice(pos, 1);
        const dest = g[editor.sides[t]];
        dest.splice(Math.min(pos, dest.length), 0, mid);
        Prefs.setBarLayout(g);
    }

    implicitHeight: editor.laneY(3) - editor.laneGap
    Component.onCompleted: editor.load()
    opacity: editor.enabled ? 1 : 0.38

    FontMetrics {
        id: metrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabelLg
        font.weight: Font.Medium
    }

    ListModel {
        id: chips
    }

    Connections {
        function onBarLayoutChanged() {
            if (!editor.dragging)
                editor.load();

        }

        target: Prefs
    }

    Repeater {
        model: editor.sides

        Item {
            id: lane

            required property string modelData
            required property int index
            readonly property bool empty: {
                void editor.revision;
                for (let i = 0; i < chips.count; i++) {
                    if (chips.get(i).side === lane.modelData)
                        return false;

                }
                return true;
            }

            y: editor.laneY(lane.index)
            width: editor.width
            height: editor.laneHeight

            Text {
                width: editor.labelWidth - 12
                anchors.verticalCenter: parent.verticalCenter
                text: editor.sideNames[lane.modelData]
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                x: editor.labelWidth
                width: editor.laneWidth
                height: parent.height
                radius: Theme.radiusMd
                color: editor.dragging && editor.dragSide === lane.modelData ? Theme.bgHover : Theme.bgSunken

                Text {
                    anchors.centerIn: parent
                    visible: lane.empty
                    text: "Drop a module here"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelMd
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

        }

    }

    Repeater {
        model: chips

        Rectangle {
            id: chip

            required property string mid
            required property string side
            readonly property var slot: editor.slots[chip.mid] || ({
                "x": 0,
                "y": 0,
                "w": 0
            })
            readonly property bool shown: Prefs[editor.modules[chip.mid].key] === true

            width: chip.slot.w
            height: editor.chipHeight
            radius: Theme.shapeFull
            z: chipDrag.active ? 10 : 1
            scale: chipDrag.active ? 1.05 : 1
            color: chipDrag.active || chip.activeFocus ? Theme.accentContainer : Theme.bgActive
            border.width: chip.activeFocus && !chipDrag.active ? 2 : 0
            border.color: Theme.accent
            // switched off in the list below: still placed, just quieter
            opacity: chip.shown || chipDrag.active ? 1 : 0.5
            onXChanged: {
                if (chipDrag.active)
                    editor.reorder(chip.mid, chip.x + chip.width / 2, chip.y + chip.height / 2);

            }
            onYChanged: {
                if (chipDrag.active)
                    editor.reorder(chip.mid, chip.x + chip.width / 2, chip.y + chip.height / 2);

            }
            Keys.onLeftPressed: editor.step(chip.mid, -1)
            Keys.onRightPressed: editor.step(chip.mid, 1)
            Keys.onUpPressed: editor.shift(chip.mid, -1)
            Keys.onDownPressed: editor.shift(chip.mid, 1)

            // the chip owns x/y while it's dragged; the Bindings take them back after
            Binding {
                target: chip
                property: "x"
                value: chip.slot.x
                when: !chipDrag.active
            }

            Binding {
                target: chip
                property: "y"
                value: chip.slot.y
                when: !chipDrag.active
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.text
                opacity: chipHover.hovered && !chipDrag.active ? Theme.stateHover : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            // a two-by-three grip of dots, the sign that this one moves
            Grid {
                id: grip

                x: 14
                anchors.verticalCenter: parent.verticalCenter
                columns: 2
                spacing: 2

                Repeater {
                    model: 6

                    Rectangle {
                        width: 2
                        height: 2
                        radius: 1
                        color: chip.activeFocus || chipDrag.active ? Theme.fgAccentContainer : Theme.subtext
                    }

                }

            }

            Text {
                anchors.left: grip.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: editor.modules[chip.mid].name
                color: chip.activeFocus || chipDrag.active ? Theme.fgAccentContainer : Theme.text
                font: metrics.font
                elide: Text.ElideRight
            }

            HoverHandler {
                id: chipHover

                cursorShape: chipDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            }

            TapHandler {
                onTapped: chip.forceActiveFocus()
            }

            DragHandler {
                id: chipDrag

                target: chip
                enabled: editor.enabled
                xAxis.minimum: editor.labelWidth
                xAxis.maximum: Math.max(editor.labelWidth, editor.width - chip.width)
                yAxis.minimum: 0
                yAxis.maximum: Math.max(0, editor.height - chip.height)
                onActiveChanged: {
                    editor.dragging = chipDrag.active;
                    if (chipDrag.active) {
                        editor.dragSide = chip.side;
                        chip.forceActiveFocus();
                    } else {
                        Prefs.setBarLayout(editor.groups());
                    }
                }
            }

            Behavior on x {
                enabled: !chipDrag.active

                NumberAnimation {
                    duration: Theme.ms(220)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on y {
                enabled: !chipDrag.active

                NumberAnimation {
                    duration: Theme.ms(220)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on width {
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

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

}
