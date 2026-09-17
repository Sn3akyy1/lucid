import QtQuick
import QtQuick.Shapes
import qs

// the badge glyph, picked from what the action actually touches
Item {
    id: glyph

    // every path below is authored on material's 24x24 grid
    readonly property var paths: ({
        "shield": "M12 1 3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4Z",
        "terminal": "M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2Zm0 14H4V8h16v10Zm-2-1h-6v-2h6v2ZM7.5 17l-1.41-1.41L8.67 13l-2.59-2.59L7.5 9l4 4-4 4Z",
        "drive": "M2 20h20v-4H2v4Zm2-3h2v2H4v-2ZM2 4v4h20V4H2Zm4 3H4V5h2v2Zm-4 7h20v-4H2v4Zm2-3h2v2H4v-2Z",
        "power": "M13 3h-2v10h2V3Zm4.83 2.17-1.42 1.42A6.92 6.92 0 0 1 19 12c0 3.87-3.13 7-7 7A6.995 6.995 0 0 1 7.58 6.58L6.17 5.17A8.932 8.932 0 0 0 3 12a9 9 0 0 0 18 0c0-2.74-1.23-5.18-3.17-6.83Z",
        "network": "M1 9l2 2c4.97-4.97 13.03-4.97 18 0l2-2C16.93 2.93 7.08 2.93 1 9Zm8 8l3 3 3-3a4.237 4.237 0 0 0-6 0Zm-4-4l2 2a7.074 7.074 0 0 1 10 0l2-2C15.14 9.14 8.87 9.14 5 13Z",
        "user": "M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4Zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4Z",
        "package": "M20 2H4c-1.1 0-2 .9-2 2v3.01c0 .72.43 1.34 1 1.69V20c0 1.1 1.1 2 2 2h14c.9 0 2-.9 2-2V8.7c.57-.35 1-.97 1-1.69V4c0-1.1-.9-2-2-2Zm-5 12H9v-2h6v2Zm5-7H4V4l16-.02V7Z",
        "key": "M12.65 10A5.99 5.99 0 0 0 7 6a6 6 0 0 0 0 12 5.99 5.99 0 0 0 5.65-4H17v4h4v-4h2v-4H12.65ZM7 14a2 2 0 1 1 0-4 2 2 0 0 1 0 4Z",
        "check": "M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17Z"
    })
    property string name: "shield"
    property color color: Theme.fgAccentContainer
    property real size: 22

    implicitWidth: glyph.size
    implicitHeight: glyph.size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: glyph.paths[glyph.name] !== undefined ? glyph.paths[glyph.name] : glyph.paths["shield"]
            }

        }

        transform: Scale {
            xScale: glyph.size / 24
            yScale: glyph.size / 24
        }

    }

}
