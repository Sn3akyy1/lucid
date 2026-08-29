import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: mark

    property color ringColor: Theme.accent
    property color starColor: Theme.text
    property real strokeWidth: 3

    function arcPath(cx, cy, r, a0, a1) {
        var t0 = a0 * Math.PI / 180, t1 = a1 * Math.PI / 180;
        var large = Math.abs(a1 - a0) > 180 ? 1 : 0;
        var sweep = a1 > a0 ? 0 : 1;
        return "M" + (cx + r * Math.cos(t0)).toFixed(2) + "," + (cy - r * Math.sin(t0)).toFixed(2) + " A" + r + "," + r + " 0 " + large + " " + sweep + " " + (cx + r * Math.cos(t1)).toFixed(2) + "," + (cy - r * Math.sin(t1)).toFixed(2);
    }

    function sparklePath(x, y, s) {
        var k = s * 0.3, j = s * 0.13;
        return "M" + x + "," + (y - s) + " C" + (x + j) + "," + (y - k) + " " + (x + k) + "," + (y - j) + " " + (x + s) + "," + y + " C" + (x + k) + "," + (y + j) + " " + (x + j) + "," + (y + k) + " " + x + "," + (y + s) + " C" + (x - j) + "," + (y + k) + " " + (x - k) + "," + (y + j) + " " + (x - s) + "," + y + " C" + (x - k) + "," + (y - j) + " " + (x - j) + "," + (y - k) + " " + x + "," + (y - s) + " Z";
    }

    function circlePath(cx, cy, r) {
        return "M" + (cx - r) + "," + cy + " A" + r + "," + r + " 0 1 0 " + (cx + r) + "," + cy + " A" + r + "," + r + " 0 1 0 " + (cx - r) + "," + cy + " Z";
    }

    implicitWidth: 24
    implicitHeight: 24

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: mark.ringColor
            strokeWidth: mark.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: mark.arcPath(12, 12, 7.4, 58, 340)
            }

        }

        ShapePath {
            strokeWidth: 0
            fillColor: mark.starColor

            PathSvg {
                path: mark.sparklePath(12, 12, 4.6)
            }

        }

        ShapePath {
            strokeWidth: 0
            fillColor: mark.ringColor

            PathSvg {
                path: mark.circlePath(21, 9.4, 1)
            }

        }

        // authored on a 24x24 grid
        transform: Scale {
            xScale: mark.width / 24
            yScale: mark.height / 24
        }

    }

}
