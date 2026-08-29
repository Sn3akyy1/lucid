import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property string themeName: "matugen"
    property real pillDarkness: pf.surfaceDarkness >= 0 ? pf.surfaceDarkness : (themeName === "matugen" ? 0.45 : 0)
    property real accentPunch: pf.accentPunch
    readonly property real motionBaseline: 1.125
    readonly property real motionScale: pf.motionScale * root.motionBaseline
    readonly property real blurAmount: blurAdapter.value || 0

    function setBlurAmount(v) {
        blurAdapter.value = v;
    }
    readonly property real _toneShift: root.pillDarkness * 3
    readonly property color cPrimary: m.primary
    readonly property color cOnPrimary: m.on_primary
    readonly property color cPrimaryContainer: m.primary_container
    readonly property color cOnPrimaryContainer: m.on_primary_container
    readonly property color cSecondary: m.secondary
    readonly property color cSecondaryContainer: m.secondary_container
    readonly property color cTertiary: m.tertiary
    readonly property color cOnTertiary: m.on_tertiary
    readonly property color cError: m.error
    readonly property color cOnError: m.on_error
    readonly property color cErrorContainer: m.error_container
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
    readonly property color cInverseSurface: m.inverse_surface
    readonly property color cShadow: m.shadow
    readonly property color cScrim: m.scrim
    readonly property color cOnSecondary: m.on_secondary !== "" ? m.on_secondary : root.atTone(root.cSecondary, 20)
    readonly property color cOnSecondaryContainer: m.on_secondary_container !== "" ? m.on_secondary_container : root.atTone(root.cSecondary, 90)
    readonly property color cTertiaryContainer: m.tertiary_container !== "" ? m.tertiary_container : root.atTone(root.cTertiary, 30)
    readonly property color cOnTertiaryContainer: m.on_tertiary_container !== "" ? m.on_tertiary_container : root.atTone(root.cTertiary, 90)
    readonly property color cOnErrorContainer: m.on_error_container !== "" ? m.on_error_container : root.atTone(root.cError, 90)
    readonly property color cSurfaceBright: m.surface_bright !== "" ? m.surface_bright : root.atTone(root.cHighest, root.toneOf(root.cHighest) + 2)
    readonly property color cInverseOnSurface: m.inverse_on_surface !== "" ? m.inverse_on_surface : root.atTone(root.cSurface, 20)
    readonly property color cInversePrimary: m.inverse_primary !== "" ? m.inverse_primary : root.atTone(root.cPrimary, 40)
    readonly property color bg: root.alpha(root.shade(root.cLowest, root._toneShift + root.blurAmount * 2), 1 - root.blurAmount * 0.85)
    readonly property color bgTransparent: root.alpha(root.bg, 0)
    readonly property color bgOpaque: root.shade(root.cLowest, root._toneShift)
    readonly property color bgSunken: root.atTone(root.cLowest, Math.max(0, root.toneOf(root.bgOpaque) - 2.5))
    readonly property color bgTile: root.shade(root.cLow, root._toneShift)
    readonly property color bgHover: root.shade(root.cContainer, root._toneShift)
    readonly property color bgActive: root.shade(root.cHigh, root._toneShift)
    readonly property color bgHigh: root.shade(root.cHighest, root._toneShift)
    readonly property color bgBright: root.shade(root.cSurfaceBright, root._toneShift)
    readonly property color bgTrack: root.shade(root.cSurfaceVariant, root._toneShift)
    readonly property color dockItem: root.atTone(root.bgOpaque, root.toneOf(root.bgOpaque) + 4)
    readonly property color text: root.cOnSurface
    readonly property color subtext: root.cOnSurfaceVariant
    readonly property color subtextDim: root.atTone(root.cOnSurfaceVariant, 65)
    readonly property color accent: root.accentPunch === 1 ? root.cPrimary : root.atTone(root.cPrimary, root.toneOf(root.cPrimary) + (root.accentPunch - 1) * 9)
    readonly property color accentHover: root.atTone(root.accent, Math.min(100, root.toneOf(root.accent) + 6))
    readonly property color accentPressed: root.atTone(root.accent, Math.max(0, root.toneOf(root.accent) - 6))
    readonly property color onAccent: root.cOnPrimary
    readonly property color accentContainer: root.shade(root.cPrimaryContainer, root._toneShift)
    readonly property color onAccentContainer: root.cOnPrimaryContainer
    readonly property color accentMuted: root.atTone(root.withSat(root.cPrimary, 0.55), (root.toneOf(root.cPrimary) + root.toneOf(root.cOnSurfaceVariant)) / 2)
    readonly property color accentBorder: root.alpha(root.accent, 0.45)
    readonly property bool hasTonalContainers: m.on_secondary_container !== ""
    readonly property color secondaryContainer: root.hasTonalContainers ? root.shade(root.cSecondaryContainer, root._toneShift) : root.bgHigh
    readonly property color onSecondaryContainer: root.hasTonalContainers ? root.cOnSecondaryContainer : root.text
    readonly property color tertiaryContainer: root.hasTonalContainers ? root.shade(root.cTertiaryContainer, root._toneShift) : root.bgHigh
    readonly property color onTertiaryContainer: root.hasTonalContainers ? root.cOnTertiaryContainer : root.text
    readonly property color outline: root.cOutlineVariant
    readonly property color outlineStrong: root.cOutline
    readonly property color error: root.cError
    readonly property color onError: root.cOnError
    readonly property color errorContainer: root.hasTonalContainers ? root.shade(root.cErrorContainer, root._toneShift) : root.bgHigh
    readonly property color onErrorContainer: root.hasTonalContainers ? root.cOnErrorContainer : root.error
    readonly property color success: root.isGreenish(root.cTertiary) ? root.cTertiary : root.statusHue(145)
    readonly property color onSuccess: root.atTone(root.success, 20)
    readonly property color warning: root.statusHue(45)
    readonly property color onWarning: root.atTone(root.warning, 20)
    readonly property color shadow: root.cShadow
    readonly property color scrim: root.alpha(root.cScrim, 0.5)
    readonly property color inverseSurface: root.cInverseSurface
    readonly property color onInverseSurface: root.cInverseOnSurface
    readonly property color inversePrimary: root.cInversePrimary
    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.1
    readonly property real statePressed: 0.1
    readonly property real stateDragged: 0.16
    readonly property int radiusPill: 999
    readonly property int radiusXs: 8
    readonly property int radiusSm: 12
    readonly property int radiusMd: 16
    readonly property int radiusLg: 20
    readonly property int radiusXl: 28
    readonly property real barMotionScale: root.motionScale * pf.barMotionScale
    readonly property int barDurQuick: Math.round(120 * root.barMotionScale)
    readonly property int barDurShort: Math.round(180 * root.barMotionScale)
    readonly property int barDurMedium: Math.round(280 * root.barMotionScale)
    readonly property int barDurLong: Math.round(400 * root.barMotionScale)
    readonly property int barDurEnter: Math.round(320 * root.barMotionScale)
    readonly property int barDurExit: Math.round(190 * root.barMotionScale)

    readonly property int durQuick: Math.round(120 * root.motionScale)
    readonly property int durShort: Math.round(180 * root.motionScale)
    readonly property int durMedium: Math.round(280 * root.motionScale)
    readonly property int durLong: Math.round(400 * root.motionScale)
    readonly property var easeEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeEmphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property int durEnter: Math.round(320 * root.motionScale)
    readonly property int durExit: Math.round(190 * root.motionScale)
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeEmphasized: Easing.OutBack
    readonly property real emphasizedOvershoot: 0.7
    readonly property string fontFamily: pf.fontFamily
    readonly property int fontLabel: Math.round(11 * pf.fontScale)
    readonly property int fontBody: Math.round(12 * pf.fontScale)
    readonly property int fontTitle: Math.round(13 * pf.fontScale)
    readonly property int fontHeadline: Math.round(15 * pf.fontScale)

    function fs(px) {
        return Math.round(px * pf.fontScale);
    }

    function ms(d) {
        return Math.round(d * root.motionScale);
    }

    function barMs(d) {
        return Math.round(d * root.barMotionScale);
    }

    function _lin(c) {
        return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }

    function _gam(c) {
        var v = c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
        return Math.max(0, Math.min(1, v));
    }

    // relative luminance, 0..1
    function _y(c) {
        return 0.2126 * root._lin(c.r) + 0.7152 * root._lin(c.g) + 0.0722 * root._lin(c.b);
    }

    // m3 tone -> luminance
    function _yAt(t) {
        return t <= 8 ? t / 903.2963 : Math.pow((t + 16) / 116, 3);
    }

    // color -> m3 tone (0..100)
    function toneOf(c) {
        var y = root._y(c);
        return y <= 0.008856 ? y * 903.2963 : 116 * Math.pow(y, 1 / 3) - 16;
    }

    function atTone(c, t) {
        var tt = Math.max(0, Math.min(100, t));
        var target = root._yAt(tt);
        var y = root._y(c);
        if (y <= 0) {
            var g = root._gam(target);
            return Qt.rgba(g, g, g, c.a);
        }
        var k = target / y;
        var lr = root._lin(c.r) * k;
        var lg = root._lin(c.g) * k;
        var lb = root._lin(c.b) * k;
        var peak = Math.max(lr, lg, lb);
        if (peak > 1) {
            lr /= peak;
            lg /= peak;
            lb /= peak;
            var yb = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb;
            var w = yb >= 1 ? 0 : Math.max(0, Math.min(1, (target - yb) / (1 - yb)));
            lr += (1 - lr) * w;
            lg += (1 - lg) * w;
            lb += (1 - lb) * w;
        }
        return Qt.rgba(root._gam(lr), root._gam(lg), root._gam(lb), c.a);
    }

    function shade(c, tones) {
        return tones === 0 ? c : root.atTone(c, root.toneOf(c) - tones);
    }

    // scale chroma, hold tone
    function withSat(c, k) {
        var h = c.hslHue;
        if (h < 0)
            return c;
        var s = Math.max(0, Math.min(1, c.hslSaturation * k));
        return root.atTone(Qt.hsla(h, s, c.hslLightness, c.a), root.toneOf(c));
    }

    function isGreenish(c) {
        var h = c.hslHue;
        return h >= 0 && h * 360 >= 55 && h * 360 <= 175 && c.hslSaturation > 0.15;
    }

    function statusHue(deg) {
        var s = Math.max(0.35, Math.min(0.75, root.cPrimary.hslSaturation));
        return root.atTone(Qt.hsla(deg / 360, s, 0.55, 1), 80);
    }

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

    function withBlur(c) {
        return root.alpha(c, 1 - root.blurAmount * 0.85);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/matugen.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: m

            property string primary: "#ffb1c4"
            property string on_primary: "#5e1130"
            property string primary_container: "#7b2947"
            property string on_primary_container: "#ffd9e1"
            property string secondary: "#e3bdc4"
            property string secondary_container: "#5c3f45"
            property string tertiary: "#f2bd9a"
            property string on_tertiary: "#4a2510"
            property string error: "#ffb4ab"
            property string on_error: "#690005"
            property string error_container: "#93000a"
            property string surface: "#191113"
            property string on_surface: "#efdfe1"
            property string surface_variant: "#524347"
            property string on_surface_variant: "#d6c2c6"
            property string surface_dim: "#191113"
            property string surface_container_lowest: "#140c0e"
            property string surface_container_low: "#221a1c"
            property string surface_container: "#261e20"
            property string surface_container_high: "#31282a"
            property string surface_container_highest: "#3d3335"
            property string outline: "#9e8c90"
            property string outline_variant: "#524347"
            property string inverse_surface: "#efdfe1"
            property string shadow: "#000000"
            property string scrim: "#000000"
            property string on_secondary: ""
            property string on_secondary_container: ""
            property string tertiary_container: ""
            property string on_tertiary_container: ""
            property string on_error_container: ""
            property string surface_bright: ""
            property string surface_tint: ""
            property string inverse_on_surface: ""
            property string inverse_primary: ""
            property string source_color: ""
        }

    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/current_theme"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.themeName = text().trim() || "matugen"
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/lucidprefs/prefs.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: pf

            property real accentPunch: 1
            property real surfaceDarkness: -1
            property real motionScale: 1
            property real barMotionScale: 1.35
            property string fontFamily: "Google Sans"
            property real fontScale: 1
        }

    }

    FileView {
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
