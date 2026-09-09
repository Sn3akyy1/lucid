import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property bool loaded: false


    property bool debugRegions: false

    IpcHandler {
        target: "debug"

        function toggle(): void {
            root.debugRegions = !root.debugRegions;
        }

        function on(): void {
            root.debugRegions = true;
        }

        function off(): void {
            root.debugRegions = false;
        }

    }

    readonly property bool barNotch: root.barStyle === "notch"
    readonly property bool dockNotch: root.dockStyle === "notch"
    readonly property int barPillRadius: Math.min(18, Math.round(root.barHeight / 2))
    readonly property int effectiveBarTopMargin: root.barNotch ? 0 : root.barTopMargin
    readonly property int effectiveDockBottomMargin: root.dockNotch ? 0 : root.dockBottomMargin
    readonly property bool anyBarModuleEnabled: root.showWorkspaces || root.showMedia || root.showTray || root.showClock || root.showNotifications || root.showSystem
    readonly property var barModuleKeys: ["showWorkspaces", "showMedia", "showTray", "showClock", "showNotifications", "showSystem"]
    readonly property var widgetKeys: ["widgetsEnabled", "widgetSnap", "widgetLockAll", "widgetHideFullscreen", "widgetOnTop"]
    readonly property var idleKeys: ["idleDim", "idleDimAfter", "idleDimLevel", "idleDimKeyboard", "idleLock", "idleLockAfter", "idleScreenOff", "idleScreenOffAfter", "idleSuspend", "idleSuspendAfter", "idleSuspendOnAc", "idleLockBeforeSleep", "idleWakeAfterSleep", "idleRespectInhibitors", "idleWhileMedia"]
    readonly property var notifKeys: ["toastEnabled", "toastTimeout", "toastUseAppTimeout", "toastCriticalSticky", "toastShowBody", "toastShowActions", "toastBodyLines", "notifShowIcons", "notifMaxHistory", "doNotDisturb", "dndAllowCritical", "dndFullscreen", "quietHours", "quietFrom", "quietTo", "notifSound", "notifSoundName", "notifSoundVolume", "notifSoundUrgentOnly", "notifMutedApps"]

    property alias barStyle: s.barStyle
    property alias dockStyle: s.dockStyle
    property alias accentPunch: s.accentPunch
    property alias surfaceDarkness: s.surfaceDarkness
    property alias motionScale: s.motionScale
    property alias fontFamily: s.fontFamily
    property alias fontScale: s.fontScale
    property alias wallpaperFolder: s.wallpaperFolder
    // bracket writes on the adapter are dropped, so this must go through the alias
    property alias themeOrder: s.themeOrder
    property string currentTheme: "matugen"
    readonly property string wallpaperDir: root.wallpaperDirFor(root.currentTheme)

    property alias barEnabled: s.barEnabled
    property alias barPopupMode: s.barPopupMode
    property alias barPopupGap: s.barPopupGap
    property alias barHeight: s.barHeight
    property alias barTopMargin: s.barTopMargin
    property alias barSideMargin: s.barSideMargin
    property alias barSpacing: s.barSpacing
    property alias barHoverGrow: s.barHoverGrow
    property alias showWorkspaces: s.showWorkspaces
    property alias showMedia: s.showMedia
    property alias showTray: s.showTray
    property alias showClock: s.showClock
    property alias showNotifications: s.showNotifications
    property alias showSystem: s.showSystem
    property alias clock24h: s.clock24h
    property alias clockShowDate: s.clockShowDate
    property alias gpsEnabled: s.gpsEnabled
    property alias locationName: s.locationName
    property alias locationLabel: s.locationLabel
    property alias locationLat: s.locationLat
    property alias locationLon: s.locationLon
    property alias locationTz: s.locationTz
    property alias timeZoneAuto: s.timeZoneAuto
    property alias doNotDisturb: s.doNotDisturb
    property alias toastTimeout: s.toastTimeout
    property alias toastEnabled: s.toastEnabled
    property alias toastUseAppTimeout: s.toastUseAppTimeout
    property alias toastCriticalSticky: s.toastCriticalSticky
    property alias toastShowBody: s.toastShowBody
    property alias toastShowActions: s.toastShowActions
    property alias toastBodyLines: s.toastBodyLines
    property alias notifShowIcons: s.notifShowIcons
    property alias notifMaxHistory: s.notifMaxHistory
    property alias dndAllowCritical: s.dndAllowCritical
    property alias dndFullscreen: s.dndFullscreen
    property alias quietHours: s.quietHours
    property alias quietFrom: s.quietFrom
    property alias quietTo: s.quietTo
    property alias notifSound: s.notifSound
    property alias notifSoundName: s.notifSoundName
    property alias notifSoundVolume: s.notifSoundVolume
    property alias notifSoundUrgentOnly: s.notifSoundUrgentOnly
    // comma-joined; bracket writes on the adapter are dropped, so both go through the alias
    property alias notifMutedApps: s.notifMutedApps
    property alias notifSeenApps: s.notifSeenApps

    property alias dockEnabled: s.dockEnabled
    property alias dockIconSize: s.dockIconSize
    property alias dockSpacing: s.dockSpacing
    property alias dockBottomMargin: s.dockBottomMargin
    property alias dockMagnify: s.dockMagnify
    property alias dockHoverEffect: s.dockHoverEffect
    property alias barMotionScale: s.barMotionScale
    property alias barNotchFlare: s.barNotchFlare
    property alias dockNotchFlare: s.dockNotchFlare
    property alias dockAutoHide: s.dockAutoHide
    property alias dockShowIndicators: s.dockShowIndicators
    property alias dockShowTooltips: s.dockShowTooltips
    property alias dockShowRunning: s.dockShowRunning
    property alias dockIconTiles: s.dockIconTiles

    property alias widgetsEnabled: s.widgetsEnabled
    property alias widgetSnap: s.widgetSnap
    property alias widgetLockAll: s.widgetLockAll
    property alias widgetHideFullscreen: s.widgetHideFullscreen
    property alias widgetOnTop: s.widgetOnTop

    property alias btScanOnOpen: s.btScanOnOpen
    property alias btShowUnnamed: s.btShowUnnamed
    property alias kdeConnectEnabled: s.kdeConnectEnabled

    property alias idleEnabled: s.idleEnabled
    property alias idleAutostart: s.idleAutostart
    property alias idleKeepAwake: s.idleKeepAwake
    // one-shot: the hand-written hypridle.conf is read into these keys once
    property alias idleAdopted: s.idleAdopted
    property alias idleDim: s.idleDim
    property alias idleDimAfter: s.idleDimAfter
    property alias idleDimLevel: s.idleDimLevel
    property alias idleDimKeyboard: s.idleDimKeyboard
    property alias idleLock: s.idleLock
    property alias idleLockAfter: s.idleLockAfter
    property alias idleScreenOff: s.idleScreenOff
    property alias idleScreenOffAfter: s.idleScreenOffAfter
    property alias idleSuspend: s.idleSuspend
    property alias idleSuspendAfter: s.idleSuspendAfter
    property alias idleSuspendOnAc: s.idleSuspendOnAc
    property alias idleLockBeforeSleep: s.idleLockBeforeSleep
    property alias idleWakeAfterSleep: s.idleWakeAfterSleep
    property alias idleRespectInhibitors: s.idleRespectInhibitors
    property alias idleWhileMedia: s.idleWhileMedia

    property alias desktopSelection: s.desktopSelection
    property alias desktopMenu: s.desktopMenu

    readonly property var builtinThemes: [
        { "id": "matugen", "name": "Matugen", "desc": "Colors generated from your wallpaper", "swatchBg": "#12171a", "swatchAccent": "#8ad0ee" },
        { "id": "pywal", "name": "Pywal", "desc": "Wallpaper colors via pywal's classic palette", "swatchBg": "#1a1e24", "swatchAccent": "#c9a1a9" },
        { "id": "catppuccin-mocha", "name": "Catppuccin Mocha", "desc": "Soothing pastel dark theme", "swatchBg": "#1e1e2e", "swatchAccent": "#89b4fa" },
        { "id": "gruvbox", "name": "Gruvbox", "desc": "Retro groove warm palette", "swatchBg": "#282828", "swatchAccent": "#83a598" },
        { "id": "nightfox", "name": "Nightfox", "desc": "Deep navy with muted blue accents", "swatchBg": "#192330", "swatchAccent": "#719cd6" },
        { "id": "nord", "name": "Nord", "desc": "Arctic blue-grey palette", "swatchBg": "#232831", "swatchAccent": "#88c0d0" },
        { "id": "tokyo-night", "name": "Tokyo Night", "desc": "Dark blues and violets", "swatchBg": "#1a1b26", "swatchAccent": "#7aa2f7" }
    ]
    // themes imported from a scheme repo, read back from their meta.json
    property var userThemes: []
    // the order the user dragged them into; anything it does not name keeps its
    // natural place at the end, so a freshly imported theme still shows up
    readonly property var themeCatalogue: {
        var all = root.builtinThemes.concat(root.userThemes);
        var order = root.themeOrder.split(",").filter((x) => {
            return x !== "";
        });
        if (order.length === 0)
            return all;

        var left = {};
        for (var i = 0; i < all.length; i++) left[all[i].id] = all[i];
        var out = [];
        for (var j = 0; j < order.length; j++) {
            if (left[order[j]]) {
                out.push(left[order[j]]);
                delete left[order[j]];
            }
        }
        for (var k = 0; k < all.length; k++) {
            if (left[all[k].id])
                out.push(all[k]);

        }
        return out;
    }

    function setThemeOrder(ids) {
        root.themeOrder = ids.join(",");
    }

    readonly property var defaults: ({
        "barStyle": "island",
        "dockStyle": "island",
        "accentPunch": 1,
        "surfaceDarkness": -1,
        "motionScale": 1,
        "fontFamily": "Google Sans",
        "fontScale": 1,
        "wallpaperFolder": "",
        "themeOrder": "",
        "barEnabled": true,
        "barPopupMode": false,
        "barPopupGap": 10,
        "barHeight": 35,
        "barTopMargin": 22,
        "barSideMargin": 17,
        "barSpacing": 8,
        "barHoverGrow": 3,
        "showWorkspaces": true,
        "showMedia": true,
        "showTray": true,
        "showClock": true,
        "showNotifications": true,
        "showSystem": true,
        "clock24h": false,
        "clockShowDate": true,
        "gpsEnabled": false,
        "locationName": "",
        "locationLabel": "",
        "locationLat": 52.4083,
        "locationLon": 16.9336,
        "locationTz": "",
        "timeZoneAuto": true,
        "doNotDisturb": false,
        "toastTimeout": 5,
        "toastEnabled": true,
        "toastUseAppTimeout": true,
        "toastCriticalSticky": true,
        "toastShowBody": true,
        "toastShowActions": true,
        "toastBodyLines": 4,
        "notifShowIcons": true,
        "notifMaxHistory": 50,
        "dndAllowCritical": true,
        "dndFullscreen": false,
        "quietHours": false,
        "quietFrom": 1320,
        "quietTo": 420,
        "notifSound": false,
        "notifSoundName": "message",
        "notifSoundVolume": 0.6,
        "notifSoundUrgentOnly": false,
        "notifMutedApps": "",
        "notifSeenApps": "",
        "dockEnabled": true,
        "dockIconSize": 46,
        "dockSpacing": 10,
        "dockBottomMargin": 20,
        "dockMagnify": true,
        "dockHoverEffect": 1,
        "barMotionScale": 1.35,
        "barNotchFlare": 14,
        "dockNotchFlare": 14,
        "dockAutoHide": false,
        "dockShowIndicators": true,
        "dockShowTooltips": true,
        "dockShowRunning": true,
        "dockIconTiles": false,
        "widgetsEnabled": true,
        "widgetSnap": true,
        "widgetLockAll": false,
        "widgetHideFullscreen": true,
        "widgetOnTop": false,
        "btScanOnOpen": true,
        "btShowUnnamed": false,
        "kdeConnectEnabled": true,
        "idleEnabled": false,
        "idleAutostart": true,
        "idleKeepAwake": false,
        "idleAdopted": false,
        "idleDim": true,
        "idleDimAfter": 120,
        "idleDimLevel": 10,
        "idleDimKeyboard": true,
        "idleLock": true,
        "idleLockAfter": 600,
        "idleScreenOff": true,
        "idleScreenOffAfter": 900,
        "idleSuspend": false,
        "idleSuspendAfter": 1800,
        "idleSuspendOnAc": false,
        "idleLockBeforeSleep": true,
        "idleWakeAfterSleep": true,
        "idleRespectInhibitors": true,
        "idleWhileMedia": true,
        "desktopSelection": true,
        "desktopMenu": true
    })

    // what the bar module is holding right now, so the settings page can offer
    // to clear it; not persisted
    property int liveNotifCount: 0

    signal notificationsClearRequested()

    signal pinnedResetRequested()
    signal settingsRequested(string page)
    signal resetConfirmRequested(string title, string body, string confirmLabel, string action)
    signal wallpaperDeleteRequested(string path)
    signal desktopActionRequested(string action)
    signal wallpapersChanged()

    readonly property string resetAllToken: "__all__"
    readonly property string resetDockToken: "__dock__"
    readonly property string resetBlurToken: "__blur__"
    readonly property string clearWidgetsToken: "__widgets__"
    readonly property string resetIdleToken: "__idle__"

    signal themeChangeRequested(string id)

    signal themeDeleteRequested(string id)

    signal fontPickerRequested()

    signal timeZonePickerRequested()

    onAnyBarModuleEnabledChanged: {
        if (!root.anyBarModuleEnabled && root.barEnabled)
            root.barEnabled = false;

    }

    function setAllBarModules(v) {
        root.showWorkspaces = v;
        root.showMedia = v;
        root.showTray = v;
        root.showClock = v;
        root.showNotifications = v;
        root.showSystem = v;
    }

    function setSurface(key, v) {
        if (key === "barEnabled") {
            if (v && !root.anyBarModuleEnabled)
                root.setAllBarModules(true);

            root.barEnabled = v;
        } else if (key === "dockEnabled") {
            root.dockEnabled = v;
        } else if (key === "widgetsEnabled") {
            root.widgetsEnabled = v;
        } else if (key === "kdeConnectEnabled") {
            root.kdeConnectEnabled = v;
        } else if (key === "showNotifications") {
            root.showNotifications = v;
        } else if (key === "idleEnabled") {
            root.idleEnabled = v;
        }
    }

    function askReset(title, body, action) {
        root.resetConfirmRequested(title, body, "Reset", action);
    }

    // same dialog, different verb
    function askConfirm(title, body, confirmLabel, action) {
        root.resetConfirmRequested(title, body, confirmLabel, action);
    }

    function isModified(key) {
        return root.defaults[key] !== undefined && root[key] !== root.defaults[key];
    }

    function resetAll() {
        for (var k in root.defaults) root.set(k, root.defaults[k])
    }

    function resetKeys(keys) {
        for (var i = 0; i < keys.length; i++) root.set(keys[i], root.defaults[keys[i]])
    }

    // a custom folder overrides every theme's own
    function wallpaperDirFor(themeId) {
        return root.wallpaperFolder !== "" ? root.wallpaperFolder : (Quickshell.env("HOME") + "/Pictures/wallpapers/" + themeId);
    }

    // must write through the alias — a bracket write on the adapter is dropped
    function set(key, value) {
        if (root.defaults[key] !== undefined && root[key] !== value)
            root[key] = value;
    }

    // quiet hours, evaluated against a clock the caller owns so Prefs need not
    // depend on Loc, which already depends on Prefs
    function inQuietWindow(d) {
        if (!root.quietHours)
            return false;

        if (root.quietFrom === root.quietTo)
            return false;

        var m = d.getHours() * 60 + d.getMinutes();
        return root.quietFrom < root.quietTo ? (m >= root.quietFrom && m < root.quietTo) : (m >= root.quietFrom || m < root.quietTo);
    }

    function minutesText(m) {
        return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }

    // "22:00", "22.00", "2200" and "9" all land somewhere sensible
    function parseMinutes(t) {
        var m = String(t).trim().match(/^(\d{1,2})\s*[:.h]?\s*(\d{2})?$/);
        if (!m)
            return -1;

        var h = parseInt(m[1], 10);
        var mi = m[2] === undefined ? 0 : parseInt(m[2], 10);
        if (h > 23 || mi > 59)
            return -1;

        return h * 60 + mi;
    }

    // the freedesktop set spreads ~17 dB between its own files, so each carries a
    // trim that lands its peak in roughly the same place
    readonly property var notifSounds: [
        { "key": "message", "label": "Message", "gain": 1.24 },
        { "key": "bell", "label": "Bell", "gain": 2.11 },
        { "key": "complete", "label": "Chime", "gain": 0.9 },
        { "key": "suspend-error", "label": "Alert", "gain": 0.71 }
    ]

    function notifSoundEntry(name) {
        for (var i = 0; i < root.notifSounds.length; i++) {
            if (root.notifSounds[i].key === name)
                return root.notifSounds[i];

        }
        return root.notifSounds[0];
    }

    readonly property string notifSoundPath: "/usr/share/sounds/freedesktop/stereo/" + root.notifSoundEntry(root.notifSoundName).key + ".oga"
    // paplay's --volume rides PulseAudio's cubic scale, so a bare 0.6 is a 13 dB
    // cut rather than six tenths of the loudness; cube-root it back
    readonly property int notifSoundPaVolume: {
        var g = Math.max(0, Math.min(2.5, root.notifSoundVolume * root.notifSoundEntry(root.notifSoundName).gain));
        return Math.round(65536 * Math.cbrt(g));
    }

    function splitList(v) {
        return v.split(",").filter((x) => {
            return x !== "";
        });
    }

    readonly property var mutedApps: root.splitList(root.notifMutedApps)
    // every app that has sent a notification since the list was last cleared, so
    // the settings page can offer them instead of asking you to type a name
    readonly property var seenApps: root.splitList(root.notifSeenApps)

    function isMuted(app) {
        return app !== "" && root.mutedApps.indexOf(app) !== -1;
    }

    function setMuted(app, on) {
        if (app === "")
            return ;

        var list = root.mutedApps.filter((x) => {
            return x !== app;
        });
        if (on)
            list.push(app);

        root.notifMutedApps = list.join(",");
    }

    function noteApp(app) {
        var name = String(app).replace(/,/g, " ").trim();
        if (name === "" || root.seenApps.indexOf(name) !== -1)
            return ;

        var list = root.seenApps.concat([name]).sort((a, b) => {
            return a.toLowerCase().localeCompare(b.toLowerCase());
        });
        root.notifSeenApps = list.slice(0, 60).join(",");
    }

    // imported themes live beside the shipped ones, so the catalogue is the
    // built-in list plus whatever meta.json files are on disk
    Process {
        id: userThemeScan

        command: ["python3", "-c", "import json,glob,os;print(json.dumps([json.load(open(f)) for f in sorted(glob.glob(os.path.expanduser('~/.config/lucid/themes/*/meta.json')))]))"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.userThemes = JSON.parse(text.trim() || "[]");
                } catch (e) {
                    root.userThemes = [];
                }
            }
        }

    }

    function rescanThemes() {
        userThemeScan.running = false;
        userThemeScan.running = true;
    }

    Component.onCompleted: root.rescanThemes()

    FileView {
        path: Quickshell.env("HOME") + "/.cache/current_theme"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.currentTheme = text().trim() || "matugen"
    }

    Timer {
        id: writeDebounce

        interval: 120
        repeat: false
        onTriggered: prefsFile.writeAdapter()
    }

    FileView {
        id: prefsFile

        path: Quickshell.env("HOME") + "/.config/quickshell/lucidprefs/prefs.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeDebounce.restart()
        onLoaded: root.loaded = true
        onLoadFailed: root.loaded = true

        adapter: JsonAdapter {
            id: s

            property string barStyle: "island"
            property string dockStyle: "island"
            property real accentPunch: 1
            property real surfaceDarkness: -1
            property real motionScale: 1
            property string fontFamily: "Google Sans"
            property real fontScale: 1
            property string wallpaperFolder: ""
            property string themeOrder: ""
            property bool barEnabled: true
            property bool barPopupMode: false
            property int barPopupGap: 10
            property int barHeight: 35
            property int barTopMargin: 22
            property int barSideMargin: 17
            property int barSpacing: 8
            property int barHoverGrow: 3
            property bool showWorkspaces: true
            property bool showMedia: true
            property bool showTray: true
            property bool showClock: true
            property bool showNotifications: true
            property bool showSystem: true
            property bool clock24h: false
            property bool clockShowDate: true
            property bool gpsEnabled: false
            property string locationName: ""
            property string locationLabel: ""
            property real locationLat: 52.4083
            property real locationLon: 16.9336
            property string locationTz: ""
            property bool timeZoneAuto: true
            property bool doNotDisturb: false
            property int toastTimeout: 5
            property bool toastEnabled: true
            property bool toastUseAppTimeout: true
            property bool toastCriticalSticky: true
            property bool toastShowBody: true
            property bool toastShowActions: true
            property int toastBodyLines: 4
            property bool notifShowIcons: true
            property int notifMaxHistory: 50
            property bool dndAllowCritical: true
            property bool dndFullscreen: false
            property bool quietHours: false
            property int quietFrom: 1320
            property int quietTo: 420
            property bool notifSound: false
            property string notifSoundName: "message"
            property real notifSoundVolume: 0.6
            property bool notifSoundUrgentOnly: false
            property string notifMutedApps: ""
            property string notifSeenApps: ""
            property bool dockEnabled: true
            property int dockIconSize: 46
            property int dockSpacing: 10
            property int dockBottomMargin: 20
            property bool dockMagnify: true
            property real dockHoverEffect: 1
            property real barMotionScale: 1.35
            property int barNotchFlare: 14
            property int dockNotchFlare: 14
            property bool dockAutoHide: false
            property bool dockShowIndicators: true
            property bool dockShowTooltips: true
            property bool dockShowRunning: true
            property bool dockIconTiles: false
            property bool widgetsEnabled: true
            property bool widgetSnap: true
            property bool widgetLockAll: false
            property bool widgetHideFullscreen: true
            property bool widgetOnTop: false
            property bool btScanOnOpen: true
            property bool btShowUnnamed: false
            property bool kdeConnectEnabled: true
            property bool idleEnabled: false
            property bool idleAutostart: true
            property bool idleKeepAwake: false
            property bool idleAdopted: false
            property bool idleDim: true
            property int idleDimAfter: 120
            property int idleDimLevel: 10
            property bool idleDimKeyboard: true
            property bool idleLock: true
            property int idleLockAfter: 600
            property bool idleScreenOff: true
            property int idleScreenOffAfter: 900
            property bool idleSuspend: false
            property int idleSuspendAfter: 1800
            property bool idleSuspendOnAc: false
            property bool idleLockBeforeSleep: true
            property bool idleWakeAfterSleep: true
            property bool idleRespectInhibitors: true
            property bool idleWhileMedia: true
            property bool desktopSelection: true
            property bool desktopMenu: true
        }

    }

}
