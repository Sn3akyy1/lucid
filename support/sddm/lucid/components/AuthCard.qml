import QtQuick

// who is being asked, the field they answer in, and the one line that tells
// them how it went. picking another account or session turns the card over to
// a sheet that pushes in from the side, then pushes back out again
Rectangle {
    id: card

    // 0 the question, 1 a sheet laid over it
    property real k: Lock.sheet !== "" ? 1 : 0
    // the sheet keeps its rows while it slides back out
    property string shown: "users"
    // the ring only follows the keyboard, never the pointer
    property bool kbd: false
    readonly property string layoutShort: {
        if (!keyboard.layouts || keyboard.layouts.length === 0)
            return "";

        var l = keyboard.layouts[keyboard.currentLayout];
        if (!l)
            return "";

        var t = l.shortName !== undefined && l.shortName !== "" ? l.shortName : l.longName;
        return t === undefined ? "" : String(t).substring(0, 6).toUpperCase();
    }
    readonly property bool hasStatus: Lock.statusText !== "" || card.layoutShort !== "" || keyboard.capsLock
    readonly property int rows: card.shown === "users" ? Lock.accounts.length + 1 : Lock.sessions.length
    readonly property int rowH: 60

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

    function activate(i) {
        if (card.shown === "sessions")
            Lock.pickSession(i);
        else if (i >= Lock.accounts.length)
            Lock.pickOther();
        else
            Lock.pick(i);
    }

    function selectedRow() {
        if (card.shown === "sessions")
            return Lock.sessionIndex;

        return Lock.manual ? Lock.accounts.length : Lock.index;
    }

    radius: Theme.shapeXl
    color: Theme.card
    clip: true
    // no Behavior: k is the one clock, and each face already eases its own
    // height, so easing the sum again would only put the card out of step
    implicitHeight: 48 + (1 - card.k) * face.implicitHeight + card.k * sheet.implicitHeight

    Behavior on k {
        NumberAnimation {
            duration: Theme.ms(460)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Connections {
        function onSheetChanged() {
            if (Lock.sheet === "") {
                Qt.callLater(card.focusInput);
                return ;
            }
            card.shown = Lock.sheet;
            card.kbd = false;
            list.currentIndex = card.selectedRow();
            list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            list.forceActiveFocus();
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

    // the push is cut to the card by a layer while it runs: the software
    // renderer lets shapes and masks draw straight past an ancestor's clip
    Item {
        id: pages

        anchors.fill: parent
        layer.enabled: card.k > 0.001 && card.k < 0.999

        // ── the question ───────────────────────────────────────────────────────
        Column {
            id: face

            // the scallops turn a little while the password is checked
            property real spin: Lock.phase === "checking" ? 30 : 0

            x: 24 - card.k * card.width
            y: 24
            width: card.width - 48
            spacing: 14
            visible: card.k < 0.999

            Behavior on spin {
                NumberAnimation {
                    duration: Theme.ms(650)
                    easing.type: Easing.OutBack
                }

            }

            Item {
                id: avatarBox

                anchors.horizontalCenter: parent.horizontalCenter
                width: 88
                height: 88

                // a ring in the avatar's own shape: accent while typing, red on
                // refusal. it sits behind the face, so the face cuts it to a rim
                Cookie {
                    anchors.centerIn: parent
                    width: parent.width + 10
                    height: parent.height + 10
                    spin: face.spin
                    color: Lock.granted ? Theme.success : (Lock.phase === "failed" ? Theme.error : Theme.alpha(Theme.accent, 0.7))
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
                        size: 38
                        color: Theme.subtext
                    }

                }

                TapHandler {
                    enabled: Lock.canSwitchUser
                    onTapped: Lock.openSheet("users")
                }

                HoverHandler {
                    enabled: Lock.canSwitchUser
                    cursorShape: Qt.PointingHandCursor
                }

            }

            // the name doubles as the way to someone else, once there is anyone
            Column {
                anchors.horizontalCenter: parent.horizontalCenter

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: nameRow.implicitWidth + (Lock.canSwitchUser ? 30 : 0)
                    height: 40

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
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
                        anchors.horizontalCenterOffset: Lock.canSwitchUser ? 3 : 0
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Lock.manual ? "Other account" : Lock.displayName
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHeadlineSm
                            font.variableAxes: Theme.axes(Theme.fontHeadlineSm, 520, 0)
                            font.weight: Font.Medium
                        }

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "expand"
                            size: 22
                            color: Theme.subtext
                            visible: Lock.canSwitchUser
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
                        onTapped: Lock.openSheet("users")
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
                width: parent.width
                height: 6
            }

            // an account sddm does not list is named by hand, above the password
            Rectangle {
                width: parent.width
                height: 56
                radius: height / 2
                color: Theme.cardHigh
                border.width: nameInput.activeFocus ? 2 : 0
                border.color: Theme.accent
                visible: Lock.manual

                Glyph {
                    id: nameLead

                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    name: "person"
                    size: 20
                    color: nameInput.activeFocus ? Theme.accent : Theme.subtext
                }

                Text {
                    anchors.left: nameLead.right
                    anchors.leftMargin: 14
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
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Theme.alpha(Theme.accent, 0.4)
                    selectedTextColor: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.variableAxes: Theme.axes(Theme.fontBodyLg, 420, 0)
                    readOnly: !Lock.acceptsInput
                    clip: true
                    onTextChanged: {
                        Lock.manualName = nameInput.text;
                        if (nameInput.text.length > 0)
                            Lock.engage();

                    }
                    onAccepted: pw.focusInput()
                    Keys.onTabPressed: pw.focusInput()
                    Keys.onDownPressed: pw.focusInput()
                }

            }

            Field {
                id: pw

                width: parent.width
            }

            // the status line: sddm's verdict, the keyboard's warnings, or nothing
            Item {
                width: parent.width
                height: card.hasStatus ? 22 : 0
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
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lock.statusText
                    elide: Text.ElideRight
                    color: {
                        switch (Lock.statusKind) {
                        case "error":
                            return Theme.error;
                        case "good":
                            return Theme.success;
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
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: capsRow.implicitWidth + 16
                        height: 20
                        radius: 999
                        color: Theme.alpha(Theme.warning, 0.18)
                        visible: keyboard.capsLock

                        Row {
                            id: capsRow

                            anchors.centerIn: parent
                            spacing: 4

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "caps"
                                size: 13
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
                        width: layoutText.implicitWidth + 18
                        height: 20
                        radius: 999
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

                }

            }

            // what the password opens, and the way to open something else
            Item {
                width: parent.width
                height: 40
                visible: Lock.sessions.length > 1

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: sessionRow.implicitWidth + 32
                    height: parent.height
                    radius: height / 2
                    color: Theme.alpha(Theme.text, sessionTap.pressed ? 0.14 : (sessionHover.hovered ? 0.1 : 0.05))

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(120)
                        }

                    }

                    Row {
                        id: sessionRow

                        anchors.centerIn: parent
                        spacing: 8

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "session"
                            size: 17
                            color: Theme.accent
                        }

                        // an eliding Text reports its elided width, so the full one
                        // is read off an unelided twin
                        Text {
                            id: sessionMeasure

                            visible: false
                            text: Lock.sessionName
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(Math.ceil(sessionMeasure.implicitWidth), face.width - 110)
                            text: Lock.sessionName
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                            font.weight: Font.Medium
                        }

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "expand"
                            size: 18
                            color: Theme.subtext
                        }

                    }

                    HoverHandler {
                        id: sessionHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: sessionTap

                        onTapped: Lock.openSheet("sessions")
                    }

                }

            }

        }

        // ── the sheet ──────────────────────────────────────────────────────────
        Item {
            id: sheet

            x: 24 + (1 - card.k) * card.width
            y: 24
            width: card.width - 48
            implicitHeight: head.height + 10 + list.height
            visible: card.k > 0.001

            Item {
                id: head

                width: parent.width
                height: 44

                IconButton {
                    id: back

                    anchors.left: parent.left
                    anchors.leftMargin: -6
                    anchors.verticalCenter: parent.verticalCenter
                    diameter: 44
                    glyph: "back"
                    glyphSize: 22
                    glyphColor: Theme.text
                    onClicked: Lock.closeSheet()
                }

                Text {
                    anchors.left: back.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.shown === "sessions" ? "Choose a session" : "Choose an account"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleMd
                    font.variableAxes: Theme.axes(Theme.fontTitleMd, 520, 0)
                    font.weight: Font.Medium
                }

            }

            ListView {
                id: list

                anchors.top: head.bottom
                anchors.topMargin: 10
                width: parent.width
                // five and a half rows show there is more without a scrollbar
                height: Math.min(card.rows, 5.5) * (card.rowH + list.spacing) - list.spacing
                spacing: 4
                clip: true
                model: card.rows
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: true
                Keys.onUpPressed: (event) => {
                    card.kbd = true;
                    event.accepted = false;
                }
                Keys.onDownPressed: (event) => {
                    card.kbd = true;
                    event.accepted = false;
                }
                Keys.onReturnPressed: card.activate(list.currentIndex)
                Keys.onEnterPressed: card.activate(list.currentIndex)
                Keys.onSpacePressed: card.activate(list.currentIndex)
                Keys.onEscapePressed: Lock.closeSheet()
                Keys.onLeftPressed: Lock.closeSheet()
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Backspace) {
                        Lock.closeSheet();
                        event.accepted = true;
                    }
                }

                delegate: Item {
                    id: row

                    required property int index
                    readonly property bool isUser: card.shown === "users"
                    readonly property bool other: row.isUser && row.index >= Lock.accounts.length
                    readonly property var acct: row.isUser && !row.other ? Lock.accounts[row.index] : null
                    readonly property var sess: !row.isUser ? Lock.sessions[row.index] : null
                    readonly property bool picked: card.selectedRow() === row.index
                    readonly property string title: row.other ? "Other account" : (row.acct ? Lock.nameOf(row.acct) : (row.sess ? row.sess.name : ""))
                    readonly property string subtitle: {
                        if (row.other)
                            return "Sign in with a username";

                        if (row.acct)
                            return row.acct.name !== row.title ? row.acct.name : "";

                        return row.sess ? row.sess.comment : "";
                    }

                    width: ListView.view.width
                    height: card.rowH

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shapeLg
                        color: row.picked ? Theme.cardHigh : "transparent"
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shapeLg
                        color: Theme.text
                        opacity: rowTap.pressed ? Theme.statePressed : (rowHover.hovered ? Theme.stateHover : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.ms(120)
                            }

                        }

                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shapeLg
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                        visible: card.kbd && row.ListView.isCurrentItem
                    }

                    Item {
                        id: lead

                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40

                        Avatar {
                            anchors.fill: parent
                            source: row.acct ? row.acct.icon : ""
                            initials: row.acct ? Lock.initialsOf(Lock.nameOf(row.acct)) : ""
                            visible: !!row.acct
                        }

                        Cookie {
                            anchors.fill: parent
                            shape: row.other ? "cookie12" : "circle"
                            color: row.picked && !row.other ? Theme.accentContainer : Theme.cardHigh
                            visible: !row.acct

                            Glyph {
                                anchors.centerIn: parent
                                name: row.other ? "personAdd" : "session"
                                size: 20
                                color: row.picked && !row.other ? Theme.fgAccentContainer : Theme.subtext
                            }

                        }

                    }

                    Column {
                        anchors.left: lead.right
                        anchors.leftMargin: 14
                        anchors.right: tick.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: row.title
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitleSm
                            font.variableAxes: Theme.axes(Theme.fontTitleSm, row.picked ? 600 : 500, 0)
                            font.weight: row.picked ? Font.DemiBold : Font.Medium
                        }

                        Text {
                            width: parent.width
                            text: row.subtitle
                            elide: Text.ElideRight
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodySm
                            font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                            visible: row.subtitle !== ""
                        }

                    }

                    Glyph {
                        id: tick

                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check"
                        size: 20
                        color: Theme.accent
                        opacity: row.picked ? 1 : 0
                    }

                    HoverHandler {
                        id: rowHover

                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (rowHover.hovered)
                                card.kbd = false;

                        }
                    }

                    TapHandler {
                        id: rowTap

                        onTapped: card.activate(row.index)
                    }

                }

            }

        }

    }

}
