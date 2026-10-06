pragma Singleton

import QtQuick
import QtCore

// lucid's tokens, as sddm can have them. every colour is written by
// sync-sddm.sh, which reads them off the running shell rather than
// re-deriving them - the tone maths in the shell's Theme.qml is not
// reproducible from the palette file alone.
// each account paints its own users/<name>/, so the greeter wears whoever is
// picked; theme.conf beside Main.qml is only the fallback for the unpainted.
// an Item rather than a QtObject so the colours can carry Behaviors
Item {
    id: root

    // a palette swap moves with the wallpaper, on the desktop's own fade
    component Glide: Behavior {
        enabled: root.settled

        ColorAnimation {
            duration: root.lookMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.easeLook
        }

    }

    // false until the greeter has picked its first account, so the boot
    // palette lands at once instead of gliding in from the fallback
    property bool settled: false
    // whose wallpaper and colours are showing
    readonly property string look: Lock.lookName
    // users/<name>/ is plain data written by that account: ini and a jpeg,
    // never qml, so no account can put code in front of another's password
    readonly property url lookDir: Qt.resolvedUrl("../users/" + encodeURIComponent(root.look) + "/")
    // an account counts as painted once its palette is there
    readonly property bool lookOwn: {
        void lookConf.location;
        return root.look !== "" && lookConf.value("accent", "") !== "";
    }
    readonly property url background: {
        if (root.lookOwn)
            return root.lookDir + "background.jpg";

        const shared = config.background;
        return shared ? Qt.resolvedUrl("../" + shared) : "";
    }
    readonly property int lookMs: 1000
    // awww's own fade curve, the one the desktop crossfades its palette on
    readonly property var easeLook: [0.54, 0, 0.34, 0.99, 1, 1]

    // read-only: Settings writes only what is set through it, and nothing is
    Settings {
        id: lookConf

        location: root.lookDir + "theme.conf"
    }

    function conf(key, fallback) {
        // read the location so every binding through here re-runs on a switch
        void lookConf.location;
        var v = root.lookOwn ? lookConf.value(key, "") : "";
        if (v === undefined || v === null || v === "")
            v = config[key];

        return (v === undefined || v === null || v === "") ? fallback : v;
    }

    function num(key, fallback) {
        var v = parseFloat(root.conf(key, ""));
        return isNaN(v) ? fallback : v;
    }

    readonly property bool isLight: root.conf("isLight", "false") === "true"

    property color accent: root.conf("accent", "#ffb1c4")
    property color accentHover: root.conf("accentHover", "#ffc9d6")
    property color fgAccent: root.conf("fgAccent", "#5e1130")
    property color accentMuted: root.conf("accentMuted", "#c98a9b")
    property color accentContainer: root.conf("accentContainer", "#762744")
    property color fgAccentContainer: root.conf("fgAccentContainer", "#ffd9e1")
    // the lock clock's hour: the primary hue lifted almost to white
    property color clockHour: root.conf("clockHour", root.text)

    property color bgOpaque: root.conf("bgOpaque", "#0f080a")
    property color bgHigh: root.conf("bgHigh", "#3a3032")
    property color text: root.conf("text", "#efdfe1")
    property color subtext: root.conf("subtext", "#d6c2c6")
    property color subtextDim: root.conf("subtextDim", "#aa9a9d")
    property color outline: root.conf("outline", "#524347")
    property color outlineStrong: root.conf("outlineStrong", "#9e8c90")

    property color error: root.conf("error", "#ffb4ab")
    property color fgError: root.conf("fgError", "#690005")
    // the shell derives this in L* tone space; sync-sddm.sh reads it off the
    // running Theme rather than trying to redo that maths here
    property color errorHover: root.conf("errorHover", "#ffc2bb")
    property color success: root.conf("success", "#36e27e")
    property color fgSuccess: root.conf("fgSuccess", "#06381b")
    property color warning: root.conf("warning", "#eec13a")
    property color cScrim: root.conf("scrim", "#000000")

    // every colour glides; card and cardHigh follow bgOpaque and bgHigh
    Glide on accent {
    }

    Glide on accentHover {
    }

    Glide on fgAccent {
    }

    Glide on accentMuted {
    }

    Glide on accentContainer {
    }

    Glide on fgAccentContainer {
    }

    Glide on clockHour {
    }

    Glide on bgOpaque {
    }

    Glide on bgHigh {
    }

    Glide on text {
    }

    Glide on subtext {
    }

    Glide on subtextDim {
    }

    Glide on outline {
    }

    Glide on outlineStrong {
    }

    Glide on error {
    }

    Glide on fgError {
    }

    Glide on errorHover {
    }

    Glide on success {
    }

    Glide on fgSuccess {
    }

    Glide on warning {
    }

    Glide on cScrim {
    }


    // solid m3 containers, the same two Lockscreen.qml draws its cards with
    readonly property color card: root.bgOpaque
    readonly property color cardHigh: root.bgHigh

    // the flex cut the shell bundles, installed beside the theme. the shell
    // has called it both names, and the sddm user can read neither from ~
    readonly property FontLoader flex: FontLoader {
        source: Qt.resolvedUrl("../fonts/GoogleSansFlex.ttf")
    }
    readonly property bool flexActive: root.flex.status === FontLoader.Ready && root.fontFamily === root.flex.name
    readonly property string fontFamily: {
        const f = root.conf("fontFamily", "Google Sans");
        const brand = f === "Google Sans" || f === "Google Sans Flex";
        return (brand && root.flex.status === FontLoader.Ready) ? root.flex.name : f;
    }
    readonly property real fontScale: root.num("fontScale", 0.9)
    readonly property real motionScale: root.num("motionScale", 1.125)

    readonly property int shapeSm: 8
    readonly property int shapeMd: 12
    readonly property int shapeLg: 16
    readonly property int shapeXl: 28
    readonly property real stateHover: 0.08
    readonly property real statePressed: 0.1

    function fs(px) {
        return Math.round(px * root.fontScale);
    }

    function ms(d) {
        return Math.round(d * root.motionScale);
    }

    // Theme.axes from the shell: opsz snapped to a ladder so qt does not
    // build a font engine per pixel size
    readonly property var _opszStops: [9, 13, 18, 28, 48, 96]

    function _snap(px) {
        var v = Math.max(6, Math.min(144, px));
        var best = root._opszStops[0];
        for (var i = 1; i < root._opszStops.length; i++) {
            if (Math.abs(root._opszStops[i] - v) < Math.abs(best - v))
                best = root._opszStops[i];

        }
        return best;
    }

    function axes(px, wght, rond) {
        if (!root.flexActive)
            return ({});

        return ({
            "wght": Math.round((wght || 400) / 25) * 25,
            "opsz": root._snap(px),
            "ROND": Math.round((rond || 0) / 10) * 10
        });
    }

    readonly property int fontLabelSm: root.fs(11)
    readonly property int fontLabelMd: root.fs(12)
    readonly property int fontLabelLg: root.fs(13)
    readonly property int fontBodySm: root.fs(12)
    readonly property int fontBodyMd: root.fs(13)
    readonly property int fontBodyLg: root.fs(15)
    readonly property int fontTitleSm: root.fs(14)
    readonly property int fontTitleMd: root.fs(16)
    readonly property int fontTitleLg: root.fs(19)
    readonly property int fontHeadlineSm: root.fs(22)

    readonly property var easeEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeEmphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property int easeEmphasized: Easing.OutBack
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property int durFastSpatial: root.ms(350)
    readonly property int durDefaultEffects: root.ms(200)
    readonly property int durShort: root.ms(180)
    readonly property int durMedium: root.ms(280)

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
}
