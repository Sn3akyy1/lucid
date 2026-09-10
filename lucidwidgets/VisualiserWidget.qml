import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs

WidgetBody {
    id: w

    readonly property string density: w.opt("density") === undefined ? "normal" : w.opt("density")
    readonly property bool flip: w.opt("flip") === true
    readonly property bool rounded: w.opt("rounded") !== false
    // frosted bars, on whenever the shell's own blur is on
    readonly property bool frosted: w.opt("frost") !== false && Theme.blurAmount > 0 && !w.preview && w.wallpaper !== ""
    property string wallpaper: ""
    // where this card sits on the board, so the sampled pixels line up with what
    // the wallpaper daemon is actually drawing under it
    readonly property real hostZoom: (w.host && w.host.zoom > 0) ? w.host.zoom : 1
    readonly property real boardX: (!w.preview && w.host) ? w.host.x : 0
    readonly property real boardY: (!w.preview && w.host) ? w.host.y : 0
    readonly property real boardW: (!w.preview && w.host && w.host.board) ? w.host.board.width : 1920
    readonly property real boardH: (!w.preview && w.host && w.host.board) ? w.host.board.height : 1080
    // a card you have just placed stays up for a moment even in silence, or dropping
    // one with nothing playing looks like it did nothing
    property bool fresh: false
    // nominal pixels per band, before the card's own width has its say
    readonly property int slotPeriod: w.density === "fine" ? 5 : (w.density === "wide" ? 18 : 9)
    readonly property int wantCount: Math.max(6, Math.min(Cava.maxBands, Math.round(w.width / w.slotPeriod)))
    // held steady while a grip is down: rebuilding 100 delegates every frame of a
    // resize stutters, and the bars stretch to fill the card in the meantime
    property int barCount: 8
    readonly property real slot: w.barCount > 0 ? w.width / w.barCount : 0
    readonly property real gapRatio: w.density === "fine" ? 0.5 : (w.density === "wide" ? 0.48 : 0.52)
    readonly property real gap: Math.max(1, w.slot * w.gapRatio)
    // a dead band while the rest are moving reads as a dot, not as a gap
    readonly property real minBar: Math.max(2, Math.min(w.slot - w.gap, w.height * 0.045))
    // the uid the demand was filed under, cached so teardown can withdraw it
    property string filed: ""
    // preview tiles have no process behind them, so they run off a clock
    property real phase: 0

    function refreshCount() {
        if (!w.resizing)
            w.barCount = w.wantCount;

    }

    function file() {
        if (w.preview || w.uid === "")
            return ;

        Cava.want(w.uid, w.barCount);
        w.filed = w.uid;
    }

    function fakeLevel(i) {
        var x = i / Math.max(1, w.barCount - 1);
        // loud at the bass end, and two beats of different lengths so it never
        // looks like it is looping
        var env = Math.pow(1 - x, 0.9) * 0.8 + 0.2;
        var v = 0.5 + 0.5 * Math.sin(w.phase * 2.1 + x * 9.4) * Math.sin(w.phase * 1.3 + x * 3.7);
        return Math.max(0.03, env * v);
    }

    function level(i) {
        if (w.preview)
            return w.fakeLevel(i);

        var src = Cava.levels;
        var n = src.length;
        if (n === 0)
            return 0;

        if (n === w.barCount)
            return src[i];

        // another card asked for more bands than this one draws, so fold them
        var from = Math.floor(i * n / w.barCount);
        var to = Math.min(n - 1, Math.max(from, Math.floor((i + 1) * n / w.barCount) - 1));
        var peak = 0;
        for (var k = from; k <= to; k++) peak = Math.max(peak, src[k])
        return peak;
    }

    // integer edges, so no bar lands on a half pixel and blurs
    function barLeft(i) {
        return Math.round(i * w.slot + w.gap / 2);
    }

    function barSpan(i) {
        return Math.max(1, Math.round((i + 1) * w.slot - w.gap / 2) - w.barLeft(i));
    }

    // an unknown mode (a card saved under the old neon "spectrum") falls through
    // to a flat accent rather than drawing nothing
    function tintAt(i) {
        var mode = w.opt("tint");
        if (mode === "mono")
            return Qt.rgba(1, 1, 1, 0.92);

        if (mode !== "gradient")
            return Theme.accent;

        // primary walked to tertiary, so the ramp is whatever matugen pulled out of
        // the wallpaper (or the static theme's own pair), never a fixed rainbow
        var t = i / Math.max(1, w.barCount - 1);
        var a = Theme.accent;
        var b = Theme.cTertiary;
        var c = Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
        // an sRGB walk between two roles drifts in brightness and leaves one end of
        // the strip looking dimmer, so pin the whole ramp to the accent's own tone
        return Theme.atTone(c, Theme.toneOf(a));
    }

    bare: true
    hidden: w.opt("idleFade") !== false && !w.preview && !w.fresh && !Cava.active
    onBornChanged: {
        if (w.born) {
            w.fresh = true;
            settle.restart();
        }
    }
    onWantCountChanged: w.refreshCount()
    onResizingChanged: w.refreshCount()
    onBarCountChanged: w.file()
    onUidChanged: {
        if (w.filed !== "" && w.filed !== w.uid)
            Cava.drop(w.filed);

        w.file();
    }
    Component.onCompleted: {
        w.refreshCount();
        w.file();
    }
    Component.onDestruction: Cava.drop(w.filed)

    FileView {
        id: wallFile

        path: Quickshell.env("HOME") + "/.cache/current_wallpaper"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: wallFile.reload()
        onLoaded: w.wallpaper = wallFile.text().trim()
        onLoadFailed: w.wallpaper = ""
    }

    Timer {
        id: settle

        interval: 5000
        onTriggered: w.fresh = false
    }

    Timer {
        interval: 55
        repeat: true
        running: w.preview
        onTriggered: w.phase += 0.055
    }

    // hyprland cannot frost the bars for us: its blur region is a readonly list, so
    // there is no way to hand the compositor one rect per bar, and a region round
    // the whole card would just frost a rectangle. the widget layer sits straight
    // on the wallpaper though, so blur a copy of that and mask it to the bars -
    // the same trick the lock screen uses. a card set to float over windows still
    // frosts the wallpaper, since that is all this can see
    Item {
        id: glass

        visible: w.frosted
        anchors.fill: parent
        layer.enabled: w.frosted

        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: w.variant === "wave" ? curve : columns
        }

        Image {
            id: wall

            x: -w.boardX / w.hostZoom
            y: -w.boardY / w.hostZoom
            width: w.boardW / w.hostZoom
            height: w.boardH / w.hostZoom
            source: w.wallpaper === "" ? "" : "file://" + w.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            x: wall.x
            y: wall.y
            width: wall.width
            height: wall.height
            source: wall
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: Math.max(0.55, Theme.blurAmount)
        }

    }

    Item {
        id: columns

        visible: w.variant === "bars" || w.variant === "mirror"
        anchors.fill: parent
        // over the glass the bar is a tint, not the whole colour
        opacity: w.frosted ? 0.55 : 1
        layer.enabled: w.frosted

        Repeater {
            model: columns.visible ? w.barCount : 0

            Rectangle {
                id: bar

                required property int index

                readonly property real level: w.level(bar.index)

                x: w.barLeft(bar.index)
                width: w.barSpan(bar.index)
                height: Math.max(w.minBar, bar.level * w.height)
                y: w.variant === "mirror" ? (w.height - bar.height) / 2 : (w.flip ? 0 : w.height - bar.height)
                radius: w.rounded ? Math.min(bar.width, bar.height) / 2 : 0
                color: w.tintAt(bar.index)
                antialiasing: w.rounded
            }

        }

    }

    Item {
        id: curve

        readonly property real base: w.flip ? 0 : w.height
        readonly property int dir: w.flip ? 1 : -1
        readonly property var line: {
            if (!curve.visible || w.width <= 0 || w.barCount < 2)
                return [];

            var out = [];
            for (var i = 0; i < w.barCount; i++) {
                var lv = w.level(i);
                out.push(Qt.point(i / (w.barCount - 1) * w.width, curve.base + curve.dir * Math.max(2, lv * (w.height - 4))));
            }
            return out;
        }
        readonly property var area: {
            if (curve.line.length < 2)
                return [];

            var edge = w.flip ? -3 : w.height + 3;
            return curve.line.concat([Qt.point(w.width, edge), Qt.point(0, edge)]);
        }

        visible: w.variant === "wave"
        anchors.fill: parent
        opacity: w.frosted ? 0.55 : 1
        layer.enabled: w.frosted

        Shape {
            anchors.fill: parent
            visible: curve.line.length > 1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0

                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: w.width
                    y2: 0

                    GradientStop {
                        position: 0
                        color: Theme.alpha(w.tintAt(0), 0.34)
                    }

                    GradientStop {
                        position: 0.55
                        color: Theme.alpha(w.tintAt(Math.floor(w.barCount / 2)), 0.3)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.alpha(w.tintAt(w.barCount - 1), 0.2)
                    }

                }

                PathPolyline {
                    path: curve.area
                }

            }

            ShapePath {
                strokeColor: w.tintAt(Math.floor(w.barCount / 2))
                strokeWidth: 2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: curve.line
                }

            }

        }

    }

}
