import QtQuick
import QtQuick.Window
import Quickshell
import qs
import qs.lucidui

// one lumen window: the places on the left, a bar with the way back and the
// path, tabs, and the folder itself in lucid's floating pane. every file action
// starts here and goes to the daemon through app.call
FloatingWindow {
    id: win

    required property var app
    required property string winId
    required property string startPath
    property string morePaths: ""
    // a tab torn off another window, as exportTab gave it: this window is made for it
    property string carryData: ""
    // the strip's chips by tab, for drags; the one under the open tab, for its pill
    property var chipItems: ({})
    property Item currentChip: null
    // a picture of the tab being dragged, drawn when it is pressed
    property url tabImage
    property var _prevTab: null
    // an app's open or save dialog this window answers, or "" for a plain window
    property string chooserData: ""
    readonly property var chooser: win.chooserData !== "" ? JSON.parse(win.chooserData) : null
    readonly property bool choosing: win.chooser !== null
    readonly property bool saving: win.choosing && win.chooser.mode !== "open"
    property int chooserFilter: win.choosing && win.chooser.filters.length > 0 ? Math.max(0, win.chooser.current) : -1
    readonly property var chooserRules: win.chooserFilter >= 0 ? win.chooser.filters[win.chooserFilter][1] : null
    property bool answered: false
    readonly property string chooserTitle: !win.choosing ? "" : (win.chooser.title || (win.chooser.mode === "open" ? (win.chooser.directory ? "Choose a folder" : "Open a file") : "Save a file"))
    readonly property string acceptLabel: !win.choosing ? "" : (win.chooser.accept.replace(/_/g, "") || (win.chooser.mode === "open" ? (win.chooser.directory ? "Select" : "Open") : "Save"))
    readonly property bool canAccept: {
        var t = win.tab;
        if (!win.choosing || !t || (t.rev < 0))
            return false;

        if (win.chooser.mode === "save")
            return !t.isSpecial && saveName.text.trim() !== "" && saveName.text.indexOf("/") === -1;

        if (win.chooser.mode === "saveFiles" || win.chooser.directory)
            return !t.isSpecial || t.selCount > 0;

        return t.selCount > 0;
    }

    onChooserRulesChanged: {
        win.eachTab(function(t) {
            t.rules = win.chooserRules;
            t.apply();
        });
    }

    // the answer goes back to the app, and the window with it
    function answer(uris, cancel) {
        if (win.answered || !win.choosing)
            return ;

        win.answered = true;
        if (!cancel && win.tab && !win.tab.isSpecial)
            win.app.prefs.chooserFolder = win.tab.path;

        win.app.call("chosen", {
            "chooser": win.chooser.id,
            "uris": uris,
            "filter": win.chooserFilter,
            "cancel": cancel === true
        });
        win.visible = false;
        win.app.closeWindow(win.winId);
    }

    // what the main button does: the picked files, the picked or open folder, or
    // the name to save under (asking first before it replaces anything)
    function acceptChooser() {
        var t = win.tab, c = win.chooser;
        if (!win.choosing || !t)
            return ;

        var sel = t.selectedItems();
        if (c.mode === "open") {
            if (c.directory) {
                var dirs = sel.filter(function(it) {
                    return it.kind === "dir";
                });
                if (dirs.length === 0 && !t.isSpecial)
                    dirs = [{
                    "uri": win.app.uriOf(t.path)
                }];

                if (dirs.length > 0)
                    win.answer((c.multiple ? dirs : dirs.slice(0, 1)).map(win.fileUri));

                return ;
            }
            // one folder picked opens, so Enter walks down to the file
            if (sel.length === 1 && sel[0].kind === "dir") {
                win.go(sel[0].path || sel[0].target || sel[0].uri);
                return ;
            }
            var files = sel.filter(function(it) {
                return it.kind !== "dir";
            });
            if (files.length > 0)
                win.answer((c.multiple ? files : files.slice(0, 1)).map(win.fileUri));

            return ;
        }
        if (t.isSpecial)
            return ;

        if (c.mode === "saveFiles") {
            win.answer(c.files.map(function(f) {
                return win.app.uriOf(t.path + "/" + f);
            }));
            return ;
        }
        var name = saveName.text.trim();
        if (name === "" || name.indexOf("/") !== -1)
            return ;

        var hit = t.raw.find(function(it) {
            return it.name === name;
        });
        // a folder's name goes into the folder, as gtk's dialog does
        if (hit && hit.kind === "dir") {
            saveName.text = c.name;
            win.go(hit.path);
            return ;
        }
        var uri = win.app.uriOf(t.path + "/" + name);
        if (hit) {
            dialog.ask({
                "title": "Replace “" + name + "”?",
                "text": "There is already a file with this name in " + t.title + ". Saving puts the new one in its place.",
                "confirm": "Replace",
                "danger": true
            }, function(ok) {
                if (ok)
                    win.answer([uri]);

            });
            return ;
        }
        win.answer([uri]);
    }

    // what an app is handed: a file on a share as its folder path, which every
    // app can open, not its sftp:// or ftp:// address, which few can
    function fileUri(it) {
        return it.path ? win.app.uriOf(it.path) : it.uri;
    }

    function cancelChooser() {
        win.answer([], true);
    }

    // what a filter's rules let through, said short: ".png, .jpg and 3 more"
    function ruleHint(rules) {
        var out = [];
        var kinds = {
            "image": "images",
            "video": "videos",
            "audio": "audio",
            "text": "text files",
            "font": "fonts"
        };
        for (var i = 0; i < rules.length; i++) {
            var kind = rules[i][0], pat = String(rules[i][1]);
            var say = "";
            if (pat === "*" || pat === "*.*" || pat === "*/*")
                return "Every file";

            if (kind === 1) {
                var parts = pat.split("/");
                if (parts[1] === "*")
                    say = "All " + (kinds[parts[0]] || parts[0] + " files");
                else
                    say = (parts[1] || pat).replace(/^(x-|vnd\.)/, "");
            } else {
                // gtk writes a case-blind glob as *.[pP][nN][gG]
                say = pat.replace(/\[([a-zA-Z])([a-zA-Z])\]/g, function(m, a, b) {
                    return a.toLowerCase() === b.toLowerCase() ? a.toLowerCase() : m;
                }).replace(/^\*\./, ".");
            }
            if (out.indexOf(say) < 0)
                out.push(say);

        }
        if (out.length > 4)
            return out.slice(0, 3).join(", ") + " and " + (out.length - 3) + " more";

        return out.join(", ");
    }
    property var tabs: []
    property int currentIndex: 0
    readonly property var tab: win.tabs.length > 0 ? win.tabs[Math.max(0, Math.min(win.currentIndex, win.tabs.length - 1))] : null
    property var cutSet: ({})
    property int cutRev: 0
    property string pendingSelect: ""
    property var templates: []
    property alias contentRoot: root
    property alias pane: folderPane
    readonly property bool isActive: root.Window.active
    readonly property bool overlayOpen: menu.shown || dialog.shown || server.shown || kindField.shown
    // too narrow for the sidebar beside the folder: it slides over it instead
    readonly property bool narrow: root.width < Theme.dp(700)
    property bool drawer: false
    readonly property real dockWidth: win.narrow ? 0 : sidebar.width
    // where the sidebar is going, and how much wider the folder will be once it
    // is there: the grid takes its columns from that, so it never jumps a column
    // part way through the slide, its cells stretching instead
    readonly property real dockTarget: win.narrow ? 0 : (win.app.prefs.sidebar ? Theme.dp(236) : 0)
    readonly property real settleDelta: Math.max(Theme.dp(12), win.dockWidth) - Math.max(Theme.dp(12), win.dockTarget)
    // the preview pane's room on the right (its width and the gap before it), and
    // where that is going: a window too narrow for it leaves it off for now
    readonly property real previewTarget: win.app.prefs.preview && root.width >= Theme.dp(900) ? Theme.dp(312) : 0
    property real previewW: win.previewTarget

    Behavior on previewW {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    onNarrowChanged: win.drawer = false

    // switching tabs slides the folder in from the side the new tab is on
    onTabChanged: {
        win.syncSearch();
        if (win._prevTab && win.tab && win._prevTab !== win.tab) {
            var was = win.tabs.indexOf(win._prevTab);
            folderPane.pushFrom(was < 0 || win.tabs.indexOf(win.tab) > was ? 1 : -1);
        }
        win._prevTab = win.tab;
    }

    // ---- tabs

    // the strip's rows follow win.tabs. a tab gone stays a row, marked leaving,
    // while it folds away (dropTabRow takes it out), so its neighbours close up
    // with it instead of jumping
    function syncTabs() {
        var moved = false;
        var want = win.tabs.map(function(t) {
            return t.vid;
        });
        for (var r = 0; r < tabModel.count; r++) {
            if (!tabModel.get(r).leaving && want.indexOf(tabModel.get(r).vid) < 0)
                tabModel.setProperty(r, "leaving", true);

        }
        for (var i = 0; i < want.length; i++) {
            var at = win.liveRow(i);
            if (at < tabModel.count && tabModel.get(at).vid === want[i])
                continue;

            var found = -1;
            for (var j = 0; j < tabModel.count; j++) {
                if (!tabModel.get(j).leaving && tabModel.get(j).vid === want[i]) {
                    found = j;
                    break;
                }
            }
            if (found >= 0) {
                tabModel.move(found, at, 1);
                moved = true;
            } else {
                tabModel.insert(at, {
                    "vid": want[i],
                    "leaving": false
                });
            }
        }
        if (moved)
            tabStrip.relayout(true);

    }

    // the row the n-th tab is on, counting past the leaving ones
    function liveRow(n) {
        var seen = 0;
        for (var r = 0; r < tabModel.count; r++) {
            if (tabModel.get(r).leaving)
                continue;

            if (seen === n)
                return r;

            seen++;
        }
        return tabModel.count;
    }

    function dropTabRow(vid) {
        for (var r = 0; r < tabModel.count; r++) {
            if (tabModel.get(r).vid === vid && tabModel.get(r).leaving) {
                tabModel.remove(r);
                return ;
            }
        }
    }

    // what a tab takes with it to another window
    function exportTab(t) {
        return {
            "path": t.path,
            "back": t.back.slice(),
            "forward": t.forward.slice(),
            "colour": t.colour
        };
    }

    function adoptTab(state, at) {
        var t = win.newTab(state.path, false, false, {
            "at": Math.max(win.pinnedCount, Math.min(at, win.tabs.length)),
            "colour": state.colour || ""
        });
        t.back = state.back || [];
        t.forward = state.forward || [];
        return t;
    }

    // a tab leaving for another window: no trace in reopen, and a window left
    // with no tab goes
    function releaseTab(vid) {
        var t = win.tabFor(vid);
        if (!t)
            return ;

        if (win.tabs.length <= 1) {
            win.visible = false;
            win.app.closeWindow(win.winId);
            return ;
        }
        var cur = win.tab;
        var i = win.tabs.indexOf(t);
        var list = win.tabs.slice();
        list.splice(i, 1);
        win.tabs = list;
        win.currentIndex = t === cur ? Math.min(i, list.length - 1) : Math.max(0, list.indexOf(cur));
        t.destroy();
    }

    // dropped where no strip took it: a window of its own, unless it is this
    // window's only tab, which is one already
    function tearOffTab(vid) {
        var t = win.tabFor(vid);
        if (!t || t.pinned || win.choosing || win.tabs.length <= 1)
            return ;

        var state = win.exportTab(t);
        win.releaseTab(vid);
        win.app.tearOff(state);
    }

    function chipOf(vid) {
        return win.chipItems[vid] || null;
    }

    onTabsChanged: win.syncTabs()

    // new tabs open beside the one in use, never in among the pinned ones
    function newTab(path, background, lookFirst, opts) {
        var o = opts || ({});
        var t = tabComp.createObject(win, {
            "app": win.app,
            "vid": win.app.nextView(),
            "rules": win.chooserRules,
            "pinned": o.pinned === true,
            "pinKey": o.pinKey || "",
            "colour": o.colour || ""
        });
        var list = win.tabs.slice();
        var at = o.at !== undefined ? o.at : Math.max(win.pinnedCount, Math.min(list.length, win.currentIndex + 1));
        list.splice(at, 0, t);
        win.tabs = list;
        if (!background)
            win.currentIndex = at;

        if (lookFirst)
            win.openStart(t, path || win.app.home);
        else
            t.go(path || win.app.home);
        return t;
    }

    // a path from outside may be a file: its folder opens with it picked
    function openStart(t, p) {
        if (p.indexOf("://") !== -1) {
            t.go(p);
            return ;
        }
        win.app.call("info", {
            "uri": win.app.uriOf(p)
        }, function(r) {
            if (r.ok && !r.isDir && r.where) {
                if (t === win.tab)
                    win.pendingSelect = r.name;

                t.go(r.where);
            } else {
                t.go(p);
            }
        });
    }

    readonly property int pinnedCount: {
        var n = 0;
        for (var i = 0; i < win.tabs.length; i++) {
            if (win.tabs[i].pinned)
                n++;

        }
        return n;
    }
    // what closed, newest last, for ctrl+shift+t
    property var closedTabs: []

    // a pinned tab only goes when asked by name (force): its menu's close
    function closeTab(i, force) {
        var t = win.tabs[i];
        if (!t)
            return ;

        if (t.pinned && !force) {
            win.say("Pinned tabs stay open. Unpin it to close it");
            return ;
        }
        if (t.pinned)
            win.app.dropPin(t.pinKey);

        if (t.path !== "")
            win.closedTabs = win.closedTabs.slice(-19).concat([{
            "path": t.path,
            "colour": t.colour
        }]);

        if (win.tabs.length <= 1) {
            if (win.choosing) {
                win.cancelChooser();
                return ;
            }
            win.visible = false;
            win.app.closeWindow(win.winId);
            return ;
        }
        var list = win.tabs.slice();
        var gone = list.splice(i, 1)[0];
        win.tabs = list;
        if (win.currentIndex >= list.length || win.currentIndex > i)
            win.currentIndex = Math.max(0, win.currentIndex - 1);

        gone.destroy();
    }

    function switchTab(i) {
        if (i >= 0 && i < win.tabs.length)
            win.currentIndex = i;

    }

    function moveTab(from, to) {
        if (from === to || from < 0 || to < 0 || from >= win.tabs.length || to >= win.tabs.length)
            return ;

        var cur = win.tab;
        var list = win.tabs.slice();
        var t = list.splice(from, 1)[0];
        list.splice(to, 0, t);
        win.tabs = list;
        win.currentIndex = Math.max(0, list.indexOf(cur));
    }

    // a pinned tab joins the end of the pinned ones and is kept for new windows
    function pinTab(i) {
        var t = win.tabs[i];
        if (!t || t.pinned)
            return ;

        var at = win.pinnedCount;
        t.pinKey = "p" + Date.now().toString(36) + Math.floor(Math.random() * 1000);
        t.pinned = true;
        win.app.addPin(t.pinKey, t.path, t.colour);
        win.moveTab(i, at);
    }

    function unpinTab(i) {
        var t = win.tabs[i];
        if (!t || !t.pinned)
            return ;

        win.app.dropPin(t.pinKey);
        t.pinned = false;
        t.pinKey = "";
        win.moveTab(i, win.pinnedCount);
    }

    function colourTab(i, id) {
        var t = win.tabs[i];
        if (!t)
            return ;

        t.colour = id;
        if (t.pinned)
            win.app.updatePin(t.pinKey, {
            "colour": id
        });

    }

    function closeOtherTabs(keep) {
        var k = win.tabs[keep];
        for (var i = win.tabs.length - 1; i >= 0; i--) {
            if (win.tabs[i] !== k && !win.tabs[i].pinned)
                win.closeTab(i);

        }
        win.currentIndex = Math.max(0, win.tabs.indexOf(k));
    }

    function closeTabsRight(from) {
        var k = win.tabs[from];
        for (var i = win.tabs.length - 1; i > from; i--) {
            if (!win.tabs[i].pinned)
                win.closeTab(i);

        }
        win.currentIndex = Math.max(0, win.tabs.indexOf(k));
    }

    function reopenTab() {
        if (win.closedTabs.length === 0)
            return ;

        var last = win.closedTabs[win.closedTabs.length - 1];
        win.closedTabs = win.closedTabs.slice(0, -1);
        win.newTab(last.path, false, false, {
            "colour": last.colour
        });
    }

    // a row of the colours, ticked on the one in use; the first takes it off
    function colourRow(current) {
        return [{
            "swatches": [{
                "id": "colour:",
                "tip": "No colour",
                "checked": current === ""
            }].concat(win.app.colours.map(function(c) {
                return {
                    "id": "colour:" + c.id,
                    "tip": c.name,
                    "color": win.app.ink(c.id),
                    "checked": current === c.id
                };
            }))
        }];
    }

    function tabMenu(i, x, y) {
        var t = win.tabs[i];
        if (!t)
            return ;

        var right = 0;
        for (var r = i + 1; r < win.tabs.length; r++) {
            if (!win.tabs[r].pinned)
                right++;

        }
        menu.open(win.clean([{
            "id": "new",
            "label": "New tab",
            "icon": "add",
            "hint": "Ctrl+T"
        }, {
            "id": "duplicate",
            "label": "Duplicate tab",
            "icon": "content_copy"
        }, !win.choosing ? {
            "id": "pin",
            "label": t.pinned ? "Unpin tab" : "Pin tab",
            "icon": t.pinned ? "keep_off" : "keep"
        } : null, {
            "id": "colour",
            "label": "Colour",
            "icon": "palette",
            "sub": win.colourRow(t.colour)
        }, {
            "sep": true
        }, {
            "id": "close",
            "label": "Close tab",
            "icon": "close",
            "hint": t.pinned ? "" : "Ctrl+W"
        }, win.tabs.length - win.pinnedCount > (t.pinned ? 0 : 1) ? {
            "id": "others",
            "label": "Close other tabs",
            "icon": "tab"
        } : null, right > 0 ? {
            "id": "right",
            "label": "Close tabs to the right",
            "icon": "keyboard_tab"
        } : null, win.closedTabs.length > 0 ? {
            "sep": true
        } : null, win.closedTabs.length > 0 ? {
            "id": "reopen",
            "label": "Reopen closed tab",
            "icon": "undo",
            "hint": "Ctrl+Shift+T"
        } : null]), x, y, function(id) {
            var at = win.tabs.indexOf(t);
            if (id.indexOf("colour:") === 0)
                win.colourTab(at, id.slice(7));
            else if (id === "new")
                win.newTab(t.path);
            else if (id === "duplicate")
                win.newTab(t.path, false, false, {
                "at": t.pinned ? win.pinnedCount : at + 1,
                "colour": t.colour
            });
            else if (id === "pin")
                t.pinned ? win.unpinTab(at) : win.pinTab(at);
            else if (id === "close")
                win.closeTab(at, true);
            else if (id === "others")
                win.closeOtherTabs(at);
            else if (id === "right")
                win.closeTabsRight(at);
            else if (id === "reopen")
                win.reopenTab();
        });
    }

    function eachTab(fn) {
        for (var i = 0; i < win.tabs.length; i++) fn(win.tabs[i])
    }

    function tabFor(vid) {
        for (var i = 0; i < win.tabs.length; i++) {
            if (win.tabs[i].vid === vid)
                return win.tabs[i];

        }
        return null;
    }

    // ---- moving around

    function go(path) {
        if (win.tab)
            win.tab.go(path);

        folderPane.takeFocus();
    }

    function goTyped(text) {
        var p = text.trim();
        // windows' way to write a share: \\server\share\folder
        if (/^\\\\[^\\]/.test(p))
            p = "smb://" + p.slice(2).replace(/\\/g, "/");

        // another computer's address: the tab connects to it, and it joins the recent servers
        if (win.app.isAddress(p)) {
            win.tab.rememberNext = p;
            win.go(p);
            return ;
        }
        if (p.indexOf("://") === -1)
            p = win.app.normalise(p.charAt(0) === "/" || p.charAt(0) === "~" ? p : win.tab.path + "/" + p);

        if (p.indexOf("trash:") === 0 || p.indexOf("recent:") === 0) {
            win.go(p);
            return ;
        }
        win.app.call("info", {
            "uri": p.indexOf("://") !== -1 ? p : win.app.uriOf(p)
        }, function(r) {
            if (!r.ok) {
                win.say("Can't find “" + text + "”");
                return ;
            }
            if (r.isDir) {
                win.go(r.path || p);
            } else {
                // a file's path opens its folder with the file picked
                win.pendingSelect = r.name;
                win.go(r.where);
            }
        });
    }

    function openIndex(i, inNewTab) {
        var it = win.tab.model.get(i);
        // in a dialog a file is the answer, or the name to save over
        if (win.choosing && it.kind !== "dir") {
            if (win.chooser.mode === "open" && !win.chooser.directory) {
                win.answer([win.fileUri(it)]);
                return ;
            }
            if (win.chooser.mode === "save") {
                saveName.text = it.name;
                win.acceptChooser();
                return ;
            }
        }
        if (it.kind === "dir" && !win.tab.isTrash) {
            // a computer the network found, a server's share: somewhere to connect to
            var where = it.path || it.target || it.uri;
            if (inNewTab)
                win.newTab(where, true);
            else
                win.go(where);
        } else if (win.tab.isTrash) {
            win.say("Restore it to open it");
        } else {
            win.app.call("open", {
                "uris": [it.uri]
            }, win.opened);
        }
    }

    function openSelection(inNewTabs) {
        if (win.choosing) {
            win.acceptChooser();
            return ;
        }
        var sel = win.tab.selectedItems();
        if (sel.length === 0)
            return ;

        var dirs = sel.filter(function(it) {
            return it.kind === "dir";
        });
        var files = sel.filter(function(it) {
            return it.kind !== "dir";
        });
        if (win.tab.isTrash) {
            win.say("Restore it to open it");
            return ;
        }
        if (files.length > 0)
            win.app.call("open", {
            "uris": files.map(function(it) {
                return it.uri;
            })
        }, win.opened);

        if (dirs.length === 1 && files.length === 0 && !inNewTabs)
            win.go(dirs[0].path || dirs[0].target || dirs[0].uri);
        else
            for (var k = 0; k < dirs.length; k++) win.newTab(dirs[k].path || dirs[k].target || dirs[k].uri, true)
    }

    function say(text, action, payload) {
        snack.show(text, action, payload);
    }

    function selectionUris() {
        return win.tab.selectedItems().map(function(it) {
            return it.uri;
        });
    }

    function namesHere(except) {
        var out = [];
        for (var k = 0; k < win.tab.model.count; k++) {
            var n = win.tab.model.get(k).name;
            if (n !== except)
                out.push(n);

        }
        return out;
    }

    function freeName(base) {
        var taken = win.namesHere("");
        if (taken.indexOf(base) === -1)
            return base;

        var stem = base, ext = "";
        var dot = base.lastIndexOf(".");
        if (dot > 0) {
            stem = base.slice(0, dot);
            ext = base.slice(dot);
        }
        for (var n = 2; ; n++) {
            var name = stem + " " + n + ext;
            if (taken.indexOf(name) === -1)
                return name;

        }
    }

    // ---- file actions

    function trashUris(uris) {
        if (uris.length === 0)
            return ;

        win.app.call("trash", {
            "uris": uris
        }, function(r) {
            var done = r.done || [];
            if (done.length > 0) {
                var entry = {
                    "kind": "trash",
                    "paths": done.map(function(d) {
                        return d.path;
                    })
                };
                win.app.pushUndo(entry);
                win.say("Moved " + (done.length === 1 ? "“" + done[0].path.split("/").pop() + "”" : done.length + " items") + " to Trash", "Undo", entry);
            }
            var failed = r.failed || [];
            if (failed.length > 0)
                dialog.ask({
                "title": "Delete permanently?",
                "text": (failed.length === 1 ? "“" + decodeURIComponent(failed[0].uri.split("/").pop()) + "” can't go to the trash here" : failed.length + " items can't go to the trash here") + ". Deleting can't be undone.",
                "confirm": "Delete",
                "danger": true
            }, function(ok) {
                if (ok)
                    win.deleteUris(failed.map(function(f) {
                    return f.uri;
                }));

            });

        });
    }

    function trashSelection() {
        if (!win.tab || win.tab.selCount === 0)
            return ;

        if (win.tab.isTrash) {
            win.deleteSelection();
            return ;
        }
        if (win.tab.isRecent) {
            win.say("Recent only lists files; open their folder to remove them");
            return ;
        }
        win.trashUris(win.selectionUris());
    }

    function deleteUris(uris) {
        win.app.call("delete", {
            "uris": uris
        }, function(r) {
            var n = (r.done || []).length;
            if (n > 0)
                win.say("Deleted " + (n === 1 ? "1 item" : n + " items"));

            if ((r.failed || []).length > 0)
                win.say(r.failed[0].error);

        });
    }

    function deleteSelection() {
        var sel = win.tab.selectedItems();
        if (sel.length === 0)
            return ;

        dialog.ask({
            "title": sel.length === 1 ? "Delete “" + sel[0].label + "” for good?" : "Delete " + sel.length + " items for good?",
            "text": "They won't go to the trash, and this can't be undone.",
            "confirm": "Delete",
            "danger": true
        }, function(ok) {
            if (ok)
                win.deleteUris(sel.map(function(it) {
                return it.uri;
            }));

        });
    }

    function restoreSelection() {
        win.app.call("restore", {
            "uris": win.selectionUris()
        }, function(r) {
            var n = (r.restored || []).length;
            win.say(r.ok ? "Restored " + (n === 1 ? "“" + r.restored[0].split("/").pop() + "”" : n + " items") : (r.error || "Could not restore"));
        });
    }

    function emptyTrash() {
        dialog.ask({
            "title": "Empty the trash?",
            "text": "Everything in it (" + win.app.trashCount + (win.app.trashCount === 1 ? " item" : " items") + ") is deleted for good.",
            "confirm": "Empty trash",
            "danger": true
        }, function(ok) {
            if (ok)
                win.app.call("emptyTrash", {
            }, function() {
                win.say("Trash emptied");
            });

        });
    }

    function copySelection(cut) {
        var uris = win.selectionUris();
        if (uris.length === 0 || win.tab.isTrash)
            return ;

        win.app.call("clipCopy", {
            "mode": cut ? "cut" : "copy",
            "uris": win.tab.selectedItems().map(folderPane.outUri)
        });
        var s = ({});
        if (cut)
            for (var k = 0; k < uris.length; k++) s[uris[k]] = true

        win.cutSet = s;
        win.cutRev++;
        win.say((uris.length === 1 ? "1 item" : uris.length + " items") + (cut ? " ready to move" : " copied"));
    }

    function paste(dest) {
        if (!dest || win.tab.isSpecial)
            return ;

        win.app.call("clipRead", {
        }, function(r) {
            var uris = r.uris || [];
            if (uris.length > 0) {
                var move = r.mode === "cut";
                win.app.transfer(move ? "move" : "copy", uris, dest);
                if (move) {
                    win.cutSet = ({});
                    win.cutRev++;
                    win.app.call("clipClear", {
                    });
                }
            } else if (r.image) {
                win.app.call("pasteImage", {
                    "dest": dest
                }, function(p) {
                    if (p.ok)
                        win.pendingSelect = p.name;

                });
            } else {
                win.say("Nothing to paste");
            }
        });
    }

    function renameSelection() {
        var sel = win.tab.selectedItems();
        if (sel.length !== 1 || win.tab.isSpecial)
            return ;

        var it = sel[0];
        var dot = it.kind === "dir" ? -1 : it.name.lastIndexOf(".");
        dialog.ask({
            "mode": "input",
            "title": "Rename",
            "input": it.name,
            "selectEnd": dot > 0 ? dot : it.name.length,
            "taken": win.namesHere(it.name),
            "confirm": "Rename"
        }, function(ok, name) {
            if (!ok || name === it.name)
                return ;

            win.app.call("rename", {
                "uri": it.uri,
                "name": name
            }, function(r) {
                if (!r.ok) {
                    win.say(r.error || "Could not rename");
                    return ;
                }
                win.app.pushUndo({
                    "kind": "rename",
                    "uri": r.uri,
                    "name": it.name
                });
                win.pendingSelect = name;
            });
        });
    }

    function newFolder() {
        if (!win.tab || win.tab.isSpecial || win.tab.searching)
            return ;

        var dest = win.tab.path;
        dialog.ask({
            "mode": "input",
            "title": "New folder",
            "input": win.freeName("New Folder"),
            "taken": win.namesHere(""),
            "confirm": "Create"
        }, function(ok, name) {
            if (!ok)
                return ;

            win.app.call("mkdir", {
                "dest": dest,
                "name": name
            }, function(r) {
                if (!r.ok) {
                    win.say(r.error || "Could not make the folder");
                    return ;
                }
                win.app.pushUndo({
                    "kind": "create",
                    "made": [r.path]
                });
                win.pendingSelect = r.name;
            });
        });
    }

    function newDocument(template) {
        if (!win.tab || win.tab.isSpecial || win.tab.searching)
            return ;

        var dest = win.tab.path;
        var base = template ? template.split("/").pop() : "New Document.txt";
        var name = win.freeName(base);
        var dot = name.lastIndexOf(".");
        dialog.ask({
            "mode": "input",
            "title": "New document",
            "input": name,
            "selectEnd": dot > 0 ? dot : name.length,
            "taken": win.namesHere(""),
            "confirm": "Create"
        }, function(ok, chosen) {
            if (!ok)
                return ;

            win.app.call("newFile", template ? {
                "dest": dest,
                "template": template,
                "name": chosen
            } : {
                "dest": dest,
                "name": chosen
            }, function(r) {
                if (!r.ok) {
                    win.say(r.error || "Could not make the file");
                    return ;
                }
                win.app.pushUndo({
                    "kind": "create",
                    "made": [r.path]
                });
                win.pendingSelect = r.name;
            });
        });
    }

    function openWith() {
        var sel = win.tab.selectedItems();
        if (sel.length === 0)
            return ;

        win.app.call("appsFor", {
            "uri": sel[0].uri
        }, function(r) {
            if (!r.ok || (r.apps || []).length === 0) {
                win.say("No app opens this kind of file");
                return ;
            }
            dialog.ask({
                "mode": "apps",
                "title": "Open with",
                "text": sel.length === 1 ? "“" + sel[0].label + "”" : sel.length + " items",
                "apps": r.apps,
                "confirm": "Open"
            }, function(ok, v) {
                if (!ok || !v.app)
                    return ;

                win.app.call("openWith", {
                    "app": v.app.id,
                    "uris": sel.map(function(it) {
                        return it.uri;
                    }),
                    "makeDefault": v.always,
                    "mime": r.mime
                });
            });
        });
    }

    function properties(item) {
        var sel = item ? [item] : win.tab.selectedItems();
        if (sel.length > 1) {
            win.summary(sel);
            return ;
        }
        var it = sel[0] || null;
        var uri = it ? it.uri : win.app.uriOf(win.tab.path);
        if (!it && win.tab.isSpecial)
            return ;

        var req = win.app.call("info", {
            "uri": uri
        }, function(r) {
            if (!r.ok) {
                win.say(r.error || "Could not read it");
                return ;
            }
            var rows = [{
                "key": "type",
                "label": "Type",
                "value": r.isDir ? "Folder" : (r.desc || r.mime)
            }, {
                "key": "size",
                "label": "Size",
                "value": r.isDir ? "Counting…" : win.app.sizeText(r.size) + " (" + r.size.toLocaleString(Qt.locale(), "f", 0) + " bytes)"
            }, {
                "key": "where",
                "label": "Location",
                "value": (r.where || "").replace(win.app.home, "~")
            }, {
                "key": "modified",
                "label": "Modified",
                "value": new Date(r.mtime * 1000).toLocaleString(Qt.locale(), "d MMMM yyyy, hh:mm")
            }];
            if (r.atime)
                rows.push({
                "key": "accessed",
                "label": "Opened",
                "value": new Date(r.atime * 1000).toLocaleString(Qt.locale(), "d MMMM yyyy, hh:mm")
            });

            if (r.target)
                rows.push({
                "key": "target",
                "label": "Links to",
                "value": r.target
            });

            rows.push({
                "key": "perms",
                "label": "Permissions",
                "value": r.mode + (r.octal ? "  (" + r.octal + ")" : "")
            });
            rows.push({
                "key": "owner",
                "label": "Owner",
                "value": r.owner + (r.group && r.group !== r.owner ? " · " + r.group : "")
            });
            if (r.total > 0)
                rows.push({
                "key": "free",
                "label": "Free space",
                "value": win.app.sizeText(r.free) + " of " + win.app.sizeText(r.total)
            });

            win.infoReq = r.id;
            dialog.ask({
                "mode": "info",
                "title": r.name,
                "rows": rows,
                "glyph": {
                    "slot": it ? it.slot : r.slot,
                    "thumb": it ? it.thumb : "",
                    "icon": it ? it.icon : "",
                    "kind": it ? it.kind : "dir",
                    "legacy": win.app.legacyIcons
                }
            });
        });
    }

    // several things at once: what they are and what they weigh, without walking folders
    function summary(sel) {
        var dirs = 0, files = 0, bytes = 0, wheres = ({}), n = 0;
        for (var i = 0; i < sel.length; i++) {
            if (sel[i].kind === "dir") {
                dirs++;
            } else {
                files++;
                bytes += sel[i].size || 0;
            }
            var w = sel[i].orig ? win.app.parentOf(sel[i].orig) : win.app.parentOf(sel[i].path || sel[i].uri);
            if (!wheres[w]) {
                wheres[w] = true;
                n++;
            }
        }
        var parts = [];
        if (dirs > 0)
            parts.push(dirs + (dirs === 1 ? " folder" : " folders"));

        if (files > 0)
            parts.push(files + (files === 1 ? " file" : " files"));

        var rows = [{
            "key": "type",
            "label": "Contains",
            "value": parts.join(", ")
        }, {
            "key": "size",
            "label": "Size",
            "value": files > 0 ? win.app.sizeText(bytes) + (dirs > 0 ? ", not counting the folders" : "") : "Folders only"
        }, {
            "key": "where",
            "label": "Location",
            "value": n === 1 ? Object.keys(wheres)[0].replace(win.app.home, "~") : n + " places"
        }];
        dialog.ask({
            "mode": "info",
            "title": sel.length + " items",
            "rows": rows,
            "glyph": {
                "slot": dirs > 0 ? "folder" : "file",
                "kind": dirs > 0 ? "dir" : "file"
            }
        });
    }

    property int infoReq: -1

    function copyPath() {
        var sel = win.tab.selectedItems();
        var paths = sel.length > 0 ? sel.map(function(it) {
            return it.path || it.uri;
        }) : [win.tab.path];
        win.app.call("clipText", {
            "text": paths.join("\n")
        });
        win.say(paths.length === 1 ? "Path copied" : paths.length + " paths copied");
    }

    function unmount(v) {
        win.app.call("unmount", {
            "volume": v.id,
            "eject": v.canEject
        }, function(r) {
            if (v.remote)
                win.say(r.ok ? "Disconnected from “" + v.label + "”" : (r.error || "Could not disconnect"));
            else
                win.say(r.ok ? "“" + v.label + "” can be removed" : (r.error || "Could not eject it"));
        });
    }

    // ---- other computers

    // the connect dialog: an address, or a server from before
    function connectServer(address) {
        server.openAddress(address || "");
    }

    // connect to an address, then go to its folder: in the tab given, else
    // this window's own. what the server asks shows in this window. returns
    // the connection's id; done(reply) hears how it went before anything moves
    function reach(uri, opts) {
        opts = opts || {};
        return win.app.connect(uri, win, function(r) {
            if (opts.done)
                opts.done(r);

            if (!r.ok) {
                if (!opts.done && !r.cancelled)
                    win.say(r.error || "Could not connect");

                return ;
            }
            if (opts.remember)
                win.app.remember(uri, r.label);

            var dest = r.path || r.uri;
            if (!r.isDir) {
                win.pendingSelect = r.name;
                dest = r.where || win.app.parentOf(dest);
            }
            if (opts.tab)
                opts.tab.go(dest, true);
            else if (opts.newTab)
                win.newTab(dest);
            else
                win.go(dest);
        });
    }

    // a tab on a share that isn't connected: connect it, then look again
    function reconnect(t) {
        if (!t || t.connectUri === "" || t.connecting)
            return ;

        var uri = t.connectUri;
        t.connecting = true;
        t.error = "";
        win.reach(uri, {
            "tab": t,
            "remember": t.rememberNext === uri,
            "done": function(r) {
                t.connecting = false;
                t.rememberNext = "";
                if (!r.ok) {
                    t.connectUri = uri;
                    t.error = r.cancelled ? (t.locked ? "An administrator's password opens it." : "Not connected to " + win.app.hostOf(uri)) : (r.error || "Could not connect");
                }
            }
        });
    }

    // someone else's file, through admin://, opens as a copy nothing but lumen could fetch
    function opened(r) {
        if (r && r.copies > 0)
            win.say(r.copies === 1 ? "Opened a copy: it's someone else's file, so changes stay in the copy" : "Opened copies: they're someone else's files, so changes stay in the copies");
        else if (r && r.error)
            win.say(r.error);
    }

    function mount(v) {
        win.app.call("mount", {
            "volume": v.id
        }, function(r) {
            if (r.ok && r.path)
                win.go(r.path);
            else if (!r.ok)
                win.say(r.error || "Could not mount it");
        });
    }

    // ---- view

    // a column heading, for this folder only: its own key turns the order round,
    // another starts the way it is mostly wanted (newest, largest first)
    function sortBy(key) {
        var t = win.tab;
        if (!t)
            return ;

        var s = win.app.sortOf(t.path);
        win.app.setSort(t.path, key, s.key === key ? !s.desc : key === "modified" || key === "size" || key === "deleted");
    }

    function resortAll() {
        win.eachTab(function(t) {
            t.resort();
        });
    }

    // this folder's sort for every folder, with the way back on the snackbar
    function sortEverywhere() {
        var t = win.tab;
        if (!t)
            return ;

        var s = win.app.sortOf(t.path);
        win.say("Every folder now sorts like “" + t.title + "”", "Undo", win.app.sortEverywhere(s.key, s.desc));
    }

    readonly property var zoomSteps: [24, 32, 40, 48, 56, 64, 72, 80, 96, 112, 128, 160, 192, 256]

    function zoom(d) {
        var steps = win.zoomSteps;
        var cur = win.app.prefs.iconSize, i = 0;
        while (i < steps.length - 1 && steps[i] < cur)i++
        i = Math.max(0, Math.min(steps.length - 1, i + d));
        win.app.prefs.iconSize = steps[i];
        if (win.app.prefs.view !== "grid" && d !== 0)
            win.app.prefs.view = "grid";

    }

    // typing in the folder carries on in the location bar, as a filter
    function startFilter(ch) {
        pathBar.edit((pathBar.editing && !pathBar.typedPath ? pathBar.text : "") + ch);
    }

    function clearFilter() {
        pathBar.text = "";
        if (win.tab) {
            win.tab.filter = "";
            win.tab.apply();
        }
        folderPane.takeFocus();
    }

    function endSearch() {
        pathBar.text = "";
        if (win.tab)
            win.tab.endSearch();

        folderPane.takeFocus();
    }

    // the field shows the tab's own filter or search, and empties when the tab moves on
    function syncSearch() {
        pathBar.sync();
    }

    // ---- menus

    function clean(items) {
        var out = [];
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            if (!it)
                continue;

            if (it.sep && (out.length === 0 || out[out.length - 1].sep))
                continue;

            out.push(it);
        }
        while (out.length > 0 && out[out.length - 1].sep)out.pop()
        return out;
    }

    function itemMenu(x, y) {
        var t = win.tab;
        var sel = t.selectedItems();
        if (sel.length === 0)
            return ;

        var one = sel.length === 1 ? sel[0] : null;
        var dir = one !== null && one.kind === "dir";
        var items;
        if (t.isTrash) {
            items = [{
                "id": "restore",
                "label": "Restore",
                "icon": "undo"
            }, {
                "sep": true
            }, {
                "id": "delete",
                "label": "Delete for good",
                "icon": "delete_forever",
                "hint": "Delete",
                "danger": true
            }];
        } else {
            items = [{
                "id": "open",
                "label": "Open",
                "icon": "open_in_new",
                "hint": "Enter"
            }, dir ? {
                "id": "openTab",
                "label": "Open in new tab",
                "icon": "tab"
            } : null, !dir ? {
                "id": "openWith",
                "label": "Open with…",
                "icon": "apps"
            } : null, t.searching || t.isRecent ? {
                "id": "reveal",
                "label": "Show in folder",
                "icon": "folder_open"
            } : null, {
                "sep": true
            }, {
                "id": "cut",
                "label": "Cut",
                "icon": "content_cut",
                "hint": "Ctrl+X"
            }, {
                "id": "copy",
                "label": "Copy",
                "icon": "content_copy",
                "hint": "Ctrl+C"
            }, dir ? {
                "id": "pasteInto",
                "label": "Paste into folder",
                "icon": "content_paste"
            } : null, {
                "sep": true
            }, one && !t.isRecent ? {
                "id": "rename",
                "label": "Rename…",
                "icon": "edit",
                "hint": "F2"
            } : null, !t.isRecent ? {
                "id": "duplicate",
                "label": "Duplicate",
                "icon": "file_copy"
            } : null, !t.isRecent ? {
                "id": "link",
                "label": "Make link",
                "icon": "link"
            } : null, {
                "id": "compress",
                "label": "Compress",
                "icon": "archive"
            }, one && one.slot === "archive" ? {
                "id": "extract",
                "label": "Extract here",
                "icon": "unarchive"
            } : null, one && one.slot === "archive" ? {
                "id": "extractInto",
                "label": "Extract to folder",
                "icon": "folder_zip"
            } : null, {
                "sep": true
            }, dir ? {
                "id": "terminal",
                "label": "Open in terminal",
                "icon": "terminal"
            } : null, dir ? {
                "id": "bookmark",
                "label": "Add to bookmarks",
                "icon": "bookmark_add"
            } : null, win.wallpaperable(one) && !t.isTrash ? {
                "id": "wallpaper",
                "label": "Set as wallpaper",
                "icon": "wallpaper"
            } : null, {
                "id": "copyPath",
                "label": sel.length > 1 ? "Copy paths" : "Copy path",
                "icon": "content_copy"
            }, {
                "id": "properties",
                "label": "Properties",
                "icon": "info",
                "hint": "Ctrl+I"
            }, {
                "sep": true
            }, !t.isRecent ? {
                "id": "trash",
                "label": "Move to trash",
                "icon": "delete",
                "hint": "Delete",
                "danger": true
            } : null];
        }
        menu.open(win.clean(items), x, y, function(id) {
            return win.runItem(id, one, sel);
        });
    }

    function runItem(id, one, sel) {
        var t = win.tab;
        switch (id) {
        case "open":
            win.openSelection(false);
            break;
        case "openTab":
            win.newTab(one.path, true);
            break;
        case "openWith":
            win.openWith();
            break;
        case "reveal":
            win.pendingSelect = one ? one.name : "";
            win.go(one ? (one.where || win.app.parentOf(one.path)) : t.path);
            break;
        case "cut":
            win.copySelection(true);
            break;
        case "copy":
            win.copySelection(false);
            break;
        case "pasteInto":
            win.paste(one.path);
            break;
        case "rename":
            win.renameSelection();
            break;
        case "duplicate":
            win.app.transfer("copy", win.selectionUris(), t.path);
            break;
        case "link":
            win.app.call("link", {
                "uris": win.selectionUris(),
                "dest": t.path
            });
            break;
        case "compress":
            win.app.call("compress", {
                "paths": sel.map(function(it) {
                    return it.path;
                })
            }, function(r) {
                if (r.ok)
                    win.pendingSelect = r.name;
                else
                    win.say(r.error || "Could not compress");
            });
            break;
        case "extract":
        case "extractInto":
            win.app.call("extract", {
                "path": one.path,
                "into": id === "extractInto"
            }, function(r) {
                if (r.ok)
                    win.pendingSelect = r.name;
                else
                    win.say(r.error || "Could not extract it");
            });
            break;
        case "terminal":
            win.app.call("terminal", {
                "path": one.path
            });
            break;
        case "bookmark":
            win.app.call("bookmarkAdd", {
                "path": one.path
            });
            win.say("Added “" + one.label + "” to bookmarks");
            break;
        case "wallpaper":
            win.setWallpaper(one);
            break;
        case "copyPath":
            win.copyPath();
            break;
        case "properties":
            win.properties(one);
            break;
        case "trash":
            win.trashSelection();
            break;
        case "restore":
            win.restoreSelection();
            break;
        case "delete":
            win.deleteSelection();
            break;
        }
    }

    // every way a folder can be sorted, two to a key: [key, descending, label]
    function sortChoices() {
        var t = win.tab;
        var date = t && t.isTrash ? "deleted" : "modified";
        var kind = t && (t.isTrash || t.searching) ? "Location" : "Type";
        return [["name", false, "Name, A to Z"], ["name", true, "Name, Z to A"], [date, true, "Newest to oldest"], [date, false, "Oldest to newest"], ["size", true, "Largest to smallest"], ["size", false, "Smallest to largest"], ["type", false, kind + ", A to Z"], ["type", true, kind + ", Z to A"]];
    }

    function sortLabel() {
        var t = win.tab;
        if (!t)
            return "";

        var s = win.app.sortOf(t.path), all = win.sortChoices();
        for (var i = 0; i < all.length; i++) {
            if (all[i][0] === s.key && all[i][1] === s.desc)
                return all[i][2];

        }
        return "";
    }

    // this folder's sort, as radios in pairs; a menu of its own is headed with
    // the folder, so it is plain the choice stays here
    function sortItems(heading) {
        var p = win.app.prefs, t = win.tab;
        if (!t)
            return [];

        var s = win.app.sortOf(t.path), all = win.sortChoices(), out = [];
        if (heading)
            out.push({
            "heading": t.searching ? "Sort results" : "Sort " + t.title
        });

        for (var i = 0; i < all.length; i++) {
            if (i > 0 && i % 2 === 0)
                out.push({
                "sep": true
            });

            out.push({
                "id": "sort:" + all[i][0] + ":" + (all[i][1] ? "desc" : "asc"),
                "label": all[i][2],
                "radio": true,
                "checked": s.key === all[i][0] && s.desc === all[i][1]
            });
        }
        out.push({
            "sep": true
        });
        out.push({
            "id": "sort:dirs",
            "label": "Folders first",
            "icon": "folder",
            "checked": p.foldersFirst
        });
        // the default is what a folder takes until it is sorted its own way
        if (!t.isSpecial && !t.searching) {
            var base = win.app.baseSort(t.path);
            out.push({
                "id": "sort:all",
                "label": "Use for all folders",
                "icon": "done_all",
                "disabled": base.key === s.key && base.desc === s.desc && win.app.ownSorts() === 0
            });
        }
        return out;
    }

    function backgroundMenu(x, y) {
        var t = win.tab;
        if (!t)
            return ;

        win.app.call("templates", {
        }, function(r) {
            if (r.ok)
                win.templates = r.items || [];

        });
        var docs = [{
            "id": "doc:text",
            "label": "Text document",
            "icon": "description"
        }, {
            "id": "doc:empty",
            "label": "Empty file",
            "icon": "note_add"
        }];
        if (win.templates.length > 0) {
            docs.push({
                "sep": true
            });
            for (var k = 0; k < win.templates.length; k++) docs.push({
                "id": "tpl:" + win.templates[k].path,
                "label": win.templates[k].label,
                "icon": "file_copy"
            })
        }
        var grid = win.app.prefs.view === "grid";
        var items = t.isTrash ? [{
            "id": "empty",
            "label": "Empty trash",
            "icon": "delete_forever",
            "danger": true,
            "disabled": win.app.trashCount === 0
        }, {
            "sep": true
        }, {
            "id": "selectAll",
            "label": "Select all",
            "icon": "select_all",
            "hint": "Ctrl+A"
        }, {
            "id": "sort",
            "label": "Sort by",
            "icon": "sort",
            "sub": win.sortItems()
        }] : [!t.isSpecial && !t.searching ? {
            "id": "newFolder",
            "label": "New folder",
            "icon": "create_new_folder",
            "hint": "Ctrl+Shift+N"
        } : null, !t.isSpecial && !t.searching ? {
            "id": "newDoc",
            "label": "New document",
            "icon": "note_add",
            "sub": docs
        } : null, {
            "sep": true
        }, !t.isSpecial && !t.searching ? {
            "id": "paste",
            "label": "Paste",
            "icon": "content_paste",
            "hint": "Ctrl+V"
        } : null, {
            "id": "selectAll",
            "label": "Select all",
            "icon": "select_all",
            "hint": "Ctrl+A"
        }, {
            "sep": true
        }, {
            "id": "sort",
            "label": "Sort by",
            "icon": "sort",
            "sub": win.sortItems()
        }, {
            "id": "view",
            "label": grid ? "Show as list" : "Show as grid",
            "icon": grid ? "view_list" : "grid_view",
            "hint": grid ? "Ctrl+2" : "Ctrl+1"
        }, {
            "id": "hidden",
            "label": "Show hidden files",
            "icon": "visibility",
            "checked": win.app.prefs.hidden,
            "hint": "Ctrl+H"
        }, {
            "sep": true
        }, !t.isSpecial ? {
            "id": "terminalHere",
            "label": "Open in terminal",
            "icon": "terminal"
        } : null, !t.isSpecial ? {
            "id": "bookmarkHere",
            "label": "Add to bookmarks",
            "icon": "bookmark_add"
        } : null, !t.isSpecial ? {
            "id": "propsHere",
            "label": "Properties",
            "icon": "info"
        } : null];
        menu.open(win.clean(items), x, y, function(id) {
            return win.runBackground(id);
        });
    }

    function runBackground(id) {
        var t = win.tab, p = win.app.prefs;
        if (id.indexOf("sort:") === 0) {
            var k = id.slice(5).split(":");
            if (k[0] === "dirs")
                p.foldersFirst = !p.foldersFirst;
            else if (k[0] === "all")
                win.sortEverywhere();
            else if (t)
                win.app.setSort(t.path, k[0], k[1] === "desc");
            return ;
        }
        if (id.indexOf("tpl:") === 0) {
            win.newDocument(id.slice(4));
            return ;
        }
        switch (id) {
        case "newFolder":
            win.newFolder();
            break;
        case "doc:text":
            win.newDocument("");
            break;
        case "doc:empty":
            var name = win.freeName("New File");
            win.app.call("newFile", {
                "dest": t.path,
                "name": name
            }, function(r) {
                if (r.ok) {
                    win.app.pushUndo({
                        "kind": "create",
                        "made": [r.path]
                    });
                    win.pendingSelect = r.name;
                }
            });
            break;
        case "paste":
            win.paste(t.path);
            break;
        case "selectAll":
            t.selectAll();
            break;
        case "view":
            p.view = p.view === "grid" ? "list" : "grid";
            break;
        case "hidden":
            p.hidden = !p.hidden;
            break;
        case "terminalHere":
            win.app.call("terminal", {
                "path": t.path
            });
            break;
        case "bookmarkHere":
            win.app.call("bookmarkAdd", {
                "path": t.path
            });
            win.say("Added “" + t.title + "” to bookmarks");
            break;
        case "propsHere":
            win.properties(null);
            break;
        case "empty":
            win.emptyTrash();
            break;
        }
    }

    function keyMenu() {
        var t = win.tab;
        if (t.selCount === 0) {
            win.backgroundMenu(root.width / 2, root.height / 2);
            return ;
        }
        var v = folderPane.view;
        var item = v.itemAtIndex ? v.itemAtIndex(t.current) : null;
        if (item) {
            var p = item.mapToItem(root, item.width / 2, item.height / 2);
            win.itemMenu(p.x, p.y);
        } else {
            win.itemMenu(root.width / 2, root.height / 2);
        }
    }

    function trashMenu(x, y) {
        menu.open([{
            "id": "open",
            "label": "Open trash",
            "icon": "delete"
        }, {
            "sep": true
        }, {
            "id": "empty",
            "label": "Empty trash",
            "icon": "delete_forever",
            "danger": true,
            "disabled": win.app.trashCount === 0
        }], x, y, function(id) {
            if (id === "open")
                win.go("trash:///");
            else
                win.emptyTrash();
        });
    }

    function bookmarkMenu(b, x, y) {
        menu.open([{
            "id": "open",
            "label": "Open",
            "icon": "open_in_new"
        }, {
            "id": "tab",
            "label": "Open in new tab",
            "icon": "tab"
        }, {
            "sep": true
        }, {
            "id": "colour",
            "label": "Colour",
            "icon": "palette",
            "sub": win.colourRow(win.app.bookmarkColour(b.uri))
        }, {
            "id": "rename",
            "label": "Rename…",
            "icon": "edit"
        }, {
            "sep": true
        }, {
            "id": "remove",
            "label": "Remove bookmark",
            "icon": "close"
        }], x, y, function(id) {
            if (id.indexOf("colour:") === 0)
                win.app.setBookmarkColour(b.uri, id.slice(7));
            else if (id === "open")
                win.go(b.path || b.uri);
            else if (id === "tab")
                win.newTab(b.path || b.uri);
            else if (id === "rename")
                win.renameBookmark(b);
            else
                win.removeBookmark(b);
        });
    }

    function renameBookmark(b) {
        dialog.ask({
            "mode": "input",
            "title": "Rename bookmark",
            "text": "An empty name goes back to the folder's own.",
            "input": b.label,
            "confirm": "Rename"
        }, function(ok, name) {
            if (ok)
                win.app.call("bookmarkRename", {
                "uri": b.uri,
                "label": name
            });

        });
    }

    function removeBookmark(b) {
        win.app.call("bookmarkRemove", {
            "uri": b.uri
        });
        win.app.setBookmarkColour(b.uri, "");
        win.say("Removed “" + b.label + "” from bookmarks");
    }

    // ctrl+d: the folder you are in, in the bookmarks or out of them again
    function toggleBookmark() {
        var t = win.tab;
        if (!t || t.isSpecial || t.searching || t.path === "" || t.path.indexOf("://") > 0)
            return ;

        for (var i = 0; i < win.app.bookmarks.length; i++) {
            if (win.app.bookmarks[i].path === t.path) {
                win.removeBookmark(win.app.bookmarks[i]);
                return ;
            }
        }
        if (t.path === win.app.home || win.app.places.some(function(p) {
            return p.path === t.path;
        })) {
            win.say("“" + t.title + "” is in the sidebar already");
            return ;
        }
        win.app.call("bookmarkAdd", {
            "path": t.path
        });
        win.say("Added “" + t.title + "” to bookmarks");
    }

    // a picture or a video the wallpaper strip could show
    function wallpaperable(it) {
        return it !== null && it.kind !== "dir" && it.path !== "" && /\.(jpe?g|png|webp|mp4|webm|mkv|mov|m4v)$/i.test(it.path);
    }

    function setWallpaper(it) {
        Quickshell.execDetached([win.app.home + "/.config/hypr/scripts/wallpaper/set-wallpaper.sh", it.path]);
        win.say("“" + it.label + "” is your wallpaper");
    }

    function driveMenu(v, x, y) {
        if (v.remote) {
            win.shareMenu(v, x, y);
            return ;
        }
        menu.open(win.clean([v.mounted ? {
            "id": "open",
            "label": "Open",
            "icon": "open_in_new"
        } : {
            "id": "mount",
            "label": "Mount",
            "icon": "hard_drive"
        }, v.mounted ? {
            "id": "tab",
            "label": "Open in new tab",
            "icon": "tab"
        } : null, {
            "sep": true
        }, v.mounted && (v.canEject || v.canUnmount) ? {
            "id": "eject",
            "label": v.canEject ? "Eject" : "Unmount",
            "icon": "eject"
        } : null]), x, y, function(id) {
            if (id === "open")
                win.go(v.path || v.uri);
            else if (id === "tab")
                win.newTab(v.path || v.uri);
            else if (id === "mount")
                win.mount(v);
            else if (id === "eject")
                win.unmount(v);
        });
    }

    // a share connected to: where it is, and letting go of it
    function shareMenu(v, x, y) {
        menu.open(win.clean([{
            "id": "open",
            "label": "Open",
            "icon": "open_in_new"
        }, {
            "id": "tab",
            "label": "Open in new tab",
            "icon": "tab"
        }, {
            "id": "address",
            "label": "Copy address",
            "icon": "content_copy"
        }, {
            "sep": true
        }, v.canUnmount || v.canEject ? {
            "id": "eject",
            "label": "Disconnect",
            "icon": "eject"
        } : null]), x, y, function(id) {
            if (id === "open")
                win.go(v.path || v.uri);
            else if (id === "tab")
                win.newTab(v.path || v.uri);
            else if (id === "address") {
                win.app.call("clipText", {
                    "text": v.uri
                });
                win.say("Address copied");
            } else if (id === "eject")
                win.unmount(v);
        });
    }

    function moreMenu(x, y) {
        var p = win.app.prefs;
        menu.open([{
            "id": "window",
            "label": "New window",
            "icon": "open_in_new",
            "hint": "Ctrl+N"
        }, {
            "id": "tab",
            "label": "New tab",
            "icon": "tab",
            "hint": "Ctrl+T"
        }, {
            "id": "connect",
            "label": "Connect to server…",
            "icon": "add_link",
            "hint": "Ctrl+K"
        }, {
            "sep": true
        }, {
            // the size steps in place: the menu stays open while you look
            "label": "Icon size",
            "buttons": [{
                "id": "zoomOut",
                "icon": "zoom_out",
                "tip": "Zoom out",
                "off": function() {
                    return win.app.prefs.view === "grid" && win.app.prefs.iconSize <= win.zoomSteps[0];
                }
            }, {
                "id": "zoomIn",
                "icon": "zoom_in",
                "tip": "Zoom in",
                "off": function() {
                    return win.app.prefs.view === "grid" && win.app.prefs.iconSize >= win.zoomSteps[win.zoomSteps.length - 1];
                }
            }]
        }, {
            "sep": true
        }, {
            "id": "hidden",
            "label": "Show hidden files",
            "icon": "visibility",
            "checked": p.hidden,
            "hint": "Ctrl+H"
        }, {
            "id": "sidebar",
            "label": "Show sidebar",
            "icon": "menu",
            "checked": p.sidebar,
            "hint": "Ctrl+B"
        }, {
            "id": "preview",
            "label": "Show preview",
            "icon": "preview",
            "checked": p.preview,
            "hint": "Alt+P"
        }, {
            "id": "single",
            "label": "Open with one click",
            "icon": "touch_app",
            "checked": p.singleClick
        }, {
            "sep": true
        }, {
            "id": "undo",
            "label": "Undo",
            "icon": "undo",
            "hint": "Ctrl+Z",
            "disabled": win.app.undoList.length === 0
        }], x, y, function(id) {
            switch (id) {
            case "window":
                win.app.openWindow(win.tab ? win.tab.path : win.app.home);
                break;
            case "tab":
                win.newTab(win.tab ? win.tab.path : win.app.home);
                break;
            case "connect":
                win.connectServer("");
                break;
            case "hidden":
                p.hidden = !p.hidden;
                break;
            case "sidebar":
                p.sidebar = !p.sidebar;
                break;
            case "preview":
                p.preview = !p.preview;
                break;
            case "single":
                p.singleClick = !p.singleClick;
                break;
            case "zoomIn":
                win.zoom(1);
                break;
            case "zoomOut":
                win.zoom(-1);
                break;
            case "undo":
                win.app.undo();
                break;
            }
        });
    }

    visible: true
    // a dialog's title ends in " — Lumen": the window rule that floats it looks for that
    title: win.choosing ? win.chooserTitle + " — Lumen" : (win.tab ? win.tab.title : "Lumen")
    // one step under solid, so hyprland can still blur it (see Settings.qml)
    color: Theme.alpha(Theme.bg, Math.min(Theme.bg.a, 254 / 255))
    // a dialog gets room to look around, up to most of the smallest screen
    readonly property size room: {
        var w = 0, h = 0, list = Quickshell.screens;
        for (var i = 0; i < list.length; i++) {
            w = w ? Math.min(w, list[i].width) : list[i].width;
            h = h ? Math.min(h, list[i].height) : list[i].height;
        }
        return Qt.size(w || 1920, h || 1080);
    }
    implicitWidth: win.choosing ? Math.round(Math.min(Theme.dp(1440), win.room.width * 0.85)) : Theme.dp(win.app.prefs.width)
    implicitHeight: win.choosing ? Math.round(Math.min(Theme.dp(940), win.room.height * 0.85)) : Theme.dp(win.app.prefs.height)
    minimumSize.width: Theme.dp(560)
    minimumSize.height: Theme.dp(420)
    onClosed: {
        if (win.choosing && !win.answered)
            win.cancelChooser();
        else
            win.app.closeWindow(win.winId);
    }
    onIsActiveChanged: {
        if (win.isActive)
            win.app.focusedWindow = win;

    }
    Component.onCompleted: {
        // torn off another window: just that tab, with its history
        if (win.carryData !== "") {
            win.adoptTab(JSON.parse(win.carryData), 0);
            win.app.focusedWindow = win;
            folderPane.takeFocus();
            Qt.callLater(function() {
                tabStrip.ready = true;
            });
            return ;
        }
        // the pinned tabs first, in every window but a dialog; a folder already
        // pinned opens in its pin
        var pins = win.choosing ? [] : win.app.prefs.pinnedTabs;
        var mine = -1;
        for (var k = 0; k < pins.length; k++) {
            var pt = win.newTab(pins[k].path, true, false, {
                "pinned": true,
                "pinKey": pins[k].key,
                "colour": pins[k].colour,
                "at": k
            });
            if (pins[k].path === win.startPath && win.morePaths === "")
                mine = k;

        }
        if (mine >= 0)
            win.currentIndex = mine;
        else
            win.newTab(win.startPath, false, true, {
            "at": win.pinnedCount
        });
        // the rest behind it, in the order given
        var more = win.morePaths === "" ? [] : win.morePaths.split("\n");
        for (var i = more.length - 1; i >= 0; i--) win.newTab(more[i], true, true)
        win.app.focusedWindow = win;
        folderPane.takeFocus();
        Qt.callLater(function() {
            tabStrip.ready = true;
        });
    }

    ListModel {
        id: tabModel
    }

    Component {
        id: tabComp

        Tab {
        }

    }

    Connections {
        // the app gave up on its dialog: the window goes without an answer
        function onChooserClosed(id) {
            if (win.choosing && win.chooser.id === id) {
                win.answered = true;
                win.visible = false;
                win.app.closeWindow(win.winId);
            }
        }

        function onListEvent(ev) {
            var t = win.tabFor(ev.view);
            if (t)
                t.onList(ev);

        }

        function onListDoneEvent(ev) {
            var t = win.tabFor(ev.view);
            if (!t)
                return ;

            // an address already connected: its folder instead, in its place in the history
            if (ev.redirect && ev.path === t.path && !t.searching) {
                if (t.rememberNext === t.path) {
                    var share = win.app.volumeAt(ev.redirect);
                    win.app.remember(t.path, share ? share.label : "");
                    t.rememberNext = "";
                }
                t.go(ev.redirect, true);
                return ;
            }
            t.onListDone(ev);
            // a share not connected, gone to on purpose in the tab in front: connect it
            if (ev.connect && ev.path === t.path) {
                if (t.wantConnect && t === win.tab)
                    win.reconnect(t);

            }

            t.wantConnect = false;
            if (t === win.tab && win.pendingSelect !== "") {
                var i = t.selectByName(win.pendingSelect);
                if (i >= 0) {
                    win.pendingSelect = "";
                    folderPane.show(i);
                }
            }
        }

        function onSearchEvent(ev) {
            var t = win.tabFor(ev.view);
            if (t)
                t.onSearch(ev);

        }

        function onSearchDoneEvent(ev) {
            var t = win.tabFor(ev.view);
            if (t)
                t.onSearchDone(ev);

        }

        function onThumbEvent(uri, thumb) {
            win.eachTab(function(t) {
                t.onThumb(uri, thumb);
            });
        }

        // a server asks for a login, or an answer, for a connection this window made
        function onAskEvent(ev) {
            if (win.app.connectOwner(ev.connect) === win)
                server.ask(ev);

        }

        function onAskCloseEvent(id) {
            server.askGone(id);
        }

        // a drive or share went: its tabs go home, pinned ones stay to connect again
        function onVolumeGone(path) {
            win.eachTab(function(t) {
                if (!t.pinned && (t.path === path || t.path.indexOf(path + "/") === 0))
                    t.go(win.app.home, false, -1);

            });
        }

        function onInfoSizeEvent(ev) {
            if (ev.req === win.infoReq && dialog.shown && dialog.mode === "info")
                dialog.setRow("size", win.app.sizeText(ev.size) + " · " + ev.files + (ev.files === 1 ? " file" : " files") + (ev.dirs > 0 ? ", " + ev.dirs + (ev.dirs === 1 ? " folder" : " folders") : ""));

        }

        function onIconsChanged() {
            win.eachTab(function(t) {
                if (!t.searching)
                    t.reload();

            });
        }

        function onNotice(text, action, undo) {
            if (win.app.focusedWindow === win)
                win.say(text, action, undo);

        }

        target: win.app
    }

    Connections {
        function onNavigated() {
            win.syncSearch();
            win.drawer = false;
        }

        function onSearchingChanged() {
            win.syncSearch();
        }

        target: win.tab
    }

    // a sort can change in several steps at once: the tabs move once, after them
    Connections {
        function onSortKeyChanged() {
            Qt.callLater(win.resortAll);
        }

        function onSortDescChanged() {
            Qt.callLater(win.resortAll);
        }

        function onFolderSortsChanged() {
            Qt.callLater(win.resortAll);
        }

        function onFoldersFirstChanged() {
            Qt.callLater(win.resortAll);
        }

        function onHiddenChanged() {
            win.eachTab(function(t) {
                if (!t.searching)
                    t.reload();

            });
        }

        target: win.app.prefs
    }

    // the window's size is remembered, once it settles
    Timer {
        id: sizeLater

        interval: 600
        onTriggered: {
            // a dialog keeps its own size, never the browsing window's
            if (win.choosing)
                return ;

            win.app.prefs.width = Math.round(win.width / Theme.uiScale);
            win.app.prefs.height = Math.round(win.height / Theme.uiScale);
        }
    }

    onWidthChanged: sizeLater.restart()
    onHeightChanged: sizeLater.restart()

    Shortcut {
        sequences: ["Ctrl+T"]
        onActivated: win.newTab(win.tab ? win.tab.path : win.app.home)
    }

    Shortcut {
        sequences: ["Ctrl+W"]
        onActivated: win.closeTab(win.currentIndex)
    }

    Shortcut {
        sequences: ["Ctrl+Shift+T"]
        onActivated: win.reopenTab()
    }

    Shortcut {
        sequences: ["Ctrl+D"]
        onActivated: win.toggleBookmark()
    }

    Shortcut {
        sequences: ["Ctrl+K"]
        onActivated: win.connectServer("")
    }

    Shortcut {
        sequences: ["Alt+P"]
        onActivated: win.app.prefs.preview = !win.app.prefs.preview
    }

    Shortcut {
        sequences: ["Ctrl+Tab", "Ctrl+PgDown"]
        onActivated: win.switchTab((win.currentIndex + 1) % win.tabs.length)
    }

    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]
        onActivated: win.switchTab((win.currentIndex - 1 + win.tabs.length) % win.tabs.length)
    }

    Shortcut {
        sequences: ["Ctrl+L", "Alt+D"]
        onActivated: pathBar.edit()
    }

    Shortcut {
        sequences: ["Ctrl+F"]
        onActivated: pathBar.edit("")
    }

    Shortcut {
        sequences: ["Ctrl+H"]
        onActivated: win.app.prefs.hidden = !win.app.prefs.hidden
    }

    Shortcut {
        sequences: ["Ctrl+1"]
        onActivated: win.app.prefs.view = "grid"
    }

    Shortcut {
        sequences: ["Ctrl+2"]
        onActivated: win.app.prefs.view = "list"
    }

    Shortcut {
        sequences: ["Ctrl+N"]
        onActivated: win.app.openWindow(win.tab ? win.tab.path : win.app.home)
    }

    Shortcut {
        sequences: ["Ctrl+Z"]
        onActivated: win.app.undo()
    }

    Shortcut {
        sequences: ["Alt+Left", "Back"]
        onActivated: win.tab.goBack()
    }

    Shortcut {
        sequences: ["Alt+Right", "Forward"]
        onActivated: win.tab.goForward()
    }

    Shortcut {
        sequences: ["Alt+Home"]
        onActivated: win.go(win.app.home)
    }

    Shortcut {
        sequences: ["F5", "Ctrl+R"]
        onActivated: win.tab.reload()
    }

    Shortcut {
        sequences: ["Ctrl+=", "Ctrl++"]
        onActivated: win.zoom(1)
    }

    Shortcut {
        sequences: ["Ctrl+-"]
        onActivated: win.zoom(-1)
    }

    Shortcut {
        sequences: ["Ctrl+0"]
        onActivated: win.app.prefs.iconSize = 80
    }

    Shortcut {
        sequences: ["Ctrl+B", "F9"]
        onActivated: win.app.prefs.sidebar = !win.app.prefs.sidebar
    }

    Shortcut {
        sequences: ["Ctrl+I", "Alt+Return"]
        onActivated: win.properties(null)
    }

    Shortcut {
        sequences: ["Ctrl+Q"]
        onActivated: {
            if (win.choosing) {
                win.cancelChooser();
                return ;
            }
            win.visible = false;
            win.app.closeWindow(win.winId);
        }
    }

    Item {
        id: root

        anchors.fill: parent

        // offscreen grabs drop the window's own colour; the rig paints it in
        Rectangle {
            anchors.fill: parent
            visible: (Quickshell.env("LUMEN_SHOT") || "") !== ""
            color: Theme.bgOpaque
        }

        // a tab from another window dropped anywhere on this one joins it at the
        // end. under everything: the strip's own drop, and the folder's for
        // files, come first. this window's own tabs it leaves alone, so one
        // dropped on its own folder still tears off
        DropArea {
            anchors.fill: parent
            enabled: tabStrip.foreign && !win.choosing
            keys: ["application/x-lucid-lumen-tab"]
            onEntered: (drag) => {
                return drag.accept(Qt.MoveAction);
            }
            onDropped: (drop) => {
                var d = win.app.tabDrag;
                drop.accept(Qt.MoveAction);
                if (d && d.win !== win.winId)
                    win.app.transferLater(d.win, d.vid, win, win.tabs.length);

            }
        }

        // the mouse's side buttons go back and forward
        MouseArea {
            anchors.fill: parent
            z: 300
            enabled: !win.overlayOpen
            acceptedButtons: Qt.BackButton | Qt.ForwardButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.BackButton)
                    win.tab.goBack();
                else
                    win.tab.goForward();
            }
        }

        Sidebar {
            id: sidebar

            app: win.app
            win: win
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.dp(64)
            width: (win.narrow ? win.drawer : win.app.prefs.sidebar) ? Theme.dp(236) : 0
            visible: width > 0
            clip: true
            z: win.narrow ? 250 : 0

            // the drawer's own sheet, when it lies over the folder
            Rectangle {
                anchors.fill: parent
                z: -1
                visible: win.narrow
                color: Theme.bgOpaque
                topRightRadius: Theme.shapeXl
                bottomRightRadius: Theme.shapeXl
            }

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

        }

        // the bar: the way back, where this is, and how to look at it
        Item {
            id: bar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.dp(64)

            Row {
                id: navs

                x: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(2)

                IconButton {
                    icon: "menu"
                    tooltip: "Sidebar"

                    Tip {
                    }

                    onClicked: {
                        if (win.narrow)
                            win.drawer = !win.drawer;
                        else
                            win.app.prefs.sidebar = !win.app.prefs.sidebar;
                    }
                }

                Item {
                    width: Math.max(Theme.dp(4), win.dockWidth - Theme.dp(12) - 4 * Theme.dp(38) - Theme.dp(10))
                    height: 1
                }

                IconButton {
                    icon: "arrow_back"
                    tooltip: "Back"

                    Tip {
                    }

                    disabled: !win.tab || win.tab.back.length === 0
                    onClicked: win.tab.goBack()
                }

                IconButton {
                    icon: "arrow_forward"
                    tooltip: "Forward"

                    Tip {
                    }

                    disabled: !win.tab || win.tab.forward.length === 0
                    onClicked: win.tab.goForward()
                }

                IconButton {
                    icon: "arrow_upward"
                    tooltip: "Up"

                    Tip {
                    }

                    disabled: !win.tab || win.tab.isSpecial || win.app.parentOf(win.tab.path) === win.tab.path
                    onClicked: win.tab.goUp()
                }

            }

            PathBar {
                id: pathBar

                app: win.app
                win: win
                anchors.left: navs.right
                anchors.leftMargin: Theme.dp(10)
                anchors.right: tools.left
                anchors.rightMargin: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.dp(42)
            }

            Row {
                id: tools

                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(2)

                IconButton {
                    icon: "preview"
                    checkable: true
                    checked: win.app.prefs.preview
                    tooltip: win.app.prefs.preview ? "Hide preview (Alt+P)" : "Show preview (Alt+P)"

                    Tip {
                    }

                    onClicked: win.app.prefs.preview = !win.app.prefs.preview
                }

                IconButton {
                    icon: win.app.prefs.view === "grid" ? "view_list" : "grid_view"
                    tooltip: win.app.prefs.view === "grid" ? "Show as list" : "Show as grid"

                    Tip {
                    }

                    onClicked: win.app.prefs.view = win.app.prefs.view === "grid" ? "list" : "grid"
                }

                IconButton {
                    id: sortBtn

                    icon: "sort"
                    tooltip: win.sortLabel() !== "" ? "Sort · " + win.sortLabel() : "Sort"

                    Tip {
                    }

                    onClicked: {
                        var p = sortBtn.mapToItem(root, 0, sortBtn.height + Theme.dp(4));
                        menu.open(win.sortItems(true), p.x - Theme.dp(140), p.y, function(id) {
                            return win.runBackground(id);
                        });
                    }
                }

                IconButton {
                    id: moreBtn

                    icon: "more_vert"
                    tooltip: "More"

                    Tip {
                    }

                    onClicked: {
                        var p = moreBtn.mapToItem(root, 0, moreBtn.height + Theme.dp(4));
                        win.moreMenu(p.x - Theme.dp(200), p.y);
                    }
                }

            }

        }

        // the tabs, always there to open another; a dialog shows them only once it
        // has more than one. pinned ones sit at the front, small. a tab dragged
        // along the strip moves there; dropped on another lumen window it joins
        // that one, and dropped anywhere else it becomes a window of its own
        Item {
            id: tabStrip

            readonly property real pinW: Theme.dp(44)
            readonly property real gap: Theme.dp(6)
            // tabs share the room, down to their glyph alone when there are many
            readonly property real tabW: {
                var loose = Math.max(1, win.tabs.length - win.pinnedCount);
                var room = tabStrip.width - Theme.dp(48) - win.pinnedCount * (tabStrip.pinW + tabStrip.gap);
                return Math.min(Theme.dp(220), Math.max(Theme.dp(44), room / loose - tabStrip.gap));
            }
            // laid out here, not by a view: each chip's slot is the width of the
            // ones before it, worked out again whenever any of them changes. a
            // view plans its moves from widths still changing and leaves gaps
            property real rowW: 0
            // the window's own tabs are in: from here on a new one opens out
            property bool ready: false

            // a width changing (a tab opening, folding, or all of them making room)
            // moves the rest with it, frame by frame. a jump (a tab moved, pinned)
            // starts each chip from where it was drawn and eases it home
            function relayout(jump) {
                var x = 0;
                for (var i = 0; i < tabRep.count; i++) {
                    var c = tabRep.itemAt(i);
                    if (!c)
                        continue;

                    if (jump && c.placed && Theme.motionScale > 0) {
                        var was = c.x;
                        c.slotX = x;
                        c.shift = was - x;
                        c.settle();
                    } else {
                        c.slotX = x;
                    }
                    x += c.width + tabStrip.gap * Math.max(0, Math.min(1, Math.min(c.enter, c.keep)));
                }
                tabStrip.rowW = Math.max(0, x - tabStrip.gap);
            }
            // a tab from another window held over this one, and where it would go
            readonly property bool foreign: win.app.tabDrag !== null && win.app.tabDrag.win !== win.winId
            property int dropAt: -1

            // the tab in the air goes where the pointer is among the others: in its
            // own window it moves there at once, from another a marker shows the spot
            function track(x) {
                var d = win.app.tabDrag;
                if (!d || win.choosing)
                    return ;

                var cx = x - tabList.x;
                var count = 0;
                for (var i = win.pinnedCount; i < win.tabs.length; i++) {
                    var c = win.chipOf(win.tabs[i].vid);
                    if (win.tabs[i].vid !== d.vid && c && c.slotX + c.width / 2 < cx)
                        count++;

                }
                var at = win.pinnedCount + count;
                if (d.win === win.winId) {
                    var from = win.tabs.indexOf(win.tabFor(d.vid));
                    if (from >= 0 && from !== at)
                        win.moveTab(from, at);

                } else {
                    tabStrip.dropAt = at;
                }
            }

            function markerX(at) {
                if (at < 0)
                    return 0;

                var t = at < win.tabs.length ? win.chipOf(win.tabs[at].vid) : null;
                if (t)
                    return tabList.x + t.slotX - tabStrip.gap / 2;

                var last = win.tabs.length > 0 ? win.chipOf(win.tabs[win.tabs.length - 1].vid) : null;
                return last ? tabList.x + last.slotX + last.width + tabStrip.gap / 2 : tabList.x;
            }

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: bar.bottom
            anchors.leftMargin: Math.max(Theme.dp(12), win.dockWidth)
            anchors.rightMargin: Theme.dp(12)
            height: !win.choosing || win.tabs.length > 1 ? Theme.dp(44) : 0
            visible: height > 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveStandard
                }

            }

            // the pill under the open tab, in its colour when it has one. it sits
            // on its chip, growing and moving with it; going to another tab it
            // starts from where it was and glides over (glideTo)
            Rectangle {
                id: pill

                readonly property Item at: win.currentChip
                property real shiftX: 0
                property real shiftW: 0

                function glideTo(c) {
                    var fromX = pill.x, fromW = pill.width, had = pill.at !== null && pill.width > 0;
                    pillGlide.stop();
                    pill.shiftX = 0;
                    pill.shiftW = 0;
                    win.currentChip = c;
                    if (!had || !c || Theme.motionScale <= 0)
                        return ;

                    pill.shiftX = fromX - pill.x;
                    pill.shiftW = fromW - pill.width;
                    pillGlide.restart();
                }

                x: (at ? tabList.x + at.x : 0) + pill.shiftX
                y: tabList.y
                width: Math.max(0, (at ? at.width : 0) + pill.shiftW)
                height: Theme.dp(36)
                radius: height / 2
                visible: at !== null && !(win.app.tabDrag !== null && win.tab && win.app.tabDrag.vid === win.tab.vid)
                color: win.tab && win.tab.colour !== "" ? win.app.container(win.tab.colour) : Theme.surfaceHigh

                ParallelAnimation {
                    id: pillGlide

                    NumberAnimation {
                        target: pill
                        property: "shiftX"
                        to: 0
                        duration: Theme.durFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                    NumberAnimation {
                        target: pill
                        property: "shiftW"
                        to: 0
                        duration: Theme.durFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            Item {
                id: tabList

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(tabStrip.rowW, parent.width - Theme.dp(44))
                height: Theme.dp(36)

                Repeater {
                    id: tabRep

                    model: tabModel
                    onItemAdded: Qt.callLater(tabStrip.relayout, false)
                    onItemRemoved: Qt.callLater(tabStrip.relayout, false)

                    delegate: Rectangle {
                        id: chip

                        required property string vid
                        required property bool leaving
                        readonly property var tab: win.tabs.length >= 0 ? win.tabFor(chip.vid) : null
                        readonly property bool on: chip.tab !== null && chip.tab === win.tab
                        readonly property bool dragged: win.app.tabDrag !== null && win.app.tabDrag.vid === chip.vid
                        // kept once the tab is gone, for the moment it folds away
                        property string title: ""
                        property string slot: "folder"
                        property string tint: ""
                        property bool pinned: false
                        // files held over it, to be dropped in its folder
                        property bool dropping: false
                        // how far open: a new tab grows from 0, a closed one folds to 0
                        property real enter: 1
                        property real keep: 1
                        property real base: chip.pinned ? tabStrip.pinW : tabStrip.tabW
                        // where the strip puts it, and how far off that it is still
                        // drawn after a jump, easing to nothing
                        property real slotX: 0
                        property real shift: 0
                        property bool placed: false

                        function settle() {
                            settleAnim.restart();
                        }

                        x: chip.slotX + chip.shift
                        // one travelling further than its own width passes over the rest
                        z: Math.abs(chip.shift) > chip.width ? 2 : chip.dragged ? 1 : 0
                        onWidthChanged: tabStrip.relayout(false)

                        width: Math.max(0, chip.base * Math.min(chip.enter, chip.keep))
                        height: Theme.dp(36)
                        radius: height / 2
                        clip: true
                        opacity: Math.max(0, Math.min(1, Math.min(chip.enter, chip.keep))) * (chip.dragged ? 0.3 : 1)
                        scale: chip.dropping ? 1.05 : chipArea.pressed && !chipArea.drag.active ? 0.95 : 1
                        // the pill under the open tab is the strip's; a tab with a colour
                        // wears a little of it when it is not the open one
                        color: chip.dropping ? Theme.alpha(Theme.accent, 0.24) : chip.tint !== "" && !chip.on ? Theme.alpha(win.app.container(chip.tint), 0.6) : "transparent"
                        onLeavingChanged: {
                            if (chip.leaving)
                                fold.start();

                        }
                        onOnChanged: {
                            if (chip.on)
                                pill.glideTo(chip);

                        }
                        Component.onCompleted: {
                            win.chipItems[chip.vid] = chip;
                            if (chip.on)
                                pill.glideTo(chip);

                            // a tab opened later grows out of nothing, the rest making room
                            if (tabStrip.ready) {
                                chip.enter = 0;
                                grow.start();
                            }
                            tabStrip.relayout(false);
                            Qt.callLater(function() {
                                chip.placed = true;
                            });
                        }
                        Component.onDestruction: {
                            if (win.chipItems[chip.vid] === chip)
                                delete win.chipItems[chip.vid];

                            if (win.currentChip === chip)
                                win.currentChip = null;

                        }

                        Binding on title {
                            when: chip.tab !== null
                            value: chip.tab ? chip.tab.title : ""
                            restoreMode: Binding.RestoreNone
                        }

                        Binding on slot {
                            when: chip.tab !== null
                            value: chip.tab ? (chip.tab.searching ? "search" : win.app.slotForPath(chip.tab.path)) : "folder"
                            restoreMode: Binding.RestoreNone
                        }

                        Binding on tint {
                            when: chip.tab !== null
                            value: chip.tab ? chip.tab.colour : ""
                            restoreMode: Binding.RestoreNone
                        }

                        Binding on pinned {
                            when: chip.tab !== null
                            value: chip.tab ? chip.tab.pinned : false
                            restoreMode: Binding.RestoreNone
                        }

                        // widths ease without overshoot: the row has a fixed room to fill, and
                        // one tab overshooting pushes the last past the edge. the bounce is left
                        // to the jumps and the pill
                        NumberAnimation {
                            id: grow

                            target: chip
                            property: "enter"
                            to: 1
                            duration: Theme.durMedium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                        NumberAnimation {
                            id: settleAnim

                            target: chip
                            property: "shift"
                            to: 0
                            duration: Theme.durDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                        NumberAnimation {
                            id: fold

                            target: chip
                            property: "keep"
                            to: 0
                            duration: Theme.durMedium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.easeEmphasizedAccel
                            onFinished: win.dropTabRow(chip.vid)
                        }

                        Behavior on base {
                            NumberAnimation {
                                duration: Theme.durMedium
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveStandard
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                        Behavior on opacity {
                            enabled: !chip.leaving

                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                        HoverLayer {
                            area: chipArea
                        }

                        // the glyph of the place the tab is in, filled for the open one
                        PlaceGlyph {
                            id: chipIcon

                            x: chip.pinned ? (chip.base - width) / 2 : Theme.dp(12)
                            anchors.verticalCenter: parent.verticalCenter
                            slot: chip.slot
                            size: Theme.dp(18)
                            fill: chip.on || chip.dropping ? 1 : 0
                            color: chip.tint !== "" ? win.app.ink(chip.tint) : chip.on ? Theme.accent : Theme.subtext
                        }

                        LText {
                            anchors.left: chipIcon.right
                            anchors.leftMargin: Theme.dp(8)
                            anchors.right: chipClose.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !chip.pinned
                            role: "labelLarge"
                            text: chip.title
                            color: chip.tint !== "" && chip.on ? win.app.onContainer(chip.tint) : chip.on ? Theme.text : Theme.subtext
                            elide: Text.ElideRight

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durShort
                                }

                            }

                        }

                        // what a drag carries: which tab, for the strip it lands on
                        Item {
                            id: proxy

                            Drag.active: chipArea.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.MoveAction
                            Drag.proposedAction: Qt.MoveAction
                            Drag.imageSource: win.tabImage
                            Drag.hotSpot: Qt.point(dragCard.width / 2, dragCard.height / 2)
                            Drag.mimeData: ({
                                "application/x-lucid-lumen-tab": chip.vid
                            })
                            Drag.onDragStarted: {
                                win.app.tabDrag = {
                                    "win": win.winId,
                                    "vid": chip.vid
                                };
                            }
                            Drag.onDragFinished: (action) => {
                                var d = win.app.tabDrag;
                                win.app.tabDrag = null;
                                tabStrip.dropAt = -1;
                                // taken by no strip: it becomes a window of its own
                                if (action === Qt.IgnoreAction && d)
                                    Qt.callLater(function() {
                                    win.tearOffTab(d.vid);
                                });

                            }
                        }

                        MouseArea {
                            id: chipArea

                            anchors.fill: parent
                            enabled: !chip.leaving
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            // pinned tabs stay put; a dialog's tabs stay in the dialog
                            drag.target: chip.pinned || win.choosing ? null : proxy
                            drag.threshold: Theme.dp(10)
                            onPressed: (mouse) => {
                                if (mouse.button !== Qt.LeftButton || chip.pinned)
                                    return ;

                                dragCard.title = chip.title;
                                dragCard.slot = chip.slot;
                                dragCard.tint = chip.tint;
                                dragCard.grabToImage(function(r) {
                                    win.tabImage = r.url;
                                });
                            }
                            onClicked: (mouse) => {
                                var i = win.tabs.indexOf(chip.tab);
                                if (i < 0)
                                    return ;

                                if (mouse.button === Qt.MiddleButton) {
                                    win.closeTab(i);
                                } else if (mouse.button === Qt.RightButton) {
                                    var p = chipArea.mapToItem(root, mouse.x, mouse.y);
                                    win.tabMenu(i, p.x, p.y);
                                } else {
                                    win.switchTab(i);
                                }
                            }
                        }

                        // a pinned tab is only its glyph: its name shows on a rest
                        Tip {
                            text: chip.pinned ? chip.title : ""
                        }

                        IconButton {
                            id: chipClose

                            visible: !chip.pinned && (chip.on || chip.base >= Theme.dp(96))
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(4)
                            anchors.verticalCenter: parent.verticalCenter
                            size: "xs"
                            icon: "close"
                            tooltip: "Close tab"

                            Tip {
                            }

                            onClicked: {
                                var i = win.tabs.indexOf(chip.tab);
                                if (i >= 0)
                                    win.closeTab(i);

                            }
                        }

                        // files dragged onto a tab: dropped there they go into its folder (the
                        // trash, for the trash's tab); held there a moment, the tab opens, to be
                        // dropped somewhere in it
                        DropArea {
                            // a tab a drop can land in: a folder, or the trash
                            readonly property bool takes: chip.tab !== null && !chip.tab.searching && !chip.tab.isRecent && chip.tab.path !== ""

                            anchors.fill: parent
                            keys: ["text/uri-list"]
                            onEntered: (drag) => {
                                if (!takes) {
                                    drag.accepted = false;
                                    return ;
                                }
                                drag.accept(drag.proposedAction);
                                chip.dropping = true;
                                springOpen.restart();
                            }
                            // a move left unaccepted reads as the drag leaving: it left and
                            // came back on every step, and the timer never ran out
                            onPositionChanged: (drag) => {
                                if (takes)
                                    drag.accept(drag.proposedAction);

                            }
                            onExited: {
                                chip.dropping = false;
                                springOpen.stop();
                            }
                            onDropped: (drop) => {
                                chip.dropping = false;
                                springOpen.stop();
                                var uris = [];
                                for (var k = 0; k < drop.urls.length; k++) uris.push(drop.urls[k].toString())
                                if (!takes || uris.length === 0)
                                    return ;

                                if (chip.tab.isTrash) {
                                    drop.acceptProposedAction();
                                    win.trashUris(uris);
                                    return ;
                                }
                                // already in that folder: nothing to move
                                if (uris.every(function(u) {
                                    return u.indexOf("file://") === 0 && win.app.parentOf(decodeURIComponent(u.slice(7))) === chip.tab.path;
                                })) {
                                    drop.accepted = false;
                                    return ;
                                }
                                folderPane.dropInto(chip.tab.path, drop);
                            }
                        }

                        Timer {
                            id: springOpen

                            interval: 650
                            onTriggered: {
                                var i = win.tabs.indexOf(chip.tab);
                                if (i >= 0 && chip.dropping)
                                    win.switchTab(i);

                            }
                        }

                    }

                }

            }

            IconButton {
                anchors.left: tabList.right
                anchors.leftMargin: Theme.dp(6)
                anchors.verticalCenter: parent.verticalCenter
                size: "xs"
                icon: "add"
                tooltip: "New tab"

                Tip {
                }

                onClicked: win.newTab(win.tab ? win.tab.path : win.app.home)

                // folders dropped on it open in tabs of their own (a file opens its
                // folder, picked out). taken as a link, never a move: a source told
                // its files moved might clear them away
                DropArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.dp(6)
                    enabled: !win.choosing
                    keys: ["text/uri-list"]
                    onDropped: (drop) => {
                        var paths = [];
                        for (var k = 0; k < drop.urls.length; k++) {
                            var u = drop.urls[k].toString();
                            if (u.indexOf("file://") === 0)
                                paths.push(decodeURIComponent(u.slice(7)));

                        }
                        if (paths.length === 0)
                            return ;

                        drop.accept((drop.supportedActions & Qt.LinkAction) ? Qt.LinkAction : Qt.CopyAction);
                        for (var i = 0; i < paths.length; i++) win.newTab(paths[i], i < paths.length - 1, true)
                    }
                }
            }

            // where a tab from another window would land
            Rectangle {
                visible: tabStrip.foreign && tabStrip.dropAt >= 0
                x: tabStrip.markerX(tabStrip.dropAt) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(3)
                height: Theme.dp(26)
                radius: width / 2
                color: Theme.accent

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

            }

            // a tab dragged along here: moved in this window, or brought from another.
            // on only while a tab is in the air: qt tells the drop under a drag that
            // it left whenever one in front of it could take drops, even one that then
            // turns the drag down, so files dragged onto a tab left it on every step
            DropArea {
                anchors.fill: parent
                enabled: !win.choosing && win.app.tabDrag !== null
                keys: ["application/x-lucid-lumen-tab"]
                onEntered: (drag) => {
                    drag.accept(Qt.MoveAction);
                    tabStrip.track(drag.x);
                }
                onPositionChanged: (drag) => {
                    return tabStrip.track(drag.x);
                }
                onExited: tabStrip.dropAt = -1
                onDropped: (drop) => {
                    var d = win.app.tabDrag;
                    var at = tabStrip.dropAt >= 0 ? tabStrip.dropAt : win.tabs.length;
                    drop.accept(Qt.MoveAction);
                    tabStrip.dropAt = -1;
                    if (d && d.win !== win.winId)
                        win.app.transferLater(d.win, d.vid, win, at);

                }
            }

        }

        // the dragged tab, as a chip on its own: the picture the pointer carries
        Rectangle {
            id: dragCard

            property string title: ""
            property string slot: "folder"
            property string tint: ""

            x: -10000
            width: Math.min(Theme.dp(240), Math.ceil(cardMetrics.advanceWidth) + Theme.dp(60))
            height: Theme.dp(40)
            radius: height / 2
            color: dragCard.tint !== "" ? win.app.container(dragCard.tint) : Theme.surfaceHighest
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.1)

            PlaceGlyph {
                x: Theme.dp(14)
                anchors.verticalCenter: parent.verticalCenter
                slot: dragCard.slot
                size: Theme.dp(18)
                color: dragCard.tint !== "" ? win.app.ink(dragCard.tint) : Theme.accent
            }

            // an eliding text reports its elided width, so measure the words
            TextMetrics {
                id: cardMetrics

                font: cardText.font
                text: dragCard.title
            }

            LText {
                id: cardText

                x: Theme.dp(42)
                width: dragCard.width - Theme.dp(56)
                anchors.verticalCenter: parent.verticalCenter
                role: "labelLarge"
                text: dragCard.title
                color: Theme.text
                elide: Text.ElideRight
            }

        }

        // the preview pane, beside the folder
        PreviewPane {
            id: previewPane

            app: win.app
            win: win
            anchors.top: tabStrip.bottom
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(12)
            anchors.bottomMargin: Theme.dp(12) + (win.choosing ? chooserBar.height : 0)
            width: Math.max(0, win.previewW - Theme.dp(12))
            visible: width > 0.5
            clip: true
        }

        // the folder, in lucid's floating pane
        Rectangle {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabStrip.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: Math.max(Theme.dp(12), win.dockWidth)
            anchors.rightMargin: Theme.dp(12) + win.previewW
            anchors.bottomMargin: Theme.dp(12) + (win.choosing ? chooserBar.height : 0)
            color: Theme.withBlur(Theme.bgSunken)
            radius: Theme.shapeXl
            clip: true

            FolderPane {
                id: folderPane

                app: win.app
                win: win
                tab: win.tab
                widthDelta: win.settleDelta + win.previewW - win.previewTarget
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: foot.top
                anchors.topMargin: Theme.dp(6)
                focus: true
            }

            StatusBar {
                id: foot

                app: win.app
                win: win
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: implicitHeight
            }

        }

        // an app's open or save dialog: the name to save under, the kind of file
        // to show, and the answer
        Item {
            id: chooserBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Math.max(Theme.dp(12), win.dockWidth)
            anchors.rightMargin: Theme.dp(12)
            height: win.choosing ? Theme.dp(64) : 0
            visible: win.choosing

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -Theme.dp(4)
                spacing: Theme.dp(10)

                TextField {
                    id: saveName

                    visible: win.saving && win.chooser.mode === "save"
                    width: Math.min(Theme.dp(380), chooserBar.width * 0.42)
                    height: Theme.dp(44)
                    variant: "filled"
                    label: "Name"
                    text: win.choosing ? win.chooser.name : ""
                    onAccepted: win.acceptChooser()
                    onEscaped: win.cancelChooser()
                    Component.onCompleted: {
                        // the name ready to type over, its extension kept
                        if (visible)
                            Qt.callLater(function() {
                            saveName.input.forceActiveFocus();
                            var dot = saveName.text.lastIndexOf(".");
                            saveName.input.select(0, dot > 0 ? dot : saveName.text.length);
                        });

                    }
                }

                LText {
                    visible: win.choosing && win.chooser.mode === "saveFiles"
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyMedium"
                    text: win.choosing && win.chooser.files.length > 0 ? (win.chooser.files.length === 1 ? "“" + win.chooser.files[0] + "” goes in the open folder" : win.chooser.files.length + " files go in the open folder") : ""
                    color: Theme.subtext
                }

                // the kinds of file the app asked for, as a dropdown
                Dropdown {
                    id: kindField

                    visible: win.chooserFilter >= 0
                    host: root
                    label: "File type"
                    options: !win.choosing ? [] : win.chooser.filters.map(function(f) {
                        return {
                            "label": f[0],
                            "hint": win.ruleHint(f[1])
                        };
                    })
                    current: win.chooserFilter
                    onPicked: (index) => {
                        return win.chooserFilter = index;
                    }
                    onDismissed: folderPane.takeFocus()
                }

            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -Theme.dp(4)
                spacing: Theme.dp(8)

                Button {
                    variant: "text"
                    text: "Cancel"
                    onClicked: win.cancelChooser()
                }

                Button {
                    variant: "filled"
                    text: win.acceptLabel
                    disabled: !win.canAccept
                    onClicked: win.acceptChooser()
                }

            }

        }

        // under the drawer: dims the folder, and a click there puts the drawer away
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: Theme.dp(64)
            z: 249
            color: Theme.scrim
            opacity: win.narrow && win.drawer ? 0.32 : 0
            visible: opacity > 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: win.drawer = false
                onWheel: (wheel) => {
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Snackbar {
            id: snack

            onActed: (payload) => {
                if (payload)
                    win.app.undoEntry(payload);

            }
        }

        LumenMenu {
            id: menu

            z: 400
            onShownChanged: {
                if (!menu.shown && !dialog.shown && !server.shown)
                    folderPane.takeFocus();

            }
        }

        LumenDialog {
            id: dialog

            z: 500
            onShownChanged: {
                if (!dialog.shown && !server.shown)
                    folderPane.takeFocus();

            }
        }

        ServerDialog {
            id: server

            z: 510
            app: win.app
            win: win
            onShownChanged: {
                if (!server.shown && !dialog.shown)
                    folderPane.takeFocus();

            }
        }

    }

    // the render rig's hook: LUMEN_RIG is a json list of steps to play before the
    // picture, so menus and dialogs can be looked at without a screen
    Timer {
        interval: 1400
        running: (Quickshell.env("LUMEN_RIG") || "") !== ""
        onTriggered: {
            var steps = JSON.parse(Quickshell.env("LUMEN_RIG"));
            for (var i = 0; i < steps.length; i++) {
                var s = steps[i];
                var t = win.tab;
                if (s.go)
                    t.go(s.go);
                if (s.view)
                    win.app.prefs.view = s.view;
                if (s.select !== undefined)
                    typeof s.select === "number" ? t.selectOnly(s.select) : t.selectByName(s.select);
                if (s.add !== undefined)
                    t.toggle(s.add);
                if (s.all)
                    t.selectAll();
                if (s.filter !== undefined)
                    win.startFilter(s.filter);
                if (s.search)
                    t.search(s.search);
                if (s.tab)
                    win.newTab(s.tab);
                if (s.menu === "item")
                    win.itemMenu(s.x, s.y);
                if (s.menu === "background")
                    win.backgroundMenu(s.x, s.y);
                if (s.menu === "more")
                    win.moreMenu(s.x, s.y);
                if (s.dialog === "rename")
                    win.renameSelection();
                if (s.dialog === "newFolder")
                    win.newFolder();
                if (s.dialog === "delete")
                    win.deleteSelection();
                if (s.dialog === "props")
                    win.properties(null);
                if (s.dialog === "openWith")
                    win.openWith();
                if (s.dialog === "connect")
                    win.connectServer(s.address || "");
                if (s.typed)
                    win.goTyped(s.typed);
                if (s.say)
                    win.say(s.say, s.action || "", null);
                if (s.zoom)
                    win.zoom(s.zoom);
            }
        }
    }

    // the render rig's hook: a picture of the window, then quit
    Timer {
        interval: Number(Quickshell.env("LUMEN_SHOT_MS") || 2600)
        running: (Quickshell.env("LUMEN_SHOT") || "") !== ""
        onTriggered: root.grabToImage(function(r) {
            console.log("LUMEN GRAB", r.saveToFile(Quickshell.env("LUMEN_SHOT")));
            Qt.quit();
        })
    }

}
