import QtQuick
import qs
import qs.lucidui

// the usage map: a folder's contents as tiles sized by what they hold. a folder
// tile zooms in, the crumbs and the up arrow zoom back out
Item {
    id: map

    readonly property bool isGroupItem: true
    property bool groupFirst: true
    property bool groupLast: true
    property var pal: null
    property var scan: null
    property string volName: ""
    property var stack: []
    property var selected: null
    property int front: 0
    readonly property var current: map.stack.length > 0 ? map.stack[map.stack.length - 1] : null
    readonly property string currentPath: map.pathAt(map.stack.length)
    // the path on screen, kept so a fresh scan can open at the same place
    property string lastPath: ""
    readonly property var frontLevel: map.front === 0 ? levelA : levelB
    readonly property var hovered: map.frontLevel.hovered
    readonly property var homeStack: map.scan && map.scan.home ? map.stackFor(map.scan.home) : null
    readonly property bool atHome: map.homeStack !== null && map.currentPath.indexOf(map.scan.home) === 0
    readonly property bool busy: Storage.detailPath !== "" && Storage.detailPath === map.currentPath
    readonly property int outerRadius: Theme.rad(26)
    readonly property int innerRadius: Theme.dp(6)
    // the size tiles are laid out for; a resize stretches them until it settles
    property real layoutW: 0
    property real layoutH: 0
    readonly property var visibleKinds: {
        var seen = [];
        var t = map.frontLevel.tiles || [];
        for (var i = 0; i < t.length; i++) {
            var n = t[i].node;
            if (n.t !== 2 && !n.u && seen.indexOf(n.k || 0) < 0)
                seen.push(n.k || 0);

        }
        return seen.sort();
    }

    signal trashRequested(string path, var node)

    function pathAt(depth) {
        if (!map.scan || depth < 1)
            return "";

        var p = map.scan.root;
        for (var i = 1; i < depth; i++) p = (p === "/" ? "" : p) + "/" + map.stack[i].n
        return p;
    }

    function pathOf(node) {
        if (!node || node === map.current)
            return map.currentPath;

        return (map.currentPath === "/" ? "" : map.currentPath) + "/" + node.n;
    }

    // the chain of nodes from the scan's root down to path, or null
    function stackFor(path) {
        if (!map.scan || !map.scan.tree)
            return null;

        var root = map.scan.root;
        if (path !== root && path.indexOf(root === "/" ? "/" : root + "/") !== 0)
            return null;

        var parts = path === root ? [] : path.substring(root === "/" ? 1 : root.length + 1).split("/");
        var out = [map.scan.tree];
        var node = map.scan.tree;
        for (var i = 0; i < parts.length; i++) {
            var next = null;
            var kids = node.c || [];
            for (var j = 0; j < kids.length; j++) {
                if (kids[j].t === 1 && kids[j].n === parts[i]) {
                    next = kids[j];
                    break;
                }
            }
            if (!next)
                return out;

            out.push(next);
            node = next;
        }
        return out;
    }

    function worst(row, side) {
        var sum = 0;
        var hi = 0;
        var lo = Infinity;
        for (var i = 0; i < row.length; i++) {
            sum += row[i];
            hi = Math.max(hi, row[i]);
            lo = Math.min(lo, row[i]);
        }
        var s2 = side * side;
        var sum2 = sum * sum;
        return Math.max(s2 * hi / sum2, sum2 / (s2 * lo));
    }

    // squarified treemap (Bruls, Huizing, van Wijk); values sorted biggest first
    function squarify(values, x, y, w, h) {
        var out = [];
        var i = 0;
        while (i < values.length) {
            var side = Math.min(w, h);
            var row = [values[i]];
            var j = i + 1;
            var score = map.worst(row, side);
            while (j < values.length) {
                var next = row.concat([values[j]]);
                var s = map.worst(next, side);
                if (s > score)
                    break;

                row = next;
                score = s;
                j++;
            }
            var sum = 0;
            for (var k = 0; k < row.length; k++) sum += row[k]
            if (w >= h) {
                var cw = h > 0 ? sum / h : 0;
                var yy = y;
                for (var a = 0; a < row.length; a++) {
                    var hh = cw > 0 ? row[a] / cw : 0;
                    out.push({
                        "x": x,
                        "y": yy,
                        "w": cw,
                        "h": hh
                    });
                    yy += hh;
                }
                x += cw;
                w -= cw;
            } else {
                var rh = w > 0 ? sum / w : 0;
                var xx = x;
                for (var b = 0; b < row.length; b++) {
                    var ww = rh > 0 ? row[b] / rh : 0;
                    out.push({
                        "x": xx,
                        "y": y,
                        "w": ww,
                        "h": rh
                    });
                    xx += ww;
                }
                y += rh;
                h -= rh;
            }
            i = j;
        }
        return out;
    }

    // slivers too thin to see are folded into the folder's "small items" tile
    function layout(node, W, H) {
        if (!node || !node.c || W <= 0 || H <= 0)
            return [];

        var total = 0;
        for (var i = 0; i < node.c.length; i++) total += Math.max(0, node.c[i].s)
        if (total <= 0)
            return [];

        var min = total * 0.0006;
        var keep = [];
        var rest = 0;
        var restN = 0;
        for (var j = 0; j < node.c.length; j++) {
            var n = node.c[j];
            if (n.s <= 0)
                continue;

            if (n.t === 2) {
                rest += n.s;
                restN += n.o || 0;
            } else if (n.s >= min && keep.length < 150) {
                keep.push(n);
            } else {
                rest += n.s;
                restN += 1;
            }
        }
        if (rest > 0)
            keep.push({
            "n": "",
            "t": 2,
            "s": rest,
            "o": restN
        });

        keep.sort((p, q) => {
            return q.s - p.s;
        });
        var scale = W * H / total;
        var rects = map.squarify(keep.map((n) => {
            return n.s * scale;
        }), 0, 0, W, H);
        var out = [];
        for (var k = 0; k < keep.length; k++) out.push({
            "node": keep[k],
            "x": rects[k].x / W,
            "y": rects[k].y / H,
            "w": rects[k].w / W,
            "h": rects[k].h / H
        })
        return out;
    }

    // a folder the whole-disk pass only saw in outline gets looked at again
    function needsDetail(node) {
        if (!node || node.t !== 1 || node.u || node.d === 1 || node.s <= 0)
            return false;

        if (!node.c)
            return true;

        var small = 0;
        for (var i = 0; i < node.c.length; i++) {
            if (node.c[i].t === 2)
                small += node.c[i].s;

        }
        return small > node.s * 0.35;
    }

    function zoom(newStack, r, dir) {
        if (!newStack || newStack.length === 0)
            return ;

        var back = map.front === 0 ? levelA : levelB;
        var fresh = map.front === 0 ? levelB : levelA;
        map.selected = null;
        fresh.hovered = null;
        back.hovered = null;
        fresh.node = newStack[newStack.length - 1];
        fresh.z = 2;
        back.z = 1;
        if (dir === 1 && r && r.w > 0 && r.h > 0) {
            fresh.place(r.x, r.y, r.w, r.h, 0);
            fresh.moveTo(0, 0, 1, 1, 1, Theme.durShort);
            back.moveTo(-r.x / r.w, -r.y / r.h, 1 / r.w, 1 / r.h, 0, Theme.durShort);
        } else if (dir === -1 && r && r.w > 0 && r.h > 0) {
            fresh.place(-r.x / r.w, -r.y / r.h, 1 / r.w, 1 / r.h, 0);
            fresh.moveTo(0, 0, 1, 1, 1, Theme.durShort);
            back.moveTo(r.x, r.y, r.w, r.h, 0, Theme.durQuick);
        } else {
            fresh.place(0, 0, 1, 1, 0);
            fresh.moveTo(0, 0, 1, 1, 1, Theme.durShort);
            back.moveTo(back.zx, back.zy, back.zw, back.zh, 0, Theme.durShort);
        }
        map.front = 1 - map.front;
        map.stack = newStack;
        map.lastPath = map.currentPath;
        if (map.needsDetail(map.current))
            Storage.detail(map.current, map.currentPath);

    }

    function enter(tile) {
        var n = tile.node;
        if (n.t === 2) {
            if (map.current && map.current.d !== 1)
                Storage.detail(map.current, map.currentPath);

            return ;
        }
        if (n.t !== 1) {
            map.selected = map.selected === n ? null : n;
            return ;
        }
        if (n.u)
            return ;

        map.zoom(map.stack.concat([n]), tile, 1);
    }

    function jumpTo(i) {
        if (i < 0 || i >= map.stack.length - 1)
            return ;

        var target = map.stack.slice(0, i + 1);
        var child = map.stack[i + 1];
        var tiles = map.layout(target[target.length - 1], map.layoutW, map.layoutH);
        var r = null;
        for (var k = 0; k < tiles.length; k++) {
            if (tiles[k].node === child) {
                r = tiles[k];
                break;
            }
        }
        map.zoom(target, r, r ? -1 : 0);
    }

    function up() {
        map.jumpTo(map.stack.length - 2);
    }

    // anywhere in the tree, zooming when it is just below or above
    function goTo(path) {
        var s = map.stackFor(path);
        if (!s)
            return ;

        if (s.length === map.stack.length + 1 && s[s.length - 2] === map.current) {
            var tiles = map.frontLevel.tiles || [];
            for (var k = 0; k < tiles.length; k++) {
                if (tiles[k].node === s[s.length - 1])
                    return map.zoom(s, tiles[k], 1);

            }
        }
        if (s.length < map.stack.length && map.stack[s.length - 1] === s[s.length - 1])
            return map.jumpTo(s.length - 1);

        map.zoom(s, null, 0);
    }

    function describe(n) {
        if (!n)
            return "";

        var parts = [Storage.size(n.s)];
        var parent = map.current;
        if (parent && parent.s > 0 && n !== parent)
            parts.push(Math.max(1, Math.round(n.s / parent.s * 100)) + "% of " + (map.stack.length > 1 ? parent.n : map.volName));

        if (n.t === 1 && n.f !== undefined)
            parts.push(n.f === 1 ? "1 file" : (n.f || 0).toLocaleString(Qt.locale(), "f", 0) + " files");

        if (n.t === 0 && n.m && map.pal)
            parts.push("changed " + map.pal.ago(n.m));

        if (n.t === 2)
            parts.push("too small to draw one by one" + (map.current && map.current.d !== 1 ? ", click to look closer" : ""));

        if (n.u)
            parts.push("you are not allowed in");

        return parts.join("  ·  ");
    }

    function canTrash(path) {
        return path !== "" && path !== Storage.home && (path.indexOf(Storage.home + "/") === 0 || (map.scan && map.scan.mount !== "/" && path.indexOf(map.scan.mount + "/") === 0));
    }

    // bindings on scan may not have caught up yet, so nothing here reads them
    onScanChanged: {
        var keep = map.stack.length > 0 ? map.lastPath : "";
        var s = keep !== "" ? map.stackFor(keep) : null;
        var home = map.scan && map.scan.home ? map.stackFor(map.scan.home) : null;
        if (!s || s.length < 1)
            s = home && home.length > 1 ? home : (map.scan && map.scan.tree ? [map.scan.tree] : []);

        map.front = 0;
        levelB.place(0, 0, 1, 1, 0);
        levelB.node = null;
        levelA.node = s.length ? s[s.length - 1] : null;
        levelA.place(0, 0, 1, 1, 1);
        map.selected = null;
        map.stack = s;
        map.lastPath = map.currentPath;
    }
    implicitWidth: parent ? parent.width : Theme.dp(400)
    implicitHeight: body.implicitHeight + Theme.dp(32)

    Rectangle {
        anchors.fill: parent
        topLeftRadius: map.groupFirst ? map.outerRadius : map.innerRadius
        topRightRadius: map.groupFirst ? map.outerRadius : map.innerRadius
        bottomLeftRadius: map.groupLast ? map.outerRadius : map.innerRadius
        bottomRightRadius: map.groupLast ? map.outerRadius : map.innerRadius
        color: Theme.withBlur(Theme.bgTile)
    }

    Column {
        id: body

        x: Theme.dp(16)
        y: Theme.dp(16)
        width: parent.width - Theme.dp(32)
        spacing: Theme.dp(12)

        Item {
            width: parent.width
            height: Theme.dp(40)

            M3IconButton {
                id: upBtn

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconPath: "arrow_upward"
                enabled: map.stack.length > 1
                onClicked: map.up()
            }

            Item {
                id: crumbBox

                anchors.left: upBtn.right
                anchors.leftMargin: Theme.dp(6)
                anchors.right: tools.left
                anchors.rightMargin: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.dp(32)
                clip: true

                Row {
                    id: crumbs

                    x: Math.min(0, crumbBox.width - crumbs.width)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(2)

                    Repeater {
                        model: map.stack.length

                        Row {
                            id: crumb

                            required property int index
                            readonly property bool last: crumb.index === map.stack.length - 1

                            spacing: Theme.dp(2)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: crumb.index > 0
                                name: "chevron_right"
                                size: Theme.dp(16)
                                color: Theme.subtextDim
                            }

                            Rectangle {
                                width: crumbRow.implicitWidth + Theme.dp(22)
                                height: Theme.dp(30)
                                radius: height / 2
                                color: crumb.last ? Theme.accentContainer : (crumbArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

                                Row {
                                    id: crumbRow

                                    anchors.centerIn: parent
                                    spacing: Theme.dp(6)

                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: crumb.index === 0
                                        name: "hard_drive"
                                        size: Theme.dp(15)
                                        color: crumb.last ? Theme.fgAccentContainer : Theme.subtext
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: crumb.index === 0 ? map.volName : (map.stack[crumb.index] ? map.stack[crumb.index].n : "")
                                        color: crumb.last ? Theme.fgAccentContainer : Theme.subtext
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontLabelLg
                                        font.weight: crumb.last ? Font.DemiBold : Font.Medium
                                    }

                                }

                                MouseArea {
                                    id: crumbArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !crumb.last
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: map.jumpTo(crumb.index)
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.durQuick
                                    }

                                }

                            }

                        }

                    }

                }

            }

            Row {
                id: tools

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(6)

                M3Button {
                    variant: "tonal"
                    visible: map.homeStack !== null && map.homeStack.length > 1
                    text: map.atHome ? "Whole disk" : "Home"
                    iconPath: map.atHome ? "hard_drive" : "home"
                    onClicked: map.atHome ? map.goTo(map.scan.root) : map.goTo(map.scan.home)
                }

                M3Button {
                    variant: "tonal"
                    text: "Open"
                    iconPath: "folder_open"
                    enabled: map.currentPath !== ""
                    onClicked: Storage.open(map.currentPath)
                }

            }

        }

        Rectangle {
            id: area

            width: parent.width
            height: Theme.dp(420)
            radius: Theme.rad(18)
            color: Theme.bgSunken
            clip: true
            onWidthChanged: map.layoutW > 0 ? relayout.restart() : relayout.settle()
            onHeightChanged: map.layoutH > 0 ? relayout.restart() : relayout.settle()
            Component.onCompleted: relayout.settle()

            Timer {
                id: relayout

                function settle() {
                    map.layoutW = area.width;
                    map.layoutH = area.height;
                }

                interval: 140
                onTriggered: relayout.settle()
            }

            StorageMapLevel {
                id: levelA

                width: area.width
                height: area.height
                pal: map.pal
                selected: map.selected
                tiles: {
                    void Storage.rev;
                    return map.layout(levelA.node, map.layoutW, map.layoutH);
                }
                onTileClicked: (t) => {
                    return map.enter(t);
                }
                onTileMenu: (t) => {
                    map.selected = t.node.t === 2 ? null : (map.selected === t.node ? null : t.node);
                }
                onTileOpened: (t) => {
                    if (t.node.t === 0)
                        Storage.open(map.pathOf(t.node));

                }
            }

            StorageMapLevel {
                id: levelB

                width: area.width
                height: area.height
                pal: map.pal
                selected: map.selected
                opacity: 0
                tiles: {
                    void Storage.rev;
                    return map.layout(levelB.node, map.layoutW, map.layoutH);
                }
                onTileClicked: (t) => {
                    return map.enter(t);
                }
                onTileMenu: (t) => {
                    map.selected = t.node.t === 2 ? null : (map.selected === t.node ? null : t.node);
                }
                onTileOpened: (t) => {
                    if (t.node.t === 0)
                        Storage.open(map.pathOf(t.node));

                }
            }

            // what an empty or unreadable folder says instead of tiles
            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.dp(80)
                spacing: Theme.dp(10)
                visible: !map.busy && map.current !== null && (map.frontLevel.tiles || []).length === 0

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: map.current && map.current.u ? "lock" : "folder_open"
                    size: Theme.dp(36)
                    color: Theme.subtextDim
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: map.current && map.current.u ? "You are not allowed to look inside this folder." : "Nothing in here takes up any room."
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    wrapMode: Text.WordWrap
                }

            }

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.bgSunken, 0.72)
                opacity: map.busy ? 1 : 0
                visible: opacity > 0.01

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.dp(10)

                    LoadingIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.dp(48)
                        height: Theme.dp(48)
                        running: map.busy
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Looking closer…"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyMd
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

        }

        // the hovered tile, else the picked one, else the folder itself
        Item {
            id: foot

            readonly property var focusNode: map.hovered || map.selected || map.current

            width: parent.width
            height: Math.max(Theme.dp(40), info.implicitHeight)

            Row {
                id: info

                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(10)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(34)
                    height: Theme.dp(34)
                    radius: Theme.rad(10)
                    color: {
                        var n = foot.focusNode;
                        if (!n || !map.pal || n.t === 2 || n.u)
                            return Theme.bgHigh;

                        return map.pal.kindColor(n.k || 0);
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: {
                            var n = foot.focusNode;
                            if (!n)
                                return "folder";

                            if (n.t === 2)
                                return "more_horiz";

                            if (n.u)
                                return "lock";

                            return n.t === 1 ? "folder" : (map.pal ? map.pal.kindIcon(n.k || 0) : "category");
                        }
                        size: Theme.dp(18)
                        color: {
                            var n = foot.focusNode;
                            if (!n || !map.pal || n.t === 2 || n.u)
                                return Theme.subtext;

                            return map.pal.kindInk(n.k || 0);
                        }
                    }

                }

                Column {
                    width: parent.width - Theme.dp(44)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(1)

                    Text {
                        width: parent.width
                        text: {
                            var n = foot.focusNode;
                            if (!n)
                                return "";

                            if (n.t === 2)
                                return n.o === 1 ? "1 small item" : (n.o || 0).toLocaleString(Qt.locale(), "f", 0) + " small items";

                            return n === map.current ? (map.stack.length > 1 ? n.n : map.volName) : n.n;
                        }
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyLg
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }

                    Text {
                        width: parent.width
                        text: map.describe(foot.focusNode)
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodySm
                        elide: Text.ElideRight
                    }

                }

            }

            Row {
                id: actions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(2)
                visible: map.selected !== null

                M3IconButton {
                    iconPath: "open_in_new"
                    onClicked: Storage.open(map.pathOf(map.selected))
                }

                M3IconButton {
                    iconPath: "folder_open"
                    onClicked: Storage.reveal(map.pathOf(map.selected))
                }

                M3IconButton {
                    iconPath: "content_copy"
                    onClicked: Storage.copyPath(map.pathOf(map.selected))
                }

                M3IconButton {
                    iconPath: "delete"
                    destructive: true
                    enabled: map.selected !== null && map.canTrash(map.pathOf(map.selected)) && Storage.trashing === ""
                    onClicked: map.trashRequested(map.pathOf(map.selected), map.selected)
                }

                M3IconButton {
                    iconPath: "close"
                    onClicked: map.selected = null
                }

            }

        }

        Flow {
            width: parent.width
            spacing: Theme.dp(14)
            visible: map.visibleKinds.length > 0

            Repeater {
                model: map.visibleKinds

                Row {
                    id: kindKey

                    required property var modelData

                    spacing: Theme.dp(6)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(10)
                        height: Theme.dp(10)
                        radius: width / 2
                        color: map.pal ? map.pal.kindColor(kindKey.modelData) : Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: map.pal ? (kindKey.modelData === 0 ? "Folders and other files" : map.pal.kindName(kindKey.modelData)) : ""
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelMd
                    }

                }

            }

            Text {
                text: "Click a folder to go in, right-click anything for more"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelMd
            }

        }

    }

}
