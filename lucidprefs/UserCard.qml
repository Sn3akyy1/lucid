import QtQuick
import QtQuick.Shapes
import qs

// the account strip at the top of the rail: a picture, a name, and the way in
// to everything about the account. collapses to the picture alone with the rail
Item {
    id: card

    // 0 collapsed .. 1 expanded, handed down so it moves with the rail
    property real railT: 1
    property bool selected: false
    readonly property var user: Users.me
    readonly property real avatarX: 20 * card.railT + ((card.width - 40) / 2) * (1 - card.railT)
    readonly property real labelFade: Math.max(0, (card.railT - 0.5) / 0.5)
    readonly property color fg: card.selected ? Theme.fgSecondaryContainer : (area.containsMouse ? Theme.text : Theme.subtext)

    signal clicked()

    implicitHeight: 58

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: card.selected ? Theme.secondaryContainer : Theme.bgTile

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: card.fg
            opacity: area.pressed ? Theme.statePressed : (area.containsMouse && !card.selected ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

    }

    UserAvatar {
        id: face

        x: card.avatarX
        anchors.verticalCenter: parent.verticalCenter
        size: 40
        user: card.user
        showAdmin: true
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: card.avatarX + 52
        anchors.right: chevron.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: -1
        opacity: card.labelFade
        visible: opacity > 0.01

        Text {
            width: parent.width
            text: Users.displayName(card.user) || "Account"
            color: card.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyLg
            font.weight: Font.DemiBold
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Text {
            width: parent.width
            // the username is worth printing only when it is not already above
            text: {
                var u = card.user;
                if (!u)
                    return "Users and accounts";

                return u.realName && u.realName !== "" ? u.name : Users.typeLabel(u.accountType);
            }
            color: card.selected ? Theme.fgSecondaryContainer : Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelMd
            elide: Text.ElideRight
            opacity: card.selected ? 0.75 : 1
        }

    }

    Shape {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        opacity: card.labelFade * 0.7
        visible: opacity > 0.01
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: card.fg

            PathSvg {
                path: "M8.6 16.6 13.2 12 8.6 7.4 10 6l6 6-6 6-1.4-1.4Z"
            }

        }

        transform: Scale {
            xScale: 16 / 24
            yScale: 16 / 24
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
    }

}
