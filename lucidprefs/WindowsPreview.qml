import QtQuick
import QtQuick.Effects
import Quickshell
import qs

// tiled windows drawn from the options in force: close up, gaps, borders,
// corners, shadow and dimming read at their real size; whole, the layout
Rectangle {
    id: preview

    readonly property var shown: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenW: preview.shown ? preview.shown.width : 1920
    readonly property real screenH: preview.shown ? preview.shown.height : 1080
    readonly property real reserved: Prefs.barEnabled ? Prefs.barHeight : 0
    // a close look shows the left three fifths, so a 2 px border still shows
    readonly property real zoom: screen.width / (preview.screenW * preview.viewFraction)
    readonly property real gapsIn: HyprConfig.num("general.gaps_in", 5)
    readonly property real gapsOut: HyprConfig.num("general.gaps_out", 20)
    readonly property real border: HyprConfig.num("general.border_size", 2)
    readonly property real rounding: HyprConfig.num("decoration.rounding", 10)
    readonly property bool shadowOn: HyprConfig.bool("decoration.shadow.enabled", false)
    readonly property real shadowRange: HyprConfig.num("decoration.shadow.range", 20)
    readonly property bool dimOn: HyprConfig.bool("decoration.dim_inactive", false)
    readonly property real dimStrength: HyprConfig.num("decoration.dim_strength", 0.5)
    readonly property var activeColours: HyprConfig.coloursOf(HyprConfig.value("general.col.active_border"))
    readonly property var inactiveColours: HyprConfig.coloursOf(HyprConfig.value("general.col.inactive_border"))
    // how many windows, and how much of the screen's width shows: a close
    // look for borders and corners, the whole screen for the layout
    property int count: 3
    // the newest window has the focus; close up the first one stands in for it
    property bool newestActive: false
    property real viewFraction: 0.6
    readonly property string layout: String(HyprConfig.value("general.layout") || "dwindle")
    readonly property bool solo: HyprConfig.choice("lucid.solo") === true && preview.count === 1
    readonly property real gapsInShown: preview.solo ? 0 : preview.gapsIn
    readonly property real gapsOutShown: preview.solo ? 0 : preview.gapsOut
    // the work area, in screen pixels
    readonly property real areaX: preview.gapsOutShown
    readonly property real areaY: preview.reserved + preview.gapsOutShown
    readonly property real areaW: preview.screenW - 2 * preview.gapsOutShown
    readonly property real areaH: preview.screenH - preview.reserved - 2 * preview.gapsOutShown
    readonly property var boxes: {
        const a = {
            "x": preview.areaX,
            "y": preview.areaY,
            "w": preview.areaW,
            "h": preview.areaH
        };
        let raw;
        if (preview.layout === "master")
            raw = preview.masterTiles(a, preview.count);
        else if (preview.layout === "scrolling")
            raw = preview.scrollingTiles(a, preview.count);
        else
            raw = preview.dwindleTiles(a, preview.count);
        // gaps_in goes on every side that faces another window, not the screen
        const g = preview.gapsInShown;
        const near = (p, q) => {
            return Math.abs(p - q) < 0.5;
        };
        return raw.map((b, i) => {
            const l = near(b.x, a.x) ? 0 : g;
            const t = near(b.y, a.y) ? 0 : g;
            const r = near(b.x + b.w, a.x + a.w) ? 0 : g;
            const bt = near(b.y + b.h, a.y + a.h) ? 0 : g;
            return {
                "x": b.x + l,
                "y": b.y + t,
                "w": Math.max(1, b.w - l - r),
                "h": Math.max(1, b.h - t - bt),
                "active": preview.newestActive ? i === raw.length - 1 : i === 0
            };
        });
    }

    // each new window splits the newest one, which is where focus sits
    function dwindleTiles(a, n) {
        const mult = HyprConfig.num("dwindle.split_width_multiplier", 1);
        const force = HyprConfig.num("dwindle.force_split", 0);
        const ratio = Math.max(0.1, Math.min(1.9, HyprConfig.num("dwindle.default_split_ratio", 1)));
        const out = [a];
        for (let i = 1; i < n; i++) {
            const last = out.pop();
            const side = last.w > last.h * mult;
            const f = ratio / 2;
            let first, second;
            if (side) {
                first = { "x": last.x, "y": last.y, "w": last.w * f, "h": last.h };
                second = { "x": last.x + last.w * f, "y": last.y, "w": last.w * (1 - f), "h": last.h };
            } else {
                first = { "x": last.x, "y": last.y, "w": last.w, "h": last.h * f };
                second = { "x": last.x, "y": last.y + last.h * f, "w": last.w, "h": last.h * (1 - f) };
            }
            // left or top takes the new window only when told to
            if (force === 1)
                out.push(second, first);
            else
                out.push(first, second);
        }
        return out;
    }

    function masterTiles(a, n) {
        if (n <= 1)
            return [a];

        const mfact = Math.max(0.05, Math.min(0.95, HyprConfig.num("master.mfact", 0.55)));
        let orient = String(HyprConfig.value("master.orientation") || "left");
        if (orient === "center" && n === 2)
            orient = "left";

        const stack = (box, k, across) => {
            const out = [];
            for (let i = 0; i < k; i++)
                out.push(across ? { "x": box.x + box.w * i / k, "y": box.y, "w": box.w / k, "h": box.h } : { "x": box.x, "y": box.y + box.h * i / k, "w": box.w, "h": box.h / k });
            return out;
        };
        if (orient === "center") {
            const mw = a.w * mfact;
            const side = (a.w - mw) / 2;
            const master = { "x": a.x + side, "y": a.y, "w": mw, "h": a.h };
            const right = Math.ceil((n - 1) / 2);
            return [master].concat(stack({ "x": a.x + side + mw, "y": a.y, "w": side, "h": a.h }, right, false), stack({ "x": a.x, "y": a.y, "w": side, "h": a.h }, n - 1 - right, false));
        }
        if (orient === "top" || orient === "bottom") {
            const mh = a.h * mfact;
            const top = orient === "top";
            const master = { "x": a.x, "y": top ? a.y : a.y + a.h - mh, "w": a.w, "h": mh };
            return [master].concat(stack({ "x": a.x, "y": top ? a.y + mh : a.y, "w": a.w, "h": a.h - mh }, n - 1, true));
        }
        const mw = a.w * mfact;
        const left = orient !== "right";
        const master = { "x": left ? a.x : a.x + a.w - mw, "y": a.y, "w": mw, "h": a.h };
        return [master].concat(stack({ "x": left ? a.x + mw : a.x, "y": a.y, "w": a.w - mw, "h": a.h }, n - 1, false));
    }

    // columns side by side, the view kept on the newest
    function scrollingTiles(a, n) {
        const one = n === 1 && HyprConfig.bool("scrolling.fullscreen_on_one_column", true);
        const cw = one ? a.w : a.w * Math.max(0.1, Math.min(1, HyprConfig.num("scrolling.column_width", 0.5)));
        const shift = Math.max(0, n * cw - a.w);
        const out = [];
        for (let i = 0; i < n; i++)
            out.push({ "x": a.x + i * cw - shift, "y": a.y, "w": cw, "h": a.h });
        return out;
    }

    radius: Theme.radiusMd
    color: Theme.bgTile
    // close up a fixed strip; whole, the screen's own proportions
    implicitHeight: preview.viewFraction >= 1 ? Math.round((preview.width - 28) * preview.screenH / preview.screenW) + 28 : 230

    Rectangle {
        id: screen

        anchors.fill: parent
        anchors.margins: 14
        radius: Theme.radiusXs
        color: Theme.bgSunken
        clip: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.accent, 0.16)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.accent, 0.03)
                }

            }

        }

        // the bar's reserved strip
        Rectangle {
            width: parent.width
            height: preview.reserved * preview.zoom
            color: Theme.bgTile
        }

        Repeater {
            model: preview.boxes

            Item {
                id: win

                required property var modelData
                readonly property var colours: win.modelData.active ? preview.activeColours : preview.inactiveColours
                readonly property real b: (preview.solo ? 0 : preview.border) * preview.zoom
                readonly property real r: (preview.solo ? 0 : preview.rounding) * preview.zoom

                x: win.modelData.x * preview.zoom
                y: win.modelData.y * preview.zoom
                width: win.modelData.w * preview.zoom
                height: win.modelData.h * preview.zoom
                layer.enabled: preview.shadowOn
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.6
                    blurMax: 48
                    shadowBlur: Math.min(1, preview.shadowRange * preview.zoom / 48)
                }

                // the border, drawn under the window so its corners follow the rounding
                Rectangle {
                    anchors.fill: parent
                    radius: win.r + win.b
                    visible: win.b > 0

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: win.colours[0]
                        }

                        GradientStop {
                            position: 0.5
                            color: win.colours[Math.min(1, win.colours.length - 1)]
                        }

                        GradientStop {
                            position: 1
                            color: win.colours[win.colours.length - 1]
                        }

                    }

                }

                Rectangle {
                    x: win.b
                    y: win.b
                    width: parent.width - 2 * win.b
                    height: parent.height - 2 * win.b
                    radius: win.r
                    color: Theme.bgActive
                    clip: true

                    Column {
                        x: 14
                        y: 14
                        spacing: 8

                        Repeater {
                            model: [0.55, 0.8, 0.4, 0.7]

                            Rectangle {
                                required property real modelData

                                width: (win.width - 28) * modelData
                                height: 6
                                radius: 3
                                color: Theme.alpha(Theme.text, 0.16)
                            }

                        }

                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: win.r
                        color: "#000000"
                        opacity: preview.dimOn && !win.modelData.active ? preview.dimStrength : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                }

            }

        }

    }

}
