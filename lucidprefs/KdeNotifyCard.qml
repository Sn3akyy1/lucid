import QtQuick
import qs

SettingCard {
    id: card

    required property var dev
    property string replyingTo: ""

    readonly property var list: card.dev.notifications || []

    title: "NOTIFICATIONS ON THE PHONE"

    SettingRow {
        title: card.list.length === 0 ? "Nothing waiting" : (card.list.length === 1 ? "1 notification" : card.list.length + " notifications")
        description: card.list.length === 0 ? "Anything that arrives on the phone shows up here while it is connected." : "Dismissing one here dismisses it on the phone too."
        showDivider: card.list.length > 0
    }

    Column {
        width: parent.width
        spacing: 2
        topPadding: card.list.length > 0 ? 6 : 0
        bottomPadding: card.list.length > 0 ? 10 : 0

        Repeater {
            model: card.list

            Column {
                id: note

                required property var modelData

                readonly property bool replying: card.replyingTo === note.modelData.id
                readonly property bool canReply: note.modelData.replyId !== ""

                width: parent.width

                Rectangle {
                    width: parent.width - 24
                    x: 12
                    height: inner.implicitHeight + 22
                    radius: Theme.radiusMd
                    color: noteArea.containsMouse ? Theme.bgHover : Theme.bgSunken

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durQuick
                        }

                    }

                    MouseArea {
                        id: noteArea

                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Column {
                        id: inner

                        anchors.left: parent.left
                        anchors.right: dismissBtn.left
                        anchors.leftMargin: 16
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            width: parent.width
                            text: note.modelData.app
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: note.modelData.title
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            elide: Text.ElideRight
                            visible: note.modelData.title !== ""
                        }

                        Text {
                            width: parent.width
                            text: note.modelData.text !== "" ? note.modelData.text : note.modelData.ticker
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: 10
                            topPadding: 4
                            visible: note.canReply && !note.replying

                            M3Button {
                                variant: "tonal"
                                text: "Reply"
                                onClicked: card.replyingTo = note.modelData.id
                            }

                        }

                        Row {
                            width: parent.width
                            spacing: 10
                            topPadding: 4
                            visible: note.replying

                            M3TextField {
                                id: replyField

                                width: parent.width - 100
                                placeholder: "Type a reply…"
                                onAccepted: (v) => {
                                    if (v.trim() === "")
                                        return ;

                                    KdeConnect.notifyReply(card.dev.id, note.modelData.id, v.trim());
                                    replyField.clear();
                                    card.replyingTo = "";
                                }
                            }

                            M3Button {
                                anchors.verticalCenter: parent.verticalCenter
                                variant: "text"
                                text: "Cancel"
                                onClicked: card.replyingTo = ""
                            }

                        }

                    }

                    Rectangle {
                        id: dismissBtn

                        width: 30
                        height: 30
                        radius: Theme.rad(15)
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 11
                        visible: note.modelData.dismissable
                        color: dismissArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                            }

                        }

                        Rectangle {
                            width: 13
                            height: 1.6
                            radius: 1
                            anchors.centerIn: parent
                            rotation: 45
                            color: Theme.subtext
                        }

                        Rectangle {
                            width: 13
                            height: 1.6
                            radius: 1
                            anchors.centerIn: parent
                            rotation: -45
                            color: Theme.subtext
                        }

                        MouseArea {
                            id: dismissArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: KdeConnect.dismiss(card.dev.id, note.modelData.id)
                        }

                    }

                }

                Item {
                    width: 1
                    height: 6
                }

            }

        }

    }

}
