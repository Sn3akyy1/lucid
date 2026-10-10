import QtQuick
import QtQuick.Shapes
import qs

// one of Material's expressive shapes, drawn rather than shipped, so it can
// breathe and turn: a circle with soft lobes (the cookies), a polygon with
// rounded corners (the pentagon the calendar marks today with), or a squircle.
// All of them follow the shell's roundness dial: squared off, the lobes flatten
// and the corners sharpen; rounder, they soften.
Shape {
    id: sh

    // "lobed", "polygon" or "squircle"
    property string form: "lobed"
    // lobes for a cookie, sides for a polygon
    property int lobes: 8
    // how far a cookie's dips reach in, as a share of the radius
    property real depth: 0.08
    // how much of each polygon edge its rounded corners take, 0 to 0.5
    property real round: 0.3
    // degrees
    property real spin: 0
    property color fill: "white"

    // the shell's corner scale: 1 as shipped, 0 square, up to 2 rounder
    readonly property real k: Math.max(0, Theme.cornerScale)
    // 0 as shipped, 1 when the shell is squared right off
    readonly property real square: Math.max(0, Math.min(1, 1 - sh.k))

    // a superellipse: 2 is a circle, 4 the app-icon squircle, 20 near square
    function superR(t, p) {
        var c = Math.abs(Math.cos(t));
        var s = Math.abs(Math.sin(t));
        return 1 / Math.pow(Math.pow(c, p) + Math.pow(s, p), 1 / p);
    }

    function polygon(R, cx, cy, a0) {
        var n = Math.max(3, sh.lobes);
        var rounding = Math.max(0, Math.min(0.5, sh.round * Math.min(1.6, sh.k)));
        var v = [];
        for (var i = 0; i < n; i++) {
            var t = a0 - Math.PI / 2 + i * 2 * Math.PI / n;
            v.push(Qt.point(cx + R * Math.cos(t), cy + R * Math.sin(t)));
        }
        var out = [];
        for (var j = 0; j < n; j++) {
            var p = v[(j + n - 1) % n];
            var c = v[j];
            var q = v[(j + 1) % n];
            // a quadratic corner from partway down one edge to partway down
            // the next, the way the calendar's blob is drawn
            var ax = c.x + (p.x - c.x) * rounding;
            var ay = c.y + (p.y - c.y) * rounding;
            var bx = c.x + (q.x - c.x) * rounding;
            var by = c.y + (q.y - c.y) * rounding;
            for (var s = 0; s <= 10; s++) {
                var u = s / 10;
                var w0 = (1 - u) * (1 - u);
                var w1 = 2 * (1 - u) * u;
                var w2 = u * u;
                out.push(Qt.point(w0 * ax + w1 * c.x + w2 * bx, w0 * ay + w1 * c.y + w2 * by));
            }
        }
        out.push(out[0]);
        return out;
    }

    readonly property var points: {
        var R = Math.min(sh.width, sh.height) / 2;
        var cx = sh.width / 2;
        var cy = sh.height / 2;
        var a0 = sh.spin * Math.PI / 180;
        if (sh.form === "polygon")
            return sh.polygon(R * 0.98, cx, cy, a0);

        var out = [];
        var n = 144;
        // squaring off pulls every form toward the same near-square
        var flat = 20;
        for (var i = 0; i <= n; i++) {
            var t = i / n * Math.PI * 2;
            var r;
            if (sh.form === "squircle") {
                var p = sh.k >= 1 ? Math.max(2.4, 4 / sh.k) : 4 + (flat - 4) * sh.square;
                r = sh.superR(t, p) * 0.86;
            } else {
                var d = sh.depth * Math.min(1.5, sh.k);
                var lobed = 1 - d * (1 - Math.cos(sh.lobes * t)) / 2;
                r = lobed * (1 - sh.square) + sh.superR(t + a0, flat) * 0.84 * sh.square;
            }
            out.push(Qt.point(cx + R * r * Math.cos(t + a0), cy + R * r * Math.sin(t + a0)));
        }
        return out;
    }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: sh.fill
        strokeWidth: 0
        strokeColor: "transparent"

        PathPolyline {
            path: sh.points
        }

    }

}
