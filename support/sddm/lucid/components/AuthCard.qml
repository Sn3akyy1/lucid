import QtQuick
import Qt5Compat.GraphicalEffects

// who is being asked, the field they answer in, and the one line that tells
// them how it went
Rectangle {
    id: card

    function focusInput() {
        pw.focusInput();
    }

    function discard() {
        pw.reveal = false;
        pw.clear();
    }

    readonly property string layoutShort: {
        if (!keyboard.layouts || keyboard.layouts.length === 0)
            return "";

        var l = keyboard.layouts[keyboard.currentLayout];
        if (!l)
            return "";

        var t = l.shortName !== undefined && l.shortName !== "" ? l.shortName : l.longName;
        return t === undefined ? "" : String(t).substring(0, 6).toUpperCase();
    }
    readonly property bool hasStatus: Lock.statusText !== "" || card.layoutShort !== "" || keyboard.capsLock

    radius: Theme.shapeXl
    color: Theme.card
    implicitHeight: body.implicitHeight + 48

    MouseArea {
        anchors.fill: parent
        onClicked: {
            Lock.engage();
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

            // clip is a rectangular scissor, so the face has to be masked to
            // really round. a plain radius would leave the corners square
            Rectangle {
                id: avatarFill

                anchors.fill: parent
                radius: width / 2
                color: Theme.accentContainer

                Text {
                    anchors.centerIn: parent
                    text: Lock.initials
                    color: Theme.fgAccentContainer
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(30)
                    font.weight: Font.Medium
                }

            }

            Image {
                id: face

                anchors.fill: parent
                source: Lock.avatar
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 168
                sourceSize.height: 168
                asynchronous: true
                cache: false
                visible: false
            }

            Rectangle {
                id: faceMask

                anchors.fill: parent
                radius: width / 2
                color: "white"
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: face
                maskSource: faceMask
                visible: face.status === Image.Ready
            }

            // a ring that answers the field: accent while typing, red on
            // refusal. it lives outside the mask, or half of it is cut off
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: Lock.granted ? Theme.success : (Lock.phase === "failed" ? Theme.error : Theme.alpha(Theme.accent, 0.55))
                opacity: Lock.focused ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(240)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.ms(200)
                    }

                }

            }

        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Lock.displayName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Lock.userName
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                visible: Lock.userName !== "" && Lock.userName !== Lock.displayName
            }

        }

        Item {
            width: parent.width
            height: 6
        }

        Field {
            id: pw

            width: parent.width
        }

        // the status line: sddm's verdict, the keyboard's warnings, or nothing
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
                text: Lock.statusText
                elide: Text.ElideRight
                color: {
                    switch (Lock.statusKind) {
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
                font.weight: Lock.statusKind === "error" ? Font.Medium : Font.Normal
                transform: Translate {
                    id: statusShift
                }

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

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: capsRow.implicitWidth + 16
                    height: 20
                    radius: 999
                    color: Theme.alpha(Theme.warning, 0.18)
                    visible: keyboard.capsLock

                    Row {
                        id: capsRow

                        anchors.centerIn: parent
                        spacing: 4

                        Glyph {
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
                            font.weight: Font.Medium
                        }

                    }

                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: layoutText.implicitWidth + 18
                    height: 20
                    radius: 999
                    color: Theme.cardHigh
                    visible: card.layoutShort !== "" && Lock.focused

                    Text {
                        id: layoutText

                        anchors.centerIn: parent
                        text: card.layoutShort
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelSm
                        font.weight: Font.Medium
                    }

                }

            }

        }

    }

}
