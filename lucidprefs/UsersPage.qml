import QtQuick
import qs

Column {
    id: page

    // -1 until something is picked, so the page opens on your own account and
    // falls back to it again whenever the one you were editing goes away
    property int selectedUid: -1
    readonly property var sel: Users.userFor(page.selectedUid) || Users.me
    readonly property bool hasSel: page.sel !== null && page.sel !== undefined
    readonly property bool isMe: page.sel ? page.sel.isMe === true : false
    readonly property bool canEdit: page.hasSel && (page.isMe || Users.canAdmin)
    readonly property bool lastAdmin: page.sel ? Users.isOnlyAdmin(page.sel.uid) : false

    function patch(o, label) {
        if (page.sel)
            Users.set(page.sel.uid, o, label);

    }

    // a removed account must not keep its slot: a later one could be given the
    // same uid and the page would jump to it
    Connections {
        function onRefreshed() {
            if (page.selectedUid >= 0 && Users.userFor(page.selectedUid) === null)
                page.selectedUid = -1;

        }

        target: Users
    }

    spacing: 26

    // a refused or cancelled polkit prompt is the usual way a change here
    // fails, and it fails silently unless something says so
    Rectangle {
        width: parent.width
        height: Math.max(52, noteText.implicitHeight + 28)
        radius: Theme.shapeLg
        color: Users.busy || Users.lastErrorKind === "cancelled" ? Theme.bgTile : Theme.errorContainer
        visible: Users.busy || Users.lastError !== ""

        Text {
            id: noteText

            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: dismissNote.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            // a change that needs an administrator waits on the polkit agent,
            // so say what the wait is for rather than just spinning
            text: Users.busy ? "Applying — confirm the prompt if one appears." : Users.lastError
            color: Users.busy || Users.lastErrorKind === "cancelled" ? Theme.subtext : Theme.fgErrorContainer
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }

        M3IconButton {
            id: dismissNote

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            size: 32
            iconSize: 17
            enabled: !Users.busy
            opacity: Users.busy ? 0 : 1
            iconPath: "M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41Z"
            onClicked: Users.lastError = ""
        }

    }

    // the account this page is about: its picture, its names, and what it is
    Rectangle {
        width: parent.width
        height: Math.max(118, heroCol.implicitHeight + 40)
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.bgTile)

        UserAvatar {
            id: heroAvatar

            x: 26
            anchors.verticalCenter: parent.verticalCenter
            size: 78
            user: page.sel
            editable: page.canEdit
            showAdmin: true
            onClicked: Users.avatarRequested(page.sel.uid)
        }

        Column {
            id: heroCol

            anchors.left: heroAvatar.right
            anchors.leftMargin: 22
            anchors.right: heroActions.left
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                width: parent.width
                text: Users.displayName(page.sel)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineSm
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: page.sel ? page.sel.name + "  ·  " + page.sel.home : ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                elide: Text.ElideRight
            }

            // small status pills, only the ones that are actually true
            Row {
                spacing: 6
                topPadding: 3

                Repeater {
                    model: {
                        var u = page.sel;
                        if (!u)
                            return [];

                        var out = [];
                        if (u.accountType === Users.admin)
                            out.push({
                                "label": "Administrator",
                                "tone": "accent"
                            });

                        if (u.isMe)
                            out.push({
                                "label": "This is you",
                                "tone": "plain"
                            });
                        else if (u.online)
                            out.push({
                                "label": "Signed in",
                                "tone": "good"
                            });

                        if (u.locked)
                            out.push({
                                "label": "Locked",
                                "tone": "bad"
                            });

                        if (u.autoLogin)
                            out.push({
                                "label": "Signs in automatically",
                                "tone": "plain"
                            });

                        if (u.passwordMode === Users.pwSetAtLogin)
                            out.push({
                                "label": "Must set a password",
                                "tone": "warn"
                            });

                        return out;
                    }

                    Rectangle {
                        required property var modelData

                        readonly property color tone: {
                            if (modelData.tone === "accent")
                                return Theme.accentContainer;

                            if (modelData.tone === "good")
                                return Theme.success;

                            if (modelData.tone === "bad")
                                return Theme.errorContainer;

                            if (modelData.tone === "warn")
                                return Theme.warning;

                            return Theme.bgSunken;
                        }
                        readonly property color ink: {
                            if (modelData.tone === "accent")
                                return Theme.fgAccentContainer;

                            if (modelData.tone === "good")
                                return Theme.fgSuccess;

                            if (modelData.tone === "bad")
                                return Theme.fgErrorContainer;

                            if (modelData.tone === "warn")
                                return Theme.fgWarning;

                            return Theme.subtext;
                        }

                        width: pill.implicitWidth + 20
                        height: 24
                        radius: Theme.rad(12)
                        color: tone

                        Text {
                            id: pill

                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: parent.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelSm
                            font.weight: Font.Medium
                        }

                    }

                }

            }

        }

        Column {
            id: heroActions

            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            M3Button {
                text: "Change picture…"
                variant: "tonal"
                enabled: page.canEdit
                onClicked: Users.avatarRequested(page.sel.uid)
            }

            M3Button {
                text: "Remove account…"
                variant: "text"
                destructive: true
                visible: !page.isMe && Users.canAdmin
                onClicked: Users.deleteRequested(page.sel.uid)
            }

        }

    }

    // every account on the machine; picking one points the page at it
    SettingCard {
        title: "ACCOUNTS"
        subtitle: Users.users.length === 1 ? "Only your account exists on this machine." : "Pick an account to see and change its settings."

        SettingRow {
            showDivider: false
            stacked: true

            Flow {
                width: parent.width
                spacing: 10

                Repeater {
                    model: Users.users

                    Rectangle {
                        id: tile

                        required property var modelData
                        readonly property bool active: page.hasSel && page.sel.uid === tile.modelData.uid

                        width: 96
                        height: 112
                        radius: Theme.shapeLg
                        color: tile.active ? Theme.secondaryContainer : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.text
                            opacity: tileArea.pressed ? Theme.statePressed : (tileArea.containsMouse && !tile.active ? Theme.stateHover : 0)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            UserAvatar {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: 52
                                user: tile.modelData
                                showAdmin: true
                            }

                            Text {
                                width: 84
                                text: Users.displayName(tile.modelData)
                                color: tile.active ? Theme.fgSecondaryContainer : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabelMd
                                font.weight: tile.active ? Font.DemiBold : Font.Normal
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                        }

                        MouseArea {
                            id: tileArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.selectedUid = tile.modelData.uid
                        }

                    }

                }

                // the same tile shape, so the row reads as one set of choices
                Rectangle {
                    width: 96
                    height: 112
                    radius: Theme.shapeLg
                    color: "transparent"
                    visible: Users.canAdmin

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.text
                        opacity: addArea.pressed ? Theme.statePressed : (addArea.containsMouse ? Theme.stateHover : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 52
                            height: 52
                            radius: Theme.rad(26)
                            color: "transparent"
                            border.width: 1.6
                            border.color: Theme.outlineStrong

                            Rectangle {
                                anchors.centerIn: parent
                                width: 18
                                height: 2
                                radius: 1
                                color: Theme.subtext
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 2
                                height: 18
                                radius: 1
                                color: Theme.subtext
                            }

                        }

                        Text {
                            width: 84
                            text: "Add"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelMd
                            horizontalAlignment: Text.AlignHCenter
                        }

                    }

                    MouseArea {
                        id: addArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Users.newUserRequested()
                    }

                }

            }

        }

    }

    SettingCard {
        title: "PROFILE"

        SettingRow {
            title: "Full name"
            description: "Shown on the lock screen and wherever this machine greets you by name."
            enabled: page.canEdit
            disabledReason: "Only an administrator can change another account's name."

            M3TextField {
                width: 260
                enabled: page.canEdit
                text: page.sel ? page.sel.realName : ""
                placeholder: page.sel ? page.sel.name : ""
                onAccepted: (v) => {
                    return page.patch({
                        "realName": v.trim()
                    }, "realName");
                }
            }

        }

        SettingRow {
            title: "Username"
            description: "The name this account signs in with. The home folder keeps its old name, so anything pointing at it still works."
            warning: page.isMe ? "Renaming the account you are signed in to takes effect at your next sign-in." : ""
            enabled: Users.canAdmin && page.hasSel && !page.sel.online
            disabledReason: page.sel && page.sel.online ? "This account is signed in; sign it out before renaming it." : "Only an administrator can rename an account."

            M3TextField {
                width: 260
                enabled: Users.canAdmin && page.hasSel && !page.sel.online
                commitOnBlur: false
                text: page.sel ? page.sel.name : ""
                onAccepted: (v) => {
                    var want = v.trim();
                    if (want !== "" && page.sel && want !== page.sel.name)
                        page.patch({
                            "userName": want
                        }, "userName");

                }
            }

        }

        SettingRow {
            title: "Account type"
            description: "Administrators can install software, change settings for everyone and manage other accounts."
            enabled: Users.canAdmin && !page.lastAdmin
            disabledReason: page.lastAdmin ? "This is the only administrator on the machine. Make another account an administrator first." : "Only an administrator can change this."

            M3Segmented {
                width: 260
                enabled: Users.canAdmin && !page.lastAdmin
                current: page.sel ? page.sel.accountType : Users.standard
                options: [{
                    "key": Users.standard,
                    "label": "Standard"
                }, {
                    "key": Users.admin,
                    "label": "Administrator"
                }]
                onChosen: (key) => {
                    return page.patch({
                        "accountType": key
                    }, "accountType");
                }
            }

        }

        SettingRow {
            title: "Login shell"
            description: "What runs when this account opens a terminal or signs in to a console."
            enabled: page.canEdit
            stacked: true

            Column {
                width: parent.width
                spacing: 10

                M3Chips {
                    width: parent.width
                    enabled: page.canEdit
                    current: page.sel ? page.sel.shell : ""
                    options: Users.shells.map((s) => {
                        return {
                            "key": s,
                            "label": Users.shellName(s)
                        };
                    })
                    onChosen: (key) => {
                        return page.patch({
                            "shell": key
                        }, "shell");
                    }
                }

                // sh and rbash are the same binary as bash under another name,
                // so the bare name is not enough to tell them apart
                Text {
                    width: parent.width
                    text: page.sel && page.sel.shell !== "" ? page.sel.shell : ""
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodySm
                    elide: Text.ElideRight
                    visible: text !== ""
                }

            }

        }

        SettingRow {
            title: "Email"
            description: "Kept with the account. Some applications read it to fill in your details."
            enabled: page.canEdit

            M3TextField {
                width: 260
                enabled: page.canEdit
                text: page.sel ? page.sel.email : ""
                placeholder: "name@example.com"
                onAccepted: (v) => {
                    return page.patch({
                        "email": v.trim()
                    }, "email");
                }
            }

        }

        SettingRow {
            title: "Location"
            description: "Where this account is, for anything that asks."
            showDivider: false
            enabled: page.canEdit

            M3TextField {
                width: 260
                enabled: page.canEdit
                text: page.sel ? page.sel.location : ""
                placeholder: "Optional"
                onAccepted: (v) => {
                    return page.patch({
                        "location": v.trim()
                    }, "location");
                }
            }

        }

    }

    SettingCard {
        title: "PASSWORD"

        SettingRow {
            title: "Password"
            description: page.sel && page.sel.passwordMode === Users.pwSetAtLogin ? "This account has no password yet and will be asked to choose one at its next sign-in." : "Changing a password asks an administrator to confirm before it is written."
            enabled: page.canEdit

            M3Button {
                text: "Change…"
                variant: "tonal"
                enabled: page.canEdit
                onClicked: Users.passwordRequested(page.sel.uid, page.isMe ? "Change your password" : "Set a password for " + Users.displayName(page.sel), page.isMe ? "You will use this the next time you sign in or unlock the screen." : "Tell them what you chose, or have them set their own at first sign-in.", page.sel.passwordHint)
            }

        }

        SettingRow {
            title: "Password hint"
            description: "Shown after a failed sign-in. Anyone at the machine can read it, so keep it away from the password itself."
            enabled: page.canEdit

            M3TextField {
                width: 260
                enabled: page.canEdit
                text: page.sel ? page.sel.passwordHint : ""
                placeholder: "Optional"
                onAccepted: (v) => {
                    return page.patch({
                        "passwordHint": v.trim()
                    }, "passwordHint");
                }
            }

        }

        SettingRow {
            title: "Ask for a new password at next sign-in"
            description: "Clears the current password and makes this account choose one before it can get in."
            enabled: Users.canAdmin && !page.isMe
            disabledReason: page.isMe ? "You cannot clear your own password this way. Change it above instead." : "Only an administrator can change this."

            M3Switch {
                checked: page.sel ? page.sel.passwordMode === Users.pwSetAtLogin : false
                enabled: Users.canAdmin && !page.isMe
                onToggled: (v) => {
                    return page.patch({
                        "passwordMode": v ? Users.pwSetAtLogin : Users.pwRegular
                    }, "passwordMode");
                }
            }

        }

        SettingRow {
            title: "Lock the account"
            description: "Keeps the account and its files but refuses every sign-in until it is unlocked again."
            showDivider: false
            enabled: Users.canAdmin && !page.isMe
            disabledReason: page.isMe ? "You cannot lock the account you are signed in to." : "Only an administrator can change this."

            M3Switch {
                checked: page.sel ? page.sel.locked : false
                enabled: Users.canAdmin && !page.isMe
                onToggled: (v) => {
                    return page.patch({
                        "locked": v
                    }, "locked");
                }
            }

        }

    }

    SettingCard {
        title: "SIGNING IN"

        SettingRow {
            title: "Sign in automatically"
            description: "Goes straight to the desktop at start-up without asking for a password. Only one account on a machine can do this."
            warning: page.sel && page.sel.autoLogin ? "Anyone who can switch this machine on gets into this account." : ""
            showDivider: false
            enabled: Users.canAdmin && page.hasSel && !page.sel.locked
            disabledReason: page.sel && page.sel.locked ? "A locked account cannot sign in at all." : "Only an administrator can change this."

            M3Switch {
                checked: page.sel ? page.sel.autoLogin : false
                enabled: Users.canAdmin && page.hasSel && !page.sel.locked
                onToggled: (v) => {
                    return page.patch({
                        "autoLogin": v
                    }, "autoLogin");
                }
            }

        }

    }

    SettingCard {
        title: "GROUPS"
        subtitle: "What this account is allowed to reach beyond its own files — sound devices, printers, virtual machines and the like. Administrator rights are set by the account type above, not here."

        SettingRow {
            showDivider: false
            stacked: true
            enabled: Users.canAdmin
            disabledReason: "Only an administrator can change group membership."

            Column {
                width: parent.width
                spacing: 12

                M3Chips {
                    id: groupChips

                    width: parent.width
                    enabled: Users.canAdmin
                    // membership is a set, so every chip the account is in reads
                    // as picked and a click toggles that one
                    multi: true
                    selectedKeys: page.sel ? page.sel.groups : []
                    interactive: Users.canAdmin
                    options: Users.groupNames.map((g) => {
                        return {
                            "key": g,
                            "label": g
                        };
                    })
                    onChosen: (key) => {
                        if (!page.sel)
                            return ;

                        var have = page.sel.groups.slice();
                        var i = have.indexOf(key);
                        if (i >= 0)
                            have.splice(i, 1);
                        else
                            have.push(key);
                        page.patch({
                            "groups": have
                        }, "groups");
                    }
                }

                Text {
                    width: parent.width
                    text: page.sel && page.sel.groups.length > 0 ? "In: " + page.sel.groups.join(", ") : ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodySm
                    lineHeight: 1.3
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }

            }

        }

    }

    SettingCard {
        title: "HISTORY"

        SettingRow {
            title: "Last signed in"
            description: page.sel && page.sel.lastLogin > 0 ? Qt.formatDateTime(new Date(page.sel.lastLogin * 1000), "dddd d MMMM yyyy, HH:mm") : "This account has never signed in."
        }

        SettingRow {
            title: "Sign-ins recorded"
            description: page.sel ? page.sel.logins + (page.sel.logins === 1 ? " time" : " times") : ""
            showDivider: false
        }

    }

}
