import QtQuick
import qs

// m3 outlined text field, recessed a surface step below the item holding it
Item {
    id: field

    property string text: ""
    property string placeholder: ""
    property bool enabled: true
    // off for a field that only commits on enter, so clicking away cancels instead
    property bool commitOnBlur: true
    // masks what is typed and offers an eye to show it again
    property bool password: false
    property bool reveal: false
    property bool error: false

    signal accepted(string value)
    signal edited(string value)
    signal cancelled()

    // typing breaks the binding to `text`, so a reset has to reach the input
    function clear() {
        input.text = "";
        field.text = "";
    }

    // text from outside, which reaches the input even while it has focus.
    // like typing it, it is announced through edited
    function set(value) {
        input.text = value;
        field.text = value;
    }

    function focusInput() {
        input.forceActiveFocus();
        input.selectAll();
    }

    implicitWidth: Theme.dp(220)
    implicitHeight: Theme.dp(46)
    opacity: field.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: Theme.shapeLg
        color: Theme.bgSunken
        border.width: input.activeFocus || field.error ? 2 : 1
        border.color: field.error ? Theme.error : (input.activeFocus ? Theme.accent : Theme.outlineStrong)

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: Theme.dp(16)
        anchors.rightMargin: field.password ? Theme.dp(46) : Theme.dp(16)
        verticalAlignment: TextInput.AlignVCenter
        echoMode: field.password && !field.reveal ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        selectByMouse: true
        selectionColor: Theme.accent
        selectedTextColor: Theme.fgAccent
        enabled: field.enabled
        clip: true
        text: field.text
        onTextChanged: {
            if (input.text !== field.text)
                field.edited(input.text);

        }
        onAccepted: field.accepted(input.text)
        onActiveFocusChanged: {
            if (!input.activeFocus && field.commitOnBlur && input.text !== field.text)
                field.accepted(input.text);

        }
        // only an enter-to-commit field owns escape; the rest still pass it up
        Keys.onEscapePressed: (event) => {
            field.cancelled();
            event.accepted = !field.commitOnBlur;
        }

        Connections {
            function onTextChanged() {
                if (!input.activeFocus && input.text !== field.text)
                    input.text = field.text;

            }

            target: field
        }

    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(16)
        anchors.right: parent.right
        anchors.rightMargin: field.password ? Theme.dp(46) : Theme.dp(16)
        anchors.verticalCenter: parent.verticalCenter
        text: field.placeholder
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
        elide: Text.ElideRight
        visible: input.text === ""
    }

    M3IconButton {
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(5)
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.dp(36)
        iconSize: Theme.dp(19)
        visible: field.password
        iconPath: field.reveal ? "visibility" : "visibility_off"
        onClicked: {
            field.reveal = !field.reveal;
            input.forceActiveFocus();
        }
    }

}
