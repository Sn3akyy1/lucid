import QtQuick
import qs

// m3 text field. "filled" and "outlined" per spec; "search" is the m3 search bar
FocusScope {
    id: tf

    // "filled" | "outlined" | "search"
    property string variant: "filled"
    property alias text: input.text
    property alias input: input
    property string label: ""
    property string placeholder: ""
    property string icon: variant === "search" ? "search" : ""
    property string supporting: ""
    property bool error: false
    property bool clearable: tf.variant === "search"
    property bool password: false
    property color containerColor: tf.variant === "search" ? Theme.surfaceHigh : Theme.surfaceHighest
    property alias trailing: trailSlot.data
    readonly property bool active: input.activeFocus
    readonly property bool raised: tf.active || input.text !== ""

    signal accepted()
    signal textEdited()
    signal escaped()

    implicitWidth: Theme.dp(280)
    implicitHeight: box.height + (tf.supporting !== "" ? Theme.dp(20) : 0)

    Rectangle {
        id: box

        width: parent.width
        height: tf.variant === "search" ? Theme.dp(48) : Theme.dp(52)
        color: tf.variant === "outlined" ? "transparent" : tf.containerColor
        radius: tf.variant === "search" ? height / 2 : (tf.variant === "outlined" ? Theme.dp(10) : 0)
        topLeftRadius: tf.variant === "filled" ? Theme.dp(10) : radius
        topRightRadius: tf.variant === "filled" ? Theme.dp(10) : radius
        border.width: tf.variant === "outlined" ? (tf.active ? 2 : 1) : 0
        border.color: tf.error ? Theme.error : (tf.active ? Theme.primary : Theme.outlineStrong)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: input.forceActiveFocus()
        }

        Rectangle {
            visible: tf.variant === "filled"
            anchors.bottom: parent.bottom
            width: parent.width
            height: tf.active ? Theme.dp(2) : 1
            color: tf.error ? Theme.error : (tf.active ? Theme.primary : Theme.subtext)
        }

        Icon {
            id: lead

            visible: tf.icon !== ""
            anchors.left: parent.left
            anchors.leftMargin: tf.variant === "search" ? Theme.dp(16) : Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            name: tf.icon
            size: Theme.dp(22)
            color: tf.active && tf.variant !== "search" ? Theme.primary : Theme.subtext
        }

        LText {
            id: floating

            visible: tf.label !== "" && tf.variant !== "search"
            x: input.x
            y: tf.raised ? Theme.dp(7) : (box.height - height) / 2
            role: tf.raised ? "bodySmall" : "bodyLarge"
            text: tf.label
            color: tf.error ? Theme.error : (tf.active ? Theme.primary : Theme.subtext)

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durFastEffects
                    easing.type: Easing.OutCubic
                }

            }

        }

        TextInput {
            id: input

            anchors.left: lead.visible ? lead.right : parent.left
            anchors.leftMargin: lead.visible ? Theme.dp(12) : Theme.dp(16)
            anchors.right: trailRow.left
            anchors.rightMargin: Theme.dp(8)
            y: tf.label !== "" && tf.variant !== "search" ? Theme.dp(24) : (box.height - height) / 2
            focus: true
            clip: true
            color: Theme.text
            selectionColor: Theme.alpha(Theme.primary, 0.35)
            selectedTextColor: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeSize("bodyLarge")
            font.variableAxes: Theme.axes(Theme.typeSize("bodyLarge"), 420, 0)
            echoMode: tf.password ? TextInput.Password : TextInput.Normal
            onAccepted: tf.accepted()
            onTextEdited: tf.textEdited()
            Keys.onEscapePressed: tf.escaped()

            LText {
                visible: input.text === "" && (tf.label === "" || tf.variant === "search" || tf.active)
                anchors.verticalCenter: parent.verticalCenter
                role: "bodyLarge"
                text: tf.placeholder
                color: Theme.subtext
                opacity: 0.8
            }

        }

        Row {
            id: trailRow

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            Row {
                id: trailSlot

                anchors.verticalCenter: parent.verticalCenter
            }

            IconButton {
                visible: tf.clearable && input.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                size: "xs"
                onClicked: {
                    input.text = "";
                    tf.textEdited();
                    input.forceActiveFocus();
                }
            }

        }

    }

    LText {
        visible: tf.supporting !== ""
        anchors.top: box.bottom
        anchors.topMargin: Theme.dp(4)
        x: Theme.dp(16)
        role: "bodySmall"
        text: tf.supporting
        color: tf.error ? Theme.error : Theme.subtext
    }

}
