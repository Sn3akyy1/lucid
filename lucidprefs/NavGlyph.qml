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
        visible: glyph.kind === "sound"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: "M14,3.23V5.29C16.89,6.15 19,8.83 19,12C19,15.17 16.89,17.84 14,18.7V20.77C18,19.86 21,16.28 21,12C21,7.72 18,4.14 14,3.23M16.5,12C16.5,10.23 15.5,8.71 14,7.97V16C15.5,15.29 16.5,13.76 16.5,12M3,9V15H7L12,20V4L7,9H3Z"
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
        visible: glyph.kind === "workspaces"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: "M12,16L19.36,10.27L21,9L12,2L3,9L4.63,10.27L12,16Z M12,18.54L4.62,12.81L3,14.07L12,21.07L21,14.07L19.37,12.8L12,18.54Z"
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
        visible: glyph.kind === "environment"

        Rectangle {
            x: 2
            y: 2
            width: 13.5
            height: 11
            radius: 3
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Shape {
            x: 8.5
            y: 7.5
            width: 13.5
            height: 13.5
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 1.5
                strokeColor: glyph.color
                fillColor: glyph.color
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: "M4 3 L4 17 L7.8 13.6 L10.1 18.6 L12.4 17.5 L10.1 12.6 L15 12.6 Z"
                }

            }

            transform: Scale {
                xScale: 13.5 / 20
                yScale: 13.5 / 20
            }

        }

    }

    // two panes, the near one see-through over the far one
    Item {
        anchors.fill: parent
        visible: glyph.kind === "glass"

        Rectangle {
            x: 2.5
            y: 2.5
            width: 12
            height: 12
            radius: 3.5
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Rectangle {
            x: 7.5
            y: 7.5
            width: 12
            height: 12
            radius: 3.5
            color: glyph.color
            opacity: 0.45
        }

        Rectangle {
            x: 7.5
            y: 7.5
            width: 12
            height: 12
            radius: 3.5
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
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

    // a fan of swatches
    Shape {
        anchors.centerIn: parent
        width: 22
        height: 22
        visible: glyph.kind === "palettes"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: "M2.53,19.65L3.87,20.21V11.18L1.44,17.04C1.03,18.06 1.5,19.23 2.53,19.65M22.03,15.95L17.07,4C16.76,3.23 16.03,2.77 15.26,2.75C15,2.75 14.73,2.79 14.47,2.9L7.1,5.95C6.35,6.26 5.89,7 5.87,7.75C5.86,8 5.9,8.29 6,8.55L11,20.5C11.29,21.28 12.03,21.74 12.81,21.75C13.07,21.75 13.33,21.7 13.58,21.6L20.94,18.55C21.96,18.13 22.45,16.96 22.03,15.95M7.88,8.75A1,1 0 0,1 6.88,7.75A1,1 0 0,1 7.88,6.75C8.43,6.75 8.88,7.2 8.88,7.75C8.88,8.3 8.43,8.75 7.88,8.75M5.88,19.75A2,2 0 0,0 7.88,21.75H9.33L5.88,13.41V19.75Z"
            }

        }

        transform: Scale {
            xScale: 22 / 24
            yScale: 22 / 24
        }

    }

    // a painter's palette
    Shape {
        anchors.centerIn: parent
        width: 22
        height: 22
        visible: glyph.kind === "colours"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: "M12,22C6.49,22 2,17.51 2,12C2,6.49 6.49,2 12,2C17.51,2 22,6.04 22,11C22,14.31 19.31,17 16,17H14.23C13.95,17 13.73,17.22 13.73,17.5C13.73,17.62 13.78,17.73 13.86,17.83C14.27,18.3 14.5,18.89 14.5,19.5C14.5,20.88 13.38,22 12,22M12,4C7.59,4 4,7.59 4,12C4,16.41 7.59,20 12,20C12.28,20 12.5,19.78 12.5,19.5C12.5,19.34 12.42,19.22 12.36,19.15C11.95,18.69 11.73,18.1 11.73,17.5C11.73,16.12 12.85,15 14.23,15H16C18.21,15 20,13.21 20,11C20,7.14 16.41,4 12,4M6.5,10C7.33,10 8,10.67 8,11.5C8,12.33 7.33,13 6.5,13C5.67,13 5,12.33 5,11.5C5,10.67 5.67,10 6.5,10M9.5,6C10.33,6 11,6.67 11,7.5C11,8.33 10.33,9 9.5,9C8.67,9 8,8.33 8,7.5C8,6.67 8.67,6 9.5,6M14.5,6C15.33,6 16,6.67 16,7.5C16,8.33 15.33,9 14.5,9C13.67,9 13,8.33 13,7.5C13,6.67 13.67,6 14.5,6M17.5,10C18.33,10 19,10.67 19,11.5C19,12.33 18.33,13 17.5,13C16.67,13 16,12.33 16,11.5C16,10.67 16.67,10 17.5,10Z"
            }

        }

        transform: Scale {
            xScale: 22 / 24
            yScale: 22 / 24
        }

    }

    // a screen on a stand, with a second one stood beside it
    Item {
        anchors.fill: parent
        visible: glyph.kind === "displays"

        Rectangle {
            x: 1.5
            y: 4
            width: 13
            height: 9.5
            radius: 2
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Rectangle {
            x: 7.2
            y: 13.5
            width: 1.6
            height: 2.6
            color: glyph.color
        }

        Rectangle {
            x: 4.5
            y: 16.1
            width: 7
            height: 1.6
            radius: 0.8
            color: glyph.color
        }

        Rectangle {
            x: 15.5
            y: 7
            width: 5.5
            height: 8
            radius: 1.8
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

    }


    Item {
        anchors.fill: parent
        visible: glyph.kind === "keybinds"

        Rectangle {
            x: 1.5
            y: 4.5
            width: 19
            height: 13.5
            radius: 3
            color: "transparent"
            border.width: 1.6
            border.color: glyph.color
        }

        Repeater {
            model: [[4.6, 7.6], [8.3, 7.6], [12, 7.6], [15.7, 7.6], [4.6, 10.8], [8.3, 10.8], [12, 10.8], [15.7, 10.8]]

            Rectangle {
                required property var modelData

                x: modelData[0]
                y: modelData[1]
                width: 1.9
                height: 1.9
                radius: 0.5
                color: glyph.color
            }

        }

        Rectangle {
            x: 7.2
            y: 14
            width: 7.6
            height: 1.6
            radius: 0.8
            color: glyph.color
        }

    }

}
