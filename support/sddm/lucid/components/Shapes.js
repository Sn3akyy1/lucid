.pragma library

// the shapes the greeter draws, cut from lucidui/Shapes.js: radial
// functions sampled round a circle, then joined with catmull-rom curves

var N = 96;
var cache = {};

function tri(x) {
    var f = x / (2 * Math.PI);
    f = f - Math.floor(f);
    return Math.abs(f * 2 - 1);
}

function polygon(n, th) {
    var seg = 2 * Math.PI / n;
    var a = th - Math.floor(th / seg) * seg - seg / 2;
    return Math.cos(Math.PI / n) / Math.cos(a);
}

function superellipse(th, a, b, p) {
    var c = Math.abs(Math.cos(th)) / a;
    var s = Math.abs(Math.sin(th)) / b;
    return Math.pow(Math.pow(c, p) + Math.pow(s, p), -1 / p);
}

// a polygon given as [x, y, ...] about the centre, for an inside test
function within(v, x, y) {
    var hit = false;
    for (var i = 0, j = v.length - 2; i < v.length; j = i, i += 2) {
        if ((v[i + 1] > y) !== (v[j + 1] > y) && x < (v[j] - v[i]) * (y - v[i + 1]) / (v[j + 1] - v[i + 1]) + v[i])
            hit = !hit;

    }
    return hit;
}

// the radius of any shape the centre can see all of, found by bisection
function hull(inside) {
    return function(t) {
        var lo = 0, hi = 2;
        var c = Math.cos(t), s = Math.sin(t);
        for (var i = 0; i < 22; i++) {
            var m = (lo + hi) / 2;
            if (inside(m * c, m * s))
                lo = m;
            else
                hi = m;
        }
        return lo;
    };
}

// [radius fn, smoothing window, rotation]
var defs = {
    "circle": [function(t) { return 1; }, 0, 0],
    "cookie12": [function(t) { return 1 - 0.07 * (1 - Math.cos(12 * t)) / 2; }, 1, 0],
    "square": [function(t) { return superellipse(t, 1, 1, 5.5); }, 2, 0],
    "slanted": [function(t) { return superellipse(t, 1, 0.92, 4.5) * (1 + 0.05 * Math.sin(2 * t)); }, 3, 0],
    "arch": [function(t) { return Math.sin(t) > 0 ? superellipse(t, 1, 1, 4) : 1; }, 2, 0],
    "fan": [hull(function(x, y) { return Math.abs(x) <= 1 && Math.abs(y) <= 1 && (x < -0.6 || y > 0.6 || (x + 0.6) * (x + 0.6) + (y - 0.6) * (y - 0.6) <= 2.56); }), 2, 0],
    "arrow": [hull(function(x, y) { return within([0, -1.32, 1.45, 1.12, 0, 0.78, -1.43, 1.1], x, y); }), 4, 0],
    "semiCircle": [hull(function(x, y) { return y >= -0.5 && x * x + (y + 0.5) * (y + 0.5) <= 1; }), 3, 0],
    "triangle": [function(t) { return polygon(3, t); }, 9, -Math.PI / 2],
    "diamond": [function(t) { return superellipse(t, 1, 0.8, 1.15); }, 6, 0],
    "clamShell": [hull(function(x, y) { return within([-0.66, -0.68, 0.66, -0.68, 1.04, 0, 0.66, 0.68, -0.66, 0.68, -1.04, 0], x, y); }), 3, 0],
    "pentagon": [function(t) { return polygon(5, t); }, 4, -Math.PI / 2],
    "gem": [function(t) { return polygon(6, t) * (1 - 0.04 * Math.cos(2 * t)); }, 6, 0],
    "sunny": [function(t) { return 1 - 0.13 * (1 - tri(8 * t)); }, 3, 0],
    "verySunny": [function(t) { return 1 - 0.24 * (1 - tri(8 * t)); }, 2, 0],
    "cookie4": [function(t) { return 1 - 0.13 * (1 - Math.cos(4 * t)) / 2; }, 2, Math.PI / 4],
    "ghostish": [hull(function(x, y) { var a = Math.abs(x); return y < 0 ? x * x + y * y <= 1 : a <= 1 && y <= (a <= 0.15 ? 0.81 : 0.81 + (a - 0.15) * 0.553); }), 3, 0],
    "softBurst": [function(t) { return 1 - 0.17 * (1 - tri(10 * t)); }, 3, 0]
};

function radii(name) {
    if (cache[name])
        return cache[name];

    var d = defs[name] || defs.circle;
    var raw = [];
    for (var i = 0; i < N; i++)
        raw.push(d[0](i / N * 2 * Math.PI - d[2]));

    var w = d[1];
    var out = raw;
    if (w > 0) {
        out = [];
        for (var j = 0; j < N; j++) {
            var sum = 0;
            for (var k = -w; k <= w; k++)
                sum += raw[(j + k + N) % N];

            out.push(sum / (2 * w + 1));
        }
    }
    var mx = 0;
    for (var m = 0; m < N; m++)
        mx = Math.max(mx, out[m]);

    for (var q = 0; q < N; q++)
        out[q] = out[q] / mx;

    cache[name] = out;
    return out;
}

function mix(a, b, f) {
    var out = [];
    for (var i = 0; i < N; i++)
        out.push(a[i] + (b[i] - a[i]) * f);

    return out;
}

function svg(r, size, rot) {
    var c = size / 2;
    var R = size / 2;
    var pts = [];
    for (var i = 0; i < N; i++) {
        var th = i / N * 2 * Math.PI + (rot || 0);
        pts.push([c + R * r[i] * Math.cos(th), c + R * r[i] * Math.sin(th)]);
    }
    var d = "M" + pts[0][0].toFixed(2) + " " + pts[0][1].toFixed(2);
    for (var j = 0; j < N; j++) {
        var p0 = pts[(j - 1 + N) % N], p1 = pts[j], p2 = pts[(j + 1) % N], p3 = pts[(j + 2) % N];
        var c1x = p1[0] + (p2[0] - p0[0]) / 6, c1y = p1[1] + (p2[1] - p0[1]) / 6;
        var c2x = p2[0] - (p3[0] - p1[0]) / 6, c2y = p2[1] - (p3[1] - p1[1]) / 6;
        d += "C" + c1x.toFixed(2) + " " + c1y.toFixed(2) + " " + c2x.toFixed(2) + " " + c2y.toFixed(2) + " " + p2[0].toFixed(2) + " " + p2[1].toFixed(2);
    }
    return d + "Z";
}

function path(name, size, rot) {
    return svg(radii(name), size, rot);
}
