import QtQuick
import QtQuick.Shapes
import qs
import "Shapes.js" as Shapes

// m3 expressive loading indicator: one shape morphing through the sequence
// while it turns. `contained` sets it on a primary-container disc
Item {
    id: li

    property bool running: visible
    property bool contained: false
    property color color: li.contained ? Theme.fgPrimaryContainer : Theme.primary
    readonly property var sequence: ["softBurst", "cookie9", "pentagon", "pill", "sunny", "cookie4", "oval"]
    // one scale for every shape, so none leaves the box while it turns
    readonly property real fit: 1 / Math.max.apply(null, li.sequence.map((n) => Math.max.apply(null, Shapes.radii(n))))
    property real t: 0

    implicitWidth: Theme.dp(44)
    implicitHeight: Theme.dp(44)

    NumberAnimation on t {
        running: li.running && li.visible
        from: 0
        to: li.sequence.length
        duration: li.sequence.length * 650
        loops: Animation.Infinite
    }

    Rectangle {
        visible: li.contained
        anchors.fill: parent
        radius: width / 2
        color: Theme.primaryContainer
    }

    Shape {
        id: s

        readonly property int step: Math.floor(li.t) % li.sequence.length
        readonly property real f: li.t - Math.floor(li.t)
        // a spring-ish settle into each shape
        readonly property real e: 1 - Math.pow(1 - Math.min(1, s.f * 1.6), 3)
        readonly property real sz: li.width * (li.contained ? 0.62 : 0.84) * li.fit

        width: s.sz
        height: s.sz
        anchors.centerIn: parent
        rotation: li.t * 140 + s.e * 50
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: li.color
            strokeColor: "transparent"
            strokeWidth: 0

            PathSvg {
                path: Shapes.svg(Shapes.mix(Shapes.radii(li.sequence[s.step]), Shapes.radii(li.sequence[(s.step + 1) % li.sequence.length]), s.e), s.sz, 0)
            }

        }

    }

}
