import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// LucidShell's settings model. One singleton, one JSON file, reached from
// every corner of the shell the same way: `import qs` + `Prefs.<key>`.
//
// This deliberately lives at the config root rather than inside lucidprefs/,
// because `import qs` resolves to the config root and is the only import that
// every other directory here can agree on - lucidbar/ files reach it the same
// way luciddocks/ files already reach Theme. Verified directly: a lucidbar
// file with an explicit `import qs` resolves to the root copy of a type, and
// an explicit import outranks the implicit same-directory one.
//
// Persistence follows Theme.qml's blur.json precedent exactly: writes to a
// JSON file under the config dir do NOT trigger a shell reload, and
// watchChanges keeps every reader honest if the file is edited from outside.
Singleton {
    id: root

    // False until the file below has actually been read, so callers can tell a
    // real setting from the adapter's declared default. It is driven off the
    // FileView's own signals and NOT off Component.onCompleted: blockLoading
    // does not make the values available that early - the singleton finishes
    // constructing while every property is still its default, and the file
    // lands a beat later.
    //
    // Anything committed to the compositor has to wait for this. A layer
    // surface's margin is applied when the surface is mapped, and later
    // changes made in that first pass are dropped, so a bar mapped against the
    // defaults kept the island style's 22px margin for the whole session - a
    // notch bar sat off the top edge until the style was touched by hand.
    property bool loaded: false


    // ---------------- derived convenience ----------------
    readonly property bool barNotch: root.barStyle === "notch"
    readonly property bool dockNotch: root.dockStyle === "notch"
    // notches sit flush against the screen edge by definition
    // The pill's rounded end, capped. It used to be written as a radius far
    // larger than any pill (60) and left to Qt's clamp at half the height,
    // which meant the corner grew with the bar - at 40px tall it reached 20
    // where at 35px it was 17.5. Capping it holds the shape steady and keeps
    // the compositor's blur bleed from having a longer curve to trace.
    readonly property int barPillRadius: Math.min(18, Math.round(root.barHeight / 2))
    readonly property int effectiveBarTopMargin: root.barNotch ? 0 : root.barTopMargin
    // The inline pill's round ends would eat into the first and last module,
    // so the module rows are pushed in past the curve. That inset lives in
    // shell.qml rather than here: it has to be latched across a mode switch
    // so the rows animate to it instead of jumping, which a plain derived
    // value cannot do.
    readonly property int effectiveDockBottomMargin: root.dockNotch ? 0 : root.dockBottomMargin

    // ---------------- General ----------------
    property alias barStyle: s.barStyle
    property alias dockStyle: s.dockStyle
    property alias accentPunch: s.accentPunch
    property alias surfaceDarkness: s.surfaceDarkness
    property alias motionScale: s.motionScale
    property alias fontFamily: s.fontFamily
    property alias fontScale: s.fontScale
    property alias wallpaperFolder: s.wallpaperFolder

    // ---------------- Bar ----------------
    property alias barPopupMode: s.barPopupMode
    property alias barPopupGap: s.barPopupGap
    property alias barHeight: s.barHeight
    property alias barTopMargin: s.barTopMargin
    property alias barSideMargin: s.barSideMargin
    property alias barSpacing: s.barSpacing
    property alias showWorkspaces: s.showWorkspaces
    property alias showMedia: s.showMedia
    property alias showTray: s.showTray
    property alias showClock: s.showClock
    property alias showBluetooth: s.showBluetooth
    property alias showNetwork: s.showNetwork
    property alias showNotifications: s.showNotifications
    property alias showSystem: s.showSystem
    property alias clock24h: s.clock24h
    property alias clockShowDate: s.clockShowDate
    property alias doNotDisturb: s.doNotDisturb
    property alias toastTimeout: s.toastTimeout

    // ---------------- Dock ----------------
    property alias dockIconSize: s.dockIconSize
    property alias dockSpacing: s.dockSpacing
    property alias dockBottomMargin: s.dockBottomMargin
    property alias dockMagnify: s.dockMagnify
    property alias dockAutoHide: s.dockAutoHide
    property alias dockShowIndicators: s.dockShowIndicators
    property alias dockShowTooltips: s.dockShowTooltips
    property alias dockShowRunning: s.dockShowRunning

    // The theme catalogue is shell data rather than a preference, but it
    // lives here so the launcher's >theme strip and the settings app read one
    // list instead of two copies that drift apart the first time a theme is
    // added. Dock.qml's allThemes binds straight to this.
    readonly property var themeCatalogue: [
        { "id": "matugen", "name": "Matugen", "desc": "Colors generated from your wallpaper", "swatchBg": "#12171a", "swatchAccent": "#8ad0ee" },
        { "id": "pywal", "name": "Pywal", "desc": "Wallpaper colors via pywal's classic palette", "swatchBg": "#1a1e24", "swatchAccent": "#c9a1a9" },
        { "id": "catppuccin-mocha", "name": "Catppuccin Mocha", "desc": "Soothing pastel dark theme", "swatchBg": "#1e1e2e", "swatchAccent": "#89b4fa" },
        { "id": "gruvbox", "name": "Gruvbox", "desc": "Retro groove warm palette", "swatchBg": "#282828", "swatchAccent": "#83a598" },
        { "id": "nightfox", "name": "Nightfox", "desc": "Deep navy with muted blue accents", "swatchBg": "#192330", "swatchAccent": "#719cd6" },
        { "id": "nord", "name": "Nord", "desc": "Arctic blue-grey palette", "swatchBg": "#232831", "swatchAccent": "#88c0d0" },
        { "id": "tokyo-night", "name": "Tokyo Night", "desc": "Dark blues and violets", "swatchBg": "#1a1b26", "swatchAccent": "#7aa2f7" }
    ]

    // every default in one place so "Reset to defaults" and the adapter's
    // own initial values can never drift apart
    readonly property var defaults: ({
        "barStyle": "island",
        "dockStyle": "island",
        "accentPunch": 1,
        "surfaceDarkness": -1,
        "motionScale": 1,
        "fontFamily": "Google Sans",
        "fontScale": 1,
        "wallpaperFolder": "",
        "barPopupMode": false,
        "barPopupGap": 10,
        "barHeight": 35,
        "barTopMargin": 22,
        "barSideMargin": 17,
        "barSpacing": 8,
        "showWorkspaces": true,
        "showMedia": true,
        "showTray": true,
        "showClock": true,
        "showBluetooth": true,
        "showNetwork": true,
        "showNotifications": true,
        "showSystem": true,
        "clock24h": false,
        "clockShowDate": true,
        "doNotDisturb": false,
        "toastTimeout": 5,
        "dockIconSize": 46,
        "dockSpacing": 10,
        "dockBottomMargin": 20,
        "dockMagnify": true,
        "dockAutoHide": false,
        "dockShowIndicators": true,
        "dockShowTooltips": true,
        "dockShowRunning": true
    })

    // the dock owns its pinned list; this is how the settings app asks for a
    // reset without either side importing the other
    signal pinnedResetRequested()
    // and the reverse direction: the launcher's >settings command asks the
    // settings app to open, without either file importing the other
    signal settingsRequested(string page)
    // Every reset in the app - the per-setting ones, the dock's pinned list
    // and "Reset all" - raises this instead of acting directly, so the
    // confirmation step lives in exactly one place (Settings.qml hosts the
    // dialog) rather than being re-implemented per button. `action` is either
    // a settings key or one of the RESET_* tokens below.
    signal resetConfirmRequested(string title, string body, string confirmLabel, string action)
    // the wallpaper grid owns the actual deletion; this is how the confirmed
    // dialog reaches back into the page that raised it
    signal wallpaperDeleteRequested(string path)
    // Raised whenever the settings app adds or removes a file from the
    // wallpaper folder. The dock scans that folder into its own model and only
    // re-scans when its strip opens or the theme changes - so without this, a
    // wallpaper deleted while the strip was already open stayed on screen, and
    // a newly added one didn't show up.
    signal wallpapersChanged()

    readonly property string resetAllToken: "__all__"
    readonly property string resetDockToken: "__dock__"
    readonly property string resetBlurToken: "__blur__"

    // Theme switching is the dock's job, not the settings app's: switchTheme()
    // there also probes the new theme's wallpaper folder and applies a
    // wallpaper from it. The settings app raising this instead of writing
    // ~/.cache/current_theme itself is what keeps the two surfaces from
    // drifting - one implementation, so the wallpaper follows and the
    // launcher's own checkmark updates from the same write.
    signal themeChangeRequested(string id)

    // the font picker is hosted at window level (a dropdown inside the page
    // would be clipped by the scrolling area), so the row asks for it the same
    // way the reset buttons ask for their dialog
    signal fontPickerRequested()

    function askReset(title, body, action) {
        root.resetConfirmRequested(title, body, "Reset", action);
    }

    // same dialog, different verb - for destructive actions that are not resets
    function askConfirm(title, body, confirmLabel, action) {
        root.resetConfirmRequested(title, body, confirmLabel, action);
    }

    // true when a key has been moved off the value it ships with - drives
    // whether a reset affordance is worth showing at all
    function isModified(key) {
        return root.defaults[key] !== undefined && root[key] !== root.defaults[key];
    }

    function resetAll() {
        for (var k in root.defaults) root.set(k, root.defaults[k])
    }

    function resetKeys(keys) {
        for (var i = 0; i < keys.length; i++) root.set(keys[i], root.defaults[keys[i]])
    }

    function set(key, value) {
        if (s[key] !== undefined && s[key] !== value)
            s[key] = value;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/lucidprefs/prefs.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.loaded = true
        // a missing or unreadable file is still an answer - the defaults are
        // what the shell will run on, so let it map rather than stranding it
        onLoadFailed: root.loaded = true

        adapter: JsonAdapter {
            id: s

            // ---- general ----
            property string barStyle: "island"
            property string dockStyle: "island"
            property real accentPunch: 1
            // -1 means "follow the theme's own choice", matching Theme.qml's
            // original themeName-derived value. Any other value overrides it.
            property real surfaceDarkness: -1
            property real motionScale: 1
            property string fontFamily: "Google Sans"
            property real fontScale: 1
            // empty means "~/Pictures/wallpapers/<current theme>", the folder
            // the launcher's >wallpaper strip already scans
            property string wallpaperFolder: ""
            // ---- bar ----
            property bool barPopupMode: false
            property int barPopupGap: 10
            property int barHeight: 35
            property int barTopMargin: 22
            property int barSideMargin: 17
            property int barSpacing: 8
            property bool showWorkspaces: true
            property bool showMedia: true
            property bool showTray: true
            property bool showClock: true
            property bool showBluetooth: true
            property bool showNetwork: true
            property bool showNotifications: true
            property bool showSystem: true
            property bool clock24h: false
            property bool clockShowDate: true
            property bool doNotDisturb: false
            property int toastTimeout: 5
            // ---- dock ----
            property int dockIconSize: 46
            property int dockSpacing: 10
            property int dockBottomMargin: 20
            property bool dockMagnify: true
            property bool dockAutoHide: false
            property bool dockShowIndicators: true
            property bool dockShowTooltips: true
            property bool dockShowRunning: true
        }

    }

}
