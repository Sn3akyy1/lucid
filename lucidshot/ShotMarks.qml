import QtQuick
import qs
import qs.lucidui

// what the editor draws on a capture: the marks so far, the one being drawn
// and the text being typed. it sits on the selection and clips to it, while
// the marks keep the stage's coordinates, so reshaping the selection never
// moves them across the picture
Item {
    id: ed

    property var stage: null
    // the picture under the marks, for redactions
    property Item base: null
    property string tool: "arrow"
    property color ink: "#ff5449"
    // the size a new mark is drawn at, picked per tool from S, M or L
    property int sizeIndex: 1
    property var store: ({
    })
    property int serial: 0
    property var redoList: []
    property var drawing: null
    readonly property int count: marks.count
    readonly property bool canUndo: marks.count > 0
    readonly property bool canRedo: ed.redoList.length > 0
    readonly property bool typing: editor.visible
    readonly property var sizes: ({
        "pen": [3, 5, 9],
        "arrow": [3, 5, 8],
        "rect": [3, 5, 8],
        "oval": [3, 5, 8],
        "hl": [14, 22, 32],
        "text": [18, 26, 38],
        "step": [26, 34, 44],
        "redact": [8, 12, 18]
    })

    function sizeFor(kind) {
        const s = ed.sizes[kind] || ed.sizes.pen;
        return Theme.dp(s[Math.max(0, Math.min(2, ed.sizeIndex))]);
    }

    function clear() {
        editor.cancel();
        marks.clear();
        ed.store = {
        };
        ed.redoList = [];
        ed.drawing = null;
    }

    function add(m, keepRedo) {
        ed.serial++;
        const id = "m" + ed.serial;
        const s = Object.assign({
        }, ed.store);
        s[id] = m;
        ed.store = s;
        marks.append({
            "mid": id
        });
        if (!keepRedo)
            ed.redoList = [];

    }

    function commitText() {
        if (editor.visible)
            editor.commit();

    }

    function undo() {
        if (editor.visible) {
            editor.cancel();
            return ;
        }
        if (marks.count === 0)
            return ;

        const id = marks.get(marks.count - 1).mid;
        ed.redoList = ed.redoList.concat([ed.store[id]]);
        marks.remove(marks.count - 1);
    }

    function redo() {
        if (ed.redoList.length === 0)
            return ;

        const m = ed.redoList[ed.redoList.length - 1];
        ed.redoList = ed.redoList.slice(0, -1);
        ed.add(m, true);
    }

    // numbered steps count on from the ones still on the picture
    function nextStep() {
        let n = 0;
        for (let i = 0; i < marks.count; i++) {
            const m = ed.store[marks.get(i).mid];
            if (m && m.kind === "step")
                n = Math.max(n, m.n || 0);

        }
        return n + 1;
    }

    // shift keeps a box square, a circle round and an arrow on the eighths
    function shaped(x0, y0, x, y, mods) {
        if (!(mods & Qt.ShiftModifier))
            return Qt.point(x, y);

        const dx = x - x0, dy = y - y0;
        if (ed.tool === "arrow") {
            const len = Math.sqrt(dx * dx + dy * dy);
            const a = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4);
            return Qt.point(x0 + Math.cos(a) * len, y0 + Math.sin(a) * len);
        }
        const side = Math.max(Math.abs(dx), Math.abs(dy));
        return Qt.point(x0 + (dx < 0 ? -side : side), y0 + (dy < 0 ? -side : side));
    }

    function press(x, y) {
        const t = ed.tool;
        if (t === "text") {
            editor.begin(x, y);
            return ;
        }
        if (t === "step") {
            const d = ed.sizeFor("step");
            ed.add({
                "kind": "step",
                "color": String(ed.ink),
                "size": d,
                "x1": x,
                "y1": y,
                "n": ed.nextStep()
            });
            return ;
        }
        if (t === "pen" || t === "hl") {
            ed.drawing = {
                "kind": t,
                "color": String(ed.ink),
                "size": ed.sizeFor(t),
                "pts": [x, y]
            };
            return ;
        }
        ed.drawing = {
            "kind": t,
            "color": String(ed.ink),
            "size": ed.sizeFor(t),
            "x1": x,
            "y1": y,
            "x2": x,
            "y2": y
        };
    }

    function move(x, y, mods) {
        const d = ed.drawing;
        if (!d)
            return ;

        if (d.kind === "pen" || d.kind === "hl") {
            const p = d.pts;
            const lx = p[p.length - 2], ly = p[p.length - 1];
            // a point per pixel and a half is plenty, and keeps long strokes light
            if ((x - lx) * (x - lx) + (y - ly) * (y - ly) < 2.25)
                return ;

            ed.drawing = Object.assign({
            }, d, {
                "pts": p.concat([x, y])
            });
            return ;
        }
        const q = ed.shaped(d.x1, d.y1, x, y, mods);
        ed.drawing = Object.assign({
        }, d, {
            "x2": q.x,
            "y2": q.y
        });
    }

    function release() {
        const d = ed.drawing;
        ed.drawing = null;
        if (!d)
            return ;

        if (d.kind === "pen" || d.kind === "hl") {
            ed.add(d);
            return ;
        }
        const w = Math.abs(d.x2 - d.x1), h = Math.abs(d.y2 - d.y1);
        if (d.kind === "arrow" ? w * w + h * h >= 64 : (w >= 3 && h >= 3))
            ed.add(d);

    }

    x: ed.stage ? ed.stage.selX : 0
    y: ed.stage ? ed.stage.selY : 0
    width: ed.stage ? ed.stage.selW : 0
    height: ed.stage ? ed.stage.selH : 0
    clip: true

    ListModel {
        id: marks
    }

    Item {
        id: plane

        x: -ed.x
        y: -ed.y
        width: ed.stage ? ed.stage.width : 0
        height: ed.stage ? ed.stage.height : 0

        Repeater {
            model: marks

            ShotMark {
                required property string mid

                m: ed.store[mid] || null
                base: ed.base
            }

        }

        ShotMark {
            m: ed.drawing
            base: ed.base
            visible: ed.drawing !== null
        }

        TextInput {
            id: editor

            property real ax: 0
            property real ay: 0

            function begin(x, y) {
                if (editor.visible)
                    editor.commit();

                editor.ax = x;
                editor.ay = y;
                editor.text = "";
                editor.visible = true;
                editor.forceActiveFocus();
            }

            function commit() {
                const t = editor.text.trim();
                editor.visible = false;
                if (t !== "")
                    ed.add({
                    "kind": "text",
                    "color": String(ed.ink),
                    "size": ed.sizeFor("text"),
                    "x1": editor.ax,
                    "y1": editor.ay,
                    "text": t
                });

                editor.text = "";
                if (ed.stage)
                    ed.stage.forceActiveFocus();

            }

            function cancel() {
                if (!editor.visible)
                    return ;

                editor.visible = false;
                editor.text = "";
                if (ed.stage)
                    ed.stage.forceActiveFocus();

            }

            visible: false
            x: editor.ax + 2
            y: editor.ay + 2
            width: Math.max(Theme.dp(40), editor.contentWidth + Theme.dp(4))
            color: ed.ink
            selectionColor: Theme.alpha(Theme.primary, 0.4)
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(ed.sizeFor("text"))
            font.weight: Font.Bold
            cursorVisible: editor.visible
            // enter would otherwise go on to the stage and save the capture
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    editor.commit();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    editor.cancel();
                    event.accepted = true;
                }
            }
            onActiveFocusChanged: {
                if (!editor.activeFocus && editor.visible)
                    editor.commit();

            }

            Rectangle {
                z: -1
                anchors.fill: parent
                anchors.margins: -Theme.dp(6)
                radius: Theme.dp(8)
                color: Theme.alpha(Theme.surfaceContainer, 0.55)
                border.width: 1
                border.color: Theme.alpha(Theme.primary, 0.8)
            }

        }

    }

}
