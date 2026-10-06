import "../lucidprefs"
import QtQuick
import qs
import qs.lucidui

// the authentication dialog: a badge for what is being asked, the request in
// plain words, who is being asked, and the one field that matters
Rectangle {
    id: card

    property bool shown: false

    readonly property var identity: Polkit.identities[Polkit.identityIndex] !== undefined ? Polkit.identities[Polkit.identityIndex] : null
    readonly property string headline: Polkit.title !== "" ? Polkit.title : "Authentication required"
    readonly property bool busy: Polkit.checking || (!Polkit.prompting && !Polkit.preview && !Polkit.granted)
    readonly property bool canSubmit: !card.busy && pwInput.text !== ""
    // the placeholder waits for the last beads to fade before it comes back
    property bool vacant: true

    function focusInput() {
        pwInput.forceActiveFocus();
    }

    function pin() {
        if (Polkit.secret && pwInput.selectionStart === pwInput.selectionEnd && pwInput.cursorPosition !== pwInput.length)
            pwInput.cursorPosition = pwInput.length;

    }

    function submit() {
        if (!card.canSubmit)
            return ;

        Polkit.submit(pwInput.text);
    }

    width: Theme.dp(452)
    height: body.implicitHeight + Theme.dp(56)
    radius: Theme.shapeXl
    color: Theme.bg
    scale: card.shown ? 1 : 0.9
    opacity: card.shown ? 1 : 0

    // a fresh prompt is a fresh field
    Connections {
        function onPromptingChanged() {
            if (!Polkit.prompting)
                return ;

            pwInput.text = "";
            card.focusInput();
        }

        // what was typed never outlives its request
        function onOpenChanged() {
            if (Polkit.open)
                return ;

            pwInput.text = "";
            revealBtn.revealed = false;
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

    Timer {
        id: vacate

        interval: Theme.durDefaultEffects
        onTriggered: card.vacant = true
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
        anchors.margins: Theme.dp(28)
        spacing: Theme.dp(14)
        opacity: Polkit.granted ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

        Row {
            width: parent.width
            spacing: Theme.dp(16)

            Item {
                width: Theme.dp(52)
                height: Theme.dp(52)

                MaterialShape {
                    anchors.fill: parent
                    shape: "cookie9"
                    color: Theme.accentContainer
                    spin: Polkit.checking ? 40 : 0

                    Behavior on spin {
                        NumberAnimation {
                            duration: Theme.durSlowSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                }

                AuthGlyph {
                    anchors.centerIn: parent
                    name: Polkit.glyph
                    color: Theme.fgAccentContainer
                    size: Theme.dp(26)
                }

            }

            Column {
                width: parent.width - Theme.dp(68)
                spacing: Theme.dp(3)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "Authentication required"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelMd
                    font.variableAxes: Theme.axes(Theme.fontLabelMd, 520, 0)
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: card.headline
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleLg
                    font.variableAxes: Theme.axes(Theme.fontTitleLg, 520, 0)
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
            font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
            lineHeight: 1.35
            wrapMode: Text.WordWrap
            visible: Polkit.message !== ""
        }

        // who the password belongs to, and the pick when polkit offers a choice
        Column {
            width: parent.width
            spacing: Theme.dp(8)
            visible: card.identity !== null

            Text {
                text: Polkit.multiUser ? "Continue as" : "Signing in as"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
                font.variableAxes: Theme.axes(Theme.fontLabelSm, 420, 0)
            }

            Flow {
                width: parent.width
                spacing: Theme.dp(8)

                Repeater {
                    model: Polkit.multiUser ? Polkit.identities : []

                    Rectangle {
                        id: chip

                        required property int index
                        required property var modelData

                        readonly property bool active: chip.index === Polkit.identityIndex

                        height: Theme.dp(40)
                        width: chipRow.width + Theme.dp(26)
                        radius: Theme.dp(20)
                        color: chip.active ? Theme.accentContainer : Theme.bgTile
                        border.width: chip.active ? 0 : 1
                        border.color: Theme.outline

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: Theme.dp(9)

                            UserAvatar {
                                anchors.verticalCenter: parent.verticalCenter
                                user: Polkit.userFor(chip.modelData)
                                size: Theme.dp(26)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Polkit.nameFor(chip.modelData)
                                color: chip.active ? Theme.fgAccentContainer : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBodyMd
                                font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
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
                spacing: Theme.dp(9)
                visible: !Polkit.multiUser

                UserAvatar {
                    anchors.verticalCenter: parent.verticalCenter
                    user: Polkit.userFor(card.identity)
                    size: Theme.dp(28)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Polkit.nameFor(card.identity)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
                }

            }

        }

        // the field, in the lock screen's language
        Rectangle {
            id: pill

            property real focusLift: pwInput.activeFocus ? 1 : 0
            property real shakeOffset: 0

            width: parent.width
            height: Theme.dp(50)
            radius: Theme.dp(25)
            color: Polkit.errorText !== "" ? Theme.alpha(Theme.error, 0.14) : (pwInput.activeFocus ? Theme.bgHigh : Theme.bgSunken)
            opacity: card.busy && pwInput.text === "" ? 0.6 : 1
            scale: 1 + pill.focusLift * 0.015

            transform: Translate {
                x: pill.shakeOffset
            }

            Behavior on focusLift {
                NumberAnimation {
                    duration: Theme.ms(240)
                    easing.type: Easing.OutCubic
                }

            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -Theme.dp(3)
                radius: parent.radius + Theme.dp(3)
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
                anchors.leftMargin: Theme.dp(18)
                anchors.verticalCenter: parent.verticalCenter
                name: "key"
                color: Polkit.errorText !== "" ? Theme.error : Theme.subtextDim
                size: Theme.dp(19)
            }

            Text {
                anchors.left: keyMark.right
                anchors.leftMargin: Theme.dp(12)
                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(48)
                anchors.verticalCenter: parent.verticalCenter
                transformOrigin: Item.Left
                text: Polkit.prompt.replace(/:\s*$/, "")
                color: pwInput.activeFocus ? Theme.subtext : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                elide: Text.ElideRight
                opacity: card.vacant ? 1 : 0
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
                id: echo

                anchors.left: keyMark.right
                anchors.leftMargin: Theme.dp(12)
                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(46)
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.dp(30)
                text: pwInput.text
                reveal: revealBtn.revealed
                busy: card.busy
                selectionStart: pwInput.selectionStart
                selectionEnd: pwInput.selectionEnd
                color: Polkit.errorText !== "" ? Theme.error : Theme.text
                edge: pill.color
                font: pwInput.font
                visible: Polkit.secret
            }

            TextInput {
                id: pwInput

                anchors.left: keyMark.right
                anchors.leftMargin: Theme.dp(12)
                anchors.right: parent.right
                anchors.rightMargin: Polkit.secret ? Theme.dp(48) : Theme.dp(18)
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                enabled: !card.busy
                // the beads stand in for the text unless pam asked something visible
                echoMode: Polkit.secret ? TextInput.Password : TextInput.Normal
                passwordCharacter: " "
                color: Polkit.secret ? "transparent" : Theme.text
                // the beads draw a secret's selection themselves
                selectionColor: Polkit.secret ? "transparent" : Theme.accent
                selectedTextColor: Polkit.secret ? "transparent" : Theme.fgAccent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                selectByMouse: false
                clip: true
                cursorDelegate: Rectangle {
                    width: Theme.dp(2)
                    radius: 1
                    color: Theme.accent
                    visible: !Polkit.secret
                }

                // the beads have no caret: a secret is typed at its end, and only a
                // selection grown back from there may hold the cursor anywhere else
                onCursorPositionChanged: Qt.callLater(card.pin)
                onAccepted: card.submit()
                onTextChanged: {
                    if (pwInput.text === "") {
                        vacate.restart();
                        return ;
                    }
                    vacate.stop();
                    card.vacant = false;
                    Polkit.errorText = "";
                }
                Keys.onEscapePressed: Polkit.cancel()
            }

            M3IconButton {
                id: revealBtn

                property bool revealed: false

                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(7)
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.dp(36)
                iconSize: Theme.dp(19)
                visible: Polkit.secret
                iconPath: revealBtn.revealed ? "visibility" : "visibility_off"
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
            height: status.line !== "" ? Theme.dp(18) : 0
            clip: true

            Text {
                width: parent.width
                text: status.line
                color: Polkit.errorText !== "" ? Theme.error : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
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
                width: detailsHead.width + Theme.dp(14)
                height: Theme.dp(40)
                cursorShape: Qt.PointingHandCursor
                onClicked: details.expanded = !details.expanded

                Row {
                    id: detailsHead

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(4)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Details"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                        font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_right"
                        size: Theme.dp(16)
                        color: Theme.subtextDim
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
                width: Math.max(0, parent.width - actions.width - detailsHead.width - Theme.dp(14))
                height: 1
            }

            Row {
                id: actions

                spacing: Theme.dp(8)

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
                    spacing: Theme.dp(4)
                    opacity: details.expanded ? 1 : 0

                    Text {
                        width: parent.width
                        text: "Action  " + Polkit.actionId
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                        font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                        elide: Text.ElideMiddle
                    }

                    Text {
                        width: parent.width
                        text: "Vendor  " + Polkit.vendor
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                        font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
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
        spacing: Theme.dp(14)
        opacity: Polkit.granted ? 1 : 0
        visible: opacity > 0.01

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.dp(60)
            height: Theme.dp(60)
            radius: Theme.dp(30)
            color: Theme.alpha(Theme.success, 0.18)

            AuthGlyph {
                anchors.centerIn: parent
                name: "check"
                color: Theme.success
                size: Theme.dp(30)
            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Authorised"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitleMd
            font.variableAxes: Theme.axes(Theme.fontTitleMd, 520, 0)
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
