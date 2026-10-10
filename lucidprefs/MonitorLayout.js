.pragma library

// where a display dragged on the Displays map lands. rects are in hyprland's
// layout coordinates: { x, y, w, h }

function overlaps(a, b) {
    return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

// v kept within lo..hi, then pulled onto the nearest line within reach
function settleAxis(v, lines, reach, lo, hi) {
    let out = Math.max(lo, Math.min(hi, v));
    let best = reach;
    for (const c of lines) {
        if (c < lo || c > hi)
            continue;

        const d = Math.abs(out - c);
        if (d <= best) {
            best = d;
            out = c;
        }
    }
    return out;
}

// the spot nearest to want (a top-left corner) where a display of size {w, h}
// touches at least one of the others along a stretch of edge and covers none
// of them, so the pointer can always cross and nothing is stacked. edges line
// up with the others' tops, bottoms and middles when they come within reach.
// null when nothing fits, which only a crowded layout gets to
function land(size, want, others, reach) {
    if (others.length === 0)
        return {
            "x": Math.round(want.x),
            "y": Math.round(want.y)
        };

    const xs = [];
    const ys = [];
    for (const o of others) {
        xs.push(o.x, o.x + o.w - size.w, Math.round(o.x + (o.w - size.w) / 2));
        ys.push(o.y, o.y + o.h - size.h, Math.round(o.y + (o.h - size.h) / 2));
    }
    let best = null;
    let bestD = Infinity;
    const consider = (x, y) => {
        const r = {
            "x": Math.round(x),
            "y": Math.round(y),
            "w": size.w,
            "h": size.h
        };
        if (others.some((o) => {
            return overlaps(r, o);
        }))
            return ;

        const d = Math.hypot(r.x - want.x, r.y - want.y);
        if (d < bestD) {
            bestD = d;
            best = {
                "x": r.x,
                "y": r.y
            };
        }
    };
    for (const o of others) {
        // a fifth of the shorter edge has to be shared, so a corner that only
        // just touches does not count as a way across
        const shareY = Math.max(1, Math.round(Math.min(size.h, o.h) / 5));
        const shareX = Math.max(1, Math.round(Math.min(size.w, o.w) / 5));
        for (const x of [o.x - size.w, o.x + o.w])
            consider(x, settleAxis(want.y, ys, reach, o.y - size.h + shareY, o.y + o.h - shareY));
        for (const y of [o.y - size.h, o.y + o.h])
            consider(settleAxis(want.x, xs, reach, o.x - size.w + shareX, o.x + o.w - shareX), y);
    }
    return best;
}

// the same layout moved so its top-left corner is 0,0, the way other desktops
// keep it. positions is { key: { x, y } }
function normalise(positions) {
    const keys = Object.keys(positions);
    if (keys.length === 0)
        return {};

    let x0 = Infinity;
    let y0 = Infinity;
    for (const k of keys) {
        x0 = Math.min(x0, positions[k].x);
        y0 = Math.min(y0, positions[k].y);
    }
    const out = {};
    for (const k of keys)
        out[k] = {
            "x": positions[k].x - x0,
            "y": positions[k].y - y0
        };
    return out;
}
