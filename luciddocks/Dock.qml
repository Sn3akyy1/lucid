import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: dockWindow

    property bool morphing: false
    property bool closingFromHidden: false
    readonly property bool dockBusy: dockWindow.menuOpen || dockWindow.dragging || (dockWindow.morphing && !dockWindow.launcherFromHidden && !dockWindow.closingFromHidden)
    property bool slidingAway: false
    readonly property bool heldByPointer: revealArea.containsMouse || (shellHover.hovered && !dockWindow.slidingAway)
    readonly property bool dockRevealed: !Prefs.dockAutoHide || dockWindow.dockBusy || dockWindow.heldByPointer
    property bool launcherFromHidden: false
    readonly property bool renderAsNotch: Prefs.dockNotch || dockWindow.launcherFromHidden
    readonly property int placementMargin: dockWindow.launcherFromHidden ? 0 : Prefs.effectiveDockBottomMargin
    readonly property real hiddenOffset: dockWindow.dockRevealed ? 0 : -(shell.implicitHeight + dockWindow.placementMargin - 1)

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

    // the one way in from outside the dock — the launcher's modes are its
    // own search prefixes, so callers pass the prefix they want
    function openLauncher(query) {
        launcherFace.searchText = query;
        dockWindow.menuOpen = true;
    }

    function pulseMorph() {
        dockWindow.shellResizeMs = Theme.ms(480);
        dockWindow.morphing = true;
        morphTimer.restart();
    }

    property bool snapPlacement: false
    property int contentFadeDelay: 0
    property bool menuOpen: false
    // true while the launcher is folding away, so the surface outlives
    // menuOpen long enough to show it — with the dock disabled it would
    // otherwise vanish on the same frame
    property bool launcherClosing: false

    onMenuOpenChanged: {
        dockWindow.pulseMorph();
        dockWindow.contentFadeDelay = dockWindow.menuOpen ? 190 : 0;
        if (dockWindow.menuOpen) {
            launcherCloseTimer.stop();
            shellFadeOut.stop();
            dockWindow.launcherClosing = false;
            shell.opacity = 1;
            // window titles only reach lastIpcObject on a refresh, and search reads them
            toplevelRefresh.restart();
        } else {
            powerDisarm.stop();
            dockWindow.armedPower = "";
            dockWindow.launcherClosing = true;
            launcherCloseTimer.restart();
            // no dock to morph back into: fade the whole surface as it shrinks
            if (!Prefs.dockEnabled)
                shellFadeOut.restart();

        }
        if (dockWindow.menuOpen) {
            dockWindow.launcherFromHidden = Prefs.dockAutoHide && !dockWindow.heldByPointer;
            dockWindow.closingFromHidden = false;
            dockWindow.snapPlacement = true;
            snapClear.restart();
        } else if (dockWindow.launcherFromHidden) {
            dockWindow.closingFromHidden = true;
            hideAfterClose.restart();
        } else {
            dockWindow.launcherFromHidden = false;
        }
    }

    Timer {
        id: launcherCloseTimer

        interval: Math.max(Theme.ms(520), Theme.durLong) + 40
        onTriggered: {
            dockWindow.launcherClosing = false;
            shell.opacity = 1;
        }
    }

    SequentialAnimation {
        id: shellFadeOut

        PauseAnimation {
            duration: Theme.ms(140)
        }

        NumberAnimation {
            target: shell
            property: "opacity"
            to: 0
            duration: Theme.ms(340)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
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
            dockWindow.closingFromHidden = false;
        }
    }

    property string fallbackWallpaper: Qt.resolvedUrl("../assets/fallback.jpg").toString().replace("file://", "")
    property var scannedApps: []
    readonly property string currentTheme: Prefs.currentTheme
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

    // quickshell only fills lastIpcObject on an explicit refresh, so without
    // this a new window waits out the poll below before it reaches the dock
    Timer {
        id: toplevelRefresh

        interval: 8
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindow":
            case "movewindowv2":
                toplevelRefresh.restart();
                break;
            }
        }
    }

    // safety net for anything the events above miss
    Timer {
        interval: 4000
        running: dockWindow.visible && (dockWindow.menuOpen || dockWindow.dockRevealed)
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }

    onClientsDataChanged: {
        dockWindow.syncRunningApps();
        // open windows are search results too
        if (dockWindow.menuOpen && dockWindow.mode === "apps" && dockWindow.filterQuery !== "")
            dockWindow.rebuildResults();

    }

    readonly property string rawQuery: launcherFace.searchText

    function modeFor(raw) {
        var q = raw.toLowerCase();
        if (q.indexOf(">wallpaper") === 0)
            return "wallpaper";

        if (q.indexOf(">theme") === 0)
            return "theme";

        if (q.indexOf(">power") === 0)
            return "power";

        if (q.indexOf(">clip") === 0)
            return "clipboard";

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

        if (mode === "clipboard")
            return ">clip";

        if (mode === "commands")
            return ">";

        return "";
    }

    function queryFor(raw) {
        return raw.substring(dockWindow.prefixFor(dockWindow.modeFor(raw)).length).trim();
    }

    readonly property string mode: dockWindow.modeFor(dockWindow.rawQuery)
    readonly property string filterQuery: dockWindow.queryFor(dockWindow.rawQuery)

    onRawQueryChanged: {
        // a new query never inherits an armed restart
        powerDisarm.stop();
        dockWindow.armedPower = "";
        launcherFace.beginFilter();
        dockWindow.rebuildResults();
        // the face already reset itself, but against the pre-rebuild rows
        launcherFace.resetSelection();
    }
    onModeChanged: {
        if (dockWindow.mode === "wallpaper") {
            wallpaperScanner.scan();
            dockWindow.wallpaperArmed = false;
            wallpaperArmTimer.restart();
        } else {
            dockWindow.wallpaperArmed = false;
        }
        if (dockWindow.mode === "clipboard")
            Clip.refresh();

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
        "id": "clipboard",
        "name": "Clipboard History",
        "desc": "Copy something you copied earlier",
        "glyph": DockIcons.clipboard
    }, {
        "id": "power",
        "name": "Power",
        "desc": "Lock, suspend, restart or shut down",
        "glyph": DockIcons.power
    }, {
        "id": "widgets",
        "name": "Desktop Widgets",
        "desc": "Place clocks, meters and notes on the desktop",
        "glyph": DockIcons.widgets
    }, {
        "id": "keyboard",
        "name": "On-Screen Keyboard",
        "desc": "Type with the pointer when there is no keyboard",
        "glyph": DockIcons.keyboard
    }, {
        "id": "settings",
        "name": "Settings",
        "desc": "Open Lucid's settings",
        "glyph": DockIcons.settings
    }]
    // found by plain search, not listed under > (the power screen covers that).
    // runPowerAction ids; restart, shut down and log out want a second Return
    readonly property var powerCommands: [{
        "id": "lock",
        "name": "Lock Screen",
        "desc": "Lock the session",
        "keywords": "",
        "confirm": "",
        "glyph": DockIcons.lock
    }, {
        "id": "suspend",
        "name": "Suspend",
        "desc": "Sleep, keeping the session in memory",
        "keywords": "sleep",
        "confirm": "",
        "glyph": DockIcons.suspend
    }, {
        "id": "hibernate",
        "name": "Hibernate",
        "desc": "Save the session to disk and power off",
        "keywords": "sleep",
        "confirm": "",
        "glyph": DockIcons.hibernate
    }, {
        "id": "logout",
        "name": "Log Out",
        "desc": "End the session",
        "keywords": "logout sign out exit",
        "confirm": "log out",
        "glyph": DockIcons.logout
    }, {
        "id": "reboot",
        "name": "Restart",
        "desc": "Reboot the computer",
        "keywords": "reboot",
        "confirm": "restart",
        "glyph": DockIcons.reboot
    }, {
        "id": "shutdown",
        "name": "Shut Down",
        "desc": "Power the computer off",
        "keywords": "shutdown poweroff power off",
        "confirm": "shut down",
        "glyph": DockIcons.power
    }]

    // 100 at the start, 90 at a word start, 80 anywhere, -1 when absent
    function textScore(text, q) {
        var at = text.indexOf(q);
        if (at === -1)
            return -1;

        if (at === 0)
            return 100;

        return text.indexOf(" " + q) !== -1 ? 90 : 80;
    }

    // every word of the query somewhere in the text, in any order
    function wordsIn(text, q) {
        var words = q.split(/\s+/);
        for (var i = 0; i < words.length; i++) {
            if (words[i] !== "" && text.indexOf(words[i]) === -1)
                return false;

        }
        return true;
    }

    // short queries only match names, or every command would turn up for one letter
    function commandScore(cmd, q) {
        if (q.length < 2)
            return -1;

        var s = dockWindow.textScore(cmd.name.toLowerCase(), q);
        if (s === 80 && q.length < 3)
            s = -1;

        if (s >= 0)
            return s;

        if (q.length < 3)
            return -1;

        return dockWindow.wordsIn((cmd.name + " " + cmd.desc + " " + (cmd.keywords || "")).toLowerCase(), q) ? 60 : -1;
    }

    function windowScore(client, app, q) {
        var best = -1;
        if (app) {
            // no loose letter-by-letter hits: a window is there to be switched to on purpose
            var byApp = dockWindow.matchScore(app, q);
            if (byApp >= 50)
                best = byApp;

        } else {
            best = dockWindow.textScore(client.class.toLowerCase(), q);
        }
        var title = (client.title || "").toLowerCase();
        if (q.length >= 2) {
            var byTitle = dockWindow.textScore(title, q);
            // a title hit ranks under the same hit on the app's own name
            if (byTitle >= 0)
                best = Math.max(best, byTitle - 15);
            else if (q.length >= 3 && dockWindow.wordsIn(title, q))
                best = Math.max(best, 55);
        }
        // the window behind the launcher is the one least likely wanted
        if (best >= 0 && client.address === dockWindow.focusedAddress)
            best -= 25;

        return best;
    }

    // something that reads as an address, ready for xdg-open; "" otherwise
    function urlFor(text) {
        var t = text.trim();
        if (t === "" || /\s/.test(t))
            return "";

        if (/^https?:\/\/\S+$/i.test(t))
            return t;

        if (/^localhost(:\d+)?(\/\S*)?$/i.test(t))
            return "http://" + t;

        if (/^[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}(:\d+)?(\/\S*)?$/i.test(t))
            return "https://" + t;

        return "";
    }

    function webSearchUrl(text) {
        var tpl = Prefs.launcherSearchUrl.trim() !== "" ? Prefs.launcherSearchUrl.trim() : "https://duckduckgo.com/?q=%s";
        var q = encodeURIComponent(text);
        return tpl.indexOf("%s") !== -1 ? tpl.split("%s").join(q) : tpl + q;
    }

    function webSearchHost() {
        var m = dockWindow.webSearchUrl("").match(/^[a-z]+:\/\/(www\.)?([^\/?#]+)/i);
        return m ? m[2] : "";
    }

    // shared with the settings app, see Prefs.themeCatalogue
    readonly property var allThemes: Prefs.themeCatalogue

    readonly property int iconSlot: Prefs.dockIconSize
    readonly property int iconGap: Prefs.dockSpacing
    readonly property int slotPitch: dockWindow.iconSlot + dockWindow.iconGap
    readonly property real maxDockWidth: dockWindow.screen ? dockWindow.screen.width : 1920
    property real dragHeadroom: 220

    // Settings -> Dock -> Launcher -> Visible results
    readonly property int maxRows: Math.max(3, Math.min(12, Prefs.launcherMaxRows))
    // room for maxRows of the tallest ordinary row (58 + spacing), inside the screen
    readonly property int menuMaxHeight: Math.min((dockWindow.screen ? dockWindow.screen.height : 1080) - 40, Math.max(560, dockWindow.panelPadding + launcherFace.chromeHeight + 8 + dockWindow.maxRows * 60))
    // the command palette is a short fixed list, so it caps tighter than the app launcher
    readonly property int commandMaxHeight: 452
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

        return dockWindow.launcherWidth;
    }
    // Settings -> Dock -> Launcher; kept inside the screen however wide prefs.json says
    readonly property real launcherWidth: Math.min(Math.max(420, Prefs.launcherWidth), dockWindow.maxDockWidth - 48)
    property real resultsHeight: 0
    readonly property real menuContentMax: (dockWindow.mode === "commands" ? dockWindow.commandMaxHeight : dockWindow.menuMaxHeight) - dockWindow.panelPadding - launcherFace.chromeHeight
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

    // the bar's scratchpad stash goes through this so it shows the icons the dock shows
    function iconForClass(cls) {
        if (!cls || cls === "")
            return "";

        var entry = dockWindow.entryForClass(cls);
        return IconTheme.resolve(entry && entry.iconName !== "" ? entry.iconName : cls);
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
            "thumb": opts.thumb || "",
            "disabled": opts.disabled === true,
            "selectable": opts.selectable !== false,
            "nested": opts.nested === true,
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
        return dockWindow.makeRow("app", "app-" + app.name, app.name, Prefs.launcherAppDescriptions ? (app.desc || "") : "", {
            "iconName": app.iconName,
            "payload": app.command
        });
    }

    readonly property var kindRank: ({
        "window": 0,
        "app": 1,
        "command": 2,
        "power": 3,
        "action": 4
    })

    // score, then kind, then each kind's own order (carried in tie, since sort isn't guaranteed stable)
    function byRank(items) {
        return items.sort(function(x, y) {
            if (x.score !== y.score)
                return y.score - x.score;

            var k = dockWindow.kindRank[x.kind] - dockWindow.kindRank[y.kind];
            return k !== 0 ? k : x.tie - y.tie;
        });
    }

    // a typed query: windows, apps, commands and app actions in one ranking,
    // then an address to open and a web search to fall back on
    function searchRows(text, q, rows, scoredApps) {
        var ranked = [];
        for (var a = 0; a < scoredApps.length; a++) ranked.push({
            "kind": "app",
            "score": scoredApps[a].score,
            "tie": a,
            "app": scoredApps[a].app
        });
        if (Prefs.launcherWindows) {
            var wins = [];
            for (var w = 0; w < dockWindow.clientsData.length; w++) {
                var c = dockWindow.clientsData[w];
                if (!c.address)
                    continue;

                var owner = dockWindow.entryForClass(c.class);
                var ws = dockWindow.windowScore(c, owner, q);
                if (ws >= 0)
                    wins.push({
                        "kind": "window",
                        "score": ws,
                        // most recently focused first
                        "tie": c.focusHistoryID === undefined ? 999 : c.focusHistoryID,
                        "client": c,
                        "app": owner
                    });

            }
            ranked = ranked.concat(dockWindow.byRank(wins).slice(0, 6));
        }
        for (var m = 0; m < dockWindow.allCommands.length; m++) {
            var cs = dockWindow.commandScore(dockWindow.allCommands[m], q);
            if (cs >= 0)
                ranked.push({
                    "kind": "command",
                    "score": cs,
                    "tie": m,
                    "cmd": dockWindow.allCommands[m]
                });

        }
        // never from two letters: "re" shouldn't put Restart one Return away
        if (q.length >= 3) {
            for (var pw = 0; pw < dockWindow.powerCommands.length; pw++) {
                var ps = dockWindow.commandScore(dockWindow.powerCommands[pw], q);
                if (ps >= 0)
                    ranked.push({
                        "kind": "power",
                        "score": ps,
                        "tie": pw,
                        "cmd": dockWindow.powerCommands[pw]
                    });

            }
        }
        ranked = dockWindow.byRank(ranked);
        // the leading app, on a real name hit, lists its actions right under it
        var expanded = null;
        for (var r = 0; r < ranked.length; r++) {
            if (ranked[r].kind !== "app")
                continue;

            if (ranked[r].score >= 90 && ranked[r].app.actions.length > 0)
                expanded = ranked[r].app;

            break;
        }
        if (q.length >= 3) {
            var acts = [];
            for (var p = 0; p < dockWindow.scannedApps.length; p++) {
                var host = dockWindow.scannedApps[p];
                if (host === expanded)
                    continue;

                for (var x = 0; x < host.actions.length; x++) {
                    var act = host.actions[x];
                    var actScore = dockWindow.textScore(act.name.toLowerCase(), q);
                    // "zen private" finds Zen's New Private Window
                    if (actScore < 0 && dockWindow.wordsIn((host.name + " " + act.name).toLowerCase(), q))
                        actScore = 65;

                    // below the apps: "new" is mostly a way to find an app
                    if (actScore >= 0)
                        acts.push({
                            "kind": "action",
                            "score": actScore - 20,
                            "tie": acts.length,
                            "app": host,
                            "action": act
                        });

                }
            }
            ranked = dockWindow.byRank(ranked.concat(dockWindow.byRank(acts).slice(0, 5)));
        }
        var url = dockWindow.urlFor(text);
        var urlRow = url === "" ? null : dockWindow.makeRow("url", "url", "Open " + url.replace(/^https?:\/\//i, ""), url, {
            "glyph": DockIcons.link,
            "payload": url
        });
        // an address beats weak name matches, not a real hit
        var urlFirst = urlRow !== null && (ranked.length === 0 || ranked[0].score < 80);
        if (urlFirst)
            rows.push(urlRow);

        for (var i = 0; i < ranked.length; i++) {
            var it = ranked[i];
            if (it.kind === "window") {
                rows.push(dockWindow.rowForWindow(it.client, it.app));
            } else if (it.kind === "app") {
                rows.push(dockWindow.rowForApp(it.app));
                if (it.app === expanded) {
                    for (var n = 0; n < Math.min(5, expanded.actions.length); n++) rows.push(dockWindow.rowForAction(expanded, expanded.actions[n], true))
                }
            } else if (it.kind === "action") {
                rows.push(dockWindow.rowForAction(it.app, it.action, false));
            } else if (it.kind === "command") {
                rows.push(dockWindow.makeRow("command", "cmd-" + it.cmd.id, it.cmd.name, it.cmd.desc, {
                    "glyph": it.cmd.glyph,
                    "payload": it.cmd.id
                }));
            } else if (it.kind === "power") {
                var armed = dockWindow.armedPower === it.cmd.id;
                rows.push(dockWindow.makeRow("power", "pow-" + it.cmd.id, it.cmd.name, armed ? "Press Return again to " + it.cmd.confirm : it.cmd.desc, {
                    "glyph": it.cmd.glyph,
                    "payload": it.cmd.id
                }));
            }
        }
        if (urlRow !== null && !urlFirst)
            rows.push(urlRow);

        if (Prefs.launcherWebSearch)
            rows.push(dockWindow.makeRow("web", "web", "Search the web for “" + text + "”", dockWindow.webSearchHost(), {
                "glyph": DockIcons.globe,
                "payload": dockWindow.webSearchUrl(text)
            }));

    }

    function rowForWindow(client, app) {
        var name = app ? app.name : client.class;
        var ws = client.workspace ? client.workspace.name : "";
        // special workspaces keep their "special:" name, numbered ones read as words
        if (ws !== "" && client.workspace.id > 0)
            ws = "Workspace " + ws;

        return dockWindow.makeRow("window", "win-" + client.address, client.title && client.title !== "" ? client.title : name, ws !== "" ? name + " · " + ws : name, {
            "iconName": app ? app.iconName : client.class,
            "payload": client.address
        });
    }

    // nested rows sit under their app, so they drop the icon and the app name
    function rowForAction(app, action, nested) {
        return dockWindow.makeRow("action", "act-" + app.name + "-" + action.name, action.name, nested ? "" : app.name, {
            "iconName": nested ? "" : app.iconName,
            "glyph": nested ? DockIcons.subItem : "",
            "nested": nested,
            "payload": JSON.stringify({
                "app": app.name,
                "command": action.command
            })
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
                dockWindow.searchRows(dockWindow.queryFor(raw), q, rows, scored);
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
        } else if (mode === "clipboard") {
            var ents = Clip.entries;
            for (var e = 0; e < ents.length; e++) {
                var ent = ents[e];
                if (q !== "" && ent.preview.toLowerCase().indexOf(q) === -1)
                    continue;

                rows.push(dockWindow.makeRow("clip", "clip-" + ent.id, ent.preview, ent.meta, {
                    "glyph": ent.isImage ? "" : DockIcons.clipboard,
                    "thumb": ent.isImage ? ent.id : "",
                    "payload": ent.id
                }));
            }
        } else if (mode === "theme") {
            for (var t = 0; t < dockWindow.allThemes.length; t++) {
                var th = dockWindow.allThemes[t];
                if (q !== "" && th.name.toLowerCase().indexOf(q) === -1)
                    continue;

                rows.push(dockWindow.makeRow("theme", "theme-" + th.id, th.name, th.desc, {
                    "swatchBg": th.swatchBg,
                    "swatchAccent": th.swatchAccent,
                    "trailing": th.id === dockWindow.currentTheme ? "check" : "",
                    "payload": th.id
                }));
            }
        }
        dockWindow.syncResults(rows);
    }

    function syncResults(rows) {
        // a key can repeat: frequent apps show up again in the full list
        var wanted = {};
        for (var j = 0; j < rows.length; j++) wanted[rows[j].key] = (wanted[rows[j].key] || 0) + 1;
        for (var i = resultsModel.count - 1; i >= 0; i--) {
            var key = resultsModel.get(i).key;
            if (!wanted[key])
                resultsModel.remove(i, 1);
            else
                wanted[key]--;
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
        if (resultsModel.count > rows.length)
            resultsModel.remove(rows.length, resultsModel.count - rows.length);

        dockWindow.resultsHeight = dockWindow.measure(rows);
        launcherFace.resultsChanged();
    }

    function measure(rows) {
        if (rows.length === 0)
            return 0;

        // the loop adds one spacing too many; 8 is the view's bottom margin
        var h = 8 - 2;
        // grow until maxRows results show, then the list scrolls; headers ride along
        var shown = 0;
        for (var i = 0; i < rows.length && shown < dockWindow.maxRows; i++) {
            h += launcherFace.rowHeightFor(rows[i].kind, rows[i].subtitle);
            h += 2;
            if (rows[i].selectable)
                shown++;

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
        } else if (row.kind === "clip") {
            Clip.copy(row.payload);
            dockWindow.menuOpen = false;
        } else if (row.kind === "theme") {
            dockWindow.switchTheme(row.payload);
        } else if (row.kind === "command") {
            dockWindow.runCommand(row.payload);
        } else if (row.kind === "window") {
            dockWindow.menuOpen = false;
            windowFocus.address = row.payload;
            windowFocus.restart();
        } else if (row.kind === "action") {
            var act = JSON.parse(row.payload);
            Quickshell.execDetached(["sh", "-c", act.command]);
            dockWindow.recordLaunch(act.app);
            dockWindow.menuOpen = false;
        } else if (row.kind === "power") {
            dockWindow.requestPower(row.payload);
        } else if (row.kind === "web" || row.kind === "url") {
            Quickshell.execDetached(["xdg-open", row.payload]);
            dockWindow.menuOpen = false;
        }
    }

    // after the launcher lets go of the keyboard, or its focus grab can hand focus back behind us
    Timer {
        id: windowFocus

        property string address: ""

        interval: 60
        onTriggered: Hyprland.dispatch("hl.dsp.focus({window='address:" + windowFocus.address + "'})")
    }

    // the power action waiting on a second press; one at a time, for rows and chips alike
    property string armedPower: ""

    onArmedPowerChanged: {
        if (dockWindow.menuOpen && dockWindow.mode === "apps" && dockWindow.filterQuery !== "")
            dockWindow.rebuildResults();

    }

    Timer {
        id: powerDisarm

        interval: 3000
        onTriggered: dockWindow.armedPower = ""
    }

    // restart, shut down and log out lose unsaved work: the first press only arms them
    function requestPower(id) {
        var risky = id === "reboot" || id === "shutdown" || id === "logout";
        if (risky && dockWindow.armedPower !== id) {
            dockWindow.armedPower = id;
            powerDisarm.restart();
            return;
        }
        powerDisarm.stop();
        dockWindow.armedPower = "";
        dockWindow.runPowerAction(id);
    }

    // clipboard rows are the only removable ones
    function deleteResult(index) {
        var row = resultsModel.get(index);
        if (!row || row.kind !== "clip")
            return;

        Clip.remove(row.payload);
    }

    function runCommand(id) {
        if (id === "wallpaper") {
            launcherFace.searchText = ">wallpaper";
        } else if (id === "theme") {
            launcherFace.searchText = ">theme";
        } else if (id === "power") {
            launcherFace.searchText = ">power";
        } else if (id === "clipboard") {
            launcherFace.searchText = ">clip";
        } else if (id === "shuffle") {
            wallpaperShuffle.pick();
            dockWindow.menuOpen = false;
        } else if (id === "keyboard") {
            dockWindow.menuOpen = false;
            Prefs.keyboardRequested();
        } else if (id === "settings") {
            dockWindow.menuOpen = false;
            Prefs.settingsRequested("");
        } else if (id === "widgets") {
            dockWindow.menuOpen = false;
            Prefs.settingsRequested("widgets");
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

    function switchTheme(id) {
        themeSwitchProbe.pendingId = id;
        themeSwitchProbe.command = ["sh", "-c", "d=\"" + Prefs.wallpaperDirFor(id) + "\"; " + "[ -d \"$d\" ] && find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort | head -n1; true"];
        themeSwitchProbe.running = true;
        dockWindow.menuOpen = false;
    }

    function runPowerAction(id) {
        if (id === "lock") {
            Lockscreen.lock();
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
            "workspaceName": groups[order[o]][0].workspace.name || "",
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

    // off for a beat when displays change, so a surface torn down with an
    // unplugged one is remapped rather than staying gone until a reload
    visible: Monitors.surfacesUp
    margins.bottom: 0
    exclusiveZone: (!Prefs.loaded || !Prefs.dockEnabled || Prefs.dockAutoHide) ? 0 : (shell.implicitHeight + Prefs.effectiveDockBottomMargin)
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

        function onWallpaperDirChanged() {
            wallpaperScanner.scan(false);
        }

        function onDockShowRunningChanged() {
            dockWindow.syncRunningApps();
        }

        function onLauncherAppDescriptionsChanged() {
            dockWindow.rebuildResults();
        }

        function onLauncherMaxRowsChanged() {
            dockWindow.rebuildResults();
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
            dockWindow.openLauncher("");
        }

        function close(): void {
            dockWindow.menuOpen = false;
        }

        function wallpaper(): void {
            dockWindow.openLauncher(">wallpaper");
        }

        function theme(): void {
            dockWindow.openLauncher(">theme");
        }

        function power(): void {
            dockWindow.openLauncher(">power");
        }

        function clipboard(): void {
            dockWindow.openLauncher(">clip");
        }

        function blur(): void {
            dockWindow.menuOpen = false;
            Prefs.settingsRequested("glass");
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

    // the strip rescan rides on wallpaperDir, which follows the theme
    onCurrentThemeChanged: dockWindow.rebuildResults()

    Connections {
        function onEntriesChanged() {
            if (dockWindow.mode === "clipboard")
                dockWindow.rebuildResults();

        }

        target: Clip
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

            // last-resort fallback only — the installer writes pinned.json from
            // what is actually installed. keep this generic: no absolute paths,
            // nothing that is not on a stock system.
            property var pinnedApps: [{
                "appKey": "files",
                "iconName": "system-file-manager",
                "command": "xdg-open " + Quickshell.env("HOME"),
                "appId": "files",
                "name": "Files"
            }, {
                "appKey": "terminal",
                "iconName": "utilities-terminal",
                "command": "xdg-terminal-exec",
                "appId": "terminal",
                "name": "Terminal"
            }]
        }

    }

    Process {
        id: appScanner

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
            wallpaperShuffle.command = ["sh", "-c", "d=\"" + Prefs.wallpaperDir + "\"; " + "[ -d \"$d\" ] || exit 0; " + "find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | shuf -n1"];
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
                var found = text.trim();
                var wallpaper = found;

                // already browsing that folder, so keep the picture and just
                // re-derive the theme. only while the folder still has one:
                // otherwise this re-applies a path that no longer exists,
                // set-wallpaper.sh bails on the missing file, and the fallback
                // below never gets its turn
                if (found !== "" && dockWindow.appliedWallpaper.indexOf(Prefs.wallpaperDirFor(id) + "/") === 0)
                    wallpaper = dockWindow.appliedWallpaper;

                // an empty theme folder is the normal state on a fresh install.
                // last word, so nothing above can override it back to a dead path
                if (wallpaper === "")
                    wallpaper = dockWindow.fallbackWallpaper;

                // the theme is switched before the wallpaper and never gated on
                // it: bailing out here used to leave the palette on the old theme
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
        id: wallpaperScanner

        // typing a folder that turns up empty shouldn't swap the desktop out
        property bool applyFallbackIfEmpty: true

        function scan(applyFallback) {
            wallpaperScanner.applyFallbackIfEmpty = applyFallback !== false;
            wallpaperScanner.running = false;
            wallpaperScanner.command = ["sh", "-c", "d=\"" + Prefs.wallpaperDir + "\"; " + "[ -d \"$d\" ] || exit 0; " + "find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"];
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
                    if (wallpaperScanner.applyFallbackIfEmpty && dockWindow.appliedWallpaper !== dockWindow.fallbackWallpaper)
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

            wallpaperWatch.command = ["sh", "-c", "d=\"" + Prefs.wallpaperDir + "\"; " + "cur=\"$1\"; " + "if [ -n \"$cur\" ] && [ ! -f \"$cur\" ]; then echo MISSING; fi; " + "if [ -d \"$d\" ]; then " + "f=$(find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort | head -n1); " + "if [ -n \"$f\" ]; then echo \"FIRST:$f\"; fi; " + "fi; exit 0", "sh", dockWindow.appliedWallpaper];
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

        visible: Prefs.dockEnabled || dockWindow.menuOpen || dockWindow.launcherClosing
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
            onDeleteRequested: (index) => dockWindow.deleteResult(index)
            onWallpaperPreviewed: (path) => dockWindow.requestWallpaper(path)
            onWallpaperChosen: (path) => {
                dockWindow.applyWallpaper(path);
                dockWindow.menuOpen = false;
            }
            onPowerActionChosen: (id) => dockWindow.runPowerAction(id)
            showPowerChips: Prefs.launcherPowerChips
            armedPower: dockWindow.armedPower
            onPowerChipTapped: (id) => dockWindow.requestPower(id)

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
            opacity: shell.opacity
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
