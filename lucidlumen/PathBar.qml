import QtQuick
import qs
import qs.lucidui

// where the tab is, and the way to anywhere: a row of folders to click back to
// (each one a drop target), or one field for both a path and a search. typed
// words filter the folder at once and Enter searches the whole disk; a path
// (/ ~ or a uri) goes there. ctrl+l edits the path, ctrl+f starts a search
Rectangle {
    id: bar

    required property var app
    required property var win
    readonly property var tab: bar.win.tab
    property bool editing: false
    property alias text: field.text
    readonly property bool typedPath: bar.isPath(field.text)
    readonly property bool searching: bar.tab !== null && bar.tab.searching
    readonly property var crumbs: {
        var t = bar.tab;
        if (!t)
            return [];

        if (t.isTrash)
            return [{
                "label": "Trash",
                "path": "trash:///",
                "glyph": "delete"
            }];

        if (t.isRecent)
            return [{
                "label": "Recent",
                "path": "recent:///",
                "glyph": "schedule"
            }];

        // someone else's folder through gvfs's admin://: its folders as they are
        // here, the last one where it's open now
        var admin = t.path.indexOf("admin://") === 0;
        var p = admin ? (decodeURIComponent(t.path.replace(/^admin:\/\/[^\/]*/, "")).replace(/\/+$/, "") || "/") : t.path;
        // an address: its server, then its folders
        if (!admin && t.path.indexOf("://") !== -1) {
            var m = /^([a-z0-9+.-]+:\/\/[^\/]*)(\/.*)?$/i.exec(t.path);
            if (m) {
                var at = m[1], list = [{
                    "label": bar.app.titleFor(m[1] + "/"),
                    "path": m[1] + "/",
                    "glyph": "lan"
                }];
                var segs = (m[2] || "").split("/").filter(function(s) {
                    return s !== "";
                });
                for (var k = 0; k < segs.length; k++) {
                    at += "/" + segs[k];
                    list.push({
                        "label": decodeURIComponent(segs[k]),
                        "path": at,
                        "glyph": ""
                    });
                }
                return list;
            }
        }
        var home = bar.app.home, out = [];
        var rest;
        if (p === home || p.indexOf(home + "/") === 0) {
            out.push({
                "label": "Home",
                "path": home,
                "glyph": "home"
            });
            rest = p.slice(home.length);
        } else {
            // on another drive, its crumbs start from the drive
            var v = bar.app.volumeAt(p);
            out.push(v ? {
                "label": v.label,
                "path": v.path,
                "glyph": v.remote ? "lan" : "hard_drive"
            } : {
                "label": bar.app.systemName,
                "path": "/",
                "glyph": "computer"
            });
            rest = v ? p.slice(v.path.length) : (p === "/" ? "" : p);
        }
        var acc = out[0].path === "/" ? "" : out[0].path;
        var parts = rest.split("/").filter(function(s) {
            return s !== "";
        });
        for (var i = 0; i < parts.length; i++) {
            acc += "/" + parts[i];
            out.push({
                "label": parts[i],
                "path": acc,
                "glyph": ""
            });
        }
        if (admin)
            out[out.length - 1].path = t.path;

        return out;
    }

    // a path is what the field goes to; anything else is words to find
    function isPath(t) {
        t = (t || "").trim();
        return t.charAt(0) === "/" || t.charAt(0) === "~" || t.indexOf("://") !== -1 || t === "." || t === ".." || t.indexOf("./") === 0 || t.indexOf("../") === 0;
    }

    // the path to edit, or text to start with (a search, a typed first letter)
    function edit(start) {
        bar.editing = true;
        if (start === undefined)
            field.text = bar.tab ? (bar.tab.isSpecial ? bar.tab.path : bar.tab.path.replace(bar.app.home, "~")) : "";
        else
            field.text = start;
        var all = start === undefined;
        Qt.callLater(function() {
            field.input.forceActiveFocus();
            if (all)
                field.input.selectAll();
            else
                field.input.cursorPosition = field.text.length;
        });
        bar.typed();
    }

    // as it is typed: words filter the folder, or redo the search on show
    function typed() {
        var t = bar.tab;
        if (!t)
            return ;

        var text = field.text.trim();
        if (bar.isPath(text) || text === "") {
            if (t.filter !== "") {
                t.filter = "";
                t.apply();
            }
            return ;
        }
        if (t.searching) {
            again.restart();
            return ;
        }
        t.filter = text;
        t.apply();
    }

    function accept() {
        var t = bar.tab, text = field.text.trim();
        again.stop();
        if (!t || text === "") {
            bar.close();
            return ;
        }
        if (bar.isPath(text)) {
            bar.close();
            bar.win.goTyped(text);
            return ;
        }
        // a name in this folder goes there; any other words search everywhere
        var hit = t.isSpecial ? null : t.raw.find(function(it) {
            return it.name === text;
        });
        if (hit && hit.kind === "dir") {
            bar.close();
            bar.win.go(hit.path);
            return ;
        }
        t.search(text);
        bar.editing = false;
        bar.win.pane.takeFocus();
    }

    // escape: a search ends, a filter clears, the field goes
    function cancel() {
        again.stop();
        var t = bar.tab;
        if (t && t.searching)
            bar.win.endSearch();
        else if (t && t.filter !== "")
            bar.win.clearFilter();
        bar.close();
    }

    function close() {
        bar.editing = false;
        bar.win.pane.takeFocus();
    }

    // the field follows the tab: its filter or its search, or nothing
    function sync() {
        var t = bar.tab;
        var want = !t ? "" : t.searching ? t.searchQuery : t.filter;
        if (want !== "") {
            if (field.text.trim() !== want.trim())
                field.text = want;

            if (!t.searching)
                bar.editing = true;

        } else if (!field.input.activeFocus) {
            bar.editing = false;
        }
    }

    color: Theme.surfaceHigh
    radius: height / 2
    implicitHeight: Theme.dp(40)

    // the crumbs as rows, changed only where the path does: a new folder slides
    // in at the end and climbing up lets the rest fade away
    function syncCrumbs() {
        var keep = 0;
        while (keep < crumbModel.count && keep < bar.crumbs.length && crumbModel.get(keep).path === bar.crumbs[keep].path)keep++
        // a kept crumb can still be renamed, like the system drive once the daemon names it
        for (var k = 0; k < keep; k++) {
            if (crumbModel.get(k).label !== bar.crumbs[k].label)
                crumbModel.setProperty(k, "label", bar.crumbs[k].label);

            if (crumbModel.get(k).glyph !== bar.crumbs[k].glyph)
                crumbModel.setProperty(k, "glyph", bar.crumbs[k].glyph);

        }
        while (crumbModel.count > keep)crumbModel.remove(crumbModel.count - 1)
        for (var i = keep; i < bar.crumbs.length; i++) crumbModel.append(bar.crumbs[i])
        Qt.callLater(trail.positionViewAtEnd);
    }

    onCrumbsChanged: bar.syncCrumbs()
    Component.onCompleted: bar.syncCrumbs()

    ListModel {
        id: crumbModel
    }

    Timer {
        id: again

        interval: 350
        onTriggered: {
            var q = field.text.trim();
            if (q === "" || bar.isPath(q))
                bar.win.endSearch();
            else
                bar.tab.search(q);
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: !bar.editing
        onClicked: bar.searching ? bar.edit(bar.tab.searchQuery) : bar.edit()
    }

    ListView {
        id: trail

        anchors.fill: parent
        anchors.leftMargin: Theme.dp(4)
        anchors.rightMargin: Theme.dp(4)
        visible: !bar.editing && !bar.searching
        orientation: ListView.Horizontal
        interactive: false
        clip: true
        model: crumbModel
        spacing: 0
        onWidthChanged: Qt.callLater(trail.positionViewAtEnd)

        add: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.durShort
                }

                NumberAnimation {
                    property: "x"
                    from: trail.contentWidth
                    duration: Theme.durFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Theme.durQuick
            }

        }

        delegate: Row {
            id: crumb

            required property string label
            required property string path
            required property string glyph
            required property int index
            readonly property bool last: crumb.index === trail.count - 1
            property bool hovering: false

            height: trail.height

            Icon {
                visible: crumb.index > 0
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron_right"
                size: Theme.dp(16)
                color: Theme.subtext
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: inner.implicitWidth + Theme.dp(20)
                height: Theme.dp(32)
                radius: height / 2
                color: crumb.hovering ? Theme.alpha(Theme.accent, 0.22) : "transparent"

                HoverLayer {
                    area: crumbArea
                }

                Row {
                    id: inner

                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Icon {
                        visible: crumb.glyph !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        name: crumb.glyph || "folder"
                        size: Theme.dp(18)
                        color: crumb.last ? Theme.text : Theme.subtext
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: crumb.last ? "titleSmall" : "labelLarge"
                        text: crumb.label
                        color: crumb.last ? Theme.text : Theme.subtext
                    }

                }

                MouseArea {
                    id: crumbArea

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton)
                            bar.win.newTab(crumb.path);
                        else
                            bar.win.go(crumb.path);
                    }
                }

                DropArea {
                    anchors.fill: parent
                    enabled: !crumb.last && crumb.path.indexOf("://") === -1
                    keys: ["text/uri-list"]
                    onEntered: crumb.hovering = true
                    onExited: crumb.hovering = false
                    onDropped: (drop) => {
                        crumb.hovering = false;
                        bar.win.pane.dropInto(crumb.path, drop);
                    }
                }

            }

        }

    }

    // a long path fades out at the start rather than cutting a name in half
    Rectangle {
        anchors.left: trail.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.dp(28)
        visible: trail.visible && trail.contentWidth > trail.width
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: bar.color
            }

            GradientStop {
                position: 1
                color: Theme.alpha(bar.color, 0)
            }

        }
    }

    // a search on show: what was asked, and the way out of it
    Item {
        anchors.fill: parent
        visible: !bar.editing && bar.searching

        Icon {
            id: lens

            x: Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: Theme.dp(18)
            color: Theme.accent
        }

        LText {
            anchors.left: lens.right
            anchors.leftMargin: Theme.dp(10)
            anchors.right: stop.left
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            role: "titleSmall"
            text: bar.searching ? "“" + bar.tab.searchQuery + "” everywhere" + (bar.tab.searchDone ? "" : "…") : ""
            color: Theme.text
            elide: Text.ElideRight
        }

        IconButton {
            id: stop

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(4)
            anchors.verticalCenter: parent.verticalCenter
            size: "xs"
            icon: "close"
            tooltip: "End search"
            onClicked: bar.win.endSearch()

            Tip {
            }

        }

    }

    TextField {
        id: field

        anchors.fill: parent
        visible: bar.editing
        variant: "search"
        icon: bar.typedPath ? "folder_open" : "search"
        clearable: true
        containerColor: Theme.surfaceHigh
        placeholder: "Go to a folder, or search everything"
        onTextEdited: bar.typed()
        onAccepted: bar.accept()
        onEscaped: bar.cancel()
        input.onActiveFocusChanged: {
            // an unfocused field stays to show a filter still at work
            if (!field.input.activeFocus && bar.editing && (bar.tab === null || bar.tab.filter === "") && !bar.searching)
                bar.editing = false;

        }
    }

}
