import QtQuick
import QtQuick.Window

// the shell's floating keyboard (lucidkeys), for the lock and the login
// screen: the same panel, grip, tabs, sizes and keys. it types straight into
// whatever field holds the keys rather than through wtype, which nothing in a
// locked session or at the login screen can reach; keys a field has no use
// for go to the host through named(). it floats over the lock and moves
// nothing on it: until dragged it places itself clear of the sign-in
Item {
    id: osk

    property var theme: null
    property var lock: null
    property var stage: null
    property bool open: false
    // kept up for the exit animation, which outlives open
    property bool rendered: false
    // "letters" | "function"
    property string keyLayer: "letters"
    // every modifier: 0 off, 1 one-shot, 2 locked
    property int shiftState: 0
    property int ctrlState: 0
    property int altState: 0
    property int superState: 0
    property real keySize: osk.dp(46)
    readonly property real minKeySize: osk.dp(32)
    readonly property real maxKeySize: osk.dp(80)
    // where the pointer left it; -1 until dragged
    property real liveX: -1
    property real liveY: -1
    // where it puts itself until then (place()); -1 is centred near the bottom
    property real autoX: -1
    property real autoY: -1
    readonly property real panelX: osk.clampX(osk.liveX >= 0 ? osk.liveX : (osk.autoX >= 0 ? osk.autoX : (osk.width - face.width) / 2))
    readonly property real panelY: osk.clampY(osk.liveY >= 0 ? osk.liveY : (osk.autoY >= 0 ? osk.autoY : osk.height - face.height - osk.dp(32)))
    // 0 hidden .. 1 up; it only glides to a new place once fully up
    property real k: osk.open ? 1 : 0

    signal closeRequested()
    // nothing holds the keys: the host hands them back to its field
    signal focusWanted()
    // a key a field has no use for (function keys, media keys), as a keysym
    signal named(string key, bool shift)

    function dp(px) {
        return osk.theme ? osk.theme.dp(px) : px;
    }

    function ms(d) {
        return osk.theme ? osk.theme.ms(d) : d;
    }

    function clampX(v) {
        return Math.max(0, Math.min(Math.max(0, osk.width - face.width), v));
    }

    function clampY(v) {
        return Math.max(0, Math.min(Math.max(0, osk.height - face.height), v));
    }

    function moveTo(px, py) {
        osk.liveX = osk.clampX(px);
        osk.liveY = osk.clampY(py);
    }

    function engage() {
        if (osk.lock && osk.lock.engage)
            osk.lock.engage();

    }

    function modState(name) {
        switch (name) {
        case "shift":
            return osk.shiftState;
        case "caps":
            return osk.shiftState === 2 ? 2 : 0;
        case "ctrl":
            return osk.ctrlState;
        case "alt":
            return osk.altState;
        case "super":
            return osk.superState;
        }
        return 0;
    }

    // off -> one-shot -> locked -> off. caps is the lock half of shift
    function cycleMod(name) {
        if (name === "caps") {
            osk.shiftState = osk.shiftState === 2 ? 0 : 2;
            return ;
        }
        var next = (osk.modState(name) + 1) % 3;
        switch (name) {
        case "shift":
            osk.shiftState = next;
            break;
        case "ctrl":
            osk.ctrlState = next;
            break;
        case "alt":
            osk.altState = next;
            break;
        case "super":
            osk.superState = next;
            break;
        }
    }

    function consumeOneShots() {
        if (osk.shiftState === 1)
            osk.shiftState = 0;

        if (osk.ctrlState === 1)
            osk.ctrlState = 0;

        if (osk.altState === 1)
            osk.altState = 0;

        if (osk.superState === 1)
            osk.superState = 0;

    }

    function clearMods() {
        osk.shiftState = 0;
        osk.ctrlState = 0;
        osk.altState = 0;
        osk.superState = 0;
    }

    function setLayer(l) {
        osk.keyLayer = l;
        osk.engage();
    }

    function resize(step) {
        osk.keySize = Math.max(osk.minKeySize, Math.min(osk.maxKeySize, osk.keySize + step));
        osk.engage();
    }

    function writable(it) {
        return !!it && typeof it.insert === "function" && typeof it.remove === "function" && it.readOnly === false;
    }

    // the field that holds the keys, asking the host for it first if need be
    function target() {
        var w = osk.Window.window;
        var it = w ? w.activeFocusItem : null;
        if (!osk.writable(it)) {
            osk.focusWanted();
            it = w ? w.activeFocusItem : null;
        }
        return osk.writable(it) ? it : null;
    }

    function erase(it, from, to) {
        if (it.selectionStart !== it.selectionEnd)
            it.remove(it.selectionStart, it.selectionEnd);
        else if (from < to)
            it.remove(from, to);
    }

    function step(it, to, shift) {
        to = Math.max(0, Math.min(it.length, to));
        if (shift)
            it.moveCursorSelection(to, TextInput.SelectCharacters);
        else
            it.cursorPosition = to;
    }

    // the keys a field answers itself, the way it answers the real ones
    function edit(it, key, shift, ctrl) {
        var pos = it.cursorPosition;
        switch (key) {
        case "BackSpace":
            osk.erase(it, ctrl ? 0 : Math.max(0, pos - 1), pos);
            return true;
        case "Delete":
            osk.erase(it, pos, ctrl ? it.length : Math.min(it.length, pos + 1));
            return true;
        case "Return":
            it.accepted();
            return true;
        case "Escape":
            it.remove(0, it.length);
            return true;
        case "Tab":
            var next = it;
            for (var i = 0; i < 40; i++) {
                next = next.nextItemInFocusChain(!shift);
                if (!next || next === it)
                    break;

                if (osk.writable(next) && next.visible) {
                    next.forceActiveFocus();
                    break;
                }
            }
            return true;
        case "Left":
            osk.step(it, ctrl ? 0 : pos - 1, shift);
            return true;
        case "Right":
            osk.step(it, ctrl ? it.length : pos + 1, shift);
            return true;
        case "Home":
            osk.step(it, 0, shift);
            return true;
        case "End":
            osk.step(it, it.length, shift);
            return true;
        }
        return false;
    }

    function chord(it, key, shift) {
        switch (key) {
        case "a":
            it.selectAll();
            break;
        case "c":
            it.copy();
            break;
        case "x":
            it.cut();
            break;
        case "v":
            it.paste();
            break;
        case "z":
            if (shift)
                it.redo();
            else
                it.undo();
            break;
        case "y":
            it.redo();
            break;
        }
    }

    function fire(entry) {
        osk.engage();
        if (entry.t === "mod") {
            osk.cycleMod(entry.k);
            return ;
        }
        var shift = osk.shiftState > 0;
        var ctrl = osk.ctrlState > 0;
        var other = osk.altState > 0 || osk.superState > 0;
        var it = osk.target();
        if (entry.t === "named") {
            if (!it || !osk.edit(it, entry.k, shift, ctrl))
                osk.named(entry.k, shift);

        } else if (it && ctrl) {
            osk.chord(it, entry.k, shift);
        } else if (it && !other) {
            if (it.selectionStart !== it.selectionEnd)
                it.remove(it.selectionStart, it.selectionEnd);

            it.insert(it.cursorPosition, shift ? entry.s : entry.l);
        }
        osk.consumeOneShots();
    }

    // until it is dragged, it sits where it hides none of the sign-in: near
    // the bottom if that is clear of it, else just under it, else just over it
    function place() {
        if (!osk.stage || face.dragging || osk.liveX >= 0 || osk.width <= 0)
            return ;

        var a = osk.stage.authRect ? osk.stage.authRect() : null;
        var w = face.width, h = face.height, gap = osk.dp(20), edge = osk.dp(16);
        var x = (osk.width - w) / 2, y = osk.height - h - osk.dp(32);
        if (a && a.width > 0) {
            var pad = osk.dp(12);
            var hit = x < a.x + a.width + pad && x + w > a.x - pad && y < a.y + a.height + pad && y + h > a.y - pad;
            if (hit) {
                var cx = Math.max(0, Math.min(osk.width - w, a.x + a.width / 2 - w / 2));
                if (a.y + a.height + gap + h <= osk.height - edge) {
                    x = cx;
                    y = a.y + a.height + gap;
                } else if (a.y - gap - h >= edge) {
                    x = cx;
                    y = a.y - gap - h;
                }
            }
        }
        osk.autoX = Math.round(x);
        osk.autoY = Math.round(y);
    }

    onOpenChanged: {
        if (osk.open) {
            osk.place();
            osk.rendered = true;
            hideTimer.stop();
        } else {
            osk.clearMods();
            hideTimer.restart();
        }
    }

    visible: osk.rendered

    Behavior on k {
        NumberAnimation {
            duration: osk.open ? osk.ms(320) : osk.ms(190)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: osk.open ? (osk.theme ? osk.theme.easeEmphasizedDecel : [0.05, 0.7, 0.1, 1, 1, 1]) : (osk.theme ? osk.theme.easeEmphasizedAccel : [0.3, 0, 0.8, 0.15, 1, 1])
        }

    }

    Timer {
        id: hideTimer

        interval: osk.ms(190) + 60
        onTriggered: osk.rendered = false
    }

    // the sign-in grows as the screen crosses into focus: keep clear of it,
    // and have the place ready before the keyboard is asked for
    Timer {
        interval: 120
        repeat: true
        running: osk.open || (!!osk.lock && osk.lock.focused === true)
        onTriggered: osk.place()
    }

    Item {
        id: face

        // true only while the header grip is held
        property bool dragging: false
        readonly property real unit: osk.keySize
        readonly property real gap: Math.max(osk.dp(3), Math.round(face.unit * 0.11))
        readonly property real pad: Math.round(face.unit * 0.34)
        readonly property real headerH: Math.round(face.unit * 0.8)
        // every row is authored to the same 15 unit width
        readonly property real span: 15
        readonly property real rowWidth: face.span * face.unit + (face.span - 1) * face.gap
        readonly property bool shifted: osk.shiftState > 0
        readonly property var rows: osk.keyLayer === "function" ? face.functionRows : face.lettersRows
        readonly property var lettersRows: [[face.nk("Esc", "Escape", 1), face.ch("1", "!"), face.ch("2", "@"), face.ch("3", "#"), face.ch("4", "$"), face.ch("5", "%"), face.ch("6", "^"), face.ch("7", "&"), face.ch("8", "*"), face.ch("9", "("), face.ch("0", ")"), face.ch("-", "_", "minus"), face.ch("=", "+", "equal"), face.nk("Backspace", "BackSpace", 2, "backspace")], [face.nk("Tab", "Tab", 1.5, "tab"), face.ch("q"), face.ch("w"), face.ch("e"), face.ch("r"), face.ch("t"), face.ch("y"), face.ch("u"), face.ch("i"), face.ch("o"), face.ch("p"), face.ch("[", "{", "bracketleft"), face.ch("]", "}", "bracketright"), face.ch("\\", "|", "backslash", 1.5)], [face.mod("Caps", "caps", 1.75, "caps"), face.ch("a"), face.ch("s"), face.ch("d"), face.ch("f"), face.ch("g"), face.ch("h"), face.ch("j"), face.ch("k"), face.ch("l"), face.ch(";", ":", "semicolon"), face.ch("'", "\"", "apostrophe"), face.enterKey], [face.mod("Shift", "shift", 2.25, "shift"), face.ch("z"), face.ch("x"), face.ch("c"), face.ch("v"), face.ch("b"), face.ch("n"), face.ch("m"), face.ch(",", "<", "comma"), face.ch(".", ">", "period"), face.ch("/", "?", "slash"), face.mod("Shift", "shift", 2.75, "shift")], [face.mod("Ctrl", "ctrl", 1.25), face.mod("Super", "super", 1.25), face.mod("Alt", "alt", 1.25), face.spaceKey, face.mod("Alt", "alt", 1.25), face.nk("Left", "Left", 1.125, "left"), face.nk("Up", "Up", 1.125, "up"), face.nk("Down", "Down", 1.125, "down"), face.nk("Right", "Right", 1.125, "right")]]
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
        readonly property var functionRows: [[face.nk("Esc", "Escape", 1), face.nk("F1", "F1"), face.nk("F2", "F2"), face.nk("F3", "F3"), face.nk("F4", "F4"), face.nk("F5", "F5"), face.nk("F6", "F6"), face.nk("F7", "F7"), face.nk("F8", "F8"), face.nk("F9", "F9"), face.nk("F10", "F10"), face.nk("F11", "F11"), face.nk("F12", "F12"), face.nk("Del", "Delete", 2)], [face.nk("PrtSc", "Print", 1.5), face.nk("Ins", "Insert", 1.5), face.nk("Home", "Home", 1.5), face.nk("End", "End", 1.5), face.nk("PgUp", "Prior", 1.5), face.nk("PgDn", "Next", 1.5), face.nk("Menu", "Menu", 1.5), face.nk("ScrLk", "Scroll_Lock", 1.5), face.nk("Pause", "Pause", 1.5), face.nk("NumLk", "Num_Lock", 1.5)], [face.nk("Prev", "XF86AudioPrev", 1.875, "prev"), face.nk("Play", "XF86AudioPlay", 1.875, "play"), face.nk("Next", "XF86AudioNext", 1.875, "next"), face.nk("Mute", "XF86AudioMute", 1.875, "mute"), face.nk("Vol-", "XF86AudioLowerVolume", 1.875, "voldown"), face.nk("Vol+", "XF86AudioRaiseVolume", 1.875, "volup"), face.nk("Dim", "XF86MonBrightnessDown", 1.875, "dim"), face.nk("Bright", "XF86MonBrightnessUp", 1.875, "bright")]]

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

        x: osk.panelX
        y: osk.panelY
        width: face.rowWidth + face.pad * 2
        height: face.pad * 2 + face.headerH + face.gap + keyStack.height
        opacity: osk.open ? 1 : 0
        // the entrance rise lives apart from the place, so a new place glides
        // and the rise stays a rise
        transform: Translate {
            y: osk.open ? 0 : osk.dp(22)

            Behavior on y {
                NumberAnimation {
                    duration: osk.open ? osk.ms(320) : osk.ms(190)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: osk.open ? (osk.theme ? osk.theme.easeEmphasizedDecel : [0.05, 0.7, 0.1, 1, 1, 1]) : (osk.theme ? osk.theme.easeEmphasizedAccel : [0.3, 0, 0.8, 0.15, 1, 1])
                }

            }

        }

        Rectangle {
            id: panel

            anchors.fill: parent
            radius: osk.theme ? osk.theme.rad(28) : 28
            color: osk.theme ? osk.theme.card : "black"

            // swallow anything that misses a key, so it never falls through to the stage
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
                        var p = dragZone.mapToItem(osk, m.x, m.y);
                        dragZone.grabX = p.x - face.x;
                        dragZone.grabY = p.y - face.y;
                        face.dragging = true;
                        osk.engage();
                    }
                    onPositionChanged: (m) => {
                        var p = dragZone.mapToItem(osk, m.x, m.y);
                        osk.moveTo(p.x - dragZone.grabX, p.y - dragZone.grabY);
                    }
                    onReleased: face.dragging = false
                    onCanceled: face.dragging = false
                }

                Glyph {
                    id: grip

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    name: "drag_indicator"
                    size: osk.dp(18)
                    color: osk.theme ? osk.theme.subtextDim : "white"
                }

                Row {
                    anchors.left: grip.right
                    anchors.leftMargin: osk.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: osk.dp(18)

                    Repeater {
                        model: [{
                            "id": "letters",
                            "label": osk.lock && osk.lock.tr ? osk.lock.tr("Letters") : "Letters" // i18n-skip
                        }, {
                            "id": "function",
                            "label": osk.lock && osk.lock.tr ? osk.lock.tr("Function") : "Function" // i18n-skip
                        }]

                        Item {
                            id: tabItem

                            required property var modelData
                            readonly property bool selected: osk.keyLayer === tabItem.modelData.id

                            width: tabLabel.implicitWidth
                            height: header.height

                            Text {
                                id: tabLabel

                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                text: tabItem.modelData.label
                                color: osk.theme ? (tabItem.selected ? osk.theme.text : osk.theme.subtext) : "white"
                                font.family: osk.theme ? osk.theme.fontFamily : ""
                                font.pixelSize: osk.theme ? osk.theme.fs(13) : 13
                                font.variableAxes: osk.theme ? osk.theme.axes(osk.theme.fs(13), 420, 0) : ({})
                                font.weight: tabItem.selected ? Font.Medium : Font.Normal

                                Behavior on color {
                                    ColorAnimation {
                                        duration: osk.ms(120)
                                    }

                                }

                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: tabItem.selected ? tabLabel.implicitWidth : 0
                                height: osk.dp(2)
                                radius: 1
                                color: osk.theme ? osk.theme.accent : "white"

                                Behavior on width {
                                    NumberAnimation {
                                        duration: osk.ms(180)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: osk.setLayer(tabItem.modelData.id)
                            }

                        }

                    }

                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: osk.dp(4)

                    Repeater {
                        model: [{
                            "icon": "remove",
                            "act": "smaller"
                        }, {
                            "icon": "add",
                            "act": "bigger"
                        }, {
                            "icon": "close",
                            "act": "close"
                        }]

                        Item {
                            id: ctl

                            required property var modelData
                            readonly property bool dead: (ctl.modelData.act === "smaller" && face.unit <= osk.minKeySize) || (ctl.modelData.act === "bigger" && face.unit >= osk.maxKeySize)

                            width: osk.dp(30)
                            height: osk.dp(30)
                            opacity: ctl.dead ? 0.3 : 1

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: osk.theme ? osk.theme.alpha(osk.theme.text, ctlHover.hovered && !ctl.dead ? osk.theme.stateHover : 0) : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: osk.ms(120)
                                    }

                                }

                            }

                            Glyph {
                                anchors.centerIn: parent
                                name: ctl.modelData.icon
                                size: osk.dp(17)
                                color: osk.theme ? osk.theme.subtext : "white"
                            }

                            HoverHandler {
                                id: ctlHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (ctl.modelData.act === "close")
                                        osk.closeRequested();
                                    else
                                        osk.resize(ctl.modelData.act === "bigger" ? 4 : -4);
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
                    model: osk.rendered ? face.rows : []

                    Row {
                        id: keyRow

                        required property var modelData

                        spacing: face.gap

                        Repeater {
                            model: keyRow.modelData

                            OnScreenKey {
                                required property var modelData

                                theme: osk.theme
                                entry: modelData
                                unit: face.unit
                                gap: face.gap
                                shifted: face.shifted
                                modState: modelData.t === "mod" ? osk.modState(modelData.k) : 0
                                onFired: osk.fire(modelData)
                            }

                        }

                    }

                }

            }

        }

        // a new place glides once it is up; a glide must never sit between
        // the pointer and the panel
        Behavior on x {
            enabled: !face.dragging && osk.k > 0.99

            NumberAnimation {
                duration: osk.ms(300)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: osk.theme ? osk.theme.curveStandard : [0.2, 0, 0, 1, 1, 1]
            }

        }

        Behavior on y {
            enabled: !face.dragging && osk.k > 0.99

            NumberAnimation {
                duration: osk.ms(300)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: osk.theme ? osk.theme.curveStandard : [0.2, 0, 0, 1, 1, 1]
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: osk.open ? osk.ms(320) : osk.ms(190)
                easing.type: Easing.OutCubic
            }

        }

    }

}
