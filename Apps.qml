import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// every application with a desktop entry, read the way the launcher lists it.
// the dock matches running windows against all of them; the launcher leaves out
// the ones hidden in Settings > Launcher and puts the favourites first
Singleton {
    id: root

    // { name, iconName, search, initials, command, wmClass, base, actions, desc },
    // one per name; base is the desktop entry's id, which is what gets remembered
    property var list: []
    readonly property var hiddenIds: Prefs.splitList(Prefs.launcherHiddenApps)
    readonly property var favIds: Prefs.splitList(Prefs.launcherFavApps)
    readonly property var hiddenSet: root.setOf(root.hiddenIds)
    readonly property var favSet: root.setOf(root.favIds)
    // what the launcher lists under Favourites, by name
    readonly property var favApps: root.list.filter((a) => {
        return root.isFav(a);
    }).sort((a, b) => {
        return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
    })

    signal scanned()

    function setOf(ids) {
        var set = {};
        for (var i = 0; i < ids.length; i++) set[ids[i]] = true;
        return set;
    }

    function isHidden(app) {
        return !!app && root.hiddenSet[app.base] === true;
    }

    // a hidden app is never a favourite, whatever the list still says
    function isFav(app) {
        return !!app && root.favSet[app.base] === true && !root.isHidden(app);
    }

    function byName(name) {
        var key = String(name).toLowerCase();
        for (var i = 0; i < root.list.length; i++) {
            if (root.list[i].name.toLowerCase() === key)
                return root.list[i];

        }
        return null;
    }

    function without(ids, id) {
        return ids.filter((x) => {
            return x !== id;
        });
    }

    // hiding an app takes it out of the favourites, and starring one shows it again
    function setHidden(id, on) {
        if (!id)
            return ;

        Prefs.launcherHiddenApps = (on ? root.without(root.hiddenIds, id).concat([id]) : root.without(root.hiddenIds, id)).join(",");
        if (on && root.favSet[id] === true)
            Prefs.launcherFavApps = root.without(root.favIds, id).join(",");

    }

    function setFav(id, on) {
        if (!id)
            return ;

        Prefs.launcherFavApps = (on ? root.without(root.favIds, id).concat([id]) : root.without(root.favIds, id)).join(",");
        if (on && root.hiddenSet[id] === true)
            Prefs.launcherHiddenApps = root.without(root.hiddenIds, id).join(",");

    }

    function toggleFav(app) {
        if (app)
            root.setFav(app.base, !root.isFav(app));

    }

    function rescan() {
        scanner.running = true;
    }

    Process {
        id: scanner

        running: true

        command: ["sh", "-c", "for d in /usr/share/applications \"$HOME/.local/share/applications\" " + "/var/lib/flatpak/exports/share/applications \"$HOME/.local/share/flatpak/exports/share/applications\" " + "/var/lib/snapd/desktop/applications; do " + "[ -d \"$d\" ] && find \"$d\" -maxdepth 1 -name '*.desktop' -print0; " + "done | xargs -0 -r awk '" + "function clean(v) { gsub(/\\|/, \" \", v); gsub(/\\r/, \"\", v); return v } " + "function flush(   n, e, ids, na, k, id, ae, al) { " + "n = clean(name); e = clean(ex); " + "if (nodisp || hidden) return; " + "if (type != \"\" && type != \"Application\") return; " + "if (n == \"\" || e == \"\") return; " + "gsub(/ ?%[a-zA-Z]/, \"\", e); sub(/[ \\t]+$/, \"\", e); " + "if (term == \"true\") e = \"kitty -e \" e; " + "al = \"\"; na = split(actlist, ids, \";\"); " + "for (k = 1; k <= na; k++) { id = ids[k]; if (id == \"\" || !(id in AN) || !(id in AE)) continue; " + "ae = clean(AE[id]); gsub(/ ?%[a-zA-Z]/, \"\", ae); sub(/[ \\t]+$/, \"\", ae); if (ae == \"\") continue; " + "if (term == \"true\") ae = \"kitty -e \" ae; " + "al = al (al == \"\" ? \"\" : \"\\036\") clean(AN[id]) \"\\037\" ae } " + "print n \"|\" clean(icon) \"|\" clean(kw \" \" gen \" \" com \" \" cats) \"|\" e \"|\" clean(wm) \"|\" base \"|\" al \"|\" clean(com != \"\" ? com : gen) } " + "BEGINFILE { name=\"\"; icon=\"\"; ex=\"\"; kw=\"\"; gen=\"\"; com=\"\"; cats=\"\"; wm=\"\"; type=\"\"; term=\"\"; nodisp=0; hidden=0; insec=0; " + "actlist=\"\"; act=\"\"; delete AN; delete AE; " + "base=FILENAME; sub(/.*\\//, \"\", base); sub(/\\.desktop$/, \"\", base) } " + "/^[ \\t]*\\[/ { insec = ($0 ~ /^\\[Desktop Entry\\]/) ? 1 : 0; act = \"\"; " + "if ($0 ~ /^\\[Desktop Action /) { act = $0; sub(/^\\[Desktop Action /, \"\", act); sub(/\\].*$/, \"\", act) } next } " + "act != \"\" && /^Name=/ { if (!(act in AN)) AN[act] = substr($0, 6); next } " + "act != \"\" && /^Exec=/ { if (!(act in AE)) AE[act] = substr($0, 6); next } " + "!insec { next } " + "/^Actions=/ { if (actlist == \"\") actlist = substr($0, 9) } " + "/^Name=/ { if (name == \"\") name = substr($0, 6) } " + "/^Icon=/ { if (icon == \"\") icon = substr($0, 6) } " + "/^Exec=/ { if (ex == \"\") ex = substr($0, 6) } " + "/^Keywords=/ { if (kw == \"\") { kw = substr($0, 10); gsub(/;/, \" \", kw) } } " + "/^GenericName=/ { if (gen == \"\") gen = substr($0, 13) } " + "/^Comment=/ { if (com == \"\") com = substr($0, 9) } " + "/^Categories=/ { if (cats == \"\") { cats = substr($0, 12); gsub(/;/, \" \", cats) } } " + "/^StartupWMClass=/ { if (wm == \"\") wm = substr($0, 16) } " + "/^Type=/ { if (type == \"\") type = substr($0, 6) } " + "/^Terminal=/ { if (term == \"\") term = substr($0, 10) } " + "/^NoDisplay=true/ { nodisp = 1 } " + "/^Hidden=true/ { hidden = 1 } " + "ENDFILE { flush() }'"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var seen = {};
                var arr = [];
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === "")
                        continue;

                    var p = lines[i].split("|");
                    if (p.length < 6)
                        continue;

                    var name = p[0];
                    var key = name.toLowerCase();
                    if (seen[key])
                        continue;

                    seen[key] = true;
                    // first letter of each word, for acronym matching
                    var initials = name.split(/[\s\-_]+/).map(function(w) {
                        return w.charAt(0);
                    }).join("").toLowerCase();
                    // [Desktop Action] entries: name and command split by US, entries by RS
                    var actions = [];
                    var packed = p.length > 6 ? p[6].split("\u001e") : [];
                    for (var a = 0; a < packed.length; a++) {
                        var pair = packed[a].split("\u001f");
                        if (pair.length === 2 && pair[0] !== "" && pair[1] !== "")
                            actions.push({
                                "name": pair[0],
                                "command": pair[1]
                            });

                    }
                    arr.push({
                        "name": name,
                        "iconName": p[1],
                        "search": (name + " " + p[2] + " " + p[5]).toLowerCase(),
                        "initials": initials,
                        "command": p[3],
                        "wmClass": p[4],
                        "base": p[5],
                        "actions": actions,
                        // Comment, or GenericName without one; never just the name again
                        "desc": p.length > 7 && p[7].toLowerCase() !== key ? p[7] : ""
                    });
                }
                root.list = arr;
                root.scanned();
            }
        }

    }

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: scanner.running = true
    }

}
