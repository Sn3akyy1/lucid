import QtQuick
import QtQuick.Shapes
import qs

// edit mode's outline round the dock, along its own edge and just inside it: the
// floating slab, a notch's shoulders running down its sides and out along the flares
// into the screen edge, or each island of a split dock
Item {
    id: outline

    property var dock: null
    property Item shellItem: null
    // the split dock's islands, in the shell's own coordinates
    property var islands: []
    property bool hot: false

    readonly property bool notch: !!outline.dock && outline.dock.renderAsNotch
    readonly property bool split: !!outline.dock && outline.dock.splitDrawn
    readonly property real line: outline.hot ? 2 : 1
    // the path runs half a line in from the edge, so the whole line sits inside it
    readonly property real d: outline.line / 2
    readonly property real flare: outline.notch ? Theme.dp(Prefs.dockNotchFlare) : 0
    readonly property real pad: Theme.dp(4)
    readonly property color ink: Theme.alpha(Theme.accent, outline.hot ? 1 : 0.55)
    readonly property color wash: outline.hot ? Theme.alpha(Theme.accent, 0.06) : "transparent"
    // the dock as painted, so the outline keeps to it while jelly bends it
    readonly property bool painted: !!outline.dock && outline.dock.paintW !== undefined
    readonly property real sx: outline.painted ? outline.dock.paintX : (outline.shellItem ? outline.shellItem.x : 0)
    readonly property real sy: outline.painted ? outline.dock.paintY : (outline.shellItem ? outline.shellItem.y : 0)
    readonly property real sw: outline.painted ? outline.dock.paintW : (outline.shellItem ? outline.shellItem.width : 0)
    readonly property real sh: outline.painted ? outline.dock.paintH : (outline.shellItem ? outline.shellItem.height : 0)
    readonly property real kx: outline.shellItem && outline.shellItem.width > 0 ? outline.sw / outline.shellItem.width : 1
    readonly property real ky: outline.shellItem && outline.shellItem.height > 0 ? outline.sh / outline.shellItem.height : 1
    readonly property real r: outline.shellItem ? outline.shellItem.radius : 0

    anchors.fill: parent
    z: 2
    opacity: Edit.active && !!outline.dock && outline.dock.shellShown && !outline.dock.menuOpen && !outline.dock.morphing ? 1 : 0
    visible: outline.opacity > 0.01

    Rectangle {
        visible: !outline.notch && !outline.split
        x: outline.sx
        y: outline.sy
        width: outline.sw
        height: outline.sh
        radius: outline.r
        bottomLeftRadius: outline.shellItem ? outline.shellItem.bottomLeftRadius : 0
        bottomRightRadius: outline.shellItem ? outline.shellItem.bottomRightRadius : 0
        color: outline.wash
        border.width: outline.line
        border.color: outline.ink
    }

    // left open along the bottom, which is the screen's own edge
    Shape {
        id: notchShape

        // the shell's sides, top and bottom in the shape's own frame
        readonly property real l: outline.pad + outline.flare
        readonly property real t: outline.pad
        readonly property real rr: notchShape.l + outline.sw
        readonly property real b: notchShape.t + outline.sh
        // a flare taller than the side reaches into the shoulder's curve, and the
        // shoulder then starts where the flare ends
        readonly property real joint: Math.min(notchShape.t + outline.r, notchShape.b - outline.flare)
        readonly property real cr: Math.max(0.01, outline.r - outline.d)
        readonly property real fr: outline.flare + outline.d

        visible: outline.notch && !outline.split
        x: outline.sx - outline.flare - outline.pad
        y: outline.sy - outline.pad
        width: outline.sw + (outline.flare + outline.pad) * 2
        height: outline.sh + outline.pad * 2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: outline.wash
            strokeColor: outline.ink
            strokeWidth: outline.line
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            startX: notchShape.l - outline.flare
            startY: notchShape.b + outline.d

            PathArc {
                x: notchShape.l + outline.d
                y: notchShape.b - outline.flare
                radiusX: notchShape.fr
                radiusY: notchShape.fr
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: notchShape.l + outline.d
                y: notchShape.joint
            }

            PathArc {
                x: notchShape.l + outline.r
                y: notchShape.t + outline.d
                radiusX: notchShape.cr
                radiusY: notchShape.cr
                direction: PathArc.Clockwise
            }

            PathLine {
                x: notchShape.rr - outline.r
                y: notchShape.t + outline.d
            }

            PathArc {
                x: notchShape.rr - outline.d
                y: notchShape.joint
                radiusX: notchShape.cr
                radiusY: notchShape.cr
                direction: PathArc.Clockwise
            }

            PathLine {
                x: notchShape.rr - outline.d
                y: notchShape.b - outline.flare
            }

            PathArc {
                x: notchShape.rr + outline.flare
                y: notchShape.b + outline.d
                radiusX: notchShape.fr
                radiusY: notchShape.fr
                direction: PathArc.Counterclockwise
            }

        }

    }

    Repeater {
        model: outline.split ? outline.islands : []

        Rectangle {
            required property var modelData

            visible: modelData.visible && modelData.width > 0.5
            x: outline.sx + modelData.x * outline.kx
            y: outline.sy + modelData.y * outline.ky
            width: modelData.width * outline.kx
            height: modelData.height * outline.ky
            topLeftRadius: modelData.topLeftRadius
            topRightRadius: modelData.topRightRadius
            bottomLeftRadius: modelData.bottomLeftRadius
            bottomRightRadius: modelData.bottomRightRadius
            color: outline.wash
            border.width: outline.line
            border.color: outline.ink
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.OutCubic
        }

    }

}
