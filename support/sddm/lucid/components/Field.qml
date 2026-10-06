import QtQuick

// the one field that matters: an m3 pill that owns the keyboard for the whole
// surface, whatever face the greeter is currently wearing
Item {
    id: field

    readonly property alias text: input.text
    property bool reveal: false
    // an account without a password logs in on an empty field
    readonly property bool canSubmit: (input.text.length > 0 || !Lock.needsPassword) && Lock.acceptsInput && Lock.userName !== ""
    readonly property bool bad: Lock.phase === "failed"
    readonly property bool good: Lock.granted
    // the placeholder waits for the last beads to fade before it comes back
    property bool vacant: true

    function focusInput() {
        input.forceActiveFocus();
    }

    function pin() {
        if (input.selectionStart === input.selectionEnd && input.cursorPosition !== input.length)
            input.cursorPosition = input.length;

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

    Timer {
        id: vacate

        interval: Theme.durDefaultEffects
        onTriggered: field.vacant = true
    }

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

        function onSwitched() {
            field.clear();
            field.reveal = false;
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
        border.width: Lock.focused || field.bad || field.good ? 2 : 0
        border.color: field.good ? Theme.success : (field.bad ? Theme.error : Theme.accent)

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

    // what to type, when nothing has been
    Text {
        anchors.left: leading.right
        anchors.leftMargin: 14
        anchors.right: trailing.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        transformOrigin: Item.Left
        text: Lock.needsPassword ? "Password" : "No password needed"
        color: Lock.focused ? Theme.subtext : Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        elide: Text.ElideRight
        opacity: field.vacant && !Lock.busy ? 1 : 0
        scale: 0.94 + 0.06 * opacity
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durDefaultEffects
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(180)
            }

        }

    }

    // the typed secret: each character lands as a turning shape and melts
    // into a dot
    PasswordEcho {
        id: echo

        anchors.left: leading.right
        anchors.leftMargin: 14
        anchors.right: trailing.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        text: input.text
        reveal: field.reveal
        busy: Lock.busy
        selectionStart: input.selectionStart
        selectionEnd: input.selectionEnd
        color: field.good ? Theme.success : (field.bad ? Theme.error : Theme.text)
        edge: pill.color
        font: input.font
    }

    TextInput {
        id: input

        anchors.left: leading.right
        anchors.leftMargin: 14
        anchors.right: trailing.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        readOnly: !Lock.acceptsInput
        echoMode: TextInput.Password
        passwordCharacter: " "
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        selectByMouse: false
        clip: true
        activeFocusOnPress: true
        cursorDelegate: Item {
        }

        // the beads have no caret: the password is typed at its end, and only a
        // selection grown back from there may hold the cursor anywhere else
        onCursorPositionChanged: Qt.callLater(field.pin)
        onAccepted: field.submit()
        onTextChanged: {
            if (input.text.length === 0) {
                vacate.restart();
                return ;
            }
            vacate.stop();
            field.vacant = false;
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
