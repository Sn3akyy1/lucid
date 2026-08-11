import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: dockWindow

    property bool morphing: false

    function pulseMorph() {
        morphing = true;
        morphTimer.restart();
    }

    onMenuOpenChanged: pulseMorph()
    // resizes while the menu is open need the same smooth morph as opening
    onMenuWidthChanged: if (menuOpen)
        pulseMorph()
    onMenuHeightChanged: if (menuOpen)
        pulseMorph()

    Timer {
        id: morphTimer

        interval: 400
        onTriggered: dockWindow.morphing = false
    }
    property string fallbackWallpaper: Qt.resolvedUrl("./fallback.jpg").toString().replace("file://", "")
    property var scannedApps: []
    property bool menuOpen: false
    property string currentTheme: "matugen"

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

    onCurrentThemeChanged: wallpaperScanner.running = true
    property string pendingWallpaper: ""
    property string appliedWallpaper: ""
    property bool wallpaperArmed: false
    property bool dragging: false
    property real menuWidth: wallpaperMode ? 820 : (powerMode ? 640 : 380)
    property real menuMaxHeight: 480
    property string searchQuery: launcherFace.searchText
    property bool commandMode: searchQuery.indexOf(">") === 0
    property bool wallpaperMode: searchQuery.toLowerCase().indexOf(">wallpaper") === 0
    property bool themeMode: searchQuery.toLowerCase().indexOf(">theme") === 0
    property bool powerMode: searchQuery.toLowerCase().indexOf(">power") === 0
    property bool blurMode: searchQuery.toLowerCase().indexOf(">blur") === 0
    property var allCommands: [{
        "name": "Choose Wallpaper",
        "desc": "Browse and set a new desktop wallpaper",
        "iconPath": "M21 3H3a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2Zm0 16H3V5h18v14ZM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5Z",
        "commandId": "wallpaper"
    }, {
        "name": "Switch Theme",
        "desc": "Change the color scheme",
        "iconPath": "M12 2C6.49 2 2 6.49 2 12s4.49 10 10 10c.83 0 1.5-.67 1.5-1.5 0-.39-.15-.74-.39-1.01-.23-.26-.38-.61-.38-.99 0-.83.67-1.5 1.5-1.5H16c3.31 0 6-2.69 6-6 0-4.96-4.49-9-10-9Zm5.5 9c-.83 0-1.5-.67-1.5-1.5S16.67 8 17.5 8s1.5.67 1.5 1.5S18.33 11 17.5 11Zm-3-4C13.67 7 13 6.33 13 5.5S13.67 4 14.5 4s1.5.67 1.5 1.5S15.33 7 14.5 7Zm-5 0C8.67 7 8 6.33 8 5.5S8.67 4 9.5 4s1.5.67 1.5 1.5S10.33 7 9.5 7Zm-3 4C5.67 11 5 10.33 5 9.5S5.67 8 6.5 8 8 8.67 8 9.5 7.33 11 6.5 11Z",
        "commandId": "theme"
    }, {
        "name": "Power",
        "desc": "Shut down, restart, or log out",
        "iconPath": "M13 3h-2v10h2V3Zm4.83 2.17-1.42 1.42A6.98 6.98 0 0 1 19 12a7 7 0 1 1-11.66-5.24L5.92 5.34A9 9 0 1 0 21 12a8.97 8.97 0 0 0-3.17-6.83Z",
        "commandId": "power"
    }, {
        "name": "Blur",
        "desc": "Adjust the shell's blur and translucency",
        "iconPath": "M12 2c-4.6 5.6-7 9.4-7 12.5C5 18.6 8.1 22 12 22s7-3.4 7-7.5C19 11.4 16.6 7.6 12 2Z",
        "commandId": "blur"
    }]
    
    property var allThemes: [
        { "id": "matugen", "name": "Matugen", "desc": "Colors generated from your wallpaper", "swatchBg": "#12171a", "swatchAccent": "#8ad0ee" },
        { "id": "catppuccin-mocha", "name": "Catppuccin Mocha", "desc": "Soothing pastel dark theme", "swatchBg": "#1e1e2e", "swatchAccent": "#89b4fa" },
        { "id": "gruvbox", "name": "Gruvbox", "desc": "Retro groove warm palette", "swatchBg": "#282828", "swatchAccent": "#83a598" },
        { "id": "nord", "name": "Nord", "desc": "Arctic blue-grey palette", "swatchBg": "#2e3440", "swatchAccent": "#88c0d0" },
        { "id": "tokyo-night", "name": "Tokyo Night", "desc": "Dark blues and violets", "swatchBg": "#1a1b26", "swatchAccent": "#7aa2f7" }
    ]
    property var clientsData: []
    property real dragHeadroom: 220
    property real maxDockWidth: 800
    property var iconCache: ({})
    property var execCache: ({})
    property var nameCache: ({})
    property var pendingLookups: ({})
    property var lookupQueue: []
    property bool lookupBusy: false
    property int activeWorkspaceId: -1

    property real menuHeight: {
        if (wallpaperMode)
            return 320;
        if (powerMode)
            return 200;
        if (blurMode)
            return 200;
        var rows = themeMode ? themesModel.count : (commandMode ? commandsModel.count : appLauncherModel.count);
        var unit = (themeMode || commandMode) ? 60 : 50;
        var listH = Math.min(rows * unit, menuMaxHeight - 86);
        return Math.max(126, listH + 86);

    }

    property var pinnedAppIds: {
        var ids = {};
        for (var i = 0; i < appListModel.count; i++) {
            var appId = appListModel.get(i).appId;
            if (appId !== "")
                ids[appId.toLowerCase()] = true;
        }
        return ids;
    }

    function queueLookup(cls) {
        var key = cls.toLowerCase();
        if (pendingLookups[key])
            return;
        var pending = dockWindow.pendingLookups;
        pending[key] = true;
        dockWindow.pendingLookups = pending;
        dockWindow.lookupQueue.push(cls);
        dockWindow.drainLookupQueue();
    }

    function currentWallpaperPath() {
        try {
            return currentWallFile.text().trim();
        } catch (e) {
            return "";
        }
    }

    function highlightMatch(name, q) {
        q = q.trim();
        if (q === "")
            return name;
        var idx = name.toLowerCase().indexOf(q.toLowerCase());
        if (idx === -1)
            return name;
        return name.substring(0, idx) + "<font color=\"#8ad0ee\">" + name.substring(idx, idx + q.length) + "</font>" + name.substring(idx + q.length);
    }

    function drainLookupQueue() {
        if (dockWindow.lookupBusy || dockWindow.lookupQueue.length === 0)
            return;
        dockWindow.lookupBusy = true;
        var cls = dockWindow.lookupQueue.shift();
        iconLookup.lookupClass(cls);
    }

    function syncModel(model, arr) {
        var wanted = {};
        for (var j = 0; j < arr.length; j++)
            wanted[arr[j].name] = true;

        for (var i = model.count - 1; i >= 0; i--) {
            if (!wanted[model.get(i).name])
                model.remove(i, 1);
        }

        for (var k = 0; k < arr.length; k++) {
            var existing = -1;
            for (var m = k; m < model.count; m++) {
                if (model.get(m).name === arr[k].name) {
                    existing = m;
                    break;
                }
            }
            if (existing === -1) {
                model.insert(k, arr[k]);
            } else {
                if (existing !== k)
                    model.move(existing, k, 1);
                model.set(k, arr[k]);
            }
        }
    }

    function matchScore(app, q) {
        var n = app.name.toLowerCase();
        if (n.indexOf(q) === 0)
            return 100;
        if (n.indexOf(q) !== -1)
            return 80;
        if (app.search.indexOf(q) !== -1)
            return 50;

        var i = 0;
        for (var c = 0; c < n.length && i < q.length; c++) {
            if (n.charAt(c) === q.charAt(i))
                i++;
        }
        return i === q.length ? 20 : -1;
    }

    function rebuildLauncherModel() {
        var counts = usageAdapter.counts || {};
        var q = dockWindow.searchQuery.toLowerCase().trim();
        // score/usage computed once per app up front, instead of inside the
        // sort comparator (which used to call matchScore twice per comparison)
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

        scored.sort(function (a, b) {
            if (a.score !== b.score)
                return b.score - a.score;
            if (a.uses !== b.uses)
                return b.uses - a.uses;
            return a.app.name.toLowerCase() < b.app.name.toLowerCase() ? -1 : 1;
        });

        dockWindow.syncModel(appLauncherModel, scored.map(function (s) {
            return s.app;
        }));
    }

    function rebuildCommandModel() {
        var q = dockWindow.searchQuery.substring(1).toLowerCase().trim();
        var arr = [];
        for (var i = 0; i < dockWindow.allCommands.length; i++) {
            var c = dockWindow.allCommands[i];
            if (q === "" || c.name.toLowerCase().indexOf(q) !== -1)
                arr.push(c);
        }
        dockWindow.syncModel(commandsModel, arr);
    }

    property var themeHasWallpaper: ({})

    function scanThemeWallpapers() {
        var home = Quickshell.env("HOME");
        var script = "";
        for (var i = 0; i < dockWindow.allThemes.length; i++) {
            var id = dockWindow.allThemes[i].id;
            if (id === "matugen")
                continue;
            script += "d=\"" + home + "/Pictures/wallpapers/" + id + "\"; " +
                "if [ -d \"$d\" ] && [ -n \"$(find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -print -quit)\" ]; " +
                "then echo \"" + id + ":1\"; else echo \"" + id + ":0\"; fi; ";
        }
        themeWallpaperScan.command = ["sh", "-c", script];
        themeWallpaperScan.running = true;
    }

    function rebuildThemeModel() {
        var q = dockWindow.searchQuery.substring(6).toLowerCase().trim();
        var arr = [];
        for (var i = 0; i < dockWindow.allThemes.length; i++) {
            var t = dockWindow.allThemes[i];
            if (q === "" || t.name.toLowerCase().indexOf(q) !== -1) {
                arr.push({
                    "id": t.id,
                    "name": t.name,
                    "desc": t.desc,
                    "swatchBg": t.swatchBg,
                    "swatchAccent": t.swatchAccent,
                    "disabled": t.id !== "matugen" && dockWindow.themeHasWallpaper[t.id] === false
                });
            }
        }
        themesModel.clear();
        for (var j = 0; j < arr.length; j++)
            themesModel.append(arr[j]);
    }

    function switchTheme(id) {
        var home = Quickshell.env("HOME");
        themeSwitchProbe.pendingId = id;
        themeSwitchProbe.command = ["sh", "-c",
            "d=\"" + home + "/Pictures/wallpapers/" + id + "\"; " +
            "[ -d \"$d\" ] && find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort | head -n1; true"];
        themeSwitchProbe.running = true;
        dockWindow.menuOpen = false;
    }

    function runPowerAction(id) {
        var cmds = {
            "lock": ["hyprlock"],
            "logout": ["uwsm", "stop"],
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

    function recordLaunch(name) {
        var counts = usageAdapter.counts || {};
        var key = name.toLowerCase();
        counts[key] = (counts[key] || 0) + 1;
        usageAdapter.counts = counts;
        dockWindow.rebuildLauncherModel();
    }

    function requestWallpaper(path) {
        if (!wallpaperArmed || path === "" || path === appliedWallpaper)
            return;
        pendingWallpaper = path;
        wallpaperDebounce.restart();
    }

    function applyWallpaper(path) {
        if (path === "")
            return;
        appliedWallpaper = path;
        wallpaperState.current = path;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper/set-wallpaper.sh", path]);
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

    function focusCommand(cls) {
        return "hyprctl eval 'local w=nil for i,win in pairs(hl.get_windows()) do if win.class==\"" + cls + "\" then w=win end end if w then hl.dispatch(hl.dsp.focus({window=w})) end'";
    }

    function pinRunningApp(cls) {
        pinLookup.pendingClass = cls;
        pinLookup.command = ["sh", "-c",
            "f=$(grep -li \"StartupWMClass=" + cls + "\" /usr/share/applications/*.desktop 2>/dev/null | head -n1); " +
            "[ -z \"$f\" ] && f=\"/usr/share/applications/" + cls + ".desktop\"; " +
            "if [ -f \"$f\" ]; then grep '^Exec=' \"$f\" | head -n1 | cut -d= -f2- | sed 's/ %[a-zA-Z]//g'; fi"];
        pinLookup.running = true;
    }

    function syncRunningApps() {
        var seen = {};
        var pinned = dockWindow.pinnedAppIds;

        for (var i = 0; i < clientsData.length; i++) {
            var c = clientsData[i];
            if (!c.class || c.class === "")
                continue;
            var cls = c.class;
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
            if (existingIdx === -1) {
                if (iconCache[key]) {
                    runningAppsModel.append({
                        "appKey": "running-" + key,
                        "iconName": iconCache[key],
                        "command": execCache[key] || dockWindow.focusCommand(cls),
                        "appId": cls,
                        "displayName": nameCache[key] || cls,
                        "justAdded": true
                    });
                } else {
                    dockWindow.queueLookup(cls);
                }
            }
        }

        for (var k = runningAppsModel.count - 1; k >= 0; k--) {
            var item = runningAppsModel.get(k);
            if (!seen[item.appId.toLowerCase()])
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
        for (var i = 0; i < clientsData.length; i++) {
            var c = clientsData[i];
            if (c.class && c.class.toLowerCase() === appId.toLowerCase()) {
                var ws = c.workspace.id;
                if (!groups[ws])
                    groups[ws] = [];
                groups[ws].push(c);
            }
        }
        var arr = [];
        for (var ws in groups) {
            arr.push({
                "workspaceId": parseInt(ws),
                "count": groups[ws].length,
                "address": groups[ws][0].address
            });
        }
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

    function unpinApp(appId) {
        for (var i = appListModel.count - 1; i >= 0; i--) {
            if (appListModel.get(i).appId.toLowerCase() === appId.toLowerCase()) {
                appListModel.remove(i, 1);
                break;
            }
        }
        dockWindow.persistOrder();
        dockWindow.syncRunningApps();
    }

    function closeAppWindows(appId, all) {
        var addrs = [];
        for (var i = 0; i < dockWindow.clientsData.length; i++) {
            var c = dockWindow.clientsData[i];
            if (c.class && c.class.toLowerCase() === appId.toLowerCase())
                addrs.push(c.address);
        }
        var targets = all ? addrs : addrs.slice(0, 1);
        for (var j = 0; j < targets.length; j++)
            Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + targets[j]]);
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
        interval: 5000
        running: true
        repeat: true

        onTriggered: {
            if (dockWindow.wallpaperMode)
                return;

            wallpaperWatch.command = ["sh", "-c",
                "d=\"$HOME/Pictures/wallpapers/" + dockWindow.currentTheme + "\"; " +
                "cur=\"$1\"; " +
                "if [ -n \"$cur\" ] && [ ! -f \"$cur\" ]; then echo MISSING; fi; " +
                "if [ -d \"$d\" ]; then " +
                "f=$(find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort | head -n1); " +
                "if [ -n \"$f\" ]; then echo \"FIRST:$f\"; fi; " +
                "fi; exit 0",
                "sh", dockWindow.appliedWallpaper];
            wallpaperWatch.running = true;
        }
    }
    margins.bottom: 0
    exclusiveZone: shell.implicitHeight + 20
    WlrLayershell.keyboardFocus: dockWindow.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: dockWindow.menuOpen ? WlrLayer.Overlay : WlrLayer.Top
    color: "transparent"
    implicitWidth: Math.max(maxDockWidth, menuWidth)
    implicitHeight: dockWindow.menuMaxHeight + dragHeadroom
    Component.onCompleted: {
        dockWindow.loadAppsFromDisk();
        dockWindow.appliedWallpaper = dockWindow.currentWallpaperPath();
        if (dockWindow.appliedWallpaper === "")
            dockWindow.applyWallpaper(dockWindow.fallbackWallpaper);
        appScanner.running = true;
    }
    onClientsDataChanged: syncRunningApps()
    onSearchQueryChanged: {
        // test the string directly, themeMode's binding may not have updated yet
        var q = dockWindow.searchQuery.toLowerCase();
        if (q.indexOf(">theme") === 0)
            rebuildThemeModel();
        else if (dockWindow.searchQuery.indexOf(">") === 0)
            rebuildCommandModel();
        else
            rebuildLauncherModel();
    }
    onWallpaperModeChanged: {
        if (wallpaperMode) {
            wallpaperScanner.running = true;
            wallpaperArmed = false;
            wallpaperArmTimer.restart();
        } else {
            wallpaperArmed = false;
        }
    }
    onThemeModeChanged: {
        if (themeMode) {
            rebuildThemeModel();
            scanThemeWallpapers();
        }
    }

    anchors {
        bottom: true
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            dockWindow.menuOpen = !dockWindow.menuOpen;
        }

        function open(): void {
            dockWindow.menuOpen = true;
        }

        function close(): void {
            dockWindow.menuOpen = false;
        }

        // if closed, prime initialSearchText so it survives the open-time reset
        function wallpaper(): void {
            if (dockWindow.menuOpen)
                launcherFace.searchText = ">wallpaper";
            else
                launcherFace.initialSearchText = ">wallpaper";
            dockWindow.menuOpen = true;
        }

        function theme(): void {
            if (dockWindow.menuOpen)
                launcherFace.searchText = ">theme";
            else
                launcherFace.initialSearchText = ">theme";
            dockWindow.menuOpen = true;
        }

        function power(): void {
            if (dockWindow.menuOpen)
                launcherFace.searchText = ">power";
            else
                launcherFace.initialSearchText = ">power";
            dockWindow.menuOpen = true;
        }

        function blur(): void {
            if (dockWindow.menuOpen)
                launcherFace.searchText = ">blur";
            else
                launcherFace.initialSearchText = ">blur";
            dockWindow.menuOpen = true;
        }

        function command(): void {
            if (dockWindow.menuOpen)
                launcherFace.searchText = ">";
            else
                launcherFace.initialSearchText = ">";
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
        onTriggered: armed = true
        onRunningChanged: {
            if (!running)
                armed = false;
        }
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

    Process {
        id: hyprctlClients

        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    dockWindow.clientsData = JSON.parse(text);
                } catch (e) {
                    console.warn("hyprctl clients parse failed:", e);
                }
            }
        }
    }

    Process {
        id: activeWorkspaceProc

        command: ["hyprctl", "activeworkspace", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var ws = JSON.parse(text);
                    dockWindow.activeWorkspaceId = ws.id;
                } catch (e) {
                    console.warn("activeworkspace parse failed:", e);
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            hyprctlClients.running = true;
            activeWorkspaceProc.running = true;
        }
    }

    // no directory-watching available here (FileView only watches single
    // files) so newly (un)installed .desktop entries are picked up by
    // periodically re-running the same scan appScanner does at startup -
    // syncModel below only touches rows that actually changed, so this is
    // cheap even though it reruns every cycle
    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: appScanner.running = true
    }

    FileView {
        id: currentWallFile

        path: Quickshell.env("HOME") + "/.cache/current_wallpaper"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
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

    ListModel {
        id: appListModel
    }

    ListModel {
        id: runningAppsModel
    }

    ListModel {
        id: appLauncherModel
    }

    ListModel {
        id: commandsModel
    }

    ListModel {
        id: wallpapersModel
    }

    ListModel {
        id: themesModel
    }

    Process {
        id: wallpaperApply

        onExited: (code) => {
            if (code !== 0)
                console.warn("wallpaper apply script exited with code", code);
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.log("WALLPAPER_ERR:", text);
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
        id: themeSwitchProbe

        property string pendingId: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var id = themeSwitchProbe.pendingId;
                var wallpaper = text.trim();
                // fall back if Matugen's folder ever gets emptied out
                if (wallpaper === "" && id === "matugen")
                    wallpaper = dockWindow.fallbackWallpaper;
                // folder changed out from under us, just no-op
                if (wallpaper === "")
                    return;

                var home = Quickshell.env("HOME");
                if (id === "matugen") {
                    // no apply-theme.sh - set-wallpaper.sh regenerates colors itself
                    Quickshell.execDetached(["sh", "-c", "echo matugen > " + home + "/.cache/current_theme"]);
                } else {
                    Quickshell.execDetached(["sh", "-c",
                        "echo " + id + " > " + home + "/.cache/current_theme && " +
                        home + "/.config/lucid/apply-theme.sh " + id]);
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
                dockWindow.rebuildThemeModel();
            }
        }
    }

    Process {
        id: wallpaperScanner

        command: ["sh", "-c",
            "d=\"$HOME/Pictures/wallpapers/" + dockWindow.currentTheme + "\"; " +
            "[ -d \"$d\" ] || exit 0; " +
            "find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]

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
                if (wallpapersModel.count === 0) {           // ← here
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
        id: appScanner

        command: ["sh", "-c",
            "for d in /usr/share/applications ~/.local/share/applications " +
            "/var/lib/flatpak/exports/share/applications ~/.local/share/flatpak/exports/share/applications " +
            "/var/lib/snapd/desktop/applications; do " +
            "[ -d \"$d\" ] || continue; " +
            "for f in \"$d\"/*.desktop; do " +
            "[ -f \"$f\" ] || continue; " +
            "grep -q '^NoDisplay=true' \"$f\" && continue; " +
            "grep -q '^Hidden=true' \"$f\" && continue; " +
            "t=$(grep -m1 '^Type=' \"$f\" | cut -d= -f2); " +
            "[ -n \"$t\" ] && [ \"$t\" != \"Application\" ] && continue; " +
            "n=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "[ -z \"$n\" ] && continue; " +
            "i=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
            "k=$(grep -m1 '^Keywords=' \"$f\" | cut -d= -f2- | tr ';' ' '); " +
            "g=$(grep -m1 '^GenericName=' \"$f\" | cut -d= -f2-); " +
            "c=$(grep -m1 '^Comment=' \"$f\" | cut -d= -f2-); " +
            "b=$(basename \"$f\" .desktop); " +
            "e=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[a-zA-Z]//g'); " +
            "[ -z \"$e\" ] && continue; " +
            "echo \"$n|$i|$k $g $c $b|$e\"; " +
            "done; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var seen = {};
                var arr = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (line.trim() === "")
                        continue;
                    var parts = line.split("|");
                    if (parts.length < 4)
                        continue;
                    var name = parts[0];
                    var key = name.toLowerCase();
                    if (seen[key])
                        continue;
                    seen[key] = true;
                    arr.push({
                        "name": name,
                        "iconName": parts[1],
                        "search": (name + " " + parts[2]).toLowerCase(),
                        "command": parts.slice(3).join("|")
                    });
                }
                dockWindow.scannedApps = arr;
                dockWindow.rebuildLauncherModel();
            }
        }
    }

    Process {
        id: pinLookup

        property string pendingClass: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var cls = pinLookup.pendingClass;
                var cmd = text.trim();
                if (cmd === "")
                    return;

                var icon = dockWindow.iconCache[cls.toLowerCase()] || cls;

                appListModel.append({
                    "appKey": "pinned-" + cls.toLowerCase() + "-" + Date.now(),
                    "iconName": icon,
                    "command": cmd,
                    "appId": cls,
                    "displayName": dockWindow.nameCache[cls.toLowerCase()] || cls,
                    "justAdded": true
                });
                dockWindow.persistOrder();

                for (var k = runningAppsModel.count - 1; k >= 0; k--) {
                    if (runningAppsModel.get(k).appId === cls) {
                        runningAppsModel.remove(k, 1);
                        break;
                    }
                }
            }
        }
    }

    Process {
        id: iconLookup

        property string pendingClass: ""

        function lookupClass(cls) {
            iconLookup.pendingClass = cls;
            iconLookup.command = ["sh", "-c",
                "f=$(grep -li \"StartupWMClass=" + cls + "\" /usr/share/applications/*.desktop 2>/dev/null | head -n1); " +
                "[ -z \"$f\" ] && f=\"/usr/share/applications/" + cls + ".desktop\"; " +
                "if [ -f \"$f\" ]; then grep '^Icon=' \"$f\" | head -n1 | cut -d= -f2; grep '^Exec=' \"$f\" | head -n1 | cut -d= -f2- | sed 's/ %[a-zA-Z]//g'; grep '^Name=' \"$f\" | head -n1 | cut -d= -f2; else echo '" + cls + "'; echo ''; echo '" + cls + "'; fi"];
            iconLookup.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var cls = iconLookup.pendingClass;
                var icon = (lines[0] || "").trim();
                var exec = (lines[1] || "").trim();
                var name = (lines[2] || "").trim();
                if (icon === "")
                    icon = cls;
                if (name === "")
                    name = cls;

                var cache = dockWindow.iconCache;
                cache[cls.toLowerCase()] = icon;
                dockWindow.iconCache = cache;

                var execC = dockWindow.execCache;
                execC[cls.toLowerCase()] = exec !== "" ? exec : dockWindow.focusCommand(cls);
                dockWindow.execCache = execC;

                var nameC = dockWindow.nameCache;
                nameC[cls.toLowerCase()] = name;
                dockWindow.nameCache = nameC;

                var pending = dockWindow.pendingLookups;
                delete pending[cls.toLowerCase()];
                dockWindow.pendingLookups = pending;

                dockWindow.lookupBusy = false;
                dockWindow.syncRunningApps();
                dockWindow.drainLookupQueue();
            }
        }
    }

    Rectangle {
        id: shell

        property int pendingDropIndex: -1
        property bool dropActive: false
        property bool shellReady: false

        clip: dockWindow.menuOpen || dockWindow.morphing
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: row.implicitWidth + 20
        implicitHeight: 62
        width: dockWindow.menuOpen ? dockWindow.menuWidth : implicitWidth
        height: dockWindow.menuOpen ? dockWindow.menuHeight : implicitHeight
        radius: dockWindow.menuOpen ? 22 : 18
        color: Theme.bg
        Component.onCompleted: readyTimer.start()

        Behavior on width {
            enabled: shell.shellReady
            NumberAnimation {
                duration: dockWindow.morphing ? 400 : 60
                easing.type: dockWindow.morphing ? Easing.BezierSpline : Easing.OutCubic
                easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
            }
        }

        Behavior on height {
            enabled: shell.shellReady
            NumberAnimation {
                duration: dockWindow.morphing ? 400 : 60
                easing.type: dockWindow.morphing ? Easing.BezierSpline : Easing.OutCubic
                easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
            }
        }

        Behavior on radius {
            enabled: shell.shellReady
            NumberAnimation {
                duration: dockWindow.morphing ? 400 : 60
                easing.type: dockWindow.morphing ? Easing.BezierSpline : Easing.OutCubic
                easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
            }
        }

        Timer {
            id: readyTimer

            interval: 50
            onTriggered: shell.shellReady = true
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]

            onEntered: shell.dropActive = true
            onExited: {
                shell.dropActive = false;
                shell.pendingDropIndex = -1;
            }

            onPositionChanged: (drag) => {
                var mapped = dragArea.mapFromItem(shell, drag.x, drag.y);
                var candidate = Math.round(mapped.x / 56);
                candidate = Math.max(0, Math.min(appListModel.count, candidate));
                shell.pendingDropIndex = candidate;
            }

            onDropped: (drop) => {
                if (drop.urls.length === 0) {
                    shell.dropActive = false;
                    shell.pendingDropIndex = -1;
                    return;
                }
                var url = drop.urls[0].toString();
                var path = url.replace("file://", "");
                pathTypeChecker.insertIndex = shell.pendingDropIndex;
                pathTypeChecker.checkPath(path);
                shell.dropActive = false;
                shell.pendingDropIndex = -1;
            }
        }

        Item {
            id: dockFace

            width: shell.implicitWidth
            height: shell.implicitHeight
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            opacity: dockWindow.menuOpen ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            Row {
                id: row

                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                DockItem {
                    svgPath: "M12 2c-5.33 4.55-8 8.48-8 11.8 0 4.98 3.8 8.2 8 8.2s8-3.22 8-8.2c0-3.32-2.67-7.25-8-11.8zm0 18c-3.35 0-6-2.57-6-6.2 0-2.34 1.95-5.44 6-9.14 4.05 3.7 6 6.79 6 9.14 0 3.63-2.65 6.2-6 6.2zm-4.17-6c.37 0 .67.26.74.62.41 2.22 2.28 2.98 3.64 2.87.43-.02.79.32.79.75 0 .4-.32.73-.72.75-2.13.13-4.62-1.09-5.19-4.12a.75.75 0 0 1 .74-.87z"
                    displayName: "Launcher"
                    isToggle: true
                    onRequestToggle: dockWindow.menuOpen = !dockWindow.menuOpen
                }

                Rectangle {
                    width: 1
                    height: 26
                    color: Theme.alpha(Theme.text, 0.25)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: dragArea

                    property int previewCount: repeater.count + (shell.dropActive ? 1 : 0)
                    // which slot the pointer is over, for the magnify-ripple
                    // effect on neighboring icons - macOS-dock-style hover feel
                    property int hoveredSlot: rowHover.hovered ? Math.max(0, Math.min(repeater.count - 1, Math.floor(rowHover.point.position.x / 56))) : -1

                    width: previewCount * 46 + (previewCount - 1) * 10
                    height: 46

                    HoverHandler {
                        id: rowHover
                    }

                    Behavior on width {
                        enabled: shell.shellReady
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        id: repeater

                        model: appListModel

                        delegate: Item {
                            id: slot

                            property real dragOffsetY: 0

                            required property string appKey
                            required property string iconName
                            required property string command
                            required property string appId
                            required property string displayName
                            required property bool justAdded
                            required property int index

                            property real targetX: {
                                var base = index;
                                if (shell.dropActive && shell.pendingDropIndex >= 0 && index >= shell.pendingDropIndex)
                                    base += 1;
                                return base * 56;
                            }
                            property real removeThreshold: 40
                            property real removeThresholdDown: 15
                            property bool overRemoveThreshold: dragHandler.active &&
                                (slot.y < 0 ? (-slot.y > slot.removeThreshold) : (slot.y > slot.removeThresholdDown))
                            property real neighborBoost: {
                                if (dragHandler.active || dragArea.hoveredSlot < 0)
                                    return 0;
                                var dist = Math.abs(slot.index - dragArea.hoveredSlot);
                                if (dist === 1)
                                    return 0.06;
                                if (dist === 2)
                                    return 0.025;
                                return 0;
                            }

                            width: 46
                            height: 46
                            scale: justAdded ? 0 : (slot.overRemoveThreshold ? 0.7 : 1)
                            opacity: justAdded ? 0 : (slot.overRemoveThreshold ? 0.35 : 1)
                            z: dragHandler.active ? 10 : 1

                            Component.onCompleted: {
                                if (slot.justAdded)
                                    entranceAnim.start();
                            }

                            onXChanged: {
                                if (!dragHandler.active)
                                    return;

                                var myCenter = slot.x + slot.width / 2;
                                var candidate = Math.round(myCenter / 56);
                                candidate = Math.max(0, Math.min(repeater.count - 1, candidate));
                                if (candidate !== slot.index)
                                    appListModel.move(slot.index, candidate, 1);
                            }

                            onYChanged: {
                                if (dragHandler.active)
                                    slot.dragOffsetY = slot.y;
                            }

                            ParallelAnimation {
                                id: entranceAnim

                                NumberAnimation {
                                    target: slot
                                    property: "scale"
                                    to: 1
                                    duration: 320
                                    easing.type: Easing.OutBack
                                }

                                NumberAnimation {
                                    target: slot
                                    property: "opacity"
                                    to: 1
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }

                            ParallelAnimation {
                                id: removeAnim

                                onFinished: {
                                    var removeIdx = slot.index;
                                    var arr = [];
                                    for (var i = 0; i < appListModel.count; i++) {
                                        if (i === removeIdx)
                                            continue;
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
                                    appListModel.remove(removeIdx, 1);
                                }

                                NumberAnimation {
                                    target: slot
                                    property: "scale"
                                    to: 0
                                    duration: 180
                                    easing.type: Easing.InCubic
                                }

                                NumberAnimation {
                                    target: slot
                                    property: "opacity"
                                    to: 0
                                    duration: 180
                                    easing.type: Easing.InCubic
                                }
                            }

                            Binding {
                                target: slot
                                property: "x"
                                value: slot.targetX
                                when: !dragHandler.active
                            }

                            Binding {
                                target: slot
                                property: "y"
                                value: 0
                                when: !dragHandler.active
                            }

                            DockItem {
                                id: pinnedItemView

                                iconName: slot.iconName
                                command: slot.command
                                appId: slot.appId
                                displayName: slot.displayName
                                clients: dockWindow.clientsData
                                activeWorkspaceId: dockWindow.activeWorkspaceId
                                magnifyBoost: slot.neighborBoost
                                onRequestStackPopup: dockWindow.openStackPopup(pinnedItemView, slot.appId, slot.iconName, slot.command)
                                onRequestContextMenu: dockWindow.openContextMenu(pinnedItemView, slot.appId, true, slot.command)
                                onLaunched: dockWindow.recordLaunch(slot.displayName)
                            }

                            DragHandler {
                                id: dragHandler

                                target: slot
                                yAxis.enabled: true
                                yAxis.minimum: -200
                                yAxis.maximum: 20
                                xAxis.minimum: 0
                                xAxis.maximum: (repeater.count - 1) * 56

                               onActiveChanged: {
                                    dockWindow.dragging = active;
                                    if (active) {
                                        slot.dragOffsetY = 0;
                                        return;
                                    }
                                    var threshold = slot.dragOffsetY < 0 ? slot.removeThreshold : slot.removeThresholdDown;
                                    if (Math.abs(slot.dragOffsetY) > threshold)
                                        removeAnim.start();
                                    else
                                        dockWindow.persistOrder();
                                }
                            }

                            Behavior on x {
                                enabled: !dragHandler.active
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on y {
                                enabled: !dragHandler.active
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    // shows exactly where a dropped file/folder will land,
                    // instead of only implying it via the other icons shifting
                    Rectangle {
                        id: dropPlaceholder

                        width: 46
                        height: 46
                        radius: 9
                        color: Theme.alpha(Theme.accent, 0.15)
                        visible: shell.dropActive && shell.pendingDropIndex >= 0
                        x: Math.max(0, Math.min(shell.pendingDropIndex, repeater.count)) * 56
                        z: 5

                        Behavior on x {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }

                    }
                }

                Item {
                    id: runningSeparatorWrap

                    width: runningAppsModel.count > 0 ? 11 : 0
                    height: 46
                    clip: true

                    Behavior on width {
                        enabled: shell.shellReady
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 26
                        color: Theme.alpha(Theme.text, 0.25)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    id: runningArea

                    property int hoveredSlot: runRowHover.hovered ? Math.max(0, Math.min(runningAppsModel.count - 1, Math.floor(runRowHover.point.position.x / 56))) : -1

                    width: runningAppsModel.count > 0 ? runningAppsModel.count * 56 - 10 : 0
                    height: 46

                    HoverHandler {
                        id: runRowHover
                    }

                    Behavior on width {
                        enabled: shell.shellReady
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        model: runningAppsModel

                        delegate: Item {
                            id: runSlot

                            required property string iconName
                            required property string command
                            required property string appId
                            required property string displayName
                            required property int index

                            property real targetX: index * 56
                            property real pinThreshold: -40
                            property bool overPinThreshold: runDragHandler.active && (runSlot.x - runSlot.targetX) < runSlot.pinThreshold
                            property real neighborBoost: {
                                if (runDragHandler.active || runningArea.hoveredSlot < 0)
                                    return 0;
                                var dist = Math.abs(runSlot.index - runningArea.hoveredSlot);
                                if (dist === 1)
                                    return 0.06;
                                if (dist === 2)
                                    return 0.025;
                                return 0;
                            }

                            width: 46
                            height: 46
                            scale: runSlot.overPinThreshold ? 1.12 : 1
                            z: runDragHandler.active ? 10 : 1

                            Binding {
                                target: runSlot
                                property: "x"
                                value: runSlot.targetX
                                when: !runDragHandler.active
                            }

                            DockItem {
                                id: runningItemView

                                iconName: runSlot.iconName
                                command: runSlot.command
                                appId: runSlot.appId
                                displayName: runSlot.displayName
                                clients: dockWindow.clientsData
                                activeWorkspaceId: dockWindow.activeWorkspaceId
                                magnifyBoost: runSlot.neighborBoost
                                onRequestStackPopup: dockWindow.openStackPopup(runningItemView, runSlot.appId, runSlot.iconName, runSlot.command)
                                onRequestContextMenu: dockWindow.openContextMenu(runningItemView, runSlot.appId, false, runSlot.command)
                                onLaunched: dockWindow.recordLaunch(runSlot.displayName)
                            }

                            // small accent dot that appears once the drag has
                            // crossed the pin threshold, mirroring the pinned
                            // row's shrink-to-remove feedback so both drag
                            // gestures give a clear "release here" signal
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: Theme.accent
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: -14
                                opacity: runSlot.overPinThreshold ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }
                            }

                            DragHandler {
                                id: runDragHandler

                                target: runSlot
                                yAxis.enabled: false
                                xAxis.minimum: runSlot.targetX - 300
                                xAxis.maximum: runSlot.targetX + 40

                                onActiveChanged: {
                                    if (!active && runSlot.overPinThreshold)
                                        dockWindow.pinRunningApp(runSlot.appId);
                                }
                            }

                            Behavior on x {
                                enabled: !runDragHandler.active
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }

        LauncherFace {
            id: launcherFace

            width: dockWindow.menuWidth - 36
            height: dockWindow.menuHeight - 36
            targetWidth: dockWindow.menuWidth - 36
            targetHeight: dockWindow.menuHeight - 36
            anchors.centerIn: parent
            opacity: dockWindow.menuOpen ? 1 : 0
            visible: opacity > 0
            model: dockWindow.themeMode ? themesModel : (dockWindow.commandMode ? commandsModel : appLauncherModel)

            // mirrors the shell Rectangle's own Behaviors so content and
            // frame grow/shrink together instead of content snapping ahead
            Behavior on width {
                enabled: shell.shellReady
                NumberAnimation {
                    duration: dockWindow.morphing ? 400 : 60
                    easing.type: dockWindow.morphing ? Easing.BezierSpline : Easing.OutCubic
                    easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
                }
            }

            Behavior on height {
                enabled: shell.shellReady
                NumberAnimation {
                    duration: dockWindow.morphing ? 400 : 60
                    easing.type: dockWindow.morphing ? Easing.BezierSpline : Easing.OutCubic
                    easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
                }
            }
            commandMode: dockWindow.commandMode
            themeMode: dockWindow.themeMode
            activeThemeId: dockWindow.currentTheme
            wallpaperMode: dockWindow.wallpaperMode
            wallpaperModel: wallpapersModel
            powerMode: dockWindow.powerMode
            blurMode: dockWindow.blurMode
            onAppLaunched: (name) => {
                dockWindow.recordLaunch(name);
                dockWindow.menuOpen = false;
            }

            onWallpaperPreviewed: (path) => dockWindow.requestWallpaper(path)
            onWallpaperChosen: (path) => {
                dockWindow.applyWallpaper(path);
                dockWindow.menuOpen = false;
            }
            onThemeChosen: (id) => dockWindow.switchTheme(id)
            onCommandActivated: (id) => {
                if (id === "wallpaper")
                    launcherFace.searchText = ">wallpaper";
                else if (id === "theme") {
                    launcherFace.searchText = ">theme";
                    dockWindow.rebuildThemeModel();
                    dockWindow.scanThemeWallpapers();
                } else if (id === "power")
                    launcherFace.searchText = ">power";
                else if (id === "blur")
                    launcherFace.searchText = ">blur";
            }

            onPowerActionChosen: (id) => dockWindow.runPowerAction(id)
            onBlurLevelChosen: (v) => Theme.setBlurAmount(v)

            onCloseRequested: dockWindow.menuOpen = false

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: dockWindow.menuOpen ? 150 : 0
                    }

                    NumberAnimation {
                        duration: 200
                    }
                }
            }
        }

        Process {
            id: pathTypeChecker

            property string pendingPath: ""
            property int insertIndex: -1

            function checkPath(path) {
                pathTypeChecker.pendingPath = path;
                pathTypeChecker.command = ["sh", "-c", "if [ -d '" + path + "' ]; then echo DIR; echo folder; " + "else echo FILE; " + "candidates=$(gio info -a standard::icon '" + path + "' 2>/dev/null | grep 'standard::icon:' | sed 's/.*standard::icon: //' | tr ',' '\\n' | sed 's/^ *//;s/ *$//' | grep -v -- '-symbolic$'); " + "found=''; " + "for c in $candidates; do " + "hit=$(find ~/.local/share/icons /usr/share/icons -iname \"$c.*\" 2>/dev/null | head -n1); " + "if [ -n \"$hit\" ]; then found=\"$c\"; break; fi; " + "done; " + "if [ -z \"$found\" ]; then " + "for c in $candidates; do " + "xvariant=$(echo \"$c\" | sed 's/^\\([a-z]*\\)-/\\1-x-/'); " + "hit=$(find ~/.local/share/icons /usr/share/icons -iname \"$xvariant.*\" 2>/dev/null | head -n1); " + "if [ -n \"$hit\" ]; then found=\"$xvariant\"; break; fi; " + "done; " + "fi; " + "echo \"$found\"; fi"];
                pathTypeChecker.running = true;
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = text.trim().split("\n");
                    var isDir = lines[0] === "DIR";
                    var gioIcon = lines.length > 1 ? lines[1].trim() : "";
                    var iconName = gioIcon !== "" ? gioIcon : (isDir ? "folder" : "text-x-generic");
                    var path = pathTypeChecker.pendingPath;
                    var name = path.substring(path.lastIndexOf("/") + 1);
                    var idx = pathTypeChecker.insertIndex;
                    if (idx < 0 || idx > appListModel.count)
                        idx = appListModel.count;

                    appListModel.insert(idx, {
                        "appKey": "dropped-" + Date.now(),
                        "iconName": iconName,
                        "command": isDir ? ("nautilus --new-window \"" + path + "\"") : ("xdg-open \"" + path + "\""),
                        "appId": "",
                        "displayName": name,
                        "justAdded": true
                    });

                    dockWindow.persistOrder();
                }
            }
        }
    }

    mask: Region {
        x: dockWindow.dragging ? 0 : shell.x
        y: dockWindow.dragging ? 0 : shell.y
        width: dockWindow.dragging ? dockWindow.width : shell.width
        height: dockWindow.dragging ? dockWindow.height : shell.height
    }

    // real compositor blur, scoped to just the dock pill - see the matching
    // note on bar in shell.qml.
    BackgroundEffect.blurRegion: Theme.blurAmount > 0 ? dockBlurRegion : null

    Region {
        id: dockBlurRegion

        item: shell
        radius: shell.radius
    }

}
