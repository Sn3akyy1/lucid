import QtQuick
import qs

// m3 outlined text field, recessed a surface step below the item holding it
Item {
    id: field

    property string text: ""
    property string placeholder: ""
    property bool enabled: true

    signal accepted(string value)
    signal edited(string value)

    // typing breaks the binding to `text`, so a reset has to reach the input
    function clear() {
        input.text = "";
        field.text = "";
    }

    implicitWidth: 220
    implicitHeight: 46
    opacity: field.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: Theme.shapeLg
        color: Theme.bgSunken
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Theme.accent : Theme.outlineStrong

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
        anchors.rightMargin: 16
        verticalAlignment: TextInput.AlignVCenter
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
            if (!input.activeFocus && input.text !== field.text)
                field.accepted(input.text);

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
        anchors.verticalCenter: parent.verticalCenter
        text: field.placeholder
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBodyLg
        visible: input.text === ""
    }

}
