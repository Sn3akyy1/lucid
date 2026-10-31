import QtQuick
import QtQuick.Shapes
import qs

// one mark on a capture. the editor keeps them as plain objects in the stage's
// own coordinates: { kind, color, size, pts | x1 y1 x2 y2, text, n }. the item
// sits on the mark's own bounds, so a highlighter's layer is no bigger than it
Item {
    id: mk

    property var m: null
    // the picture under the marks, which a redaction pixelates
    property Item base: null
    readonly property string kind: mk.m ? mk.m.kind : ""
    readonly property color ink: mk.m ? mk.m.color : "transparent"
    readonly property real size: mk.m ? mk.m.size : 4
    readonly property real ax: mk.m && mk.m.x1 !== undefined ? mk.m.x1 : 0
    readonly property real ay: mk.m && mk.m.y1 !== undefined ? mk.m.y1 : 0
    readonly property real bx: mk.m && mk.m.x2 !== undefined ? mk.m.x2 : mk.ax
    readonly property real by: mk.m && mk.m.y2 !== undefined ? mk.m.y2 : mk.ay
    readonly property bool lightInk: (0.299 * mk.ink.r + 0.587 * mk.ink.g + 0.114 * mk.ink.b) > 0.6
    // how far a stroke reaches past the points it runs through
    readonly property real reach: mk.kind === "arrow" ? mk.size * 3 : mk.size
    // the bounds, in stage coordinates
    readonly property rect span: {
        if (!mk.m)
            return Qt.rect(0, 0, 0, 0);

        if (mk.kind === "pen" || mk.kind === "hl") {
            const p = mk.m.pts || [];
            if (p.length < 2)
                return Qt.rect(0, 0, 0, 0);

            let x0 = p[0], y0 = p[1], x1 = p[0], y1 = p[1];
            for (let i = 2; i + 1 < p.length; i += 2) {
                x0 = Math.min(x0, p[i]);
                x1 = Math.max(x1, p[i]);
                y0 = Math.min(y0, p[i + 1]);
                y1 = Math.max(y1, p[i + 1]);
            }
            return Qt.rect(x0 - mk.reach, y0 - mk.reach, x1 - x0 + mk.reach * 2, y1 - y0 + mk.reach * 2);
        }
        if (mk.kind === "step")
            return Qt.rect(mk.ax - mk.size / 2 - 2, mk.ay - mk.size / 2 - 2, mk.size + 4, mk.size + 4);

        if (mk.kind === "text")
            return Qt.rect(mk.ax, mk.ay, words.implicitWidth + 4, words.implicitHeight + 4);

        const x0 = Math.min(mk.ax, mk.bx), y0 = Math.min(mk.ay, mk.by);
        const w = Math.abs(mk.bx - mk.ax), h = Math.abs(mk.by - mk.ay);
        if (mk.kind === "redact")
            return Qt.rect(x0, y0, w, h);

        return Qt.rect(x0 - mk.reach, y0 - mk.reach, w + mk.reach * 2, h + mk.reach * 2);
    }
    // a pen stroke's points, made local
    readonly property var points: {
        const p = mk.m && mk.m.pts ? mk.m.pts : [];
        const out = [];
        for (let i = 0; i + 1 < p.length; i += 2)
            out.push(Qt.point(p[i] - mk.span.x, p[i + 1] - mk.span.y));
        // a click with no drag still leaves a dot
        if (out.length === 1)
            out.push(Qt.point(out[0].x + 0.01, out[0].y));

        return out;
    }
    // an arrow's shaft and head, made local
    readonly property var arrow: {
        const dx = mk.bx - mk.ax, dy = mk.by - mk.ay;
        const len = Math.sqrt(dx * dx + dy * dy);
        if (mk.kind !== "arrow" || len < 1)
            return null;

        const ux = dx / len, uy = dy / len, nx = -uy, ny = ux;
        const head = Math.min(len * 0.6, Math.max(14, mk.size * 3.4));
        const wide = head * 0.92;
        const ox = mk.span.x, oy = mk.span.y;
        const tipX = mk.bx - ox, tipY = mk.by - oy;
        const baseX = tipX - ux * head, baseY = tipY - uy * head;
        const neckX = tipX - ux * head * 0.7, neckY = tipY - uy * head * 0.7;
        return {
            "shaft": "M " + (mk.ax - ox) + " " + (mk.ay - oy) + " L " + neckX + " " + neckY,
            "head": "M " + tipX + " " + tipY + " L " + (baseX + nx * wide / 2) + " " + (baseY + ny * wide / 2) + " L " + (baseX - nx * wide / 2) + " " + (baseY - ny * wide / 2) + " Z"
        };
    }

    x: mk.span.x
    y: mk.span.y
    width: mk.span.width
    height: mk.span.height

    // a highlighter is see-through as one sheet, so where it crosses itself
    // it does not darken
    Item {
        anchors.fill: parent
        visible: mk.kind === "pen" || mk.kind === "hl"
        opacity: mk.kind === "hl" ? 0.42 : 1
        layer.enabled: mk.kind === "hl" && mk.width > 0
        layer.samples: 4

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: mk.ink
                strokeWidth: mk.size
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: mk.points
                }

            }

        }

    }

    Shape {
        anchors.fill: parent
        visible: mk.arrow !== null
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: mk.ink
            strokeWidth: mk.size
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: mk.arrow ? mk.arrow.shaft : ""
            }

        }

        // stroked as well as filled, which rounds the head's corners
        ShapePath {
            strokeColor: mk.ink
            strokeWidth: Math.max(2, mk.size * 0.55)
            fillColor: mk.ink
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: mk.arrow ? mk.arrow.head : ""
            }

        }

    }

    Rectangle {
        visible: mk.kind === "rect"
        x: mk.reach - mk.size / 2
        y: mk.reach - mk.size / 2
        width: mk.width - (mk.reach - mk.size / 2) * 2
        height: mk.height - (mk.reach - mk.size / 2) * 2
        radius: Math.min(Theme.dp(6) + mk.size, Math.min(width, height) / 2)
        color: "transparent"
        border.width: mk.size
        border.color: mk.ink
    }

    Shape {
        anchors.fill: parent
        visible: mk.kind === "oval"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: mk.ink
            strokeWidth: mk.size
            fillColor: "transparent"

            PathAngleArc {
                centerX: mk.width / 2
                centerY: mk.height / 2
                radiusX: Math.max(0.5, mk.width / 2 - mk.reach)
                radiusY: Math.max(0.5, mk.height / 2 - mk.reach)
                startAngle: 0
                sweepAngle: 360
            }

        }

    }

    Text {
        id: words

        visible: mk.kind === "text"
        x: 2
        y: 2
        text: mk.m && mk.m.text ? mk.m.text : ""
        color: mk.ink
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(8, Math.round(mk.size))
        font.weight: Font.Bold
        style: Text.Outline
        styleColor: mk.lightInk ? Theme.alpha("#000000", 0.6) : Theme.alpha("#ffffff", 0.75)
    }

    Rectangle {
        visible: mk.kind === "step"
        x: 2
        y: 2
        width: mk.size
        height: mk.size
        radius: width / 2
        color: mk.ink
        border.width: Math.max(1.5, mk.size * 0.07)
        border.color: mk.lightInk ? Theme.alpha("#000000", 0.35) : Theme.alpha("#ffffff", 0.85)

        Text {
            anchors.centerIn: parent
            text: mk.m && mk.m.n ? String(mk.m.n) : ""
            color: mk.lightInk ? "#1b1b1f" : "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(mk.size * 0.5)
            font.weight: Font.Bold
        }

    }

    // drawn from the picture itself at a twelfth of the size, then blown back
    // up without smoothing, so what was under it is gone rather than blurred
    Item {
        anchors.fill: parent
        visible: mk.kind === "redact" && mk.base !== null && mk.width >= 1 && mk.height >= 1
        clip: true

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: mk.kind === "redact" ? mk.base : null
            sourceRect: mk.base ? Qt.rect(mk.x - mk.base.x, mk.y - mk.base.y, mk.width, mk.height) : Qt.rect(0, 0, 0, 0)
            textureSize: Qt.size(Math.max(1, Math.ceil(mk.width / Math.max(4, mk.size))), Math.max(1, Math.ceil(mk.height / Math.max(4, mk.size))))
            smooth: false
            hideSource: false
        }

    }

}
