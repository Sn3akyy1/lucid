pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

// the whole notification centre's state: the server, the history, the
// grouping, and the popup queue. the bar pill and the popup window are both
// views onto this.
Singleton {
    id: root

    // material symbols rounded, converted to a 24dp grid
    // material symbol names, drawn by NotifIcon
    readonly property var icons: ({
        "notifications": "notifications",
        "notifications_off": "notifications_off",
        "notifications_active": "notifications_active",
        "close": "close",
        "expand_more": "expand_more",
        "expand_less": "expand_less",
        "reply": "reply",
        "send": "send",
        "volume_off": "volume_off",
        "bedtime": "bedtime",
        "do_not_disturb_on": "do_not_disturb_on",
        "delete_sweep": "delete_sweep",
        "schedule": "schedule",
        "settings": "settings",
        "more_vert": "more_vert",
        "done_all": "done_all",
        "priority_high": "priority_high",
        "chevron_right": "chevron_right",
        "sync": "sync",
        "download": "download",
        "arrow_upward": "arrow_upward"
    })

    readonly property bool dnd: Prefs.doNotDisturb
    property int quietTick: 0
    readonly property bool quietNow: {
        root.quietTick;
        return Prefs.inQuietWindow(Loc.now());
    }
    readonly property bool fullscreenUp: {
        var t = Hyprland.activeToplevel;
        if (!t || !t.lastIpcObject)
            return false;

        return (t.lastIpcObject.fullscreen || 0) > 0;
    }
    // anything that should hold a popup back, however it was asked for
    readonly property bool silenced: root.dnd || root.quietNow || (Prefs.dndFullscreen && root.fullscreenUp)

    // dnd is derived, so callers cannot assign it — they go through here
    function toggleDnd() {
        Prefs.doNotDisturb = !Prefs.doNotDisturb;
    }

    function setDnd(v) {
        Prefs.doNotDisturb = v === true;
    }

    // ---- history ---------------------------------------------------------
    property var entries: []
    readonly property int count: root.entries.length
    readonly property int criticalCount: {
        var c = 0;
        for (var i = 0; i < root.entries.length; i++) {
            if (root.entries[i].urgency === NotificationUrgency.Critical)
                c++;

        }
        return c;
    }
    // id -> arrival ms, so cards can age
    property var arrivals: ({})
    property int timeTick: 0
    property bool trimming: false
    property bool ready: false

    signal shadeRequested()
    signal shadeCloseRequested()
    signal shadeToggleRequested()
    signal settingsRequested()

    // a card only plays its arrival once, and never for the backlog on startup
    property var shownIds: ({})
    property bool shownSeeded: false

    function markShown(id) {
        if (!root.shownSeeded) {
            for (const n of root.entries) root.shownIds[n.id] = true
            root.shownSeeded = true;
        }
        if (root.shownIds[id])
            return false;

        root.shownIds[id] = true;
        return true;
    }

    function stamp(n) {
        if (root.arrivals[n.id] === undefined)
            root.arrivals[n.id] = Loc.nowMs();

    }

    function rebuild() {
        if (root.trimming)
            return ;

        var v = notifServer.trackedNotifications ? notifServer.trackedNotifications.values.slice() : [];
        v.sort((a, b) => b.id - a.id);
        // dismissing re-enters this through onValuesChanged, so hold it off
        if (v.length > Prefs.notifMaxHistory) {
            root.trimming = true;
            for (const old of v.slice(Prefs.notifMaxHistory)) old.dismiss()
            root.trimming = false;
            v.length = Prefs.notifMaxHistory;
        }
        for (var i = 0; i < v.length; i++) root.stamp(v[i])
        root.entries = v;
        root.popupPrune(v);
        Prefs.liveNotifCount = v.length;
        root.regroup();
    }

    // ---- grouping --------------------------------------------------------
    property var expandedKeys: ({})
    property var rows: []

    function groupKey(n) {
        return (n.appName || n.desktopEntry || "Unknown").toLowerCase();
    }

    function isExpanded(key) {
        return root.expandedKeys[key] === true;
    }

    function expandAll() {
        var next = {};
        var anyCollapsed = false;
        for (var i = 0; i < root.rows.length; i++) {
            var r = root.rows[i];
            if (r.kind !== "group" || r.count < 2)
                continue;

            if (!root.isExpanded(r.key))
                anyCollapsed = true;

        }
        for (var j = 0; j < root.rows.length; j++) {
            var g = root.rows[j];
            if (g.kind === "group" && g.count > 1)
                next[g.key] = anyCollapsed;

        }
        root.expandedKeys = next;
        root.regroup();
    }

    function toggleGroup(key) {
        var next = {};
        for (var k in root.expandedKeys) next[k] = root.expandedKeys[k]
        next[key] = !next[key];
        root.expandedKeys = next;
        root.regroup();
    }

    // "new" is anything that landed while you were not looking
    function sectionOf(ms) {
        var now = Loc.nowMs();
        var age = now - ms;
        if (age < 300000)
            return 0;

        var d = new Date(ms);
        var today = Loc.now();
        if (d.toDateString() === today.toDateString())
            return 1;

        var y = new Date(today.getTime() - 86400000);
        if (d.toDateString() === y.toDateString())
            return 2;

        return 3;
    }

    readonly property var sectionNames: ["New", "Earlier today", "Yesterday", "Older"]

    function regroup() {
        root.timeTick;
        var out = [];
        var groups = [];
        if (Prefs.notifGrouping) {
            var byKey = ({});
            for (var i = 0; i < root.entries.length; i++) {
                var n = root.entries[i];
                var k = root.groupKey(n);
                if (byKey[k] === undefined) {
                    byKey[k] = groups.length;
                    groups.push({
                        "kind": "group",
                        "key": k,
                        "appName": n.appName || "Unknown",
                        "items": [n],
                        "newestMs": root.arrivals[n.id] || 0
                    });
                } else {
                    groups[byKey[k]].items.push(n);
                }
            }
        } else {
            for (var j = 0; j < root.entries.length; j++) {
                var e = root.entries[j];
                groups.push({
                    "kind": "group",
                    "key": "n" + e.id,
                    "appName": e.appName || "Unknown",
                    "items": [e],
                    "newestMs": root.arrivals[e.id] || 0
                });
            }
        }
        var lastSection = -1;
        for (var g = 0; g < groups.length; g++) {
            var grp = groups[g];
            grp.count = grp.items.length;
            grp.expanded = grp.count > 1 && root.isExpanded(grp.key);
            var s = root.sectionOf(grp.newestMs);
            if (s !== lastSection) {
                out.push({
                    "kind": "header",
                    "key": "h" + s,
                    "label": root.sectionNames[s],
                    "section": s
                });
                lastSection = s;
            }
            grp.section = s;
            out.push(grp);
        }
        root.rows = out;
    }

    // ---- actions ---------------------------------------------------------
    function dismiss(n) {
        if (!n)
            return ;

        root.popupDrop(n.id);
        n.dismiss();
    }

    function clearAll() {
        root.popupClear();
        root.trimming = true;
        for (const n of root.entries.slice()) n.dismiss()
        root.trimming = false;
        root.rebuild();
    }

    function clearGroup(key) {
        root.trimming = true;
        for (const n of root.entries.slice()) {
            if (root.groupKey(n) === key) {
                root.popupDrop(n.id);
                n.dismiss();
            }
        }
        root.trimming = false;
        root.rebuild();
    }

    // muting an app also clears what it has already put up
    function muteApp(name) {
        Prefs.setMuted(name, true);
        root.clearGroup((name || "Unknown").toLowerCase());
    }

    function relLabel(id) {
        root.timeTick;
        var t = root.arrivals[id];
        if (!t)
            return "";

        var s = Math.max(0, Math.floor((Loc.nowMs() - t) / 1000));
        if (s < 45)
            return "now";

        if (s < 3600)
            return Math.max(1, Math.round(s / 60)) + "m";

        if (s < 86400)
            return Math.floor(s / 3600) + "h";

        if (s < 604800)
            return Math.floor(s / 86400) + "d";

        return new Date(t).toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }

    // freedesktop progress lives in a hint, under two spellings
    function progressOf(n) {
        if (!n || !n.hints)
            return -1;

        var v = n.hints["value"];
        if (v === undefined)
            v = n.hints["x-kde-value"];

        if (v === undefined)
            return -1;

        var f = Number(v);
        return isNaN(f) ? -1 : Math.max(0, Math.min(100, f));
    }

    function hasProgress(n) {
        return Prefs.notifProgress && root.progressOf(n) >= 0;
    }

    function invokeAction(a) {
        // an action activates an application; the lock screen is not allowed to
        if (Lockscreen.locked)
            return ;

        try {
            if (a)
                a.invoke();

        } catch (e) {
        }
    }

    function canReply(n) {
        return Prefs.notifInlineReply && n && n.hasInlineReply;
    }

    function reply(n, text) {
        if (!n || !text || Lockscreen.locked)
            return ;

        n.sendInlineReply(text);
        root.popupDrop(n.id);
    }

    // ---- popup queue -----------------------------------------------------
    property var popups: []
    property var popupLeft: ({})
    property bool popupsPaused: false
    property int replyingId: -1
    readonly property bool replying: root.replyingId >= 0

    function popupLimit() {
        return Math.max(1, Math.min(6, Prefs.toastMaxVisible));
    }

    // 0 means it waits for you
    function toastMsFor(n) {
        if (!n)
            return Prefs.toastTimeout * 1000;

        if (Prefs.toastCriticalSticky && n.urgency === NotificationUrgency.Critical)
            return 0;

        if (n.expireTimeout === 0)
            return 0;

        if (Prefs.toastUseAppTimeout && n.expireTimeout > 0)
            return n.expireTimeout;

        return Prefs.toastTimeout * 1000;
    }

    function popupPush(n) {
        var ms = root.toastMsFor(n);
        var left = {};
        for (var k in root.popupLeft) left[k] = root.popupLeft[k]
        left[n.id] = ms <= 0 ? -1 : ms;
        var v = root.popups.filter((p) => p.id !== n.id);
        v.unshift(n);
        // the oldest falls off rather than the stack growing forever
        var limit = root.popupLimit();
        if (v.length > limit) {
            for (const gone of v.slice(limit)) delete left[gone.id]
            v.length = limit;
        }
        root.popupLeft = left;
        root.popups = v;
    }

    function popupDrop(id) {
        if (!root.popups.some((p) => p.id === id))
            return ;

        var left = {};
        for (var k in root.popupLeft) {
            if (Number(k) !== id)
                left[k] = root.popupLeft[k];

        }
        root.popupLeft = left;
        root.popups = root.popups.filter((p) => p.id !== id);
        if (root.replyingId === id)
            root.replyingId = -1;

    }

    // an application can close its own notification; its popup goes with it
    // instead of lingering as an empty card
    function popupPrune(live) {
        var ids = {};
        for (var i = 0; i < live.length; i++) ids[live[i].id] = true
        var gone = root.popups.filter((p) => {
            return !p || !ids[p.id];
        });
        if (gone.length === 0)
            return ;

        var left = {};
        for (var k in root.popupLeft) {
            if (ids[Number(k)])
                left[k] = root.popupLeft[k];

        }
        root.popupLeft = left;
        root.popups = root.popups.filter((p) => {
            return p && ids[p.id];
        });
        if (root.replyingId >= 0 && !ids[root.replyingId])
            root.replyingId = -1;

    }

    function popupClear() {
        root.popupLeft = ({});
        root.popups = [];
        root.replyingId = -1;
    }

    // the bar pill takes over once the shade is open
    function popupSuspend() {
        root.popupClear();
    }

    NotificationServer {
        id: notifServer

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true
        Component.onCompleted: root.rebuild()
        onNotification: (notification) => {
            Prefs.noteApp(notification.appName);
            // a muted application is turned away outright, never tracked
            if (Prefs.isMuted(notification.appName))
                return ;

            notification.tracked = true;
            root.stamp(notification);
            if (!root.ready)
                return ;

            const urgent = notification.urgency === NotificationUrgency.Critical;
            if (root.silenced && !(Prefs.dndAllowCritical && urgent))
                return ;

            root.playSound(notification);
            if (!Prefs.toastEnabled || root.shadeOpen)
                return ;

            root.popupPush(notification);
        }
    }

    // set by the bar pill while its panel is up
    property bool shadeOpen: false

    onShadeOpenChanged: {
        if (root.shadeOpen)
            root.popupSuspend();

    }

    function playSound(n) {
        if (!Prefs.notifSound || root.silenced)
            return ;

        if (Prefs.notifSoundUrgentOnly && n.urgency !== NotificationUrgency.Critical)
            return ;

        // a chat sending a run of messages chimes once, not once a message
        Sounds.play(Sounds.notifKey(Prefs.notifSoundName), Prefs.notifSoundVolume, 800);
    }

    // startup is noisy: let the session settle before anything pops
    Timer {
        interval: 300
        running: true
        onTriggered: root.ready = true
    }

    // one ticker drains every popup, so hovering can freeze them all at once
    Timer {
        id: popupTick

        readonly property int step: 100

        interval: popupTick.step
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            if (root.popupsPaused || root.replying)
                return ;

            var left = {};
            var expired = [];
            for (var i = 0; i < root.popups.length; i++) {
                var id = root.popups[i].id;
                var v = root.popupLeft[id];
                if (v === undefined || v < 0) {
                    left[id] = v === undefined ? -1 : v;
                    continue;
                }
                var nv = v - popupTick.step;
                if (nv <= 0)
                    expired.push(id);
                else
                    left[id] = nv;
            }
            root.popupLeft = left;
            if (expired.length > 0)
                root.popups = root.popups.filter((p) => expired.indexOf(p.id) < 0);

        }
    }

    // relative stamps and the section split both move on this
    Timer {
        interval: 20000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.timeTick++;
            root.regroup();
        }
    }

    Timer {
        interval: 20000
        repeat: true
        running: Prefs.quietHours
        triggeredOnStart: true
        onTriggered: root.quietTick++
    }

    // lastIpcObject only moves when something asks it to
    Timer {
        id: fullscreenPoll

        interval: 120
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "fullscreen" || event.name === "activewindowv2" || event.name === "closewindow")
                fullscreenPoll.restart();

        }

        enabled: Prefs.dndFullscreen
        target: Hyprland
    }

    Connections {
        function onNotificationsClearRequested() {
            root.clearAll();
        }

        target: Prefs
    }

    Connections {
        function onValuesChanged() {
            root.rebuild();
        }

        target: notifServer.trackedNotifications
    }

    Connections {
        function onNotifGroupingChanged() {
            root.regroup();
        }

        target: Prefs
    }

    IpcHandler {
        function toggleDnd(): void {
            root.toggleDnd();
        }

        function clear(): void {
            root.clearAll();
        }

        function open(): void {
            root.shadeRequested();
        }

        function close(): void {
            root.shadeCloseRequested();
        }

        function toggle(): void {
            root.shadeToggleRequested();
        }

        function settings(): void {
            root.settingsRequested();
        }

        function expandAll(): void {
            root.expandAll();
        }

        function count(): int {
            return root.count;
        }

        target: "notifs"
    }

}
