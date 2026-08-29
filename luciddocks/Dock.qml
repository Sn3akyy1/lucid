import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: dockWindow

    // wired from shell.qml, so the power menu can reach the real lock screen
    property var lockScreen: null

    property bool morphing: false
    readonly property bool dockBusy: dockWindow.menuOpen || dockWindow.dragging || (dockWindow.morphing && !dockWindow.launcherFromHidden)
    property bool slidingAway: false
    readonly property bool heldByPointer: revealArea.containsMouse || (shellHover.hovered && !dockWindow.slidingAway)
    readonly property bool dockRevealed: !Prefs.dockAutoHide || dockWindow.dockBusy || dockWindow.heldByPointer
    property bool launcherFromHidden: false
    readonly property bool renderAsNotch: Prefs.dockNotch || dockWindow.launcherFromHidden
    readonly property int placementMargin: dockWindow.launcherFromHidden ? 0 : Prefs.effectiveDockBottomMargin
    readonly property real hiddenOffset: dockWindow.dockRevealed ? 0 : -(shell.implicitHeight + Prefs.dockBottomMargin - 1)

    onDockRevealedChanged: {
        if (dockWindow.dockRevealed) {
            dockWindow.slidingAway = false;
            slideAwayTimer.stop();
        } else {
            dockWindow.slidingAway = true;
            slideAwayTimer.restart();
        }
    }

    Timer {
        id: slideAwayTimer

        interval: Theme.durLong
        onTriggered: dockWindow.slidingAway = false
    }

    property int shellResizeMs: Theme.ms(60)
    readonly property var morphCurve: [0.4, 0, 0.2, 1, 1, 1]

    function pulseMorph() {
        dockWindow.shellResizeMs = Theme.ms(480);
        dockWindow.morphing = true;
        morphTimer.restart();
    }

    property bool snapPlacement: false
    property int contentFadeDelay: 0
    property bool menuOpen: false

    onMenuOpenChanged: {
        dockWindow.pulseMorph();
        dockWindow.contentFadeDelay = dockWindow.menuOpen ? 190 : 0;
        if (dockWindow.menuOpen) {
            dockWindow.launcherFromHidden = Prefs.dockAutoHide && !dockWindow.heldByPointer;
            dockWindow.snapPlacement = true;
            snapClear.restart();
        } else if (dockWindow.launcherFromHidden) {
            hideAfterClose.restart();
        } else {
            dockWindow.launcherFromHidden = false;
        }
    }

    Timer {
        id: hideAfterClose

        interval: Theme.durLong
        onTriggered: dockWindow.launcherFromHidden = false
    }

    Timer {
        id: snapClear

        interval: 16
        onTriggered: dockWindow.snapPlacement = false
    }

    onMenuWidthChanged: if (dockWindow.menuOpen)
        dockWindow.pulseMorph()
    onMenuHeightChanged: if (dockWindow.menuOpen)
        dockWindow.pulseMorph()

    Timer {
        id: morphTimer

        interval: Theme.ms(520)
        onTriggered: {
            dockWindow.morphing = false;
            dockWindow.shellResizeMs = Theme.ms(60);
        }
    }

    property string fallbackWallpaper: Qt.resolvedUrl("./fallback.jpg").toString().replace("file://", "")
    property var scannedApps: []
    property string currentTheme: "matugen"
    property string pendingWallpaper: ""
    property string appliedWallpaper: ""
    property bool wallpaperArmed: false
    readonly property bool dragging: pinnedRow.dragging || runningRow.dragging

    readonly property var clientsData: {
        var out = [];
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var o = tl[i].lastIpcObject;
            if (o && o.class)
                out.push(o);

        }
        return out;
    }
    readonly property int activeWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    readonly property string focusedAddress: {
        var t = Hyprland.activeToplevel;
        return t && t.lastIpcObject && t.lastIpcObject.address ? t.lastIpcObject.address : "";
    }

    Timer {
        interval: 4000
        running: dockWindow.visible && (dockWindow.menuOpen || dockWindow.dockRevealed)
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }

    onClientsDataChanged: dockWindow.syncRunningApps()

    readonly property string rawQuery: launcherFace.searchText

    function modeFor(raw) {
        var q = raw.toLowerCase();
        if (q.indexOf(">wallpaper") === 0)
            return "wallpaper";

        if (q.indexOf(">theme") === 0)
            return "theme";

        if (q.indexOf(">power") === 0)
            return "power";

        if (q.indexOf(">") === 0)
            return "commands";

        return "apps";
    }

    function prefixFor(mode) {
        if (mode === "wallpaper")
            return ">wallpaper";

        if (mode === "theme")
            return ">theme";

        if (mode === "power")
            return ">power";

        if (mode === "commands")
            return ">";

        return "";
    }

    function queryFor(raw) {
        return raw.substring(dockWindow.prefixFor(dockWindow.modeFor(raw)).length).trim();
    }

    readonly property string mode: dockWindow.modeFor(dockWindow.rawQuery)
    readonly property string filterQuery: dockWindow.queryFor(dockWindow.rawQuery)

    onRawQueryChanged: dockWindow.rebuildResults()
    onModeChanged: {
        if (dockWindow.mode === "wallpaper") {
            wallpaperScanner.scan();
            dockWindow.wallpaperArmed = false;
            wallpaperArmTimer.restart();
        } else {
            dockWindow.wallpaperArmed = false;
        }
        if (dockWindow.mode === "theme")
            dockWindow.scanThemeWallpapers();

    }

    readonly property var allCommands: [{
        "id": "wallpaper",
        "name": "Choose Wallpaper",
        "desc": "Browse and set a new desktop wallpaper",
        "glyph": DockIcons.wallpaper
    }, {
        "id": "shuffle",
        "name": "Shuffle Wallpaper",
        "desc": "Pick a random wallpaper from this theme's folder",
        "glyph": DockIcons.shuffle
    }, {
        "id": "theme",
        "name": "Switch Theme",
        "desc": "Change the colour scheme",
        "glyph": DockIcons.palette
    }, {
        "id": "power",
        "name": "Power",
        "desc": "Lock, suspend, restart or shut down",
        "glyph": DockIcons.power
    }, {
        "id": "settings",
        "name": "Settings",
        "desc": "Open Lucid's settings",
        "glyph": DockIcons.settings
    }]
    // shared with the settings app, see Prefs.themeCatalogue
    readonly property var allThemes: Prefs.themeCatalogue
    property var themeHasWallpaper: ({})

    readonly property int iconSlot: Prefs.dockIconSize
    readonly property int iconGap: Prefs.dockSpacing
    readonly property int slotPitch: dockWindow.iconSlot + dockWindow.iconGap
    readonly property real maxDockWidth: dockWindow.screen ? dockWindow.screen.width : 1920
    property real dragHeadroom: 220

    readonly property int menuMaxHeight: 560
    // how much of the panel is chrome, not results
    readonly property int panelPadding: 36
    readonly property int wallCardCount: 5
    readonly property int wallCardGap: 10
    readonly property int wallHeroW: Math.max(280, Math.min(420, Math.round(dockWindow.maxDockWidth * 0.177)))
    readonly property int wallHeroH: Math.round(dockWindow.wallHeroW * 0.62)
    readonly property int wallMidW: Math.round(dockWindow.wallHeroW * 0.70)
    readonly property int wallMidH: Math.round(dockWindow.wallMidW * 0.62)
    readonly property int wallSmallW: Math.round(dockWindow.wallHeroW * 0.44)
    readonly property int wallSmallH: Math.round(dockWindow.wallSmallW * 0.62)
    readonly property int wallStripWidth: dockWindow.wallHeroW + 2 * (dockWindow.wallMidW + dockWindow.wallCardGap) + 2 * (dockWindow.wallSmallW + dockWindow.wallCardGap)
    readonly property int wallHoverRoom: 12

    readonly property real menuWidth: {
        if (dockWindow.mode === "wallpaper")
            return dockWindow.wallStripWidth + dockWindow.panelPadding + dockWindow.wallHoverRoom;

        if (dockWindow.mode === "power")
            return 660;

        return 420;
    }
    property real resultsHeight: 0
    readonly property real menuContentMax: dockWindow.menuMaxHeight - dockWindow.panelPadding - launcherFace.chromeHeight
    readonly property real menuHeight: {
        var content;
        if (dockWindow.mode === "wallpaper")
            content = dockWindow.wallHeroH + 70;
        else if (dockWindow.mode === "power")
            content = 140;
        else
            content = Math.max(70, Math.min(dockWindow.resultsHeight, dockWindow.menuContentMax));
        return Math.round(dockWindow.panelPadding + launcherFace.chromeHeight + content);
    }

    readonly property var classIndex: {
        var idx = {};
        for (var i = 0; i < dockWindow.scannedApps.length; i++) {
            var a = dockWindow.scannedApps[i];
            var keys = [];
            if (a.wmClass !== "")
                keys.push(a.wmClass.toLowerCase());

            keys.push(a.base.toLowerCase());
            keys.push(a.name.toLowerCase());
            for (var k = 0; k < keys.length; k++) {
                if (keys[k] !== "" && idx[keys[k]] === undefined)
                    idx[keys[k]] = a;

            }
        }
        return idx;
    }

    readonly property var desktopIndex: {
        var idx = {};
        for (var i = 0; i < dockWindow.scannedApps.length; i++) {
            var a = dockWindow.scannedApps[i];
            if (a.base !== "")
                idx[a.base.toLowerCase()] = a;

        }
        return idx;
    }

    readonly property var pinnedCommands: {
        var cmds = {};
        for (var i = 0; i < appListModel.count; i++) cmds[appListModel.get(i).command] = i;
        return cmds;
    }

    function entryForClass(cls) {
        var key = cls.toLowerCase();
        var hit = dockWindow.classIndex[key];
        if (hit)
            return hit;

        var dot = key.lastIndexOf(".");
        if (dot > 0 && dot < key.length - 1)
            return dockWindow.classIndex[key.substring(dot + 1)] || null;

        return null;
    }

    readonly property var pinnedAppIds: {
        var ids = {};
        for (var i = 0; i < appListModel.count; i++) {
            var appId = appListModel.get(i).appId;
            if (appId !== "")
                ids[appId.toLowerCase()] = true;

        }
        return ids;
    }

    function arcPath(cx, cy, r, a0, a1) {
        var t0 = a0 * Math.PI / 180, t1 = a1 * Math.PI / 180;
        var large = Math.abs(a1 - a0) > 180 ? 1 : 0;
        var sweep = a1 > a0 ? 0 : 1;
        return "M" + (cx + r * Math.cos(t0)).toFixed(2) + "," + (cy - r * Math.sin(t0)).toFixed(2) + " A" + r + "," + r + " 0 " + large + " " + sweep + " " + (cx + r * Math.cos(t1)).toFixed(2) + "," + (cy - r * Math.sin(t1)).toFixed(2);
    }

    function sparklePath(x, y, s) {
        var k = s * 0.3, j = s * 0.13;
        return "M" + x + "," + (y - s) + " C" + (x + j) + "," + (y - k) + " " + (x + k) + "," + (y - j) + " " + (x + s) + "," + y + " C" + (x + k) + "," + (y + j) + " " + (x + j) + "," + (y + k) + " " + x + "," + (y + s) + " C" + (x - j) + "," + (y + k) + " " + (x - k) + "," + (y + j) + " " + (x - s) + "," + y + " C" + (x - k) + "," + (y - j) + " " + (x - j) + "," + (y - k) + " " + x + "," + (y - s) + " Z";
    }

    function circlePath(cx, cy, r) {
        return "M" + (cx - r) + "," + cy + " A" + r + "," + r + " 0 1 0 " + (cx + r) + "," + cy + " A" + r + "," + r + " 0 1 0 " + (cx - r) + "," + cy + " Z";
    }

    readonly property string lucidaRing: dockWindow.arcPath(12, 12, 7.4, 58, 340)
    readonly property string lucidaStar: dockWindow.sparklePath(12, 12, 4.6)
    readonly property string lucidaCompanion: dockWindow.circlePath(21, 9.4, 1)

    function makeRow(kind, key, title, subtitle, opts) {
        opts = opts || {};
        return {
            "kind": kind,
            "key": key,
            "title": title,
            "subtitle": subtitle,
            "iconName": opts.iconName || "",
            "glyph": opts.glyph || "",
            "swatchBg": opts.swatchBg || "",
            "swatchAccent": opts.swatchAccent || "",
            "trailing": opts.trailing || "",
            "disabled": opts.disabled === true,
            "selectable": opts.selectable !== false,
            "payload": opts.payload || ""
        };
    }

    function headerRow(title) {
        return dockWindow.makeRow("header", "hdr-" + title, title, "", {
            "selectable": false
        });
    }

    function matchScore(app, q) {
        var n = app.name.toLowerCase();
        if (n.indexOf(q) === 0)
            return 100;

        // a word-boundary hit beats a hit buried mid-word
        if (n.indexOf(" " + q) !== -1)
            return 90;

        if (n.indexOf(q) !== -1)
            return 80;

        if (app.search.indexOf(q) !== -1)
            return 50;

        // initials: "vsc" finds "Visual Studio Code"
        if (app.initials.indexOf(q) === 0)
            return 70;

        var i = 0;
        for (var c = 0; c < n.length && i < q.length; c++) {
            if (n.charAt(c) === q.charAt(i))
                i++;

        }
        return i === q.length ? 20 : -1;
    }

    function appRows(q) {
        var counts = usageAdapter.counts || {};
        var scored = [];
        for (var i = 0; i < dockWindow.scannedApps.length; i++) {
            var app = dockWindow.scannedApps[i];
            var score = q !== "" ? dockWindow.matchScore(app, q) : 0;
            if (q !== "" && score < 0)
                continue;

            scored.push({
                "app": app,
                "score": score,
                "uses": counts[app.name.toLowerCase()] || 0
            });
        }
        scored.sort(function(a, b) {
            if (a.score !== b.score)
                return b.score - a.score;

            if (a.uses !== b.uses)
                return b.uses - a.uses;

            return a.app.name.toLowerCase() < b.app.name.toLowerCase() ? -1 : 1;
        });
        return scored;
    }

    function rowForApp(app) {
        return dockWindow.makeRow("app", "app-" + app.name, app.name, "", {
            "iconName": app.iconName,
            "payload": app.command
        });
    }

    function rebuildResults() {
        var raw = launcherFace.searchText;
        var mode = dockWindow.modeFor(raw);
        var rows = [];
        var q = dockWindow.queryFor(raw).toLowerCase();
        if (mode === "apps") {
            var calc = DockCalc.evaluate(dockWindow.queryFor(raw));
            if (calc !== "")
                rows.push(dockWindow.makeRow("calc", "calc", "= " + calc, "Press Return to copy", {
                    "glyph": DockIcons.equals,
                    "payload": calc
                }));

            var scored = dockWindow.appRows(q);
            if (q === "") {
                var frequent = scored.filter(function(s) {
                    return s.uses > 0;
                }).slice(0, 5);
                if (frequent.length > 0) {
                    rows.push(dockWindow.headerRow("Frequent"));
                    for (var f = 0; f < frequent.length; f++) rows.push(dockWindow.rowForApp(frequent[f].app));
                    rows.push(dockWindow.headerRow("All applications"));
                }
                var rest = scored.slice().sort(function(a, b) {
                    return a.app.name.toLowerCase() < b.app.name.toLowerCase() ? -1 : 1;
                });
                for (var r = 0; r < rest.length; r++) rows.push(dockWindow.rowForApp(rest[r].app));
            } else {
                for (var s2 = 0; s2 < scored.length; s2++) rows.push(dockWindow.rowForApp(scored[s2].app));
            }
        } else if (mode === "commands") {
            for (var c = 0; c < dockWindow.allCommands.length; c++) {
                var cmd = dockWindow.allCommands[c];
                if (q === "" || cmd.name.toLowerCase().indexOf(q) !== -1)
                    rows.push(dockWindow.makeRow("command", "cmd-" + cmd.id, cmd.name, cmd.desc, {
                        "glyph": cmd.glyph,
                        "payload": cmd.id
                    }));

            }
        } else if (mode === "theme") {
            for (var t = 0; t < dockWindow.allThemes.length; t++) {
                var th = dockWindow.allThemes[t];
                if (q !== "" && th.name.toLowerCase().indexOf(q) === -1)
                    continue;

                var noWall = th.id !== "matugen" && dockWindow.themeHasWallpaper[th.id] === false;
                rows.push(dockWindow.makeRow("theme", "theme-" + th.id, th.name, noWall ? "No wallpapers installed for this theme" : th.desc, {
                    "swatchBg": th.swatchBg,
                    "swatchAccent": th.swatchAccent,
                    "trailing": th.id === dockWindow.currentTheme ? "check" : "",
                    "disabled": noWall,
                    "payload": th.id
                }));
            }
        }
        dockWindow.syncResults(rows);
    }

    function syncResults(rows) {
        var wanted = {};
        for (var j = 0; j < rows.length; j++) wanted[rows[j].key] = true;
        for (var i = resultsModel.count - 1; i >= 0; i--) {
            if (!wanted[resultsModel.get(i).key])
                resultsModel.remove(i, 1);

        }
        for (var k = 0; k < rows.length; k++) {
            var existing = -1;
            for (var m = k; m < resultsModel.count; m++) {
                if (resultsModel.get(m).key === rows[k].key) {
                    existing = m;
                    break;
                }
            }
            if (existing === -1) {
                resultsModel.insert(k, rows[k]);
            } else {
                if (existing !== k)
                    resultsModel.move(existing, k, 1);

                resultsModel.set(k, rows[k]);
            }
        }
        dockWindow.resultsHeight = dockWindow.measure(rows);
        launcherFace.resultsChanged();
    }

    function measure(rows) {
        var h = 8;
        for (var i = 0; i < rows.length; i++) {
            h += rows[i].kind === "header" ? 30 : (rows[i].subtitle !== "" ? 58 : 48);
            h += 2;
        }
        return h;
    }

    function activateResult(index) {
        var row = resultsModel.get(index);
        if (!row || !row.selectable || row.disabled)
            return;

        if (row.kind === "app") {
            Quickshell.execDetached(["sh", "-c", row.payload]);
            dockWindow.recordLaunch(row.title);
            dockWindow.menuOpen = false;
        } else if (row.kind === "calc") {
            Quickshell.execDetached(["wl-copy", "--", row.payload]);
            dockWindow.menuOpen = false;
        } else if (row.kind === "theme") {
            dockWindow.switchTheme(row.payload);
        } else if (row.kind === "command") {
            dockWindow.runCommand(row.payload);
        }
    }

    function runCommand(id) {
        if (id === "wallpaper") {
            launcherFace.searchText = ">wallpaper";
        } else if (id === "theme") {
            launcherFace.searchText = ">theme";
        } else if (id === "power") {
            launcherFace.searchText = ">power";
        } else if (id === "shuffle") {
            wallpaperShuffle.pick();
            dockWindow.menuOpen = false;
        } else if (id === "settings") {
            dockWindow.menuOpen = false;
            Prefs.settingsRequested("");
        }
    }

    function recordLaunch(name) {
        var counts = usageAdapter.counts || {};
        var key = name.toLowerCase();
        counts[key] = (counts[key] || 0) + 1;
        usageAdapter.counts = counts;
        dockWindow.rebuildResults();
    }

    function currentWallpaperPath() {
        try {
            return currentWallFile.text().trim();
        } catch (e) {
            return "";
        }
    }

    function requestWallpaper(path) {
        if (!dockWindow.wallpaperArmed || path === "" || path === dockWindow.appliedWallpaper)
            return;

        dockWindow.pendingWallpaper = path;
        wallpaperDebounce.restart();
    }

    function applyWallpaper(path) {
        if (path === "")
            return;

        dockWindow.appliedWallpaper = path;
        wallpaperState.current = path;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper/set-wallpaper.sh", path]);
    }

    function syncStripToCurrent() {
        for (var i = 0; i < wallpapersModel.count; i++) {
            if (wallpapersModel.get(i).path === wallpaperState.current) {
                launcherFace.setWallpaperIndex(i);
                return;
            }
        }
    }

    function scanThemeWallpapers() {
        var home = Quickshell.env("HOME");
        var script = "";
        for (var i = 0; i < dockWindow.allThemes.length; i++) {
            var id = dockWindow.allThemes[i].id;
            if (id === "matugen")
                continue;

            script += "d=\"" + home + "/Pictures/wallpapers/" + id + "\"; " + "if [ -d \"$d\" ] && [ -n \"$(find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -print -quit)\" ]; " + "then echo \"" + id + ":1\"; else echo \"" + id + ":0\"; fi; ";
        }
        themeWallpaperScan.command = ["sh", "-c", script];
        themeWallpaperScan.running = true;
    }

    function switchTheme(id) {
        var home = Quickshell.env("HOME");
        themeSwitchProbe.pendingId = id;
        themeSwitchProbe.command = ["sh", "-c", "d=\"" + home + "/Pictures/wallpapers/" + id + "\"; " + "[ -d \"$d\" ] && find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort | head -n1; true"];
        themeSwitchProbe.running = true;
        dockWindow.menuOpen = false;
    }

    function runPowerAction(id) {
        if (id === "lock") {
            if (dockWindow.lockScreen)
                dockWindow.lockScreen.locked = true;

            dockWindow.menuOpen = false;
            return;
        }
        var cmds = {
            // uwsm only stops a session it started, so fall back to hyprland
            "logout": ["sh", "-c", "uwsm stop 2>/dev/null || hyprctl dispatch exit"],
            "suspend": ["systemctl", "suspend"],
            "shutdown": ["systemctl", "poweroff"],
            "hibernate": ["systemctl", "hibernate"],
            "reboot": ["systemctl", "reboot"]
        };
        var cmd = cmds[id];
        if (cmd)
            Quickshell.execDetached(cmd);

        dockWindow.menuOpen = false;
    }

    function loadAppsFromDisk() {
        var apps = null;
        try {
            var raw = pinnedFile.text();
            if (raw && raw.trim() !== "") {
                var parsed = JSON.parse(raw);
                apps = parsed.pinnedApps;
            }
        } catch (e) {
            console.warn("pinned.json parse failed, falling back to defaults:", e);
        }
        if (!apps || apps.length === 0)
            apps = pinnedAdapter.pinnedApps;

        appListModel.clear();
        for (var i = 0; i < apps.length; i++) {
            var a = apps[i];
            appListModel.append({
                "appKey": a.appKey,
                "iconName": a.iconName,
                "command": a.command,
                "appId": a.appId,
                "displayName": a.name || a.appId || a.appKey,
                "justAdded": false
            });
        }
    }

    function persistOrder() {
        var arr = [];
        for (var i = 0; i < appListModel.count; i++) {
            var item = appListModel.get(i);
            arr.push({
                "appKey": item.appKey,
                "iconName": item.iconName,
                "command": item.command,
                "appId": item.appId,
                "name": item.displayName
            });
        }
        pinnedAdapter.pinnedApps = arr;
    }

    function removePinnedAt(index) {
        if (index < 0 || index >= appListModel.count)
            return;

        appListModel.remove(index, 1);
        dockWindow.persistOrder();
        dockWindow.syncRunningApps();
    }

    function focusCommand(cls) {
        return "hyprctl eval 'local w=nil for i,win in pairs(hl.get_windows()) do if win.class==\"" + cls + "\" then w=win end end if w then hl.dispatch(hl.dsp.focus({window=w})) end'";
    }

    function pinRunningApp(cls, index) {
        var entry = dockWindow.entryForClass(cls);
        if (entry) {
            dockWindow.addPinned(cls, entry.iconName, entry.command, entry.name, index);
            return;
        }
        pinLookup.pendingClass = cls;
        pinLookup.pendingIndex = index === undefined ? -1 : index;
        pinLookup.command = ["sh", "-c", "dirs=\"$HOME/.local/share/applications /usr/share/applications /var/lib/snapd/desktop/applications /var/lib/flatpak/exports/share/applications\"; " + "f=''; " + "for d in $dirs; do m=$(grep -lis \"StartupWMClass=" + cls + "\" \"$d\"/*.desktop 2>/dev/null | head -n1); [ -n \"$m\" ] && f=\"$m\" && break; done; " + "if [ -z \"$f\" ]; then for d in $dirs; do [ -f \"$d/" + cls + ".desktop\" ] && f=\"$d/" + cls + ".desktop\" && break; done; fi; " + "if [ -f \"$f\" ]; then grep '^Exec=' \"$f\" | head -n1 | cut -d= -f2- | sed 's/ %[a-zA-Z]//g'; fi"];
        pinLookup.running = true;
    }

    function addPinned(cls, iconName, command, name, index) {
        if (command === "")
            return false;

        var dupe = dockWindow.pinnedCommands[command];
        if (dupe !== undefined) {
            dockWindow.bumpPinned(dupe);
            return false;
        }
        var at = (index === undefined || index < 0 || index > appListModel.count) ? appListModel.count : index;
        appListModel.insert(at, {
            "appKey": "pinned-" + cls.toLowerCase() + "-" + Date.now() + "-" + at,
            "iconName": iconName !== "" ? iconName : cls,
            "command": command,
            "appId": cls,
            "displayName": name !== "" ? name : cls,
            "justAdded": true
        });
        dockWindow.persistOrder();
        for (var k = runningAppsModel.count - 1; k >= 0; k--) {
            if (runningAppsModel.get(k).appId === cls) {
                runningAppsModel.remove(k, 1);
                break;
            }
        }
        return true;
    }

    function bumpPinned(index) {
        pinnedRow.bump(index);
    }

    readonly property bool pointerOnDock: shellHover.hovered && !dockWindow.menuOpen

    readonly property int pinDropIndex: {
        if (runningRow.pinDragCenter < 0)
            return -1;

        var lx = pinnedRow.mapFromItem(null, runningRow.pinDragCenter, 0).x;
        return Math.max(0, Math.min(appListModel.count, Math.round(lx / dockWindow.slotPitch)));
    }
    readonly property bool pinArmed: runningRow.pinDragCenter >= 0 && pinnedRow.mapFromItem(null, runningRow.pinDragCenter, 0).x < appListModel.count * dockWindow.slotPitch

    function shQuote(v) {
        return "'" + v.split("'").join("'\\''") + "'";
    }

    function localPaths(urls) {
        var out = [];
        for (var i = 0; i < urls.length; i++) {
            var u = urls[i].toString();
            if (u.indexOf("file://") !== 0)
                continue;

            try {
                out.push(decodeURIComponent(u.substring(7)));
            } catch (e) {
                out.push(u.substring(7));
            }
        }
        return out;
    }

    function pinDroppedPaths(paths, index) {
        var unresolved = [];
        var at = index;
        for (var i = 0; i < paths.length; i++) {
            var path = paths[i];
            if (path.length > 8 && path.substring(path.length - 8) === ".desktop") {
                var base = path.substring(path.lastIndexOf("/") + 1, path.length - 8).toLowerCase();
                var entry = dockWindow.desktopIndex[base];
                if (entry) {
                    if (dockWindow.addPinned(entry.wmClass !== "" ? entry.wmClass : entry.base, entry.iconName, entry.command, entry.name, at) && at >= 0)
                        at += 1;

                    continue;
                }
            }
            unresolved.push(path);
        }
        if (unresolved.length === 0)
            return;

        dropResolver.resolve(unresolved, at);
    }

    function unpinApp(appId) {
        for (var i = appListModel.count - 1; i >= 0; i--) {
            if (appListModel.get(i).appId.toLowerCase() === appId.toLowerCase()) {
                dockWindow.removePinnedAt(i);
                return;
            }
        }
    }

    function syncRunningApps() {
        var seen = {};
        var pinned = dockWindow.pinnedAppIds;
        if (!Prefs.dockShowRunning) {
            runningAppsModel.clear();
            return;
        }
        for (var i = 0; i < dockWindow.clientsData.length; i++) {
            var cls = dockWindow.clientsData[i].class;
            if (!cls || cls === "")
                continue;

            var key = cls.toLowerCase();
            if (pinned[key] || seen[key])
                continue;

            seen[key] = true;
            var existingIdx = -1;
            for (var j = 0; j < runningAppsModel.count; j++) {
                if (runningAppsModel.get(j).appId.toLowerCase() === key) {
                    existingIdx = j;
                    break;
                }
            }
            if (existingIdx !== -1)
                continue;

            var entry = dockWindow.entryForClass(cls);
            runningAppsModel.append({
                "appKey": "running-" + key,
                "iconName": entry ? entry.iconName : cls,
                "command": entry ? entry.command : dockWindow.focusCommand(cls),
                "appId": cls,
                "displayName": entry ? entry.name : cls,
                "justAdded": true
            });
        }
        for (var k = runningAppsModel.count - 1; k >= 0; k--) {
            if (!seen[runningAppsModel.get(k).appId.toLowerCase()])
                runningAppsModel.remove(k, 1);

        }
    }

    function openStackPopup(item, appId, iconName, launchCommand) {
        if (stackPopup.popupVisible && stackPopup.appId.toLowerCase() === appId.toLowerCase()) {
            stackPopup.popupVisible = false;
            return;
        }
        var localPos = item.mapToItem(null, 0, 0);
        var groups = {};
        var order = [];
        for (var i = 0; i < dockWindow.clientsData.length; i++) {
            var c = dockWindow.clientsData[i];
            if (!c.class || c.class.toLowerCase() !== appId.toLowerCase() || !c.workspace)
                continue;

            var ws = c.workspace.id;
            if (!groups[ws]) {
                groups[ws] = [];
                order.push(ws);
            }
            groups[ws].push(c);
        }
        var arr = [];
        for (var o = 0; o < order.length; o++) arr.push({
            "workspaceId": order[o],
            "count": groups[order[o]].length,
            "address": groups[order[o]][0].address
        });
        stackPopup.groups = arr;
        stackPopup.iconName = iconName;
        stackPopup.appId = appId;
        stackPopup.launchCommand = launchCommand;
        stackPopup.anchorLocalX = localPos.x + item.width / 2;
        stackPopup.anchorLocalY = localPos.y;
        stackPopup.popupVisible = true;
    }

    function openContextMenu(item, appId, isPinned, command) {
        var count = 0;
        for (var i = 0; i < dockWindow.clientsData.length; i++) {
            var c = dockWindow.clientsData[i];
            if (c.class && c.class.toLowerCase() === appId.toLowerCase())
                count++;

        }
        contextMenu.openFor(item, appId, isPinned, command, count);
    }

    function handleContextAction(id) {
        var appId = contextMenu.appId;
        if (id === "pin")
            dockWindow.pinRunningApp(appId);
        else if (id === "unpin")
            dockWindow.unpinApp(appId);
        else if (id === "newWindow" && contextMenu.command !== "")
            Quickshell.execDetached(["sh", "-c", contextMenu.command]);
        else if (id === "close")
            dockWindow.closeAppWindows(appId, false);
        else if (id === "closeAll")
            dockWindow.closeAppWindows(appId, true);
    }

    function closeAppWindows(appId, all) {
        var addrs = [];
        for (var i = 0; i < dockWindow.clientsData.length; i++) {
            var c = dockWindow.clientsData[i];
            if (c.class && c.class.toLowerCase() === appId.toLowerCase() && c.address)
                addrs.push(c.address);

        }
        var targets = all ? addrs : addrs.slice(0, 1);
        for (var j = 0; j < targets.length; j++) Hyprland.dispatch("hl.dsp.window.close({window='address:" + targets[j] + "'})");
    }

    margins.bottom: 0
    exclusiveZone: (!Prefs.dockEnabled || Prefs.dockAutoHide) ? 0 : (shell.implicitHeight + Prefs.effectiveDockBottomMargin)
    WlrLayershell.keyboardFocus: dockWindow.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: dockWindow.menuOpen ? WlrLayer.Overlay : WlrLayer.Top
    color: "transparent"
    implicitWidth: Math.max(dockWindow.maxDockWidth, dockWindow.menuWidth)
    implicitHeight: dockWindow.menuMaxHeight + dockWindow.dragHeadroom

    anchors {
        bottom: true
    }

    Component.onCompleted: {
        dockWindow.loadAppsFromDisk();
        dockWindow.appliedWallpaper = dockWindow.currentWallpaperPath();
        if (dockWindow.appliedWallpaper === "")
            dockWindow.applyWallpaper(dockWindow.fallbackWallpaper);

        appScanner.running = true;
    }

    Connections {
        function onThemeChangeRequested(id) {
            dockWindow.switchTheme(id);
        }

        function onWallpapersChanged() {
            wallpaperScanner.scan();
        }

        function onDockShowRunningChanged() {
            dockWindow.syncRunningApps();
        }

        function onPinnedResetRequested() {
            appListModel.clear();
            var defaults = pinnedAdapter.pinnedApps;
            for (var i = 0; i < defaults.length; i++) {
                var a = defaults[i];
                appListModel.append({
                    "appKey": a.appKey,
                    "iconName": a.iconName,
                    "command": a.command,
                    "appId": a.appId,
                    "displayName": a.name || a.appId || a.appKey,
                    "justAdded": false
                });
            }
            dockWindow.persistOrder();
            dockWindow.syncRunningApps();
        }

        target: Prefs
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (!dockWindow.menuOpen)
                launcherFace.searchText = "";

            dockWindow.menuOpen = !dockWindow.menuOpen;
        }

        function open(): void {
            launcherFace.searchText = "";
            dockWindow.menuOpen = true;
        }

        function close(): void {
            dockWindow.menuOpen = false;
        }

        function wallpaper(): void {
            launcherFace.searchText = ">wallpaper";
            dockWindow.menuOpen = true;
        }

        function theme(): void {
            launcherFace.searchText = ">theme";
            dockWindow.menuOpen = true;
        }

        function power(): void {
            launcherFace.searchText = ">power";
            dockWindow.menuOpen = true;
        }

        function blur(): void {
            dockWindow.menuOpen = false;
            Prefs.settingsRequested("general");
        }

        function command(): void {
            launcherFace.searchText = ">";
            dockWindow.menuOpen = true;
        }

        function shuffle(): void {
            wallpaperShuffle.pick();
        }

        function search(q: string): void {
            launcherFace.searchText = q;
            dockWindow.menuOpen = true;
        }

    }

    HyprlandFocusGrab {
        id: launcherGrab

        windows: [dockWindow]
        active: dockWindow.menuOpen && grabArm.armed
        onCleared: {
            if (grabArm.armed)
                dockWindow.menuOpen = false;

        }
    }

    Timer {
        id: grabArm

        property bool armed: false

        interval: 250
        running: dockWindow.menuOpen
        onTriggered: grabArm.armed = true
        onRunningChanged: {
            if (!grabArm.running)
                grabArm.armed = false;

        }
    }

    // touching this strip reveals the dock
    MouseArea {
        id: revealArea

        x: shell.x
        width: shell.width
        anchors.bottom: parent.bottom
        height: dockWindow.dockRevealed ? dockWindow.placementMargin + 3 : 3
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: Prefs.dockAutoHide
        visible: Prefs.dockAutoHide
    }

    StackPopup {
        id: stackPopup

        hostWindow: dockWindow
        activeWorkspaceId: dockWindow.activeWorkspaceId
    }

    ContextMenu {
        id: contextMenu

        hostWindow: dockWindow
        onActionChosen: (id) => dockWindow.handleContextAction(id)
    }

    ListModel {
        id: appListModel
    }

    ListModel {
        id: runningAppsModel
    }

    ListModel {
        id: resultsModel
    }

    ListModel {
        id: wallpapersModel
    }

    FileView {
        id: themeFile

        path: Quickshell.env("HOME") + "/.cache/current_theme"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var t = text().trim();
            dockWindow.currentTheme = t !== "" ? t : "matugen";
        }
    }

    onCurrentThemeChanged: {
        wallpaperScanner.scan();
        dockWindow.rebuildResults();
    }

    FileView {
        id: currentWallFile

        path: Quickshell.env("HOME") + "/.cache/current_wallpaper"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var p = text().trim();
            if (p === "" || p === dockWindow.appliedWallpaper)
                return;

            dockWindow.appliedWallpaper = p;
            wallpaperState.current = p;
            dockWindow.syncStripToCurrent();
        }
    }

    FileView {
        id: usageFile

        path: Qt.resolvedUrl("./usage.json")
        blockLoading: true
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: usageAdapter

            property var counts: ({})
        }

    }

    FileView {
        id: wallpaperStateFile

        path: Qt.resolvedUrl("./wallpaper.json")
        blockLoading: true
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: wallpaperState

            property string current: ""
        }

    }

    FileView {
        id: pinnedFile

        path: Qt.resolvedUrl("./pinned.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: pinnedAdapter

            property var pinnedApps: [{
                "appKey": "nautilus",
                "iconName": "org.gnome.Nautilus",
                "command": "nautilus --new-window",
                "appId": "org.gnome.Nautilus",
                "name": "Files"
            }, {
                "appKey": "codium",
                "iconName": "vscodium",
                "command": "/usr/bin/codium",
                "appId": "codium",
                "name": "VSCodium"
            }, {
                "appKey": "zen",
                "iconName": "zen-browser",
                "command": "/opt/zen-browser-bin/zen-bin",
                "appId": "zen",
                "name": "Zen Browser"
            }, {
                "appKey": "kitty",
                "iconName": "kitty",
                "command": "kitty",
                "appId": "kitty",
                "name": "Kitty"
            }, {
                "appKey": "spotify",
                "iconName": "spotify-client",
                "command": "spotify",
                "appId": "Spotify",
                "name": "Spotify"
            }]
        }

    }

    Process {
        id: appScanner

        command: ["sh", "-c", "for d in /usr/share/applications \"$HOME/.local/share/applications\" " + "/var/lib/flatpak/exports/share/applications \"$HOME/.local/share/flatpak/exports/share/applications\" " + "/var/lib/snapd/desktop/applications; do " + "[ -d \"$d\" ] && find \"$d\" -maxdepth 1 -name '*.desktop' -print0; " + "done | xargs -0 -r awk '" + "function clean(v) { gsub(/\\|/, \" \", v); gsub(/\\r/, \"\", v); return v } " + "function flush(   n, e) { " + "n = clean(name); e = clean(ex); " + "if (nodisp || hidden) return; " + "if (type != \"\" && type != \"Application\") return; " + "if (n == \"\" || e == \"\") return; " + "gsub(/ ?%[a-zA-Z]/, \"\", e); sub(/[ \\t]+$/, \"\", e); " + "if (term == \"true\") e = \"kitty -e \" e; " + "print n \"|\" clean(icon) \"|\" clean(kw \" \" gen \" \" com \" \" cats) \"|\" e \"|\" clean(wm) \"|\" base } " + "BEGINFILE { name=\"\"; icon=\"\"; ex=\"\"; kw=\"\"; gen=\"\"; com=\"\"; cats=\"\"; wm=\"\"; type=\"\"; term=\"\"; nodisp=0; hidden=0; insec=0; " + "base=FILENAME; sub(/.*\\//, \"\", base); sub(/\\.desktop$/, \"\", base) } " + "/^[ \\t]*\\[/ { insec = ($0 ~ /^\\[Desktop Entry\\]/) ? 1 : 0; next } " + "!insec { next } " + "/^Name=/ { if (name == \"\") name = substr($0, 6) } " + "/^Icon=/ { if (icon == \"\") icon = substr($0, 6) } " + "/^Exec=/ { if (ex == \"\") ex = substr($0, 6) } " + "/^Keywords=/ { if (kw == \"\") { kw = substr($0, 10); gsub(/;/, \" \", kw) } } " + "/^GenericName=/ { if (gen == \"\") gen = substr($0, 13) } " + "/^Comment=/ { if (com == \"\") com = substr($0, 9) } " + "/^Categories=/ { if (cats == \"\") { cats = substr($0, 12); gsub(/;/, \" \", cats) } } " + "/^StartupWMClass=/ { if (wm == \"\") wm = substr($0, 16) } " + "/^Type=/ { if (type == \"\") type = substr($0, 6) } " + "/^Terminal=/ { if (term == \"\") term = substr($0, 10) } " + "/^NoDisplay=true/ { nodisp = 1 } " + "/^Hidden=true/ { hidden = 1 } " + "ENDFILE { flush() }'"]

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
                    arr.push({
                        "name": name,
                        "iconName": p[1],
                        "search": (name + " " + p[2] + " " + p[5]).toLowerCase(),
                        "initials": initials,
                        "command": p[3],
                        "wmClass": p[4],
                        "base": p[5]
                    });
                }
                dockWindow.scannedApps = arr;
                dockWindow.rebuildResults();
                dockWindow.syncRunningApps();
            }
        }

    }

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: appScanner.running = true
    }

    Process {
        id: pinLookup

        property string pendingClass: ""
        property int pendingIndex: -1

        stdout: StdioCollector {
            onStreamFinished: {
                var cmd = text.trim();
                if (cmd === "")
                    return;

                dockWindow.addPinned(pinLookup.pendingClass, "", cmd, "", pinLookup.pendingIndex);
            }
        }

    }

    Timer {
        id: wallpaperDebounce

        interval: 250
        onTriggered: dockWindow.applyWallpaper(dockWindow.pendingWallpaper)
    }

    Timer {
        id: wallpaperArmTimer

        interval: 400
        onTriggered: dockWindow.wallpaperArmed = true
    }

    Process {
        id: wallpaperShuffle

        function pick() {
            wallpaperShuffle.running = false;
            wallpaperShuffle.command = ["sh", "-c", "d=\"$HOME/Pictures/wallpapers/" + dockWindow.currentTheme + "\"; " + "[ -d \"$d\" ] || exit 0; " + "find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | shuf -n1"];
            wallpaperShuffle.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                if (p !== "" && p !== dockWindow.appliedWallpaper)
                    dockWindow.applyWallpaper(p);

            }
        }

    }

    Process {
        id: themeSwitchProbe

        property string pendingId: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var id = themeSwitchProbe.pendingId;
                var wallpaper = text.trim();
                if (wallpaper === "" && id === "matugen")
                    wallpaper = dockWindow.fallbackWallpaper;

                if (wallpaper === "")
                    return;

                var home = Quickshell.env("HOME");
                if (id === "matugen" || id === "pywal") {
                    Quickshell.execDetached(["sh", "-c", "echo " + id + " > " + home + "/.cache/current_theme"]);
                } else {
                    Quickshell.execDetached(["sh", "-c", "echo " + id + " > " + home + "/.cache/current_theme && " + home + "/.config/lucid/apply-theme.sh " + id]);
                }
                dockWindow.applyWallpaper(wallpaper);
            }
        }

    }

    Process {
        id: themeWallpaperScan

        stdout: StdioCollector {
            onStreamFinished: {
                var map = {};
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":");
                    if (parts.length === 2)
                        map[parts[0]] = parts[1] === "1";

                }
                dockWindow.themeHasWallpaper = map;
                dockWindow.rebuildResults();
            }
        }

    }

    Process {
        id: wallpaperScanner

        function scan() {
            wallpaperScanner.running = false;
            wallpaperScanner.command = ["sh", "-c", "d=\"$HOME/Pictures/wallpapers/" + dockWindow.currentTheme + "\"; " + "[ -d \"$d\" ] || exit 0; " + "find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"];
            wallpaperScanner.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                wallpapersModel.clear();
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim();
                    if (p === "")
                        continue;

                    var base = p.substring(p.lastIndexOf("/") + 1);
                    var dot = base.lastIndexOf(".");
                    wallpapersModel.append({
                        "path": p,
                        "name": dot > 0 ? base.substring(0, dot) : base
                    });
                }
                if (wallpapersModel.count === 0) {
                    if (dockWindow.appliedWallpaper !== dockWindow.fallbackWallpaper)
                        dockWindow.applyWallpaper(dockWindow.fallbackWallpaper);

                    return;
                }
                var want = wallpaperState.current;
                var idx = 0;
                for (var k = 0; k < wallpapersModel.count; k++) {
                    if (wallpapersModel.get(k).path === want) {
                        idx = k;
                        break;
                    }
                }
                launcherFace.setWallpaperIndex(idx);
            }
        }

    }

    Process {
        id: wallpaperWatch

        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim();
                var missing = out.indexOf("MISSING") !== -1;
                var first = "";
                var m = out.match(/FIRST:(.*)/);
                if (m)
                    first = m[1].trim();

                var onFallback = dockWindow.appliedWallpaper === "" || dockWindow.appliedWallpaper === dockWindow.fallbackWallpaper;
                if (onFallback) {
                    if (first !== "")
                        dockWindow.applyWallpaper(first);

                } else if (missing) {
                    dockWindow.applyWallpaper(first !== "" ? first : dockWindow.fallbackWallpaper);
                }
            }
        }

    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (dockWindow.mode === "wallpaper")
                return;

            wallpaperWatch.command = ["sh", "-c", "d=\"$HOME/Pictures/wallpapers/" + dockWindow.currentTheme + "\"; " + "cur=\"$1\"; " + "if [ -n \"$cur\" ] && [ ! -f \"$cur\" ]; then echo MISSING; fi; " + "if [ -d \"$d\" ]; then " + "f=$(find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort | head -n1); " + "if [ -n \"$f\" ]; then echo \"FIRST:$f\"; fi; " + "fi; exit 0", "sh", dockWindow.appliedWallpaper];
            wallpaperWatch.running = true;
        }
    }

    Process {
        id: dropResolver

        property var pendingPaths: []
        property int insertIndex: -1

        readonly property string script: 'for p in "$@"; do ' + 'n=${p##*/}; ' + 'if [ -d "$p" ]; then printf "dir\tfolder\t%s\t\t\t%s\n" "$n" "$p"; ' + 'elif [ "${p%.desktop}" != "$p" ]; then ' + 'nm=$(sed -n "s/^Name=//p" "$p" | head -n1); ' + 'ic=$(sed -n "s/^Icon=//p" "$p" | head -n1); ' + 'ex=$(sed -n "s/^Exec=//p" "$p" | head -n1 | sed "s/ *%[a-zA-Z]//g"); ' + 'wm=$(sed -n "s/^StartupWMClass=//p" "$p" | head -n1); ' + '[ -z "$nm" ] && nm="$n"; ' + 'printf "app\t%s\t%s\t%s\t%s\t%s\n" "$ic" "$nm" "$ex" "$wm" "$p"; ' + 'else ' + 'c=$(gio info -a standard::icon "$p" 2>/dev/null | sed -n "s/.*standard::icon: //p" | tr "," "\n" | sed "s/^ *//;s/ *$//" | grep -v -- "-symbolic$"); ' + 'f=""; ' + 'for i in $c; do ' + 'if [ -n "$(find "$HOME/.local/share/icons" /usr/share/icons -iname "$i.*" 2>/dev/null | head -n1)" ]; then f="$i"; break; fi; ' + 'done; ' + '[ -z "$f" ] && f=text-x-generic; ' + 'printf "file\t%s\t%s\t\t\t%s\n" "$f" "$n" "$p"; ' + 'fi; done'

        function resolve(paths, index) {
            dropResolver.running = false;
            dropResolver.pendingPaths = paths;
            dropResolver.insertIndex = index;
            dropResolver.command = ["sh", "-c", dropResolver.script, "sh"].concat(paths);
            dropResolver.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var at = dropResolver.insertIndex;
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === "")
                        continue;

                    var f = lines[i].split("\t");
                    if (f.length < 6)
                        continue;

                    var kind = f[0];
                    var icon = f[1];
                    var name = f[2];
                    var exec = f[3];
                    var wm = f[4];
                    var path = f[5];
                    var added = false;
                    if (kind === "app" && exec !== "") {
                        added = dockWindow.addPinned(wm !== "" ? wm : name, icon, exec, name, at);
                    } else {
                        var display = name;
                        if (kind !== "dir") {
                            var dot = name.lastIndexOf(".");
                            if (dot > 0)
                                display = name.substring(0, dot);

                        }
                        added = dockWindow.addPinned(display, icon, "xdg-open " + dockWindow.shQuote(path), display, at);
                    }
                    if (added && at >= 0)
                        at += 1;

                }
            }
        }

    }

    Rectangle {
        id: shell

        property int pendingDropIndex: -1
        property bool dropActive: false
        property bool shellReady: false

        visible: Prefs.dockEnabled || dockWindow.menuOpen
        clip: dockWindow.menuOpen || dockWindow.morphing
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dockWindow.hiddenOffset + dockWindow.placementMargin
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: dockFace.implicitWidth
        implicitHeight: dockWindow.iconSlot + 20
        width: dockWindow.menuOpen ? dockWindow.menuWidth : shell.implicitWidth
        height: dockWindow.menuOpen ? dockWindow.menuHeight : shell.implicitHeight
        radius: Math.min(Theme.radiusXl, Math.round(shell.height / 2))
        color: Theme.bg
        // corners meeting the screen edge square off in notch mode
        bottomLeftRadius: dockWindow.renderAsNotch ? 0 : shell.radius
        bottomRightRadius: dockWindow.renderAsNotch ? 0 : shell.radius

        Component.onCompleted: readyTimer.start()

        HoverHandler {
            id: shellHover
        }

        Timer {
            id: readyTimer

            interval: 50
            onTriggered: shell.shellReady = true
        }

        Behavior on anchors.bottomMargin {
            enabled: !dockWindow.snapPlacement

            NumberAnimation {
                duration: Theme.durLong
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on width {
            enabled: shell.shellReady && dockWindow.morphing

            NumberAnimation {
                duration: dockWindow.shellResizeMs
                easing.type: Easing.Bezier
                easing.bezierCurve: dockWindow.morphCurve
            }

        }

        Behavior on height {
            enabled: shell.shellReady

            NumberAnimation {
                duration: dockWindow.shellResizeMs
                easing.type: Easing.Bezier
                easing.bezierCurve: dockWindow.morphCurve
            }

        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            enabled: !dockWindow.menuOpen && Prefs.dockEnabled

            onEntered: (drag) => {
                if (dockWindow.localPaths(drag.urls).length === 0) {
                    drag.accepted = false;
                    return;
                }
                shell.dropActive = true;
            }
            onExited: {
                shell.dropActive = false;
                shell.pendingDropIndex = -1;
            }
            onPositionChanged: (drag) => {
                var mapped = pinnedRow.mapFromItem(shell, drag.x, drag.y);
                var candidate = Math.round(mapped.x / dockWindow.slotPitch);
                shell.pendingDropIndex = Math.max(0, Math.min(appListModel.count, candidate));
            }
            onDropped: (drop) => {
                var paths = dockWindow.localPaths(drop.urls);
                var at = shell.pendingDropIndex;
                shell.dropActive = false;
                shell.pendingDropIndex = -1;
                if (paths.length > 0)
                    dockWindow.pinDroppedPaths(paths, at);

            }
        }

        Item {
            id: dockFace

            implicitWidth: iconRow.implicitWidth + 24
            width: shell.implicitWidth
            height: shell.implicitHeight
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            opacity: (dockWindow.menuOpen || dockWindow.launcherFromHidden) ? 0 : 1
            visible: dockFace.opacity > 0

            Behavior on opacity {
                enabled: !dockWindow.launcherFromHidden

                NumberAnimation {
                    duration: Theme.ms(200)
                }

            }

            Row {
                id: iconRow

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                DockItem {
                    id: launcherItem

                    displayName: "Launcher"
                    isToggle: true
                    pointerInside: dockWindow.pointerOnDock
                    toggleActive: dockWindow.menuOpen
                    iconContent: Component {
                        Shape {
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: Theme.accent
                                strokeWidth: 3
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                PathSvg {
                                    path: dockWindow.lucidaRing
                                }

                            }

                            ShapePath {
                                strokeWidth: 0
                                fillColor: Theme.text

                                PathSvg {
                                    path: dockWindow.lucidaStar
                                }

                            }

                            ShapePath {
                                strokeWidth: 0
                                fillColor: Theme.accent

                                PathSvg {
                                    path: dockWindow.lucidaCompanion
                                }

                            }

                            transform: Scale {
                                xScale: width / 24
                                yScale: height / 24
                            }

                        }

                    }
                    onRequestToggle: {
                        if (!dockWindow.menuOpen)
                            launcherFace.searchText = "";

                        dockWindow.menuOpen = !dockWindow.menuOpen;
                    }
                }

                Rectangle {
                    width: 1
                    height: Math.round(dockWindow.iconSlot * 0.5)
                    color: Theme.outline
                    anchors.verticalCenter: parent.verticalCenter
                }

                DockRow {
                    id: pinnedRow

                    dragMode: "reorder"
                    model: appListModel
                    clients: dockWindow.clientsData
                    activeWorkspaceId: dockWindow.activeWorkspaceId
                    focusedAddress: dockWindow.focusedAddress
                    ready: shell.shellReady
                    pointerInside: dockWindow.pointerOnDock
                    dropActive: shell.dropActive || dockWindow.pinArmed
                    reserveSlot: shell.dropActive
                    dropIndex: shell.dropActive ? shell.pendingDropIndex : dockWindow.pinDropIndex
                    onStackPopupRequested: (view, appId, iconName, command) => dockWindow.openStackPopup(view, appId, iconName, command)
                    onContextMenuRequested: (view, appId, command) => dockWindow.openContextMenu(view, appId, true, command)
                    onLaunchRecorded: (name) => dockWindow.recordLaunch(name)
                    onOrderChanged: dockWindow.persistOrder()
                    onRemoveRequested: (index) => dockWindow.removePinnedAt(index)
                }

                Item {
                    id: runningGroup

                    readonly property int lead: 21
                    readonly property real fill: Math.min(1, runningRow.width / runningGroup.lead)

                    width: runningRow.width > 0.5 ? runningRow.width + runningGroup.lead * runningGroup.fill : 0
                    height: dockWindow.iconSlot
                    visible: runningGroup.width > 0.5 || runningRow.dragging

                    Rectangle {
                        width: 1
                        height: Math.round(dockWindow.iconSlot * 0.5)
                        color: Theme.outline
                        opacity: runningGroup.fill
                        x: Math.round(runningGroup.lead / 2)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DockRow {
                        id: runningRow

                        x: runningGroup.lead
                        dragMode: "pin"
                        model: runningAppsModel
                        clients: dockWindow.clientsData
                        activeWorkspaceId: dockWindow.activeWorkspaceId
                        focusedAddress: dockWindow.focusedAddress
                        ready: shell.shellReady
                        onStackPopupRequested: (view, appId, iconName, command) => dockWindow.openStackPopup(view, appId, iconName, command)
                        onContextMenuRequested: (view, appId, command) => dockWindow.openContextMenu(view, appId, false, command)
                        onLaunchRecorded: (name) => dockWindow.recordLaunch(name)
                        pointerInside: dockWindow.pointerOnDock
                        pinArmed: dockWindow.pinArmed
                        dropIndex: dockWindow.pinDropIndex
                        onPinRequested: (appId, index) => dockWindow.pinRunningApp(appId, index)
                    }

                }

            }

        }

        LauncherFace {
            id: launcherFace

            width: dockWindow.menuWidth - dockWindow.panelPadding
            height: dockWindow.menuHeight - dockWindow.panelPadding
            targetWidth: dockWindow.menuWidth - dockWindow.panelPadding
            targetHeight: dockWindow.menuHeight - dockWindow.panelPadding
            anchors.centerIn: parent
            opacity: dockWindow.menuOpen ? 1 : 0
            visible: launcherFace.opacity > 0
            mode: dockWindow.mode
            model: resultsModel
            wallpaperModel: wallpapersModel
            wallHeroW: dockWindow.wallHeroW
            wallHeroH: dockWindow.wallHeroH
            wallMidW: dockWindow.wallMidW
            wallMidH: dockWindow.wallMidH
            wallSmallW: dockWindow.wallSmallW
            wallSmallH: dockWindow.wallSmallH
            wallCardGap: dockWindow.wallCardGap
            appliedWallpaper: dockWindow.appliedWallpaper
            highlightQuery: dockWindow.filterQuery
            onActivated: (index) => dockWindow.activateResult(index)
            onCloseRequested: dockWindow.menuOpen = false
            onBackRequested: launcherFace.searchText = dockWindow.mode === "commands" ? "" : ">"
            onWallpaperPreviewed: (path) => dockWindow.requestWallpaper(path)
            onWallpaperChosen: (path) => {
                dockWindow.applyWallpaper(path);
                dockWindow.menuOpen = false;
            }
            onPowerActionChosen: (id) => dockWindow.runPowerAction(id)

            Behavior on width {
                enabled: shell.shellReady

                NumberAnimation {
                    duration: dockWindow.shellResizeMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: dockWindow.morphCurve
                }

            }

            Behavior on height {
                enabled: shell.shellReady

                NumberAnimation {
                    duration: dockWindow.shellResizeMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: dockWindow.morphCurve
                }

            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.ms(dockWindow.contentFadeDelay)
                    }

                    NumberAnimation {
                        duration: Theme.ms(200)
                    }

                }

            }

        }

    }

    Rectangle {
        visible: Prefs.debugRegions
        x: 0
        y: 0
        width: parent.width
        height: Math.max(0, shell.y)
        color: dockWindow.dragging ? "#3800e5ff" : "#1a00b0ff"
        border.color: dockWindow.dragging ? "#ff00e5ff" : "#8000b0ff"
        border.width: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: "dock surface headroom - " + Math.round(parent.width) + " x " + Math.round(parent.height) + " transparent" + (dockWindow.dragging ? " (INPUT LIVE: dragging)" : ", input masked out")
            color: "#cc80d8ff"
            font.pixelSize: 12
            font.family: Theme.fontFamily
        }

    }

    mask: Region {
        x: dockWindow.dragging ? 0 : shell.x
        y: dockWindow.dragging ? 0 : shell.y
        width: dockWindow.dragging ? dockWindow.width : shell.width
        height: dockWindow.dragging ? dockWindow.height : shell.height

        Region {
            item: Prefs.dockAutoHide ? revealArea : null
        }

    }

    Repeater {
        model: dockWindow.renderAsNotch ? 2 : 0

        DockFlare {
            required property int index

            readonly property bool isRight: index === 1

            size: Prefs.dockNotchFlare
            mirrored: isRight
            x: isRight ? shell.x + shell.width : shell.x - width
            y: shell.y + shell.height - height
            z: shell.z
            visible: dockWindow.renderAsNotch && shell.visible
        }

    }

    BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && shell.shellReady) ? dockBlurRegion : null

    Region {
        id: dockBlurRegion

        x: Math.ceil(shell.x - 0.002)
        y: Math.ceil(shell.y - 0.002)
        width: Math.max(0, Math.floor(shell.x + shell.width + 0.002) - Math.ceil(shell.x - 0.002))
        height: Math.max(0, Math.floor(shell.y + shell.height + 0.002) - Math.ceil(shell.y - 0.002))
        radius: shell.radius
        bottomLeftRadius: shell.bottomLeftRadius
        bottomRightRadius: shell.bottomRightRadius
    }

}
