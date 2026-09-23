import QtQuick
import qs

Item {
    id: face

    property var host
    // true only while the header grip is held
    property bool dragging: false

    readonly property real unit: face.host ? face.host.keySize : 46
    readonly property real gap: Math.max(3, Math.round(face.unit * 0.11))
    readonly property real pad: Math.round(face.unit * 0.34)
    readonly property real headerH: Math.round(face.unit * 0.8)
    // every row is authored to the same 15 unit width
    readonly property real span: 15
    readonly property real rowWidth: face.span * face.unit + (face.span - 1) * face.gap
    readonly property bool shifted: face.host ? face.host.shiftState > 0 : false
    readonly property string keyLayer: face.host ? face.host.keyLayer : "letters"
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
                width: 18
                height: 18
            }

            Row {
                anchors.left: grip.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

                Repeater {
                    model: [{
                        "id": "letters",
                        "label": "Letters"
                    }, {
                        "id": "function",
                        "label": "Function"
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
                            height: 2
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
                spacing: 4

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

                        width: 30
                        height: 30
                        opacity: ctl.dead ? 0.3 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.pill(width)
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
                            width: 17
                            height: 17
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
            spacing: face.gap

            Repeater {
                model: face.rows

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
                            modState: (face.host && modelData.t === "mod") ? face.host.modState(modelData.k) : 0
                            onFired: face.host.fire(modelData)
                        }

                    }

                }

            }

        }

    }

}
