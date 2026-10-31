import QtQuick
import QtQuick.Shapes
import qs
import qs.lucidicons
import qs.lucidui

// a place as one bold symbol: the very emblem its folder wears, from the icon
// theme's glyphs. a place the theme has no glyph for is the material symbol by name
Item {
    id: glyph

    property string slot: "folder"
    property string fallback: "folder"
    property real size: Theme.dp(20)
    property real fill: 1
    property color color: Theme.text
    // off where the colour is already driven frame by frame
    property bool animateColor: true
    readonly property var paths: LucidIcons.glyphs[glyph.slot] || null
    property real _fill: Math.max(0, Math.min(1, glyph.fill))

    implicitWidth: glyph.size
    implicitHeight: glyph.size
    width: glyph.size
    height: glyph.size
    // as Icon draws its symbols: the curve renderer chips small corners, so a
    // multisampled layer, filtered for the swell a row gives it on hover
    layer.enabled: glyph.paths !== null && glyph.width > 0
    layer.samples: 8
    layer.smooth: true

    Behavior on _fill {
        NumberAnimation {
            duration: Theme.durDefaultEffects
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEffects
        }

    }

    Behavior on color {
        enabled: glyph.animateColor

        ColorAnimation {
            duration: Theme.durFastEffects
        }

    }

    Shape {
        visible: glyph.paths !== null
        width: 24
        height: 24
        preferredRendererType: Shape.GeometryRenderer

        transform: Scale {
            xScale: glyph.width / 24
            yScale: glyph.height / 24
        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: glyph._fill >= 0.999 ? "transparent" : Qt.rgba(glyph.color.r, glyph.color.g, glyph.color.b, glyph.color.a * (1 - glyph._fill))

            PathSvg {
                path: glyph.paths ? glyph.paths[0] : ""
            }

        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: glyph._fill <= 0.001 ? "transparent" : Qt.rgba(glyph.color.r, glyph.color.g, glyph.color.b, glyph.color.a * glyph._fill)

            PathSvg {
                path: glyph.paths ? glyph.paths[1] : ""
            }

        }

    }

    Icon {
        visible: glyph.paths === null
        anchors.centerIn: parent
        name: glyph.fallback
        size: glyph.size
        fill: glyph.fill
        color: glyph.color
    }

}
