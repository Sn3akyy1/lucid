import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidui

// who is being asked, the field they answer in, and the one line that tells
// them how it went
Rectangle {
    id: card

    function focusInput() {
        pw.focusInput();
    }

    // a click off the card forgets what was half-typed
    function discard() {
        pw.reveal = false;
        pw.clear();
    }

    // the status line only takes room when it has something to say
    readonly property bool hasStatus: Lockscreen.statusText !== "" || Lockscreen.layoutShort !== "" || Lockscreen.capsLock

    radius: Theme.shapeXl
    color: Lockscreen.card
    implicitHeight: body.implicitHeight + 48

    // the card counts as inside the field: clicking it aims the keyboard at the
    // pill rather than dropping back to the glance
    MouseArea {
        anchors.fill: parent
        onClicked: {
            Lockscreen.engage();
            card.focusInput();
        }
    }

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 14

        Item {
            id: avatarBox

            anchors.horizontalCenter: parent.horizontalCenter
            width: 84
            height: 84

            // a ring in the avatar's own shape: accent while typing, red on refusal
            MaterialShape {
                anchors.centerIn: parent
                width: parent.width + 10
                height: parent.height + 10
                shape: "cookie12"
                spin: avatar.spin
                color: Lockscreen.granted ? Theme.success : (Lockscreen.phase === "failed" || Lockscreen.phase === "error" ? Theme.error : Theme.alpha(Theme.accent, 0.7))
                opacity: Lockscreen.focused ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(240)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(200)
                    }

                }

            }

            ShapedImage {
                id: avatar

                anchors.fill: parent
                shape: "cookie12"
                source: Lockscreen.avatar
                fallbackColor: Theme.accentContainer
                decode: 168
                // the scallops turn a little while the password is checked
                spin: Lockscreen.phase === "checking" ? 30 : 0

                Behavior on spin {
                    NumberAnimation {
                        duration: Theme.durSlowSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

                LText {
                    anchors.centerIn: parent
                    role: "headlineMedium"
                    weight: 560
                    rounded: 100
                    text: Lockscreen.initials
                    color: Theme.fgAccentContainer
                }

            }

        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Lockscreen.displayName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.variableAxes: Theme.axes(Theme.fontHeadlineSm, 520, 0)
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Lockscreen.userName
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                visible: Lockscreen.userName !== "" && Lockscreen.userName !== Lockscreen.displayName
            }

        }

        Item {
            width: parent.width
            height: 6
        }

        LockField {
            id: pw

            width: parent.width
        }

        // the status line: pam's verdict, the keyboard's warnings, or nothing
        Item {
            width: parent.width
            height: card.hasStatus ? 22 : 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Theme.ms(260)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

            Text {
                id: status

                anchors.left: parent.left
                anchors.right: marks.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: Lockscreen.statusText
                elide: Text.ElideRight
                color: {
                    switch (Lockscreen.statusKind) {
                    case "error":
                        return Theme.error;
                    case "good":
                        return Theme.success;
                    case "info":
                        return Theme.subtext;
                    }
                    return Theme.subtextDim;
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                font.weight: Lockscreen.statusKind === "error" ? Font.Medium : Font.Normal
                transform: Translate {
                    id: statusShift
                }

                // every new verdict arrives rather than simply being there
                onTextChanged: {
                    if (status.text !== "")
                        statusIn.restart();

                }

                SequentialAnimation {
                    id: statusIn

                    ParallelAnimation {
                        NumberAnimation {
                            target: status
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.ms(220)
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: statusShift
                            property: "y"
                            from: 7
                            to: 0
                            duration: Theme.ms(300)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                }

            }

            Row {
                id: marks

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // the commonest reason a password is refused, said where it
                // cannot be pushed aside by the refusal itself
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: capsRow.implicitWidth + 16
                    height: 20
                    radius: 999
                    color: Theme.alpha(Theme.warning, 0.18)
                    visible: Lockscreen.capsLock

                    Row {
                        id: capsRow

                        anchors.centerIn: parent
                        spacing: 4

                        LockGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "caps"
                            size: 13
                            color: Theme.warning
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Caps Lock"
                            color: Theme.warning
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelSm
                            font.variableAxes: Theme.axes(Theme.fontLabelSm, 520, 0)
                            font.weight: Font.Medium
                        }

                    }

                }

                // which keymap is live
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: layoutText.implicitWidth + 18
                    height: 20
                    radius: 999
                    color: Lockscreen.cardHigh
                    visible: Lockscreen.layoutShort !== "" && Lockscreen.focused

                    Text {
                        id: layoutText

                        anchors.centerIn: parent
                        text: Lockscreen.layoutShort
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelSm
                        font.variableAxes: Theme.axes(Theme.fontLabelSm, 520, 0)
                        font.weight: Font.Medium
                    }

                }

            }

        }

    }

}
