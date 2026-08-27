import QtQuick
import QtQuick.Shapes
import qs

// One concave corner joining the dock's side to the bottom of the screen.
//
// A notched dock meets the screen edge at a hard right angle. This fills the
// corner beside it with material that sweeps outward as it descends, tangent
// to the dock's side where it leaves and tangent to the screen edge where it
// lands - so the dock reads as carved out of the bottom of the display rather
// than parked on it.
//
// Traced as one continuous closed contour. `PathMove` does not start a new
// subpath in a ShapePath here - subpaths get chained onto the previous one -
// so the outline is drawn without lifting the pen.
//
// Drawn strictly *outside* the dock's own rectangle, never overlapping it: two
// translucent surfaces of one colour cannot be made to match, so with Glass on
// any overlap would show as a darker seam. The join has to be an edge.
Item {
    id: flare

    // false is the left-hand corner; the right-hand one is the same shape
    // mirrored, so the two can never drift apart when the radius changes
    property bool mirrored: false
    property int size: 14
    property color fillColor: Theme.bg

    implicitWidth: flare.size
    implicitHeight: flare.size
    visible: flare.size > 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        transform: Scale {
            xScale: flare.mirrored ? -1 : 1
            origin.x: flare.width / 2
        }

        ShapePath {
            strokeWidth: 0
            fillColor: flare.fillColor
            // top of the dock's side, where the flare begins
            startX: flare.size
            startY: 0

            // the concave sweep, centred on the box's far top corner so it
            // leaves the dock's side vertically and lands on the screen edge
            // horizontally
            PathArc {
                x: 0
                y: flare.size
                radiusX: flare.size
                radiusY: flare.size
                direction: PathArc.Clockwise
            }

            // back along the screen edge, under the dock
            PathLine {
                x: flare.size
                y: flare.size
            }

            // and up the dock's side to close
            PathLine {
                x: flare.size
                y: 0
            }

        }

    }

}
