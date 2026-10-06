import QtQuick
import qs
import qs.lucidui

// the account strip at the top of the rail: a picture, a name, and the way in
// to everything about the account. collapses to the picture alone with the rail
Item {
    id: card

    // 0 collapsed .. 1 expanded, handed down so it moves with the rail
    property real railT: 1
    property bool selected: false
    readonly property var user: Users.me
    readonly property real avatarX: Theme.dp(20) * card.railT + ((card.width - Theme.dp(40)) / 2) * (1 - card.railT)
    readonly property real labelFade: Math.max(0, (card.railT - 0.5) / 0.5)
    readonly property color fg: card.selected ? Theme.fgSecondaryContainer : (area.containsMouse ? Theme.text : Theme.subtext)

    signal clicked()

    implicitHeight: Theme.dp(58)

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
        size: Theme.dp(40)
        user: card.user
        showAdmin: true
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: card.avatarX + Theme.dp(52)
        anchors.right: chevron.left
        anchors.rightMargin: Theme.dp(6)
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
            font.variableAxes: Theme.axes(Theme.fontBodyLg, 600, 0)
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
            font.variableAxes: Theme.axes(Theme.fontLabelMd, 420, 0)
            elide: Text.ElideRight
            opacity: card.selected ? 0.75 : 1
        }

    }

    Icon {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(16)
        anchors.verticalCenter: parent.verticalCenter
        opacity: card.labelFade * 0.7
        visible: opacity > 0.01
        name: "chevron_right"
        size: Theme.dp(18)
        color: card.fg
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
    }

}
