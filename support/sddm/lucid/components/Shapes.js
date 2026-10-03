.pragma library

// the two shapes the greeter draws, cut from lucidui/Shapes.js: radial
// functions sampled round a circle, then joined with catmull-rom curves

var N = 96;
var cache = {};

// [radius fn, smoothing window, rotation]
var defs = {
    "circle": [function(t) { return 1; }, 0, 0],
    "cookie12": [function(t) { return 1 - 0.07 * (1 - Math.cos(12 * t)) / 2; }, 1, 0]
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
