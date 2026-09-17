import QtQuick
import qs

// m3 dialog for choosing a password, with a strength read-out and a hint
Item {
    id: dialog

    property bool shown: false
    property string headline: ""
    property string body: ""
    property string hint: ""
    property bool askHint: true
    property int uid: -1
    property string pw: ""
    property string confirm: ""

    signal submitted(int uid, string password, string hint)

    // 0..4, from length first and character variety second
    readonly property int strength: {
        var p = dialog.pw;
        if (p.length === 0)
            return 0;

        var classes = 0;
        if (/[a-z]/.test(p))
            classes++;

        if (/[A-Z]/.test(p))
            classes++;

        if (/[0-9]/.test(p))
            classes++;

        if (/[^A-Za-z0-9]/.test(p))
            classes++;

        var score = 0;
        if (p.length >= 8)
            score++;

        if (p.length >= 12)
            score++;

        if (classes >= 2)
            score++;

        if (classes >= 3 && p.length >= 10)
            score++;

        return Math.max(1, score);
    }
    readonly property string strengthLabel: ["", "Weak", "Fair", "Good", "Strong"][dialog.strength]
    readonly property color strengthColor: dialog.strength <= 1 ? Theme.error : (dialog.strength === 2 ? Theme.warning : Theme.success)
    readonly property bool tooShort: dialog.pw.length > 0 && dialog.pw.length < 4
    readonly property bool mismatch: dialog.confirm.length > 0 && dialog.confirm !== dialog.pw
    readonly property bool valid: dialog.pw.length >= 4 && dialog.pw === dialog.confirm

    function open(uid, headline, body, hint) {
        dialog.uid = uid;
        dialog.headline = headline;
        dialog.body = body;
        dialog.hint = hint || "";
        dialog.pw = "";
        dialog.confirm = "";
        pwField.clear();
        confirmField.clear();
        hintField.clear();
        hintField.text = dialog.hint;
        pwField.reveal = false;
        confirmField.reveal = false;
        dialog.shown = true;
        Qt.callLater(pwField.focusInput);
    }

    function dismiss() {
        dialog.shown = false;
        // never leave a typed password sitting in a property
        dialog.pw = "";
        dialog.confirm = "";
        pwField.clear();
        confirmField.clear();
    }

    function submit() {
        if (!dialog.shown || !dialog.valid)
            return ;

        var p = dialog.pw;
        var h = hintField.text;
        var u = dialog.uid;
        dialog.dismiss();
        dialog.submitted(u, p, h);
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
        width: Math.min(460, dialog.width - 64)
        height: cardCol.implicitHeight + 56
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
                text: dialog.headline
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: dialog.body
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                lineHeight: 1.3
                wrapMode: Text.WordWrap
                visible: dialog.body !== ""
            }

            Item {
                width: parent.width
                height: 6
            }

            M3TextField {
                id: pwField

                width: parent.width
                password: true
                commitOnBlur: false
                placeholder: "New password"
                error: dialog.tooShort
                onEdited: (v) => {
                    return dialog.pw = v;
                }
                onAccepted: confirmField.focusInput()
            }

            // four segments that fill as the password earns them
            Row {
                width: parent.width
                spacing: 4
                opacity: dialog.pw.length > 0 ? 1 : 0
                visible: opacity > 0.01

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        width: (cardCol.width - 12) / 4
                        height: 4
                        radius: 2
                        color: index < dialog.strength ? dialog.strengthColor : Theme.outline

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            Text {
                width: parent.width
                text: dialog.tooShort ? "Use at least four characters." : dialog.strengthLabel
                color: dialog.tooShort ? Theme.error : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                visible: dialog.pw.length > 0
            }

            M3TextField {
                id: confirmField

                width: parent.width
                password: true
                commitOnBlur: false
                placeholder: "Confirm password"
                error: dialog.mismatch
                onEdited: (v) => {
                    return dialog.confirm = v;
                }
                onAccepted: dialog.submit()
            }

            Text {
                width: parent.width
                text: "Those two do not match."
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                visible: dialog.mismatch
            }

            M3TextField {
                id: hintField

                width: parent.width
                commitOnBlur: false
                placeholder: "Password hint (optional)"
                visible: dialog.askHint
                onAccepted: dialog.submit()
            }

            Text {
                width: parent.width
                text: "A hint is shown to anyone who fails to sign in, so keep it away from the password itself."
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodySm
                lineHeight: 1.25
                wrapMode: Text.WordWrap
                visible: dialog.askHint
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
                    text: "Set password"
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
