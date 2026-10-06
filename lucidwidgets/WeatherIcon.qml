import "../lucidui/SymbolPaths.js" as Symbols
import QtQuick
import QtQuick.Shapes
import qs

// a condition as its material symbol, cut into its shapes so each can move:
// the sun spins, the moon rocks, clouds drift, rain falls, snow tumbles, fog
// slides, bolts flash. cloud and mist take the cloud ink, the rest the tint
Item {
    id: icon

    // clear, clear-night, partly, partly-night, cloud, rain, snow, storm, fog
    property string kind: "clear"
    property real size: Theme.dp(48)
    property color tint: Theme.accent
    property color cloudColor: Theme.subtext
    property bool animate: true
    // visible is the effective one, so a hidden card stops every drift and spin
    // rather than driving the animation clock for something nobody can see
    readonly property bool moving: icon.live && icon.visible
    readonly property bool live: icon.animate && Theme.motionScale > 0
    // the bar passes "sunny"/"cloudy"; everything else already matches
    readonly property var symbols: ({
        "clear": "clear_day",
        "sunny": "clear_day",
        "clear-night": "clear_night",
        "partly": "partly_cloudy_day",
        "partly-night": "partly_cloudy_night",
        "cloud": "cloud",
        "cloudy": "cloud",
        "rain": "rainy",
        "snow": "weather_snowy",
        "storm": "thunderstorm",
        "fog": "foggy"
    })
    readonly property string symbol: icon.symbols[icon.kind] || "cloud"
    // what is drawn; it trails the condition by a fade so a change does not snap
    property string shown: ""
    // [role, path, centre x, centre y] per shape, the cloud last
    readonly property var parts: Symbols.parts[icon.shown] || []
    // seconds, on a loop every period below divides, so it closes without a seam
    property real clock: 0

    // -1..1 over a period
    function wave(period, shift) {
        return Math.sin((icon.clock / period + shift) * 2 * Math.PI);
    }

    // 0..1 over a period
    function turn(period, shift) {
        const v = icon.clock / period + shift;
        return v - Math.floor(v);
    }

    // where shape i of its kind is in the fall, 0..1
    function fall(role, i) {
        const shift = i / Math.max(1, icon.parts.length - 1);
        return role === "drop" ? icon.turn(1.2, shift) : icon.turn(3, shift);
    }

    function offsetX(role, i, cy) {
        if (!icon.live)
            return 0;

        // a cloud with something hanging from it stays over it
        if (role === "cloud")
            return icon.shown === "cloud" ? 0.9 * icon.wave(6, 0) : (/^partly/.test(icon.shown) ? 0.5 * icon.wave(6, 0) : 0);

        // along the lean of the drop
        if (role === "drop")
            return 0.4 * (icon.fall(role, i) - 0.5) * 3;

        if (role === "flake")
            return 0.35 * icon.wave(3, i * 0.37);

        // the two rows of mist pass each other
        if (role === "mist")
            return (cy < 19.5 ? 0.8 : -0.8) * icon.wave(6, 0);

        return 0;
    }

    function offsetY(role, i) {
        if (!icon.live)
            return 0;

        if (role === "drop")
            return (icon.fall(role, i) - 0.5) * 3;

        if (role === "flake")
            return (icon.fall(role, i) - 0.5) * 2.4;

        return 0;
    }

    function angle() {
        if (!icon.live)
            return 0;

        if (icon.shown === "clear_day")
            return icon.turn(30, 0) * 360;

        if (icon.shown === "clear_night")
            return 7 * icon.wave(6, 0);

        return 0;
    }

    // behind a cloud the rays cannot go round, so they breathe
    function swell(role) {
        if (!icon.live || role !== "ray" || icon.shown !== "partly_cloudy_day")
            return 1;

        return 1 + 0.07 * icon.wave(3, 0);
    }

    function ink(role, i) {
        if (!icon.live)
            return 1;

        if (role === "drop" || role === "flake") {
            const t = icon.fall(role, i);
            return Math.min(1, t * 4, (1 - t) * 4);
        }
        if (role === "bolt") {
            const t = icon.turn(2.4, i * 0.5);
            return t < 0.05 ? 0.25 : (t < 0.1 ? 1 : (t < 0.15 ? 0.35 : 1));
        }
        return 1;
    }

    implicitWidth: icon.size
    implicitHeight: icon.size
    onSymbolChanged: {
        if (icon.shown !== "" && icon.shown !== icon.symbol)
            swap.restart();

    }
    Component.onCompleted: icon.shown = icon.symbol

    NumberAnimation on clock {
        from: 0
        to: 120
        duration: Theme.ms(120000)
        loops: Animation.Infinite
        running: icon.moving
    }

    SequentialAnimation {
        id: swap

        NumberAnimation {
            target: stage
            property: "opacity"
            to: 0
            duration: Theme.ms(130)
        }

        ScriptAction {
            script: icon.shown = icon.symbol
        }

        NumberAnimation {
            target: stage
            property: "opacity"
            to: 1
            duration: Theme.ms(130)
        }

    }

    Item {
        id: stage

        readonly property real drawn: Math.round(icon.size * 1.1)

        anchors.centerIn: parent
        width: stage.drawn
        height: stage.drawn

        // google's 24 grid, scaled to the size asked for
        Item {
            width: 24
            height: 24

            Repeater {
                model: icon.parts.length

                Shape {
                    id: part

                    required property int index
                    readonly property var spec: icon.parts[part.index] || ["", "", 12, 12]
                    readonly property string role: part.spec[0]

                    x: icon.offsetX(part.role, part.index, part.spec[3])
                    y: icon.offsetY(part.role, part.index)
                    width: 24
                    height: 24
                    rotation: icon.angle()
                    scale: icon.swell(part.role)
                    opacity: icon.ink(part.role, part.index)
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 0
                        strokeColor: "transparent"
                        fillColor: part.role === "cloud" || part.role === "mist" ? icon.cloudColor : icon.tint

                        PathSvg {
                            path: part.spec[1]
                        }

                    }

                }

            }

            transform: Scale {
                xScale: stage.drawn / 24
                yScale: stage.drawn / 24
            }

        }

    }

}
