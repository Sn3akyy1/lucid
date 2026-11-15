.pragma library

// the rules behind I18n, kept free of any state so they can be tested alone.
// a catalogue is a plain object keyed by the English text; "" means not
// translated yet, and a missing or empty entry falls back to the English

function lookup(strings, key) {
    var v = strings ? strings[key] : undefined;
    return v === "" || v === null ? undefined : v;
}

// %1..%9 take the matching argument; a % not followed by a digit stays as it is
function format(text, args) {
    return String(text).replace(/%([1-9])/g, function(m, n) {
        var i = Number(n) - 1;
        return args && i < args.length ? String(args[i]) : m;
    });
}

function tr(strings, text, args) {
    var v = lookup(strings, text);
    return format(typeof v === "string" ? v : text, args);
}

function trc(strings, ctx, text, args) {
    var v = lookup(strings, ctx + "|" + text);
    return format(typeof v === "string" ? v : text, args);
}

// English and Spanish share the rule: one for 1, other for the rest. a language
// with more forms would grow it here
function trn(strings, singular, plural, n, args) {
    var a = args && args.length ? args : [n];
    var v = lookup(strings, singular);
    var form = n === 1 ? "one" : "other";
    if (v && typeof v === "object" && typeof v[form] === "string" && v[form] !== "")
        return format(v[form], a);

    return format(n === 1 ? singular : plural, a);
}

// the locale the environment asks for, the way libc reads it: LC_ALL, then
// LC_MESSAGES, then LANG. "es_MX.UTF-8@euro" -> "es_MX"; C and POSIX mean none
function envLocale(lcAll, lcMessages, lang) {
    var v = lcAll || lcMessages || lang || "";
    v = v.split(".")[0].split("@")[0];
    return v === "C" || v === "POSIX" ? "" : v;
}

// the catalogues worth trying for a locale, most specific first
function candidates(code) {
    if (!code)
        return [];

    var base = code.split("_")[0];
    return base === code ? [code] : [code, base];
}

// pref "auto" follows the environment; English needs no catalogue, so it is
// what is left when none of the candidates exists
function resolve(pref, envCode, available) {
    var want = pref === "auto" ? envCode : pref;
    var c = candidates(want);
    for (var i = 0; i < c.length; i++) {
        if (c[i] === "en" || available.indexOf(c[i]) >= 0)
            return c[i];
    }
    return "en";
}
