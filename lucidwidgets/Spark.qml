import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: spark

    // samples run 0..1, oldest first
    property var samples: []
    property color lineColor: Theme.accent
    property real lineWidth: 2
    property bool filled: true

    readonly property var points: {
        var n = spark.samples.length;
        if (n < 2 || spark.width <= 0)
            return [];

        var out = [];
        for (var i = 0; i < n; i++) {
            var x = (spark.width - spark.lineWidth) * (i / (n - 1)) + spark.lineWidth / 2;
            var v = Math.max(0, Math.min(1, spark.samples[i]));
            out.push(Qt.point(x, spark.height - spark.lineWidth / 2 - v * (spark.height - spark.lineWidth)));
        }
        return out;
    }
    readonly property var area: {
        if (spark.points.length < 2)
            return [];

        return spark.points.concat([Qt.point(spark.width, spark.height + 2), Qt.point(0, spark.height + 2)]);
    }

    implicitHeight: 48
    implicitWidth: 120
    clip: true

    Shape {
        anchors.fill: parent
        visible: spark.points.length > 1
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: spark.filled ? Theme.alpha(spark.lineColor, 0.22) : "transparent"

            PathPolyline {
                path: spark.area
            }

        }

        ShapePath {
            strokeColor: spark.lineColor
            strokeWidth: spark.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: spark.points
            }

        }

    }

}
