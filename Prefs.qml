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
    readonly property int dockItemRadius: Math.min(root.dockRadius, Math.round(root.dockIconSize / 2))
    readonly property int dockIconInset: Math.max(0, Math.min(root.dockIconPadding, Math.floor(root.dockIconSize / 2) - 6))
    // every module the bar can carry, and the order they appear in the layout
    // editor's spare list
    readonly property var barModules: [
        { "key": "workspaces", "icon": "grid_view", "name": "Workspaces", "desc": "Workspace pills and the expanded overview" },
        { "key": "media", "icon": "music_note", "name": "Media", "desc": "Now playing, with the full player behind it" },
        { "key": "tray", "icon": "widgets", "name": "System tray", "desc": "Status icons from running applications" },
        { "key": "clock", "icon": "schedule", "name": "Clock", "desc": "Time and date, with the calendar, timers and world clocks behind them" },
        { "key": "notifications", "icon": "notifications", "name": "Notifications", "desc": "Unread count, and the notification centre" },
        { "key": "system", "icon": "tune", "name": "System", "desc": "Network, sound, brightness and the quick settings panel" }
    ]
    readonly property var barZones: ["left", "centre", "right"]
    readonly property var barLayoutKeys: ["barLeft", "barCentre", "barRight"]

    function barModuleAt(key) {
        for (var i = 0; i < root.barModules.length; i++) {
            if (root.barModules[i].key === key)
                return root.barModules[i];

        }
        return null;
    }

    function barParse(raw) {
        return String(raw).split(",").map((x) => {
            return x.trim();
        }).filter((x, i, all) => {
            return x !== "" && all.indexOf(x) === i && root.barModuleAt(x) !== null;
        });
    }

    readonly property var barLeftKeys: root.barParse(root.barLeft)
    readonly property var barCentreKeys: root.barParse(root.barCentre)
    readonly property var barRightKeys: root.barParse(root.barRight)

    function barKeysOf(zone) {
        return zone === "left" ? root.barLeftKeys : (zone === "centre" ? root.barCentreKeys : root.barRightKeys);
    }

    function barZoneOf(key) {
        for (var i = 0; i < root.barZones.length; i++) {
            if (root.barKeysOf(root.barZones[i]).indexOf(key) >= 0)
                return root.barZones[i];

        }
        return "";
    }

    function barHas(key) {
        return root.barZoneOf(key) !== "";
    }

    function setBarKeys(zone, keys) {
        const joined = keys.join(",");
        if (zone === "left")
            root.barLeft = joined;
        else if (zone === "centre")
            root.barCentre = joined;
        else
            root.barRight = joined;
    }

    // moving a module anywhere is one call: it leaves whatever zone it was in
    // first, so it can never appear twice. a target index past the end appends
    function barMove(key, zone, index) {
        if (root.barModuleAt(key) === null)
            return ;

        const from = root.barZoneOf(key);
        // must precede the writes, or the x bindings re-evaluate before the
        // bar knows this one is worth easing
        if (from !== "")
            root.barReorderTick++;

        if (from !== "" && from !== zone)
            root.setBarKeys(from, root.barKeysOf(from).filter((k) => {
                return k !== key;
            }));

        const rest = root.barKeysOf(zone).filter((k) => {
            return k !== key;
        });
        const at = index < 0 ? rest.length : Math.min(index, rest.length);
        rest.splice(at, 0, key);
        root.setBarKeys(zone, rest);
    }

    function barRemove(key) {
        const from = root.barZoneOf(key);
        if (from === "")
            return ;

        // the key leaves the list at once while the pill itself takes a moment
        // to empty, so the bar is told to keep the slot until it has
        root.barRetiring = ({ "key": key, "zone": from, "at": root.barKeysOf(from).indexOf(key) });
        root.setBarKeys(from, root.barKeysOf(from).filter((k) => {
            return k !== key;
        }));
    }

    // one pair of buttons reaches every position: stepping off either end of a
    // zone carries the module into the next one
    function barStep(key, delta) {
        const zone = root.barZoneOf(key);
        if (zone === "")
            return ;

        const list = root.barKeysOf(zone);
        const to = list.indexOf(key) + delta;
        if (to >= 0 && to < list.length) {
            root.barMove(key, zone, to);
            return ;
        }
        const zi = root.barZones.indexOf(zone) + delta;
        if (zi < 0 || zi >= root.barZones.length)
            return ;

        const next = root.barZones[zi];
        root.barMove(key, next, delta > 0 ? 0 : root.barKeysOf(next).length);
    }

    function barCanStep(key, delta) {
        const zone = root.barZoneOf(key);
        if (zone === "")
            return false;

        const list = root.barKeysOf(zone);
        const to = list.indexOf(key) + delta;
        if (to >= 0 && to < list.length)
            return true;

        const zi = root.barZones.indexOf(zone) + delta;
        return zi >= 0 && zi < root.barZones.length;
    }

    readonly property var barPlacedKeys: root.barLeftKeys.concat(root.barCentreKeys, root.barRightKeys)

    function barSignature(keys) {
        return keys.slice().sort().join(",");
    }

    // bumped just before an arrangement change that only moves modules about,
    // so the bar can ease the pills across. an add or a remove is deliberately
    // not bumped: those animate the pill's own width, and every neighbour's x
    // already follows that frame by frame
    property int barReorderTick: 0

    // the module that has just left the bar, and the slot it had. the bar draws
    // it there until its pill has emptied, so the neighbours close the gap at
    // the rate it shrinks instead of dropping into it
    property var barRetiring: null

    function barClearRetiring() {
        root.barRetiring = null;
    }

    readonly property var barUnusedKeys: root.barModules.filter((m) => {
        return !root.barHas(m.key);
    }).map((m) => {
        return m.key;
    })

    // every tile the system panel's grid can carry. the panel shows the ones
    // named in systemTiles, in that order, and its editor offers the rest
    readonly property var systemTileCatalog: [
        { "key": "dnd", "icon": "do_not_disturb_on", "name": "Silence" },
        { "key": "awake", "icon": "coffee", "name": "Awake" },
        { "key": "dark", "icon": "dark_mode", "name": "Dark" },
        { "key": "airplane", "icon": "flight", "name": "Airplane" },
        { "key": "location", "icon": "location_on", "name": "Location" },
        { "key": "mic", "icon": "mic", "name": "Mic" },
        { "key": "capture", "icon": "screenshot_region", "name": "Capture" },
        { "key": "record", "icon": "screen_record", "name": "Record" },
        { "key": "picker", "icon": "colorize", "name": "Picker" },
        { "key": "keyboard", "icon": "keyboard", "name": "Keyboard" },
        { "key": "timer", "icon": "timer", "name": "Timer" },
        { "key": "session", "icon": "power_settings_new", "name": "Session" },
        { "key": "profile", "icon": "speed", "name": "Power" },
        { "key": "gamemode", "icon": "sports_esports", "name": "Game mode" },
        { "key": "clipboard", "icon": "content_paste", "name": "Clipboard" },
        { "key": "emoji", "icon": "mood", "name": "Emoji" },
        { "key": "wallpaper", "icon": "wallpaper", "name": "Wallpaper" },
        { "key": "theme", "icon": "palette", "name": "Theme" },
        { "key": "widgets", "icon": "widgets", "name": "Widgets" },
        { "key": "clear", "icon": "clear_all", "name": "Clear" }
    ]

    function systemTileAt(key) {
        for (var i = 0; i < root.systemTileCatalog.length; i++) {
            if (root.systemTileCatalog[i].key === key)
                return root.systemTileCatalog[i];

        }
        return null;
    }

    // same rules as the bar zones: no repeats, nothing the catalogue lacks
    readonly property var systemTileKeys: String(root.systemTiles).split(",").map((x) => {
        return x.trim();
    }).filter((x, i, all) => {
        return x !== "" && all.indexOf(x) === i && root.systemTileAt(x) !== null;
    })
    readonly property var systemTileSpare: root.systemTileCatalog.filter((t) => {
        return root.systemTileKeys.indexOf(t.key) < 0;
    }).map((t) => {
        return t.key;
    })

    function setSystemTiles(keys) {
        root.systemTiles = keys.join(",");
    }

    readonly property bool anyBarModuleEnabled: root.barLeftKeys.length + root.barCentreKeys.length + root.barRightKeys.length > 0
    // the notification page's own header switch, which is really "is the module
    // in the bar at all"
    readonly property bool barNotifications: root.barHas("notifications")
    readonly property var widgetKeys: ["widgetsEnabled", "widgetSnap", "widgetLockAll", "widgetHideFullscreen", "widgetOnTop"]
    readonly property var idleKeys: ["idleDim", "idleDimAfter", "idleDimLevel", "idleDimKeyboard", "idleLock", "idleLockAfter", "idleScreenOff", "idleScreenOffAfter", "idleSuspend", "idleSuspendAfter", "idleSuspendOnAc", "idleLockBeforeSleep", "idleWakeAfterSleep", "idleRespectInhibitors", "idleWhileMedia"]
    readonly property var envKeys: ["envCursorTheme", "envCursorSize", "envCursorShadow", "envIconTheme", "envGtkTheme", "envQtStyle", "envQtPlatformTheme", "envColorScheme", "envFontSync", "envAppFont", "envAppFontSize", "envDocumentFont", "envDocumentFontSize", "envMonoFont", "envMonoFontSize", "envApplyGtk", "envApplyQt", "envApplyHypr", "envAdopted"]
    readonly property var specialKeys: ["specialScratchpad", "specialMusic", "specialComms", "specialTodo", "specialSysmon", "specialMusicApps", "specialCommsApps", "specialTodoApps", "specialSysmonApps", "specialKeepApps", "specialHideOnSwitch", "specialDim", "specialBlur", "specialGaps"]
    readonly property var glassKeys: ["glassApps", "glassValues"]
    readonly property var monitorKeys: ["monitorSetups", "monitorShellScreen", "monitorBarScreen", "monitorDockScreen", "monitorWorkspaces"]
    readonly property var notifKeys: ["toastEnabled", "toastTimeout", "toastUseAppTimeout", "toastCriticalSticky", "toastShowBody", "toastShowActions", "toastBodyLines", "notifShowIcons", "notifMaxHistory", "doNotDisturb", "dndAllowCritical", "dndFullscreen", "quietHours", "quietFrom", "quietTo", "notifSound", "notifSoundName", "notifSoundVolume", "notifSoundUrgentOnly", "notifMutedApps", "notifGrouping", "notifTimestamps", "notifProgress", "notifInlineReply", "toastMaxVisible"]

    property alias barStyle: s.barStyle
    property alias dockStyle: s.dockStyle
    property alias accentPunch: s.accentPunch
    property alias surfaceDarkness: s.surfaceDarkness
    property alias surfaceTint: s.surfaceTint
    property alias motionScale: s.motionScale
    property alias fontFamily: s.fontFamily
    property alias fontScale: s.fontScale
    property alias wallpaperFolder: s.wallpaperFolder
    // bracket writes on the adapter are dropped, so this must go through the alias
    property alias themeOrder: s.themeOrder
    property string currentTheme: "matugen"
    readonly property string wallpaperDir: root.wallpaperDirFor(root.currentTheme)
    // "dark" | "light". kept in ~/.cache/current_mode beside current_theme
    // because set-wallpaper.sh and apply-theme.sh have to agree on it too
    property string colorMode: "dark"

    function setColorMode(mode) {
        if ((mode !== "dark" && mode !== "light") || mode === root.colorMode)
            return;

        // set straight away so the control answers the click; the cache file is
        // what actually confirms it, and the palette lands a moment later
        root.colorMode = mode;
        // a light shell beside dark application chrome reads as broken, so apps
        // follow. the Environment page can still be set back to auto afterwards
        root.envColorScheme = mode;
        // Env owns the theme names and knows what is installed, so the matching
        // GTK and icon variants are swapped there
        root.colorModeApplied(mode);
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/lucid/set-mode.sh", mode]);
    }

    property alias barEnabled: s.barEnabled
    property alias barPopupMode: s.barPopupMode
    property alias barPopupGap: s.barPopupGap
    property alias barHeight: s.barHeight
    property alias barTopMargin: s.barTopMargin
    property alias barSideMargin: s.barSideMargin
    property alias barSpacing: s.barSpacing
    property alias barHoverGrow: s.barHoverGrow
    property alias barZoneGap: s.barZoneGap
    property alias barLeft: s.barLeft
    property alias barCentre: s.barCentre
    property alias barRight: s.barRight
    property alias systemTiles: s.systemTiles
    property alias showKbLayout: s.showKbLayout
    property alias gameModeOnCmd: s.gameModeOnCmd
    property alias gameModeOffCmd: s.gameModeOffCmd
    property alias gameModeStatusCmd: s.gameModeStatusCmd

    readonly property string gameModeStateFile: {
        const m = /(?:test|\[)\s+-[ef]\s+(\S+)/.exec(root.gameModeStatusCmd || "");
        return m ? m[1].replace(/^['"]|['"]$/g, "") : "";
    }
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
    property alias toastOnLayout: s.toastOnLayout
    property alias toastOnGameMode: s.toastOnGameMode
    property alias toastOnBattery: s.toastOnBattery
    property alias toastOnBluetooth: s.toastOnBluetooth
    property alias toastOnWifi: s.toastOnWifi
    property alias toastOnAudio: s.toastOnAudio
    property alias toastOnDisplays: s.toastOnDisplays
    property alias toastOnPower: s.toastOnPower
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
    property alias notifGrouping: s.notifGrouping
    property alias notifTimestamps: s.notifTimestamps
    property alias notifProgress: s.notifProgress
    property alias notifInlineReply: s.notifInlineReply
    property alias toastMaxVisible: s.toastMaxVisible

    property alias dockEnabled: s.dockEnabled
    property alias dockIconSize: s.dockIconSize
    property alias dockSpacing: s.dockSpacing
    property alias dockRadius: s.dockRadius
    property alias dockIconPadding: s.dockIconPadding
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
    property alias clipboardEnabled: s.clipboardEnabled

    property alias widgetsEnabled: s.widgetsEnabled
    property alias widgetSnap: s.widgetSnap
    property alias widgetLockAll: s.widgetLockAll
    property alias widgetHideFullscreen: s.widgetHideFullscreen
    property alias widgetOnTop: s.widgetOnTop

    property alias btScanOnOpen: s.btScanOnOpen
    property alias btShowUnnamed: s.btShowUnnamed
    property alias audioMoveStreams: s.audioMoveStreams
    property alias kdeConnectEnabled: s.kdeConnectEnabled
    property alias updateCheck: s.updateCheck

    property alias specialScratchpad: s.specialScratchpad
    property alias specialMusic: s.specialMusic
    property alias specialComms: s.specialComms
    property alias specialTodo: s.specialTodo
    property alias specialSysmon: s.specialSysmon
    // comma-joined app ids, or "auto" for the first one installed
    property alias specialMusicApps: s.specialMusicApps
    property alias specialCommsApps: s.specialCommsApps
    property alias specialTodoApps: s.specialTodoApps
    property alias specialSysmonApps: s.specialSysmonApps
    property alias specialKeepApps: s.specialKeepApps
    property alias specialHideOnSwitch: s.specialHideOnSwitch
    property alias specialDim: s.specialDim
    property alias specialBlur: s.specialBlur
    property alias specialGaps: s.specialGaps
    // the workspaces you made, a JSON list of { key, label, glyph, on, apps }
    property alias specialCustom: s.specialCustom

    property alias glassApps: s.glassApps
    property alias glassValues: s.glassValues

    // per-output display config, JSON keyed by hyprland monitor selector
    property alias monitorSetups: s.monitorSetups
    property alias monitorShellScreen: s.monitorShellScreen
    // empty means the bar or dock goes wherever the shell went
    property alias monitorBarScreen: s.monitorBarScreen
    property alias monitorDockScreen: s.monitorDockScreen
    property alias monitorWorkspaces: s.monitorWorkspaces

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
    property alias shotPreview: s.shotPreview
    property alias shotPreviewSeconds: s.shotPreviewSeconds

    // one-shot: the machine's own gtk/qt/cursor settings are read in once
    property alias envAdopted: s.envAdopted
    property alias envCursorTheme: s.envCursorTheme
    property alias envCursorSize: s.envCursorSize
    property alias envCursorShadow: s.envCursorShadow
    property alias envIconTheme: s.envIconTheme
    property alias envGtkTheme: s.envGtkTheme
    property alias envQtStyle: s.envQtStyle
    property alias envQtPlatformTheme: s.envQtPlatformTheme
    property alias envColorScheme: s.envColorScheme
    property alias envFontSync: s.envFontSync
    property alias envAppFont: s.envAppFont
    property alias envAppFontSize: s.envAppFontSize
    property alias envDocumentFont: s.envDocumentFont
    property alias envDocumentFontSize: s.envDocumentFontSize
    property alias envMonoFont: s.envMonoFont
    property alias envMonoFontSize: s.envMonoFontSize
    property alias envApplyGtk: s.envApplyGtk
    property alias envApplyQt: s.envApplyQt
    property alias envApplyHypr: s.envApplyHypr
    property alias clockShowSeconds: s.clockShowSeconds
    property alias clockShowWeather: s.clockShowWeather
    property alias clockShowTimer: s.clockShowTimer
    property alias clockWorldZones: s.clockWorldZones
    property alias pomodoroFocus: s.pomodoroFocus
    property alias pomodoroShort: s.pomodoroShort
    property alias pomodoroLong: s.pomodoroLong
    property alias pomodoroRounds: s.pomodoroRounds
    property alias pomodoroAutoStart: s.pomodoroAutoStart
    property alias timerSound: s.timerSound
    property alias weekStartMonday: s.weekStartMonday
    property alias launcherSearchEngine: s.launcherSearchEngine
    property alias launcherWebRow: s.launcherWebRow
    property alias launcherWidth: s.launcherWidth
    property alias launcherSearchPosition: s.launcherSearchPosition
    property alias launcherDensity: s.launcherDensity
    property alias launcherModeBar: s.launcherModeBar
    property alias launcherActionHints: s.launcherActionHints
    property alias launcherFrequentFirst: s.launcherFrequentFirst
    property alias launcherCalculator: s.launcherCalculator
    property alias launcherSettingsResults: s.launcherSettingsResults
    property alias launcherContentScale: s.launcherContentScale
    property alias launcherHiddenApps: s.launcherHiddenApps

    // the launcher's m3 metrics, read by the dock's geometry and the face alike
    // how large the launcher draws itself, apart from the shell-wide font scale
    readonly property real launcherScale: Math.max(0.8, Math.min(1.4, root.launcherContentScale))
    readonly property int launcherBaseWidth: root.launcherWidth === "compact" ? 460 : (root.launcherWidth === "wide" ? 680 : 560)
    readonly property int launcherPanelWidth: Math.round(root.launcherBaseWidth * root.launcherScale)
    readonly property bool launcherDense: root.launcherDensity === "compact"
    readonly property bool launcherSearchTop: root.launcherSearchPosition === "top"
    // m3 list item container heights, one line and two
    readonly property int launcherRowOne: Math.round((root.launcherDense ? 48 : 56) * root.launcherScale)
    readonly property int launcherRowTwo: Math.round((root.launcherDense ? 62 : 72) * root.launcherScale)
    readonly property int launcherRowHeader: Math.round((root.launcherDense ? 32 : 38) * root.launcherScale)
    // the calculator's answer takes a display-type hero rather than a list row
    readonly property int launcherRowCalc: Math.round((root.launcherDense ? 84 : 96) * root.launcherScale)
    // m3 ItemLeadingAvatarSize, the slot every kind of leading element shares.
    // a compact row at a small content size is shorter than 40dp, so it caps
    readonly property int launcherLeadSlot: Math.max(24, Math.min(Math.round(40 * root.launcherScale), root.launcherRowOne - 8))
    readonly property int launcherEdgeSpace: Math.round(16 * root.launcherScale)
    readonly property int launcherBetweenSpace: Math.round(12 * root.launcherScale)
    readonly property int launcherRowGap: root.launcherDense ? 2 : 4
    readonly property int launcherListPad: 8
    // m3 search bar container height
    readonly property int launcherSearchH: Math.round(56 * root.launcherScale)
    // the head band: the mark, the mode set and the count
    readonly property int launcherHeadH: Math.round(38 * root.launcherScale)
    readonly property int launcherHeadGap: Math.round(10 * root.launcherScale)
    readonly property int launcherContentGap: 12

    readonly property int launcherChromeH: root.launcherSearchH + (root.launcherModeBar ? root.launcherHeadH + root.launcherHeadGap : 0) + root.launcherContentGap

    // every settings page, for the app's rail and for the launcher's search
    readonly property var settingsPages: [
        { "key": "users", "icon": "account_circle", "keys": "user account password avatar login admin sudo", "group": "Account", "label": "Account", "title": "Users and Accounts", "blurb": "Who may sign in to this machine, what they are called and what they are allowed to do", "hidden": true },
        { "key": "general", "icon": "tune", "keys": "style islands notches accent darkness surface tint motion animation speed font scale typography", "group": "Appearance", "label": "General", "title": "General", "blurb": "Shape, colour and motion across the whole shell" },
        { "key": "glass", "icon": "blur_on", "keys": "blur transparency opacity translucent frosted kitty terminal windows", "group": "Appearance", "label": "Glass", "title": "Glass", "blurb": "How far the desktop shows through the shell, the terminal and your windows" },
        { "key": "theme", "icon": "palette", "keys": "colour color scheme wallpaper matugen pywal catppuccin gruvbox nord dark light mode import", "group": "Appearance", "label": "Theme", "title": "Theme and Appearance", "blurb": "Colour schemes, wallpapers and themes you import" },
        { "key": "environment", "icon": "format_paint", "keys": "cursor icons gtk qt fonts application theme", "group": "Appearance", "label": "Environment", "title": "Environment", "blurb": "Cursors, icons, fonts and application themes, across GTK, Qt and Hyprland alike" },
        { "key": "bar", "icon": "toolbar", "keys": "status height margin spacing modules workspaces clock media tray system popup", "group": "Desktop", "label": "Bar", "title": "Bar", "blurb": "The status bar, its modules and how they open", "toggle": "barEnabled" },
        { "key": "dock", "icon": "dock_to_bottom", "keys": "icons size magnify autohide pinned running indicators tooltips windows notch radius corners rounding padding inset", "group": "Desktop", "label": "Dock", "title": "Dock", "blurb": "The dock, its icons and how it behaves", "toggle": "dockEnabled" },
        { "key": "launcher", "icon": "search", "keys": "launcher search spotlight apps results width density rows chips modes prefix engine web emoji run clipboard calculator frequent recent", "group": "Desktop", "label": "Launcher", "title": "Launcher", "blurb": "The search panel the dock opens into: how wide it is, how its results read, and what it looks through" },
        { "key": "widgets", "icon": "widgets", "keys": "desktop cards clock calendar weather presets", "group": "Desktop", "label": "Widgets", "title": "Widgets", "blurb": "Cards you place on the desktop and arrange yourself", "toggle": "widgetsEnabled" },
        { "key": "workspaces", "icon": "workspaces", "keys": "special scratchpad music chat todo sysmon", "group": "Desktop", "label": "Workspaces", "title": "Special Workspaces", "blurb": "Your music, chat, to-do list and a scratchpad, each one key away and gone again with the same key" },
        { "key": "keybinds", "icon": "keyboard", "keys": "shortcuts hotkeys keys bindings hyprland super binds", "group": "Desktop", "label": "Keybinds", "title": "Keybinds", "blurb": "Every Hyprland shortcut: change one, switch it off or add your own" },
        { "key": "displays", "icon": "desktop_windows", "keys": "monitor screen resolution refresh rate scale vrr arrangement", "group": "Devices", "label": "Displays", "title": "Displays", "blurb": "Every screen this machine has: resolution, refresh rate, scale, how they are arranged and which one the shell sits on" },
        { "key": "sound", "icon": "volume_up", "keys": "audio volume speakers microphone output input devices", "group": "Devices", "label": "Sound", "title": "Sound", "blurb": "Which speakers play and which microphone listens, what each application is using, and how loud any of it is" },
        { "key": "network", "icon": "wifi", "keys": "wifi ethernet vpn dns ip proxy internet", "group": "Devices", "label": "Network", "title": "Network", "blurb": "Wi-Fi, wired, VPN and how this machine gets its address" },
        { "key": "bluetooth", "icon": "bluetooth", "keys": "devices pair headphones", "group": "Devices", "label": "Bluetooth", "title": "Bluetooth and Devices", "blurb": "The radio, what it is paired with, and the phone you connect to it" },
        { "key": "kdeconnect", "icon": "smartphone", "keys": "phone kde connect files notifications clipboard", "group": "Devices", "label": "Phone", "title": "Phone", "blurb": "Your phone on this machine over KDE Connect: files, notifications, clipboard and a remote", "toggle": "kdeConnectEnabled" },
        { "key": "notifications", "icon": "notifications", "keys": "popups toasts do not disturb dnd quiet hours sound muted apps", "group": "System", "label": "Notifications", "title": "Notifications", "blurb": "Popups, quiet hours, sound and which applications may interrupt you", "toggle": "barNotifications" },
        { "key": "idle", "icon": "bedtime", "keys": "sleep suspend lock dim screen off hypridle caffeine", "group": "System", "label": "Idle", "title": "Idle and Sleep", "blurb": "What happens when you walk away: dimming, locking, screen off and suspend", "toggle": "idleEnabled" },
        { "key": "datetime", "icon": "schedule", "keys": "clock time zone location 24 hour seconds week monday sunday timer pomodoro focus break alarm world", "group": "System", "label": "Date & Time", "title": "Date and Time", "blurb": "Where you are, the clock, and its timers" },
        { "key": "about", "icon": "info", "keys": "version update lucid", "group": "System", "label": "About", "title": "About", "blurb": "Lucid" }
    ]

    function settingsPage(key) {
        for (var i = 0; i < root.settingsPages.length; i++) {
            if (root.settingsPages[i].key === key)
                return root.settingsPages[i];

        }
        return null;
    }

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
        "surfaceTint": -1,
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
        "barZoneGap": 26,
        "barLeft": "workspaces,media,tray",
        "barCentre": "clock",
        "barRight": "notifications,system",
        "systemTiles": "dnd,awake,dark,airplane,location,mic,capture,record,picker,keyboard,timer,session",
        "showKbLayout": true,
        "gameModeOnCmd": "",
        "gameModeOffCmd": "",
        "gameModeStatusCmd": "",
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
        "toastOnLayout": true,
        "toastOnGameMode": true,
        "toastOnBattery": true,
        "toastOnBluetooth": true,
        "toastOnWifi": true,
        "toastOnAudio": true,
        "toastOnDisplays": true,
        "toastOnPower": true,
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
        "notifGrouping": true,
        "notifTimestamps": true,
        "notifProgress": true,
        "notifInlineReply": true,
        "toastMaxVisible": 3,
        "dockEnabled": true,
        "dockIconSize": 41,
        "dockSpacing": 10,
        "dockRadius": 28,
        "dockIconPadding": 5,
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
        "clipboardEnabled": true,
        "widgetsEnabled": true,
        "widgetSnap": true,
        "widgetLockAll": false,
        "widgetHideFullscreen": true,
        "widgetOnTop": false,
        "btScanOnOpen": true,
        "btShowUnnamed": false,
        "audioMoveStreams": true,
        "kdeConnectEnabled": true,
        "updateCheck": true,
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
        "desktopMenu": true,
        "shotPreview": "preview",
        "shotPreviewSeconds": 6,
        "envAdopted": false,
        "envCursorTheme": "",
        "envCursorSize": 24,
        "envCursorShadow": true,
        "envIconTheme": "",
        "envGtkTheme": "",
        "envQtStyle": "Fusion",
        "envQtPlatformTheme": "",
        "envColorScheme": "auto",
        "envFontSync": false,
        "envAppFont": "",
        "envAppFontSize": 11,
        "envDocumentFont": "",
        "envDocumentFontSize": 11,
        "envMonoFont": "",
        "envMonoFontSize": 10,
        "envApplyGtk": true,
        "envApplyQt": true,
        "envApplyHypr": true,
        "specialScratchpad": true,
        "specialMusic": true,
        "specialComms": true,
        "specialTodo": true,
        "specialSysmon": true,
        "specialMusicApps": "auto",
        "specialCommsApps": "auto",
        "specialTodoApps": "auto",
        "specialSysmonApps": "auto",
        "specialKeepApps": true,
        "specialHideOnSwitch": false,
        "specialDim": 0.2,
        "specialBlur": false,
        "specialGaps": 0,
        "specialCustom": "[]",
        "glassApps": "vscodium",
        "glassValues": "vscodium=0.9",
        "monitorSetups": "{}",
        "monitorShellScreen": "",
        "monitorBarScreen": "",
        "monitorDockScreen": "",
        "clockShowSeconds": false,
        "clockShowWeather": true,
        "clockShowTimer": true,
        "clockWorldZones": "Europe/London,America/New_York,Asia/Tokyo",
        "pomodoroFocus": 25,
        "pomodoroShort": 5,
        "pomodoroLong": 15,
        "pomodoroRounds": 4,
        "pomodoroAutoStart": true,
        "timerSound": true,
        "weekStartMonday": true,
        "launcherSearchEngine": "duckduckgo",
        "launcherWebRow": true,
        "launcherWidth": "standard",
        "launcherSearchPosition": "bottom",
        "launcherDensity": "comfortable",
        "launcherModeBar": true,
        "launcherActionHints": true,
        "launcherFrequentFirst": true,
        "launcherCalculator": true,
        "launcherSettingsResults": true,
        "launcherContentScale": 1,
        "launcherHiddenApps": "",
        "monitorWorkspaces": "{}"
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
    readonly property string clearClipboardToken: "__clipboard__"
    readonly property string resetIdleToken: "__idle__"
    readonly property string resetEnvToken: "__env__"
    readonly property string resetSpecialsToken: "__specials__"
    readonly property string resetGlassToken: "__glass__"
    readonly property string resetMonitorsToken: "__monitors__"

    signal themeChangeRequested(string id)

    // a deliberate light/dark flip, as opposed to the cache file merely loading
    signal colorModeApplied(string mode)

    signal themeDeleteRequested(string id)

    signal fontPickerRequested()

    // "cursor" | "icon" | "gtk" | "qtStyle" | "appFont" | "docFont" | "monoFont"
    signal envPickerRequested(string kind)

    signal timeZonePickerRequested()

    signal keyboardRequested()

    // which special workspace the app being picked is going into
    signal appPickerRequested(string workspace)

    onAnyBarModuleEnabledChanged: {
        if (!root.anyBarModuleEnabled && root.barEnabled)
            root.barEnabled = false;

    }

    // emptying the bar switches it off, so putting the modules back has to
    // switch it on again or the restore looks like it did nothing
    function setBarDefaults() {
        const after = root.barParse(root.defaults.barLeft).concat(root.barParse(root.defaults.barCentre), root.barParse(root.defaults.barRight));
        if (root.barSignature(root.barPlacedKeys) === root.barSignature(after))
            root.barReorderTick++;

        root.resetKeys(root.barLayoutKeys);
        root.barEnabled = true;
    }

    function setAllBarModules(v) {
        if (v)
            root.resetKeys(root.barLayoutKeys);
        else
            for (var i = 0; i < root.barZones.length; i++) root.setBarKeys(root.barZones[i], [])
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
        } else if (key === "barNotifications") {
            if (v)
                root.barMove("notifications", "right", -1);
            else
                root.barRemove("notifications");
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

    // desktop-file ids the launcher leaves out. the scan itself already drops
    // anything NoDisplay or shown only in another desktop; this is the rest,
    // whatever you decided you never want to see
    readonly property var hiddenLauncherApps: root.splitList(root.launcherHiddenApps)
    // base -> display name, published by the dock's scan so the settings page
    // can name what it is offering to bring back
    property var launcherAppNames: ({})

    function isLauncherHidden(base) {
        return base !== "" && root.hiddenLauncherApps.indexOf(base) !== -1;
    }

    function setLauncherHidden(base, on) {
        if (base === "")
            return ;

        var list = root.hiddenLauncherApps.filter((x) => {
            return x !== base;
        });
        if (on)
            list.push(base);

        root.launcherHiddenApps = list.sort().join(",");
    }

    function launcherAppLabel(base) {
        var n = root.launcherAppNames[base];
        return n !== undefined && n !== "" ? n : base;
    }

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

    FileView {
        path: Quickshell.env("HOME") + "/.cache/current_mode"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.colorMode = text().trim() === "light" ? "light" : "dark"
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
            property real surfaceTint: -1
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
            property int barZoneGap: 26
            property string barLeft: "workspaces,media,tray"
            property string barCentre: "clock"
            property string barRight: "notifications,system"
            property string systemTiles: "dnd,awake,dark,airplane,location,mic,capture,record,picker,keyboard,timer,session"
            property bool showKbLayout: true
            property string gameModeOnCmd: ""
            property string gameModeOffCmd: ""
            property string gameModeStatusCmd: ""
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
            property bool toastOnLayout: true
            property bool toastOnGameMode: true
            property bool toastOnBattery: true
            property bool toastOnBluetooth: true
            property bool toastOnWifi: true
            property bool toastOnAudio: true
            property bool toastOnDisplays: true
            property bool toastOnPower: true
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
            property bool notifGrouping: true
            property bool notifTimestamps: true
            property bool notifProgress: true
            property bool notifInlineReply: true
            property int toastMaxVisible: 3
            property bool dockEnabled: true
            property int dockIconSize: 41
            property int dockSpacing: 10
            property int dockRadius: 28
            property int dockIconPadding: 5
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
            property bool clipboardEnabled: true
            property bool widgetsEnabled: true
            property bool widgetSnap: true
            property bool widgetLockAll: false
            property bool widgetHideFullscreen: true
            property bool widgetOnTop: false
            property bool btScanOnOpen: true
            property bool btShowUnnamed: false
            property bool audioMoveStreams: true
            property bool kdeConnectEnabled: true
            property bool updateCheck: true
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
            property string shotPreview: "preview"
            property int shotPreviewSeconds: 6
            property bool envAdopted: false
            property string envCursorTheme: ""
            property int envCursorSize: 24
            property bool envCursorShadow: true
            property string envIconTheme: ""
            property string envGtkTheme: ""
            property string envQtStyle: "Fusion"
            property string envQtPlatformTheme: ""
            property string envColorScheme: "auto"
            property bool envFontSync: false
            property string envAppFont: ""
            property int envAppFontSize: 11
            property string envDocumentFont: ""
            property int envDocumentFontSize: 11
            property string envMonoFont: ""
            property int envMonoFontSize: 10
            property bool envApplyGtk: true
            property bool envApplyQt: true
            property bool envApplyHypr: true
            property bool specialScratchpad: true
            property bool specialMusic: true
            property bool specialComms: true
            property bool specialTodo: true
            property bool specialSysmon: true
            property string specialMusicApps: "auto"
            property string specialCommsApps: "auto"
            property string specialTodoApps: "auto"
            property string specialSysmonApps: "auto"
            property bool specialKeepApps: true
            property bool specialHideOnSwitch: false
            property real specialDim: 0.2
            property bool specialBlur: false
            property int specialGaps: 0
            property string specialCustom: "[]"
            // the apps on the Glass page, and the ones given their own value
            property string glassApps: "vscodium"
            property string glassValues: "vscodium=0.9"
            // what Settings > Displays gave each output, and which one the shell sits on
            property string monitorSetups: "{}"
            property string monitorShellScreen: ""
            property string monitorBarScreen: ""
            property string monitorDockScreen: ""
            property bool clockShowSeconds: false
            property bool clockShowWeather: true
            property bool clockShowTimer: true
            property string clockWorldZones: "Europe/London,America/New_York,Asia/Tokyo"
            property int pomodoroFocus: 25
            property int pomodoroShort: 5
            property int pomodoroLong: 15
            property int pomodoroRounds: 4
            property bool pomodoroAutoStart: true
            property bool timerSound: true
            property bool weekStartMonday: true
            property string launcherSearchEngine: "duckduckgo"
            property bool launcherWebRow: true
            property string launcherWidth: "standard"
            property string launcherSearchPosition: "bottom"
            property string launcherDensity: "comfortable"
            property bool launcherModeBar: true
            property bool launcherActionHints: true
            property bool launcherFrequentFirst: true
            property bool launcherCalculator: true
            property bool launcherSettingsResults: true
            property real launcherContentScale: 1
            property string launcherHiddenApps: ""
            property string monitorWorkspaces: "{}"
        }

    }

}
