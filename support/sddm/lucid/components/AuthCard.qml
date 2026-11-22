import QtQuick
import "../parts" as Parts

// who is being asked, the field they answer in, and the one line that tells
// them how it went. the face, the name and the session chip open the pickers
// (Picker.qml, over the whole greeter), so choosing never resizes the card or
// moves the layout around it
Rectangle {
    id: card

    // card | bare | sheet | row, set by the preset's AuthHost (parts/AuthHost.qml):
    // on a card of its own, straight on the wallpaper, inside the panel
    // preset's sheet, or as one line, a small face beside the field.
    // lucidlock/LockAuthCard.qml dresses the same four ways
    property string authStyle: "card"
    // 1 at rest where the preset keeps only a hint of the field
    property real collapse: 0
    // at rest the hint alone: the face and the name wait for typing
    property bool quiet: false
    readonly property bool boxed: card.authStyle === "card"
    // the face beside the field, and no name: the deck preset's corner
    readonly property bool inline: card.authStyle === "row"
    readonly property real mini: Theme.dp(52)
    readonly property real pad: card.boxed ? Theme.dp(24) : 0
    readonly property real face: card.authStyle === "sheet" ? Theme.dp(96) : (card.authStyle === "bare" ? Theme.dp(76) : Theme.dp(88))
    readonly property real who: card.quiet ? Math.max(0, 1 - card.collapse * 1.6) : 1
    readonly property string layoutShort: {
        if (!keyboard.layouts || keyboard.layouts.length === 0)
            return "";

        var l = keyboard.layouts[keyboard.currentLayout];
        if (!l)
            return "";

        var t = l.shortName !== undefined && l.shortName !== "" ? l.shortName : l.longName;
        return t === undefined ? "" : String(t).substring(0, 6).toUpperCase();
    }
    readonly property bool hasStatus: card.collapse < 0.5 && (Lock.statusText !== "" || card.layoutShort !== "" || keyboard.capsLock || Lock.focused)

    function focusInput() {
        if (Lock.sheet !== "")
            return ;

        if (Lock.manual && Lock.manualName === "")
            nameInput.forceActiveFocus();
        else
            pw.focusInput();
    }

    function discard() {
        pw.reveal = false;
        pw.clear();
        Lock.closeSheet();
    }

    radius: Theme.shapeXl
    color: card.boxed ? Theme.card : "transparent"
    implicitHeight: card.pad * 2 + face.implicitHeight

    Connections {
        // a picker closed: the keys come back to the field
        function onSheetChanged() {
            if (Lock.sheet === "")
                Qt.callLater(card.focusInput);

        }

        function onSwitched() {
            nameInput.text = "";
            Qt.callLater(card.focusInput);
        }

        target: Lock
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            Lock.engage();
            card.focusInput();
        }
    }

    Item {
        id: pages

        anchors.fill: parent

        // ── the question ───────────────────────────────────────────────────────
        Column {
            id: face

            // the scallops turn a little while the password is checked
            property real spin: Lock.phase === "checking" ? 30 : 0

            x: card.pad
            y: card.pad
            width: card.width - card.pad * 2
            spacing: Theme.dp(14)

            Behavior on spin {
                NumberAnimation {
                    duration: Theme.ms(650)
                    easing.type: Easing.OutBack
                }

            }

            Item {
                id: avatarBox

                visible: !card.inline
                // faded out at rest (the quiet presets), it takes no clicks either
                enabled: card.who > 0.5
                anchors.horizontalCenter: parent.horizontalCenter
                width: card.face
                height: card.face
                opacity: card.who
                scale: 0.85 + 0.15 * card.who

                // a ring in the avatar's own shape: accent while typing, red on
                // refusal. it sits behind the face, so the face cuts it to a rim
                Cookie {
                    anchors.centerIn: parent
                    width: parent.width + Theme.dp(10)
                    height: parent.height + Theme.dp(10)
                    spin: face.spin
                    color: Lock.granted ? Theme.accent : (Lock.phase === "failed" ? Theme.wrong : Theme.alpha(Theme.accent, 0.7))
                    opacity: Lock.focused ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(240)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(200)
                        }

                    }

                }

                Avatar {
                    anchors.fill: parent
                    source: Lock.avatar
                    initials: Lock.initials
                    spin: face.spin
                    visible: !Lock.manual
                }

                Cookie {
                    anchors.fill: parent
                    spin: face.spin
                    color: Theme.cardHigh
                    visible: Lock.manual

                    Glyph {
                        anchors.centerIn: parent
                        name: "person"
                        size: Theme.dp(38)
                        color: Theme.subtext
                    }

                }

                TapHandler {
                    enabled: Lock.canSwitchUser
                    onTapped: Lock.openSheet("users", avatarBox)
                }

                HoverHandler {
                    enabled: Lock.canSwitchUser
                    cursorShape: Qt.PointingHandCursor
                }

            }

            // the name doubles as the way to someone else, once there is anyone
            Column {
                visible: !card.inline
                enabled: card.who > 0.5
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: card.who

                Item {
                    id: nameChip

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: nameRow.implicitWidth + (Lock.canSwitchUser ? Theme.dp(30) : 0)
                    height: Theme.dp(40)

                    // tonal while its menu is up
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.pill(height)
                        color: Theme.accentContainer
                        opacity: Lock.sheet === "users" ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.ms(160)
                            }

                        }

                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.pill(height)
                        color: Theme.text
                        opacity: nameTap.pressed ? Theme.statePressed : (nameHover.hovered ? Theme.stateHover : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.ms(120)
                            }

                        }

                    }

                    Row {
                        id: nameRow

                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: Lock.canSwitchUser ? Theme.dp(3) : 0
                        spacing: Theme.dp(4)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Lock.manual ? "Other account" : Lock.displayName
                            color: Lock.sheet === "users" ? Theme.fgAccentContainer : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHeadlineSm
                            font.variableAxes: Theme.axes(Theme.fontHeadlineSm, 520, 0)
                            font.weight: Font.Medium
                        }

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "expand"
                            size: Theme.dp(22)
                            color: Lock.sheet === "users" ? Theme.fgAccentContainer : Theme.subtext
                            visible: Lock.canSwitchUser
                            // points the way the list went
                            rotation: Lock.sheet === "users" ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Theme.ms(320)
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveDefaultSpatial
                                }

                            }

                        }

                    }

                    HoverHandler {
                        id: nameHover

                        enabled: Lock.canSwitchUser
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: nameTap

                        enabled: Lock.canSwitchUser
                        onTapped: Lock.openSheet("users", nameChip)
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lock.userName
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodySm
                    font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                    visible: !Lock.manual && Lock.userName !== "" && Lock.userName !== Lock.displayName
                }

            }

            Item {
                visible: !card.inline
                width: parent.width
                height: Theme.dp(6)
            }

            // an account sddm does not list is named by hand, above the password
            Rectangle {
                width: parent.width
                height: Theme.dp(56)
                radius: Theme.pill(height)
                color: Theme.cardHigh
                border.width: nameInput.activeFocus ? 2 : 0
                border.color: Theme.accent
                visible: Lock.manual

                Glyph {
                    id: nameLead

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(20)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "person"
                    size: Theme.dp(20)
                    color: nameInput.activeFocus ? Theme.accent : Theme.subtext
                }

                Text {
                    anchors.left: nameLead.right
                    anchors.leftMargin: Theme.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Username"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                    visible: nameInput.text.length === 0
                }

                TextInput {
                    id: nameInput

                    anchors.left: nameLead.right
                    anchors.leftMargin: Theme.dp(14)
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(20)
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Theme.alpha(Theme.accent, 0.4)
                    selectedTextColor: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                    readOnly: !Lock.acceptsInput
                    clip: true
                    // as in Field: on, it opens the on-screen keyboard at every focus
                    activeFocusOnPress: false
                    activeFocusOnTab: true
                    onTextChanged: {
                        Lock.manualName = nameInput.text;
                        if (nameInput.text.length > 0)
                            Lock.engage();

                    }
                    onAccepted: pw.focusInput()
                    Keys.onTabPressed: pw.focusInput()
                    Keys.onDownPressed: pw.focusInput()
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: (mouse) => {
                        Lock.engage();
                        nameInput.forceActiveFocus();
                        if (nameFinger.active)
                            Lock.openKeys();

                        mouse.accepted = false;
                    }

                    PointHandler {
                        id: nameFinger

                        acceptedDevices: PointerDevice.TouchScreen
                    }

                }

            }

            Item {
                width: parent.width
                height: Math.max(pw.height, card.inline ? card.mini : 0)

                // the row's own face: a tap on it is the way to another account
                Item {
                    visible: card.inline
                    y: (parent.height - height) / 2
                    width: card.mini
                    height: card.mini

                    Cookie {
                        anchors.centerIn: parent
                        width: parent.width + Theme.dp(8)
                        height: parent.height + Theme.dp(8)
                        spin: face.spin
                        color: Lock.granted ? Theme.accent : (Lock.phase === "failed" ? Theme.wrong : Theme.alpha(Theme.accent, 0.7))
                        opacity: Lock.focused ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.ms(240)
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Avatar {
                        anchors.fill: parent
                        source: card.inline ? Lock.avatar : ""
                        initials: Lock.initials
                        spin: face.spin
                        visible: !Lock.manual
                    }

                    Cookie {
                        anchors.fill: parent
                        spin: face.spin
                        color: Theme.cardHigh
                        visible: Lock.manual

                        Glyph {
                            anchors.centerIn: parent
                            name: "person"
                            size: Theme.dp(24)
                            color: Theme.subtext
                        }

                    }

                    TapHandler {
                        enabled: Lock.canSwitchUser
                        onTapped: Lock.openSheet("users", parent)
                    }

                    HoverHandler {
                        enabled: Lock.canSwitchUser
                        cursorShape: Qt.PointingHandCursor
                    }

                }

                Field {
                    id: pw

                    x: card.inline ? card.mini + Theme.dp(12) : 0
                    y: (parent.height - height) / 2
                    width: parent.width - x
                    collapse: card.collapse
                }

            }

            // the status line: sddm's verdict, the keyboard's warnings, or nothing
            Item {
                width: parent.width
                height: card.hasStatus ? Theme.dp(22) : 0
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.ms(260)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                Text {
                    id: status

                    anchors.left: parent.left
                    anchors.right: marks.left
                    anchors.rightMargin: Theme.dp(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lock.statusText
                    elide: Text.ElideRight
                    color: {
                        switch (Lock.statusKind) {
                        case "error":
                            return Theme.wrong;
                        case "good":
                            return Theme.accent;
                        case "info":
                            return Theme.subtext;
                        }
                        return Theme.subtextDim;
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodySm
                    font.variableAxes: Theme.axes(Theme.fontBodySm, Lock.statusKind === "error" ? 520 : 420, 0)
                    font.weight: Lock.statusKind === "error" ? Font.Medium : Font.Normal
                    transform: Translate {
                        id: statusShift
                    }

                    onTextChanged: {
                        if (status.text !== "")
                            statusIn.restart();

                    }

                    SequentialAnimation {
                        id: statusIn

                        ParallelAnimation {
                            NumberAnimation {
                                target: status
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Theme.ms(220)
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: statusShift
                                property: "y"
                                from: 7
                                to: 0
                                duration: Theme.ms(300)
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.easeEmphasizedDecel
                            }

                        }

                    }

                }

                Row {
                    id: marks

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(6)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: capsRow.implicitWidth + Theme.dp(16)
                        height: Theme.dp(20)
                        radius: Theme.dp(999)
                        color: Theme.alpha(Theme.warning, 0.18)
                        visible: keyboard.capsLock

                        Row {
                            id: capsRow

                            anchors.centerIn: parent
                            spacing: Theme.dp(4)

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "caps"
                                size: Theme.dp(13)
                                color: Theme.warning
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Caps Lock"
                                color: Theme.warning
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabelSm
                                font.variableAxes: Theme.axes(Theme.fontLabelSm, 520, 0)
                                font.weight: Font.Medium
                            }

                        }

                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: layoutText.implicitWidth + Theme.dp(18)
                        height: Theme.dp(20)
                        radius: Theme.dp(999)
                        color: Theme.cardHigh
                        visible: card.layoutShort !== "" && Lock.focused

                        Text {
                            id: layoutText

                            anchors.centerIn: parent
                            text: card.layoutShort
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelSm
                            font.variableAxes: Theme.axes(Theme.fontLabelSm, 520, 0)
                            font.weight: Font.Medium
                        }

                    }

                    Parts.KeysChip {
                        anchors.verticalCenter: parent.verticalCenter
                        theme: Theme
                        base: Theme.cardHigh
                        on: Lock.keysOpen
                        visible: Lock.focused
                        onToggled: Lock.toggleKeys()
                    }

                }

            }

            // what the password opens, and the way to open something else
            Item {
                width: parent.width
                height: Theme.dp(40)
                visible: Lock.sessions.length > 1
                opacity: 1 - card.collapse
                // folded away with the field it takes no clicks either
                enabled: card.collapse < 0.5

                // the session, as an m3 chip: 32dp, 8dp corners, an outline, the
                // name and a chevron; filled with the tonal container while its
                // menu is up
                Rectangle {
                    id: sessionChip

                    readonly property bool open: Lock.sheet === "sessions"

                    anchors.centerIn: parent
                    width: Math.min(face.width, sessionRow.implicitWidth + Theme.dp(16) + Theme.dp(8))
                    height: Theme.dp(32)
                    radius: Theme.shapeSm
                    color: sessionChip.open ? Theme.accentContainer : "transparent"
                    border.width: sessionChip.open ? 0 : 1
                    border.color: Theme.outline

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(160)
                        }

                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: sessionChip.open ? Theme.fgAccentContainer : Theme.text
                        opacity: sessionTap.pressed ? Theme.statePressed : (sessionHover.hovered ? Theme.stateHover : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.ms(120)
                            }

                        }

                    }

                    Row {
                        id: sessionRow

                        x: Theme.dp(16)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(8)

                        // an eliding Text reports its elided width: the full one is measured
                        TextMetrics {
                            id: sessionMeasure

                            font: sessionText.font
                            text: Lock.sessionName
                        }

                        Text {
                            id: sessionText

                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(Math.ceil(sessionMeasure.advanceWidth) + 1, face.width - Theme.dp(50))
                            text: Lock.sessionName
                            elide: Text.ElideRight
                            color: sessionChip.open ? Theme.fgAccentContainer : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            font.variableAxes: Theme.axes(Theme.fontLabelLg, 500, 0)
                            font.weight: Font.Medium
                        }

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "expand"
                            size: Theme.dp(18)
                            color: sessionChip.open ? Theme.fgAccentContainer : Theme.subtext
                            rotation: sessionChip.open ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Theme.ms(320)
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveDefaultSpatial
                                }

                            }

                        }

                    }

                    HoverHandler {
                        id: sessionHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: sessionTap

                        onTapped: Lock.openSheet("sessions", sessionChip)
                    }

                }

            }

        }

    }

}
