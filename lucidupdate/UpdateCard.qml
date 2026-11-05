import "../lucidprefs"
import QtQuick
import Quickshell
import qs
import qs.lucidui

// the update start to finish: the warning, the password, the bar with any
// question the installer asks, and the restart once it is in. the graphical
// installer shows it too, from the password on (fresh)
Rectangle {
    id: card

    // the installer's: Close, or start the shell it just put in place
    signal leave(bool start)

    // the installer's too: a line for a Hyprland config Lucid left alone
    property string note: ""
    // the installer on another desktop: its name, and the last page logs out instead of starting Lucid
    property string elsewhere: ""

    property bool shown: false
    // the last real stage, so the card does not empty itself while it fades out
    property string view: "confirm"
    property bool stopArmed: false
    readonly property bool beta: Updates.flowChannel === "beta"
    readonly property bool fresh: Updates.flowChannel === "local"
    readonly property var ask: Updates.ask
    readonly property bool asking: card.ask !== null && Updates.askSent !== card.ask.n
    readonly property bool authAsk: card.view === "auth" && card.asking && card.ask.kind === "password"
    readonly property bool runAsk: card.view === "running" && card.asking
    readonly property bool wantsKeys: card.view === "auth" || (card.runAsk && card.ask.kind !== "yesno")
    readonly property var res: Updates.result || ({
    })
    readonly property bool canRetry: card.view === "failed" && card.res.reason !== "nosudo" && !card.fresh
    readonly property string home: Quickshell.env("HOME")
    readonly property bool logOpen: (card.view === "running" || card.view === "failed") && details.expanded
    readonly property int logFull: Theme.dp(220)

    function tilde(p) {
        return String(p).indexOf(card.home) === 0 ? "~" + String(p).slice(card.home.length) : String(p);
    }

    function mb(n) {
        return (n / 1048576).toFixed(n < 10485760 ? 1 : 0) + " MB";
    }

    // "install these now? [Y/n]" reads better without its brackets
    function question(t) {
        var q = String(t).replace(/\s*[\[(]\s*[Yy]\s*\/\s*[Nn]\s*[\])]\s*[:?]?\s*$/, "").replace(/^\[\w+\]\s*/, "").trim();
        return q.charAt(0).toUpperCase() + q.slice(1);
    }

    function dismiss() {
        if (card.view === "confirm" || card.view === "auth")
            Updates.cancel();
        else if (card.view === "running")
            Updates.hide();
    }

    function focusInput() {
        if (card.view === "auth")
            authField.focusInput();
        else if (card.runAsk && card.ask.kind === "password")
            askField.focusInput();
        else if (card.runAsk && card.ask.kind === "text")
            askText.forceActiveFocus();
    }

    function submitAuth() {
        if (!card.authAsk || authField.text === "")
            return ;

        Updates.answer(authField.text);
    }

    function submitAsk() {
        if (!card.runAsk)
            return ;

        if (card.ask.kind === "password" && askField.text !== "")
            Updates.answer(askField.text);
        else if (card.ask.kind === "text")
            Updates.answer(askText.text);
    }

    width: Theme.dp(480)
    height: body.implicitHeight + Theme.dp(56) + (card.logOpen ? card.logFull + body.spacing : 0)
    radius: Theme.shapeXl
    color: Theme.bg
    scale: card.shown ? 1 : 0.9
    opacity: card.shown ? 1 : 0
    Component.onCompleted: {
        if (Updates.flow !== "")
            card.view = Updates.flow;

    }

    Connections {
        function onFlowChanged() {
            if (Updates.flow !== "")
                card.view = Updates.flow;

            // what was typed never outlives the prompt it was for
            if (Updates.flow !== "auth")
                authField.clear();

            card.stopArmed = false;
            Qt.callLater(card.focusInput);
        }

        function onAskChanged() {
            var a = Updates.ask;
            askField.clear();
            askText.text = "";
            if (a === null || a.kind !== "password") {
                Qt.callLater(card.focusInput);
                return ;
            }
            if (card.view === "auth") {
                authField.clear();
                if (a.retry)
                    authField.shake();

            } else if (a.retry) {
                askField.shake();
            }
            Qt.callLater(card.focusInput);
        }

        target: Updates
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: card.stopArmed = false
    }

    // a new stage is uncovered by the card's own growth, never drawn past it.
    // the clip ends at the bottom padding and leaves slack for focus rings
    Item {
        id: viewport

        x: Theme.dp(16)
        y: Theme.dp(20)
        width: card.width - Theme.dp(32)
        height: Math.max(0, card.height - Theme.dp(48))
        clip: true

        Column {
            id: body

            x: Theme.dp(12)
            y: Theme.dp(8)
            width: viewport.width - Theme.dp(24)
            spacing: Theme.dp(14)

            Row {
                width: parent.width
                spacing: Theme.dp(16)

                Item {
                    width: Theme.dp(52)
                    height: Theme.dp(52)

                    MaterialShape {
                        anchors.fill: parent
                        shape: "cookie9"
                        color: {
                            if (card.view === "failed" || (card.view === "confirm" && card.beta))
                                return Theme.errorContainer;

                            if (card.view === "restart")
                                return Theme.alpha(Theme.success, 0.18);

                            return Theme.accentContainer;
                        }
                        spin: card.view === "running" && Updates.phase !== "stopping" ? 30 : 0

                        Behavior on spin {
                            NumberAnimation {
                                duration: Theme.durSlowSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveDefaultSpatial
                            }

                        }

                    }

                    Icon {
                        anchors.centerIn: parent
                        size: Theme.dp(26)
                        name: {
                            if (card.view === "confirm")
                                return card.beta ? "warning" : "update";

                            if (card.view === "auth")
                                return "key";

                            if (card.view === "running")
                                return Updates.phase === "download" ? "download" : "update";

                            if (card.view === "restart")
                                return card.fresh ? "check" : "restart_alt";

                            return "error";
                        }
                        color: {
                            if (card.view === "failed" || (card.view === "confirm" && card.beta))
                                return Theme.fgErrorContainer;

                            if (card.view === "restart")
                                return Theme.success;

                            return Theme.fgAccentContainer;
                        }
                    }

                }

                Column {
                    width: parent.width - Theme.dp(68)
                    spacing: Theme.dp(3)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: {
                            if (card.view === "confirm")
                                return card.beta ? "Beta build" : "Update available";

                            if (card.view === "auth")
                                return "Authentication required";

                            if (card.view === "running")
                                return Updates.phase === "stopping" ? "Stopping" : card.fresh ? "Installing Lucid" : "Updating Lucid";

                            if (card.view === "restart")
                                return card.fresh ? "All done" : "Update installed";

                            var what = card.fresh ? "Install" : "Update";
                            return card.res.reason === "cancelled" ? what + " stopped" : what + " failed";
                        }
                        color: {
                            if (card.view === "failed" || (card.view === "confirm" && card.beta))
                                return Theme.error;

                            if (card.view === "restart")
                                return Theme.success;

                            return Theme.accent;
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelMd
                        font.variableAxes: Theme.axes(Theme.fontLabelMd, 520, 0)
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width
                        text: {
                            if (card.view === "confirm")
                                return card.beta ? "Install " + Updates.flowLabel.toLowerCase() + "?" : "Update to " + Updates.flowLabel + "?";

                            if (card.view === "auth")
                                return "Enter your password";

                            if (card.view === "running")
                                return Updates.flowLabel;

                            if (card.view === "restart")
                                return Updates.flowLabel + " is installed";

                            var r = card.res.reason;
                            if (r === "password")
                                return "The password was not accepted";

                            if (r === "timeout")
                                return "No password was given in time";

                            if (r === "download")
                                return "The download failed";

                            if (r === "unpack")
                                return "The download could not be unpacked";

                            if (r === "cancelled")
                                return card.fresh ? "The install was stopped" : "The update was stopped";

                            if (r === "crash")
                                return "The updater stopped unexpectedly";

                            if (r === "nosudo")
                                return "sudo is not installed";

                            return "The installer stopped with an error";
                        }
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

            // what is about to happen, what is needed, or what came of it
            Text {
                width: parent.width
                visible: text !== ""
                text: {
                    if (card.view === "confirm") {
                        var what = card.beta ? "This is the newest commit on main, not a release" + (Updates.betaTitle !== "" ? ": “" + Updates.betaTitle + "”" : "") + ". Lucid downloads it from GitHub" : "Lucid downloads v" + Updates.latest + " from its GitHub release";
                        return what + " and runs the installer that comes with it. Your current setup is moved to a backup in ~/.config first, and your settings, pins and widgets carry over. It takes a few minutes, and the installer may ask you things along the way. Your password is needed next.";
                    }
                    if (card.view === "auth")
                        return "The installer uses sudo to install packages and system files such as the login screen theme. The password goes to sudo once and is not kept.";

                    if (card.view === "restart" && card.fresh && card.elsewhere !== "")
                        return "You are on " + card.elsewhere + " right now, and Lucid runs on Hyprland. Save what you have open, log out, and choose Hyprland on the login screen." + (card.note !== "" ? " Your Hyprland config was kept, so add this line to it first, or nothing starts Lucid there." : " Lucid starts with it.") + " " + (card.elsewhere === "another desktop" ? "Your desktop" : card.elsewhere) + " stays on that list to go back to, and ./uninstall.sh, beside install.sh, takes Lucid out." + (card.res.backup ? " Your previous setup is in " + card.tilde(card.res.backup) + "." : "");

                    if (card.view === "restart" && card.fresh && card.note !== "")
                        return "Start it now. Your Hyprland config was kept, so nothing starts Lucid when you log in yet: add this line to it." + (card.res.backup ? " Your previous setup is in " + card.tilde(card.res.backup) + "." : "");

                    if (card.view === "restart" && card.fresh)
                        return "Start it now, or log out and back in to begin your next session with it." + (card.res.backup ? " Your previous setup is in " + card.tilde(card.res.backup) + "." : "");

                    if (card.view === "restart")
                        return "Restart Lucid to start using it. Only the shell restarts: your windows and apps stay open." + (card.res.backup ? " Your previous setup is in " + card.tilde(card.res.backup) + "." : "");

                    if (card.view === "failed")
                        return (card.res.text ? card.res.text + " " : "") + (card.res.backup ? "Your previous setup is kept in " + card.tilde(card.res.backup) + "." : "Your Lucid files were not changed.");

                    return "";
                }
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
                lineHeight: 1.35
                wrapMode: Text.WordWrap
            }

            Rectangle {
                width: parent.width
                height: noteText.implicitHeight + Theme.dp(28)
                radius: Theme.dp(16)
                color: Theme.bgSunken
                visible: card.view === "restart" && card.fresh && card.note !== ""

                // selectable, to be copied into the config
                TextEdit {
                    id: noteText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.dp(16)
                    text: card.note
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.fgAccent
                    font.family: "monospace"
                    font.pixelSize: Theme.fontLabelMd
                }

            }

            // the beta's critical warning, in the error container
            Rectangle {
                width: parent.width
                height: betaWarn.implicitHeight + Theme.dp(28)
                radius: Theme.dp(18)
                color: Theme.errorContainer
                visible: card.view === "confirm" && card.beta

                Icon {
                    id: betaMark

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(16)
                    anchors.top: parent.top
                    anchors.topMargin: Theme.dp(15)
                    name: "warning"
                    fill: 1
                    size: Theme.dp(18)
                    color: Theme.fgErrorContainer
                }

                Text {
                    id: betaWarn

                    anchors.left: betaMark.right
                    anchors.leftMargin: Theme.dp(10)
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(16)
                    anchors.top: parent.top
                    anchors.topMargin: Theme.dp(14)
                    text: "<b>Things may break.</b> Beta builds are untested: the bar, the lock screen or the whole shell can fail to start. If that happens, move the backup back over ~/.config/quickshell from a terminal."
                    textFormat: Text.StyledText
                    color: Theme.fgErrorContainer
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
                    lineHeight: 1.3
                    wrapMode: Text.WordWrap
                }

            }

            // the opening sudo prompt
            Column {
                width: parent.width
                spacing: Theme.dp(10)
                visible: card.view === "auth"

                SecretField {
                    id: authField

                    width: parent.width
                    error: card.authAsk && card.ask.retry && authField.text === ""
                    busy: !card.authAsk
                    placeholder: card.authAsk ? "Password for " + Quickshell.env("USER") : "Getting ready…"
                    onAccepted: card.submitAuth()
                }

                Text {
                    width: parent.width
                    text: {
                        if (card.authAsk && card.ask.retry)
                            return "That password did not work. Try again.";

                        if (card.ask !== null && Updates.askSent === card.ask.n)
                            return "Checking…";

                        return "";
                    }
                    visible: text !== ""
                    color: card.authAsk && card.ask.retry ? Theme.error : Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodySm
                    font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                }

            }

            // the bar
            Column {
                width: parent.width
                spacing: Theme.dp(10)
                visible: card.view === "running"

                Row {
                    width: parent.width

                    Text {
                        width: parent.width - pct.width
                        text: {
                            if (Updates.phase === "download")
                                return "Downloading" + (Updates.bytes > 0 ? " — " + card.mb(Updates.bytes) : "");

                            if (Updates.phase === "install" && Updates.stepText !== "")
                                return Updates.stepText + (Updates.stepOf > 0 ? "  ·  step " + Updates.stepN + " of " + Updates.stepOf : "");

                            return Updates.phaseText !== "" ? Updates.phaseText : "Starting";
                        }
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyMd
                        font.variableAxes: Theme.axes(Theme.fontBodyMd, 480, 0)
                        elide: Text.ElideRight
                    }

                    Text {
                        id: pct

                        text: Updates.progressKnown ? Math.round(Updates.progress * 100) + "%" : ""
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyMd
                        font.variableAxes: Theme.axes(Theme.fontBodyMd, 480, 0)
                        font.features: {
                            "tnum": 1
                        }
                    }

                }

                LinearProgress {
                    width: parent.width
                    value: Updates.progress
                    wavy: true
                    animated: card.shown && card.view === "running" && Updates.phase !== "stopping"
                    // held still while it waits on an answer
                    flowing: !card.runAsk
                    thickness: Theme.dp(5)
                }

                Text {
                    width: parent.width
                    text: Updates.liveLine.trim()
                    // the question below already says it
                    visible: !card.runAsk
                    color: Theme.subtextDim
                    font.family: "monospace"
                    font.pixelSize: Theme.fontLabelSm
                    elide: Text.ElideRight
                }

            }

            // a question from the installer, or sudo wanting its password again
            Rectangle {
                width: parent.width
                height: askCol.implicitHeight + Theme.dp(36)
                radius: Theme.dp(20)
                color: Theme.bgTile
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.35)
                visible: card.runAsk

                Column {
                    id: askCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.dp(18)
                    spacing: Theme.dp(10)

                    Row {
                        spacing: Theme.dp(8)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: card.runAsk && card.ask.kind === "password" ? "key" : "help"
                            size: Theme.dp(16)
                            color: Theme.accent
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.runAsk && card.ask.kind === "password" ? "sudo needs your password again" : "The installer asks"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelMd
                            font.variableAxes: Theme.axes(Theme.fontLabelMd, 520, 0)
                            font.weight: Font.Medium
                        }

                    }

                    // the lines above the question say what it is about
                    Text {
                        width: parent.width
                        visible: card.runAsk && card.ask.kind !== "password" && text !== ""
                        text: card.runAsk ? (card.ask.context || []).map((l) => {
                            return l.trim();
                        }).filter((l) => {
                            return l !== "";
                        }).join("\n") : ""
                        color: Theme.subtextDim
                        font.family: "monospace"
                        font.pixelSize: Theme.fontLabelSm
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 6
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: card.runAsk && card.ask.kind !== "password"
                        text: card.runAsk ? card.question(card.ask.text) : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyLg
                        font.variableAxes: Theme.axes(Theme.fontBodyLg, 480, 0)
                        wrapMode: Text.WordWrap
                    }

                    SecretField {
                        id: askField

                        width: parent.width
                        visible: card.runAsk && card.ask.kind === "password"
                        error: card.runAsk && card.ask.retry === true && askField.text === ""
                        placeholder: card.runAsk && card.ask.retry ? "Wrong password, try again" : "Password for " + Quickshell.env("USER")
                        onAccepted: card.submitAsk()
                    }

                    Rectangle {
                        width: parent.width
                        height: Theme.dp(44)
                        radius: Theme.dp(22)
                        color: askText.activeFocus ? Theme.bgHigh : Theme.bgSunken
                        visible: card.runAsk && card.ask.kind === "text"

                        TextInput {
                            id: askText

                            anchors.fill: parent
                            anchors.leftMargin: Theme.dp(18)
                            anchors.rightMargin: Theme.dp(18)
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.fgAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyLg
                            clip: true
                            onAccepted: card.submitAsk()
                        }

                    }

                    Row {
                        anchors.right: parent.right
                        spacing: Theme.dp(8)

                        M3Button {
                            visible: card.runAsk && card.ask.kind === "yesno"
                            text: "No"
                            variant: card.runAsk && card.ask.def === "n" ? "filled" : "outlined"
                            onClicked: Updates.answer("n")
                        }

                        M3Button {
                            visible: card.runAsk && card.ask.kind === "yesno"
                            text: "Yes"
                            variant: card.runAsk && card.ask.def === "n" ? "outlined" : "filled"
                            onClicked: Updates.answer("y")
                        }

                        M3Button {
                            visible: card.runAsk && card.ask.kind !== "yesno"
                            text: "Send"
                            variant: "filled"
                            enabled: card.runAsk && (card.ask.kind === "text" || askField.text !== "")
                            onClicked: card.submitAsk()
                        }

                    }

                }

            }

            Row {
                width: parent.width

                MouseArea {
                    id: detailsToggle

                    width: visible ? detailsHead.width + Theme.dp(14) : 0
                    height: Theme.dp(40)
                    visible: card.view === "running" || card.view === "failed"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: details.expanded = !details.expanded

                    Row {
                        id: detailsHead

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(4)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "terminal"
                            size: Theme.dp(16)
                            color: Theme.subtextDim
                        }

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
                    width: Math.max(0, parent.width - actions.width - detailsToggle.width)
                    height: 1
                }

                Row {
                    id: actions

                    spacing: Theme.dp(8)

                    // confirm
                    M3Button {
                        visible: card.view === "confirm" || card.view === "auth"
                        text: "Cancel"
                        variant: "text"
                        onClicked: Updates.cancel()
                    }

                    M3Button {
                        visible: card.view === "confirm"
                        text: "OK"
                        variant: "filled"
                        destructive: card.beta
                        onClicked: Updates.confirmUpdate()
                    }

                    // auth
                    M3Button {
                        visible: card.view === "auth"
                        text: "Continue"
                        variant: "filled"
                        enabled: card.authAsk && authField.text !== ""
                        onClicked: card.submitAuth()
                    }

                    // running: a stop has to be meant, it can leave packages half done
                    M3Button {
                        visible: card.view === "running"
                        enabled: Updates.phase !== "stopping"
                        text: card.stopArmed ? "Stop now" : "Stop"
                        variant: card.stopArmed ? "tonal" : "text"
                        destructive: true
                        onClicked: {
                            if (!card.stopArmed) {
                                card.stopArmed = true;
                                disarm.restart();
                                return ;
                            }
                            card.stopArmed = false;
                            Updates.cancel();
                        }
                    }

                    M3Button {
                        visible: card.view === "running" && !card.fresh
                        text: "Hide"
                        variant: "tonal"
                        onClicked: Updates.hide()
                    }

                    // restart
                    M3Button {
                        visible: card.view === "restart" && card.fresh
                        text: "Close"
                        variant: "text"
                        onClicked: card.leave(false)
                    }

                    M3Button {
                        visible: card.view === "restart" && card.fresh
                        text: card.elsewhere !== "" ? "Log out to Hyprland" : "Start Lucid"
                        variant: "filled"
                        iconPath: card.elsewhere !== "" ? "logout" : "play_arrow"
                        onClicked: card.leave(true)
                    }

                    M3Button {
                        visible: card.view === "restart" && !card.fresh
                        text: "Cancel"
                        variant: "text"
                        onClicked: Updates.closeEnd()
                    }

                    M3Button {
                        visible: card.view === "restart" && !card.fresh
                        text: "Remind me later"
                        variant: "tonal"
                        iconPath: "snooze"
                        onClicked: Updates.remindLater()
                    }

                    M3Button {
                        visible: card.view === "restart" && !card.fresh
                        text: "Restart now"
                        variant: "filled"
                        iconPath: "restart_alt"
                        onClicked: Updates.restartNow()
                    }

                    // failed
                    M3Button {
                        visible: card.view === "failed"
                        text: "Open log"
                        variant: "text"
                        onClicked: Updates.openLog()
                    }

                    M3Button {
                        visible: card.canRetry
                        text: "Try again"
                        variant: "tonal"
                        onClicked: Updates.retry()
                    }

                    M3Button {
                        visible: card.view === "failed"
                        text: card.fresh ? "Back" : "Close"
                        variant: "filled"
                        onClicked: Updates.closeEnd()
                    }

                }

            }

        }

        // the installer's own words, kept out of the way until wanted
        Item {
            id: details

            property bool expanded: false

            // whatever room the card has grown so far, so the box never runs ahead of it
            anchors.left: body.left
            anchors.right: body.right
            anchors.top: body.bottom
            anchors.topMargin: body.spacing
            height: Math.max(0, Math.min(card.logFull, viewport.height - Theme.dp(8) - body.implicitHeight - body.spacing))
            clip: true
            visible: height > 0

            // full size behind the clip, so it is uncovered rather than reflowed
            Rectangle {
                width: parent.width
                height: card.logFull
                radius: Theme.dp(16)
                color: Theme.bgSunken

                ListView {
                    id: logView

                    // follows the end until scrolled away from it
                    property bool stick: true

                    anchors.fill: parent
                    anchors.margins: Theme.dp(12)
                    model: Updates.logLines
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onCountChanged: {
                        if (logView.stick)
                            Qt.callLater(logView.positionViewAtEnd);

                    }
                    onMovementEnded: logView.stick = logView.atYEnd
                    onVisibleChanged: {
                        if (logView.visible) {
                            logView.stick = true;
                            Qt.callLater(logView.positionViewAtEnd);
                        }
                    }

                    delegate: Text {
                        required property string line

                        width: ListView.view.width
                        text: line
                        color: Theme.subtext
                        font.family: "monospace"
                        font.pixelSize: Theme.fontLabelSm
                        wrapMode: Text.WrapAnywhere
                    }

                }

            }

        }

    }

    Behavior on height {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
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
