import QtQuick
import QtQuick.Shapes
import qs

// removing an account is two decisions, not one: the account, and their files
Item {
    id: dialog

    property bool shown: false
    property var user: null
    property bool removeFiles: false

    signal submitted(int uid, bool removeFiles)

    function open(u) {
        dialog.user = u;
        dialog.removeFiles = false;
        dialog.shown = true;
    }

    function dismiss() {
        dialog.shown = false;
    }

    function submit() {
        if (!dialog.shown || !dialog.user)
            return ;

        var uid = dialog.user.uid;
        var rm = dialog.removeFiles;
        dialog.dismiss();
        dialog.submitted(uid, rm);
    }

    anchors.fill: parent
    visible: dialog.opacity > 0.01
    opacity: dialog.shown ? 1 : 0

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: dialog.dismiss()
        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(460, dialog.width - 64)
        height: cardCol.implicitHeight + 56
        radius: Theme.shapeXl
        color: Theme.bgHigh
        scale: dialog.shown ? 1 : 0.88
        opacity: dialog.shown ? 1 : 0

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: cardCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            spacing: 12

            Shape {
                width: 26
                height: 26
                anchors.horizontalCenter: parent.horizontalCenter
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.error

                    PathSvg {
                        path: "M12 2 1 21h22L12 2Zm0 5 7.5 12.9h-15L12 7Zm-1 4v5h2v-5h-2Zm0 6v2h2v-2h-2Z"
                    }

                }

                transform: Scale {
                    xScale: 26 / 24
                    yScale: 26 / 24
                }

            }

            Text {
                width: parent.width
                text: "Remove " + Users.displayName(dialog.user) + "?"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: "They will no longer be able to sign in to this machine."
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                lineHeight: 1.3
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Item {
                width: parent.width
                height: 2
            }

            // the files are the half that cannot be undone, so it is its own choice
            Rectangle {
                width: parent.width
                height: fileCol.implicitHeight + 32
                radius: Theme.shapeLg
                color: dialog.removeFiles ? Theme.errorContainer : Theme.bgSunken

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

                Column {
                    id: fileCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 8

                    CheckLine {
                        label: "Delete their home folder as well"
                        checked: dialog.removeFiles
                        danger: true
                        onToggled: dialog.removeFiles = !dialog.removeFiles
                    }

                    Text {
                        width: parent.width
                        text: dialog.removeFiles ? "Everything in " + (dialog.user ? dialog.user.home : "") + " is erased. There is no undoing this." : "Their files stay in " + (dialog.user ? dialog.user.home : "") + " for you to keep or clear out later."
                        color: dialog.removeFiles ? Theme.fgErrorContainer : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                        lineHeight: 1.25
                        wrapMode: Text.WordWrap
                    }

                }

            }

            Item {
                width: parent.width
                height: 6
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                M3Button {
                    text: "Cancel"
                    variant: "text"
                    onClicked: dialog.dismiss()
                }

                M3Button {
                    text: dialog.removeFiles ? "Remove and erase" : "Remove"
                    variant: "filled"
                    destructive: true
                    onClicked: dialog.submit()
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

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

}
