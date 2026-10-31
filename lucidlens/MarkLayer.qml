import QtQuick
import QtQuick.Shapes
import qs

// what was drawn on a picture, in its own pixels: strokes, highlighter, lines,
// arrows, boxes, rings, words, and boxes that pixelate what is under them.
// a mark is {kind, ink, w, pts: [x, y, ...]} or {kind, x, y, w, h, ...}
Item {
    id: ml

    property var marks: []
    // the mark still being drawn
    property var draft: null
    // the picture under the marks, for redaction to pixelate
    property Item under: null
    property real longSide: 1000
    readonly property real block: Math.max(6, Math.round(ml.longSide / 90))

    // a stroke's points as a smooth path: each point bends the line on its way to
    // the middle of the next, so a hand's jitter reads as a curve
    function smooth(p, ox, oy) {
        var n = p.length / 2;
        if (n === 0)
            return "";

        var f = function(v) {
            return (Math.round(v * 10) / 10).toString();
        };
        var d = "M " + f(p[0] - ox) + " " + f(p[1] - oy);
        if (n === 1)
            return d + " L " + f(p[0] - ox + 0.05) + " " + f(p[1] - oy);

        for (var i = 1; i < n - 1; i++) {
            var mx = (p[2 * i] + p[2 * i + 2]) / 2, my = (p[2 * i + 1] + p[2 * i + 3]) / 2;
            d += " Q " + f(p[2 * i] - ox) + " " + f(p[2 * i + 1] - oy) + " " + f(mx - ox) + " " + f(my - oy);
        }
        return d + " L " + f(p[2 * n - 2] - ox) + " " + f(p[2 * n - 1] - oy);
    }

    function bounds(p, pad) {
        var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (var i = 0; i < p.length; i += 2) {
            x0 = Math.min(x0, p[i]);
            x1 = Math.max(x1, p[i]);
            y0 = Math.min(y0, p[i + 1]);
            y1 = Math.max(y1, p[i + 1]);
        }
        if (x0 === Infinity)
            return Qt.rect(0, 0, 1, 1);

        return Qt.rect(Math.floor(x0 - pad), Math.floor(y0 - pad), Math.ceil(x1 - x0 + 2 * pad) + 1, Math.ceil(y1 - y0 + 2 * pad) + 1);
    }

    // an arrow's head, a rounded triangle at the far end of its line
    function head(m) {
        var x1 = m.pts[0], y1 = m.pts[1], x2 = m.pts[2], y2 = m.pts[3];
        var dx = x2 - x1, dy = y2 - y1, len = Math.max(0.001, Math.sqrt(dx * dx + dy * dy));
        var ux = dx / len, uy = dy / len, nx = -uy, ny = ux;
        var hl = Math.min(len * 0.6, Math.max(m.w * 4.2, 10)), hw = hl * 0.62;
        var bx = x2 - ux * hl, by = y2 - uy * hl;
        return {
            "tip": [x2, y2],
            "a": [bx + nx * hw, by + ny * hw],
            "b": [bx - nx * hw, by - ny * hw],
            "base": [x2 - ux * hl * 0.7, y2 - uy * hl * 0.7]
        };
    }

    Repeater {
        model: ml.marks

        delegate: Loader {
            required property var modelData

            sourceComponent: ml.componentFor(modelData.kind)
            onLoaded: item.m = modelData
        }

    }

    Loader {
        active: ml.draft !== null
        sourceComponent: ml.draft ? ml.componentFor(ml.draft.kind) : null
        onLoaded: item.m = Qt.binding(function() {
            return ml.draft;
        })
    }

    function componentFor(kind) {
        switch (kind) {
        case "pen":
            return penMark;
        case "marker":
            return markerMark;
        case "line":
        case "arrow":
            return lineMark;
        case "rect":
            return rectMark;
        case "ellipse":
            return ellipseMark;
        case "text":
            return textMark;
        case "redact":
            return redactMark;
        }
        return null;
    }

    Component {
        id: penMark

        Shape {
            id: s

            property var m: null
            readonly property rect box: s.m ? ml.bounds(s.m.pts, s.m.w) : Qt.rect(0, 0, 1, 1)

            x: s.box.x
            y: s.box.y
            width: s.box.width
            height: s.box.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: s.m ? s.m.ink : "transparent"
                strokeWidth: s.m ? s.m.w : 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: s.m ? ml.smooth(s.m.pts, s.box.x, s.box.y) : ""
                }

            }

        }

    }

    // see-through ink drawn solid into a layer and faded as one, so where the
    // stroke crosses itself it doesn't darken
    Component {
        id: markerMark

        Item {
            id: hl

            property var m: null
            readonly property rect box: hl.m ? ml.bounds(hl.m.pts, hl.m.w) : Qt.rect(0, 0, 1, 1)

            x: hl.box.x
            y: hl.box.y
            width: hl.box.width
            height: hl.box.height
            opacity: 0.42
            layer.enabled: true

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: hl.m ? hl.m.ink : "transparent"
                    strokeWidth: hl.m ? hl.m.w : 1
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathSvg {
                        path: hl.m ? ml.smooth(hl.m.pts, hl.box.x, hl.box.y) : ""
                    }

                }

            }

        }

    }

    Component {
        id: lineMark

        Shape {
            id: ln

            property var m: null
            readonly property bool arrow: ln.m !== null && ln.m.kind === "arrow"
            readonly property var h: ln.arrow ? ml.head(ln.m) : null
            readonly property rect box: ln.m ? ml.bounds(ln.m.pts, ln.m.w * 6) : Qt.rect(0, 0, 1, 1)

            x: ln.box.x
            y: ln.box.y
            width: ln.box.width
            height: ln.box.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: ln.m ? ln.m.ink : "transparent"
                strokeWidth: ln.m ? ln.m.w : 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathSvg {
                    path: !ln.m ? "" : "M " + (ln.m.pts[0] - ln.box.x) + " " + (ln.m.pts[1] - ln.box.y) + " L " + ((ln.arrow ? ln.h.base[0] : ln.m.pts[2]) - ln.box.x) + " " + ((ln.arrow ? ln.h.base[1] : ln.m.pts[3]) - ln.box.y)
                }

            }

            ShapePath {
                strokeColor: ln.arrow ? ln.m.ink : "transparent"
                strokeWidth: ln.m ? ln.m.w * 0.6 : 0
                fillColor: ln.arrow ? ln.m.ink : "transparent"
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: !ln.arrow ? "" : "M " + (ln.h.tip[0] - ln.box.x) + " " + (ln.h.tip[1] - ln.box.y) + " L " + (ln.h.a[0] - ln.box.x) + " " + (ln.h.a[1] - ln.box.y) + " L " + (ln.h.b[0] - ln.box.x) + " " + (ln.h.b[1] - ln.box.y) + " Z"
                }

            }

        }

    }

    Component {
        id: rectMark

        Rectangle {
            id: r

            property var m: null

            x: r.m ? r.m.x : 0
            y: r.m ? r.m.y : 0
            width: r.m ? r.m.w : 0
            height: r.m ? r.m.h : 0
            radius: r.m ? Math.min(r.m.line * 1.4, Math.min(width, height) / 2) : 0
            color: r.m && r.m.fill ? r.m.ink : "transparent"
            border.width: r.m ? r.m.line : 0
            border.color: r.m ? r.m.ink : "transparent"
            antialiasing: true
        }

    }

    Component {
        id: ellipseMark

        Shape {
            id: el

            property var m: null

            x: el.m ? el.m.x - el.m.line : 0
            y: el.m ? el.m.y - el.m.line : 0
            width: el.m ? el.m.w + 2 * el.m.line : 0
            height: el.m ? el.m.h + 2 * el.m.line : 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: el.m ? el.m.ink : "transparent"
                strokeWidth: el.m ? el.m.line : 1
                fillColor: el.m && el.m.fill ? el.m.ink : "transparent"

                PathAngleArc {
                    centerX: el.width / 2
                    centerY: el.height / 2
                    radiusX: el.m ? Math.max(0.5, el.m.w / 2) : 1
                    radiusY: el.m ? Math.max(0.5, el.m.h / 2) : 1
                    startAngle: 0
                    sweepAngle: 360
                }

            }

        }

    }

    // words stand upright on screen whichever way the picture was turned when
    // they were put down: q, fx, fy and a undo that turn
    Component {
        id: textMark

        Item {
            id: t

            property var m: null
            readonly property real pad: t.m ? t.m.size * 0.28 : 0

            x: t.m ? t.m.x : 0
            y: t.m ? t.m.y : 0
            width: words.implicitWidth
            height: words.implicitHeight
            transform: [
                Rotation {
                    angle: t.m ? -(t.m.a || 0) : 0
                },
                Scale {
                    xScale: t.m && t.m.fx ? -1 : 1
                    yScale: t.m && t.m.fy ? -1 : 1
                },
                Rotation {
                    angle: t.m ? -(t.m.q || 0) : 0
                }
            ]

            // words on a label, for a busy picture
            Rectangle {
                visible: t.m !== null && (t.m.halo || "") !== ""
                x: -t.pad
                y: -t.pad * 0.55
                width: words.implicitWidth + 2 * t.pad
                height: words.implicitHeight + 1.1 * t.pad
                radius: t.pad * 1.1
                color: t.m && t.m.halo ? t.m.halo : "transparent"
            }

            Text {
                id: words

                text: t.m ? t.m.text : ""
                color: t.m ? t.m.ink : "transparent"
                font.family: Theme.fontFamily
                font.pixelSize: t.m ? Math.max(4, t.m.size) : 12
                font.weight: Font.Bold
                font.variableAxes: Theme.axes(t.m ? t.m.size : 12, 700, 0)
            }

        }

    }

    // the picture under the box, drawn back in blocks too coarse to read
    Component {
        id: redactMark

        ShaderEffectSource {
            id: rd

            property var m: null

            x: rd.m ? rd.m.x : 0
            y: rd.m ? rd.m.y : 0
            width: rd.m ? Math.max(1, rd.m.w) : 1
            height: rd.m ? Math.max(1, rd.m.h) : 1
            sourceItem: ml.under
            sourceRect: Qt.rect(rd.x * ml.scale, rd.y * ml.scale, rd.width * ml.scale, rd.height * ml.scale)
            textureSize: Qt.size(Math.max(1, Math.round(rd.width / ml.block)), Math.max(1, Math.round(rd.height / ml.block)))
            smooth: false
            live: true
        }

    }

}
