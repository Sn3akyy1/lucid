import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
pragma Singleton

// the session's polkit agent. polkitd and pam still do the work; only the
// dialog is ours, so every prompt the machine raises lands in lucid's theme
Singleton {
    id: root

    readonly property bool registered: agent.isRegistered

    // the flow dies with the request, so everything drawn is snapshotted
    property var flowRef: null
    property bool open: false
    property bool granted: false
    property bool preview: false
    property string message: ""
    property string actionId: ""
    property string iconHint: ""
    property var identities: []
    property int identityIndex: 0
    property string errorText: ""
    property string infoText: ""
    property bool checking: false
    // a response is out and its verdict is owed
    property bool submitted: false
    // we ended the pam session ourselves, so its failure is not the user's
    property bool restarting: false

    // pkaction knows the action's short description and who ships it
    property var metaCache: ({
    })
    property string title: ""
    property string vendor: ""

    readonly property bool prompting: root.flowRef !== null && root.flowRef.isResponseRequired
    readonly property string prompt: root.flowRef ? root.flowRef.inputPrompt : "Password"
    readonly property bool secret: root.flowRef ? !root.flowRef.responseVisible : true
    readonly property bool multiUser: root.identities.length > 1
    readonly property string glyph: root.glyphFor(root.actionId, root.iconHint)

    signal failed()

    // polkit writes `like this', which reads as a stray backtick everywhere else
    function humanise(s) {
        if (!s)
            return "";

        return s.replace(/`([^']*)'/g, "“$1”");
    }

    function glyphFor(id, icon) {
        var a = id || "";
        if (a === "org.freedesktop.policykit.exec")
            return "terminal";

        if (a.indexOf("org.freedesktop.udisks2") === 0 || a.indexOf("io.systemd.mount") === 0 || (icon || "").indexOf("drive") >= 0)
            return "drive";

        if (a.indexOf("org.freedesktop.login1") === 0 || a.indexOf("org.freedesktop.systemd1") === 0 || a.indexOf("org.freedesktop.sysupdate1") === 0)
            return "power";

        if (a.indexOf("org.freedesktop.NetworkManager") === 0 || a.indexOf("org.freedesktop.network1") === 0 || a.indexOf("org.freedesktop.resolve1") === 0 || a.indexOf("org.freedesktop.ModemManager") === 0)
            return "network";

        if (a.indexOf("org.freedesktop.accounts") === 0 || a.indexOf("org.freedesktop.home1") === 0 || a.indexOf("org.freedesktop.machine1") === 0)
            return "user";

        if (a.indexOf("org.freedesktop.packagekit") === 0 || a.indexOf("org.freedesktop.Flatpak") === 0 || (icon || "").indexOf("software") >= 0)
            return "package";

        return "shield";
    }

    // the uid is the identity's id, so the accounts we already know fill in
    function nameFor(identity) {
        if (!identity)
            return "";

        var u = identity.isGroup ? null : Users.userFor(identity.id);
        if (u)
            return Users.displayName(u);

        return identity.displayName || identity.string || "";
    }

    function userFor(identity) {
        if (!identity || identity.isGroup)
            return null;

        return Users.userFor(identity.id);
    }

    function lookupMeta(id) {
        if (!id) {
            root.title = "";
            root.vendor = "";
            return ;
        }
        var hit = root.metaCache[id];
        if (hit) {
            root.title = hit.title;
            root.vendor = hit.vendor;
            return ;
        }
        root.title = "";
        root.vendor = "";
        metaProc.wanted = id;
        metaProc.command = ["pkaction", "--action-id", id, "--verbose"];
        metaProc.running = true;
    }

    function begin(flow) {
        root.flowRef = flow;
        root.message = root.humanise(flow.message);
        root.actionId = flow.actionId;
        root.iconHint = flow.iconName;
        root.identities = flow.identities;
        root.identityIndex = Math.max(0, root.identities.indexOf(flow.selectedIdentity));
        root.errorText = "";
        root.infoText = "";
        root.checking = false;
        root.submitted = false;
        root.restarting = false;
        root.granted = false;
        root.preview = false;
        root.lookupMeta(flow.actionId);
        root.open = true;
    }

    function pick(index) {
        if (index < 0 || index >= root.identities.length || index === root.identityIndex)
            return ;

        root.identityIndex = index;
        root.errorText = "";
        root.infoText = "";
        root.submitted = false;
        root.restarting = true;
        if (root.flowRef)
            root.flowRef.selectedIdentity = root.identities[index];

    }

    function submit(value) {
        if (root.preview) {
            root.errorText = value === "" ? "Type something to see the error state." : "";
            root.checking = false;
            return ;
        }
        if (!root.flowRef || !root.flowRef.isResponseRequired)
            return ;

        root.checking = true;
        root.submitted = true;
        // switching identity does not always re-prompt, so the teardown guard
        // is lifted here rather than waiting on a prompt that may never change
        root.restarting = false;
        root.errorText = "";
        root.flowRef.submit(value);
    }

    function cancel() {
        if (root.preview) {
            root.close();
            return ;
        }
        root.submitted = false;
        root.restarting = true;
        if (root.flowRef)
            root.flowRef.cancelAuthenticationRequest();
        else
            root.close();
    }

    function close() {
        root.open = false;
        root.flowRef = null;
        root.errorText = "";
        root.infoText = "";
        root.checking = false;
        root.submitted = false;
        root.restarting = false;
        root.preview = false;
    }

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: root.begin(agent.flow)
    }

    Connections {
        function onIsResponseRequiredChanged() {
            // a fresh prompt means pam is asking again, so the field reopens
            if (root.flowRef && root.flowRef.isResponseRequired) {
                root.checking = false;
                root.restarting = false;
            }

        }

        function onSupplementaryMessageChanged() {
            var f = root.flowRef;
            if (!f || root.restarting)
                return ;

            var m = root.humanise(f.supplementaryMessage);
            if (f.supplementaryIsError) {
                root.errorText = m;
                root.infoText = "";
            } else {
                root.infoText = m;
            }
        }

        function onAuthenticationFailed() {
            root.checking = false;
            // pam also reports a failure when the session is torn down to switch
            // identity or to cancel, and neither is a password the user got wrong
            if (root.restarting || !root.submitted)
                return ;

            root.submitted = false;
            if (root.errorText === "")
                root.errorText = "That password was not accepted.";

            root.failed();
        }

        function onAuthenticationRequestCancelled() {
            root.close();
        }

        function onIsCompletedChanged() {
            var f = root.flowRef;
            if (!f || !f.isCompleted)
                return ;

            root.checking = false;
            root.granted = f.isSuccessful;
            // the surface drops keyboard focus at once; the tick is only shown
            root.flowRef = null;
            if (root.granted)
                doneTimer.restart();
            else
                root.close();
        }

        target: root.flowRef
        ignoreUnknownSignals: true
    }

    // the dialog takes the keyboard, so it must never outlive the request
    Connections {
        function onFlowChanged() {
            if (agent.flow === null && root.open && !root.preview && !root.granted)
                root.close();

        }

        target: agent
    }

    Timer {
        id: doneTimer

        interval: Theme.ms(520)
        onTriggered: root.close()
    }

    Process {
        id: metaProc

        property string wanted: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var title = "";
                var vendor = "";
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var m = lines[i].match(/^\s+(description|vendor):\s+(.*\S)\s*$/);
                    if (!m)
                        continue;

                    if (m[1] === "description")
                        title = m[2];
                    else
                        vendor = m[2];
                }
                var next = Object.assign({
                }, root.metaCache);
                next[metaProc.wanted] = {
                    "title": title,
                    "vendor": vendor
                };
                root.metaCache = next;
                if (root.actionId === metaProc.wanted) {
                    root.title = title;
                    root.vendor = vendor;
                }
            }
        }

    }

    // a themed dry run: the dialog with no pam session behind it
    IpcHandler {
        function demo(kind: string): string {
            var id = kind === "" ? "org.freedesktop.policykit.exec" : kind;
            root.flowRef = null;
            root.preview = true;
            root.actionId = id;
            root.iconHint = "";
            root.message = root.humanise("Authentication is needed to run `/usr/bin/lucid-preview' as the super user");
            root.identities = Users.users.map((u) => {
                return {
                    "id": u.uid,
                    "displayName": u.name,
                    "string": "unix-user:" + u.uid,
                    "isGroup": false
                };
            });
            root.identityIndex = 0;
            root.errorText = "";
            root.infoText = "";
            root.checking = false;
            root.granted = false;
            root.lookupMeta(id);
            root.open = true;
            return "shown";
        }

        function fail(): string {
            root.errorText = "That password was not accepted.";
            root.checking = false;
            root.failed();
            return "failed";
        }

        function grant(): string {
            root.granted = true;
            return "granted";
        }

        function close(): string {
            // a live request must be answered, not just hidden
            root.cancel();
            return "closed";
        }

        function status(): string {
            return (root.registered ? "registered" : "not registered") + ", " + (root.open ? "prompting for " + root.actionId : "idle");
        }

        target: "polkit"
    }

}
