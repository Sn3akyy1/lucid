import "../lucidprefs"
import QtQuick
import qs
import qs.lucidui

// the polkit dialog's password pill, for the updater's sudo prompts
Rectangle {
    id: pill

    property bool error: false
    property bool busy: false
    property string placeholder: I18n.tr("Password")
    property real focusLift: input.activeFocus ? 1 : 0
    property real shakeOffset: 0
    property bool vacant: true
    readonly property string text: input.text

    signal accepted(string text)

    function focusInput() {
        input.forceActiveFocus();
    }

    function clear() {
        input.text = "";
        revealBtn.revealed = false;
    }

    function shake() {
        shakeAnim.restart();
    }

    function pin() {
        if (input.selectionStart === input.selectionEnd && input.cursorPosition !== input.length)
            input.cursorPosition = input.length;

    }

    width: parent ? parent.width : Theme.dp(400)
    height: Theme.dp(50)
    radius: Theme.dp(25)
    color: pill.error ? Theme.alpha(Theme.error, 0.14) : (input.activeFocus ? Theme.bgHigh : Theme.bgSunken)
    opacity: pill.busy && input.text === "" ? 0.6 : 1
    scale: 1 + pill.focusLift * 0.015

    Timer {
        id: vacate

        interval: Theme.durDefaultEffects
        onTriggered: pill.vacant = true
    }

    SequentialAnimation {
        id: shakeAnim

        NumberAnimation {
            target: pill
            property: "shakeOffset"
            to: -6
            duration: Theme.ms(45)
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: pill
            property: "shakeOffset"
            to: 6
            duration: Theme.ms(90)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: pill
            property: "shakeOffset"
            to: -4
            duration: Theme.ms(90)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: pill
            property: "shakeOffset"
            to: 4
            duration: Theme.ms(90)
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: pill
            property: "shakeOffset"
            to: 0
            duration: Theme.ms(60)
            easing.type: Easing.OutCubic
        }

    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -Theme.dp(3)
        radius: parent.radius + Theme.dp(3)
        color: "transparent"
        border.width: 1.5
        border.color: pill.error ? Theme.error : Theme.accent
        opacity: pill.error ? 0.55 : pill.focusLift * 0.55

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(240)
                easing.type: Easing.OutCubic
            }

        }

    }

    Icon {
        id: keyMark

        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(18)
        anchors.verticalCenter: parent.verticalCenter
        name: "key"
        size: Theme.dp(19)
        color: pill.error ? Theme.error : Theme.subtextDim
    }

    Text {
        anchors.left: keyMark.right
        anchors.leftMargin: Theme.dp(12)
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(48)
        anchors.verticalCenter: parent.verticalCenter
        transformOrigin: Item.Left
        text: pill.placeholder
        color: input.activeFocus ? Theme.subtext : Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        elide: Text.ElideRight
        opacity: pill.vacant ? 1 : 0
        scale: 0.94 + 0.06 * opacity
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durDefaultEffects
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }

        }

    }

    // each character lands as a turning shape and melts into a dot
    PasswordEcho {
        anchors.left: keyMark.right
        anchors.leftMargin: Theme.dp(12)
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(46)
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.dp(30)
        text: input.text
        reveal: revealBtn.revealed
        busy: pill.busy
        selectionStart: input.selectionStart
        selectionEnd: input.selectionEnd
        color: pill.error ? Theme.error : Theme.text
        edge: pill.color
        font: input.font
    }

    TextInput {
        id: input

        anchors.left: keyMark.right
        anchors.leftMargin: Theme.dp(12)
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(48)
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        enabled: !pill.busy
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
        cursorDelegate: Item {
        }
        // the beads have no caret, so a secret is typed at its end
        onCursorPositionChanged: Qt.callLater(pill.pin)
        onAccepted: {
            if (input.text !== "" && !pill.busy)
                pill.accepted(input.text);

        }
        onTextChanged: {
            if (input.text === "") {
                vacate.restart();
                return ;
            }
            vacate.stop();
            pill.vacant = false;
        }
    }

    M3IconButton {
        id: revealBtn

        property bool revealed: false

        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(7)
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.dp(36)
        iconSize: Theme.dp(19)
        iconPath: revealBtn.revealed ? "visibility" : "visibility_off"
        onClicked: {
            revealBtn.revealed = !revealBtn.revealed;
            pill.focusInput();
        }
    }

    transform: Translate {
        x: pill.shakeOffset
    }

    Behavior on focusLift {
        NumberAnimation {
            duration: Theme.ms(240)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.ms(150)
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durQuick
        }

    }

}
