import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: spark

    // samples run 0..1, oldest first
    property var samples: []
    property color lineColor: Theme.accent
    property real lineWidth: Theme.dp(2)
    property bool filled: true
    // scale to the loudest sample instead of 0..1, for rates with no ceiling
    property bool autoScale: false
    readonly property real peak: {
        if (!spark.autoScale)
            return 1;

        var m = 0;
        for (var i = 0; i < spark.samples.length; i++) m = Math.max(m, spark.samples[i])
        return m > 0 ? m * 1.15 : 1;
    }

    readonly property var points: {
        var n = spark.samples.length;
        if (n < 2 || spark.width <= 0)
            return [];

        var out = [];
        for (var i = 0; i < n; i++) {
            var x = (spark.width - spark.lineWidth) * (i / (n - 1)) + spark.lineWidth / 2;
            var v = Math.max(0, Math.min(1, spark.samples[i] / spark.peak));
            out.push(Qt.point(x, spark.height - spark.lineWidth / 2 - v * (spark.height - spark.lineWidth)));
        }
        return out;
    }
    readonly property var area: {
        if (spark.points.length < 2)
            return [];

        return spark.points.concat([Qt.point(spark.width, spark.height + 2), Qt.point(0, spark.height + 2)]);
    }

    implicitHeight: Theme.dp(48)
    implicitWidth: Theme.dp(120)
    clip: true

    Shape {
        anchors.fill: parent
        visible: spark.points.length > 1
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: spark.filled ? "white" : "transparent"

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: spark.height

                GradientStop {
                    position: 0
                    color: Theme.alpha(spark.lineColor, spark.filled ? 0.32 : 0)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(spark.lineColor, 0)
                }

            }

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
