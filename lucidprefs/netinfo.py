#!/usr/bin/env python3
"""Reads what NetworkManager knows that Quickshell's Networking module does not.

Two modes, both printing one JSON object:
  (no args)      devices with their addressing, plus every saved profile
  --conn <uuid>  the editable settings of one profile
"""

import json
import subprocess
import sys


def nmcli(args):
    try:
        r = subprocess.run(["nmcli"] + args, capture_output=True, text=True,
                           timeout=8)
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout if r.returncode == 0 else ""


def unescape(s):
    out, esc = [], False
    for ch in s:
        if esc:
            out.append(ch)
            esc = False
        elif ch == "\\":
            esc = True
        else:
            out.append(ch)
    return "".join(out)


def split_row(line):
    """nmcli -t rows are colon separated with backslash-escaped colons."""
    fields, cur, esc = [], [], False
    for ch in line:
        if esc:
            cur.append(ch)
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            fields.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    fields.append("".join(cur))
    return fields


def link_speed(dev):
    for path in ("/sys/class/net/%s/speed" % dev,):
        try:
            with open(path) as f:
                v = int(f.read().strip())
                return v if v > 0 else 0
        except (OSError, ValueError):
            pass
    return 0


def wifi_rate():
    for line in nmcli(["-t", "-f", "IN-USE,RATE", "device", "wifi", "list",
                       "--rescan", "no"]).splitlines():
        row = split_row(line)
        if row and row[0].strip() == "*":
            return row[1] if len(row) > 1 else ""
    return ""


def devices():
    fields = ("GENERAL.DEVICE,GENERAL.TYPE,GENERAL.HWADDR,GENERAL.MTU,"
              "GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,"
              "IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS")
    out, cur = [], None
    for line in nmcli(["-t", "-f", fields, "device", "show"]).splitlines():
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        value = unescape(value).strip()
        base = key.split("[")[0]
        if base == "GENERAL.DEVICE":
            cur = {"name": value, "type": "", "mac": "", "mtu": 0,
                   "state": "", "stateCode": 0, "connection": "",
                   "ip4": [], "gw4": "", "dns4": [],
                   "ip6": [], "gw6": "", "dns6": [], "speed": 0, "rate": ""}
            out.append(cur)
        elif cur is None:
            continue
        elif base == "GENERAL.TYPE":
            cur["type"] = value
        elif base == "GENERAL.HWADDR":
            cur["mac"] = value
        elif base == "GENERAL.MTU":
            cur["mtu"] = int(value) if value.isdigit() else 0
        elif base == "GENERAL.STATE":
            cur["stateCode"] = int(value.split()[0]) if value[:1].isdigit() else 0
            lo, hi = value.find("("), value.rfind(")")
            cur["state"] = value[lo + 1:hi] if 0 <= lo < hi else value
        elif base == "GENERAL.CONNECTION":
            cur["connection"] = value
        elif base == "IP4.ADDRESS":
            cur["ip4"].append(value)
        elif base == "IP4.GATEWAY":
            cur["gw4"] = value
        elif base == "IP4.DNS":
            cur["dns4"].append(value)
        elif base == "IP6.ADDRESS":
            cur["ip6"].append(value)
        elif base == "IP6.GATEWAY":
            cur["gw6"] = value
        elif base == "IP6.DNS":
            cur["dns6"].append(value)

    # anything without an address is noise on a settings page
    keep = [d for d in out if d["type"] not in ("loopback", "wifi-p2p")]
    rate = wifi_rate()
    for d in keep:
        d["speed"] = link_speed(d["name"])
        if d["type"] == "wifi":
            d["rate"] = rate
    return keep


def connections():
    out = []
    for line in nmcli(["-t", "-f", "NAME,UUID,TYPE,DEVICE,ACTIVE,AUTOCONNECT",
                       "connection", "show"]).splitlines():
        row = split_row(line)
        if len(row) < 6:
            continue
        kind = row[2]
        if kind == "loopback":
            continue
        out.append({
            "name": row[0],
            "uuid": row[1],
            "type": kind,
            "device": row[3],
            "active": row[4] == "yes",
            "autoconnect": row[5] == "yes",
            "vpn": kind in ("vpn", "wireguard"),
        })
    out.sort(key=lambda c: (not c["active"], c["name"].lower()))
    return out


def connection_detail(uuid):
    fields = ("ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,"
              "ipv4.ignore-auto-dns,ipv6.method,connection.metered,"
              "connection.autoconnect,connection.autoconnect-priority,"
              "802-11-wireless-security.key-mgmt")
    out = {"uuid": uuid}
    for line in nmcli(["-t", "-f", fields, "connection", "show",
                       uuid]).splitlines():
        key, _, value = line.partition(":")
        out[key] = unescape(value).strip()
    return out


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--conn":
        print(json.dumps(connection_detail(sys.argv[2])))
        return
    conn = nmcli(["-t", "-f", "CONNECTIVITY", "general", "status"]).strip()
    print(json.dumps({
        "connectivity": conn,
        "devices": devices(),
        "connections": connections(),
    }))


main()
