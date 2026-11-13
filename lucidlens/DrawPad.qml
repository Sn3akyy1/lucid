import QtQuick
import qs

// the pointer, drawing on the picture. marks are made in the picture's own
// pixels, so they turn, crop and zoom with it; sizes are picked as they look
// on screen and kept as they will be in the file
Item {
    id: pad

    required property var win
    required property var stage
    property bool active: false
    readonly property var prefs: pad.win.app.prefs
    readonly property string tool: pad.prefs.tool
    readonly property var pic: pad.stage.current
    // screen pixels to one of the picture's
    readonly property real k: pad.pic ? pad.stage.shownScale * pad.pic.cover : 1
    readonly property var inkHex: ({
        "red": "#e53935",
        "orange": "#fb8c00",
        "yellow": "#fdd835",
        "green": "#43a047",
        "blue": "#1e88e5",
        "purple": "#8e24aa",
        "white": "#ffffff",
        "black": "#141414"
    })
    readonly property string ink: pad.inkHex[pad.prefs.ink] || Theme.toHex(Theme.accent)
    readonly property real stroke: Theme.dp([3, 5, 8, 13, 20][Math.max(0, Math.min(4, pad.prefs.inkSize))])
    readonly property real textPx: Theme.dp([18, 26, 36, 50, 72][Math.max(0, Math.min(4, pad.prefs.inkSize))])
    property bool typing: false
    property point textAt
    property var _start: null
    property point _last
    property bool _panning: false
    property real _panX: 0
    property real _panY: 0

    function toPic(x, y) {
        var p = pad.pic.body.mapFromItem(pad, x, y);
        return Qt.point(p.x, p.y);
    }

    // a line's end drawn straight on the nearest fifteen degrees
    function snapAngle(a, b) {
        var dx = b.x - a.x, dy = b.y - a.y, len = Math.sqrt(dx * dx + dy * dy);
        var ang = Math.round(Math.atan2(dy, dx) / (Math.PI / 12)) * (Math.PI / 12);
        return Qt.point(a.x + Math.cos(ang) * len, a.y + Math.sin(ang) * len);
    }

    function box(a, b, even) {
        var w = b.x - a.x, h = b.y - a.y;
        if (even) {
            var m = Math.max(Math.abs(w), Math.abs(h));
            w = w < 0 ? -m : m;
            h = h < 0 ? -m : m;
        }
        return {
            "x": Math.min(a.x, a.x + w),
            "y": Math.min(a.y, a.y + h),
            "w": Math.abs(w),
            "h": Math.abs(h)
        };
    }

    function commit(m) {
        var marks = (pad.win.edits.marks || []).concat([m]);
        pad.win.draft = null;
        pad.win.change({
            "marks": marks
        });
    }

    function press(x, y) {
        var p = pad.toPic(x, y);
        pad._start = Qt.point(x, y);
        pad._last = Qt.point(x, y);
        var w = pad.stroke / pad.k;
        switch (pad.tool) {
        case "pen":
        case "marker":
            pad.win.draft = {
                "kind": pad.tool,
                "ink": pad.ink,
                "w": pad.tool === "marker" ? w * 3.2 : w,
                "pts": [p.x, p.y]
            };
            break;
        case "line":
        case "arrow":
            pad.win.draft = {
                "kind": pad.tool,
                "ink": pad.ink,
                "w": w,
                "pts": [p.x, p.y, p.x, p.y]
            };
            break;
        case "rect":
        case "ellipse":
            pad.win.draft = {
                "kind": pad.tool,
                "ink": pad.ink,
                "line": w,
                "fill": pad.prefs.fillShapes,
                "x": p.x,
                "y": p.y,
                "w": 0,
                "h": 0
            };
            break;
        case "redact":
            pad.win.draft = {
                "kind": "redact",
                "x": p.x,
                "y": p.y,
                "w": 0,
                "h": 0
            };
            break;
        case "text":
            pad.startText(x, y);
            break;
        case "eraser":
            pad.erase(x, y);
            break;
        }
    }

    function move(x, y, shift) {
        var d = pad.win.draft;
        if (!d)
            return ;

        var p = pad.toPic(x, y);
        var a = pad.toPic(pad._start.x, pad._start.y);
        if (d.kind === "pen" || d.kind === "marker") {
            // a hand's tiny steps are dropped: they only add weight to the path
            if (Math.abs(x - pad._last.x) + Math.abs(y - pad._last.y) < 2.5)
                return ;

            pad._last = Qt.point(x, y);
            if (shift) {
                pad.win.draft = Object.assign({}, d, {
                    "pts": [d.pts[0], d.pts[1], p.x, p.y]
                });
                return ;
            }
            pad.win.draft = Object.assign({}, d, {
                "pts": d.pts.concat([p.x, p.y])
            });
        } else if (d.kind === "line" || d.kind === "arrow") {
            var e = shift ? pad.snapAngle(a, p) : p;
            pad.win.draft = Object.assign({}, d, {
                "pts": [a.x, a.y, e.x, e.y]
            });
        } else {
            pad.win.draft = Object.assign({}, d, pad.box(a, p, shift && d.kind !== "redact"));
        }
    }

    function release() {
        var d = pad.win.draft;
        if (!d)
            return ;

        if ((d.kind === "rect" || d.kind === "ellipse" || d.kind === "redact") && (d.w * pad.k < 4 || d.h * pad.k < 4)) {
            pad.win.draft = null;
            return ;
        }
        if ((d.kind === "line" || d.kind === "arrow") && Math.abs(d.pts[2] - d.pts[0]) + Math.abs(d.pts[3] - d.pts[1]) < 3 / pad.k) {
            pad.win.draft = null;
            return ;
        }
        pad.commit(d);
    }

    // ---- words

    function startText(x, y) {
        if (pad.typing)
            pad.finishText();

        pad.textAt = Qt.point(x, y);
        input.text = "";
        pad.typing = true;
        Qt.callLater(function() {
            input.forceActiveFocus();
        });
    }

    function finishText() {
        if (!pad.typing)
            return ;

        pad.typing = false;
        var t = input.text.trim();
        if (t !== "" && pad.pic) {
            var p = pad.toPic(pad.textAt.x, pad.textAt.y);
            var e = pad.win.edits;
            pad.commit({
                "kind": "text",
                "x": p.x,
                "y": p.y,
                "text": input.text,
                "ink": pad.ink,
                "size": pad.textPx / pad.k,
                "halo": pad.prefs.fillShapes ? (pad.prefs.ink === "white" || pad.prefs.ink === "yellow" ? "#141414" : "#ffffff") : "",
                "q": (e.turns || 0) * 90,
                "fx": e.flipH === true,
                "fy": e.flipV === true,
                "a": e.angle || 0
            });
        }
        input.text = "";
        pad.win.keysBack();
    }

    function cancelText() {
        pad.typing = false;
        input.text = "";
        pad.win.keysBack();
    }

    // ---- the eraser takes the topmost mark under the pointer

    function near(px, py, pts, reach) {
        for (var i = 0; i + 1 < pts.length; i += 2) {
            var x1 = pts[i], y1 = pts[i + 1];
            var x2 = i + 3 < pts.length ? pts[i + 2] : x1, y2 = i + 3 < pts.length ? pts[i + 3] : y1;
            var dx = x2 - x1, dy = y2 - y1, l2 = dx * dx + dy * dy;
            var t = l2 > 0 ? Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / l2)) : 0;
            var qx = x1 + t * dx - px, qy = y1 + t * dy - py;
            if (qx * qx + qy * qy <= reach * reach)
                return true;

        }
        return false;
    }

    function hit(m, p, sx, sy) {
        var tol = Theme.dp(8) / pad.k;
        switch (m.kind) {
        case "pen":
        case "marker":
        case "line":
        case "arrow":
            return pad.near(p.x, p.y, m.pts, m.w / 2 + tol);
        case "rect":
        case "ellipse":
        case "redact":
            return p.x >= m.x - tol && p.x <= m.x + m.w + tol && p.y >= m.y - tol && p.y <= m.y + m.h + tol;
        case "text":
            var at = pad.pic.body.mapToItem(pad, m.x, m.y);
            var s = m.size * pad.k;
            var lines = m.text.split("\n");
            var longest = Math.max.apply(null, lines.map(function(l) {
                return l.length;
            }));
            return sx >= at.x - 4 && sx <= at.x + longest * s * 0.62 + 4 && sy >= at.y - 4 && sy <= at.y + lines.length * s * 1.3 + 4;
        }
        return false;
    }

    function erase(x, y) {
        var marks = pad.win.edits.marks || [];
        var p = pad.toPic(x, y);
        for (var i = marks.length - 1; i >= 0; i--) {
            if (pad.hit(marks[i], p, x, y)) {
                pad.win.change({
                    "marks": marks.slice(0, i).concat(marks.slice(i + 1))
                });
                return ;
            }
        }
    }

    onActiveChanged: {
        if (!pad.active) {
            pad.finishText();
            pad.win.draft = null;
        }
    }
    visible: pad.active

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: pad.active
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: pad._panning ? Qt.ClosedHandCursor : pad.tool === "text" ? Qt.IBeamCursor : pad.tool === "eraser" ? Qt.PointingHandCursor : Qt.CrossCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                pad._panning = true;
                pad._start = Qt.point(mouse.x, mouse.y);
                pad._panX = pad.stage.panX;
                pad._panY = pad.stage.panY;
                return ;
            }
            pad.press(mouse.x, mouse.y);
        }
        onPositionChanged: (mouse) => {
            if (pad._panning) {
                pad.stage.panX = pad._panX + mouse.x - pad._start.x;
                pad.stage.panY = pad._panY + mouse.y - pad._start.y;
                pad.stage.clampPan();
                return ;
            }
            if (pressed)
                pad.move(mouse.x, mouse.y, (mouse.modifiers & Qt.ShiftModifier) !== 0);

        }
        onReleased: (mouse) => {
            if (pad._panning) {
                pad._panning = false;
                return ;
            }
            pad.release();
        }
        onCanceled: {
            pad._panning = false;
            pad.win.draft = null;
        }

        HeldPointer {
            held: area.pressed
            cursor: area.cursorShape
        }

    }

    // the words as they are typed, the size and colour they will have
    TextEdit {
        id: input

        x: pad.textAt.x
        y: pad.textAt.y
        visible: pad.typing
        color: pad.ink
        font.family: Theme.fontFamily
        font.pixelSize: pad.textPx
        font.weight: Font.Bold
        font.variableAxes: Theme.axes(pad.textPx, 700, 0)
        selectByMouse: true
        cursorVisible: pad.typing
        Keys.onReturnPressed: (event) => {
            if (event.modifiers & Qt.ShiftModifier)
                event.accepted = false;
            else
                pad.finishText();
        }
        Keys.onEnterPressed: pad.finishText()
        Keys.onEscapePressed: pad.cancelText()

        Rectangle {
            x: -Theme.dp(6)
            y: -Theme.dp(4)
            width: Math.max(Theme.dp(24), input.contentWidth) + Theme.dp(12)
            height: input.contentHeight + Theme.dp(8)
            z: -1
            radius: Theme.radiusXs
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.6)
        }

    }

}
