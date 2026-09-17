import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// the machine's user accounts; usertool.py speaks to accountsservice, so every
// privileged change is asked for by the session's polkit agent, not by us
Singleton {
    id: root

    readonly property string helper: Qt.resolvedUrl("lucidprefs/usertool.py").toString().replace("file://", "")
    readonly property int standard: 0
    readonly property int admin: 1
    // accountsservice's password modes
    readonly property int pwRegular: 0
    readonly property int pwSetAtLogin: 1
    readonly property int pwNone: 2

    property bool probed: false
    property bool busy: false
    property var users: []
    property var shells: []
    property var groupNames: []
    property var faces: []
    property bool facesLoaded: false
    // pictures this account has worn before, newest first
    property var avatarHistory: []
    property int historyUid: -1
    property int myUid: -1
    property bool canAdmin: false
    property string lastError: ""
    property string lastErrorKind: ""
    // an avatar keeps its path when it changes, so the url needs a fresh tail
    property int avatarRev: 0

    signal refreshed()
    signal failed(string message, string kind)
    signal applied(string what)
    // the dialogs live in the settings window; the page only asks for them
    signal avatarRequested(int uid)
    signal passwordRequested(int uid, string headline, string body, string hint)
    signal newUserRequested()
    signal deleteRequested(int uid)

    readonly property var me: {
        var list = root.users;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isMe)
                return list[i];

        }
        return null;
    }
    readonly property var others: root.users.filter((u) => {
        return !u.isMe;
    })

    function userFor(uid) {
        var list = root.users;
        for (var i = 0; i < list.length; i++) {
            if (list[i].uid === uid)
                return list[i];

        }
        return null;
    }

    function displayName(u) {
        if (!u)
            return "";

        return u.realName && u.realName !== "" ? u.realName : u.name;
    }

    // two letters at most: initials of a real name, else the username's start
    function initials(u) {
        if (!u)
            return "?";

        var src = u.realName && u.realName !== "" ? u.realName : u.name;
        var parts = src.trim().split(/[\s._-]+/).filter((p) => {
            return p.length > 0;
        });
        if (parts.length === 0)
            return "?";

        if (parts.length === 1)
            return parts[0].substring(0, 2).toUpperCase();

        return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    }

    // a plain file url: qt does not strip a query string off a local path, it
    // looks for a file with that name and fails. avatarRev busts the cache
    function avatarUrl(u) {
        if (!u || !u.avatar || u.avatar === "")
            return "";

        return "file://" + u.avatar;
    }

    function typeLabel(t) {
        return t === root.admin ? "Administrator" : "Standard";
    }

    function isOnlyAdmin(uid) {
        var admins = root.users.filter((u) => {
            return u.accountType === root.admin;
        });
        return admins.length === 1 && admins[0].uid === uid;
    }

    function shellName(path) {
        if (!path || path === "")
            return "";

        return path.split("/").pop();
    }

    function probe() {
        probeProc.running = false;
        probeProc.running = true;
    }

    // the picker asks for these; they are read from our own data dir, so no
    // administrator is involved and nothing here raises a polkit prompt
    function loadHistory(uid) {
        root.historyUid = uid;
        histProc.mode = "history";
        histProc.pending = JSON.stringify({
            "uid": uid
        });
        histProc.command = ["python3", root.helper, "history"];
        histProc.running = true;
    }

    function clearHistory(uid) {
        root.historyUid = uid;
        histProc.mode = "history-clear";
        histProc.pending = JSON.stringify({
            "uid": uid
        });
        histProc.command = ["python3", root.helper, "history-clear"];
        histProc.running = true;
    }

    // only the picker needs these, so they wait until it opens
    function loadFaces() {
        if (root.facesLoaded)
            return ;

        facesProc.running = true;
    }

    // every mutation goes out the same door, so only one can be in flight
    function send(mode, cmd, label) {
        // one at a time: two polkit prompts at once help nobody
        if (root.busy) {
            root.lastError = "Still applying the last change — try that again in a moment.";
            root.lastErrorKind = "busy";
            return ;
        }

        root.busy = true;
        root.lastError = "";
        root.lastErrorKind = "";
        applyProc.pending = JSON.stringify(cmd);
        applyProc.label = label || "";
        applyProc.touchedAvatar = cmd.avatar !== undefined;
        applyProc.command = ["python3", root.helper, mode];
        applyProc.running = true;
    }

    function set(uid, patch, label) {
        var cmd = Object.assign({
        }, patch);
        cmd.uid = uid;
        root.send("set", cmd, label);
    }

    function create(spec) {
        root.send("create", spec, "create");
    }

    function remove(uid, removeFiles) {
        root.send("delete", {
            "uid": uid,
            "removeFiles": removeFiles === true
        }, "delete");
    }

    Process {
        id: probeProc

        running: true
        command: ["python3", root.helper, "probe"]

        stdout: StdioCollector {
            onStreamFinished: {
                var d = ({
                });
                try {
                    d = JSON.parse(this.text.trim() || "{}");
                } catch (e) {
                    root.lastError = "could not read this machine's accounts";
                    root.probed = true;
                    return ;
                }
                if (d.ok === false) {
                    root.lastError = d.error || "could not read this machine's accounts";
                    root.lastErrorKind = d.kind || "error";
                    root.probed = true;
                    return ;
                }
                root.users = d.users || [];
                root.shells = d.shells || [];
                root.groupNames = d.groups || [];
                root.myUid = d.me !== undefined ? d.me : -1;
                root.canAdmin = d.canAdmin === true;
                root.probed = true;
                root.refreshed();
            }
        }

    }

    Process {
        id: facesProc

        command: ["python3", root.helper, "faces"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.faces = JSON.parse(this.text.trim() || "{}").faces || [];
                } catch (e) {
                    root.faces = [];
                }
                root.facesLoaded = true;
            }
        }

    }

    Process {
        id: histProc

        property string pending: ""
        property string mode: "history"

        stdinEnabled: true
        onStarted: {
            write(histProc.pending);
            histProc.pending = "";
            histCloser.start();
        }
        onExited: stdinEnabled = true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.avatarHistory = JSON.parse(this.text.trim() || "{}").items || [];
                } catch (e) {
                    root.avatarHistory = [];
                }
            }
        }

    }

    // the write needs a moment to reach the child before the pipe closes
    Timer {
        id: histCloser

        interval: 100
        onTriggered: histProc.stdinEnabled = false
    }

    Process {
        id: applyProc

        property string pending: ""
        property string label: ""
        property bool touchedAvatar: false

        stdinEnabled: true
        onStarted: {
            write(applyProc.pending);
            applyProc.pending = "";
            stdinCloser.start();
        }
        onExited: {
            root.busy = false;
            stdinEnabled = true;
            if (applyProc.touchedAvatar)
                root.avatarRev = root.avatarRev + 1;

            // the daemon has finished writing by the time it answers; re-read
            root.probe();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var r = ({
                });
                try {
                    r = JSON.parse(this.text.trim() || "{}");
                } catch (e) {
                    root.lastError = "that change could not be made";
                    root.lastErrorKind = "error";
                    root.failed(root.lastError, "error");
                    return ;
                }
                if (r.ok === false) {
                    root.lastError = r.error || "that change could not be made";
                    root.lastErrorKind = r.kind || "error";
                    root.failed(root.lastError, root.lastErrorKind);
                    return ;
                }
                root.applied(applyProc.label);
            }
        }

    }

    // the write needs a moment to reach the child before the pipe closes
    Timer {
        id: stdinCloser

        interval: 100
        onTriggered: applyProc.stdinEnabled = false
    }

}
