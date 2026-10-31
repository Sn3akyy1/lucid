import QtQuick
import qs
import qs.lucidui

// connecting to another computer, as one card that changes as it goes: the
// address (with the servers from before), the wait while the server answers,
// and what it asks on the way, a login or a question (a host never seen
// before). open() starts at the address; ask() shows what a server wants for a
// connection made anywhere in the window, a tab going back to a share say
Item {
    id: dlg

    required property var app
    required property var win

    property bool shown: false
    // "address" | "connecting" | "login" | "question"
    property string mode: "address"
    // the connection the card is about. own: the card made it, so it stays to
    // say how it went; a login for a tab's own connection goes once answered
    property int cid: -1
    property bool own: false
    property string uri: ""
    property string problem: ""
    property var ev: ({})
    property bool anonymous: false
    property bool remember: false
    property bool reveal: false
    readonly property string host: dlg.app.hostOf(dlg.uri)
    // the lines of what the server said: its first is a heading
    readonly property var lines: (dlg.ev.message || "").split("\n").map(function(l) {
        return l.trim();
    }).filter(function(l) {
        return l !== "";
    })
    // a question's words under its heading, its paragraphs kept apart
    readonly property string body: {
        var all = (dlg.ev.message || "").split("\n").map(function(l) {
            return l.trim();
        });
        while (all.length > 0 && all[0] === "")
            all.shift();
        return all.slice(1).join("\n").replace(/\n{3,}/g, "\n\n").trim();
    }
    readonly property var choices: dlg.ev.choices || []
    // what the address can start with here: gvfs reaches only what it has backends for
    readonly property var kinds: ["smb", "sftp", "ftp", "dav", "nfs"].filter(function(k) {
        return dlg.app.schemes.indexOf(k) !== -1;
    })
    readonly property var recent: dlg.app.prefs.servers.slice(0, 5)

    function openAddress(text) {
        dlg.mode = "address";
        dlg.own = true;
        dlg.cid = -1;
        dlg.problem = "";
        field.text = text || "";
        dlg.shown = true;
        Qt.callLater(function() {
            field.input.forceActiveFocus();
            field.input.selectAll();
        });
    }

    // how people write an address, as gvfs wants it: windows' \\server\share,
    // and a bare name, which is a windows share (what most nas drives speak)
    function address(t) {
        t = (t || "").trim();
        if (/^\\\\[^\\]/.test(t))
            t = "smb://" + t.slice(2).replace(/\\/g, "/");

        if (t !== "" && !/^[a-z][a-z0-9+.-]*:\/\//i.test(t))
            t = "smb://" + t.replace(/^\/+/, "");

        return t;
    }

    function go(text) {
        var u = dlg.address(text);
        if (u === "") {
            dlg.problem = "Type the address of a server";
            return ;
        }
        dlg.uri = u;
        dlg.problem = "";
        dlg.mode = "connecting";
        dlg.own = true;
        Qt.callLater(function() {
            card.forceActiveFocus();
        });
        var id = dlg.win.reach(u, {
            "remember": true,
            "done": function(r) {
                dlg.result(id, r);
            }
        });
        dlg.cid = id;
    }

    // a connection came back: the card's own goes, or says what went wrong
    function result(id, r) {
        if (id !== dlg.cid || !dlg.shown)
            return ;

        if (r.ok || r.cancelled || !dlg.own) {
            dlg.close();
            return ;
        }
        dlg.mode = "address";
        dlg.problem = r.error || "Could not connect";
        field.text = dlg.uri;
        Qt.callLater(function() {
            field.input.forceActiveFocus();
        });
    }

    function ask(e) {
        if (!dlg.shown || dlg.cid !== e.connect)
            dlg.own = false;

        dlg.cid = e.connect;
        dlg.uri = e.uri || dlg.uri;
        dlg.ev = e;
        dlg.mode = e.kind === "question" ? "question" : "login";
        dlg.anonymous = false;
        dlg.reveal = false;
        dlg.remember = false;
        user.text = e.user || "";
        domain.text = e.domain || "";
        password.text = "";
        dlg.shown = true;
        Qt.callLater(function() {
            if (dlg.mode !== "login")
                card.forceActiveFocus();
            else if (user.visible && user.text === "")
                user.input.forceActiveFocus();
            else if (password.visible)
                password.input.forceActiveFocus();
            else
                card.forceActiveFocus();
        });
    }

    // the server stopped asking (it gave up waiting)
    function askGone(id) {
        if (id !== dlg.cid || (dlg.mode !== "login" && dlg.mode !== "question"))
            return ;

        if (dlg.own)
            dlg.mode = "connecting";
        else
            dlg.close();
    }

    function answer(choice) {
        var a = {
            "connect": dlg.cid,
            "kind": dlg.mode === "question" ? "question" : "password"
        };
        if (dlg.mode === "question") {
            a.choice = choice;
        } else {
            a.anonymous = dlg.anonymous;
            a.user = user.text;
            a.domain = domain.text;
            a.password = password.text;
            a.save = dlg.remember ? "forever" : "never";
        }
        dlg.app.call("answer", a);
        password.text = "";
        if (dlg.own) {
            dlg.mode = "connecting";
            Qt.callLater(function() {
                card.forceActiveFocus();
            });
        } else {
            dlg.close();
        }
    }

    function cancel() {
        if (dlg.mode === "connecting")
            dlg.app.call("cancelConnect", {
            "connect": dlg.cid
        });
        else if (dlg.mode === "login" || dlg.mode === "question")
            dlg.app.call("answer", {
            "connect": dlg.cid,
            "cancel": true
        });
        dlg.close();
    }

    function accept() {
        if (!dlg.shown)
            return ;

        if (dlg.mode === "address")
            dlg.go(field.text);
        else if (dlg.mode === "login")
            dlg.answer(0);
        else if (dlg.mode === "question")
            dlg.answer(0);
    }

    function close() {
        dlg.shown = false;
        password.text = "";
        dlg.cid = -1;
    }

    anchors.fill: parent
    visible: dlg.shown || scrim.opacity > 0

    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Theme.scrim
        opacity: dlg.shown ? 0.55 : 0

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: dlg.cancel()
            onWheel: (wheel) => {
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.dp(48), Theme.dp(440))
        height: body.implicitHeight + Theme.dp(48)
        radius: Theme.shapeXl
        color: Theme.bgHigh
        opacity: dlg.shown ? 1 : 0
        scale: dlg.shown ? 1 : 0.94
        focus: dlg.shown
        clip: true
        Keys.onEscapePressed: dlg.cancel()
        // a field's enter comes on up here after the field took it (TextInput
        // passes it on): only the card's own is the card's to take
        Keys.onReturnPressed: {
            if (card.activeFocus)
                dlg.accept();

        }
        Keys.onEnterPressed: {
            if (card.activeFocus)
                dlg.accept();

        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: body

            x: Theme.dp(24)
            y: Theme.dp(24)
            width: card.width - Theme.dp(48)
            spacing: Theme.dp(16)

            // the glyph of what it is about, over the heading
            Rectangle {
                width: Theme.dp(48)
                height: Theme.dp(48)
                radius: width / 2
                color: Theme.accentContainer

                PlaceGlyph {
                    anchors.centerIn: parent
                    size: Theme.dp(24)
                    slot: dlg.mode === "login" ? "lock" : dlg.mode === "question" ? "help" : "network"
                    fallback: slot
                    color: Theme.fgAccentContainer
                }

            }

            LText {
                width: parent.width
                role: "headlineSmall"
                text: dlg.mode === "address" ? "Connect to server" : dlg.mode === "connecting" ? "Connecting to " + dlg.host : dlg.mode === "login" ? "Sign in to " + dlg.host : (dlg.lines[0] || "A question from " + dlg.host)
                color: Theme.text
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            LText {
                width: parent.width
                visible: text !== ""
                role: "bodyMedium"
                text: {
                    if (dlg.mode === "address")
                        return "Open a shared folder on another computer, a NAS or a server.";

                    if (dlg.mode === "connecting")
                        return dlg.uri;

                    if (dlg.mode === "login")
                        return dlg.ev.retry ? "That didn't work. Check the name and password, and try again." : dlg.lines.slice(1).join(" ").replace(/:$/, "");

                    return dlg.body;
                }
                color: dlg.mode === "login" && dlg.ev.retry ? Theme.error : Theme.subtext
                wrapMode: Text.Wrap
            }

            // ---- the address

            TextField {
                id: field

                width: parent.width
                visible: dlg.mode === "address"
                variant: "filled"
                label: "Server address"
                placeholder: dlg.kinds.indexOf("smb") !== -1 ? "smb://nas.local/share" : "sftp://user@server"
                error: dlg.problem !== ""
                supporting: dlg.problem !== "" ? dlg.problem : "Like " + dlg.kinds.slice(0, 3).map(function(k) {
                    return k === "smb" ? "smb://server/share" : k === "sftp" ? "sftp://user@server" : k + "://server";
                }).join(", ")
                onAccepted: dlg.accept()
                onEscaped: dlg.cancel()
                onTextEdited: dlg.problem = ""
            }

            // windows shares, which most nas drives speak, need a backend gvfs ships apart
            LText {
                width: parent.width
                visible: dlg.mode === "address" && dlg.problem === "" && dlg.app.schemes.length > 0 && dlg.kinds.indexOf("smb") === -1
                role: "bodySmall"
                text: "Windows shares and most NAS drives (smb://) need the gvfs-smb package."
                color: Theme.subtext
                wrapMode: Text.Wrap
            }

            Column {
                width: parent.width
                visible: dlg.mode === "address" && dlg.recent.length > 0
                spacing: Theme.dp(2)

                LText {
                    width: parent.width
                    bottomPadding: Theme.dp(6)
                    role: "labelLarge"
                    text: "Recent"
                    color: Theme.subtext
                }

                Repeater {
                    model: dlg.mode === "address" ? dlg.recent : []

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool first: index === 0
                        readonly property bool last: index === dlg.recent.length - 1

                        width: parent.width
                        height: Theme.dp(56)
                        topLeftRadius: row.first ? Theme.dp(16) : Theme.dp(4)
                        topRightRadius: row.first ? Theme.dp(16) : Theme.dp(4)
                        bottomLeftRadius: row.last ? Theme.dp(16) : Theme.dp(4)
                        bottomRightRadius: row.last ? Theme.dp(16) : Theme.dp(4)
                        color: Theme.surfaceHigh

                        StateLayer {
                            anchors.fill: parent
                            anchors.rightMargin: Theme.dp(48)
                            tint: Theme.text
                            onClicked: dlg.go(row.modelData.uri)
                        }

                        PlaceGlyph {
                            id: rowGlyph

                            x: Theme.dp(16)
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.dp(22)
                            slot: "network"
                            color: Theme.subtext
                        }

                        Column {
                            anchors.left: rowGlyph.right
                            anchors.leftMargin: Theme.dp(16)
                            anchors.right: forget.left
                            anchors.rightMargin: Theme.dp(4)
                            anchors.verticalCenter: parent.verticalCenter

                            LText {
                                width: parent.width
                                role: "bodyLarge"
                                text: row.modelData.label
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            LText {
                                width: parent.width
                                role: "bodySmall"
                                text: row.modelData.uri
                                color: Theme.subtext
                                elide: Text.ElideMiddle
                            }

                        }

                        IconButton {
                            id: forget

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(8)
                            anchors.verticalCenter: parent.verticalCenter
                            size: "xs"
                            icon: "close"
                            onClicked: dlg.app.forgetServer(row.modelData.uri)

                            Tip {
                                text: "Forget"
                            }

                        }

                    }

                }

            }

            // ---- the wait

            Item {
                width: parent.width
                height: Theme.dp(56)
                visible: dlg.mode === "connecting"

                LoadingIndicator {
                    anchors.centerIn: parent
                    running: dlg.shown && dlg.mode === "connecting"
                }

            }

            // ---- a login

            ButtonGroup {
                width: parent.width
                visible: dlg.mode === "login" && dlg.ev.anonymous === true
                options: [{
                    "key": "user",
                    "label": "Registered user",
                    "icon": "person"
                }, {
                    "key": "anon",
                    "label": "Anonymous",
                    "icon": "public"
                }]
                current: dlg.anonymous ? "anon" : "user"
                onPicked: (key) => {
                    dlg.anonymous = key === "anon";
                }
            }

            TextField {
                id: user

                width: parent.width
                visible: dlg.mode === "login" && dlg.ev.needUser === true && !dlg.anonymous
                variant: "filled"
                label: "User name"
                icon: "person"
                onAccepted: password.visible ? password.input.forceActiveFocus() : dlg.accept()
                onEscaped: dlg.cancel()
            }

            TextField {
                id: domain

                width: parent.width
                visible: dlg.mode === "login" && dlg.ev.needDomain === true && !dlg.anonymous
                variant: "filled"
                label: "Domain"
                icon: "lan"
                onAccepted: dlg.accept()
                onEscaped: dlg.cancel()
            }

            TextField {
                id: password

                width: parent.width
                visible: dlg.mode === "login" && dlg.ev.needPassword === true && !dlg.anonymous
                variant: "filled"
                label: "Password"
                icon: "key"
                password: !dlg.reveal
                onAccepted: dlg.accept()
                onEscaped: dlg.cancel()
                trailing: IconButton {
                    size: "xs"
                    icon: dlg.reveal ? "visibility_off" : "visibility"
                    onClicked: dlg.reveal = !dlg.reveal

                    Tip {
                        text: dlg.reveal ? "Hide the password" : "Show the password"
                    }

                }
            }

            // a check of its own, as the open with dialog's: lucid's switch plays the shell's sounds
            Item {
                width: parent.width
                height: Theme.dp(40)
                visible: dlg.mode === "login" && dlg.ev.canSave === true && !dlg.anonymous

                Rectangle {
                    id: box

                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.dp(4)
                    width: Theme.dp(20)
                    height: Theme.dp(20)
                    radius: Theme.dp(6)
                    color: dlg.remember ? Theme.accent : "transparent"
                    border.width: dlg.remember ? 0 : Theme.dp(2)
                    border.color: Theme.subtext

                    Icon {
                        anchors.centerIn: parent
                        visible: dlg.remember
                        name: "check"
                        size: Theme.dp(16)
                        color: Theme.fgAccent
                    }

                }

                LText {
                    anchors.left: box.right
                    anchors.leftMargin: Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyMedium"
                    text: "Remember the password"
                    color: Theme.text
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: dlg.remember = !dlg.remember
                }

            }

            // ---- the buttons: a question's choices, first one last, as gtk lays them

            Row {
                anchors.right: parent.right
                spacing: Theme.dp(8)

                Button {
                    visible: dlg.mode !== "question"
                    variant: "text"
                    text: "Cancel"
                    onClicked: dlg.cancel()
                }

                Button {
                    visible: dlg.mode === "address" || dlg.mode === "login"
                    variant: "filled"
                    text: dlg.mode === "login" ? "Sign in" : "Connect"
                    disabled: dlg.mode === "address" && field.text.trim() === ""
                    onClicked: dlg.accept()
                }

                Repeater {
                    model: dlg.mode === "question" ? dlg.choices.length : 0

                    delegate: Button {
                        required property int index
                        readonly property int choice: dlg.choices.length - 1 - index

                        variant: choice === 0 ? "filled" : "text"
                        text: dlg.choices[choice] || ""
                        onClicked: dlg.answer(choice)
                    }

                }

            }

        }

        Behavior on height {
            enabled: dlg.shown

            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

}
