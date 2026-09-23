import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property string themeName: "matugen"
    // read off the palette, never off the pref: whatever is in the cache decides,
    // so the shell never renders light rules against a palette still being regenerated
    readonly property bool isLight: root.toneOf(root.cSurface) > 50
    // +1 dark, -1 light. every "lighter means more elevated" derivation flips on it
    readonly property int _dir: root.isLight ? -1 : 1
    property real pillDarkness: pf.surfaceDarkness >= 0 ? pf.surfaceDarkness : (themeName === "matugen" && !root.isLight ? 0.45 : 0)
    // light surfaces come out of matugen near-white, so the accent is what keeps
    // them from reading as flat paper. auto is off in dark: pills stay flat there.
    // 0.7 is not a taste call — it is the smallest value that clears the chroma
    // ceiling: k also sets how far `surface()` walks off white (k * _tintLift),
    // and below ~0.6 the ramp never leaves the tones where no hue can exist
    readonly property real surfaceTint: pf.surfaceTint >= 0 ? pf.surfaceTint : (root.isLight ? 0.7 : 0)
    property real accentPunch: pf.accentPunch
    readonly property real motionBaseline: 1.125
    readonly property real motionScale: pf.motionScale * root.motionBaseline
    // the ramp below is authored a step large; 1.00x renders it at 0.9
    readonly property real typeBaseline: 0.9
    readonly property real fontScale: pf.fontScale * root.typeBaseline
    readonly property real blurAmount: blurAdapter.value || 0

    function setBlurAmount(v) {
        blurAdapter.value = v;
    }
    readonly property real _toneShift: root.pillDarkness * 3
    // tones the ramp travels off white (or off black) at full tint
    readonly property real _tintLift: 10
    // chroma the tint aims for at full strength, as an 0..1 channel spread.
    // aiming at an *amount* rather than mixing a fixed fraction is what keeps
    // every palette looking alike: chroma headroom grows steeply as tone falls,
    // so one fixed fraction turned a near-grey gruvbox into bright mint while
    // leaving a near-white matugen untouched
    readonly property real _tintTarget: 0.13
    // where the top rung of a light ramp is pulled to. taken off cLowest so a
    // palette whose own ladder already starts below white is moved less, not more
    readonly property real _rampShift: root.surfaceTint <= 0 ? 0 : (root.isLight ? Math.max(0, root.toneOf(root.cLowest) - (100 - root.surfaceTint * root._tintLift)) : -(root.surfaceTint * root._tintLift))
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
    readonly property color cOnSecondary: m.on_secondary !== "" ? m.on_secondary : root.atTone(root.cSecondary, root.isLight ? 100 : 20)
    readonly property color cOnSecondaryContainer: m.on_secondary_container !== "" ? m.on_secondary_container : root.atTone(root.cSecondary, root.isLight ? 10 : 90)
    readonly property color cTertiaryContainer: m.tertiary_container !== "" ? m.tertiary_container : root.atTone(root.cTertiary, root.isLight ? 90 : 30)
    readonly property color cOnTertiaryContainer: m.on_tertiary_container !== "" ? m.on_tertiary_container : root.atTone(root.cTertiary, root.isLight ? 10 : 90)
    readonly property color cOnErrorContainer: m.on_error_container !== "" ? m.on_error_container : root.atTone(root.cError, root.isLight ? 10 : 90)
    readonly property color cSurfaceBright: m.surface_bright !== "" ? m.surface_bright : root.isLight ? root.atTone(root.cLowest, root.toneOf(root.cLowest) - 2) : root.atTone(root.cHighest, root.toneOf(root.cHighest) + 2)
    readonly property color cInverseOnSurface: m.inverse_on_surface !== "" ? m.inverse_on_surface : root.atTone(root.cSurface, root.isLight ? 95 : 20)
    readonly property color cInversePrimary: m.inverse_primary !== "" ? m.inverse_primary : root.atTone(root.cPrimary, root.isLight ? 80 : 40)
    readonly property color bg: root.alpha(root.surface(root.cLowest, root._toneShift + root.blurAmount * 2), 1 - root.blurAmount * 0.85)
    readonly property color bgTransparent: root.alpha(root.bg, 0)
    readonly property color bgOpaque: root.surface(root.cLowest, root._toneShift)
    readonly property color bgSunken: root.tint(root.atTone(root.cLowest, Math.max(0, root.toneOf(root.bgOpaque) - 2.5)), root.surfaceTint)
    readonly property color bgTile: root.surface(root.cLow, root._toneShift)
    readonly property color bgHover: root.surface(root.cContainer, root._toneShift)
    readonly property color bgActive: root.surface(root.cHigh, root._toneShift)
    readonly property color bgHigh: root.surface(root.cHighest, root._toneShift)
    readonly property color bgBright: root.surface(root.cSurfaceBright, root._toneShift)
    readonly property color bgTrack: root.surface(root.cSurfaceVariant, root._toneShift)
    readonly property color dockItem: root.atTone(root.bgOpaque, root.toneOf(root.bgOpaque) + root._dir * 4)
    readonly property color text: root.cOnSurface
    readonly property color subtext: root.cOnSurfaceVariant
    readonly property color subtextDim: root.atTone(root.cOnSurfaceVariant, root.isLight ? 50 : 65)
    readonly property color accent: root.accentPunch === 1 ? root.cPrimary : root.atTone(root.cPrimary, root.toneOf(root.cPrimary) + root._dir * (root.accentPunch - 1) * 9)
    readonly property color accentHover: root.atTone(root.accent, Math.max(0, Math.min(100, root.toneOf(root.accent) + root._dir * 6)))
    readonly property color accentPressed: root.atTone(root.accent, Math.max(0, Math.min(100, root.toneOf(root.accent) - root._dir * 6)))
    // NB: these cannot be named on<Role>. A property `onFoo` declared beside a
    // property `foo` is parsed as a signal-handler assignment, so the binding is
    // silently dropped and the colour stays black. Keep the fg prefix.
    readonly property color fgAccent: root.cOnPrimary
    readonly property color accentContainer: root.shade(root.cPrimaryContainer, root._toneShift)
    readonly property color fgAccentContainer: root.cOnPrimaryContainer
    readonly property color accentMuted: root.atTone(root.withSat(root.cPrimary, 0.55), (root.toneOf(root.cPrimary) + root.toneOf(root.cOnSurfaceVariant)) / 2)
    readonly property color accentBorder: root.alpha(root.accent, 0.45)
    readonly property bool hasTonalContainers: m.on_secondary_container !== ""
    readonly property color secondaryContainer: root.hasTonalContainers ? root.shade(root.cSecondaryContainer, root._toneShift) : root.bgHigh
    readonly property color fgSecondaryContainer: root.hasTonalContainers ? root.cOnSecondaryContainer : root.text
    readonly property color tertiaryContainer: root.hasTonalContainers ? root.shade(root.cTertiaryContainer, root._toneShift) : root.bgHigh
    readonly property color fgTertiaryContainer: root.hasTonalContainers ? root.cOnTertiaryContainer : root.text
    readonly property color outline: root.cOutlineVariant
    readonly property color outlineStrong: root.cOutline
    readonly property color error: root.cError
    readonly property color fgError: root.cOnError
    readonly property color errorContainer: root.hasTonalContainers ? root.shade(root.cErrorContainer, root._toneShift) : root.bgHigh
    readonly property color fgErrorContainer: root.hasTonalContainers ? root.cOnErrorContainer : root.error
    readonly property color success: root.isGreenish(root.cTertiary) ? root.cTertiary : root.statusHue(145)
    readonly property color fgSuccess: root.atTone(root.success, root.isLight ? 100 : 20)
    readonly property color warning: root.statusHue(45)
    readonly property color fgWarning: root.atTone(root.warning, root.isLight ? 100 : 20)
    readonly property color shadow: root.cShadow
    readonly property color scrim: root.alpha(root.cScrim, 0.5)
    readonly property color inverseSurface: root.cInverseSurface
    readonly property color fgInverseSurface: root.cInverseOnSurface
    readonly property color inversePrimary: root.cInversePrimary
    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.1
    readonly property real statePressed: 0.1
    readonly property real stateDragged: 0.16
    // how round the whole shell is: every corner below is the authored dp times
    // this, so one slider squares the shell off. 1 is the shipped shape scale.
    readonly property real radiusScale: pf.radiusScale

    function rad(px) {
        return Math.round(px * root.radiusScale);
    }
    // a pill or a circle, by its short side: fully round up to 1, and below
    // that it squares off with the rest (radiusPill would stay a pill until 0)
    function pill(size) {
        return Math.round(size / 2 * Math.min(1, root.radiusScale));
    }
    readonly property int radiusPill: root.rad(999)
    readonly property int radiusXs: root.rad(8)
    readonly property int radiusSm: root.rad(12)
    readonly property int radiusMd: root.rad(16)
    readonly property int radiusLg: root.rad(20)
    readonly property int radiusXl: root.rad(28)

    // m3 shape scale, in dp
    readonly property int shapeNone: 0
    readonly property int shapeXs: root.rad(4)
    readonly property int shapeSm: root.rad(8)
    readonly property int shapeMd: root.rad(12)
    readonly property int shapeLg: root.rad(16)
    readonly property int shapeLgInc: root.rad(20)
    readonly property int shapeXl: root.rad(28)
    readonly property int shapeXlInc: root.rad(32)
    readonly property int shapeXxl: root.rad(48)
    readonly property int shapeFull: root.rad(999)

    // m3 surface containers, under their spec names
    readonly property color surfaceLowest: root.bgOpaque
    readonly property color surfaceLow: root.bgTile
    readonly property color surfaceContainer: root.bgHover
    readonly property color surfaceHigh: root.bgActive
    readonly property color surfaceHighest: root.bgHigh
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
    readonly property int fontLabel: Math.round(11 * root.fontScale)
    readonly property int fontBody: Math.round(12 * root.fontScale)
    readonly property int fontTitle: Math.round(13 * root.fontScale)
    readonly property int fontHeadline: Math.round(15 * root.fontScale)

    // m3 type scale, trimmed one step for desktop density
    readonly property int fontDisplaySm: Math.round(32 * root.fontScale)
    readonly property int fontHeadlineLg: Math.round(30 * root.fontScale)
    readonly property int fontHeadlineMd: Math.round(26 * root.fontScale)
    readonly property int fontHeadlineSm: Math.round(22 * root.fontScale)
    readonly property int fontTitleLg: Math.round(19 * root.fontScale)
    readonly property int fontTitleMd: Math.round(16 * root.fontScale)
    readonly property int fontTitleSm: Math.round(14 * root.fontScale)
    readonly property int fontBodyLg: Math.round(15 * root.fontScale)
    readonly property int fontBodyMd: Math.round(13 * root.fontScale)
    readonly property int fontBodySm: Math.round(12 * root.fontScale)
    readonly property int fontLabelLg: Math.round(13 * root.fontScale)
    readonly property int fontLabelMd: Math.round(12 * root.fontScale)
    readonly property int fontLabelSm: Math.round(11 * root.fontScale)

    function fs(px) {
        return Math.round(px * root.fontScale);
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

    // pull a neutral toward the accent's hue without moving it off its tone. the
    // blend is re-pinned afterwards so the elevation ladder keeps its spacing —
    // mixing in sRGB alone would drag every rung a different distance
    function tint(c, k) {
        if (k <= 0)
            return c;

        var h = root.cPrimary.hslHue;
        if (h < 0)
            return c;

        var t = root.toneOf(c);
        // built at mid lightness, where saturation still has room to read, then
        // moved onto the target tone.
        // floor the chroma: a wallpaper-derived accent is often nearly grey
        // (pywal has handed us 0.18), and mixing grey into grey stays grey
        var pure = root.atTone(Qt.hsla(h, Math.max(0.55, Math.min(1, root.cPrimary.hslSaturation)), 0.55, 1), t);
        // all the hue this tone can physically carry. nothing survives at tone
        // 100, which is why the ramp has to be walked off white first
        var head = root.chromaOf(pure);
        if (head <= 0.001)
            return c;

        var f = Math.min(1, k * root._tintTarget / head);
        var m = root._mix(c, pure, f);
        return root.atTone(Qt.rgba(m.r, m.g, m.b, c.a), t);
    }

    // how much colour a value actually shows, as a 0..1 channel spread
    function chromaOf(c) {
        return Math.max(c.r, c.g, c.b) - Math.min(c.r, c.g, c.b);
    }

    // one rung of the surface ramp. tinting also walks the rung away from the
    // extreme it sits against, because a tone carries no hue there — matugen's
    // light `surface_container_lowest` is pure #ffffff, and without the lift the
    // accent would have nowhere to land on the shell's main surface
    function surface(c, tones) {
        return root.tint(root.shade(c, tones + root._rampShift), root.surfaceTint);
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
        return root.atTone(Qt.hsla(deg / 360, s, 0.55, 1), root.isLight ? 40 : 80);
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
            property real radiusScale: 1
            property real surfaceTint: -1
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
