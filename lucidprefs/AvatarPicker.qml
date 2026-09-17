import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs

// choosing an account picture: what the machine ships with, anything on disk,
// or none at all and back to initials
Item {
    id: picker

    property bool shown: false
    property var user: null

    signal chosen(int uid, string path)

    function open(u) {
        picker.user = u;
        picker.shown = true;
        Users.loadFaces();
        Users.loadHistory(u ? u.uid : -1);
    }

    function dismiss() {
        picker.shown = false;
    }

    function pick(path) {
        if (!picker.user)
            return ;

        var uid = picker.user.uid;
        picker.dismiss();
        picker.chosen(uid, path);
    }

    component AvatarChoice: ClippingRectangle {
        id: choice

        required property var modelData

        width: 62
        height: 62
        radius: 31
        color: Theme.bgSunken

        Image {
            anchors.fill: parent
            source: "file://" + choice.modelData.path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 128
            sourceSize.height: 128
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.text
            opacity: choiceArea.pressed ? Theme.statePressed : (choiceArea.containsMouse ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        MouseArea {
            id: choiceArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: picker.pick(choice.modelData.path)
        }

    }

    anchors.fill: parent
    visible: picker.opacity > 0.01
    opacity: picker.shown ? 1 : 0

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: picker.dismiss()
        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(460, picker.width - 64)
        height: cardCol.implicitHeight + 56
        radius: Theme.shapeXl
        color: Theme.bgHigh
        scale: picker.shown ? 1 : 0.88
        opacity: picker.shown ? 1 : 0

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: cardCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            spacing: 14

            Text {
                width: parent.width
                text: "Account picture"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                text: "It is squared off and shrunk to 256 pixels before it is saved, so any picture will do."
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                lineHeight: 1.3
                wrapMode: Text.WordWrap
            }

            // the machine's own stock faces, when it has any
            Flow {
                width: parent.width
                spacing: 10
                visible: Users.faces.length > 0

                Repeater {
                    model: Users.faces

                    AvatarChoice {
                    }

                }

            }

            // what this account wore before, so a picture is never lost by
            // changing it. the oldest drop off once the shelf is full
            Column {
                width: parent.width
                spacing: 8
                visible: Users.avatarHistory.length > 0

                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Previously used"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelSm
                    }

                    Text {
                        id: clearLabel

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear"
                        color: clearArea.containsMouse ? Theme.error : Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelSm

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    MouseArea {
                        id: clearArea

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        width: clearLabel.width + 16
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Users.clearHistory(picker.user ? picker.user.uid : -1)
                    }

                }

                Flow {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: Users.avatarHistory

                        AvatarChoice {
                        }

                    }

                }

            }

            Item {
                width: parent.width
                height: 2
            }

            Row {
                width: parent.width
                spacing: 8

                M3Button {
                    text: "Choose a picture…"
                    variant: "filled"
                    iconPath: "M9 2 7.17 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-3.17L15 2H9Zm3 5a6 6 0 1 1 0 12 6 6 0 0 1 0-12Zm0 2a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z"
                    onClicked: {
                        browse.command = ["sh", "-c", "zenity --file-selection --title='Choose an account picture' --file-filter='Images | *.jpg *.jpeg *.png *.webp *.JPG *.PNG *.WEBP' 2>/dev/null || true"];
                        browse.running = true;
                    }
                }

                M3Button {
                    text: "Remove"
                    variant: "text"
                    destructive: true
                    enabled: picker.user !== null && picker.user.avatar !== ""
                    onClicked: picker.pick("")
                }

            }

            Item {
                width: parent.width
                height: 4
            }

            Row {
                anchors.right: parent.right

                M3Button {
                    text: "Cancel"
                    variant: "text"
                    onClicked: picker.dismiss()
                }

            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    Process {
        id: browse

        stdout: StdioCollector {
            onStreamFinished: {
                var path = this.text.trim();
                if (path !== "")
                    picker.pick(path);

            }
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

}
