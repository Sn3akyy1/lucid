import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import qs

// a round account picture, falling back to initials on a tonal disc
Item {
    id: av

    property var user: null
    property int size: 44
    // a camera scrim on hover, for the ones you can change
    property bool editable: false
    property bool showAdmin: false
    readonly property string source: Users.avatarUrl(av.user)
    readonly property bool ready: av.source !== "" && img.status === Image.Ready

    signal clicked()

    implicitWidth: av.size
    implicitHeight: av.size

    ClippingRectangle {
        id: disc

        anchors.fill: parent
        radius: width / 2
        color: Theme.secondaryContainer

        Text {
            anchors.centerIn: parent
            text: Users.initials(av.user)
            color: Theme.fgSecondaryContainer
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(av.size * 0.38)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
            visible: !av.ready
        }

        Image {
            id: img

            anchors.fill: parent
            source: av.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // the path stays put when the picture changes, so never hold one
            cache: false
            sourceSize.width: 256
            sourceSize.height: 256
            visible: av.ready

            // a new picture usually lands on the same path, so the source never
            // changes and qt never re-reads it. drop it and put the binding back
            Connections {
                function onAvatarRevChanged() {
                    img.source = "";
                    Qt.callLater(function() {
                        img.source = Qt.binding(function() {
                            return av.source;
                        });
                    });
                }

                target: Users
            }

        }

        // the scrim and its camera only exist while the pointer is on the disc
        Rectangle {
            anchors.fill: parent
            color: Theme.cShadow
            opacity: av.editable && hover.hovered ? 0.55 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        Shape {
            anchors.centerIn: parent
            width: Math.round(av.size * 0.34)
            height: Math.round(av.size * 0.34)
            opacity: av.editable && hover.hovered ? 1 : 0
            visible: opacity > 0.01
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillColor: "white"

                PathSvg {
                    path: "M9 2 7.17 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-3.17L15 2H9Zm3 5a6 6 0 1 1 0 12 6 6 0 0 1 0-12Zm0 2a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z"
                }

            }

            transform: Scale {
                xScale: Math.round(av.size * 0.34) / 24
                yScale: Math.round(av.size * 0.34) / 24
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        HoverHandler {
            id: hover

            enabled: av.editable
            cursorShape: Qt.PointingHandCursor
        }

    }

    // a small key on the corner marks an account that can administer the machine
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.round(av.size * 0.36)
        height: Math.round(av.size * 0.36)
        visible: av.showAdmin && av.user && av.user.accountType === Users.admin

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.accent
            border.width: Math.max(1.5, av.size * 0.035)
            border.color: Theme.bgTile
        }

        Shape {
            anchors.centerIn: parent
            width: parent.width * 0.62
            height: parent.height * 0.62
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillColor: Theme.fgAccent

                PathSvg {
                    path: "M12 1 4 4.5v6c0 5 3.4 9.7 8 10.9 4.6-1.2 8-5.9 8-10.9v-6L12 1Zm0 2.2 6 2.6v4.7c0 3.9-2.5 7.6-6 8.8-3.5-1.2-6-4.9-6-8.8V5.8l6-2.6Z"
                }

            }

            transform: Scale {
                xScale: (av.size * 0.36 * 0.62) / 24
                yScale: (av.size * 0.36 * 0.62) / 24
            }

        }

    }

    MouseArea {
        anchors.fill: parent
        enabled: av.editable
        cursorShape: Qt.PointingHandCursor
        onClicked: av.clicked()
    }

}
