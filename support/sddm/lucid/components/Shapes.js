.pragma library
.import "ShapeRadii.js" as Table

// lucidui/Shapes.js for the greeter, reading the greeter's own table

var N = Table.N;

function radii(name) {
    return Table.r[name] || Table.r.circle;
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
