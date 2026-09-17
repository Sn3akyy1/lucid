import "../lucidprefs"
import QtQuick
import qs

// the authentication dialog: a badge for what is being asked, the request in
// plain words, who is being asked, and the one field that matters
Rectangle {
    id: card

    property bool shown: false

    readonly property var identity: Polkit.identities[Polkit.identityIndex] !== undefined ? Polkit.identities[Polkit.identityIndex] : null
    readonly property string headline: Polkit.title !== "" ? Polkit.title : "Authentication required"
    readonly property bool busy: Polkit.checking || (!Polkit.prompting && !Polkit.preview && !Polkit.granted)
    readonly property bool canSubmit: !card.busy && pwInput.text !== ""

    function focusInput() {
        pwInput.forceActiveFocus();
    }

    function submit() {
        if (!card.canSubmit)
            return ;

        Polkit.submit(pwInput.text);
        pwInput.text = "";
    }

    width: 452
    height: body.implicitHeight + 56
    radius: Theme.shapeXl
    color: Theme.bg
    scale: card.shown ? 1 : 0.9
    opacity: card.shown ? 1 : 0

    // a fresh prompt is a fresh field
    Connections {
        function onPromptingChanged() {
            if (Polkit.prompting)
                card.focusInput();

        }

        // another administrator wants their own password, not the one typed
        function onIdentityIndexChanged() {
            pwInput.text = "";
        }

        target: Polkit
    }

    Connections {
        function onFailed() {
            pwInput.text = "";
            shakeAnim.restart();
            card.focusInput();
        }

        target: Polkit
    }

    // the lock screen's refusal, step for step
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

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 28
        spacing: 14
        opacity: Polkit.granted ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

        Row {
            width: parent.width
            spacing: 16

            Rectangle {
                width: 52
                height: 52
                radius: 26
                color: Theme.accentContainer

                AuthGlyph {
                    anchors.centerIn: parent
                    name: Polkit.glyph
                    color: Theme.fgAccentContainer
                    size: 26
                }

            }

            Column {
                width: parent.width - 68
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "Authentication required"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelMd
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: card.headline
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleLg
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

            }

        }

        Text {
            width: parent.width
            text: Polkit.message
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            lineHeight: 1.35
            wrapMode: Text.WordWrap
            visible: Polkit.message !== ""
        }

        // who the password belongs to, and the pick when polkit offers a choice
        Column {
            width: parent.width
            spacing: 8
            visible: card.identity !== null

            Text {
                text: Polkit.multiUser ? "Continue as" : "Signing in as"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
            }

            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: Polkit.multiUser ? Polkit.identities : []

                    Rectangle {
                        id: chip

                        required property int index
                        required property var modelData

                        readonly property bool active: chip.index === Polkit.identityIndex

                        height: 40
                        width: chipRow.width + 26
                        radius: 20
                        color: chip.active ? Theme.accentContainer : Theme.bgTile
                        border.width: chip.active ? 0 : 1
                        border.color: Theme.outline

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: 9

                            UserAvatar {
                                anchors.verticalCenter: parent.verticalCenter
                                user: Polkit.userFor(chip.modelData)
                                size: 26
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Polkit.nameFor(chip.modelData)
                                color: chip.active ? Theme.fgAccentContainer : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBodyMd
                                font.weight: chip.active ? Font.Medium : Font.Normal
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Polkit.pick(chip.index);
                                card.focusInput();
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                }

            }

            Row {
                spacing: 9
                visible: !Polkit.multiUser

                UserAvatar {
                    anchors.verticalCenter: parent.verticalCenter
                    user: Polkit.userFor(card.identity)
                    size: 28
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Polkit.nameFor(card.identity)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                }

            }

        }

        // the field, in the lock screen's language
        Rectangle {
            id: pill

            property real focusLift: pwInput.activeFocus ? 1 : 0
            property real typePulse: 0
            property real shakeOffset: 0

            width: parent.width
            height: 50
            radius: 25
            color: Polkit.errorText !== "" ? Theme.alpha(Theme.error, 0.14) : (pwInput.activeFocus ? Theme.bgHigh : Theme.bgSunken)
            opacity: card.busy ? 0.6 : 1
            scale: 1 + pill.focusLift * 0.015 + pill.typePulse

            transform: Translate {
                x: pill.shakeOffset
            }

            Behavior on focusLift {
                NumberAnimation {
                    duration: Theme.ms(240)
                    easing.type: Easing.OutCubic
                }

            }

            // every keystroke gives the bar the same small kick it has on the lock screen
            SequentialAnimation {
                id: typeBump

                NumberAnimation {
                    target: pill
                    property: "typePulse"
                    to: 0.02
                    duration: Theme.ms(70)
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: pill
                    property: "typePulse"
                    to: 0
                    duration: Theme.ms(160)
                    easing.type: Easing.OutCubic
                }

            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 1.5
                border.color: Polkit.errorText !== "" ? Theme.error : Theme.accent
                opacity: Polkit.errorText !== "" ? 0.55 : pill.focusLift * 0.55

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(240)
                        easing.type: Easing.OutCubic
                    }

                }

            }

            AuthGlyph {
                id: keyMark

                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                name: "key"
                color: Polkit.errorText !== "" ? Theme.error : Theme.subtextDim
                size: 19
            }

            TextInput {
                id: pwInput

                anchors.left: keyMark.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: Polkit.secret ? 48 : 18
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                enabled: !card.busy
                echoMode: (Polkit.secret && !revealBtn.revealed) ? TextInput.Password : TextInput.Normal
                passwordCharacter: "•"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.fgAccent
                clip: true
                onAccepted: card.submit()
                onTextChanged: {
                    if (pwInput.text !== "") {
                        Polkit.errorText = "";
                        typeBump.restart();
                    }
                }
                Keys.onEscapePressed: Polkit.cancel()
            }

            Text {
                anchors.left: keyMark.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Polkit.prompt.replace(/:\s*$/, "")
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                visible: pwInput.text === ""
            }

            M3IconButton {
                id: revealBtn

                property bool revealed: false

                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                size: 36
                iconSize: 19
                visible: Polkit.secret
                iconPath: revealBtn.revealed ? "M12 6.5c3.79 0 7.17 2.13 8.82 5.5-1.65 3.37-5.03 5.5-8.82 5.5S4.83 15.37 3.18 12C4.83 8.63 8.21 6.5 12 6.5m0-2C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5Zm0 5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5m0-2a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9Z" : "M12 6.5c3.79 0 7.17 2.13 8.82 5.5a10.6 10.6 0 0 1-2.1 2.9l1.42 1.42A12.6 12.6 0 0 0 23 12c-1.73-4.39-6-7.5-11-7.5-1.27 0-2.49.2-3.64.57l1.64 1.64c.65-.14 1.32-.21 2-.21ZM2.71 3.16 1.29 4.58l2.2 2.2A12.5 12.5 0 0 0 1 12c1.73 4.39 6 7.5 11 7.5 1.9 0 3.7-.45 5.29-1.25l3.13 3.13 1.42-1.42L2.71 3.16ZM12 17.5c-3.79 0-7.17-2.13-8.82-5.5a10.6 10.6 0 0 1 2.72-3.43l2.04 2.04a4.5 4.5 0 0 0 6.13 6.13l1.09 1.09c-1 .44-2.08.67-3.16.67Z"
                onClicked: {
                    revealBtn.revealed = !revealBtn.revealed;
                    card.focusInput();
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

        // one line that is either the failure, pam's own words, or the wait
        Item {
            id: status

            readonly property string line: Polkit.errorText !== "" ? Polkit.errorText : (Polkit.infoText !== "" ? Polkit.infoText : (card.busy ? "Checking with the authentication service…" : ""))

            width: parent.width
            height: status.line !== "" ? 18 : 0
            clip: true

            Text {
                width: parent.width
                text: status.line
                color: Polkit.errorText !== "" ? Theme.error : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                elide: Text.ElideRight
                opacity: status.line !== "" ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Theme.easeStandard
                }

            }

        }

        Row {
            width: parent.width

            MouseArea {
                width: detailsHead.width + 14
                height: 40
                cursorShape: Qt.PointingHandCursor
                onClicked: details.expanded = !details.expanded

                Row {
                    id: detailsHead

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Details"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                        rotation: details.expanded ? 90 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Theme.easeStandard
                            }

                        }

                    }

                }

            }

            Item {
                width: Math.max(0, parent.width - actions.width - detailsHead.width - 14)
                height: 1
            }

            Row {
                id: actions

                spacing: 8

                M3Button {
                    text: "Cancel"
                    variant: "text"
                    onClicked: Polkit.cancel()
                }

                M3Button {
                    text: "Authenticate"
                    variant: "filled"
                    enabled: card.canSubmit
                    onClicked: card.submit()
                }

            }

        }

        // polkit's own paperwork, kept out of the way until it is wanted
        Item {
            id: details

            property bool expanded: false

            width: parent.width
            height: detailBox.height

            Item {
                id: detailBox

                width: parent.width
                height: details.expanded ? detailRows.implicitHeight : 0
                clip: true

                Column {
                    id: detailRows

                    width: parent.width
                    spacing: 4
                    opacity: details.expanded ? 1 : 0

                    Text {
                        width: parent.width
                        text: "Action  " + Polkit.actionId
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                        elide: Text.ElideMiddle
                    }

                    Text {
                        width: parent.width
                        text: "Vendor  " + Polkit.vendor
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                        elide: Text.ElideRight
                        visible: Polkit.vendor !== ""
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

            }

        }

    }

    // the grant, held just long enough to be read
    Column {
        anchors.centerIn: parent
        spacing: 14
        opacity: Polkit.granted ? 1 : 0
        visible: opacity > 0.01

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 60
            height: 60
            radius: 30
            color: Theme.alpha(Theme.success, 0.18)

            AuthGlyph {
                anchors.centerIn: parent
                name: "check"
                color: Theme.success
                size: 30
            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Authorised"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitleMd
            font.weight: Font.Medium
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Theme.easeEmphasized
            easing.overshoot: Theme.emphasizedOvershoot
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

}
