import QtQuick
import qs

// the outputs laid out the way hyprland sees them, drag one to move it. edges
// snap to the neighbours they are dragged near, so there are no gaps to leave
// the pointer stranded in
Item {
    id: map

    readonly property int snap: 60
    property string held: ""
    // the display the page is pointed at
    property string selected: ""

    signal picked(string key)

    // the whole layout in hyprland's own coordinates, with a margin so an
    // output dragged past the edge still has somewhere to land
    readonly property var bounds: {
        let x0 = 0;
        let y0 = 0;
        let x1 = 0;
        let y1 = 0;
        let first = true;
        for (const key of Monitors.keys) {
            if (!Monitors.isOn(key))
                continue;

            const p = Monitors.posOf(key);
            const s = Monitors.layoutSize(key);
            if (first) {
                x0 = p.x;
                y0 = p.y;
                x1 = p.x + s.w;
                y1 = p.y + s.h;
                first = false;
            } else {
                x0 = Math.min(x0, p.x);
                y0 = Math.min(y0, p.y);
                x1 = Math.max(x1, p.x + s.w);
                y1 = Math.max(y1, p.y + s.h);
            }
        }
        if (first)
            return {
                "x": 0,
                "y": 0,
                "w": 1920,
                "h": 1080
            };

        const padX = Math.max(160, (x1 - x0) * 0.1);
        const padY = Math.max(160, (y1 - y0) * 0.1);
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

    // the nearest edge alignment to where an output was dropped
    function settle(key, wantX, wantY) {
        const s = Monitors.layoutSize(key);
        let x = Math.round(wantX);
        let y = Math.round(wantY);
        let bestX = map.snap + 1;
        let bestY = map.snap + 1;
        let snapX = x;
        let snapY = y;
        for (const other of Monitors.keys) {
            if (other === key || !Monitors.isOn(other))
                continue;

            const p = Monitors.posOf(other);
            const o = Monitors.layoutSize(other);
            // left or right of it, and the two ways the tops can line up
            for (const cand of [p.x - s.w, p.x + o.w, p.x, p.x + o.w - s.w]) {
                const d = Math.abs(x - cand);
                if (d < bestX) {
                    bestX = d;
                    snapX = cand;
                }
            }
            for (const cand of [p.y - s.h, p.y + o.h, p.y, p.y + o.h - s.h]) {
                const d = Math.abs(y - cand);
                if (d < bestY) {
                    bestY = d;
                    snapY = cand;
                }
            }
        }
        if (bestX <= map.snap)
            x = snapX;

        if (bestY <= map.snap)
            y = snapY;

        Monitors.setPos(key, x, y);
    }

    implicitHeight: Math.max(180, Math.min(420, map.width * map.bounds.h / map.bounds.w))

    Rectangle {
        id: frame

        anchors.fill: parent
        radius: Theme.radiusXl
        color: Theme.bgSunken
        clip: true

        Repeater {
            model: Monitors.keys

            Rectangle {
                id: plate

                required property string modelData
                readonly property var out: Monitors.output(plate.modelData)
                readonly property var size: Monitors.layoutSize(plate.modelData)
                readonly property var pos: Monitors.posOf(plate.modelData)
                readonly property bool lit: drag.containsMouse || map.held === plate.modelData
                readonly property bool chosen: map.selected === plate.modelData

                visible: plate.out !== null && Monitors.isOn(plate.modelData)
                width: Math.max(34, plate.size.w * map.fit)
                height: Math.max(26, plate.size.h * map.fit)
                x: map.offX + plate.pos.x * map.fit
                y: map.offY + plate.pos.y * map.fit
                radius: Theme.shapeSm
                color: plate.lit ? Theme.accent : Theme.bgActive
                border.width: plate.chosen && !plate.lit ? 2 : 0
                border.color: Theme.accent
                z: plate.lit ? 2 : 1

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 6
                    visible: plate.height > 44
                    text: Monitors.numberFor(plate.modelData)
                    color: plate.lit ? Theme.fgAccent : Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    font.weight: Font.DemiBold
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: plate.out ? plate.out.name : ""
                        color: plate.lit ? Theme.fgAccent : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: plate.size.w + " × " + plate.size.h
                        color: plate.lit ? Theme.fgAccent : Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        visible: plate.height > 44
                    }

                }

                MouseArea {
                    id: drag

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeAllCursor
                    // the grab point in hyprland's coordinates, so the plate
                    // does not jump to the pointer as the drag starts
                    property real grabX: 0
                    property real grabY: 0
                    // a press that never moved is a pick, not a drag
                    property bool moved: false
                    onPressed: (mouse) => {
                        map.held = plate.modelData;
                        drag.moved = false;
                        drag.grabX = mouse.x / map.fit;
                        drag.grabY = mouse.y / map.fit;
                    }
                    onReleased: {
                        map.held = "";
                        if (!drag.moved)
                            map.picked(plate.modelData);

                    }
                    onPositionChanged: (mouse) => {
                        if (map.held !== plate.modelData)
                            return ;

                        // moving anything pins them all, or hyprland reshuffles
                        // the rest around the one that moved
                        if (!drag.moved) {
                            drag.moved = true;
                            Monitors.pinAll();
                        }

                        const gx = (mouse.x - drag.grabX * map.fit + plate.x - map.offX) / map.fit;
                        const gy = (mouse.y - drag.grabY * map.fit + plate.y - map.offY) / map.fit;
                        map.settle(plate.modelData, gx, gy);
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

                Behavior on x {
                    enabled: map.held !== plate.modelData

                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

                Behavior on y {
                    enabled: map.held !== plate.modelData

                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

            }

        }

    }

}
