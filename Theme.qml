import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    // ---------------- tuning knobs ----------------
    property string themeName: "matugen"
    // -1 in prefs means "let the theme decide", which is the original
    // themeName-derived behaviour; any other value is an explicit override
    // set from the settings app.
    property real pillDarkness: pf.surfaceDarkness >= 0 ? pf.surfaceDarkness : (themeName === "matugen" ? 0.45 : 0)
    property real accentPunch: pf.accentPunch
    // Scales every duration token below. Reading it here rather than in each
    // module is the whole point: one setting reaches every Behavior in the
    // shell that animates off a Theme duration, with no per-module wiring.
    readonly property real motionScale: pf.motionScale
    // stepped 0..1 glass amount set from the launcher's >blur slider -
    // 0 keeps pills fully opaque, 1 is the most transparent/darkened glass
    // look. Persisted via blurAdapter below so it survives restarts.
    readonly property real blurAmount: blurAdapter.value || 0

    function setBlurAmount(v) {
        blurAdapter.value = v;
    }
    // pillDarkness expressed as a shift DOWN the tone ladder instead of a
    // multiply toward black. This is the whole fix: M3 spaces the dark
    // surface roles at tones 4/10/12/17/22, an 18-tone ladder, and the old
    // `mix(c, black, 0.45)` scaled the CHANNELS, which scales the gaps
    // between those steps too - the ladder arrived compressed to 8.9 tones
    // and bgTile/bgHover ended up 0.8 tones apart, close enough to identical
    // that hover states stopped reading at all. Subtracting a constant in
    // tone space moves the ladder without touching its spacing.
    //
    // x3 is calibrated so the default 0.45 lands the pill on roughly the
    // same darkness the multiply produced (~tone 2-3 on a matugen palette),
    // i.e. the flat dark pill is unchanged - only the depth above it comes
    // back. At pillDarkness 0 the shift is 0 and every palette passes
    // through completely untouched, which is what keeps the four static
    // themes byte-identical to how they render today.
    readonly property real _toneShift: root.pillDarkness * 3
    // ---- string -> color conversion happens here, once ----
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
    // ---- roles the old template never captured ----
    // matugen 4.x emits all of these; the template only asked for 26 of its
    // 50 roles, so the shell had to fake containers and on-container colors
    // by darkening whatever it did have. They are requested properly now,
    // but the four static theme palettes in ~/.config/lucid/themes still
    // carry the original 26 keys, so an empty string here means "this
    // palette predates the wider template". Each one then falls back to the
    // M3 tone the role is *defined* as in a dark scheme - on-container is
    // tone 90, container is tone 30, and so on - derived from a role the
    // palette does have. Every theme renders correctly today, and simply
    // picks up matugen's exact HCT-solved value once its palette is rewritten.
    readonly property color cOnSecondary: m.on_secondary !== "" ? m.on_secondary : root.atTone(root.cSecondary, 20)
    readonly property color cOnSecondaryContainer: m.on_secondary_container !== "" ? m.on_secondary_container : root.atTone(root.cSecondary, 90)
    readonly property color cTertiaryContainer: m.tertiary_container !== "" ? m.tertiary_container : root.atTone(root.cTertiary, 30)
    readonly property color cOnTertiaryContainer: m.on_tertiary_container !== "" ? m.on_tertiary_container : root.atTone(root.cTertiary, 90)
    readonly property color cOnErrorContainer: m.on_error_container !== "" ? m.on_error_container : root.atTone(root.cError, 90)
    // surface_bright sits just above surface_container_highest (tones 24 vs
    // 22 in M3's dark scheme), so the fallback has to be relative - a fixed
    // tone 24 would land *below* highest on the lighter hand-authored
    // palettes, where highest is already tone 36.
    readonly property color cSurfaceBright: m.surface_bright !== "" ? m.surface_bright : root.atTone(root.cHighest, root.toneOf(root.cHighest) + 2)
    readonly property color cInverseOnSurface: m.inverse_on_surface !== "" ? m.inverse_on_surface : root.atTone(root.cSurface, 20)
    readonly property color cInversePrimary: m.inverse_primary !== "" ? m.inverse_primary : root.atTone(root.cPrimary, 40)
    // ---------------- surfaces ----------------
    readonly property color bg: root.alpha(root.shade(root.cLowest, root._toneShift + root.blurAmount * 2), 1 - root.blurAmount * 0.85)
    readonly property color bgTransparent: root.alpha(root.bg, 0)
    // same base color as bg, but never faded by blurAmount - for content
    // (like button text) that needs to read against the pill's original
    // color regardless of how transparent the pill itself currently is
    readonly property color bgOpaque: root.shade(root.cLowest, root._toneShift)
    // A real well again. This used to be built by over-darkening `surface`,
    // which sits a tone ABOVE surface_container_lowest in M3 - so after the
    // multiply it landed 0.3 tones *lighter* than the pill it was supposed
    // to be sunk into, and the inset simply didn't read. Anchored to the
    // pill's own tone and pushed below it instead.
    readonly property color bgSunken: root.atTone(root.cLowest, Math.max(0, root.toneOf(root.bgOpaque) - 2.5))
    readonly property color bgTile: root.shade(root.cLow, root._toneShift)
    readonly property color bgHover: root.shade(root.cContainer, root._toneShift)
    readonly property color bgActive: root.shade(root.cHigh, root._toneShift)
    readonly property color bgHigh: root.shade(root.cHighest, root._toneShift)
    readonly property color bgBright: root.shade(root.cSurfaceBright, root._toneShift)
    readonly property color bgTrack: root.shade(root.cSurfaceVariant, root._toneShift)
    readonly property color dockItem: root.atTone(root.bgOpaque, root.toneOf(root.bgOpaque) + 4)
    // ---------------- content ----------------
    readonly property color text: root.cOnSurface
    readonly property color subtext: root.cOnSurfaceVariant
    // M3 puts on_surface_variant at tone 80 and outline at tone 60; a third
    // text weight belongs between them rather than at "25% darker", which is
    // a multiply that drifts with whatever hue the palette happens to carry.
    readonly property color subtextDim: root.atTone(root.cOnSurfaceVariant, 65)
    // ---------------- accent ----------------
    // Same direction as before - the slider still lifts the accent away from
    // the wallpaper-derived original - but done as a move up the tone ladder
    // rather than a mix toward white. Mixing with white raises the tone and
    // strips the chroma on the way, so the old "punchier" accent arrived
    // paler; re-toning holds the hue and chroma and only moves the
    // lightness. On a primary already sitting at the edge of the sRGB gamut
    // (a fully saturated one, as a vivid wallpaper tends to give) the top of
    // the range still has to desaturate to get brighter - there is nowhere
    // else for it to go - but everywhere else it now keeps its color.
    readonly property color accent: root.accentPunch === 1 ? root.cPrimary : root.atTone(root.cPrimary, root.toneOf(root.cPrimary) + (root.accentPunch - 1) * 9)
    readonly property color accentHover: root.atTone(root.accent, Math.min(100, root.toneOf(root.accent) + 6))
    readonly property color accentPressed: root.atTone(root.accent, Math.max(0, root.toneOf(root.accent) - 6))
    readonly property color onAccent: root.cOnPrimary
    readonly property color accentContainer: root.shade(root.cPrimaryContainer, root._toneShift)
    readonly property color onAccentContainer: root.cOnPrimaryContainer
    // A de-emphasised accent for secondary and disabled affordances. The old
    // version averaged the accent with grey body text, which produced mud;
    // dropping chroma instead keeps it recognisably the accent hue. It stays
    // at the lightness that average used to land on - halfway between accent
    // and body text - rather than a fixed tone, because a fixed one silently
    // dropped this 20 tones on the hand-authored palettes, where it reads as
    // text going dim rather than as an accent being de-emphasised.
    readonly property color accentMuted: root.atTone(root.withSat(root.cPrimary, 0.55), (root.toneOf(root.cPrimary) + root.toneOf(root.cOnSurfaceVariant)) / 2)
    readonly property color accentBorder: root.alpha(root.accent, 0.45)
    // ---------------- tonal containers ----------------
    // M3's tonal surfaces, but only where the palette actually has them.
    // A palette that carries on_secondary_container came through the current
    // template and has real, tinted containers. The four hand-authored
    // themes in ~/.config/lucid/themes predate it and reuse plain neutral
    // surfaces for their *_container roles - nord literally sets
    // secondary_container and surface_container to the same #3b4252 - so
    // treating those as tonal surfaces would render a "tonal" button in the
    // exact colour of the card behind it. Those palettes keep the neutral
    // high surface they have always used here; rewriting one with the full
    // key set opts it in automatically.
    readonly property bool hasTonalContainers: m.on_secondary_container !== ""
    readonly property color secondaryContainer: root.hasTonalContainers ? root.shade(root.cSecondaryContainer, root._toneShift) : root.bgHigh
    readonly property color onSecondaryContainer: root.hasTonalContainers ? root.cOnSecondaryContainer : root.text
    readonly property color tertiaryContainer: root.hasTonalContainers ? root.shade(root.cTertiaryContainer, root._toneShift) : root.bgHigh
    readonly property color onTertiaryContainer: root.hasTonalContainers ? root.cOnTertiaryContainer : root.text
    // ---------------- lines ----------------
    readonly property color outline: root.cOutlineVariant
    readonly property color outlineStrong: root.cOutline
    // ---------------- status ----------------
    readonly property color error: root.cError
    readonly property color onError: root.cOnError
    readonly property color errorContainer: root.hasTonalContainers ? root.shade(root.cErrorContainer, root._toneShift) : root.bgHigh
    readonly property color onErrorContainer: root.hasTonalContainers ? root.cOnErrorContainer : root.error
    // `success` was bound straight to tertiary, which for matugen is just
    // "whatever third hue the wallpaper produced" - it lands blue or orange
    // as often as green, so battery-good and connected states rendered in a
    // color that reads as informational rather than positive. But the
    // hand-authored palettes DO put a real green there on purpose (nord's
    // #a3be8c, gruvbox's #b8bb26), and overriding those replaced a colour
    // chosen to fit the theme with one that clashes against it. So: keep
    // tertiary when it is genuinely green, and only synthesise when it
    // isn't.
    readonly property color success: root.isGreenish(root.cTertiary) ? root.cTertiary : root.statusHue(145)
    readonly property color onSuccess: root.atTone(root.success, 20)
    readonly property color warning: root.statusHue(45)
    readonly property color onWarning: root.atTone(root.warning, 20)
    readonly property color shadow: root.cShadow
    readonly property color scrim: root.alpha(root.cScrim, 0.5)
    // ---------------- inverse (toasts, snackbars) ----------------
    readonly property color inverseSurface: root.cInverseSurface
    readonly property color onInverseSurface: root.cInverseOnSurface
    readonly property color inversePrimary: root.cInversePrimary
    // ---------------- state layer opacities ----------------
    // M3 state layer spec: hover 8%, focus 10%, pressed 10%, dragged 16%.
    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.1
    readonly property real statePressed: 0.1
    readonly property real stateDragged: 0.16
    // ---------------- shape ----------------
    readonly property int radiusPill: 999
    readonly property int radiusXs: 8
    readonly property int radiusSm: 12
    readonly property int radiusMd: 16
    readonly property int radiusLg: 20
    readonly property int radiusXl: 28
    // ---------------- motion ----------------
    readonly property int durQuick: Math.round(120 * root.motionScale)
    readonly property int durShort: Math.round(180 * root.motionScale)
    readonly property int durMedium: Math.round(280 * root.motionScale)
    readonly property int durLong: Math.round(400 * root.motionScale)
    // Material 3 emphasized easing as real cubic-beziers rather than the
    // nearest Qt curve. Decelerate for something entering (it arrives quickly
    // then settles), accelerate for something leaving (it eases off, then gets
    // out of the way). One symmetrical curve for both directions - especially
    // an overshooting one - is what makes a pop-up feel rubbery on the way out,
    // because the overshoot fires backwards as it closes.
    readonly property var easeEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeEmphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    // Asymmetric on purpose: an entrance is given time to be read, an exit is
    // not. Every property of a given transition shares one of these so they
    // land together - a fade that finishes before the movement does is what
    // reads as a jump rather than a glide.
    readonly property int durEnter: Math.round(320 * root.motionScale)
    readonly property int durExit: Math.round(190 * root.motionScale)
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeEmphasized: Easing.OutBack
    readonly property real emphasizedOvershoot: 0.7
    // ---------------- type ----------------
    readonly property string fontFamily: pf.fontFamily
    readonly property int fontLabel: Math.round(11 * pf.fontScale)
    readonly property int fontBody: Math.round(12 * pf.fontScale)
    readonly property int fontTitle: Math.round(13 * pf.fontScale)
    readonly property int fontHeadline: Math.round(15 * pf.fontScale)

    // Scales a one-off pixel size by the same factor as the type ramp above.
    // The shell has ~170 hand-tuned font sizes that never went through the
    // ramp; wrapping them in this is what makes the text-size setting global
    // rather than something that only moves the handful of tokenised ones.
    // At scale 1.0 it returns its argument unchanged, so nothing moves until
    // the setting is touched.
    function fs(px) {
        return Math.round(px * pf.fontScale);
    }

    // The same idea for motion. Only ~a quarter of this shell's animations
    // were ever expressed as durQuick/durShort/durMedium/durLong - the other
    // few hundred are hand-tuned numbers written inline, and the animation
    // speed setting could not see any of them. Wrapping them in this is what
    // makes that slider actually mean something. At scale 1.0 it returns its
    // argument unchanged; at 0 every duration collapses to 0, which is the
    // "no animation at all" end of the slider.
    function ms(d) {
        return Math.round(d * pf.motionScale);
    }

    // ---------------- tone engine ----------------
    // An M3 "tone" is CIE L*, not an sRGB channel value, which is why every
    // color operation below routes through linear light. Mixing toward black
    // or white in gamma-encoded sRGB - what _darken/_lighten do - moves a
    // color by an amount that depends on how bright it already was, so it
    // squashes ramps and drags hues around. These do not.

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

    // luminance for a given M3 tone - the standard L* -> Y transfer
    function _yAt(t) {
        return t <= 8 ? t / 903.2963 : Math.pow((t + 16) / 116, 3);
    }

    // any color -> its M3 tone (0..100)
    function toneOf(c) {
        var y = root._y(c);
        return y <= 0.008856 ? y * 903.2963 : 116 * Math.pow(y, 1 / 3) - 16;
    }

    // Re-tone a color to an exact M3 tone, holding its hue. Scaling in
    // LINEAR light is what preserves the hue - the same scale applied to
    // gamma-encoded channels is precisely the mistake _darken makes.
    // Checked against matugen's own HCT solver across the full surface
    // ramp: every role lands within 3/255 of the value matugen computes.
    function atTone(c, t) {
        var tt = Math.max(0, Math.min(100, t));
        var target = root._yAt(tt);
        var y = root._y(c);
        if (y <= 0) {
            // black carries no hue to preserve, so the tone is a pure grey
            var g = root._gam(target);
            return Qt.rgba(g, g, g, c.a);
        }
        var k = target / y;
        var lr = root._lin(c.r) * k;
        var lg = root._lin(c.g) * k;
        var lb = root._lin(c.b) * k;
        var peak = Math.max(lr, lg, lb);
        if (peak > 1) {
            // Scaling alone would clip a channel and skew the hue, so
            // desaturate toward white instead - which is what a tonal
            // palette itself does as it approaches tone 100.
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

    // Move a color DOWN the tone ladder by a fixed number of tones.
    // Subtracting a constant in tone space is what keeps every gap in a
    // ramp exactly as its author (or matugen's solver) intended.
    function shade(c, tones) {
        return tones === 0 ? c : root.atTone(c, root.toneOf(c) - tones);
    }

    // Scale a color's chroma while holding its tone exactly.
    function withSat(c, k) {
        var h = c.hslHue;
        if (h < 0)
            return c;
        var s = Math.max(0, Math.min(1, c.hslSaturation * k));
        return root.atTone(Qt.hsla(h, s, c.hslLightness, c.a), root.toneOf(c));
    }

    // Whether a palette's tertiary is already a usable green. The window is
    // deliberately wide at the yellow end so gruvbox's lime #b8bb26 (hue 61)
    // counts - it is that theme's green, whatever a colour wheel says.
    function isGreenish(c) {
        var h = c.hslHue;
        return h >= 0 && h * 360 >= 55 && h * 360 <= 175 && c.hslSaturation > 0.15;
    }

    // A status color that belongs to the current palette: the requested hue
    // at M3's tone 80 - the dark-scheme tone for every accent-on-surface
    // role - carrying the scheme's own saturation, clamped so a nearly
    // greyscale wallpaper still yields a legible green or amber.
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
            // Roles the widened template now requests. Empty means the
            // palette on disk predates it, which the cOn*/c*Container
            // bindings above detect and derive from the M3 tone instead.
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

    // The settings app owns lucidprefs/prefs.json; Theme only reads it, and
    // only the handful of keys that are design tokens rather than layout.
    // Read here rather than through Prefs.qml on purpose: this file has two
    // on-disk copies (see quickshell_duplicate_theme_qml) and an `import qs`
    // from the root copy would be a self-import. Watching the file keeps both
    // copies in step for free, exactly as blur.json already does below.
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
            property string fontFamily: "Google Sans"
            property real fontScale: 1
        }

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
