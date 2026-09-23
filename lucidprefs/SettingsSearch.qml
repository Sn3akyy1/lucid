import QtQuick
import QtQuick.Shapes
import qs

// the search field at the head of the rail. with the rail folded it is only the
// magnifier, and focusing it opens the rail for as long as the search lasts
Item {
    id: field

    // 0 collapsed .. 1 expanded, handed down so it moves with the rail
    property real railT: 1
    property alias text: input.text
    readonly property bool focused: input.activeFocus
    readonly property real iconX: 20 * field.railT + ((field.width - 22) / 2) * (1 - field.railT)
    readonly property real labelFade: Math.max(0, (field.railT - 0.5) / 0.5)

    signal moved(int by)
    signal accepted()
    signal escaped()

    // `typed` is the key that started the search from elsewhere in the window
    function focusInput(typed) {
        input.forceActiveFocus();
        if (typed)
            input.insert(input.cursorPosition, typed);

    }

    function clear() {
        input.text = "";
    }

    implicitHeight: 50

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.bgTile
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.accent

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.text
            opacity: area.containsMouse && !input.activeFocus ? Theme.stateHover : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

    }

    // under the input, so a click there still places the cursor; this takes the
    // rest of the pill, and the folded rail's magnifier
    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: field.labelFade > 0.5 ? Qt.IBeamCursor : Qt.PointingHandCursor
        onClicked: field.focusInput()
    }

    Shape {
        x: field.iconX
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: input.activeFocus ? Theme.accent : Theme.subtext

            PathSvg {
                path: "M9.5 3A6.5 6.5 0 0 1 16 9.5c0 1.61-.59 3.09-1.56 4.23l.27.27h.79l5 5-1.5 1.5-5-5v-.79l-.27-.27A6.516 6.516 0 0 1 9.5 16 6.5 6.5 0 0 1 3 9.5 6.5 6.5 0 0 1 9.5 3m0 2C7 5 5 7 5 9.5S7 14 9.5 14 14 12 14 9.5 12 5 9.5 5Z"
            }

        }

        transform: Scale {
            xScale: 22 / 24
            yScale: 22 / 24
        }

    }

    // kept visible while folded: a hidden item cannot take the focus, and taking
    // it is what opens the rail
    TextInput {
        id: input

        anchors.left: parent.left
        anchors.leftMargin: field.iconX + 38
        anchors.right: clearBtn.visible ? clearBtn.left : parent.right
        anchors.rightMargin: clearBtn.visible ? 4 : 18
        anchors.verticalCenter: parent.verticalCenter
        opacity: field.labelFade
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        selectByMouse: true
        selectionColor: Theme.accent
        selectedTextColor: Theme.fgAccent
        clip: true
        onAccepted: field.accepted()
        Keys.onUpPressed: field.moved(-1)
        Keys.onDownPressed: field.moved(1)
        Keys.onTabPressed: field.moved(1)
        Keys.onBacktabPressed: field.moved(-1)
        Keys.onEscapePressed: field.escaped()
    }

    Text {
        anchors.left: input.left
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: "Search settings"
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        elide: Text.ElideRight
        opacity: field.labelFade
        visible: input.text === "" && opacity > 0.01
    }

    M3IconButton {
        id: clearBtn

        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        size: 36
        iconSize: 18
        opacity: field.labelFade
        visible: input.text !== "" && opacity > 0.01
        iconPath: "M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41Z"
        onClicked: {
            field.clear();
            input.forceActiveFocus();
        }
    }

}
