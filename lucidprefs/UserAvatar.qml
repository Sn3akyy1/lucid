import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidui

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
            font.variableAxes: Theme.axes(Math.round(av.size * 0.38), 600, 0)
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

        Icon {
            anchors.centerIn: parent
            opacity: av.editable && hover.hovered ? 1 : 0
            visible: opacity > 0.01
            name: "photo_camera"
            size: Math.round(av.size * 0.36)
            fill: 1
            color: "white"
            animateColor: false

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

    // a small shield on the corner marks an account that can administer the machine
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

        Icon {
            anchors.centerIn: parent
            name: "shield"
            size: Math.round(parent.width * 0.7)
            fill: 1
            color: Theme.fgAccent
        }

    }

    MouseArea {
        anchors.fill: parent
        enabled: av.editable
        cursorShape: Qt.PointingHandCursor
        onClicked: av.clicked()
    }

}
