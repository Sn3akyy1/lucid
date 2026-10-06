import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: mark

    property color ringColor: Theme.accent
    property color starColor: Theme.text
    property real strokeWidth: 3
    // intro progress, 0..1 each; the resting mark is all three at 1
    property real ringT: 1
    property real starT: 1
    property real dotT: 1
    readonly property real dotRestA: Math.atan2(2.6, 9)
    readonly property real dotRestR: Math.sqrt(9 * 9 + 2.6 * 2.6)

    function play() {
        mark.ringT = 0;
        mark.starT = 0;
        mark.dotT = 0;
        intro.restart();
    }

    function arcPath(cx, cy, r, a0, a1) {
        var t0 = a0 * Math.PI / 180, t1 = a1 * Math.PI / 180;
        var large = Math.abs(a1 - a0) > 180 ? 1 : 0;
        var sweep = a1 > a0 ? 0 : 1;
        return "M" + (cx + r * Math.cos(t0)).toFixed(2) + "," + (cy - r * Math.sin(t0)).toFixed(2) + " A" + r + "," + r + " 0 " + large + " " + sweep + " " + (cx + r * Math.cos(t1)).toFixed(2) + "," + (cy - r * Math.sin(t1)).toFixed(2);
    }

    function sparklePath(x, y, s, deg) {
        var k = s * 0.3, j = s * 0.13;
        var c = Math.cos(deg * Math.PI / 180), n = Math.sin(deg * Math.PI / 180);
        var pt = function(dx, dy) {
            return (x + dx * c - dy * n).toFixed(3) + "," + (y + dx * n + dy * c).toFixed(3);
        };
        return "M" + pt(0, -s) + " C" + pt(j, -k) + " " + pt(k, -j) + " " + pt(s, 0) + " C" + pt(k, j) + " " + pt(j, k) + " " + pt(0, s) + " C" + pt(-j, k) + " " + pt(-k, j) + " " + pt(-s, 0) + " C" + pt(-k, -j) + " " + pt(-j, -k) + " " + pt(0, -s) + " Z";
    }

    function circlePath(cx, cy, r) {
        return "M" + (cx - r) + "," + cy + " A" + r + "," + r + " 0 1 0 " + (cx + r) + "," + cy + " A" + r + "," + r + " 0 1 0 " + (cx - r) + "," + cy + " Z";
    }

    implicitWidth: Theme.dp(24)
    implicitHeight: Theme.dp(24)

    // ring swings round as it draws, star twinkles open, companion flung into orbit
    ParallelAnimation {
        id: intro

        NumberAnimation {
            target: mark
            property: "ringT"
            from: 0
            to: 1
            duration: Theme.ms(950)
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation {
                duration: Theme.ms(220)
            }

            NumberAnimation {
                target: mark
                property: "starT"
                from: 0
                to: 1
                duration: Theme.durSlowSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        SequentialAnimation {
            PauseAnimation {
                duration: Theme.ms(620)
            }

            NumberAnimation {
                target: mark
                property: "dotT"
                from: 0
                to: 1
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: mark.ringColor
            strokeWidth: mark.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: mark.ringT <= 0 ? "" : mark.arcPath(12, 12, 7.4, 58 - 200 * (1 - mark.ringT), 58 - 200 * (1 - mark.ringT) + 282 * mark.ringT)
            }

        }

        ShapePath {
            strokeWidth: 0
            fillColor: mark.starColor

            PathSvg {
                path: mark.starT <= 0 ? "" : mark.sparklePath(12, 12, 4.6 * mark.starT, 90 * (1 - mark.starT))
            }

        }

        ShapePath {
            strokeWidth: 0
            fillColor: mark.ringColor

            PathSvg {
                path: {
                    if (mark.dotT <= 0)
                        return "";

                    var a = mark.dotRestA - 0.7 * (1 - mark.dotT);
                    var r = 7.4 + (mark.dotRestR - 7.4) * mark.dotT;
                    return mark.circlePath(12 + r * Math.cos(a), 12 - r * Math.sin(a), mark.dotT);
                }
            }

        }

        // authored on a 24x24 grid
        transform: Scale {
            xScale: mark.width / 24
            yScale: mark.height / 24
        }

    }

}
