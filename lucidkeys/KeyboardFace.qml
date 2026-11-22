import QtQuick
import qs

Item {
    id: face

    property var host
    // true only while the header grip is held
    property bool dragging: false

    readonly property real unit: face.host ? face.host.keySize : Theme.dp(46)
    readonly property real gap: Math.max(Theme.dp(3), Math.round(face.unit * 0.11))
    readonly property real pad: Math.round(face.unit * 0.34)
    readonly property real headerH: Math.round(face.unit * 0.8)
    // every row is authored to the same 15 unit width
    readonly property real span: 15
    readonly property real rowWidth: face.span * face.unit + (face.span - 1) * face.gap
    readonly property bool shifted: face.host ? face.host.shiftState > 0 : false
    readonly property bool altgr: face.host ? face.host.altGrState > 0 : false
    readonly property string keyLayer: face.host ? face.host.keyLayer : "letters"
    // the layout in use, as keymap.py read it; until it has, the US board below
    readonly property var board: face.host ? face.host.board : null
    readonly property bool manyLayouts: face.host ? face.host.layouts.length > 1 : false
    // the right Alt is AltGr where a key on the board has a third level (US has
    // one only on the key between Shift and Z, which it does not draw)
    readonly property bool hasAltGr: {
        if (!face.board)
            return false;

        var iso = face.lsgtNeeded(face.board);
        for (var n in face.board.keys) {
            if (n === "TLDE" || (n === "LSGT" && !iso))
                continue;

            if (face.board.keys[n][2])
                return true;

        }
        return false;
    }
    readonly property var lettersRows: face.board ? face.boardRows(face.board) : face.usRows
    readonly property var rows: face.keyLayer === "function" ? face.functionRows : face.lettersRows

    signal closeRequested()
    signal movedTo(real px, real py)
    signal dragFinished()

    function ch(l, s, k, w) {
        return {
            "t": "char",
            "r": "key",
            "l": l,
            "s": s === undefined ? l.toUpperCase() : s,
            "k": k === undefined ? l : k,
            "w": w === undefined ? 1 : w
        };
    }

    function nk(l, k, w, g) {
        var e = {
            "t": "named",
            "r": "util",
            "l": l,
            "k": k,
            "w": w === undefined ? 1 : w
        };
        if (g !== undefined)
            e.g = g;

        return e;
    }

    function mod(l, name, w, g) {
        var e = {
            "t": "mod",
            "r": "mod",
            "l": l,
            "k": name,
            "w": w === undefined ? 1 : w
        };
        if (g !== undefined)
            e.g = g;

        return e;
    }

    readonly property var usRows: [[face.nk("Esc", "Escape", 1), face.ch("1", "!"), face.ch("2", "@"), face.ch("3", "#"), face.ch("4", "$"), face.ch("5", "%"), face.ch("6", "^"), face.ch("7", "&"), face.ch("8", "*"), face.ch("9", "("), face.ch("0", ")"), face.ch("-", "_", "minus"), face.ch("=", "+", "equal"), face.nk("Backspace", "BackSpace", 2, "backspace")], [face.nk("Tab", "Tab", 1.5, "tab"), face.ch("q"), face.ch("w"), face.ch("e"), face.ch("r"), face.ch("t"), face.ch("y"), face.ch("u"), face.ch("i"), face.ch("o"), face.ch("p"), face.ch("[", "{", "bracketleft"), face.ch("]", "}", "bracketright"), face.ch("\\", "|", "backslash", 1.5)], [face.mod("Caps", "caps", 1.75, "caps"), face.ch("a"), face.ch("s"), face.ch("d"), face.ch("f"), face.ch("g"), face.ch("h"), face.ch("j"), face.ch("k"), face.ch("l"), face.ch(";", ":", "semicolon"), face.ch("'", "\"", "apostrophe"), face.enterKey], [face.mod("Shift", "shift", 2.25, "shift"), face.ch("z"), face.ch("x"), face.ch("c"), face.ch("v"), face.ch("b"), face.ch("n"), face.ch("m"), face.ch(",", "<", "comma"), face.ch(".", ">", "period"), face.ch("/", "?", "slash"), face.mod("Shift", "shift", 2.75, "shift")], [face.mod("Ctrl", "ctrl", 1.25), face.mod("Super", "super", 1.25), face.mod("Alt", "alt", 1.25), face.spaceKey, face.mod("Alt", "alt", 1.25), face.nk("Left", "Left", 1.125, "left"), face.nk("Up", "Up", 1.125, "up"), face.nk("Down", "Down", 1.125, "down"), face.nk("Right", "Right", 1.125, "right")]]
    // one key of the layout's board by its xkb name, every level of it along;
    // a key the layout leaves empty keeps its place, blank
    function xk(b, name, w) {
        var v = b.keys[name];
        if (!v)
            return {
                "t": "blank",
                "r": "key",
                "l": "",
                "w": w === undefined ? 1 : w
            };

        var l1 = v[0] || v[1];
        var l2 = v[1] || v[0];
        return {
            "t": "char",
            "r": "key",
            "pos": name,
            "lv": v,
            "l": l1 ? l1.c : "",
            "s": l2 ? l2.c : "",
            "k": l1 ? l1.n : "",
            "w": w === undefined ? 1 : w
        };
    }

    function xkRun(b, row, from, to) {
        var out = [];
        for (var i = from; i <= to; i++) out.push(face.xk(b, row + (i < 10 ? "0" : "") + i))
        return out;
    }

    // the key between Shift and Z on ISO boards, drawn only when it has
    // something no other key does (< and > on German)
    function lsgtNeeded(b) {
        var v = b.keys["LSGT"];
        if (!v)
            return false;

        var have = {};
        for (var n in b.keys) {
            if (n === "LSGT")
                continue;

            for (var i = 0; i < b.keys[n].length; i++) {
                if (b.keys[n][i])
                    have[b.keys[n][i].c] = true;

            }
        }
        return [v[0], v[1]].some((x) => {
            return x && !have[x.c];
        });
    }

    // the typing block in the shape of the US board, filled from the layout.
    // with more than one layout, a key left of space steps to the next
    function boardRows(b) {
        var iso = face.lsgtNeeded(b);
        var bottom = [face.mod("Ctrl", "ctrl", 1.25), face.mod("Super", "super", 1.25), face.mod("Alt", "alt", 1.25)];
        if (face.manyLayouts)
            bottom.push({
                "t": "layout",
                "r": "util",
                "l": String(b.code || "").toUpperCase(),
                "w": 1.25
            });

        bottom.push(face.manyLayouts ? face.shortSpaceKey : face.spaceKey);
        bottom.push(face.hasAltGr ? face.mod("AltGr", "altgr", 1.25) : face.mod("Alt", "alt", 1.25));
        bottom.push(face.nk("Left", "Left", 1.125, "left"), face.nk("Up", "Up", 1.125, "up"), face.nk("Down", "Down", 1.125, "down"), face.nk("Right", "Right", 1.125, "right"));
        return [[face.nk("Esc", "Escape", 1)].concat(face.xkRun(b, "AE", 1, 12), [face.nk("Backspace", "BackSpace", 2, "backspace")]), [face.nk("Tab", "Tab", 1.5, "tab")].concat(face.xkRun(b, "AD", 1, 12), [face.xk(b, "BKSL", 1.5)]), [face.mod("Caps", "caps", 1.75, "caps")].concat(face.xkRun(b, "AC", 1, 11), [face.enterKey]), (iso ? [face.mod("Shift", "shift", 1.25, "shift"), face.xk(b, "LSGT")] : [face.mod("Shift", "shift", 2.25, "shift")]).concat(face.xkRun(b, "AB", 1, 10), [face.mod("Shift", "shift", 2.75, "shift")]), bottom];
    }

    readonly property var enterKey: ({
        "t": "named",
        "r": "go",
        "l": "Enter",
        "k": "Return",
        "g": "enter",
        "w": 2.25
    })
    readonly property var spaceKey: ({
        "t": "char",
        "r": "key",
        "l": " ",
        "s": " ",
        "k": "space",
        "w": 5.5
    })
    readonly property var shortSpaceKey: ({
        "t": "char",
        "r": "key",
        "l": " ",
        "s": " ",
        "k": "space",
        "w": 4.25
    })
    readonly property var functionRows: [[face.nk("Esc", "Escape", 1), face.nk("F1", "F1"), face.nk("F2", "F2"), face.nk("F3", "F3"), face.nk("F4", "F4"), face.nk("F5", "F5"), face.nk("F6", "F6"), face.nk("F7", "F7"), face.nk("F8", "F8"), face.nk("F9", "F9"), face.nk("F10", "F10"), face.nk("F11", "F11"), face.nk("F12", "F12"), face.nk("Del", "Delete", 2)], [face.nk("PrtSc", "Print", 1.5), face.nk("Ins", "Insert", 1.5), face.nk("Home", "Home", 1.5), face.nk("End", "End", 1.5), face.nk("PgUp", "Prior", 1.5), face.nk("PgDn", "Next", 1.5), face.nk("Menu", "Menu", 1.5), face.nk("ScrLk", "Scroll_Lock", 1.5), face.nk("Pause", "Pause", 1.5), face.nk("NumLk", "Num_Lock", 1.5)], [face.nk("Prev", "XF86AudioPrev", 1.875, "prev"), face.nk("Play", "XF86AudioPlay", 1.875, "play"), face.nk("Next", "XF86AudioNext", 1.875, "next"), face.nk("Mute", "XF86AudioMute", 1.875, "mute"), face.nk("Vol-", "XF86AudioLowerVolume", 1.875, "voldown"), face.nk("Vol+", "XF86AudioRaiseVolume", 1.875, "volup"), face.nk("Dim", "XF86MonBrightnessDown", 1.875, "dim"), face.nk("Bright", "XF86MonBrightnessUp", 1.875, "bright")]]

    implicitWidth: face.rowWidth + face.pad * 2
    implicitHeight: face.pad * 2 + face.headerH + face.gap + keyStack.height

    Rectangle {
        id: panel

        anchors.fill: parent
        radius: Theme.radiusXl
        color: Theme.bg

        // swallow anything that misses a key, so it never falls through to the app
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: face.pad
            anchors.leftMargin: face.pad
            anchors.rightMargin: face.pad
            height: face.headerH

            // everything the controls do not claim is the drag grip
            MouseArea {
                id: dragZone

                // where in the panel the pointer went down. the grip travels with
                // the panel, so relative deltas double-count and run it into a clamp
                property real grabX: 0
                property real grabY: 0

                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                onPressed: (m) => {
                    var p = dragZone.mapToItem(null, m.x, m.y);
                    dragZone.grabX = p.x - face.x;
                    dragZone.grabY = p.y - face.y;
                    face.dragging = true;
                }
                onPositionChanged: (m) => {
                    var p = dragZone.mapToItem(null, m.x, m.y);
                    return face.movedTo(p.x - dragZone.grabX, p.y - dragZone.grabY);
                }
                onReleased: {
                    face.dragging = false;
                    face.dragFinished();
                }
                onCanceled: {
                    face.dragging = false;
                    face.dragFinished();
                }
            }

            KeyGlyph {
                id: grip

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "grip"
                glyphColor: Theme.subtextDim
                width: Theme.dp(18)
                height: Theme.dp(18)
            }

            Row {
                anchors.left: grip.right
                anchors.leftMargin: Theme.dp(14)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(18)

                Repeater {
                    model: [{
                        "id": "letters",
                        "label": I18n.tr("Letters")
                    }, {
                        "id": "function",
                        "label": I18n.tr("Function")
                    }]

                    Item {
                        id: tabItem

                        required property var modelData

                        readonly property bool selected: face.keyLayer === tabItem.modelData.id

                        width: tabLabel.implicitWidth
                        height: header.height

                        Text {
                            id: tabLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabItem.modelData.label
                            color: tabItem.selected ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitle
                            font.variableAxes: Theme.axes(Theme.fontTitle, 420, 0)
                            font.weight: tabItem.selected ? Font.Medium : Font.Normal

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: tabItem.selected ? tabLabel.implicitWidth : 0
                            height: Theme.dp(2)
                            radius: 1
                            color: Theme.accent

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.durShort
                                    easing.type: Theme.easeStandard
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: face.host.setLayer(tabItem.modelData.id)
                        }

                    }

                }

            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(4)

                Repeater {
                    model: [{
                        "icon": "minus",
                        "act": "smaller"
                    }, {
                        "icon": "plus",
                        "act": "bigger"
                    }, {
                        "icon": "close",
                        "act": "close"
                    }]

                    Item {
                        id: ctl

                        required property var modelData

                        readonly property bool dead: (ctl.modelData.act === "smaller" && face.unit <= face.host.minKeySize) || (ctl.modelData.act === "bigger" && face.unit >= face.host.maxKeySize)

                        width: Theme.dp(30)
                        height: Theme.dp(30)
                        opacity: ctl.dead ? 0.3 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Theme.alpha(Theme.text, ctlHover.hovered && !ctl.dead ? Theme.stateHover : 0)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                        }

                        KeyGlyph {
                            anchors.centerIn: parent
                            name: ctl.modelData.icon
                            glyphColor: Theme.subtext
                            width: Theme.dp(17)
                            height: Theme.dp(17)
                        }

                        HoverHandler {
                            id: ctlHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (ctl.modelData.act === "close")
                                    face.closeRequested();
                                else
                                    face.host.resize(ctl.modelData.act === "bigger" ? 4 : -4);
                            }
                        }

                    }

                }

            }

        }

        Column {
            id: keyStack

            anchors.top: header.bottom
            anchors.topMargin: face.gap
            anchors.horizontalCenter: parent.horizontalCenter
            width: face.rowWidth
            // held to what the keys take, so the panel keeps its size while they are gone
            height: face.rows.length * face.unit + (face.rows.length - 1) * face.gap
            spacing: face.gap

            // the keys are only built while the keyboard is up
            Repeater {
                model: !face.host || face.host.rendered ? face.rows : []

                Row {
                    id: keyRow

                    required property var modelData

                    spacing: face.gap

                    Repeater {
                        model: keyRow.modelData

                        KeyCap {
                            required property var modelData

                            entry: modelData
                            unit: face.unit
                            gap: face.gap
                            shifted: face.shifted
                            level3: face.altgr
                            // a dead key lights up while it waits for its letter
                            modState: !face.host ? 0 : (modelData.t === "mod" ? face.host.modState(modelData.k) : (face.host.deadKey && modelData.pos !== undefined && face.host.deadKey.pos === modelData.pos ? 1 : 0))
                            onFired: (repeated) => {
                                return face.host.fire(modelData, repeated);
                            }
                        }

                    }

                }

            }

        }

    }

}
