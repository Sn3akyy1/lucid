import QtQuick
import qs
import qs.lucidui

// m3 basic dialog: extra-large shape, hero icon, headline, actions bottom-right
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
        width: Math.min(Theme.dp(420), dialog.width - Theme.dp(64))
        height: cardCol.implicitHeight + Theme.dp(56)
        radius: Theme.shapeXl
        color: Theme.bgHigh
        scale: dialog.shown ? 1 : 0.88
        opacity: dialog.shown ? 1 : 0

        // clicks on the card must not reach the dimmer
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: cardCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(28)
            spacing: Theme.dp(12)

            // m3 puts a hero icon above a destructive headline
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "warning"
                size: Theme.dp(26)
                color: Theme.error
            }

            Text {
                width: parent.width
                text: dialog.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.variableAxes: Theme.axes(Theme.fontHeadlineSm, 520, 0)
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: dialog.body
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                lineHeight: 1.3
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Item {
                width: parent.width
                height: Theme.dp(10)
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.dp(8)

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
