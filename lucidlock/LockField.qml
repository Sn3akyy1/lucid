import QtQuick
import qs
import qs.lucidui

// the one field that matters: an m3 pill that owns the keyboard for the whole
// surface, whatever face the lock is currently wearing
Item {
    id: field

    readonly property alias text: input.text
    property bool reveal: false
    readonly property bool canSubmit: input.text.length > 0 && Lockscreen.acceptsInput
    // green while the door is opening, red when it just refused
    readonly property bool bad: Lockscreen.phase === "failed" || Lockscreen.phase === "error" || Lockscreen.lockedOut
    readonly property bool good: Lockscreen.granted
    // the placeholder waits for the last beads to fade before it comes back
    property bool vacant: true

    function focusInput() {
        input.forceActiveFocus();
    }

    function pin() {
        if (Lockscreen.secret && input.selectionStart === input.selectionEnd && input.cursorPosition !== input.length)
            input.cursorPosition = input.length;

    }

    function clear() {
        input.text = "";
    }

    function submit() {
        if (!field.canSubmit)
            return ;

        Lockscreen.submit(input.text);
        field.reveal = false;
    }

    implicitHeight: Theme.dp(56)

    Timer {
        id: vacate

        interval: Theme.durDefaultEffects
        onTriggered: field.vacant = true
    }

    // pam refusing, drawn as the door not giving
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

        target: Lockscreen
    }

    transform: Translate {
        id: shift
    }

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: height / 2
        color: field.good ? Theme.alpha(Theme.success, 0.16) : (field.bad ? Theme.alpha(Theme.error, 0.14) : Lockscreen.cardHigh)
        border.width: Lockscreen.focused || field.bad || field.good ? 2 : 0
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
    LockGlyph {
        id: leading

        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(20)
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.dp(20)
        name: field.good ? "lockOpen" : (Lockscreen.phase === "prompting" ? "key" : "lock")
        color: field.good ? Theme.success : (field.bad ? Theme.error : (Lockscreen.focused ? Theme.accent : Theme.subtext))

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(180)
            }

        }

    }

    // what to type, when nothing has been
    Text {
        anchors.left: leading.right
        anchors.leftMargin: Theme.dp(14)
        anchors.right: trailing.left
        anchors.rightMargin: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        transformOrigin: Item.Left
        text: Lockscreen.lockedOut ? "Locked" : (Lockscreen.phase === "prompting" && Lockscreen.prompt !== "" ? Lockscreen.prompt : "Password")
        color: Lockscreen.focused ? Theme.subtext : Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        elide: Text.ElideRight
        opacity: field.vacant && !Lockscreen.busy ? 1 : 0
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
        anchors.leftMargin: Theme.dp(14)
        anchors.right: trailing.left
        anchors.rightMargin: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.dp(30)
        text: input.text
        reveal: field.reveal
        busy: Lockscreen.busy
        selectionStart: input.selectionStart
        selectionEnd: input.selectionEnd
        color: field.good ? Theme.success : (field.bad ? Theme.error : Theme.text)
        edge: pill.color
        font: input.font
        visible: Lockscreen.secret
    }

    TextInput {
        id: input

        anchors.left: leading.right
        anchors.leftMargin: Theme.dp(14)
        anchors.right: trailing.left
        anchors.rightMargin: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        // readOnly rather than disabled: the field must never hand the
        // keyboard back while pam is thinking, or the surface goes deaf
        readOnly: !Lockscreen.acceptsInput
        // the beads stand in for the text unless pam asked something visible
        echoMode: Lockscreen.secret ? TextInput.Password : TextInput.Normal
        passwordCharacter: " "
        color: Lockscreen.secret ? "transparent" : Theme.text
        // the beads draw a secret's selection themselves
        selectionColor: Lockscreen.secret ? "transparent" : Theme.alpha(Theme.accent, 0.4)
        selectedTextColor: Lockscreen.secret ? "transparent" : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        selectByMouse: false
        clip: true
        activeFocusOnPress: true
        cursorDelegate: Rectangle {
            width: Theme.dp(2)
            radius: 1
            color: Theme.accent
            visible: !Lockscreen.secret
        }

        // the beads have no caret: a secret is typed at its end, and only a
        // selection grown back from there may hold the cursor anywhere else
        onCursorPositionChanged: Qt.callLater(field.pin)
        onAccepted: field.submit()
        // only real typing clears a verdict — emptying the field after a
        // refusal must not wipe the sentence explaining it
        onTextChanged: {
            if (input.text.length === 0) {
                vacate.restart();
                return ;
            }
            vacate.stop();
            field.vacant = false;
            Lockscreen.engage();
            if (Lockscreen.phase === "failed" || Lockscreen.phase === "error")
                Lockscreen.phase = "idle";

        }
        Keys.onEscapePressed: {
            input.text = "";
            field.reveal = false;
        }
        // typing already engages through onTextChanged, so this only has to
        // catch the keys that move or erase without producing any text. a bare
        // modifier is not typing: super, shift, ctrl, alt and the lock keys all
        // reach the field while it holds the keyboard, and none of them should
        // pull the lock out of its glance
        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Backspace:
            case Qt.Key_Delete:
            case Qt.Key_Left:
            case Qt.Key_Right:
            case Qt.Key_Home:
            case Qt.Key_End:
                Lockscreen.engage();
                break;
            }
        }
    }

    Row {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(2)

        // an eye, but only once there is something worth hiding
        LockIconButton {
            anchors.verticalCenter: parent.verticalCenter
            diameter: Theme.dp(40)
            glyphSize: Theme.dp(19)
            glyph: field.reveal ? "eyeOff" : "eye"
            glyphColor: Theme.subtext
            tooltip: field.reveal ? "Hide" : "Show"
            visible: Lockscreen.secret && input.text.length > 0 && !Lockscreen.busy
            onClicked: {
                field.reveal = !field.reveal;
                field.focusInput();
            }
        }

        Rectangle {
            id: submit

            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(44)
            height: Theme.dp(44)
            radius: Theme.dp(999)
            color: field.good ? Theme.success : (field.canSubmit || Lockscreen.busy ? (submitArea.hovered ? Theme.accentHover : Theme.accent) : Theme.alpha(Theme.outlineStrong, 0.35))
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

            LockGlyph {
                anchors.centerIn: parent
                size: Theme.dp(20)
                name: field.good ? "check" : "arrow"
                color: field.good ? Theme.fgSuccess : (field.canSubmit ? Theme.fgAccent : Theme.subtextDim)
                opacity: Lockscreen.busy ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(120)
                    }

                }

            }

            LockSpinner {
                anchors.centerIn: parent
                diameter: Theme.dp(22)
                color: Theme.fgAccent
                running: Lockscreen.busy
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
            Lockscreen.engage();
            field.focusInput();
            mouse.accepted = false;
        }
    }

}
