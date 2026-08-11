import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    // ---------------- tuning knobs ----------------
    property string themeName: "matugen"
    property real pillDarkness: themeName === "matugen" ? 0.45 : 0
    property real accentPunch: 1
    // stepped 0..1 glass amount set from the launcher's >blur slider -
    // 0 keeps pills fully opaque, 1 is the most transparent/darkened glass
    // look. Persisted via blurAdapter below so it survives restarts.
    readonly property real blurAmount: blurAdapter.value || 0

    function setBlurAmount(v) {
        blurAdapter.value = v;
    }
    // ---- string -> color conversion happens here, once ----
    readonly property color cPrimary: m.primary
    readonly property color cOnPrimary: m.on_primary
    readonly property color cPrimaryContainer: m.primary_container
    readonly property color cTertiary: m.tertiary
    readonly property color cError: m.error
    readonly property color cOnError: m.on_error
    readonly property color cSurface: m.surface
    readonly property color cOnSurface: m.on_surface
    readonly property color cSurfaceVariant: m.surface_variant
    readonly property color cOnSurfaceVariant: m.on_surface_variant
    readonly property color cLowest: m.surface_container_lowest
    readonly property color cLow: m.surface_container_low
    readonly property color cContainer: m.surface_container
    readonly property color cHigh: m.surface_container_high
    readonly property color cHighest: m.surface_container_highest
    readonly property color cOutline: m.outline
    readonly property color cOutlineVariant: m.outline_variant
    readonly property color cShadow: m.shadow
    readonly property color cScrim: m.scrim
    // ---------------- surfaces ----------------
    readonly property color bg: root.alpha(root._darken(root.cLowest, root.pillDarkness + root.blurAmount * 0.25), 1 - root.blurAmount * 0.85)
    readonly property color bgTransparent: root.alpha(root.bg, 0)
    // same base color as bg, but never faded by blurAmount - for content
    // (like button text) that needs to read against the pill's original
    // color regardless of how transparent the pill itself currently is
    readonly property color bgOpaque: root._darken(root.cLowest, root.pillDarkness)
    readonly property color bgSunken: root._darken(root.cSurface, root.pillDarkness + 0.1)
    readonly property color bgTile: root._darken(root.cLow, root.pillDarkness)
    readonly property color bgHover: root._darken(root.cContainer, root.pillDarkness)
    readonly property color bgActive: root._darken(root.cHigh, root.pillDarkness)
    readonly property color bgHigh: root._darken(root.cHighest, root.pillDarkness)
    readonly property color bgTrack: root._darken(root.cSurfaceVariant, root.pillDarkness * 0.6)
    readonly property color dockItem: root._lighten(root.bg, 0.05)
    // ---------------- content ----------------
    readonly property color text: root.cOnSurface
    readonly property color subtext: root.cOnSurfaceVariant
    readonly property color subtextDim: root._darken(root.cOnSurfaceVariant, 0.25)
    // ---------------- accent ----------------
    readonly property color accent: root.accentPunch === 1 ? root.cPrimary : root._lighten(root.cPrimary, (root.accentPunch - 1) * 0.4)
    readonly property color accentHover: root._lighten(root.accent, 0.18)
    readonly property color accentPressed: root._darken(root.accent, 0.12)
    readonly property color onAccent: root.cOnPrimary
    readonly property color accentContainer: root._darken(root.cPrimaryContainer, root.pillDarkness * 0.5)
    readonly property color accentMuted: root._mix(root.cPrimary, root.cOnSurfaceVariant, 0.55)
    readonly property color accentBorder: root.alpha(root.accent, 0.45)
    // ---------------- lines ----------------
    readonly property color outline: root.cOutlineVariant
    readonly property color outlineStrong: root.cOutline
    // ---------------- status ----------------
    readonly property color error: root.cError
    readonly property color onError: root.cOnError
    readonly property color success: root.cTertiary
    readonly property color shadow: root.cShadow
    readonly property color scrim: root.alpha(root.cScrim, 0.5)
    // ---------------- state layer opacities ----------------
    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.1
    readonly property real statePressed: 0.12
    readonly property real stateDragged: 0.16
    // ---------------- shape ----------------
    readonly property int radiusPill: 999
    readonly property int radiusXs: 8
    readonly property int radiusSm: 12
    readonly property int radiusMd: 16
    readonly property int radiusLg: 20
    readonly property int radiusXl: 28
    // ---------------- motion ----------------
    readonly property int durQuick: 120
    readonly property int durShort: 180
    readonly property int durMedium: 280
    readonly property int durLong: 400
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeEmphasized: Easing.OutBack
    readonly property real emphasizedOvershoot: 0.7
    // ---------------- type ----------------
    readonly property string fontFamily: "Google Sans"
    readonly property int fontLabel: 11
    readonly property int fontBody: 12
    readonly property int fontTitle: 13
    readonly property int fontHeadline: 15

    function _mix(a, b, t) {
        return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t, a.b * (1 - t) + b.b * t, 1);
    }

    function _darken(c, t) {
        return root._mix(c, Qt.rgba(0, 0, 0, 1), t);
    }

    function _lighten(c, t) {
        return root._mix(c, Qt.rgba(1, 1, 1, 1), t);
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function toHex(c) {
        var r = Math.round(c.r * 255).toString(16).padStart(2, "0");
        var g = Math.round(c.g * 255).toString(16).padStart(2, "0");
        var b = Math.round(c.b * 255).toString(16).padStart(2, "0");
        return "#" + r + g + b;
    }

    // fades an arbitrary (opaque) color by the same amount as the >blur
    // slider, for the handful of spots that opt into tracking it without
    // making every consumer of that base token (e.g. every bgTile/bgHover
    // usage shell-wide) translucent too.
    function withBlur(c) {
        return root.alpha(c, 1 - root.blurAmount * 0.85);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/matugen.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: m

            property string primary: "#8ad0ee"
            property string on_primary: "#0f1417"
            property string primary_container: "#22343c"
            property string on_primary_container: "#cccaec"
            property string secondary: "#8c8aa4"
            property string secondary_container: "#2a3137"
            property string tertiary: "#7ee08a"
            property string on_tertiary: "#0f1417"
            property string error: "#e06c75"
            property string on_error: "#0f1417"
            property string error_container: "#3a2226"
            property string surface: "#12171a"
            property string on_surface: "#cccaec"
            property string surface_variant: "#2e343a"
            property string on_surface_variant: "#8c8aa4"
            property string surface_dim: "#0f1417"
            property string surface_container_lowest: "#0f1417"
            property string surface_container_low: "#161a1d"
            property string surface_container: "#171c1f"
            property string surface_container_high: "#1c2226"
            property string surface_container_highest: "#242a2f"
            property string outline: "#5a5f66"
            property string outline_variant: "#2e343a"
            property string inverse_surface: "#cccaec"
            property string shadow: "#000000"
            property string scrim: "#000000"
        }

    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/current_theme"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.themeName = text().trim() || "matugen"
    }

    FileView {
        // absolute path (not Qt.resolvedUrl("./blur.json")) so this resolves
        // identically regardless of which physical copy of this file a
        // given caller's "Theme" ends up bound to. watchChanges+onFileChanged
        // matters here specifically: there are two on-disk copies of this
        // file's own source (see quickshell_duplicate_theme_qml memory), so
        // two independent Singleton instances exist in the running engine.
        // Without watching the file, a write from one instance (e.g. the
        // dock's launcher, reached via "import qs") never reaches the
        // other's in-memory blurAdapter (e.g. the bar's widgets, reached via
        // same-directory implicit import) - the file is the only thing they
        // actually share.
        path: Quickshell.env("HOME") + "/.config/quickshell/lucidbar/blur.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: blurAdapter

            property real value: 0
        }

    }

}
