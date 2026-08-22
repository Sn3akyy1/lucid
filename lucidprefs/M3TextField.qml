import QtQuick
import qs

// Material 3 outlined text field, trimmed to what this app needs: no
// floating label (the setting row already names it), but the same outline
// that thickens and takes the accent colour on focus.
Item {
    id: field

    property string text: ""
    property string placeholder: ""
    property bool enabled: true

    signal accepted(string value)
    signal edited(string value)

    implicitWidth: 220
    implicitHeight: 44
    opacity: field.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
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
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
        selectByMouse: true
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        enabled: field.enabled
        clip: true
        text: field.text
        onTextChanged: {
            if (input.text !== field.text)
                field.edited(input.text);

        }
        onAccepted: field.accepted(input.text)
        // Losing focus commits too. Requiring Enter and silently throwing the
        // edit away otherwise is how a field looks like it "does nothing" -
        // the user typed the right thing and the app just discarded it.
        onActiveFocusChanged: {
            if (!input.activeFocus && input.text !== field.text)
                field.accepted(input.text);

        }

        // an external change to the bound value (a reset, say) has to reach
        // the editor, but only when the user isn't mid-edit
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
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: field.placeholder
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
        visible: input.text === ""
    }

}
