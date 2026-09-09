import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: glyph

    property string kind: "general"
    property color color: Theme.subtext

    implicitWidth: 22
    implicitHeight: 22

    Item {
        anchors.fill: parent
        visible: glyph.kind === "general"

        Rectangle {
            x: 2
            y: 6
            width: 18
            height: 2
            radius: 1
            color: glyph.color
        }

        Rectangle {
            x: 12
            y: 3.5
            width: 3.5
            height: 7
            radius: 1.75
            color: glyph.color
        }

        Rectangle {
            x: 2
            y: 14
            width: 18
            height: 2
            radius: 1
            color: glyph.color
        }

        Rectangle {
            x: 6
            y: 11.5
            width: 3.5
            height: 7
            radius: 1.75
            color: glyph.color
        }

    }

    Item {
        anchors.fill: parent
        visible: glyph.kind === "bar"

        Rectangle {
            x: 2
            y: 3
            width: 18
            height: 16
            radius: 3
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Rectangle {
            x: 4.5
            y: 6
            width: 4.5
            height: 2.5
            radius: 1.25
            color: glyph.color
        }

        Rectangle {
            x: 10.5
            y: 6
            width: 3
            height: 2.5
            radius: 1.25
            color: glyph.color
        }

        Rectangle {
            x: 15
            y: 6
            width: 2.5
            height: 2.5
            radius: 1.25
            color: glyph.color
        }

    }

    Item {
        anchors.fill: parent
        visible: glyph.kind === "widgets"

        Rectangle {
            x: 2.5
            y: 2.5
            width: 7.5
            height: 7.5
            radius: 2
            color: glyph.color
        }

        Rectangle {
            x: 12.5
            y: 2.5
            width: 7.5
            height: 7.5
            radius: 3.75
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Rectangle {
            x: 2.5
            y: 12.5
            width: 7.5
            height: 7.5
            radius: 2
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Rectangle {
            x: 12.5
            y: 12.5
            width: 7.5
            height: 7.5
            radius: 2
            color: glyph.color
        }

    }

    Item {
        anchors.fill: parent
        visible: glyph.kind === "dock"

        Rectangle {
            x: 2
            y: 3
            width: 18
            height: 16
            radius: 3
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Row {
            x: 5
            y: 13
            spacing: 2

            Repeater {
                model: 3

                Rectangle {
                    width: 3.3
                    height: 3.3
                    radius: 1
                    color: glyph.color
                }

            }

        }

    }

    Item {
        anchors.fill: parent
        visible: glyph.kind === "datetime"

        Rectangle {
            x: 2
            y: 2
            width: 18
            height: 18
            radius: 9
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Rectangle {
            x: 10.2
            y: 5.6
            width: 1.6
            height: 5.4
            radius: 0.8
            color: glyph.color
        }

        Rectangle {
            x: 10.2
            y: 10.2
            width: 4.6
            height: 1.6
            radius: 0.8
            color: glyph.color
        }

    }

    Shape {
        anchors.centerIn: parent
        width: 22
        height: 22
        visible: glyph.kind === "bluetooth"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: "M17.71,7.71L12,2H11V9.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L11,14.41V22H12L17.71,16.29L13.41,12L17.71,7.71M13,5.83L15.17,8L13,10.17V5.83M13,13.83L15.17,16L13,18.17V13.83Z"
            }

        }

        transform: Scale {
            xScale: 22 / 24
            yScale: 22 / 24
        }

    }

    Shape {
        anchors.centerIn: parent
        width: 22
        height: 22
        visible: glyph.kind === "kdeconnect"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: "M22,17H18V10H22M23,8H17A1,1 0 0,0 16,9V19A1,1 0 0,0 17,20H23A1,1 0 0,0 24,19V9A1,1 0 0,0 23,8M4,6H22V4H4A2,2 0 0,0 2,6V17H0V20H14V17H4V6Z"
            }

        }

        transform: Scale {
            xScale: 22 / 24
            yScale: 22 / 24
        }

    }

    Shape {
        anchors.centerIn: parent
        width: 22
        height: 22
        visible: glyph.kind === "network"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: "M12,21L15.6,16.2C14.6,15.45 13.35,15 12,15C10.65,15 9.4,15.45 8.4,16.2L12,21M12,3C7.95,3 4.21,4.34 1.2,6.6L3,9C5.5,7.12 8.62,6 12,6C15.38,6 18.5,7.12 21,9L22.8,6.6C19.79,4.34 16.05,3 12,3M12,9C9.3,9 6.81,9.89 4.8,11.4L6.6,13.8C8.1,12.67 9.97,12 12,12C14.03,12 15.9,12.67 17.4,13.8L19.2,11.4C17.19,9.89 14.7,9 12,9Z"
            }

        }

        transform: Scale {
            xScale: 22 / 24
            yScale: 22 / 24
        }

    }

    Shape {
        anchors.centerIn: parent
        width: 22
        height: 22
        visible: glyph.kind === "notifications"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: "M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6v-5c0-3.07-1.63-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C8.64 5.36 7 7.92 7 11v5l-2 2v1h14v-1l-2-2Z"
            }

        }

        transform: Scale {
            xScale: 22 / 24
            yScale: 22 / 24
        }

    }

    Shape {
        anchors.centerIn: parent
        width: 22
        height: 22
        visible: glyph.kind === "idle"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: "M17.75 4.09l-2.53 1.94.91 3.06-2.63-1.81-2.63 1.81.91-3.06-2.53-1.94L12.44 4l1.06-3 1.06 3 3.19.09m3.5 6.91l-1.64 1.25.59 1.98-1.7-1.17-1.7 1.17.59-1.98L15.75 11l2.06-.05.69-1.94.69 1.94 2.06.05m-2.28 4.95c.83-.08 1.72 1.1 1.19 1.85-.32.45-.66.87-1.08 1.27C15.17 22.5 8.84 22.5 4.94 18.6c-3.9-3.9-3.9-10.24 0-14.14.4-.4.82-.76 1.27-1.08.75-.53 1.93.36 1.85 1.19-.27 2.86.69 5.83 2.89 8.02a9.96 9.96 0 0 0 8.02 2.89m-1.64 2.02a12.08 12.08 0 0 1-7.8-3.47c-2.17-2.19-3.33-5-3.49-7.82-2.51 3.15-2.31 7.76.6 10.67 2.91 2.92 7.53 3.12 10.69.62Z"
            }

        }

        transform: Scale {
            xScale: 22 / 24
            yScale: 22 / 24
        }

    }

    Item {
        anchors.fill: parent
        visible: glyph.kind === "theme"

        Rectangle {
            x: 2
            y: 2
            width: 18
            height: 18
            radius: 9
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Rectangle {
            x: 6
            y: 6
            width: 10
            height: 10
            radius: 5
            color: glyph.color
        }

        Rectangle {
            x: 10.6
            y: 2
            width: 1.6
            height: 4.4
            color: glyph.color
        }

        Rectangle {
            x: 10.6
            y: 15.6
            width: 1.6
            height: 4.4
            color: glyph.color
        }

    }

}
