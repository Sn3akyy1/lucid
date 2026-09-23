.pragma library

// the m3 expressive shape library, as radial functions sampled round a circle.
// every shape shares the same angles, so any two can be morphed point by point

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

// [radius fn, smoothing window, rotation]
var defs = {
    "circle": [function(t) { return 1; }, 0, 0],
    "square": [function(t) { return superellipse(t, 1, 1, 5.5); }, 2, 0],
    "slanted": [function(t) { return superellipse(t, 1, 0.92, 4.5) * (1 + 0.05 * Math.sin(2 * t)); }, 3, 0],
    "pill": [function(t) { return superellipse(t, 1, 0.62, 3.2); }, 2, -Math.PI / 4],
    "oval": [function(t) { return superellipse(t, 1, 0.7, 2); }, 0, -Math.PI / 4],
    "triangle": [function(t) { return polygon(3, t); }, 9, -Math.PI / 2],
    "diamond": [function(t) { return superellipse(t, 1, 0.8, 1.15); }, 6, 0],
    "pentagon": [function(t) { return polygon(5, t); }, 4, -Math.PI / 2],
    "gem": [function(t) { return polygon(6, t) * (1 - 0.04 * Math.cos(2 * t)); }, 6, 0],
    "cookie4": [function(t) { return 1 - 0.13 * (1 - Math.cos(4 * t)) / 2; }, 2, Math.PI / 4],
    "cookie6": [function(t) { return 1 - 0.1 * (1 - Math.cos(6 * t)) / 2; }, 2, 0],
    "cookie7": [function(t) { return 1 - 0.1 * (1 - Math.cos(7 * t)) / 2; }, 2, -Math.PI / 2],
    "cookie9": [function(t) { return 1 - 0.085 * (1 - Math.cos(9 * t)) / 2; }, 1, -Math.PI / 2],
    "cookie12": [function(t) { return 1 - 0.07 * (1 - Math.cos(12 * t)) / 2; }, 1, 0],
    "clover4": [function(t) { return 0.5 + 0.5 * Math.pow(Math.abs(Math.cos(2 * t)), 0.9); }, 3, Math.PI / 4],
    "clover8": [function(t) { return 0.76 + 0.24 * Math.pow(Math.abs(Math.cos(4 * t)), 0.6); }, 3, 0],
    "sunny": [function(t) { return 1 - 0.13 * (1 - tri(8 * t)); }, 3, 0],
    "verySunny": [function(t) { return 1 - 0.24 * (1 - tri(8 * t)); }, 2, 0],
    "burst": [function(t) { return 1 - 0.2 * (1 - tri(12 * t)); }, 1, 0],
    "softBurst": [function(t) { return 1 - 0.17 * (1 - tri(10 * t)); }, 3, 0],
    "flower": [function(t) { return 0.72 + 0.28 * Math.pow(Math.abs(Math.cos(4 * t)), 0.8); }, 3, Math.PI / 8],
    "arch": [function(t) { return Math.sin(t) > 0 ? superellipse(t, 1, 1, 4) : 1; }, 2, 0],
    "puffy": [function(t) { return 0.88 + 0.12 * Math.pow(Math.abs(Math.cos(3 * t)), 0.5) - 0.05 * Math.cos(2 * t); }, 3, 0]
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

// catmull-rom through the samples, as cubic segments
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
