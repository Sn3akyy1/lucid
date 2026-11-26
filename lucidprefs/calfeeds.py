#!/usr/bin/env python3
"""Fetch subscribed calendars (.ics links) and write their events, one entry
per occurrence in local time, to a cache the shell reads.

    calfeeds.py '<feeds json>' <cache path>
    calfeeds.py --test

feeds: [{"id": "...", "name": "...", "url": "https://... or webcal://..."}]
A feed that fails keeps the events it had last time, so being offline does not
empty the calendar.
"""
import io
import json
import os
import sys
import time
import urllib.request
from datetime import date, datetime, timedelta, timezone

from dateutil import rrule, tz

PAST_DAYS = 62
AHEAD_DAYS = 366
MAX_PER_FEED = 3000
MAX_SPAN_DAYS = 31


def unfold(text):
    out = []
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if line[:1] in (" ", "\t") and out:
            out[-1] += line[1:]
        elif line:
            out.append(line)
    return out


def split_prop(line):
    # NAME;PARAM=a;PARAM2="b:c":value; a colon inside quotes is not the split
    quoted = False
    for i, ch in enumerate(line):
        if ch == '"':
            quoted = not quoted
        elif ch == ":" and not quoted:
            head, value = line[:i], line[i + 1:]
            break
    else:
        return None
    parts = head.split(";")
    params = {}
    for p in parts[1:]:
        if "=" in p:
            k, v = p.split("=", 1)
            params[k.upper()] = v.strip('"')
    return parts[0].upper(), params, value


def unescape(s):
    return (s.replace("\\n", " ").replace("\\N", " ").replace("\\,", ",")
            .replace("\\;", ";").replace("\\\\", "\\"))


def parse(text):
    """VEVENTs as {NAME: [(params, value), ...]} and the file's VTIMEZONEs."""
    lines = unfold(text)
    events, zones, stack, cur, zone_lines = [], {}, [], None, []
    for line in lines:
        prop = split_prop(line)
        if not prop:
            continue
        name, params, value = prop
        if name == "BEGIN":
            stack.append(value.upper())
            if stack[-1] == "VEVENT" and len(stack) == 2:
                cur = {}
        elif name == "END":
            top = stack.pop() if stack else ""
            if top == "VEVENT" and cur is not None:
                events.append(cur)
                cur = None
        elif cur is not None and stack[-1] == "VEVENT":
            cur.setdefault(name, []).append((params, value))
        if "VTIMEZONE" in stack or (name == "END" and value.upper() == "VTIMEZONE"):
            zone_lines.append(line)
    if zone_lines:
        try:
            cal = tz.tzical(io.StringIO("\n".join(zone_lines)))
            zones = {k: cal.get(k) for k in cal.keys()}
        except Exception:
            zones = {}
    return events, zones


def zone_for(tzid, zones):
    if not tzid:
        return None
    z = tz.gettz(tzid)
    return z if z is not None else zones.get(tzid)


def when(params, value, zones):
    """date for all-day, aware datetime when the zone is known, naive (floating
    local time) otherwise."""
    value = value.strip()
    if params.get("VALUE") == "DATE" or len(value) == 8:
        return date(int(value[:4]), int(value[4:6]), int(value[6:8]))
    dt = datetime.strptime(value[:15], "%Y%m%dT%H%M%S")
    if value.endswith("Z"):
        return dt.replace(tzinfo=timezone.utc)
    z = zone_for(params.get("TZID"), zones)
    return dt.replace(tzinfo=z) if z else dt


def as_dt(v):
    return v if isinstance(v, datetime) else datetime(v.year, v.month, v.day)


def duration(text):
    # PnW / PnDTnHnMnS
    sign = -1 if text.startswith("-") else 1
    text = text.lstrip("+-").lstrip("P")
    total, num, in_time = timedelta(), "", False
    units = {"W": timedelta(weeks=1), "D": timedelta(days=1)}
    tunits = {"H": timedelta(hours=1), "M": timedelta(minutes=1), "S": timedelta(seconds=1)}
    for ch in text:
        if ch == "T":
            in_time = True
        elif ch.isdigit():
            num += ch
        else:
            total += int(num or 0) * (tunits if in_time else units).get(ch, timedelta())
            num = ""
    return sign * total


def local(dt):
    # aware → the machine's zone; floating and dates stay as they are
    return dt.astimezone(tz.tzlocal()).replace(tzinfo=None) if dt.tzinfo else dt


def occurrences(events, zones, now):
    lo, hi = now - timedelta(days=PAST_DAYS), now + timedelta(days=AHEAD_DAYS)
    moved = {}
    for ev in events:
        if "RECURRENCE-ID" in ev and "UID" in ev:
            p, v = ev["RECURRENCE-ID"][0]
            moved.setdefault(ev["UID"][0][1], []).append(when(p, v, zones))

    out = []
    for ev in events:
        try:
            if "DTSTART" not in ev:
                continue
            uid = ev.get("UID", [({}, "")])[0][1]
            start = when(*ev["DTSTART"][0], zones)
            all_day = not isinstance(start, datetime)
            if "DTEND" in ev:
                span = as_dt(when(*ev["DTEND"][0], zones)) - as_dt(start)
            elif "DURATION" in ev:
                span = duration(ev["DURATION"][0][1])
            else:
                span = timedelta(days=1) if all_day else timedelta()

            if ev.get("STATUS", [({}, "")])[0][1].upper() == "CANCELLED":
                continue

            first = as_dt(start)
            aware = first.tzinfo is not None
            bounds = (lo.astimezone(timezone.utc), hi.astimezone(timezone.utc)) if aware else (lo.replace(tzinfo=None), hi.replace(tzinfo=None))
            if "RRULE" in ev and "RECURRENCE-ID" not in ev:
                rs = rrule.rruleset()
                for _, rule in ev["RRULE"]:
                    rs.rrule(rrule.rrulestr(rule, dtstart=first, ignoretz=not aware))
                for key, add in (("RDATE", rs.rdate), ("EXDATE", rs.exdate)):
                    for p, v in ev.get(key, []):
                        for one in v.split(","):
                            d = as_dt(when(p, one, zones))
                            add(d if aware == (d.tzinfo is not None) else (d.replace(tzinfo=first.tzinfo) if aware else local(d)))
                for d in moved.get(uid, []):
                    d = as_dt(d)
                    rs.exdate(d if aware == (d.tzinfo is not None) else (d.replace(tzinfo=first.tzinfo) if aware else local(d)))
                starts = rs.between(bounds[0] - span, bounds[1], inc=True)
            else:
                starts = [first] if bounds[0] - span <= first <= bounds[1] else []

            title = unescape(ev.get("SUMMARY", [({}, "")])[0][1]).strip()
            for s in starts:
                out.extend(entries(uid, title, local(s), all_day, span))
        except Exception:
            continue  # one broken event should not cost the rest of the feed
    return out


def entries(uid, title, s, all_day, span):
    days = 1
    if all_day:
        # DTEND of an all-day event is the day after its last
        days = max(1, min(MAX_SPAN_DAYS, span.days))
    for i in range(days):
        d = s + timedelta(days=i)
        yield {
            "id": "%s@%s" % (uid, d.strftime("%Y%m%dT%H%M")),
            "name": title,
            "year": d.year,
            "month": d.month - 1,
            "day": d.day,
            "hour": 0 if all_day else d.hour,
            "minute": 0 if all_day else d.minute,
            "allDay": all_day,
            "repeat": "",
        }


def fetch(url):
    if url.startswith("webcal://"):
        url = "https://" + url[len("webcal://"):]
    if not url.startswith(("https://", "http://")):
        raise ValueError("not a web link")
    req = urllib.request.Request(url, headers={"User-Agent": "Lucid calendar"})
    with urllib.request.urlopen(req, timeout=25) as r:
        body = r.read(20 * 1024 * 1024)
    text = body.decode("utf-8", "replace")
    if "BEGIN:VCALENDAR" not in text[:4096].upper():
        raise ValueError("not a calendar")
    return text


def refresh(feeds, old, now, fetcher=fetch):
    events, status = [], {}
    for f in feeds:
        fid, name = str(f.get("id", "")), str(f.get("name", ""))
        try:
            evs, zones = parse(fetcher(str(f.get("url", ""))))
            got = occurrences(evs, zones, now)[:MAX_PER_FEED]
            status[fid] = {"ok": True, "at": int(time.time() * 1000), "count": len(got)}
        except Exception as e:
            e = getattr(e, "reason", None) or e  # urlopen wraps the real cause
            got = [e2 for e2 in old.get("events", []) if e2.get("feed") == fid]
            prev = old.get("status", {}).get(fid, {})
            status[fid] = {"ok": False, "at": prev.get("at", 0), "count": len(got), "error": str(e)[:160]}
        for e in got:
            e["feed"], e["cal"] = fid, name
            if not e["id"].startswith(fid + ":"):  # kept ones already carry it
                e["id"] = fid + ":" + e["id"]
        events.extend(got)
    return {"events": events, "status": status}


def main():
    if sys.argv[1:] == ["--test"]:
        return selftest()
    feeds = json.loads(sys.argv[1] or "[]")
    path = sys.argv[2]
    try:
        with open(path) as fh:
            old = json.load(fh)
    except Exception:
        old = {}
    data = refresh(feeds, old, datetime.now().astimezone())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(data, fh)
    os.replace(tmp, path)


def selftest():
    ics = "\r\n".join([
        "BEGIN:VCALENDAR",
        "BEGIN:VTIMEZONE", "TZID:Romance Standard Time",
        "BEGIN:STANDARD", "DTSTART:16010101T030000", "TZOFFSETFROM:+0200", "TZOFFSETTO:+0100",
        "RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10", "END:STANDARD",
        "BEGIN:DAYLIGHT", "DTSTART:16010101T020000", "TZOFFSETFROM:+0100", "TZOFFSETTO:+0200",
        "RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3", "END:DAYLIGHT", "END:VTIMEZONE",
        "BEGIN:VEVENT", "UID:a", "DTSTART:20261202T150000Z", "DTEND:20261202T160000Z",
        "SUMMARY:Dentist\\, Dr. X", "END:VEVENT",
        "BEGIN:VEVENT", "UID:b", "DTSTART;VALUE=DATE:20261224", "DTEND;VALUE=DATE:20261227",
        "SUMMARY:Holidays", "END:VEVENT",
        "BEGIN:VEVENT", "UID:c", "DTSTART;TZID=Romance Standard Time:20261130T090000",
        "DTEND;TZID=Romance Standard Time:20261130T093000",
        "RRULE:FREQ=WEEKLY;COUNT=4", "EXDATE;TZID=Romance Standard Time:20261207T090000",
        "SUMMARY:Stand", " up", "END:VEVENT",
        "BEGIN:VEVENT", "UID:c", "RECURRENCE-ID;TZID=Romance Standard Time:20261214T090000",
        "DTSTART;TZID=Romance Standard Time:20261214T110000", "SUMMARY:Standup moved", "END:VEVENT",
        "BEGIN:VEVENT", "UID:d", "DTSTART:20261203T100000Z", "STATUS:CANCELLED", "SUMMARY:Gone", "END:VEVENT",
        "BEGIN:VEVENT", "UID:e", "SUMMARY:no start", "END:VEVENT",
        "END:VCALENDAR", ""])
    os.environ["TZ"] = "UTC"
    time.tzset()
    now = datetime(2026, 11, 25, tzinfo=timezone.utc)
    got = refresh([{"id": "f1", "name": "Work", "url": "x"}], {}, now, lambda u: ics)
    ev = got["events"]
    names = sorted((e["name"], e["year"], e["month"] + 1, e["day"], e["hour"], e["minute"]) for e in ev)
    assert ("Dentist, Dr. X", 2026, 12, 2, 15, 0) in names, names
    assert [n for n in names if n[0] == "Holidays"] == [("Holidays", 2026, 12, d, 0, 0) for d in (24, 25, 26)], names
    stand = [n for n in names if n[0] == "Standup"]
    assert stand == [("Standup", 2026, 11, 30, 8, 0), ("Standup", 2026, 12, 21, 8, 0)], stand
    assert ("Standup moved", 2026, 12, 14, 10, 0) in names, names
    assert not any(n[0] in ("Gone", "no start") for n in names), names
    assert all(e["feed"] == "f1" and e["cal"] == "Work" and e["id"].startswith("f1:") for e in ev)
    assert got["status"]["f1"]["ok"]
    # offline: the last good events stay
    def boom(u):
        raise OSError("offline")
    again = refresh([{"id": "f1", "name": "Work", "url": "x"}], got, now, boom)
    assert len(again["events"]) == len(ev) and not again["status"]["f1"]["ok"], again["status"]
    assert len({e["id"] for e in again["events"]}) == len(ev)
    print("ok", len(ev), "events")


if __name__ == "__main__":
    main()
