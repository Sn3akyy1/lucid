import QtQuick
import qs

Item {
    id: dialog

    property bool shown: false
    property string title: ""
    property string body: ""
    property string action: ""
    property string confirmLabel: "Reset"

    signal confirmed(string action)

    function ask(t, b, label, a) {
        dialog.title = t;
        dialog.body = b;
        dialog.confirmLabel = label;
        dialog.action = a;
        dialog.shown = true;
    }

    function dismiss() {
        dialog.shown = false;
    }

    function confirm() {
        if (!dialog.shown)
            return ;

        var a = dialog.action;
        dialog.dismiss();
        dialog.confirmed(a);
    }

    anchors.fill: parent
    visible: dialog.opacity > 0.01
    opacity: dialog.shown ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

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
        width: Math.min(400, dialog.width - 64)
        height: cardCol.implicitHeight + 48
        radius: Theme.radiusXl
        color: Theme.bgHigh
        scale: dialog.shown ? 1 : 0.9

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        // clicks on the card must not reach the dimmer
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: cardCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 10

            Text {
                width: parent.width
                text: dialog.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(17)
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: dialog.body
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(12)
                wrapMode: Text.WordWrap
            }

            Item {
                width: parent.width
                height: 8
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
                    text: dialog.confirmLabel
                    variant: "filled"
                    destructive: true
                    onClicked: dialog.confirm()
                }

            }

        }

    }

}
