import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import qs

// one slot of lucid's icon theme, drawn from its parts on the 48 grid: each part
// a path filled with a palette tone or a two-tone gradient, at its own opacity,
// and moving the way the theme says while hovered
Item {
    id: icon

    property string slot: "file"
    // a set other than the one in use, for a preview of it
    property string set: ""
    property real size: Theme.dp(48)
    property bool hovered: false
    // how far a holder scales it up (the dock swells under the pointer): the
    // drawing is made that much larger then, so it never stretches soft
    property real scaleHint: 1
    readonly property var parts: LucidIcons.parts(icon.slot, icon.set)
    readonly property bool moving: icon.hovered && Theme.motionScale > 0
    // every scale the drawing sits under, its own included
    readonly property real _scale: {
        var k = 1;
        for (var p = icon; p; p = p.parent)
            k *= p.scale;
        return k;
    }
    // under a wobbling jelly, which bends the layer the way a scale does
    readonly property bool _bent: {
        for (var p = icon; p; p = p.parent) {
            if (p.jellyWobbling === true)
                return true;

        }
        return false;
    }

    implicitWidth: icon.size
    implicitHeight: icon.size
    width: icon.size
    height: icon.size

    // the drawing, with room all round: motion that leaves the 48 grid (a lid
    // tipping up, a tile rising off its base, a spring's overshoot) is not cut
    Item {
        id: canvas

        readonly property real pad: Math.ceil(icon.size * 0.18)

        x: -canvas.pad
        y: -canvas.pad
        // whole pixels, so the texture is never stretched by a fraction to fit
        width: Math.ceil(icon.size) + 2 * canvas.pad
        height: Math.ceil(icon.size) + 2 * canvas.pad
        // the geometry renderer chips joins at small sizes, a multisampled layer does not
        layer.enabled: icon.parts.length > 0 && icon.width > 0
        layer.samples: 8
        // 1:1 every texel lands on a pixel. filtered, an icon centred on a half pixel
        // (a stretched grid cell) smears each edge across two, so only scaled ones filter
        layer.smooth: Math.abs(icon._scale - 1) > 0.001 || icon._bent
        layer.textureSize: icon.scaleHint > 1 ? Qt.size(Math.ceil(canvas.width * icon.scaleHint * Screen.devicePixelRatio), Math.ceil(canvas.height * icon.scaleHint * Screen.devicePixelRatio)) : Qt.size(0, 0)

        Item {
            x: canvas.pad
            y: canvas.pad
            width: 48
            height: 48
            scale: icon.size / 48
            transformOrigin: Item.TopLeft

            Repeater {
                model: icon.parts

                delegate: Shape {
                    id: part

                    required property var modelData
                    readonly property bool graded: part.modelData.grad !== undefined
                    readonly property var hv: part.modelData.hover || null
                    readonly property bool live: icon.moving && part.hv !== null

                    width: 48
                    height: 48
                    opacity: part.modelData.opacity !== undefined ? part.modelData.opacity : 1
                    preferredRendererType: Shape.GeometryRenderer
                    // scale and turn about the theme's origin, then shift; one curve both
                    // ways, so a quick pass of the pointer settles as it rose
                    transform: [
                        Scale {
                            origin.x: part.hv ? part.hv.ox : 24
                            origin.y: part.hv ? part.hv.oy : 24
                            xScale: part.live ? part.hv.sx : 1
                            yScale: part.live ? part.hv.sy : 1

                            Behavior on xScale {
                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveFastSpatial
                                }

                            }

                            Behavior on yScale {
                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveFastSpatial
                                }

                            }

                        },
                        Rotation {
                            origin.x: part.hv ? part.hv.ox : 24
                            origin.y: part.hv ? part.hv.oy : 24
                            angle: part.live ? part.hv.rot : 0

                            Behavior on angle {
                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveFastSpatial
                                }

                            }

                        },
                        Translate {
                            x: part.live ? part.hv.dx : 0
                            y: part.live ? part.hv.dy : 0

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveFastSpatial
                                }

                            }

                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveFastSpatial
                                }

                            }

                        }
                    ]

                    ShapePath {
                        strokeWidth: -1
                        strokeColor: "transparent"
                        fillRule: ShapePath.WindingFill
                        // never transparent under a gradient: the gpu geometry renderer
                        // skips a fill whose colour has no alpha, gradient or not
                        fillColor: LucidIcons.tone(part.graded ? part.modelData.stops[0][1] : part.modelData.fill)
                        fillGradient: part.graded ? shade : null

                        PathSvg {
                            path: part.modelData.d
                        }

                    }

                    LinearGradient {
                        id: shade

                        x1: part.graded ? part.modelData.grad[0] : 0
                        y1: part.graded ? part.modelData.grad[1] : 0
                        x2: part.graded ? part.modelData.grad[2] : 0
                        y2: part.graded ? part.modelData.grad[3] : 48

                        GradientStop {
                            position: 0
                            color: part.graded ? LucidIcons.tone(part.modelData.stops[0][1]) : "transparent"
                        }

                        GradientStop {
                            position: 1
                            color: part.graded ? LucidIcons.tone(part.modelData.stops[1][1]) : "transparent"
                        }

                    }

                }

            }

        }

    }

}
