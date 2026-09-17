import QtQuick

// the one field that matters: an m3 pill that owns the keyboard for the whole
// surface, whatever face the greeter is currently wearing
Item {
    id: field

    readonly property alias text: input.text
    property bool reveal: false
    readonly property bool canSubmit: input.text.length > 0 && Lock.acceptsInput
    readonly property bool bad: Lock.phase === "failed"
    readonly property bool good: Lock.granted

    function focusInput() {
        input.forceActiveFocus();
    }

    function clear() {
        input.text = "";
    }

    function submit() {
        if (!field.canSubmit)
            return ;

        Lock.submit(input.text);
        field.reveal = false;
    }

    implicitHeight: 56

    // sddm refusing, drawn as the door not giving
    SequentialAnimation {
        id: shake

        NumberAnimation {
            target: shift
            property: "x"
            to: -9
            duration: Theme.ms(45)
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: shift
            property: "x"
            to: 9
            duration: Theme.ms(90)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: shift
            property: "x"
            to: -5
            duration: Theme.ms(90)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: shift
            property: "x"
            to: 5
            duration: Theme.ms(90)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: shift
            property: "x"
            to: 0
            duration: Theme.ms(60)
            easing.type: Easing.OutCubic
        }

    }

    Connections {
        function onFailed() {
            field.clear();
            field.reveal = false;
            shake.restart();
            field.focusInput();
        }

        target: Lock
    }

    transform: Translate {
        id: shift
    }

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: height / 2
        color: field.good ? Theme.alpha(Theme.success, 0.16) : (field.bad ? Theme.alpha(Theme.error, 0.14) : Theme.cardHigh)
        border.width: Lock.focused || field.bad || field.good ? 2 : 1
        border.color: field.good ? Theme.success : (field.bad ? Theme.error : (Lock.focused ? Theme.accent : Theme.outlineStrong))

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(180)
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.ms(180)
            }

        }

    }

    // the lock turns over when the password is accepted
    Glyph {
        id: leading

        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        size: 20
        name: field.good ? "lockOpen" : "lock"
        color: field.good ? Theme.success : (field.bad ? Theme.error : (Lock.focused ? Theme.accent : Theme.subtext))

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(180)
            }

        }

    }

    Text {
        anchors.left: leading.right
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "Password"
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        opacity: input.text.length === 0 && !Lock.busy && !Lock.focused ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(140)
            }

        }

    }

    // the typed secret. every character is dropped by the caret: the bead
    // starts as the caret's own line and settles into a dot where it stood
    Item {
        id: beadsClip

        readonly property int pitch: 15

        anchors.left: leading.right
        anchors.leftMargin: 14
        anchors.right: trailing.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        clip: true
        visible: !field.reveal

        Row {
            id: beads

            x: Math.min(0, beadsClip.width - beads.width)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            leftPadding: 4
            rightPadding: 4

            Behavior on x {
                NumberAnimation {
                    duration: Theme.ms(180)
                    easing.type: Easing.OutCubic
                }

            }

            Repeater {
                model: input.text.length

                Item {
                    id: bead

                    property real born: 0

                    width: 9
                    height: 18

                    NumberAnimation on born {
                        from: 0
                        to: 1
                        duration: Theme.ms(300)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 2 + 7 * bead.born
                        height: 18 - 9 * bead.born
                        radius: width / 2
                        opacity: 0.45 + 0.55 * bead.born
                        color: field.good ? Theme.success : (field.bad ? Theme.error : Theme.text)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.ms(180)
                            }

                        }

                    }

                }

            }

        }

        Rectangle {
            id: caret

            x: beads.x + input.cursorPosition * beadsClip.pitch
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 18
            radius: 1
            color: field.good ? Theme.success : (field.bad ? Theme.error : Theme.accent)
            visible: Lock.focused && !Lock.busy && !field.good

            Behavior on x {
                NumberAnimation {
                    duration: Theme.ms(150)
                    easing.type: Easing.OutCubic
                }

            }

            SequentialAnimation {
                id: blink

                running: true
                loops: Animation.Infinite

                PauseAnimation {
                    duration: 620
                }

                NumberAnimation {
                    target: caret
                    property: "opacity"
                    to: 0
                    duration: 130
                }

                PauseAnimation {
                    duration: 420
                }

                NumberAnimation {
                    target: caret
                    property: "opacity"
                    to: 1
                    duration: 130
                }

            }

        }

    }

    TextInput {
        id: input

        anchors.left: leading.right
        anchors.leftMargin: 14
        anchors.right: trailing.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        readOnly: !Lock.acceptsInput
        echoMode: field.reveal ? TextInput.Normal : TextInput.Password
        passwordCharacter: " "
        color: field.reveal ? Theme.text : "transparent"
        selectionColor: Theme.alpha(Theme.accent, 0.4)
        selectedTextColor: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        selectByMouse: false
        clip: true
        activeFocusOnPress: true
        cursorDelegate: Rectangle {
            width: 2
            radius: 1
            color: Theme.accent
            visible: field.reveal
        }

        onCursorPositionChanged: {
            caret.opacity = 1;
            blink.restart();
        }
        onAccepted: field.submit()
        onTextChanged: {
            if (input.text.length === 0)
                return ;

            Lock.engage();
            if (Lock.phase === "failed")
                Lock.phase = "idle";

        }
        Keys.onEscapePressed: {
            input.text = "";
            field.reveal = false;
        }
        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Backspace:
            case Qt.Key_Delete:
            case Qt.Key_Left:
            case Qt.Key_Right:
            case Qt.Key_Home:
            case Qt.Key_End:
                Lock.engage();
                break;
            }
        }
    }

    Row {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            diameter: 40
            glyphSize: 19
            glyph: field.reveal ? "eyeOff" : "eye"
            glyphColor: Theme.subtext
            visible: input.text.length > 0 && !Lock.busy
            onClicked: {
                field.reveal = !field.reveal;
                field.focusInput();
            }
        }

        Rectangle {
            id: submit

            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 999
            color: field.good ? Theme.success : (field.canSubmit || Lock.busy ? (submitArea.hovered ? Theme.accentHover : Theme.accent) : Theme.alpha(Theme.outlineStrong, 0.35))
            scale: submitTap.pressed ? 0.9 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(180)
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(110)
                    easing.type: Easing.OutCubic
                }

            }

            Glyph {
                anchors.centerIn: parent
                size: 20
                name: field.good ? "check" : "arrow"
                color: field.good ? Theme.fgSuccess : (field.canSubmit ? Theme.fgAccent : Theme.subtextDim)
                opacity: Lock.busy ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(120)
                    }

                }

            }

            Spinner {
                anchors.centerIn: parent
                diameter: 22
                color: Theme.fgAccent
                running: Lock.busy
            }

            HoverHandler {
                id: submitArea

                enabled: field.canSubmit
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: submitTap

                enabled: field.canSubmit
                onTapped: field.submit()
            }

        }

    }

    // the TextInput only covers the text line, and it takes that press
    // exclusively — which is why a handler on the pill never saw a click there.
    // this sits over the whole pill, engages, then declines so the press still
    // reaches the input underneath. the trailing buttons are left alone
    MouseArea {
        anchors.left: parent.left
        anchors.right: trailing.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        acceptedButtons: Qt.LeftButton
        onPressed: (mouse) => {
            Lock.engage();
            field.focusInput();
            mouse.accepted = false;
        }
    }

}
