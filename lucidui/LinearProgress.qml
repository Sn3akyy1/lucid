import QtQuick
import QtQuick.Shapes
import qs

// m3 expressive linear progress. wavy draws the active part as a travelling
// wave that flattens out whenever `animated` goes false
Item {
    id: lp

    property real value: 0
    property real thickness: 4
    property bool wavy: false
    property bool animated: true
    // off for a value that already arrives frame by frame
    property bool valueAnimated: true
    property real amplitude: 3
    property real wavelength: 28
    property color color: Theme.primary
    property color trackColor: Theme.secondaryContainer
    property real _v: Math.max(0, Math.min(1, lp.value))
    property real _amp: lp.wavy && lp.animated ? lp.amplitude : 0
    property real phase: 0
    readonly property real gap: lp.thickness + 2
    readonly property real split: lp._v * lp.width
    readonly property real _step: 3

    // x and the unit sin/cos at that x, rebuilt only when the geometry moves.
    // the phase then shifts the wave with an angle-sum, so no trig runs per frame
    readonly property var _table: {
        const x0 = lp.thickness / 2;
        const span = Math.max(0, lp.width - x0);
        const n = Math.floor(span / lp._step) + 1;
        const xs = new Array(n);
        const sn = new Array(n);
        const cs = new Array(n);
        const w = 2 * Math.PI / Math.max(0.0001, lp.wavelength);
        for (let i = 0; i < n; i++) {
            const x = x0 + i * lp._step;
            xs[i] = x;
            sn[i] = Math.sin(x * w);
            cs[i] = Math.cos(x * w);
        }
        return {
            "xs": xs,
            "sn": sn,
            "cs": cs
        };
    }

    function _wavePoints() {
        if (!lp.visible || lp._amp < 0.05)
            return [];

        const t = lp._table;
        const xs = t.xs;
        const mid = lp.height / 2;
        const end = Math.max(lp.thickness / 2, lp.split - lp.thickness / 2);
        const a = lp._amp;
        const cp = Math.cos(lp.phase);
        const sp = Math.sin(lp.phase);
        // every x strictly inside the sweep, then the endpoint exactly on it
        let n = 0;
        while (n < xs.length && xs[n] < end) n++;
        const pts = new Array(n + 1);
        for (let i = 0; i < n; i++) pts[i] = Qt.point(xs[i], mid + a * (t.sn[i] * cp - t.cs[i] * sp))
        const we = 2 * Math.PI / Math.max(0.0001, lp.wavelength);
        pts[n] = Qt.point(end, mid + a * Math.sin(end * we - lp.phase));
        return pts;
    }

    implicitWidth: 200
    implicitHeight: lp.wavy ? lp.thickness + lp.amplitude * 2 + 2 : lp.thickness

    Behavior on _v {
        enabled: lp.valueAnimated

        NumberAnimation {
            duration: Theme.durSlowEffects
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

    }

    Behavior on _amp {
        NumberAnimation {
            duration: Theme.durSlowEffects
        }

    }

    NumberAnimation on phase {
        running: lp.wavy && lp.animated && lp.visible
        from: 0
        to: Math.PI * 2
        duration: 1400
        loops: Animation.Infinite
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: Math.min(lp.width, lp.split + (lp._v > 0.001 ? lp.gap : 0))
        width: Math.max(0, lp.width - x)
        height: lp.thickness
        radius: lp.thickness / 2
        color: lp.trackColor
        visible: width > 0.5

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: lp.thickness
            height: lp.thickness
            radius: width / 2
            color: lp.color
            visible: parent.width > lp.thickness * 3
        }

    }

    Rectangle {
        visible: lp._amp < 0.05
        anchors.verticalCenter: parent.verticalCenter
        width: lp.split
        height: lp.thickness
        radius: lp.thickness / 2
        color: lp.color
    }

    Shape {
        visible: lp._amp >= 0.05 && lp.split > lp.thickness
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: lp.color
            strokeWidth: lp.thickness
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: lp._wavePoints()
            }

        }

    }

}
