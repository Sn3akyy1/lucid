pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.lucidicons

// what the tray knows about an app beyond what it sends: a name worth reading,
// one line of status, the icon lucid draws for it, and where it goes in line.
// the bar's module and the module's card both read it
Singleton {
    id: root

    // apps whose job the bar already does: blueman is the system module's bluetooth
    readonly property var builtin: ["blueman"]
    // the ones switched off on the module's card
    readonly property var hidden: String(Prefs.trayHidden).split(",").filter((k) => {
        return k !== "";
    })

    // electron apps all go by chrome_status_icon_<n>, numbered per app, so the id
    // names nothing; the tooltip's title is the app
    function isElectron(item) {
        return !!item && /^chrome_status_icon/.test(item.id || "");
    }

    // what the card stores to hide an app: its id, or for an electron app its
    // name, since every electron app's first icon has the same id
    function keyOf(item) {
        if (!item)
            return "";

        if (root.isElectron(item)) {
            const n = String(item.tooltipTitle || item.title || "").trim().toLowerCase();
            return n !== "" ? "electron:" + n : (item.id || "");
        }
        return item.id || "";
    }

    function isBuiltin(item) {
        if (!item)
            return false;

        const words = ((item.id || "") + " " + (item.title || "")).toLowerCase();
        return root.builtin.some((w) => {
            return words.indexOf(w) !== -1;
        });
    }

    function isHidden(item) {
        if (!item)
            return true;

        // a list written before electron apps had keys of their own holds bare ids
        return root.isBuiltin(item) || root.hidden.indexOf(root.keyOf(item)) !== -1 || (!root.isElectron(item) && root.hidden.indexOf(item.id || "") !== -1);
    }

    function setHidden(item, off) {
        const key = root.keyOf(item);
        if (key === "")
            return ;

        const list = root.hidden.filter((k) => {
            return k !== key && k !== (item.id || "");
        });
        if (off)
            list.push(key);

        Prefs.trayHidden = list.join(",");
    }

    // the desktop entry's name where there is one: "Spotify", not "spotify"
    function nameOf(item) {
        if (!item)
            return "";

        const electron = root.isElectron(item);
        const raw = String((electron ? (item.tooltipTitle || item.title) : (item.title || item.tooltipTitle)) || item.id || "").trim();
        const tries = electron ? [raw] : [item.id || "", item.title || "", raw];
        for (const t of tries) {
            if (!t)
                continue;

            const e = DesktopEntries.heuristicLookup(t);
            if (e && e.name)
                return e.name;

        }
        if (raw === "")
            return "Unknown";

        return raw === raw.toLowerCase() ? raw.charAt(0).toUpperCase() + raw.slice(1) : raw;
    }

    function plain(html) {
        return String(html || "").replace(/<br\s*\/?>/gi, " ").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'").replace(/\s+/g, " ").trim();
    }

    // one line under the name: what the app says about itself, if anything
    function detailOf(item) {
        if (!item)
            return "";

        const desc = root.plain(item.tooltipDescription);
        if (desc !== "")
            return desc;

        const tip = root.plain(item.tooltipTitle);
        if (tip !== "" && !root.isElectron(item) && tip.toLowerCase() !== root.nameOf(item).toLowerCase())
            return tip;

        return "";
    }

    function wantsYou(item) {
        return !!item && item.status === Status.NeedsAttention;
    }

    // asking for attention first, then the ones at work, then the idle ones
    function rankOf(item) {
        if (!item)
            return 3;

        return item.status === Status.NeedsAttention ? 0 : (item.status === Status.Passive ? 2 : 1);
    }

    // the apps the tray shows, in the order it shows them
    function ordered(items) {
        const list = (items || []).filter((i) => {
            return !root.isHidden(i);
        });
        const names = new Map();
        for (const i of list)
            names.set(i, root.nameOf(i).toLowerCase());
        return list.sort((a, b) => {
            const r = root.rankOf(a) - root.rankOf(b);
            return r !== 0 ? r : names.get(a).localeCompare(names.get(b));
        });
    }

    // an icon sent as a name plus a folder of the app's own comes as
    // name?path=dir; the file is the name in that folder
    function iconSource(raw) {
        if (!raw)
            return "";

        const q = raw.indexOf("?path=");
        if (q === -1)
            return raw;

        const name = raw.substring(0, q);
        return "file://" + raw.substring(q + 6) + "/" + name.substring(name.lastIndexOf("/") + 1);
    }

    // lucid's icon for the app, unless legacy icons are on or lucid draws none.
    // a hardware or service icon shows a state (signal, charge), so it keeps its own
    function slotOf(item) {
        if (Prefs.envLegacyIcons || !item || item.category === Category.Hardware || item.category === Category.SystemServices)
            return "";

        const id = root.isElectron(item) ? "" : (item.id || "");
        const name = item.title || item.tooltipTitle || "";
        const raw = item.icon || "";
        const icon = raw.indexOf("image://icon/") === 0 ? raw.slice(13).split("?")[0] : "";
        return LucidIcons.slotFor(id || name, icon, name);
    }

    // a menu label without its access keys: "_Off" reads "Off", "__" is one "_"
    function label(text) {
        return String(text || "").replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_");
    }

}
