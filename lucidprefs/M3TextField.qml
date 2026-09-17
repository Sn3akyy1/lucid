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

    function focusInput() {
        input.forceActiveFocus();
        input.selectAll();
    }

    implicitWidth: 220
    implicitHeight: 46
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
        anchors.leftMargin: 16
        anchors.rightMargin: field.password ? 46 : 16
        verticalAlignment: TextInput.AlignVCenter
        echoMode: field.password && !field.reveal ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
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
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: field.password ? 46 : 16
        anchors.verticalCenter: parent.verticalCenter
        text: field.placeholder
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        elide: Text.ElideRight
        visible: input.text === ""
    }

    M3IconButton {
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        size: 36
        iconSize: 19
        visible: field.password
        iconPath: field.reveal ? "M12 6.5c3.79 0 7.17 2.13 8.82 5.5-1.65 3.37-5.03 5.5-8.82 5.5S4.83 15.37 3.18 12C4.83 8.63 8.21 6.5 12 6.5m0-2C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5Zm0 5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5m0-2a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9Z" : "M12 6.5c3.79 0 7.17 2.13 8.82 5.5a10.6 10.6 0 0 1-2.1 2.9l1.42 1.42A12.6 12.6 0 0 0 23 12c-1.73-4.39-6-7.5-11-7.5-1.27 0-2.49.2-3.64.57l1.64 1.64c.65-.14 1.32-.21 2-.21ZM2.71 3.16 1.29 4.58l2.2 2.2A12.5 12.5 0 0 0 1 12c1.73 4.39 6 7.5 11 7.5 1.9 0 3.7-.45 5.29-1.25l3.13 3.13 1.42-1.42L2.71 3.16ZM12 17.5c-3.79 0-7.17-2.13-8.82-5.5a10.6 10.6 0 0 1 2.72-3.43l2.04 2.04a4.5 4.5 0 0 0 6.13 6.13l1.09 1.09c-1 .44-2.08.67-3.16.67Z"
        onClicked: {
            field.reveal = !field.reveal;
            input.forceActiveFocus();
        }
    }

}
