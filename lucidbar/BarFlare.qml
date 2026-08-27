import QtQuick
import QtQuick.Shapes
import qs

// One concave corner joining a bar module's side to the top of the screen.
//
// The same shape as the dock's, inverted: a notched module meets the screen
// edge at a hard right angle, and this fills the corner beside it with
// material that sweeps outward as it rises - tangent to the module's side
// where it leaves, tangent to the screen edge where it lands - so the module
// reads as carved out of the top of the display rather than hung below it.
//
// Traced as one continuous closed contour. `PathMove` does not start a new
// subpath in a ShapePath here - subpaths get chained onto the previous one -
// so the outline is drawn without lifting the pen.
//
// Drawn strictly *outside* the module's own rectangle, never overlapping it:
// two translucent surfaces of one colour cannot be made to match, so with
// Glass on any overlap would show as a darker seam. The join has to be an edge.
Item {
    id: flare

    // false is the left-hand corner; the right-hand one is the same shape
    // mirrored, so the two can never drift apart when the radius changes
    property bool mirrored: false
    property int size: 14
    property color fillColor: Theme.bg
    // Whether the module this corner belongs to is being hovered. The pill
    // itself lightens by laying Theme.text over its fill at 8%; the flare is
    // the same material, so it has to pick up the same lift or the corner
    // visibly stays behind while the module lights up.
    property bool hovered: false

    // Composited into the fill rather than drawn as a second shape on top:
    // stacking another Shape would mean two translucent layers over the same
    // pixels, which with Glass on reads darker than the pill it is joining.
    property real tint: flare.hovered ? 0.08 : 0

    Behavior on tint {
        NumberAnimation {
            duration: Theme.barMs(150)
            easing.type: Easing.OutCubic
        }

    }

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
            fillColor: Qt.tint(flare.fillColor, Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, flare.tint))
            // bottom of the module's side, where the flare begins
            startX: flare.size
            startY: flare.size

            // the concave sweep, centred on the box's far bottom corner so it
            // leaves the module's side vertically and lands on the screen edge
            // horizontally
            PathArc {
                x: 0
                y: 0
                radiusX: flare.size
                radiusY: flare.size
                direction: PathArc.Counterclockwise
            }

            // back along the screen edge, over the module
            PathLine {
                x: flare.size
                y: 0
            }

            // and down the module's side to close
            PathLine {
                x: flare.size
                y: flare.size
            }

        }

    }

}
