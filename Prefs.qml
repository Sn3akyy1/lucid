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
    readonly property int barPillRadius: Math.min(Theme.rad(18), Math.round(Theme.pill(Theme.dp(root.barHeight))))
    readonly property int effectiveBarTopMargin: root.barNotch ? 0 : Theme.dp(root.barTopMargin)
    readonly property int effectiveDockBottomMargin: root.dockNotch ? 0 : Theme.dp(root.dockBottomMargin)
    readonly property int dockItemRadius: Math.min(Theme.rad(root.dockRadius), Math.round(Theme.pill(Theme.dp(root.dockIconSize))))
    readonly property int dockIconInset: Math.max(0, Math.min(Theme.dp(root.dockIconPadding), Math.floor(Theme.dp(root.dockIconSize) / 2) - Theme.dp(6)))
    // the bar's layout reads through these: the groups in barLayout, keeping
    // only the modules switched on. the names are the zones' from before the
    // bar page's arrangement editor, so the bar itself needn't know the difference
    readonly property var barZones: ["left", "centre", "right"]
    readonly property var barLayoutKeys: ["barLayout"]

    function barModuleAt(key) {
        return root.barModuleById[key] || null;
    }

    function barShown(id) {
        const m = root.barModuleById[id];
        return !!m && root[m.key] === true;
    }

    readonly property var barLeftKeys: root.barLayoutGroups.left.filter((id) => {
        return root.barShown(id);
    })
    readonly property var barCentreKeys: root.barLayoutGroups.center.filter((id) => {
        return root.barShown(id);
    })
    readonly property var barRightKeys: root.barLayoutGroups.right.filter((id) => {
        return root.barShown(id);
    })

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

    // switching a module on or off; one going off keeps its slot until its
    // pill has emptied, so the neighbours close the gap at the rate it shrinks
    function setBarModuleShown(id, v) {
        const m = root.barModuleById[id];
        if (!m || (root[m.key] === true) === v)
            return ;

        const zone = root.barZoneOf(id);
        if (!v && zone !== "")
            root.barRetiring = ({ "key": id, "zone": zone, "at": root.barKeysOf(zone).indexOf(id) });

        root[m.key] = v;
    }

    readonly property var barPlacedKeys: root.barLeftKeys.concat(root.barCentreKeys, root.barRightKeys)

    function barSignature(keys) {
        return keys.slice().sort().join(",");
    }

    // bumped just before an arrangement change that only moves modules about,
    // so the bar can ease the pills across. switching one on or off is
    // deliberately not bumped: that animates the pill's own width, and every
    // neighbour's x already follows that frame by frame
    property int barReorderTick: 0

    // the module that has just left the bar, and the slot it had. the bar draws
    // it there until its pill has emptied, so the neighbours close the gap at
    // the rate it shrinks instead of dropping into it
    property var barRetiring: null

    function barClearRetiring() {
        root.barRetiring = null;
    }

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
        { "key": "gamemode", "icon": "sports_esports", "name": "Game" },
        { "key": "nightlight", "icon": "nightlight", "name": "Night light" },
        { "key": "sound", "icon": "volume_up", "name": "Sound" },
        { "key": "vpn", "icon": "vpn_key", "name": "VPN" },
        { "key": "dock", "icon": "dock_to_bottom", "name": "Dock" },
        { "key": "clipboard", "icon": "content_paste", "name": "Clipboard" },
        { "key": "emoji", "icon": "mood", "name": "Emoji" },
        { "key": "wallpaper", "icon": "wallpaper", "name": "Wallpaper" },
        { "key": "theme", "icon": "palette", "name": "Theme" },
        { "key": "widgets", "icon": "widgets", "name": "Widgets" },
        { "key": "lock", "icon": "lock", "name": "Lock" },
        { "key": "screenshot", "icon": "screenshot_monitor", "name": "Screen" },
        { "key": "ocr", "icon": "document_scanner", "name": "Scan text" },
        { "key": "overview", "icon": "grid_view", "name": "Overview" },
        { "key": "scratchpad", "icon": "stacks", "name": "Scratch" },
        { "key": "stopwatch", "icon": "av_timer", "name": "Stopwatch" },
        { "key": "phone", "icon": "phonelink_ring", "name": "Phone" },
        { "key": "keybinds", "icon": "keyboard_command_key", "name": "Shortcuts" },
        { "key": "settings", "icon": "settings", "name": "Settings" },
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

    // every bar module, in one place: the id barLayout arranges it by, the
    // show* pref that switches it on, the group it starts in, how Settings
    // names it, and where any settings it has elsewhere live (more, page), and,
    // for one that leaves the bar while it has nothing to show, when it is
    // there (when). the modules that came with the privacy, power and window
    // pills also name their options and looks (options, style, panelStyle);
    // BarStyleSample draws a sample of each look
    readonly property var barModules: [
    {
        "id": "workspaces",
        "key": "showWorkspaces",
        "home": "left",
        "name": "Workspaces",
        "desc": "Workspace pills and the expanded overview",
        "more": "Special workspaces, which it shows as well, have a page of their own.",
        "page": "workspaces",
        "options": ["workspacesShown", "workspacesWheel"],
        "style": "workspacesStyle",
        "styles": [
            {"key": "dots", "name": "Shapes", "blurb": "A dot while empty, a square in use, a new shape on the one you are on"},
            {"key": "numbers", "name": "Numbers", "blurb": "Each one's number, the empty ones quieter"}
        ]
    },
    {
        "id": "media",
        "key": "showMedia",
        "home": "left",
        "name": "Media",
        "desc": "Now-playing pill and player controls",
        "when": "while something plays",
        "options": ["mediaHideIdle", "mediaArtist", "mediaTitleWidth", "mediaPlayButton", "mediaWheelVolume"],
        "style": "mediaStyle",
        "styles": [
            {"key": "disc", "name": "Disc", "blurb": "The cover turning in a ring that fills as it plays"},
            {"key": "cover", "name": "Cover", "blurb": "The album's cover standing still, then the track"},
            {"key": "compact", "name": "Compact", "blurb": "Only the moving bars and the play button"}
        ],
        "panelStyle": "mediaPanelStyle",
        "panelStyles": [
            {"key": "side", "name": "Side by side", "blurb": "The cover beside the track"},
            {"key": "cover", "name": "Large cover", "blurb": "The cover across the panel, the track under it"}
        ]
    },
    {
        "id": "tray",
        "key": "showTray",
        "home": "left",
        "name": "Tray",
        "desc": "Status icons from running applications",
        "when": "while an app has an icon in the tray",
        "options": ["trayHidden", "trayIconColor"],
        "style": "trayStyle",
        "styles": [
            {"key": "collapsed", "name": "Collapsed", "blurb": "One icon and how many are running"},
            {"key": "icons", "name": "Icons", "blurb": "Each app's icon in the bar"}
        ]
    },
    {
        "id": "clock",
        "key": "showClock",
        "home": "center",
        "name": "Clock",
        "desc": "Time, date and the calendar panel",
        "more": "The time format, seconds, the temperature, whether the date shows and the time zone are on the Date & Time page.",
        "page": "datetime",
        "options": ["clockDateFormat"],
        "style": "clockStyle",
        "styles": [
            {"key": "accent", "name": "Accent", "blurb": "The date, then the time on an accent chip"},
            {"key": "inline", "name": "One line", "blurb": "The time, then the date"},
            {"key": "stacked", "name": "Two lines", "blurb": "The date small under the time"}
        ]
    },
    {
        "id": "notifications",
        "key": "showNotifications",
        "home": "right",
        "name": "Notifications",
        "desc": "Toasts and the notification list",
        "when": "while a notification is waiting",
        "more": "Do not disturb is just below; popups, sounds and quiet hours are on the Notifications page.",
        "page": "notifications",
        "style": "notificationsStyle",
        "styles": [
            {"key": "badge", "name": "Count", "blurb": "The bell and how many are waiting"},
            {"key": "dot", "name": "Dot", "blurb": "The bell with a dot while any are waiting"},
            {"key": "chip", "name": "Accent", "blurb": "Bell and count on the accent while any wait"}
        ]
    },
    {
        "id": "system",
        "key": "showSystem",
        "home": "right",
        "name": "System",
        "desc": "Battery, volume, brightness and quick settings",
        "more": "Its tiles are set with Edit tiles in the control centre itself; the keyboard layout sign and game mode are in System module, further down this page.",
        "page": ""
    },
    {
        "id": "privacy",
        "key": "showPrivacy",
        "home": "right",
        "name": "Privacy",
        "desc": "Shows up only while an app uses the microphone, the camera or the screen, and says which",
        "when": "while an app uses the microphone, the camera or the screen",
        "options": ["privacyWatch", "privacyToast", "privacyAlwaysShown"],
        "style": "privacyStyle",
        "styles": [
            {"key": "marks", "name": "Marks", "blurb": "A tinted mark for each thing in use"},
            {"key": "dot", "name": "Dot", "blurb": "One small dot, red while the screen is shared"}
        ]
    },
    {
        "id": "power",
        "key": "showPower",
        "home": "right",
        "name": "Power",
        "desc": "Lock, suspend, log out, restart or shut down, the ones you pick in the order you pick",
        "options": ["powerModuleActions", "powerModuleConfirm", "powerModuleUptime"],
        "style": "powerModuleStyle",
        "styles": [
            {"key": "icon", "name": "Icon", "blurb": "The power symbol"},
            {"key": "accent", "name": "Accent", "blurb": "The symbol on a circle in the accent"}
        ],
        "panelStyle": "powerModulePanelStyle",
        "panelStyles": [
            {"key": "list", "name": "List", "blurb": "One action to a row"},
            {"key": "grid", "name": "Grid", "blurb": "Three to a row, the name under each"}
        ]
    },
    {
        "id": "window",
        "key": "showWindow",
        "home": "left",
        "name": "Active window",
        "desc": "The focused window's icon and title; open it to float, pin, fullscreen, move or close it, or switch to another window on the workspace",
        "when": "while a window on this workspace has the focus",
        "options": ["windowModuleText", "windowModuleWidth", "windowModuleScroll", "windowModuleMiddleClose"],
        "style": "windowModuleStyle",
        "styles": [
            {"key": "plain", "name": "Plain", "blurb": "The icon and the text on the bar"},
            {"key": "chip", "name": "Chip", "blurb": "The same on a chip tinted with the accent"}
        ]
    }
    ]

    // the notification page's own header switch, which is the module's
    readonly property bool barNotifications: root.showNotifications
    readonly property bool anyBarModuleEnabled: root.barModules.some((m) => {
        return root[m.key] === true;
    })
    readonly property var barModuleKeys: root.barModules.map((m) => {
        return m.key;
    })
    readonly property var barModuleHome: {
        const out = {};
        for (const m of root.barModules)
            out[m.id] = m.home;
        return out;
    }
    // the module the Bar page opens on, set by a right click on its pill
    property string barModuleFocus: ""
    // the ids of the modules switched on that the bar leaves out right now,
    // having nothing to show (an empty tray); the bar keeps it up to date, and
    // a module's "when" in barModules says when it comes back
    property var barModulesAway: []

    function openBarModule(id) {
        root.barModuleFocus = id;
        root.settingsRequested("bar");
    }

    readonly property var barModuleById: {
        const out = {};
        for (const m of root.barModules)
            out[m.id] = m;
        return out;
    }
    readonly property var barLayoutGroups: root.parseBarLayout(root.barLayout)
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
    property alias uiScale: s.uiScale
    property alias cornerScale: s.cornerScale
    // room the bar and dock keep clear of windows, past their own size: added to
    // their exclusive zones, in real pixels like hyprland's gaps
    property alias shellGap: s.shellGap
    // the same clamp Theme.uiScale applies, for code that has to wait on Prefs.loaded
    readonly property real interfaceScale: Math.max(0.7, Math.min(1.3, root.uiScale || 1))
    property alias wallpaperFolder: s.wallpaperFolder
    // bracket writes on the adapter are dropped, so this must go through the alias
    property alias themeOrder: s.themeOrder
    // how matugen builds a palette, from the wallpaper or from themeColour: its
    // scheme type, contrast from -1 to 1, and which of the wallpaper's dominant
    // colours to start from (the index holds for matugenSourceImage only; any
    // other wallpaper starts from its most dominant)
    property alias matugenScheme: s.matugenScheme
    property alias matugenContrast: s.matugenContrast
    property alias matugenSourceImage: s.matugenSourceImage
    property alias matugenSourceIndex: s.matugenSourceIndex
    // the one colour the "colour" theme is built from
    property alias themeColour: s.themeColour
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
    property alias systemTiles: s.systemTiles
    property alias barLayout: s.barLayout
    property alias showWorkspaces: s.showWorkspaces
    property alias showMedia: s.showMedia
    property alias showTray: s.showTray
    property alias showKbLayout: s.showKbLayout
    property alias gameModeOnCmd: s.gameModeOnCmd
    property alias gameModeOffCmd: s.gameModeOffCmd
    property alias gameModeStatusCmd: s.gameModeStatusCmd

    // game mode, as the tile, the thermals card and the games widget run it. with
    // both commands left empty it is Lucid's own: animations, blur, shadows,
    // rounding and gaps off, their values kept inside hyprland and put back after,
    // so turning it off needs no reload (which would reset the keyboard layout)
    readonly property var gameModeKeys: ["animations.enabled", "decoration.blur.enabled", "decoration.shadow.enabled", "decoration.rounding", "general.gaps_in", "general.gaps_out"]
    readonly property string gameModeMarker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-gamemode"
    readonly property bool gameModeUsesDefault: root.gameModeOnCmd.trim() === "" && root.gameModeOffCmd.trim() === ""
    readonly property string gameModeDefaultOn: {
        const keys = root.gameModeKeys.map((k) => {
            return JSON.stringify(k);
        }).join(", ");
        const off = "[\"animations.enabled\"] = false, [\"decoration.blur.enabled\"] = false, [\"decoration.shadow.enabled\"] = false, [\"decoration.rounding\"] = 0, [\"general.gaps_in\"] = 0, [\"general.gaps_out\"] = 0";
        const lua = "LucidGameMode = LucidGameMode or {} for _, k in ipairs({ " + keys + " }) do if LucidGameMode[k] == nil then local ok, v = pcall(hl.get_config, k) if ok then LucidGameMode[k] = v end end end hl.config({ " + off + " })";
        return "hyprctl eval '" + lua + "' && touch '" + root.gameModeMarker + "'";
    }
    readonly property string gameModeDefaultOff: "rm -f '" + root.gameModeMarker + "'; hyprctl eval 'if LucidGameMode then for k, v in pairs(LucidGameMode) do pcall(hl.config, { [k] = v }) end LucidGameMode = nil end'"
    readonly property string gameModeOnRun: root.gameModeUsesDefault ? root.gameModeDefaultOn : root.gameModeOnCmd
    readonly property string gameModeOffRun: root.gameModeUsesDefault ? root.gameModeDefaultOff : root.gameModeOffCmd
    readonly property string gameModeStatusRun: root.gameModeStatusCmd.trim() !== "" ? root.gameModeStatusCmd : (root.gameModeUsesDefault ? "test -f '" + root.gameModeMarker + "'" : "")
    readonly property bool gameModeConfigured: root.gameModeUsesDefault || (root.gameModeOnCmd.trim() !== "" && root.gameModeOffCmd.trim() !== "")

    readonly property string gameModeStateFile: {
        const m = /(?:test|\[)\s+-[ef]\s+(\S+)/.exec(root.gameModeStatusRun || "");
        return m ? m[1].replace(/^['"]|['"]$/g, "") : "";
    }
    property alias showClock: s.showClock
    property alias showNotifications: s.showNotifications
    property alias showSystem: s.showSystem
    property alias showPrivacy: s.showPrivacy
    property alias privacyWatch: s.privacyWatch
    property alias privacyToast: s.privacyToast
    property alias privacyAlwaysShown: s.privacyAlwaysShown
    property alias privacyStyle: s.privacyStyle
    property alias showPower: s.showPower
    property alias powerModuleActions: s.powerModuleActions
    property alias powerModuleConfirm: s.powerModuleConfirm
    property alias powerModuleUptime: s.powerModuleUptime
    property alias powerModuleStyle: s.powerModuleStyle
    property alias powerModulePanelStyle: s.powerModulePanelStyle
    property alias showWindow: s.showWindow
    property alias windowModuleText: s.windowModuleText
    property alias windowModuleWidth: s.windowModuleWidth
    property alias windowModuleScroll: s.windowModuleScroll
    property alias windowModuleMiddleClose: s.windowModuleMiddleClose
    property alias windowModuleStyle: s.windowModuleStyle
    property alias workspacesByDisplay: s.workspacesByDisplay
    property alias audioMeters: s.audioMeters
    property alias clockStyle: s.clockStyle
    property alias clockDateFormat: s.clockDateFormat
    property alias mediaStyle: s.mediaStyle
    property alias mediaPanelStyle: s.mediaPanelStyle
    property alias mediaHideIdle: s.mediaHideIdle
    property alias mediaArtist: s.mediaArtist
    property alias mediaTitleWidth: s.mediaTitleWidth
    property alias mediaPlayButton: s.mediaPlayButton
    property alias mediaWheelVolume: s.mediaWheelVolume
    property alias workspacesStyle: s.workspacesStyle
    property alias workspacesShown: s.workspacesShown
    property alias workspacesWheel: s.workspacesWheel
    property alias notificationsStyle: s.notificationsStyle
    property alias trayStyle: s.trayStyle
    property alias trayIconColor: s.trayIconColor
    property alias trayHidden: s.trayHidden
    property alias clock24h: s.clock24h
    property alias clockShowDate: s.clockShowDate
    property alias gpsEnabled: s.gpsEnabled
    property alias locationName: s.locationName
    property alias locationLabel: s.locationLabel
    property alias locationLat: s.locationLat
    property alias locationLon: s.locationLon
    property alias nightLight: s.nightLight
    property alias nightLightTemp: s.nightLightTemp
    property alias nightLightSchedule: s.nightLightSchedule
    property alias nightLightFrom: s.nightLightFrom
    property alias nightLightTo: s.nightLightTo
    property alias locationTz: s.locationTz
    property alias timeZoneAuto: s.timeZoneAuto
    property alias doNotDisturb: s.doNotDisturb
    readonly property bool osdNotch: root.osdStyle === "notch"
    // caps lock, num lock and the microphone show as a toast instead of on the osd
    readonly property bool osdTogglesToast: root.osdToggles === "toast"
    property alias osdStyle: s.osdStyle
    property alias osdToggles: s.osdToggles
    property alias toastTimeout: s.toastTimeout
    property alias toastOnLayout: s.toastOnLayout
    property alias toastOnGameMode: s.toastOnGameMode
    property alias toastOnBattery: s.toastOnBattery
    property alias toastOnBluetooth: s.toastOnBluetooth
    property alias toastOnWifi: s.toastOnWifi
    property alias toastOnAudio: s.toastOnAudio
    property alias toastOnDisplays: s.toastOnDisplays
    property alias toastOnPower: s.toastOnPower
    property alias toastOnUsb: s.toastOnUsb
    property alias toastOnCamera: s.toastOnCamera
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
    property alias sysSounds: s.sysSounds
    property alias sysSoundVolume: s.sysSoundVolume
    property alias soundOnUsb: s.soundOnUsb
    property alias soundOnBluetooth: s.soundOnBluetooth
    property alias soundOnCharger: s.soundOnCharger
    property alias soundOnBattery: s.soundOnBattery
    property alias soundOnCapture: s.soundOnCapture
    property alias soundOnCamera: s.soundOnCamera
    property alias soundOnVolume: s.soundOnVolume
    property alias soundOnBrightness: s.soundOnBrightness
    property alias soundOnCaps: s.soundOnCaps
    property alias soundOnMic: s.soundOnMic
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
    property alias storageLowWarn: s.storageLowWarn
    property alias storageLowPercent: s.storageLowPercent
    // 0 means never
    property alias storageTrashDays: s.storageTrashDays

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
    // Hyprland options set from Settings > Windows, as JSON { "general.gaps_in": 8, ... }
    property alias hyprOptions: s.hyprOptions

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
    property alias pomodoroAutoFocus: s.pomodoroAutoFocus
    property alias pomodoroRepeat: s.pomodoroRepeat
    property alias pomodoroSilence: s.pomodoroSilence
    property alias pomodoroGoal: s.pomodoroGoal
    property alias timerSound: s.timerSound
    property alias reminderSound: s.reminderSound
    property alias weekStartMonday: s.weekStartMonday
    property alias launcherSearchEngine: s.launcherSearchEngine
    property alias launcherWebRow: s.launcherWebRow
    property alias launcherWindows: s.launcherWindows
    property alias launcherAppActions: s.launcherAppActions
    property alias launcherAppDescriptions: s.launcherAppDescriptions
    property alias launcherPowerSearch: s.launcherPowerSearch
    property alias launcherAddressFirst: s.launcherAddressFirst
    property alias launcherPowerChips: s.launcherPowerChips
    property alias launcherPowerButtons: s.launcherPowerButtons
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
    readonly property real launcherScale: Math.max(0.8, Math.min(1.4, root.launcherContentScale)) * Theme.uiScale
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
    readonly property int launcherLeadSlot: Math.max(Theme.dp(24), Math.min(Math.round(40 * root.launcherScale), root.launcherRowOne - Theme.dp(8)))
    readonly property int launcherEdgeSpace: Math.round(16 * root.launcherScale)
    readonly property int launcherBetweenSpace: Math.round(12 * root.launcherScale)
    readonly property int launcherRowGap: root.launcherDense ? Theme.dp(2) : Theme.dp(4)
    readonly property int launcherListPad: Theme.dp(8)
    // m3 search bar container height
    readonly property int launcherSearchH: Math.round(56 * root.launcherScale)
    // the head band: the mark, the mode set and the count
    readonly property int launcherHeadH: Math.round(38 * root.launcherScale)
    readonly property int launcherHeadGap: Math.round(10 * root.launcherScale)
    readonly property int launcherContentGap: Theme.dp(12)

    readonly property int launcherChromeH: root.launcherSearchH + (root.launcherModeBar ? root.launcherHeadH + root.launcherHeadGap : 0) + root.launcherContentGap

    // every settings page, for the app's rail and for the launcher's search
    readonly property var settingsPages: [
        { "key": "users", "icon": "account_circle", "keys": "user account password avatar login admin sudo", "group": "Account", "label": "Account", "title": "Users and Accounts", "blurb": "Who may sign in to this machine, what they are called and what they are allowed to do", "hidden": true },
        { "key": "general", "icon": "tune", "keys": "style islands notches osd accent darkness surface tint motion animation speed font scale typography interface size zoom smaller bigger density", "group": "Appearance", "label": "General", "title": "General", "blurb": "Size, shape, colour and motion across the whole shell" },
        { "key": "glass", "icon": "blur_on", "keys": "blur transparency opacity translucent frosted kitty terminal windows", "group": "Appearance", "label": "Glass", "title": "Glass", "blurb": "How far the desktop shows through the shell, the terminal and your windows" },
        { "key": "theme", "icon": "palette", "keys": "colour color scheme wallpaper matugen pywal catppuccin gruvbox nord dark light mode import", "group": "Appearance", "label": "Theme", "title": "Theme and Appearance", "blurb": "Colour schemes, wallpapers and themes you import" },
        { "key": "colours", "icon": "format_color_fill", "keys": "matugen style scheme contrast your colour hex picker templates apps render variables", "group": "Appearance", "label": "Colours", "title": "Colours", "blurb": "How Matugen and Your colour build a palette, the applications that follow it, and templates of your own" },
        { "key": "palettes", "icon": "colors", "keys": "gallery schemes base16 base24 tinted import repo file editor export", "group": "Appearance", "label": "Palettes", "title": "Palettes", "blurb": "A gallery of colour schemes, and themes from a repo or a file" },
        { "key": "environment", "icon": "format_paint", "keys": "cursor icons gtk qt fonts application theme", "group": "Appearance", "label": "Environment", "title": "Environment", "blurb": "Cursors, icons, fonts and application themes, across GTK, Qt and Hyprland alike" },
        { "key": "bar", "icon": "toolbar", "keys": "status height margin spacing modules workspaces clock media tray system popup", "group": "Desktop", "label": "Bar", "title": "Bar", "blurb": "The status bar, its modules and how they open", "toggle": "barEnabled" },
        { "key": "dock", "icon": "dock_to_bottom", "keys": "icons size magnify autohide pinned running indicators tooltips windows notch radius corners rounding padding inset", "group": "Desktop", "label": "Dock", "title": "Dock", "blurb": "The dock, its icons and how it behaves", "toggle": "dockEnabled" },
        { "key": "launcher", "icon": "search", "keys": "launcher search spotlight apps results width density rows chips modes prefix engine web emoji run clipboard calculator frequent recent", "group": "Desktop", "label": "Launcher", "title": "Launcher", "blurb": "The search panel the dock opens into: how wide it is, how its results read, and what it looks through" },
        { "key": "widgets", "icon": "widgets", "keys": "desktop cards clock calendar weather presets", "group": "Desktop", "label": "Widgets", "title": "Widgets", "blurb": "Cards you place on the desktop and arrange yourself", "toggle": "widgetsEnabled" },
        { "key": "windows", "icon": "select_window", "keys": "hyprland gaps exclusive zone reserved distance shell bar dock borders border colour rounding corners shadow dim tiling layout dwindle master scrolling focus follow mouse cursor resize snap animations", "group": "Desktop", "label": "Windows", "title": "Windows", "blurb": "How Hyprland draws your windows, tiles them and hands them the focus" },
        { "key": "workspaces", "icon": "workspaces", "keys": "special scratchpad music chat todo sysmon", "group": "Desktop", "label": "Workspaces", "title": "Special Workspaces", "blurb": "Your music, chat, to-do list and a scratchpad, each one key away and gone again with the same key" },
        { "key": "keybinds", "icon": "keyboard", "keys": "shortcuts hotkeys keys bindings hyprland super binds", "group": "Desktop", "label": "Keybinds", "title": "Keybinds", "blurb": "Every Hyprland shortcut: change one, switch it off or add your own" },
        { "key": "input", "icon": "mouse", "keys": "keyboard layout layouts xkb caps lock repeat numlock mouse pointer speed acceleration touchpad tap natural scroll gestures swipe", "group": "Devices", "label": "Input", "title": "Input", "blurb": "Keyboard layouts and key repeat, the mouse, the touchpad and its gestures" },
        { "key": "displays", "icon": "desktop_windows", "keys": "monitor screen resolution refresh rate scale vrr arrangement", "group": "Devices", "label": "Displays", "title": "Displays", "blurb": "Every screen this machine has: resolution, refresh rate, scale, how they are arranged and which one the shell sits on" },
        { "key": "sound", "icon": "volume_up", "keys": "audio volume speakers microphone output input devices system sounds chime usb bluetooth charger battery screenshot camera", "group": "Devices", "label": "Sound", "title": "Sound", "blurb": "Which speakers play and which microphone listens, what each application is using, and how loud any of it is" },
        { "key": "network", "icon": "wifi", "keys": "wifi ethernet vpn dns ip proxy internet", "group": "Devices", "label": "Network", "title": "Network", "blurb": "Wi-Fi, wired, VPN and how this machine gets its address" },
        { "key": "bluetooth", "icon": "bluetooth", "keys": "devices pair headphones", "group": "Devices", "label": "Bluetooth", "title": "Bluetooth and Devices", "blurb": "The radio, what it is paired with, and the phone you connect to it" },
        { "key": "kdeconnect", "icon": "smartphone", "keys": "phone kde connect files notifications clipboard", "group": "Devices", "label": "Phone", "title": "Phone", "blurb": "Your phone on this machine over KDE Connect: files, notifications, clipboard and a remote", "toggle": "kdeConnectEnabled" },
        { "key": "notifications", "icon": "notifications", "keys": "popups toasts do not disturb dnd quiet hours sound muted apps caps lock num lock microphone", "group": "System", "label": "Notifications", "title": "Notifications", "blurb": "Popups, quiet hours, sound and which applications may interrupt you", "toggle": "barNotifications" },
        { "key": "idle", "icon": "bedtime", "keys": "sleep suspend lock dim screen off hypridle caffeine", "group": "System", "label": "Idle", "title": "Idle and Sleep", "blurb": "What happens when you walk away: dimming, locking, screen off and suspend", "toggle": "idleEnabled" },
        { "key": "datetime", "icon": "schedule", "keys": "clock time zone location 24 hour seconds week monday sunday timer pomodoro focus break alarm world", "group": "System", "label": "Date & Time", "title": "Date and Time", "blurb": "Where you are, the clock, and its timers" },
        { "key": "storage", "icon": "hard_drive", "keys": "disk space storage usage free full clean cleanup cache trash duplicates large files drives ssd health smart trim mount", "group": "System", "label": "Storage", "title": "Storage", "blurb": "What fills your drives, what could go, and the drives themselves" },
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
        { "id": "tokyo-night", "name": "Tokyo Night", "desc": "Dark blues and violets", "swatchBg": "#1a1b26", "swatchAccent": "#7aa2f7" },
        { "id": "colour", "name": "Your colour", "desc": "A palette built from one colour you pick", "swatchBg": "#14121a", "swatchAccent": root.themeColour }
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
        "uiScale": 1,
        "cornerScale": 1,
        "shellGap": 0,
        "wallpaperFolder": "",
        "themeOrder": "",
        "matugenScheme": "scheme-tonal-spot",
        "matugenContrast": 0,
        "matugenSourceImage": "",
        "matugenSourceIndex": 0,
        "themeColour": "#6750a4",
        "barEnabled": true,
        "barPopupMode": false,
        "barPopupGap": 10,
        "barHeight": 35,
        "barTopMargin": 22,
        "barSideMargin": 17,
        "barSpacing": 8,
        "barHoverGrow": 3,
        "barZoneGap": 26,
        "systemTiles": "dnd,awake,dark,airplane,location,mic,capture,record,picker,keyboard,timer,session",
        "barLayout": "{\"left\":[\"workspaces\",\"media\",\"tray\"],\"center\":[\"clock\"],\"right\":[\"notifications\",\"system\"]}",
        "showWorkspaces": true,
        "showMedia": true,
        "showTray": true,
        "showKbLayout": true,
        "gameModeOnCmd": "",
        "gameModeOffCmd": "",
        "gameModeStatusCmd": "",
        "showClock": true,
        "showNotifications": true,
        "showSystem": true,
        "showPrivacy": false,
        "privacyWatch": "mic,camera,screen",
        "privacyToast": true,
        "privacyAlwaysShown": false,
        "privacyStyle": "marks",
        "showPower": false,
        "powerModuleActions": "lock,suspend,hibernate,logout,reboot,shutdown",
        "powerModuleConfirm": true,
        "powerModuleUptime": true,
        "powerModuleStyle": "icon",
        "powerModulePanelStyle": "list",
        "showWindow": false,
        "windowModuleText": "title",
        "windowModuleWidth": 260,
        "windowModuleScroll": true,
        "windowModuleMiddleClose": false,
        "windowModuleStyle": "plain",
        "workspacesByDisplay": true,
        "audioMeters": true,
        "clockStyle": "accent",
        "clockDateFormat": "dayMonth",
        "mediaStyle": "disc",
        "mediaPanelStyle": "side",
        "mediaHideIdle": false,
        "mediaArtist": true,
        "mediaTitleWidth": 170,
        "mediaPlayButton": true,
        "mediaWheelVolume": true,
        "workspacesStyle": "dots",
        "workspacesShown": 6,
        "workspacesWheel": true,
        "notificationsStyle": "badge",
        "trayStyle": "collapsed",
        "trayIconColor": "original",
        "trayHidden": "",
        "clock24h": false,
        "clockShowDate": true,
        "gpsEnabled": false,
        "locationName": "",
        "locationLabel": "",
        "locationLat": 52.4083,
        "locationLon": 16.9336,
        "nightLight": false,
        "nightLightTemp": 4000,
        "nightLightSchedule": "off",
        "nightLightFrom": 1260,
        "nightLightTo": 420,
        "locationTz": "",
        "timeZoneAuto": true,
        "doNotDisturb": false,
        "osdStyle": "island",
        "osdToggles": "osd",
        "toastTimeout": 5,
        "toastOnLayout": true,
        "toastOnGameMode": true,
        "toastOnBattery": true,
        "toastOnBluetooth": true,
        "toastOnWifi": true,
        "toastOnAudio": true,
        "toastOnDisplays": true,
        "toastOnPower": true,
        "toastOnUsb": true,
        "toastOnCamera": true,
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
        "notifSoundName": "glint",
        "notifSoundVolume": 0.6,
        "notifSoundUrgentOnly": false,
        "sysSounds": true,
        "sysSoundVolume": 0.6,
        "soundOnUsb": true,
        "soundOnBluetooth": true,
        "soundOnCharger": true,
        "soundOnBattery": true,
        "soundOnCapture": true,
        "soundOnCamera": true,
        "soundOnVolume": true,
        "soundOnBrightness": true,
        "soundOnCaps": true,
        "soundOnMic": true,
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
        "storageLowWarn": true,
        "storageLowPercent": 10,
        "storageTrashDays": 0,
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
        "hyprOptions": "{}",
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
        "pomodoroAutoFocus": true,
        "pomodoroRepeat": true,
        "pomodoroSilence": false,
        "pomodoroGoal": 0,
        "timerSound": true,
        "reminderSound": true,
        "weekStartMonday": true,
        "launcherSearchEngine": "duckduckgo",
        "launcherWebRow": true,
        "launcherWindows": true,
        "launcherAppActions": true,
        "launcherAppDescriptions": false,
        "launcherPowerSearch": true,
        "launcherAddressFirst": true,
        "launcherPowerChips": false,
        "launcherPowerButtons": "lock,suspend,reboot,shutdown",
        "launcherWidth": "standard",
        "launcherSearchPosition": "bottom",
        "launcherDensity": "compact",
        "launcherModeBar": true,
        "launcherActionHints": true,
        "launcherFrequentFirst": true,
        "launcherCalculator": true,
        "launcherSettingsResults": true,
        "launcherContentScale": 0.8,
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
        root.barReorderTick++;
        root.resetKeys(root.barLayoutKeys.concat(root.barModuleKeys));
        root.barEnabled = true;
    }

    // barLayout is JSON: {"left": [...], "center": [...], "right": [...]}, each
    // list in order from the screen's left edge. a module it leaves out (a hand
    // edit, a module added later) goes back to the end of its home group and an
    // unknown or repeated id is skipped, so every module always has a place
    function parseBarLayout(text) {
        let parsed = null;
        try {
            parsed = JSON.parse(text);
        } catch (e) {
        }
        const out = {
            "left": [],
            "center": [],
            "right": []
        };
        const seen = {};
        for (const side of ["left", "center", "right"]) {
            const ids = parsed && Array.isArray(parsed[side]) ? parsed[side] : [];
            for (const id of ids) {
                if (root.barModuleHome[id] === undefined || seen[id])
                    continue;

                seen[id] = true;
                out[side].push(id);
            }
        }
        for (const id in root.barModuleHome) {
            if (!seen[id])
                out[root.barModuleHome[id]].push(id);

        }
        return out;
    }

    function setBarLayout(groups) {
        // before the write, or the x bindings re-evaluate before the bar knows
        // this one is worth easing
        root.barReorderTick++;
        root.barLayout = JSON.stringify({
            "left": groups.left,
            "center": groups.center,
            "right": groups.right
        });
    }

    // on means the modules that ship switched on; one that ships off stays off
    function setAllBarModules(v) {
        for (const m of root.barModules)
            root[m.key] = v && root.defaults[m.key] === true;
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
            root.setBarModuleShown("notifications", v);
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
            property real uiScale: 1
            property real cornerScale: 1
            property int shellGap: 0
            property string wallpaperFolder: ""
            property string themeOrder: ""
            property string matugenScheme: "scheme-tonal-spot"
            property real matugenContrast: 0
            property string matugenSourceImage: ""
            property int matugenSourceIndex: 0
            property string themeColour: "#6750a4"
            property bool barEnabled: true
            property bool barPopupMode: false
            property int barPopupGap: 10
            property int barHeight: 35
            property int barTopMargin: 22
            property int barSideMargin: 17
            property int barSpacing: 8
            property int barHoverGrow: 3
            property int barZoneGap: 26
            property string systemTiles: "dnd,awake,dark,airplane,location,mic,capture,record,picker,keyboard,timer,session"
            property string barLayout: "{\"left\":[\"workspaces\",\"media\",\"tray\"],\"center\":[\"clock\"],\"right\":[\"notifications\",\"system\"]}"
            property bool showWorkspaces: true
            property bool showMedia: true
            property bool showTray: true
            property bool showKbLayout: true
            property string gameModeOnCmd: ""
            property string gameModeOffCmd: ""
            property string gameModeStatusCmd: ""
            property bool showClock: true
            property bool showNotifications: true
            property bool showSystem: true
            property bool showPrivacy: false
            property string privacyWatch: "mic,camera,screen"
            property bool privacyToast: true
            property bool privacyAlwaysShown: false
            property string privacyStyle: "marks"
            property bool showPower: false
            property string powerModuleActions: "lock,suspend,hibernate,logout,reboot,shutdown"
            property bool powerModuleConfirm: true
            property bool powerModuleUptime: true
            property string powerModuleStyle: "icon"
            property string powerModulePanelStyle: "list"
            property bool showWindow: false
            property string windowModuleText: "title"
            property int windowModuleWidth: 260
            property bool windowModuleScroll: true
            property bool windowModuleMiddleClose: false
            property string windowModuleStyle: "plain"
            property bool workspacesByDisplay: true
            property bool audioMeters: true
            property string clockStyle: "accent"
            property string clockDateFormat: "dayMonth"
            property string mediaStyle: "disc"
            property string mediaPanelStyle: "side"
            property bool mediaHideIdle: false
            property bool mediaArtist: true
            property int mediaTitleWidth: 170
            property bool mediaPlayButton: true
            property bool mediaWheelVolume: true
            property string workspacesStyle: "dots"
            property int workspacesShown: 6
            property bool workspacesWheel: true
            property string notificationsStyle: "badge"
            property string trayStyle: "collapsed"
            property string trayIconColor: "original"
            property string trayHidden: ""
            property bool clock24h: false
            property bool clockShowDate: true
            property bool gpsEnabled: false
            property string locationName: ""
            property string locationLabel: ""
            property real locationLat: 52.4083
            property real locationLon: 16.9336
            property bool nightLight: false
            property int nightLightTemp: 4000
            property string nightLightSchedule: "off"
            property int nightLightFrom: 1260
            property int nightLightTo: 420
            property string locationTz: ""
            property bool timeZoneAuto: true
            property bool doNotDisturb: false
            property string osdStyle: "island"
            property string osdToggles: "osd"
            property int toastTimeout: 5
            property bool toastOnLayout: true
            property bool toastOnGameMode: true
            property bool toastOnBattery: true
            property bool toastOnBluetooth: true
            property bool toastOnWifi: true
            property bool toastOnAudio: true
            property bool toastOnDisplays: true
            property bool toastOnPower: true
            property bool toastOnUsb: true
            property bool toastOnCamera: true
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
            property string notifSoundName: "glint"
            property real notifSoundVolume: 0.6
            property bool notifSoundUrgentOnly: false
            property bool sysSounds: true
            property real sysSoundVolume: 0.6
            property bool soundOnUsb: true
            property bool soundOnBluetooth: true
            property bool soundOnCharger: true
            property bool soundOnBattery: true
            property bool soundOnCapture: true
            property bool soundOnCamera: true
            property bool soundOnVolume: true
            property bool soundOnBrightness: true
            property bool soundOnCaps: true
            property bool soundOnMic: true
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
            property bool storageLowWarn: true
            property int storageLowPercent: 10
            property int storageTrashDays: 0
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
            property string hyprOptions: "{}"
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
            property bool pomodoroAutoFocus: true
            property bool pomodoroRepeat: true
            property bool pomodoroSilence: false
            property int pomodoroGoal: 0
            property bool timerSound: true
            property bool reminderSound: true
            property bool weekStartMonday: true
            property string launcherSearchEngine: "duckduckgo"
            property bool launcherWebRow: true
            property bool launcherWindows: true
            property bool launcherAppActions: true
            property bool launcherAppDescriptions: false
            property bool launcherPowerSearch: true
            property bool launcherAddressFirst: true
            property bool launcherPowerChips: false
            property string launcherPowerButtons: "lock,suspend,reboot,shutdown"
            property string launcherWidth: "standard"
            property string launcherSearchPosition: "bottom"
            property string launcherDensity: "compact"
            property bool launcherModeBar: true
            property bool launcherActionHints: true
            property bool launcherFrequentFirst: true
            property bool launcherCalculator: true
            property bool launcherSettingsResults: true
            property real launcherContentScale: 0.8
            property string launcherHiddenApps: ""
            property string monitorWorkspaces: "{}"
        }

    }

}
