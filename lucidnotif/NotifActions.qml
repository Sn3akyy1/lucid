import QtQuick
import qs

// the action chips plus, where the app supports it, the inline reply field
Item {
    id: actions

    property var notification: null
    property bool replyOpen: false
    property var actionList: []
    readonly property bool canReply: Notifs.canReply(actions.notification)
    readonly property bool hasAny: actions.actionList.length > 0 || actions.canReply

    signal replyToggled(bool open)

    function closeReply() {
        actions.replyOpen = false;
        replyInput.text = "";
    }

    function send() {
        if (replyInput.text.length === 0)
            return ;

        Notifs.reply(actions.notification, replyInput.text);
        actions.closeReply();
    }

    onReplyOpenChanged: {
        actions.replyToggled(actions.replyOpen);
        if (actions.replyOpen)
            replyInput.forceActiveFocus();

    }
    implicitHeight: actions.hasAny ? (actions.replyOpen ? replyRow.implicitHeight : chipRow.implicitHeight) : 0
    clip: true
    // only animate once the row has its real size; animating up from zero on
    // creation makes any enclosing ListView lay out from a moving number
    Component.onCompleted: Qt.callLater(() => {
        return actions.settled = true;
    })

    property bool settled: false

    Behavior on implicitHeight {
        enabled: actions.settled

        NumberAnimation {
            duration: Theme.ms(220)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Flow {
        id: chipRow

        width: parent.width
        spacing: 6
        opacity: actions.replyOpen ? 0 : 1
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(140)
            }

        }

        // reply leads, because it is the one that needs no reading
        NotifChip {
            visible: actions.canReply
            label: actions.notification && actions.notification.inlineReplyPlaceholder ? actions.notification.inlineReplyPlaceholder : "Reply"
            iconPath: Notifs.icons.reply
            onClicked: actions.replyOpen = true
        }

        Repeater {
            model: actions.actionList

            NotifChip {
                required property var modelData

                label: modelData.text
                onClicked: modelData.invoke()
            }

        }

    }

    Row {
        id: replyRow

        width: parent.width
        spacing: 6
        opacity: actions.replyOpen ? 1 : 0
        visible: opacity > 0.01

        Rectangle {
            id: replyBox

            width: parent.width - sendButton.width - parent.spacing
            height: 32
            radius: Theme.pill(height)
            color: Theme.bgSunken
            border.width: 1
            border.color: replyInput.activeFocus ? Theme.accent : Theme.bgHigh

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.ms(150)
                }

            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: replyInput.text.length === 0
                text: "Message…"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
            }

            TextInput {
                id: replyInput

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.fgAccent
                onAccepted: actions.send()
                Keys.onEscapePressed: actions.closeReply()
            }

        }

        // the one place a filled accent circle is right: the commit
        Rectangle {
            id: sendButton

            width: 32
            height: 32
            radius: sendArea.pressed ? Theme.shapeMd : Theme.pill(width)
            color: replyInput.text.length > 0 ? Theme.accent : Theme.bgHigh

            NotifIcon {
                anchors.centerIn: parent
                size: 17
                path: Notifs.icons.send
                color: replyInput.text.length > 0 ? Theme.fgAccent : Theme.subtextDim
            }

            MouseArea {
                id: sendArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: actions.send()
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(150)
                }

            }

            Behavior on radius {
                NumberAnimation {
                    duration: Theme.ms(220)
                    easing.type: Theme.easeEmphasized
                    easing.overshoot: Theme.emphasizedOvershoot
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(180)
            }

        }

    }

}
