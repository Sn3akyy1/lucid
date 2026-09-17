import QtQuick
import qs

// m3 dialog for adding an account: a name, what it may do, and how it first signs in
Item {
    id: dialog

    property bool shown: false
    property string realName: ""
    property string userName: ""
    // true while the username still follows the full name being typed
    property bool nameLinked: true
    property int accountType: Users.standard
    property string mode: "later" // "later" | "now"
    property string pw: ""
    property string confirm: ""

    signal submitted(var spec)

    readonly property bool nameOk: /^[a-z_][a-z0-9_-]{0,31}$/.test(dialog.userName)
    readonly property bool nameTaken: Users.users.some((u) => {
        return u.name === dialog.userName;
    })
    readonly property bool pwOk: dialog.mode === "later" || (dialog.pw.length >= 4 && dialog.pw === dialog.confirm)
    readonly property bool valid: dialog.userName !== "" && dialog.nameOk && !dialog.nameTaken && dialog.pwOk
    readonly property string nameProblem: {
        if (dialog.userName === "")
            return "";

        if (dialog.nameTaken)
            return "There is already an account with that username.";

        if (!dialog.nameOk)
            return "Start with a letter, then lowercase letters, digits, - and _ only.";

        return "";
    }

    // "Ada Lovelace" -> "ada", the way every other account tool guesses it
    function suggest(full) {
        var s = full.toLowerCase().trim().replace(/[^a-z0-9 _-]/g, "");
        var first = s.split(/\s+/)[0] || "";
        return first.substring(0, 32);
    }

    function open() {
        dialog.realName = "";
        dialog.userName = "";
        dialog.nameLinked = true;
        dialog.accountType = Users.standard;
        dialog.mode = "later";
        dialog.pw = "";
        dialog.confirm = "";
        fullField.clear();
        userField.clear();
        pwField.clear();
        confirmField.clear();
        dialog.shown = true;
        Qt.callLater(fullField.focusInput);
    }

    function dismiss() {
        dialog.shown = false;
        dialog.pw = "";
        dialog.confirm = "";
        pwField.clear();
        confirmField.clear();
    }

    function submit() {
        if (!dialog.shown || !dialog.valid)
            return ;

        var spec = {
            "name": dialog.userName,
            "realName": dialog.realName,
            "accountType": dialog.accountType
        };
        if (dialog.mode === "now")
            spec.password = dialog.pw;
        else
            spec.passwordMode = Users.pwSetAtLogin;
        dialog.dismiss();
        dialog.submitted(spec);
    }

    anchors.fill: parent
    visible: dialog.opacity > 0.01
    opacity: dialog.shown ? 1 : 0

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: dialog.dismiss()
        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(480, dialog.width - 64)
        height: Math.min(cardCol.implicitHeight + 56, dialog.height - 48)
        radius: Theme.shapeXl
        color: Theme.bgHigh
        scale: dialog.shown ? 1 : 0.88
        opacity: dialog.shown ? 1 : 0

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: cardCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            spacing: 10

            Text {
                width: parent.width
                text: "Add an account"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                text: "A home folder is created the first time they sign in."
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                wrapMode: Text.WordWrap
            }

            Item {
                width: parent.width
                height: 6
            }

            M3TextField {
                id: fullField

                width: parent.width
                commitOnBlur: false
                placeholder: "Full name"
                onEdited: (v) => {
                    dialog.realName = v;
                    if (dialog.nameLinked) {
                        dialog.userName = dialog.suggest(v);
                        userField.text = dialog.userName;
                    }
                }
                onAccepted: userField.focusInput()
            }

            M3TextField {
                id: userField

                width: parent.width
                commitOnBlur: false
                placeholder: "Username"
                error: dialog.nameProblem !== ""
                onEdited: (v) => {
                    // typing here by hand cuts the tie to the full name
                    dialog.nameLinked = false;
                    dialog.userName = v;
                }
            }

            Text {
                width: parent.width
                text: dialog.nameProblem !== "" ? dialog.nameProblem : (dialog.userName !== "" ? "Their home folder will be /home/" + dialog.userName : "")
                color: dialog.nameProblem !== "" ? Theme.error : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                wrapMode: Text.WordWrap
                visible: text !== ""
            }

            Text {
                width: parent.width
                text: "Account type"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                topPadding: 6
            }

            M3Segmented {
                width: parent.width
                current: dialog.accountType
                options: [{
                    "key": Users.standard,
                    "label": "Standard"
                }, {
                    "key": Users.admin,
                    "label": "Administrator"
                }]
                onChosen: (key) => {
                    return dialog.accountType = key;
                }
            }

            Text {
                width: parent.width
                text: dialog.accountType === Users.admin ? "Administrators can install software and change settings for everyone on this machine." : "Standard accounts can change only their own settings and files."
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: "Password"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                topPadding: 6
            }

            M3Segmented {
                width: parent.width
                current: dialog.mode
                options: [{
                    "key": "later",
                    "label": "Set at first sign-in"
                }, {
                    "key": "now",
                    "label": "Set it now"
                }]
                onChosen: (key) => {
                    return dialog.mode = key;
                }
            }

            M3TextField {
                id: pwField

                width: parent.width
                password: true
                commitOnBlur: false
                placeholder: "Password"
                visible: dialog.mode === "now"
                onEdited: (v) => {
                    return dialog.pw = v;
                }
                onAccepted: confirmField.focusInput()
            }

            M3TextField {
                id: confirmField

                width: parent.width
                password: true
                commitOnBlur: false
                placeholder: "Confirm password"
                error: dialog.confirm.length > 0 && dialog.confirm !== dialog.pw
                visible: dialog.mode === "now"
                onEdited: (v) => {
                    return dialog.confirm = v;
                }
                onAccepted: dialog.submit()
            }

            Item {
                width: parent.width
                height: 8
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                M3Button {
                    text: "Cancel"
                    variant: "text"
                    onClicked: dialog.dismiss()
                }

                M3Button {
                    text: "Add account"
                    variant: "filled"
                    enabled: dialog.valid
                    onClicked: dialog.submit()
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

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

}
