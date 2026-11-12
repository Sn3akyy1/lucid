.pragma library
// lrclib.net answers, turned into lines the shell can follow: each line
// {t, end, text, words: [{t, end, text}]} in seconds, sorted. a line with only
// its own start gets its words spread over it by length, so every look can
// treat a track the same way whatever the source had

function stamp(s) {
    var m = /^(\d+):(\d+(?:\.\d+)?)$/.exec(s.trim());
    return m ? parseInt(m[1], 10) * 60 + parseFloat(m[2]) : -1;
}

// a yaml scalar the way lrclib writes them: plain, 'single' or "double"
function scalar(v) {
    v = v.trim();
    if (v.length >= 2 && v[0] === "'" && v[v.length - 1] === "'")
        return v.slice(1, -1).replace(/''/g, "'");
    if (v.length >= 2 && v[0] === '"' && v[v.length - 1] === '"') {
        try {
            return JSON.parse(v);
        } catch (e) {
            return v.slice(1, -1);
        }
    }
    return v;
}

// lrclib's "lyricsfile": a fixed yaml shape (lines, each with words), read
// line by line rather than with a yaml parser the shell does not have
function parseLyricsfile(src) {
    var lines = [];
    var line = null, word = null, inLines = false, last = null;
    var rows = String(src || "").split("\n");
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        if (/^lines:\s*$/.test(row)) {
            inLines = true;
            continue;
        }
        if (!inLines)
            continue;
        if (/^\S/.test(row) && !/^-/.test(row))
            break;
        var m = /^(\s*)(- )?(\w+):\s?(.*)$/.exec(row);
        if (!m) {
            // a long scalar folded onto the next row
            if (last && row.trim() !== "")
                last.o[last.k] += " " + scalar(row);
            continue;
        }
        var depth = m[1].length + (m[2] ? 2 : 0);
        var key = m[3], val = m[4];
        if (m[2] && m[1].length === 0) {
            line = { t: -1, end: -1, text: "", words: [] };
            lines.push(line);
            word = null;
        } else if (m[2] && line) {
            word = { t: -1, end: -1, text: "" };
            line.words.push(word);
        }
        var o = depth >= 4 ? word : line;
        if (!o)
            continue;
        last = null;
        if (key === "text") {
            o.text = scalar(val);
            last = { o: o, k: "text" };
        } else if (key === "start_ms") {
            o.t = parseFloat(val) / 1000;
        } else if (key === "end_ms") {
            o.end = parseFloat(val) / 1000;
        }
    }
    return lines.filter(function(l) { return l.t >= 0; });
}

// [mm:ss.xx] lines, several stamps on one line allowed, <mm:ss.xx> word stamps too
function parseLrc(src) {
    var out = [];
    var rows = String(src || "").split(/\r?\n/);
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i], stamps = [], m;
        var re = /^\s*\[(\d+:\d+(?:\.\d+)?)\]/;
        while ((m = re.exec(row))) {
            stamps.push(stamp(m[1]));
            row = row.slice(m[0].length);
        }
        if (!stamps.length)
            continue;
        var words = [];
        if (/<\d+:\d+(?:\.\d+)?>/.test(row)) {
            var parts = row.split(/<(\d+:\d+(?:\.\d+)?)>/);
            for (var p = 1; p < parts.length; p += 2)
                if (parts[p + 1] && parts[p + 1].trim() !== "")
                    words.push({ t: stamp(parts[p]), end: -1, text: parts[p + 1] });
            row = parts.filter(function(_, k) { return k % 2 === 0; }).join("");
        }
        for (var s = 0; s < stamps.length; s++)
            out.push({ t: stamps[s], end: -1, text: row.trim(), words: words });
    }
    return out.sort(function(a, b) { return a.t - b.t; });
}

// ends filled in, and words for a line that came without them
function finish(lines, length) {
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        var next = i + 1 < lines.length ? lines[i + 1].t : (length > 0 ? length : l.t + 6);
        if (l.end <= l.t)
            l.end = next;
        l.end = Math.min(l.end, Math.max(next, l.t));
        l.text = l.text.trim();
        if (!l.words.length && l.text !== "") {
            var ws = l.text.split(/\s+/);
            var chars = l.text.replace(/\s+/g, "").length || 1;
            // most of the line is sung, but an instrumental break after it is not part of it
            var span = Math.min((l.end - l.t) * 0.9, Math.max(1, chars * 0.15));
            var at = l.t;
            for (var w = 0; w < ws.length; w++) {
                var d = span * ws[w].length / chars;
                l.words.push({ t: at, end: at + d, text: ws[w] });
                at += d;
            }
        } else {
            for (var k = 0; k < l.words.length; k++) {
                var wd = l.words[k];
                wd.text = String(wd.text).trim();
                if (wd.end <= wd.t)
                    wd.end = k + 1 < l.words.length ? l.words[k + 1].t : l.end;
            }
            l.words = l.words.filter(function(x) { return x.text !== ""; });
        }
    }
    return lines;
}

// the answer of /api/get (one record) or /api/search (a list): the record that
// fits the track best, word sync over line sync over plain
function pick(answer, artist, length) {
    var list = Array.isArray(answer) ? answer : (answer && typeof answer === "object" ? [answer] : []);
    var a = String(artist || "").toLowerCase();
    var best = null, score = -1e9;
    for (var i = 0; i < list.length; i++) {
        var r = list[i];
        if (!r || (!r.syncedLyrics && !r.plainLyrics && !r.instrumental))
            continue;
        var sc = 0;
        if (a !== "" && String(r.artistName || "").toLowerCase().indexOf(a) === -1 && a.indexOf(String(r.artistName || "").toLowerCase()) === -1)
            sc -= 50;
        if (length > 0 && r.duration > 0)
            sc -= Math.min(40, Math.abs(r.duration - length) * 2);
        sc += r.hasWordSync ? 6 : (r.syncedLyrics ? 4 : 0);
        if (sc > score) {
            score = sc;
            best = r;
        }
    }
    return best;
}

// {status: "found"|"instrumental"|"none", synced, lines, record}
function read(answer, artist, length) {
    var r = pick(answer, artist, length);
    if (!r)
        return { status: "none", synced: false, lines: [], record: null };
    var out = readRecord(r, length);
    out.record = r;
    return out;
}

function readRecord(r, length) {
    if (r.instrumental && !r.syncedLyrics && !r.plainLyrics)
        return { status: "instrumental", synced: false, lines: [] };
    var lines = r.hasWordSync && r.lyricsfile ? parseLyricsfile(r.lyricsfile) : [];
    if (!lines.length && r.syncedLyrics)
        lines = parseLrc(r.syncedLyrics);
    if (lines.length)
        return { status: "found", synced: true, lines: finish(lines, length) };
    var plain = String(r.plainLyrics || "").split(/\r?\n/).map(function(t) {
        return { t: -1, end: -1, text: t.trim(), words: [] };
    });
    return { status: plain.length ? "found" : "none", synced: false, lines: plain };
}

// the line playing at sec, -1 before the first
function lineAt(lines, sec, hint) {
    if (!lines.length || lines[0].t < 0 || sec < lines[0].t)
        return -1;
    var i = hint >= 0 && hint < lines.length && lines[hint].t <= sec ? hint : 0;
    while (i + 1 < lines.length && lines[i + 1].t <= sec)
        i++;
    return i;
}

// how many letters of a word have been sung at sec, 0..length, fractional
// inside the letter being sung. letters go at a sung pace; whatever time the
// word has beyond that is held on its last vowel, where a singer stretches it,
// so a long note stalls the fill there instead of slowing the whole word
var letterPace = 0.07;

function lettersSung(wd, sec) {
    var n = wd ? wd.text.length : 0;
    if (!n || sec <= wd.t)
        return 0;
    var d = wd.end - wd.t;
    if (d <= 0 || sec >= wd.end)
        return n;
    var hold = Math.max(0, d - n * letterPace);
    var pace = hold > 0 ? letterPace : d / n;
    var held = -1;
    for (var i = n - 1; i >= 0 && hold > 0; i--)
        if (/[aeiouyàáâãäåèéêëìíîïòóôõöùúûüýæœ]/i.test(wd.text[i])) {
            held = i;
            break;
        }
    // no vowel to hold: the word just goes slower
    if (hold > 0 && held < 0) {
        pace = d / n;
        hold = 0;
    }
    var at = sec - wd.t;
    for (var k = 0; k < n; k++) {
        var slot = pace + (k === held ? hold : 0);
        if (at < slot)
            return k + at / slot;
        at -= slot;
    }
    return n;
}

// a caption's words in two rows as even as their letters allow, the first
// row the longer one on a tie, the way subtitles break a line
function splitRows(words) {
    if (!words || words.length < 2)
        return [words || []];
    var len = function(a, b) {
        var n = 0;
        for (var i = a; i < b; i++)
            n += words[i].text.length + (i > a ? 1 : 0);
        return n;
    };
    var best = 1, diff = 1e9;
    for (var k = 1; k < words.length; k++) {
        var d = len(0, k) - len(k, words.length);
        var score = Math.abs(d) + (d < 0 ? 0.5 : 0);
        if (score < diff) {
            diff = score;
            best = k;
        }
    }
    return [words.slice(0, best), words.slice(best)];
}
