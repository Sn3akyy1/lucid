pragma Singleton

import QtQuick

// lucid's tokens, as sddm can have them. every colour is written into
// theme.conf by sync-sddm.sh, which reads them off the running shell rather
// than re-deriving them - the tone maths in the shell's Theme.qml is not
// reproducible from the palette file alone
QtObject {
    id: root

    function conf(key, fallback) {
        var v = config[key];
        return (v === undefined || v === null || v === "") ? fallback : v;
    }

    function num(key, fallback) {
        var v = parseFloat(root.conf(key, ""));
        return isNaN(v) ? fallback : v;
    }

    readonly property bool isLight: root.conf("isLight", "false") === "true"

    readonly property color accent: root.conf("accent", "#ffb1c4")
    readonly property color accentHover: root.conf("accentHover", "#ffc9d6")
    readonly property color fgAccent: root.conf("fgAccent", "#5e1130")
    readonly property color accentMuted: root.conf("accentMuted", "#c98a9b")
    readonly property color accentContainer: root.conf("accentContainer", "#762744")
    readonly property color fgAccentContainer: root.conf("fgAccentContainer", "#ffd9e1")
    // the lock clock's hour: the primary hue lifted almost to white
    readonly property color clockHour: root.conf("clockHour", root.text)

    readonly property color bgOpaque: root.conf("bgOpaque", "#0f080a")
    readonly property color bgHigh: root.conf("bgHigh", "#3a3032")
    readonly property color text: root.conf("text", "#efdfe1")
    readonly property color subtext: root.conf("subtext", "#d6c2c6")
    readonly property color subtextDim: root.conf("subtextDim", "#aa9a9d")
    readonly property color outline: root.conf("outline", "#524347")
    readonly property color outlineStrong: root.conf("outlineStrong", "#9e8c90")

    readonly property color error: root.conf("error", "#ffb4ab")
    readonly property color fgError: root.conf("fgError", "#690005")
    // the shell derives this in L* tone space; sync-sddm.sh reads it off the
    // running Theme rather than trying to redo that maths here
    readonly property color errorHover: root.conf("errorHover", "#ffc2bb")
    readonly property color success: root.conf("success", "#36e27e")
    readonly property color fgSuccess: root.conf("fgSuccess", "#06381b")
    readonly property color warning: root.conf("warning", "#eec13a")
    readonly property color cScrim: root.conf("scrim", "#000000")

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

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
}
