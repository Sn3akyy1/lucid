import QtQuick
import qs
import qs.lucidui

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

    Icon {
        x: field.iconX
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 22
        color: input.activeFocus ? Theme.accent : Theme.subtext
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
        iconPath: "close"
        onClicked: {
            field.clear();
            input.forceActiveFocus();
        }
    }

}
