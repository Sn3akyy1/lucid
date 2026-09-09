import QtQuick
import QtQuick.Shapes
import qs

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
        width: Math.min(420, dialog.width - 64)
        height: cardCol.implicitHeight + 56
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
            anchors.margins: 28
            spacing: 12

            // m3 puts a hero icon above a destructive headline
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
                text: dialog.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
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
                lineHeight: 1.3
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Item {
                width: parent.width
                height: 10
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
