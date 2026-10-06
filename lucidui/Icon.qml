import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import qs
import "SymbolPaths.js" as Symbols

// a material symbol by name, drawn from google's own svg paths. fill runs 0..1
// and eases, so a state change reads as the outline filling in
Item {
    id: icon

    property string name: ""
    property real size: Theme.dp(20)
    property real fill: 0
    property color color: Theme.text
    property bool animateFill: true
    // off where the colour is already driven frame by frame
    property bool animateColor: true
    // kept so older callers still parse; the svgs come in one weight
    property real weight: 400
    property real grade: 0
    property real _fill: Math.max(0, Math.min(1, icon.fill))
    readonly property var paths: Symbols.p[icon.name] || null
    // every scale the icon sits under, so a zoomed card gets a texture to match
    readonly property real _scale: {
        var k = 1;
        for (var p = icon.parent; p; p = p.parent)
            k *= p.scale;
        return k;
    }
    // in quarter steps, so a hover or press animation never reallocates it
    readonly property real _zoom: icon._scale < 1.1 ? 1 : Math.ceil(icon._scale * 4) / 4

    implicitWidth: icon.size
    implicitHeight: icon.size
    width: icon.size
    height: icon.size
    // the curve renderer chips these glyphs where a corner meets an edge at
    // small sizes, so they draw through a multisampled layer instead
    layer.enabled: icon.paths !== null && icon.width > 0 && icon.height > 0
    layer.samples: 8
    // 1:1 snaps to the pixel grid; anything scaled has to filter
    layer.smooth: Math.abs(icon._scale - 1) > 0.001
    layer.textureSize: icon._zoom === 1 ? Qt.size(0, 0) : Qt.size(Math.ceil(icon.width * icon._zoom * Screen.devicePixelRatio), Math.ceil(icon.height * icon._zoom * Screen.devicePixelRatio))

    Behavior on _fill {
        enabled: icon.animateFill

        NumberAnimation {
            duration: Theme.durDefaultEffects
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEffects
        }

    }

    Behavior on color {
        enabled: icon.animateColor

        ColorAnimation {
            duration: Theme.durFastEffects
        }

    }

    Shape {
        visible: icon.paths !== null
        // the paths' own 24-unit grid, scaled below
        width: 24
        height: 24
        preferredRendererType: Shape.GeometryRenderer
        transform: Scale {
            xScale: icon.width / 24
            yScale: icon.height / 24
        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: icon._fill >= 0.999 ? "transparent" : Qt.rgba(icon.color.r, icon.color.g, icon.color.b, icon.color.a * (1 - icon._fill))

            PathSvg {
                path: icon.paths ? icon.paths[0] : ""
            }

        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: icon._fill <= 0.001 ? "transparent" : Qt.rgba(icon.color.r, icon.color.g, icon.color.b, icon.color.a * icon._fill)

            PathSvg {
                path: icon.paths && icon._fill > 0.001 ? icon.paths[1] : ""
            }

        }

    }

}
