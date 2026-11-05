import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// asks github once a day whether a newer release is out, and says so once per
// version. off switch: Prefs.updateCheck. Update installs it from the release
// through lucidupdate/updater.py, which runs outside the shell
Singleton {
    id: root

    readonly property string repo: "Sn3akyy1/lucid"
    readonly property string releasesUrl: "https://github.com/" + root.repo + "/releases"
    readonly property int everyMs: 86400000 // test-marker

    // the installer copies a VERSION file in beside shell.qml
    property string current: ""
    property string latest: ""
    property string latestTag: ""
    property string latestName: ""
    property string latestUrl: root.releasesUrl
    // the version already announced, so an ignored update stays quiet
    property string notified: ""
    // the version whose What's new sheet has been shown, so it opens by itself once
    property string seen: ""
    property real checkedAt: 0
    property bool busy: false
    // "" | "offline" | "ratelimited" | "norelease" | "unreadable"
    property string problem: ""
    property bool gotResponse: false

    // the beta channel: the newest commit on main
    property string betaSha: ""
    property string betaTitle: ""
    property real betaDate: 0
    property bool betaBusy: false
    property string betaProblem: ""
    // what the updater last put in place, from installed.json
    property string installedSha: ""
    property string installedChannel: ""

    readonly property string currentLabel: root.current === "" ? "unknown" : "v" + root.current
    readonly property bool available: root.current !== "" && root.latest !== "" && root.isNewer(root.latest, root.current)
    readonly property bool wanted: Prefs.loaded && Prefs.updateCheck && root.current !== ""
    readonly property string betaShort: root.betaSha.slice(0, 7)
    readonly property bool betaAvailable: Prefs.updateBeta && root.betaSha !== "" && root.betaSha !== root.installedSha

    // --- installing ---
    readonly property string updateDir: Quickshell.env("HOME") + "/.cache/quickshell/lucid-update"
    readonly property string runDir: root.updateDir + "/" + root.run
    readonly property string logPath: root.runDir + "/install.log"
    // "" | "confirm" | "auth" | "running" | "restart" | "failed"
    property string flow: ""
    property bool sheetOpen: false
    // "release" | "beta" | "local" (the graphical installer, installer.qml)
    property string flowChannel: "release"
    property string flowLabel: ""
    // the run being followed; its folder holds events.jsonl, the log, the answers fifo
    property string run: ""
    // the user has dealt with this run's last sheet, so a reload must not bring it back
    property bool runClosed: false
    property real remindAt: 0
    property int runPid: 0
    property int runShell: 0
    property string phase: ""
    property string phaseText: ""
    property real progress: 0
    property bool progressKnown: true
    property string stepText: ""
    property int stepN: 0
    property int stepOf: 0
    property real bytes: 0
    property string liveLine: ""
    property var ask: null
    property int askSent: 0
    property bool authOk: false
    property var result: null
    property int missed: 0
    readonly property bool installing: root.flow === "auth" || root.flow === "running"
    readonly property bool restartPending: root.flow === "restart"
    readonly property var logLines: logModel
    // the run this singleton has already read back, so a reload replays it once
    property string attached: ""

    function numbers(v) {
        return String(v).trim().replace(/^v/i, "").split("-")[0].split(".").map((n) => {
            return parseInt(n, 10) || 0;
        });
    }

    function isNewer(a, b) {
        var x = root.numbers(a);
        var y = root.numbers(b);
        for (var i = 0; i < Math.max(x.length, y.length); i++) {
            var d = (x[i] || 0) - (y[i] || 0);
            if (d !== 0)
                return d > 0;

        }
        return false;
    }

    function ago(ts) {
        var m = Math.max(0, Math.round((Date.now() - ts) / 60000));
        if (m < 2)
            return "just now";

        if (m < 60)
            return m + " minutes ago";

        var h = Math.round(m / 60);
        if (h < 24)
            return h === 1 ? "an hour ago" : h + " hours ago";

        var d = Math.round(h / 24);
        return d === 1 ? "yesterday" : d + " days ago";
    }

    readonly property string status: {
        if (root.current === "")
            return "Lucid cannot tell which version it is — there is no VERSION file beside shell.qml.";

        if (root.installing)
            return root.flowLabel + ": " + root.phaseText + (root.progressKnown ? " — " + Math.round(root.progress * 100) + "%" : "");

        if (root.restartPending)
            return root.flowLabel + " is installed. Restart Lucid to finish.";

        if (root.busy)
            return "Asking GitHub…";

        if (root.problem === "offline")
            return "Could not reach GitHub. Lucid tries again later.";

        if (root.problem === "ratelimited")
            return "GitHub is rate-limiting this address. Lucid tries again later.";

        if (root.problem === "norelease")
            return "No release has been published yet.";

        if (root.problem === "unreadable")
            return "GitHub answered with something Lucid could not read.";

        if (root.available)
            return (root.latestName !== "" ? root.latestName + ". " : "") + "Update installs it from the release.";

        // a saved timestamp outlives the reason for it, so an empty latest after
        // a real check means nothing is published rather than up to date
        if (root.checkedAt > 0 && root.latest === "")
            return "No release has been published yet.";

        if (root.checkedAt > 0)
            return "Up to date — checked " + root.ago(root.checkedAt) + ".";

        return Prefs.updateCheck ? "Not checked yet." : "The daily check is off.";
    }

    readonly property string betaStatus: {
        if (root.betaBusy)
            return "Asking GitHub…";

        if (root.betaProblem !== "")
            return root.betaProblem;

        if (root.betaSha === "")
            return "Not checked yet.";

        var what = root.betaShort + (root.betaTitle !== "" ? " — " + root.betaTitle : "") + (root.betaDate > 0 ? ", " + root.ago(root.betaDate) : "");
        if (!root.betaAvailable)
            return "You are on the newest beta build, " + what + ".";

        return "Newest build: " + what + ".";
    }

    function check() {
        if (Prefs.updateBeta)
            root.checkBeta();

        if (root.busy || root.current === "")
            return ;

        root.busy = true;
        root.gotResponse = false;
        fetcher.running = true;
    }

    function checkBeta() {
        if (root.betaBusy)
            return ;

        root.betaBusy = true;
        betaFetcher.running = true;
    }

    function maybeCheck() {
        if (root.wanted && Date.now() - root.checkedAt >= root.everyMs)
            root.check();

    }

    function openLatest() {
        Quickshell.execDetached(["xdg-open", root.latestUrl]);
    }

    // the What's new sheet (lucidnews) listens for this
    signal whatsNewRequested()

    function showWhatsNew() {
        root.whatsNewRequested();
    }

    function markSeen() {
        if (root.current === "" || root.seen === root.current)
            return ;

        root.seen = root.current;
        root.save();
    }

    // one notification per version, with buttons onto the notes and the update
    function announce() {
        if (!root.available || root.notified === root.latest)
            return ;

        root.notified = root.latest;
        root.save();
        var body = "You have v" + root.current + ". Update installs it from the release.";
        if (root.latestName !== "" && root.latestName.trim().replace(/^v/i, "") !== root.latest)
            body = root.latestName + "\n" + body;

        Quickshell.execDetached(["sh", "-c", "A=$(notify-send -a Lucid -i \"$1\" \"$2\" \"$3\" -A \"open=What's new\" -A \"update=Update\" --wait); case \"$A\" in open) xdg-open \"$4\" ;; update) qs ipc call updates update ;; esac; true", "sh", root.iconPath, "Lucid v" + root.latest + " is out", body, root.latestUrl]);
    }

    // the mark on its plate: the bare one fades out on a light-mode card
    readonly property string iconPath: Qt.resolvedUrl("assets/logo.svg").toString().replace("file://", "")

    function take(body) {
        var d = JSON.parse(body);
        var raw = String(d.tag_name || "").trim();
        var tag = raw.replace(/^v/i, "");
        if (tag === "") {
            root.problem = "unreadable";
            return ;
        }
        root.latest = tag;
        root.latestTag = raw;
        root.latestName = String(d.name || "").trim().replace(/^lucid\s+/i, "");
        root.latestUrl = String(d.html_url || root.releasesUrl);
        root.checkedAt = Date.now();
        root.problem = "";
        root.save();
        root.announce();
    }

    function takeBeta(body) {
        var d = JSON.parse(body);
        var sha = String(d.sha || "");
        if (!/^[0-9a-f]{40}$/.test(sha)) {
            root.betaProblem = "GitHub answered with something Lucid could not read.";
            return ;
        }
        var c = d.commit || {
        };
        root.betaSha = sha;
        root.betaTitle = String(c.message || "").split("\n")[0].trim();
        root.betaDate = Date.parse((c.committer || {
        }).date || "") || 0;
        root.betaProblem = "";
        root.save();
    }

    function save() {
        stateFile.setText(JSON.stringify({
            "checkedAt": root.checkedAt,
            "latest": root.latest,
            "tag": root.latestTag,
            "name": root.latestName,
            "url": root.latestUrl,
            "notified": root.notified,
            "seen": root.seen,
            "betaSha": root.betaSha,
            "betaTitle": root.betaTitle,
            "betaDate": root.betaDate,
            "run": root.run,
            "runClosed": root.runClosed,
            "remindAt": root.remindAt
        }));
    }

    // --- installing ---

    // the warning comes first; nothing runs until it is accepted
    function startUpdate(channel) {
        if (root.installing || root.current === "")
            return ;

        if (channel === "beta" && root.betaSha === "")
            return ;

        if (channel !== "beta" && !root.available)
            return ;

        root.flowChannel = channel;
        root.flowLabel = channel === "beta" ? "Beta " + root.betaShort : "Lucid v" + root.latest;
        root.flow = "confirm";
        root.sheetOpen = true;
    }

    function confirmUpdate() {
        if (root.flow !== "confirm")
            return ;

        var beta = root.flowChannel === "beta";
        var tag = root.latestTag !== "" ? root.latestTag : "v" + root.latest;
        var ref = beta ? root.betaSha : tag;
        var url = "https://codeload.github.com/" + root.repo + "/tar.gz/" + (beta ? root.betaSha : "refs/tags/" + encodeURIComponent(tag));
        root.launch(["--url", url, "--ref", ref, "--sha", beta ? root.betaSha : ""]);
    }

    // the graphical installer: this tree's own install.sh, nothing to download
    function installHere(args) {
        if (root.installing)
            return ;

        root.flowChannel = "local";
        root.flowLabel = "Lucid" + (root.current !== "" ? " v" + root.current : "");
        root.sheetOpen = true;
        root.launch(["--src", Quickshell.shellDir.replace(/\/$/, ""), "--"].concat(args || []));
    }

    function launch(source) {
        root.resetRun();
        root.run = "run-" + Date.now();
        root.runClosed = false;
        root.remindAt = 0;
        root.save();
        root.flow = "auth";
        Quickshell.execDetached(["setsid", "-f", "python3", root.updaterPath, "--dir", root.runDir, "--channel", root.flowChannel, "--label", root.flowLabel, "--shell-pid", String(Quickshell.processId)].concat(source));
        root.follow(false);
    }

    readonly property string updaterPath: Qt.resolvedUrl("lucidupdate/updater.py").toString().replace("file://", "")

    function resetRun() {
        follower.running = false;
        writer.running = false;
        root.pending = [];
        logModel.clear();
        root.runPid = 0;
        root.runShell = 0;
        root.phase = "";
        root.phaseText = "";
        root.progress = 0;
        root.progressKnown = true;
        root.stepText = "";
        root.stepN = 0;
        root.stepOf = 0;
        root.bytes = 0;
        root.liveLine = "";
        root.ask = null;
        root.askSent = 0;
        root.authOk = false;
        root.result = null;
        root.missed = 0;
    }

    // a fresh run waits for its file; an old one is read back only if it is still there
    function follow(existing) {
        root.attached = root.run;
        follower.command = existing ? ["sh", "-c", "[ -f \"$1\" ] && exec tail -n +1 -F \"$1\"", "sh", root.runDir + "/events.jsonl"] : ["tail", "-n", "+1", "-F", root.runDir + "/events.jsonl"];
        follower.running = true;
    }

    property var pending: []

    function send(obj) {
        root.pending = root.pending.concat([JSON.stringify(obj) + "\n"]);
        if (writer.running)
            root.flush();
        else
            writer.running = true;
    }

    function flush() {
        var q = root.pending;
        root.pending = [];
        for (var i = 0; i < q.length; i++) writer.write(q[i])
    }

    function answer(value) {
        if (root.ask === null || root.askSent === root.ask.n)
            return ;

        root.askSent = root.ask.n;
        root.send({
            "n": root.ask.n,
            "value": String(value)
        });
    }

    function cancel() {
        if (root.flow === "confirm") {
            root.flow = "";
            root.sheetOpen = false;
            return ;
        }
        if (root.installing) {
            root.send({
                "cancel": true
            });
            root.phaseText = "Stopping";
        }
    }

    function hide() {
        if (root.installing)
            root.sheetOpen = false;

    }

    function show() {
        if (root.flow !== "")
            root.sheetOpen = true;

    }

    function closeEnd() {
        root.runClosed = true;
        root.remindAt = 0;
        root.save();
        root.sheetOpen = false;
        if (root.flow === "failed")
            root.flow = "";

    }

    function remindLater() {
        root.runClosed = true;
        root.remindAt = Date.now() + 3600000;
        root.save();
        root.sheetOpen = false;
    }

    // the installer goes back to its choices rather than straight round again
    function retry() {
        var ch = root.flowChannel;
        root.closeEnd();
        if (ch !== "local")
            root.startUpdate(ch);

    }

    function openLog() {
        Quickshell.execDetached(["xdg-open", root.logPath]);
    }

    // through the launcher, as autostart does. a supervisor that brings the
    // shell back by itself is left to it. the installer passes the installed shell's folder
    function restartNow(shellDir) {
        root.runClosed = true;
        root.remindAt = 0;
        root.save();
        root.sheetOpen = false;
        var dir = (shellDir || Quickshell.shellDir).replace(/\/$/, "");
        Quickshell.execDetached(["setsid", "-f", "sh", "-c", "qs kill -p \"$2\" >/dev/null 2>&1; i=0; while kill -0 \"$1\" 2>/dev/null && [ $i -lt 50 ]; do sleep 0.1; i=$((i+1)); done; sleep 0.8; qs list 2>/dev/null | grep -F \"Config path: $2/shell.qml\" >/dev/null && exit 0; if [ -x \"$3\" ]; then exec \"$3\" -d; else exec qs -d -p \"$2\"; fi", "sh", String(Quickshell.processId), dir, Quickshell.env("HOME") + "/.config/lucid/launch-shell.sh"]);
    }

    function event(line) {
        var e;
        try {
            e = JSON.parse(line);
        } catch (err) {
            return ;
        }
        if (e.e === "start") {
            root.runPid = e.pid || 0;
            root.runShell = e.shell || 0;
            root.flowChannel = e.channel || root.flowChannel;
            root.flowLabel = e.label || root.flowLabel;
            if (!root.installing)
                root.flow = "auth";

            if (!writer.running)
                writer.running = true;

        } else if (e.e === "phase") {
            root.phase = e.phase;
            root.phaseText = e.text || "";
            root.progress = e.p || 0;
            root.progressKnown = e.known !== false;
            if (e.phase !== "auth" && e.phase !== "stopping") {
                root.authOk = true;
                root.flow = "running";
            }
        } else if (e.e === "authok") {
            root.authOk = true;
            root.flow = "running";
        } else if (e.e === "bytes") {
            root.bytes = e.n || 0;
            root.progress = e.p || root.progress;
        } else if (e.e === "step") {
            root.stepText = e.text || "";
            root.stepN = e.n || 0;
            root.stepOf = e.of || 0;
            root.progress = e.p || root.progress;
        } else if (e.e === "line") {
            logModel.append({
                "line": String(e.text)
            });
            if (logModel.count > 400)
                logModel.remove(0, logModel.count - 400);

            if (String(e.text).trim() !== "")
                root.liveLine = e.text;

        } else if (e.e === "live") {
            if (String(e.text).trim() !== "")
                root.liveLine = e.text;

        } else if (e.e === "ask") {
            root.ask = e;
        } else if (e.e === "answered" || e.e === "unask") {
            if (root.ask !== null && root.ask.n === e.n)
                root.ask = null;

        } else if (e.e === "done") {
            root.result = e;
            root.ask = null;
            root.progress = e.ok ? 1 : root.progress;
            follower.running = false;
            writer.running = false;
            root.flow = e.ok ? "restart" : "failed";
            if (e.ok)
                installedFile.reload();

        }
        Qt.callLater(root.settle);
    }

    // one decision after a burst of events, so a replay never flashes the sheet
    function settle() {
        if (root.flow === "restart") {
            // a shell started since the install is already on the new files
            if (root.runShell !== Quickshell.processId) {
                root.flow = "";
                root.sheetOpen = false;
                return ;
            }
            if (!root.runClosed)
                root.sheetOpen = true;

            return ;
        }
        if (root.flow === "failed") {
            if (root.runClosed) {
                root.flow = "";
                root.sheetOpen = false;
            } else {
                root.sheetOpen = true;
            }
            return ;
        }
        // a question brings a hidden sheet back
        if (root.installing && root.ask !== null && root.askSent !== root.ask.n)
            root.sheetOpen = true;

    }

    onWantedChanged: {
        if (root.wanted)
            root.maybeCheck();

    }

    Connections {
        function onUpdateBetaChanged() {
            if (Prefs.updateBeta && root.current !== "")
                root.checkBeta();

        }

        target: Prefs
    }

    ListModel {
        id: logModel
    }

    IpcHandler {
        target: "updates"

        function check(): void {
            root.check();
        }

        function status(): string {
            return root.currentLabel + " — " + root.status;
        }

        function probe(): string {
            return root.repo + " | latest=" + root.latest + " | tag=" + root.latestTag + " | beta=" + root.betaShort + " | installed=" + root.installedSha.slice(0, 7) + " | flow=" + root.flow + " | run=" + root.run;
        }

        // the What's new sheet for this version
        function whatsnew(): void {
            root.showWhatsNew();
        }

        // the release update, warning first
        function update(): void {
            root.startUpdate("release");
        }

        function beta(): void {
            root.startUpdate("beta");
        }

        // brings back a hidden update sheet
        function show(): void {
            root.show();
        }

    }

    Process {
        id: fetcher

        // no -f: the http code is wanted even when it is an error
        command: ["curl", "-s", "--max-time", "15", "-H", "Accept: application/vnd.github+json", "-w", "\n%{http_code}", "https://api.github.com/repos/" + root.repo + "/releases/latest"]
        onExited: {
            root.busy = false;
            if (!root.gotResponse)
                root.problem = "offline";

        }

        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim();
                var cut = t.lastIndexOf("\n");
                var code = parseInt(cut === -1 ? t : t.slice(cut + 1), 10);
                var body = cut === -1 ? "" : t.slice(0, cut);
                if (!code)
                    return ;

                root.gotResponse = true;
                if (code === 404) {
                    // a real answer, not a failure: nothing is published yet
                    root.problem = "norelease";
                    root.checkedAt = Date.now();
                    root.save();
                } else if (code === 403 || code === 429)
                    root.problem = "ratelimited";
                else if (code !== 200)
                    root.problem = "offline";
                else
                    try {
                        root.take(body);
                    } catch (e) {
                        root.problem = "unreadable";
                    }
            }
        }

    }

    Process {
        id: betaFetcher

        command: ["curl", "-s", "--max-time", "15", "-H", "Accept: application/vnd.github+json", "-w", "\n%{http_code}", "https://api.github.com/repos/" + root.repo + "/commits/main"]
        onExited: (code) => {
            root.betaBusy = false;
            if (code !== 0 && root.betaProblem === "")
                root.betaProblem = "Could not reach GitHub. Lucid tries again later.";

        }

        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim();
                var cut = t.lastIndexOf("\n");
                var code = parseInt(cut === -1 ? t : t.slice(cut + 1), 10);
                if (code === 200) {
                    try {
                        root.takeBeta(t.slice(0, cut));
                    } catch (e) {
                        root.betaProblem = "GitHub answered with something Lucid could not read.";
                    }
                } else if (code === 403 || code === 429) {
                    root.betaProblem = "GitHub is rate-limiting this address. Lucid tries again later.";
                } else {
                    root.betaProblem = "Could not reach GitHub. Lucid tries again later.";
                }
            }
        }

    }

    // the runner's events, one json object a line; a reload reads them back from the top
    Process {
        id: follower

        stdout: SplitParser {
            onRead: (line) => {
                return root.event(line);
            }
        }

    }

    // answers to the runner's fifo. -p: never create a plain file in its place
    Process {
        id: writer

        command: ["sh", "-c", "[ -p \"$1\" ] && exec cat > \"$1\"", "sh", root.runDir + "/answers"]
        stdinEnabled: true
        onStarted: root.flush()
    }

    // a runner that died without a word still has to end the sheet
    Process {
        id: alive

        command: ["sh", "-c", "grep -qa updater.py /proc/$1/cmdline 2>/dev/null", "sh", String(root.runPid)]
        onExited: (code) => {
            if (!root.installing)
                return ;

            root.missed = code === 0 ? 0 : root.missed + 1;
            if (root.missed < 2)
                return ;

            root.result = {
                "ok": false,
                "reason": "crash",
                "text": "The updater stopped before it finished."
            };
            follower.running = false;
            writer.running = false;
            root.flow = "failed";
            root.settle();
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.installing && root.runPid > 0
        onTriggered: alive.running = true
    }

    // "remind me later" comes back here
    Timer {
        interval: 60000
        repeat: true
        running: root.remindAt > 0 && root.restartPending
        onTriggered: {
            if (Date.now() < root.remindAt || Lockscreen.locked)
                return ;

            root.remindAt = 0;
            root.runClosed = false;
            root.save();
            root.sheetOpen = true;
        }
    }

    Timer {
        interval: 3600000
        repeat: true
        running: true
        onTriggered: root.maybeCheck()
    }

    // let the session get a network up before the first look
    Timer {
        id: firstLook

        interval: 30000
        onTriggered: root.maybeCheck()
    }

    Component.onCompleted: firstLook.start()

    FileView {
        path: Qt.resolvedUrl("VERSION").toString().replace("file://", "")
        blockLoading: true
        printErrors: false
        onLoaded: root.current = text().trim().replace(/^v/i, "")
    }

    FileView {
        id: installedFile

        path: root.updateDir + "/installed.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                var p = JSON.parse(text());
                root.installedSha = p.sha || "";
                root.installedChannel = p.channel || "";
            } catch (e) {
            }
        }
    }

    FileView {
        id: stateFile

        path: Quickshell.env("HOME") + "/.cache/quickshell/lucid-updates.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                var p = JSON.parse(text());
                root.checkedAt = p.checkedAt || 0;
                root.latest = p.latest || "";
                root.latestTag = p.tag || "";
                root.latestName = p.name || "";
                root.latestUrl = p.url || root.releasesUrl;
                root.notified = p.notified || "";
                root.seen = p.seen || "";
                root.betaSha = p.betaSha || "";
                root.betaTitle = p.betaTitle || "";
                root.betaDate = p.betaDate || 0;
                root.run = p.run || "";
                root.runClosed = p.runClosed === true;
                root.remindAt = p.remindAt || 0;
            } catch (e) {
            }
            if (root.run !== "" && root.attached !== root.run)
                Qt.callLater(root.follow, true);

        }
    }

}
