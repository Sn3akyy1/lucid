import QtQuick
import qs

// the theme as the shared lock parts (lucidlock/parts) see it: every token
// they read and nothing more. the login screen's Theme carries the same names,
// and theme-dump.qml writes its colours out of an instance of this very file,
// so the two screens can never be painted from different maths
QtObject {
    id: tk

    // ── colours: theme-dump.qml sends every one of these to the login screen ──
    readonly property var colourKeys: ["accent", "accentHover", "fgAccent", "accentMuted", "accentContainer", "fgAccentContainer", "altContainer", "fgAltContainer", "altAccent", "clockHour", "card", "cardMid", "cardHigh", "cardLow", "text", "subtext", "subtextDim", "outline", "outlineStrong", "hairline", "error", "fgError", "errorHover", "errorContainer", "fgErrorContainer", "wrong", "wrongContainer", "fgWrongContainer", "success", "fgSuccess", "warning", "scrim"]
    readonly property bool isLight: Theme.isLight
    readonly property color accent: Theme.accent
    readonly property color accentHover: Theme.accentHover
    readonly property color fgAccent: Theme.fgAccent
    readonly property color accentMuted: Theme.accentMuted
    readonly property color accentContainer: Theme.accentContainer
    readonly property color fgAccentContainer: Theme.fgAccentContainer
    // the same hue a step brighter, for the second of two containers side by
    // side: one hue of card per screen, two tones of it
    readonly property color altContainer: Theme.containerFill(Theme._containerSeed, Theme.isLight ? 84 : Theme._containerTone + 14, Theme._cardSatFloor)
    readonly property color fgAltContainer: Theme.isLight ? Theme.containerFill(Theme._containerSeed, 22) : Theme.containerFill(Theme._containerSeed, 96)
    readonly property color altAccent: Theme.tertiary
    // the lock clock's hour: the primary hue lifted almost to white
    readonly property color clockHour: Theme.atTone(Theme.cPrimary, Theme.isLight ? 25 : 92)
    // solid m3 containers, so a busy wallpaper never reads through a card
    readonly property color card: Theme.surfaceContainer
    // between the two, as the shell's keyboard draws its keys
    readonly property color cardMid: Theme.surfaceHigh
    readonly property color cardHigh: Theme.surfaceHighest
    readonly property color cardLow: Theme.surfaceLow
    readonly property color text: Theme.text
    readonly property color subtext: Theme.subtext
    readonly property color subtextDim: Theme.subtextDim
    readonly property color outline: Theme.outline
    readonly property color outlineStrong: Theme.outlineStrong
    readonly property color hairline: Theme.alpha(Theme.outline, 0.45)
    readonly property color error: Theme.error
    readonly property color fgError: Theme.fgError
    readonly property color errorHover: Theme.atTone(Theme.error, Theme.toneOf(Theme.error) + (Theme.isLight ? -6 : 6))
    readonly property color errorContainer: Theme.errorContainer
    readonly property color fgErrorContainer: Theme.fgErrorContainer
    // a wrong password, in the palette's own voice (Theme.wrong)
    readonly property color wrong: Theme.wrong
    readonly property color wrongContainer: Theme.wrongContainer
    readonly property color fgWrongContainer: Theme.fgWrongContainer
    readonly property color success: Theme.success
    readonly property color fgSuccess: Theme.fgSuccess
    readonly property color warning: Theme.warning
    readonly property color scrim: Theme.cScrim

    // ── type, shape and motion ─────────────────────────────────────────────
    readonly property string fontFamily: Theme.fontFamily
    readonly property real fontScale: Theme.fontScale
    readonly property real uiScale: Theme.uiScale
    readonly property real cornerScale: Theme.cornerScale
    readonly property real motionScale: Theme.motionScale
    readonly property int shapeXs: Theme.shapeXs
    readonly property int shapeSm: Theme.shapeSm
    readonly property int shapeMd: Theme.shapeMd
    readonly property int shapeLg: Theme.shapeLg
    readonly property int shapeLgInc: Theme.shapeLgInc
    readonly property int shapeXl: Theme.shapeXl
    readonly property int shapeXlInc: Theme.shapeXlInc
    readonly property int shapeXxl: Theme.shapeXxl
    readonly property int fontLabelSm: Theme.fontLabelSm
    readonly property int fontLabelMd: Theme.fontLabelMd
    readonly property int fontLabelLg: Theme.fontLabelLg
    readonly property int fontBodySm: Theme.fontBodySm
    readonly property int fontBodyMd: Theme.fontBodyMd
    readonly property int fontBodyLg: Theme.fontBodyLg
    readonly property int fontTitleSm: Theme.fontTitleSm
    readonly property int fontTitleMd: Theme.fontTitleMd
    readonly property int fontTitleLg: Theme.fontTitleLg
    readonly property int fontHeadlineSm: Theme.fontHeadlineSm
    readonly property int fontHeadlineMd: Theme.fontHeadlineMd
    readonly property int fontHeadlineLg: Theme.fontHeadlineLg
    readonly property int fontDisplaySm: Theme.fontDisplaySm
    readonly property int fontDisplayMd: Theme.fontDisplayMd
    readonly property real stateHover: Theme.stateHover
    readonly property real statePressed: Theme.statePressed
    readonly property var easeEmphasizedDecel: Theme.easeEmphasizedDecel
    readonly property var easeEmphasizedAccel: Theme.easeEmphasizedAccel
    readonly property var curveStandard: Theme.curveStandard
    readonly property var curveEffects: Theme.curveEffects
    readonly property var curveFastSpatial: Theme.curveFastSpatial
    readonly property var curveDefaultSpatial: Theme.curveDefaultSpatial

    function dp(px) {
        return Theme.dp(px);
    }

    function rad(px) {
        return Theme.rad(px);
    }

    function pill(size) {
        return Theme.pill(size);
    }

    function ms(d) {
        return Theme.ms(d);
    }

    function fs(px) {
        return Theme.fs(px);
    }

    function axes(px, wght, rond) {
        return Theme.axes(px, wght, rond);
    }

    function alpha(c, a) {
        return Theme.alpha(c, a);
    }

    function mix(a, b, t) {
        return Theme._mix(a, b, t);
    }

}
