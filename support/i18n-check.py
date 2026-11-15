#!/usr/bin/env python3
# i18n-check.py [--root DIR] [--lang CODE] [--write] [--strict] [PATHS...]
#
# keeps the code and the catalogues (i18n/<code>.json) in step:
#   missing       a text the code asks for that the catalogue lacks
#   unused        a catalogue entry nothing asks for any more
#   empty         an entry still "" (an error only with --strict)
#   placeholders  a translation whose %1..%9 differ from the English
#   plural        an I18n.trn text without a {one, other} entry, or the reverse
#   nonliteral    I18n.tr*(x) with no literal to extract (allow: // i18n-dynamic)
#   unwrapped     a bare literal on a label-like property (allow: // i18n-skip)
#   compared      a text the file translates, then compares or passes on in English
# PATHS narrows only the unwrapped scan; the rest always looks at everything.
# --write adds what is missing as "", drops what is unused and sorts the file.
import argparse
import json
import os
import re
import sys

STR = re.compile(r'"(?:[^"\\\n]|\\.)*"')
CALL = re.compile(r"\bI18n\.(trn|trc|tr)\(")
PROP = re.compile(r'(?:^|[{;,])\s*(text|title|label|placeholderText|placeholder|subtitle|description|blurb|disabledReason|emptyText|tooltip|detailText|labelText|warning|unavailableReason|resetTitle|resetBody|heading|confirmLabel|"label"|"title"|"blurb"|"description"|"desc"|"hint"|"note"|"more"|"when"|"subtitle")\s*:')
MARK = re.compile(r"%[1-9]")
CMP = re.compile(r"[!=]==?\s*$")


def compared(line, m):
    """a literal on either side of ==, ===, != or !==, or a subscript ["key"],
    is a value, not a label"""
    if line[: m.start()].endswith("[") and line[m.end():].startswith("]"):
        return True
    # the first argument of a call that is not I18n's: a key, an id, a path
    if re.search(r"[\w$]\($", line[: m.start()]):
        return True
    return bool(CMP.search(line[: m.start()])) or bool(re.match(r"\s*[!=]==?", line[m.end():]))
SKIP_DIRS = {".git", ".superpowers", "docs", "node_modules", "__pycache__"}
SKIP_PATHS = (os.path.join("support", "sddm"), os.path.join("support", "tests"))


def decode(lit):
    try:
        return json.loads(lit.replace("\\'", "'"))
    except ValueError:
        return lit[1:-1]


def code_part(line):
    """the line up to a // comment that is not inside a string"""
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if c == '"':
            m = STR.match(line, i)
            i = m.end() if m else n
            continue
        if line.startswith("//", i):
            return line[:i]
        i += 1
    return line


def call_spans(line):
    """(start, end, kind, [literal args at the front]) for each I18n call"""
    out = []
    for m in CALL.finditer(line):
        i, depth, n = m.end(), 1, len(line)
        lits, front = [], True
        while i < n and depth:
            c = line[i]
            if c == '"':
                s = STR.match(line, i)
                if not s:
                    break
                if front and depth == 1:
                    lits.append(decode(s.group()))
                i = s.end()
                continue
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
            elif c == "," and depth == 1:
                pass
            elif not c.isspace():
                front = False
            i += 1
        out.append((m.start(), i, m.group(1), lits))
    return out


def value_spans(line):
    """(start, end) of each label-like property's value on the line. a value runs
    to the next , ; or closing bracket at its own depth; a list value is data
    (window titles, key names), never a label, so it gets no span"""
    out = []
    for m in PROP.finditer(line):
        i, n, depth = m.end(), len(line), 0
        while i < n and line[i].isspace():
            i += 1
        if i < n and line[i] == "[":
            continue
        start = i
        while i < n:
            c = line[i]
            if c == '"':
                s = STR.match(line, i)
                i = s.end() if s else n
                continue
            if c in "([{":
                depth += 1
            elif c in ")]}":
                if depth == 0:
                    break
                depth -= 1
            elif c in ",;" and depth == 0:
                break
            i += 1
        out.append((start, i))
    return out


def files_under(root, paths=None):
    tops = paths or [root]
    for top in tops:
        if os.path.isfile(top):
            yield top
            continue
        for d, dirs, names in os.walk(top):
            rel = os.path.relpath(d, root)
            dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not os.path.join(rel, x).lstrip("./").startswith(SKIP_PATHS))
            for name in sorted(names):
                if name.endswith((".qml", ".js")):
                    yield os.path.join(d, name)


def scan(root):
    """keys asked for: {key: {"kind": "tr"|"trn", "where": "file:line", "marks": set}}, and problems"""
    keys, problems = {}, []
    for path in files_under(root):
        rel = os.path.relpath(path, root)
        with open(path, encoding="utf-8") as f:
            for no, raw in enumerate(f, 1):
                line = code_part(raw)
                for _s, _e, kind, lits in call_spans(line):
                    need = 2 if kind in ("trc", "trn") else 1
                    if len(lits) < need:
                        if "i18n-dynamic" not in raw:
                            problems.append(f"{rel}:{no}: nonliteral: {line.strip()}")
                        continue
                    if kind == "trc":
                        key, marks = lits[0] + "|" + lits[1], set(MARK.findall(lits[1]))
                    elif kind == "trn":
                        key, marks = lits[0], set(MARK.findall(lits[0])) | set(MARK.findall(lits[1]))
                    else:
                        key, marks = lits[0], set(MARK.findall(lits[0]))
                    keys.setdefault(key, {"kind": "trn" if kind == "trn" else "tr", "where": f"{rel}:{no}", "marks": marks})
    return keys, problems


def unwrapped(root, paths):
    out = []
    for path in files_under(root, paths):
        rel = os.path.relpath(path, root)
        with open(path, encoding="utf-8") as f:
            for no, raw in enumerate(f, 1):
                line = code_part(raw)
                values = value_spans(line)
                if "i18n-skip" in raw or not values:
                    continue
                spans = call_spans(line)
                for m in STR.finditer(line):
                    if not any(s <= m.start() < e for s, e in values):
                        continue
                    text = decode(m.group())
                    if not any(ch.isalpha() for ch in text):
                        continue
                    if compared(line, m) or any(s <= m.start() < e for s, e, _k, _l in spans):
                        continue
                    out.append(f"{rel}:{no}: unwrapped: {m.group()}")
    return out


def compared_labels(root):
    """a text the file translates, then compares or hands on in English: once the
    shell speaks another language the two never match"""
    out = []
    for path in files_under(root):
        rel = os.path.relpath(path, root)
        raw = open(path, encoding="utf-8").readlines()
        lines = [code_part(l) for l in raw]
        mine = set()
        for line in lines:
            for _s, _e, kind, lits in call_spans(line):
                if kind == "tr" and lits:
                    mine.add(lits[0])
        if not mine:
            continue
        for no, line in enumerate(lines, 1):
            if "i18n-skip" in raw[no - 1]:
                continue
            spans = call_spans(line)
            for m in STR.finditer(line):
                text = decode(m.group())
                if text not in mine or any(s <= m.start() < e for s, e, _k, _l in spans):
                    continue
                if CMP.search(line[: m.start()]) or re.match(r"\s*[!=]==?", line[m.end():]) or re.search(r"[\w$]\($", line[: m.start()]):
                    out.append(f"{rel}:{no}: compared: {json.dumps(text, ensure_ascii=False)}")
    return out


def dump(cat):
    meta = {"_meta": cat["_meta"]} if "_meta" in cat else {}
    body = {k: cat[k] for k in sorted(k for k in cat if k != "_meta")}
    return json.dumps({**meta, **body}, ensure_ascii=False, indent=2) + "\n"


def compare(keys, cat, name):
    errors, empty = [], []
    for key, info in sorted(keys.items()):
        if key not in cat:
            errors.append(f"{info['where']}: missing: {json.dumps(key, ensure_ascii=False)} ({name})")
            continue
        v = cat[key]
        if info["kind"] == "trn" and not isinstance(v, dict):
            errors.append(f"{info['where']}: plural: {json.dumps(key, ensure_ascii=False)} needs {{one, other}} ({name})")
            continue
        if info["kind"] == "tr" and isinstance(v, dict):
            errors.append(f"{info['where']}: plural: {json.dumps(key, ensure_ascii=False)} is not a plural ({name})")
            continue
        forms = [v.get("one", ""), v.get("other", "")] if isinstance(v, dict) else [v]
        if any(f == "" for f in forms):
            empty.append(f"{info['where']}: empty: {json.dumps(key, ensure_ascii=False)} ({name})")
        for f in forms:
            if f and set(MARK.findall(f)) != info["marks"]:
                errors.append(f"{info['where']}: placeholders: {json.dumps(key, ensure_ascii=False)} -> {json.dumps(f, ensure_ascii=False)} ({name})")
                break
    unused = [k for k in cat if k != "_meta" and k not in keys]
    return errors, empty, unused


def main(argv):
    ap = argparse.ArgumentParser(description="keep the code and the i18n catalogues in step")
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--lang")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("paths", nargs="*")
    a = ap.parse_args(argv)
    root = os.path.abspath(a.root)

    keys, problems = scan(root)
    problems += unwrapped(root, [os.path.abspath(p) for p in a.paths] or None)
    problems += compared_labels(root)
    for p in problems:
        print(p)
    bad = bool(problems)

    cdir = os.path.join(root, "i18n")
    langs = [a.lang] if a.lang else sorted(f[:-5] for f in os.listdir(cdir) if f.endswith(".json")) if os.path.isdir(cdir) else []
    for lang in langs:
        path = os.path.join(cdir, lang + ".json")
        name = os.path.relpath(path, root)
        with open(path, encoding="utf-8") as f:
            cat = json.load(f)
        errors, empty, unused = compare(keys, cat, name)
        for k in unused:
            print(f"{name}: unused: {json.dumps(k, ensure_ascii=False)}")
        if a.write:
            for k in unused:
                del cat[k]
            for key, info in keys.items():
                if key not in cat:
                    cat[key] = {"one": "", "other": ""} if info["kind"] == "trn" else ""
            with open(path, "w", encoding="utf-8") as f:
                f.write(dump(cat))
            errors, empty, unused = compare(keys, cat, name)
        for p in errors + (empty if a.strict else []):
            print(p)
        bad = bad or bool(errors or unused or (a.strict and empty))
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
